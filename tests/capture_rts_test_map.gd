extends SceneTree
## Windowed capture of the RTS test map, driven by real mouse and key events.
##   Godot --path . --script res://tests/capture_rts_test_map.gd
## The real cursor is warped along with the simulated events so stray OS mouse motion over the
## window cannot move the drag box. Saves render_captures/rts_test_01_start.png, _02_dragbox, _03_moving_tiles, _04_attack.

const SCENE := "res://scenes/maps/rts_test_map.tscn"
const CAPTURE_DIR := "res://render_captures"

var _map: Node2D
var _grid: RtsGrid
var _cmd: RtsCommands


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("Timed out")
		quit(1))
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _capture(file: String) -> void:
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	var img := root.get_texture().get_image()
	img.save_png(CAPTURE_DIR + "/" + file)
	print("Captured ", file, " ", img.get_size())


func _screen(world: Vector2) -> Vector2:
	return root.get_canvas_transform() * world


func _mouse_button(button: MouseButton, pressed: bool, at: Vector2) -> void:
	Input.warp_mouse(at)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	root.push_input(ev)


func _mouse_move(at: Vector2) -> void:
	Input.warp_mouse(at)
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(ev)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.pressed = pressed
		root.push_input(ev)


func _run() -> void:
	_map = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_map)
	_grid = _map.get_node("Grid")
	_cmd = _map.get_node("Commands")
	(_map.get_node("Camera") as RtsCamera).edge_scroll = false
	await _frames(10)
	await _capture("rts_test_01_start.png")

	# Drag a box around the Blue spawn.
	var a := _screen(_grid.center_of(Vector2i(3, 7)))
	var b := _screen(_grid.center_of(Vector2i(8, 12)))
	_mouse_button(MOUSE_BUTTON_LEFT, true, a)
	_mouse_move(a.lerp(b, 0.5))
	_mouse_move(b)
	await _frames(2)
	print("Drag box from %s to %s" % [_cmd._press_world, _cmd._drag_world])
	await _capture("rts_test_02_dragbox.png")
	_mouse_button(MOUSE_BUTTON_LEFT, false, b)
	await _frames(2)
	print("Selected after box: ", _cmd.selection.size())

	# Right-click beside the rock, then show the tile overlay while they walk.
	_mouse_button(MOUSE_BUTTON_RIGHT, true, _screen(_grid.center_of(Vector2i(21, 17))))
	_key(KEY_F1)
	await _frames(170)
	await _capture("rts_test_03_moving_tiles.png")
	_key(KEY_F1)
	await _frames(600)
	for u in _cmd.selection:
		print("  %s at %s" % [u.name, u.cell])

	# Look at the Red group and attack one Red Legionary.
	var victim := _map.get_node("Units/RedTroop2") as RtsUnit
	(_map.get_node("Camera") as RtsCamera).look_at_point(_grid.center_of(Vector2i(32, 20)))
	await _frames(2)
	_mouse_button(MOUSE_BUTTON_RIGHT, true, _screen(victim.position))
	await _frames(2)
	print("Orders after right-click on Red: ", _cmd.selection.map(func(u: RtsUnit) -> String: return RtsUnit.Order.keys()[u.order]))
	var waited := 0
	while waited < 900 and victim.alive and victim.health == victim.stats.max_health:
		await _frames(10)
		waited += 10
	await _frames(40)
	await _capture("rts_test_04_attack.png")
	print("Victim hp %d alive %s" % [victim.health, victim.alive])
	quit(0)
