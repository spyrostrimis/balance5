extends "res://scripts/canyon/canyon_camera.gd"

const PARALLEL_PITCH := -42.0
const PARALLEL_DISTANCE := 17.0
# The unchanged commander fills 105 of 540 art pixels in the reference framing.
const PARALLEL_VIEW_HEIGHT := 5.05
const PARALLEL_FOLLOW_SPEED := 10.0

@export var parallel_view := false


func _ready() -> void:
	super()
	set_parallel_view(parallel_view)


func set_parallel_view(enabled: bool) -> void:
	parallel_view = enabled
	projection = Camera3D.PROJECTION_ORTHOGONAL if enabled else Camera3D.PROJECTION_PERSPECTIVE
	size = PARALLEL_VIEW_HEIGHT
	snap()


func snap() -> void:
	if not parallel_view:
		super()
		return
	if _target:
		rotation_degrees = Vector3(PARALLEL_PITCH, 0.0, 0.0)
		global_position = _parallel_position()


func _process(delta: float) -> void:
	if not parallel_view:
		super(delta)
		return
	if _target:
		var weight := 1.0 - exp(-PARALLEL_FOLLOW_SPEED * delta)
		global_position = global_position.lerp(_parallel_position(), weight)


func _parallel_position() -> Vector3:
	return _target.global_position + global_basis.z * PARALLEL_DISTANCE


## The original camera follows the bend at its own depth so it clears the inside wall.
func _desired_position() -> Vector3:
	if route == null:
		return super()
	var p := _target.global_position
	var chase_z := p.z + follow_offset.z
	var lateral: float = (p.x - route.center_x(p.z)) * x_follow_factor
	return Vector3(route.center_x(chase_z) + lateral - 0.16, follow_offset.y, chase_z)
