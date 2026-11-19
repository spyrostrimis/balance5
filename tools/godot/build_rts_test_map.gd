extends SceneTree
## One-time builder for the RTS test map and its placeholder tile set.
##   python tools/python/make_rts_placeholder_tiles.py
##   Godot --path . --headless --import
##   Godot --path . --headless --script res://tools/godot/build_rts_test_map.gd -- --force
## Rerunning overwrites any tiles repainted by hand in the editor, hence the guard.

const ToolGuard := preload("res://tools/godot/tool_guard.gd")

const TEXTURE_PATH := "res://assets/textures/rts/placeholder_tiles.png"
const TILESET_PATH := "res://scenes/rts/rts_placeholder_tiles.tres"
const SCENE_PATH := "res://scenes/maps/rts_test_map.tscn"
const UNIT_SCENE := "res://scenes/actors/rts_unit.tscn"
const TILE := 32
const W := 48
const H := 30

enum T { SAND, ROAD, ROCK, ORE }
const WALKABLE := [true, true, false, false]

const SPAWNS := [
	["BlueCommander", "blue_commander", Vector2i(4, 9)],
	["BlueTroop1", "blue_troop", Vector2i(6, 8)],
	["BlueTroop2", "blue_troop", Vector2i(7, 9)],
	["BlueTroop3", "blue_troop", Vector2i(6, 10)],
	["BlueTroop4", "blue_troop", Vector2i(5, 11)],
	["RedCommander", "red_commander", Vector2i(43, 24)],
	["RedTroop1", "red_troop", Vector2i(42, 22)],
	["RedTroop2", "red_troop", Vector2i(40, 24)],
	["RedTroop3", "red_troop", Vector2i(41, 23)],
	["RedTroop4", "red_troop", Vector2i(41, 25)],
]


func _init() -> void:
	if not ToolGuard.confirm(self, PackedStringArray([TILESET_PATH, SCENE_PATH])):
		return
	var tile_set := _build_tile_set()
	if tile_set == null:
		quit(1)
		return
	var err := ResourceSaver.save(tile_set, TILESET_PATH)
	if err != OK:
		push_error("Could not save tile set: " + error_string(err))
		quit(1)
		return
	tile_set = load(TILESET_PATH)
	err = _build_scene(tile_set)
	quit(0 if err == OK else 1)


func _build_tile_set() -> TileSet:
	var texture := load(TEXTURE_PATH) as Texture2D
	if texture == null:
		push_error("Missing %s: run tools/python/make_rts_placeholder_tiles.py and --import first" % TEXTURE_PATH)
		return null
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "walkable")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	for i in WALKABLE.size():
		source.create_tile(Vector2i(i, 0))
	ts.add_source(source, 0)
	for i in WALKABLE.size():
		source.get_tile_data(Vector2i(i, 0), 0).set_custom_data("walkable", WALKABLE[i])
	return ts


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


func _in_ellipse(p: Vector2, center: Vector2, radii: Vector2) -> bool:
	var d := (p - center) / radii
	return d.length_squared() <= 1.0


## A rough sketch of the Mission 1 layout: Blue west, Red south-east, a diagonal road through
## a ring around the central Orichalcum rock, cliffs in two corners, a mesa, scattered boulders,
## and a north-south ridge with a road gate to test routing.
func _tile_at(x: int, y: int) -> int:
	var p := Vector2(x, y) + Vector2(0.5, 0.5)
	var core := Vector2(24, 15)
	if _in_ellipse(p, core, Vector2(2.3, 1.6)):
		return T.ORE
	if _in_ellipse(p, core, Vector2(3.5, 2.7)):
		return T.ROCK
	var road_pts := [Vector2(0, 8), Vector2(9, 10), Vector2(19.5, 14.2)]
	var road_east := [Vector2(28.7, 17), Vector2(38, 22), Vector2(48, 25.5)]
	for pts: Array in [road_pts, road_east]:
		for i in pts.size() - 1:
			if _segment_distance(p, pts[i], pts[i + 1]) < 1.3:
				return T.ROAD
	var ring := p.distance_to(core)
	if ring > 4.6 and ring < 6.0:
		return T.ROAD
	var rocks := [
		[Vector2(45, 2), Vector2(9, 6)],     # north-east cliffs
		[Vector2(1, 29), Vector2(10, 6)],    # south-west cliffs
		[Vector2(9, 2), Vector2(4, 2)],      # north-west mesa
		[Vector2(14, 21), Vector2(1.7, 1.4)],
		[Vector2(33, 8), Vector2(2.2, 1.6)],
		[Vector2(30, 25), Vector2(1.5, 1.2)],
	]
	for r: Array in rocks:
		if _in_ellipse(p, r[0], r[1]):
			return T.ROCK
	if (x == 15 or x == 16) and y >= 3 and y <= 18:  # ridge; the road above cuts the gate
		return T.ROCK
	return T.SAND


func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_own(child, owner_node)


func _build_scene(tile_set: TileSet) -> Error:
	var root := Node2D.new()
	root.name = "RtsTestMap"
	root.set_script(load("res://scripts/rts/rts_test_map.gd"))

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tile_set
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep pixels crisp when zoomed
	var ascii := PackedStringArray()
	for y in H:
		var line := ""
		for x in W:
			var t := _tile_at(x, y)
			ground.set_cell(Vector2i(x, y), 0, Vector2i(t, 0))
			line += ".=#*"[t]
		ascii.append(line)
	root.add_child(ground)

	var grid := Node2D.new()
	grid.name = "Grid"
	grid.set_script(load("res://scripts/rts/rts_grid.gd"))
	root.add_child(grid)

	var units := Node2D.new()
	units.name = "Units"
	units.y_sort_enabled = true
	root.add_child(units)
	var unit_scene := load(UNIT_SCENE) as PackedScene
	for spawn: Array in SPAWNS:
		var cell: Vector2i = spawn[2]
		if not WALKABLE[_tile_at(cell.x, cell.y)]:
			push_error("Spawn %s is on a blocked tile %s" % [spawn[0], cell])
			return FAILED
		var unit := unit_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		unit.name = spawn[0]
		unit.set("stats", load("res://scenes/rts/units/%s.tres" % spawn[1]))
		unit.position = Vector2(cell * TILE) + Vector2(TILE, TILE) * 0.5
		units.add_child(unit)

	var commands := Node2D.new()
	commands.name = "Commands"
	commands.set_script(load("res://scripts/rts/rts_commands.gd"))
	root.add_child(commands)

	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.set_script(load("res://scripts/rts/rts_camera.gd"))
	root.add_child(camera)

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	root.add_child(hud)
	var help := Label.new()
	help.name = "Help"
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_left = 12
	help.offset_right = -12
	help.offset_top = -32
	help.offset_bottom = -8
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_constant_override("outline_size", 5)
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hud.add_child(help)

	for child in root.get_children():
		_own(child, root)
	# Instanced units keep their own children; only the instance root belongs to this scene.
	for unit in units.get_children():
		for c in unit.get_children():
			c.owner = unit

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Pack failed: " + error_string(err))
		return err
	err = ResourceSaver.save(packed, SCENE_PATH)
	print("\n".join(ascii))
	print("Saved %s (%s)" % [SCENE_PATH, error_string(err)])
	root.free()
	return err
