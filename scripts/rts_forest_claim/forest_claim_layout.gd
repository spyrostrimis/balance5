class_name ForestClaimLayout
extends Resource
## Rows use ~ for the ravine, # for a raised cliff, . for ochre and m for forest floor.
## Scenery locations are in cells. Whole numbers lie on tile corners and .5 is a centre.
@export var label := ""
@export var terrain: PackedStringArray
@export var scenery: Array[Dictionary] = []


func size() -> Vector2i:
	return Vector2i(terrain[0].length(), terrain.size())


func tile(cell: Vector2i) -> String:
	if not Rect2i(Vector2i.ZERO, size()).has_point(cell):
		return "~"
	return terrain[cell.y][cell.x]


func height(cell: Vector2i) -> float:
	match tile(cell):
		"~": return -142.0
		"#": return 69.0
	return 0.0
