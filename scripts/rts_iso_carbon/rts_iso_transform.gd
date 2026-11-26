class_name RtsIsoTransform
extends RefCounted
## Single mathematical source of truth converting between isotropic logical RTS map
## coordinates (36x36 cells, 32 units/cell) and Fight 4's true-isometric 35.264° canvas
## projection (±30° ground axes, √3 : 1 diamond aspect), screen pixels, and the minimap.

const CELL_SIZE := 32.0
const GRID_W := 36
const GRID_H := 36
const MAP_SIZE := Vector2(float(GRID_W) * CELL_SIZE, float(GRID_H) * CELL_SIZE) # 1152 x 1152

## Exact true-isometric forward & inverse transforms from scripts/forest_fight_4/forest_fight_4.gd
const ISO := Transform2D(
	Vector2(0.70710678, 0.40824829),
	Vector2(-0.70710678, 0.40824829),
	Vector2.ZERO
)
const GROUND := Transform2D(
	Vector2(0.70710678, -0.70710678),
	Vector2(1.22474487, 1.22474487),
	Vector2.ZERO
)

## Tight isometric bounding box enclosing the entire 36x36 logical diamond:
## West=(-814.6, 470.3), East=(+814.6, 470.3), North=(0, 0), South=(0, 940.6)
const MINIMAP_ISO_RECT := Rect2(-824.0, -12.0, 1648.0, 964.0)


static func map_to_iso(map_pt: Vector2) -> Vector2:
	return ISO * map_pt


static func iso_to_map(iso_pt: Vector2) -> Vector2:
	return GROUND * iso_pt


static func cell_of(map_pt: Vector2) -> Vector2i:
	return Vector2i((map_pt / CELL_SIZE).floor())


static func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_W and cell.y < GRID_H


static func clamp_map_point(map_pt: Vector2, margin := 16.0) -> Vector2:
	return Vector2(
		clampf(map_pt.x, margin, MAP_SIZE.x - margin),
		clampf(map_pt.y, margin, MAP_SIZE.y - margin)
	)


static func screen_to_iso(canvas_xf: Transform2D, screen_pt: Vector2) -> Vector2:
	return canvas_xf.affine_inverse() * screen_pt


static func screen_to_map(canvas_xf: Transform2D, screen_pt: Vector2) -> Vector2:
	return iso_to_map(canvas_xf.affine_inverse() * screen_pt)


static func map_to_screen(canvas_xf: Transform2D, map_pt: Vector2) -> Vector2:
	return canvas_xf * map_to_iso(map_pt)


static func map_dir_to_col8(map_dir: Vector2) -> int:
	var iso_dir := map_to_iso(map_dir)
	if iso_dir.length_squared() < 1e-6:
		return 0
	return posmod(roundi(iso_dir.angle() / (PI / 4.0)), 8)


static func iso_angle_to_col8(iso_angle: float) -> int:
	return posmod(roundi(iso_angle / (PI / 4.0)), 8)


static func map_to_minimap_uv(map_pt: Vector2) -> Vector2:
	var iso_pt := map_to_iso(map_pt)
	return (iso_pt - MINIMAP_ISO_RECT.position) / MINIMAP_ISO_RECT.size


static func minimap_uv_to_map(uv: Vector2) -> Vector2:
	var iso_pt := MINIMAP_ISO_RECT.position + uv * MINIMAP_ISO_RECT.size
	return iso_to_map(iso_pt)


static func iso_to_minimap_uv(iso_pt: Vector2) -> Vector2:
	return (iso_pt - MINIMAP_ISO_RECT.position) / MINIMAP_ISO_RECT.size
