extends SceneTree
## Records a squad and the tank crossing Mission 1's sand hill at Close zoom (frames to tmp/sand_hill/).
##   Godot_console.exe --path . --rendering-method forward_plus --fullscreen --script res://tests/capture_sand_hill_clip.gd

const FRAMES := "res://tmp/sand_hill/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dir := ProjectSettings.globalize_path(FRAMES)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	var map := (load("res://scenes/maps/rts_mission_1_desert.tscn") as PackedScene).instantiate() as RtsCarbonBattlefield
	root.add_child(map)
	for _i in 3:
		await process_frame
	for u in map.get_living_units():
		u.set_physics_process(false)
		u.peaceful = true
	var hill := map.get_node("Dunes/SandHillWest") as RtsCarbonPiece
	var summit := hill.global_position + hill.relief_offset * hill.scale
	var squad := map.get_node("YSortWorld/BlueSquad3") as RtsCarbonUnit
	var squad2 := map.get_node("YSortWorld/BlueSquad1") as RtsCarbonUnit
	var tank := map.get_node("YSortWorld/BlueTank") as RtsCarbonUnit
	squad.position = summit + Vector2(-150, -6)
	squad.command_move(summit + Vector2(150, 6))
	squad2.position = summit + Vector2(-20, -95)
	squad2.command_move(summit + Vector2(20, 95))
	tank.position = summit + Vector2(150, -40)
	tank.hull_angle = PI
	tank.turret_angle = PI
	tank.command_move(summit + Vector2(-150, 30))
	map.set_selection([])
	map.close_zoom = true
	map.apply_zoom_framing()
	map.set_camera_focus(summit)
	for f in 240:
		for u in map.get_living_units():
			u.tick(1.0 / 30.0)
		map._process(1.0 / 30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_jpg(dir.path_join("%05d.jpg" % f), 0.94)
	print("lift at summit ", map.call("terrain_lift_at", summit))
	quit()
