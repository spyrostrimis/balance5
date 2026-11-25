extends SceneTree
## Headless gameplay and catalog checks. Add --stills for Forward+ evidence.

const STUDY := "res://scenes/forest_fight_4/forest_fight_4.tscn"
const OPENING := "res://scenes/ui/opening_screen.tscn"
const Scene := preload(STUDY)
const Study := preload("res://scripts/forest_fight_4/forest_fight_4.gd")
const Layout := preload("res://scripts/forest_fight_4/forest_fight_4_layout.gd")
const Bat := preload("res://scripts/forest_fight_4/forest_fight_4_bat.gd")
const CAPTURES := "res://render_captures/forest_fight_4/"
const TICK := 1.0 / 60.0
const DIAGONAL := Vector2(0.89442719, -0.44721360)

var game: Study
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = Scene.instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	await physics_frame
	await _verify_projection_and_aim()
	await _verify_doorway()
	await _verify_live_controls()
	await _verify_boundaries()
	await _verify_encounter()
	if "--stills" in OS.get_cmdline_user_args():
		await _verify_stills()
	await _verify_catalog()
	print("Forest Fight 4 %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(int(failures > 0))


func _verify_projection_and_aim() -> void:
	var x := Study.ISO.x
	var y := Study.ISO.y
	check(is_equal_approx(rad_to_deg(x.angle()), 30.0), "ground X edge projects at +30°")
	check(is_equal_approx(rad_to_deg(y.angle()), 150.0), "ground Y edge projects at −30°")
	check(is_equal_approx(x.length(), y.length()), "equal square sides stay equal")
	for degrees in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0, 22.5, 61.7]:
		game.reset()
		var heading := Vector2.from_angle(deg_to_rad(degrees))
		var pivot := game.commander.position + Study.grip_for(heading)
		await _frame(Vector2.ZERO, pivot + heading * 440.0, true)
		check(game.bolts.size() == 1, "%s° fired" % degrees)
		if game.bolts.size() == 1:
			var bolt := game.bolts[0]
			check(bolt.direction.dot(heading) > 0.99999 and bolt.position.is_equal_approx(game.muzzle),
				"%s° bolt launches on aim from the visible barrel" % degrees)
			await _frame(Vector2.ZERO, pivot + heading * 440.0)
			check((bolt.position - game.muzzle).normalized().dot(heading) > 0.99999, "%s° bolt travels on aim" % degrees)
		check(game.hero.pose.frame_coords.y == game.hero.POSES[posmod(roundi(degrees / 45.0), 8)], "pose faces aim")
	for degrees in range(0, 360, 45):
		var pivot := game.commander.position + Study.AIM_PIVOT
		var edge := deg_to_rad(degrees + 22.5)
		await _frame(Vector2.ZERO, pivot + Vector2.from_angle(edge - 0.001) * 500.0)
		var before := game.muzzle
		await _frame(Vector2.ZERO, pivot + Vector2.from_angle(edge + 0.001) * 500.0)
		check(before.distance_to(game.muzzle) < 0.2, "barrel remains continuous at %s° pose boundary" % degrees)

	var projected_distances: Array[float] = []
	for direction in [Vector2.RIGHT, Vector2.UP, DIAGONAL]:
		_place(Layout.SPAWN)
		await _frame(direction, Layout.SPAWN + Vector2.RIGHT * 500.0)
		projected_distances.append((Study.GROUND * (game.commander.position - Layout.SPAWN)).length())
	for distance in projected_distances:
		check(absf(distance - Study.SPEED * TICK) < 0.01, "one tick travels the same world distance")
	print("Isometric grid, world speed, eight main headings and two in-between angles passed")


func _verify_doorway() -> void:
	game.reset()
	_place(Layout.DOOR - DIAGONAL * 99.0)
	var aim_at := Vector2(1670, -260)
	var player := game.commander
	var camera := game.camera
	var previous_side := signf(player.position.x - Layout.DOOR.x)
	for direction in [DIAGONAL, -DIAGONAL]:
		var shots_at_start := game.shot_count
		var largest_step := 0.0
		var largest_pan := 0.0
		for tick in 53:
			var previous := player.position
			var camera_before := camera.position
			await _frame(direction, aim_at, true)
			largest_step = maxf(largest_step, previous.distance_to(player.position))
			largest_pan = maxf(largest_pan, camera_before.distance_to(camera.position))
			check(game.aim.dot(game.gun_pivot.direction_to(aim_at)) > 0.99999,
				"tracking a fixed world landmark across the doorway")
		check(signf(player.position.x - Layout.DOOR.x) != previous_side, "held diagonal crosses the lip")
		check(game.shot_count >= shots_at_start + 4, "fire stays available across the lip")
		check(largest_step < 5.5 and largest_pan < 5.5, "movement and translation stay continuous")
		check(camera == game.camera and camera.zoom == Vector2.ONE and is_zero_approx(camera.rotation),
			"same camera and projection throughout")
		check(player == game.commander, "same actor throughout")
		previous_side = signf(player.position.x - Layout.DOOR.x)
	print("Doorway crossed in both directions with held movement and fire")


func _verify_live_controls() -> void:
	game.reset()
	_place(Vector2(1100, 251))
	game.camera.force_update_scroll()
	game.set_physics_process(true)
	_key(KEY_W, true)
	_key(KEY_D, true)
	for i in 35:
		await physics_frame
	_key(KEY_W, false)
	_key(KEY_D, false)
	check(game.commander.position.x > Layout.DOOR.x, "W+D walks into the cave in the running scene")
	_key(KEY_DOWN, true)
	_key(KEY_LEFT, true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(900, 235)
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	for i in 37:
		await physics_frame
	_key(KEY_DOWN, false)
	_key(KEY_LEFT, false)
	check(game.commander.position.x < Layout.DOOR.x, "arrow diagonal walks back in the running scene")
	check(game.shot_count == 1, "short left click fires during the held diagonal")
	game.set_physics_process(false)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _verify_boundaries() -> void:
	for route in [
		[Vector2(519, 592), Vector2.LEFT], [Vector2(2230, -155), Vector2.UP],
		[Vector2(1840, 143), Vector2.RIGHT]
	]:
		_place(route[0])
		var collided := false
		for tick in 46:
			await _frame(route[1], Layout.CHAMBER)
			collided = collided or game.commander.get_slide_collision_count() != 0
			check(Geometry2D.is_point_in_polygon(game.commander.position, PackedVector2Array(Layout.FLOOR)),
				"boots stay on solid ground")
			check(not Geometry2D.is_point_in_polygon(game.commander.position, PackedVector2Array(Layout.ROCK)),
				"boots remain outside the boulder")
		check(collided, "walk meets a painted cliff, cave wall, or boulder")


func _verify_encounter() -> void:
	game.reset()
	_place(Layout.CHAMBER)
	check(game.bats.size() == 3, "exactly three bats")
	var hero_feet := game.commander.position
	for i in 435:
		await _frame(Vector2.ZERO, Layout.CHAMBER + Vector2.RIGHT * 300.0)
		if game.contact_count > 0:
			break
	check(game.contact_count > 0, "live bat makes contact")
	check(game._sparks.any(func(spark: Study.Spark) -> bool: return spark.texture == Study.ARMOUR_SPARK),
		"contact shows a harmless armour spark")
	check(game.commander.position == hero_feet and game.bats_killed == 0 and game.commander.is_visible_in_tree(),
		"contact leaves standing Commander and all three bats")
	await _frame(Vector2.LEFT, hero_feet + Vector2.RIGHT * 200.0)
	check(game.commander.position.x < hero_feet.x, "movement continues immediately after contact")
	_place(Vector2(1850, 137))
	var first := game.bats[0]
	_station_bat(first, Vector2(2230, 137))
	_station_bat(game.bats[1], Vector2(2230, -110))
	_station_bat(game.bats[2], Vector2(1450, 121))
	var blocked_before := game.blocked_count
	await _fire_at(first.body_center())
	check(first.alive and game.blocked_count == blocked_before + 1, "boulder intercepts before a bat behind it")

	_place(Layout.CHAMBER)
	_station_bat(first, Layout.CHAMBER + Vector2(-164, -63))
	var sight := first.body_center() - (Layout.CHAMBER + Study.AIM_PIVOT)
	await _fire_at(first.body_center() + sight.normalized().orthogonal() * 75.0)
	check(first.alive and game.bats_killed == 0, "a diagonal shot passing beside the bat misses")

	_station_bat(game.bats[1], Layout.CHAMBER + Vector2(122, -115))
	_station_bat(game.bats[2], Layout.CHAMBER + Vector2(-160, 98))
	var shots_before := game.shot_count
	for i in game.bats.size():
		var bat := game.bats[i]
		await _fire_at(bat.body_center())
		check(not bat.alive and game.bats_killed == i + 1, "one shot kills bat %d" % (i + 1))
	check(game.shot_count - shots_before == 3, "three shots clear three bats")
	await _frame(Vector2.ZERO, Layout.CHAMBER + Vector2.RIGHT * 300.0)
	check(game.clear_label.visible, "clear cue appears")
	_place(Layout.DOOR + DIAGONAL * 42.0)
	for i in 32:
		await _frame(-DIAGONAL, Layout.SPAWN)
	check(game.commander.position.x < Layout.DOOR.x and game.bats_killed == 3, "walk back outside after the clear")
	game.reset()
	check(game.bats.all(func(bat: Bat) -> bool: return bat.alive), "restart restores the three-bat encounter")
	print("Cliff and rock containment, harmless contact, a blocked shot, a miss and three one-shot kills passed")


func _station_bat(bat: Bat, feet: Vector2) -> void:
	bat.position = feet
	bat.altitude = Bat.PASS_HEIGHT


func _fire_at(target: Vector2) -> void:
	game.fire_delay = 0.0
	game.bolts.clear()
	game._track_aim(target)
	game._update_art(Vector2.ZERO)
	for tick in 40:
		await physics_frame
		game._update_shots(tick == 0, TICK)


func _verify_stills() -> void:
	check(RenderingServer.get_current_rendering_method() == "forward_plus", "Forward+ evidence")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
	game.reset()
	await _pose_at(Layout.SPAWN)
	await _still("forest.png")
	await _height("near forest")
	await _pose_at(Vector2(1018, 270))
	await _height("far forest")

	await _pose_at(Vector2(911, 408), Vector2.RIGHT)
	await _overlap(game.get_node("Actors/Fence"), "forest fence")
	await _pose_at(Vector2(1178, 168), DIAGONAL)
	await _overlap(game.roof, "cave roof")
	await _still("doorway.png")

	await _pose_at(Vector2(2040, 104), Vector2.LEFT)
	await _overlap(game.get_node("Actors/Boulder"), "cave boulder")
	await _pose_at(Vector2(1810, 52))
	game._update_encounter(TICK)
	await _still("cave.png")
	await _height("inside cave")


func _height(place: String) -> void:
	var pivot := Vector2i(game.commander.get_global_transform_with_canvas().origin)
	var region := Rect2i(pivot - Vector2i(110, 150), Vector2i(220, 168))
	var with_pose := (await _image()).get_region(region)
	game.hero.pose.hide()
	var without_pose := (await _image()).get_region(region)
	game.hero.pose.show()
	var rows: Array[int] = []
	for y in region.size.y:
		for x in region.size.x:
			var a := with_pose.get_pixel(x, y)
			var b := without_pose.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 0.035:
				rows.append(y)
				break
	var height := rows[-1] - rows[0] + 1 if not rows.is_empty() else 0
	print("Standing raster height (%s): %d px of %d (%.2f%%)" % [place, height, Study.VIEW.y, 100.0 * height / Study.VIEW.y])
	check(height >= 129 and height <= 132, "Commander stays at 17% of frame height")


func _overlap(prop: Sprite2D, prop_name: String) -> void:
	# Count the pose pixels actually hidden by a foreground prop.
	var cropped := await _pose_difference()
	prop.hide()
	var exposed := await _pose_difference()
	prop.show()
	print("%s occludes %d Commander pixels" % [prop_name, exposed - cropped])
	check(exposed > cropped + 40 and cropped > 1000, "%s selectively covers the Commander" % prop_name)


func _pose_difference() -> int:
	var pivot := Vector2i(game.commander.get_global_transform_with_canvas().origin)
	var region := Rect2i(pivot - Vector2i(110, 150), Vector2i(220, 168))
	var with_pose := (await _image()).get_region(region)
	game.hero.pose.hide()
	var without_pose := (await _image()).get_region(region)
	game.hero.pose.show()
	var count := 0
	for y in region.size.y:
		for x in region.size.x:
			if not with_pose.get_pixel(x, y).is_equal_approx(without_pose.get_pixel(x, y)):
				count += 1
	return count


func _pose_at(feet: Vector2, heading := Vector2.RIGHT) -> void:
	_place(feet)
	await _frame(Vector2.ZERO, feet + Study.AIM_PIVOT + heading * 400.0)
	game.camera.force_update_scroll()


func _image() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _still(name: String) -> void:
	var image := await _image()
	check(image.get_size() == Study.VIEW, "1376×768 still")
	check(image.save_png(CAPTURES + name) == OK, "%s saved" % name)


func _verify_catalog() -> void:
	check(change_scene_to_file(OPENING) == OK, "opening scene loads")
	await scene_changed
	var shell := [root.title, root.size, root.content_scale_size]
	current_scene.get_node("%DevelopersPage").pressed.emit()
	var catalog := current_scene.get_node("%Catalog")
	var play: Button
	var earlier := 0
	for section in catalog.get_children():
		for card in section.get_children():
			var path: String = card.get_meta("catalog_key", "")
			if path in ["res://assets/scenes/forest_test/forest_walk.tscn",
				"res://scenes/rpg_2d/forest_fight.tscn", "res://scenes/forest_fight_2/forest_fight_2.tscn"]:
				earlier += 1
			if path == STUDY:
				for button in card.find_children("*", "Button", true, false):
					if button.text == "Play":
						play = button
	check(earlier == 3, "all earlier forest studies are listed")
	check(is_instance_valid(play), "new Play card available")
	if not is_instance_valid(play):
		return
	play.pressed.emit()
	await scene_changed
	check(current_scene.scene_file_path == STUDY, "Play launches Fight 4")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await scene_changed
	check(current_scene.get_node("%Library").visible, "Esc returns to Developers Page")
	check(shell == [root.title, root.size, root.content_scale_size], "launcher window settings restored")
	print("Developers Page Play and Esc passed")


func _place(point: Vector2) -> void:
	game.commander.position = point
	game.camera.position = point + Study.CAMERA_BIAS


func _frame(move: Vector2, aim: Vector2, fire := false) -> void:
	await physics_frame
	game.step(move, aim, fire, TICK)


func check(condition: bool, details: String) -> void:
	if not condition:
		failures += 1
		push_error("Fight 4: " + details)
