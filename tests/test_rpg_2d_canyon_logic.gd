extends SceneTree
## Headless logic verification for Approach 1 (Uncut 2D Artwork) and Approach 2 (Modular Stitched 2D Kit).
## Run: C:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_rpg_2d_canyon_logic.gd

const SCENE_STUDY := "res://scenes/rpg_2d/canyon_orthographic_study.tscn"
const SCENE_A1 := "res://scenes/rpg_2d/canyon_approach1_uncut.tscn"
const SCENE_A2 := "res://scenes/rpg_2d/canyon_approach2_modular.tscn"

var _failed := false


func _assert_true(cond: bool, msg: String) -> void:
	if not cond:
		push_error("ASSERT FAILED: " + msg)
		_failed = true
	else:
		print("  OK: ", msg)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for sp in [SCENE_STUDY, SCENE_A1, SCENE_A2]:
		var p := load(sp) as PackedScene
		_assert_true(p != null, "Scene loads cleanly: " + sp)
		if p == null:
			quit(1)
			return

	var packed := load(SCENE_STUDY) as PackedScene
	var study := packed.instantiate() as Canyon2DStudy
	_assert_true(study != null, "Root instantiates as Canyon2DStudy")
	root.add_child(study)
	await process_frame
	await physics_frame

	var vp := study.world_viewport
	var hero := study.hero
	var cam := study.camera

	_assert_true(vp != null and hero != null and cam != null, "Core scene nodes exist")
	_assert_true(study.active_approach == 1 and study.a1_ground.visible and not study.a2_ground.visible, "Default approach is Approach 1 (Uncut 2D Artwork)")

	# 1. Resolution toggle test (960x540 <-> 640x360) and framing zoom (Z)
	_assert_true(vp.size == Vector2i(960, 540), "Default viewport is 960x540")
	study.set_resolution_preset(640, 360)
	await process_frame
	_assert_true(vp.size == Vector2i(640, 360), "Viewport switches to 640x360")
	_assert_true(is_equal_approx(cam.zoom.x, 640.0 / 960.0), "Camera zoom matches framing at 640x360")
	study.set_resolution_preset(960, 540)
	await process_frame
	_assert_true(vp.size == Vector2i(960, 540) and is_equal_approx(cam.zoom.x, 1.0), "Viewport switches back to 960x540 (zoom=1)")

	# 2. Explore Mode: 8-way facing & constant hero scale across vertical travel
	hero.use_script_input = true
	hero.set_mode(Hero2DController.Mode.EXPLORE)
	var cases := [
		[Vector2(0, -1), "N"],
		[Vector2(1, -1), "NE"],
		[Vector2(1, 0), "E"],
		[Vector2(1, 1), "SE"],
		[Vector2(0, 1), "S"],
		[Vector2(-1, 1), "SW"],
		[Vector2(-1, 0), "W"],
		[Vector2(-1, -1), "NW"],
	]
	for item in cases:
		hero.script_input_dir = item[0]
		await physics_frame
		await physics_frame
		_assert_true(hero.get_facing_label() == item[1], "Explore 8-way facing -> " + item[1] + " (got " + hero.get_facing_label() + ")")

	# Walk north along the road and verify camera follows and hero scale stays 100% constant
	study.reset_hero_position(1600.0)
	var scale_start := hero.scale
	var cam_y_start := cam.global_position.y
	hero.script_input_dir = Vector2(0, -1)
	for _i in range(60):
		await physics_frame
		await process_frame
	hero.script_input_dir = Vector2.ZERO
	_assert_true(hero.global_position.y < 1500.0 and cam.global_position.y < cam_y_start - 50.0, "Locked camera smoothly follows hero northward")
	_assert_true(hero.scale.is_equal_approx(scale_start), "Hero scale stays 100% constant during vertical travel")

	# 3. Approach 1 collision check: push West hard into left canyon terrace wall
	hero.script_input_dir = Vector2.ZERO
	study.reset_hero_position(1400.0)
	hero.script_input_dir = Vector2(-1, 0)
	for _i in range(140):
		await physics_frame
	var a1_stop_x := hero.global_position.x
	for _i in range(20):
		await physics_frame
	_assert_true(absf(hero.global_position.x - a1_stop_x) < 1.5 and a1_stop_x > 180.0, "Approach 1 left canyon wall stops hero cleanly (x=%.1f)" % a1_stop_x)

	# 4. Live toggle to Approach 2 (Modular Stitched 2D Kit) and verify visibility, road alignment & collision
	hero.script_input_dir = Vector2.ZERO
	study.reset_hero_position(1200.0)
	study.toggle_approach()
	await physics_frame
	_assert_true(study.active_approach == 2 and study.a2_ground.visible and not study.a1_ground.visible, "Live toggle switches to Approach 2 (Modular Stitched 2D Kit)")
	var expected_a2_cx := Canyon2DStudy.get_road_center_x(2, 1200.0)
	_assert_true(absf(hero.global_position.x - expected_a2_cx) < 2.0, "Hero road offset preserved on Approach 1 -> Approach 2 toggle")

	hero.script_input_dir = Vector2(1, 0)
	for _i in range(140):
		await physics_frame
	var a2_stop_x := hero.global_position.x
	for _i in range(20):
		await physics_frame
	_assert_true(absf(hero.global_position.x - a2_stop_x) < 1.5 and a2_stop_x < 790.0, "Approach 2 right canyon wall stops hero cleanly (x=%.1f)" % a2_stop_x)

	study.queue_free()
	await process_frame

	# 5. Developers Page check: verify opening_screen.tscn registers the 2D study cleanly
	var opening_packed := load("res://scenes/ui/opening_screen.tscn") as PackedScene
	_assert_true(opening_packed != null, "Opening screen loads cleanly")
	if opening_packed != null:
		var opening := opening_packed.instantiate()
		var found_entry := false
		for b in opening.get("builds"):
			if b != null and b.get("scene_path") == SCENE_STUDY and b.call("is_available"):
				found_entry = true
				break
		_assert_true(found_entry, "Developers Page catalog includes available entry for " + SCENE_STUDY)
		opening.free()

	if _failed:
		print("FAIL: rpg_2d_canyon_logic")
		quit(1)
	else:
		print("PASS: All rpg_2d_canyon_logic checks passed!")
		quit(0)
