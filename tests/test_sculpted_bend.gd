extends SceneTree
## Real-input round trip in Forward+ at 1376Γ—768, physics and navigation checks headless.
## Add --road-pair for a stationary raised/flat pair and a short walk in the flat variant.
## Add --catalog for the Developers Page launch and Esc path, or --vista-pair for both overlooks.
## Add --record with --fixed-fps 30 to write the exact rendered window as raw RGB frames.

const SCENE := "res://scenes/maps/sculpted_bend.tscn"
const OPENING := "res://scenes/ui/opening_screen.tscn"
const CAPTURES := "res://render_captures/sculpted_bend"
const SIZE := Vector2i(1376, 768)
const ACTIONS := [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]

var _study: Node3D
var _hero: CharacterBody3D
var _route: Node
var _camera: Camera3D
var _windowed := false
var _failed := false
var _samples := 0
var _airborne := 0
var _furthest_lateral := 0.0
var _exit_events: Array[bool] = []
var _recording: FileAccess
var _recorded := 0


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		_check(false, "watchdog expired")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_windowed = DisplayServer.get_name() != "headless"
	if _windowed:
		root.size = SIZE
		root.content_scale_size = SIZE
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
		_check(RenderingServer.get_current_rendering_method() == "forward_plus", "Forward+ renderer")
	if "--catalog" in args:
		await _launch_from_catalog()
	else:
		change_scene_to_file(SCENE)
		await scene_changed
	if current_scene.scene_file_path != SCENE:
		quit(1)
		return
	_study = current_scene
	_hero = _study.get_node("BlueCommander")
	_route = _study.get_node("Route")
	_camera = _study.get_node("CameraRig")
	_hero.reached_canyon_exit.connect(func(value: bool) -> void: _exit_events.append(value))
	await _wait_ticks(20)
	_check(not _hero.clamp_to_route, "physics containment is active")
	_check(_hero.is_on_floor(), "spawn settles on the floor")
	_check(_study.get_node("Landmarks/LayeredWest").find_children("*", "MeshInstance3D").size() == 1,
		"west layered boulder mesh")
	_check(_study.get_node("Landmarks/LayeredEast").find_children("*", "MeshInstance3D").size() == 1,
		"east layered boulder mesh")
	var scan := _study.get_node("Landmarks/PaleRock").find_children("*", "MeshInstance3D", true, false)
	_check(scan.size() == 1, "pale Grand Canyon landmark mesh")
	if scan.size() == 1:
		var surface := (scan[0] as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
		_check(surface != null and surface.albedo_texture != null, "pale landmark keeps its photo texture")
	if "--record" in args:
		_check(_windowed, "recording requires the rendered viewport")
		if _windowed:
			_recording = FileAccess.open("res://tmp/sculpted_round_trip.rgb", FileAccess.WRITE)
			_check(_recording != null, "recording path is writable")
			if _recording:
				RenderingServer.frame_post_draw.connect(_record_frame)
	if "--catalog" in args:
		await _capture("catalog_launch")
		_key(KEY_ESCAPE)
		await scene_changed
		_check(current_scene.scene_file_path == OPENING and current_scene.get_node("%Library").visible,
			"Esc reopened the Developers Page")
		print("Catalog launch and Esc return")
	elif "--road-pair" in args:
		await _road_pair()
	elif "--vista-pair" in args:
		await _vista_pair()
	else:
		await _round_trip()
		_check_navigation()
		if not _windowed:
			await _check_boundaries()
	if _recording:
		RenderingServer.frame_post_draw.disconnect(_record_frame)
		_recording.close()
		print("Rendered recording | %s frames | %s" % [_recorded, SIZE])
	quit(1 if _failed else 0)


func _launch_from_catalog() -> void:
	change_scene_to_file(OPENING)
	await scene_changed
	current_scene.get_node("%DevelopersPage").pressed.emit()
	for card in current_scene.get_node("%Catalog").find_children("*", "PanelContainer", true, false):
		if card.get_meta("catalog_key", "") != SCENE:
			continue
		for button in card.find_children("*", "Button", true, false):
			if button.text == "Play":
				button.pressed.emit()
				await scene_changed
				return
	_check(false, "Sculpted Bend Play card is missing")


func _round_trip() -> void:
	var start := _hero.position
	await _capture("entrance")
	await _walk_to(2.0)
	await _walk_to(-1.1)
	await _walk_to(-3.5)
	await _wait_ticks(60)
	await _capture("middle")
	var stopped := _hero.position
	var stopped_camera := _camera.position
	await _wait_ticks(24)
	_check(_hero.position.distance_to(stopped) < 0.001 and _camera.position.distance_to(stopped_camera) < 0.012,
		"boots and camera settle at the middle stop")
	await _walk_to(stopped.z, 0.76)
	_check(_hero.position.x > stopped.x + 0.64 and absf(_hero.position.z - stopped.z) < 0.1,
		"sideways step toward the wall")
	await _capture("side_step")
	await _walk_to(-1.85, 0.37)
	_check(_hero.position.z > stopped.z + 1.4, "reversal near the inside wall")
	await _capture("reversal")
	for z: float in [-4.6, -8.8, -12.5, -15.5, -17.65]:
		await _walk_to(z)
	await _wait_ticks(36)
	await _capture("exit")
	_check(_exit_events == [true], "exit signal entered once")
	for z: float in [-13.4, -9.2, -4.9, -0.35, 3.5, start.z]:
		await _walk_to(z)
	await _wait_ticks(25)
	await _capture("return")
	_check(_hero.position.distance_to(start) < 0.17, "round trip returns to the entrance")
	_check(_exit_events == [true, false], "exit signal reset on return")
	_check(_airborne == 0, "floor contact across the continuous walk")
	_check(_furthest_lateral < _route.half_width + 0.04, "walk stayed inside the corridor")
	print("Round trip | %s sampled ticks | %s airborne | maximum lateral %.3f m | exit events %s" %
		[_samples, _airborne, _furthest_lateral, _exit_events])


func _road_pair() -> void:
	await _walk_to(3.75)
	await _wait_ticks(75)
	_hero.set_physics_process(false)
	_camera.set_process(false)
	var original := _camera.global_transform
	await _capture("raised")
	_key(KEY_R)
	await _wait_ticks(6)
	await _capture("flat")
	_check(_camera.global_transform.is_equal_approx(original), "raised and flat camera matches")
	var stones := _study.get_node("Dressing/Cobbles0") as MultiMeshInstance3D
	var flat_height := stones.multimesh.get_instance_transform(0).basis.y.length()
	_camera.set_process(true)
	_hero.set_physics_process(true)
	await _walk_to(0.9)
	await _capture("flat_walk")
	_key(KEY_R)
	await _wait_ticks(6)
	var raised_height := stones.multimesh.get_instance_transform(0).basis.y.length()
	_check(is_equal_approx(flat_height, raised_height * 0.075), "R switches the same stones between both heights")
	_check(_airborne == 0, "flat and raised share a grounded walking surface")


func _vista_pair() -> void:
	_study.set_painted_vista(false)
	_hero.set_physics_process(false)
	_camera.set_process(false)
	for stop: float in [6.0, -3.5, -17.58344]:
		_hero.position = _point(stop) + Vector3.UP * 0.000137
		_camera.snap()
		var original := _camera.global_transform
		await _wait_ticks(8)
		await _capture("distance_geometry_%s" % stop)
		_key(KEY_V)
		await _wait_ticks(8)
		await _capture("distance_paint_%s" % stop)
		_check(_camera.global_transform == original, "real and painted vistas use the same camera")
		_check(_study.get_node("PaintedVista").visible, "V displays the distant painting")
		_key(KEY_V)
		await _wait_ticks(4)
		_check(_study.get_node("VistaArch").visible, "V restores the 3D terrain")


func _record_frame() -> void:
	var frame := root.get_texture().get_image()
	if frame.get_size() != SIZE:
		_check(false, "recorded frame has the requested size")
		return
	frame.convert(Image.FORMAT_RGB8)
	_recording.store_buffer(frame.get_data())
	_recorded += 1


func _check_boundaries() -> void:
	_hero.position = _point(-9.65) + Vector3.UP * 0.02
	await _wait_ticks(8)
	await _hold(&"ui_right", 55)
	var right := _offset()
	await _hold(&"ui_left", 95)
	var left := _offset()
	_check(right > _route.half_width - 0.16 and right < _route.half_width + 0.04, "right wall stops movement")
	_check(left < -_route.half_width + 0.16 and left > -_route.half_width - 0.04, "left wall stops movement")
	_hero.position = _point(-17.65) + Vector3.UP * 0.02
	await _wait_ticks(8)
	await _hold(&"ui_up", 40)
	var far_cap := _hero.position.z
	_hero.position = _point(6.3) + Vector3.UP * 0.02
	await _wait_ticks(8)
	await _hold(&"ui_down", 40)
	var near_cap := _hero.position.z
	_check(absf(far_cap + 18.5) < 0.06 and absf(near_cap - 7.5) < 0.06, "both end caps stop movement")
	print("Containment | right %.3f m | left %.3f m | far %.3f m | near %.3f m" %
		[right, left, far_cap, near_cap])


func _check_navigation() -> void:
	var map := _hero.get_world_3d().navigation_map
	var start := _point(6.0)
	var goal := _point(-17.65)
	var route := NavigationServer3D.map_get_path(map, start, goal, true)
	_check(route.size() >= 2 and route[-1].distance_to(goal) < 0.23, "navigation reaches the overlook")
	var space := _hero.get_world_3d().direct_space_state
	var distance := 0.0
	for i in range(1, route.size()):
		var from := route[i - 1]
		var to := route[i]
		distance += from.distance_to(to)
		var trace := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.3, to + Vector3.UP * 0.3)
		trace.exclude = [_hero.get_rid()]
		_check(space.intersect_ray(trace).is_empty(), "navigation segment clears static blockers")
		for j in 9:
			var point := from.lerp(to, j / 8.0)
			_check(absf(point.x - _route.center_x(point.z)) <= _route.half_width + 0.05, "navigation stays inside corridor")
	var outside := NavigationServer3D.map_get_closest_point(map, _point(-10.0) + Vector3.RIGHT * 6.0)
	_check(absf(outside.x - _route.center_x(outside.z)) < _route.half_width, "outside move snaps inside the corridor")
	print("Navigation | %s points | %.2f m | outside projects to %s" % [route.size(), distance, outside])


func _walk_to(z: float, lateral := 0.0) -> void:
	var point := _point(z) + Vector3(lateral, 0, 0)
	var target := Vector2(point.x, point.z)
	for tick in 240:
		var direction := target - Vector2(_hero.position.x, _hero.position.z)
		if direction.length() < 0.10:
			_move(Vector2.ZERO)
			await _wait_ticks(4)
			return
		_move(direction.normalized())
		await physics_frame
		_samples += 1
		_airborne += int(not _hero.is_on_floor())
		_furthest_lateral = maxf(_furthest_lateral, absf(_offset()))
	_move(Vector2.ZERO)
	_check(false, "could not reach %s from %s" % [point, _hero.position])


func _point(z: float) -> Vector3:
	return Vector3(_route.center_x(z), 0.0, z)


func _offset() -> float:
	return _hero.position.x - _route.center_x(_hero.position.z)


func _move(direction: Vector2) -> void:
	var strength := [-direction.x, direction.x, -direction.y, direction.y]
	for i in ACTIONS.size():
		if strength[i] > 0.0:
			Input.action_press(ACTIONS[i], strength[i])
		else:
			Input.action_release(ACTIONS[i])


func _hold(action: StringName, ticks: int) -> void:
	Input.action_press(action)
	await _wait_ticks(ticks)
	Input.action_release(action)
	await _wait_ticks(4)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)


func _wait_ticks(ticks: int) -> void:
	for i in ticks:
		await physics_frame


func _capture(label: String) -> void:
	_check(_hero.is_on_floor(), "grounded at " + label)
	print("%s | boots %s | camera %s | on floor %s" %
		[label, _hero.position, _camera.position, _hero.is_on_floor()])
	if not _windowed:
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image.get_size() == SIZE and image.save_png("%s/%s.png" % [CAPTURES, label]) == OK,
		"saved 1376Γ—768 viewport frame " + label)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL " + message)
