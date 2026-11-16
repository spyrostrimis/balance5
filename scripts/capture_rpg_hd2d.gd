extends SceneTree

func _init():
	print("Loading desert canyon RPG scene...")
	var scene_res = load("res://scenes/maps/desert_canyon_rpg.tscn")
	if not scene_res:
		print("ERROR: Failed to load desert canyon RPG scene!")
		quit(1)
		return
		
	var scene = scene_res.instantiate()
	root.add_child(scene)
	
	print("Rendering frames to allow Forward+ shaders, DoF, and volumetric fog to accumulate...")
	# Allow 30 frames for volumetric fog temporal accumulation
	for i in range(30):
		await process_frame
		
	var img = root.get_viewport().get_texture().get_image()
	if img:
		DirAccess.make_dir_absolute("d:/Games/Balance5/render_captures")
		var save_path = "d:/Games/Balance5/render_captures/desert_step3_rpg_hd2d.png"
		var err = img.save_png(save_path)
		if err == OK:
			print("SUCCESS: HD-2D render capture saved to: ", save_path)
		else:
			print("ERROR: Failed to save image, error code: ", err)
	else:
		print("ERROR: Viewport texture image is null.")
		
	quit(0)
