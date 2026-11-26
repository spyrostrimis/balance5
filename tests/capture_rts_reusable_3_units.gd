extends SceneTree

const CARBON := "res://scenes/maps/rts_reusable_2_carbon.tscn"
const REUSABLE_3 := "res://scenes/maps/rts_reusable_3.tscn"
const CAPTURE := "res://render_captures/rts_reusable_3/"
const UNIT_NAMES := [
	"BlueSquad1", "RedSquad1", "BlueSquad2", "RedSquad2",
	"BlueCommander", "RedCommander", "BlueTank", "RedTank", "BlueSquad3", "RedSquad3"
]
const LINEUP := [
	Vector2(368, 377), Vector2(432, 401), Vector2(368, 478), Vector2(432, 478),
	Vector2(493, 421), Vector2(493, 478), Vector2(320, 357), Vector2(545, 478),
	Vector2(368, 529), Vector2(432, 529)
]

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var original := "--original" in args
	var color_only := "--color-only" in args
	var map := (load(CARBON if original or color_only else REUSABLE_3) as PackedScene).instantiate() as RtsCarbonBattlefield
	root.add_child(map)
	map.set_process(false)
	map.set_selection([])
	map.set_camera_focus(Vector2(443, 440))
	for i in UNIT_NAMES.size():
		var unit := map.world_ysort.get_node(UNIT_NAMES[i]) as RtsCarbonUnit
		if color_only:
			unit._detailed_art_directory = "res://assets/textures/rts/reusable_3"
			unit.apply_visual_mode(false)
		unit.set_physics_process(false)
		unit.peaceful = true
		unit.position = LINEUP[i]
		unit.facing = Vector2.DOWN
		if i in [8, 9]:
			unit.health = floori(unit.max_health * 0.7)
		unit.queue_redraw()
	var name := "carbon" if original else ("uniforms_only" if color_only else "reusable_3")
	await _save(name + "_command")
	if "--facings" in args:
		for column in 8:
			for unit in map.get_living_units():
				unit.facing = Vector2.DOWN.rotated(float(column) * TAU / 8.0)
				unit._moving_now = true
				unit._stride_dist = float(column % 4) * 5.0
				unit.queue_redraw()
			await _save(name + "_facing_%d" % column)
	quit()


func _save(stem: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE))
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var err := frame.save_png(CAPTURE.path_join(stem + ".png"))
	print(stem, " ", frame.get_size(), " save=", err)
