class_name RtsGrid
extends Node2D
## The battlefield as a chessboard of tiles.
## Knows which tiles are walkable (from the Ground layer's "walkable" custom data), which unit
## claims which tile (one unit per tile), and finds routes with A* (AStarGrid2D).
## F1 in the test map draws blocked tiles red and claimed tiles white.

const WALKABLE_DATA := "walkable"
const BLOCKED_COLOR := Color(0.95, 0.1, 0.1, 0.35)
const CLAIM_COLOR := Color(1, 1, 1, 0.55)
const GRID_COLOR := Color(0, 0, 0, 0.12)

@export var ground_path: NodePath = ^"../Ground"

var show_debug := false:
	set(value):
		show_debug = value
		queue_redraw()

var ground: TileMapLayer
var tile_size := Vector2i(32, 32)
var region := Rect2i()

var _astar := AStarGrid2D.new()
var _claims := {}  # Vector2i -> RtsUnit


func _ready() -> void:
	setup()


func setup() -> void:
	ground = get_node(ground_path) as TileMapLayer
	tile_size = ground.tile_set.tile_size
	region = ground.get_used_rect()
	_astar.region = region
	_astar.cell_size = Vector2(tile_size)
	# Diagonal steps are allowed, but never squeezing between two blocked corners.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell := Vector2i(x, y)
			var data := ground.get_cell_tile_data(cell)
			var walkable := data != null and bool(data.get_custom_data(WALKABLE_DATA))
			_astar.set_point_solid(cell, not walkable)
	_claims.clear()


# --- Tiles and positions -------------------------------------------------------------------

func cell_of(world: Vector2) -> Vector2i:
	return Vector2i((world / Vector2(tile_size)).floor())


func center_of(cell: Vector2i) -> Vector2:
	return Vector2(cell * tile_size) + Vector2(tile_size) * 0.5


func world_rect() -> Rect2:
	return Rect2(Vector2(region.position * tile_size), Vector2(region.size * tile_size))


func in_bounds(cell: Vector2i) -> bool:
	return region.has_point(cell)


func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and not _astar.is_point_solid(cell)


## Walkable and not claimed by another unit.
func is_free(cell: Vector2i, for_unit: Object = null) -> bool:
	if not is_walkable(cell):
		return false
	var holder: Object = _claims.get(cell)
	return holder == null or holder == for_unit


## Tile distance where diagonal neighbours count as 1 (so range 1 means "touching").
static func tile_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# --- One unit per tile ---------------------------------------------------------------------

func claim(cell: Vector2i, unit: Object) -> bool:
	if not is_free(cell, unit):
		return false
	_claims[cell] = unit
	_redraw_debug()
	return true


func release(cell: Vector2i, unit: Object) -> void:
	if _claims.get(cell) == unit:
		_claims.erase(cell)
		_redraw_debug()


func unit_at(cell: Vector2i) -> Object:
	var holder: Object = _claims.get(cell)
	return holder if is_instance_valid(holder) else null


# --- Routes --------------------------------------------------------------------------------

## Tiles to walk through from `from` to `to`, not including `from`.
## With avoid_units, tiles held by other units count as blocked, and the route stops at the
## closest reachable tile when `to` itself cannot be reached.
func find_path(from: Vector2i, to: Vector2i, unit: Object = null, avoid_units := false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not in_bounds(from) or not in_bounds(to):
		return result
	var made_solid: Array[Vector2i] = []
	if avoid_units:
		for cell: Vector2i in _claims:
			if _claims[cell] != unit and not _astar.is_point_solid(cell):
				_astar.set_point_solid(cell, true)
				made_solid.append(cell)
	# The start tile may be one we just marked, or the unit may stand on it; keep it open.
	var start_was_solid := _astar.is_point_solid(from)
	_astar.set_point_solid(from, false)
	var ids := _astar.get_id_path(from, to, avoid_units)
	_astar.set_point_solid(from, start_was_solid)
	for cell in made_solid:
		_astar.set_point_solid(cell, false)
	for i in range(1, ids.size()):
		result.append(ids[i])
	return result


## The `count` free tiles nearest to `center`, closest first. Tiles held by any of `movers`
## count as free, because those units are about to leave them.
func free_cells_near(center: Vector2i, count: int, movers: Array = []) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var max_ring := maxi(region.size.x, region.size.y)
	for ring in range(0, max_ring):
		var ring_cells: Array[Vector2i] = []
		for y in range(center.y - ring, center.y + ring + 1):
			for x in range(center.x - ring, center.x + ring + 1):
				var cell := Vector2i(x, y)
				if tile_distance(cell, center) != ring or not is_walkable(cell):
					continue
				var holder: Object = _claims.get(cell)
				if holder == null or holder in movers:
					ring_cells.append(cell)
		ring_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return Vector2(a - center).length_squared() < Vector2(b - center).length_squared())
		for cell in ring_cells:
			found.append(cell)
			if found.size() >= count:
				return found
	return found


# --- Debug overlay (F1) --------------------------------------------------------------------

func _redraw_debug() -> void:
	if show_debug:
		queue_redraw()


func _draw() -> void:
	if not show_debug:
		return
	var size := Vector2(tile_size)
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell * tile_size), size)
			if _astar.is_point_solid(cell):
				draw_rect(rect, BLOCKED_COLOR)
			draw_rect(rect, GRID_COLOR, false, 1.0)
	for cell: Vector2i in _claims:
		draw_rect(Rect2(Vector2(cell * tile_size), size).grow(-2.0), CLAIM_COLOR, false, 2.0)
