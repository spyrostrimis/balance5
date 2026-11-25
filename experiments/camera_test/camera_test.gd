extends Node3D

const HERO_TEXTURE_PATH := "res://assets/textures/units/blue_commander_rpg.png"
const PROP_ROCK_PATHS: Array[String] = [
	"res://assets/textures/rpg_2d/approach3/bend_rocks.png",
	"res://assets/textures/rpg_2d/approach3/lookout_boulder.png",
]

const WINDOW_SIZE := Vector2i(1280, 720)
const HERO_HEIGHT_M := 1.7
const HERO_MOVE_SPEED := 3.0
const CAMERA_TARGET_OFFSET := Vector3(0.0, 1.0, 0.0)
const CAMERA_VERTICAL_SPAN_M := 8.95

const COLOR_SAND := Color(0.84, 0.58, 0.32, 1.0)
const COLOR_ROAD := Color(0.48, 0.42, 0.37, 1.0)
const COLOR_CLIFF_A := Color(0.72, 0.35, 0.22, 1.0)
const COLOR_CLIFF_B := Color(0.62, 0.29, 0.18, 1.0)
const COLOR_SHRUB := Color(0.35, 0.44, 0.24, 1.0)

var pitch_deg: float = 30.0
var fov_deg: float = 30.0
var is_ortho: bool = false
var hero_low_offset: bool = false

var _prev_aniso := Viewport.ANISOTROPY_4X
var _capturing := false

@onready var _world_env: WorldEnvironment = $WorldEnvironment
@onready var _camera: Camera3D = $Camera3D
@onready var _hero: Node3D = $Hero
@onready var _hero_sprite: Sprite3D = $Hero/HeroSprite
@onready var _foot_shadow: MeshInstance3D = $Hero/FootShadow
@onready var _ground_root: Node3D = $GroundRoot
@onready var _cliffs_root: Node3D = $CliffsRoot
@onready var _props_root: Node3D = $PropsRoot
@onready var _hud_label: Label = $HUD/StatusLabel


func _ready() -> void:
	_setup_window_and_viewport()
	_setup_environment()
	_setup_ground_and_road()
	_setup_cliffs()
	_setup_props()
	_setup_hero()
	_setup_hud()
	_update_camera()
	_update_hud()


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.anisotropic_filtering_level = _prev_aniso


func _is_key_down(key: Key) -> bool:
	return Input.is_key_pressed(key) or Input.is_physical_key_pressed(key)


func _matches_key(key_event: InputEventKey, key: Key) -> bool:
	return key_event.keycode == key or key_event.physical_keycode == key


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if _is_key_down(KEY_W) or _is_key_down(KEY_UP):
		move.y -= 1.0
	if _is_key_down(KEY_S) or _is_key_down(KEY_DOWN):
		move.y += 1.0
	if _is_key_down(KEY_A) or _is_key_down(KEY_LEFT):
		move.x -= 1.0
	if _is_key_down(KEY_D) or _is_key_down(KEY_RIGHT):
		move.x += 1.0

	if move != Vector2.ZERO:
		move = move.normalized()
		_hero.position.x += move.x * HERO_MOVE_SPEED * delta
		_hero.position.z += move.y * HERO_MOVE_SPEED * delta
		_hero.position.y = 0.0
		if move.x < 0.0:
			_hero_sprite.flip_h = true
		elif move.x > 0.0:
			_hero_sprite.flip_h = false

	_update_camera()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if _matches_key(key_event, KEY_1) or _matches_key(key_event, KEY_KP_1):
		set_camera_settings(25.0, fov_deg, is_ortho, hero_low_offset)
	elif _matches_key(key_event, KEY_2) or _matches_key(key_event, KEY_KP_2):
		set_camera_settings(30.0, fov_deg, is_ortho, hero_low_offset)
	elif _matches_key(key_event, KEY_3) or _matches_key(key_event, KEY_KP_3):
		set_camera_settings(40.0, fov_deg, is_ortho, hero_low_offset)
	elif _matches_key(key_event, KEY_4) or _matches_key(key_event, KEY_KP_4):
		set_camera_settings(55.0, fov_deg, is_ortho, hero_low_offset)
	elif (
		_matches_key(key_event, KEY_O)
		or _matches_key(key_event, KEY_0)
		or _matches_key(key_event, KEY_KP_0)
		or _matches_key(key_event, KEY_TAB)
	):
		set_camera_settings(pitch_deg, fov_deg, not is_ortho, hero_low_offset)
		get_viewport().set_input_as_handled()
	elif _matches_key(key_event, KEY_H):
		set_camera_settings(pitch_deg, fov_deg, is_ortho, not hero_low_offset)
	elif _matches_key(key_event, KEY_F):
		var next_fov := 45.0 if is_equal_approx(fov_deg, 30.0) else 30.0
		set_camera_settings(pitch_deg, next_fov, is_ortho, hero_low_offset)
	elif _matches_key(key_event, KEY_P):
		save_screenshot()
	elif _matches_key(key_event, KEY_ESCAPE):
		get_tree().quit()


func set_camera_settings(
	new_pitch_deg: float,
	new_fov_deg: float = fov_deg,
	new_is_ortho: bool = is_ortho,
	new_hero_low_offset: bool = hero_low_offset
) -> void:
	pitch_deg = new_pitch_deg
	fov_deg = new_fov_deg
	is_ortho = new_is_ortho
	hero_low_offset = new_hero_low_offset
	_update_camera()
	_update_hud()


func save_screenshot(custom_path: String = "") -> void:
	if _capturing:
		return
	_capturing = true
	await RenderingServer.frame_post_draw
	var shots_dir := ProjectSettings.globalize_path("res://experiments/camera_test/shots")
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var out_path := custom_path
	if out_path.is_empty():
		var proj_tag := "ortho" if is_ortho else "persp"
		var offset_tag := 1 if hero_low_offset else 0
		out_path = shots_dir.path_join("%s_pitch%d_offset%d.png" % [proj_tag, int(round(pitch_deg)), offset_tag])
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out_path)
	if err == OK:
		print("Saved screenshot: ", out_path)
	else:
		push_error("Failed to save screenshot (%s): %s" % [error_string(err), out_path])
	_capturing = false


func _setup_window_and_viewport() -> void:
	var vp := get_viewport()
	if vp != null:
		_prev_aniso = vp.anisotropic_filtering_level
		vp.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
	if DisplayServer.get_name() != "headless":
		var win := get_window()
		if win != null and win.size != WINDOW_SIZE:
			win.size = WINDOW_SIZE


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.70, 0.90)
	sky_mat.sky_horizon_color = Color(0.95, 0.75, 0.55)
	sky_mat.ground_horizon_color = Color(0.95, 0.75, 0.55)
	sky_mat.ground_bottom_color = COLOR_SAND

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	_world_env.environment = env


func _make_unshaded_material(color: Color, anisotropic: bool = false, double_sided: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.texture_filter = (
		BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if anisotropic
		else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	)
	if double_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _setup_ground_and_road() -> void:
	# 400 x 400 m sand plane at y = 0, centered at z = -130 to span z in [-330, +70]
	var sand_mesh := PlaneMesh.new()
	sand_mesh.size = Vector2(400.0, 400.0)
	var sand := MeshInstance3D.new()
	sand.name = "SandPlane"
	sand.mesh = sand_mesh
	sand.material_override = _make_unshaded_material(COLOR_SAND, true)
	sand.position = Vector3(0.0, 0.0, -130.0)
	_ground_root.add_child(sand)

	# 4 m wide (x in [-2, 2]) x 300 m long road strip along -Z at y = 0.01 (z from +20 to -280)
	var road_mesh := PlaneMesh.new()
	road_mesh.size = Vector2(4.0, 300.0)
	var road := MeshInstance3D.new()
	road.name = "RoadStrip"
	road.mesh = road_mesh
	road.material_override = _make_unshaded_material(COLOR_ROAD, true)
	road.position = Vector3(0.0, 0.01, -130.0)
	_ground_root.add_child(road)


func _setup_cliffs() -> void:
	var cliff_mesh := QuadMesh.new()
	cliff_mesh.size = Vector2(8.0, 6.0)
	var mat_a := _make_unshaded_material(COLOR_CLIFF_A, false, true)
	var mat_b := _make_unshaded_material(COLOR_CLIFF_B, false, true)

	var idx := 0
	var z := 20.0
	while z >= -150.0:
		var mat := mat_a if (idx % 2 == 0) else mat_b

		# Left cliff at x = -4.5 facing +X (toward road)
		var left_card := MeshInstance3D.new()
		left_card.name = "CliffLeft_%02d" % idx
		left_card.mesh = cliff_mesh
		left_card.material_override = mat
		left_card.position = Vector3(-4.5, 3.0, z)
		left_card.rotation = Vector3(0.0, PI * 0.5, 0.0)
		_cliffs_root.add_child(left_card)

		# Right cliff at x = +4.5 facing -X (toward road)
		var right_card := MeshInstance3D.new()
		right_card.name = "CliffRight_%02d" % idx
		right_card.mesh = cliff_mesh
		right_card.material_override = mat
		right_card.position = Vector3(4.5, 3.0, z)
		right_card.rotation = Vector3(0.0, -PI * 0.5, 0.0)
		_cliffs_root.add_child(right_card)

		idx += 1
		z -= 8.0


func _make_solid_texture(color: Color) -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _setup_props() -> void:
	var rock_textures: Array[Texture2D] = []
	for path in PROP_ROCK_PATHS:
		var tex := load(path) as Texture2D
		if tex != null:
			rock_textures.append(tex)
	var shrub_tex := _make_solid_texture(COLOR_SHRUB)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	for i in range(14):
		var side := -1.0 if rng.randi_range(0, 1) == 0 else 1.0
		var x := side * rng.randf_range(2.5, 4.2)
		var z := rng.randf_range(-80.0, 10.0)
		var height_m := rng.randf_range(0.8, 1.6)
		var kind := rng.randi_range(0, rock_textures.size()) # 0..rock_count-1 = Approach3 rocks, last = shrub placeholder

		var sprite := Sprite3D.new()
		sprite.name = "Prop_%02d" % i
		sprite.shaded = false
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = 0.5
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.centered = true

		var tex: Texture2D
		if kind < rock_textures.size():
			tex = rock_textures[kind]
		else:
			tex = shrub_tex

		sprite.texture = tex
		var bounds := _find_visible_y_bounds(tex)
		var tex_h := float(tex.get_height())
		var vis_h := float(bounds.y - bounds.x + 1)
		var px_size := height_m / vis_h
		sprite.pixel_size = px_size
		var center_y := (float(bounds.y + 1) - tex_h * 0.5) * px_size
		sprite.position = Vector3(x, center_y, z)
		_props_root.add_child(sprite)


func _setup_hero() -> void:
	_hero.position = Vector3.ZERO
	var hero_tex := load(HERO_TEXTURE_PATH) as Texture2D
	assert(hero_tex != null, "Missing hero texture: " + HERO_TEXTURE_PATH)

	_hero_sprite.texture = hero_tex
	_hero_sprite.shaded = false
	_hero_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_hero_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_hero_sprite.alpha_scissor_threshold = 0.5
	_hero_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_hero_sprite.centered = true

	var bounds := _find_visible_y_bounds(hero_tex)
	var tex_h := float(hero_tex.get_height())
	var vis_h := float(bounds.y - bounds.x + 1)
	var px_size := HERO_HEIGHT_M / vis_h
	_hero_sprite.pixel_size = px_size
	# Place bottom edge of visible pixels (row bounds.y + 1) exactly on y = 0.
	_hero_sprite.position = Vector3(0.0, (float(bounds.y + 1) - tex_h * 0.5) * px_size, 0.0)

	# Soft dark radial-gradient ellipse under her feet (0.9 m x 0.45 m, black at 45% opacity)
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(0.9, 0.45)
	_foot_shadow.mesh = shadow_mesh
	_foot_shadow.position = Vector3(0.0, 0.015, 0.0)

	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	shadow_mat.albedo_texture = _make_radial_shadow_texture(128, 0.45)
	shadow_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_foot_shadow.material_override = shadow_mat


func _make_radial_shadow_texture(size: int, peak_alpha: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := (float(size) - 1.0) * 0.5
	for y in range(size):
		for x in range(size):
			var nx := (float(x) - half) / half
			var ny := (float(y) - half) / half
			var r := sqrt(nx * nx + ny * ny)
			var falloff := clampf(1.0 - r, 0.0, 1.0)
			# Smooth radial curve peaking at peak_alpha in the center and 0 at the ellipse rim.
			var a := peak_alpha * falloff * falloff * (3.0 - 2.0 * falloff)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _find_visible_y_bounds(tex: Texture2D, alpha_threshold: float = 0.5) -> Vector2i:
	var h := tex.get_height()
	var w := tex.get_width()
	var img := tex.get_image()
	if img == null:
		return Vector2i(0, h - 1)
	if img.is_compressed():
		img.decompress()
	var min_y := h
	var max_y := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a >= alpha_threshold:
				if y < min_y:
					min_y = y
				if y > max_y:
					max_y = y
				break
	if max_y < min_y:
		return Vector2i(0, h - 1)
	return Vector2i(min_y, max_y)


func _setup_hud() -> void:
	_hud_label.position = Vector2(12.0, 10.0)
	_hud_label.add_theme_font_size_override("font_size", 20)
	_hud_label.add_theme_color_override("font_color", Color.WHITE)
	_hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_label.add_theme_constant_override("outline_size", 4)


func _update_camera() -> void:
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	if is_ortho:
		_camera.set_orthogonal(CAMERA_VERTICAL_SPAN_M, 0.05, 500.0)
	else:
		_camera.set_perspective(fov_deg, 0.05, 1000.0)

	var fov_rad := deg_to_rad(fov_deg)
	var pitch_rad := deg_to_rad(pitch_deg)
	var d := CAMERA_VERTICAL_SPAN_M / (2.0 * tan(fov_rad * 0.5))

	var target := _hero.global_position + CAMERA_TARGET_OFFSET
	if hero_low_offset:
		target.z -= 0.2 * CAMERA_VERTICAL_SPAN_M / sin(pitch_rad)
	var cam_pos := target + d * Vector3(0.0, sin(pitch_rad), cos(pitch_rad))
	_camera.global_position = cam_pos
	_camera.look_at(target, Vector3.UP)


func _update_hud() -> void:
	var proj_tag := "ortho" if is_ortho else "persp"
	var offset_tag := "on" if hero_low_offset else "off"
	_hud_label.text = "%s  pitch %d  offset %s  fov %d" % [
		proj_tag,
		int(round(pitch_deg)),
		offset_tag,
		int(round(fov_deg)),
	]
