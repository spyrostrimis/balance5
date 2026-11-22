extends "res://scripts/canyon/canyon_camera.gd"

## The camera follows the bend at its own depth so it clears the inside wall.
func _desired_position() -> Vector3:
	if route == null:
		return super()
	var p := _target.global_position
	var chase_z := p.z + follow_offset.z
	var lateral: float = (p.x - route.center_x(p.z)) * x_follow_factor
	return Vector3(route.center_x(chase_z) + lateral - 0.16, follow_offset.y, chase_z)
