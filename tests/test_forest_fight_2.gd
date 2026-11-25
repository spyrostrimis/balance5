extends SceneTree
## Automated verification, still capture, and real-time MP4 frame recorder
## for “2D Painted Forest Fight 2” (res://scenes/forest_fight_2/forest_fight_2.tscn).

const SCENE_PATH := "res://scenes/forest_fight_2/forest_fight_2.tscn"
const OPENING_PATH := "res://scenes/ui/opening_screen.tscn"
const SceneRes := preload(SCENE_PATH)
const Route := preload("res://scripts/forest_fight_2/forest_fight_2_route.gd")

const CAPTURE_DIR := "res://render_captures/forest_fight_2/"
const LIVE_DIR := CAPTURE_DIR + "live_frames/"
const RECORD_FPS := 30.0

var game: ForestFight2
var failures: int = 0
var observed_phases: Array[String] = []

var _recording := false
var _rec_start_usec := 0
var _rec_frame := 0
var _rec_dupes := 0
var _last_jpg := PackedByteArray()


func _initialize() -> void:
	call_deferred("_main")


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var rendered := DisplayServer.get_name() != "headless"
	if rendered or "--stills" in args or "--record-clip" in args:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))

	if "--record-clip" in args:
		await _run_live_clip_recording()
		quit(0 if failures == 0 else 1)
		return

	await _run_verification("--stills" in args and rendered, "--catalog" in args)
	print("Forest Fight 2 verification %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _run_verification(capture_stills: bool, run_catalog: bool) -> void:
	game = SceneRes.instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.mode_transitioned.connect(func(p: String) -> void: observed_phases.append(p))

	var rendered := DisplayServer.get_name() != "headless"
	print("ForestFight2 | driver=%s | method=%s | viewport=%s" % [
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_current_rendering_method(),
		root.get_visible_rect().size,
	])
	if rendered:
		_check(root.get_visible_rect().size == Route.VIEW, "viewport matches 1376x768")
		_check(RenderingServer.get_current_rendering_method() == "forward_plus", "Forward+ active")

	# 1. Opening Forest Walk state
	_check(game.phase == ForestFight2.Phase.EXPLORE_FOREST, "starts in EXPLORE_FOREST")
	_check(game.forest_stage.visible and not game.cave_stage.visible, "forest visible, cave hidden")
	var boot_scr := game.forest_commander.get_global_transform_with_canvas().origin
	_check(is_equal_approx(boot_scr.y, 537.6), "opening forest boots at 70% height")

	# 2. Walk to clearing & approach cave mouth, stop, and back away without triggering entry!
	await _walk_forest_to_y(332.0)
	_check(game.phase == ForestFight2.Phase.EXPLORE_FOREST, "approaching cave mouth stays in explore")
	if capture_stills:
		await _save_still("01_forest_cave_approach.png")
	await _walk_forest_to_y(396.0)
	_check(game.phase == ForestFight2.Phase.EXPLORE_FOREST, "backing away from cave mouth works cleanly")

	# 3. Hold UP continuously across the threshold and all the way through Beats 1-3 into Combat!
	observed_phases.clear()
	var captured_b1 := false
	var captured_b2 := false
	for tick in 260:
		await physics_frame
		game.step_sequence(Vector2.UP, 1.0 / 60.0)
		if capture_stills and not captured_b1 and game.phase == ForestFight2.Phase.TRANSITION_BEAT_1 and game._beat_timer >= 0.26:
			captured_b1 = true
			await _save_still("02_beat1_under_lip.png")
		if capture_stills and not captured_b2 and game.phase == ForestFight2.Phase.TRANSITION_BEAT_2 and game._beat_timer >= 0.36:
			captured_b2 = true
			await _save_still("03_beat2_sunlit_threshold.png")
		if game.phase == ForestFight2.Phase.COMBAT_CAVE:
			break

	_check(
		observed_phases == ["TRANSITION_BEAT_1", "TRANSITION_BEAT_2", "TRANSITION_BEAT_3", "COMBAT_CAVE"],
		"exact 3-beat transition sequence fired once (%s)" % [str(observed_phases)]
	)
	_check(game.cave_stage.visible and not game.forest_stage.visible, "cave visible after transition")
	_check(game.cave_hero != null and game.cave_hero.controls_enabled, "cave hero controls unlocked")

	# Keep holding UP for 0.30s right after entry to prove held key moves safely in depth without turning!
	for tick in 18:
		await physics_frame
		game.step_sequence(Vector2.UP, 1.0 / 60.0)
	_check(game.cave_hero.combat_facing == 1, "holding UP through entry preserves right profile facing")
	_check(game.cave_hero.depth_y >= CaveCommander2D.DEPTH_MIN_Y, "back wall clamps continuous UP walk")

	# Verify grace window: no bat has started diving yet!
	for b in game.bats:
		_check(b.state == AlienBat2D.State.ORBIT, "bat grants opening movement grace window")

	# 4. Middle-depth Image 1 framing & rendered raster height measurement
	game.cave_hero.set_floor_position(Vector2(540.0, 770.0), 1)
	game.cave_camera.position = Vector2(game._desired_cave_cam_x(), ForestFight2.CAVE_CAM_CHAMBER_Y)
	game.cave_camera.force_update_scroll()
	var mid_h := game.cave_hero.rendered_height_px()
	var mid_pct := 100.0 * mid_h / Route.VIEW.y
	print("Cave middle depth | depth_y=770 | height=%.1f px (%.2f%% of 768)" % [mid_h, mid_pct])
	_check(mid_pct >= 35.0 and mid_pct <= 37.0, "middle-depth Commander is 35-37% of frame height")

	if capture_stills:
		await _measure_cave_raster_height()
		await _save_still("04_cave_mid_depth_img1.png")

	# 5. Pure depth movement preserves both Left and Right facing; diagonal shots stay strictly horizontal
	game.cave_hero.set_floor_position(Vector2(680.0, 760.0), -1)
	for tick in 12:
		game.cave_hero.step_combat(Vector2.DOWN, 1.0 / 60.0)
	_check(game.cave_hero.combat_facing == -1, "pure DOWN preserves left facing")
	for tick in 12:
		game.cave_hero.step_combat(Vector2.UP, 1.0 / 60.0)
	_check(game.cave_hero.combat_facing == -1, "pure UP preserves left facing")

	# Park bats high during wall-stop & lane-miss deterministic checks
	for b in game.bats:
		b.combat_active = false
		b.altitude = 340.0

	# Fire LEFT while moving diagonally up-left -> must travel strictly at hero's shot depth_y and stop on left wall
	game.cave_hero._cooldown_timer = 0.0
	game.cave_hero.step_combat(Vector2(-1.0, -1.0), 1.0 / 60.0)
	var left_bolt := game.fire_player_rifle()
	_check(left_bolt != null and left_bolt.dir_x == -1, "diagonal up-left fires strictly left")
	var start_bolt_lane := left_bolt.depth_y
	for tick in 120:
		if not is_instance_valid(left_bolt) or left_bolt.spent:
			break
		left_bolt.step_bolt(1.0 / 60.0)
		_check(is_equal_approx(left_bolt.depth_y, start_bolt_lane), "left bolt stays strictly horizontal")
	_check(left_bolt.stopped_on_wall, "left bolt stops cleanly on left cave wall")

	# Fire RIGHT while moving diagonally down-right -> must stop on right cave wall
	game.cave_hero._cooldown_timer = 0.0
	game.cave_hero.step_combat(Vector2(1.0, 1.0), 1.0 / 60.0)
	var right_bolt := game.fire_player_rifle()
	_check(right_bolt != null and right_bolt.dir_x == 1, "diagonal down-right fires strictly right")
	for tick in 120:
		if not is_instance_valid(right_bolt) or right_bolt.spent:
			break
		right_bolt.step_bolt(1.0 / 60.0)
	_check(right_bolt.stopped_on_wall, "right bolt stops cleanly on right cave wall")

	# 6. Out-of-lane miss test: bat at rifle height (212 px) directly ahead in X, but 88 px behind in depth!
	var test_bat: AlienBat2D = game.bats[0]
	game.cave_hero.set_floor_position(Vector2(420.0, 790.0), 1)
	test_bat.position = Vector2(680.0, 702.0)
	test_bat.depth_y = 702.0
	test_bat.altitude = AlienBat2D.RIFLE_PASS_ALTITUDE
	test_bat._update_visuals()
	game.cave_hero._cooldown_timer = 0.0
	var miss_bolt := game.fire_player_rifle()
	for tick in 90:
		if not is_instance_valid(miss_bolt) or miss_bolt.spent:
			break
		miss_bolt.step_bolt(1.0 / 60.0)
	_check(test_bat.alive and not miss_bolt.hit_bat, "bat clearly behind hero survives shot in front lane")

	# 7. Repeated bat contacts cause visible blue spark, max 1 contact per pass, and zero harm!
	test_bat.combat_active = true
	test_bat.state = AlienBat2D.State.SWOOP_PASS
	test_bat._swoop_start_x = 280.0
	test_bat._swoop_end_x = 620.0
	test_bat._swoop_start_lane = 790.0
	test_bat._swoop_end_lane = 790.0
	test_bat._swoop_duration = 0.60
	test_bat._timer = 0.60
	test_bat.contacted_this_pass = false
	var captured_spark := false
	for tick in 40:
		await physics_frame
		game.step_sequence(Vector2.ZERO, 1.0 / 60.0)
		if capture_stills and not captured_spark and game.cave_hero.contact_count == 1:
			captured_spark = true
			await _save_still("05_bat_contact_spark.png")
	_check(game.cave_hero.contact_count == 1, "exactly one contact counted on first swoop pass")

	# Second pass contact
	test_bat.state = AlienBat2D.State.SWOOP_PASS
	test_bat._timer = 0.60
	test_bat.contacted_this_pass = false
	for tick in 40:
		game.step_sequence(Vector2.ZERO, 1.0 / 60.0)
	_check(game.cave_hero.contact_count == 2, "second pass counts second harmless contact")
	_check(game.cave_hero.controls_enabled, "Commander stays responsive and unharmed after contacts")

	# 8. Reposition into each bat's depth lane and score 3 one-shot kills -> Cave clear!
	var placements := [
		Vector3(740.0, 740.0, 1.0),
		Vector3(290.0, 825.0, -1.0),
		Vector3(820.0, 688.0, 1.0),
	]
	for i in 3:
		var b: AlienBat2D = game.bats[i]
		b.combat_active = false
		var p: Vector3 = placements[i]
		b.position = Vector2(p.x, p.y)
		b.depth_y = p.y
		b.altitude = AlienBat2D.RIFLE_PASS_ALTITUDE
		b.state = AlienBat2D.State.SWOOP_PASS
		b._update_visuals()

		# Step Commander into matching lane facing the bat and fire ONE shot!
		var hero_x := 500.0 if p.z > 0.0 else 560.0
		game.cave_hero.set_floor_position(Vector2(hero_x, p.y + 8.0), int(p.z))
		game.cave_hero._cooldown_timer = 0.0
		var kill_bolt := game.fire_player_rifle()
		_check(kill_bolt != null, "fired shot at bat %d" % i)
		for tick in 60:
			game.step_sequence(Vector2.ZERO, 1.0 / 60.0)
			if not b.alive:
				break
		_check(not b.alive, "bat %d dies in one shot" % i)

	# Let cave settle (~0.65s) so Cave clear banner appears
	for tick in 50:
		await physics_frame
		game.step_sequence(Vector2.ZERO, 1.0 / 60.0)

	_check(game.bats_killed == 3, "exactly three bat kills counted")
	_check(game.cave_is_clear and game.cave_clear_label.visible, "Cave clear banner shown after 3rd kill")

	# Verify player remains free to walk after Cave clear
	var before_walk := game.cave_hero.position
	for tick in 15:
		game.step_sequence(Vector2(1.0, 0.0), 1.0 / 60.0)
	_check(game.cave_hero.position.x > before_walk.x + 20.0, "player remains free to move after Cave clear")

	if capture_stills:
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		game.cave_clear_label.modulate.a = 1.0
		await _save_still("06_cave_clear.png")

	# 9. Fresh replay reset check
	game.reset_sequence()
	_check(
		game.phase == ForestFight2.Phase.EXPLORE_FOREST and game.bats_killed == 0 and not game.cave_is_clear,
		"R reset_sequence restores fresh exploration start"
	)

	if run_catalog:
		await _verify_developers_page_roundtrip()


func _verify_developers_page_roundtrip() -> void:
	for test_combat_esc in [false, true]:
		var err := change_scene_to_file(OPENING_PATH)
		_check(err == OK, "opening_screen loads")
		if err != OK:
			return
		await scene_changed
		var orig_win := [root.size, root.content_scale_size, root.title]
		current_scene.get_node("%DevelopersPage").pressed.emit()
		var catalog := current_scene.get_node("%Catalog")
		var found := false
		for section in catalog.get_children():
			for card in section.get_children():
				if card.get_meta("catalog_key", "") != SCENE_PATH:
					continue
				for btn in card.find_children("*", "Button", true, false):
					if btn.text != "Play":
						continue
					found = true
					btn.pressed.emit()
					await scene_changed
					_check(current_scene is ForestFight2, "Developers Page opens ForestFight2")
					if test_combat_esc:
						var ff := current_scene as ForestFight2
						ff.set_physics_process(false)
						ff._begin_beat_2()
						ff._begin_cave_combat()
						_check(ff.phase == ForestFight2.Phase.COMBAT_CAVE, "switched to combat before Esc")
					var esc := InputEventKey.new()
					esc.keycode = KEY_ESCAPE
					esc.physical_keycode = KEY_ESCAPE
					esc.pressed = true
					root.push_input(esc)
					await scene_changed
					_check(current_scene.get_node("%Library").visible, "Esc returns to Developers Page")
					_check(orig_win == [root.size, root.content_scale_size, root.title], "window settings restored")
					break
				if found:
					break
			if found:
				break
		_check(found, "Developers Page lists 2D Painted Forest Fight 2 Play card")
	print("Catalog Play + Esc (both modes) PASS")


func _run_live_clip_recording() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("--record-clip requires a rendered Forward+ viewport")
		failures += 1
		return

	var abs_live := ProjectSettings.globalize_path(LIVE_DIR)
	DirAccess.make_dir_recursive_absolute(abs_live)
	var d := DirAccess.open(abs_live)
	if d != null:
		for f in d.get_files():
			d.remove(f)

	game = SceneRes.instantiate()
	root.add_child(game)
	current_scene = game
	game.use_script_input = true
	game.script_move_input = Vector2.ZERO

	# Start several seconds south of the clearing cave mouth (around Y=675, wooded rise into clearing!)
	var lim := Route.feet_limits(675.0)
	game.forest_commander.position = Vector2((lim.x + lim.y) * 0.5, 675.0)
	game._forest_facing = Vector2.UP
	game._update_forest_pose(false)
	game.forest_camera.follow(game.forest_commander.position, 0.0, true)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	_recording = true
	_rec_start_usec = Time.get_ticks_usec()
	RenderingServer.frame_post_draw.connect(_on_record_post_draw)

	# 1. Brief opening beat, then walk smoothly north into the clearing toward the cave mouth (~3.2s)
	await _realtime_wait(0.35)
	while game.phase == ForestFight2.Phase.EXPLORE_FOREST and game.forest_commander.position.y > 356.0:
		var c_lim := Route.feet_limits(game.forest_commander.position.y)
		var center_x := (c_lim.x + c_lim.y) * 0.5
		var steer := clampf((center_x - game.forest_commander.position.x) * 0.015, -0.45, 0.45)
		game.script_move_input = Vector2(steer, -1.0)
		await process_frame

	# Pause briefly at the sunlit clearing mouth so the viewer takes in the cave opening (~0.55s)
	game.script_move_input = Vector2.ZERO
	await _realtime_wait(0.55)

	# 2. Walk across threshold under the stone lip & keep holding forward through Beats 1, 2, 3!
	game.script_move_input = Vector2.UP
	while game.phase != ForestFight2.Phase.COMBAT_CAVE:
		await process_frame
	game.script_move_input = Vector2.ZERO

	# 3. Inside cave: step forward-right to middle depth so the player sees responsive profile movement
	await _realtime_move_cave_to(Vector2(470.0, 775.0), 0.75)

	# 4. Let Bat 0 make its first dive pass right into the Commander so we see the incoming tell + blue spark!
	var initial_contacts := game.cave_hero.contact_count
	var wait_contact := 0.0
	while game.cave_hero.contact_count == initial_contacts and wait_contact < 4.5:
		# Track Bat 0's lane so its first swoop visibly contacts her blue armour!
		if is_instance_valid(game.bats[0]):
			var dy := game.bats[0].depth_y - game.cave_hero.depth_y
			game.script_move_input = Vector2(0.0, clampf(dy / 18.0, -1.0, 1.0)) if absf(dy) > 8.0 else Vector2.ZERO
		var dt: float = game.get_process_delta_time()
		wait_contact += dt
		await process_frame
	game.script_move_input = Vector2.ZERO
	await _realtime_wait(0.28)

	# 5. Actively reposition into diving/swooping bats' lanes and fire horizontal shots until all 3 die!
	var combat_elapsed := 0.0
	while not game.cave_is_clear and combat_elapsed < 14.0:
		var best_bat: AlienBat2D = null
		var best_score := 99999.0
		for b in game.bats:
			if is_instance_valid(b) and b.alive:
				var state_bonus := 0.0 if (b.state == AlienBat2D.State.SWOOP_PASS or b.state == AlienBat2D.State.DIVE_TELL) else 260.0
				var score := state_bonus + absf(b.altitude - AlienBat2D.RIFLE_PASS_ALTITUDE) + absf(b.depth_y - game.cave_hero.depth_y) * 0.5
				if score < best_score:
					best_score = score
					best_bat = b

		if best_bat != null:
			var desired_x := clampf(
				best_bat.position.x + (-290.0 if best_bat.position.x > 520.0 else 290.0),
				200.0,
				1260.0
			)
			var dx := desired_x - game.cave_hero.position.x
			var dy := best_bat.depth_y - game.cave_hero.depth_y
			var move_cmd := Vector2.ZERO
			if absf(dx) > 28.0:
				move_cmd.x = signf(dx)
			else:
				# Face the bat!
				var face_dir := 1.0 if best_bat.position.x >= game.cave_hero.position.x else -1.0
				if game.cave_hero.combat_facing != int(face_dir):
					move_cmd.x = face_dir
			if absf(dy) > 12.0:
				move_cmd.y = signf(dy)
			game.script_move_input = move_cmd

			var in_lane := absf(best_bat.depth_y - game.cave_hero.depth_y) <= 28.0
			var in_alt := absf(best_bat.altitude - game.cave_hero.muzzle_altitude()) <= 54.0
			var facing_bat := (best_bat.position.x - game.cave_hero.position.x) * float(game.cave_hero.combat_facing) > 35.0
			if in_lane and in_alt and facing_bat:
				game.fire_player_rifle()
		else:
			game.script_move_input = Vector2.ZERO

		combat_elapsed += game.get_process_delta_time()
		await process_frame

	game.script_move_input = Vector2.ZERO
	await _realtime_wait(1.15)

	RenderingServer.frame_post_draw.disconnect(_on_record_post_draw)
	_recording = false
	var wall_secs := (Time.get_ticks_usec() - _rec_start_usec) / 1e6
	print("Recorded %d frames (%.2f s at 30 fps, dupes=%d) | contacts=%d | kills=%d | clear=%s" % [
		_rec_frame, wall_secs, _rec_dupes, game.cave_hero.contact_count, game.bats_killed, game.cave_is_clear
	])
	_check(game.cave_hero.contact_count >= 1, "clip includes at least 1 visible bat contact")
	_check(game.bats_killed == 3 and game.cave_is_clear, "clip clears all 3 bats")


func _realtime_wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		t += game.get_process_delta_time()
		await process_frame


func _realtime_move_cave_to(target: Vector2, max_time: float) -> void:
	var t := 0.0
	while t < max_time and game.cave_hero != null:
		var d := target - game.cave_hero.position
		if d.length() < 12.0:
			break
		game.script_move_input = d.normalized()
		t += game.get_process_delta_time()
		await process_frame
	game.script_move_input = Vector2.ZERO


func _on_record_post_draw() -> void:
	if not _recording:
		return
	var elapsed := (Time.get_ticks_usec() - _rec_start_usec) / 1e6
	var fnum := floori(elapsed * RECORD_FPS)
	if fnum < _rec_frame:
		return
	var img := root.get_texture().get_image()
	var jpg := img.save_jpg_to_buffer(0.95)
	if _last_jpg.is_empty():
		_last_jpg = jpg
	while _rec_frame < fnum:
		_write_live_jpg(_last_jpg)
		_rec_dupes += 1
	_write_live_jpg(jpg)
	_last_jpg = jpg


func _write_live_jpg(buf: PackedByteArray) -> void:
	var f := FileAccess.open(LIVE_DIR + "%05d.jpg" % _rec_frame, FileAccess.WRITE)
	if f != null:
		f.store_buffer(buf)
	_rec_frame += 1


func _walk_forest_to_y(target_y: float) -> void:
	var sign_y := -1.0 if target_y < game.forest_commander.position.y else 1.0
	for tick in 1100:
		var feet := game.forest_commander.position
		var rem := sign_y * (target_y - feet.y)
		if rem <= 0.5:
			break
		var lim := Route.feet_limits(feet.y)
		var center_x := (lim.x + lim.y) * 0.5
		var steer := clampf((center_x - feet.x) * 0.015, -0.6, 0.6)
		await physics_frame
		game.step_sequence(Vector2(steer, sign_y), 1.0 / 60.0)
	game.step_sequence(Vector2.ZERO, 1.0 / 60.0)


func _measure_cave_raster_height() -> void:
	var boot_screen := Vector2i(game.cave_hero.get_global_transform_with_canvas().origin)
	var region := Rect2i(
		clampi(boot_screen.x - 160, 0, int(Route.VIEW.x) - 320),
		clampi(boot_screen.y - 310, 0, int(Route.VIEW.y) - 330),
		320,
		330
	)
	await RenderingServer.frame_post_draw
	var with_hero := root.get_texture().get_image().get_region(region)
	game.cave_hero.sprite.hide()
	await RenderingServer.frame_post_draw
	var without_hero := root.get_texture().get_image().get_region(region)
	game.cave_hero.sprite.show()
	await RenderingServer.frame_post_draw

	var top_r := region.size.y
	var bot_r := -1
	for y in region.size.y:
		for x in region.size.x:
			var a := with_hero.get_pixel(x, y)
			var b := without_hero.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 0.05:
				top_r = mini(top_r, y)
				bot_r = y
				break
	var raster_h := bot_r - top_r + 1
	print("Measured cave Commander raster height = %d px (%.2f%% of 768)" % [
		raster_h, 100.0 * float(raster_h) / Route.VIEW.y
	])
	_check(raster_h >= 266 and raster_h <= 286, "rasterized Commander height matches Image 1 target (266-286 px)")


func _save_still(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	_check(img.get_size() == Vector2i(Route.VIEW), "still size is 1376x768")
	var err := img.save_png(ProjectSettings.globalize_path(CAPTURE_DIR + filename))
	_check(err == OK, "saved " + filename)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		push_error("CHECK FAILED: " + msg)
