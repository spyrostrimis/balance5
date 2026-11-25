extends Node2D
## A bat's shadow and steering use its foot position. The rendered body
## rises above that point. The same body center is used for aiming and hits.

signal contacted(at: Vector2)

enum Flight { ORBIT, TELL, DIVE, BREAK, FALL }

const Layout := preload("res://scripts/forest_fight_4/forest_fight_4_layout.gd")
const ATLAS := preload("res://assets/textures/forest_fight_2/alien_bat_hd.png")
const SHADOW := preload("res://assets/textures/rpg_2d/sprites/contact_shadow.png")
const HIT_RADIUS := 25.0
const PASS_HEIGHT := 91.0
const ORBIT_HEIGHT := 143.0
const BODY_OFFSET := Vector2(0, 1)
const ORBIT_HOME := [
	Vector2(1650, 14), Vector2(2127, -25), Vector2(1905, 107),
]

var flight := Flight.ORBIT
var altitude := ORBIT_HEIGHT
var index := 0
var alive := true
var clock := 0.0
var timer := 0.0
var departure := Vector2.ZERO
var break_target := Vector2.ZERO
var drift := Vector2.RIGHT
var hit_velocity := Vector2.ZERO
var _did_contact := false
var _recovery_altitude := ORBIT_HEIGHT


func prepare(number: int) -> void:
	index = number
	clock = TAU * index / 3.0
	timer = 1.08 + index * 0.63
	position = _orbit_point()


func body_center() -> Vector2:
	return position + BODY_OFFSET - Vector2(0, altitude)


func hittable() -> bool:
	return alive and altitude <= 124.0


func hit(direction: Vector2) -> void:
	alive = false
	flight = Flight.FALL
	timer = 0.52
	hit_velocity = direction * 72.0


func update_flight(delta: float, player: Vector2, engage: bool) -> void:
	if flight == Flight.FALL:
		timer -= delta
		position = Layout.flight_position(position + hit_velocity * delta)
		altitude = move_toward(altitude, 6.0, 240.0 * delta)
		modulate.a = clampf(timer * 4.0, 0.0, 1.0)
		visible = timer > 0.0
		queue_redraw()
		return

	var previous := position
	clock += delta
	timer -= delta
	match flight:
		Flight.ORBIT:
			position = position.move_toward(_orbit_point(), 205.0 * delta)
			altitude = move_toward(altitude, ORBIT_HEIGHT + sin(clock * 4.2) * 12.0, 180.0 * delta)
			if engage and timer <= 0.0:
				flight = Flight.TELL
				timer = 0.48
				_did_contact = false
		Flight.TELL:
			altitude = move_toward(altitude, 112.0, 100.0 * delta)
			if timer <= 0.0:
				departure = position.direction_to(player)
				flight = Flight.DIVE
				timer = 2.3
		Flight.DIVE:
			var toward := position.direction_to(player)
			if toward.dot(departure) > 0.2:
				departure = departure.lerp(toward, 1.0 - exp(-2.4 * delta)).normalized()
			position = Layout.flight_position(position + departure * (286.0 + 19.0 * index) * delta)
			altitude = move_toward(altitude, PASS_HEIGHT, 170.0 * delta)
			if not _did_contact and engage and position.distance_to(player) <= 29.0:
				_did_contact = true
				contacted.emit(player + Vector2(0, -88))
				_start_break()
			elif timer <= 0.0 or not engage:
				_start_break()
		Flight.BREAK:
			position = position.move_toward(break_target, 232.0 * delta)
			altitude = lerpf(_recovery_altitude, ORBIT_HEIGHT, smoothstep(0.0, 0.75, 0.94 - timer))
			if timer <= 0.0:
				flight = Flight.ORBIT
				timer = 0.76 + index * 0.27
	if absf(position.x - previous.x) > 0.25:
		drift = position - previous
	queue_redraw()


func _start_break() -> void:
	flight = Flight.BREAK
	timer = 0.94
	_recovery_altitude = altitude
	var turn := 0.62 if index == 1 else -0.62
	break_target = Layout.flight_position(position + departure.rotated(turn) * 227.0)


func _orbit_point() -> Vector2:
	var angle := clock * (1.33 if index == 1 else -1.44)
	var center: Vector2 = ORBIT_HOME[index]
	return Layout.flight_position(center + Vector2(cos(angle) * 183.0, sin(angle) * 93.0))


func _draw() -> void:
	var tell := flight == Flight.TELL
	var shadow_width := lerpf(69.0, 42.0, clampf(altitude / ORBIT_HEIGHT, 0.0, 1.0))
	draw_texture_rect(SHADOW, Rect2(-shadow_width * 0.5, -10, shadow_width, 20), false,
		Color(0.19, 0.15, 0.24, 0.35 if altitude > 124.0 else 0.74))
	var frame := int(clock * 7.6) % 2
	if tell or flight == Flight.DIVE:
		frame = 2
	elif not alive:
		frame = 3
	var body := BODY_OFFSET - Vector2(0, altitude)
	draw_set_transform(body, -0.15 if flight == Flight.DIVE else 0.0, Vector2(-1 if drift.x > 0 else 1, 1))
	draw_texture_rect_region(ATLAS, Rect2(-57, -60, 114, 114), Rect2(frame * 512, 0, 512, 512),
		Color(1.20, 1.05, 1.11) if tell else Color.WHITE)
	if tell:
		draw_set_transform(body + Vector2(0, -33))
		draw_arc(Vector2.ZERO, 8.0 + 8.0 * (timer / 0.48), 0.0, TAU, 18, Color(1.0, 0.71, 0.57, 0.63), 1.25, true)
