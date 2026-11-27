@tool
class_name RtsCarbonPiece
extends Node2D
## One reusable placed RTS battlefield module (cliff, oasis, Orichalcum rock, outpost pad,
## plaza, boulder group, dune cluster, or desert scrub).
## Swaps cleanly in-place between 2x Detailed Painted (*_hd.png) and 1x 960x540 Pixel (*_pixel.png),
## while sharing the exact same blocked footprint, cast shadow, lee shade, and dune relief.

@export var piece_id := "rock_mesa"
@export var world_size := Vector2(196.0, 140.0):
	set(value):
		world_size = value
		queue_redraw()
## "obstacle", "water", "dune", "ground_decal", or "prop"
@export var layer_role := "obstacle"
@export var flip_x := false:
	set(value):
		flip_x = value
		queue_redraw()
## Lift the painting above its ground pivot (e.g. a canopy above its trunk).
@export var draw_offset := Vector2.ZERO:
	set(value):
		draw_offset = value
		queue_redraw()
@export var detailed_texture_override: Texture2D:
	set(value):
		detailed_texture_override = value
		queue_redraw()
@export var pixel_texture_override: Texture2D
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
## Moves the top of the relief bump away from the piece centre (e.g. a hill's summit).
@export var relief_offset := Vector2.ZERO
@export var is_orichalcum := false
## Minimap colour of this piece's blocked ground (or, for a flat piece with no blocked ground, of its
## whole patch). Fully transparent = the battlefield's default (rock brown, water teal). Read by
## RtsMissionBattlefield only, so older battlefields ignore it.
@export var minimap_color := Color(0.0, 0.0, 0.0, 0.0)
## Crown fades over selected troops walking beneath it (RtsMissionBattlefield). Pieces whose id ends
## in "_tree" always fade, as in the desert kit.
@export var canopy_fade := false

var texture: Texture2D
var pixel_mode := false
## Set by a battlefield's planet skin; empty = the piece's own art.
var skin_directories := PackedStringArray()

static var _editor_dune_material: ShaderMaterial


func _ready() -> void:
	# Editor only: show dunes as lit sand instead of their raw grey relief map. Set on the canvas item
	# directly (not the `material` property) so nothing is saved into scenes.
	if Engine.is_editor_hint() and layer_role == "dune":
		if _editor_dune_material == null:
			_editor_dune_material = ShaderMaterial.new()
			_editor_dune_material.shader = load("res://assets/shaders/rts_carbon_dune.gdshader")
			var blank := ImageTexture.create_from_image(Image.create_empty(4, 4, false, Image.FORMAT_L8))
			_editor_dune_material.set_shader_parameter("sand_tex", load("res://assets/textures/rts/carbon/sand_tile_hd.png"))
			_editor_dune_material.set_shader_parameter("calm_mask_tex", blank)
			_editor_dune_material.set_shader_parameter("tread_tex", blank)
			_editor_dune_material.set_shader_parameter("show_treads", false)
		RenderingServer.canvas_item_set_material(get_canvas_item(), _editor_dune_material.get_rid())


func apply_visual_mode(use_pixel: bool, dune_shader: Shader = null, sand_tex: Texture2D = null,
		calm_tex: Texture2D = null, tread_tex: Texture2D = null, map_world_size := Vector2(1408, 896),
		show_treads := true, detailed_art_directory := "", use_painted_sand := false) -> void:
	pixel_mode = use_pixel
	texture = null
	# Planet skin (Detailed only): the first skin folder holding this piece's painting wins.
	if not use_pixel:
		for dir in skin_directories:
			if flip_x:
				texture = RtsCarbonArt.detailed_texture(piece_id + "_mirrored", dir)
			if texture == null:
				texture = RtsCarbonArt.detailed_texture(piece_id, dir)
			if texture != null:
				break
	if texture == null:
		texture = pixel_texture_override if use_pixel else detailed_texture_override
	if texture == null and flip_x and not use_pixel:
		texture = RtsCarbonArt.detailed_texture(piece_id + "_mirrored", detailed_art_directory)
	if texture == null:
		texture = RtsCarbonArt.texture(piece_id, use_pixel, detailed_art_directory)
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
		sm.set_shader_parameter("painted_sand", use_painted_sand)
		sm.set_shader_parameter("show_treads", show_treads)
	queue_redraw()


func _draw() -> void:
	var painting := detailed_texture_override if Engine.is_editor_hint() else texture
	if painting == null:
		return
	var draw_size := world_size
	if flip_x:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(painting, Rect2(draw_offset - draw_size * 0.5, draw_size), false)
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
	var local_pt := to_local(world_pt) - relief_offset
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
