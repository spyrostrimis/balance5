extends SceneTree

func _init():
	print("Testing walking Blue Commander to the canyon opening ledge (Y=178)...")
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

	print("Player start pos: ", player.position)

	# 1. Warmup
	for i in range(15):
		await physics_frame

	# 2. Walk along the winding path all the way up toward the canyon opening!
	# Segment A: Walk up along trail towards Y ~ 300
	print("Walking up along mid-canyon path...")
	player.input_override = Vector2(-0.08, -1.0).normalized()
	for f in range(65):
		await physics_frame

	print("Midway pos: ", player.position, " Cam pos: ", cam.position, " Cam zoom: ", cam.zoom)

	# Segment B: Walk straight to the canyon mouth threshold (Y ~ 178)
	print("Approaching the sunlit canyon opening ledge...")
	player.input_override = Vector2(0.16, -1.0).normalized()
	for f in range(50):
		await physics_frame

	player.input_override = Vector2.ZERO
	# Let camera and physics settle
	for f in range(35):
		await physics_frame

	print("At Canyon Opening! Player pos: ", player.position, " Cam pos: ", cam.position, " Cam zoom: ", cam.zoom)
	print("Player sprite scale: ", sprite.scale, " Apparent on-screen scale: ", abs(sprite.scale.x) * cam.zoom.x)

	# Capture final frame at the canyon opening
	var img = root.get_viewport().get_texture().get_image()
	if img:
		var save_path = "res://render_captures/desert_step1_canyon_opening.png"
		var err = img.save_png(save_path)
		if err == OK:
			print("SUCCESS: Canyon opening snapshot saved to: ", save_path)
		else:
			print("ERROR saving snapshot: ", err)

	quit(0)
