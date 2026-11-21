extends SceneTree
## Runs the round trip through normal input and captures the real viewport.

const SCENE := "res://scenes/rpg_2d/canyon_session_b.tscn"
const OUT := "res://render_captures/canyon_session_b/"
const PAINTED_SCENE := "res://scenes/rpg_2d/canyon_session_b_painted.tscn"
const PAINTED_OUT := "res://render_captures/canyon_session_b_painted/"
const STAIR := Vector2(991, 654)
const ACTIONS := [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]

var _failed := false
var _world
var _display
var _windowed := false
var _scene_path := SCENE
var _out := OUT
var _record_window := false
var _movie: FileAccess
var _frames := 0
var _ticks := 0
var _initial_scale := Vector2.ONE
var _wall: Image
var _actor: Image
var _last_ground: Vector2
var _out_stair: Image


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--painted" in args:
		_scene_path = PAINTED_SCENE
		_out = PAINTED_OUT
		_record_window = true
	if "--catalog" in args:
		await check_catalog()
		return
	_windowed = DisplayServer.get_name() != "headless"
	var scene_error := change_scene_to_file(_scene_path)
	if scene_error != OK:
		check(false, "could not open " + _scene_path)
		quit(1)
		return
	await scene_changed
	_display = current_scene
	_world = _display.get_node("Canvas/World")
	_initial_scale = _world.sprite.scale
	_last_ground = _world.commander.position
	_wall = _world.get_node("NearWall").texture.get_image()
	_actor = _world.sprite.texture.get_image()
	if _windowed:
		print("Renderer %s / %s | window %s | native %s" % [
			RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(),
			root.size, _display.canvas.size])
		check(RenderingServer.get_current_rendering_method() == "forward_plus", "Forward+ renderer")
		check(root.size == Vector2i(1376, 768), "Forward+ capture at 1376×768")
		check(_display.picture.size == Vector2(960, 540), "game image at native scale")
	if "--record" in args:
		if not _windowed:
			check(false, "--record needs a rendered window")
			quit(1)
			return
		var movie_path := "res://tmp/canyon_session_b/session_b.rgb"
		if _record_window:
			movie_path = "res://tmp/canyon_session_b_painted/round_trip_window.rgb"
		_movie = FileAccess.open(movie_path, FileAccess.WRITE)
		if _movie == null:
			check(false, "raw capture path is writable")
			quit(1)
			return
		RenderingServer.frame_post_draw.connect(record_frame)

	var entrance: Vector2 = _world.commander.position
	var entrance_view: Vector2 = _world.camera.position
	check(entrance_view.x + 480 < 1104, "twin arch outside entrance framing")
	await mark("entrance_out")
	await walk_path([Vector2(534, 1017), Vector2(610, 861), Vector2(681, 808), Vector2(756, 771)])
	var outward_cover := wall_overlap()
	check(outward_cover > 0.25 and outward_cover < 1.0, "commander partially hidden behind near wall")
	await mark("wall_out", 33)
	var stopped_camera: Vector2 = _world.camera.position
	var stopped_ground: Vector2 = _world.commander.position
	await wait_ticks(12)
	check(_world.camera.position == stopped_camera and _world.commander.position == stopped_ground,
		"camera and boots settle when input stops")
	await walk_to(Vector2(729, 784))
	await mark("wall_reversal", 18)
	await walk_path([Vector2(792, 757), Vector2(885, 730), Vector2(1009, 687), Vector2(1110, 654)])
	check(wall_overlap() == 0.0, "commander emerges from near wall")
	check(_world.camera.position.x + 480 >= 1344, "camera has uncovered the full arch")
	await mark("overlook_out", 25)

	var before_crossing: Vector2 = _world.commander.position
	await walk_to(Vector2(1225, before_crossing.y))
	check(absf(_world.commander.position.y - before_crossing.y) <= 2.5
		and _world.commander.position.x - before_crossing.x > 109, "free sideways crossing")
	await mark("crossed_road", 21)
	await walk_to(Vector2(1110, 654))
	await mark("overlook_back", 18)
	await walk_path([Vector2(1009, 687), Vector2(885, 730), Vector2(792, 757), Vector2(756, 771)])
	check(wall_overlap() > 0.25, "same wall covers the commander downhill")
	await mark("wall_back")
	await walk_path([Vector2(681, 808), Vector2(610, 861), Vector2(534, 1017), entrance])
	check(_world.commander.position.distance_to(entrance) < 3.0, "round trip returns to its starting ground point")
	await mark("entrance_back", 33)

	if _movie:
		RenderingServer.frame_post_draw.disconnect(record_frame)
		_movie.close()
		print("Recorded %d frames at 30 fps" % _frames)
	if not _windowed:
		await check_road_edges()
	print("Session B | %d ticks | pass %s" % [_ticks, not _failed])
	quit(1 if _failed else 0)


func walk_path(points: Array[Vector2]) -> void:
	for point in points:
		await walk_to(point)


func walk_to(target: Vector2) -> void:
	var reached := false
	for tick in 700:
		var remaining: Vector2 = target - _world.commander.position
		if remaining.length() < 2.55:
			reached = true
			break
		var horizontal := signf(remaining.x) if absf(remaining.x) > 1.15 else 0.0
		var vertical := signf(remaining.y) if absf(remaining.y) > 1.15 else 0.0
		if absf(remaining.x) > 2.0 * absf(remaining.y):
			vertical = 0.0
		elif absf(remaining.y) > 2.0 * absf(remaining.x):
			horizontal = 0.0
		set_input(Vector2(horizontal, vertical))
		await wait_ticks(1)
	check(reached, "walked to %s (at %s)" % [target, _world.commander.position])


func set_input(direction: Vector2) -> void:
	var pressed := [direction.x < 0, direction.x > 0, direction.y < 0, direction.y > 0]
	for index in ACTIONS.size():
		if pressed[index] != Input.is_action_pressed(ACTIONS[index]):
			if pressed[index]:
				Input.action_press(ACTIONS[index])
			else:
				Input.action_release(ACTIONS[index])


func wait_ticks(amount: int) -> void:
	for tick in amount:
		await physics_frame
		_ticks += 1
		var ground: Vector2 = _world.commander.position
		check(ground.distance_to(_last_ground) <= 2.4, "continuous walking at game speed")
		check(_world.sprite.scale == _initial_scale and _world.camera.zoom == Vector2.ONE,
			"sprite and camera scale stay fixed")
		_last_ground = ground


func check_road_edges() -> void:
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT]:
		set_input(direction)
		await wait_ticks(95)
		var edge: Vector2 = _world.commander.position
		await wait_ticks(12)
		check(absf(_world.commander.position.x - edge.x) < 1.1, "solid road edge")
	set_input(Vector2.ZERO)


func wall_overlap() -> float:
	var actor: Sprite2D = _world.sprite
	var size := Vector2i(64, 96)
	var frame := actor.frame_coords * size
	var origin := Vector2i(actor.global_position + actor.offset) - size / 2
	var wall_origin := Vector2i(_world.get_node("NearWall").position)
	var covered := 0
	var opaque := 0
	for y in size.y:
		for x in size.x:
			var tx := size.x - 1 - x if actor.flip_h else x
			if _actor.get_pixelv(frame + Vector2i(tx, y)).a == 0.0:
				continue
			opaque += 1
			var sample := origin + Vector2i(x, y) - wall_origin
			if Rect2i(Vector2i.ZERO, _wall.get_size()).has_point(sample) and _wall.get_pixelv(sample).a > 0.0:
				covered += 1
	return float(covered) / max(1, opaque)


func mark(label: String, holds := 14) -> void:
	set_input(Vector2.ZERO)
	await wait_ticks(2)
	print("%s frame=%d tick=%d boots=%s camera=%s wall_cover=%.1f%%" % [
		label, _frames, _ticks, _world.commander.position, _world.camera.position, wall_overlap() * 100.0])
	if _windowed:
		await RenderingServer.frame_post_draw
		var art: Image = _display.canvas.get_texture().get_image()
		check(art.save_png(_out + label + ".png") == OK, "saved " + label)
		if label in ["overlook_out", "overlook_back"]:
			var pixel := Vector2i(_world.get_global_transform_with_canvas() * STAIR)
			var crop := art.get_region(Rect2i(pixel - Vector2i(58, 48), Vector2i(116, 96)))
			if label == "overlook_out":
				_out_stair = crop
				check(root.get_texture().get_image().save_png(_out + "forward_plus_viewport.png") == OK, "saved viewport")
			else:
				check(_out_stair.get_data() == crop.get_data(), "same stair pixels on the return")
	await wait_ticks(holds)


func record_frame() -> void:
	var image: Image = root.get_texture().get_image() if _record_window else _display.canvas.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	_movie.store_buffer(image.get_data())
	_frames += 1


func check_catalog() -> void:
	change_scene_to_file("res://scenes/ui/opening_screen.tscn")
	await scene_changed
	current_scene.get_node("%DevelopersPage").pressed.emit()
	for card in current_scene.get_node("%Catalog").find_children("*", "PanelContainer", true, false):
		if card.get_meta("catalog_key", "") != _scene_path:
			continue
		for button in card.find_children("*", "Button", true, false):
			if button.text != "Play":
				continue
			button.pressed.emit()
			await scene_changed
			check(current_scene.scene_file_path == _scene_path, "Play opens " + _scene_path)
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			Input.parse_input_event(escape)
			await scene_changed
			check(current_scene.get_node("%Library").visible, "Esc returns to the Developers Page")
			print("Session B catalog launch and Esc return: ", not _failed)
			quit(1 if _failed else 0)
			return
	check(false, "found Session B Play card")
	quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL " + message)
