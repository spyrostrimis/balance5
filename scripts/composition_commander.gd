extends "res://scripts/blue_commander_3d_player.gd"
## Composition-test commander. Clamps to the scene's route instead of the D4b curve.

var route: Resource


func _route_center_x(z: float) -> float:
	if route == null:
		return super(z)
	return route.center_x(z)
