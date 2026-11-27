extends SceneTree
## ONE-TIME bootstrap of the forest kit and RTS Mission 1 – Forest (Blue's first mission).
## After it runs, the kit and mission scenes are hand-edited files; rerunning overwrites them, so it
## refuses without `-- --force` (tool_guard.gd).
##
##   C:/Python312/python.exe tools/python/make_forest_kit.py   (art into assets/textures/rts/forest_kit)
##   Godot_console.exe --headless --editor --import --path .
##   Godot_console.exe --headless --path . --script res://tools/godot/bootstrap_forest_kit.gd -- --force
##
## Writes:
##   scenes/rts/forest_kit/pieces/<piece_id>.tscn   one scene per painted piece (art, blocked footprint,
##                                                  shadow, shade, minimap colour, tags)
##   scenes/rts/forest_kit/groups/*.tscn            editable groups made of piece instances
##   scenes/rts/forest_kit/kit_preview.tscn         arrangements page + every piece (desert_kit_preview.gd)
##   scenes/maps/rts_mission_1_forest.tscn          the forest map, with the desert map's forces

const Guard := preload("res://tools/godot/tool_guard.gd")
const PIECE_SCRIPT := preload("res://scripts/rts_carbon/rts_carbon_piece.gd")
const RIVER_SCRIPT := preload("res://scripts/rts_kit/rts_kit_river.gd")
const MISSION_SCRIPT := preload("res://scripts/rts_kit/rts_mission_battlefield.gd")
const PREVIEW_SCRIPT := preload("res://scripts/rts_kit/desert_kit_preview.gd")
const UNIT_SCRIPT := preload("res://scripts/rts_carbon/rts_carbon_unit.gd")
const GRID_SCRIPT := preload("res://scripts/rts/rts_grid.gd")
const HUD_SCRIPT := preload("res://scripts/rts_kit/rts_mission_hud.gd")

const KIT_DIR := "res://scenes/rts/forest_kit/"
const PIECES_DIR := KIT_DIR + "pieces/"
const GROUPS_DIR := KIT_DIR + "groups/"
const KIT_ART := "res://assets/textures/rts/forest_kit/"
const DESERT_PIECES := "res://scenes/rts/desert_kit/pieces/"
const DESERT_MAP := "res://scenes/maps/rts_mission_1_desert.tscn"
const MISSION_PATH := "res://scenes/maps/rts_mission_1_forest.tscn"

const C_TREE := Color(0.09, 0.24, 0.13, 1.0)
const C_DIRT := Color(0.66, 0.46, 0.24, 0.92)
const C_GRAVEL := Color(0.52, 0.50, 0.47, 0.92)
const C_ROCK := Color(0.40, 0.42, 0.36, 1.0)
const C_WOOD := Color(0.42, 0.29, 0.16, 1.0)
const C_WATER := Color(0.20, 0.50, 0.80, 1.0)

## piece_id -> definition. size = world size; core = blocked ellipse radii (centred on core_centre);
## lift = how far the painting is drawn above the piece's ground pivot.
var PIECES := {
	# Flat ground
	"dirt_clearing_plaza": {"size": Vector2(400, 288), "role": "ground_decal", "mm": C_DIRT, "tags": ["forest", "ground", "clearing"]},
	"dirt_patch_round": {"size": Vector2(112, 96), "role": "ground_decal", "mm": C_DIRT, "tags": ["forest", "ground", "clearing"]},
	"dirt_patch_long": {"size": Vector2(176, 80), "role": "ground_decal", "mm": C_DIRT, "tags": ["forest", "ground", "clearing"]},
	"gravel_pad_base": {"size": Vector2(288, 224), "role": "ground_decal", "mm": C_GRAVEL, "tags": ["forest", "ground", "gravel", "building"]},
	"gravel_field": {"size": Vector2(288, 208), "role": "ground_decal", "mm": C_GRAVEL, "tags": ["forest", "ground", "gravel"]},
	"grass_flowers": {"size": Vector2(40, 30), "role": "ground_decal", "tags": ["forest", "ground", "detail", "plants"]},
	"grass_stones": {"size": Vector2(40, 30), "role": "ground_decal", "tags": ["forest", "ground", "detail", "rock"]},
	"fern_patch": {"size": Vector2(48, 36), "role": "ground_decal", "tags": ["forest", "ground", "detail", "plants"]},
	# Forest masses: block the trunks' core only; the crown overhangs and fades over selected troops.
	"tree_cluster_large": {"size": Vector2(288, 224), "core": Vector2(112, 80), "lift": 80.0, "tree": true, "tags": ["forest", "trees", "cluster"]},
	"tree_cluster_medium": {"size": Vector2(192, 156), "core": Vector2(72, 54), "lift": 54.0, "tree": true, "tags": ["forest", "trees", "cluster"]},
	"tree_cluster_small": {"size": Vector2(128, 108), "core": Vector2(44, 36), "lift": 36.0, "tree": true, "tags": ["forest", "trees", "cluster"]},
	"conifer_tree": {"size": Vector2(64, 64), "trunk": true, "lift": 18.0, "tree": true, "tags": ["forest", "trees", "single"]},
	"broadleaf_tree": {"size": Vector2(72, 66), "trunk": true, "lift": 18.0, "tree": true, "tags": ["forest", "trees", "single"]},
	"broadleaf_tree_tall": {"size": Vector2(84, 78), "trunk": true, "lift": 22.0, "tree": true, "tags": ["forest", "trees", "single"]},
	"maple_tree_red": {"size": Vector2(80, 78), "trunk": true, "lift": 22.0, "tree": true, "tags": ["forest", "trees", "single", "maple"]},
	"forest_verge": {"size": Vector2(192, 56), "role": "prop", "lift": 14.0, "verge": true, "tags": ["forest", "trees", "plants", "edge"]},
	# Water
	"river": {"size": Vector2(256, 112), "role": "water", "river": true, "mm": C_WATER, "tags": ["forest", "water", "river"]},
	"river_ford": {"size": Vector2(176, 136), "role": "crossing", "cross": Vector2(72, 68), "mm": Color(0.60, 0.58, 0.52, 1.0), "tags": ["forest", "water", "river", "crossing"]},
	"river_bridge": {"size": Vector2(104, 144), "role": "crossing", "cross": Vector2(48, 72), "mm": C_WOOD, "tags": ["forest", "water", "river", "crossing", "building"]},
	# Rocks and logs (cover)
	"mossy_boulder": {"size": Vector2(44, 38), "rock": Vector2(16, 13), "mm": C_ROCK, "tags": ["forest", "rock", "cover"]},
	"mossy_boulder_pair": {"size": Vector2(76, 52), "rock": Vector2(30, 18), "mm": C_ROCK, "tags": ["forest", "rock", "cover"]},
	"mossy_slab": {"size": Vector2(88, 48), "rock": Vector2(36, 16), "mm": C_ROCK, "tags": ["forest", "rock", "cover"]},
	"fallen_log": {"size": Vector2(112, 36), "rock": Vector2(48, 11), "mm": C_WOOD, "tags": ["forest", "log", "cover"]},
	"tree_stump": {"size": Vector2(28, 24), "rock": Vector2(9, 8), "mm": C_WOOD, "tags": ["forest", "log"]},
}

var _scenes := {}  # piece_id -> PackedScene
## Sizes and blocked outlines measured from the owner's paintings by make_forest_kit.py.
var _shapes := {}


func _initialize() -> void:
	if not Guard.confirm(self, PackedStringArray([KIT_DIR, MISSION_PATH])):
		return
	for d in [PIECES_DIR, GROUPS_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	if FileAccess.file_exists(KIT_ART + "kit_shapes.json"):
		_shapes = JSON.parse_string(FileAccess.get_file_as_string(KIT_ART + "kit_shapes.json"))
		print("Using painted shapes for: ", ", ".join(_shapes.keys()))
	var ids := PIECES.keys()
	ids.sort()
	for id in ids:
		_save_piece(id)
	print("Saved %d forest piece scenes" % ids.size())
	_save_groups()
	_save_preview()
	_save_mission()
	print("FOREST KIT BOOTSTRAP DONE")
	quit(0)


# --- pieces ---------------------------------------------------------------------------------------

func _tex(id: String, pixel: bool) -> Texture2D:
	var path := KIT_ART + id + ("_pixel.png" if pixel else "_hd.png")
	if not ResourceLoader.exists(path, "Texture2D"):
		push_error("Missing art " + path)
		return null
	return load(path) as Texture2D


func _pascal(id: String) -> String:
	var out := ""
	for part in id.split("_"):
		out += part.capitalize().replace(" ", "")
	return out


## A slightly irregular oval polygon, so blocked ground does not look machine-made in F1.
func _oval(centre: Vector2, radii: Vector2, n := 14, wobble := 0.06) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var k := 1.0 + wobble * sin(a * 3.0 + 0.7)
		pts.append((centre + Vector2(cos(a) * radii.x, sin(a) * radii.y) * k).round())
	return pts


func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p[0], p[1]))
	return out


func _save_piece(id: String) -> void:
	var d: Dictionary = PIECES[id]
	var root := Node2D.new()
	root.name = _pascal(id)
	root.set_script(RIVER_SCRIPT if d.get("river", false) else PIECE_SCRIPT)
	var size: Vector2 = d["size"]
	var sh: Dictionary = _shapes.get(id, {})
	if sh.has("world_size"):
		size = Vector2(sh["world_size"][0], sh["world_size"][1])
	root.set("piece_id", id)
	root.set("world_size", size)
	root.set("layer_role", d.get("role", "obstacle"))
	root.set("detailed_texture_override", _tex(id, false))
	root.set("pixel_texture_override", _tex(id, true))
	root.set("blocked_poly", PackedVector2Array())
	root.set("shadow_alpha", 0.0)
	if d.has("mm"):
		root.set("minimap_color", d["mm"])
	var lift: float = float(sh.get("lift", d.get("lift", 0.0)))
	root.set("draw_offset", Vector2(0, -lift))
	if d.has("core"):
		var core: Vector2 = d["core"]
		root.set("blocked_poly", _poly(sh["poly"]) if sh.has("poly") else _oval(Vector2(0, -lift), core))
		root.set("shadow_offset", Vector2(16, -lift + 14))
		root.set("shadow_size", size * 1.02)
		root.set("shadow_alpha", 0.40)
		root.set("shade_offset", Vector2(12, -lift + 8))
		root.set("shade_radii", size * 0.52)
		root.set("shade_strength", 0.34)
		root.set("minimap_color", C_TREE)
	elif d.get("trunk", false):
		root.set("blocked_poly", PackedVector2Array([Vector2(-10, -6), Vector2(10, -6), Vector2(11, 7), Vector2(-11, 7)]))
		root.set("shadow_offset", Vector2(14, -lift + 10))
		root.set("shadow_size", size * 1.05)
		root.set("shadow_alpha", 0.32)
		root.set("shade_offset", Vector2(12, -lift + 6))
		root.set("shade_radii", size * 0.55)
		root.set("shade_strength", 0.30)
		root.set("minimap_color", C_TREE)
	elif d.get("verge", false):
		root.set("shadow_offset", Vector2(10, -lift + 6))
		root.set("shadow_size", size * Vector2(1.0, 0.9))
		root.set("shadow_alpha", 0.22)
	elif d.has("rock"):
		var r: Vector2 = d["rock"]
		root.set("blocked_poly", _poly(sh["poly"]) if sh.has("poly") else _oval(Vector2.ZERO, r, 10, 0.04))
		root.set("shadow_offset", Vector2(6, 5))
		root.set("shadow_size", size * 1.08)
		root.set("shadow_alpha", 0.34)
	elif d.has("cross"):
		var c: Vector2 = Vector2(sh["cross"][0], sh["cross"][1]) if sh.has("cross") else d["cross"]
		root.set("blocked_poly", PackedVector2Array([Vector2(-c.x, -c.y), Vector2(c.x, -c.y), Vector2(c.x, c.y), Vector2(-c.x, c.y)]))
	if d.get("tree", false):
		root.set("canopy_fade", true)
	if d.get("river", false):
		var rs: Dictionary = _shapes.get("river", {})
		root.set("water_half_width", float(rs.get("water_half_width", 32.0)))
		var course := Line2D.new()
		course.name = "Course"
		course.points = PackedVector2Array([Vector2(-128, 0), Vector2(0, 8), Vector2(128, 0)])
		course.width = float(rs.get("course_width", 112.0))
		course.texture = _tex(id, false)
		course.texture_mode = Line2D.LINE_TEXTURE_TILE
		course.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		course.joint_mode = Line2D.LINE_JOINT_ROUND
		course.begin_cap_mode = Line2D.LINE_CAP_NONE
		course.end_cap_mode = Line2D.LINE_CAP_NONE
		course.antialiased = false
		root.add_child(course)
		course.owner = root
	root.set_meta("tags", PackedStringArray(d["tags"]))
	var ps := PackedScene.new()
	_ok(ps.pack(root), "pack " + id)
	var path := PIECES_DIR + id + ".tscn"
	_ok(ResourceSaver.save(ps, path), path)
	_scenes[id] = load(path)
	root.free()


func _inst(id: String, pos: Vector2, props := {}) -> Node2D:
	var scene: PackedScene = _scenes[id] if _scenes.has(id) else load(DESERT_PIECES + id + ".tscn")
	var n := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	n.position = pos
	for k in props:
		n.set(k, PackedVector2Array(props[k]) if props[k] is Array else props[k])
	return n


func _add(parent: Node, child: Node, owner_root: Node, name := "") -> Node:
	if name != "":
		child.name = name
	parent.add_child(child)
	child.owner = owner_root
	return child


# --- groups ---------------------------------------------------------------------------------------

const GROUPS := {
	"woodland_copse": [
		["tree_cluster_medium", Vector2(0, 0), {}],
		["conifer_tree", Vector2(-96, 6), {}],
		["broadleaf_tree", Vector2(92, 10), {}],
		["forest_verge", Vector2(-6, 30), {"scale": Vector2(0.8, 0.8)}],
		["mossy_boulder", Vector2(64, 34), {}],
		["fern_patch", Vector2(-58, 40), {}],
	],
	"forest_corner": [
		["tree_cluster_large", Vector2(0, 0), {}],
		["tree_cluster_medium", Vector2(170, -60), {}],
		["tree_cluster_small", Vector2(-150, -20), {}],
		["broadleaf_tree_tall", Vector2(120, 16), {}],
		["forest_verge", Vector2(10, 34), {}],
	],
	"mossy_cover": [
		["mossy_boulder_pair", Vector2(-40, 0), {}],
		["fallen_log", Vector2(46, 14), {}],
		["tree_stump", Vector2(-2, 30), {}],
		["fern_patch", Vector2(-70, 22), {}],
		["grass_stones", Vector2(16, -18), {}],
	],
}


func _save_groups() -> void:
	for gname in GROUPS:
		var root := Node2D.new()
		root.name = _pascal(gname)
		root.y_sort_enabled = true
		var tags := PackedStringArray(["forest", "group"])
		for e in GROUPS[gname]:
			var inst := _inst(e[0], e[1], e[2])
			_add(root, inst, root, _pascal(e[0]) + str(root.get_child_count()))
			for t in PackedStringArray(PIECES[e[0]]["tags"]):
				if t not in tags and t != "single":
					tags.append(t)
		root.set_meta("tags", tags)
		var ps := PackedScene.new()
		_ok(ps.pack(root), "pack " + gname)
		_ok(ResourceSaver.save(ps, GROUPS_DIR + gname + ".tscn"), gname)
		root.free()


# --- kit preview ----------------------------------------------------------------------------------

func _label(text: String, pos: Vector2, width: float, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.z_index = 4
	l.position = pos - Vector2(width * 0.5, 0)
	l.size = Vector2(width, size + 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(1, 0.96, 0.84))
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.12, 0.05))
	l.add_theme_constant_override("outline_size", 6 if size > 13 else 4)
	l.add_theme_font_size_override("font_size", size)
	return l


func _save_preview() -> void:
	var root := Node2D.new()
	root.name = "ForestKitPreview"
	root.set_script(PREVIEW_SCRIPT)
	root.set("art_directory", KIT_ART.trim_suffix("/"))
	root.set("pieces_directory", PIECES_DIR.trim_suffix("/"))
	root.set("kit_title", "Forest Kit")
	root.set("centre_paintings", true)
	root.set("sand_area", Vector2(2400, 2700))
	var grass := Sprite2D.new()
	grass.z_index = -5
	grass.centered = false
	grass.position = Vector2(-1200, -700)
	grass.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grass.region_enabled = true
	grass.texture = _tex("sand_tile", false)
	_add(root, grass, root, "Sand")
	var shadows := Node2D.new()
	shadows.z_index = -3
	_add(root, shadows, root, "CastShadows")
	var cam := Camera2D.new()
	cam.zoom = Vector2(0.6, 0.6)
	_add(root, cam, root, "Camera")
	var views := _add(root, Node2D.new(), root, "Views")
	var page_a := Marker2D.new()
	page_a.set_meta("zoom", 0.6)
	_add(views, page_a, root, "Arrangements")
	var page_b := Marker2D.new()
	page_b.position = Vector2(0, 896)
	page_b.set_meta("zoom", 0.88)
	_add(views, page_b, root, "Pieces")

	# Page 1: a short river with a ford and a bridge, and the three groups.
	var decals := _add(root, Node2D.new(), root, "GroundDecals")
	(decals as Node2D).z_index = -4
	var river := _inst("river", Vector2.ZERO)
	_add(decals, river, root, "River")
	root.set_editable_instance(river, true)
	(river.get_node("Course") as Line2D).points = PackedVector2Array([Vector2(-640, -330), Vector2(-220, -318), Vector2(160, -338), Vector2(640, -326)])
	_add(decals, _inst("river_ford", Vector2(-260, -320), {"rotation": 0.0}), root, "RiverFord")
	_add(decals, _inst("river_bridge", Vector2(300, -332), {"rotation": -0.02}), root, "RiverBridge")
	_add(root, _label("River (drag the Course points) · ford · bridge", Vector2(0, -236), 800, 24), root)
	var ysort := _add(root, Node2D.new(), root, "YSortWorld")
	(ysort as Node2D).y_sort_enabled = true
	var spots := {
		"woodland_copse": [Vector2(-720, 230), "Woodland copse"],
		"forest_corner": [Vector2(-60, 250), "Forest corner"],
		"mossy_cover": [Vector2(700, 200), "Mossy cover"],
	}
	for g in spots:
		var inst := (load(GROUPS_DIR + g + ".tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
		inst.position = spots[g][0]
		_add(ysort, inst, root, _pascal(g))
		_add(root, _label(spots[g][1], spots[g][0] + Vector2(0, 90), 360, 24), root)
	_add(root, _label("Forest Kit · arrangements (Command scale) · 2 = every piece", Vector2(0, -540), 1200, 32), root, "Title")
	var hint := _label("[V] Detailed Painted  ·  [Esc] Developers Page", Vector2(0, 450), 800, 20)
	_add(root, hint, root, "ModeHint")
	var palette := Node2D.new()
	palette.y_sort_enabled = true
	_add(root, palette, root, "Palette")
	var ps := PackedScene.new()
	_ok(ps.pack(root), "pack preview")
	_ok(ResourceSaver.save(ps, KIT_DIR + "kit_preview.tscn"), "kit_preview.tscn")
	root.free()


# --- mission --------------------------------------------------------------------------------------

## The map, in world pixels (44 × 28 cells of 32). Pivots of tree masses sit at the bottom of their
## blocked core, so troops south of a mass draw in front of it and troops north of it pass beneath.
const RIVER_COURSE := [Vector2(540, -60), Vector2(478, 40), Vector2(404, 132), Vector2(306, 214),
	Vector2(196, 284), Vector2(84, 336), Vector2(-60, 372)]
const ROAD_MAIN := [Vector2(236, 940), Vector2(300, 862), Vector2(392, 780), Vector2(496, 690),
	Vector2(596, 586), Vector2(704, 456), Vector2(826, 408), Vector2(968, 372), Vector2(1120, 352),
	Vector2(1268, 352), Vector2(1440, 358)]
const ROAD_BASE := [Vector2(500, 686), Vector2(420, 662), Vector2(320, 652)]
const ROAD_FORD := [Vector2(452, 470), Vector2(404, 372), Vector2(372, 252), Vector2(330, 196),
	Vector2(284, 140), Vector2(236, 112)]
## Where the crossings sit on the river, and the river's flow there (art runs along local x).
const FORD_AT := Vector2(330, 196)
const BRIDGE_AT := Vector2(140, 310)

const LAYOUT := {
	"GroundDecals": [
		["dirt_clearing_plaza", "PlazaClearing", Vector2(704, 448), {}],
		["gravel_pad_base", "BlueBasePad", Vector2(296, 612), {}],
		["gravel_field", "SoutheastGravelField", Vector2(1136, 760), {}],
		["dirt_patch_round", "NortheastDirt", Vector2(1080, 170), {}],
		["dirt_patch_long", "FordMeadowDirt", Vector2(196, 120), {"rotation": -0.35}],
		["dirt_patch_round", "SouthLaneDirt", Vector2(560, 700), {"scale": Vector2(0.8, 0.8)}],
		["grass_flowers", "FlowersNorth", Vector2(560, 268), {}],
		["grass_flowers", "FlowersWest", Vector2(110, 470), {}],
		["grass_flowers", "FlowersEast", Vector2(1210, 268), {}],
		["grass_flowers", "FlowersSouth", Vector2(900, 612), {}],
		["grass_stones", "StonesPlazaNE", Vector2(866, 324), {}],
		["grass_stones", "StonesSE", Vector2(990, 664), {}],
		["grass_stones", "StonesBase", Vector2(470, 560), {}],
		["fern_patch", "FernsNorthEdge", Vector2(760, 236), {}],
		["fern_patch", "FernsSouthEdge", Vector2(700, 742), {}],
		["fern_patch", "FernsWest", Vector2(120, 560), {}],
		["fern_patch", "FernsMeadow", Vector2(212, 150), {}],
	],
	"YSortWorld": [
		# North forest mass (top middle), with a verge along its south edge.
		["tree_cluster_large", "NorthForest", Vector2(700, 150), {}],
		["tree_cluster_medium", "NorthForestEast", Vector2(890, 104), {}],
		["tree_cluster_small", "NorthForestWest", Vector2(560, 92), {}],
		["forest_verge", "NorthForestVerge", Vector2(700, 196), {}],
		["conifer_tree", "NorthEdgeConifer", Vector2(586, 176), {}],
		["broadleaf_tree", "NorthEdgeBroadleaf", Vector2(826, 186), {}],
		# Red maples (owner's request): one standing in the middle of the north wood's canopy (its
		# trunk hidden in the wood's blocked core), two on wood edges.
		["maple_tree_red", "MapleInNorthForest", Vector2(712, 151), {"draw_offset": Vector2(0, -64), "blocked_poly": []}],
		["maple_tree_red", "MapleNorthEdge", Vector2(604, 206), {}],
		# Northeast corner and the NE meadow's back wall.
		["tree_cluster_large", "NortheastForest", Vector2(1334, 176), {}],
		["tree_cluster_medium", "NortheastForestNorth", Vector2(1176, 58), {}],
		["broadleaf_tree_tall", "NortheastEdgeTree", Vector2(1228, 228), {}],
		# Beyond the river (northwest): a ring of trees round a small meadow.
		["tree_cluster_medium", "RiverWoodWest", Vector2(40, 170), {}],
		["tree_cluster_small", "RiverWoodNorth", Vector2(300, 52), {}],
		["conifer_tree", "RiverMeadowConifer", Vector2(110, 36), {}],
		# West edge and the southwest corner frame Blue's base.
		["tree_cluster_medium", "WestForest", Vector2(32, 520), {}],
		["tree_cluster_small", "WestForestSouth", Vector2(40, 660), {}],
		["tree_cluster_large", "SouthwestForest", Vector2(60, 900), {}],
		["conifer_tree", "WestEdgeConifer", Vector2(108, 430), {}],
		["broadleaf_tree", "SouthwestEdgeTree", Vector2(196, 800), {}],
		# South wood: the southern flank of the plaza.
		["tree_cluster_large", "SouthWood", Vector2(744, 900), {}],
		["tree_cluster_medium", "SouthWoodEast", Vector2(916, 906), {}],
		["tree_cluster_small", "SouthWoodWest", Vector2(552, 906), {}],
		["forest_verge", "SouthWoodVerge", Vector2(744, 764), {}],
		["broadleaf_tree_tall", "SouthWoodEdgeTree", Vector2(624, 790), {}],
		["maple_tree_red", "MapleSouthWoodEdge", Vector2(884, 770), {}],
		# East wood between Red's road and the gravel field, and the SE corner.
		["tree_cluster_medium", "EastWood", Vector2(1352, 610), {}],
		["tree_cluster_small", "EastWoodWest", Vector2(1236, 566), {}],
		["conifer_tree", "EastWoodConifer", Vector2(1300, 486), {}],
		["tree_cluster_small", "SoutheastForest", Vector2(1376, 900), {}],
		# A small copse east of the plaza splits Red's approach into the road and the south route.
		["tree_cluster_small", "EastCopse", Vector2(990, 566), {}],
		["broadleaf_tree", "EastCopseTree", Vector2(1056, 586), {}],
		# Buildings (desert kit pieces; the forest uses the same HQ and outposts).
		["blue_field_hq", "BlueFieldHQ", Vector2(250, 590), {}],
		["outpost_pad", "BlueOutpostPad", Vector2(380, 540), {"scale": Vector2(0.86, 0.86)}],
		["outpost_pad", "RedOutpostPad", Vector2(1296, 266), {}],
		# The Orichalcum rock and cover around the plaza.
		["orichalcum_outcrop", "CentralOrichalcum", Vector2(704, 444), {}],
		["mossy_boulder_pair", "PlazaCoverNorth", Vector2(470, 250), {}],
		["mossy_slab", "PlazaCoverEast", Vector2(900, 300), {"rotation": 0.3}],
		["fallen_log", "NortheastMeadowLog", Vector2(1150, 180), {"rotation": -0.2}],
		["mossy_boulder", "SouthLaneBoulder", Vector2(440, 820), {}],
		["mossy_boulder", "NorthLaneBoulder", Vector2(1110, 262), {}],
		["tree_stump", "BaseStump", Vector2(488, 486), {}],
		# A few lone trees so the open ground is not bare.
		["broadleaf_tree", "MeadowTreeNorth", Vector2(1000, 236), {}],
		["conifer_tree", "MeadowConiferSouth", Vector2(500, 830), {}],
		["broadleaf_tree_tall", "FieldTreeEast", Vector2(1290, 736), {}],
		["conifer_tree", "MeadowConiferWest", Vector2(176, 438), {}],
	],
}

## Same forces and stats as the desert map. Blue starts east of its base, Red on its road.
const UNIT_SPOTS := {
	"BlueTank": Vector2(452, 600),
	"BlueCommander": Vector2(520, 560),
	"BlueSquad1": Vector2(528, 640),
	"BlueSquad2": Vector2(470, 524),
	"BlueSquad3": Vector2(576, 500),
	"RedSquad1": Vector2(1000, 420),
	"RedCommander": Vector2(1064, 448),
	"RedSquad2": Vector2(1120, 420),
	"RedTank": Vector2(1176, 400),
	"RedSquad3": Vector2(1080, 300),
}

const VIEWS := {
	"1_Opening": Vector2(500, 500),
	"2_RiverFord": Vector2(360, 200),
	"3_NorthLane": Vector2(880, 270),
	"4_SouthLane": Vector2(760, 660),
	"5_BlueBase": Vector2(330, 620),
	"6_GravelField": Vector2(1120, 700),
	"7_RedRoad": Vector2(1140, 380),
}


## Angle of the river's flow at p, turned to point rightwards so the art's light stays upper-left.
func _flow_angle(p: Vector2) -> float:
	var best := INF
	var dir := Vector2.RIGHT
	for i in RIVER_COURSE.size() - 1:
		var a: Vector2 = RIVER_COURSE[i]
		var b: Vector2 = RIVER_COURSE[i + 1]
		var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
		if d < best:
			best = d
			dir = (b - a).normalized()
	if dir.x < 0.0:
		dir = -dir
	return snappedf(dir.angle(), 0.01)


func _line(points: Array, width: float) -> Line2D:
	var l := Line2D.new()
	l.points = PackedVector2Array(points)
	l.width = width
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	return l


func _save_mission() -> void:
	var desert := (load(DESERT_MAP) as PackedScene).instantiate()
	var root := Node2D.new()
	root.name = "RtsMission1Forest"
	root.set_script(MISSION_SCRIPT)
	root.set("detailed_art_directory", KIT_ART.trim_suffix("/"))
	root.set("art_directory_has_painted_sand", true)
	root.set("visual_squad_spacing", desert.get("visual_squad_spacing"))
	root.set("pixel_ground_from_kit", true)
	root.set("minimap_canopy_color", Color(0.14, 0.34, 0.16, 0.75))
	root.set("ground_tile_world", float(_shapes.get("ground", {}).get("tile_world", 256.0)))
	root.set("skin_names", PackedStringArray(["Forest"]))
	root.set("skin_paths", PackedStringArray([""]))
	root.set("skin_painted_sand", [true] as Array[bool])
	root.set_meta("owns_catalog_button", true)

	var floor_rect := ColorRect.new()
	floor_rect.z_index = -10
	floor_rect.size = Vector2(1408, 896)
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, floor_rect, root, "GroundFloor")
	var dunes := Node2D.new()
	dunes.z_index = -9
	_add(root, dunes, root, "Dunes")
	var roads := Node2D.new()
	roads.z_index = -8
	_add(root, roads, root, "RoadNetwork")
	_add(roads, _line(ROAD_MAIN, 48.0), root, "MainRoad")
	_add(roads, _line(ROAD_BASE, 36.0), root, "BaseDriveway")
	_add(roads, _line(ROAD_FORD, 34.0), root, "FordTrack")
	var decals := Node2D.new()
	decals.z_index = -7
	_add(root, decals, root, "GroundDecals")
	var river := _inst("river", Vector2.ZERO)
	_add(decals, river, root, "River")
	root.set_editable_instance(river, true)
	(river.get_node("Course") as Line2D).points = PackedVector2Array(RIVER_COURSE)
	for e in LAYOUT["GroundDecals"]:
		_add(decals, _inst(e[0], e[2], e[3]), root, e[1])
	# Crossings sit on the river, turned to its flow.
	_add(decals, _inst("river_ford", FORD_AT, {"rotation": _flow_angle(FORD_AT)}), root, "RiverFord")
	_add(decals, _inst("river_bridge", BRIDGE_AT, {"rotation": _flow_angle(BRIDGE_AT)}), root, "RiverBridge")

	var shadows := Node2D.new()
	shadows.z_index = -6
	_add(root, shadows, root, "CastShadows")
	var marks := Node2D.new()
	marks.z_index = -5
	_add(root, marks, root, "SurfaceMarks")
	var ysort := Node2D.new()
	ysort.y_sort_enabled = true
	_add(root, ysort, root, "YSortWorld")
	for e in LAYOUT["YSortWorld"]:
		_add(ysort, _inst(e[0], e[2], e[3]), root, e[1])

	# Units: copy every exported stat from the desert map so the encounter numbers stay identical.
	for uname in UNIT_SPOTS:
		var src := desert.get_node("YSortWorld/" + uname)
		var u := Node2D.new()
		u.set_script(UNIT_SCRIPT)
		for prop in src.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and prop["usage"] & PROPERTY_USAGE_STORAGE:
				u.set(prop["name"], src.get(prop["name"]))
		u.position = UNIT_SPOTS[uname]
		_add(ysort, u, root, uname)

	_add(root, Node2D.new(), root, "CombatFx")
	_add(root, Node2D.new(), root, "SelectionOverlay")
	var grid := Node2D.new()
	grid.set_script(GRID_SCRIPT)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0])
	grad.colors = PackedColorArray([Color.BLACK])
	var mask := GradientTexture2D.new()
	mask.gradient = grad
	mask.width = 44
	mask.height = 28
	grid.set("blocked_cells", mask)
	_add(root, grid, root, "Grid")
	var cam := Camera2D.new()
	cam.position = VIEWS["1_Opening"]
	_add(root, cam, root, "Camera")
	var hud := CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	_add(root, hud, root, "Hud")
	var views := _add(root, Node2D.new(), root, "CameraViews")
	for k in VIEWS:
		var m := Marker2D.new()
		m.position = VIEWS[k]
		_add(views, m, root, k)

	var ps := PackedScene.new()
	_ok(ps.pack(root), "pack mission")
	_ok(ResourceSaver.save(ps, MISSION_PATH), MISSION_PATH)
	root.free()
	desert.free()


func _ok(err: int, what: String) -> void:
	if err != OK:
		push_error("Failed: %s (%d)" % [what, err])
