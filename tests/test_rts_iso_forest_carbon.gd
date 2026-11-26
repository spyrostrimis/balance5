extends SceneTree
## Automated verification, Forward+ 1376x768 stills, gameplay clip recorder, and
## Developers Page catalog loop check for 'RTS Isometric 2— Forest Claim Carbon'.

const SCENE_A := "res://scenes/maps/rts_isometric_2_forest_claim_carbon.tscn"
const SCENE_B := "res://scenes/maps/rts_isometric_2_forest_claim_carbon_layout_b.tscn"
const OPENING_SCENE := "res://scenes/ui/opening_screen.tscn"
const CAP_DIR := "res://render_captures/rts_iso_forest_carbon/"
const CLIP_DIR := "res://tmp/rts_iso_forest_carbon/frames/"

var _failures: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--catalog" in args:
		call_deferred("_run_catalog_check")
	elif "--clip" in args:
		call_deferred("_run_clip_capture")
	else:
		call_deferred("_run_suite", "--stills" in args)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("FAIL: ", msg)


func _step_sim(bf: RtsIsoBattlefield, seconds: float, dt := 1.0 / 60.0) -> void:
	var steps := int(round(seconds / dt))
	for _i in range(steps):
		for u in bf.get_living_units():
			u.tick(dt)
		bf._process(dt)


func _find_unit(bf: RtsIsoBattlefield, uname: String) -> RtsIsoUnit:
	for u in bf.get_living_units():
		if u.name == uname:
			return u
	return null


func _save_png(stem: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(CAP_DIR + stem + ".png"))


func _run_suite(capture_stills: bool) -> void:
	if capture_stills:
		root.size = Vector2i(1376, 768)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAP_DIR))
		await process_frame

	var packed_a := load(SCENE_A) as PackedScene
	var packed_b := load(SCENE_B) as PackedScene
	_check(packed_a != null and packed_b != null, "Both Layout A and Layout B scenes load")
	if packed_a == null or packed_b == null:
		quit(1)
		return

	var bf := packed_a.instantiate() as RtsIsoBattlefield
	if bf == null:
		printerr("FAIL: Could not instantiate RtsIsoBattlefield")
		quit(1)
		return
	root.add_child(bf)
	await process_frame
	await process_frame

	for u in bf.get_living_units():
		u.set_physics_process(false)

	# 1. Single consistent coordinate conversion round-trip (screen <-> map <-> minimap)
	for test_cell: Vector2i in [Vector2i(8, 8), Vector2i(17, 18), Vector2i(24, 25), Vector2i(10, 24)]:
		var mp := RtsIsoTransform.center_of(test_cell)
		var iso := RtsIsoTransform.map_to_iso(mp)
		var back_mp := RtsIsoTransform.iso_to_map(iso)
		_check(mp.distance_to(back_mp) < 0.02, "map_to_iso/iso_to_map exact round-trip at %s" % str(test_cell))
		var muv := RtsIsoTransform.map_to_minimap_uv(mp)
		var mm_back := RtsIsoTransform.minimap_uv_to_map(muv)
		_check(mp.distance_to(mm_back) < 0.05, "minimap UV round-trip exact at %s" % str(test_cell))

	# 2. Apparent unit size invariance (near vs far edge) & 4-corner + cliff-side clicking at BOTH zooms
	for zoom_flag: bool in [false, true]:
		bf.close_zoom = zoom_flag
		bf.apply_zoom_framing()
		await process_frame
		var z_name := "Close" if zoom_flag else "Command"

		# Apparent height of identical unit vector (0, -34 iso px) at far North vs near South
		var far_top := bf.map_to_screen(RtsIsoTransform.center_of(Vector2i(12, 8)))
		var far_head := RtsIsoTransform.ISO * RtsIsoTransform.center_of(Vector2i(12, 8)) + Vector2(0, -34.0)
		var far_h_px := far_top.distance_to(bf.get_canvas_transform() * far_head)

		var near_bot := bf.map_to_screen(RtsIsoTransform.center_of(Vector2i(22, 25)))
		var near_head := RtsIsoTransform.ISO * RtsIsoTransform.center_of(Vector2i(22, 25)) + Vector2(0, -34.0)
		var near_h_px := near_bot.distance_to(bf.get_canvas_transform() * near_head)
		_check(absf(far_h_px - near_h_px) < 0.05, "%s zoom keeps apparent unit size identical near vs far (%.2f vs %.2f px)" % [z_name, far_h_px, near_h_px])

		# Four corners of playable screen rect -> screen_to_map -> map_to_screen consistency
		var play := bf.hud.playable_screen_rect().grow(-28.0)
		for corner_scr: Vector2 in [
			play.position,
			Vector2(play.end.x, play.position.y),
			Vector2(play.position.x, play.end.y),
			play.end,
		]:
			var picked_map := bf.screen_to_map(corner_scr)
			var reprojected := bf.map_to_screen(picked_map)
			_check(corner_scr.distance_to(reprojected) < 0.1, "%s zoom 4-corner pick round-trips at %s" % [z_name, str(corner_scr.round())])

		# Clicking right beside the raised central bluff (14,21 -> walkable neighbor 14,19) & shelf rim (14,28 -> walkable 14,27)
		for safe_cell: Vector2i in [Vector2i(14, 19), Vector2i(14, 27)]:
			_check(bf.grid.is_walkable(safe_cell), "%s zoom cliff-adjacent cell %s is walkable" % [z_name, str(safe_cell)])
			var scr_pt := bf.map_to_screen(RtsIsoTransform.center_of(safe_cell))
			var resolved_cell := RtsIsoTransform.cell_of(bf.screen_to_map(scr_pt))
			_check(resolved_cell == safe_cell, "%s zoom click beside cliff resolves exact cell %s" % [z_name, str(safe_cell)])

	bf.close_zoom = false
	bf.apply_zoom_framing()

	# 3. Verify trunk blocks while overhanging tree canopy is walkable AND fades smoothly
	_check(not bf.grid.is_walkable(Vector2i(7, 15)), "Hero Buttress Tree trunk blocks tank/unit cell (7,15)")
	_check(bf.grid.is_walkable(Vector2i(6, 13)), "Ground under overhanging Hero Tree canopy (6,13) is walkable")
	var sq1 := _find_unit(bf, "BlueSquad1")
	_check(sq1 != null, "BlueSquad1 exists")
	sq1.peaceful = true
	sq1.map_pos = RtsIsoTransform.center_of(Vector2i(6, 14))
	sq1.position = RtsIsoTransform.map_to_iso(sq1.map_pos)
	bf.set_selection([sq1])
	_step_sim(bf, 0.6)
	var hero_mod: RtsIsoModule = null
	for m in bf._tree_modules:
		if m.piece_id == "tree_hero_buttress":
			hero_mod = m
			break
	_check(hero_mod != null and hero_mod.crown_alpha < 0.62, "Overhanging canopy fades when selected squad stands beneath (alpha=%.2f)" % (hero_mod.crown_alpha if hero_mod != null else -1.0))

	# Reset Layout A cleanly for live capture & Tank Route A check
	bf.load_layout(0)
	for u in bf.get_living_units():
		u.set_physics_process(false)
		u.peaceful = true

	var tank_a := _find_unit(bf, "BlueTank")
	var cmd_a := _find_unit(bf, "BlueCommander")
	var sq1_a := _find_unit(bf, "BlueSquad1")
	var sq2_a := _find_unit(bf, "BlueSquad2")

	# Advance units onto both approaches while keeping the opening crystal uncontested for clear reading!
	sq1_a.command_move(RtsIsoTransform.center_of(Vector2i(11, 17)))  # NW Rooted Canopy Trail
	cmd_a.command_move(RtsIsoTransform.center_of(Vector2i(10, 22)))
	sq2_a.command_move(RtsIsoTransform.center_of(Vector2i(15, 25)))
	tank_a.command_move(RtsIsoTransform.center_of(Vector2i(21, 22))) # SE Cliff-Rim Tank Road!
	bf.set_selection([cmd_a])

	# Record tank's southern route in Layout A
	var max_v_layout_a := tank_a.cell.y
	for _s in range(26):
		_step_sim(bf, 0.25)
		max_v_layout_a = maxi(max_v_layout_a, tank_a.cell.y)

	_check(max_v_layout_a >= 23, "Layout A tank uses SE Cliff-Rim Road (max cell.y=%d)" % max_v_layout_a)
	_check(bf.disturbed_tread_pixels > 30, "Tank stamps dual tracks on forest earth (%d px)" % bf.disturbed_tread_pixels)

	if capture_stills:
		bf.close_zoom = false
		bf.apply_zoom_framing()
		bf.set_camera_focus_map(Vector2(16.8, 19.4) * RtsIsoTransform.CELL_SIZE)
		await _save_png("01_layout_a_command_hud")

		# Close view: squad passing directly beneath Hero Buttress Tree canopy (showing translucent crown fade!) & Commander beside mossy bluff!
		sq1_a.map_pos = RtsIsoTransform.center_of(Vector2i(6, 14))
		sq1_a.position = RtsIsoTransform.map_to_iso(sq1_a.map_pos)
		sq1_a.command_move(RtsIsoTransform.center_of(Vector2i(8, 13)))
		cmd_a.map_pos = RtsIsoTransform.center_of(Vector2i(10, 20))
		cmd_a.position = RtsIsoTransform.map_to_iso(cmd_a.map_pos)
		cmd_a.command_stop()
		bf.set_selection([sq1_a, cmd_a])
		_step_sim(bf, 0.45)
		bf.close_zoom = true
		bf.apply_zoom_framing()
		bf.set_camera_focus_map(Vector2(10.2, 17.5) * RtsIsoTransform.CELL_SIZE)
		await _save_png("02_layout_a_close_squad_tree_cliff")

		bf.close_zoom = false
		bf.apply_zoom_framing()
		bf.set_camera_focus_map(Vector2(16.8, 19.4) * RtsIsoTransform.CELL_SIZE)
		bf.grid.show_debug = true
		bf.show_seam_debug = true
		for m in bf._modules:
			m.show_seam_debug = true
			m.queue_redraw()
		bf._overlay_layer.queue_redraw()
		await _save_png("03_layout_a_footprints_and_pieces")
		bf.grid.show_debug = false
		bf.show_seam_debug = false

	# 4. Layout B Modularity Proof: EXACT same kit catalog, SE road closed, Tank reroutes North!
	var pieces_a := RtsIsoKit.all_piece_ids()
	bf.load_layout(1)
	for u in bf.get_living_units():
		u.set_physics_process(false)
		u.peaceful = true

	_check(bf.active_layout_index == 1, "Switched to Layout B")
	_check(RtsIsoKit.all_piece_ids() == pieces_a, "Layout B uses exact same RtsIsoKit catalog")
	_check(not bf.grid.is_walkable(Vector2i(19, 25)) and not bf.grid.is_walkable(Vector2i(22, 27)),
		"Moved L-bluff seals former SE cliff-rim road in Layout B")
	_check(bf.grid.is_walkable(Vector2i(14, 21)), "Former Layout A central bluff cell (14,21) is now open in Layout B")

	var tank_b := _find_unit(bf, "BlueTank")
	var sq1_b := _find_unit(bf, "BlueSquad1")
	var cmd_b := _find_unit(bf, "BlueCommander")
	# Order Tank along the newly opened Northern Woodland Flank (10,14 -> 17,12 -> 20,15)!
	tank_b.command_move(RtsIsoTransform.center_of(Vector2i(17, 13)))
	sq1_b.command_move(RtsIsoTransform.center_of(Vector2i(14, 18)))
	cmd_b.command_move(RtsIsoTransform.center_of(Vector2i(12, 20)))
	bf.set_selection([tank_b, cmd_b, sq1_b])

	var min_v_layout_b := tank_b.cell.y
	for _s in range(46):
		_step_sim(bf, 0.25)
		min_v_layout_b = mini(min_v_layout_b, tank_b.cell.y)

	_check(min_v_layout_b <= 15 and tank_b.map_pos.distance_to(bf._orichalcum_map_pos) <= 185.0,
		"Layout B tank reaches Orichalcum via new Northern flank (min cell.y=%d, dist=%.1f)" % [min_v_layout_b, tank_b.map_pos.distance_to(bf._orichalcum_map_pos)])

	if capture_stills:
		bf.close_zoom = false
		bf.apply_zoom_framing()
		bf.set_camera_focus_map(Vector2(16.8, 19.4) * RtsIsoTransform.CELL_SIZE)
		await _save_png("04_layout_b_command_hud")

		bf.grid.show_debug = true
		bf.show_seam_debug = true
		for m in bf._modules:
			m.show_seam_debug = true
			m.queue_redraw()
		bf._overlay_layer.queue_redraw()
		await _save_png("05_layout_b_footprints_and_pieces")
		bf.grid.show_debug = false
		bf.show_seam_debug = false

	# 5. Minimap order landing on the exact intended side of the moved Layout B cliff (19,24)
	var west_side_target := RtsIsoTransform.center_of(Vector2i(16, 24)) # West of moved cliff (u < 19)
	var minimap_uv := RtsIsoTransform.map_to_minimap_uv(west_side_target)
	var decoded_target := RtsIsoTransform.minimap_uv_to_map(minimap_uv)
	bf.set_selection([cmd_b])
	bf.issue_order_at_map(decoded_target)
	_step_sim(bf, 4.8)
	_check(cmd_b.cell.x <= 18 and cmd_b.map_pos.distance_to(west_side_target) < 28.0,
		"Minimap order lands cleanly on intended West side of moved cliff (cell=%s)" % str(cmd_b.cell))

	# 6. Combat, Squad Casualties, Blue Commander Mend & Orichalcum Hold Timer
	for u in bf.get_living_units():
		u.peaceful = false
	var red1 := _find_unit(bf, "RedSquad1")
	sq1_b.take_damage(40, red1)
	var wounded_fit := sq1_b.fit_count()
	_check(wounded_fit < 4, "Wounded squad reduces fit soldier count (%d/4)" % wounded_fit)
	cmd_b.map_pos = sq1_b.map_pos + Vector2(-20.0, 0.0)
	var healed := cmd_b.cast_mend()
	_check(healed >= 1 and sq1_b.fit_count() > wounded_fit, "Blue Commander Mend heals wounded squad (%d/4 fit)" % sq1_b.fit_count())

	# Uncontested hold timer around Orichalcum
	for u in bf.get_living_units():
		if u.team == RtsIsoUnit.Team.RED:
			u.map_pos = RtsIsoTransform.center_of(Vector2i(24, 9))
			u.command_stop()
			u.peaceful = true
	tank_b.map_pos = RtsIsoTransform.center_of(Vector2i(16, 19))
	tank_b.command_stop()
	var hold_before := bf.hold_seconds_left
	_step_sim(bf, 2.2)
	_check(bf.hold_owner == 1 and bf.hold_seconds_left < hold_before - 1.6,
		"Orichalcum hold timer counts down for Blue (%.1fs left)" % bf.hold_seconds_left)

	# Verify standalone Layout B scene also boots directly into Layout B
	var bf_b := packed_b.instantiate() as RtsIsoBattlefield
	root.add_child(bf_b)
	await process_frame
	_check(bf_b.active_layout_index == 1, "Standalone Layout B scene opens directly in Layout B")
	bf_b.queue_free()

	print("RTS Isometric 2— Forest Claim Carbon suite complete: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _run_clip_capture() -> void:
	root.size = Vector2i(1376, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CLIP_DIR))
	await process_frame

	var packed := load(SCENE_A) as PackedScene
	var bf := packed.instantiate() as RtsIsoBattlefield
	root.add_child(bf)
	await process_frame
	await process_frame

	for u in bf.get_living_units():
		u.set_physics_process(false)
		u.peaceful = true

	var cmd := _find_unit(bf, "BlueCommander")
	var sq1 := _find_unit(bf, "BlueSquad1")
	var sq2 := _find_unit(bf, "BlueSquad2")
	var tank := _find_unit(bf, "BlueTank")

	# Cue ring drawn over HUD minimap during Beat 2 so the viewer clearly sees the minimap order!
	var mm_cue := Control.new()
	mm_cue.set_anchors_preset(Control.PRESET_FULL_RECT)
	mm_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cue_age := -1.0
	var cue_screen_pt := Vector2.ZERO
	mm_cue.draw.connect(func() -> void:
		if cue_age >= 0.0 and cue_age <= 1.1:
			var a := 1.0 - cue_age / 1.1
			mm_cue.draw_arc(cue_screen_pt, lerpf(6.0, 24.0, cue_age / 1.1), 0.0, TAU, 24, Color(0.42, 1.0, 0.65, a), 2.5)
			mm_cue.draw_circle(cue_screen_pt, 4.0, Color(1.0, 0.96, 0.45, a))
	)
	bf.hud.add_child(mm_cue)

	bf.set_selection([])
	bf.set_camera_focus_map(Vector2(14.0, 22.0) * RtsIsoTransform.CELL_SIZE)

	var total_frames := 330  # 11.0 seconds at 30 fps
	var dt := 1.0 / 30.0

	for f in range(total_frames):
		# Beat 1 (frames 8..38): Visible marquee box selection sweeping across all 4 Blue units!
		if f == 8:
			bf._dragging_box = true
			bf._press_screen = Vector2(130, 270)
			bf._drag_screen = Vector2(150, 290)
			bf._overlay_layer.queue_redraw()
		elif f > 8 and f < 38:
			var t := float(f - 8) / 30.0
			bf._drag_screen = Vector2(130, 270).lerp(Vector2(560, 650), t)
			bf._overlay_layer.queue_redraw()
		elif f == 38:
			bf._dragging_box = false
			bf.select_in_screen_box(Rect2(Vector2(130, 270), Vector2(430, 380)), false)
			bf._overlay_layer.queue_redraw()

		# Beat 2 (frame 48): Issue Minimap Move order (with visible minimap pulse!) + Tank rounding the SE cliff!
		elif f == 48:
			var mm_goal := RtsIsoTransform.center_of(Vector2i(16, 16))
			var muv := RtsIsoTransform.map_to_minimap_uv(mm_goal)
			cue_screen_pt = (bf.hud._minimap_rect.position + muv * bf.hud._minimap_rect.size) * bf.hud.ui_scale()
			cue_age = 0.0
			bf.set_selection([sq1, cmd])
			bf.issue_order_at_map(mm_goal)
			# Send Tank & Squad2 rounding the raised West-Central bluff via the SE Cliff-Rim Road!
			tank.command_move(RtsIsoTransform.center_of(Vector2i(21, 19)))
			sq2.command_move(RtsIsoTransform.center_of(Vector2i(19, 20)))
			bf.set_selection([tank, cmd, sq1, sq2])

		if cue_age >= 0.0:
			cue_age += dt
			mm_cue.queue_redraw()

		# Smooth camera pan following the Tank rounding the cliff into the Orichalcum clearing
		if f >= 55 and f <= 185:
			var ct := smoothstep(55.0, 185.0, float(f))
			var cam_cell := Vector2(14.0, 22.0).lerp(Vector2(18.5, 17.5), ct)
			bf.set_camera_focus_map(cam_cell * RtsIsoTransform.CELL_SIZE)

		# Beat 3 (frame 155): Activate Red Skirmish AI & engage in full battle at the Orichalcum crystal!
		if f == 155:
			bf.red_ai_active = true
			for u in bf.get_living_units():
				u.peaceful = false
			var red_lead := _find_unit(bf, "RedSquad1")
			if red_lead != null:
				tank.command_attack(red_lead)
				sq1.command_attack(red_lead)
				sq2.command_attack(red_lead)

		# Beat 4 (frame 235): Blue Commander casts cyan Mend healing pulse mid-fight!
		if f == 235 and cmd != null and cmd.alive:
			cmd.mend_timer = 0.0
			cmd.cast_mend()

		_step_sim(bf, dt, 1.0 / 60.0)
		await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_jpg(ProjectSettings.globalize_path(CLIP_DIR + ("%05d.jpg" % f)), 0.92)

	print("Saved %d clip frames to %s" % [total_frames, CLIP_DIR])
	quit(0)


func _run_catalog_check() -> void:
	change_scene_to_file(OPENING_SCENE)
	for _i in range(6):
		await process_frame
	var opening := current_scene
	_check(opening != null, "Opening screen loaded")
	var found_card: Resource = null
	if opening != null and "builds" in opening:
		for b in opening.builds:
			if b != null and b.scene_path == SCENE_A:
				found_card = b
				break
	_check(found_card != null, "Developers Page catalog contains RTS Isometric 2— Forest Claim Carbon card")
	if found_card != null:
		var launcher := root.get_node_or_null("BuildLauncher")
		_check(launcher != null, "BuildLauncher autoload exists")
		if launcher != null:
			var err: int = launcher.launch(found_card)
			_check(err == OK, "BuildLauncher launched study cleanly")
			for _i in range(6):
				await process_frame
			_check(current_scene is RtsIsoBattlefield, "Active scene is RtsIsoBattlefield")
			# Simulate Esc return via BuildLauncher
			launcher._return_to_developers_page()
			for _i in range(6):
				await process_frame
			_check(current_scene != null and current_scene.scene_file_path == OPENING_SCENE, "Esc returned cleanly to Developers Page")

	print("Catalog loop check complete: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
