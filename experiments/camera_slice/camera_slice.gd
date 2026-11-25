extends Node3D

const SLICE_ROOT := "res://experiments/camera_slice"
const ASSETS_DIR := "res://experiments/camera_slice/assets"
const SHOTS_DIR := "res://experiments/camera_slice/shots"
const PROPS_JSON_PATH := "res://experiments/camera_slice/props.json"
const CAMERA_PROFILES_JSON_PATH := "res://experiments/camera_slice/camera_profiles.json"

const HERO_CLEAN_PATH := "res://experiments/camera_slice/assets/hero_clean.png"
const HERO_FALLBACK_PATH := "res://assets/textures/units/blue_commander_rpg.png"

const WINDOW_SIZE := Vector2i(1280, 720)
const HERO_HEIGHT_M := 1.7
const HERO_MOVE_SPEED := 3.0

const GROUND_SIZE_M := 300.0
const GROUND_TILE_M := 4.0
const ROAD_WIDTH_M := 4.0
const ROAD_LENGTH_M := 300.0
const ROAD_TILE_M := 4.0
const ROAD_Y := 0.01
# Center the 300 m strip at z = -120 so it spans z in [-270, +30] (covers cliffs at +20..-90 and horizon).
const WORLD_CENTER_Z := -120.0

const CLIFF_WIDTH_M := 8.0
const CLIFF_DEPTH_M := 5.0
const CLIFF_HEIGHT_M := 6.0
const CLIFF_FRONT_TEX_W_M := 8.0
const CLIFF_FRONT_TEX_H_M := 6.0
const CLIFF_TOP_TEX_W_M := 8.0
const CLIFF_TOP_TEX_D_M := 4.0
const CLIFF_Z_START := 20.0
const CLIFF_Z_END := -90.0
const CLIFF_Z_STEP := 5.0
const CLIFF_INNER_BASE_X := 2.5
const CLIFF_INNER_JITTER_MAX := 1.5
const CLIFF_SEED := 42

const PROP_COUNT := 40
const PROP_X_MIN := 2.3
const PROP_X_MAX := 5.0
const PROP_Z_MAX := 10.0
const PROP_Z_MIN := -90.0
const PROP_SEED := 42

const PLACEHOLDER_SAND := Color(0.84, 0.58, 0.32, 1.0)
const PLACEHOLDER_ROAD := Color(0.48, 0.42, 0.37, 1.0)
const PLACEHOLDER_CLIFF_FRONT := Color(0.72, 0.35, 0.22, 1.0)
const PLACEHOLDER_CLIFF_TOP := Color(0.65, 0.31, 0.19, 1.0)
const PLACEHOLDER_PROP := Color(0.35, 0.44, 0.24, 1.0)
const PLACEHOLDER_HERO := Color(0.20, 0.45, 0.85, 1.0)

var _camera_profiles: Dictionary = {}
var _vertical_span_m: float = 8.95
var _target_offset: Vector3 = Vector3(0.0, 1.0, 0.0)
var _active_profile: String = "A"
var _pitch_deg: float = 25.0
var _fov_deg: float = 30.0

var _cliff_inner_left: Dictionary = {}
var _cliff_inner_right: Dictionary = {}
var _found_assets: Array[String] = []
var _placeholder_assets: Array[String] = []

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
	_load_camera_profiles()
	_setup_ground_and_road()
	_setup_cliffs()
	_setup_props()
	_setup_hero()
	_setup_hud()
	_apply_profile(_active_profile)

	print("[camera_slice] Found assets (%d): %s" % [_found_assets.size(), ", ".join(_found_assets)])
	if not _placeholder_assets.is_empty():
		print("[camera_slice] Placeholders (%d): %s" % [_placeholder_assets.size(), ", ".join(_placeholder_assets)])

	if _has_user_arg("--capture-all"):
		call_deferred("_run_capture_all")


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.anisotropic_filtering_level = _prev_aniso


func _has_user_arg(flag: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == flag:
			return true
	return false


func _run_capture_all() -> void:
	for profile_id in ["A", "B"]:
		_apply_profile(profile_id)
		# Wait 3 frames so the viewport and HUD label fully settle before grabbing pixels.
		for _i in range(3):
			await get_tree().process_frame
		await save_screenshot()
	get_tree().quit()


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
		_apply_profile("A")
	elif _matches_key(key_event, KEY_2) or _matches_key(key_event, KEY_KP_2):
		_apply_profile("B")
	elif _matches_key(key_event, KEY_P):
		save_screenshot()
	elif _matches_key(key_event, KEY_ESCAPE):
		get_tree().quit()


func save_screenshot(custom_path: String = "") -> void:
	if _capturing:
		return
	_capturing = true
	await RenderingServer.frame_post_draw
	var shots_dir := ProjectSettings.globalize_path(SHOTS_DIR)
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var out_path := custom_path
	if out_path.is_empty():
		out_path = shots_dir.path_join("%s.png" % _active_profile)
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out_path)
	if err == OK:
		print("[camera_slice] Saved screenshot: ", out_path)
	else:
		push_error("[camera_slice] Failed to save screenshot (%s): %s" % [error_string(err), out_path])
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
	sky_mat.ground_bottom_color = PLACEHOLDER_SAND

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	_world_env.environment = env


func _read_json_file(res_path: String) -> Variant:
	if not FileAccess.file_exists(res_path):
		push_warning("[camera_slice] Missing JSON config: %s" % res_path)
		return null
	var text := FileAccess.get_file_as_string(res_path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_warning("[camera_slice] Failed to parse JSON: %s" % res_path)
	return parsed


func _load_camera_profiles() -> void:
	# Fallback defaults matching spec exactly in case JSON is absent.
	_camera_profiles = {
		"A": {"pitch_deg": 25.0, "fov_deg": 30.0},
		"B": {"pitch_deg": 30.0, "fov_deg": 45.0},
	}
	_active_profile = "A"

	var data: Variant = _read_json_file(CAMERA_PROFILES_JSON_PATH)
	if not (data is Dictionary):
		return
	var dict := data as Dictionary
	if dict.has("vertical_span_m"):
		_vertical_span_m = float(dict["vertical_span_m"])
	if dict.has("target_offset") and dict["target_offset"] is Array:
		var arr := dict["target_offset"] as Array
		if arr.size() >= 3:
			_target_offset = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	if dict.has("profiles") and dict["profiles"] is Dictionary:
		_camera_profiles = (dict["profiles"] as Dictionary).duplicate(true)
	if dict.has("default"):
		_active_profile = str(dict["default"])


func _apply_profile(profile_id: String) -> void:
	if not _camera_profiles.has(profile_id):
		return
	var prof := _camera_profiles[profile_id] as Dictionary
	_active_profile = profile_id
	_pitch_deg = float(prof.get("pitch_deg", 25.0))
	_fov_deg = float(prof.get("fov_deg", 30.0))
	_update_camera()
	_update_hud()


func _load_texture_mipmapped(res_path: String, label: String) -> Texture2D:
	var abs_path := ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		_placeholder_assets.append(label)
		return null
	var img := Image.load_from_file(abs_path)
	if img == null or img.is_empty():
		_placeholder_assets.append(label)
		return null
	if not img.has_mipmaps():
		img.generate_mipmaps()
	_found_assets.append(label)
	return ImageTexture.create_from_image(img)


func _make_solid_texture(color: Color) -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _make_unshaded_material(
	tex: Texture2D,
	fallback_color: Color,
	uv_scale: Vector3 = Vector3.ONE,
	anisotropic: bool = true,
	repeat: bool = true
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_repeat = repeat
	mat.texture_filter = (
		BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if anisotropic
		else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	)
	mat.uv1_scale = uv_scale
	if tex != null:
		mat.albedo_color = Color.WHITE
		mat.albedo_texture = tex
	else:
		mat.albedo_color = fallback_color
	return mat


func _setup_ground_and_road() -> void:
	var sand_tex := _load_texture_mipmapped(ASSETS_DIR.path_join("sand_topdown.png"), "sand_topdown.png")
	var road_tex := _load_texture_mipmapped(ASSETS_DIR.path_join("road_topdown.png"), "road_topdown.png")

	# 300 x 300 m sand plane at y = 0, tiled every 4 x 4 m.
	var sand_mesh := PlaneMesh.new()
	sand_mesh.size = Vector2(GROUND_SIZE_M, GROUND_SIZE_M)
	var sand := MeshInstance3D.new()
	sand.name = "SandPlane"
	sand.mesh = sand_mesh
	var sand_uv := Vector3(GROUND_SIZE_M / GROUND_TILE_M, GROUND_SIZE_M / GROUND_TILE_M, 1.0)
	sand.material_override = _make_unshaded_material(sand_tex, PLACEHOLDER_SAND, sand_uv, true, true)
	sand.position = Vector3(0.0, 0.0, WORLD_CENTER_Z)
	_ground_root.add_child(sand)

	# 4 m wide (x in [-2, 2]) x 300 m long road strip along -Z at y = 0.01, tiled every 4 m.
	var road_mesh := PlaneMesh.new()
	road_mesh.size = Vector2(ROAD_WIDTH_M, ROAD_LENGTH_M)
	var road := MeshInstance3D.new()
	road.name = "RoadStrip"
	road.mesh = road_mesh
	var road_uv := Vector3(ROAD_WIDTH_M / ROAD_TILE_M, ROAD_LENGTH_M / ROAD_TILE_M, 1.0)
	road.material_override = _make_unshaded_material(road_tex, PLACEHOLDER_ROAD, road_uv, true, true)
	road.position = Vector3(0.0, ROAD_Y, WORLD_CENTER_Z)
	_ground_root.add_child(road)


func _create_cliff_block(
	side: int,
	front_mesh: QuadMesh,
	top_mesh: QuadMesh,
	side_mesh: QuadMesh,
	mat_front: StandardMaterial3D,
	mat_top: StandardMaterial3D,
	mat_side: StandardMaterial3D
) -> Node3D:
	# Box: 8 m wide (x), 5 m deep (z), 6 m tall (y), local origin centered in X/Z with base at y = 0.
	var block := Node3D.new()

	# Front face (+Z): 8 m wide x 6 m tall, facing camera (+Z).
	var front := MeshInstance3D.new()
	front.name = "FrontFace"
	front.mesh = front_mesh
	front.material_override = mat_front
	front.position = Vector3(0.0, CLIFF_HEIGHT_M * 0.5, CLIFF_DEPTH_M * 0.5)
	block.add_child(front)

	# Top face (+Y): 8 m wide x 5 m deep, facing up (+Y).
	var top := MeshInstance3D.new()
	top.name = "TopFace"
	top.mesh = top_mesh
	top.material_override = mat_top
	top.position = Vector3(0.0, CLIFF_HEIGHT_M, 0.0)
	top.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	block.add_child(top)

	# Inner side face (toward road): 5 m deep x 6 m tall.
	var inner := MeshInstance3D.new()
	inner.name = "InnerSideFace"
	inner.mesh = side_mesh
	inner.material_override = mat_side
	if side < 0:
		# Left cliff: inner face at +4 m facing +X (toward road).
		inner.position = Vector3(CLIFF_WIDTH_M * 0.5, CLIFF_HEIGHT_M * 0.5, 0.0)
		inner.rotation = Vector3(0.0, PI * 0.5, 0.0)
	else:
		# Right cliff: inner face at -4 m facing -X (toward road).
		inner.position = Vector3(-CLIFF_WIDTH_M * 0.5, CLIFF_HEIGHT_M * 0.5, 0.0)
		inner.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	block.add_child(inner)

	return block


func _setup_cliffs() -> void:
	var front_tex := _load_texture_mipmapped(ASSETS_DIR.path_join("cliff_front.png"), "cliff_front.png")
	var top_tex := _load_texture_mipmapped(ASSETS_DIR.path_join("cliff_top.png"), "cliff_top.png")

	var front_mesh := QuadMesh.new()
	front_mesh.size = Vector2(CLIFF_WIDTH_M, CLIFF_HEIGHT_M)

	var top_mesh := QuadMesh.new()
	top_mesh.size = Vector2(CLIFF_WIDTH_M, CLIFF_DEPTH_M)

	var side_mesh := QuadMesh.new()
	side_mesh.size = Vector2(CLIFF_DEPTH_M, CLIFF_HEIGHT_M)

	# Map 1 m of texture to 1 m of surface on every face:
	# - Front (8x6 m) with cliff_front (8x6 m) -> uv scale (1.0, 1.0)
	# - Top   (8x5 m) with cliff_top   (8x4 m) -> uv scale (1.0, 1.25)
	# - Inner (5x6 m) with cliff_front (8x6 m) -> uv scale (0.625, 1.0)
	var mat_front := _make_unshaded_material(
		front_tex,
		PLACEHOLDER_CLIFF_FRONT,
		Vector3(CLIFF_WIDTH_M / CLIFF_FRONT_TEX_W_M, CLIFF_HEIGHT_M / CLIFF_FRONT_TEX_H_M, 1.0),
		true,
		true
	)
	var mat_top := _make_unshaded_material(
		top_tex,
		PLACEHOLDER_CLIFF_TOP,
		Vector3(CLIFF_WIDTH_M / CLIFF_TOP_TEX_W_M, CLIFF_DEPTH_M / CLIFF_TOP_TEX_D_M, 1.0),
		true,
		true
	)
	var mat_side := _make_unshaded_material(
		front_tex,
		PLACEHOLDER_CLIFF_FRONT,
		Vector3(CLIFF_DEPTH_M / CLIFF_FRONT_TEX_W_M, CLIFF_HEIGHT_M / CLIFF_FRONT_TEX_H_M, 1.0),
		true,
		true
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = CLIFF_SEED

	var idx := 0
	var z := CLIFF_Z_START
	while z >= CLIFF_Z_END - 0.001:
		var z_key := int(round(z))

		# Left side (-X): inner face at -(2.5 + jitter 0..1.5 m), block center shifted left by half width (4 m).
		var inner_l := CLIFF_INNER_BASE_X + rng.randf_range(0.0, CLIFF_INNER_JITTER_MAX)
		_cliff_inner_left[z_key] = inner_l
		var left_block := _create_cliff_block(-1, front_mesh, top_mesh, side_mesh, mat_front, mat_top, mat_side)
		left_block.name = "CliffLeft_%02d" % idx
		left_block.position = Vector3(-(inner_l + CLIFF_WIDTH_M * 0.5), 0.0, z)
		_cliffs_root.add_child(left_block)

		# Right side (+X): inner face at +(2.5 + jitter 0..1.5 m), block center shifted right by half width (4 m).
		var inner_r := CLIFF_INNER_BASE_X + rng.randf_range(0.0, CLIFF_INNER_JITTER_MAX)
		_cliff_inner_right[z_key] = inner_r
		var right_block := _create_cliff_block(1, front_mesh, top_mesh, side_mesh, mat_front, mat_top, mat_side)
		right_block.name = "CliffRight_%02d" % idx
		right_block.position = Vector3(inner_r + CLIFF_WIDTH_M * 0.5, 0.0, z)
		_cliffs_root.add_child(right_block)

		idx += 1
		z -= CLIFF_Z_STEP


func _get_cliff_inner_abs_x(side: int, z: float) -> float:
	# Each block spans [z_center - 2.5, z_center + 2.5]; snap z to nearest 5 m band.
	var z_key := int(round(z / CLIFF_Z_STEP)) * int(CLIFF_Z_STEP)
	if side < 0 and _cliff_inner_left.has(z_key):
		return float(_cliff_inner_left[z_key])
	if side > 0 and _cliff_inner_right.has(z_key):
		return float(_cliff_inner_right[z_key])
	return PROP_X_MAX


func _discover_prop_files() -> Array[String]:
	var files: Array[String] = []
	var abs_dir := ProjectSettings.globalize_path(ASSETS_DIR)
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return files
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			# Match cut-out prop_*.png files while excluding raw source sheet "prop_.png".
			if fname.begins_with("prop_") and fname.ends_with(".png") and fname != "prop_.png":
				files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files


func _load_prop_heights() -> Dictionary:
	var heights: Dictionary = {"_default": 0.9}
	var data: Variant = _read_json_file(PROPS_JSON_PATH)
	if not (data is Dictionary):
		return heights
	var dict := data as Dictionary
	if dict.has("default_height_m"):
		heights["_default"] = float(dict["default_height_m"])
	var cats: Dictionary = dict.get("categories", {}) as Dictionary
	var props_map: Dictionary = dict.get("props", {}) as Dictionary
	for fname in props_map.keys():
		var entry: Variant = props_map[fname]
		if entry is Dictionary:
			var ed := entry as Dictionary
			if ed.has("height_m"):
				heights[str(fname)] = float(ed["height_m"])
			elif ed.has("category") and cats.has(ed["category"]):
				heights[str(fname)] = float(cats[ed["category"]])
		elif entry is float or entry is int:
			heights[str(fname)] = float(entry)
	return heights


func _setup_props() -> void:
	var prop_heights := _load_prop_heights()
	var prop_files := _discover_prop_files()

	var catalog: Array[Dictionary] = []
	for fname in prop_files:
		var tex := _load_texture_mipmapped(ASSETS_DIR.path_join(fname), fname)
		if tex != null:
			var bounds := _find_visible_y_bounds(tex, 0.5)
			catalog.append({
				"name": fname,
				"texture": tex,
				"height_m": float(prop_heights.get(fname, prop_heights["_default"])),
				"bounds": bounds,
			})

	if catalog.is_empty():
		_placeholder_assets.append("prop_*.png")
		var fallback_tex := _make_solid_texture(PLACEHOLDER_PROP)
		catalog.append({
			"name": "placeholder_prop",
			"texture": fallback_tex,
			"height_m": 0.9,
			"bounds": Vector2i(0, fallback_tex.get_height() - 1),
		})

	var rng := RandomNumberGenerator.new()
	rng.seed = PROP_SEED

	for i in range(PROP_COUNT):
		var side := -1 if rng.randi_range(0, 1) == 0 else 1
		var z := rng.randf_range(PROP_Z_MIN, PROP_Z_MAX)
		var abs_x := rng.randf_range(PROP_X_MIN, PROP_X_MAX)

		# Keep props on visible sand in front of each Z-band's jittered cliff face while staying strictly in [2.3, 5.0].
		var cliff_inner := _get_cliff_inner_abs_x(side, z)
		var attempts := 0
		while abs_x > cliff_inner - 0.15 and attempts < 24:
			z = rng.randf_range(PROP_Z_MIN, PROP_Z_MAX)
			abs_x = rng.randf_range(PROP_X_MIN, PROP_X_MAX)
			cliff_inner = _get_cliff_inner_abs_x(side, z)
			attempts += 1
		if abs_x > cliff_inner - 0.10:
			abs_x = maxf(PROP_X_MIN, cliff_inner - 0.15)

		var x := float(side) * abs_x
		var item := catalog[rng.randi_range(0, catalog.size() - 1)]
		var tex: Texture2D = item["texture"]
		var height_m: float = item["height_m"]
		var bounds: Vector2i = item["bounds"]

		var sprite := Sprite3D.new()
		sprite.name = "Prop_%02d" % i
		sprite.shaded = false
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		sprite.centered = true
		sprite.flip_h = rng.randi_range(0, 1) == 1
		sprite.texture = tex

		var tex_h := float(tex.get_height())
		var vis_h := float(bounds.y - bounds.x + 1)
		var px_size := height_m / vis_h
		sprite.pixel_size = px_size
		var center_y := (float(bounds.y + 1) - tex_h * 0.5) * px_size
		sprite.position = Vector3(x, center_y, z)
		_props_root.add_child(sprite)


func _setup_hero() -> void:
	_hero.position = Vector3.ZERO
	var hero_tex: Texture2D = null
	var clean_abs := ProjectSettings.globalize_path(HERO_CLEAN_PATH)
	if FileAccess.file_exists(clean_abs):
		hero_tex = _load_texture_mipmapped(HERO_CLEAN_PATH, "hero_clean.png")
	else:
		hero_tex = _load_texture_mipmapped(HERO_FALLBACK_PATH, "blue_commander_rpg.png")

	if hero_tex == null:
		hero_tex = _make_solid_texture(PLACEHOLDER_HERO)

	_hero_sprite.texture = hero_tex
	_hero_sprite.shaded = false
	_hero_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_hero_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_hero_sprite.alpha_scissor_threshold = 0.5
	_hero_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_hero_sprite.centered = true

	var bounds := _find_visible_y_bounds(hero_tex, 0.5)
	var tex_h := float(hero_tex.get_height())
	var vis_h := float(bounds.y - bounds.x + 1)
	var px_size := HERO_HEIGHT_M / vis_h
	_hero_sprite.pixel_size = px_size
	# Place bottom edge of visible pixels (row bounds.y + 1) squarely on y = 0.
	_hero_sprite.position = Vector3(0.0, (float(bounds.y + 1) - tex_h * 0.5) * px_size, 0.0)

	# Soft dark radial-gradient ellipse under her feet (exact match to camera_test: 0.9 x 0.45 m, 45% peak opacity).
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
	_camera.set_perspective(_fov_deg, 0.05, 1000.0)

	var fov_rad := deg_to_rad(_fov_deg)
	var pitch_rad := deg_to_rad(_pitch_deg)
	var d := _vertical_span_m / (2.0 * tan(fov_rad * 0.5))

	var target := _hero.global_position + _target_offset
	var cam_pos := target + d * Vector3(0.0, sin(pitch_rad), cos(pitch_rad))
	_camera.global_position = cam_pos
	_camera.look_at(target, Vector3.UP)


func _update_hud() -> void:
	_hud_label.text = "%s pitch %d fov %d" % [
		_active_profile,
		int(round(_pitch_deg)),
		int(round(_fov_deg)),
	]
