extends SceneTree

func _init():
	print("Starting test of Cinematic True 3D Canyon...")
	var scene_res = load("res://scenes/maps/desert_canyon_true_3d.tscn")
	if not scene_res:
		print("ERROR: Failed to load desert_canyon_true_3d.tscn!")
		quit(1)
		return

	var scene = scene_res.instantiate()
	root.add_child(scene)
	root.size = Vector2i(1280, 720)

	var player = scene.get_node("BlueCommander") as CharacterBody3D
	var cam = scene.get_node("Camera3D") as Camera3D

	# 1. Warmup frames for shaders, lights, and camera smoothing
	for i in range(25):
		await physics_frame

	print("Player start pos: ", player.global_position, " Cam pos: ", cam.global_position)

	# Snapshot 1: Start of canyon trail
	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("d:/Games/Balance5/render_captures/test_organic_3d_pos1_start.png")
	print("Snapshot 1 saved: Start of canyon trail (Z = ", player.global_position.z, ").")

	# 2. Walk forward down the canyon towards Z = 0
	print("Walking forward down the canyon trail...")
	player.input_override = Vector2(0.0, -1.0) # Move forward along -Z
	for f in range(100):
		await physics_frame

	player.input_override = Vector2.ZERO
	for f in range(15):
		await physics_frame

	print("Midway pos: ", player.global_position, " Cam pos: ", cam.global_position)
	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("d:/Games/Balance5/render_captures/test_organic_3d_pos2_midway.png")
	print("Snapshot 2 saved: Midway through canyon.")

	# 3. Walk all the way to the canyon exit opening (Z ~ -14 to -16)
	print("Walking to the sunlit canyon exit opening...")
	player.input_override = Vector2(0.0, -1.0)
	for f in range(180):
		await physics_frame

	player.input_override = Vector2.ZERO
	for f in range(20):
		await physics_frame

	print("At Canyon Exit! Player pos: ", player.global_position, " Cam pos: ", cam.global_position)
	var img3 = root.get_viewport().get_texture().get_image()
	img3.save_png("d:/Games/Balance5/render_captures/test_organic_3d_pos3_exit.png")
	print("Snapshot 3 saved: At the sunlit canyon exit opening.")

	print("ALL CINEMATIC 3D WALKING TESTS COMPLETED!")
	quit(0)
