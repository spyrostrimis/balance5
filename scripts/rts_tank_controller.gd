extends CharacterBody2D
## Playable RTS tank controller using an 8-directional, 3-frame animated sprite sheet (tank_blue.png).
## Supports left/right mouse click-to-move and WASD/Arrow direct driving.

const SHADOW_OFFSET := Vector2(2.0, 2.5)
const TRACK_SPACING := 6.5
const TRACK_LIFETIME := 4.0
const MAX_TRACK_MARKS := 44

@export var map_bounds := Rect2(24.0, 24.0, 976.0, 664.0)
@export var move_speed: float = 128.0
@export var turn_speed: float = 9.5
@export var arrival_tolerance: float = 4.0
@export var stuck_timeout: float = 0.25
@export var initial_facing: int = 6  # 0=S, 1=SW, 2=W, 3=NW, 4=N, 5=NE, 6=E, 7=SE

@onready var _tank_sprite: Sprite2D = $TankSprite
@onready var _tank_shadow: Sprite2D = get_node_or_null("TankShadow")

var _target_pos: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _heading: float = 0.0
var _facing: int = 6
var _anim_timer: float = 0.0
var _anim_row: int = 0
var _stuck_timer: float = 0.0
var _pulse_time: float = 0.0
var _last_track_pos: Vector2 = Vector2.ZERO
var _tracks: Array[Dictionary] = []


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_facing = posmod(initial_facing, 8)
	_heading = _angle_for_facing(_facing)
	_last_track_pos = global_position
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


func get_facing() -> int:
	return _facing


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			set_move_target(get_global_mouse_position())
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_pulse_time += delta
	_age_tracks(delta)

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

	var step_moved := 0.0
	if move_dir.length_squared() > 0.0:
		_heading = rotate_toward(_heading, move_dir.angle(), turn_speed * delta)
		_facing = _facing_from_angle(_heading)
		velocity = move_dir * move_speed
		var prev_pos := global_position
		var prev_dist := prev_pos.distance_to(_target_pos)
		move_and_slide()
		global_position = _clamp_to_map(global_position)
		step_moved = global_position.distance_to(prev_pos)

		if step_moved > 0.15:
			_anim_timer += delta
			_anim_row = int(floor(_anim_timer * 10.0)) % maxi(_tank_sprite.vframes, 1)
			_emit_track_mark(move_dir)

		if _has_target:
			var progress := prev_dist - global_position.distance_to(_target_pos)
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
	if _has_target or step_moved > 0.01 or not _tracks.is_empty():
		queue_redraw()


func _draw() -> void:
	# Subtle fading sand tread impressions behind the tank
	for mark in _tracks:
		var alpha := clampf(1.0 - (float(mark["age"]) / TRACK_LIFETIME), 0.0, 1.0)
		var col := Color(0.42, 0.22, 0.05, alpha * 0.34)
		var local_p := to_local(mark["pos"] as Vector2)
		var dir: Vector2 = mark["dir"]
		var perp := Vector2(-dir.y, dir.x) * 7.5
		var half_dash := dir * 2.2
		draw_line(local_p + perp - half_dash, local_p + perp + half_dash, col, 2.4, false)
		draw_line(local_p - perp - half_dash, local_p - perp + half_dash, col, 2.4, false)

	# Crisp RTS corner-bracket selection box around the 36x36 unit footprint
	var r := 17.0
	var tick := 5.0
	var border_col := Color(0.06, 0.12, 0.07, 0.62)
	var bracket_col := Color(0.38, 0.94, 0.52, 0.78)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := Vector2(sx * r, sy * r)
			var hx := corner + Vector2(-sx * tick, 0.0)
			var hy := corner + Vector2(0.0, -sy * tick)
			draw_line(corner, hx, border_col, 2.6, false)
			draw_line(corner, hy, border_col, 2.6, false)
			draw_line(corner, hx, bracket_col, 1.2, false)
			draw_line(corner, hy, bracket_col, 1.2, false)

	if _has_target:
		var local_target := to_local(_target_pos)
		var pulse := 0.5 + 0.5 * sin(_pulse_time * 8.0)
		var radius := lerpf(5.0, 9.0, pulse)
		var col := Color(0.42, 0.95, 0.56, lerpf(0.88, 0.42, pulse))
		draw_arc(local_target, radius, 0.0, TAU, 24, col, 1.4, true)
		draw_line(local_target + Vector2(-3.5, 0), local_target + Vector2(3.5, 0), col, 1.2, false)
		draw_line(local_target + Vector2(0, -3.5), local_target + Vector2(0, 3.5), col, 1.2, false)


func _emit_track_mark(dir: Vector2) -> void:
	if global_position.distance_to(_last_track_pos) < TRACK_SPACING:
		return
	_last_track_pos = global_position
	_tracks.append({
		"pos": global_position - dir * 6.0,
		"dir": dir,
		"age": 0.0,
	})
	if _tracks.size() > MAX_TRACK_MARKS:
		_tracks.pop_front()


func _age_tracks(delta: float) -> void:
	if _tracks.is_empty():
		return
	var keep: Array[Dictionary] = []
	for mark in _tracks:
		var next_age := float(mark["age"]) + delta
		if next_age < TRACK_LIFETIME:
			mark["age"] = next_age
			keep.append(mark)
	_tracks = keep


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
		clampf(pos.x, map_bounds.position.x, map_bounds.end.x),
		clampf(pos.y, map_bounds.position.y, map_bounds.end.y)
	)


func _facing_from_angle(angle_rad: float) -> int:
	var v := Vector2.from_angle(angle_rad)
	return posmod(roundi(atan2(-v.x, v.y) / (PI / 4.0)), 8)


func _angle_for_facing(facing_idx: int) -> float:
	# 0=S (+PI/2), 1=SW (+3PI/4), 2=W (PI), 3=NW (-3PI/4), 4=N (-PI/2), 5=NE (-PI/4), 6=E (0), 7=SE (+PI/4)
	return wrapf(PI * 0.5 + float(facing_idx) * (PI / 4.0), -PI, PI)


func _sync_visuals() -> void:
	_tank_sprite.rotation = 0.0
	_tank_sprite.frame_coords = Vector2i(_facing, _anim_row)
	if _tank_shadow != null:
		_tank_shadow.position = SHADOW_OFFSET
		_tank_shadow.rotation = 0.0
		_tank_shadow.frame_coords = Vector2i(_facing, _anim_row)
