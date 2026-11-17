extends Camera3D

@export var target_path: NodePath = NodePath("../BlueCommander")
@export var follow_offset: Vector3 = Vector3(0.0, 3.8, 12.6)
@export var fixed_pitch_deg: float = -13.0
@export var x_follow_factor: float = 0.35
@export var follow_smooth_speed: float = 6.5

var _target: Node3D = null


func _ready() -> void:
	fov = 30.0
	rotation_degrees = Vector3(fixed_pitch_deg, 0.0, 0.0)
	_target = get_node_or_null(target_path) as Node3D
	if _target:
		global_position = _desired_position()


func _desired_position() -> Vector3:
	return Vector3(
		_target.global_position.x * x_follow_factor,
		follow_offset.y,
		_target.global_position.z + follow_offset.z
	)


func _process(delta: float) -> void:
	if _target == null:
		return
	global_position = global_position.lerp(_desired_position(), clampf(delta * follow_smooth_speed, 0.0, 1.0))
	rotation_degrees = Vector3(fixed_pitch_deg, 0.0, 0.0)
