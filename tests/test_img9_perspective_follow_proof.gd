extends SceneTree
## Windowed Forward+ proof-of-concept test & capture script for Image 9 2.5D Perspective Follow.
## Run non-headless:
##   C:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/test_img9_perspective_follow_proof.gd

const SCENE_PATH := "res://scenes/rpg_2d/img9_perspective_follow_proof.tscn"
const REF_IMG_PATH := "res://assets/textures/rpg_2d/img9_perspective/img9_ref_960x540.png"
const OUT_DIR := "res://render_captures/img9_perspective_proof"


func _init() -> void:
	call_deferred("_run")


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _capture_window(file_name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var abs_path := ProjectSettings.globalize_path(OUT_DIR + "/" + file_name)
	img.save_png(abs_path)
	print("Captured ", file_name, " (", img.get_width(), "x", img.get_height(), ")")
	return img


func _save_side_by_side(sub_img: Image, file_name: String) -> void:
	var ref_tex := load(REF_IMG_PATH) as Texture2D
	if ref_tex == null:
		push_warning("Could not load reference image for side-by-side comparison.")
		return
	var ref_img := ref_tex.get_image()
	if ref_img.get_format() != Image.FORMAT_RGBA8:
		ref_img.convert(Image.FORMAT_RGBA8)
	var live_img := sub_img.duplicate() as Image
	if live_img.get_format() != Image.FORMAT_RGBA8:
		live_img.convert(Image.FORMAT_RGBA8)
	if live_img.get_size() != Vector2i(960, 540):
		live_img.resize(960, 540, Image.INTERPOLATE_NEAREST)

	var combined := Image.create(1920, 540, false, Image.FORMAT_RGBA8)
	combined.blit_rect(ref_img, Rect2i(0, 0, 960, 540), Vector2i(0, 0))
	combined.blit_rect(live_img, Rect2i(0, 0, 960, 540), Vector2i(960, 0))
	var abs_path := ProjectSettings.globalize_path(OUT_DIR + "/" + file_name)
	combined.save_png(abs_path)
	print("Saved side-by-side comparison: ", file_name, " (1920x540)")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Failed to load " + SCENE_PATH)
		quit(1)
		return

	var proof := packed.instantiate() as Img9PerspectiveFollow
	root.add_child(proof)
	await _wait_frames(5)

	# --- 1. Spawn (distance = 0, 960x540) ---
	proof.set_resolution_preset(960, 540)
	proof.set_leeway_enabled(false)
	proof.set_reference_overlay(false)
	proof.set_hud_visible(true)
	proof.set_walk_position(24.0, 0.0, true, Vector2.DOWN)
	await _wait_frames(4)
	await _capture_window("01_spawn_960x540.png")

	# Capture raw SubViewport for exact 1:1 side-by-side with untouched 960x540 Image 9
	await RenderingServer.frame_post_draw
	var sub_spawn := proof.world_viewport.get_texture().get_image()
	_save_side_by_side(sub_spawn, "01b_spawn_vs_img9_sidebyside.png")

	var spawn_boots := Img9PerspectiveFollow.project_point(proof.hero_ground, proof.camera_distance, proof.camera_center)
	print("CHECK Spawn: ground=", proof.hero_ground, " cam_d=", proof.camera_distance, " boots=", spawn_boots, " horizon_y=", proof.horizon_sprite.position.y)
	assert(absf(spawn_boots.y - 320.0) < 0.5, "Spawn boots Y must stay pinned near 320")

	# --- 2. Mid-bend uphill (distance = 220, camera following hero around first curve) ---
	proof.set_walk_position(0.0, 220.0, true, Vector2.UP)
	await _wait_frames(4)
	await _capture_window("02_mid_bend_uphill.png")
	var mid_boots := Img9PerspectiveFollow.project_point(proof.hero_ground, proof.camera_distance, proof.camera_center)
	print("CHECK Mid-bend: ground=", proof.hero_ground, " cam_d=", proof.camera_distance, " cam_cx=", proof.camera_center, " boots=", mid_boots)
	assert(absf(mid_boots.y - 320.0) < 0.5, "Mid-bend boots Y must stay locked near 320")

	# --- 3. Upper canyon uphill (distance = 420, approaching sunlit gap) ---
	proof.set_walk_position(0.0, 420.0, true, Vector2.UP)
	await _wait_frames(4)
	await _capture_window("03_upper_canyon_uphill.png")
	var upper_boots := Img9PerspectiveFollow.project_point(proof.hero_ground, proof.camera_distance, proof.camera_center)
	print("CHECK Upper canyon: ground=", proof.hero_ground, " cam_d=", proof.camera_distance, " cam_cx=", proof.camera_center, " boots=", upper_boots)
	assert(absf(upper_boots.y - 320.0) < 0.5, "Upper canyon boots Y must stay locked near 320")

	# --- Verify optional 8px leeway band ---
	proof.set_walk_position(0.0, 120.0, true, Vector2.UP)
	proof.set_leeway_enabled(true)
	proof.set_walk_position(0.0, 126.0, false, Vector2.UP)
	var leeway_boots := Img9PerspectiveFollow.project_point(proof.hero_ground, proof.camera_distance, proof.camera_center)
	print("CHECK Leeway: cam_d=", proof.camera_distance, " hero_d=", proof.hero_ground.y, " boots_y=", leeway_boots.y)
	assert(leeway_boots.y >= 311.5 and leeway_boots.y <= 328.5, "Leeway boots Y should stay within 8px band")
	proof.set_leeway_enabled(false)

	# --- Verify F2 Reference Overlay toggle ---
	proof.set_reference_overlay(true)
	assert(proof.reference_overlay.visible, "F2 reference overlay should become visible")
	proof.set_reference_overlay(false)
	assert(not proof.reference_overlay.visible, "F2 reference overlay should hide cleanly")

	# --- 4. Live 640x360 toggle at spawn ---
	proof.set_walk_position(24.0, 0.0, true, Vector2.DOWN)
	proof.set_resolution_preset(640, 360)
	await _wait_frames(4)
	assert(proof.world_viewport.size == Vector2i(640, 360), "WorldViewport must switch to 640x360")
	await _capture_window("04_spawn_640x360.png")

	proof.queue_free()
	await _wait_frames(2)
	print("PASS: All 4 Image-9 2.5D perspective follow captures and checks succeeded.")
	quit(0)
