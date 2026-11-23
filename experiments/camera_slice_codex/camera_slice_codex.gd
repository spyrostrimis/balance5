extends Node3D

const SLICE_DIR := "res://experiments/camera_slice_codex/"
const ART_DIR := SLICE_DIR + "assets/"
const HERO_SOURCE := "res://assets/textures/units/blue_commander_rpg.png"
const GROUND_Z := -130.0
const ROAD_HALF_WIDTH := 2.0
const CLIFF_FRONT_Z := 20
const CLIFF_LAST_Z := -90
const CLIFF_DEPTH := 5
const SEED := 42
const HERO_SPEED := 3.0
const CAMERA_SPAN := 8.95
const PROP_COLORS := {
	"rock": Color("a16342"),
	"shrub": Color("687747"),
	"grass": Color("b69d53"),
	"flower": Color("bb6549"),
}

var _profiles: Dictionary
var _profile := "A"
var _pitch := 0.0
var _distance := 0.0
var _cliff_edges := PackedVector2Array()

@onready var _camera: Camera3D = $Camera3D
@onready var _hero: Node3D = $Hero
@onready var _label: Label = $HUD/ProfileLabel


func _ready() -> void:
	get_viewport().anisotropic_filtering_level = Viewport.ANISOTROPY_16X
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	_build_ground()
	_build_cliffs()
	_build_props()
	_build_hero()
	_profiles = JSON.parse_string(FileAccess.get_file_as_string(SLICE_DIR + "camera_profiles.json"))
	_select_profile("A")


func _process(delta: float) -> void:
	var move := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		0.0,
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	_hero.position += move.normalized() * HERO_SPEED * delta
	_update_camera()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			_select_profile("A")
		KEY_2:
			_select_profile("B")
		KEY_P:
			_save_screenshot()
		KEY_ESCAPE:
			get_tree().quit()


func _select_profile(profile: String) -> void:
	_profile = profile
	var config: Dictionary = _profiles[profile]
	var fov := float(config["fov"])
	_pitch = deg_to_rad(float(config["pitch"]))
	_distance = CAMERA_SPAN / (2.0 * tan(deg_to_rad(fov) * 0.5))
	_camera.set_perspective(fov, 0.05, 1000.0)
	_label.text = "%s pitch %d fov %d" % [profile, config["pitch"], fov]
	_update_camera()


func _update_camera() -> void:
	var target := _hero.global_position + Vector3.UP
	var camera_position := target + _distance * Vector3(0.0, sin(_pitch), cos(_pitch))
	_camera.look_at_from_position(camera_position, target, Vector3.UP)


func _save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path(SLICE_DIR + "shots")
	var path := directory.path_join(_profile + ".png")
	var result := DirAccess.make_dir_recursive_absolute(directory)
	if result == OK:
		result = get_viewport().get_texture().get_image().save_png(path)
	if result == OK:
		print("Saved screenshot ", path)
	else:
		push_error("Could not save %s (%s)" % [path, error_string(result)])


func _build_ground() -> void:
	var sand := PlaneMesh.new()
	sand.size = Vector2(300.0, 300.0)
	sand.material = _surface_material("sand_topdown.png", Color("d69753"), sand.size / 4.0)
	_add_mesh($Ground, "Sand", sand, Vector3(0.0, 0.0, GROUND_Z))

	var road := PlaneMesh.new()
	road.size = Vector2(ROAD_HALF_WIDTH * 2.0, 300.0)
	road.material = _surface_material("road_topdown.png", Color("817165"), road.size / 4.0)
	_add_mesh($Ground, "Road", road, Vector3(0.0, 0.01, GROUND_Z))


func _build_cliffs() -> void:
	var front := QuadMesh.new()
	front.size = Vector2(8.0, 6.0)
	front.material = _surface_material("cliff_front.png", Color("9e5839"), Vector2.ONE)
	var side := QuadMesh.new()
	side.size = Vector2(CLIFF_DEPTH, 6.0)
	var side_material := front.material.duplicate() as StandardMaterial3D
	side_material.uv1_scale.x = CLIFF_DEPTH / 8.0
	side.material = side_material
	var top := QuadMesh.new()
	top.size = Vector2(8.0, CLIFF_DEPTH)
	top.material = _surface_material("cliff_top.png", Color("b7784c"), top.size / Vector2(8.0, 4.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for z in range(CLIFF_FRONT_Z, CLIFF_LAST_Z - 1, -CLIFF_DEPTH):
		var edges := Vector2(2.5 + rng.randf_range(0.0, 1.5), 2.5 + rng.randf_range(0.0, 1.5))
		_cliff_edges.append(edges)
		for direction: float in [-1.0, 1.0]:
			var edge := edges.x if direction < 0.0 else edges.y
			var block := Node3D.new()
			block.name = "CliffBlock_%s_%02d" % ["L" if direction < 0.0 else "R", _cliff_edges.size()]
			block.position = Vector3(direction * edge, 0.0, z)
			$Cliffs.add_child(block)
			var midpoint_x := direction * front.size.x * 0.5
			var midpoint_z := -CLIFF_DEPTH * 0.5
			var mid_height := front.size.y * 0.5
			_add_mesh(block, "Front", front, Vector3(midpoint_x, mid_height, 0.0))
			_add_mesh(block, "Top", top, Vector3(midpoint_x, front.size.y, midpoint_z)).rotation.x = -PI * 0.5
			_add_mesh(block, "InnerSide", side, Vector3(0.0, mid_height, midpoint_z)).rotation.y = -direction * PI * 0.5


func _build_props() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SLICE_DIR + "props.json"))
	var heights: Dictionary = config["heights_m"]
	var kinds: Dictionary = config["types_by_file"]
	for file in DirAccess.get_files_at(ART_DIR):
		if file.begins_with("prop_") and file.ends_with(".png") and file != "prop_.png":
			if not kinds.has(file):
				kinds[file] = "rock"

	var files := kinds.keys()
	files.sort()
	var art: Array[Dictionary] = []
	for file: String in files:
		var kind: String = kinds[file]
		var image := _load_art(ART_DIR + file, PROP_COLORS[kind])
		art.append({"texture": _make_texture(image), "bounds": image.get_used_rect(), "height": heights[kind]})

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for index in range(40):
		var chosen := art[rng.randi_range(0, art.size() - 1)]
		var prop := _make_billboard(chosen.texture, chosen.bounds, chosen.height, SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS)
		var bounds: Rect2i = chosen.bounds
		prop.offset.x = (prop.texture.get_width() - bounds.position.x - bounds.end.x) * 0.5
		var half_width := bounds.size.x * prop.pixel_size * 0.5
		var position := _prop_position(rng, half_width)
		prop.name = "Prop_%02d" % (index + 1)
		prop.position.x = position.x
		prop.position.z = position.y
		$Props.add_child(prop)


func _prop_position(rng: RandomNumberGenerator, half_width: float) -> Vector2:
	var min_x := maxf(2.3, ROAD_HALF_WIDTH + half_width)
	var fallback := Vector2.ZERO
	for attempt in range(256):
		var z := rng.randf_range(-90.0, 10.0)
		var direction := -1.0 if rng.randi_range(0, 1) == 0 else 1.0
		var edges := _cliff_edges[int((CLIFF_FRONT_Z - z) / CLIFF_DEPTH)]
		var edge := edges.x if direction < 0.0 else edges.y
		var max_x := minf(5.0, edge - half_width)
		if min_x <= max_x:
			return Vector2(direction * rng.randf_range(min_x, max_x), z)
		fallback = Vector2(direction * (2.3 + edge) * 0.5, z)
	push_warning("Prop art is too wide for the verge. Placing its center on sand.")
	return fallback


func _build_hero() -> void:
	var cleaned_path := ART_DIR + "hero_clean.png"
	var path := cleaned_path if FileAccess.file_exists(cleaned_path) else HERO_SOURCE
	var image := _load_art(path, Color("4a7cba"))
	var sprite := _make_billboard(_make_texture(image), image.get_used_rect(), 1.7, SpriteBase3D.ALPHA_CUT_DISCARD)
	sprite.name = "HeroSprite"
	_hero.add_child(sprite)

	# Same soft contact shadow as the original camera test.
	var shadow_image := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var center := Vector2(63.5, 63.5)
	for y in range(128):
		for x in range(128):
			var falloff := maxf(1.0 - (Vector2(x, y) - center).length() / center.x, 0.0)
			var alpha := 0.45 * falloff * falloff * (3.0 - 2.0 * falloff)
			shadow_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.albedo_texture = _make_texture(shadow_image)
	var shadow := PlaneMesh.new()
	shadow.size = Vector2(0.9, 0.45)
	shadow.material = material
	_add_mesh(_hero, "FootShadow", shadow, Vector3(0.0, 0.015, 0.0))


func _make_billboard(
	texture: Texture2D, bounds: Rect2i, height: float, alpha_cut: SpriteBase3D.AlphaCutMode
) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.shaded = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = alpha_cut
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = height / bounds.size.y
	# Sprite3D is centered on the whole file. Line up the bottom visible row with the ground.
	sprite.position.y = (bounds.end.y - texture.get_height() * 0.5) * sprite.pixel_size
	return sprite


func _surface_material(file: String, placeholder: Color, repeats: Vector2) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = true
	material.uv1_scale = Vector3(repeats.x, repeats.y, 1.0)
	material.albedo_texture = _make_texture(_load_art(ART_DIR + file, placeholder))
	return material


func _load_art(path: String, placeholder: Color) -> Image:
	var image := Image.new()
	if FileAccess.file_exists(path):
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK and image.get_used_rect().has_area():
			return image
	push_warning("Using a flat placeholder for %s" % path)
	image = Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(placeholder)
	return image


func _make_texture(image: Image) -> ImageTexture:
	if image.detect_alpha() != Image.ALPHA_NONE:
		image.fix_alpha_edges()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _add_mesh(parent: Node3D, node_name: String, mesh: Mesh, position: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	parent.add_child(node)
	return node
