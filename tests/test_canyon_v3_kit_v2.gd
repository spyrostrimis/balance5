extends SceneTree
## Headless verification of "3D Kit Canyon · v2" (scenes/maps/canyon_v3_kit_v2.tscn):
##   1. Corridor physics walls, end caps, exit signal, and obstacle-aware navigation;
##   2. Zero debug HUD labels or mode-switching hotkeys (1-5, R, P, K, W, B, N, M);
##   3. Active 4x MSAA and >= 8x anisotropic filtering;
##   4. Unscaled 1:1 transforms across all meshes & sprites, commander pixel_size = 1/64, flat min_y >= -0.002;
##   5. Zero interpenetration / exact flush seating across cliffs, rocks, rubble, curbs, boulders, and bushes;
##   6. Developers Page catalog entry check.

const SCENE := "res://scenes/maps/canyon_v3_kit_v2.tscn"
const OPENING := "res://scenes/ui/opening_screen.tscn"
const TOLERANCE := 0.03

var _scene: Node3D
var _hero: CharacterBody3D
var _route: Node
var _exit_fired := false


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void: _fail("Timed out"))
	_run.call_deferred()


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for i in frames:
		await physics_frame
	Input.action_release(action)
	for i in 3:
		await physics_frame


func _offset() -> float:
	return _hero.global_position.x - _route.center_x(_hero.global_position.z)


func _snapshot_states(node: Node, out: Dictionary) -> void:
	if node is Node3D:
		out[node.get_instance_id()] = (node as Node3D).visible
	if node is MeshInstance3D:
		out["mat_%d" % node.get_instance_id()] = (node as MeshInstance3D).get_surface_override_material(0)
	for child in node.get_children():
		_snapshot_states(child, out)


func _run() -> void:
	_scene = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_scene)
	_hero = _scene.get_node("BlueCommander")
	_route = _scene.get_node("Route")
	_hero.reached_canyon_exit.connect(func(at_exit: bool) -> void: _exit_fired = _exit_fired or at_exit)
	for i in 25:
		await physics_frame

	# 1. Anti-aliasing active
	if root.msaa_3d != Viewport.MSAA_4X:
		return _fail("Expected MSAA_4X, got %d" % root.msaa_3d)
	if root.anisotropic_filtering_level < Viewport.ANISOTROPY_8X:
		return _fail("Expected ANISOTROPY >= 8X, got %d" % root.anisotropic_filtering_level)
	print("AA verified: MSAA_4X, Anisotropy=%d" % root.anisotropic_filtering_level)

	# 2. Zero debug HUD / zero hotkeys
	if not _scene.find_children("*", "CanvasLayer", true, false).is_empty() or not _scene.find_children("*", "Label", true, false).is_empty():
		return _fail("Found unexpected CanvasLayer or Label debug UI inside canyon_v3_kit_v2")
	var before := {}
	_snapshot_states(_scene, before)
	for key: Key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_R, KEY_P, KEY_K, KEY_W, KEY_B, KEY_N, KEY_M]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.pressed = true
		root.push_input(ev)
		await process_frame
	var after := {}
	_snapshot_states(_scene, after)
	if before != after:
		return _fail("Debug key press changed visibility or material state")
	print("Zero debug HUD and zero debug hotkeys verified.")

	# 3. Unscaled 1:1 transforms, commander pixel_size = 1/64, mesh base min_y >= -0.002, cliff surfaces == 2
	var cmd_sprite := _hero.get_node("CommanderSprite") as Sprite3D
	if absf(cmd_sprite.pixel_size - (1.0 / 64.0)) > 0.0001:
		return _fail("CommanderSprite pixel_size=%f != 1/64" % cmd_sprite.pixel_size)
	for node in _scene.find_children("*", "MeshInstance3D", true, false) + _scene.find_children("*", "Sprite3D", true, false):
		if node is Node3D and node.name != "GroundFloorMesh":
			var sc: Vector3 = (node as Node3D).scale.abs()
			if not sc.is_equal_approx(Vector3.ONE):
				return _fail("Non-unit scale on %s: %s" % [node.name, (node as Node3D).scale])
		if node is MeshInstance3D and node.name.begins_with("CliffRock_"):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			if mesh.get_surface_count() != 2:
				return _fail("%s surface count %d != 2" % [node.name, mesh.get_surface_count()])
			if mesh.get_aabb().position.y < -0.002:
				return _fail("%s mesh min_y=%.4f < 0" % [node.name, mesh.get_aabb().position.y])
	print("Unscaled 1:1 transforms and 64 texels/m geometry verified.")

	# 4. Zero interpenetration / exact fitting
	var cliffs := _scene.get_node("Cliffs")
	if cliffs.get_node_or_null("CoreLeft") == null or cliffs.get_node_or_null("CoreRight") == null:
		return _fail("Missing CoreLeft or CoreRight cliff bedrock")
	for cname in ["CoreLeft", "CoreRight"]:
		var cm := (cliffs.get_node(cname) as MeshInstance3D).mesh
		if cm.get_surface_count() != 2:
			return _fail("%s surface count %d != 2" % [cname, cm.get_surface_count()])
	if cliffs.get_placed_rocks().size() < 15 or cliffs.get_placed_rubble().size() < 5:
		return _fail("Too few cliff rocks (%d) or rubble (%d)" % [cliffs.get_placed_rocks().size(), cliffs.get_placed_rubble().size()])
	var cliff_issues: Array[String] = cliffs.audit_clearances()
	if not cliff_issues.is_empty():
		return _fail("Cliff clearance audit failed: %s" % [cliff_issues])

	var curbs_node := _scene.get_node("Curbs")
	var curbs: Array[Dictionary] = curbs_node.get_placed()
	for i in curbs.size():
		var ca := curbs[i]
		if absf(float((ca["pos"] as Vector3).y)) > 0.001:
			return _fail("Curb %s not at y=0" % ca["label"])
		for j in range(i + 1, curbs.size()):
			var cb := curbs[j]
			if ca["side"] != cb["side"]:
				continue
			if curbs_node._obb_overlap_2d(
				Vector2(ca["pos"].x, ca["pos"].z), ca["yaw"], Vector2(ca["width"] * 0.5, ca["length"] * 0.5),
				Vector2(cb["pos"].x, cb["pos"].z), cb["yaw"], Vector2(cb["width"] * 0.5, cb["length"] * 0.5),
				0.005
			):
				return _fail("Curb overlap: %s vs %s" % [ca["label"], cb["label"]])

	var boulders: Array[Dictionary] = _scene.get_placed_boulders()
	if boulders.is_empty():
		return _fail("No roadside boulders placed")
	for i in boulders.size():
		var b := boulders[i]
		var bp: Vector3 = b["pos"]
		var br: float = b["radius"]
		if absf(bp.y) > 0.001:
			return _fail("Boulder %s not at y=0" % b["label"])
		if float(b["lateral"]) - br < 1.66:
			return _fail("Boulder %s too close to curbs (inner edge %.3f)" % [b["label"], float(b["lateral"]) - br])
		var foot: float = cliffs.get_cliff_foot_lat(b["side"], b["z"])
		if float(b["lateral"]) + br > foot - 0.08:
			return _fail("Boulder %s clips cliff toe (outer=%.3f vs foot=%.3f)" % [b["label"], float(b["lateral"]) + br, foot])
		for j in range(i + 1, boulders.size()):
			var b2 := boulders[j]
			if Vector2(bp.x - b2["pos"].x, bp.z - b2["pos"].z).length() < br + float(b2["radius"]) + 0.05:
				return _fail("Boulder overlap: %s vs %s" % [b["label"], b2["label"]])

	var plants: Array[Dictionary] = _scene.get_node("Bushes").get_placed()
	if plants.is_empty():
		return _fail("No plants placed")
	for p in plants:
		var pp: Vector3 = p["pos"]
		var phw: float = p["hw"]
		for c in curbs:
			if Vector2(pp.x - c["pos"].x, pp.z - c["pos"].z).length() < phw + 0.12:
				return _fail("Plant %s overlaps curb %s" % [p["label"], c["label"]])
		for b in boulders:
			if Vector2(pp.x - b["pos"].x, pp.z - b["pos"].z).length() < phw + float(b["radius"]) + 0.04:
				return _fail("Plant %s overlaps boulder %s" % [p["label"], b["label"]])
	print("Clearance audit passed: %d curbs, %d cliff rocks, %d rubble, %d boulders, %d plants (0 overlaps)." % [
		curbs.size(), cliffs.get_placed_rocks().size(), cliffs.get_placed_rubble().size(), boulders.size(), plants.size()
	])

	# 5. Corridor physics walls, end caps, exit signal, navigation
	if _hero.clamp_to_route:
		return _fail("Position clamp is still on")
	var half_width: float = _route.half_width
	await _hold(&"ui_right", 90)
	if _offset() > half_width + TOLERANCE or _offset() < half_width - 0.15:
		return _fail("Right corridor wall failed (offset=%.3f)" % _offset())
	await _hold(&"ui_left", 150)
	if _offset() < -half_width - TOLERANCE or _offset() > -half_width + 0.15:
		return _fail("Left corridor wall failed (offset=%.3f)" % _offset())
	await _hold(&"ui_up", 420)
	var z := _hero.global_position.z
	if not _exit_fired or z < -14.5 - TOLERANCE or z > -14.0 or not _hero.is_on_floor():
		return _fail("Exit cap or exit signal failed (z=%.3f, exit=%s, floor=%s)" % [z, _exit_fired, _hero.is_on_floor()])
	_hero.global_position = Vector3(_route.center_x(6.5), 0.02, 6.5)
	await _hold(&"ui_down", 120)
	z = _hero.global_position.z
	if z > 7.5 + TOLERANCE or z < 7.0:
		return _fail("Spawn-side cap failed (z=%.3f)" % z)

	var nav_map := _hero.get_world_3d().navigation_map
	var start := Vector3(_route.center_x(6.0), 0.0, 6.0)
	var goal := Vector3(_route.center_x(-14.0), 0.0, -14.0)
	var path := NavigationServer3D.map_get_path(nav_map, start, goal, true)
	var last := path[path.size() - 1] if path.size() > 0 else Vector3.INF
	if path.size() < 2 or Vector2(last.x - goal.x, last.z - goal.z).length() > 0.2:
		return _fail("Navigation path missing or short")
	print("Corridor & navigation verified (%d path points)." % path.size())

	# 6. Opening screen catalog entry
	var opening := (load(OPENING) as PackedScene).instantiate()
	var found := false
	for b: Resource in opening.builds:
		if b.get("title") == "3D Kit Canyon · v2" and b.get("scene_path") == SCENE and b.get("action") == "Play":
			found = true
			break
	opening.free()
	if not found:
		return _fail("Developers Page missing '3D Kit Canyon · v2' pointing to %s" % SCENE)
	print("PASS: 3D Kit Canyon · v2 verified across all geometry, AA, density, corridor, and catalog checks.")
	quit(0)
