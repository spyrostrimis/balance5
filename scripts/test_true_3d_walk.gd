extends SceneTree

func _init():
	print("Starting automated test of Frustum-Unprojected HD-2D Canyon...")
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

	# 1. Warmup frames for shaders, particles, and lighting
	for i in range(25):
		await physics_frame

	print("Start pos: ", player.global_position, " Cam pos: ", cam.global_position, " Cam rot: ", cam.rotation_degrees)
	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("d:/Games/Balance5/render_captures/test_organic_3d_pos1_start.png")
	print("Snapshot 1 saved: test_organic_3d_pos1_start.png")

	# 2. Walk forward from Z = 2.0 to Z ~ -3.7 (95 physics frames at speed 3.6)
	print("Walking midway down the stone canyon path...")
	player.input_override = Vector2(0.0, -1.0)
	for f in range(95):
		await physics_frame

	player.input_override = Vector2.ZERO
	for f in range(50):
		await physics_frame

	print("Midway pos: ", player.global_position, " Cam pos: ", cam.global_position, " Cam rot: ", cam.rotation_degrees, " FOV: ", cam.fov)
	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("d:/Games/Balance5/render_captures/test_organic_3d_pos2_midway.png")
	print("Snapshot 2 saved: test_organic_3d_pos2_midway.png")

	# 3. Walk to the canyon exit opening (Z = -9.5)
	print("Walking to canyon exit opening...")
	player.input_override = Vector2(0.0, -1.0)
	for f in range(110):
		await physics_frame

	player.input_override = Vector2.ZERO
	for f in range(60):
		await physics_frame

	print("Exit pos: ", player.global_position, " Cam pos: ", cam.global_position, " Cam rot: ", cam.rotation_degrees, " FOV: ", cam.fov)
	var img3 = root.get_viewport().get_texture().get_image()
	img3.save_png("d:/Games/Balance5/render_captures/test_organic_3d_pos3_exit.png")
	print("Snapshot 3 saved: test_organic_3d_pos3_exit.png")

	print("ALL TESTS COMPLETED!")
	quit(0)
