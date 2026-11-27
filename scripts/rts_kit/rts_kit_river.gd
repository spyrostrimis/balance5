@tool
class_name RtsKitRiver
extends RtsCarbonPiece
## A river that follows a path. Its child Line2D "Course" draws the painted river strip (water in the
## middle, banks on both sides) along its points, and the same points decide the blocked ground:
## everything within water_half_width of the course is water. Bend the river by dragging the
## Course points in the 2D editor; the water and the blocked ground move together, no repainting.
## Fords and bridges are separate kit pieces (layer_role "crossing") placed on top; their footprint
## reopens the water under them (RtsMissionBattlefield.is_point_blocked).

## Half the width of the blocked water, in world pixels. The Course line is wider: its outer parts
## are the painted banks, which stay walkable.
@export var water_half_width := 32.0

var _course: Line2D


func _ready() -> void:
	_course = get_node_or_null("Course") as Line2D
	super._ready()


func course() -> Line2D:
	if _course == null or not is_instance_valid(_course):
		_course = get_node_or_null("Course") as Line2D
	return _course


func apply_visual_mode(use_pixel: bool, dune_shader: Shader = null, sand_tex: Texture2D = null,
		calm_tex: Texture2D = null, tread_tex: Texture2D = null, map_world_size := Vector2(1408, 896),
		show_treads := true, detailed_art_directory := "", use_painted_sand := false) -> void:
	super.apply_visual_mode(use_pixel, dune_shader, sand_tex, calm_tex, tread_tex, map_world_size,
			show_treads, detailed_art_directory, use_painted_sand)
	var c := course()
	if c == null:
		return
	c.texture = texture
	c.texture_mode = Line2D.LINE_TEXTURE_TILE
	c.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if use_pixel else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## The course drawn by the Line2D; the piece's own painting is only the strip it repeats.
func _draw() -> void:
	pass


func blocks_world_point(world_pt: Vector2) -> bool:
	return distance_to_course(world_pt) <= water_half_width


## Distance from a world point to the river's centre line (INF without a course).
func distance_to_course(world_pt: Vector2) -> float:
	var c := course()
	if c == null or c.get_point_count() < 2:
		return INF
	var p := c.to_local(world_pt)
	var best := INF
	for i in range(c.get_point_count() - 1):
		var q := Geometry2D.get_closest_point_to_segment(p, c.get_point_position(i), c.get_point_position(i + 1))
		best = minf(best, p.distance_to(q))
	return best * c.global_scale.x


## Direction the water runs at the course point nearest world_pt (for placing a ford or bridge).
func flow_direction_at(world_pt: Vector2) -> Vector2:
	var c := course()
	if c == null or c.get_point_count() < 2:
		return Vector2.RIGHT
	var p := c.to_local(world_pt)
	var best := INF
	var dir := Vector2.RIGHT
	for i in range(c.get_point_count() - 1):
		var a := c.get_point_position(i)
		var b := c.get_point_position(i + 1)
		var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
		if d < best:
			best = d
			dir = (b - a).normalized()
	return (c.global_transform.basis_xform(dir)).normalized()
