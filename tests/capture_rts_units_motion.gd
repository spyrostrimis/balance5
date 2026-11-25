extends SceneTree
## Windowed play and capture of the same route on both studies.
## Default: stills and mouse checks. -- --catalog checks both Play cards. -- --clip records live frames.

const ORIGINAL := preload("res://scenes/maps/rts_units_test.tscn")
const STUDY := preload("res://scenes/maps/rts_units_test_v2.tscn")
const OPENING := "res://scenes/ui/opening_screen.tscn"
const OUT := "res://render_captures/rts_units_v2/"
const LOOKS := ["hd", "pixel", "pixel-640"]
const OPEN_SAND := Vector2(240, 112)
const MESA_SHADOW := Vector2(144, 8)
const ROCK_SHADOW := Vector2(368, 240)
const RALLY := Vector2(400, 272)

var _failures := 0
var _study: Node2D
var _map: Node2D
var _camera: RtsCamera
var _commands: RtsCommands
var _tank: RtsUnit
var _squad: RtsUnit
var _enemy: RtsUnit


func _initialize() -> void:
	create_timer(100.0).timeout.connect(func():
		push_error("RTS capture timed out")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--catalog" in args:
		await _catalog()
	elif "--clip" in args:
		await _record()
	else:
		await _stills()
	quit(1 if _failures else 0)


func _check(condition: bool, name: String) -> void:
	print(("PASS " if condition else "FAIL ") + name)
	if not condition:
		_failures += 1


func _catalog() -> void:
	change_scene_to_file(OPENING)
	await scene_changed
	var settings := [root.size, root.content_scale_mode, root.content_scale_size, root.title]
	current_scene.get_node("%DevelopersPage").pressed.emit()
	for build in [ORIGINAL, STUDY]:
		var card: Button = null
		for group in current_scene.get_node("%Catalog").get_children():
			for item in group.get_children():
				if item.get_meta("catalog_key", "") == build.resource_path:
					for button in item.find_children("*", "Button", true, false):
						if button.text == "Play":
							card = button
		_check(card != null, "Play card for " + build.resource_path)
		if card == null:
			return
		card.pressed.emit()
		await scene_changed
		_check(current_scene.scene_file_path == build.resource_path, "card opens the requested scene")
		if build == STUDY:
			_check(current_scene.map.get_node("Units/RedCommander").art_hd != null, "exported actor texture loads")
			_key(KEY_K)
			_check(not RtsLook.shadows, "catalog scene receives effect toggle")
			_key(KEY_V)
			_check(current_scene.look == 1, "catalog scene receives V")
		_key(KEY_ESCAPE)
		await scene_changed
		_check(current_scene.get_node("%Library").visible, "Esc returns to the Developers Page")
		_check([root.size, root.content_scale_mode, root.content_scale_size, root.title] == settings
			and RtsLook.shadows, "catalog window and effect settings restored")


func _open(successor: bool) -> void:
	if successor:
		_study = STUDY.instantiate()
		root.add_child(_study)
		_map = _study.map
	else:
		_map = ORIGINAL.instantiate()
		root.add_child(_map)
	_camera = _map.get_node("Camera")
	_camera.set_scroll_bounds(Rect2(0, 0, 960, 540))
	_camera.look_at_point(Vector2(480, 270))
	_camera.edge_scroll = false
	_camera.force_update_scroll()
	_commands = _map.get_node("Commands")
	_tank = _map.get_node("Units/BlueTank")
	_squad = _map.get_node("Units/BlueSquad1")
	_enemy = _map.get_node("Units/RedSquad1")
	for unit: RtsUnit in _map.units.get_children():
		unit.peaceful = true  # Keep the opening positions until the player orders the attack.


func _close() -> void:
	if _study != null:
		_study.free()
		_study = null
	else:
		_map.free()


func _world_in_window(world: Vector2) -> Vector2:
	var view := _camera.get_viewport().get_canvas_transform() * world
	if _study != null:
		view = _study.screen.get_global_transform_with_canvas() * view
	return root.get_final_transform() * view


func _mouse(world: Vector2, button: MouseButton, pressed: bool, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = _world_in_window(world)
	event.global_position = event.position
	event.pressed = pressed
	event.shift_pressed = shift
	root.push_input(event)


func _click(world: Vector2, button: MouseButton, shift := false) -> void:
	_mouse(world, button, true, shift)
	_mouse(world, button, false, shift)


func _drag(from: Vector2, to: Vector2, button: MouseButton) -> void:
	_mouse(from, button, true)
	var motion := InputEventMouseMotion.new()
	motion.position = _world_in_window(to)
	motion.global_position = motion.position
	motion.relative = motion.position - _world_in_window(from)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_MIDDLE
	root.push_input(motion)
	_mouse(to, button, false)


func _key(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	root.push_input(key)


func _choose_group() -> void:
	_click(_tank.position, MOUSE_BUTTON_LEFT)
	_click(_squad.position, MOUSE_BUTTON_LEFT, true)
	_check(_commands.selection.has(_tank) and _commands.selection.has(_squad)
		and _commands.selection.size() == 2, "click and shift-click select tank and squad")


func _wait_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


func _move_and_wait(world: Vector2, title: String) -> void:
	_click(world, MOUSE_BUTTON_RIGHT)
	var goal := _map.grid.cell_of(world) as Vector2i
	_check(_tank.order == RtsUnit.Order.MOVE and _squad.order == RtsUnit.Order.MOVE
		and _tank.goal != _squad.goal and goal in [_tank.goal, _squad.goal], "cursor gives separate group goals at " + title)
	for i in 7 * 60:
		await physics_frame
		if _tank.order == RtsUnit.Order.NONE and _squad.order == RtsUnit.Order.NONE:
			break
	_check(_tank.cell == _tank.goal and _squad.cell == _squad.goal, "tank and squad arrive at " + title)
	print("  ", title, " tank ", _tank.position, " squad ", _squad.position)


func _matched(title: String, all_resolutions := false) -> void:
	# Freeze both orders and existing ground effects while changing art.
	var live := _map.process_mode
	_map.process_mode = Node.PROCESS_MODE_DISABLED
	if _study == null:
		await _save("original-" + title)
	else:
		for mode in (3 if all_resolutions else 2):
			_study.set_look(mode, false)
			_study.notice.hide()
			await _save(LOOKS[mode] + "-" + title)
		_study.set_look(0, false)
	_map.process_mode = live


func _save(name: String) -> void:
	await _wait_frame()
	await _wait_frame()
	var screenshot := root.get_texture().get_image()
	_check(screenshot.save_png(OUT + name + ".png") == OK, "%s capture %s" % [name, screenshot.get_size()])


func _stills() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1920, 1080)
	await _wait_frame()
	for successor in [false, true]:
		_open(successor)
		await _wait_frame()
		_choose_group()
		await _matched("01-opening", true)
		await _move_and_wait(OPEN_SAND, "open sand")
		await _matched("02-open-sand")
		await _move_and_wait(MESA_SHADOW, "northwest cliff edge")
		await _matched("02b-cliff-shadow")
		await _move_and_wait(ROCK_SHADOW, "Orichalcum shadow")
		await _matched("03-rock-shadow", true)
		_click(RALLY, MOUSE_BUTTON_RIGHT)
		for i in 24:
			await physics_frame
		_key(KEY_S)
		_check(_tank.order == RtsUnit.Order.NONE and _squad.order == RtsUnit.Order.NONE, "S cancels the active order")
		await _move_and_wait(RALLY, "road after the stop")
		var health := _enemy.health
		_click(_enemy.position, MOUSE_BUTTON_RIGHT)
		_check(_tank.target == _enemy and _squad.target == _enemy, "right-click enemy gives the group an attack order")
		for i in 3 * 60:
			await physics_frame
			if _enemy.health < health:
				break
		_check(_enemy.health < health, "attack closes to range and damages the enemy")
		await _matched("04-attack")
		_close()
		await process_frame
	await _check_resizes()


func _check_resizes() -> void:
	_open(true)
	for unit: RtsUnit in _map.units.get_children():
		unit.set_physics_process(false)
	for resolution in [Vector2i(1280, 720), Vector2i(1376, 768)]:
		root.size = resolution
		await _wait_frame()
		_check(root.size == resolution, "review window %s" % resolution)
		_choose_group()
		_drag(Vector2(86, 121), Vector2(194, 192), MOUSE_BUTTON_LEFT)
		_check(_commands.selection.has(_tank) and _commands.selection.has(_squad)
			and not _commands.selection.has(_enemy), "drag box selects Blue units")
		var frame := _camera.position
		_key(KEY_V)
		_check(_study.look == 1 and _camera.position == frame, "V swaps art in the resized window")
		_study.notice.hide()
		await _save("review-%d-pixel" % resolution.x)
		_choose_group()
		_click(OPEN_SAND, MOUSE_BUTTON_RIGHT)
		_check(_tank.goal == Vector2i(7, 3) or _squad.goal == Vector2i(7, 3),
			"right-click stays on the same tile after V and resize")
		_click(_squad.position, MOUSE_BUTTON_LEFT)
		_check(_commands.selection == [_squad], "click selects the same unit after V and resize")
		_key(KEY_F1)
		_check(_map.grid.show_debug, "F1 blocked-tile display")
		_key(KEY_F1)
		_click(_squad.position, MOUSE_BUTTON_WHEEL_UP)
		_check(_camera.zoom.x > 1.0, "wheel zoom follows the pixel switch")
		var centre := _camera.position
		_drag(centre, centre + Vector2(20, -12), MOUSE_BUTTON_MIDDLE)
		_check(_camera.position.distance_to(centre) > 12, "middle drag pans after the pixel switch")
		var panned := _camera.position
		_key(KEY_V)
		_check(is_equal_approx(_camera.zoom.x, 2.3) and _camera.position.is_equal_approx(panned),
			"pan and zoom survive the HD switch")
		_click(_camera.position, MOUSE_BUTTON_WHEEL_DOWN)
		_camera.look_at_point(Vector2(480, 270))
		_camera.force_update_scroll()
	_close()


func _record() -> void:
	root.size = Vector2i(1920, 1080)
	Engine.max_fps = 30
	seed(35)
	DirAccess.make_dir_recursive_absolute(OUT + "live")
	_open(true)
	await _wait_frame()
	_choose_group()
	var start := Time.get_ticks_msec()
	var next := 0
	var index := 0
	var times := [0.7, 1.8, 3.5, 5.0, 6.5, 9.7, 11.25, 11.65, 12.35, 13.2, 14.4]
	while true:
		await _wait_frame()
		var seconds := (Time.get_ticks_msec() - start) / 1000.0
		if seconds >= 19.0:
			break
		if next < times.size() and seconds >= times[next]:
			match next:
				0: _click(OPEN_SAND, MOUSE_BUTTON_RIGHT)
				1, 3, 9: _key(KEY_V)
				2: _click(MESA_SHADOW, MOUSE_BUTTON_RIGHT)
				4: _click(ROCK_SHADOW, MOUSE_BUTTON_RIGHT)
				5:
					_click(ROCK_SHADOW, MOUSE_BUTTON_WHEEL_UP)
					_click(ROCK_SHADOW, MOUSE_BUTTON_WHEEL_UP)
				6, 8: _click(RALLY, MOUSE_BUTTON_RIGHT)
				7: _key(KEY_S)
				10: _click(_enemy.position, MOUSE_BUTTON_RIGHT)
			next += 1
		var frame := root.get_texture().get_image()
		frame.save_jpg(OUT + "live/%04d.jpg" % index, 0.91)
		index += 1
	print("19-second live recording: ", index, " frames")
	_close()
