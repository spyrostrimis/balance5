extends SceneTree
## Checks and captures for RTS Mission 1 – Forest (Blue's first mission), built from the forest kit.
##
## Headless (kit integrity, kit-only placements, blocked ground vs pieces, lane widths, tank and squad
## routes, ford/bridge/river, canopy fade, minimap colours, Mend, hold, reset, catalog + Esc):
##   Godot_console.exe --headless --path . --script res://tests/test_rts_mission_1_forest.gd
## Windowed at 1920x1080 fullscreen Forward+ (adds HUD styles, captures and the clip):
##   Godot_console.exe --path . --rendering-method forward_plus --fullscreen --script res://tests/test_rts_mission_1_forest.gd -- --capture --record
##   --capture  stills: opening, lanes, ford, Blue base, plaza fight, Pixel, F1, HUD styles, kit pages
##   --record   12 s moving sequence, frames to tmp/rts_mission_1_forest/frames (encode with ffmpeg)

const SCENE_PATH := "res://scenes/maps/rts_mission_1_forest.tscn"
const DESERT_PATH := "res://scenes/maps/rts_mission_1_desert.tscn"
const KIT_PATH := "res://scenes/rts/forest_kit/kit_preview.tscn"
const PIECES_DIR := "res://scenes/rts/forest_kit/pieces/"
const GROUPS_DIR := "res://scenes/rts/forest_kit/groups/"
const KIT_ART := "res://assets/textures/rts/forest_kit/"
const DESERT_PIECES := "res://scenes/rts/desert_kit/pieces/"
const OPENING_PATH := "res://scenes/ui/opening_screen.tscn"
const CAP_DIR := "res://render_captures/rts_mission_1_forest/"
const FRAME_DIR := "res://tmp/rts_mission_1_forest/frames/"
const UNIT_NAMES := ["BlueTank", "BlueCommander", "BlueSquad1", "BlueSquad2", "BlueSquad3",
	"RedSquad1", "RedCommander", "RedSquad2", "RedTank", "RedSquad3"]

## Lanes the brief asks for, as waypoints in world pixels. Main lanes must carry a 4-cell-wide
## corridor end to end; tank routes a 3-cell-wide one.
const LANES := {
	"main_road": [Vector2(500, 700), Vector2(600, 584), Vector2(860, 380), Vector2(1100, 360), Vector2(1330, 380)],
	"north_lane": [Vector2(440, 470), Vector2(520, 300), Vector2(780, 280), Vector2(1060, 300), Vector2(1200, 400)],
	"south_lane": [Vector2(500, 720), Vector2(660, 690), Vector2(880, 660), Vector2(1110, 660), Vector2(1140, 470)],
}
const TANK_ROUTES := {
	"base_to_plaza": [Vector2(452, 600), Vector2(600, 540)],
	"red_road_to_plaza": [Vector2(1220, 380), Vector2(880, 380), Vector2(800, 520)],
	"red_to_gravel_field": [Vector2(1180, 420), Vector2(1140, 640), Vector2(1140, 760)],
	"base_to_ford_meadow": [Vector2(452, 470), Vector2(380, 270), Vector2(250, 90)],
}
const MEADOW := Vector2(250, 84)  # beyond the river

var _failures: Array[String] = []
var _mission_done := false  # a script error aborts a coroutine silently; this catches it


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("FAIL: ", msg)
	else:
		print("ok   ", msg)


func _advance_sim(map: RtsCarbonBattlefield, seconds: float, step := 1.0 / 60.0) -> void:
	for _i in range(int(round(seconds / step))):
		for u in map.get_living_units():
			u.tick(step)
		map._process(step)


func _save_still(stem: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAP_DIR))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	_check(img.save_png(ProjectSettings.globalize_path(CAP_DIR + stem + ".png")) == OK, "Saved " + stem + ".png")
	print("CAPTURE ", stem, ".png -> ", img.get_size())


func _load_map(path: String) -> RtsCarbonBattlefield:
	var map := (load(path) as PackedScene).instantiate() as RtsCarbonBattlefield
	root.add_child(map)
	await process_frame
	await process_frame
	for u in map.get_living_units():
		u.set_physics_process(false)
		u.peaceful = true
	return map


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var capture := "--capture" in args
	await _verify_catalog_and_esc()
	_verify_kit_files()
	await _verify_kit_preview(capture)
	await _verify_mission(capture)
	_check(_mission_done, "Mission checks ran to the end")
	if "--record" in args:
		await _record_moving_sequence()
	_finish()


# --- Kit ------------------------------------------------------------------------------------------

func _verify_kit_files() -> void:
	var count := 0
	for f in DirAccess.get_files_at(PIECES_DIR):
		f = f.trim_suffix(".remap")
		if not f.ends_with(".tscn"):
			continue
		count += 1
		var p := (load(PIECES_DIR + f) as PackedScene).instantiate() as RtsCarbonPiece
		_check(p != null, "Forest piece %s is an RtsCarbonPiece" % f)
		if p == null:
			continue
		_check(p.piece_id == f.get_basename(), "%s piece_id matches its file name" % f)
		_check(p.detailed_texture_override != null and p.pixel_texture_override != null, "%s has Detailed and Pixel art" % f)
		var tags := PackedStringArray(p.get_meta("tags", PackedStringArray()))
		_check(tags.has("forest") and tags.size() >= 2, "%s is tagged for the Kit Palette (%s)" % [f, ", ".join(tags)])
		p.free()
	_check(count >= 20, "Forest kit has one scene per painted piece (%d)" % count)
	for g in ["woodland_copse", "forest_corner", "mossy_cover"]:
		_check(ResourceLoader.exists(GROUPS_DIR + g + ".tscn"), "Forest kit group %s exists" % g)
	for key in ["sand_tile", "road_strip"]:
		_check(ResourceLoader.exists(KIT_ART + key + "_hd.png") and ResourceLoader.exists(KIT_ART + key + "_pixel.png"),
			"Forest ground art %s (Detailed and Pixel)" % key)
	var dock := load("res://addons/balance_kit_palette/kit_palette_dock.gd") as Script
	var folders: Array = dock.get_script_constant_map().get("FOLDERS", [])
	_check(folders.has(PIECES_DIR.trim_suffix("/")) and folders.has(GROUPS_DIR.trim_suffix("/")),
		"Kit Palette dock lists the forest kit folders")


func _verify_kit_preview(capture: bool) -> void:
	var kit := (load(KIT_PATH) as PackedScene).instantiate() as Node2D
	root.add_child(kit)
	await process_frame
	await process_frame
	_check(kit.has_node("GroundDecals/River") and kit.has_node("GroundDecals/RiverFord") and kit.has_node("GroundDecals/RiverBridge"),
		"Kit preview shows the river with a ford and a bridge")
	_check(kit.has_node("YSortWorld/WoodlandCopse") and kit.has_node("YSortWorld/ForestCorner") and kit.has_node("YSortWorld/MossyCover"),
		"Kit preview shows the three forest groups")
	_check(kit.get_node("Palette").get_child_count() >= 20, "Kit preview palette shows every forest piece")
	if capture:
		await _save_still("kit_1_arrangements_hd")
		kit.call("show_page", 1)
		await _save_still("kit_2_pieces_hd")
		kit.call("apply_visual_mode", true)
		kit.call("show_page", 0)
		await _save_still("kit_1_arrangements_pixel")
	kit.queue_free()
	await process_frame


# --- Mission --------------------------------------------------------------------------------------

func _kit_only(n: Node, map: Node, out: Array[String]) -> void:
	for c in n.get_children():
		if c is RtsCarbonPiece:
			var src := c.scene_file_path
			if src.is_empty() and c.owner != map:
				src = c.owner.scene_file_path
			if not (src.begins_with(PIECES_DIR) or src.begins_with(GROUPS_DIR) or src.begins_with(DESERT_PIECES)):
				out.append(String(map.get_path_to(c)))
		_kit_only(c, map, out)


func _pieces(map: RtsCarbonBattlefield) -> Array[RtsCarbonPiece]:
	var out: Array[RtsCarbonPiece] = []
	for n in map.find_children("*", "Node2D", true, false):
		if n is RtsCarbonPiece:
			out.append(n)
	return out


func _in_world(p: Vector2) -> bool:
	return p.x > 0.0 and p.y > 0.0 and p.x < 1408.0 and p.y < 896.0


func _verify_mission(capture: bool) -> void:
	var map := await _load_map(SCENE_PATH)
	var grid := map.grid
	_check(map is RtsMissionBattlefield, "Forest mission uses RtsMissionBattlefield")
	var loose: Array[String] = []
	_kit_only(map, map, loose)
	_check(loose.is_empty(), "Every placed piece comes from a kit (%s)" % ", ".join(loose))
	_check(map.get("pixel_ground_from_kit") == true and map._sand_px.resource_path.begins_with(KIT_ART),
		"Pixel view uses the forest's own grass (%s)" % map._sand_px.resource_path)
	_check(map._sand_hd.resource_path.begins_with(KIT_ART) and map._road_hd.resource_path.begins_with(KIT_ART),
		"Detailed ground and road come from the forest kit")
	_check(map.get_living_units().size() == UNIT_NAMES.size(), "Ten forces on the field")

	# Same forces and numbers as the desert map.
	var desert := (load(DESERT_PATH) as PackedScene).instantiate()
	var same := true
	for uname in UNIT_NAMES:
		var a := map.get_node("YSortWorld/" + uname)
		var b := desert.get_node("YSortWorld/" + uname)
		for prop in ["team", "role", "max_health", "attack_damage", "armour", "attack_range_cells",
				"guard_range_cells", "attack_cooldown", "speed_px", "sprite_key", "display_name"]:
			if a.get(prop) != b.get(prop):
				same = false
				printerr("  %s.%s differs: %s vs %s" % [uname, prop, a.get(prop), b.get(prop)])
	desert.free()
	_check(same, "Forest forces keep the desert map's encounter numbers")
	for u in map.get_living_units():
		_check(grid.is_walkable(grid.cell_of(u.position)), "%s starts on open ground" % u.name)

	# Blocked ground agrees with the visible pieces.
	var masses := 0
	var mass_ok := true
	for p in _pieces(map):
		if p.canopy_fade and p.blocked_poly.size() >= 3 and p.piece_id.begins_with("tree_cluster"):
			var core := p.to_global(p.draw_offset)
			if _in_world(core):
				masses += 1
				if grid.is_walkable(grid.cell_of(core)):
					mass_ok = false
					printerr("  %s core is walkable" % p.name)
	_check(masses >= 10 and mass_ok, "Every tree mass blocks its trunks' core (%d masses)" % masses)
	var cluster := map.get_node("YSortWorld/NorthForest") as RtsCarbonPiece
	var overhang := cluster.global_position + Vector2(0, 12)
	_check(grid.is_walkable(grid.cell_of(overhang)) and cluster.texture != null,
		"The canopy overhangs open ground south of the trunks")
	_check(not grid.is_walkable(grid.cell_of(Vector2(704, 444))), "Central Orichalcum blocks its cells")
	_check(not grid.is_walkable(grid.cell_of(Vector2(250, 590))), "Blue Field HQ blocks its footprint")

	# River: water blocks, banks are open, the ford and bridge cross it.
	var river := map.get_node("GroundDecals/River") as RtsKitRiver
	var course := river.course()
	_check(course.width >= river.water_half_width * 2.0 + 24.0, "River strip is wider than its blocked water (banks stay walkable)")
	var ford := map.get_node("GroundDecals/RiverFord") as RtsCarbonPiece
	var bridge := map.get_node("GroundDecals/RiverBridge") as RtsCarbonPiece
	var water_blocked := true
	var samples := 0
	for i in range(course.get_point_count() - 1):
		var a := course.to_global(course.get_point_position(i))
		var b := course.to_global(course.get_point_position(i + 1))
		for k in range(0, 16):
			var pt := a.lerp(b, float(k) / 16.0)
			if not _in_world(pt) or ford.blocks_world_point(pt) or bridge.blocks_world_point(pt):
				continue
			if ford.global_position.distance_to(pt) < 120.0 or bridge.global_position.distance_to(pt) < 110.0:
				continue
			samples += 1
			if grid.is_walkable(grid.cell_of(pt)):
				water_blocked = false
				printerr("  river open at %s" % str(pt.round()))
	_check(samples > 12 and water_blocked, "Water blocks all along the river away from the crossings (%d samples)" % samples)
	var seg_a := course.to_global(course.get_point_position(4))
	var seg_b := course.to_global(course.get_point_position(5))
	var mid := seg_a.lerp(seg_b, 0.25)
	var normal := (seg_b - seg_a).normalized().orthogonal()
	_check(grid.is_walkable(grid.cell_of(mid + normal * (river.water_half_width + 22.0)))
		and grid.is_walkable(grid.cell_of(mid - normal * (river.water_half_width + 22.0))),
		"River banks beside the water are walkable on both sides")
	_check(grid.is_walkable(grid.cell_of(ford.global_position)) and grid.is_walkable(grid.cell_of(bridge.global_position)),
		"Ford and bridge reopen the water under them")
	_check(not grid.find_path(grid.cell_of(Vector2(452, 470)), grid.cell_of(MEADOW)).is_empty(), "The meadow beyond the river is reachable")
	_check(_corridor(grid, [Vector2(420, 330), ford.global_position, MEADOW], 3), "Ford carries a 3-cell tank route")
	var ford_pos := ford.position
	var bridge_pos := bridge.position
	ford.position = Vector2(-600, -600)
	map.call("rebuild_navigation_and_minimap")
	_check(not grid.find_path(grid.cell_of(Vector2(452, 470)), grid.cell_of(MEADOW)).is_empty(),
		"With the ford gone, infantry still cross by the bridge")
	_check(not _corridor(grid, [Vector2(420, 330), MEADOW], 3, 3.0), "Without the ford, no 3-cell route crosses the river")
	bridge.position = Vector2(-600, -400)
	map.call("rebuild_navigation_and_minimap")
	_check(grid.find_path(grid.cell_of(Vector2(452, 470)), grid.cell_of(MEADOW)).is_empty(),
		"Without ford and bridge the river cuts the meadow off")
	ford.position = ford_pos
	bridge.position = bridge_pos
	map.call("rebuild_navigation_and_minimap")
	_check(not grid.find_path(grid.cell_of(Vector2(452, 470)), grid.cell_of(MEADOW)).is_empty(), "Restored crossings reopen the meadow")

	# Lanes: room to manoeuvre.
	for lane in LANES:
		_check(_corridor(grid, LANES[lane], 4), "Lane %s carries a 4-cell-wide corridor" % lane)
	for route in TANK_ROUTES:
		_check(_corridor(grid, TANK_ROUTES[route], 3), "Tank route %s is at least 3 cells wide" % route)
	var plaza_room := 0
	for cy in 28:
		for cx in 44:
			var c := Vector2i(cx, cy)
			if grid.is_walkable(c) and grid.center_of(c).distance_to(Vector2(704, 448)) < 224.0:
				plaza_room += 1
	_check(plaza_room >= 120, "Central clearing has room for both forces (%d open cells within 7 cells of the rock)" % plaza_room)

	# Minimap: forests dark green, water blue, the clearing dirt.
	var mm: Image = map.hud.minimap_tex.get_image()
	var mmc := func(w: Vector2) -> Color: return mm.get_pixel(int(w.x / 1408.0 * mm.get_width()), int(w.y / 896.0 * mm.get_height()))
	var tree_c: Color = mmc.call(cluster.to_global(cluster.draw_offset))
	var water_c: Color = mmc.call(course.to_global(course.get_point_position(1)))
	var dirt_c: Color = mmc.call(Vector2(704, 560))
	_check(tree_c.g > tree_c.r and tree_c.get_luminance() < 0.3, "Minimap shows forest as dark green (%s)" % str(tree_c))
	_check(water_c.b > water_c.r and water_c.b > water_c.g, "Minimap shows the river as blue (%s)" % str(water_c))
	_check(dirt_c.r > dirt_c.g and dirt_c.r > dirt_c.b, "Minimap shows the clearing as dirt (%s)" % str(dirt_c))

	map.close_zoom = false
	map.apply_zoom_framing()
	var frame_w: float = map.hud.call("framing_width") if map.hud.has_method("framing_width") else map.hud.playable_screen_rect().size.x
	_check(absf(map.camera.zoom.x - frame_w / (21.0 * 32.0)) < 0.001, "Command zoom keeps Carbon's 21-cell scale (zoom %.3f)" % map.camera.zoom.x)

	if capture:
		await _capture_views(map)
	if DisplayServer.get_name() != "headless":
		await _verify_hud_styles(map, capture)

	await _drive_routes(map)
	await _verify_canopy_mend_hold(map, capture)

	map.reset_encounter()
	await process_frame
	_check(map.get_living_units().size() == UNIT_NAMES.size(), "Reset restores all ten forces")
	_mission_done = true
	map.queue_free()
	await process_frame


## True when a disc `diameter` cells wide can travel through each leg of `points` on open ground.
## Even diameters ride on cell corners, odd ones on cell centres. Each leg may be at most
## `max_ratio` times longer than the straight line, so a detour round the map does not count.
func _corridor(grid: RtsGrid, points: Array, diameter: int, max_ratio := 1.8) -> bool:
	var even := diameter % 2 == 0
	var r := float(diameter) * 0.5
	var nw := 45 if even else 44
	var nh := 29 if even else 28
	var free := {}
	for ny in nh:
		for nx in nw:
			var centre := Vector2(nx, ny) if even else Vector2(nx + 0.5, ny + 0.5)
			var ok := true
			for oy in range(-3, 4):
				for ox in range(-3, 4):
					var cell := Vector2i(int(floor(centre.x)) + ox, int(floor(centre.y)) + oy)
					if Vector2(cell) + Vector2(0.5, 0.5) == centre or (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(centre) < r:
						if not (grid.in_bounds(cell) and grid.is_walkable(cell)):
							ok = false
			if ok:
				free[Vector2i(nx, ny)] = true
	var to_node := func(w: Vector2) -> Vector2i:
		var c := w / 32.0
		return Vector2i(roundi(c.x), roundi(c.y)) if even else Vector2i(floori(c.x), floori(c.y))
	for i in range(points.size() - 1):
		var a: Vector2i = to_node.call(points[i])
		var b: Vector2i = to_node.call(points[i + 1])
		a = _nearest_free(free, a)
		b = _nearest_free(free, b)
		if a.x < -100 or b.x < -100:
			printerr("  no %d-cell room at %s or %s" % [diameter, str(points[i]), str(points[i + 1])])
			return false
		var steps := _bfs(free, a, b)
		var straight := Vector2(a).distance_to(Vector2(b))
		if steps < 0 or float(steps) > maxf(straight * max_ratio, straight + 4.0):
			printerr("  %d-cell corridor fails between %s and %s (steps %d, straight %.1f)" % [diameter, str(points[i]), str(points[i + 1]), steps, straight])
			return false
	return true


func _nearest_free(free: Dictionary, n: Vector2i) -> Vector2i:
	if free.has(n):
		return n
	for ring in range(1, 3):
		for oy in range(-ring, ring + 1):
			for ox in range(-ring, ring + 1):
				if free.has(n + Vector2i(ox, oy)):
					return n + Vector2i(ox, oy)
	return Vector2i(-999, -999)


func _bfs(free: Dictionary, a: Vector2i, b: Vector2i) -> int:
	var dist := {a: 0}
	var queue: Array[Vector2i] = [a]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		if c == b:
			return dist[c]
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var n := c + Vector2i(ox, oy)
				if (ox != 0 or oy != 0) and free.has(n) and not dist.has(n):
					dist[n] = dist[c] + 1
					queue.append(n)
	return -1


## Drive a unit through waypoints; true when it reaches every one in time.
func _drive(map: RtsCarbonBattlefield, unit: RtsCarbonUnit, pts: Array, seconds_per_leg := 16.0) -> bool:
	for p in pts:
		unit.command_move(p)
		var t := 0.0
		while t < seconds_per_leg and unit.position.distance_to(p) > 40.0:
			_advance_sim(map, 0.25, 1.0 / 30.0)
			t += 0.25
		if unit.position.distance_to(p) > 40.0:
			printerr("  %s stuck at %s heading for %s" % [unit.name, str(unit.position.round()), str(p)])
			return false
	return true


func _drive_routes(map: RtsCarbonBattlefield) -> void:
	var saved := {}
	for u in map.get_living_units():
		saved[u] = u.position
	var tank := map.get_node("YSortWorld/BlueTank") as RtsCarbonUnit
	var squad := map.get_node("YSortWorld/BlueSquad1") as RtsCarbonUnit
	var red_tank := map.get_node("YSortWorld/RedTank") as RtsCarbonUnit
	for lane in LANES:
		var pts: Array = LANES[lane]
		tank.position = pts[0]
		tank.command_stop()
		_check(_drive(map, tank, pts.slice(1)), "Blue tank drives the %s" % lane)
		squad.position = pts[0] + Vector2(0, 40)
		squad.command_stop()
		_check(_drive(map, squad, pts.slice(1)), "Blue squad walks the %s" % lane)
	tank.position = Vector2(452, 470)
	tank.command_stop()
	_check(_drive(map, tank, [Vector2(380, 280), ford_point(map), MEADOW]), "Blue tank crosses the river at the ford")
	var bridge := map.get_node("GroundDecals/RiverBridge") as Node2D
	var across := Vector2.from_angle(bridge.rotation).orthogonal()  # points to the meadow side
	squad.position = bridge.position - across * 110.0
	squad.command_stop()
	_check(_drive(map, squad, [bridge.position - across * 60.0, bridge.position, bridge.position + across * 70.0, MEADOW]),
		"Blue squad crosses the bridge to the meadow")
	red_tank.position = Vector2(1220, 380)
	red_tank.command_stop()
	_check(_drive(map, red_tank, TANK_ROUTES["red_road_to_plaza"].slice(1)), "Red tank drives its road to the plaza")
	for u in saved:
		u.command_stop()
		u.position = saved[u]


func ford_point(map: RtsCarbonBattlefield) -> Vector2:
	return (map.get_node("GroundDecals/RiverFord") as Node2D).position


func _verify_canopy_mend_hold(map: RtsCarbonBattlefield, capture: bool) -> void:
	for u in map.get_living_units():
		u.set_physics_process(false)
		u.peaceful = true
	var sq3 := map.get_node("YSortWorld/BlueSquad3") as RtsCarbonUnit
	var cluster := map.get_node("YSortWorld/NorthForest") as RtsCarbonPiece
	# Stand the squad on the nearest open cell beneath the crown, north of the trunks' line.
	var grid := map.grid
	var best := INF
	var under := cluster.global_position
	for oy in range(-200, 0, 8):
		for ox in range(-150, 151, 8):
			var pt := cluster.global_position + Vector2(ox, oy)
			var local := cluster.to_local(pt) - cluster.draw_offset
			var inside := absf(local.x) < cluster.world_size.x * 0.42 and absf(local.y) < cluster.world_size.y * 0.42
			if inside and grid.is_walkable(grid.cell_of(pt)) and pt.y > 4.0 and Vector2(ox, oy).length() < best:
				best = Vector2(ox, oy).length()
				under = grid.center_of(grid.cell_of(pt))
	sq3.position = under
	sq3.command_stop()
	map.set_selection([sq3])
	_advance_sim(map, 1.2)
	_check(cluster.modulate.a < 0.6, "Forest crown fades over a selected squad beneath it (alpha=%.2f at %s)" % [cluster.modulate.a, str(under)])
	map.set_selection([])
	_advance_sim(map, 1.0)
	_check(cluster.modulate.a > 0.95, "Crown returns once the squad is deselected")

	var sq1 := map.get_node("YSortWorld/BlueSquad1") as RtsCarbonUnit
	var red_sq1 := map.get_node("YSortWorld/RedSquad1") as RtsCarbonUnit
	var cmd := map.get_node("YSortWorld/BlueCommander") as RtsCarbonUnit
	sq1.take_damage(36, red_sq1)
	_check(sq1.fit_count() == 3, "Wounded squad drops to 3 of 4")
	cmd.position = sq1.position + Vector2(28, 0)
	cmd.cast_mend()
	_check(sq1.fit_count() == 4, "Mend restores the squad to 4 of 4")

	# Hold: Blue alone at the rock runs the timer down.
	for u in map.get_living_units():
		if u.team == RtsCarbonUnit.Team.RED:
			u.position = Vector2(1330, 420) + Vector2(randf_range(-20, 20), randf_range(-60, 60))
			u.command_stop()
	sq1.position = Vector2(704, 540)
	sq1.command_stop()
	map.hold_seconds_left = RtsCarbonBattlefield.HOLD_DURATION
	map.hold_owner = 0
	_advance_sim(map, 2.0)
	_check(map.hold_owner == 1 and map.hold_seconds_left < RtsCarbonBattlefield.HOLD_DURATION - 1.5,
		"Blue holds the plaza and the timer runs (%.1f s left, %s)" % [map.hold_seconds_left, map.hud.hold_state])

	if capture:
		# Plaza fight: both sides meet at the rock (units by name, so no reset_encounter here).
		for u in map.get_living_units():
			u.heal(999)
		var spots := {
			"BlueSquad1": Vector2(596, 548), "BlueSquad2": Vector2(620, 610), "BlueSquad3": Vector2(660, 566),
			"BlueCommander": Vector2(572, 600), "BlueTank": Vector2(548, 648),
			"RedSquad1": Vector2(780, 560), "RedSquad2": Vector2(800, 624), "RedSquad3": Vector2(756, 606),
			"RedCommander": Vector2(836, 592), "RedTank": Vector2(866, 640),
		}
		for n in spots:
			var u := map.get_node("YSortWorld/" + n) as RtsCarbonUnit
			u.position = spots[n]
			u.peaceful = false
			u.set_physics_process(false)
			u.command_stop()
		map.set_selection([])
		map.set_camera_focus(Vector2(704, 540))
		_advance_sim(map, 1.6)
		await _save_still("06_plaza_fight_hd")


func _capture_views(map: RtsCarbonBattlefield) -> void:
	map.set_selection([])
	map.call("focus_view", 0)
	await _save_still("01_opening_command_hd")
	map.apply_visual_mode(true)
	await _save_still("01_opening_command_pixel")
	map.apply_visual_mode(false)
	map.grid.show_debug = true
	await _save_still("01_opening_f1_blocked")
	map.grid.show_debug = false
	var views := {1: "02_river_ford_hd", 2: "03_north_lane_hd", 3: "04_south_lane_hd", 4: "05_blue_base_hd", 5: "07_gravel_field_hd", 6: "08_red_road_hd"}
	for i in views:
		map.call("focus_view", i)
		await _save_still(views[i])
	map.call("focus_view", 1)
	map.grid.show_debug = true
	await _save_still("02_river_ford_f1_blocked")
	map.grid.show_debug = false
	map.close_zoom = true
	map.apply_zoom_framing()
	map.call("focus_view", 1)
	await _save_still("02b_river_ford_close_hd")
	map.close_zoom = false
	map.apply_zoom_framing()


# --- HUD styles ------------------------------------------------------------------------------------

func _click_hud(map: RtsCarbonBattlefield, virtual_pt: Vector2) -> void:
	var hud := map.hud
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = virtual_pt * hud.ui_scale()
		hud._on_panel_gui_input(mb)


func _verify_hud_styles(map: RtsCarbonBattlefield, capture: bool) -> void:
	var hud := map.hud as RtsMissionHud
	_check(hud != null, "Forest mission uses the switchable RtsMissionHud")
	if hud == null:
		return
	var commander := map.get_node("YSortWorld/BlueCommander") as RtsCarbonUnit
	var zoom_ref := -1.0
	for st in RtsMissionHud.STYLES:
		map.call("set_hud_style", st)
		map.set_selection([commander])
		map.call("focus_view", 0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		if zoom_ref < 0.0:
			zoom_ref = map.camera.zoom.x
		_check(absf(map.camera.zoom.x - zoom_ref) < 0.001, "%s HUD keeps the same battlefield scale" % st)
		_check(hud._btn_rects.has("cmd_move") and hud._btn_rects.has("cmd_mend"), "%s HUD draws the four command buttons" % st)
		if hud._btn_rects.has("cmd_attack"):
			hud.command_cursor_mode = ""
			_click_hud(map, (hud._btn_rects["cmd_attack"] as Rect2).get_center())
			_check(hud.command_cursor_mode == "attack", "%s HUD: clicking Attack arms an attack order" % st)
			hud.command_cursor_mode = ""
		var before := map.hud.camera_world_rect.get_center()
		_click_hud(map, hud._minimap_rect.position + hud._minimap_rect.size * Vector2(0.85, 0.2))
		_check(map.hud.camera_world_rect.get_center().distance_to(before) > 60.0, "%s HUD: clicking the minimap pans the camera" % st)
		map.call("focus_view", 0)
		var centre := map.get_viewport().get_visible_rect().size * 0.5
		_check(not hud.consumes_screen_point(centre), "%s HUD leaves the battlefield centre clickable" % st)
		if capture:
			await process_frame
			await _save_still("09_hud_%s_hd" % st)
	map.call("set_hud_style", "mockup_e")
	map.set_selection([])


# --- Moving sequence ------------------------------------------------------------------------------

func _record_moving_sequence() -> void:
	var abs_frames := ProjectSettings.globalize_path(FRAME_DIR)
	DirAccess.make_dir_recursive_absolute(abs_frames)
	for f in DirAccess.get_files_at(abs_frames):
		DirAccess.remove_absolute(abs_frames.path_join(f))
	var map := await _load_map(SCENE_PATH)
	var n := func(name: String) -> RtsCarbonUnit: return map.get_node("YSortWorld/" + name) as RtsCarbonUnit
	map.close_zoom = false
	map.apply_zoom_framing()
	map.set_selection([])
	# Blue advances from its base on the road and the north lane; Red comes down its road.
	n.call("BlueTank").command_move(Vector2(700, 580))
	n.call("BlueCommander").command_move(Vector2(640, 560))
	n.call("BlueSquad1").command_move(Vector2(620, 620))
	n.call("BlueSquad2").command_move(Vector2(560, 320))
	n.call("BlueSquad3").command_move(Vector2(660, 330))
	n.call("RedSquad1").command_move(Vector2(830, 380))
	n.call("RedCommander").command_move(Vector2(860, 450))
	n.call("RedSquad2").command_move(Vector2(880, 540))
	n.call("RedTank").command_move(Vector2(900, 380))
	n.call("RedSquad3").command_move(Vector2(840, 300))
	for f in range(360):
		var cam := Vector2(520, 540).lerp(Vector2(780, 440), smoothstep(30.0, 300.0, float(f)))
		map.set_camera_focus(cam)
		_advance_sim(map, 1.0 / 30.0, 1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_jpg(abs_frames.path_join("%05d.jpg" % f), 0.94)
	print("RECORDED 360 frames to ", abs_frames)
	map.queue_free()
	await process_frame


# --- Developers Page ------------------------------------------------------------------------------

func _verify_catalog_and_esc() -> void:
	if root.get_node_or_null("BuildLauncher") == null:
		var bl := (load("res://scenes/ui/build_launcher.tscn") as PackedScene).instantiate()
		bl.name = "BuildLauncher"
		root.add_child(bl)
		await process_frame
	_check(change_scene_to_file(OPENING_PATH) == OK, "Developers Page is available")
	await scene_changed
	await process_frame
	current_scene.get_node("%DevelopersPage").pressed.emit()
	await process_frame
	for path in [SCENE_PATH, KIT_PATH]:
		var card_button: Button = null
		var section_name := ""
		for section in current_scene.get_node("%Catalog").get_children():
			for card in section.get_children():
				if card.get_meta("catalog_key", "") == path:
					section_name = String(section.get_meta("section", section.name))
					for button in card.find_children("*", "Button", true, false):
						if button.text == ("View" if path == KIT_PATH else "Play"):
							card_button = button
		_check(is_instance_valid(card_button), "Developers Page card for " + path.get_file())
		if not is_instance_valid(card_button):
			continue
		card_button.pressed.emit()
		await scene_changed
		await process_frame
		_check(current_scene != null and current_scene.scene_file_path == path, "Card launched " + path.get_file())
		var esc := InputEventKey.new()
		esc.pressed = true
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		Input.parse_input_event(esc)
		await scene_changed
		await process_frame
		_check(current_scene != null and current_scene.get_node("%Library").visible, "Esc returned from " + path.get_file())
	if current_scene != null:
		current_scene.queue_free()
		await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("ALL RTS MISSION 1 FOREST CHECKS PASSED")
		quit(0)
	else:
		printerr("RTS MISSION 1 FOREST FAILED (%d): %s" % [_failures.size(), ", ".join(_failures)])
		quit(1)
