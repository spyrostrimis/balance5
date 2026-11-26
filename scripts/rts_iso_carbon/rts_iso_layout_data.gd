class_name RtsIsoLayoutData
extends Resource
## Pure data-driven battlefield layout for 'RTS Isometric 2— Forest Claim Carbon'.
## Both Layout A and Layout B use the exact same art files and RtsIsoKit catalog;
## changing terrain_rows and placements automatically updates visuals, shelf mist,
## blocked AStarGrid2D cells, canopy shade, and the isometric minimap.

@export var layout_id := "layout_a"
@export var display_name := "Layout A · Shelf Clearing"
@export_multiline var summary := ""
## 36 rows x 36 chars: '.'=Void/Mist, 'F'=Forest Turf, 'M'=Moss Verge, 'O'=Ochre Clearing, 'T'=Worn Trail
@export var terrain_rows: PackedStringArray = PackedStringArray()
## Array of Dictionaries: { "id": String, "cell": Vector2i, "offset": Vector2, "flip_x": bool, "tint": Color, "tag": String }
@export var placements: Array[Dictionary] = []
## Array of Dictionaries: { "name": String, "team": int, "role": int, "cell": Vector2i }
@export var unit_spawns: Array[Dictionary] = []
@export var camera_start_cell := Vector2(16.5, 19.5)
@export var camera_poi_north := Vector2(18.0, 11.0)
@export var camera_poi_east := Vector2(24.0, 16.0)


func terrain_code_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= terrain_rows.size():
		return "."
	var row := terrain_rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return "."
	return row.substr(cell.x, 1)


func is_shelf_cell(cell: Vector2i) -> bool:
	return terrain_code_at(cell) != "."


func ochre_weight_at(cell: Vector2i) -> float:
	match terrain_code_at(cell):
		"T":
			return 1.0
		"O":
			return 0.88
		"M":
			return 0.36
		"F":
			return 0.04
		_:
			return 0.0
