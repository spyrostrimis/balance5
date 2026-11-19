extends SceneTree

func _init():
	print("Starting automated test of True 3D Desert Canyon...")
	var scene_res = load("res://scenes/maps/desert_canyon_3d_rpg.tscn")
	if not scene_res:
		print("ERROR: Failed to load desert_canyon_3d_rpg.tscn!")
		quit(1)
		return

	var scene = scene_res.instantiate()
	root.add_child(scene)
	root.size = Vector2i(1280, 720)

	var player = scene.get_node("BlueCommander") as CharacterBody3D
	var cam = scene.get_node("Camera3D") as Camera3D

	print("Player start pos: ", player.global_position, " Cam pos: ", cam.global_position)

	# 1. Warmup frames to let Forward+ shaders and volumetric fog settle
	for i in range(25):
		await physics_frame

	# Snapshot 1: Start of canyon trail
	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("res://render_captures/test_3d_pos1_start.png")
	print("Snapshot 1 saved: Start of canyon trail.")

	# 2. Walk forward down the canyon towards Z = 0
	print("Walking forward down the canyon...")
	player.input_override = Vector2(0.0, -1.0) # Move forward along -Z
	for f in range(90):
		await physics_frame

	player.input_override = Vector2.ZERO
	for f in range(15):
		await physics_frame

	print("Midway pos: ", player.global_position, " Cam pos: ", cam.global_position)
	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("res://render_captures/test_3d_pos2_midway.png")
	print("Snapshot 2 saved: Midway through canyon.")

	# 3. Walk all the way to the canyon exit opening (Z ~ -19)
	print("Walking to the sunlit canyon exit archway...")
	player.input_override = Vector2(0.0, -1.0)
	for f in range(160):
		await physics_frame

	player.input_override = Vector2.ZERO
	for f in range(25):
		await physics_frame

	print("At Canyon Exit! Player pos: ", player.global_position, " Cam pos: ", cam.global_position)
	var img3 = root.get_viewport().get_texture().get_image()
	img3.save_png("res://render_captures/test_3d_pos3_exit.png")
	print("Snapshot 3 saved: At the sunlit canyon exit archway.")

	print("ALL TRUE 3D WALKING TESTS COMPLETED!")
	quit(0)
