extends Node2D

const SHADOW := preload("res://assets/textures/rpg_2d/sprites/contact_shadow.png")
const RIFLE_HEIGHT := 217.0
const WINDUP := 0.54
const PASS := 1.32
const RETURN := 2.46
const CYCLE := WINDUP + PASS + RETURN

var alive := true
var body := Vector2.ZERO
var altitude := 300.0
var diving := false
var pass_number := -1
var _contacted_pass := -1
var _time := 0.0
var _delay: float
var _start: Vector2
var _aim: Vector2
var _end: Vector2
var _turn: Vector2
var _height: float
var _side: float
var _texture: Texture2D
var _art: Sprite2D
var _shade: Sprite2D


func setup(index: int, texture: Texture2D) -> void:
	_texture = texture
	_delay = [1.35, 2.85, 4.25][index]
	_start = [Vector2(132, 514), Vector2(1232, 663), Vector2(940, 399)][index]
	_aim = [Vector2(225, 570), Vector2(1152, 649), Vector2(1050, 483)][index]
	_end = [Vector2(1165, 570), Vector2(245, 649), Vector2(264, 483)][index]
	_turn = [Vector2(655, 432), Vector2(826, 727), Vector2(690, 391)][index]
	_height = [292.0, 359.0, 325.0][index]
	_side = signf(_end.x - _aim.x)
	_shade = Sprite2D.new()
	_shade.texture = SHADOW
	_shade.z_index = -1
	add_child(_shade)
	if _texture != null:
		_art = Sprite2D.new()
		_art.texture = _texture
		_art.hframes = 4
		_art.scale = Vector2.ONE * 214.0 / (_texture.get_width() / 4.0)
		add_child(_art)
	tick(0.0)


func tick(delta: float) -> void:
	if not alive:
		return
	_time += delta
	var flight_time := _time - _delay
	var phase := fposmod(maxf(0.0, flight_time), CYCLE)
	diving = flight_time >= WINDUP and phase >= WINDUP and phase < WINDUP + PASS
	pass_number = floori(maxf(0.0, flight_time) / CYCLE)
	var tucked := flight_time >= 0.0 and phase < WINDUP + 0.19
	var direction := _side
	if flight_time < 0.0:
		position = _start + Vector2(-_side * 30.0, -14.0) * sin(-flight_time * 1.7)
		altitude = _height + sin(flight_time * 4.5) * 15.0
	elif phase < WINDUP:
		var blend := smoothstep(0.0, WINDUP, phase)
		position = _start.lerp(_aim, blend)
		altitude = lerpf(_height, RIFLE_HEIGHT, blend)
	elif diving:
		position = _aim.lerp(_end, (phase - WINDUP) / PASS)
		altitude = RIFLE_HEIGHT
	else:
		var t := (phase - WINDUP - PASS) / RETURN
		position = _end.lerp(_turn, t).lerp(_turn.lerp(_start, t), t)
		altitude = lerpf(RIFLE_HEIGHT, _height, smoothstep(0.0, 0.38, t))
		direction = -_side if t < 0.84 else _side
	body = position - Vector2(0, altitude)
	_shade.position.y = maxf(0.0, 454.0 - position.y)
	_shade.scale = Vector2(1.68, 0.73) if tucked or diving else Vector2(2.40, 0.90)
	_shade.modulate = Color(0.08, 0.10, 0.17, 0.64 if tucked or diving else 0.29)
	if _art != null:
		_art.position.y = -altitude
		_art.flip_h = direction < 0.0
		_art.frame = 3 if tucked else [0, 1, 2, 1][int(_time * 17.0) % 4]
	queue_redraw()


func try_contact(boots: Vector2) -> bool:
	if not diving or not alive or _contacted_pass == pass_number:
		return false
	if absf(boots.y - position.y) > 32.0 or absf(boots.x - position.x) > 46.0:
		return false
	_contacted_pass = pass_number
	return true


func fall() -> void:
	alive = false
	_shade.modulate.a = 0.44
	if _art != null:
		_art.frame = 3
		var animation := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD)
		animation.tween_property(_art, "position:y", -25.0, 0.40).set_ease(Tween.EASE_IN)
		animation.tween_property(_art, "rotation", _side * 1.75, 0.42)
		animation.tween_property(_art, "modulate", Color(0.59, 0.58, 0.68, 0.82), 0.38)
	else:
		var animation := create_tween()
		animation.tween_method(_fall_blockout, altitude, 22.0, 0.40)


func _fall_blockout(next_altitude: float) -> void:
	altitude = next_altitude
	queue_redraw()


func _draw() -> void:
	if _texture != null:
		return
	var centre := Vector2(0, -altitude)
	var wing := 28.0 if diving else 54.0 + sin(_time * 18.0) * 18.0
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(-72, -wing), centre + Vector2(-47, 14), centre,
		centre + Vector2(47, 14), centre + Vector2(72, -wing), centre + Vector2(0, -12)
	]), Color("aa6290"))
	draw_circle(centre, 20.0, Color("603a69") if alive else Color("3b3143"))
