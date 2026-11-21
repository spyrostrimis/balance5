extends Node2D

const ROOM_A := preload("res://scenes/pixel_canyon/road_to_the_arch.tscn")
const ROOM_B := preload("res://scenes/pixel_canyon/arch_overlook.tscn")
const SHOT_SPEED := 650.0
const LANE_TOLERANCE := 11.0
const MIN_SHOT_COOLDOWN := 0.31
const VIEW_CENTER := Vector2(480, 270)
const FOLLOW_FROM_Y := 300.0
const FOLLOW_TRAVEL_PER_PIXEL := 6.0
const FOLLOW_LIMIT := 24
const COMPARISON_NAMES := ["A  Current game", "B  Depth calibration", "C  Depth + camera"]

enum Comparison { CURRENT, DEPTH, FOLLOW }

signal shot_resolved(hit: bool)
signal room_entered(index: int)

@export var top_extension: Texture2D

class Shot:
	var origin: Vector2
	var position: Vector2
	var facing: int
	var lane: float

	func _init(muzzle: Vector2, direction: int, depth: float) -> void:
		origin = muzzle
		position = muzzle
		facing = direction
		lane = depth

var room_index := 0
var encounter_clear := false
var showing_reference := false
var _room: Node2D
var _foreground: Sprite2D
var _sentry: Sprite2D
var _shots: Array[Shot] = []
var _cooldown := 0.0
var _impact := Vector2.ZERO
var _impact_time := 0.0
var _hint_time := 5.0
var _comparison := Comparison.CURRENT
var _extension: Sprite2D

@onready var commander = $Depth/Commander
@onready var _depth: Node2D = $Depth
@onready var _shadows = $Shadows
@onready var _master: Sprite2D = $"../Screen/VisualMaster"
@onready var _hint: Label = $"../Screen/Interface/Hint"
@onready var _effects: Node2D = $Effects
@onready var _camera: Camera2D = get_node_or_null("StudyCamera")


func _ready() -> void:
	_shadows.commander = commander
	_effects.draw.connect(_draw_shots)
	_enter_room(0)
	if top_extension:
		show_controls()
	if "--clean" in OS.get_cmdline_user_args():
		_hint_time = 0.0
		_hint.hide()
	set_reference("--reference" in OS.get_cmdline_user_args())


func _physics_process(delta: float) -> void:
	if showing_reference or not is_instance_valid(_room):
		return
	_hint_time = maxf(_hint_time - delta, 0.0)
	_hint.visible = _hint_time > 0.0
	_cooldown = maxf(_cooldown - delta, 0.0)
	_impact_time = maxf(_impact_time - delta, 0.0)
	var direction := _direction()
	commander.walk(direction, delta)
	_update_camera()
	if _cooldown == 0.0 and Input.is_action_just_pressed("ui_accept"):
		_shots.append(Shot.new(commander.fire(), commander.facing, commander.position.y))
		_cooldown = MIN_SHOT_COOLDOWN
	_advance_shots(delta)
	_shadows.queue_redraw()
	_effects.queue_redraw()


func set_reference(enabled: bool) -> void:
	showing_reference = enabled
	_master.visible = enabled
	if not enabled and top_extension and _hint_time > 0.0:
		_set_controls_text()
	_hint.visible = not enabled and _hint_time > 0.0
	_update_camera()


func show_controls() -> void:
	if showing_reference:
		return
	_set_controls_text()
	_hint_time = 5.0


func _set_controls_text() -> void:
	if top_extension:
		_hint.text = "%s    •    1 / 2 / 3  Compare    Arrows / WASD  Move    Space  Fire    F2  Reference    F11  Fullscreen" % COMPARISON_NAMES[_comparison]
	else:
		_hint.text = "Arrows / WASD  Move     Space  Fire     F2  Reference     F11  Fullscreen"


func set_comparison(version: Comparison) -> void:
	_comparison = version
	_apply_comparison()
	show_controls()
	_hint.visible = not showing_reference


func _uses_calibration() -> bool:
	return room_index == 0 and _comparison != Comparison.CURRENT


func _apply_comparison() -> void:
	var calibrated := _uses_calibration()
	commander.set_calibrated_depth(calibrated)
	if is_instance_valid(_sentry):
		var size: float = commander.calibrated_size_at(_sentry.position.y) if calibrated else 1.0
		_sentry.scale = Vector2.ONE * size
		_sentry.offset = (-commander.PIVOT * size).round() / size
	if is_instance_valid(_extension):
		_extension.visible = _comparison == Comparison.FOLLOW
	_update_camera()
	_shadows.queue_redraw()


func _update_camera() -> void:
	if not _camera:
		return
	var travel := 0
	if _comparison == Comparison.FOLLOW and room_index == 0 and not showing_reference:
		travel = clampi(roundi((FOLLOW_FROM_Y - commander.position.y) / FOLLOW_TRAVEL_PER_PIXEL), 0, FOLLOW_LIMIT)
	var target := VIEW_CENTER - Vector2(0, travel)
	if _camera.position != target:
		_camera.position = target
		_camera.force_update_scroll()


func _direction() -> Vector2:
	var left := Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)
	var right := Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D)
	var up := Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W)
	var down := Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S)
	return Vector2(int(right) - int(left), int(down) - int(up)).normalized()


func _enter_room(index: int) -> void:
	if is_instance_valid(_room):
		_foreground.free()
		_room.free()
		if is_instance_valid(_sentry):
			_sentry.free()
	_shots.clear()
	_impact_time = 0.0
	var previous := room_index
	room_index = index
	_room = (ROOM_A if index == 0 else ROOM_B).instantiate()
	add_child(_room)
	if index == 0 and top_extension:
		_extension = Sprite2D.new()
		_extension.texture = top_extension
		_extension.centered = false
		_extension.position.y = -top_extension.get_height()
		_extension.z_index = -2
		_room.add_child(_extension)
	_foreground = _room.get_node("Foreground")
	_foreground.reparent(_depth)
	if index == 0 and not encounter_clear:
		_sentry = _room.get_node("Sentry")
		_sentry.reparent(_depth)
	elif _room.has_node("Sentry"):
		_room.get_node("Sentry").free()
	_shadows.sentry = _sentry if is_instance_valid(_sentry) else null
	var spawn := "FromOverlook" if index == 0 and previous == 1 else "Spawn"
	commander.place(_room.get_node(spawn).position)
	_apply_comparison()
	_room.get_node("Gate").body_entered.connect(_on_gate_entered)
	_effects.queue_redraw()
	room_entered.emit(index)


func _on_gate_entered(body: Node2D) -> void:
	if body != commander:
		return
	if room_index == 0 and not encounter_clear:
		_hint.text = "The scout holds the bend. Line up your boots before you fire."
		_hint_time = 3.0
		return
	_enter_room.call_deferred(1 - room_index)


func _advance_shots(delta: float) -> void:
	for index in range(_shots.size() - 1, -1, -1):
		var shot := _shots[index]
		var old_x := shot.position.x
		shot.position.x += shot.facing * SHOT_SPEED * delta
		if _shot_hits(shot, old_x):
			_impact = Vector2(_sentry.position.x, shot.position.y).round()
			_impact_time = 0.28
			encounter_clear = true
			_sentry.hide()
			_shots.remove_at(index)
			shot_resolved.emit(true)
		elif shot.position.x < 0.0 or shot.position.x > 960.0:
			_shots.remove_at(index)
			shot_resolved.emit(false)


func _shot_hits(shot: Shot, old_x: float) -> bool:
	if encounter_clear or not is_instance_valid(_sentry):
		return false
	return absf(shot.lane - _sentry.position.y) <= LANE_TOLERANCE \
		and _sentry.position.x >= minf(old_x, shot.position.x) \
		and _sentry.position.x <= maxf(old_x, shot.position.x)


func _draw_shots() -> void:
	for shot in _shots:
		var head := shot.position.round()
		var tail := move_toward(head.x, shot.origin.x, 21.0)
		var strip := Rect2(minf(tail, head.x), head.y - 1.0, absf(head.x - tail) + 1.0, 3.0)
		_effects.draw_rect(strip, Color("#c36c3b"))
		_effects.draw_rect(Rect2(strip.position + Vector2(1, 1), Vector2(maxf(strip.size.x - 2.0, 2.0), 1)), Color("#fff0b0"))
		if absf(head.x - shot.origin.x) < 40.0:
			_effects.draw_rect(Rect2(shot.origin.round() - Vector2(4, 3), Vector2(9, 6)), Color("#ef9d50"))
			_effects.draw_rect(Rect2(shot.origin.round() - Vector2(2, 1), Vector2(12, 3)), Color("#fff0b0"))
	if _impact_time > 0.0:
		var spread := floorf(4.0 + (0.28 - _impact_time) * 61.0)
		for ray: Vector2 in [Vector2(-1, -1), Vector2(1, -0.6), Vector2(0.5, 1), Vector2(-0.9, 0.45)]:
			_effects.draw_rect(Rect2((_impact + ray * spread).round(), Vector2(4, 3)), Color("#ffc87a"))
