extends SceneTree

const TEST_SCENE := "res://scenes/maps/desert_canyon_chatgpt_road_test.tscn"
const CAPTURE_DIR := "res://render_captures/chatgpt_road_test"
const CAPTURE_SIZE := Vector2i(1376, 768)

enum Stage {
	SPAWN_SPLIT,
	SPAWN_FULL,
	SPAWN_CAM_A,
	WALK_MIDWAY,
	MIDWAY_FULL,
	MIDWAY_CAM_A,
}

var _stage := Stage.SPAWN_SPLIT
var _frames := 0
var _scene: Node = null
var _commander: CharacterBody3D = null
var _cam: Camera3D = null
var _ground_mat: ShaderMaterial = null
var _abs_capture_dir := ""


func _move_forward(pressed: bool) -> void:
	if pressed:
		Input.action_press(&"ui_up")
	else:
		Input.action_release(&"ui_up")


func _apply_camera(offset: Vector3, pitch_deg: float) -> void:
	_cam.follow_offset = offset
	_cam.fixed_pitch_deg = pitch_deg
	_cam.global_position = Vector3(
		_commander.global_position.x * _cam.x_follow_factor,
		offset.y,
		_commander.global_position.z + offset.z
	)
	_cam.rotation_degrees = Vector3(pitch_deg, 0.0, 0.0)


func _capture(filename: String) -> bool:
	var out_path := _abs_capture_dir.path_join(filename)
	var img := root.get_texture().get_image()
	if img == null or img.get_size() != CAPTURE_SIZE:
		push_error("Invalid image size for %s: %s" % [out_path, img.get_size() if img else Vector2i.ZERO])
		quit(1)
		return false
	if img.save_png(out_path) != OK:
		push_error("Failed saving capture " + out_path)
		quit(1)
		return false
	print("Captured %s | Hero=%s | Cam=%s | Pitch=%.1f | on_floor=%s" % [
		filename, _commander.global_position, _cam.global_position, _cam.fixed_pitch_deg, _commander.is_on_floor()
	])
	return true


func _initialize() -> void:
	_abs_capture_dir = ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(_abs_capture_dir)
	DisplayServer.window_set_size(CAPTURE_SIZE)
	root.size = CAPTURE_SIZE
	root.content_scale_size = CAPTURE_SIZE
	root.anisotropic_filtering_level = Viewport.ANISOTROPY_16X

	var packed := load(TEST_SCENE) as PackedScene
	if packed == null:
		push_error("Cannot load " + TEST_SCENE)
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)

	_commander = _scene.get_node("BlueCommander") as CharacterBody3D
	_cam = _scene.get_node("CameraRig") as Camera3D
	var ground_mesh := _scene.get_node("GroundFloorMesh") as MeshInstance3D
	_ground_mat = ground_mesh.get_surface_override_material(0) as ShaderMaterial
	if _ground_mat == null:
		push_error("GroundFloorMesh missing ShaderMaterial")
		quit(1)
		return
	_ground_mat.set_shader_parameter("compare_mode", 1)


func _process(_delta: float) -> bool:
	_frames += 1
	match _stage:
		Stage.SPAWN_SPLIT:
			if _frames == 1:
				_apply_camera(Vector3(0.0, 3.8, 12.6), -13.0)
			if _frames >= 16:
				if not _capture("1_chatgpt_split_patch_pos1_start.png"):
					return true
				_ground_mat.set_shader_parameter("compare_mode", 0)
				_frames = 0
				_stage = Stage.SPAWN_FULL
		Stage.SPAWN_FULL:
			if _frames >= 6:
				if not _capture("2_chatgpt_full_pos1_start.png"):
					return true
				_apply_camera(Vector3(0.0, 4.85, 12.2), -17.5)
				_frames = 0
				_stage = Stage.SPAWN_CAM_A
		Stage.SPAWN_CAM_A:
			if _frames >= 6:
				if not _capture("3_chatgpt_cam17_5_pos1_start.png"):
					return true
				_apply_camera(Vector3(0.0, 3.8, 12.6), -13.0)
				_move_forward(true)
				_frames = 0
				_stage = Stage.WALK_MIDWAY
		Stage.WALK_MIDWAY:
			if _commander.global_position.z <= -3.52 or _frames >= 2400:
				_move_forward(false)
				if _frames >= 2400:
					push_error("Walk timeout before Z=-3.52")
					quit(1)
					return true
				_apply_camera(Vector3(0.0, 3.8, 12.6), -13.0)
				_frames = 0
				_stage = Stage.MIDWAY_FULL
		Stage.MIDWAY_FULL:
			if _frames >= 45:
				if not _capture("2_chatgpt_full_pos2_midway.png"):
					return true
				_apply_camera(Vector3(0.0, 4.85, 12.2), -17.5)
				_frames = 0
				_stage = Stage.MIDWAY_CAM_A
		Stage.MIDWAY_CAM_A:
			if _frames >= 6:
				_capture("3_chatgpt_cam17_5_pos2_midway.png")
				_scene.queue_free()
				return true
	return false
