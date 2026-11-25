extends SceneTree
## Records an uninterrupted run of the live Forward+ scene at real-time pace.
## Encode with FFmpeg, using a 30 fps numbered JPEG sequence.

const Scene := preload("res://scenes/forest_fight_4/forest_fight_4.tscn")
const Study := preload("res://scripts/forest_fight_4/forest_fight_4.gd")
const Layout := preload("res://scripts/forest_fight_4/forest_fight_4_layout.gd")
const Bat := preload("res://scripts/forest_fight_4/forest_fight_4_bat.gd")
const TICK := 1.0 / 60.0
const FPS := 30.0
const PATH := "res://tmp/forest_fight_4/clip"
const HEADING := Vector2(0.89442719, -0.44721360)

var game: Study
var frame := 0
var dropped := 0
var start_usec := 0
var last_frame := PackedByteArray()
var fired_bearings: Array[float] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
		push_error("The recording requires the real Forward+ viewport.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH))
	game = Scene.instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if root.get_texture().get_size() != Vector2(Study.VIEW):
		push_error("Capture viewport must be 1376×768.")
		quit(1)
		return
	start_usec = Time.get_ticks_usec()
	RenderingServer.frame_post_draw.connect(_capture)

	await _hold(28, Vector2.ZERO, Layout.SPAWN + Study.AIM_PIVOT + Vector2.RIGHT * 500.0)
	var trail: Vector2 = Layout.SPAWN + Study.grip_for(HEADING) + HEADING * 1030.0
	await _hold(9, Vector2.ZERO, trail)
	await _hold(1, HEADING, trail, true)
	await _hold(158, HEADING, trail)
	var cave_aim := game.commander.position + Study.grip_for(HEADING) + HEADING * 720.0
	var entry := game.commander.position
	await _hold(1, HEADING, cave_aim, true)
	await _hold(104, Vector2(1.0, -0.18).normalized(), cave_aim)

	var delay := 0.0
	var elapsed := 0.0
	var aim_at := cave_aim
	var previous_positions: Dictionary[Bat, Vector2] = {}
	while game.bats_killed < 3 and elapsed < 14.0:
		await physics_frame
		var prey := _select_target()
		var strafe := Vector2(0.11 * cos(elapsed * 1.8), 0.91 * sin(elapsed * 2.1))
		var fire := false
		if prey != null:
			var body := prey.body_center()
			var previous := previous_positions.get(prey, body) as Vector2
			var velocity := (body - previous) / TICK
			var pivot := game.gun_pivot
			var time_to_bat := maxf(0.0, (Study.GROUND * (body - pivot)).length() - Study.RIFLE_REACH) / Study.BOLT_SPEED
			aim_at = body + velocity * time_to_bat
			var bearing := rad_to_deg((aim_at - pivot).angle())
			if prey.hittable() and delay <= 0.0 and _fits_bearing(bearing, elapsed) and _clear_line(pivot, aim_at):
				fire = true
				delay = 0.75
				fired_bearings.append(bearing)
		for bat in game.bats:
			previous_positions[bat] = bat.body_center()
		delay -= TICK
		elapsed += TICK
		game.step(strafe, aim_at, fire, TICK)
	await _hold(68, Vector2.LEFT * 0.30, aim_at)
	RenderingServer.frame_post_draw.disconnect(_capture)
	print("Clip frames=%d, duplicate capture slots=%d, duration=%.2fs, inside shot at %s, kills=%d, attack angles=%s" % [
		frame, dropped, frame / FPS, entry, game.bats_killed, fired_bearings,
	])
	quit(int(game.bats_killed != 3 or entry.x <= Layout.DOOR.x or fired_bearings.size() < 3))


func _select_target() -> Bat:
	var closest: Bat
	var score := INF
	for bat in game.bats:
		if not bat.alive:
			continue
		var distance := (bat.body_center() - game.commander.position - Study.AIM_PIVOT).length()
		var priority := distance + (0.0 if bat.hittable() else 340.0)
		if priority < score:
			closest = bat
			score = priority
	return closest


func _fits_bearing(bearing: float, seconds: float) -> bool:
	if fired_bearings.is_empty():
		return absf(bearing) > 98.0 or seconds > 4.0
	if seconds > 8.0:
		return true
	for earlier in fired_bearings:
		if absf(wrapf(bearing - earlier, -180.0, 180.0)) < 43.0:
			return false
	return true


func _clear_line(from: Vector2, to: Vector2) -> bool:
	return game._cast_wall(from + Study.SHOT_HEIGHT, to + Study.SHOT_HEIGHT).is_empty()


func _hold(ticks: int, direction: Vector2, target: Vector2, fire := false) -> void:
	for i in ticks:
		await physics_frame
		game.step(direction, target, fire, TICK)


func _capture() -> void:
	var slot := floori((Time.get_ticks_usec() - start_usec) * FPS / 1000000.0)
	if slot < frame:
		return
	var jpeg := root.get_texture().get_image().save_jpg_to_buffer(0.95)
	if last_frame.is_empty():
		last_frame = jpeg
	while frame < slot:
		_write(last_frame)
		dropped += 1
	_write(jpeg)
	last_frame = jpeg


func _write(bytes: PackedByteArray) -> void:
	var path := "%s/%05d.jpg" % [PATH, frame]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
	frame += 1
