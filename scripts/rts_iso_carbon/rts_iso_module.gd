class_name RtsIsoModule
extends Node2D
## One placed reusable scenery/terrain module in the isometric battlefield.
## Owns its ground contact anchor (for exact u+v Y-sorting), blocked logical footprint,
## dynamic shadow/shade parameters, and split Trunk + Canopy rendering for tall trees.

var piece_id := ""
var anchor_cell := Vector2i.ZERO
var map_pos := Vector2.ZERO
var flip_x := false
var tint := Color.WHITE
var tag := ""

var role := "obstacle"
var draw_size := Vector2.ZERO
var anchor_px := Vector2.ZERO
var has_canopy := false
var is_orichalcum := false
var tall_occluder := false
var shade_radius := Vector2.ZERO
var shade_offset := Vector2.ZERO
var shade_strength := 0.0

var tex_main: Texture2D
var tex_trunk: Texture2D
var tex_crown: Texture2D

var crown_alpha := 1.0
var show_seam_debug := false
var _blocked_cells: Array[Vector2i] = []


func configure(placement: Dictionary) -> void:
	piece_id = String(placement.get("id", "boulder_moss_pair"))
	anchor_cell = placement.get("cell", Vector2i.ZERO) as Vector2i
	var cell_offset: Vector2 = placement.get("offset", Vector2.ZERO)
	map_pos = RtsIsoTransform.center_of(anchor_cell) + cell_offset
	flip_x = bool(placement.get("flip_x", false))
	tint = placement.get("tint", Color.WHITE) as Color
	tag = String(placement.get("tag", ""))

	var meta := RtsIsoKit.piece_meta(piece_id)
	var sz: Array = meta.get("size", [96, 96])
	var anc: Array = meta.get("anchor_px", [48.0, 64.0])
	draw_size = Vector2(float(sz[0]), float(sz[1]))
	anchor_px = Vector2(float(anc[0]), float(anc[1]))
	role = String(meta.get("role", "obstacle"))
	has_canopy = bool(meta.get("has_canopy", false))
	is_orichalcum = bool(meta.get("is_orichalcum", false))
	tall_occluder = bool(meta.get("tall_occluder", false))

	var sr: Array = meta.get("shade_radius", [0.0, 0.0])
	var so: Array = meta.get("shade_offset", [16.0, 12.0])
	shade_radius = Vector2(float(sr[0]), float(sr[1]))
	shade_offset = Vector2(float(so[0]), float(so[1]))
	shade_strength = float(meta.get("shade_strength", 0.0))

	tex_main = RtsIsoKit.texture(piece_id)
	if has_canopy:
		tex_trunk = RtsIsoKit.texture(piece_id + "_trunk")
		tex_crown = RtsIsoKit.texture(piece_id + "_crown")

	_blocked_cells = RtsIsoKit.blocked_cells_for(piece_id, anchor_cell, flip_x)
	position = RtsIsoTransform.map_to_iso(map_pos)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()


func blocked_cells() -> Array[Vector2i]:
	return _blocked_cells


func draw_top_left() -> Vector2:
	var ax := (draw_size.x - anchor_px.x) if flip_x else anchor_px.x
	return -Vector2(ax, anchor_px.y)


## Bounding rect of overhanging foliage canopy in isometric canvas space (above root contact).
func canopy_iso_rect() -> Rect2:
	if not has_canopy:
		return Rect2()
	var tl := position + draw_top_left()
	return Rect2(tl + Vector2(draw_size.x * 0.04, draw_size.y * 0.03), Vector2(draw_size.x * 0.92, draw_size.y * 0.84))


## Bounding rect of upper vertical stone/trunk silhouette that can occlude units standing behind it.
func occluder_iso_rect() -> Rect2:
	if not tall_occluder:
		return Rect2()
	var tl := position + draw_top_left()
	return Rect2(tl + Vector2(draw_size.x * 0.22, draw_size.y * 0.20), Vector2(draw_size.x * 0.56, draw_size.y * 0.62))


func shade_at_iso(iso_pt: Vector2) -> float:
	if shade_strength <= 0.0 or shade_radius.x <= 1.0 or shade_radius.y <= 1.0:
		return 0.0
	var rel := iso_pt - (position + shade_offset)
	var nx := rel.x / shade_radius.x
	var ny := rel.y / shade_radius.y
	var d := sqrt(nx * nx + ny * ny)
	if d >= 1.0:
		return 0.0
	return shade_strength * (1.0 - smoothstep(0.28, 1.0, d))


func update_canopy_fade(target_alpha: float, delta: float) -> void:
	if not has_canopy:
		return
	var next_a := lerpf(crown_alpha, target_alpha, 1.0 - exp(-10.0 * delta))
	if absf(next_a - crown_alpha) > 0.004:
		crown_alpha = next_a
		queue_redraw()


func _draw() -> void:
	var tl := draw_top_left()
	if flip_x:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
		tl = -Vector2(anchor_px.x, anchor_px.y)

	if has_canopy and tex_trunk != null and tex_crown != null:
		draw_texture_rect(tex_trunk, Rect2(tl, draw_size), false, tint)
		var crown_col := Color(tint.r, tint.g, tint.b, tint.a * crown_alpha)
		draw_texture_rect(tex_crown, Rect2(tl, draw_size), false, crown_col)
	elif tex_main != null:
		draw_texture_rect(tex_main, Rect2(tl, draw_size), false, tint)

	if flip_x:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if show_seam_debug:
		var box := Rect2(draw_top_left(), draw_size)
		draw_rect(box, Color(1.0, 0.88, 0.28, 0.45), false, 1.2)
		draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.92, 0.25, 0.95))
