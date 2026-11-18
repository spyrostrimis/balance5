extends "res://scripts/rpg_camera_3d_follow.gd"
## Composition-test camera. Tracks the route centre and turns slightly toward the road ahead.
## With use_original the inherited D4b rig runs unchanged: 30° FOV, −13° pitch, offset (0, 3.8, 12.6).

const ORIGINAL_PITCH := -13.0
const ORIGINAL_OFFSET := Vector3(0.0, 3.8, 12.6)

@export var use_original := false
@export var composition_pitch_deg := -21.0
@export var composition_offset := Vector3(0.0, 5.5, 11.9)
## Share of the route centre the camera follows in X. The rest follows the commander via x_follow_factor.
@export var route_follow := 0.6
## Share of the full look-at yaw toward the road ahead.
@export var yaw_follow := 0.45
@export var look_ahead := 9.0

var route: Resource
var _yaw := 0.0


func set_original(enabled: bool) -> void:
	use_original = enabled
	snap()


func snap() -> void:
	if _target == null:
		return
	_apply_mode()
	global_position = _desired_position()
	_yaw = _desired_yaw()
	rotation = Vector3(deg_to_rad(fixed_pitch_deg), _yaw, 0.0)


func _apply_mode() -> void:
	fixed_pitch_deg = ORIGINAL_PITCH if use_original else composition_pitch_deg
	follow_offset = ORIGINAL_OFFSET if use_original else composition_offset


func _desired_position() -> Vector3:
	if use_original or route == null:
		return super()
	var p := _target.global_position
	var cx: float = route.center_x(p.z)
	return Vector3(
		cx * route_follow + (p.x - cx) * x_follow_factor,
		follow_offset.y,
		p.z + follow_offset.z
	)


func _desired_yaw() -> float:
	if use_original or route == null:
		return 0.0
	var ahead_z := _target.global_position.z - look_ahead
	var ahead_x: float = route.center_x(ahead_z)
	return atan2(-(ahead_x - global_position.x), global_position.z - ahead_z) * yaw_follow


func _process(delta: float) -> void:
	if _target == null:
		return
	_apply_mode()
	var t := clampf(delta * follow_smooth_speed, 0.0, 1.0)
	global_position = global_position.lerp(_desired_position(), t)
	_yaw = lerp_angle(_yaw, _desired_yaw(), t)
	rotation = Vector3(deg_to_rad(fixed_pitch_deg), _yaw, 0.0)
