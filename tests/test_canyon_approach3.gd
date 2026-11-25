extends SceneTree
## Check the standalone study with the real movement, camera and projectile nodes.

const PATH := "res://scenes/rpg_2d/canyon_approach3.tscn"
const OPENING := "res://scenes/ui/opening_screen.tscn"
const Approach := preload("res://scripts/rpg_2d/canyon_approach3.gd")

var _failed := false
var _arrivals := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1376, 768)
	var original_scale_mode := root.content_scale_mode
	var study := (load(PATH) as PackedScene).instantiate() as Approach
	root.add_child(study)
	var hero := study.hero
	var sprite := hero.get_node("Sprite") as Sprite2D
	hero.use_script_input = true
	study.reached_lookout.connect(func() -> void: _arrivals += 1)
	await process_frame

	_check(study.world_viewport.size == Vector2i(1360, 765), "1360x765 view in a 1376x768 window")
	_check(study.picture.position == Vector2(8, 1), "centers on whole window pixels")
	_check(_idle_height(sprite) == 149, "149 opaque rows in reference front idle")
	root.size = Vector2i(1280, 720)
	await process_frame
	_check(study.world_viewport.size == Vector2i(1280, 720), "full 1280x720 view after resize")
	_check(_idle_height(sprite) == 140, "140 opaque rows after resize")
	root.size = Vector2i(1376, 768)
	await process_frame
	_check(_idle_height(sprite) == 149, "full-size atlas restored")

	var north_frames := {}
	hero.script_input_dir = Vector2.UP
	for frame in 44:
		await physics_frame
		north_frames[sprite.frame_coords] = true
	hero.script_input_dir = Vector2.ZERO
	await _steps(3)
	for column in range(1, 5):
		_check(north_frames.has(Vector2i(column, 1)), "north walk uses frame %d" % column)
	_check(sprite.frame_coords == Vector2i(0, 1), "stop lands on back idle")
	await process_frame
	var canvas_boot := sprite.get_global_transform_with_canvas().origin
	var camera_grid := study.world_viewport.get_canvas_transform().origin
	_check(canvas_boot.distance_to(canvas_boot.round()) < 0.01, "art anchor is snapped in render pixels")
	_check(camera_grid.distance_to(camera_grid.round()) < 0.01, "camera is snapped in render pixels")

	await _walk_center(study, 90.0)
	hero.script_input_dir = Vector2.UP
	await _steps(30)
	hero.script_input_dir = Vector2.ZERO
	await _steps(4)
	_check(absf(hero.position.y - 88.1) < 0.1, "physical north cap holds the boots near Y=88.1")
	_check(study.arrived and _arrivals == 1, "lookout event fires once")
	var boot_y := sprite.get_global_transform_with_canvas().origin.y
	_check(boot_y >= 189.0 and boot_y < 694.0, "full figure with headroom at the cap")
	await _walk_center(study, 1720.0)
	_check(absf(hero.position.y - 1720.0) < 3.0, "road-centre round trip reaches spawn row")
	_check(_arrivals == 1, "reversing does not repeat arrival")
	await _walk_center(study, 1930.0)
	hero.script_input_dir = Vector2.DOWN
	await _steps(35)
	hero.script_input_dir = Vector2.ZERO
	_check(absf(hero.position.y - 1933.9) < 0.25, "south cap holds the boots inside the painting")

	hero.position = Vector2(539, 1010)
	hero.script_input_dir = Vector2.LEFT
	await _steps(95)
	_check(hero.position.x > 438.0 and hero.position.x < 450.0, "inside bend wall stops the player")
	hero.script_input_dir = Vector2.RIGHT
	await _steps(180)
	_check(hero.position.x > 685.0 and hero.position.x < 704.0, "outside bend wall stops the player")
	hero.position = Vector2(570, 518)
	hero.script_input_dir = Vector2.DOWN
	await _steps(36)
	_check(hero.position.y < 548.0 and hero.position.y > 525.0, "raised boulder has a blocking foot on the north side")
	hero.position = Vector2(541, 518)
	await _steps(35)
	_check(hero.position.y > 595.0, "boulder has a clear route around its foot")
	hero.script_input_dir = Vector2.ZERO

	hero.position = Vector2(485, 1560)
	hero.set_mode(Hero2DController.Mode.COMBAT)
	var muzzle := hero.recoil_muzzle / Approach3Commander.DRAW_DENSITY
	for side in [Vector2.RIGHT, Vector2.LEFT]:
		hero.script_input_dir = side
		await _steps(5)
		hero.script_input_dir = Vector2.DOWN
		await _steps(4)
		_check(hero.combat_facing == int(side.x), "depth movement preserves rifle direction %s" % side)
		hero.script_input_dir = Vector2.ZERO
		var bolt := hero.fire_horizontal_shot()
		_check(bolt != null and bolt.direction == side, "rifle shot is horizontal %s" % side)
		var boot_world := hero.get_canvas_transform().affine_inverse() * (hero.get_canvas_transform() * hero.position).round()
		var tip := boot_world + Vector2(side.x * muzzle.x, muzzle.y)
		_check(bolt != null and bolt.position.distance_to(tip) < 0.01,
			"shot starts at the mirrored barrel tip %s" % side)
		_check(sprite.frame_coords == Vector2i(3, 3) and sprite.flip_h == (side.x < 0.0), "recoil uses the registered facing")
		await _steps(17)

	study.queue_free()
	await process_frame
	_check(root.content_scale_mode == original_scale_mode, "scene restores its window scale mode")

	await _catalog_round_trip()

	print("FAIL: Approach 3" if _failed else "PASS: Approach 3")
	quit(1 if _failed else 0)


func _catalog_round_trip() -> void:
	var result := change_scene_to_file(OPENING)
	_check(result == OK, "loads the opening screen")
	if result != OK:
		return
	await scene_changed
	var developers := current_scene.get_node("%DevelopersPage") as Button
	developers.pressed.emit()
	var play := _find_play_button(current_scene.get_node("%Catalog"))
	_check(play != null, "Developers Page shows the standalone Play card")
	if play == null:
		return
	play.pressed.emit()
	await process_frame
	await process_frame
	var scene := current_scene
	_check(scene != null and scene.scene_file_path == PATH, "Play opens Approach 3")
	if scene == null or scene.scene_file_path != PATH:
		return

	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	await process_frame
	await process_frame
	var library := current_scene.get_node_or_null("%Library") as Control if current_scene else null
	_check(library != null and library.visible, "Esc returns directly to the Developers Page")


func _find_play_button(node: Node) -> Button:
	if node.get_meta("catalog_key", "") == PATH:
		for candidate in node.find_children("*", "Button", true, false):
			if (candidate as Button).text == "Play":
				return candidate
	for child in node.get_children():
		var button := _find_play_button(child)
		if button != null:
			return button
	return null


func _idle_height(sprite: Sprite2D) -> int:
	var frame := sprite.texture.get_image().get_region(Rect2i(0, 0, 160, 168))
	return frame.get_used_rect().size.y


func _check(result: bool, description: String) -> void:
	if result:
		print("OK: ", description)
	else:
		_failed = true
		push_error(description)


func _steps(count: int) -> void:
	for frame in count:
		await physics_frame


func _walk_center(study: Approach, y: float) -> void:
	var hero := study.hero
	var direction := signf(y - hero.position.y)
	for step in 1000:
		var current := hero.position
		if absf(y - current.y) < 2.8:
			break
		var x := Approach.road_center_x(move_toward(current.y, y, 14.0))
		var side := clampf((x - current.x) * 0.12, -1.0, 1.0)
		hero.script_input_dir = Vector2(side, direction).normalized()
		await physics_frame
	hero.script_input_dir = Vector2.ZERO
	_check(absf(hero.position.y - y) < 3.0, "moves on the centerline to Y=%.0f" % y)
