extends SceneTree
## Exercises the same viewport inputs and simulation as the normal Play cards.
const GAME := preload("res://scripts/rts_forest_claim/forest_claim_battlefield.gd")
const A := "res://scenes/rts/forest_claim/forest_claim_a.tscn"
const B := "res://scenes/rts/forest_claim/forest_claim_b.tscn"
const OPENING := "res://scenes/ui/opening_screen.tscn"
const Unit := preload("res://scripts/rts_carbon/rts_carbon_unit.gd")

var game: GAME
var failures := 0


func _initialize() -> void:
	create_timer(100.0).timeout.connect(func() -> void:
		push_error("Forest Claim verification timed out")
		quit(1))
	call_deferred("_run")


func _run() -> void:
	var x := ForestClaimProjection.point(Vector2.RIGHT)
	var y := ForestClaimProjection.point(Vector2.DOWN)
	check(is_equal_approx(x.length(), y.length()) and is_equal_approx(rad_to_deg(x.angle_to(y)), 120.0),
		"fixed isometric axes have equal scale and 120° separation")
	var crossing := []
	for study in [A, B]:
		await _open(study)
		await _inputs()
		await _abilities()
		await _objective()
		await _open(study)
		crossing.append(await _tank_route())
	check(crossing[0] >= 13 and crossing[1] <= 10, "tank crosses the same meridian south in A and north in B")
	await _catalog()
	print("Forest Claim verification: %d failures, crossing rows=%s" % [failures, crossing])
	quit(int(failures > 0))


func _open(path: String) -> void:
	if current_scene != null:
		unload_current_scene()
		await process_frame
	var packed := load(path) as PackedScene
	game = packed.instantiate()
	root.add_child(game)
	current_scene = game
	game.red_ai_active = false
	for unit in game.get_living_units():
		unit.peaceful = true
	await process_frame
	await process_frame


func _inputs() -> void:
	var commander := _unit(Unit.Role.COMMANDER)
	var tank := _unit(Unit.Role.TANK)
	var squad := _unit(Unit.Role.SQUAD)
	check(squad.fit_count() == 4 and game.get_living_units().size() == 6, "each side has commander, four-person squad and tank")
	var standard_zoom: float = game.camera.zoom.x
	var cliff_cell := Vector2i(9, 9) if game.layout.label.begins_with("A") else Vector2i(8, 12)
	var rock: PackedVector2Array = game.landscape._face_points(cliff_cell, Vector2i.RIGHT)
	var face := (rock[0] + rock[1] + rock[2] + rock[3]) / 4.0
	var face_world := ForestClaimProjection.world(face)
	for close in [false, true]:
		if close:
			_key(KEY_Z)
			check(game.camera.zoom.x > standard_zoom, "Z reaches inspection zoom")
		game.set_camera_focus(Vector2(359, 324))
		var near := game.ground_to_screen(Vector2(320, 480)) - game.ground_to_screen(Vector2(288, 480))
		var far := game.ground_to_screen(Vector2(320, 160)) - game.ground_to_screen(Vector2(288, 160))
		check(near.distance_to(far) < 0.005, "apparent distance stays constant at near and far edges")
		var play := game.hud.playable_screen_rect()
		for uv: Vector2 in [Vector2(0.10, 0.12), Vector2(0.90, 0.12), Vector2(0.10, 0.88), Vector2(0.90, 0.88)]:
			var corner := play.position + play.size * uv
			var world := game.screen_to_ground(corner)
			check(game.ground_to_screen(world).distance_to(corner) < 0.005, "corner round trip at close=%s uv=%s" % [close, uv])
			game.set_selection([commander])
			_click(corner, MOUSE_BUTTON_RIGHT)
			if game.grid.is_walkable(game.grid.cell_of(world)) and not game.landscape.hits_cliff(ForestClaimProjection.point(world)):
				check(game._last_order.distance_to(world) < 0.005, "corner order lands in the projected cell")
			else:
				check(game._markers[-1].get("blocked", false), "corner outside the playable shelf rejects orders")
		game.set_camera_focus(face_world)
		var cliff_screen := game.ground_to_screen(face_world)
		_click(cliff_screen, MOUSE_BUTTON_RIGHT)
		check(game._markers[-1].get("blocked", false), "click on the visible face rejects orders")
		var adjacent_cell := cliff_cell + Vector2i.RIGHT
		var adjacent := game.grid.center_of(adjacent_cell)
		game.set_camera_focus(adjacent)
		_click(game.ground_to_screen(adjacent), MOUSE_BUTTON_RIGHT)
		check(game.grid.cell_of(commander.move_goal_world) == adjacent_cell, "click beside cliff chooses exact side at close=%s" % close)
		_key(KEY_S)

	game.close_zoom = false
	game.apply_zoom_framing()
	_key(KEY_1)
	var start := game.ground_to_screen(commander.position).min(game.ground_to_screen(tank.position)) - Vector2(21, 28)
	var end := game.ground_to_screen(commander.position).max(game.ground_to_screen(tank.position)) + Vector2(23, 20)
	_button(start, MOUSE_BUTTON_LEFT, true)
	var motion := InputEventMouseMotion.new()
	motion.position = end
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	_button(end, MOUSE_BUTTON_LEFT, false)
	check(game.selection.size() == 3 and squad in game.selection, "box-select picks all Blue roles")
	_key(KEY_T)
	check(commander.hold_position and squad.hold_position and tank.hold_position, "T holds the selected group")
	_key(KEY_T)
	check(not commander.hold_position, "hold can be released")
	var red := _unit(Unit.Role.SQUAD, Unit.Team.RED)
	_click(game.ground_to_screen(red.position), MOUSE_BUTTON_RIGHT)
	check(commander.target_enemy == red and tank.order == Unit.Order.ATTACK, "projected right-click attacks Red")
	_key(KEY_S)
	check(tank.order == Unit.Order.NONE and squad.order == Unit.Order.NONE, "S cancels the projected attack")

	var featured: Dictionary = game.landscape.scenery[1]
	check(not game.grid.is_walkable(game.grid.cell_of(featured.at)), "the tree trunk blocks navigation")
	var overlap := Vector2.ZERO
	for x_offset in range(-90, 1, 5):
		for z_offset in range(-95, 1, 5):
			var feet := ForestClaimProjection.world(Vector2(featured.anchor) + Vector2(x_offset, z_offset))
			if game.grid.is_walkable(game.grid.cell_of(feet)) and game.landscape.covers(featured, feet):
				overlap = feet
				break
		if overlap != Vector2.ZERO:
			break
	check(overlap != Vector2.ZERO, "painted canopy overhangs walkable cells")
	if overlap != Vector2.ZERO:
		var initial := squad.position
		squad.position = overlap
		squad.sync_visual()
		game.set_selection([squad])
		game._update_canopy_fade(1.0)
		check(is_equal_approx(featured.art.modulate.a, 0.32), "selected squad stays visible under sustained canopy overlap")
		squad.position = initial
		squad.sync_visual()
		game._update_canopy_fade(1.0)
		check(is_equal_approx(featured.art.modulate.a, 1.0), "canopy restores after the squad leaves")


func _abilities() -> void:
	var commander := _unit(Unit.Role.COMMANDER)
	var squad := _unit(Unit.Role.SQUAD)
	squad.take_damage(31, null)
	var damaged := squad.health
	_key(KEY_E)
	check(squad.health == mini(squad.max_health, damaged + 30) and commander.mend_timer > 0.0,
		"Mend heals a nearby squad and starts cooldown")
	var timer := commander.mend_timer
	_key(KEY_E)
	check(is_equal_approx(timer, commander.mend_timer), "Mend cannot recast on cooldown")


func _objective() -> void:
	var blue := _unit(Unit.Role.TANK)
	var red := _unit(Unit.Role.TANK, Unit.Team.RED)
	blue.position = game._orichalcum_pos + Vector2(48, 48)
	game._tick_objective(1.0)
	check(game.hold_owner == 1 and is_equal_approx(game.hold_seconds_left, 29.0), "Blue presence ticks the hold timer")
	red.position = game._orichalcum_pos + Vector2(100, 0)
	game._tick_objective(2.0)
	check(is_equal_approx(game.hold_seconds_left, 29.0) and game.hud.hold_state.begins_with("Contested"), "Red presence pauses the hold")
	blue.position = Vector2(32, 32)
	game._tick_objective(31.0)
	check(game.match_finished and game.hold_owner == 2, "Red can win by holding uncontested")
	_key(KEY_R)
	check(not game.match_finished and game.get_living_units().size() == 6, "R resets the encounter")
	for unit in game.get_living_units():
		if unit.team == Unit.Team.RED:
			unit.take_damage(500, null)
	game._tick_objective(0.0)
	check(game.match_finished and game.hold_owner == 1, "Blue can win by eliminating Red")


func _tank_route() -> int:
	var tank := _unit(Unit.Role.TANK)
	game.set_selection([tank])
	var goal := Vector2(368.0, 336.0)
	var mini := game.hud.minimap_screen_point(goal)
	_click(mini, MOUSE_BUTTON_LEFT)
	check(game.ground_to_screen(goal).distance_to(game.hud.playable_screen_rect().get_center()) < 0.05, "minimap left click pans to the projected point")
	_click(mini, MOUSE_BUTTON_RIGHT)
	check(game._last_minimap_order.distance_to(goal) < 0.015, "minimap right click and world click agree")
	check(game.grid.cell_of(tank.move_goal_world) == Vector2i(11, 10), "minimap order selects the east side of the ridge")
	var on_shelf_a := game.layout.label.begins_with("A")
	var squad := _unit(Unit.Role.SQUAD)
	var high_pass := game.grid.center_of(Vector2i(8, 5))
	if on_shelf_a:
		squad.command_move(high_pass)
	var crossing_row := -1
	var clearance := true
	for i in range(600):
		await physics_frame
		if tank.position.x >= 256.0 and crossing_row < 0:
			crossing_row = game.grid.cell_of(tank.position).y
		clearance = clearance and tank._line_walkable(tank.position, tank.position)
		if tank.order == Unit.Order.NONE and (not on_shelf_a or squad.order == Unit.Order.NONE):
			break
	check(clearance and tank.position.distance_to(goal) < 2.0, "tank reaches the minimap destination clear of every cliff and trunk")
	check(tank.position.distance_to(game._orichalcum_pos) < game.HOLD_RADIUS, "tank finishes inside the Orichalcum field")
	if on_shelf_a:
		check(squad.position.distance_to(high_pass) < 2.0, "the squad reaches A’s high path while the tank takes the low road")
	return crossing_row


func _catalog() -> void:
	check(change_scene_to_file(OPENING) == OK, "opening scene loads")
	await scene_changed
	for path in [A, B]:
		current_scene.get_node("%DevelopersPage").pressed.emit()
		var catalog := current_scene.get_node("%Catalog")
		var play: Button
		for section in catalog.get_children():
			for card in section.get_children():
				if card.get_meta("catalog_key", "") != path:
					continue
				for button in card.find_children("*", "Button", true, false):
					if button.text == "Play":
						play = button
		check(is_instance_valid(play), "Play card for " + path.get_file())
		if not is_instance_valid(play):
			return
		play.pressed.emit()
		await scene_changed
		check(current_scene.scene_file_path == path, "Play loads " + path.get_file())
		check(not root.get_node("BuildLauncher/ReturnButton").visible, "the catalog button leaves the Forest Claim HUD clear")
		_key(KEY_ESCAPE)
		await scene_changed
		check(current_scene.get_node("%Library").visible, "Esc returns to Developers Page")


func _unit(role: Unit.Role, team := Unit.Team.BLUE) -> ForestClaimUnit:
	for unit in game.get_living_units():
		if unit.team == team and unit.role == role:
			return unit as ForestClaimUnit
	return null


func _button(at: Vector2, which: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = which
	event.pressed = down
	root.push_input(event, true)


func _click(at: Vector2, which: MouseButton) -> void:
	_button(at, which, true)
	_button(at, which, false)


func _key(which: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = which
	event.physical_keycode = which
	event.pressed = true
	root.push_input(event, true)


func check(passed: bool, details: String) -> void:
	if not passed:
		failures += 1
		push_error(details)
