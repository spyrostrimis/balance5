extends "res://scripts/canyon/canyon_level.gd"
## HD-2D A/B on canyon v2: same geometry, camera, lighting and lens, different surface treatment.
##   A   — current realistic materials (linear filtering, high-resolution textures)
##   B32 — pixel-art textures at 32 texels per metre, nearest filtering
##   B64 — pixel-art textures at 64 texels per metre, nearest filtering
## Keys 1, 2, 3 switch modes. PIXEL_AB_MODE=A|B32|B64 sets the starting mode for capture runs.

const MODES: Array[String] = ["A", "B32", "B64"]
const PIXEL_SHADERS := {
	"res://assets/shaders/hd2d_octopath_rock.gdshader": "res://assets/shaders/pixel/hd2d_octopath_rock_pixel.gdshader",
	"res://assets/shaders/hd2d_canyon_ground_crisp.gdshader": "res://assets/shaders/pixel/hd2d_canyon_ground_crisp_pixel.gdshader",
	"res://assets/shaders/hd2d_chatgpt_boulder.gdshader": "res://assets/shaders/pixel/hd2d_chatgpt_boulder_pixel.gdshader",
}

@export_enum("A", "B32", "B64") var mode := "B32"

## Each entry: {node, kind, original}, where kind is "surface", "override" or "sprite".
var _slots: Array[Dictionary] = []
var _pixel_cache := {}
var _label: Label


func _ready() -> void:
	super()
	_collect(self)
	var start := OS.get_environment("PIXEL_AB_MODE")
	set_mode(start if start in MODES else mode)
	_label = Label.new()
	_label.position = Vector2(16, 690)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	var layer := CanvasLayer.new()
	layer.add_child(_label)
	add_child(layer)
	_label.visible = start.is_empty()
	_update_label()


func set_mode(value: String) -> void:
	mode = value
	var density := 0 if value == "A" else int(value.substr(1))
	for slot in _slots:
		var node: Node = slot["node"]
		match slot["kind"]:
			"surface":
				(node as MeshInstance3D).set_surface_override_material(0, _material_for(slot["original"], density))
			"override":
				(node as GeometryInstance3D).material_override = _material_for(slot["original"], density)
			"sprite":
				_apply_sprite(node as Sprite3D, slot["original"], density)
	print("PixelAB mode=%s slots=%d" % [value, _slots.size()])
	_update_label()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = [KEY_1, KEY_2, KEY_3].find(event.keycode)
		if index >= 0:
			set_mode(MODES[index])
			get_viewport().set_input_as_handled()


func _update_label() -> void:
	if _label:
		_label.text = "Mode %s   ·   1 = A realistic   2 = B32 pixel   3 = B64 pixel" % mode


func _collect(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var override := mesh.get_surface_override_material(0) as ShaderMaterial
		if override and PIXEL_SHADERS.has(override.shader.resource_path):
			_slots.append({"node": mesh, "kind": "surface", "original": override})
		var whole := mesh.material_override as ShaderMaterial
		if whole and PIXEL_SHADERS.has(whole.shader.resource_path):
			_slots.append({"node": mesh, "kind": "override", "original": whole})
	elif node is Sprite3D:
		var sprite := node as Sprite3D
		_slots.append({"node": sprite, "kind": "sprite", "original": {
			"texture": sprite.texture, "pixel_size": sprite.pixel_size, "filter": sprite.texture_filter,
		}})
	for child in node.get_children():
		_collect(child)


func _material_for(original: ShaderMaterial, density: int) -> ShaderMaterial:
	if density == 0:
		return original
	var key := [original.get_instance_id(), density]
	if _pixel_cache.has(key):
		return _pixel_cache[key]
	var pixel := original.duplicate() as ShaderMaterial
	pixel.shader = load(PIXEL_SHADERS[original.shader.resource_path])
	for uniform in original.shader.get_shader_uniform_list():
		var value: Variant = original.get_shader_parameter(uniform["name"])
		if value is Texture2D:
			pixel.set_shader_parameter(uniform["name"], _pixel_texture(value, density))
		elif value != null:
			pixel.set_shader_parameter(uniform["name"], value)
	_pixel_cache[key] = pixel
	return pixel


func _pixel_texture(texture: Texture2D, density: int) -> Texture2D:
	var path := "res://assets/textures/pixel_ab/d%d/%s" % [density, texture.resource_path.get_file()]
	if ResourceLoader.exists(path):
		return load(path)
	return texture


func _apply_sprite(sprite: Sprite3D, original: Dictionary, density: int) -> void:
	if sprite.get_parent() is CharacterBody3D:
		# The commander keeps her own art; only the filter changes so her pixels stay square.
		sprite.texture_filter = original["filter"] if density == 0 else BaseMaterial3D.TEXTURE_FILTER_NEAREST
		return
	var source: Texture2D = original["texture"]
	if density == 0:
		sprite.texture = source
		sprite.pixel_size = original["pixel_size"]
		sprite.texture_filter = original["filter"]
		return
	var pixel := _pixel_texture(source, density)
	sprite.texture = pixel
	sprite.pixel_size = original["pixel_size"] * float(source.get_width()) / float(pixel.get_width())
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
