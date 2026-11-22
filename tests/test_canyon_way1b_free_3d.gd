extends SceneTree
## Headless verification of "3D Canyon · Way 1B Free 3D Modules" (scenes/maps/canyon_way1b_free_3d.tscn):
##   - verifies physics corridor walls, end caps, exit signal, and obstacle-aware navigation around the kept boulders;
##   - verifies all 5 Way 1B free-module roles (3D Cobbles, 3D Curbs, 3D Cliffs, 3D Succulents & Verge, Exit Vista)
##     plus the kept anchors (BlueCommander, 2 ChatGPT Trellis boulders, and the pale Grand Canyon rock);
##   - verifies interactive key toggles (G, R, K, B, W, V).

const SCENE := "res://scenes/maps/canyon_way1b_free_3d.tscn"
const TOLERANCE := 0.03

var _scene: Node3D
var _hero: CharacterBody3D
var _route: Node
var _exit_fired := false


func _initialize() -> void:
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


func _send_key(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	_scene._unhandled_key_input(ev)


func _run() -> void:
	_scene = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_scene)
	_hero = _scene.get_node("BlueCommander")
	_route = _scene.get_node("Route")
	_hero.reached_canyon_exit.connect(func(at_exit: bool) -> void: _exit_fired = _exit_fired or at_exit)
	for i in 20:
		await physics_frame

	# 1. Verify kept anchors and all 5 Way 1B free-module groups
	var layout := _scene.get_node("Layout")
	if layout.get_node_or_null("ChatGPTBoulder_HF_Trellis2") == null or layout.get_node_or_null("ChatGPTBoulder_Trellis3DNet") == null:
		return _fail("Missing kept ChatGPT Trellis boulders in Layout")
	var anchors := _scene.get_node_or_null("KeptAnchors")
	if anchors == null or anchors.get_node_or_null("GrandCanyonWhiteRock") == null:
		return _fail("Missing kept pale Grand Canyon rock in KeptAnchors")

	for group_name: String in ["Way1BCliffs", "Way1BCurbs", "Way1BCobbles", "Way1BVerge", "Way1BVista"]:
		var g := _scene.get_node_or_null(group_name)
		if g == null or g.get_child_count() == 0:
			return _fail("Way 1B group missing or empty: " + group_name)
		print("Verified %s: %d children" % [group_name, g.get_child_count()])

	# 2. Verify interactive toggles (G, R, K, B, W, V)
	_send_key(KEY_G)
	if _scene._harmonized:
		return _fail("Key G did not toggle palette grading")
	_send_key(KEY_G)
	if not _scene._harmonized:
		return _fail("Key G did not restore palette grading")

	for pair: Array in [[KEY_R, "Way1BCobbles"], [KEY_K, "Way1BCurbs"], [KEY_B, "Way1BVerge"], [KEY_W, "Way1BCliffs"], [KEY_V, "Way1BVista"]]:
		var node := _scene.get_node(pair[1]) as Node3D
		_send_key(pair[0])
		if node.visible:
			return _fail("Toggle key failed to hide " + pair[1])
		_send_key(pair[0])
		if not node.visible:
			return _fail("Toggle key failed to show " + pair[1])

	# 3. Verify corridor physics walls, end caps, exit signal, and navigation mesh
	if _hero.clamp_to_route:
		return _fail("Position clamp is still on")
	var half_width: float = _route.half_width

	await _hold(&"ui_right", 90)
	if _offset() > half_width + TOLERANCE or _offset() < half_width - 0.15:
		return _fail("Right wall did not stop the commander at the corridor edge")
	await _hold(&"ui_left", 150)
	if _offset() < -half_width - TOLERANCE or _offset() > -half_width + 0.15:
		return _fail("Left wall did not stop the commander at the corridor edge")

	await _hold(&"ui_up", 420)
	var z := _hero.global_position.z
	if not _exit_fired or z < -14.5 - TOLERANCE or z > -14.0 or not _hero.is_on_floor():
		return _fail("Exit cap or exit signal failed")

	_hero.global_position = Vector3(_route.center_x(6.5), 0.02, 6.5)
	await _hold(&"ui_down", 120)
	z = _hero.global_position.z
	if z > 7.5 + TOLERANCE or z < 7.0:
		return _fail("Spawn-side cap failed")

	var map := _hero.get_world_3d().navigation_map
	var start := Vector3(_route.center_x(6.0), 0.0, 6.0)
	var goal := Vector3(_route.center_x(-14.0), 0.0, -14.0)
	var path := NavigationServer3D.map_get_path(map, start, goal, true)
	var last := path[path.size() - 1] if path.size() > 0 else Vector3.INF
	if path.size() < 2 or Vector2(last.x - goal.x, last.z - goal.z).length() > 0.2:
		return _fail("Navigation path missing or short")

	print("PASS: Way 1B Free 3D Modules — all 5 roles, kept anchors, toggles, corridor walls, exit signal, and navigation verified")
	quit(0)
