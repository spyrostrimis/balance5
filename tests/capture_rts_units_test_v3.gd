extends SceneTree
## Windowed Forward+ capture and benchmark of scenes/maps/rts_units_test.tscn.
##   Godot --path . --script res://tests/capture_rts_units_test.gd
## Captures matched 1920x1080 and 1280x720 screenshots of BOTH "pixel" and "hd_painted"
## profiles (overview, F3 debug overlay, and close-ups of Blue Tank, Red Tank, and Infantry Squads),
## measures Forward+ FPS and GPU frame time (8 units and 100-unit stress check), and verifies
## the Developers Page Play -> Esc round-trip restores window state cleanly.

const SCENE := "res://scenes/maps/rts_units_test_v3.tscn"
const OPENING_SCENE := "res://scenes/ui/opening_screen.tscn"
const UNIT_SCENE := preload("res://scenes/actors/rts_unit.tscn")
const DIR := "res://render_captures/rts_units"

var _map: Node2D


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("Timed out")
		quit(1))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _set_all(on: bool) -> void:
	RtsLook.shadows = on
	RtsLook.ground_light = on
	RtsLook.marks = on
	RtsLook.dust = on
	for node in _map.get_node("Units").get_children():
		(node as CanvasItem).queue_redraw()
	_map.get_node("Look").queue_redraw()


func _capture_window_image() -> Image:
	await _frames(3)
	var vp_img := root.get_texture().get_image()
	var win_size := root.size
	if vp_img.get_size() == win_size:
		return vp_img
	# When integer stretch letters/pillarboxes a smaller logical viewport (e.g. 960x540 inside 1280x720),
	# composite the viewport texture onto the full window frame at its exact final_transform origin.
	var xform := root.get_final_transform()
	var scale := xform.get_scale()
	var margin := Vector2i(xform.origin.round())
	var scaled_w := int(round(vp_img.get_width() * scale.x))
	var scaled_h := int(round(vp_img.get_height() * scale.y))
	var blit_img := vp_img
	if scaled_w != vp_img.get_width() or scaled_h != vp_img.get_height():
		blit_img = vp_img.duplicate()
		blit_img.resize(scaled_w, scaled_h, Image.INTERPOLATE_NEAREST)
	var frame := Image.create(win_size.x, win_size.y, false, vp_img.get_format())
	frame.fill(Color(0.0, 0.0, 0.0, 1.0))
	frame.blit_rect(blit_img, Rect2i(Vector2i.ZERO, blit_img.get_size()), margin)
	return frame


func _capture(file: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var img := await _capture_window_image()
	img.save_png(DIR + "/" + file)
	print("Captured %-40s size=%s" % [file, img.get_size()])


func _measure_gpu_perf(label: String, sample_frames: int = 30) -> Dictionary:
	var vp_rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	await _frames(5)
	var gpu_sum := 0.0
	var cpu_sum := 0.0
	var t0 := Time.get_ticks_usec()
	for i in sample_frames:
		await process_frame
		gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
	var wall_s := maxf(0.001, (Time.get_ticks_usec() - t0) / 1000000.0)
	var avg_fps := float(sample_frames) / wall_s
	var avg_gpu := gpu_sum / float(sample_frames)
	var avg_cpu := cpu_sum / float(sample_frames)
	print("PERF  %-36s FPS=%6.1f  GPU=%5.2f ms  CPU=%5.2f ms" % [label, avg_fps, avg_gpu, avg_cpu])
	return {"fps": avg_fps, "gpu_ms": avg_gpu, "cpu_ms": avg_cpu}


func _set_camera_logical(camera: RtsCamera, logical_zoom: float, world_pos: Vector2) -> void:
	camera._set_zoom(logical_zoom * camera.density_scale)
	camera.look_at_point(world_pos)


func _capture_matched_set(res_tag: String, win_res: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = win_res
	await _frames(4)
	var camera := _map.get_node("Camera") as RtsCamera

	var blue_tank := _map.get_node("Units/BlueTank") as RtsUnit
	var red_tank := _map.get_node("Units/RedTank") as RtsUnit
	var blue_squad := _map.get_node("Units/BlueSquad1") as RtsUnit
	var blue_cmd := _map.get_node("Units/BlueCommander") as RtsUnit
	var squad_focus := (blue_squad.position + blue_cmd.position) * 0.5

	for prof_id in [RtsVisualProfile.ID_PIXEL, RtsVisualProfile.ID_HD_PAINTED]:
		_map.set_visual_profile(RtsVisualProfile.by_id(prof_id))
		await _frames(4)

		# 1. Overview
		_map.set_debug_overlay(false)
		_set_camera_logical(camera, 1.0, Vector2(480, 270))
		await _capture("%s_%s_overview.png" % [prof_id, res_tag])

		# 2. Overview with F3 debug overlay
		_map.set_debug_overlay(true)
		await _frames(2)
		await _capture("%s_%s_f3_debug.png" % [prof_id, res_tag])
		_map.set_debug_overlay(false)

		# 3. Matched close-up: Blue Tank (2.5x logical zoom)
		_set_camera_logical(camera, 2.5, blue_tank.position)
		await _capture("%s_%s_zoom_bluetank.png" % [prof_id, res_tag])

		# 4. Matched close-up: Red Tank (2.5x logical zoom)
		_set_camera_logical(camera, 2.5, red_tank.position)
		await _capture("%s_%s_zoom_redtank.png" % [prof_id, res_tag])

		# 5. Matched close-up: Infantry Squads & Commander (2.5x logical zoom)
		_set_camera_logical(camera, 2.5, squad_focus)
		await _capture("%s_%s_zoom_squads.png" % [prof_id, res_tag])

		# Measure GPU frame time at overview
		_set_camera_logical(camera, 1.0, Vector2(480, 270))
		await _measure_gpu_perf("%s @ %s (8 units)" % [prof_id, res_tag], 25)


func _run() -> void:
	var initial_win := RtsVisualProfile.capture_window_state(root)

	_map = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_map)
	var camera := _map.get_node("Camera") as RtsCamera
	camera.edge_scroll = false
	await _frames(5)

	# Let units patrol briefly so tracks, footprints, and dust are visible on the sand,
	# then pause patrol so all matched pixel vs hd_painted captures show the exact same moment!
	_map.set_patrol(true)
	for i in 240:
		await physics_frame
	_map.set_patrol(false)
	for node in _map.get_node("Units").get_children():
		if node is RtsUnit:
			var ru := node as RtsUnit
			ru.peaceful = true
			ru.command_stop()
			ru._shot_timer = 0.0
			ru._flash = 0.0
			ru.set_physics_process(false)
	await _frames(4)

	# Keep legacy on/off grounding captures at 1280x720
	_map.set_visual_profile(RtsVisualProfile.create_pixel())
	_set_camera_logical(camera, 1.0, Vector2(480, 270))
	_set_all(true)
	await _capture("overview_on.png")
	_set_all(false)
	await _capture("overview_off.png")
	_set_all(true)

	# Matched 1920x1080 and 1280x720 captures for BOTH "pixel" and "hd_painted"
	await _capture_matched_set("1080p", Vector2i(1920, 1080))
	await _capture_matched_set("720p", Vector2i(1280, 720))

	# 100-unit Forward+ GPU stress test at 1920x1080 in both profiles
	root.size = Vector2i(1920, 1080)
	await _frames(3)
	var grid := _map.get_node("Grid") as RtsGrid
	var units_node := _map.get_node("Units") as Node2D
	var blue_sq := units_node.get_node("BlueSquad1") as RtsUnit
	var red_tank := units_node.get_node("RedTank") as RtsUnit
	var blue_cmd := units_node.get_node("BlueCommander") as RtsUnit
	var blue_tank := units_node.get_node("BlueTank") as RtsUnit
	var stats_pool := [
		blue_sq.stats.duplicate() as UnitStats,
		red_tank.stats.duplicate() as UnitStats,
		blue_cmd.stats.duplicate() as UnitStats,
		blue_tank.stats.duplicate() as UnitStats,
	]
	stats_pool[0].faction = UnitStats.Faction.BLUE
	stats_pool[1].faction = UnitStats.Faction.RED
	stats_pool[2].faction = UnitStats.Faction.GREEN
	stats_pool[3].faction = UnitStats.Faction.PALATINATE

	var free_spots := grid.free_cells_near(Vector2i(15, 8), 110)
	var idx := 0
	while units_node.get_child_count() < 100 and idx < free_spots.size():
		var spot := free_spots[idx]
		idx += 1
		if not grid.is_free(spot):
			continue
		var u := UNIT_SCENE.instantiate() as RtsUnit
		u.name = "Stress_%d" % units_node.get_child_count()
		u.stats = stats_pool[units_node.get_child_count() % 4]
		u.position = grid.center_of(spot)
		u.peaceful = true
		units_node.add_child(u)
		u.setup(grid)
		u.apply_visual_profile(_map.profile)
	for node in units_node.get_children():
		if node is RtsUnit:
			(node as RtsUnit).set_physics_process(true)
	_map.set_patrol(true)
	for prof_id in [RtsVisualProfile.ID_PIXEL, RtsVisualProfile.ID_HD_PAINTED]:
		_map.set_visual_profile(RtsVisualProfile.by_id(prof_id))
		_map.set_debug_overlay(true)
		_set_camera_logical(camera, 1.0, Vector2(480, 270))
		await _measure_gpu_perf("%s @ 1080p (100 units)" % prof_id, 30)
		await _capture("%s_1080p_stress_100units.png" % prof_id)

	# Verify Developers Page Play -> Esc round-trip restores Window state cleanly
	root.size = initial_win["size"]
	_map.queue_free()
	await _frames(3)
	var opening := (load(OPENING_SCENE) as PackedScene).instantiate()
	root.add_child(opening)
	await _frames(4)
	var roundtrip_ok: bool = (
		root.content_scale_mode == initial_win["content_scale_mode"]
		and root.content_scale_size == initial_win["content_scale_size"]
		and root.content_scale_aspect == initial_win["content_scale_aspect"]
		and root.content_scale_stretch == initial_win["content_scale_stretch"]
		and root.snap_2d_transforms_to_pixel == initial_win["snap_2d_transforms_to_pixel"]
	)
	print("ROUNDTRIP Developers Page restore: ", "PASS" if roundtrip_ok else "FAIL")
	await _capture("developers_page_after_esc.png")
	opening.queue_free()
	await _frames(2)
	quit(0 if roundtrip_ok else 1)
