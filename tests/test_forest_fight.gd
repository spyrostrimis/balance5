extends SceneTree
## Run in Forward+ with -- --record for an uninterrupted live capture.

const Fight := preload("res://scripts/rpg_2d/forest_fight.gd")
const OPENING := "res://scenes/ui/opening_screen.tscn"
const SCENE := "res://scenes/rpg_2d/forest_fight.tscn"
const OUT := "res://render_captures/forest_fight/"
const FRAMES := OUT + "frames/"
const TICK := 1.0 / 60.0

var _fight: Fight
var _failures := 0
var _crossings := 0
var _clears := 0
var _contacts: Array[Node2D] = []
var _stops: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _start_usec := 0
var _frame := 0
var _duplicates := 0
var _last_frame := PackedByteArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file(OPENING) != OK:
		quit(1)
		return
	await scene_changed
	current_scene.get_node("%DevelopersPage").pressed.emit()
	if not await _play():
		quit(1)
		return
	if "--record" in OS.get_cmdline_user_args():
		await _record_sequence()
	else:
		await _escape("forest")
		if not await _play():
			quit(1)
			return
		await _verify_encounter()
		await _escape("cave")
		if await _play():
			_check(_fight.killed == 0 and _fight.bats.is_empty(),
				"fresh replay starts over before any bats have spawned")
	print("Forest Fight %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _play() -> bool:
	var catalog := current_scene.get_node("%Catalog")
	for card in catalog.find_children("*", "Control", true, false):
		if card.get_meta("catalog_key", "") != SCENE:
			continue
		for button in card.find_children("*", "Button", true, false):
			if button.text != "Play":
				continue
			button.pressed.emit()
			await scene_changed
			_fight = current_scene as Fight
			if _fight == null:
				_check(false, "Play loads the fight scene")
				return false
			_fight.set_physics_process(false)
			_fight.entered_threshold.connect(func() -> void: _crossings += 1)
			_fight.cave_cleared.connect(func() -> void: _clears += 1)
			_fight.bat_contacted.connect(func(bat: Node2D) -> void: _contacts.append(bat))
			_fight.shot_stopped.connect(func(point: Vector2, target: Node2D) -> void:
				_stops.append({"point": point, "target": target}))
			_fight.hero.shot_fired.connect(func(point: Vector2, direction: Vector2) -> void:
				_shots.append({"point": point, "direction": direction}))
			_check(_fight.stage == Fight.Stage.FOREST and _fight.forest.commander.position.y == 1720.0,
				"Developers Page Play starts at the beginning of the painted forest walk")
			return true
	_check(false, "Developers Page shows the Forest Fight Play card")
	return false


func _escape(place: String) -> void:
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	await scene_changed
	_check(current_scene.scene_file_path == OPENING and current_scene.get_node("%Library").visible,
		"Esc from %s returns to the Developers Page" % place)


func _verify_encounter() -> void:
	await _walk_to(505.0)
	var before := _fight.forest.commander.position
	await _advance(14)
	_check(_fight.forest.commander.position == before, "stop before the mouth")
	await _advance(22, Vector2.DOWN)
	_check(_fight.forest.commander.position.y > before.y + 30.0 and _crossings == 0,
		"back away with no entry")
	await _cross_while_holding_forward()
	_check(_fight.bats.size() == 3, "exactly three bats spawn at the chamber reveal")

	await _advance(12, Vector2.UP)
	_check(_fight.hero.position.y < Fight.SPAWN.y - 30.0 and _fight.hero.combat_facing == 1,
		"forward movement carries over into floor depth while retaining right profile")
	await _advance(12, Vector2.DOWN)
	await _advance(1, Vector2(-1, 1), true)
	_check_shot(Vector2.LEFT, "while moving diagonally down-left")
	await _advance(26, Vector2.UP)
	_check(_fight.hero.combat_facing == -1, "depth movement retains left profile")
	_check(_stops.size() == 1 and is_equal_approx(_stops[0].point.x, Fight.LEFT_WALL),
		"first shot ends at the left wall")
	await _advance(1, Vector2(1, 1), true)
	_check_shot(Vector2.RIGHT, "while moving diagonally down-right")
	await _advance(28)
	_check(_stops.size() == 2 and is_equal_approx(_stops[1].point.x, Fight.RIGHT_WALL),
		"second shot ends at the right wall")
	_test_intersections()

	await _move_to(Fight.SPAWN)
	var still := _fight.hero.position
	await _advance(410)
	_check(_contacts.count(_fight.bats[0]) >= 2, "the first bat can contact again on another pass")
	_check(_contacts.count(_fight.bats[0]) <= 2, "first bat contacts only once per pass")
	_check(_fight.hero.position == still and _fight.killed == 0, "the contacts leave the Commander in place and able to shoot")
	await _advance(300, Vector2.ZERO, true)
	_check(_fight.killed == 1 and not _fight.bats[0].alive,
		"holding fire from the starting depth clears only the aligned bat")
	await _finish_other_lanes()
	var settled := _fight.hero.position
	await _advance(260, Vector2.LEFT, true)
	_check(_fight.hero.position.x < settled.x - 100.0, "movement continues after clearing the room")
	_check(_fight.killed == 3 and _clears == 1 and not _fight.clear_message.visible,
		"three bats stay dead and the single clear message goes away")
	await _verify_input_bindings()


func _verify_input_bindings() -> void:
	_fight.set_physics_process(true)
	var start := _fight.hero.position
	_key(KEY_RIGHT, true)
	await _live_ticks(8)
	_key(KEY_RIGHT, false)
	_key(KEY_W, true)
	await _live_ticks(8)
	_key(KEY_W, false)
	_check(_fight.hero.position.x > start.x and _fight.hero.position.y < start.y
		and _fight.hero.combat_facing == 1, "arrow and WASD bindings move freely in the running scene")
	var presses := _shots.size()
	for code in [KEY_SPACE, KEY_J]:
		await _live_ticks(18)
		_key(code, true)
		await _live_ticks(3)
		_key(code, false)
		presses += 1
		_check(_shots.size() == presses, "%s fires in the running scene" % OS.get_keycode_string(code))
	await _live_ticks(18)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(1000, 90)
	root.push_input(click)
	await _live_ticks(3)
	_check(_shots.size() == presses + 1, "left click fires")
	_check_shot(Vector2.RIGHT, "with the pointer high above the rifle")
	_fight.set_physics_process(false)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _live_ticks(count: int) -> void:
	for tick in count:
		await physics_frame


func _test_intersections() -> void:
	var left: Node2D = _fight.bats[0]
	var right: Node2D = _fight.bats[1]
	var start := Vector2(480, 360)
	left.body = start + Vector2(200, 0)
	right.body = start + Vector2(440, 0)
	left.position.y = 505.0
	right.position.y = 578.0
	var depth_miss := _fight.trace_shot(start, 1000.0, 578.0)
	_check(depth_miss.get("target") == right, "a visually overlapping bat in a different depth lane survives")
	left.position.y = 555.0
	var forward := _fight.trace_shot(start, 1000.0, 578.0)
	_check(forward.get("target") == left, "a small depth offset connects and the first valid bat stops the shot")
	var back := _fight.trace_shot(Vector2(1000.0, 360.0), 480.0, 578.0)
	_check(back.get("target") == right, "first intersection also works right-to-left")


func _check_shot(direction: Vector2, description: String) -> void:
	if _shots.is_empty():
		_check(false, "shot was fired " + description)
		return
	var shot: Dictionary = _shots.back()
	var origin := _fight.hero.get_shot_origin(int(direction.x))
	_check(shot.direction == direction and shot.point.distance_to(origin) < 0.01,
		"fires horizontally from the exposed barrel tip " + description)


func _finish_other_lanes() -> void:
	# Face left at the near lane, then face right at the back for the rear bat.
	await _move_to(Vector2(757, 649))
	await _advance(1, Vector2.LEFT)
	await _hunt(1)
	await _move_to(Vector2(680, 483))
	await _advance(1, Vector2.RIGHT)
	await _hunt(2)
	_check(_fight.killed == 3 and _clears == 1 and _fight.clear_message.visible,
		"repositioning gives two more one-shot kills and shows Cave clear")


func _hunt(index: int) -> void:
	for tick in 330:
		if not _fight.bats[index].alive:
			return
		await _advance(1, Vector2.ZERO, true)
	_check(false, "bat %d can be killed in its rifle-height lane" % (index + 1))


func _cross_while_holding_forward() -> void:
	var seen := {}
	for tick in 600:
		seen[_fight.stage] = true
		if _fight.stage == Fight.Stage.FIGHT:
			break
		await _advance(1, Vector2.UP)
	_check(_crossings == 1 and seen.has(Fight.Stage.THRESHOLD) and seen.has(Fight.Stage.INSIDE_DOOR)
		and seen.has(Fight.Stage.READY_RIFLE), "holding forward crosses once and plays every transition beat")
	_check(_fight.hero.mode == Hero2DController.Mode.COMBAT and _fight.hero.position == Fight.SPAWN
		and _contacts.is_empty(), "the rifle stance is automatic and opens with time to move")


func _record_sequence() -> void:
	_check(RenderingServer.get_current_rendering_method() == "forward_plus"
		and DisplayServer.get_name() != "headless", "running in a window with Forward+")
	_check(DirAccess.make_dir_recursive_absolute(FRAMES) == OK, "recording folder ready")
	await _walk_to(978.0)
	_start_usec = Time.get_ticks_usec()
	RenderingServer.frame_post_draw.connect(_record_frame)
	await _cross_while_holding_forward()
	await _advance(8, Vector2.UP)
	await _advance(8, Vector2.DOWN)
	while _contacts.is_empty() and Time.get_ticks_usec() - _start_usec < 14000000:
		await _advance(1)
	_check(_contacts.size() == 1, "recorded a visible first-pass contact")
	await _advance(24)
	await RenderingServer.frame_post_draw
	var bitmap := root.get_texture().get_image()
	_check(bitmap.get_size() == Vector2i(1376, 768), "capture is 1376 × 768")
	await _advance(1, Vector2.ZERO, true)
	await _advance(24)
	_check(_fight.killed == 1, "recorded the shot and one-hit fall")
	await _finish_other_lanes()
	await _advance(100)
	RenderingServer.frame_post_draw.disconnect(_record_frame)
	_check(bitmap.save_png(OUT + "cave-middle-depth.png") == OK, "saved the middle-depth capture")
	print("Continuous recording: %d frames at 30 fps, %d repeated frames" % [_frame, _duplicates])
	await _measure_middle()


func _measure_middle() -> void:
	_fight.hero.position = Fight.SPAWN
	_fight.hero.combat_facing = 1
	await _advance(1)
	await process_frame
	await RenderingServer.frame_post_draw
	var with_hero := root.get_texture().get_image()
	var sprite := _fight.hero.get_node("Sprite") as Sprite2D
	sprite.hide()
	await RenderingServer.frame_post_draw
	var without_hero := root.get_texture().get_image()
	sprite.show()
	var first := with_hero.get_height()
	var last := 0
	for y in range(275, 575):
		for x in range(343, 581):
			var diff := with_hero.get_pixel(x, y) - without_hero.get_pixel(x, y)
			if maxf(absf(diff.r), maxf(absf(diff.g), absf(diff.b))) < 0.055:
				continue
			first = mini(first, y)
			last = y
			break
	var height := last - first + 1
	print("Rendered crown to boots: %d px (%.1f%% of the frame), rows %d–%d" %
		[height, 100.0 * height / 768.0, first, last])
	_check(height >= 269 and height <= 284, "middle-depth scale meets the framing reference")


func _record_frame() -> void:
	var number := floori((Time.get_ticks_usec() - _start_usec) * 30.0 / 1000000.0)
	if number < _frame:
		return
	var jpeg := root.get_texture().get_image().save_jpg_to_buffer(0.94)
	if _last_frame.is_empty():
		_last_frame = jpeg
	while _frame < number:
		_write_frame(_last_frame)
		_duplicates += 1
	_write_frame(jpeg)
	_last_frame = jpeg


func _write_frame(jpeg: PackedByteArray) -> void:
	var stream := FileAccess.open(FRAMES + "%05d.jpg" % _frame, FileAccess.WRITE)
	if stream != null:
		stream.store_buffer(jpeg)
	_frame += 1


func _walk_to(y: float) -> void:
	for tick in 750:
		if _fight.forest.commander.position.y <= y:
			return
		await _advance(1, Vector2(
			clampf((Fight.DOOR_X - _fight.forest.commander.position.x) * 0.015, -0.4, 0.4), -1.0))
	_check(false, "reaches forest Y %.0f" % y)


func _move_to(target: Vector2) -> void:
	for tick in 240:
		var remaining := target - _fight.hero.position
		if remaining.length() < 1.0:
			return
		var speed := Vector2(_fight.hero.combat_speed_x, _fight.hero.combat_speed_y)
		await _advance(1, (remaining / (speed * TICK)).limit_length())
	_check(false, "reaches floor position %s" % target)


func _advance(count: int, movement := Vector2.ZERO, fire := false) -> void:
	for tick in count:
		await physics_frame
		_fight.step(movement, fire, TICK)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("OK: ", description)
	else:
		_failures += 1
		push_error(description)
