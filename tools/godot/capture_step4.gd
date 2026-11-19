extends SceneTree

func _init():
	print("Loading Desert Approach RPG with Commander scene (Step 4)...")
	var scene_res = load("res://scenes/maps/desert_approach_rpg_with_commander.tscn")
	if not scene_res:
		print("ERROR: Failed to load desert_approach_rpg_with_commander.tscn!")
		quit(1)
		return

	var scene = scene_res.instantiate()
	root.add_child(scene)
	root.size = Vector2i(1376, 768)

	print("Rendering frames to allow particles, lights, and tilt-shift shaders to settle...")
	for i in range(25):
		await process_frame

	var img = root.get_viewport().get_texture().get_image()
	if img:
		DirAccess.make_dir_absolute("res://render_captures")
		var save_path = "res://render_captures/desert_step4_with_commander.png"
		var err = img.save_png(save_path)
		if err == OK:
			print("SUCCESS: Step 4 render capture saved to: ", save_path)
		else:
			print("ERROR saving PNG: ", err)
	else:
		print("ERROR: Viewport texture image is null.")

	quit(0)
