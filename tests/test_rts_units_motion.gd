extends SceneTree
## Godot --headless --path . --script res://tests/test_rts_units_motion.gd

const STUDY := preload("res://scenes/maps/rts_units_test_v2.tscn")
const Motion := preload("res://scripts/rts/rts_motion_unit.gd")
const TANK := preload("res://scenes/rts/units/look/blue_tank.tres")
const DT := 1.0 / 60.0

var _failures := 0
var _safe := true


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_failures += 1


func _run() -> void:
	var study := STUDY.instantiate()
	root.add_child(study)
	var world: Node2D = study.map
	for unit: RtsUnit in world.units.get_children():
		unit.set_physics_process(false)
		unit.peaceful = true
	var tank := world.get_node("Units/BlueTank") as Motion
	var commands := world.get_node("Commands") as RtsCommands
	var camera := world.get_node("Camera") as RtsCamera
	commands.set_selection([tank])
	var start := tank.position
	var goal := Vector2i(8, 1)
	tank.command_move(goal)
	var off_axis := 0.0
	for i in 100:
		_tick([tank])
		var axis: Vector2 = (world.grid.center_of(goal) - start).normalized()
		off_axis = maxf(off_axis, absf(axis.cross(tank.position - start)))
	_check(off_axis < 0.01 and tank.distance_walked > 85.0, "open sand supports a straight non-grid-angle route")
	print("  Open sand: off-axis %.4f px, distance %.2f px" % [off_axis, tank.distance_walked])
	var effects := world.get_node("Look") as RtsLook
	var before := [tank.position, tank.goal, tank.order, tank._facing, tank.distance_walked, camera.position,
		effects._tracks.duplicate(), commands.selection.duplicate()]
	study.set_look(1)
	_check(before == [tank.position, tank.goal, tank.order, tank._facing, tank.distance_walked, camera.position,
		effects._tracks, commands.selection] and not effects._tracks.is_empty(),
		"live switch preserves position, order, heading, camera, selection and track history")
	_check(study.field.size == Vector2i(960, 540) and is_equal_approx(camera.zoom.x, 1.0), "pixel render size")
	study.set_look(2)
	_check(study.field.size == Vector2i(640, 360) and is_equal_approx(camera.zoom.x, 2.0 / 3.0), "640×360 proof framing")
	study.set_look(0)
	_check(study.field.size == Vector2i(1920, 1080) and is_equal_approx(camera.zoom.x, 2.0), "HD render size")
	tank.command_stop()
	var stopped := [tank.position, tank.distance_walked, effects._tracks.size()]
	for i in 30:
		_tick([tank])
	_check(stopped == [tank.position, tank.distance_walked, effects._tracks.size()],
		"stop freezes travel, tread phase and new track samples")
	tank.command_move(Vector2i(6, 2))
	for i in 220:
		_tick([tank])
	_check(tank.cell == Vector2i(6, 2), "new order starts from the exact stopped position")
	var squad := world.get_node("Units/BlueSquad1") as Motion
	squad.command_move(Vector2i(6, 5))
	for i in 24:
		_tick([squad])
	_check(squad.distance_walked > 8.0 and squad._moving_now, "squad step advances by measured distance")
	squad.command_stop()
	var foot_phase := squad.distance_walked
	_tick([squad])
	_check(not squad._moving_now and foot_phase == squad.distance_walked, "idle squad stops stepping")
	study.free()
	RtsLook.instance = null

	_corner_and_passage()
	_check(_safe, "every footprint stays in walkable cells claimed by its unit")
	quit(1 if _failures else 0)


func _corner_and_passage() -> void:
	var grid := RtsGrid.new()
	var mask := Image.create_empty(8, 8, false, Image.FORMAT_RGB8)
	mask.fill(Color.WHITE)
	for x in range(1, 7):
		mask.set_pixel(x, 3, Color.BLACK)
	for y in range(4, 7):
		mask.set_pixel(6, y, Color.BLACK)
	mask.set_pixel(1, 2, Color.BLACK)
	grid.blocked_cells = ImageTexture.create_from_image(mask)
	root.add_child(grid)
	var first := _tank(grid, Vector2i(1, 3))
	var second := _tank(grid, Vector2i(6, 6))
	first.command_move(Vector2i(6, 5))
	var max_turn := 0.0
	for i in 315:
		var heading := first._facing.angle()
		_tick([first])
		max_turn = maxf(max_turn, absf(angle_difference(heading, first._facing.angle())))
	_check(first.cell == Vector2i(6, 5) and max_turn <= Motion.TURN_SPEED * DT + 0.001,
		"tank takes a tight corner without cutting blocked cells and keeps a bounded turn rate")
	first.command_move(Vector2i(1, 3))
	for i in 320:
		_tick([first])
	_check(first.cell == Vector2i(1, 3), "turn and return through the same elbow")
	first.command_move(Vector2i(6, 3))
	second.command_move(Vector2i(1, 3))
	for i in 475:
		_tick([first, second])
	_check(first.position.x < second.position.x and first.order == RtsUnit.Order.NONE
		and second.order == RtsUnit.Order.NONE, "head-on traffic in a single lane waits and gives up safely")
	first.command_move(Vector2i(1, 2))
	second.command_move(Vector2i(1, 3))
	for i in 390:
		_tick([first, second])
	_check(first.cell == Vector2i(1, 2) and second.cell == Vector2i(1, 3),
		"give one tank the passing bay and both new orders finish")
	first.free()
	second.free()
	grid.free()


func _tank(grid: RtsGrid, at: Vector2i) -> Motion:
	var unit := Motion.new()
	unit.stats = TANK
	unit.position = grid.center_of(at)
	root.add_child(unit)
	unit.setup(grid)
	unit.set_physics_process(false)
	unit.peaceful = true
	return unit


func _tick(units: Array) -> void:
	for unit: Motion in units:
		unit.tick(DT)
		for tile in unit.grid.cells_along(unit.position, unit.position, Motion.CLEARANCE):
			if not unit.grid.is_walkable(tile) or unit.grid.unit_at(tile) != unit:
				_safe = false
