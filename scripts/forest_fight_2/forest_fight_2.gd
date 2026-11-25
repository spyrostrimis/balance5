class_name ForestFight2
extends Node2D
## Continuous playable sequence for “2D Painted Forest Fight 2”:
## 1. EXPLORE_FOREST: Walk the painted tropical forest trail to the clearing cave mouth.
## 2. TRANSITION_BEAT_1: Cross threshold (Y <= 312); boots & silhouette pass under the rock lip into shadow.
## 3. TRANSITION_BEAT_2: Cut inside the sunlit left cave archway; step in & settle into right-facing rifle stance.
## 4. TRANSITION_BEAT_3: Ease camera out to the Streets of Rage 4 (Image 1) chamber view; awaken 3 alien bats.
## 5. COMBAT_CAVE: Free X+depth movement, strictly left/right profile & horizontal rifle, 3 one-shot bats, zero harm.

signal mode_transitioned(new_phase_name: String)
signal cave_cleared

enum Phase {
	EXPLORE_FOREST = 0,
	TRANSITION_BEAT_1 = 1,
	TRANSITION_BEAT_2 = 2,
	TRANSITION_BEAT_3 = 3,
	COMBAT_CAVE = 4,
}

const Route := preload("res://scripts/forest_fight_2/forest_fight_2_route.gd")

const FOREST_SPEED := Vector2(218.0, 174.0)
const FOREST_FPS := 7.6
const FOREST_IDLE_HEIGHT := 149.0

const CAVE_CAM_DOORWAY_POS := Vector2(565.0, 578.0)
const CAVE_CAM_DOORWAY_ZOOM := Vector2(1.24, 1.24)
const CAVE_CAM_CHAMBER_Y := 590.0
const CAVE_CAM_MIN_X := 688.0
const CAVE_CAM_MAX_X := 848.0

var phase: Phase = Phase.EXPLORE_FOREST
var guides: bool = false
var cave_is_clear: bool = false
var bats_killed: int = 0
var use_script_input: bool = false
var script_move_input: Vector2 = Vector2.ZERO

var _forest_stride_phase: float = 0.0
var _forest_facing: Vector2 = Vector2.DOWN
var _beat_timer: float = 0.0
var _beat1_start_pos := Vector2.ZERO
var _beat3_cam_start := CAVE_CAM_DOORWAY_POS
var _clear_delay_timer: float = -1.0

var _window: Window
var _original_title: String
var _original_size: Vector2i
var _original_scale_size: Vector2i
var _original_scale_mode: Window.ContentScaleMode
var _original_scale_aspect: Window.ContentScaleAspect

@onready var forest_stage: Node2D = $ForestStage
@onready var forest_painting: Sprite2D = $ForestStage/Painting
@onready var forest_commander: Node2D = $ForestStage/Commander
@onready var forest_pose: Sprite2D = $ForestStage/Commander/Pose
@onready var forest_shadow: Sprite2D = $ForestStage/Commander/Shadow
@onready var forest_cave_lip: Sprite2D = $ForestStage/CaveLip
@onready var forest_camera = $ForestStage/ForestCamera

@onready var cave_stage: Node2D = $CaveStage
@onready var cave_bg: Sprite2D = $CaveStage/ChamberBG
@onready var cave_actors: Node2D = $CaveStage/Actors
@onready var cave_rim: Sprite2D = $CaveStage/ForegroundRim
@onready var cave_camera: Camera2D = $CaveStage/CaveCamera

@onready var wipe_curtain: ColorRect = $HUD/DoorwayCurtain
@onready var mode_badge: Label = $HUD/ModeBadge
@onready var controls_label: Label = $HUD/ControlsLabel
@onready var cave_clear_label: Label = $HUD/CaveClearLabel
@onready var debug_readout: Label = $HUD/DebugReadout

var cave_hero: CaveCommander2D = null
var bats: Array[AlienBat2D] = []


func _ready() -> void:
	_window = get_window()
	_original_title = _window.title
	_original_size = _window.size
	_original_scale_size = _window.content_scale_size
	_original_scale_mode = _window.content_scale_mode
	_original_scale_aspect = _window.content_scale_aspect

	_window.title = "Balance · 2D Painted Forest Fight 2"
	_window.content_scale_size = Vector2i(Route.VIEW)
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_window.size = Vector2i(Route.VIEW)

	forest_pose.scale = Vector2.ONE * Route.START_HEIGHT / FOREST_IDLE_HEIGHT
	forest_painting.scale = Route.CANVAS / forest_painting.texture.get_size()

	reset_sequence()


func _exit_tree() -> void:
	if is_instance_valid(_window):
		_window.title = _original_title
		_window.content_scale_size = _original_scale_size
		_window.content_scale_mode = _original_scale_mode
		_window.content_scale_aspect = _original_scale_aspect
		_window.size = _original_size


func reset_sequence() -> void:
	_clear_cave_entities()
	phase = Phase.EXPLORE_FOREST
	cave_is_clear = false
	bats_killed = 0
	_clear_delay_timer = -1.0
	_beat_timer = 0.0

	forest_stage.visible = true
	cave_stage.visible = false
	forest_camera.enabled = true
	cave_camera.enabled = false
	wipe_curtain.color.a = 0.0
	cave_clear_label.visible = false
	cave_clear_label.modulate.a = 0.0

	var limits := Route.feet_limits(Route.START_Y)
	forest_commander.position = Vector2((limits.x + limits.y) * 0.5, Route.START_Y)
	forest_commander.modulate = Color.WHITE
	_forest_facing = Vector2.DOWN
	_forest_stride_phase = 0.0
	_update_forest_pose(false)
	forest_camera.follow(forest_commander.position, 0.0, true)

	_update_hud_text()
	queue_redraw()


func _clear_cave_entities() -> void:
	for child in cave_actors.get_children():
		child.queue_free()
	cave_hero = null
	bats.clear()


func _spawn_cave_encounter() -> void:
	_clear_cave_entities()
	cave_hero = CaveCommander2D.new()
	cave_hero.name = "CaveCommander"
	cave_hero.actors_host = cave_actors
	cave_actors.add_child(cave_hero)
	cave_hero.set_floor_position(Vector2(138.0, 725.0), 1)
	cave_hero.controls_enabled = false

	for i in 3:
		var bat := AlienBat2D.new()
		bat.name = "AlienBat_%d" % i
		cave_actors.add_child(bat)
		bat.setup(i, cave_hero)
		bat.died.connect(_on_bat_died)
		bats.append(bat)

	cave_hero.bats_ref = bats


func _physics_process(delta: float) -> void:
	var move_dir := script_move_input if use_script_input else _read_keyboard_direction()
	step_sequence(move_dir, delta)


func _read_keyboard_direction() -> Vector2:
	var left := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var up := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	return Vector2(float(right) - float(left), float(down) - float(up))


func step_sequence(input_dir: Vector2, delta: float) -> void:
	match phase:
		Phase.EXPLORE_FOREST:
			_step_forest_explore(input_dir, delta)
		Phase.TRANSITION_BEAT_1:
			_step_beat_1(delta)
		Phase.TRANSITION_BEAT_2:
			_step_beat_2(delta)
		Phase.TRANSITION_BEAT_3:
			_step_beat_3(delta)
		Phase.COMBAT_CAVE:
			_step_cave_combat(input_dir, delta)

	if guides:
		_update_debug_readout()


func _step_forest_explore(input_dir: Vector2, delta: float) -> void:
	var prev := forest_commander.position
	var ratio := Route.figure_scale(prev.y)
	var next := prev + input_dir.limit_length(1.0) * FOREST_SPEED * ratio * delta
	next.y = clampf(next.y, Route.CAVE_THROAT_Y, Route.SOUTH_Y)
	var limits := Route.feet_limits(next.y)
	next.x = clampf(next.x, limits.x, limits.y)

	var travel := next - prev
	forest_commander.position = next
	if not input_dir.is_zero_approx():
		_forest_facing = input_dir.normalized()

	var moving := travel.length_squared() > 0.0001
	if moving:
		_forest_stride_phase = fposmod(
			_forest_stride_phase + (travel / FOREST_SPEED).length() * FOREST_FPS / ratio,
			4.0
		)
	_update_forest_pose(moving)

	# Subtle shadow darkening right at the mouth lip (Y 345 -> 312) before committing
	var mouth_shade := clampf(inverse_lerp(348.0, Route.CAVE_THRESHOLD_Y, next.y), 0.0, 1.0)
	forest_commander.modulate = Color.WHITE.lerp(Color(0.76, 0.78, 0.82, 1.0), mouth_shade)

	forest_camera.follow(next, delta)

	if next.y <= Route.CAVE_THRESHOLD_Y:
		_begin_beat_1()


func _begin_beat_1() -> void:
	phase = Phase.TRANSITION_BEAT_1
	_beat_timer = 0.0
	_beat1_start_pos = forest_commander.position
	_forest_facing = Vector2.UP
	_update_hud_text()
	mode_transitioned.emit("TRANSITION_BEAT_1")


func _step_beat_1(delta: float) -> void:
	# Beat 1 (0.58s): Her boots and silhouette walk under the overhanging stone lip into cave darkness.
	const DURATION := 0.58
	_beat_timer += delta
	var t := clampf(_beat_timer / DURATION, 0.0, 1.0)

	var target := Vector2(Route.CAVE_CENTER_X, Route.CAVE_THROAT_Y)
	var next := _beat1_start_pos.lerp(target, t)
	var travel := next - forest_commander.position
	forest_commander.position = next
	var ratio := Route.figure_scale(next.y)
	_forest_facing = Vector2.UP
	if travel.length_squared() > 0.0001:
		_forest_stride_phase = fposmod(
			_forest_stride_phase + (travel / FOREST_SPEED).length() * FOREST_FPS / ratio,
			4.0
		)
	_update_forest_pose(t < 0.96)

	# Darken into the cave throat shadow as the foreground CaveLip sprite occludes her head & torso
	var throat_dark := clampf(inverse_lerp(0.05, 0.88, t), 0.0, 1.0)
	var fade_alpha := clampf(1.0 - inverse_lerp(0.72, 0.98, t), 0.0, 1.0)
	forest_commander.modulate = Color(
		lerpf(0.76, 0.08, throat_dark),
		lerpf(0.78, 0.10, throat_dark),
		lerpf(0.82, 0.14, throat_dark),
		fade_alpha
	)
	wipe_curtain.color.a = clampf(inverse_lerp(0.52, 0.98, t), 0.0, 1.0)

	if t >= 1.0:
		_begin_beat_2()


func _begin_beat_2() -> void:
	# Beat 2 (0.68s): Cut inside the sunlit left cave entrance; step out of golden daylight into profile stance.
	phase = Phase.TRANSITION_BEAT_2
	_beat_timer = 0.0
	_spawn_cave_encounter()

	forest_stage.visible = false
	cave_stage.visible = true
	forest_camera.enabled = false
	cave_camera.enabled = true
	cave_camera.position = CAVE_CAM_DOORWAY_POS
	cave_camera.zoom = CAVE_CAM_DOORWAY_ZOOM
	cave_camera.force_update_scroll()

	_update_hud_text()
	mode_transitioned.emit("TRANSITION_BEAT_2")


func _step_beat_2(delta: float) -> void:
	const DURATION := 0.68
	_beat_timer += delta
	var t := clampf(_beat_timer / DURATION, 0.0, 1.0)

	# Lift doorway shadow curtain quickly so we see warm forest daylight behind her
	wipe_curtain.color.a = 1.0 - clampf(t / 0.34, 0.0, 1.0)

	if cave_hero != null:
		cave_hero.step_scripted_walk(Vector2(312.0, 770.0), 305.0, delta)
	for bat in bats:
		if is_instance_valid(bat):
			bat.step_bat(delta)

	if t >= 1.0:
		_begin_beat_3()


func _begin_beat_3() -> void:
	# Beat 3 (0.72s): Settle into combat stance & ease camera out to the Image 1 chamber framing.
	phase = Phase.TRANSITION_BEAT_3
	_beat_timer = 0.0
	_beat3_cam_start = cave_camera.position
	wipe_curtain.color.a = 0.0
	if cave_hero != null:
		cave_hero.set_floor_position(Vector2(312.0, 770.0), 1)
	_update_hud_text()
	mode_transitioned.emit("TRANSITION_BEAT_3")


func _step_beat_3(delta: float) -> void:
	const DURATION := 0.72
	_beat_timer += delta
	var t := clampf(_beat_timer / DURATION, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)

	var target_cam := Vector2(_desired_cave_cam_x(), CAVE_CAM_CHAMBER_Y)
	cave_camera.position = _beat3_cam_start.lerp(target_cam, eased)
	cave_camera.zoom = CAVE_CAM_DOORWAY_ZOOM.lerp(Vector2.ONE, eased)
	cave_camera.force_update_scroll()

	for bat in bats:
		if is_instance_valid(bat):
			bat.step_bat(delta)

	if t >= 1.0:
		_begin_cave_combat()


func _begin_cave_combat() -> void:
	phase = Phase.COMBAT_CAVE
	cave_camera.zoom = Vector2.ONE
	cave_camera.position = Vector2(_desired_cave_cam_x(), CAVE_CAM_CHAMBER_Y)
	cave_camera.force_update_scroll()

	if cave_hero != null:
		cave_hero.controls_enabled = true

	# Stagger initial dive delays (>= 1.15s grace window so the player moves freely before any dive!)
	var delays := [1.18, 2.05, 2.90]
	for i in bats.size():
		if is_instance_valid(bats[i]):
			bats[i].awaken_into_chamber(delays[i])

	_update_hud_text()
	mode_transitioned.emit("COMBAT_CAVE")


func _step_cave_combat(input_dir: Vector2, delta: float) -> void:
	if cave_hero != null:
		cave_hero.step_combat(input_dir, delta)

	for child in cave_actors.get_children():
		if child is ForestFight2Bolt:
			(child as ForestFight2Bolt).step_bolt(delta)

	for bat in bats:
		if is_instance_valid(bat):
			bat.step_bat(delta)

	var target_x := _desired_cave_cam_x()
	cave_camera.position.x = lerpf(cave_camera.position.x, target_x, 1.0 - exp(-9.0 * delta))
	cave_camera.position.y = CAVE_CAM_CHAMBER_Y
	cave_camera.force_update_scroll()

	if _clear_delay_timer > 0.0:
		_clear_delay_timer -= delta
		if _clear_delay_timer <= 0.0 and not cave_is_clear:
			cave_is_clear = true
			cave_clear_label.visible = true
			var tw := create_tween()
			tw.tween_property(cave_clear_label, "modulate:a", 1.0, 0.35)
			_update_hud_text()
			cave_cleared.emit()


func _desired_cave_cam_x() -> float:
	if cave_hero == null:
		return 768.0
	# Subtle follow across [688..848] keeps the Image 1 chamber stable while revealing both walls
	var t := clampf(inverse_lerp(180.0, 1340.0, cave_hero.position.x), 0.0, 1.0)
	return lerpf(CAVE_CAM_MIN_X, CAVE_CAM_MAX_X, t)


func _on_bat_died(_bat: AlienBat2D) -> void:
	bats_killed += 1
	_update_hud_text()
	if bats_killed >= 3 and _clear_delay_timer < 0.0:
		_clear_delay_timer = 0.42


func fire_player_rifle() -> ForestFight2Bolt:
	if phase != Phase.COMBAT_CAVE or cave_hero == null:
		return null
	return cave_hero.fire_horizontal_shot()


func _update_forest_pose(moving: bool) -> void:
	forest_commander.scale = Vector2.ONE * Route.figure_scale(forest_commander.position.y)
	var row := 2
	var mirror := _forest_facing.x < 0.0
	if _forest_facing.y < -0.35:
		row = 1
		mirror = _forest_facing.x > 0.15
	elif _forest_facing.y > 0.35:
		row = 0
	var column := 1 + int(_forest_stride_phase) if moving else 0
	forest_pose.frame_coords = Vector2i(column, row)
	forest_pose.flip_h = mirror
	forest_pose.offset.y = -80.0 if row == 1 and column == 1 else -76.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_SPACE, KEY_J:
				if fire_player_rifle() != null:
					get_viewport().set_input_as_handled()
			KEY_G:
				guides = not guides
				debug_readout.visible = guides
				queue_redraw()
				get_viewport().set_input_as_handled()
			KEY_R:
				reset_sequence()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				var launcher := get_node_or_null("/root/BuildLauncher")
				if launcher == null or not launcher.is_build_active():
					get_tree().quit()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if fire_player_rifle() != null:
				get_viewport().set_input_as_handled()


func _update_hud_text() -> void:
	match phase:
		Phase.EXPLORE_FOREST:
			mode_badge.text = "Exploration Mode · Forest Trail"
			controls_label.text = "WASD / Arrows  Walk     ·     R  Restart     ·     Esc  Developers Page"
		Phase.TRANSITION_BEAT_1, Phase.TRANSITION_BEAT_2, Phase.TRANSITION_BEAT_3:
			mode_badge.text = "Entering Cave · Preparing Rifle"
			controls_label.text = "Entering cave chamber…"
		Phase.COMBAT_CAVE:
			var remaining := maxi(0, 3 - bats_killed)
			mode_badge.text = (
				"Fighting Mode · Cave Clear"
				if cave_is_clear
				else "Fighting Mode · Bats remaining: %d" % remaining
			)
			controls_label.text = "WASD / Arrows  Move (Profile)     ·     Space / J / Click  Fire     ·     R  Restart     ·     Esc  Developers Page"


func _update_debug_readout() -> void:
	if phase == Phase.EXPLORE_FOREST or phase == Phase.TRANSITION_BEAT_1:
		debug_readout.text = "Phase=%s | Forest pos=(%.1f, %.1f) | Threshold=%.0f" % [
			Phase.keys()[phase], forest_commander.position.x, forest_commander.position.y, Route.CAVE_THRESHOLD_Y
		]
	elif cave_hero != null:
		debug_readout.text = "Phase=%s | Hero=(%.1f, %.1f) facing=%d height=%.1fpx (%.1f%%) | Kills=%d/3 | Contacts=%d" % [
			Phase.keys()[phase],
			cave_hero.position.x,
			cave_hero.depth_y,
			cave_hero.combat_facing,
			cave_hero.rendered_height_px(),
			100.0 * cave_hero.rendered_height_px() / Route.VIEW.y,
			bats_killed,
			cave_hero.contact_count,
		]
