extends SceneTree
## Drives the study through its ordinary input actions. Optional movie output
## uses the same inputs and the real game viewport.

const STUDY := "res://scenes/pixel_canyon/pixel_canyon.tscn"
const CAMERA_STUDY := "res://scenes/pixel_canyon/pixel_canyon_camera.tscn"
const OPENING := "res://scenes/ui/opening_screen.tscn"
const CAPTURES := "res://render_captures/pixel_canyon/"
const CAMERA_CAPTURES := "res://render_captures/pixel_canyon_camera/"
const STANDING := [Vector2(545, 425), Vector2(511, 325), Vector2(514, 217), Vector2(575, 165)]

var world
var commander: CharacterBody2D
var shot_results: Array[bool] = []
var visited: Array[int] = []
var recording := false
var windowed := false
var failed := false
var ticks := 0
var movie: FileAccess
var comparison := -1
var version := ""
var frame_number := 0
var last_room := -1
var last_y := 0.0
var last_scroll := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	for index in 3:
		var letter := "ABC".substr(index, 1)
		if "--camera=" + letter in arguments:
			comparison = index
			version = letter
	if "--catalog" in arguments:
		await check_catalog()
		return
	recording = "--record" in arguments
	windowed = DisplayServer.get_name() != "headless"
	change_scene_to_file(_study_path())
	await scene_changed
	world = current_scene.get_node("Canvas/World")
	commander = world.commander
	world.room_entered.connect(func(index: int) -> void: visited.append(index))
	world.shot_resolved.connect(func(hit: bool) -> void: shot_results.append(hit))
	if comparison >= 0:
		tap_key(KEY_1 + comparison)
		await wait_ticks(2)
		var expected_calibration := comparison != 0
		check(commander.calibrated_depth == expected_calibration, "comparison key chooses depth mode")
		var scout: Sprite2D = world.get_node("Depth/Sentry")
		var scout_size: float = commander.calibrated_size_at(scout.position.y) if expected_calibration else 1.0
		check(is_equal_approx(scout.scale.x, scout_size), "scout uses the same local scale")
		# Key selection reveals the HUD. Keep the recorded comparison clean.
		world._hint_time = 0.0
		await wait_ticks(2)
	if recording:
		var path := (
			"res://tmp/pixel_study_frames.rgb" if comparison < 0
			else "res://tmp/pixel_canyon_camera/%s.rgb" % version
		)
		movie = FileAccess.open(path, FileAccess.WRITE)
		if movie == null or not windowed:
			push_error("Recording needs a windowed run and a writable tmp directory.")
			quit(1)
			return
		RenderingServer.frame_post_draw.connect(_record_frame)
	mark("Original stance")
	await wait_ticks(54)
	check(commander.position.is_equal_approx(Vector2(511, 325)), "reference boot position")
	check(world.commander.perspective == 1.0, "reference sprite scale")
	if windowed and not recording and comparison < 0:
		await snapshot("game_standing_1080p.png")
		world.set_reference(true)
		await snapshot("reference_game_1080p.png")
		world.set_reference(false)

	# Walk behind the shrub, go around its right edge and cross in front.
	await walk(&"ui_left", 462.0)
	await walk(&"ui_down", 377.0)
	await walk(&"ui_left", 412.0)
	check(commander.position.y < 406.0, "behind shrub")
	mark("Behind shrub")
	if windowed and not recording and comparison < 0:
		await snapshot("behind_shrub.png")
	await wait_ticks(30)
	await walk(&"ui_right", 469.0)
	await walk(&"ui_down", 425.0)
	await walk(&"ui_left", 414.0)
	check(commander.position.y > 406.0, "in front of shrub")
	mark("In front of shrub")
	if windowed and not recording and comparison < 0:
		await snapshot("in_front_of_shrub.png")
	await wait_ticks(27)
	if comparison >= 0:
		await walk(&"ui_right", STANDING[0].x)
		mark("Near paving")
		await wait_ticks(30)
		await walk(&"ui_left", 480.0)
	await walk(&"ui_right", 493.0)
	await walk(&"ui_up", 384.0)
	mark("Off-lane shot")
	await shoot()
	check(shot_results == [false], "off-lane shot misses")
	check(not world.encounter_clear, "first shot leaves scout standing")

	await walk(&"ui_up", 354.0)
	mark("Same-lane shot")
	await shoot()
	check(shot_results == [false, true], "same-lane shot hits")
	check(world.encounter_clear, "hit clears the bend")

	await walk(&"ui_up", 253.0)
	await walk(&"ui_right", 514.0)
	await walk(&"ui_up", 217.0)
	if comparison >= 0:
		mark("Upper road stop")
		await wait_ticks(36)
		mark("Downhill reversal")
		await walk(&"ui_down", 239.0)
		await wait_ticks(12)
		mark("Uphill reversal")
		await walk(&"ui_up", 217.0)
	elif windowed and not recording:
		await snapshot("far_standing.png")
	await walk(&"ui_right", 550.0)
	await walk(&"ui_up", 184.0)
	await walk(&"ui_right", 575.0)
	if comparison >= 0:
		await walk(&"ui_up", 165.0)
		check(world.room_index == 0, "upper gate standing mark is still in the first room")
		mark("Before the gate")
		await wait_ticks(30)
	await walk(&"ui_up", 158.0, 1)
	check(visited == [1], "bend leads to the overlook")
	mark("Arch Overlook")
	await wait_ticks(30)
	await walk(&"ui_up", 342.0)
	await walk(&"ui_right", 539.0)
	await walk(&"ui_up", 246.0)
	await walk(&"ui_right", 563.0)
	if windowed and not recording and comparison < 0:
		await snapshot("overlook_walk.png")
	await wait_ticks(138 if comparison < 0 else 24)
	if not recording or comparison >= 0:
		await walk(&"ui_down", 390.0)
		await walk(&"ui_down", 519.0, 0)
		mark("Return to the bend")
		await wait_ticks(12)
		check(visited == [1, 0], "overlook leads back to the bend")
		check(world.encounter_clear, "scout stays cleared on return")
		check(commander.position.distance_to(Vector2(569, 184)) < 19.0, "return spawn clears gate")
		await walk(&"ui_left", 556.0)
		check(world.commander.facing == -1 and world.commander.sprite.flip_h, "left-facing pose")
		await shoot()
		check(shot_results == [false, true, false], "left-facing shot resolves")
	if recording:
		RenderingServer.frame_post_draw.disconnect(_record_frame)
		movie.close()
		print("Recorded %d frames" % frame_number)
	print("Pixel canyon %s: rooms %s; shots %s; %.2f seconds of simulated play" % [version, visited, shot_results, ticks / 60.0])
	if comparison >= 0:
		await check_comparison_views()
	quit(1 if failed else 0)


func walk(action: StringName, target: float, stop_in_room := -1) -> void:
	var horizontal := action in [&"ui_left", &"ui_right"]
	var increasing := action in [&"ui_right", &"ui_down"]
	Input.action_press(action)
	var reached := false
	for tick in 375:
		await wait_ticks(1)
		if stop_in_room >= 0:
			if world.room_index == stop_in_room:
				reached = true
				break
		else:
			var axis := commander.position.x if horizontal else commander.position.y
			if (increasing and axis >= target) or (not increasing and axis <= target):
				reached = true
				break
	Input.action_release(action)
	check(reached, "%s to %s from room %s (at %s)" % [action, target, world.room_index, commander.position])
	await wait_ticks(2)


func shoot() -> void:
	# A keyboard event exercises the same just-pressed path as a key on a desk.
	var press := InputEventKey.new()
	press.keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	await wait_ticks(5)
	var release := InputEventKey.new()
	release.keycode = KEY_SPACE
	Input.parse_input_event(release)
	await wait_ticks(49)


func wait_ticks(amount: int) -> void:
	for tick in amount:
		await physics_frame
		ticks += 1
		if comparison >= 0:
			check_scroll()


func check_scroll() -> void:
	var scroll: Vector2 = world.get_viewport().canvas_transform.origin
	var y := commander.position.y
	var expected := 0
	if comparison == 2 and world.room_index == 0 and not world.showing_reference:
		expected = clampi(roundi((300.0 - y) / 6.0), 0, 24)
	check(scroll == Vector2(0, expected), "camera maps room to screen at boot Y %.2f: %s" % [y, scroll])
	if world.room_index == last_room and not world.showing_reference and not world._master.visible:
		if is_equal_approx(y, last_y):
			check(expected == last_scroll, "camera holds on a stop")
		elif comparison == 2:
			check(absi(expected - last_scroll) <= 1, "camera moves at most one art pixel per tick")
			check((expected - last_scroll) * (y - last_y) <= 0, "camera retraces on reversal")
	last_room = world.room_index
	last_y = y
	last_scroll = expected


func check_comparison_views() -> void:
	# Stills share exact world coordinates. The recording uses ordinary input and keeps its speed.
	world.encounter_clear = false
	world._enter_room(0)
	commander.facing = 1
	for ground: Vector2 in STANDING:
		if ground.y < 300.0 and not world.encounter_clear:
			world.encounter_clear = true
			world._enter_room(0)
		last_room = -1
		commander.place(ground)
		world._update_camera()
		await wait_ticks(3)
		if windowed:
			await snapshot("%s_y%d.png" % [version, ground.y])

	# A blocked stride into the bend lets the camera reach its full travel.
	if comparison == 2:
		world.encounter_clear = false
		world._enter_room(0)
		last_room = -1
		commander.place(Vector2(575, 153))
		world._update_camera()
		await wait_ticks(3)
		check(last_scroll == 24, "camera reaches the full 24-pixel extension")
		world._hint_time = 0.0
		await wait_ticks(2)
		if windowed:
			await snapshot("C_maximum_pan.png")
		tap_key(KEY_F2)
		last_room = -1
		await wait_ticks(3)
		check(world.showing_reference and last_scroll == 0, "F2 shows the master in fixed screen space")
		if windowed:
			await snapshot("C_reference.png")
		tap_key(KEY_F2)
		last_room = -1
		await wait_ticks(3)
		check(not world.showing_reference and last_scroll == 24, "F2 restores the live framing")
		if windowed:
			await snapshot("C_restored_pan.png")
		tap_key(KEY_F1)
		await wait_ticks(3)
		check(world._hint.is_visible_in_tree(), "controls appear during follow")
		check(world._hint.get_global_transform_with_canvas().origin == Vector2(20, 490),
			"controls stay attached to the screen")


func tap_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release)


func snapshot(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if comparison < 0:
		check(root.get_texture().get_image().save_png(CAPTURES + filename) == OK, "saved " + filename)
	else:
		var image: Image = current_scene.canvas.get_texture().get_image()
		image.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		check(image.save_png(CAMERA_CAPTURES + filename) == OK, "saved " + filename)


func check(ok: bool, what: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL " + what)


func _record_frame() -> void:
	var image: Image = current_scene.canvas.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	movie.store_buffer(image.get_data())
	frame_number += 1
	if comparison >= 0:
		check_scroll()

func mark(label: String) -> void:
	if recording:
		print("Frame %d  %s at %s" % [frame_number, label, commander.position])


func _study_path() -> String:
	return STUDY if comparison < 0 else CAMERA_STUDY


func check_catalog() -> void:
	change_scene_to_file(OPENING)
	await scene_changed
	current_scene.get_node("%DevelopersPage").pressed.emit()
	var play: Button
	for card in current_scene.get_node("%Catalog").find_children("*", "PanelContainer", true, false):
		if card.get_meta("catalog_key", "") != _study_path():
			continue
		for button in card.find_children("*", "Button", true, false):
			if button.text == "Play":
				play = button
				break
	if play == null:
		check(false, "study is available in the Developers Page")
		quit(1)
		return
	play.pressed.emit()
	await scene_changed
	check(current_scene.scene_file_path == _study_path(), "Play opens the study")
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED, "study owns scaling")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await scene_changed
	check(current_scene.scene_file_path == OPENING and current_scene.get_node("%Library").visible,
		"Escape returns to the Developers Page")
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "restored opening scale")
	print("Pixel canyon catalog launch and Esc return: ", not failed)
	quit(1 if failed else 0)
