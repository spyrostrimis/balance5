extends SceneTree
## Windowed Forward+ visual capture script for Approach 1 (Uncut 2D Artwork) and Approach 2 (Modular Stitched 2D Kit).
## Run non-headless:
##   C:\Godot\Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1376x768 --script res://tests/capture_rpg_2d_canyon.gd

const SCENE_PATH := "res://scenes/rpg_2d/canyon_orthographic_study.tscn"
const OUT_DIR := "res://render_captures/rpg_2d"


func _init() -> void:
	call_deferred("_run")


func _wait_frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _capture(rel_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var abs_path := ProjectSettings.globalize_path(OUT_DIR + "/" + rel_name)
	img.save_png(abs_path)
	print("Captured ", rel_name, " (", img.get_width(), "x", img.get_height(), ")")


func _pose_hero(study: Canyon2DStudy, y_pos: float, dx_offset: float, facing_vec: Vector2) -> void:
	var hero := study.hero
	var cam := study.camera
	var cx := Canyon2DStudy.get_road_center_x(study.active_approach, y_pos)
	hero.global_position = Vector2(cx + dx_offset, y_pos)
	hero.script_input_dir = facing_vec
	await physics_frame
	await physics_frame
	hero.script_input_dir = Vector2.ZERO
	await physics_frame
	await physics_frame
	cam.snap_immediately()
	await _wait_frames(4)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Failed to load " + SCENE_PATH)
		quit(1)
		return

	var study := packed.instantiate() as Canyon2DStudy
	root.add_child(study)
	await _wait_frames(4)

	var hero := study.hero
	hero.use_script_input = true
	hero.set_mode(Hero2DController.Mode.EXPLORE)

	# --- APPROACH 1: CONTINUOUS UNCUT 2D ARTWORK ---
	study.set_approach(1, false)
	study.framed_uncut_zoom = false
	study.set_resolution_preset(960, 540)

	# 1. Approach 1 - Entrance (y=1560), 960x540 1:1 Widescreen, HUD ON
	study.set_hud_visible(true)
	await _pose_hero(study, 1560.0, 0.0, Vector2(0, 1))
	await _capture("a1_01_start_960x540_hud.png")

	# 2. Approach 1 - Entrance (y=1560), 960x540 1:1 Widescreen, HUD OFF (pure art comparison)
	study.set_hud_visible(false)
	await _wait_frames(2)
	await _capture("a1_02_start_960x540_clean.png")

	# 3. Approach 1 - Mid-Canyon S-Bend (y=1010), walking North, HUD OFF
	await _pose_hero(study, 1010.0, -8.0, Vector2(0, -1))
	await _capture("a1_03_mid_canyon_north.png")

	# 4. Approach 1 - Upper Canyon Sunbeams (y=360), diagonal NE walk, HUD OFF
	await _pose_hero(study, 360.0, 6.0, Vector2(1, 1))
	await _capture("a1_04_upper_canyon_sunbeams.png")

	# 5. Approach 1 - 640x360 Live Toggle Comparison at Entrance (y=1560), HUD ON
	study.set_hud_visible(true)
	study.set_resolution_preset(640, 360)
	await _pose_hero(study, 1560.0, 0.0, Vector2(0, 1))
	await _capture("a1_05_start_640x360_toggle.png")

	# --- APPROACH 2: MODULAR STITCHED & Y-SORTED 2D KIT ---
	study.set_resolution_preset(960, 540)
	study.set_approach(2, false)

	# 6. Approach 2 - Entrance (y=1560), 960x540, HUD ON
	study.set_hud_visible(true)
	await _pose_hero(study, 1560.0, 0.0, Vector2(0, 1))
	await _capture("a2_01_start_960x540_hud.png")

	# 7. Approach 2 - Entrance (y=1560), 960x540, HUD OFF (pure art comparison)
	study.set_hud_visible(false)
	await _wait_frames(2)
	await _capture("a2_02_start_960x540_clean.png")

	# 8. Approach 2 - Mid-Canyon Ruined Archway & Carved Stone Staircase (y=1010), walking North, HUD OFF
	await _pose_hero(study, 1010.0, -10.0, Vector2(0, -1))
	await _capture("a2_03_mid_canyon_arch_stairs.png")

	# 9. Approach 2 - Upper Canyon Pass & Y-Sort Walk-Behind Boulder check (y=304, x=366 behind boulder at 336,325), HUD OFF
	await _pose_hero(study, 304.0, -144.0, Vector2(0, 1))
	await _capture("a2_04_upper_canyon_ysort_behind_boulder.png")

	# Also keep legacy capture filenames updated so any external reference points to the new build
	study.set_approach(1, false)
	study.set_hud_visible(true)
	study.set_resolution_preset(960, 540)
	await _pose_hero(study, 1560.0, 0.0, Vector2(0, 1))
	await _capture("01_start_960x540_explore.png")

	study.set_resolution_preset(640, 360)
	await _pose_hero(study, 1560.0, 0.0, Vector2(0, 1))
	await _capture("02_start_640x360_explore.png")

	study.set_resolution_preset(960, 540)
	study.set_hud_visible(false)
	await _pose_hero(study, 1010.0, 0.0, Vector2(0, -1))
	await _capture("03_mid_bend_explore_north.png")

	study.set_approach(2, false)
	study.set_hud_visible(true)
	await _pose_hero(study, 1010.0, 0.0, Vector2(0, 1))
	await _capture("04_combat_mode_shoot.png")

	study.set_hud_visible(false)
	await _pose_hero(study, 360.0, 0.0, Vector2(0, -1))
	await _capture("05_exit_overlook_960x540.png")

	study.queue_free()
	await _wait_frames(2)
	print("PASS: All Approach 1 & Approach 2 windowed captures saved.")
	quit(0)
