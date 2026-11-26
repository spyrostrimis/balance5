extends SceneTree

const MAP := "res://scenes/maps/rts_reusable_3.tscn"
const CARBON := "res://scenes/maps/rts_reusable_2_carbon.tscn"
const KIT := "res://scenes/rts/reusable_3/kit_preview.tscn"
const OPENING := "res://scenes/ui/opening_screen.tscn"
const CAPTURE := "res://render_captures/rts_reusable_3"
const Unit := preload("res://scripts/rts_carbon/rts_carbon_unit.gd")

var _failures := 0
var _capture := false
var _record := false


func _initialize() -> void:
	_capture = "--capture" in OS.get_cmdline_user_args()
	_record = "--record" in OS.get_cmdline_user_args()
	call_deferred("_run")


func _run() -> void:
	if _capture or _record:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE))
	_check(Engine.get_version_info().major == 4, "Godot 4 runtime")
	await _check_narrow_pass()
	var map := _load_map()
	await _check_map(map)
	map.queue_free()
	await process_frame
	if _record:
		await _moving_shots()
	await _check_catalog()
	print("RTS Reusable 3: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _load_map(cliff_shift := 0.0) -> RtsCarbonBattlefield:
	var map := (load(MAP) as PackedScene).instantiate() as RtsCarbonBattlefield
	var cliff := map.get_node("YSortWorld/RoadsidePool/PassCliff") as RtsCarbonPiece
	cliff.position.x += cliff_shift
	root.add_child(map)
	map.set_process(false)
	map.set_selection([])
	for unit in map.get_living_units():
		unit.set_physics_process(false)
		unit.peaceful = true
	return map


func _check_narrow_pass() -> void:
	var narrow := _load_map(42.0)
	_check(not narrow.grid.is_walkable(narrow.grid.cell_of(Vector2(1008, 816))),
		"Sliding PassCliff inward closes the straight tank lane")
	if _capture:
		narrow.set_camera_focus(Vector2(1060, 731))
		narrow.grid.show_debug = true
		await _png("roadside_narrow_grid")
	narrow.queue_free()
	await process_frame


func _check_map(map: RtsCarbonBattlefield) -> void:
	var hq := map.world_ysort.get_node("BlueFieldHeadquarters") as RtsCarbonPiece
	var spring := map.world_ysort.get_node("ShelteredSpring")
	var pool := map.world_ysort.get_node("RoadsidePool")
	for landmark: RtsCarbonPiece in [hq, spring.get_node("Water"), spring.get_node("CliffLedge"), pool.get_node("Water")]:
		_check(not landmark.blocked_poly.is_empty(), "%s has its own footprint" % landmark.get_path())
		var probe := landmark.to_global(landmark.blocked_poly[0].lerp(landmark.blocked_poly[5], 0.5))
		_check(not map.grid.is_walkable(map.grid.cell_of(probe)), "%s blocks its pictured ground" % landmark.name)
	var tree := spring.get_node("SpringTree") as RtsCarbonPiece
	_check(tree.blocks_world_point(tree.global_position)
		and not tree.blocks_world_point(tree.global_position + Vector2(24, -22)), "Tree blocks the trunk, while the canopy overhang stays open")
	for at in [Vector2(1104, 784), Vector2(1136, 784), Vector2(1104, 816), Vector2(1136, 816)]:
		_check(not map.grid.is_walkable(map.grid.cell_of(at)), "The roadside pool covers wet ground at %s" % at)
	var objective_count := 0
	for piece in map._pieces:
		objective_count += int(piece.is_orichalcum)
		_check(piece.texture != null, "%s loads Detailed art" % piece.name, false)
	_check(objective_count == 1 and map._orichalcum_pos == Vector2(656, 444), "Original outcrop is the only objective")
	_check(map.get_living_units().size() == 10 and not map.red_ai_active, "Original troop count and Guard opening")
	_check(is_equal_approx(map.hud.camera_world_rect.size.x / 32.0, 21.0), "Command zoom is 21 cells wide")
	if _capture:
		await _png("play_command")
		map.set_camera_focus(spring.global_position + Vector2(0, 50))
		await _png("sheltered_spring")
		map.set_camera_focus(pool.global_position + Vector2(-64, -65))
		await _png("roadside_pool")
	map.close_zoom = true
	map.apply_zoom_framing()
	_check(is_equal_approx(map.hud.camera_world_rect.size.x / 32.0, 15.0), "Close zoom is 15 cells wide")
	map.apply_visual_mode(true)
	for piece in map._pieces:
		_check(piece.texture != null, "%s loads its Pixel art" % piece.name, false)
	if _capture:
		await _png("roadside_pixel_close")
	map.apply_visual_mode(false)
	map.close_zoom = false
	map.apply_zoom_framing()

	var tank := _unit(map, "BlueTank")
	var squad := _unit(map, "BlueSquad2")
	var commander := _unit(map, "BlueCommander")
	_move(map, squad, Vector2(272, 336), Vector2(440, 336))
	_check(_travel(map, squad, Vector2(440, 336), 4.0), "Squad passes the HQ entrance along the road")
	_reposition(map, commander, Vector2(432, 371))
	squad.take_damage(ceili(squad.max_health * 0.31) + squad.armour, null)
	_check(squad.fit_count() == 3 and commander.cast_mend() == 1 and squad.fit_count() == 4,
		"Mend restores the fourth visible soldier")

	const DUNE_START := Vector2(432, 500)
	const DUNE_END := Vector2(432, 638)
	_move(map, tank, DUNE_START, DUNE_END)
	_check(_travel(map, tank, DUNE_END, 4.2), "Tank drives through the new forked dune crest")
	var tread_columns := 0
	for x in range(208, 224):
		if map._tread_img.get_pixel(x, 286).r > 0.65:
			tread_columns += 1
	_check(tread_columns >= 2 and map._tread_img.get_pixel(216, 286).r < 0.35,
		"Fresh lanes stay separate through the painted fork")
	if _capture:
		map.set_camera_focus(Vector2(502, 575))
		await _png("fork_dune_treads")
		map.show_treads = false
		map.apply_visual_mode(false)
		await _png("fork_dune_treads_off")
		map.show_treads = true
		map.apply_visual_mode(false)
		map.set_camera_focus(Vector2(548, 240))
		await _png("long_dune_field")
		map.set_camera_focus(Vector2(400, 348))
		await _png("blue_headquarters")

	const PASS_START := Vector2(1008, 688)
	const PASS_END := Vector2(1008, 863)
	_move(map, tank, PASS_START, PASS_END)
	_check(tank._line_walkable(PASS_START, PASS_END), "Widened arrangement clears the direct route with tank-width clearance")
	_check(_travel(map, tank, PASS_END, 3.7, true), "Tank drives directly between the visible banks without entering water or cliff")
	if _capture:
		map.set_camera_focus(Vector2(1060, 731))
		await _png("tank_through_roadside_pass")
		map.grid.show_debug = true
		await _png("roadside_open_grid")
		map.grid.show_debug = false

	# Exercise the inherited minimap order, encounter reset, combat and objective.
	map.set_selection([tank])
	map.hud.minimap_order_requested.emit(Vector2(1072, 816))
	_check(tank.order == Unit.Order.MOVE, "Minimap issues a move order")
	map.reset_encounter()
	await process_frame
	_check(map.get_living_units().size() == 10 and map.disturbed_tread_pixels == 0, "Retry rebuilds the troop roster and clears tracks")
	for unit in map.get_living_units():
		unit.set_physics_process(false)
		unit.peaceful = true
		if unit.team == Unit.Team.RED:
			unit.position = Vector2(1264, 800)
	tank = _find(map, Unit.Team.BLUE, Unit.Role.TANK)
	var red := _find(map, Unit.Team.RED, Unit.Role.TANK)
	_reposition(map, tank, Vector2(656, 528))
	red.position = Vector2(750, 535)
	tank.command_attack(red)
	tank.tick(0.05)
	_check(red.health < red.max_health, "Tank fires and damages an enemy")
	map._tick_objective(1.0)
	_check(map.hud.hold_state.begins_with("Contested"), "Both sides contest the central outcrop")
	red.position = Vector2(1264, 800)
	map._tick_objective(2.0)
	_check(map.hold_owner == 1 and is_equal_approx(map.hold_seconds_left, 28.0), "Blue starts the original 30-second hold")


func _moving_shots() -> void:
	var map := _load_map()
	map.set_camera_focus(Vector2(458, 416))
	var blue := _unit(map, "BlueSquad1")
	var red := _unit(map, "RedSquad1")
	var commander := _unit(map, "BlueCommander")
	_move(map, blue, Vector2(432, 338), Vector2(432, 505))
	_move(map, red, Vector2(501, 495), Vector2(501, 341))
	_move(map, commander, Vector2(401, 330), Vector2(401, 487))
	var red_wounded := _unit(map, "RedSquad2")
	_reposition(map, red_wounded, Vector2(537, 476))
	red_wounded.health = floori(red_wounded.max_health * 0.7)
	red_wounded.queue_redraw()
	await _record_shot(map, "01_crossing", 120)
	_check(blue.position.is_equal_approx(Vector2(432, 505)) and red.position.is_equal_approx(Vector2(501, 341)),
		"Both factions cross the road under their own move orders")

	map.set_camera_focus(Vector2(397, 333))
	var hq_squad := _unit(map, "BlueSquad2")
	_move(map, hq_squad, Vector2(267, 338), Vector2(440, 338))
	await _record_shot(map, "02_headquarters", 119)
	_check(hq_squad.position.is_equal_approx(Vector2(440, 338)), "Recorded squad clears the HQ entrance")

	map.set_camera_focus(Vector2(1060, 719))
	var tank := _unit(map, "RedTank")
	_move(map, tank, Vector2(1008, 687), Vector2(1008, 864))
	await _record_shot(map, "03_roadside_pool", 122)
	_check(tank.position.is_equal_approx(Vector2(1008, 864)), "Recorded tank clears the roadside bank")
	map.queue_free()
	await process_frame


func _unit(map: RtsCarbonBattlefield, unit_name: String) -> Unit:
	return map.world_ysort.get_node(unit_name) as Unit


func _find(map: RtsCarbonBattlefield, team: Unit.Team, role: Unit.Role) -> Unit:
	for unit in map.get_living_units():
		if unit.team == team and unit.role == role:
			return unit
	return null


func _reposition(map: RtsCarbonBattlefield, unit: Unit, pos: Vector2) -> void:
	unit.command_stop()
	map.grid.release(unit._claimed_cell, unit)
	unit.position = pos
	unit.cell = map.grid.cell_of(pos)
	unit._claimed_cell = unit.cell
	_check(map.grid.claim(unit.cell, unit), "Test start free at %s" % pos, false)
	unit.queue_redraw()


func _move(map: RtsCarbonBattlefield, unit: Unit, start: Vector2, finish: Vector2) -> void:
	_reposition(map, unit, start)
	unit.facing = (finish - start).normalized()
	unit.hull_angle = unit.facing.angle()
	unit.turret_angle = unit.hull_angle
	unit.command_move(finish)


func _travel(map: RtsCarbonBattlefield, unit: Unit, goal: Vector2, seconds: float, check_banks := false) -> bool:
	var clear := true
	for i in int(seconds * 60):
		unit.tick(1.0 / 60.0)
		map._tick_fx_and_treads(1.0 / 60.0)
		if check_banks:
			for piece in map._pieces:
				for lateral in [-11.0, 0.0, 11.0]:
					clear = clear and not piece.blocks_world_point(unit.position + Vector2(lateral, 0))
		if unit.position.distance_to(goal) < 0.1:
			break
	return clear and unit.position.distance_to(goal) < 0.1


func _check_catalog() -> void:
	_check(change_scene_to_file(OPENING) == OK, "Developers Page is available")
	await scene_changed
	current_scene.get_node("%DevelopersPage").pressed.emit()
	for path in [MAP, KIT, CARBON]:
		var card_button: Button
		for section in current_scene.get_node("%Catalog").get_children():
			for card in section.get_children():
				if card.get_meta("catalog_key", "") == path:
					for button in card.find_children("*", "Button", true, false):
						if button.text == ("View" if path == KIT else "Play"):
							card_button = button
		_check(is_instance_valid(card_button), "Catalog button for " + path.get_file())
		if not is_instance_valid(card_button):
			return
		card_button.pressed.emit()
		await scene_changed
		_check(current_scene.scene_file_path == path, "Catalog loads " + path.get_file())
		if path == MAP:
			_check(not root.get_node("BuildLauncher/ReturnButton").visible, "Launch leaves the Command HUD unobstructed")
		if path == KIT and _capture:
			await _png("desert_kit")
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.pressed = true
		Input.parse_input_event(key)
		await scene_changed
		_check(current_scene.get_node("%Library").visible, "Esc returns to Developers Page")


func _png(stem: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_check(frame.save_png(CAPTURE.path_join(stem + ".png")) == OK, "%s saved at %s" % [stem, frame.get_size()])


func _record_shot(map: RtsCarbonBattlefield, stem: String, frames: int) -> void:
	var folder := CAPTURE.path_join(stem)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for i in frames:
		for j in 2:
			for unit in map.get_living_units():
				unit.tick(1.0 / 60.0)
			map._tick_fx_and_treads(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		_check(frame.save_jpg(folder.path_join("%04d.jpg" % i), 0.94) == OK, "Recording frame %d" % i, false)
	print(stem, ": ", frames, " Forward+ frames")


func _check(ok: bool, message: String, report_pass := true) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL  ", message)
	elif report_pass:
		print("PASS  ", message)
