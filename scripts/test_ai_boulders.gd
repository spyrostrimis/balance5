extends SceneTree

const TEST_SCENE := "res://scenes/maps/desert_canyon_ai_boulder_test.tscn"
const ROCK_SHADER_MAT := "res://assets/models/right_buttress_rock.tres"
const CAPTURE_DIR := "res://render_captures/ai_boulder_test"
const CAPTURE_SIZE := Vector2i(1376, 768)

enum Stage {
	SPAWN_NATIVE,
	SPAWN_SHADER,
	WALK_MIDWAY,
	MIDWAY_NATIVE,
	WALK_EXIT,
	EXIT_NATIVE,
	CLOSEUP_SIDE_BY_SIDE,
}

var _stage := Stage.SPAWN_NATIVE
var _frames := 0
var _scene: Node = null
var _commander: CharacterBody3D = null
var _cam: Camera3D = null
var _boulder_hf: Node3D = null
var _boulder_t3d: Node3D = null
var _mesh_hf: MeshInstance3D = null
var _mesh_t3d: MeshInstance3D = null
var _rock_mat: Material = null
var _exit_fired := false
var _abs_capture_dir := ""


func _find_first_mesh(root_node: Node) -> MeshInstance3D:
	if root_node is MeshInstance3D:
		return root_node as MeshInstance3D
	for child in root_node.get_children():
		var found := _find_first_mesh(child)
		if found != null:
			return found
	return null


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
	print("Captured %s | Hero=%s | Cam=%s | on_floor=%s | exit_fired=%s" % [
		filename, _commander.global_position, _cam.global_position, _commander.is_on_floor(), _exit_fired
	])
	return true


func _on_exit(is_at_exit: bool) -> void:
	if is_at_exit:
		_exit_fired = true


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
	_commander.reached_canyon_exit.connect(_on_exit)

	_boulder_hf = _scene.get_node("AIBoulder_HF_Trellis2") as Node3D
	_boulder_t3d = _scene.get_node("AIBoulder_Trellis3DNet") as Node3D
	_mesh_hf = _find_first_mesh(_boulder_hf)
	_mesh_t3d = _find_first_mesh(_boulder_t3d)
	_rock_mat = load(ROCK_SHADER_MAT) as Material
	if _mesh_hf == null or _mesh_t3d == null or _rock_mat == null:
		push_error("Missing boulder meshes or rock material override")
		quit(1)
		return


func _process(_delta: float) -> bool:
	_frames += 1
	match _stage:
		Stage.SPAWN_NATIVE:
			if _frames == 1:
				_apply_camera(Vector3(0.0, 3.8, 12.6), -13.0)
			if _frames >= 16:
				if not _capture("1_ai_native_pos1_start.png"):
					return true
				_mesh_hf.material_override = _rock_mat
				_mesh_t3d.material_override = _rock_mat
				_frames = 0
				_stage = Stage.SPAWN_SHADER
		Stage.SPAWN_SHADER:
			if _frames >= 6:
				if not _capture("2_balance5_shader_pos1_start.png"):
					return true
				_mesh_hf.material_override = null
				_mesh_t3d.material_override = null
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
				_stage = Stage.MIDWAY_NATIVE
		Stage.MIDWAY_NATIVE:
			if _frames >= 30:
				if not _capture("3_ai_native_pos2_midway.png"):
					return true
				_move_forward(true)
				_frames = 0
				_stage = Stage.WALK_EXIT
		Stage.WALK_EXIT:
			if _commander.global_position.z <= -14.0 or _frames >= 2400:
				_move_forward(false)
				if _frames >= 2400:
					push_error("Walk timeout before Z=-14.0")
					quit(1)
					return true
				_apply_camera(Vector3(0.0, 3.8, 12.6), -13.0)
				_frames = 0
				_stage = Stage.EXIT_NATIVE
		Stage.EXIT_NATIVE:
			if _frames >= 30:
				if not _capture("4_ai_native_pos3_exit.png"):
					return true
				# Stage a close-up inspection of both boulders side-by-side in direct sun at Z=6.2
				_cam.set_process(false)
				_cam.set_physics_process(false)
				_cam.attributes = null
				_boulder_hf.position = Vector3(-0.75, 0.0, 6.2)
				_boulder_hf.scale = Vector3(0.9, 0.9, 0.9)
				_boulder_t3d.position = Vector3(1.15, 0.0, 6.2)
				_boulder_t3d.scale = Vector3(0.95, 0.95, 0.95)
				_commander.visible = false
				_cam.global_position = Vector3(0.2, 2.25, 11.4)
				_cam.rotation_degrees = Vector3(-16.0, 0.0, 0.0)
				_frames = 0
				_stage = Stage.CLOSEUP_SIDE_BY_SIDE
		Stage.CLOSEUP_SIDE_BY_SIDE:
			if _frames >= 8:
				_capture("5_closeup_native_ai_comparison.png")
				_scene.queue_free()
				return true
	return false
