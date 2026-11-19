extends SceneTree
## Headless check of canyon_v2's physics corridor and navigation mesh.
##   Godot --path . --headless --script res://tests/test_canyon_corridor.gd
## Fails (exit 1) unless walls contain the commander on both sides and at both ends with the position
## clamp off, the exit signal fires, and navigation returns an in-corridor path from spawn to exit.

const SCENE := "res://scenes/maps/canyon_v2.tscn"
const TOLERANCE := 0.03

var _scene: Node3D
var _hero: CharacterBody3D
var _route: Node
var _exit_fired := false


func _initialize() -> void:
	# Watchdog: a script error inside the coroutine would otherwise leave the run hanging.
	create_timer(120.0).timeout.connect(func() -> void: _fail("Timed out"))
	_run.call_deferred()


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for i in frames:
		await physics_frame
	Input.action_release(action)
	for i in 3:
		await physics_frame


func _offset() -> float:
	return _hero.global_position.x - _route.center_x(_hero.global_position.z)


func _run() -> void:
	_scene = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_scene)
	_hero = _scene.get_node("BlueCommander")
	_route = _scene.get_node("Route")
	_hero.reached_canyon_exit.connect(func(at_exit: bool) -> void: _exit_fired = _exit_fired or at_exit)
	for i in 20:
		await physics_frame
	if _hero.clamp_to_route:
		return _fail("Position clamp is still on")
	var half_width: float = _route.half_width
	var walls := _scene.get_node("Corridor/Walls").get_child_count()
	print("Corridor wall shapes: %d | half width %.2f m" % [walls, half_width])

	await _hold(&"ui_right", 90)
	print("Right wall offset %.3f m at z %.2f" % [_offset(), _hero.global_position.z])
	if _offset() > half_width + TOLERANCE or _offset() < half_width - 0.15:
		return _fail("Right wall did not stop the commander at the corridor edge")
	await _hold(&"ui_left", 150)
	print("Left wall offset %.3f m" % _offset())
	if _offset() < -half_width - TOLERANCE or _offset() > -half_width + 0.15:
		return _fail("Left wall did not stop the commander at the corridor edge")

	await _hold(&"ui_up", 420)
	var z := _hero.global_position.z
	print("Forward end z %.3f | exit signal %s | on floor %s" % [z, _exit_fired, _hero.is_on_floor()])
	if not _exit_fired or z < -14.5 - TOLERANCE or z > -14.0 or not _hero.is_on_floor():
		return _fail("Exit cap or exit signal failed")
	# Walk the last stretch back from the road centre so the Trellis boulder blocker is not in the way.
	_hero.global_position = Vector3(_route.center_x(6.5), 0.02, 6.5)
	await _hold(&"ui_down", 120)
	z = _hero.global_position.z
	print("Backward end z %.3f" % z)
	if z > 7.5 + TOLERANCE or z < 7.0:
		return _fail("Spawn-side cap failed")

	var map := _hero.get_world_3d().navigation_map
	var start := Vector3(_route.center_x(6.0), 0.0, 6.0)
	var goal := Vector3(_route.center_x(-14.0), 0.0, -14.0)
	var path := NavigationServer3D.map_get_path(map, start, goal, true)
	var last := path[path.size() - 1] if path.size() > 0 else Vector3.INF
	if path.size() < 2 or Vector2(last.x - goal.x, last.z - goal.z).length() > 0.2:
		return _fail("Navigation path missing or short: %s" % [path])
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
		if absf(path[i].x - _route.center_x(path[i].z)) > half_width + 0.05:
			return _fail("Navigation point outside corridor: %s" % path[i])
	var blockers: Array[AABB] = []
	for shape in _scene.get_node("Layout").find_children("*", "CollisionShape3D", true, false):
		var box := (shape as CollisionShape3D).shape as BoxShape3D
		if box:
			blockers.append((shape as Node3D).global_transform * AABB(-box.size * 0.5, box.size))
	for i in range(1, path.size()):
		for k in 11:
			var p := path[i - 1].lerp(path[i], k / 10.0)
			for blocker in blockers:
				if blocker.grow(-0.05).has_point(Vector3(p.x, 0.5, p.z)):
					return _fail("Navigation path crosses a module blocker at %s" % p)
	var outside := NavigationServer3D.map_get_closest_point(map, start + Vector3(6.0, 0.0, 0.0))
	print("Navigation path: %d points, %.2f m, clear of %d blockers | off-corridor target snaps to %s" % [path.size(), length, blockers.size(), outside])
	if absf(outside.x - _route.center_x(outside.z)) > half_width + 0.05:
		return _fail("Closest navigation point left the corridor")
	print("PASS: corridor walls, end caps, exit signal and obstacle-aware navigation")
	quit(0)
