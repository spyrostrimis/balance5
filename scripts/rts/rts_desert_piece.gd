class_name RtsDesertPiece
extends Node2D
## One placed module. Art swaps in place. Footprints, relief and shade are in world units.

@export var art: String
## Both views can draw the same cutout so its silhouette follows the shared footprint.
@export var shared_texture: Texture2D
@export var size := Vector2(96, 64)
@export var footprint := PackedVector2Array()
@export var shade_offset := Vector2(12, 9)
@export var shade_size := Vector2.ZERO
@export_range(0.0, 1.0) var shade_strength := 0.0
## Optional cliff-foot layers share the placement and dimensions of the shade.
@export var shade_texture: Texture2D
@export var footing_texture: Texture2D
@export var relief_height := 0.0
@export var relief_radius := Vector2(52.0, 45.0)

var texture: Texture2D
var _shade_pixels: Image


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


func prepare_shade() -> void:
	if shade_texture != null:
		_shade_pixels = shade_texture.get_image()


func shade_rect() -> Rect2:
	return Rect2(shade_offset - shade_size * 0.5, shade_size)


func shade_at(world: Vector2) -> float:
	if shade_strength <= 0.0:
		return 0.0
	var point := to_local(world)
	if _shade_pixels != null:
		var rect := shade_rect()
		if not rect.has_point(point):
			return 0.0
		var texel := Vector2i((point - rect.position) / rect.size * Vector2(_shade_pixels.get_size()))
		return shade_strength * _shade_pixels.get_pixelv(texel).a
	var d := 2.0 * (point - shade_offset) / shade_size
	return shade_strength * (1.0 - smoothstep(0.22, 1.0, d.length()))
