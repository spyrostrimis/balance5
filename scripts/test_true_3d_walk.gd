extends SceneTree

const LAUNCH_SCENE := "res://scenes/maps/desert_canyon_true_3d.tscn"
const CAPTURE_SIZE := Vector2i(1376, 768)

enum Stage { SPAWN, NORMAL_ON, NORMAL_OFF, WALK_TO_MIDWAY, MIDWAY, WALK_TO_EXIT, EXIT, STRAFE, SHADOW_ON, SHADOW_OFF }

var _stage := Stage.SPAWN
var _frames: int = 0
var _scene: Node = null
var _commander: CharacterBody3D = null
var _cam: Camera3D = null
var _exit_fired: bool = false
var _capture_dir := "res://render_captures"
var _prefix := "test_organic_3d"
var _scene_path := LAUNCH_SCENE
var _shadow_pair := false
var _normal_pair := false
var _road_material: ShaderMaterial
var _road_normal: Texture2D
var _bend_probes := false
var _focus := "scene"
var _landmark := Vector3.INF
var _buttress: MeshInstance3D


func _send_key(keycode: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return true


func _capture(label: String) -> bool:
	if not _commander.is_on_floor():
		_fail("Commander is airborne at " + label)
		return false
	var path := _capture_dir.path_join(_prefix + "_" + label + ".png")
	var img := root.get_texture().get_image()
	if img == null or img.get_size() != CAPTURE_SIZE or img.save_png(path) != OK:
		var actual_size := img.get_size() if img else Vector2i.ZERO
		_fail("Failed to save a 1376x768 viewport capture at %s (image size=%s)" % [path, actual_size])
		return false
	print("Captured %s | Hero=%s | Cam=%s | on_floor=%s | ExitSignal=%s" % [
		path, _commander.global_position, _cam.global_position, _commander.is_on_floor(), _exit_fired
	])
	if _bend_probes:
		_log_bend_frame()
	if _landmark.is_finite():
		var hit := {}
		if _buttress:
			var triangles := _buttress.mesh.generate_triangle_mesh()
			hit = triangles.intersect_segment(_buttress.to_local(_cam.global_position), _buttress.to_local(_landmark))
		var hit_position: Variant = _buttress.to_global(hit["position"]) if not hit.is_empty() else "clear"
		print("Landmark=%s | Pixel=%s | InFrustum=%s | ButtressHit=%s" % [
			_landmark, _cam.unproject_position(_landmark), _cam.is_position_in_frustum(_landmark), hit_position
		])
	return true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var option := args[i]
		i += 1
		match option:
			"--shadow-pair":
				_shadow_pair = true
			"--normal-pair":
				_normal_pair = true
			"--bend-probes":
				_bend_probes = true
			"--scene", "--capture-dir", "--prefix", "--landmark", "--resolution", "--focus":
				if i >= args.size():
					_fail("Missing value for " + option)
					return
				var value := args[i]
				i += 1
				match option:
					"--scene": _scene_path = value
					"--capture-dir": _capture_dir = value
					"--prefix": _prefix = value
					"--focus":
						if value not in ["off", "screen", "scene"]:
							_fail("--focus requires off, screen or scene")
							return
						_focus = value
					"--landmark":
						var coordinates := value.split_floats(",")
						if coordinates.size() != 3:
							_fail("--landmark requires x,y,z")
							return
						_landmark = Vector3(coordinates[0], coordinates[1], coordinates[2])
					"--resolution":
						if value != "1376x768":
							_fail("The walk harness captures at 1376x768")
							return
			_:
				_fail("Unknown option " + option)
				return
	var has_output_paths := _capture_dir != "res://render_captures" or _prefix != "test_organic_3d"
	if _scene_path != LAUNCH_SCENE and not has_output_paths:
		_fail("Use --capture-dir or --prefix for an alternate scene")
		return
	_capture_dir = ProjectSettings.globalize_path(_capture_dir)
	if DirAccess.make_dir_recursive_absolute(_capture_dir) != OK:
		_fail("Cannot create " + _capture_dir)
		return
	if DisplayServer.get_name() == "headless":
		_fail("A windowed renderer is required for viewport captures")
		return
	DisplayServer.window_set_size(CAPTURE_SIZE)
	root.size = CAPTURE_SIZE
	root.content_scale_size = CAPTURE_SIZE
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		_fail("Cannot load scene " + _scene_path)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	_commander = _scene.get_node_or_null("BlueCommander") as CharacterBody3D
	_cam = _scene.get_node_or_null("CameraRig") as Camera3D
	if _commander == null or _cam == null:
		_fail("Scene is missing the D4b commander or camera")
		return
	if _bend_probes or _normal_pair:
		var ground := _scene.get_node_or_null("GroundFloorMesh") as MeshInstance3D
		if ground:
			_road_material = ground.get_surface_override_material(0) as ShaderMaterial
		if _road_material:
			_road_normal = _road_material.get_shader_parameter("cobble_norm") as Texture2D
		if _road_normal == null:
			_fail("Scene is missing the cobble normal map")
			return
	if _focus != "scene":
		var overlay := _scene.get_node_or_null("PostProcessing/TiltShiftDof") as ColorRect
		if overlay == null:
			_fail("Scene is missing the D4b screen-height filter")
			return
		_cam.attributes = null
		overlay.visible = _focus == "screen"
		if overlay.visible:
			# Compare the D4b blur with the fixed scene exposure and neutral grading.
			var filter := overlay.material.duplicate() as ShaderMaterial
			filter.set_shader_parameter("vignette_strength", 0.0)
			filter.set_shader_parameter("warm_tint", Color.WHITE)
			overlay.material = filter
	_commander.reached_canyon_exit.connect(func(is_at_exit: bool) -> void:
		if is_at_exit:
			_exit_fired = true
	)
	print("Scene=%s | Renderer=%s | FOV=%s | Pitch=%s | FollowOffset=%s" % [
		_scene.scene_file_path, RenderingServer.get_current_rendering_method(), _cam.fov,
		_cam.rotation_degrees.x, _cam.get("follow_offset")
	])
	_buttress = _scene.get_node_or_null("RightButtress/Rock/ButtressMesh") as MeshInstance3D
	if (_shadow_pair or _scene.has_node("RightButtress")) and _buttress == null:
		_fail("The right buttress mesh is missing")
		return
	if _shadow_pair and _buttress.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
		_fail("Enable buttress shadow casting before taking the pair")
		return


func _log_buttress() -> void:
	var blocker := _scene.get_node("RightButtress/Blocker/CollisionShape3D") as CollisionShape3D
	var vertices: PackedVector3Array = _buttress.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	print("Buttress=%s | Vertices=%s | VertexHash=%s | Material=%s | Blocker=%s | BoxSize=%s | Disabled=%s" % [
		_buttress.global_transform, vertices.size(), hash(vertices), _buttress.material_override.resource_path,
		blocker.global_position, (blocker.shape as BoxShape3D).size, blocker.disabled
	])


func _log_bend_setup() -> void:
	var albedo: Texture2D = _road_material.get_shader_parameter("cobble_tex")
	print("TileMetres=%s | Albedo=%s %s %s levels beyond base | Normal=%s %s %s levels beyond base" % [
		_road_material.get_shader_parameter("cobble_tile_metres"), albedo.resource_path,
		albedo.get_size(), albedo.get_image().get_mipmap_count(), _road_normal.resource_path,
		_road_normal.get_size(), _road_normal.get_image().get_mipmap_count()
	])
	print("Spawn scale | 1m pixels=%s..%s" % [
		_cam.unproject_position(Vector3(-0.5, 0.0, 7.7)), _cam.unproject_position(Vector3(0.5, 0.0, 7.7))
	])
	var attributes := _cam.attributes as CameraAttributesPractical
	var overlay := _scene.get_node("PostProcessing/TiltShiftDof") as ColorRect
	if attributes:
		print("Native DOF | Near=%s/%sm | Far=%s/%sm | Amount=%s | Exposure=%s | Auto=%s" % [
			attributes.dof_blur_near_distance, attributes.dof_blur_near_transition,
			attributes.dof_blur_far_distance, attributes.dof_blur_far_transition,
			attributes.dof_blur_amount, attributes.exposure_multiplier, attributes.auto_exposure_enabled
		])
	print("FocusMode=%s | ScreenFilter=%s | NativeAttributes=%s" % [_focus, overlay.visible, attributes != null])


func _log_bend_frame() -> void:
	var feet := _commander.global_position
	var torso := (_commander.get_node("CommanderSprite") as Node3D).global_position
	var world_to_camera := _cam.global_transform.affine_inverse()
	print("CameraDepth | Feet=%.3fm | SpriteCenter=%.3fm | 1mNearPaving=%.3fm | 1mFarPaving=%.3fm | Velocity=%s" % [
		-(world_to_camera * feet).z, -(world_to_camera * torso).z,
		-(world_to_camera * Vector3(feet.x, 0.0, feet.z + 1.0)).z,
		-(world_to_camera * Vector3(feet.x, 0.0, feet.z - 1.0)).z, _commander.velocity
	])


func _begin_walk() -> void:
	_send_key(KEY_W, true)
	_frames = 0
	_stage = Stage.WALK_TO_MIDWAY


func _process(_delta: float) -> bool:
	_frames += 1
	match _stage:
		Stage.SPAWN:
			if _frames >= 25 and _commander.is_on_floor():
				if _buttress:
					_log_buttress()
				if _bend_probes:
					_log_bend_setup()
				if not _capture("pos1_start"):
					return true
				if _normal_pair:
					_commander.set_physics_process(false)
					_cam.set_process(false)
					_frames = 0
					_stage = Stage.NORMAL_ON
				else:
					_begin_walk()
			elif _frames >= 2400:
				return _fail("Commander did not settle onto the floor at spawn")
		Stage.NORMAL_ON:
			if _frames >= 8:
				if not _capture("normal_on"):
					return true
				var flat := Image.create_empty(1, 1, false, Image.FORMAT_RGBF)
				flat.fill(Color(0.5, 0.5, 1.0))
				_road_material.set_shader_parameter("cobble_norm", ImageTexture.create_from_image(flat))
				_frames = 0
				_stage = Stage.NORMAL_OFF
		Stage.NORMAL_OFF:
			if _frames >= 8:
				if not _capture("normal_off"):
					return true
				_road_material.set_shader_parameter("cobble_norm", _road_normal)
				_commander.set_physics_process(true)
				_cam.set_process(true)
				_begin_walk()
		Stage.WALK_TO_MIDWAY:
			if _bend_probes and _frames in [65, 69]:
				var label := "motion" if _frames == 65 else "motion_followup"
				if not _capture(label):
					return true
			# Walk forward to canyon midpoint (~Z = -3.5)
			if _commander.global_position.z <= -3.5:
				_send_key(KEY_W, false)
				_frames = 0
				_stage = Stage.MIDWAY
			elif _frames >= 2400:
				return _fail("Timed out before the midpoint")
		Stage.MIDWAY:
			# Let camera finish catching up cleanly before midway snapshot
			if _frames >= 45:
				if not _capture("pos2_midway"):
					return true
				_send_key(KEY_W, true)
				_frames = 0
				_stage = Stage.WALK_TO_EXIT
		Stage.WALK_TO_EXIT:
			# Walk forward to canyon exit (~Z = -14.0)
			if _commander.global_position.z <= -13.95:
				_send_key(KEY_W, false)
				_frames = 0
				_stage = Stage.EXIT
			elif _frames >= 3000:
				return _fail("Timed out before the exit")
		Stage.EXIT:
			# Settle camera and capture canyon exit vista
			if _frames >= 40:
				if not _exit_fired:
					return _fail("The commander did not emit the exit signal")
				if not _capture("pos3_exit"):
					return true
				if _shadow_pair:
					_commander.set_physics_process(false)
					_cam.set_process(false)
					_frames = 0
					_stage = Stage.SHADOW_ON
					return false
				_send_key(KEY_A, true)
				_frames = 0
				_stage = Stage.STRAFE
		Stage.STRAFE:
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
		Stage.SHADOW_ON:
			if _frames >= 8:
				if not _capture("shadow_on"):
					return true
				_buttress.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_frames = 0
				_stage = Stage.SHADOW_OFF
		Stage.SHADOW_OFF:
			if _frames >= 8:
				_capture("shadow_off")
				return true
	return false
