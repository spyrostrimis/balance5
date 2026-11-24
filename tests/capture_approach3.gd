extends SceneTree
## Windowed Forward+ evidence for the three canyon studies.
## Pass -- --record for the scripted walk, -- --walk-cycle for its pose crops,
## or -- --timing for a live lighting A/B.

const Approach := preload("res://scripts/rpg_2d/canyon_approach3.gd")
const SCENE := preload("res://scenes/rpg_2d/canyon_approach3.tscn")
const OUT := "res://render_captures/approach3/"
const STOPS := ["entrance", "bend", "upper", "end"]
const Y_STOPS := [1560.0, 1010.0, 360.0, 88.1]
const BASELINE_X := [[416.0, 509.5, 414.0, 398.7], [487.2, 494.25, 493.0, 453.4]]
const BASELINES := [
	"res://scenes/rpg_2d/canyon_orthographic_study.tscn",
	"res://scenes/rpg_2d/canyon_approach2_modular.tscn",
]

var _capture_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720) if "--record" in args else Vector2i(1376, 768)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if args.is_empty():
		await _capture_baselines()

	var study := SCENE.instantiate() as Approach
	root.add_child(study)
	study.controls.hide()
	study.hero.use_script_input = true
	if "--record" in args:
		await _record_walk(study)
	elif "--walk-cycle" in args:
		await _capture_walk_cycle(study)
	elif "--timing" in args:
		await _measure_lighting(study)
	else:
		await _capture_approach(study)
	quit(1 if _capture_failed else 0)


func _capture_baselines() -> void:
	for index in BASELINES.size():
		var study := (load(BASELINES[index]) as PackedScene).instantiate() as Canyon2DStudy
		root.add_child(study)
		study.set_hud_visible(false)
		study.hero.use_script_input = true
		for i in STOPS.size():
			study.hero.position = Vector2(float(BASELINE_X[index][i]), float(Y_STOPS[i]))
			study.hero.facing_dir_8way = Vector2.DOWN if i == 0 else Vector2.UP
			study.camera.snap_immediately()
			await _snapshot("a%d_%s" % [index + 1, STOPS[i]])
		study.queue_free()
		await process_frame


func _pose(study: Approach, pos: Vector2, facing: Vector2, mode: Hero2DController.Mode) -> void:
	study.hero.position = pos
	study.hero.facing_dir_8way = facing
	study.hero.combat_facing = -1 if facing.x < 0.0 else 1
	study.hero.set_mode(mode)
	study.camera.snap_immediately()
	for frame in 18:
		await physics_frame


func _capture_approach(study: Approach) -> void:
	for i in STOPS.size():
		var y: float = Y_STOPS[i]
		var facing := Vector2.DOWN if i == 0 else Vector2.UP
		await _pose(study, Vector2(Approach.road_center_x(y), y), facing, Hero2DController.Mode.EXPLORE)
		await _snapshot("a3_" + STOPS[i], study, i < 2)
		print(STOPS[i], " boots=", study.hero.position, " camera=", study.camera.position,
			" viewport boots=", study.hero.get_global_transform_with_canvas().origin, " arrived=", study.arrived)
	await _pose(study, Vector2(569, 536), Vector2.DOWN, Hero2DController.Mode.EXPLORE)
	await _snapshot("a3_boulder_behind_south", study, true)
	await _pose(study, Vector2(569, 586), Vector2.UP, Hero2DController.Mode.EXPLORE)
	await _snapshot("a3_boulder_in_front_north", study, true)
	await _pose(study, Vector2(569, 536), Vector2.UP, Hero2DController.Mode.EXPLORE)
	await _snapshot("a3_boulder_behind_north", study, true)
	await _pose(study, Vector2(569, 586), Vector2.DOWN, Hero2DController.Mode.EXPLORE)
	await _snapshot("a3_boulder_in_front_south", study, true)

	var samples := [Vector2(485, 1560), Vector2(480, 1003)]
	for i in samples.size():
		var light: String = ["light", "shade"][i]
		for pose in [[Vector2.DOWN, "front"], [Vector2.UP, "back"],
				[Vector2.RIGHT, "aim_right"], [Vector2.LEFT, "aim_left"]]:
			var facing: Vector2 = pose[0]
			var mode := Hero2DController.Mode.EXPLORE if facing.x == 0.0 else Hero2DController.Mode.COMBAT
			await _pose(study, samples[i], facing, mode)
			await _snapshot("a3_%s_%s" % [light, pose[1]], study, true)

	await _pose(study, samples[1], Vector2.DOWN, Hero2DController.Mode.EXPLORE)
	await _snapshot("a3_bend_surface", study, true)
	study.shafts.show()
	await _snapshot("a3_bend_shafts", study, true)
	study.shafts.hide()
	study.set_surface_lighting(false)
	await _pose(study, samples[1], Vector2.DOWN, Hero2DController.Mode.EXPLORE)
	await _snapshot("a3_bend_painted_light", study, true)
	study.set_surface_lighting(true)

	root.size = Vector2i(1280, 720)
	for frame in 5:
		await process_frame
	await _pose(study, samples[0], Vector2.DOWN, Hero2DController.Mode.EXPLORE)
	await _snapshot("a3_entrance_720", study, true)
	print("Resize picture ", study.world_viewport.size, " at ", study.picture.position)


func _snapshot(name: String, study: Approach = null, crop := false) -> void:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_save_png(image, name)
	if crop:
		_save_png(_hero_crop(study, image), name + "_hero")


func _hero_crop(study: Approach, image: Image) -> Image:
	var sprite: Sprite2D = study.hero.get_node("Sprite")
	var boot := (sprite.get_global_transform_with_canvas().origin + study.picture.position).round()
	return image.get_region(Rect2i(Vector2i(boot) - Vector2i(100, 158), Vector2i(200, 177)))


func _capture_walk_cycle(study: Approach) -> void:
	await _pose(study, Vector2(485, 1560), Vector2.DOWN, Hero2DController.Mode.EXPLORE)
	study.hero.set_physics_process(false)
	var sprite: Sprite2D = study.hero.get_node("Sprite")
	for row in 3:
		for phase in 4:
			sprite.frame_coords = Vector2i(phase + 1, row)
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			_save_png(_hero_crop(study, image), "cycle_%d_%d" % [row, phase])


func _save_png(image: Image, name: String) -> void:
	var result := image.save_png(OUT + name + ".png")
	if result != OK:
		_capture_failed = true
		push_error("Could not save %s: %s" % [name, error_string(result)])


func _record_walk(study: Approach) -> void:
	# Each shoulder point leaves room for the feet to clear the boulder footprint.
	await _walk_road(study, 640.0)
	await _walk_points(study, [Vector2(552, 592), Vector2(543, 550), Vector2(570, 536), Vector2(510, 488)])
	await _walk_road(study, 91.0)
	study.hero.script_input_dir = Vector2.UP
	await _wait_physics(25)
	study.hero.script_input_dir = Vector2.ZERO
	await _wait_physics(24)
	print("Walk north cap boots=", study.hero.position, " arrived=", study.arrived)

	study.hero.set_mode(Hero2DController.Mode.COMBAT)
	await _walk_points(study, [Vector2(527, 125)])
	_record_shot(study, Vector2.RIGHT)
	await _wait_physics(26)
	await _walk_points(study, [Vector2(451, 166)])
	_record_shot(study, Vector2.LEFT)
	await _wait_physics(26)

	study.hero.set_mode(Hero2DController.Mode.EXPLORE)
	await _walk_road(study, 488.0)
	await _walk_points(study, [Vector2(570, 536), Vector2(543, 550), Vector2(552, 592), Vector2(438, 638)])
	await _walk_road(study, 1720.0)
	await _wait_physics(30)
	print("Walk back boots=", study.hero.position)


func _record_shot(study: Approach, expected: Vector2) -> void:
	var bolt := study.hero.fire_horizontal_shot()
	if bolt == null or bolt.direction != expected:
		_capture_failed = true
		push_error("Expected a horizontal shot in direction %s" % expected)
	else:
		print("Shot ", bolt.direction, " at ", bolt.position)


func _walk_points(study: Approach, points: Array[Vector2]) -> void:
	for point in points:
		for step in 100:
			var remaining := point - study.hero.position
			if remaining.length() < 3.0:
				break
			study.hero.script_input_dir = remaining.normalized()
			await physics_frame
		if study.hero.position.distance_to(point) > 4.0:
			_capture_failed = true
			push_error("Shoulder point %s blocked at %s" % [point, study.hero.position])
	study.hero.script_input_dir = Vector2.ZERO


func _walk_road(study: Approach, y: float) -> void:
	var direction := signf(y - study.hero.position.y)
	for step in 1000:
		var at := study.hero.position
		if absf(y - at.y) < 2.8:
			study.hero.script_input_dir = Vector2.ZERO
			return
		var ahead := move_toward(at.y, y, 14.0)
		var side := clampf((Approach.road_center_x(ahead) - at.x) * 0.12, -1.0, 1.0)
		study.hero.script_input_dir = Vector2(side, direction).normalized()
		await physics_frame
	study.hero.script_input_dir = Vector2.ZERO
	_capture_failed = true
	push_error("Road point %.1f blocked at %s" % [y, study.hero.position])


func _wait_physics(count: int) -> void:
	for frame in count:
		await physics_frame


func _measure_lighting(study: Approach) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var rid := study.world_viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for lit in [true, false]:
		study.set_surface_lighting(lit)
		study.hero.position = Vector2(Approach.road_center_x(1200.0), 1200.0)
		study.hero.script_input_dir = Vector2.ZERO
		study.camera.snap_immediately()
		await _wait_physics(35)
		var wall_clock: Array[float] = []
		var gpu: Array[float] = []
		var time := Time.get_ticks_usec()
		while study.hero.position.y > 780.0:
			var side := clampf((Approach.road_center_x(study.hero.position.y - 14.0)
				- study.hero.position.x) * 0.12, -1.0, 1.0)
			study.hero.script_input_dir = Vector2(side, -1.0).normalized()
			await process_frame
			var next_time := Time.get_ticks_usec()
			wall_clock.append((next_time - time) / 1000.0)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			time = next_time
		study.hero.script_input_dir = Vector2.ZERO
		print("Surface lighting ", lit, " rendered frames ", wall_clock.size(),
			" frame median/p95 ms ", _percentiles(wall_clock), " GPU viewport median/p95 ms ", _percentiles(gpu))


func _percentiles(samples: Array[float]) -> Vector2:
	samples.sort()
	return Vector2(samples[samples.size() / 2], samples[floori((samples.size() - 1) * 0.95)])
