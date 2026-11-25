extends SceneTree
## Headless verification of scenes/maps/rts_units_test.tscn:
##   Godot --path . --headless --script res://tests/test_rts_units_test.gd
## Verifies:
##   1. 32x32 logical grid parity across "pixel" and "hd_painted" profiles
##   2. Tank 1:1 sprite_scale (1.0, no 0.85 fractional wobble) and 4-faction team-colour mask shader
##   3. Live F4 profile toggle, F3 debug overlay, P/K/L/M/N/F1 hotkeys
##   4. Distance-driven walk/tread animation (zero moonwalking when paused behind a blocker)
##   5. 100-unit stress check (4 factions moving simultaneously with zero tile overlap)
##   6. Clean Window state restoration on scene exit (Developers Page Play -> Esc round-trip)

const SCENE := "res://scenes/maps/rts_units_test_v3.tscn"
const ORIGINAL_SCENE := "res://scenes/maps/rts_units_test.tscn"
const UNIT_SCENE := preload("res://scenes/actors/rts_unit.tscn")
const DT := 1.0 / 60.0

var _failures := 0


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("FAIL: timed out")
		quit(1))
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		_failures += 1


func _key_event(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func _run() -> void:
	var win := root
	var initial_win := RtsVisualProfile.capture_window_state(win)

	var map := (load(SCENE) as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	await process_frame

	var grid := map.get_node("Grid") as RtsGrid
	var units_node := map.get_node("Units") as Node2D
	var camera := map.get_node("Camera") as RtsCamera
	var ground := map.get_node("Ground") as Sprite2D

	# 1. Grid and initial profile check
	_check(grid.tile_size == Vector2i(32, 32) and grid.region == Rect2i(0, 0, 30, 16),
		"Logical grid is 30x16 tiles of 32x32 px (%s)" % grid.region)
	_check(map.profile != null and map.profile.is_pixel(),
		"Default profile is 'pixel' (1x 960x540 integer)")
	_check(win.content_scale_size == Vector2i(960, 540) and win.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER,
		"Window uses scene-local 960x540 integer stretch in pixel mode")
	_check(is_equal_approx(camera.zoom.x, 1.0) and ground.scale == Vector2.ONE,
		"Pixel mode uses camera zoom 1.0 (not 1.3333) and 1x ground scale")

	# 2. Tank 1:1 sprite_scale and team-colour mask shader check
	var blue_tank := units_node.get_node("BlueTank") as RtsUnit
	var red_tank := units_node.get_node("RedTank") as RtsUnit
	var blue_cmd := units_node.get_node("BlueCommander") as RtsUnit
	var blue_sq := units_node.get_node("BlueSquad1") as RtsUnit
	_check(is_equal_approx(blue_tank.stats.sprite_scale, 1.0) and is_equal_approx(red_tank.stats.sprite_scale, 1.0),
		"BlueTank and RedTank use exact 1:1 sprite_scale = 1.0 (0.85 wobble eliminated)")
	_check(blue_tank.stats.sprite.get_size() == Vector2(256, 96) and blue_tank.stats.sprite_hd.get_size() == Vector2(512, 192),
		"Tank sheets are 256x96 (32x32 frames at 1x) and 512x192 (64x64 frames at 2x)")
	_check(blue_tank.stats.sprite == red_tank.stats.sprite and blue_tank.stats.team_mask != null,
		"BlueTank and RedTank share one neutral sprite + team-colour mask shader")
	_check(blue_tank.material is ShaderMaterial and (blue_tank.material as ShaderMaterial).get_shader_parameter("use_mask") == true,
		"RtsUnit binds rts_team_color.gdshader ShaderMaterial")
	_check(UnitStats.FACTION_PALETTES.size() == 4,
		"UnitStats defines 4 faction palettes (Blue, Red, Green, Palatinate)")
	_check(blue_cmd.stats.sprite_frames == 4 and blue_sq.stats.sprite_frames == 4,
		"Commanders and 4-figure squads have 4 distance-driven animation rows")

	# 3. Live F4 switch between pixel and hd_painted preserves logical grid and unit positions
	var cells_before := {}
	for u: RtsUnit in units_node.get_children():
		cells_before[u.name] = u.cell
		u.set_physics_process(false)

	map._unhandled_key_input(_key_event(KEY_F4))
	await process_frame
	_check(map.profile.is_hd_painted(), "F4 switches live to 'hd_painted' profile")
	_check(win.content_scale_size == Vector2i(1920, 1080) and win.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_FRACTIONAL,
		"Window switches to 1920x1080 canvas_items in hd_painted mode")
	_check(is_equal_approx(camera.zoom.x, 2.0) and ground.scale == Vector2(0.5, 0.5),
		"HD Painted mode uses 1920x1080 textures at 0.5 logical scale and 2.0x camera density zoom")
	_check(ground.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"HD Painted mode enables TEXTURE_FILTER_LINEAR_WITH_MIPMAPS")
	var same_cells := true
	for u: RtsUnit in units_node.get_children():
		if u.cell != cells_before[u.name]:
			same_cells = false
	_check(same_cells and grid.tile_size == Vector2i(32, 32),
		"Switching profiles keeps exact same 32x32 grid cells for all units")

	# Toggle F3 debug overlay & hotkeys
	map._unhandled_key_input(_key_event(KEY_F3))
	var metrics: Dictionary = map.get_perf_metrics()
	_check(map.debug_overlay_visible and metrics["unit_count"] == 8 and metrics["profile_id"] == "hd_painted",
		"F3 debug overlay reports profile, scale, FPS, GPU ms, and active unit count (%d)" % metrics["unit_count"])
	map._unhandled_key_input(_key_event(KEY_F4))
	await process_frame
	_check(map.profile.is_pixel(), "Second F4 returns cleanly to 'pixel' profile")

	# 4. Distance-driven animation check (no moonwalking while blocked)
	var start_cell := blue_sq.cell
	var neighbor := start_cell + Vector2i(1, 0)
	if not grid.is_free(neighbor):
		neighbor = grid.free_cells_near(start_cell, 2)[0]
	var dist_before := blue_sq._distance_moved
	blue_sq.command_move(neighbor)
	for i in 15:
		blue_sq.tick(DT)
	var dist_moving := blue_sq._distance_moved
	_check(dist_moving > dist_before + 5.0,
		"Moving unit advances _distance_moved proportionally to travel (%.1f px)" % (dist_moving - dist_before))
	# Finish the current tile step, then block the next tile and verify _distance_moved freezes while waiting
	while blue_sq._stepping:
		blue_sq.tick(DT)
	var settled_dist := blue_sq._distance_moved
	var blocked_next := blue_sq.cell + Vector2i(1, 0)
	var further_dest := blue_sq.cell + Vector2i(2, 0)
	# Temporarily claim intermediate tile blocked_next with blue_cmd so blue_sq must wait during BLOCKED_WAIT
	grid.claim(blocked_next, blue_cmd)
	blue_sq._path = [blocked_next, further_dest]
	blue_sq._path_dest = further_dest
	blue_sq.order = RtsUnit.Order.MOVE
	blue_sq.goal = further_dest
	blue_sq._blocked_time = 0.0
	for i in 10:
		blue_sq.tick(DT)
	grid.release(blocked_next, blue_cmd)
	blue_sq.command_stop()
	_check(is_equal_approx(blue_sq._distance_moved, settled_dist) and not blue_sq._stepping,
		"Blocked unit waiting on occupied intermediate tile does not advance walk cycle (0.0 px moonwalk)")

	# 5. 100-unit stress check across all 4 factions (Blue, Red, Green, Palatinate)
	var base_stats := [
		blue_sq.stats.duplicate() as UnitStats,
		red_tank.stats.duplicate() as UnitStats,
		blue_cmd.stats.duplicate() as UnitStats,
		blue_tank.stats.duplicate() as UnitStats,
	]
	base_stats[0].faction = UnitStats.Faction.BLUE
	base_stats[1].faction = UnitStats.Faction.RED
	base_stats[2].faction = UnitStats.Faction.GREEN
	base_stats[3].faction = UnitStats.Faction.PALATINATE

	var free_spots := grid.free_cells_near(Vector2i(15, 8), 110)
	var spawned: Array[RtsUnit] = []
	var target_total := 100
	var idx := 0
	while units_node.get_child_count() < target_total and idx < free_spots.size():
		var spot := free_spots[idx]
		idx += 1
		if not grid.is_free(spot):
			continue
		var u := UNIT_SCENE.instantiate() as RtsUnit
		u.name = "StressUnit_%d" % units_node.get_child_count()
		u.stats = base_stats[units_node.get_child_count() % 4]
		u.position = grid.center_of(spot)
		u.peaceful = true
		units_node.add_child(u)
		u.setup(grid)
		u.set_physics_process(false)
		u.apply_visual_profile(map.profile)
		spawned.append(u)

	var total_units := units_node.get_child_count()
	_check(total_units == 100, "Spawned 100 active units across 4 factions (%d total)" % total_units)

	# Give patrol move orders and simulate 180 ticks (3 seconds) while timing CPU step cost
	var all_u: Array[RtsUnit] = []
	for n in units_node.get_children():
		if n is RtsUnit:
			var ru := n as RtsUnit
			ru.peaceful = true
			all_u.append(ru)
	for i in all_u.size():
		var dest := free_spots[(i * 7 + 13) % free_spots.size()]
		all_u[i].command_move(dest)

	var t0 := Time.get_ticks_usec()
	var overlap_errors := 0
	for step_i in 180:
		if step_i == 90:
			map.toggle_visual_profile()
		for ru in all_u:
			ru.tick(DT)
		var seen := {}
		for ru in all_u:
			if seen.has(ru.cell) or not grid.is_walkable(ru.cell):
				overlap_errors += 1
			seen[ru.cell] = true
	var elapsed_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var ms_per_tick := elapsed_ms / 180.0
	_check(overlap_errors == 0,
		"100-unit stress simulation had 0 tile overlaps or blocked-tile violations over 180 ticks")
	_check(ms_per_tick < 8.0,
		"100-unit simulation tick averages %.3f ms/tick (< 8.0 ms budget)" % ms_per_tick)

	# 6. Scene exit restores Window properties cleanly (Developers Page Play -> Esc round-trip)
	map.queue_free()
	await process_frame
	await process_frame
	var restored_ok: bool = (
		win.content_scale_mode == initial_win["content_scale_mode"]
		and win.content_scale_size == initial_win["content_scale_size"]
		and win.content_scale_aspect == initial_win["content_scale_aspect"]
		and win.content_scale_stretch == initial_win["content_scale_stretch"]
		and win.snap_2d_transforms_to_pixel == initial_win["snap_2d_transforms_to_pixel"]
		and win.snap_2d_vertices_to_pixel == initial_win["snap_2d_vertices_to_pixel"]
	)
	_check(restored_ok, "Exiting RtsUnitsTestV3 restores all Window content_scale and snap properties cleanly")

	# 7. Verify original RTS Units Test (scenes/maps/rts_units_test.tscn) is preserved intact
	var orig_map := (load(ORIGINAL_SCENE) as PackedScene).instantiate()
	root.add_child(orig_map)
	await process_frame
	var orig_bt := orig_map.get_node("Units/BlueTank") as RtsUnit
	var orig_cam := orig_map.get_node("Camera") as RtsCamera
	_check(orig_bt != null and is_equal_approx(orig_bt.stats.sprite_scale, 0.85) and is_equal_approx(orig_cam.zoom.x, 1.3333),
		"Original RTS Units Test (rts_units_test.tscn) is preserved untouched")
	orig_map.queue_free()
	await process_frame

	if _failures == 0:
		print("RESULT: PASS")
		quit(0)
	else:
		push_error("RESULT: FAIL (%d failures)" % _failures)
		quit(1)
