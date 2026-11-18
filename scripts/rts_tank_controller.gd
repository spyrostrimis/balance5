extends CharacterBody2D
## Playable RTS tank controller supporting mouse click-to-move and WASD/Arrow direct drive.

const MAP_BOUNDS := Rect2(24.0, 24.0, 976.0, 664.0)
const SHADOW_OFFSET := Vector2(2.5, 3.5)

@export var move_speed: float = 135.0
@export var turn_speed: float = 8.5
@export var arrival_tolerance: float = 4.0
@export var stuck_timeout: float = 0.25

@onready var _tank_sprite: Sprite2D = $TankSprite
@onready var _tank_shadow: Sprite2D = get_node_or_null("TankShadow")

var _target_pos: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _heading: float = 0.0
var _stuck_timer: float = 0.0
var _pulse_time: float = 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_heading = _tank_sprite.rotation
	_sync_visuals()


func set_move_target(world_pos: Vector2) -> void:
	_target_pos = _clamp_to_map(world_pos)
	_has_target = true
	_stuck_timer = 0.0
	queue_redraw()


func clear_move_target() -> void:
	_has_target = false
	_stuck_timer = 0.0
	velocity = Vector2.ZERO
	queue_redraw()


func has_move_target() -> bool:
	return _has_target


func is_moving() -> bool:
	return velocity.length_squared() > 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			set_move_target(get_global_mouse_position())
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_pulse_time += delta
	var move_dir := _read_keyboard_direction()

	if move_dir.length_squared() > 0.0:
		_has_target = false
		_stuck_timer = 0.0
	elif _has_target:
		var to_target := _target_pos - global_position
		if to_target.length() <= arrival_tolerance:
			clear_move_target()
		else:
			move_dir = to_target.normalized()

	if move_dir.length_squared() > 0.0:
		_heading = rotate_toward(_heading, move_dir.angle(), turn_speed * delta)
		velocity = move_dir * move_speed
		var prev_pos := global_position
		var prev_dist := prev_pos.distance_to(_target_pos)
		move_and_slide()
		global_position = _clamp_to_map(global_position)

		if _has_target:
			var progress := prev_dist - global_position.distance_to(_target_pos)
			var step_moved := global_position.distance_to(prev_pos)
			var stalled := (
				(get_slide_collision_count() > 0 and progress < move_speed * delta * 0.12)
				or step_moved < move_speed * delta * 0.12
			)
			if stalled:
				_stuck_timer += delta
				if _stuck_timer >= stuck_timeout:
					clear_move_target()
			else:
				_stuck_timer = 0.0
	else:
		velocity = Vector2.ZERO

	_sync_visuals()
	if _has_target or is_moving():
		queue_redraw()


func _draw() -> void:
	# Subtle RTS selection ring grounded beneath the tank
	draw_circle(Vector2.ZERO, 18.0, Color(0.28, 0.80, 1.0, 0.08))
	draw_arc(Vector2.ZERO, 18.5, 0.0, TAU, 36, Color(0.32, 0.85, 1.0, 0.72), 1.6, true)

	if _has_target:
		var local_target := to_local(_target_pos)
		var pulse := 0.5 + 0.5 * sin(_pulse_time * 8.0)
		var radius := lerpf(6.0, 11.0, pulse)
		var col := Color(0.38, 0.92, 1.0, lerpf(0.9, 0.45, pulse))
		draw_arc(local_target, radius, 0.0, TAU, 24, col, 1.6, true)
		draw_line(local_target + Vector2(-4, 0), local_target + Vector2(4, 0), col, 1.4, true)
		draw_line(local_target + Vector2(0, -4), local_target + Vector2(0, 4), col, 1.4, true)


func _read_keyboard_direction() -> Vector2:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	return dir


func _clamp_to_map(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, MAP_BOUNDS.position.x, MAP_BOUNDS.end.x),
		clampf(pos.y, MAP_BOUNDS.position.y, MAP_BOUNDS.end.y)
	)


func _sync_visuals() -> void:
	_tank_sprite.rotation = _heading
	if _tank_shadow != null:
		_tank_shadow.position = SHADOW_OFFSET
		_tank_shadow.rotation = _heading
