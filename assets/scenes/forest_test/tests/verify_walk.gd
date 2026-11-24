extends SceneTree

const STUDY := "res://assets/scenes/forest_test/"
const Route := preload(STUDY + "forest_route.gd")
const Walk := preload(STUDY + "forest_walk.gd")
const Forest := preload(STUDY + "forest_walk.tscn")
const STOPS := ["01-entrance", "02-fern-grove", "03-rise", "04-clearing"]
const CAPTURES := STUDY + "captures/"
const LIVE_FRAMES := CAPTURES + "live_frames/"
const RECORDING_FPS := 30.0
const OPENING := "res://scenes/ui/opening_screen.tscn"

var walk: Walk
var failures := 0
var max_scale_step := 0.0
var max_camera_step := 0.0
var recording_start := 0
var recording_frame := 0
var recording_duplicates := 0
var last_frame := PackedByteArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	walk = Forest.instantiate()
	root.add_child(walk)
	current_scene = walk
	walk.set_physics_process(false)
	var rendered := DisplayServer.get_name() != "headless"
	var capture := rendered and "--stills" in OS.get_cmdline_user_args()
	print("Forest walk | rough=%s | driver=%s | method=%s | viewport=%s" % [
		walk.rough, RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_current_rendering_method(), root.get_visible_rect().size,
	])
	_check(is_equal_approx(_boot_screen().y, 537.6), "opening boots at 70%")
	_check(not walk.guides and not walk.readout.visible, "starts with guides hidden")
	_check(walk.pose.frame_coords == Vector2i.ZERO, "opening front idle")
	_check(walk.rough == ("--rough" in OS.get_cmdline_user_args()), "requested scenery loaded")
	if rendered:
		_check(root.get_visible_rect().size == Route.VIEW, "native capture viewport")
		_check(RenderingServer.get_current_rendering_method() == "forward_plus", "Forward+")
	if "--tour" in OS.get_cmdline_user_args():
		await _record_tour()
		return
	if capture:
		await _save(STOPS[0])
	await _measure("entrance start", capture)
	var starting_camera: Vector2 = walk.camera.position
	await _sideways()
	for index in Route.BOUNDARIES.size():
		var boundary := Route.START_Y - Route.BOUNDARIES[index]
		await _walk_y(boundary)
		await _stop()
		await _measure("%s end / %s start" % [
			Route.STRETCH_NAMES[index], Route.STRETCH_NAMES[index + 1],
		], capture)
		if index == 0:
			_check(starting_camera.y - walk.camera.position.y > 175.0, "camera traveled on entrance")
		var before_reverse: float = walk.camera.position.y
		var scale_at_boundary := walk.commander.scale.y
		await _walk_y(boundary + 26.0)
		_check(absf(walk.camera.position.y - before_reverse) < 1.0, "camera gives short reverse leeway")
		await _walk_y(boundary)
		_check(is_equal_approx(walk.commander.scale.y, scale_at_boundary), "matched size after reversal")
		await _walk_y(boundary - [140.0, 155.0, 290.0][index])
		await _stop()
		if capture:
			await _save(STOPS[index + 1])
		await _sideways()
		await _hold(0.22)
	await _step(Vector2.UP)
	await _stop()
	await _measure("clearing end", capture)
	_check(walk.commander.position.y == Route.NORTH_Y, "reached north end cap")
	_check(_boot_screen().y > 230.0 and _boot_screen().y < 520.0, "finish framing")
	for index in range(Route.BOUNDARIES.size() - 1, -1, -1):
		var boundary := Route.START_Y - Route.BOUNDARIES[index]
		await _walk_y(boundary)
		await _walk_y(boundary - 26.0)
		await _walk_y(boundary)
		await _walk_y(boundary + 55.0)
	await _walk_y(Route.SOUTH_Y)
	await _step(Vector2.DOWN)
	await _stop()
	_check(walk.commander.position.y == Route.SOUTH_Y, "reached south end cap")
	_check(walk.pose.frame_coords == Vector2i.ZERO, "return front idle")
	_check(max_scale_step < 0.002, "size continuity during steps and reversals")
	_check(max_camera_step < 6.0, "camera continuity during steps and reversals")
	print("Max physics step: scale %.5f (%.3f idle px), camera %.3f px" % [
		max_scale_step, max_scale_step * Route.START_HEIGHT, max_camera_step,
	])
	if "--catalog" in OS.get_cmdline_user_args():
		await _check_catalog()
	print("Forest walk %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check_catalog() -> void:
	var result := change_scene_to_file(OPENING)
	_check(result == OK, "opening screen scene loads")
	if result != OK:
		return
	await scene_changed
	var original_settings := [root.size, root.content_scale_size, root.title]
	current_scene.get_node("%DevelopersPage").pressed.emit()
	var catalog := current_scene.get_node("%Catalog")
	for section in catalog.get_children():
		for card in section.get_children():
			if card.get_meta("catalog_key", "") != Forest.resource_path:
				continue
			for button in card.find_children("*", "Button", true, false):
				if button.text != "Play":
					continue
				button.pressed.emit()
				await scene_changed
				_check(current_scene is Walk, "catalog Play opens the forest walk")
				_check(current_scene.get_node("Painting").visible, "packaged painting is visible")
				var esc := InputEventKey.new()
				esc.keycode = KEY_ESCAPE
				esc.physical_keycode = KEY_ESCAPE
				esc.pressed = true
				root.push_input(esc)
				await scene_changed
				_check(current_scene.get_node("%Library").visible, "Esc returns to the Developers Page")
				_check(original_settings == [root.size, root.content_scale_size, root.title],
					"forest restores the catalog window")
				print("Catalog Play and Esc checked")
				return
	_check(false, "Developers Page lists the forest Play card")


func _record_tour() -> void:
	var live := "--live-record" in OS.get_cmdline_user_args()
	if live:
		var mkdir := DirAccess.make_dir_recursive_absolute(LIVE_FRAMES)
		_check(mkdir == OK, "create live recording directory")
		if mkdir != OK or DisplayServer.get_name() == "headless":
			quit(1)
			return
		recording_start = Time.get_ticks_usec()
		RenderingServer.frame_post_draw.connect(_record_frame)
	await _hold(0.45)
	await _walk_y(1240.0)
	await _hold(0.35)
	await _walk_y(1070.0)
	await _walk_y(1150.0)
	await _walk_y(910.0)
	await _hold(0.35)
	await _walk_y(Route.NORTH_Y)
	await _hold(0.85)
	await _walk_y(Route.START_Y)
	await _hold(0.55)
	if live:
		RenderingServer.frame_post_draw.disconnect(_record_frame)
		print("Live capture: %d frames at 30 fps, %d duplicate frames, %.2f wall-clock seconds" % [
			recording_frame, recording_duplicates, (Time.get_ticks_usec() - recording_start) / 1e6,
		])
	print("Forest recording %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _record_frame() -> void:
	var elapsed := (Time.get_ticks_usec() - recording_start) / 1e6
	var frame_number := floori(elapsed * RECORDING_FPS)
	if frame_number < recording_frame:
		return
	var bitmap := root.get_texture().get_image()
	var jpeg := bitmap.save_jpg_to_buffer(0.96)
	if last_frame.is_empty():
		last_frame = jpeg
	while recording_frame < frame_number:
		_write_recording_frame(last_frame)
		recording_duplicates += 1
	_write_recording_frame(jpeg)
	last_frame = jpeg


func _write_recording_frame(jpeg: PackedByteArray) -> void:
	var filename := LIVE_FRAMES + "%05d.jpg" % recording_frame
	_check(not jpeg.is_empty(), "encode recording frame")
	var stream := FileAccess.open(filename, FileAccess.WRITE)
	if stream != null:
		stream.store_buffer(jpeg)
	else:
		_check(false, "write " + filename)
	recording_frame += 1


func _walk_y(target_y: float) -> void:
	var north := target_y < walk.commander.position.y
	var sign_y := -1.0 if north else 1.0
	for tick in 650:
		var feet := walk.commander.position
		var remaining := sign_y * (target_y - feet.y)
		if remaining <= 0.002:
			break
		var limits := Route.feet_limits(feet.y, walk.active_trail())
		var center := (limits.x + limits.y) * 0.5
		var steer := clampf((center - feet.x) * 0.014, -0.68, 0.68)
		var pace := Walk.SPEED.y * Route.figure_scale(feet.y) / Engine.physics_ticks_per_second
		await _step(Vector2(steer, sign_y).normalized().limit_length(remaining / pace))
		_check(walk.pose.frame_coords.y == (1 if north else 0), "directional north/south pose")
	_check(absf(walk.commander.position.y - target_y) < 0.003, "reached y %.0f" % target_y)


func _sideways() -> void:
	var limits := Route.feet_limits(walk.commander.position.y, walk.active_trail())
	for side in [-1, 1]:
		var target := limits.x if side < 0 else limits.y
		for tick in 250:
			await _step(Vector2(side, 0))
			if is_equal_approx(walk.commander.position.x, target):
				break
		await _step(Vector2(side, 0))
		_check(is_equal_approx(walk.commander.position.x, target), "boots stop at side %d" % side)
		_check(walk.pose.frame_coords == Vector2i(0, 2) and walk.pose.flip_h == (side < 0),
			"side pose and idle at the boundary")
		await _hold(0.16)


func _step(next_direction: Vector2) -> void:
	await physics_frame
	var prior_scale := walk.commander.scale.y
	var prior_camera: Vector2 = walk.camera.position
	walk.step_walk(next_direction, 1.0 / Engine.physics_ticks_per_second)
	max_scale_step = maxf(max_scale_step, absf(walk.commander.scale.y - prior_scale))
	max_camera_step = maxf(max_camera_step, walk.camera.position.distance_to(prior_camera))
	var feet := walk.commander.position
	var limits := Route.feet_limits(feet.y, walk.active_trail())
	_check(feet.x >= limits.x - 0.001 and feet.x <= limits.y + 0.001, "boot containment")
	var camera_edges := Rect2(walk.camera.position - Route.VIEW * 0.5, Route.VIEW)
	_check(Rect2(Vector2.ZERO, Route.CANVAS).encloses(camera_edges), "camera canvas containment")
	var onscreen := _boot_screen()
	_check(onscreen.y - Route.START_HEIGHT * walk.commander.scale.y > 0.0 and onscreen.y < Route.VIEW.y,
		"heroine inside the vertical frame")
	_check(onscreen.x > 90.0 and onscreen.x < Route.VIEW.x - 90.0,
		"heroine inside the horizontal frame")


func _stop() -> void:
	var feet := walk.commander.position
	var scale_before := walk.commander.scale
	await _hold(0.38)
	_check(walk.commander.position == feet, "boots still at a stop")
	_check(walk.commander.scale == scale_before, "size unaffected by camera settling")
	_check(walk.pose.frame_coords.x == 0, "stationary idle")


func _hold(seconds: float) -> void:
	for tick in ceili(seconds * Engine.physics_ticks_per_second):
		await _step(Vector2.ZERO)


func _boot_screen() -> Vector2:
	return walk.commander.get_global_transform_with_canvas().origin


func _measure(label: String, sample_pixels: bool) -> void:
	var feet := walk.commander.position
	var height := Route.START_HEIGHT * walk.commander.scale.y
	var actual := ""
	if sample_pixels:
		var boot := Vector2i(_boot_screen())
		var region := Rect2i(boot - Vector2i(90, 170), Vector2i(180, 176))
		await RenderingServer.frame_post_draw
		var with_pose := root.get_texture().get_image().get_region(region)
		walk.pose.hide()
		await RenderingServer.frame_post_draw
		var without_pose := root.get_texture().get_image().get_region(region)
		walk.pose.show()
		var first_row := region.size.y
		var last_row := -1
		for y in region.size.y:
			for x in region.size.x:
				var a := with_pose.get_pixel(x, y)
				var b := without_pose.get_pixel(x, y)
				if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 0.04:
					first_row = mini(first_row, y)
					last_row = y
					break
		var pixel_height := last_row - first_row + 1
		_check(absf(pixel_height - height) <= 3.0, "rendered idle height")
		actual = " | raster=%d px" % pixel_height
	print("%s | y=%.2f bootsY=%.1f idleHeight=%.2f (%.2f%%)%s" % [
		label, feet.y, _boot_screen().y, height, 100.0 * height / Route.VIEW.y, actual,
	])


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var bitmap := root.get_texture().get_image()
	_check(bitmap.get_size() == Vector2i(Route.VIEW), "actual screenshot dimensions")
	var filename := ("rough-" if walk.rough else "") + name + ".png"
	_check(bitmap.save_png(CAPTURES + filename) == OK, "save " + filename)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		if failures < 12:
			push_error(message)
