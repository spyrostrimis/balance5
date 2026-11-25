extends Camera2D

const Route := preload("res://assets/scenes/forest_test/forest_route.gd")
const LEEWAY := Vector2(45, 38)
const FOLLOW_RATE := 13.0


func follow(feet: Vector2, delta: float, reset := false) -> void:
	var focus := feet - Vector2(0, Route.camera_lead(feet.y))
	var half_view: Vector2 = Route.VIEW * 0.5
	if reset:
		position = focus.clamp(half_view, Route.CANVAS - half_view)
	else:
		var target := position.clamp(focus - LEEWAY, focus + LEEWAY)
		target = target.clamp(half_view, Route.CANVAS - half_view)
		position = position.lerp(target, 1.0 - exp(-FOLLOW_RATE * delta))
	force_update_scroll()
