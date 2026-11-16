extends SceneTree

func _init():
	print("Loading Desert Approach RPG HD-2D scene...")
	var scene_res = load("res://scenes/maps/desert_approach_rpg_hd2d.tscn")
	if not scene_res:
		print("ERROR: Failed to load desert_approach_rpg_hd2d.tscn!")
		quit(1)
		return

	var scene = scene_res.instantiate()
	root.add_child(scene)

	# Set window / viewport size to 1376x768 to match asset resolution
	root.size = Vector2i(1376, 768)

	print("Rendering frames to allow particles and shaders to settle...")
	for i in range(20):
		await process_frame

	var img = root.get_viewport().get_texture().get_image()
	if img:
		DirAccess.make_dir_absolute("d:/Games/Balance5/render_captures")
		var save_path = "d:/Games/Balance5/render_captures/desert_step3_rpg_hd2d_canvas.png"
		var err = img.save_png(save_path)
		if err == OK:
			print("SUCCESS: HD-2D RPG render capture saved to: ", save_path)
		else:
			print("ERROR saving PNG: ", err)
	else:
		print("ERROR: Viewport texture image is null.")

	quit(0)
