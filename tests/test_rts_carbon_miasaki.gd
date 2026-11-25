extends SceneTree
## Matched northeast captures and Miasaki playtest. Run windowed in Forward+.

const CARBON := "res://scenes/maps/rts_reusable_2_carbon.tscn"
const MIASAKI := "res://scenes/maps/rts_reusable_2_carbon_miasaki.tscn"
const CAPTURE_DIR := "res://render_captures/rts_carbon_miasaki/"
const MOVIE_DIR := "res://tmp/carbon_miasaki/frames/"
const FRAME_SIZE := Vector2i(1376, 768)
const OPENING := "res://scenes/ui/opening_screen.tscn"
const TITLE := "RTS Reusable 2 Carbon — Miasaki"
const STEP := 1.0 / 60.0
const TANK_SPAWN := Vector2(1160, 754) # On Carbon's main road.
const DUNE_GOAL := Vector2(1224, 548)
const CLIFF_GOAL := Vector2(1178, 231)
const SQUAD_SPAWN := Vector2(516, 448)
const SQUAD_GOAL := Vector2(776, 432)

var _failures := 0
var _record := false
var _movie_frame := 0


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("Miasaki verification timed out")
		quit(1))
	call_deferred("_run")


func _run() -> void:
	# Use the full capture window instead of the project's 16:9 letterbox.
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = FRAME_SIZE
	var args := OS.get_cmdline_user_args()
	if "--catalog" in args:
		await _catalog()
	elif "--clip" in args:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOVIE_DIR))
		_record = true
		await _route(MIASAKI)
		print("Recorded %d Forward+ frames at 30 fps" % _movie_frame)
	elif "--route-only" in args:
		await _verify_routes()
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
		var original_pixel := await _northeast(CARBON, "carbon")
		if "--baseline-only" not in args:
			var miasaki_pixel := await _northeast(MIASAKI, "miasaki")
			_check(original_pixel.get_data() == miasaki_pixel.get_data(), "Pixel captures match exactly")
			if "--proof" not in args:
				await _verify_routes()
	print("Carbon Miasaki verification: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _northeast(scene_path: String, stem: String) -> Image:
	var map := (load(scene_path) as PackedScene).instantiate() as RtsCarbonBattlefield
	root.add_child(map)
	_freeze_simulation(map)
	var tank := map.get_node("YSortWorld/BlueTank") as RtsCarbonUnit
	var red := map.get_node("YSortWorld/RedSquad3") as RtsCarbonUnit
	tank.position = Vector2(848, 380)
	_check(red.fit_count() == 4, "Four fit soldiers at northeast")
	_check(map.grid.is_walkable(map.grid.cell_of(tank.position)), "Tank pose sits on walkable sand")
	_check(not map.grid.is_walkable(map.grid.cell_of(Vector2(1096, 294))), "Cliff foot is blocked")
	map.set_selection([tank])
	map._sync_hud_state()
	for close: bool in [false, true]:
		map.close_zoom = close
		map.apply_zoom_framing()
		map.set_camera_focus(Vector2(980, 290)) # Carbon's key 2 position.
		map.camera.force_update_scroll()
		var framing := "close" if close else "command"
		await _save_still(stem + "_northeast_" + framing + ".png")
	_press_key(KEY_V)
	_check(map.pixel_mode, "V switches to the shared Pixel art")
	var pixel_frame := await _save_still(stem + "_northeast_close_pixel.png")
	_press_key(KEY_V)
	_check(not map.pixel_mode, "V returns to Detailed")
	if scene_path == MIASAKI and "--review" in OS.get_cmdline_user_args():
		_press_key(KEY_Z)
		_press_key(KEY_F1)
		await _save_still("miasaki_northeast_blocking.png")
		_press_key(KEY_F1)
		_press_key(KEY_1)
		var commander := map.get_node("YSortWorld/BlueCommander") as RtsCarbonUnit
		map.set_selection([commander])
		map._sync_hud_state()
		await _save_still("miasaki_opening_command.png")
	map.queue_free()
	await process_frame
	return pixel_frame


func _verify_routes() -> void:
	var original := await _route(CARBON)
	var painted := await _route(MIASAKI)
	_check(original == painted, "Identical endpoints, dune relief, shade and tread mask in both maps")


func _route(scene_path: String) -> Dictionary:
	var map := (load(scene_path) as PackedScene).instantiate() as RtsCarbonBattlefield
	root.add_child(map)
	_freeze_simulation(map)
	var tank := map.get_node("YSortWorld/BlueTank") as RtsCarbonUnit
	var squad := map.get_node("YSortWorld/BlueSquad1") as RtsCarbonUnit
	_stage(tank, TANK_SPAWN)
	_stage(squad, SQUAD_SPAWN)
	map.set_camera_focus(Vector2(1080, 630))
	map.camera.force_update_scroll()
	map._sync_hud_state()
	await process_frame
	await RenderingServer.frame_post_draw

	var start_zoom := map.camera.zoom.x
	_click_world(map, TANK_SPAWN, MOUSE_BUTTON_WHEEL_UP)
	_check(map.camera.zoom.x > start_zoom, "Battlefield mouse wheel zooms")
	_press_key(KEY_Z)
	_press_key(KEY_Z)
	_check(is_equal_approx(map.camera.zoom.x, start_zoom), "Z restores the Command preset after wheel zoom")
	map.camera.force_update_scroll()

	_click_world(map, TANK_SPAWN, MOUSE_BUTTON_LEFT)
	_check(map.selection.has(tank), "Battlefield click selects Vanguard Tank")
	await _play_seconds(map, tank, Vector2(1080, 630), 0.7)
	_click_world(map, DUNE_GOAL, MOUSE_BUTTON_RIGHT)
	_check(tank.move_goal_world.distance_to(DUNE_GOAL) < 1.5, "Battlefield click orders the east dune")
	var relief := await _play_seconds(map, tank, Vector2(1138, 546), 3.85)
	var dune_end := tank.position
	_check(relief > 0.65 and dune_end.distance_to(DUNE_GOAL) < 2.0, "Tank crossed the dune relief")
	_check(map.disturbed_tread_pixels > 100, "Tank pressed through the dune texture")
	var dune_cross_section := Vector3.ZERO
	# Read across the actual track where it enters the dune, after steering off the road.
	for y in range(288, 309):
		var section := _tread_cross_section(map._tread_img, y)
		if minf(section.x, section.z) > minf(dune_cross_section.x, dune_cross_section.z):
			dune_cross_section = section
	_check(minf(dune_cross_section.x, dune_cross_section.z) > 0.55 and dune_cross_section.y < 0.24,
			"Two separate compressed lanes cross the dune ripples")

	var minimap_point := (map.hud._minimap_rect.position + CLIFF_GOAL / map.hud.world_size * map.hud._minimap_rect.size) * map.hud.ui_scale()
	_mouse(minimap_point, MOUSE_BUTTON_RIGHT)
	_check(tank.move_goal_world.distance_to(CLIFF_GOAL) < 1.5, "Minimap click orders the cliff foot")
	await _play_seconds(map, tank, Vector2(1112, 365), 6.8)
	var cliff_end := tank.position
	var shade := map.shade_at(cliff_end)
	_check(cliff_end.distance_to(CLIFF_GOAL) < 2.0 and shade > 0.12, "Tank arrived in cliff shade")
	await _play_seconds(map, tank, Vector2(1112, 315), 0.7)

	map.set_camera_focus(Vector2(672, 465))
	map.camera.force_update_scroll()
	_click_world(map, SQUAD_SPAWN, MOUSE_BUTTON_LEFT)
	_check(map.selection.has(squad), "Battlefield click selects the Rifle Squad")
	await _play_seconds(map, squad, Vector2(672, 465), 0.7)
	_check(not squad._line_walkable(SQUAD_SPAWN, SQUAD_GOAL), "Orichalcum blocks the direct squad route")
	_click_world(map, SQUAD_GOAL, MOUSE_BUTTON_RIGHT)
	await _play_seconds(map, squad, Vector2(672, 465), 7.7)
	_check(squad.position.distance_to(SQUAD_GOAL) < 2.0 and squad.fit_count() == 4, "Four soldiers reached the far side of Orichalcum")
	var result := {
		"dune": dune_end, "relief": relief, "cliff": cliff_end, "shade": shade,
		"treads": map.disturbed_tread_pixels, "lane_strengths": dune_cross_section,
		"squad": squad.position,
	}
	print(scene_path.get_file(), " route ", result)
	map.queue_free()
	await process_frame
	return result


func _tread_cross_section(mask: Image, y: int) -> Vector3:
	# The 2:1 texture has approximately six pixels between the tread centres.
	for x in range(580, 638):
		var left := mask.get_pixel(x, y).r
		var center := mask.get_pixel(x + 3, y).r
		var right := mask.get_pixel(x + 6, y).r
		if left > 0.55 and right > 0.55 and center < 0.24:
			return Vector3(left, center, right)
	return Vector3.ZERO


func _play_seconds(map: RtsCarbonBattlefield, active: RtsCarbonUnit, camera_goal: Vector2, seconds: float) -> float:
	var peak_relief := 0.0
	for frame in roundi(seconds * 30.0):
		for substep in 2:
			for unit in map.get_living_units():
				unit.tick(STEP)
			map._process(STEP)
			peak_relief = maxf(peak_relief, map.height_at(active.position))
		if _record:
			var focus := map.hud.camera_world_rect.get_center().lerp(camera_goal, 0.045)
			map.set_camera_focus(focus)
			map.camera.force_update_scroll()
			await process_frame
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_jpg(MOVIE_DIR + "%05d.jpg" % _movie_frame, 0.92) == OK, "Saved video frame")
			_movie_frame += 1
		else:
			map.set_camera_focus(camera_goal)
			map.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	return peak_relief


func _stage(unit: RtsCarbonUnit, destination: Vector2) -> void:
	unit.grid.release(unit._claimed_cell, unit)
	unit.position = destination
	unit._claimed_cell = Vector2i(-999, -999)
	unit._update_cell_claim()
	unit.queue_redraw()


func _click_world(map: RtsCarbonBattlefield, world_point: Vector2, button: MouseButton) -> void:
	_mouse(map.get_canvas_transform() * world_point, button)


func _mouse(at: Vector2, button: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)


func _press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)


func _catalog() -> void:
	change_scene_to_file(OPENING)
	await scene_changed
	var opening := current_scene
	(opening.get_node("%DevelopersPage") as Button).pressed.emit()
	var play_button: Button
	var original_found := false
	for node in opening.find_children("*", "Button", true, false):
		var button := node as Button
		if button.tooltip_text == "Play " + TITLE:
			play_button = button
		elif button.tooltip_text == "Play RTS Reusable 2 Carbon":
			original_found = true
	_check(original_found and play_button != null and play_button.is_visible_in_tree(), "Both Play cards exist in the catalog")
	if play_button == null:
		return
	play_button.pressed.emit()
	await scene_changed
	_check(current_scene.scene_file_path == MIASAKI, "Miasaki Play card launches its scene")
	var map := current_scene as RtsCarbonBattlefield
	if map != null:
		for texture in [map._sand_hd, map._road_hd, map.hud._portraits_hd["blue_commander"]]:
			_check(_uses_miasaki(texture), "Loaded painted ground, road and portrait")
		for piece in map._pieces:
			_check(_uses_miasaki(piece.texture), "Loaded painted terrain " + piece.piece_id)
		for unit in map.get_living_units():
			_check(_uses_miasaki(unit._tex_main), "Loaded painted unit " + unit.sprite_key)
			if unit.role == RtsCarbonUnit.Role.TANK:
				_check(_uses_miasaki(unit._tex_turret), "Loaded independent painted turret")
	_press_key(KEY_ESCAPE)
	await scene_changed
	_check(current_scene.scene_file_path == OPENING and current_scene.get_node("%Library").visible, "Esc returns directly to Developers Page")


func _uses_miasaki(texture: Texture2D) -> bool:
	return texture != null and texture.resource_path.begins_with("res://assets/textures/rts/carbon_miasaki/")


func _freeze_simulation(map: RtsCarbonBattlefield) -> void:
	map.set_process(false)
	for unit in map.get_living_units():
		unit.set_physics_process(false)
		unit.peaceful = true


func _save_still(filename: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_check(frame.get_size() == FRAME_SIZE, "Forward+ capture resolution %s" % str(frame.get_size()))
	_check(frame.save_png(CAPTURE_DIR + filename) == OK, "Saved " + filename)
	return frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("CHECK FAILED: " + label)
