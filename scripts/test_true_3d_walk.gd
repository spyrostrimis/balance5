extends SceneTree

var _stage: int = 0
var _frames: int = 0
var _scene: Node = null
var _commander: CharacterBody3D = null
var _cam: Camera3D = null
var _exit_fired: bool = false
var _dir_created: bool = false


func _send_key(keycode: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _capture(filename: String) -> void:
	if not _dir_created:
		DirAccess.make_dir_recursive_absolute("d:/Games/Balance5/render_captures")
		_dir_created = true
	var img: Image = get_root().get_texture().get_image()
	if img == null:
		push_error("Viewport image is null for " + filename)
		return
	var out_path := "d:/Games/Balance5/render_captures/" + filename
	img.save_png(out_path)
	print("Captured %s | Hero=%s | Cam=%s | ExitSignal=%s" % [
		filename,
		str(_commander.global_position),
		str(_cam.global_position),
		str(_exit_fired)
	])


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1376, 768))
	get_root().size = Vector2i(1376, 768)
	var packed := load("res://scenes/maps/desert_canyon_true_3d.tscn") as PackedScene
	_scene = packed.instantiate()
	get_root().add_child(_scene)
	_commander = _scene.get_node("BlueCommander") as CharacterBody3D
	_cam = _scene.get_node("CameraRig") as Camera3D
	_commander.reached_canyon_exit.connect(func(is_at_exit: bool) -> void:
		if is_at_exit:
			_exit_fired = true
	)


func _process(_delta: float) -> bool:
	_frames += 1
	match _stage:
		0:
			# Warmup frames for textures, particles, and DOF screen texture
			if _frames >= 25:
				_capture("test_organic_3d_pos1_start.png")
				_send_key(KEY_W, true)
				_frames = 0
				_stage = 1
		1:
			# Walk forward to canyon midpoint (~Z = -3.5)
			if _commander.global_position.z <= -3.5 or _frames >= 2400:
				_send_key(KEY_W, false)
				_frames = 0
				_stage = 2
		2:
			# Let camera finish catching up cleanly before midway snapshot
			if _frames >= 45:
				_capture("test_organic_3d_pos2_midway.png")
				_send_key(KEY_W, true)
				_frames = 0
				_stage = 3
		3:
			# Walk forward to canyon exit (~Z = -14.0)
			if _commander.global_position.z <= -13.95 or _frames >= 3000:
				_send_key(KEY_W, false)
				_frames = 0
				_stage = 4
		4:
			# Settle camera and capture canyon exit vista
			if _frames >= 40:
				_capture("test_organic_3d_pos3_exit.png")
				_send_key(KEY_A, true)
				_frames = 0
				_stage = 5
		5:
			# Verify left movement & horizontal path clamp
			if _frames >= 18:
				_send_key(KEY_A, false)
				print("Post-strafe check: Hero=%s flip_h=%s on_floor=%s" % [
					str(_commander.global_position),
					str(_commander.get_node("CommanderSprite").flip_h),
					str(_commander.is_on_floor())
				])
				_scene.queue_free()
				return true
	return false
