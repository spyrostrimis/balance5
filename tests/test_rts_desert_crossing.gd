extends SceneTree
## Headless checks by default. Windowed modes: -- --stills, -- --record, or -- --catalog.

const STUDY := preload("res://scenes/maps/rts_desert_crossing.tscn")
const OUTPUT := "res://render_captures/rts_desert_proof/"
const SHADE := Vector2(464, 240)
const TANK_GOAL := Vector2(432, 240)

var _study: Node2D
var _squad: RtsUnit
var _tank: RtsUnit
var _failed := 0


func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--catalog" in args:
		await _catalog()
	else:
		if "--stills" in args or "--record" in args:
			root.size = Vector2i(1920, 1080)
		_study = STUDY.instantiate()
		root.add_child(_study)
		_squad = _study.map.get_node("Units/BlueSquad")
		_tank = _study.map.get_node("Units/BlueTank")
		if "--stills" in args:
			await _stills()
		elif "--record" in args:
			await _record()
		else:
			_headless()
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_failed += 1


func _headless() -> void:
	var terrain := _study.terrain as RtsDesertTerrain
	var grid := _study.map.grid as RtsGrid
	var area: Vector2 = Vector2(_study.field.size) / _study._camera.zoom
	_check(area.is_equal_approx(Vector2(480, 336)), "15 × 10.5 opening field")
	for unit: RtsUnit in _study.map.units.get_children():
		unit.set_physics_process(false)
	_check(not grid.is_walkable(grid.cell_of(Vector2(450, 154)))
		and not grid.is_walkable(grid.cell_of(Vector2(449, 305)))
		and not grid.is_walkable(grid.cell_of(Vector2(183, 200))), "cliff, outcrop and outpost footprints block routes")
	_check(grid.is_walkable(grid.cell_of(SHADE)) and grid.is_walkable(grid.cell_of(Vector2(306, 264))),
		"dune and cliff shade are walkable")
	_squad.command_move(grid.cell_of(SHADE))
	var max_height := 0.0
	var max_rate := 1.0
	var min_speed := 1.0
	var safe := true
	for i in 250:
		_squad.tick(1.0 / 60)
		max_height = maxf(terrain.height_at(_squad.position), max_height)
		max_rate = maxf(_squad._footfall_rate(), max_rate)
		min_speed = minf(_squad._terrain_speed_factor(_squad._facing), min_speed)
		safe = safe and grid.unit_at(_squad.cell) == _squad
	_check(max_height > 8 and max_rate > 1.12 and min_speed < 0.9,
		"squad crests dune and shortens uphill steps (height %.2f, cadence %.2f, speed %.2f)" %
		[max_height, max_rate, min_speed])
	_check(safe and _squad.position.is_equal_approx(SHADE) and _squad._ground_light() < 0.80,
		"squad holds its cells and reaches shared cliff shade (light %.2f)" % _squad._ground_light())
	_tank.command_move(grid.cell_of(TANK_GOAL))
	for i in 106:
		_tank.tick(1.0 / 60)
	var before := [_tank.position, _tank.goal, _tank.order, _tank._facing, _study._camera.position, terrain.disturbed_pixels]
	_study.set_look(1)
	_check(before == [_tank.position, _tank.goal, _tank.order, _tank._facing, _study._camera.position, terrain.disturbed_pixels]
		and terrain.disturbed_pixels > 100, "pixel switch keeps live order, heading, camera and the tread mask")
	for i in 230:
		_tank.tick(1.0 / 60)
	_check(_tank.position.is_equal_approx(TANK_GOAL) and terrain.disturbed_pixels > 450,
		"tank reaches shade and compresses the dune (%d pixels at %s)" % [terrain.disturbed_pixels, _tank.position])
	var marks := 0
	var in_mark := false
	for y in range(260, 302):
		var on := terrain._treads.get_pixel(303, y).r >= 0.48
		if on and not in_mark:
			marks += 1
		in_mark = on
	_check(marks == 2, "two distinct tread lanes across the middle of the dune")
	_study._restart()
	_check(_study.terrain.disturbed_pixels == 0 and _study.look == 1, "restart clears marks and keeps the chosen look")


func _key(code: Key) -> void:
	var input := InputEventKey.new()
	input.keycode = code
	input.physical_keycode = code
	input.pressed = true
	root.push_input(input)


func _click(point: Vector2, button: MouseButton) -> void:
	var viewport_point: Vector2 = _study.field.get_canvas_transform() * point
	var root_point: Vector2 = _study.screen.get_global_transform_with_canvas() * viewport_point
	for down in [true, false]:
		var input := InputEventMouseButton.new()
		input.button_index = button
		input.pressed = down
		input.position = root.get_final_transform() * root_point
		input.global_position = input.position
		root.push_input(input)


func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


func _pair(filename: String) -> void:
	var last: Node.ProcessMode = _study.map.process_mode
	_study.map.process_mode = Node.PROCESS_MODE_DISABLED
	for mode in 2:
		_study.set_look(mode, false)
		await _frame()
		await _frame()
		var filename_with_look := filename + ("-painted.png" if mode == 0 else "-pixel.png")
		_check(root.get_texture().get_image().save_png(OUTPUT + filename_with_look) == OK, filename_with_look)
	_study.set_look(0, false)
	_study.map.process_mode = last


func _stills() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	await _frame()
	_study._route.button_pressed = true
	await _frame()
	_check(_study._show_route and root.get_texture().get_image().save_png(OUTPUT + "00-crossing-targets.png") == OK,
		"optional squad and tank targets")
	_study._route.button_pressed = false
	await _pair("01-opening")
	_click(SHADE, MOUSE_BUTTON_RIGHT)
	for i in 125:
		await physics_frame
	await _pair("02-squad-crossing")
	for i in 90:
		await physics_frame
	_check(_squad.position.is_equal_approx(SHADE), "right-click squad into shade")
	_click(_tank.position, MOUSE_BUTTON_LEFT)
	_click(TANK_GOAL, MOUSE_BUTTON_RIGHT)
	for i in 122:
		await physics_frame
	await _pair("03-treads")
	for i in 139:
		await physics_frame
	await _pair("04-lee")
	_check(_tank.position.is_equal_approx(TANK_GOAL), "mouse tank order completes")
	_key(KEY_M)
	await _frame()
	await _frame()
	_check(not RtsLook.marks and root.get_texture().get_image().save_png(OUTPUT + "04-lee-marks-off.png") == OK,
		"M hides the tire marks and the underlying compression together")
	_key(KEY_M)
	root.size = Vector2i(1376, 768)
	await _frame()
	_key(KEY_V)
	_click(_squad.position, MOUSE_BUTTON_LEFT)
	var enemy: RtsUnit = _study.map.get_node("Units/RedSquad")
	var old_health := enemy.health
	_click(enemy.position, MOUSE_BUTTON_RIGHT)
	_check(_study.look == 1 and _study._commands.selection == [_squad] and _squad.target == enemy,
		"selection and attack stay under the mouse after resize and V")
	for i in 270:
		await physics_frame
		if enemy.health < old_health:
			break
	_check(enemy.health < old_health, "attack closes to range and causes damage")


func _record() -> void:
	Engine.max_fps = 30
	DirAccess.make_dir_recursive_absolute(OUTPUT + "frames")
	await _frame()
	var begin := Time.get_ticks_msec()
	var actions := [0.6, 2.2, 4.0, 5.4, 8.5]
	var cursor := 0
	var frame := 0
	while true:
		await _frame()
		var seconds := (Time.get_ticks_msec() - begin) / 1000.0
		if seconds >= 13.0:
			break
		if cursor < actions.size() and seconds >= actions[cursor]:
			match cursor:
				0: _click(SHADE, MOUSE_BUTTON_RIGHT)
				1, 3, 4: _key(KEY_V)
				2:
					_click(_tank.position, MOUSE_BUTTON_LEFT)
					_click(TANK_GOAL, MOUSE_BUTTON_RIGHT)
			cursor += 1
		root.get_texture().get_image().save_jpg(OUTPUT + "frames/%04d.jpg" % frame, 0.9)
		frame += 1
	print("Recorded %d frames in 13 seconds" % frame)


func _catalog() -> void:
	change_scene_to_file("res://scenes/ui/opening_screen.tscn")
	await scene_changed
	current_scene.get_node("%DevelopersPage").pressed.emit()
	for group in current_scene.get_node("%Catalog").get_children():
		for card in group.get_children():
			if card.get_meta("catalog_key", "") != STUDY.resource_path:
				continue
			for button in card.find_children("*", "Button", true, false):
				if button.text != "Play":
					continue
				button.pressed.emit()
				await scene_changed
				_check(current_scene.scene_file_path == STUDY.resource_path, "Developers Page launches Desert Crossing")
				_key(KEY_V)
				_check(current_scene.look == 1, "keyboard switches the packaged look")
				_key(KEY_ESCAPE)
				await scene_changed
				_check(current_scene.get_node("%Library").visible, "Esc returns to the catalog")
				return
	_check(false, "Desert Crossing Play card is present")
