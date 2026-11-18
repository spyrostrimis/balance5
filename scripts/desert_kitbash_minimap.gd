extends Node2D
## Playable tile-based desert mini-map built from the Modular Desert Kitbash Library + Balance4 Blue Tank.

const GRID_W := 20
const GRID_H := 11

# Tactical desert road layout: west approach -> central crystal ring road -> east highway
const ROAD_CELLS: Array[Vector2i] = [
	Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
	# North ring bypass
	Vector2i(5, 4), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3),
	Vector2i(9, 3), Vector2i(10, 3), Vector2i(11, 3), Vector2i(12, 3), Vector2i(12, 4), Vector2i(12, 5),
	# South ring bypass
	Vector2i(5, 6), Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7),
	Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7), Vector2i(12, 7), Vector2i(12, 6),
	# East highway
	Vector2i(13, 5), Vector2i(14, 5), Vector2i(15, 5), Vector2i(15, 6), Vector2i(15, 7),
	Vector2i(16, 7), Vector2i(17, 7), Vector2i(18, 7), Vector2i(19, 7),
]

@onready var _sand_layer: TileMapLayer = $SandBaseLayer
@onready var _road_layer: TileMapLayer = $RoadLayer
@onready var _collision_overlay: Node2D = $CollisionOverlay
@onready var _hint_label: Label = $HUD/HintPanel/HintLabel

var _show_collisions: bool = false


func _ready() -> void:
	_build_sand_tiles()
	_build_road_tiles()
	_collision_overlay.setup(self)
	_update_overlay()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		set_show_collisions(not _show_collisions)
		get_viewport().set_input_as_handled()


func set_show_collisions(enabled: bool) -> void:
	_show_collisions = enabled
	_update_overlay()


func _build_sand_tiles() -> void:
	_sand_layer.clear()
	# Pad 1 row above and below (rows -1..GRID_H) so 1280x720 at 2x zoom has edge-to-edge sand
	for r in range(-1, GRID_H + 1):
		for c in range(GRID_W):
			_sand_layer.set_cell(Vector2i(c, r), 0, Vector2i(posmod(c, 4), posmod(r, 4)))


func _build_road_tiles() -> void:
	_road_layer.clear()
	var road_set: Dictionary = {}
	for cell in ROAD_CELLS:
		road_set[cell] = true

	for cell in ROAD_CELLS:
		var mask := 0
		if road_set.has(cell + Vector2i(0, -1)):
			mask |= 1  # North
		if road_set.has(cell + Vector2i(1, 0)) or cell.x == GRID_W - 1:
			mask |= 2  # East
		if road_set.has(cell + Vector2i(0, 1)):
			mask |= 4  # South
		if road_set.has(cell + Vector2i(-1, 0)) or cell.x == 0:
			mask |= 8  # West
		_road_layer.set_cell(cell, 0, Vector2i(mask % 4, mask / 4))


func _update_overlay() -> void:
	_collision_overlay.visible = _show_collisions
	_collision_overlay.queue_redraw()
	if _hint_label != null:
		var state := "ON" if _show_collisions else "OFF"
		_hint_label.text = (
			"Modular Desert Kitbash Mini-Map  ·  Click or WASD/Arrows to drive Blue Tank  ·  "
			+ "Press C for colliders (%s)" % state
		)
