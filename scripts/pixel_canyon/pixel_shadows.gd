extends Node2D
## Ground effects sit under the Y-sorted picture layers.

static var _cast_shape := PackedVector2Array([
	Vector2(-63, 3), Vector2(-56, -1), Vector2(-42, -3), Vector2(-28, -5),
	Vector2(-13, -6), Vector2(7, -6), Vector2(19, -3), Vector2(24, 1),
	Vector2(22, 5), Vector2(12, 7), Vector2(-5, 7), Vector2(-23, 8),
	Vector2(-41, 7), Vector2(-55, 5),
])
static var _contact_shape := PackedVector2Array([
	Vector2(-21, -3), Vector2(-13, -6), Vector2(12, -5), Vector2(19, -2),
	Vector2(20, 2), Vector2(15, 4), Vector2(-13, 4), Vector2(-22, 1),
])

var commander: CharacterBody2D
var sentry: Sprite2D


func _draw() -> void:
	if is_instance_valid(commander) and commander.is_visible_in_tree():
		_shadow(commander.position.round(), commander.perspective)
	if is_instance_valid(sentry) and sentry.is_visible_in_tree():
		_shadow(sentry.position, sentry.scale.x)


func _shadow(ground: Vector2, size: float) -> void:
	draw_set_transform(ground, 0.0, Vector2.ONE * size)
	draw_colored_polygon(_cast_shape, Color(0.18, 0.12, 0.23, 0.37))
	draw_colored_polygon(_contact_shape, Color(0.10, 0.07, 0.14, 0.48))
