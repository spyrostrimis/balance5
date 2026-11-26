extends SceneTree
## Captures matched Command-zoom infantry & commander comparisons on pale road and calm sand
## with selection brackets OFF, testing:
##   1. --original    : Original Carbon (rts_reusable_2_carbon.tscn, Carbon paint, 1.0x squad spacing)
##   2. --color-only  : Original Carbon scene, camera, positions, scale & 1.0x spacing, swapping ONLY Reusable 4 unit paint
##   3. (default)     : Same Carbon scene & camera with Reusable 4 unit paint + 1.20x visual squad spacing
##   4. --reusable-4  : Full RTS Reusable 4 scene at the same lineup
##   5. --facings     : Also captures all 8 facings (0:S .. 7:SE) with walking stride frames active

const CARBON := "res://scenes/maps/rts_reusable_2_carbon.tscn"
const REUSABLE_4 := "res://scenes/maps/rts_reusable_4.tscn"
const CAPTURE := "res://render_captures/rts_reusable_4/"
const UNIT_NAMES := [
	"BlueSquad1", "RedSquad1", "BlueSquad2", "RedSquad2",
	"BlueCommander", "RedCommander", "BlueTank", "RedTank", "BlueSquad3", "RedSquad3"
]
# Top row on pale road, middle row (4 of 4) on calm sand, lower row (wounded 3 of 4) on calm sand
const LINEUP := [
	Vector2(368, 376), Vector2(432, 400),
	Vector2(368, 462), Vector2(432, 462),
	Vector2(494, 420), Vector2(494, 462),
	Vector2(316, 355), Vector2(548, 462),
	Vector2(368, 514), Vector2(432, 514),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var original := "--original" in args
	var color_only := "--color-only" in args
	var full_r4 := "--reusable-4" in args
	var map_path := REUSABLE_4 if full_r4 else CARBON
	var map := (load(map_path) as PackedScene).instantiate() as RtsCarbonBattlefield
	root.add_child(map)
	await process_frame
	await process_frame

	map.set_process(false)
	map.close_zoom = false
	map.apply_zoom_framing()
	map.set_selection([])
	map.set_camera_focus(Vector2(444, 434))

	var stem := "carbon_original"
	if color_only:
		stem = "reusable_4_color_only"
	elif full_r4:
		stem = "reusable_4_full_scene"
	elif not original:
		stem = "reusable_4_spaced"

	for i in UNIT_NAMES.size():
		var unit := map.world_ysort.get_node(UNIT_NAMES[i]) as RtsCarbonUnit
		if not original:
			unit._detailed_art_directory = "res://assets/textures/rts/reusable_4"
			unit._squad_spacing = 1.0 if color_only else 1.20
			unit.apply_visual_mode(false)
		unit.set_physics_process(false)
		unit.peaceful = true
		unit.selected = false
		unit.position = LINEUP[i]
		unit.facing = Vector2(0.82, 0.57).normalized() if unit.team == RtsCarbonUnit.Team.BLUE else Vector2(-0.82, -0.57).normalized()
		if i in [8, 9]:
			# 3 of 4 fit soldiers! Set max_health = health after reducing or test both with and without health bars:
			unit.health = floori(float(unit.max_health) * 0.70)
		unit.queue_redraw()

	await _save(stem + "_command")

	# Also capture clean figure-only count check (hiding wounded health bars by matching max_health temporarily
	# while keeping fit_count = 3 via a 3-soldier health ratio? No: RtsCarbonUnit draws health bar iff health < max_health;
	# capturing both standard wounded and South-facing gives full clarity!)
	if "--facings" in args:
		for column in 8:
			# Match RtsCarbonUnit.dir_to_col(dir): 0:S, 1:SW, 2:W, 3:NW, 4:N, 5:NE, 6:E, 7:SE
			var angle := PI * 0.5 + float(column) * (PI * 0.25)
			var dir := Vector2(cos(angle), sin(angle))
			# Verify dir_to_col: atan2(-dir.x, dir.y) -> for col 0 (S): dir=(0,1) -> 0; col 1 (SW): (-0.7, 0.7) -> +1!
			for unit in map.get_living_units():
				unit.facing = dir
				unit.hull_angle = dir.angle()
				unit.turret_angle = dir.angle()
				unit._moving_now = true
				unit._stride_dist = float((column % 4)) * 5.0
				unit.queue_redraw()
			await _save(stem + "_facing_%d" % column)

	quit()


func _save(stem: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE))
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var err := frame.save_png(CAPTURE.path_join(stem + ".png"))
	print(stem, " size=", frame.get_size(), " save=", err)
