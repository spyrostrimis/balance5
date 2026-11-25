class_name ForestClaimProjection
extends RefCounted
## Equal ground axes at ±30° in screen space. Vertical height stays upright.
const CELL := 32.0
const GROUND := Transform2D(Vector2(0.70710678, 0.40824829), Vector2(-0.70710678, 0.40824829), Vector2.ZERO)
const HEIGHT_SCALE := 0.81649658


static func point(world: Vector2, height := 0.0) -> Vector2:
	return GROUND * world - Vector2(0.0, height * HEIGHT_SCALE)


static func world(iso: Vector2) -> Vector2:
	return GROUND.affine_inverse() * iso
