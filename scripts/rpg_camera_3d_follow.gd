extends Camera3D

@export var target_path: NodePath = NodePath("../BlueCommander")
@export var post_processing_path: NodePath = NodePath("../PostProcessing/TiltShiftDof")
@export var follow_smooth_speed: float = 6.0

const REF_POS: Vector3 = Vector3(0.0, 2.4, 10.0)
const REF_PITCH_DEG: float = -11.5
const REF_FOV: float = 40.0

var target: Node3D
var tilt_material: ShaderMaterial

func _ready():
	fov = REF_FOV
	position = REF_POS
	rotation_degrees = Vector3(REF_PITCH_DEG, 0.0, 0.0)

	if has_node(target_path):
		target = get_node(target_path) as Node3D
	if has_node(post_processing_path):
		var post_rect = get_node(post_processing_path) as ColorRect
		if post_rect and post_rect.material is ShaderMaterial:
			tilt_material = post_rect.material as ShaderMaterial

func _process(delta: float):
	if not target:
		return

	var walk_t = clamp((2.0 - target.global_position.z) / 11.5, 0.0, 1.0)

	var desired_pos: Vector3
	var desired_rot: Vector3
	var desired_fov: float
	if walk_t <= 0.0001:
		desired_pos = REF_POS
		desired_rot = Vector3(REF_PITCH_DEG, 0.0, 0.0)
		desired_fov = REF_FOV
	else:
		desired_pos = Vector3(
			lerp(0.0, target.global_position.x * 0.40, walk_t),
			lerp(2.4, 1.65, walk_t),
			lerp(10.0, 2.2, walk_t)
		)
		desired_rot = Vector3(lerp(REF_PITCH_DEG, -6.5, walk_t), 0.0, 0.0)
		desired_fov = lerp(REF_FOV, 28.0, walk_t)

	global_position = global_position.lerp(desired_pos, clamp(follow_smooth_speed * delta, 0.0, 1.0))
	rotation_degrees = rotation_degrees.lerp(desired_rot, clamp(follow_smooth_speed * delta, 0.0, 1.0))
	fov = lerp(fov, desired_fov, clamp(follow_smooth_speed * delta, 0.0, 1.0))

	if tilt_material:
		tilt_material.set_shader_parameter("blur_amount", lerp(2.6, 0.35, walk_t))
		var focal_y = lerp(0.58, 0.48, walk_t)
		tilt_material.set_shader_parameter("focal_position_y", focal_y)
