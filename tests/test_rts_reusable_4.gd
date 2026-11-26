extends SceneTree
## Automated verification, Forward+ 1376x768 capture & moving-sequence harness for RTS Reusable 4.
##
## Headless checks (layout, blocked ground, passage widening/narrowing, combat, Mend, hold, catalog):
##   Godot_console.exe --headless --path . --script res://tests/test_rts_reusable_4.gd
##
## Windowed Forward+ 1376x768 matched stills & 12s live moving sequence:
##   Godot_console.exe --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/test_rts_reusable_4.gd -- --capture --record

const SCENE_PATH := "res://scenes/maps/rts_reusable_4.tscn"
const KIT_PATH := "res://scenes/rts/reusable_4/kit_preview.tscn"
const OPENING_PATH := "res://scenes/ui/opening_screen.tscn"
const CAP_DIR := "res://render_captures/rts_reusable_4/"
const FRAME_DIR := "res://tmp/rts_reusable_4/frames/"

var _failures: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	call_deferred("_run", "--capture" in args, "--record" in args, "--catalog-window" in args)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("FAIL: ", msg)


func _advance_sim(map: RtsCarbonBattlefield, seconds: float, step := 1.0 / 60.0) -> void:
	var n := int(round(seconds / step))
	for _i in range(n):
		for u in map.get_living_units():
			u.tick(step)
		map._process(step)


func _save_still(stem: String) -> Vector2i:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAP_DIR))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var err := img.save_png(ProjectSettings.globalize_path(CAP_DIR + stem + ".png"))
	_check(err == OK, "Saved capture " + stem + ".png")
	print("CAPTURE ", stem, ".png -> ", img.get_size())
	return img.get_size()


func _run(capture_mode: bool, record_mode: bool, catalog_window_only: bool) -> void:
	if catalog_window_only:
		await _verify_catalog_and_esc(true)
		_finish()
		return

	await _verify_catalog_and_esc(false)

	# 1. Verify Kit Preview scene loads cleanly
	var kit_packed := load(KIT_PATH) as PackedScene
	_check(kit_packed != null, "Load Desert Kit preview scene")
	if kit_packed != null:
		var kit := kit_packed.instantiate() as Node2D
		root.add_child(kit)
		await process_frame
		await process_frame
		_check(kit.has_node("ShelteredSpring") and kit.has_node("RoadsidePool"), "Kit preview contains both oasis groups")
		_check(kit.has_node("WideOrichalcum") and kit.has_node("TallOrichalcum"), "Kit preview contains both crystal arrangements")
		if capture_mode:
			await _save_still("desert_kit_command_hd")
			kit.call("apply_visual_mode", true)
			await _save_still("desert_kit_command_pixel")
			kit.call("apply_visual_mode", false)
		kit.queue_free()
		await process_frame

	# 2. Load RTS Reusable 4 playable battlefield
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Load RTS Reusable 4 scene")
	if packed == null:
		_finish()
		return

	var map := packed.instantiate() as RtsCarbonBattlefield
	root.add_child(map)
	await process_frame
	await process_frame

	for u in map.get_living_units():
		u.set_physics_process(false)
		u.peaceful = true

	# 3. Verify landmarks, zoom framing, and walkable ground agreement
	_check(not map.grid.is_walkable(map.grid.cell_of(Vector2(656, 444))), "Central Orichalcum blocks its cells")
	_check(not map.grid.is_walkable(map.grid.cell_of(Vector2(316, 232))), "Blue Field HQ blocks its building footprint")
	_check(not map.grid.is_walkable(map.grid.cell_of(Vector2(116, 192))), "Smaller Blue Outpost blocks its pad")
	_check(map.grid.is_walkable(map.grid.cell_of(Vector2(316, 312))), "Forecourt in front of Blue HQ is walkable for squad & tank")
	_check(not map.grid.is_walkable(map.grid.cell_of(Vector2(996, 240))), "ShelteredSpring water blocks deep water cells")
	_check(not map.grid.is_walkable(map.grid.cell_of(Vector2(1050, 162))), "ShelteredSpring cliff ledge blocks cliff cells")
	_check(map.grid.is_walkable(map.grid.cell_of(Vector2(1008, 288))), "ShelteredSpring sandy bank shore is walkable")
	_check(map.height_at(Vector2(382, 654)) > 0.6, "Forked dune crest provides elevation relief")

	map.close_zoom = false
	map.apply_zoom_framing()
	var cmd_cells_w := map.hud.camera_world_rect.size.x / 32.0
	_check(absf(cmd_cells_w - 21.0) < 0.5, "Command zoom spans ~21 cells (got %.2f)" % cmd_cells_w)

	if capture_mode:
		map.set_selection([])
		map.set_camera_focus(Vector2(504, 412))
		await _save_still("01_opening_command_hd")
		map.apply_visual_mode(true)
		await _save_still("01_opening_command_pixel")
		map.apply_visual_mode(false)

		# Sheltered spring & northeast outpost
		map.set_camera_focus(Vector2(1040, 232))
		await _save_still("02_sheltered_spring_hd")

	# 4. Verify Roadside Pool passage narrowing vs widening!
	var roadside := map.get_node("YSortWorld/RoadsidePool") as Node2D
	var pass_cliff := roadside.get_node("PassCliff") as RtsCarbonPiece
	var orig_cliff_pos := pass_cliff.position
	# Published layout: lane cells cx=31 (1008, 784) & cx=32 (1040, 784) are open, water at cx=34 (1104, 768) is blocked
	_check(not map.grid.is_walkable(Vector2i(29, 24)), "PassCliff blocks rock west of roadside passage")
	_check(map.grid.is_walkable(Vector2i(31, 24)) and map.grid.is_walkable(Vector2i(32, 24)),
		"Published widened roadside passage leaves 2 clear cells for tank")
	_check(not map.grid.is_walkable(Vector2i(34, 24)), "RoadsidePool water blocks cells inside visible pool")

	# Slide PassCliff 64 units right to narrow/close the passage and verify path closes!
	pass_cliff.position = orig_cliff_pos + Vector2(64.0, 0.0)
	map.call("rebuild_navigation_and_minimap")
	_check(not map.grid.is_walkable(Vector2i(31, 24)) and not map.grid.is_walkable(Vector2i(32, 24)),
		"Sliding PassCliff inward closes the roadside tank lane")
	var narrow_path := map.grid.find_path(Vector2i(31, 21), Vector2i(31, 26), null, false)
	var uses_direct_narrow := false
	for c in narrow_path:
		if c.y == 24 and c.x >= 30 and c.x <= 32:
			uses_direct_narrow = true
	_check(not uses_direct_narrow, "Narrowed passage blocks direct tank route through (cx=31..32, cy=24)")

	if capture_mode:
		map.grid.show_debug = true
		map.grid.queue_redraw()
		map.set_camera_focus(Vector2(1052, 708))
		await _save_still("03a_roadside_passage_narrow_grid")

	# Restore widened published position and verify direct tank route opens!
	pass_cliff.position = orig_cliff_pos
	map.call("rebuild_navigation_and_minimap")
	var wide_path := map.grid.find_path(Vector2i(31, 21), Vector2i(31, 26), null, false)
	var uses_direct_wide := false
	for c in wide_path:
		if c.y == 24 and (c.x == 31 or c.x == 32):
			uses_direct_wide = true
	_check(uses_direct_wide, "Widening PassCliff opens direct route through roadside passage")

	if capture_mode:
		map.grid.show_debug = true
		map.grid.queue_redraw()
		await _save_still("03b_roadside_passage_open_grid")
		map.grid.show_debug = false
		map.grid.queue_redraw()
		await _save_still("03c_roadside_pool_and_fork_hd")
		map.close_zoom = true
		map.apply_zoom_framing()
		map.apply_visual_mode(true)
		await _save_still("03d_roadside_fork_close_pixel")
		map.apply_visual_mode(false)
		map.close_zoom = false
		map.apply_zoom_framing()

	# 5. Drive BlueTank across the new forked dune crest (verify twin tracks!)
	#    Walk BlueSquad3 past BlueFieldHQ entrance, and drive RedTank through the roadside oasis passage!
	var blue_tank := map.get_node("YSortWorld/BlueTank") as RtsCarbonUnit
	var blue_cmd := map.get_node("YSortWorld/BlueCommander") as RtsCarbonUnit
	var blue_sq1 := map.get_node("YSortWorld/BlueSquad1") as RtsCarbonUnit
	var blue_sq2 := map.get_node("YSortWorld/BlueSquad2") as RtsCarbonUnit
	var blue_sq3 := map.get_node("YSortWorld/BlueSquad3") as RtsCarbonUnit
	var red_tank := map.get_node("YSortWorld/RedTank") as RtsCarbonUnit
	var red_sq1 := map.get_node("YSortWorld/RedSquad1") as RtsCarbonUnit
	var red_sq2 := map.get_node("YSortWorld/RedSquad2") as RtsCarbonUnit

	# First verify squad walking past HQ while BlueTank sits near HQ entrance!
	blue_sq2.position = Vector2(216, 336)
	blue_sq2.command_move(Vector2(392, 368))
	_advance_sim(map, 3.2)
	_check(blue_sq2.position.x > 360.0, "Squad walked cleanly past Blue Field HQ & stationed tank (x=%.1f)" % blue_sq2.position.x)

	if capture_mode:
		map.set_selection([])
		map.set_camera_focus(Vector2(348, 304))
		await _save_still("04_blue_headquarters_and_squad_hd")

	# Now drive BlueTank south-east across DuneLongFork (382, 654) and RedTank through the roadside passage!
	blue_tank.position = Vector2(304, 528)
	blue_tank.hull_angle = Vector2(1.0, 1.2).angle()
	blue_tank.turret_angle = blue_tank.hull_angle
	blue_tank.command_move(Vector2(456, 744))

	red_tank.position = Vector2(1008, 672)
	red_tank.hull_angle = PI * 0.5
	red_tank.turret_angle = PI * 0.5
	red_tank.command_move(Vector2(1024, 848))

	# Walk a selected squad onto open ground directly beneath ShelteredSpring/SpringTree's overhanging canopy!
	var spring_tree := map.get_node("YSortWorld/ShelteredSpring/SpringTree") as RtsCarbonPiece
	blue_sq3.position = spring_tree.global_position + Vector2(-56, -16)
	blue_sq3.command_move(spring_tree.global_position + Vector2(-14, -16))
	map.set_selection([blue_sq3])

	_advance_sim(map, 4.4)
	_check(map.disturbed_tread_pixels > 110, "BlueTank compressed twin tracks across forked dune (%d px)" % map.disturbed_tread_pixels)
	_check(red_tank.position.y > 815.0, "RedTank drove cleanly through the roadside oasis passage (pos=%s)" % str(red_tank.position.round()))
	_check(spring_tree.modulate.a < 0.60, "Oasis tree canopy faded over selected squad beneath crown (alpha=%.2f)" % spring_tree.modulate.a)

	if capture_mode:
		map.set_selection([])
		map.set_camera_focus(Vector2(396, 656))
		await _save_still("05a_forked_dune_treads_on_hd")
		map.show_treads = false
		map.apply_visual_mode(false)
		await _save_still("05b_forked_dune_treads_off_hd")
		map.show_treads = true
		map.apply_visual_mode(false)

	# 6. Verify wounded squad (3 of 4) & Blue Commander Mend back to 4 of 4!
	blue_sq1.take_damage(36, red_sq1)
	_check(blue_sq1.fit_count() == 3, "Wounded squad drops to 3 of 4 soldiers (got %d)" % blue_sq1.fit_count())
	blue_cmd.position = blue_sq1.position + Vector2(28, 0)
	var healed := blue_cmd.cast_mend()
	_check(healed >= 1 and blue_sq1.fit_count() == 4, "Blue Commander Mend restores wounded squad to 4 of 4")

	# 7. Optional 12-second (360-frame @ 30fps) Forward+ live moving sequence!
	map.queue_free()
	await process_frame
	if record_mode:
		await _record_moving_sequence()

	_finish()


func _record_moving_sequence() -> void:
	var abs_frames := ProjectSettings.globalize_path(FRAME_DIR)
	DirAccess.make_dir_recursive_absolute(abs_frames)
	var map := (load(SCENE_PATH) as PackedScene).instantiate() as RtsCarbonBattlefield
	root.add_child(map)
	await process_frame
	await process_frame
	for u in map.get_living_units():
		u.set_physics_process(false)
		u.peaceful = true

	var blue_tank := map.get_node("YSortWorld/BlueTank") as RtsCarbonUnit
	var blue_cmd := map.get_node("YSortWorld/BlueCommander") as RtsCarbonUnit
	var blue_sq1 := map.get_node("YSortWorld/BlueSquad1") as RtsCarbonUnit
	var blue_sq2 := map.get_node("YSortWorld/BlueSquad2") as RtsCarbonUnit
	var blue_sq3 := map.get_node("YSortWorld/BlueSquad3") as RtsCarbonUnit
	var red_tank := map.get_node("YSortWorld/RedTank") as RtsCarbonUnit
	var red_cmd := map.get_node("YSortWorld/RedCommander") as RtsCarbonUnit
	var red_sq1 := map.get_node("YSortWorld/RedSquad1") as RtsCarbonUnit
	var red_sq2 := map.get_node("YSortWorld/RedSquad2") as RtsCarbonUnit

	# Beat 1 (0..4.2s, frames 0..125): Opening near Blue HQ — Squad walks past HQ & stationed tank,
	# while Blue & Red forces cross sand and pale road toward the central Orichalcum plaza!
	map.close_zoom = false
	map.apply_zoom_framing()
	map.set_selection([])
	map.set_camera_focus(Vector2(452, 368))

	blue_sq2.position = Vector2(192, 316)
	blue_sq2.command_move(Vector2(476, 408))
	blue_cmd.command_move(Vector2(544, 434))
	blue_sq1.command_move(Vector2(536, 488))
	blue_sq3.command_move(Vector2(576, 368))
	red_sq1.command_move(Vector2(752, 476))
	red_cmd.command_move(Vector2(784, 516))
	red_sq2.command_move(Vector2(744, 540))

	# Beat 2 (4.2..8.0s, frames 126..239): Pan gently across central plaza & SW forked dune as BlueTank carves tracks!
	# Beat 3 (8.0..12.0s, frames 240..359): Pan to SE road fork & RoadsidePool as RedTank drives through the oasis passage!
	var total_frames := 360
	for f in range(total_frames):
		if f == 95:
			blue_tank.position = Vector2(304, 520)
			blue_tank.hull_angle = Vector2(0.9, 1.1).angle()
			blue_tank.turret_angle = blue_tank.hull_angle
			blue_tank.command_move(Vector2(468, 748))
		if f == 215:
			red_tank.position = Vector2(984, 632)
			red_tank.hull_angle = Vector2(0.2, 1.0).angle()
			red_tank.turret_angle = red_tank.hull_angle
			red_tank.command_move(Vector2(1024, 852))
			red_sq2.position = Vector2(920, 580)
			red_sq2.command_move(Vector2(1012, 740))

		# Smooth camera choreography across the three beats
		var cam_target := Vector2(452, 368)
		if f >= 105 and f < 225:
			var t1 := smoothstep(105.0, 155.0, float(f))
			cam_target = Vector2(452, 368).lerp(Vector2(512, 548), t1)
		elif f >= 225:
			var t2 := smoothstep(225.0, 270.0, float(f))
			cam_target = Vector2(512, 548).lerp(Vector2(1036, 696), t2)
		map.set_camera_focus(cam_target)

		_advance_sim(map, 1.0 / 30.0, 1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.save_jpg(abs_frames.path_join("%05d.jpg" % f), 0.94)
	print("RECORDED 360 frames to ", abs_frames)
	map.queue_free()
	await process_frame


func _verify_catalog_and_esc(capture_window: bool) -> void:
	if root.get_node_or_null("BuildLauncher") == null:
		var bl := (load("res://scenes/ui/build_launcher.tscn") as PackedScene).instantiate()
		bl.name = "BuildLauncher"
		root.add_child(bl)
		await process_frame

	_check(change_scene_to_file(OPENING_PATH) == OK, "Developers Page is available")
	await scene_changed
	await process_frame
	current_scene.get_node("%DevelopersPage").pressed.emit()
	await process_frame

	for path in [SCENE_PATH, KIT_PATH, "res://scenes/maps/rts_reusable_2_carbon.tscn"]:
		var card_button: Button = null
		for section in current_scene.get_node("%Catalog").get_children():
			for card in section.get_children():
				if card.get_meta("catalog_key", "") == path:
					for button in card.find_children("*", "Button", true, false):
						if button.text == ("View" if path == KIT_PATH else "Play"):
							card_button = button
		_check(is_instance_valid(card_button), "Catalog button found for " + path.get_file())
		if not is_instance_valid(card_button):
			return
		card_button.pressed.emit()
		await scene_changed
		await process_frame
		_check(current_scene != null and current_scene.scene_file_path == path, "Catalog launched " + path.get_file())
		if path == SCENE_PATH:
			_check(not root.get_node("BuildLauncher/ReturnButton").visible, "Launch leaves Command HUD unobstructed")
			if capture_window:
				await _save_still("06_launched_from_developers_page")
		var esc := InputEventKey.new()
		esc.pressed = true
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		Input.parse_input_event(esc)
		await scene_changed
		await process_frame
		_check(current_scene != null and current_scene.get_node("%Library").visible, "Esc returned to Developers Page from " + path.get_file())
		if capture_window and path == SCENE_PATH:
			await _save_still("07_returned_to_developers_page_esc")

	if current_scene != null:
		current_scene.queue_free()
		await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("ALL RTS REUSABLE 4 CHECKS PASSED")
		quit(0)
	else:
		printerr("RTS REUSABLE 4 FAILED (%d): %s" % [_failures.size(), ", ".join(_failures)])
		quit(1)
