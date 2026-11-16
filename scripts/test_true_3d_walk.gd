extends SceneTree

func _init():
	print("Starting automated test of True 3D Stepped-Terrace HD-2D Canyon...")
	var scene_res = load("res://scenes/maps/desert_canyon_true_3d.tscn")
	if not scene_res:
		print("ERROR: Failed to load desert_canyon_true_3d.tscn!")
		quit(1)
		return

	var scene = scene_res.instantiate()
	root.add_child(scene)
	root.size = Vector2i(1376, 768)

	var player = scene.get_node("BlueCommander") as CharacterBody3D
	var cam = scene.get_node("Camera3D") as Camera3D

	# 1. Warmup frames for shaders, volumetric fog, particles, and shadows
	for i in range(25):
		await physics_frame

	print("Start pos: ", player.global_position, " Cam pos: ", cam.global_position)
	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("d:/Games/Balance5/render_captures/test_organic_3d_pos1_start.png")
	print("Snapshot 1 saved: test_organic_3d_pos1_start.png")

	# 2. Walk forward from Z = +8.0 to Z ~ -0.2 (100 physics frames at speed 4.8)
	print("Walking midway down the canyon trail...")
	player.input_override = Vector2(0.0, -1.0)
	for f in range(100):
		await physics_frame

	player.input_override = Vector2.ZERO
	for f in range(35):
		await physics_frame

	print("Midway pos: ", player.global_position, " Cam pos: ", cam.global_position)
	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("d:/Games/Balance5/render_captures/test_organic_3d_pos2_midway.png")
	print("Snapshot 2 saved: test_organic_3d_pos2_midway.png")

	# 3. Walk all the way to the canyon exit opening (Z ~ -14.8, 180 physics frames)
	print("Walking to the sunlit canyon exit opening...")
	player.input_override = Vector2(0.0, -1.0)
	for f in range(180):
		await physics_frame

	player.input_override = Vector2.ZERO
	for f in range(45):
		await physics_frame

	print("Exit pos: ", player.global_position, " Cam pos: ", cam.global_position)
	var img3 = root.get_viewport().get_texture().get_image()
	img3.save_png("d:/Games/Balance5/render_captures/test_organic_3d_pos3_exit.png")
	print("Snapshot 3 saved: test_organic_3d_pos3_exit.png")

	print("ALL STEPPED-TERRACE TRUE 3D WALK TESTS COMPLETED!")
	quit(0)
