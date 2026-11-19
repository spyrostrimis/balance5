extends SceneTree

const SCENE_PATH := "res://scenes/maps/desert_kitbash_minimap.tscn"
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
		push_error("Null viewport image for " + filename)
		return
	DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	var out_path := CAPTURE_DIR + "/" + filename
	var err := img.save_png(out_path)
	if err != OK:
		push_error("Failed saving %s: %s" % [out_path, error_string(err)])
	else:
		print("Captured: ", out_path)


func _is_inside_body_poly(world_pos: Vector2, body: StaticBody2D) -> bool:
	var poly_node := body.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var local_pos := poly_node.to_local(world_pos)
	return Geometry2D.is_point_in_polygon(local_pos, poly_node.polygon)


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
	var oasis := scene.get_node("Obstacles/OasisWater") as StaticBody2D
	var crystal := scene.get_node("Obstacles/CrystalOutcrop") as StaticBody2D
	var mesa := scene.get_node("Obstacles/SouthWestMesa") as StaticBody2D

	print("Mini-map initial BlueTank pos=", tank.global_position, " facing=", tank.get_facing())
	await _capture("kitbash_minimap_start.png")

	# Drive east along the road, turn north onto the ring road, then east across the northern bypass.
	tank.set_move_target(Vector2(176, 176))
	await _step_seconds(2.0, tank)
	tank.set_move_target(Vector2(176, 112))
	await _step_seconds(1.5, tank)
	tank.set_move_target(Vector2(400, 112))
	await _step_seconds(1.3)
	print("Mid-drive pos=", tank.global_position, " facing=", tank.get_facing())
	await _capture("kitbash_minimap_drive.png")

	await _step_seconds(1.8, tank)
	print("Ring east corner pos=", tank.global_position)

	# Attempt to drive directly into OasisWater (486, 98)
	tank.set_move_target(Vector2(486, 98))
	await _step_seconds(2.0, tank)
	var oasis_dist := tank.global_position.distance_to(oasis.global_position)
	var in_oasis := _is_inside_body_poly(tank.global_position, oasis)
	print("Oasis check: pos=", tank.global_position, " dist=", oasis_dist, " in_oasis=", in_oasis)
	if in_oasis or oasis_dist <= 30.0:
		printerr("FAIL: Tank entered OasisWater on kitbash mini-map!")
		quit(1)
		return

	scene.set_show_collisions(true)
	await _capture("kitbash_minimap_colliders.png")
	scene.set_show_collisions(false)

	# Attempt to drive into CrystalOutcrop (288, 176) from the northern bypass
	tank.set_move_target(Vector2(288, 112))
	await _step_seconds(2.0, tank)
	tank.set_move_target(Vector2(288, 176))
	await _step_seconds(1.5, tank)
	var cryst_dist := tank.global_position.distance_to(crystal.global_position)
	var in_cryst := _is_inside_body_poly(tank.global_position, crystal)
	print("Crystal check: pos=", tank.global_position, " dist=", cryst_dist, " in_cryst=", in_cryst)
	if in_cryst or cryst_dist <= 40.0:
		printerr("FAIL: Tank entered CrystalOutcrop!")
		quit(1)
		return

	# Attempt to drive into SouthWestMesa (88, 286)
	tank.set_move_target(Vector2(176, 240))
	await _step_seconds(2.5, tank)
	tank.set_move_target(Vector2(88, 286))
	await _step_seconds(2.0, tank)
	var mesa_dist := tank.global_position.distance_to(mesa.global_position)
	var in_mesa := _is_inside_body_poly(tank.global_position, mesa)
	print("SouthWestMesa check: pos=", tank.global_position, " dist=", mesa_dist, " in_mesa=", in_mesa)
	if in_mesa or mesa_dist <= 40.0:
		printerr("FAIL: Tank climbed SouthWestMesa!")
		quit(1)
		return

	print("ALL KITBASH MINI-MAP CHECKS PASSED!")
	quit(0)
