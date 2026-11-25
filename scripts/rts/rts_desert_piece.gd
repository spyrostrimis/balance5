class_name RtsDesertPiece
extends Node2D
## One placed module. Art swaps in place. Footprints, relief and shade are in world units.

@export var art: String
@export var size := Vector2(96, 64)
@export var footprint := PackedVector2Array()
@export var shade_offset := Vector2(12, 9)
@export var shade_size := Vector2.ZERO
@export_range(0.0, 1.0) var shade_strength := 0.0
@export var relief_height := 0.0
@export var relief_radius := Vector2(52.0, 45.0)

var texture: Texture2D


func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, Rect2(-size * 0.5, size), false)


func covers(world: Vector2) -> bool:
	return footprint.size() >= 3 and Geometry2D.is_point_in_polygon(to_local(world), footprint)


func height_at(world: Vector2) -> float:
	if relief_height <= 0.0:
		return 0.0
	var d := to_local(world) / relief_radius
	var hill := clampf(1.0 - d.length_squared(), 0.0, 1.0)
	return relief_height * hill * hill


func shade_at(world: Vector2) -> float:
	if shade_strength <= 0.0:
		return 0.0
	var d := 2.0 * (to_local(world) - shade_offset) / shade_size
	return shade_strength * (1.0 - smoothstep(0.22, 1.0, d.length()))
