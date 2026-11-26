class_name ForestFight3
extends Node2D
## “2D Painted Forest Fight 3” — Strictly-Isometric Unified Single-Mode Sequence:
## - Same isometric camera angle, zoom (1.0), constant hero scale (~145 px), and 360° controls everywhere!
## - Stage 1 (FOREST): Walk the sunlit isometric cliff-ridge trail; wake & fight (or dodge) the sleeping
##   bat hanging under the giant tree branch, then cross under the NE stone cave arch.
## - Dissolve: Dreamy 0.62s warm-pastel mist transition into the Miyazaki Cavern.
## - Stage 2 (CAVERN): Emerge from the SW sunlit moss arch at the exact same zoom/angle/scale and fight
##   3 swooping alien-mutant bats from all 360° angles across the sunlit pastel cavern terrace.

signal stage_changed(stage_name: String)
signal cavern_cleared

enum Stage {
	FOREST = 0,
	DISSOLVE_TO_CAVERN = 1,
	CAVERN_EMERGE = 2,
	CAVERN = 3,
}

const VIEW_SIZE := Vector2(1376.0, 768.0)
const CANVAS_SIZE := Vector2(1920.0, 1280.0)
const CAM_LEEWAY := Vector2(40.0, 32.0)
const CAM_FOLLOW_RATE := 10.5
const CAM_LEAD_OFFSET := Vector2(56.0, -96.0)

## Full-width isometric dirt trail polygon on iso_forest_bg.png (1920x1280)
static var FOREST_POLY := PackedVector2Array([
	Vector2(215, 1030), Vector2(315, 930), Vector2(415, 810), Vector2(605, 695),
	Vector2(855, 560), Vector2(1100, 435), Vector2(1335, 325), Vector2(1505, 240),
	Vector2(1695, 225), Vector2(1705, 345), Vector2(1615, 435), Vector2(1405, 560),
	Vector2(1165, 695), Vector2(895, 855), Vector2(675, 975), Vector2(355, 1165),
	Vector2(220, 1105),
])

## Broad Miyazaki pastel cavern terrace polygon on iso_cavern_bg.png (1920x1280)
static var CAVERN_POLY := PackedVector2Array([
	Vector2(150, 935), Vector2(380, 760), Vector2(655, 615), Vector2(960, 470),
	Vector2(1285, 350), Vector2(1595, 265), Vector2(1765, 355), Vector2(1685, 520),
	Vector2(1505, 605), Vector2(1265, 725), Vector2(1015, 865), Vector2(755, 1015),
	Vector2(505, 1105), Vector2(255, 1080), Vector2(145, 995),
])

const FOREST_SPAWN := Vector2(335.0, 1045.0)
const FOREST_BRANCH_GROUND := Vector2(1015.0, 468.0)
const FOREST_BRANCH_ALT := 232.0
const FOREST_CAVE_TARGET := Vector2(1635.0, 248.0)

const CAVERN_ARCH_START := Vector2(185.0, 962.0)
const CAVERN_EMERGE_POS := Vector2(360.0, 885.0)

var stage: Stage = Stage.FOREST
var guides: bool = false
var cavern_is_clear: bool = false
var cavern_bats_killed: int = 0
var forest_bat_killed: bool = false
var use_script_input: bool = false
var script_move_input: Vector2 = Vector2.ZERO

var _transition_timer: float = 0.0
var _dissolve_start_pos := Vector2.ZERO
var _clear_delay: float = -1.0

var _window: Window
var _original_title: String
var _original_size: Vector2i
var _original_scale_size: Vector2i
var _original_scale_mode: Window.ContentScaleMode
var _original_scale_aspect: Window.ContentScaleAspect

@onready var forest_stage: Node2D = $ForestStage
@onready var forest_actors: Node2D = $ForestStage/Actors
@onready var cavern_stage: Node2D = $CaveStage
@onready var cavern_actors: Node2D = $CaveStage/Actors
@onready var iso_camera: Camera2D = $IsoCamera

@onready var mist_curtain: ColorRect = $HUD/PastelMistCurtain
@onready var status_badge: Label = $HUD/StatusBadge
@onready var clear_label: Label = $HUD/CavernClearLabel
@onready var controls_label: Label = $HUD/ControlsLabel
@onready var debug_label: Label = $HUD/DebugReadout

var hero: IsoCommander2D = null
var active_bats: Array[IsoBat2D] = []
var forest_sleeping_bat: IsoBat2D = null


func _ready() -> void:
	_window = get_window()
	_original_title = _window.title
	_original_size = _window.size
	_original_scale_size = _window.content_scale_size
	_original_scale_mode = _window.content_scale_mode
	_original_scale_aspect = _window.content_scale_aspect

	_window.title = "Balance · 2D Painted Forest Fight 3 (Isometric)"
	_window.content_scale_size = Vector2i(VIEW_SIZE)
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_window.size = Vector2i(VIEW_SIZE)

	iso_camera.zoom = Vector2.ONE
	reset_sequence()


func _exit_tree() -> void:
	if is_instance_valid(_window):
		_window.title = _original_title
		_window.content_scale_size = _original_scale_size
		_window.content_scale_mode = _original_scale_mode
		_window.content_scale_aspect = _original_scale_aspect
		_window.size = _original_size


func reset_sequence() -> void:
	_clear_stage_actors()
	stage = Stage.FOREST
	cavern_is_clear = false
	cavern_bats_killed = 0
	forest_bat_killed = false
	_clear_delay = -1.0
	_transition_timer = 0.0

	forest_stage.visible = true
	cavern_stage.visible = false
	mist_curtain.color.a = 0.0
	clear_label.visible = false
	clear_label.modulate.a = 0.0

	hero = IsoCommander2D.new()
	hero.name = "IsoCommander"
	hero.position = FOREST_SPAWN
	hero.aim_dir = Vector2(0.866, -0.5).normalized()
	hero.walk_polygon = FOREST_POLY
	hero.actors_host = forest_actors
	forest_actors.add_child(hero)

	forest_sleeping_bat = IsoBat2D.new()
	forest_sleeping_bat.name = "SleepingBranchBat"
	forest_actors.add_child(forest_sleeping_bat)
	forest_sleeping_bat.setup_sleeping_forest_bat(FOREST_BRANCH_GROUND, FOREST_BRANCH_ALT, hero, FOREST_POLY)
	forest_sleeping_bat.woke_up.connect(func(_b: IsoBat2D) -> void: _update_hud())
	forest_sleeping_bat.died.connect(func(_b: IsoBat2D) -> void:
		forest_bat_killed = true
		_update_hud()
	)

	active_bats = [forest_sleeping_bat]
	hero.bats_ref = active_bats

	_snap_camera_to_hero()
	_update_hud()
	queue_redraw()


func _clear_stage_actors() -> void:
	for c in forest_actors.get_children():
		c.queue_free()
	for c in cavern_actors.get_children():
		c.queue_free()
	hero = null
	active_bats.clear()
	forest_sleeping_bat = null


func _physics_process(delta: float) -> void:
	var move_in := script_move_input if use_script_input else _read_keyboard_move()
	step_sequence(move_in, delta)


func _read_keyboard_move() -> Vector2:
	var left := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var up := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	return Vector2(float(right) - float(left), float(down) - float(up))


func step_sequence(move_dir: Vector2, delta: float) -> void:
	match stage:
		Stage.FOREST:
			_step_forest(move_dir, delta)
		Stage.DISSOLVE_TO_CAVERN:
			_step_dissolve_to_cavern(delta)
		Stage.CAVERN_EMERGE:
			_step_cavern_emerge(delta)
		Stage.CAVERN:
			_step_cavern(move_dir, delta)

	if guides:
		_update_debug()


func _step_forest(move_dir: Vector2, delta: float) -> void:
	hero.step_hero(move_dir, delta)
	_step_bolts_in(forest_actors, delta)
	for b in active_bats:
		if is_instance_valid(b):
			b.step_bat(delta)

	# Darken softly right inside the NE cave throat (x >= 1495, y <= 330)
	var mouth_t := clampf(inverse_lerp(1485.0, 1565.0, hero.position.x), 0.0, 1.0)
	if hero.position.y > 350.0:
		mouth_t = 0.0
	hero.modulate = Color.WHITE.lerp(Color(0.72, 0.75, 0.82, 1.0), mouth_t)

	_follow_camera(hero.position, delta)

	# Trigger cave entry when her boots cross into the NE cave mouth opening!
	if hero.position.x >= 1538.0 and hero.position.y <= 322.0:
		_begin_dissolve_to_cavern()


func _begin_dissolve_to_cavern() -> void:
	stage = Stage.DISSOLVE_TO_CAVERN
	_transition_timer = 0.0
	_dissolve_start_pos = hero.position
	hero.controls_enabled = false
	_update_hud()
	stage_changed.emit("DISSOLVE_TO_CAVERN")


func _step_dissolve_to_cavern(delta: float) -> void:
	const DURATION := 0.58
	_transition_timer += delta
	var t := clampf(_transition_timer / DURATION, 0.0, 1.0)

	hero.step_scripted_to(FOREST_CAVE_TARGET, 220.0, delta)
	var shade := clampf(inverse_lerp(0.0, 0.85, t), 0.0, 1.0)
	hero.modulate = Color(lerpf(0.72, 0.18, shade), lerpf(0.75, 0.22, shade), lerpf(0.82, 0.28, shade), 1.0 - 0.85 * shade)
	mist_curtain.color.a = clampf(inverse_lerp(0.28, 0.98, t), 0.0, 1.0)

	if t >= 1.0:
		_enter_cavern_stage()


func _enter_cavern_stage() -> void:
	# Reparent the exact same IsoCommander (same zoom, same scale, same controls!) into CaveStage!
	forest_actors.remove_child(hero)
	for c in forest_actors.get_children():
		c.queue_free()
	active_bats.clear()
	forest_sleeping_bat = null

	forest_stage.visible = false
	cavern_stage.visible = true

	cavern_actors.add_child(hero)
	hero.actors_host = cavern_actors
	hero.walk_polygon = CAVERN_POLY
	hero.position = CAVERN_ARCH_START
	hero.modulate = Color.WHITE
	hero.aim_dir = Vector2(0.866, -0.5).normalized()
	hero.controls_enabled = false

	for i in 3:
		var cb := IsoBat2D.new()
		cb.name = "CavernBat_%d" % i
		cavern_actors.add_child(cb)
		cb.setup_cavern_bat(i, hero, CAVERN_POLY)
		cb.died.connect(_on_cavern_bat_died)
		active_bats.append(cb)
	hero.bats_ref = active_bats

	_snap_camera_to_hero()
	stage = Stage.CAVERN_EMERGE
	_transition_timer = 0.0
	_update_hud()
	stage_changed.emit("CAVERN_EMERGE")


func _step_cavern_emerge(delta: float) -> void:
	const DURATION := 0.56
	_transition_timer += delta
	var t := clampf(_transition_timer / DURATION, 0.0, 1.0)

	mist_curtain.color.a = 1.0 - clampf(t / 0.48, 0.0, 1.0)
	hero.step_scripted_to(CAVERN_EMERGE_POS, 260.0, delta)
	_follow_camera(hero.position, delta)

	for b in active_bats:
		if is_instance_valid(b):
			b.step_bat(delta)

	if t >= 1.0:
		mist_curtain.color.a = 0.0
		stage = Stage.CAVERN
		hero.controls_enabled = true
		var delays := [1.15, 1.95, 2.75]
		for i in active_bats.size():
			if is_instance_valid(active_bats[i]):
				active_bats[i].awaken_cavern_bat(delays[i])
		_update_hud()
		stage_changed.emit("CAVERN")


func _step_cavern(move_dir: Vector2, delta: float) -> void:
	hero.step_hero(move_dir, delta)
	_step_bolts_in(cavern_actors, delta)
	for b in active_bats:
		if is_instance_valid(b):
			b.step_bat(delta)

	_follow_camera(hero.position, delta)

	if _clear_delay > 0.0:
		_clear_delay -= delta
		if _clear_delay <= 0.0 and not cavern_is_clear:
			cavern_is_clear = true
			clear_label.visible = true
			var tw := create_tween()
			tw.tween_property(clear_label, "modulate:a", 1.0, 0.35)
			_update_hud()
			cavern_cleared.emit()


func _step_bolts_in(container: Node2D, delta: float) -> void:
	for child in container.get_children():
		if child is IsoBolt2D:
			(child as IsoBolt2D).step_bolt(delta)


func _on_cavern_bat_died(_b: IsoBat2D) -> void:
	cavern_bats_killed += 1
	_update_hud()
	if cavern_bats_killed >= 3 and _clear_delay < 0.0:
		_clear_delay = 0.40


func _snap_camera_to_hero() -> void:
	var half := VIEW_SIZE * 0.5
	var focus := hero.position + CAM_LEAD_OFFSET
	iso_camera.position = focus.clamp(half, CANVAS_SIZE - half)
	iso_camera.force_update_scroll()


func _follow_camera(feet: Vector2, delta: float) -> void:
	var half := VIEW_SIZE * 0.5
	var focus := feet + CAM_LEAD_OFFSET
	var target := iso_camera.position.clamp(focus - CAM_LEEWAY, focus + CAM_LEEWAY)
	target = target.clamp(half, CANVAS_SIZE - half)
	iso_camera.position = iso_camera.position.lerp(target, 1.0 - exp(-CAM_FOLLOW_RATE * delta))
	iso_camera.force_update_scroll()


func _unhandled_input(event: InputEvent) -> void:
	if hero == null:
		return
	if event is InputEventMouseMotion and hero.controls_enabled and not use_script_input:
		hero.aim_toward_world_point(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and hero.controls_enabled:
			if hero.fire_at_world_point(get_global_mouse_position()) != null:
				get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_SPACE, KEY_J:
				if hero.fire_shot_in_direction() != null:
					get_viewport().set_input_as_handled()
			KEY_G:
				guides = not guides
				debug_label.visible = guides
				queue_redraw()
				get_viewport().set_input_as_handled()
			KEY_R:
				reset_sequence()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				var launcher := get_node_or_null("/root/BuildLauncher")
				if launcher == null or not launcher.is_build_active():
					get_tree().quit()


func _update_hud() -> void:
	match stage:
		Stage.FOREST:
			var bat_note := ""
			if is_instance_valid(forest_sleeping_bat):
				if forest_sleeping_bat.state == IsoBat2D.State.SLEEPING_BRANCH:
					bat_note = " · Trail ahead"
				elif forest_sleeping_bat.alive:
					bat_note = " · Ambush bat awake!"
			status_badge.text = "Isometric Forest Trail%s" % bat_note
		Stage.DISSOLVE_TO_CAVERN, Stage.CAVERN_EMERGE:
			status_badge.text = "Entering Crystal Cavern…"
		Stage.CAVERN:
			var rem := maxi(0, 3 - cavern_bats_killed)
			status_badge.text = "Crystal Cavern · Clear" if cavern_is_clear else "Crystal Cavern · Bats remaining: %d" % rem
	controls_label.text = "WASD / Arrows  Move     ·     Left Click (360° Cursor) or Space / J  Fire     ·     R  Restart     ·     Esc  Developers Page"


func _update_debug() -> void:
	if hero == null:
		return
	debug_label.text = "Stage=%s | Hero=(%.1f, %.1f) oct=%d h=%.1fpx (%.1f%%) zoom=%.2f | CavernKills=%d/3 | Contacts=%d" % [
		Stage.keys()[stage],
		hero.position.x,
		hero.position.y,
		hero.octant_for_direction(hero.aim_dir),
		hero.rendered_height_px(),
		100.0 * hero.rendered_height_px() / VIEW_SIZE.y,
		iso_camera.zoom.x,
		cavern_bats_killed,
		hero.contact_count,
	]
