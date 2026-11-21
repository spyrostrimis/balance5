extends SceneTree
## Exercises the normal action inputs. Windowed runs capture real rendered frames.

const STUDY := "res://scenes/pixel_canyon/pixel_canyon_follow.tscn"
const OPENING := "res://scenes/ui/opening_screen.tscn"
const OUT := "res://render_captures/pixel_canyon_follow/"
const Route := preload("res://scripts/pixel_canyon/pixel_follow_route.gd")

var world
var display
var windowed := false
var recording := false
var prefix := ""
var movie: FileAccess
var frames := 0
var ticks := 0
var failed := false
var shot_results: Array[bool] = []
var last_ground := Vector2.ZERO
var last_camera := 0.0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--catalog" in args:
		await check_catalog()
		return

	windowed = DisplayServer.get_name() != "headless"
	recording = "--record" in args
	prefix = "rough_" if "--rough" in args else ""
	prefix += "exact" if "--exact" in args else "leeway"
	change_scene_to_file(STUDY)
	await scene_changed
	display = current_scene
	world = display.get_node("Canvas/World")
	world.shot_resolved.connect(func(hit: bool) -> void: shot_results.append(hit))
	check(world.commander.position == Route.BOOTS, "original boot point")
	check(world.commander.perspective == 1.0, "original standing height")
	check(display.canvas.size == Vector2i(960, 540), "native canvas dimensions")
	var arch_at_spawn := Route.scale_at(Route.ARCH.y, world.camera_distance)
	if windowed:
		print("Renderer %s / %s | window %s | native %s" % [
			RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(),
			root.size, display.canvas.size])
		check(root.size == Vector2i(1376, 768), "capture window dimensions")
		check(display.picture.size == Vector2(960, 540), "native image shown at 1×")
	if recording:
		if not windowed:
			check(false, "--record requires a real window")
			quit(1)
			return
		movie = FileAccess.open("res://tmp/pixel_canyon_follow/%s.rgb" % prefix, FileAccess.WRITE)
		if not movie:
			check(false, "capture directory exists and is writable")
			quit(1)
			return
		RenderingServer.frame_post_draw.connect(record_frame)

	await mark("out_spawn", 36)
	await walk(&"ui_down", -72.5)
	await walk(&"ui_left", -97.5)
	Input.action_press(&"ui_down")
	await wait_ticks(16)
	Input.action_release(&"ui_down")
	check(world.ground.y >= Route.SHRUB.y + 18.0, "roots block boots from uphill")
	await walk(&"ui_up", -72.5)
	await mark("out_shrub_behind")
	await walk(&"ui_right", -60.0)
	await walk(&"ui_down", -118.75)
	await walk(&"ui_left", -97.5)
	await mark("out_shrub_front")
	await walk(&"ui_right", -60.0)
	await walk(&"ui_up", -72.5)
	await walk(&"ui_right", -45.0)
	await walk(&"ui_up", Route.BLOCKED_AT)
	Input.action_press(&"ui_up")
	await wait_ticks(24)
	Input.action_release(&"ui_up")
	check(world.ground.y == Route.BLOCKED_AT, "scout blocks the route in place")
	await mark("blocked_bend")

	await mark("miss", 0, false)
	await shoot()
	check(shot_results == [false] and not world.encounter_clear, "off-lane shot leaves scout standing")
	await walk(&"ui_down", 148.75)
	await mark("out_scout")
	await shoot()
	check(shot_results == [false, true] and world.encounter_clear, "same-lane shot clears scout")

	await walk(&"ui_right", 0.0)
	await walk(&"ui_up", Route.BEND_AT)
	await mark("out_bend", 30)
	var camera_at_turn: float = world.camera_distance
	Input.action_press(&"ui_down")
	await wait_ticks(8)
	Input.action_release(&"ui_down")
	if world.follow_leeway > 0.0:
		check(is_equal_approx(world.camera_distance, camera_at_turn), "reversal crosses band before camera backs up")
	await walk(&"ui_down", Route.BEND_AT - 48.75)
	check(world.camera_distance < camera_at_turn, "camera retreats after reversal")
	await mark("reverse_in_bend", 20)
	await walk(&"ui_up", Route.BEND_AT)
	await walk(&"ui_up", Route.OVERLOOK_AT)
	await mark("out_overlook")
	await walk(&"ui_up", Route.ROAD_END)
	check(world.ground.y == Route.ROAD_END, "arrives at far end")
	check(Route.scale_at(Route.ARCH.y, world.camera_distance) > arch_at_spawn * 2.5,
		"near arch grows to more than twice its spawn size")
	await mark("twin_arch", 42)

	await walk(&"ui_down", Route.OVERLOOK_AT)
	await mark("back_overlook")
	await walk(&"ui_down", Route.BEND_AT)
	await mark("back_bend")
	await walk(&"ui_down", 148.75)
	await walk(&"ui_left", -45.0)
	await mark("back_scout")
	check(world.encounter_clear and not world.get_node("Depth/Sentry").visible, "scout stays defeated downhill")
	await walk(&"ui_down", -72.5)
	await walk(&"ui_left", -60.0)
	await walk(&"ui_down", -118.75)
	await walk(&"ui_left", -97.5)
	await mark("back_shrub_front")
	await walk(&"ui_right", -60.0)
	await walk(&"ui_up", -72.5)
	await walk(&"ui_left", -97.5)
	await mark("back_shrub_behind")
	await walk(&"ui_right", 0.0)
	await walk(&"ui_up", 0.0)
	await mark("back_spawn", 36)
	check(world.ground.distance_to(Vector2.ZERO) < 0.001, "retrace ends on original ground point")

	if recording:
		RenderingServer.frame_post_draw.disconnect(record_frame)
		movie.close()
		print("Recorded %d frames at 30 fps" % frames)
	if not windowed:
		await check_edges_and_controls()
	print("Pixel Canyon Follow | %s | shots %s | %d physics ticks | pass %s" % [
		prefix, shot_results, ticks, not failed])
	quit(1 if failed else 0)


func check_edges_and_controls() -> void:
	await walk(&"ui_left", -10.0)
	await shoot()
	check(world.commander.sprite.flip_h and shot_results == [false, true, false],
		"left-facing shot resolves after the scout has gone")
	var width: float = Route.road(world.ground.y).y - world.BOOT_RADIUS
	for action: StringName in [&"ui_left", &"ui_right"]:
		var limit := -width if action == &"ui_left" else width
		await walk(action, limit)
		check(is_equal_approx(world.ground.x, limit), "road edge contains the boots")
	await walk(&"ui_down", Route.ROAD_START)
	check(world.ground.y == Route.ROAD_START, "near endpoint reachable")
	var was_rough: bool = world.rough_art
	tap_key(KEY_F3)
	check(world.rough_art != was_rough, "F3 toggles the drawing pass")
	tap_key(KEY_1)
	last_camera = world.camera_distance
	await wait_ticks(2)
	check(world.follow_leeway == 0.0 and world.commander.position.y == 325.0, "1 selects exact follow")
	tap_key(KEY_2)
	await wait_ticks(2)
	check(world.follow_leeway == 8.0, "2 selects leeway")
	tap_key(KEY_F2)
	var camera: float = world.camera_distance
	await wait_ticks(2)
	check(world.showing_reference and world.camera_distance == camera, "reference preserves camera")
	tap_key(KEY_F2)
	tap_key(KEY_F1)
	check(not world.showing_reference and world.get_node("../Screen/Interface/Hint").visible,
		"reference dismisses and F1 shows controls")
	check(world.get_node("../Screen/Interface/Hint").get_global_transform_with_canvas().origin == Vector2(20, 490),
		"controls stay fixed on screen")


func walk(action: StringName, target: float) -> void:
	var horizontal := action in [&"ui_left", &"ui_right"]
	var increasing := action in [&"ui_right", &"ui_up"]
	Input.action_press(action)
	var reached := false
	for tick in 900:
		await wait_ticks(1)
		var axis: float = world.ground.x if horizontal else world.ground.y
		if (increasing and axis >= target - 0.001) or (not increasing and axis <= target + 0.001):
			reached = true
			break
	Input.action_release(action)
	check(reached, "%s to %.2f (at %s)" % [action, target, world.ground])
	await wait_ticks(2)


func shoot() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	await wait_ticks(5)
	event = InputEventKey.new()
	event.keycode = KEY_SPACE
	Input.parse_input_event(event)
	await wait_ticks(50)


func wait_ticks(amount: int) -> void:
	for tick in amount:
		await physics_frame
		ticks += 1
		var camera: float = world.camera_distance
		var ground: Vector2 = world.ground
		var boot_y: float = world.commander.position.y
		check(absf(boot_y - Route.BOOTS.y) <= world.follow_leeway + 0.001, "boots stay in camera band")
		check(ground.distance_to(last_ground) <= 1.8, "continuous movement, no relocation")
		check(absf(camera - last_camera) <= absf(ground.y - last_ground.y) + 0.001,
			"camera follows only movement and settles on release")
		last_ground = ground
		last_camera = camera


func mark(label: String, hold := 18, snapshot := true) -> void:
	print("%s frame=%d tick=%d ground=%s camera=(%.2f, %.2f) boots=%s standing=%.2f" % [
		label, frames, ticks, world.ground, world.camera_center, world.camera_distance,
		world.commander.position.round(), world.commander.perspective * 125.0])
	if windowed and snapshot:
		await RenderingServer.frame_post_draw
		var art: Image = display.canvas.get_texture().get_image()
		check(art.save_png(OUT + "%s_%s.png" % [prefix, label]) == OK, "saved " + label)
		if label == "out_spawn":
			check(root.get_texture().get_image().save_png(OUT + "%s_viewport.png" % prefix) == OK,
				"saved full Forward+ viewport")
	await wait_ticks(hold)


func record_frame() -> void:
	var image: Image = display.canvas.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	movie.store_buffer(image.get_data())
	frames += 1


func tap_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release)


func check_catalog() -> void:
	change_scene_to_file(OPENING)
	await scene_changed
	current_scene.get_node("%DevelopersPage").pressed.emit()
	for card in current_scene.get_node("%Catalog").find_children("*", "PanelContainer", true, false):
		if card.get_meta("catalog_key", "") != STUDY:
			continue
		for button in card.find_children("*", "Button", true, false):
			if button.text != "Play":
				continue
			button.pressed.emit()
			await scene_changed
			check(current_scene.scene_file_path == STUDY, "Play opens Through the Bend")
			check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED, "study owns scaling")
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			Input.parse_input_event(escape)
			await scene_changed
			check(current_scene.scene_file_path == OPENING and current_scene.get_node("%Library").visible,
				"Escape returns to the Developers Page")
			check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "opening scale restored")
			print("Through the Bend catalog launch and Esc return: ", not failed)
			quit(1 if failed else 0)
			return
	check(false, "Through the Bend Play card found")
	quit(1)


func check(condition: bool, what: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL " + what)
