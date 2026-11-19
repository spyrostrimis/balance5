extends "res://scripts/canyon/canyon_level.gd"
## HD-2D A/B on canyon v2: same geometry, camera, lighting and lens, different surface treatment.
##   1  A       current realistic materials (linear filtering, high-resolution textures)
##   2  B32     pixel textures derived from the current art at 32 texels per metre, nearest filtering
##   3  B64     the same at 64 texels per metre
##   4  art*    authored pixel sets in assets/textures/pixel_ab/art*/ (tools/python/pixel_snap.py), nearest
##              filtering, mapped at the metres in each set's manifest.json. Missing roles fall back to B64.
##   5  hr*     authored high-resolution sets in assets/textures/pixel_ab/hr*/ (tools/python/smooth_texture.py),
##              the source filtering, same mapping. Missing roles fall back to A.
## Press 4 or 5 again to cycle through the sets of that kind. PIXEL_AB_MODE=A|B32|B64|ART|HR|<set folder>
## sets the starting mode for capture runs (ART and HR pick the first set of that kind).
##   R      raised stones: a dense road mesh lifts every cobble by the set's chatgpt_cobble_height.png
##          (tools/python/relief_height.py), so stones get real shoulders and cast real shadows.
##          Only sets with that file. PIXEL_AB_RELIEF=1 turns it on for capture runs,
##          PIXEL_AB_RELIEF_DEPTH sets the stone height in metres.

const BASE_MODES: Array[String] = ["A", "B32", "B64"]
const SETS_ROOT := "res://assets/textures/pixel_ab/"
const SHADER_VARIANTS := {
	"res://assets/shaders/hd2d_octopath_rock.gdshader": "res://assets/shaders/pixel/hd2d_octopath_rock_%s.gdshader",
	"res://assets/shaders/hd2d_canyon_ground_crisp.gdshader": "res://assets/shaders/pixel/hd2d_canyon_ground_crisp_%s.gdshader",
	"res://assets/shaders/hd2d_chatgpt_boulder.gdshader": "res://assets/shaders/pixel/hd2d_chatgpt_boulder_%s.gdshader",
}

@export var mode := "B64"
@export var relief := false
## Height of a stone top above its joints, in metres (6 cm read as raised but unwalkable, §14d; real cobbles sit 1-3 cm proud).
@export var relief_depth := 0.02
## Road relief mesh: spacing between vertices and the stretch it covers.
@export var relief_spacing := 0.015
@export var relief_z_range := Vector2(-16.0, 10.0)
@export var relief_half_width := 1.45

const RELIEF_HEIGHT := "chatgpt_cobble_height.png"

## Each entry: {node, kind, original}, where kind is "surface", "override" or "sprite".
var _slots: Array[Dictionary] = []
var _material_cache := {}
var _art_sets: Array[String] = []
var _hr_sets: Array[String] = []
## Set folder -> {texture file name: manifest entry}
var _manifests := {}
var _label: Label
var _relief_mesh: MeshInstance3D
var _floor_slot := {}


func _ready() -> void:
	super()
	_discover_sets()
	_collect(self)
	relief = OS.get_environment("PIXEL_AB_RELIEF") == "1" or relief
	if not OS.get_environment("PIXEL_AB_RELIEF_DEPTH").is_empty():
		relief_depth = OS.get_environment("PIXEL_AB_RELIEF_DEPTH").to_float()
	set_mode(_resolve(OS.get_environment("PIXEL_AB_MODE"), mode))
	_label = Label.new()
	_label.position = Vector2(16, 690)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	var layer := CanvasLayer.new()
	layer.add_child(_label)
	add_child(layer)
	_label.visible = OS.get_environment("PIXEL_AB_MODE").is_empty()
	_update_label()


func set_mode(value: String) -> void:
	mode = value
	for slot in _slots:
		var node: Node = slot["node"]
		match slot["kind"]:
			"surface":
				(node as MeshInstance3D).set_surface_override_material(0, _material_for(slot["original"], value))
			"override":
				(node as GeometryInstance3D).material_override = _material_for(slot["original"], value)
			"sprite":
				_apply_sprite(node as Sprite3D, slot["original"], value)
	_update_relief()
	print("PixelAB mode=%s slots=%d authored=%d relief=%s" % [value, _slots.size(), _manifests.get(value, {}).size(),
		("%.3f m" % relief_depth) if _relief_mesh and _relief_mesh.visible else "off"])
	_update_label()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3:
			set_mode(BASE_MODES[event.keycode - KEY_1])
		KEY_4:
			_cycle(_art_sets)
		KEY_5:
			_cycle(_hr_sets)
		KEY_R:
			relief = not relief
			set_mode(mode)
		_:
			return
	get_viewport().set_input_as_handled()


func _cycle(sets: Array[String]) -> void:
	if sets.is_empty():
		return
	var index := sets.find(mode)
	set_mode(sets[(index + 1) % sets.size()])


func _resolve(requested: String, fallback: String) -> String:
	if requested in BASE_MODES or requested in _art_sets or requested in _hr_sets:
		return requested
	if requested == "ART" and not _art_sets.is_empty():
		return _art_sets[0]
	if requested == "HR" and not _hr_sets.is_empty():
		return _hr_sets[0]
	if not requested.is_empty():
		push_warning("PIXEL_AB_MODE=%s not found; using %s" % [requested, fallback])
	return fallback


func _update_label() -> void:
	if _label:
		var relief_text := "off"
		if relief:
			relief_text = ("%.1f cm" % (relief_depth * 100.0)) if _relief_height(mode) else "no height in this set"
		_label.text = "Mode %s   ·   1 A realistic   2 B32   3 B64   4 pixel sets %s   5 smooth sets %s   R raised stones: %s" % [
			mode, _art_sets if _art_sets.size() else "(none)", _hr_sets if _hr_sets.size() else "(none)", relief_text]


func _discover_sets() -> void:
	var folders := Array(DirAccess.get_directories_at(SETS_ROOT))
	folders.sort()
	for folder: String in folders:
		var kind := "art" if folder.begins_with("art") else ("hr" if folder.begins_with("hr") else "")
		if kind.is_empty():
			continue
		var manifest_path := SETS_ROOT + folder + "/manifest.json"
		var textures := {}
		if FileAccess.file_exists(manifest_path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			if parsed is Dictionary:
				textures = (parsed as Dictionary).get("textures", {})
		if textures.is_empty():
			continue
		_manifests[folder] = textures
		(_art_sets if kind == "art" else _hr_sets).append(folder)


func _is_smooth(set_name: String) -> bool:
	return set_name == "A" or set_name.begins_with("hr")


## Texture folders to search, in order. An empty result means "keep the original texture".
func _dirs_for(set_name: String) -> Array[String]:
	match set_name:
		"A":
			return []
		"B32":
			return ["d32"]
		"B64":
			return ["d64"]
	if set_name.begins_with("art"):
		return [set_name, "d64"]
	return [set_name]


func _collect(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var override := mesh.get_surface_override_material(0) as ShaderMaterial
		if override and SHADER_VARIANTS.has(override.shader.resource_path):
			_slots.append({"node": mesh, "kind": "surface", "original": override})
			if override.shader.resource_path.ends_with("hd2d_canyon_ground_crisp.gdshader") and _floor_slot.is_empty():
				_floor_slot = _slots.back()
		var whole := mesh.material_override as ShaderMaterial
		if whole and SHADER_VARIANTS.has(whole.shader.resource_path):
			_slots.append({"node": mesh, "kind": "override", "original": whole})
	elif node is Sprite3D:
		var sprite := node as Sprite3D
		_slots.append({"node": sprite, "kind": "sprite", "original": {
			"texture": sprite.texture, "pixel_size": sprite.pixel_size, "filter": sprite.texture_filter,
		}})
	for child in node.get_children():
		_collect(child)


func _material_for(original: ShaderMaterial, set_name: String) -> ShaderMaterial:
	if set_name == "A":
		return original
	var key := [original.get_instance_id(), set_name]
	if _material_cache.has(key):
		return _material_cache[key]
	var material := original.duplicate() as ShaderMaterial
	var variant := "smooth" if _is_smooth(set_name) else "pixel"
	material.shader = load(SHADER_VARIANTS[original.shader.resource_path] % variant)
	for uniform in original.shader.get_shader_uniform_list():
		var value: Variant = original.get_shader_parameter(uniform["name"])
		if value is Texture2D:
			var found := _set_texture(value, set_name)
			material.set_shader_parameter(uniform["name"], found["texture"])
			_apply_authored_scale(material, uniform["name"], found["metres"])
		elif value != null:
			material.set_shader_parameter(uniform["name"], value)
	_material_cache[key] = material
	return material


## Returns {texture, dir, metres}: the first folder (in _dirs_for order) holding this file name.
## metres is set only for authored sets, from that set's manifest.
func _set_texture(texture: Texture2D, set_name: String) -> Dictionary:
	var file := texture.resource_path.get_file()
	for dir: String in _dirs_for(set_name):
		var path := SETS_ROOT + "%s/%s" % [dir, file]
		if ResourceLoader.exists(path):
			var metres: Array = []
			if _manifests.has(dir):
				# Normal and ORM maps share their albedo's manifest entry.
				var entry := file.replace("_normal.", "_albedo.").replace("_orm.", "_albedo.")
				metres = _manifests[dir].get(entry, {}).get("metres", [])
				if metres.size() != 2:
					push_warning("%s/%s has no manifest entry for %s; run the tool again" % [dir, file, entry])
			return {"texture": load(path), "dir": dir, "metres": metres}
	return {"texture": texture, "dir": "", "metres": []}


## Map an authored texture at its exact size: one repeat covers the metres in the manifest.
func _apply_authored_scale(material: ShaderMaterial, uniform_name: StringName, metres: Array) -> void:
	if metres.size() != 2:
		return
	var along := float(metres[0])
	var up := float(metres[1])
	match String(uniform_name):
		"sandstone_tex":
			material.set_shader_parameter("strata_scale", Vector2(1.0 / along, 1.0 / up))
		"basalt_tex":
			material.set_shader_parameter("basalt_scale", 1.0 / along)
			material.set_shader_parameter("basalt_side_scale", Vector2(1.0 / up, 1.0 / along))
		"boulder_tex":
			material.set_shader_parameter("boulder_scale", 1.0 / along)
		"cobble_tex":
			material.set_shader_parameter("cobble_tile_metres", along)
		"sand_tex":
			material.set_shader_parameter("sand_scale", Vector2(1.0 / along, 1.0 / up))
			material.set_shader_parameter("sand_scale_detail", Vector2(0.674 / along, 0.708 / up))
		"desert_sand_tex":
			material.set_shader_parameter("desert_scale", 1.0 / along)
		"albedo_tex":
			material.set_shader_parameter("tile_metres", along)


func _apply_sprite(sprite: Sprite3D, original: Dictionary, set_name: String) -> void:
	var smooth := _is_smooth(set_name)
	if sprite.get_parent() is CharacterBody3D:
		# The commander keeps her own art; in pixel modes only the filter changes so her pixels stay square.
		sprite.texture_filter = original["filter"] if smooth else BaseMaterial3D.TEXTURE_FILTER_NEAREST
		return
	var source: Texture2D = original["texture"]
	var found := _set_texture(source, set_name)
	if found["dir"] == "":
		sprite.texture = source
		sprite.pixel_size = original["pixel_size"]
		sprite.texture_filter = original["filter"]
		return
	var replacement: Texture2D = found["texture"]
	sprite.texture = replacement
	var metres: Array = found["metres"]
	if metres.size() == 2:
		# Authored sprites keep their own size: one texel = 1 / density metres.
		sprite.pixel_size = float(metres[0]) / float(replacement.get_width())
	else:
		# Derived sprites keep the original world size.
		sprite.pixel_size = original["pixel_size"] * float(source.get_width()) / float(replacement.get_width())
	sprite.texture_filter = original["filter"] if smooth else BaseMaterial3D.TEXTURE_FILTER_NEAREST


func _relief_height(set_name: String) -> Texture2D:
	if not (set_name.begins_with("art") or set_name.begins_with("hr")):
		return null
	var path := SETS_ROOT + "%s/%s" % [set_name, RELIEF_HEIGHT]
	return load(path) if ResourceLoader.exists(path) else null


## The floor is one flat quad, so the raised stones need their own dense strip along the route. It uses the
## floor's material for the current set with relief_depth set, so colour and mapping match exactly.
func _update_relief() -> void:
	var height := _relief_height(mode)
	if not relief or height == null or _floor_slot.is_empty():
		if _relief_mesh:
			_relief_mesh.visible = false
		return
	if _relief_mesh == null:
		_relief_mesh = MeshInstance3D.new()
		_relief_mesh.name = "RoadRelief"
		_relief_mesh.mesh = _build_relief_strip(get_node(route_path))
		add_child(_relief_mesh)
	var key := [_floor_slot["original"].get_instance_id(), mode, "relief"]
	if not _material_cache.has(key):
		var material := _material_for(_floor_slot["original"], mode).duplicate() as ShaderMaterial
		material.set_shader_parameter("cobble_height", height)
		material.set_shader_parameter("relief_depth", relief_depth)
		_material_cache[key] = material
	_relief_mesh.material_override = _material_cache[key]
	_relief_mesh.visible = true


func _build_relief_strip(route: Node) -> ArrayMesh:
	var columns := int(ceil(relief_half_width * 2.0 / relief_spacing)) + 1
	var rows := int(ceil((relief_z_range.y - relief_z_range.x) / relief_spacing)) + 1
	var vertices := PackedVector3Array()
	vertices.resize(rows * columns)
	var normals := PackedVector3Array()
	normals.resize(rows * columns)
	normals.fill(Vector3.UP)
	var tangents := PackedFloat32Array()
	tangents.resize(rows * columns * 4)
	for r in rows:
		var z := relief_z_range.y - r * relief_spacing
		var x0: float = route.center_x(z) - relief_half_width
		for c in columns:
			var i := r * columns + c
			# 2 mm above the floor so the joints never fight it for depth; the stones rise from there.
			vertices[i] = Vector3(x0 + c * relief_spacing, 0.002, z)
			tangents[i * 4] = 1.0
			tangents[i * 4 + 3] = 1.0
	var indices := PackedInt32Array()
	indices.resize((rows - 1) * (columns - 1) * 6)
	var k := 0
	for r in rows - 1:
		for c in columns - 1:
			var a := r * columns + c
			var b := a + columns
			# Clockwise seen from above: Godot's front face.
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = a + 1
			indices[k + 3] = a + 1
			indices[k + 4] = b
			indices[k + 5] = b + 1
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# The shader lifts vertices by up to relief_depth; widen the bounds so culling keeps the raised parts.
	mesh.custom_aabb = AABB(Vector3(-50.0, -0.1, relief_z_range.x - 1.0), Vector3(100.0, 0.4, relief_z_range.y - relief_z_range.x + 2.0))
	print("PixelAB relief strip: %d x %d vertices, %d triangles" % [columns, rows, indices.size() / 3])
	return mesh
