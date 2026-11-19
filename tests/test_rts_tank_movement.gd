extends SceneTree

const SCENE_PATH := "res://scenes/maps/desert_mission_1_with_units.tscn"
const CAPTURE_DIR := "res://render_captures"


func _step_seconds(seconds: float, stop_when_idle: Node = null) -> void:
	var steps := int(round(seconds * 60.0))
	for i in range(steps):
		await physics_frame
		if stop_when_idle != null and not stop_when_idle.has_move_target() and i > 6:
			break


func _capture(filename: String) -> void:
	for _i in range(3):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	if img == null:
		push_error("Viewport image null for " + filename)
		return
	DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	var out_path := CAPTURE_DIR + "/" + filename
	var err := img.save_png(out_path)
	if err != OK:
		push_error("Failed saving capture %s: %s" % [out_path, error_string(err)])
	else:
		print("Captured: ", out_path)


func _init() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		printerr("ERROR: Failed to load ", SCENE_PATH)
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await _step_seconds(0.1)

	var tank := scene.get_node("Units/BlueForces/BlueTank") as CharacterBody2D
	var water_poly: PackedVector2Array = scene.get_node("Obstacles/OasisWater/CollisionPolygon2D").polygon
	var mound_poly: PackedVector2Array = scene.get_node("Obstacles/CenterCrystalMound/CollisionPolygon2D").polygon
	var turret_poly: PackedVector2Array = scene.get_node("Obstacles/TurretBuilding/CollisionPolygon2D").polygon
	var cliff_poly: PackedVector2Array = scene.get_node("Obstacles/UpperRightCliff/CollisionPolygon2D").polygon

	print("Initial BlueTank pos: ", tank.global_position)
	if tank.global_position.distance_to(Vector2(170, 222)) > 2.0:
		printerr("FAIL: Unexpected initial tank position")
		quit(1)
		return

	# 1. Drive around the south side of the central roundabout and east past RedHarvester.
	tank.set_move_target(Vector2(210, 345))
	await _step_seconds(2.0, tank)
	print("After waypoint 1 (210, 345): ", tank.global_position)

	tank.set_move_target(Vector2(495, 465))
	await _step_seconds(3.5, tank)
	print("After waypoint 2 (495, 465): ", tank.global_position)
	if tank.global_position.distance_to(Vector2(495, 465)) > 16.0:
		printerr("FAIL: Tank could not drive cleanly around the central roundabout")
		quit(1)
		return

	tank.set_move_target(Vector2(675, 405))
	await _step_seconds(2.5, tank)
	print("After waypoint 3 (675, 405): ", tank.global_position)
	if tank.global_position.distance_to(Vector2(675, 405)) > 16.0:
		printerr("FAIL: Tank could not steer past RedHarvester")
		quit(1)
		return

	# Capture mid-route heading north across open sand toward the oasis (shows waypoint + rotated tank + shadow).
	tank.set_move_target(Vector2(695, 195))
	await _step_seconds(0.9)
	print("Mid-route pos (heading to 695, 195): ", tank.global_position, " sprite_rot=", tank.get_node("TankSprite").rotation)
	await _capture("rts_mission1_tank_move.png")

	await _step_seconds(2.0, tank)
	print("Arrived at oasis staging pos: ", tank.global_position)
	if tank.global_position.distance_to(Vector2(695, 195)) > 16.0:
		printerr("FAIL: Tank did not reach oasis staging position (695, 195)")
		quit(1)
		return

	# 2. Attempt to drive directly into OasisWater center (800, 150).
	tank.set_move_target(Vector2(800, 150))
	await _step_seconds(2.5, tank)
	var water_dist := tank.global_position.distance_to(Vector2(800, 150))
	var in_water := Geometry2D.is_point_in_polygon(tank.global_position, water_poly)
	print("Water collision check: pos=", tank.global_position, " dist_to_water_center=", water_dist, " in_water=", in_water, " has_target=", tank.has_move_target())
	if in_water or water_dist <= 35.0 or water_dist >= 95.0:
		printerr("FAIL: Tank water shoreline collision check out of range! water_dist=", water_dist)
		quit(1)
		return

	scene.set_show_collisions(true)
	await _capture("rts_mission1_tank_water_blocked.png")
	scene.set_show_collisions(false)

	# 3. Drive around to southern approach below TurretBuilding and try climbing onto (940, 178).
	tank.set_move_target(Vector2(860, 310))
	await _step_seconds(2.5, tank)
	print("Turret staging pos: ", tank.global_position)
	tank.set_move_target(Vector2(940, 178))
	await _step_seconds(2.0, tank)
	var turret_dist := tank.global_position.distance_to(Vector2(940, 178))
	var in_turret := Geometry2D.is_point_in_polygon(tank.global_position, turret_poly)
	var in_cliff := Geometry2D.is_point_in_polygon(tank.global_position, cliff_poly)
	print("Turret/Cliff collision check: pos=", tank.global_position, " dist_to_turret=", turret_dist, " in_turret=", in_turret, " in_cliff=", in_cliff)
	if in_turret or in_cliff or turret_dist <= 75.0 or turret_dist >= 145.0:
		printerr("FAIL: Tank turret/cliff collision check out of range! turret_dist=", turret_dist)
		quit(1)
		return

	# 4. Drive back west below harvester, then attempt to drive directly into CenterCrystalMound (500, 350).
	tank.set_move_target(Vector2(660, 420))
	await _step_seconds(2.5, tank)
	tank.set_move_target(Vector2(500, 460))
	await _step_seconds(2.5, tank)
	tank.set_move_target(Vector2(500, 350))
	await _step_seconds(2.0, tank)
	var mound_dist := tank.global_position.distance_to(Vector2(500, 350))
	var in_mound := Geometry2D.is_point_in_polygon(tank.global_position, mound_poly)
	print("CenterCrystalMound collision check: pos=", tank.global_position, " dist_to_mound=", mound_dist, " in_mound=", in_mound)
	if in_mound or mound_dist <= 65.0 or mound_dist >= 110.0:
		printerr("FAIL: Tank crystal mound collision check out of range! mound_dist=", mound_dist)
		quit(1)
		return

	print("ALL RTS TANK MOVEMENT & COLLISION CHECKS PASSED!")
	quit(0)
