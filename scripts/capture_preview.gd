extends SceneTree

func _init():
	var scene_res = load("res://scenes/maps/desert_mission_1_2d.tscn")
	if not scene_res:
		print("ERROR: Failed to load 2D scene!")
		quit(1)
		return
		
	var scene = scene_res.instantiate()
	root.add_child(scene)
	
	print("2D Scene loaded. Rendering frames...")
	for i in range(10):
		await process_frame
		
	var img = root.get_viewport().get_texture().get_image()
	if img:
		DirAccess.make_dir_absolute("d:/Games/Balance5/render_captures")
		var save_path = "d:/Games/Balance5/render_captures/desert_step1_clean_2d.png"
		var err = img.save_png(save_path)
		if err == OK:
			print("SUCCESS: 2D Render capture saved to: ", save_path)
		else:
			print("ERROR: Failed to save image, error code: ", err)
	else:
		print("ERROR: Viewport texture image is null.")
		
	quit(0)
