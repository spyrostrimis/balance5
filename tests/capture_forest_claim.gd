extends SceneTree
## Captures the live 1376×768 Forward+ study and records its actual simulated tank routes.
const GAME := preload("res://scripts/rts_forest_claim/forest_claim_battlefield.gd")
const A := preload("res://scenes/rts/forest_claim/forest_claim_a.tscn")
const B := preload("res://scenes/rts/forest_claim/forest_claim_b.tscn")
const CAPTURE := "res://render_captures/forest_claim"
const CLIP := "res://tmp/forest_claim_clip"
var game: GAME
var cursor: Node2D
var painter: Node2D
var pointer := Vector2.ZERO
var frame := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
		push_error("The capture needs the live Forward+ viewport.")
		quit(1)
		return
	root.size = Vector2i(1376, 768)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE))
	await _load(A)
	await _still("a_command")
	await _load(B)
	await _still("b_command")
	if "--preview" in OS.get_cmdline_user_args():
		quit()
		return
	await _routes_and_close()
	await _record()
	quit()


func _load(scene: PackedScene) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = scene.instantiate()
	root.add_child(game)
	current_scene = game
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _unit(role: RtsCarbonUnit.Role) -> ForestClaimUnit:
	for unit in game.get_living_units():
		if unit.role == role and unit.team == RtsCarbonUnit.Team.BLUE:
			return unit as ForestClaimUnit
	return null


func _still(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var view := root.get_texture().get_image()
	assert(view.get_size() == Vector2i(1376, 768))
	view.save_png("%s/%s.png" % [CAPTURE, filename])


func _routes_and_close() -> void:
	var goal := Vector2(11.5, 10.5) * 32.0
	var output := {}
	for pair in [["a", A], ["b", B]]:
		await _load(pair[1])
		game.red_ai_active = false
		for unit in game.get_living_units():
			unit.peaceful = true
		var tank := _unit(RtsCarbonUnit.Role.TANK)
		game.set_selection([tank])
		await _still("%s_route" % pair[0])
		_click(game.hud.minimap_screen_point(goal), MOUSE_BUTTON_RIGHT)
		var route := []
		for i in range(720):
			await physics_frame
			if i % 6 == 0 or route.is_empty():
				var pixel := game.ground_to_screen(tank.position) * Vector2(root.size) / root.get_visible_rect().size
				route.append([pixel.x, pixel.y, tank.position.x, tank.position.y])
			if tank.order == RtsCarbonUnit.Order.NONE:
				break
		output[pair[0]] = route
		print("Route %s: distance=%.3f picked=%s" % [pair[0], tank.position.distance_to(goal), game._last_minimap_order])
		assert(tank.position.distance_to(goal) < 3.0)
	var file := FileAccess.open(CAPTURE + "/routes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output))
	await _load(A)
	game.red_ai_active = false
	var squad := _unit(RtsCarbonUnit.Role.SQUAD)
	squad.peaceful = true
	game.set_selection([squad])
	game.close_zoom = true
	game.apply_zoom_framing()
	game.set_camera_focus(Vector2(3.08, 10.75) * 32.0)
	_click(game.ground_to_screen(Vector2(3.62, 8.65) * 32.0), MOUSE_BUTTON_RIGHT)
	for i in 83:
		await physics_frame
	await _still("a_close")


func _record() -> void:
	await _load(B)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CLIP))
	for filename in DirAccess.get_files_at(CLIP):
		if filename.ends_with(".jpg"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(CLIP.path_join(filename)))
	var overlay := CanvasLayer.new()
	overlay.layer = 18
	game.add_child(overlay)
	painter = Node2D.new()
	overlay.add_child(painter)
	painter.draw.connect(_draw_pointer)
	var tank := _unit(RtsCarbonUnit.Role.TANK)
	var commander := _unit(RtsCarbonUnit.Role.COMMANDER)
	var squad := _unit(RtsCarbonUnit.Role.SQUAD)
	var tl := game.ground_to_screen(commander.position).min(game.ground_to_screen(tank.position)) - Vector2(21, 26)
	var br := game.ground_to_screen(commander.position).max(game.ground_to_screen(tank.position)) + Vector2(22, 16)
	pointer = tl - Vector2(42, 15)
	for i in range(540):
		if i < 32:
			_motion(pointer.lerp(tl, 0.095))
		elif i == 32:
			_button(tl, MOUSE_BUTTON_LEFT, true)
		elif i in range(33, 58):
			_motion(tl.lerp(br, float(i - 32) / 25.0), MOUSE_BUTTON_MASK_LEFT)
		elif i == 58:
			_button(br, MOUSE_BUTTON_LEFT, false)
			assert(game.selection.size() == 3)
		elif i == 78:
			_click(game.ground_to_screen(tank.position) + Vector2(0, 1), MOUSE_BUTTON_LEFT)
			assert(game.selection == [tank])
		elif i in range(79, 110):
			_motion(pointer.lerp(game.hud.minimap_screen_point(Vector2(11.5, 10.5) * 32.0), 0.13))
		elif i == 110:
			_click(game.hud.minimap_screen_point(Vector2(11.5, 10.5) * 32.0), MOUSE_BUTTON_RIGHT)
		elif i == 125:
			_click(game.ground_to_screen(squad.position) - Vector2(0, 5), MOUSE_BUTTON_LEFT)
			_click(game.ground_to_screen(commander.position) - Vector2(0, 5), MOUSE_BUTTON_LEFT, true)
			_click(game.ground_to_screen(Vector2(12.7, 11.7) * 32.0), MOUSE_BUTTON_RIGHT)
		elif i == 313:
			_key(KEY_E)
		painter.queue_redraw()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg("%s/%05d.jpg" % [CLIP, frame], 0.93)
		frame += 1
	var fought := false
	for unit in game.get_living_units():
		fought = fought or unit.health < unit.max_health
	print("Recorded %d frames, crystal combat=%s." % [frame, fought])
	assert(fought)


func _draw_pointer() -> void:
	var outline := PackedVector2Array([pointer, pointer + Vector2(4, 16), pointer + Vector2(8, 9),
		pointer + Vector2(14, 8), pointer])
	painter.draw_colored_polygon(outline, Color("#fff4d2"))
	painter.draw_polyline(outline, Color("#252419"), 1.2, true)


func _motion(at: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = mask
	event.relative = at - pointer
	pointer = at
	root.push_input(event, true)


func _button(at: Vector2, which: MouseButton, down: bool, shift := false) -> void:
	pointer = at
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = down
	event.shift_pressed = shift
	event.position = at
	event.global_position = at
	root.push_input(event, true)


func _click(at: Vector2, which: MouseButton, shift := false) -> void:
	_button(at, which, true, shift)
	_button(at, which, false, shift)


func _key(which: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = which
	event.pressed = true
	root.push_input(event, true)
