class_name RtsCarbonPiece
extends Node2D
## One reusable placed RTS battlefield module (cliff, oasis, Orichalcum rock, outpost pad,
## plaza, boulder group, dune cluster, or desert scrub).
## Swaps cleanly in-place between 2x Detailed Painted (*_hd.png) and 1x 960x540 Pixel (*_pixel.png),
## while sharing the exact same blocked footprint, cast shadow, lee shade, and dune relief.

const TEX_DIR := "res://assets/textures/rts/carbon/"

@export var piece_id := "rock_mesa"
@export var world_size := Vector2(196.0, 140.0)
## "obstacle", "dune", "ground_decal", or "prop"
@export var layer_role := "obstacle"
@export var flip_x := false
## Local-space collision polygon (relative to node position). Automatically blocks 32px grid cells.
@export var blocked_poly := PackedVector2Array()
## Top-left directional light casts shadows down-right.
@export var shadow_offset := Vector2(12.0, 9.0)
@export var shadow_size := Vector2.ZERO
@export_range(0.0, 1.0) var shadow_alpha := 0.34
## Darkens units walking through this landmark's lee shadow.
@export var shade_offset := Vector2(16.0, 12.0)
@export var shade_radii := Vector2.ZERO
@export_range(0.0, 0.65) var shade_strength := 0.0
## Gentle elevation for dune clusters (shortens uphill infantry stride & enables tread flattening).
@export var relief_height := 0.0
@export var relief_radii := Vector2(110.0, 80.0)
@export var is_orichalcum := false

var texture: Texture2D
var pixel_mode := false


func apply_visual_mode(use_pixel: bool, dune_shader: Shader = null, sand_tex: Texture2D = null,
		calm_tex: Texture2D = null, tread_tex: Texture2D = null, map_world_size := Vector2(1408, 896),
		show_treads := true) -> void:
	pixel_mode = use_pixel
	var suffix := "_pixel.png" if use_pixel else "_hd.png"
	texture = load(TEX_DIR + piece_id + suffix) as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if use_pixel else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	if layer_role == "dune" and dune_shader != null:
		var sm := material as ShaderMaterial
		if sm == null:
			sm = ShaderMaterial.new()
			sm.shader = dune_shader
			material = sm
		sm.set_shader_parameter("sand_tex", sand_tex)
		sm.set_shader_parameter("calm_mask_tex", calm_tex)
		sm.set_shader_parameter("tread_tex", tread_tex)
		sm.set_shader_parameter("world_size", map_world_size)
		sm.set_shader_parameter("piece_origin", global_position)
		sm.set_shader_parameter("piece_size", world_size)
		sm.set_shader_parameter("pixel_mode", use_pixel)
		sm.set_shader_parameter("show_treads", show_treads)
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var draw_size := world_size
	if flip_x:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false)
	if flip_x:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func blocks_world_point(world_pt: Vector2) -> bool:
	if blocked_poly.size() < 3:
		return false
	var local_pt := to_local(world_pt)
	if flip_x:
		local_pt.x = -local_pt.x
	return Geometry2D.is_point_in_polygon(local_pt, blocked_poly)


func height_at(world_pt: Vector2) -> float:
	if relief_height <= 0.0 or relief_radii.x <= 1.0 or relief_radii.y <= 1.0:
		return 0.0
	var local_pt := to_local(world_pt)
	var nx := local_pt.x / relief_radii.x
	var ny := local_pt.y / relief_radii.y
	var d2 := nx * nx + ny * ny
	if d2 >= 1.0:
		return 0.0
	var t := 1.0 - d2
	return relief_height * t * t


func shade_at(world_pt: Vector2) -> float:
	if shade_strength <= 0.0 or shade_radii.x <= 1.0 or shade_radii.y <= 1.0:
		return 0.0
	var local_pt := to_local(world_pt) - shade_offset
	var nx := local_pt.x / shade_radii.x
	var ny := local_pt.y / shade_radii.y
	var d := sqrt(nx * nx + ny * ny)
	if d >= 1.0:
		return 0.0
	return shade_strength * (1.0 - smoothstep(0.32, 1.0, d))
