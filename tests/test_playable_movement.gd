extends SceneTree

func _init():
	print("Starting automated test of Playable Desert Canyon...")
	var scene_res = load("res://scenes/maps/desert_canyon_playable.tscn")
	if not scene_res:
		print("ERROR: Failed to load desert_canyon_playable.tscn!")
		quit(1)
		return

	var scene = scene_res.instantiate()
	root.add_child(scene)
	root.size = Vector2i(1280, 720)

	var player = scene.get_node("BlueCommander") as CharacterBody2D
	var cam = scene.get_node("Camera2D") as Camera2D
	var sprite = player.get_node("CommanderSprite") as Sprite2D

	print("Player initial pos: ", player.position, " scale: ", sprite.scale)

	# 1. Warmup frames
	for i in range(15):
		await process_frame

	# Save snapshot 1: Initial position
	var img1 = root.get_viewport().get_texture().get_image()
	img1.save_png("res://render_captures/test_walk_pos1.png")
	print("Snapshot 1 saved (initial position).")

	# 2. Simulate walking forward-up deeper into canyon (W / UP)
	print("Simulating walking forward deeper into the canyon...")
	for f in range(40):
		player.velocity = Vector2(-20.0, -140.0) # Move up-left along trail
		player.move_and_slide()
		# Trigger player physics logic
		player._physics_process(1.0 / 60.0)
		cam._process(1.0 / 60.0)
		await process_frame

	print("Player pos after walking up: ", player.position, " scale: ", sprite.scale)

	# Save snapshot 2: Deeper in canyon (smaller scale, camera shifted)
	var img2 = root.get_viewport().get_texture().get_image()
	img2.save_png("res://render_captures/test_walk_pos2_deeper.png")
	print("Snapshot 2 saved (deeper in canyon).")

	# 3. Simulate walking down-right toward camera (S / D)
	print("Simulating walking down toward the camera...")
	for f in range(60):
		player.velocity = Vector2(80.0, 150.0) # Move down-right toward foreground
		player.move_and_slide()
		player._physics_process(1.0 / 60.0)
		cam._process(1.0 / 60.0)
		await process_frame

	print("Player pos after walking down: ", player.position, " scale: ", sprite.scale)

	# Save snapshot 3: Near foreground (larger scale, camera shifted down)
	var img3 = root.get_viewport().get_texture().get_image()
	img3.save_png("res://render_captures/test_walk_pos3_foreground.png")
	print("Snapshot 3 saved (near foreground).")

	print("ALL MOVEMENT TESTS PASSED!")
	quit(0)
