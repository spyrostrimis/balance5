extends SceneTree
## Automated verification, Forward+ still capture, and real-time MP4 recorder
## for “2D Painted Forest Fight 3” (res://scenes/forest_fight_3/forest_fight_3.tscn).

const SCENE_PATH := "res://scenes/forest_fight_3/forest_fight_3.tscn"
const OPENING_PATH := "res://scenes/ui/opening_screen.tscn"
const SceneRes := preload(SCENE_PATH)

const CAPTURE_DIR := "res://render_captures/forest_fight_3/"
const LIVE_DIR := CAPTURE_DIR + "live_frames/"
const RECORD_FPS := 30.0

var game: ForestFight3
var failures: int = 0
var observed_stages: Array[String] = []

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
		await _run_live_clip()
		quit(0 if failures == 0 else 1)
		return

	await _run_verification("--stills" in args and rendered, "--catalog" in args)
	print("Forest Fight 3 verification %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _run_verification(capture_stills: bool, run_catalog: bool) -> void:
	game = SceneRes.instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.stage_changed.connect(func(s: String) -> void: observed_stages.append(s))

	var rendered := DisplayServer.get_name() != "headless"
	print("ForestFight3 | driver=%s | method=%s | viewport=%s" % [
		RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_current_rendering_method(),
		root.get_visible_rect().size,
	])
	if rendered:
		_check(root.get_visible_rect().size == ForestFight3.VIEW_SIZE, "viewport matches 1376x768")
		_check(RenderingServer.get_current_rendering_method() == "forward_plus", "Forward+ active")

	# 1. Unified single-mode opening checks: constant zoom=1.0, constant scale, 360° firing ALREADY live in forest!
	_check(game.stage == ForestFight3.Stage.FOREST, "opens in FOREST stage")
	_check(game.iso_camera.zoom == Vector2.ONE, "camera zoom locked to 1.0")
	var start_h := game.hero.rendered_height_px()
	_check(absf(start_h - 144.64) < 0.5, "Commander height ~145 px (18.8% of 768)")

	if capture_stills:
		await _save_still("01_iso_forest_start.png")

	# Verify all 8 compass aiming directions & live firing right on the forest trail!
	for oct in 8:
		var ang := float(oct) * (PI * 0.25)
		var dir_v := Vector2(cos(ang), sin(ang))
		game.hero._cooldown_timer = 0.0
		var b := game.hero.fire_shot_in_direction(dir_v)
		_check(b != null and b.dir_2d.distance_to(dir_v) < 0.01, "fires 360° bolt in octant %d" % oct)
		if is_instance_valid(b):
			b.queue_free()

	# 2. Sleeping bat under the sunlit tree branch: walk near so it's clearly visible while asleep, then wake & shoot!
	_check(
		game.forest_sleeping_bat != null and game.forest_sleeping_bat.state == IsoBat2D.State.SLEEPING_BRANCH,
		"bat starts sleeping upside-down under tree branch"
	)
	await _walk_to_point(Vector2(835.0, 575.0))
	for settle in 24:
		await physics_frame
		game.step_sequence(Vector2.ZERO, 1.0 / 60.0)
	_check(game.forest_sleeping_bat.state == IsoBat2D.State.SLEEPING_BRANCH, "still asleep at ~240 px distance")
	if capture_stills:
		await _save_still("02_sleeping_branch_bat.png")

	# Walk closer (<= 175 px) -> wakes up and dives!
	await _walk_to_point(Vector2(935.0, 515.0))
	_check(game.forest_sleeping_bat.state != IsoBat2D.State.SLEEPING_BRANCH, "sleeping bat wakes up when approached")

	# Advance until it swoops down to rifle altitude, then aim 360° at its body and kill in 1 shot!
	for tick in 95:
		await physics_frame
		game.step_sequence(Vector2.ZERO, 1.0 / 60.0)
		if absf(game.forest_sleeping_bat.altitude - IsoCommander2D.RIFLE_ALTITUDE) <= 34.0:
			break
	game.hero._cooldown_timer = 0.0
	var branch_shot := game.hero.fire_at_world_point(
		Vector2(game.forest_sleeping_bat.position.x, game.forest_sleeping_bat.position.y - game.forest_sleeping_bat.altitude)
	)
	_check(branch_shot != null, "fired 360° shot at awakened branch bat")
	if capture_stills:
		await _save_still("03_branch_bat_ambush_shot.png")
	for tick in 50:
		game.step_sequence(Vector2.ZERO, 1.0 / 60.0)
		if game.forest_bat_killed:
			break
	_check(game.forest_bat_killed, "awakened forest branch bat dies in one aimed shot")

	# 3. Approach NE cave mouth, stop, back away, then cross under stone arch into Miyazaki cavern!
	await _walk_to_point(Vector2(1480.0, 345.0))
	_check(game.stage == ForestFight3.Stage.FOREST, "approaching cave mouth allows stopping before entry")
	await _walk_to_point(Vector2(1380.0, 405.0))
	_check(game.stage == ForestFight3.Stage.FOREST, "backing away SW from cave mouth works cleanly")

	observed_stages.clear()
	var saved_arch := false
	for tick in 260:
		await physics_frame
		game.step_sequence(Vector2(0.86, -0.52), 1.0 / 60.0)
		if capture_stills and not saved_arch and game.stage == ForestFight3.Stage.DISSOLVE_TO_CAVERN and game._transition_timer >= 0.16:
			saved_arch = true
			await _save_still("04_iso_forest_cave_arch.png")
		if game.stage == ForestFight3.Stage.CAVERN:
			break

	_check(
		observed_stages == ["DISSOLVE_TO_CAVERN", "CAVERN_EMERGE", "CAVERN"],
		"seamless dissolve into Miyazaki cavern fired once (%s)" % [str(observed_stages)]
	)

	# 4. Verify 100% identical camera zoom, hero scale, and controls inside Miyazaki Cavern!
	_check(game.iso_camera.zoom == Vector2.ONE, "cavern keeps identical zoom=1.0")
	_check(is_equal_approx(game.hero.rendered_height_px(), start_h), "cavern keeps identical hero pixel height")
	_check(game.hero.controls_enabled and game.active_bats.size() == 3, "3 cavern bats spawned & controls active")

	# High-altitude miss test: bat hovering at altitude=205 survives bolt fired directly underneath its ground pos!
	for b in game.active_bats:
		b.combat_active = false
		b.altitude = 205.0
	var b0: IsoBat2D = game.active_bats[0]
	game.hero.position = Vector2(780.0, 720.0)
	b0.position = Vector2(980.0, 620.0)
	game.hero._cooldown_timer = 0.0
	var under_bolt := game.hero.fire_shot_in_direction((b0.position - game.hero.position).normalized())
	for tick in 45:
		if not is_instance_valid(under_bolt) or under_bolt.spent:
			break
		under_bolt.step_bolt(1.0 / 60.0)
	_check(b0.alive and not under_bolt.hit_bat, "high-orbit bat survives shot passing beneath it")

	# Capture dreamy Miyazaki cavern combat framing with all 3 bats visible!
	game.hero.position = Vector2(790.0, 745.0)
	game.hero.aim_dir = Vector2(0.866, -0.5).normalized()
	game.hero._apply_visuals(false)
	game.active_bats[0].position = Vector2(1135.0, 565.0)
	game.active_bats[0].altitude = 155.0
	game.active_bats[0]._update_visuals()
	game.active_bats[1].position = Vector2(655.0, 615.0)
	game.active_bats[1].altitude = 165.0
	game.active_bats[1]._update_visuals()
	game.active_bats[2].position = Vector2(1065.0, 760.0)
	game.active_bats[2]._vel_dir = Vector2(-0.7, -0.7)
	game.active_bats[2].altitude = 145.0
	game.active_bats[2]._update_visuals()
	game._snap_camera_to_hero()
	if capture_stills:
		await _save_still("05_miyazaki_cavern_combat.png")

	# Harmless bat contact spark check (1 contact per pass, zero health loss)
	b0.combat_active = true
	b0.state = IsoBat2D.State.SWOOP_PASS
	b0._swoop_start = game.hero.position - Vector2(140.0, 80.0)
	b0._swoop_end = game.hero.position + Vector2(140.0, 80.0)
	b0._swoop_duration = 0.50
	b0._timer = 0.50
	b0.contacted_this_pass = false
	var prior_contacts := game.hero.contact_count
	for tick in 35:
		game.step_sequence(Vector2.ZERO, 1.0 / 60.0)
	_check(game.hero.contact_count == prior_contacts + 1, "cavern bat swoop registers 1 harmless armour spark")

	# Shoot all 3 cavern bats from 3 distinct 360° angles (NE, NW, SE)!
	var offsets_test: Array[Vector2] = [
		Vector2(210.0, -115.0),
		Vector2(-185.0, -105.0),
		Vector2(195.0, 110.0),
	]
	for i in 3:
		var cb: IsoBat2D = game.active_bats[i]
		cb.combat_active = false
		cb.position = game.hero.position + offsets_test[i]
		cb.altitude = IsoBat2D.RIFLE_ALTITUDE
		cb.state = IsoBat2D.State.SWOOP_PASS
		cb._update_visuals()
		game.hero._cooldown_timer = 0.0
		var shot := game.hero.fire_at_world_point(Vector2(cb.position.x, cb.position.y - cb.altitude))
		_check(shot != null, "fired 360° shot at cavern bat %d" % i)
		for tick in 45:
			game.step_sequence(Vector2.ZERO, 1.0 / 60.0)
			if not cb.alive:
				break
		_check(not cb.alive, "cavern bat %d dies in one shot" % i)

	for tick in 45:
		await physics_frame
		game.step_sequence(Vector2.ZERO, 1.0 / 60.0)
	_check(game.cavern_bats_killed == 3 and game.cavern_is_clear, "Cavern clear triggered after 3rd kill")

	if capture_stills:
		game.clear_label.modulate.a = 1.0
		await RenderingServer.frame_post_draw
		await _save_still("06_cavern_clear.png")

	# Verify R reset & catalog Play + Esc round-trip
	game.reset_sequence()
	_check(game.stage == ForestFight3.Stage.FOREST and game.cavern_bats_killed == 0, "R resets cleanly")

	if run_catalog:
		await _verify_catalog_roundtrip()


func _verify_catalog_roundtrip() -> void:
	for test_in_cavern in [false, true]:
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
					_check(current_scene is ForestFight3, "Developers Page opens ForestFight3")
					if test_in_cavern:
						var ff := current_scene as ForestFight3
						ff.set_physics_process(false)
						ff._enter_cavern_stage()
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
		_check(found, "Developers Page lists 2D Painted Forest Fight 3 Play card")
	print("Catalog Play + Esc (both stages) PASS")


func _run_live_clip() -> void:
	if DisplayServer.get_name() == "headless":
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

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	_recording = true
	_rec_start_usec = Time.get_ticks_usec()
	RenderingServer.frame_post_draw.connect(_on_record_post_draw)

	# 1. Start on the isometric stone steps, walk NE up the trail until the sleeping bat wakes up!
	await _rt_wait(0.25)
	while is_instance_valid(game.forest_sleeping_bat) and game.forest_sleeping_bat.state == IsoBat2D.State.SLEEPING_BRANCH:
		game.script_move_input = (Vector2(1045.0, 465.0) - game.hero.position).normalized()
		await process_frame

	# Pause & backstep slightly as the branch bat startles awake and dives, then shoot it in 360°!
	game.script_move_input = Vector2(-0.5, 0.3)
	await _rt_wait(0.35)
	game.script_move_input = Vector2.ZERO
	var forest_combat_t := 0.0
	while not game.forest_bat_killed and forest_combat_t < 3.5:
		if is_instance_valid(game.forest_sleeping_bat) and game.forest_sleeping_bat.alive:
			var fb := game.forest_sleeping_bat
			game.hero.aim_toward_world_point(Vector2(fb.position.x, fb.position.y - fb.altitude))
			if absf(fb.altitude - IsoCommander2D.RIFLE_ALTITUDE) <= 52.0:
				game.hero.fire_at_world_point(Vector2(fb.position.x, fb.position.y - fb.altitude))
		forest_combat_t += game.get_process_delta_time()
		await process_frame

	await _rt_wait(0.25)

	# 2. Continue NE up the sunlit forest trail and cross under the stone cave arch!
	while game.stage == ForestFight3.Stage.FOREST:
		var target_mouth := Vector2(1595.0, 275.0)
		game.script_move_input = (target_mouth - game.hero.position).normalized()
		await process_frame

	while game.stage != ForestFight3.Stage.CAVERN:
		await process_frame
	game.script_move_input = Vector2.ZERO

	# 3. Walk out onto the Miyazaki pastel cavern terrace and let the first bat brush her blue armour!
	await _rt_move_to(Vector2(780.0, 735.0), 1.15)
	var pre_contacts := game.hero.contact_count
	var wait_c := 0.0
	while game.hero.contact_count == pre_contacts and wait_c < 3.8:
		if is_instance_valid(game.active_bats[0]):
			var to_b := game.active_bats[0].position - game.hero.position
			game.script_move_input = to_b.normalized() * 0.65 if to_b.length() > 18.0 else Vector2.ZERO
		wait_c += game.get_process_delta_time()
		await process_frame
	game.script_move_input = Vector2.ZERO
	await _rt_wait(0.20)

	# 4. Roam freely in isometric space and shoot all 3 swooping cavern bats across 360°!
	var cav_t := 0.0
	while not game.cavern_is_clear and cav_t < 13.0:
		var target_bat: IsoBat2D = null
		var best_sc := 99999.0
		for b in game.active_bats:
			if is_instance_valid(b) and b.alive:
				var sc := absf(b.altitude - IsoCommander2D.RIFLE_ALTITUDE) + (0.0 if b.state == IsoBat2D.State.SWOOP_PASS else 180.0)
				if sc < best_sc:
					best_sc = sc
					target_bat = b

		if target_bat != null:
			# Strafe gently across the sunny cavern terrace while aiming 360° at the swooping bat!
			var perp := Vector2(-(target_bat.position.y - game.hero.position.y), target_bat.position.x - game.hero.position.x).normalized()
			game.script_move_input = perp * 0.55
			var aim_pt := Vector2(target_bat.position.x, target_bat.position.y - target_bat.altitude)
			game.hero.aim_toward_world_point(aim_pt)
			if absf(target_bat.altitude - IsoCommander2D.RIFLE_ALTITUDE) <= 50.0 and target_bat.position.distance_to(game.hero.position) > 65.0:
				game.hero.fire_at_world_point(aim_pt)
		else:
			game.script_move_input = Vector2.ZERO

		cav_t += game.get_process_delta_time()
		await process_frame

	game.script_move_input = Vector2.ZERO
	await _rt_wait(1.05)

	RenderingServer.frame_post_draw.disconnect(_on_record_post_draw)
	_recording = false
	var secs := (Time.get_ticks_usec() - _rec_start_usec) / 1e6
	print("Recorded %d frames (%.2f s at 30 fps, dupes=%d) | forestKill=%s | contacts=%d | cavernKills=%d | clear=%s" % [
		_rec_frame, secs, _rec_dupes, game.forest_bat_killed, game.hero.contact_count, game.cavern_bats_killed, game.cavern_is_clear
	])
	_check(game.forest_bat_killed, "clip shows waking & defeating forest tree-branch bat")
	_check(game.cavern_bats_killed == 3 and game.cavern_is_clear, "clip clears all 3 Miyazaki cavern bats")


func _walk_to_point(target: Vector2) -> void:
	for tick in 900:
		var d := target - game.hero.position
		if d.length() <= 6.0:
			break
		await physics_frame
		game.step_sequence(d.normalized(), 1.0 / 60.0)
	game.step_sequence(Vector2.ZERO, 1.0 / 60.0)


func _rt_wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		t += game.get_process_delta_time()
		await process_frame


func _rt_move_to(target: Vector2, max_secs: float) -> void:
	var t := 0.0
	while t < max_secs:
		var d := target - game.hero.position
		if d.length() <= 14.0:
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
	var jpg := root.get_texture().get_image().save_jpg_to_buffer(0.95)
	if _last_jpg.is_empty():
		_last_jpg = jpg
	while _rec_frame < fnum:
		_write_jpg(_last_jpg)
		_rec_dupes += 1
	_write_jpg(jpg)
	_last_jpg = jpg


func _write_jpg(buf: PackedByteArray) -> void:
	var f := FileAccess.open(LIVE_DIR + "%05d.jpg" % _rec_frame, FileAccess.WRITE)
	if f != null:
		f.store_buffer(buf)
	_rec_frame += 1


func _save_still(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	_check(img.get_size() == Vector2i(ForestFight3.VIEW_SIZE), "still is 1376x768")
	var err := img.save_png(ProjectSettings.globalize_path(CAPTURE_DIR + filename))
	_check(err == OK, "saved " + filename)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		push_error("CHECK FAILED: " + msg)
