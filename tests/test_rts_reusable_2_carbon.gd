extends SceneTree
## Automated verification & Forward+ visual capture harness for RTS Reusable 2 Carbon.
##
## Headless logic & ground-interaction test:
##   Godot_console.exe --headless --path . --script res://tests/test_rts_reusable_2_carbon.gd
##
## Windowed Forward+ 1376x768 matched HD vs Pixel captures:
##   Godot_console.exe --path . --rendering-method forward_plus --resolution 1376x768 --script res://tests/test_rts_reusable_2_carbon.gd -- --capture

const SCENE_PATH := "res://scenes/maps/rts_reusable_2_carbon.tscn"
const CAP_DIR := "res://render_captures/rts_carbon/"
const MIASAKI_SCENE_PATH := "res://scenes/maps/rts_reusable_2_carbon_miasaki.tscn"

var _failures: Array[String] = []
var _capture_dir := CAP_DIR


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var miasaki := "--miasaki" in args
	if miasaki:
		_capture_dir = "res://render_captures/rts_carbon_miasaki/regression/"
	call_deferred("_run", "--capture" in args, MIASAKI_SCENE_PATH if miasaki else SCENE_PATH)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("FAIL: ", msg)


func _advance_sim(map: RtsCarbonBattlefield, seconds: float, step := 1.0 / 60.0) -> void:
	var n := int(round(seconds / step))
	for _i in range(n):
		for u in map.get_living_units():
			u.tick(step)
		map._process(step)


func _save_pair(map: RtsCarbonBattlefield, stem: String) -> void:
	map.apply_visual_mode(false)
	await process_frame
	await process_frame
	var img_hd := root.get_viewport().get_texture().get_image()
	img_hd.save_png(ProjectSettings.globalize_path(_capture_dir + stem + "_hd.png"))

	map.apply_visual_mode(true)
	await process_frame
	await process_frame
	var img_px := root.get_viewport().get_texture().get_image()
	img_px.save_png(ProjectSettings.globalize_path(_capture_dir + stem + "_pixel.png"))

	map.apply_visual_mode(false)
	await process_frame


func _run(capture_mode: bool, scene_path: String) -> void:
	if capture_mode:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_capture_dir))
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "Load " + scene_path)
	if packed == null:
		quit(1)
		return

	var map := packed.instantiate() as RtsCarbonBattlefield
	root.add_child(map)
	await process_frame
	await process_frame

	# Disable automatic physics tick during deterministic stepping so headless & windowed match 1:1
	for u in map.get_living_units():
		u.set_physics_process(false)

	# 1. Verify obstacle blocking vs walkable sand/dunes/oasis shore
	_check(not map.grid.is_walkable(map.grid.cell_of(Vector2(656, 444))), "Central Orichalcum outcrop blocks 32px cells")
	_check(not map.grid.is_walkable(map.grid.cell_of(Vector2(1016, 192))), "NE Cliff Oasis rock blocks 32px cells")
	_check(not map.grid.is_walkable(map.grid.cell_of(Vector2(1236, 312))), "Red Outpost Pad blocks 32px cells")
	_check(map.grid.is_walkable(map.grid.cell_of(Vector2(488, 566))), "Dune cluster cells are walkable")
	_check(map.height_at(Vector2(488, 566)) > 0.5, "DuneWestApproach provides elevation relief")
	_check(map.shade_at(Vector2(644, 662)) > 0.22, "SouthPassBoulders casts lee shade on adjacent sand")

	# 2. Verify framing presets (Command ~21 cells vs Close ~15 cells)
	map.close_zoom = false
	map.apply_zoom_framing()
	var cmd_cells_w := map.hud.camera_world_rect.size.x / 32.0
	_check(absf(cmd_cells_w - 21.0) < 0.5, "Command view spans ~21 playable cells (got %.2f)" % cmd_cells_w)

	if capture_mode:
		map.set_camera_focus(Vector2(548, 432))
		await _save_pair(map, "01_opening_command_21x14")

	map.close_zoom = true
	map.apply_zoom_framing()
	var close_cells_w := map.hud.camera_world_rect.size.x / 32.0
	_check(absf(close_cells_w - 15.0) < 0.5, "Close view spans ~15 playable cells (got %.2f)" % close_cells_w)

	if capture_mode:
		map.set_camera_focus(Vector2(512, 436))
		await _save_pair(map, "02_opening_close_15x10")
		map.close_zoom = false
		map.apply_zoom_framing()

	# 3. Repeatable Ground-Interaction Encounter:
	#    Walk BlueSquad1 over DuneWestApproach into SouthPassBoulders lee shade,
	#    and drive BlueTank off the stone road across DuneWestApproach!
	var squad1 := map.get_node("YSortWorld/BlueSquad1") as RtsCarbonUnit
	var tank := map.get_node("YSortWorld/BlueTank") as RtsCarbonUnit
	var cmdr := map.get_node("YSortWorld/BlueCommander") as RtsCarbonUnit
	_check(squad1 != null and tank != null and cmdr != null, "Core Blue encounter units exist")

	for u in map.get_living_units():
		u.peaceful = true

	squad1.command_move(Vector2(680, 668))  # Over DuneWestApproach into boulder lee shade!
	tank.command_move(Vector2(560, 592))    # Off stone road across golden dune ripples!
	cmdr.command_move(Vector2(528, 468))
	map.set_selection([tank, cmdr, squad1])

	_advance_sim(map, 6.4)

	_check(map.disturbed_tread_pixels > 90, "Tank compressed dual tracks across sand & dune (%d px)" % map.disturbed_tread_pixels)
	_check(map.shade_at(squad1.position) > 0.18, "Squad reached lee shade (shade=%.2f at %s)" % [map.shade_at(squad1.position), str(squad1.position.round())])

	# Verify switching Detailed Painted <-> Pixel preserves exact state
	var pos_before := tank.position
	var treads_before := map.disturbed_tread_pixels
	map.apply_visual_mode(true)
	_check(tank.position == pos_before and map.disturbed_tread_pixels == treads_before, "Pixel switch preserves exact unit & tread state")
	map.apply_visual_mode(false)

	if capture_mode:
		map.close_zoom = true
		map.apply_zoom_framing()
		map.set_camera_focus(Vector2(548, 560))
		await _save_pair(map, "03_dune_treads_and_lee_shade")

		# Capture NE Cliff Oasis & Stone Outpost landmark
		map.close_zoom = false
		map.apply_zoom_framing()
		map.set_camera_focus(Vector2(980, 290))
		await _save_pair(map, "04_northeast_oasis_and_outpost")

	# 4. Combat, Squad Casualties, Blue Commander Mend & Orichalcum Hold Timer
	for u in map.get_living_units():
		u.peaceful = false

	var red1 := map.get_node("YSortWorld/RedSquad1") as RtsCarbonUnit
	squad1.take_damage(38, red1)  # Drop squad HP so fit_count drops below 4
	var wounded_fit := squad1.fit_count()
	_check(wounded_fit < 4, "Wounded squad drops fit count (%d/4)" % wounded_fit)

	# Move Commander next to squad1 and cast Mend
	cmdr.position = squad1.position + Vector2(-24.0, -10.0)
	var healed := cmdr.cast_mend()
	_check(healed >= 1 and squad1.fit_count() > wounded_fit, "Blue Commander Mend heals squad & restores fit soldiers (%d/4)" % squad1.fit_count())

	# Engage Red vanguard near Orichalcum plaza
	map.set_selection([tank, cmdr, squad1])
	tank.position = Vector2(724, 498)
	cmdr.position = Vector2(700, 520)
	squad1.position = Vector2(748, 532)
	tank.command_attack(red1)
	cmdr.command_attack(red1)
	squad1.command_attack(red1)
	_advance_sim(map, 1.35)
	cmdr.mend_timer = 0.0
	cmdr.cast_mend()
	_advance_sim(map, 0.12)

	if capture_mode:
		map.close_zoom = false
		map.apply_zoom_framing()
		map.set_camera_focus(Vector2(760, 508))
		await _save_pair(map, "05_orichalcum_combat_and_mend")

	# Verify Orichalcum hold timer ticks down when Blue holds uncontested
	for u in map.get_living_units():
		if u.team == RtsCarbonUnit.Team.RED:
			u.position = Vector2(1280, 820)
			u.command_stop()
			u.peaceful = true
	tank.position = Vector2(656, 528)
	tank.command_stop()
	var hold_before := map.hold_seconds_left
	_advance_sim(map, 2.0)
	_check(map.hold_owner == 1 and map.hold_seconds_left < hold_before - 1.5, "Orichalcum hold timer counts down for Blue (%.1fs)" % map.hold_seconds_left)

	print("RTS Reusable 2 Carbon verification complete: %d failures, disturbed_treads=%d, hold_left=%.1f" % [
		_failures.size(), map.disturbed_tread_pixels, map.hold_seconds_left
	])
	quit(0 if _failures.is_empty() else 1)
