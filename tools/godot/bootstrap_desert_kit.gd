extends SceneTree
## ONE-TIME bootstrap of the shared desert kit and RTS Mission 1 from RTS Reusable 4 (+ Carbon).
## After it runs, the kit and mission scenes are hand-edited files; rerunning overwrites them, so it
## refuses without `-- --force` (tool_guard.gd).
##
##   Godot_console.exe --headless --editor --import --path .   (imports assets/textures/rts/desert_kit first)
##   Godot_console.exe --headless --path . --script res://tools/godot/bootstrap_desert_kit.gd -- --force
##
## Writes:
##   scenes/rts/desert_kit/pieces/<piece_id>.tscn   one scene per painted piece, with its textures,
##                                                  blocked footprint, shadow, lee shade and dune relief
##   scenes/rts/desert_kit/groups/*.tscn            sheltered spring, roadside pool, two Orichalcum deposits,
##                                                  each made of piece-scene instances
##   scenes/rts/desert_kit/kit_preview.tscn         arrangements page + labelled palette of every piece
##   scenes/maps/rts_mission_1.tscn                 Reusable 4's layout rebuilt from kit instances

const Guard := preload("res://tools/godot/tool_guard.gd")
const PIECE_SCRIPT := preload("res://scripts/rts_carbon/rts_carbon_piece.gd")
const MISSION_SCRIPT := preload("res://scripts/rts_kit/rts_mission_battlefield.gd")
const FORK_SCRIPT := preload("res://scripts/rts_kit/road_fork_join.gd")
const SPUR_SCRIPT := preload("res://scripts/rts_kit/road_sand_end.gd")
const PREVIEW_SCRIPT := preload("res://scripts/rts_kit/desert_kit_preview.gd")
const ROAD_FADE := preload("res://assets/shaders/rts_desert_road_fade.gdshader")

const KIT_DIR := "res://scenes/rts/desert_kit/"
const PIECES_DIR := KIT_DIR + "pieces/"
const GROUPS_DIR := KIT_DIR + "groups/"
const KIT_ART := "res://assets/textures/rts/desert_kit/"
const CARBON_ART := "res://assets/textures/rts/carbon/"
const MISSION_PATH := "res://scenes/maps/rts_mission_1.tscn"
const R4_MAP := "res://scenes/maps/rts_reusable_4.tscn"
const CARBON_MAP := "res://scenes/maps/rts_reusable_2_carbon.tscn"
const R4_GROUPS := {
	"res://scenes/rts/reusable_4/sheltered_spring.tscn": "sheltered_spring",
	"res://scenes/rts/reusable_4/roadside_pool.tscn": "roadside_pool",
	"res://scenes/rts/reusable_4/orichalcum_wide.tscn": "orichalcum_wide",
	"res://scenes/rts/reusable_4/orichalcum_tall.tscn": "orichalcum_tall",
}

## Properties that define a piece (saved in its own scene).
const PIECE_PROPS := ["piece_id", "world_size", "layer_role", "draw_offset", "blocked_poly",
	"shadow_offset", "shadow_size", "shadow_alpha", "shade_offset", "shade_radii", "shade_strength",
	"relief_height", "relief_radii", "is_orichalcum", "z_index"]
## Properties a placed instance may override (Godot only stores those that differ from the piece scene).
const INSTANCE_PROPS := ["position", "rotation", "scale", "flip_x", "modulate", "world_size", "layer_role",
	"draw_offset", "blocked_poly", "shadow_offset", "shadow_size", "shadow_alpha", "shade_offset",
	"shade_radii", "shade_strength", "relief_height", "relief_radii", "is_orichalcum", "z_index"]

var _templates := {}  # piece_id -> Dictionary of PIECE_PROPS
var _piece_scenes := {}  # piece_id -> PackedScene
var _group_scenes := {}  # R4 group path -> PackedScene


func _initialize() -> void:
	if not Guard.confirm(self, PackedStringArray([KIT_DIR, MISSION_PATH])):
		return
	for d in [PIECES_DIR, GROUPS_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))

	# Reusable 4 first so its tuned footprints win; Carbon adds the pieces R4 did not place.
	for path in [R4_MAP] + R4_GROUPS.keys() + [CARBON_MAP]:
		var inst := (load(path) as PackedScene).instantiate()
		_collect_templates(inst)
		inst.free()

	var ids := _templates.keys()
	ids.sort()
	for id in ids:
		_save_piece_scene(id)
	print("Saved %d piece scenes" % ids.size())

	for path in R4_GROUPS:
		_group_scenes[path] = _save_group(path, R4_GROUPS[path])

	_save_mission()
	_save_preview(ids)
	print("DESERT KIT BOOTSTRAP DONE")
	quit(0)


func _is_plain_piece(n: Node) -> bool:
	return n.get_script() == PIECE_SCRIPT


func _collect_templates(n: Node) -> void:
	if _is_plain_piece(n):
		var id := String(n.get("piece_id"))
		if not _templates.has(id):
			var t := {}
			for p in PIECE_PROPS:
				t[p] = n.get(p)
			_templates[id] = t
	for c in n.get_children():
		_collect_templates(c)


func _art(id: String, pixel: bool) -> Texture2D:
	var file := id + ("_pixel.png" if pixel else "_hd.png")
	for dir in [KIT_ART, CARBON_ART]:
		if ResourceLoader.exists(dir + file, "Texture2D"):
			return load(dir + file) as Texture2D
	push_warning("No art for " + file)
	return null


func _pascal(id: String) -> String:
	var out := ""
	for part in id.split("_"):
		out += part.capitalize().replace(" ", "")
	return out


func _save_piece_scene(id: String) -> void:
	var root := Node2D.new()
	root.name = _pascal(id)
	root.set_script(PIECE_SCRIPT)
	var t: Dictionary = _templates[id]
	for p in PIECE_PROPS:
		root.set(p, t[p])
	root.set("detailed_texture_override", _art(id, false))
	root.set("pixel_texture_override", _art(id, true))
	var ps := PackedScene.new()
	ps.pack(root)
	var path := PIECES_DIR + id + ".tscn"
	_check_save(ResourceSaver.save(ps, path), path)
	_piece_scenes[id] = load(path)
	root.free()


func _piece_instance(src: Node) -> Node2D:
	var id := String(src.get("piece_id"))
	var inst := (_piece_scenes[id] as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	inst.name = src.name
	for p in INSTANCE_PROPS:
		inst.set(p, src.get(p))
	return inst


func _save_group(src_path: String, file_stem: String) -> PackedScene:
	var src := (load(src_path) as PackedScene).instantiate() as Node2D
	var root := Node2D.new()
	root.name = src.name
	root.y_sort_enabled = true
	for c in src.get_children():
		if _is_plain_piece(c):
			var inst := _piece_instance(c)
			root.add_child(inst)
			inst.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	var path := GROUPS_DIR + file_stem + ".tscn"
	_check_save(ResourceSaver.save(ps, path), path)
	root.free()
	src.free()
	return load(path) as PackedScene


func _replace(old: Node, replacement: Node, owner_root: Node) -> void:
	var parent := old.get_parent()
	var idx := old.get_index()
	replacement.name = old.name
	parent.remove_child(old)
	old.free()
	parent.add_child(replacement)
	parent.move_child(replacement, idx)
	replacement.owner = owner_root


func _convert_children(n: Node, owner_root: Node) -> void:
	for c in n.get_children():
		if c.scene_file_path in _group_scenes:
			var g := (_group_scenes[c.scene_file_path] as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
			g.position = (c as Node2D).position
			_replace(c, g, owner_root)
		elif _is_plain_piece(c):
			_replace(c, _piece_instance(c), owner_root)
		elif c.owner == owner_root:
			_convert_children(c, owner_root)


func _save_mission() -> void:
	var root := (load(R4_MAP) as PackedScene).instantiate() as Node2D
	root.scene_file_path = ""
	var spacing: float = root.get("visual_squad_spacing")
	root.set_script(MISSION_SCRIPT)
	root.name = "RtsMission1"
	root.set("detailed_art_directory", KIT_ART.trim_suffix("/"))
	root.set("art_directory_has_painted_sand", false)
	root.set("visual_squad_spacing", spacing)
	root.set_meta("owns_catalog_button", true)

	_convert_children(root, root)

	# Road helpers move to the shared kit scripts.
	var fork := root.get_node("GroundDecals/RoadForkJoin")
	var fork_props := {}
	for p in PIECE_PROPS + ["position", "rotation", "spur_path", "throat_offset"]:
		fork_props[p] = fork.get(p)
	fork.set_script(FORK_SCRIPT)
	for p in fork_props:
		fork.set(p, fork_props[p])
	fork.set("detailed_texture_override", _art("road_join_patch", false))
	fork.set("pixel_texture_override", _art("road_join_patch", true))

	var spur := root.get_node("RoadNetwork/RoadsideSpur") as Line2D
	var cap_path: NodePath = spur.get("end_cap_path")
	var old_mat := spur.material as ShaderMaterial
	spur.set_script(SPUR_SCRIPT)
	spur.set("end_cap_path", cap_path)
	var mat := ShaderMaterial.new()
	mat.shader = ROAD_FADE
	for param in ["end_point", "end_direction", "fade_length", "sand_tint"]:
		mat.set_shader_parameter(param, old_mat.get_shader_parameter(param))
	spur.material = mat

	# Camera views (keys 1-4). The first one is the opening frame.
	var views := Node2D.new()
	views.name = "CameraViews"
	root.add_child(views)
	views.owner = root
	var spring := root.get_node("YSortWorld/ShelteredSpring") as Node2D
	var pool := root.get_node("YSortWorld/RoadsidePool") as Node2D
	var spots := {
		"1_Opening": Vector2(520, 418),
		"2_ShelteredSpring": spring.position + Vector2(16, 36),
		"3_RoadsidePool": pool.position + Vector2(-96, -56),
		"4_ForkedDunes": Vector2(384, 648),
	}
	for key in spots:
		var m := Marker2D.new()
		m.name = key
		m.position = spots[key]
		views.add_child(m)
		m.owner = root

	var ps := PackedScene.new()
	_check_save(ps.pack(root), "pack mission")
	_check_save(ResourceSaver.save(ps, MISSION_PATH), MISSION_PATH)
	root.free()


func _label(text: String, pos: Vector2, width: float, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.z_index = 4
	l.position = pos - Vector2(width * 0.5, 0)
	l.size = Vector2(width, size + 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(1, 0.91, 0.72))
	l.add_theme_color_override("font_outline_color", Color(0.18, 0.09, 0.04))
	l.add_theme_constant_override("outline_size", 6 if size > 13 else 4)
	l.add_theme_font_size_override("font_size", size)
	return l


func _add(parent: Node, child: Node, owner_root: Node) -> void:
	parent.add_child(child)
	child.owner = owner_root


func _save_preview(_ids: Array) -> void:
	var root := Node2D.new()
	root.name = "DesertKitPreview"
	root.set_script(PREVIEW_SCRIPT)

	var sand := Sprite2D.new()
	sand.name = "Sand"
	sand.z_index = -5
	sand.centered = false
	sand.position = Vector2(-832, -480)
	sand.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sand.region_enabled = true
	sand.texture = _art("sand_tile", false)
	_add(root, sand, root)
	var shadows := Node2D.new()
	shadows.name = "CastShadows"
	shadows.z_index = -3
	_add(root, shadows, root)
	var cam := Camera2D.new()
	cam.name = "Camera"
	cam.zoom = Vector2(1.49, 1.49)
	_add(root, cam, root)

	var views := Node2D.new()
	views.name = "Views"
	_add(root, views, root)
	var page_a := Marker2D.new()
	page_a.name = "Arrangements"
	page_a.set_meta("zoom", 1.49)
	_add(views, page_a, root)
	var page_b := Marker2D.new()
	page_b.name = "Pieces"
	page_b.position = Vector2(0, 896)
	page_b.set_meta("zoom", 0.88)
	_add(views, page_b, root)

	# Page 1: the four arrangements (same layout as Reusable 4's kit preview).
	var placements := {
		"res://scenes/rts/reusable_4/sheltered_spring.tscn": [Vector2(-235, -62), "Sheltered spring (cliff + modular banks)", Vector2(-234, 48)],
		"res://scenes/rts/reusable_4/roadside_pool.tscn": [Vector2(228, -46), "Roadside pool (PassCliff tank passage)", Vector2(212, 48)],
		"res://scenes/rts/reusable_4/orichalcum_wide.tscn": [Vector2(-196, 134), "Low, wide Orichalcum", Vector2(-196, 188)],
		"res://scenes/rts/reusable_4/orichalcum_tall.tscn": [Vector2(196, 134), "Compact, tall Orichalcum", Vector2(196, 188)],
	}
	for path in placements:
		var g := (_group_scenes[path] as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
		g.position = placements[path][0]
		_add(root, g, root)
		_add(root, _label(placements[path][1], placements[path][2], 400, 15), root)
	_add(root, _label("Desert Kit · arrangements (Command scale) · 2 = every piece", Vector2(0, -232), 760, 20), root)
	var hint := _label("[V] Detailed Painted  ·  [Esc] Developers Page", Vector2(0, 218), 520, 12)
	hint.name = "ModeHint"
	_add(root, hint, root)

	# Page 2: desert_kit_preview.gd fills this from scenes/rts/desert_kit/pieces/ at runtime.
	var palette := Node2D.new()
	palette.name = "Palette"
	palette.y_sort_enabled = true
	_add(root, palette, root)

	var ps := PackedScene.new()
	ps.pack(root)
	_check_save(ResourceSaver.save(ps, KIT_DIR + "kit_preview.tscn"), "kit_preview.tscn")
	root.free()


func _check_save(err: int, what: String) -> void:
	if err != OK:
		push_error("Failed to save %s (%d)" % [what, err])
