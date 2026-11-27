extends SceneTree
## Checks and captures for RTS Mission 1, the canonical RTS scene built from the shared desert kit.
##
## Headless (kit integrity, blocked ground, passage widening, tracks, canopy, Mend, catalog + Esc):
##   Godot_console.exe --headless --path . --script res://tests/test_rts_mission_1.gd
## RTS acceptance view is 1920x1080 (the native size of Carbon's Detailed art). The monitor's work area
## is shorter than 1080, so captures run fullscreen:
##   Godot_console.exe --path . --rendering-method forward_plus --fullscreen --script res://tests/test_rts_mission_1.gd -- --capture --compare --record
##   --capture  Mission 1 stills (opening, spring, roadside pool, HQ, dune tracks, kit pages, Pixel)
##   --compare  the same camera and unit lineup in Reusable 4 and Mission 1 (before/after)
##   --record   12 s moving sequence, frames to tmp/rts_mission_1/frames (encode with ffmpeg)

const SCENE_PATH := "res://scenes/maps/rts_mission_1.tscn"
const R4_PATH := "res://scenes/maps/rts_reusable_4.tscn"
const KIT_PATH := "res://scenes/rts/desert_kit/kit_preview.tscn"
const PIECES_DIR := "res://scenes/rts/desert_kit/pieces/"
const GROUPS_DIR := "res://scenes/rts/desert_kit/groups/"
const OPENING_PATH := "res://scenes/ui/opening_screen.tscn"
const CAP_DIR := "res://render_captures/rts_mission_1/"
const FRAME_DIR := "res://tmp/rts_mission_1/frames/"
const UNIT_NAMES := ["BlueSquad1", "RedSquad1", "BlueSquad2", "RedSquad2", "BlueCommander", "RedCommander",
	"BlueTank", "RedTank", "BlueSquad3", "RedSquad3"]
## Top row on the pale road, middle row (4 of 4) on calm sand, lower row (wounded, 3 of 4) on calm sand.
const LINEUP := [Vector2(368, 376), Vector2(432, 400), Vector2(368, 462), Vector2(432, 462),
	Vector2(494, 420), Vector2(494, 462), Vector2(316, 355), Vector2(548, 462),
	Vector2(368, 514), Vector2(432, 514)]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("FAIL: ", msg)
	else:
		print("ok   ", msg)


func _advance_sim(map: RtsCarbonBattlefield, seconds: float, step := 1.0 / 60.0) -> void:
	for _i in range(int(round(seconds / step))):
		for u in map.get_living_units():
			u.tick(step)
		map._process(step)


func _save_still(stem: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAP_DIR))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	_check(img.save_png(ProjectSettings.globalize_path(CAP_DIR + stem + ".png")) == OK, "Saved " + stem + ".png")
	print("CAPTURE ", stem, ".png -> ", img.get_size())


func _load_map(path: String) -> RtsCarbonBattlefield:
	var map := (load(path) as PackedScene).instantiate() as RtsCarbonBattlefield
	root.add_child(map)
	await process_frame
	await process_frame
	for u in map.get_living_units():
		u.set_physics_process(false)
		u.peaceful = true
	return map


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var capture := "--capture" in args
	await _verify_catalog_and_esc()
	_verify_kit_files()
	await _verify_kit_preview(capture)
	await _verify_mission(capture)
	if "--compare" in args:
		await _capture_comparisons()
	if "--record" in args:
		await _record_moving_sequence()
	_finish()


# --- Kit ------------------------------------------------------------------------------------------

func _verify_kit_files() -> void:
	var piece_files := DirAccess.get_files_at(PIECES_DIR)
	var count := 0
	for f in piece_files:
		f = f.trim_suffix(".remap")  # exported builds list scenes as *.tscn.remap
		if not f.ends_with(".tscn"):
			continue
		count += 1
		var p := (load(PIECES_DIR + f) as PackedScene).instantiate() as RtsCarbonPiece
		_check(p != null, "Piece scene %s is an RtsCarbonPiece" % f)
		if p == null:
			continue
		_check(p.piece_id == f.get_basename(), "%s piece_id matches its file name" % f)
		_check(p.detailed_texture_override != null and p.pixel_texture_override != null, "%s has Detailed and Pixel art" % f)
		p.free()
	_check(count >= 30, "Kit has one scene per painted piece (%d)" % count)
	for g in ["sheltered_spring", "roadside_pool", "orichalcum_wide", "orichalcum_tall"]:
		_check(ResourceLoader.exists(GROUPS_DIR + g + ".tscn"), "Kit group %s exists" % g)


func _verify_kit_preview(capture: bool) -> void:
	var kit := (load(KIT_PATH) as PackedScene).instantiate() as Node2D
	root.add_child(kit)
	await process_frame
	await process_frame
	_check(kit.has_node("ShelteredSpring") and kit.has_node("RoadsidePool"), "Kit preview shows both oasis groups")
	_check(kit.has_node("WideOrichalcum") and kit.has_node("TallOrichalcum"), "Kit preview shows both crystal deposits")
	_check(kit.get_node("Palette").get_child_count() >= 30, "Kit preview palette shows every piece")
	if capture:
		await _save_still("kit_1_arrangements_hd")
		kit.call("show_page", 1)
		await _save_still("kit_2_pieces_hd")
		kit.call("apply_visual_mode", true)
		kit.call("show_page", 0)
		await _save_still("kit_1_arrangements_pixel")
	kit.queue_free()
	await process_frame


# --- Mission --------------------------------------------------------------------------------------

func _kit_only(n: Node, map: Node, out: Array[String]) -> void:
	for c in n.get_children():
		var p := c as RtsCarbonPiece
		if p != null and c.get_script() == load("res://scripts/rts_carbon/rts_carbon_piece.gd"):
			var src := c.scene_file_path
			if src.is_empty() and c.owner != map:
				src = c.owner.scene_file_path  # a piece inside a kit group
			if not (src.begins_with(PIECES_DIR) or src.begins_with(GROUPS_DIR)):
				out.append(String(map.get_path_to(c)))
		_kit_only(c, map, out)


func _verify_mission(capture: bool) -> void:
	var map := await _load_map(SCENE_PATH)
	_check(map is RtsMissionBattlefield, "Mission 1 uses RtsMissionBattlefield")
	var loose: Array[String] = []
	_kit_only(map, map, loose)
	_check(loose.is_empty(), "Every placed piece comes from the kit (%s)" % ", ".join(loose))
	_check(map.get("smooth_wind") == true, "Seam-free wind lighting is on")
	_check(map.has_node("RoadNetwork/HQDriveway") and not map.has_node("GroundDecals/HQForecourt"),
		"HQ joins the road with a driveway instead of a loose paving patch")
	var oasis := map.get_node_or_null("YSortWorld/NortheastCliffOasis") as RtsCarbonPiece
	_check(oasis != null and oasis.piece_id == "cliff_oasis", "Carbon's painted cliff oasis holds the northeast")
	var spring_kit := (load(GROUPS_DIR + "sheltered_spring.tscn") as PackedScene).instantiate()
	var green := 0
	for c in spring_kit.get_children():
		if String(c.get("piece_id")).begins_with("scrub") or String(c.get("piece_id")) == "oasis_reeds":
			green += 1
	spring_kit.free()
	_check(green >= 8, "Kit sheltered spring has a ring of green at the waterline (%d plants)" % green)

	# Blocked ground agrees with the visible pieces.
	var grid := map.grid
	_check(not grid.is_walkable(grid.cell_of(Vector2(656, 444))), "Central Orichalcum blocks its cells")
	_check(not grid.is_walkable(grid.cell_of(Vector2(316, 232))), "Blue Field HQ blocks its footprint")
	_check(grid.is_walkable(grid.cell_of(Vector2(316, 312))), "Driveway in front of the HQ is walkable")
	_check(not grid.is_walkable(grid.cell_of(Vector2(996, 240))), "Oasis pool blocks its cells")
	_check(not grid.is_walkable(grid.cell_of(Vector2(1050, 162))), "Oasis cliff blocks its cells")
	_check(grid.is_walkable(grid.cell_of(Vector2(1008, 352))), "Sand south of the oasis is walkable")
	_check(map.height_at(Vector2(382, 654)) > 0.6, "Forked dune gives elevation")
	map.close_zoom = false
	map.apply_zoom_framing()
	var cells_w := map.hud.camera_world_rect.size.x / 32.0
	_check(absf(cells_w - 21.0) < 0.5, "Command zoom spans ~21 cells (%.2f)" % cells_w)

	if capture:
		map.set_selection([])
		map.call("focus_view", 0)
		await _save_still("01_opening_command_hd")
		map.apply_visual_mode(true)
		await _save_still("01_opening_command_pixel")
		map.apply_visual_mode(false)
		map.call("focus_view", 1)
		await _save_still("02_sheltered_spring_hd")
		map.close_zoom = true
		map.apply_zoom_framing()
		await _save_still("02b_sheltered_spring_close_hd")
		map.close_zoom = false
		map.apply_zoom_framing()

	if DisplayServer.get_name() != "headless":
		await _verify_hud_styles(map, capture)

	# Planet skin: terrain art changes, the ground units can use does not.
	var rock := map.get_node("YSortWorld/CentralOrichalcum") as RtsCarbonPiece
	var desert_tex := rock.texture
	var walk_before := []
	for cy in 28:
		for cx in 44:
			walk_before.append(grid.is_walkable(Vector2i(cx, cy)))
	map.call("apply_skin", 1, false)
	_check(map.call("skin_name") == "Miasaki", "P switches the planet skin to Miasaki")
	_check(rock.texture != desert_tex and rock.texture.resource_path.contains("miasaki"), "Orichalcum outcrop uses Miasaki's painting (%s)" % rock.texture.resource_path)
	var bank := map.get_node("YSortWorld/RoadsidePool/SandyBank") as RtsCarbonPiece
	_check(bank.texture.resource_path.contains("skins/miasaki"), "Kit-only pieces use the palette-matched skin art")
	var same := true
	var i := 0
	for cy in 28:
		for cx in 44:
			same = same and walk_before[i] == grid.is_walkable(Vector2i(cx, cy))
			i += 1
	_check(same, "Skin switch leaves blocked ground unchanged")
	if capture:
		map.call("focus_view", 0)
		await _save_still("06_miasaki_opening_hd")
		map.call("focus_view", 1)
		await _save_still("06b_miasaki_northeast_hd")
		map.call("focus_view", 2)
		await _save_still("06c_miasaki_roadside_pool_hd")
	map.call("apply_skin", 0, false)
	_check(rock.texture == desert_tex, "Switching back restores the desert art")

	# Roadside passage: moving PassCliff in the layout changes where tanks can go.
	var pass_cliff := map.get_node("YSortWorld/RoadsidePool/PassCliff") as Node2D
	var orig := pass_cliff.position
	_check(grid.is_walkable(Vector2i(31, 24)) and grid.is_walkable(Vector2i(32, 24)), "Published passage leaves two clear cells")
	_check(not grid.is_walkable(Vector2i(34, 24)), "Roadside water blocks its cells")
	pass_cliff.position = orig + Vector2(64, 0)
	map.call("rebuild_navigation_and_minimap")
	_check(not grid.is_walkable(Vector2i(31, 24)) and not grid.is_walkable(Vector2i(32, 24)), "Sliding PassCliff in closes the lane")
	pass_cliff.position = orig
	map.call("rebuild_navigation_and_minimap")
	var path := grid.find_path(Vector2i(31, 21), Vector2i(31, 26), null, false)
	var direct := false
	for c in path:
		if c.y == 24 and (c.x == 31 or c.x == 32):
			direct = true
	_check(direct, "Restored passage opens the direct route")
	if capture:
		map.call("focus_view", 2)
		await _save_still("03_roadside_pool_and_fork_hd")

	var blue_tank := map.get_node("YSortWorld/BlueTank") as RtsCarbonUnit
	var blue_cmd := map.get_node("YSortWorld/BlueCommander") as RtsCarbonUnit
	var blue_sq1 := map.get_node("YSortWorld/BlueSquad1") as RtsCarbonUnit
	var blue_sq2 := map.get_node("YSortWorld/BlueSquad2") as RtsCarbonUnit
	var blue_sq3 := map.get_node("YSortWorld/BlueSquad3") as RtsCarbonUnit
	var red_tank := map.get_node("YSortWorld/RedTank") as RtsCarbonUnit
	var red_sq1 := map.get_node("YSortWorld/RedSquad1") as RtsCarbonUnit

	blue_sq2.position = Vector2(216, 336)
	blue_sq2.command_move(Vector2(392, 368))
	_advance_sim(map, 3.2)
	_check(blue_sq2.position.x > 360.0, "Squad walks past the HQ (x=%.1f)" % blue_sq2.position.x)
	if capture:
		map.set_selection([])
		map.set_camera_focus(Vector2(348, 304))
		await _save_still("04_blue_headquarters_and_squad_hd")

	blue_tank.position = Vector2(304, 528)
	blue_tank.hull_angle = Vector2(1.0, 1.2).angle()
	blue_tank.turret_angle = blue_tank.hull_angle
	blue_tank.command_move(Vector2(456, 744))
	red_tank.position = Vector2(1008, 672)
	red_tank.hull_angle = PI * 0.5
	red_tank.turret_angle = PI * 0.5
	red_tank.command_move(Vector2(1024, 848))
	var tree := map.get_node("YSortWorld/RoadsidePool/BankTree") as RtsCarbonPiece
	# Stand the squad on the nearest walkable cell under the crown (the trunk sits among boulders).
	var under := tree.global_position + Vector2(0, -16)
	var best := INF
	for oy in range(-40, 4, 4):
		for ox in range(-40, 41, 4):
			var pt := tree.global_position + Vector2(ox, oy)
			if grid.is_walkable(grid.cell_of(pt)) and Vector2(ox, oy).length() < best:
				best = Vector2(ox, oy).length()
				under = grid.center_of(grid.cell_of(pt))
	blue_sq3.position = under
	blue_sq3.command_stop()
	map.set_selection([blue_sq3])
	_advance_sim(map, 4.4)
	_check(map.disturbed_tread_pixels > 110, "Tank leaves twin tracks across the forked dune (%d px)" % map.disturbed_tread_pixels)
	_check(red_tank.position.y > 815.0, "Red tank drives through the roadside passage (%s)" % str(red_tank.position.round()))
	_check(tree.modulate.a < 0.60, "Tree crown fades over a selected squad (alpha=%.2f)" % tree.modulate.a)
	if capture:
		map.set_selection([])
		map.call("focus_view", 3)
		await _save_still("05_forked_dune_treads_hd")

	blue_sq1.take_damage(36, red_sq1)
	_check(blue_sq1.fit_count() == 3, "Wounded squad drops to 3 of 4")
	blue_cmd.position = blue_sq1.position + Vector2(28, 0)
	blue_cmd.cast_mend()
	_check(blue_sq1.fit_count() == 4, "Mend restores the squad to 4 of 4")

	map.reset_encounter()
	await process_frame
	_check(map.get_living_units().size() == UNIT_NAMES.size(), "Reset restores all ten forces")
	map.queue_free()
	await process_frame


# --- HUD styles ------------------------------------------------------------------------------------

func _click_hud(map: RtsCarbonBattlefield, virtual_pt: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var hud := map.hud
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = button
		mb.pressed = pressed
		mb.position = virtual_pt * hud.ui_scale()
		hud._on_panel_gui_input(mb)


func _verify_hud_styles(map: RtsCarbonBattlefield, capture: bool) -> void:
	var hud := map.hud as RtsMissionHud
	_check(hud != null, "Mission 1 uses the switchable RtsMissionHud")
	if hud == null:
		return
	var commander := map.get_node("YSortWorld/BlueCommander") as RtsCarbonUnit
	var zoom_ref := -1.0
	for st in ["classic", "holo", "placeholder"]:
		map.call("set_hud_style", st)
		map.set_selection([commander])
		map.call("focus_view", 0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		if zoom_ref < 0.0:
			zoom_ref = map.camera.zoom.x
		_check(absf(map.camera.zoom.x - zoom_ref) < 0.001, "%s HUD keeps the same battlefield scale" % st)
		_check(hud._btn_rects.has("cmd_move") and hud._btn_rects.has("cmd_mend"), "%s HUD draws the four command buttons" % st)
		if hud._btn_rects.has("cmd_attack"):
			hud.command_cursor_mode = ""
			_click_hud(map, (hud._btn_rects["cmd_attack"] as Rect2).get_center())
			_check(hud.command_cursor_mode == "attack", "%s HUD: clicking Attack arms an attack order" % st)
			hud.command_cursor_mode = ""
		var before := map.hud.camera_world_rect.get_center()
		_click_hud(map, hud._minimap_rect.position + hud._minimap_rect.size * Vector2(0.85, 0.2))
		_check(map.hud.camera_world_rect.get_center().distance_to(before) > 60.0, "%s HUD: clicking the minimap pans the camera" % st)
		map.call("focus_view", 0)
		var centre := map.get_viewport().get_visible_rect().size * 0.5
		_check(not hud.consumes_screen_point(centre), "%s HUD leaves the battlefield centre clickable" % st)
		if capture:
			await process_frame
			await _save_still("07_hud_%s_hd" % st)
	map.call("set_hud_style", "classic")
	map.set_selection([])


# --- Before/after against Reusable 4 --------------------------------------------------------------

func _capture_comparisons() -> void:
	for pair in [[R4_PATH, "r4"], [SCENE_PATH, "mission"]]:
		var map := await _load_map(pair[0])
		map.set_process(false)
		map.close_zoom = false
		map.apply_zoom_framing()
		map.set_selection([])
		map.set_camera_focus(Vector2(1040, 232))
		await _save_still("cmp_spring_%s" % pair[1])
		map.set_camera_focus(Vector2(348, 304))
		await _save_still("cmp_hq_%s" % pair[1])
		for i in UNIT_NAMES.size():
			var unit := map.world_ysort.get_node(UNIT_NAMES[i]) as RtsCarbonUnit
			unit.selected = false
			unit.position = LINEUP[i]
			unit.facing = Vector2(0.82, 0.57).normalized() if unit.team == RtsCarbonUnit.Team.BLUE else Vector2(-0.82, -0.57).normalized()
			if i in [8, 9]:
				unit.health = floori(float(unit.max_health) * 0.70)
			unit.queue_redraw()
		map.set_camera_focus(Vector2(444, 434))
		await _save_still("cmp_units_%s" % pair[1])
		map.queue_free()
		await process_frame


# --- Moving sequence ------------------------------------------------------------------------------

func _record_moving_sequence() -> void:
	var abs_frames := ProjectSettings.globalize_path(FRAME_DIR)
	DirAccess.make_dir_recursive_absolute(abs_frames)
	for f in DirAccess.get_files_at(abs_frames):
		DirAccess.remove_absolute(abs_frames.path_join(f))
	var map := await _load_map(SCENE_PATH)
	var n := func(name: String) -> RtsCarbonUnit: return map.get_node("YSortWorld/" + name) as RtsCarbonUnit
	map.close_zoom = false
	map.apply_zoom_framing()
	map.set_selection([])
	n.call("BlueSquad2").position = Vector2(192, 316)
	n.call("BlueSquad2").command_move(Vector2(476, 408))
	n.call("BlueCommander").command_move(Vector2(544, 434))
	n.call("BlueSquad1").command_move(Vector2(536, 488))
	n.call("BlueSquad3").command_move(Vector2(576, 368))
	n.call("RedSquad1").command_move(Vector2(752, 476))
	n.call("RedCommander").command_move(Vector2(784, 516))
	n.call("RedSquad2").command_move(Vector2(744, 540))
	for f in range(360):
		if f == 95:
			var bt: RtsCarbonUnit = n.call("BlueTank")
			bt.position = Vector2(304, 520)
			bt.hull_angle = Vector2(0.9, 1.1).angle()
			bt.turret_angle = bt.hull_angle
			bt.command_move(Vector2(468, 748))
		if f == 215:
			var rt: RtsCarbonUnit = n.call("RedTank")
			rt.position = Vector2(984, 632)
			rt.hull_angle = Vector2(0.2, 1.0).angle()
			rt.turret_angle = rt.hull_angle
			rt.command_move(Vector2(1024, 852))
		var cam := Vector2(452, 368)
		if f >= 105 and f < 225:
			cam = Vector2(452, 368).lerp(Vector2(512, 548), smoothstep(105.0, 155.0, float(f)))
		elif f >= 225:
			cam = Vector2(512, 548).lerp(Vector2(1036, 696), smoothstep(225.0, 270.0, float(f)))
		map.set_camera_focus(cam)
		_advance_sim(map, 1.0 / 30.0, 1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_jpg(abs_frames.path_join("%05d.jpg" % f), 0.94)
	print("RECORDED 360 frames to ", abs_frames)
	map.queue_free()
	await process_frame


# --- Developers Page ------------------------------------------------------------------------------

func _verify_catalog_and_esc() -> void:
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
		_check(is_instance_valid(card_button), "Developers Page card for " + path.get_file())
		if not is_instance_valid(card_button):
			continue
		card_button.pressed.emit()
		await scene_changed
		await process_frame
		_check(current_scene != null and current_scene.scene_file_path == path, "Card launched " + path.get_file())
		var esc := InputEventKey.new()
		esc.pressed = true
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		Input.parse_input_event(esc)
		await scene_changed
		await process_frame
		_check(current_scene != null and current_scene.get_node("%Library").visible, "Esc returned from " + path.get_file())
	if current_scene != null:
		current_scene.queue_free()
		await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("ALL RTS MISSION 1 CHECKS PASSED")
		quit(0)
	else:
		printerr("RTS MISSION 1 FAILED (%d): %s" % [_failures.size(), ", ".join(_failures)])
		quit(1)
