extends Node2D
## The map uses projected screen coordinates. Only speed and weapon length
## need the inverse ground transform. The camera never changes this basis.

const Layout := preload("res://scripts/forest_fight_4/forest_fight_4_layout.gd")
const Bat := preload("res://scripts/forest_fight_4/forest_fight_4_bat.gd")
const BOLT := preload("res://assets/textures/forest_fight_2/bolt_hd.png")
const FLASH := preload("res://assets/textures/forest_fight_2/muzzle_flash_hd.png")
const ARMOUR_SPARK := preload("res://assets/textures/forest_fight_2/armour_spark_hd.png")
const IMPACT := preload("res://assets/textures/forest_fight_2/bat_hit_spark_hd.png")

const VIEW := Vector2i(1376, 768)
const ISO := Transform2D(Vector2(0.70710678, 0.40824829), Vector2(-0.70710678, 0.40824829), Vector2.ZERO)
const GROUND := Transform2D(Vector2(0.70710678, -0.70710678), Vector2(1.22474487, 1.22474487), Vector2.ZERO)
const SPEED := 318.0
const AIM_PIVOT := Vector2(0, -91)
const SHOT_HEIGHT := -AIM_PIVOT
const RIFLE_REACH := 57.0
const BOLT_SPEED := 1460.0
const FIRE_INTERVAL := 0.19
const CAMERA_BIAS := Vector2(36, -75)
const CAMERA_LEEWAY := Vector2(34, 23)
const SOLID_MASK := 1
const BAT_ROOM_START := 1450.0

class Bolt:
	var position: Vector2
	var direction: Vector2
	var speed: float
	var distance := 0.0

	func _init(at: Vector2, heading: Vector2, travel_speed: float) -> void:
		position = at
		direction = heading
		speed = travel_speed

class Spark:
	var position: Vector2
	var direction: Vector2
	var texture: Texture2D
	var duration: float
	var size: Vector2
	var age := 0.0

	func _init(at: Vector2, heading: Vector2, art: Texture2D, seconds: float, dimensions: Vector2) -> void:
		position = at
		direction = heading
		texture = art
		duration = seconds
		size = dimensions

var guides := false
var rough := "--rough" in OS.get_cmdline_user_args()
var aim := Vector2.RIGHT
var gun_pivot := Vector2.ZERO
var muzzle := Vector2.ZERO
var fire_delay := 0.0
var shot_count := 0
var contact_count := 0
var blocked_count := 0
var bats_killed := 0
var bats: Array[Bat] = []
var bolts: Array[Bolt] = []
var _sparks: Array[Spark] = []
var _encounter_started := false
var _fire_pressed := false
var _clear_notice := 0.0
var _shell: Dictionary

@onready var commander: CharacterBody2D = $Actors/Commander
@onready var hero = $Actors/Commander/Art
@onready var camera: Camera2D = $Camera
@onready var outdoor: Sprite2D = $Forest
@onready var cavern: Sprite2D = $Cave
@onready var roof: Sprite2D = $CaveLip
@onready var effects: Node2D = $Effects
@onready var clear_label: Label = $HUD/Clear


func _ready() -> void:
	var window := get_window()
	_shell = {
		"title": window.title, "size": window.size,
		"design": window.content_scale_size, "mode": window.content_scale_mode,
		"aspect": window.content_scale_aspect,
	}
	window.title = "Balance · 2D Painted Forest Fight 4"
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = VIEW
	window.size = VIEW
	_add_boundary(Layout.FLOOR)
	_add_boundary(Layout.ROCK)
	effects.draw.connect(_draw_effects)
	_set_rough(rough)
	reset()


func _exit_tree() -> void:
	var window := get_window()
	if is_instance_valid(window) and not _shell.is_empty():
		window.title = _shell.title
		window.content_scale_mode = _shell.mode
		window.content_scale_aspect = _shell.aspect
		window.content_scale_size = _shell.design
		window.size = _shell.size


func reset() -> void:
	commander.position = Layout.SPAWN
	commander.velocity = Vector2.ZERO
	camera.position = Layout.SPAWN + CAMERA_BIAS
	camera.force_update_scroll()
	aim = Vector2.RIGHT
	fire_delay = 0.0
	shot_count = 0
	contact_count = 0
	blocked_count = 0
	bats_killed = 0
	hero.distance_walked = 0.0
	_encounter_started = false
	_fire_pressed = false
	_clear_notice = 0.0
	clear_label.hide()
	bolts.clear()
	_sparks.clear()
	for bat in bats:
		bat.queue_free()
	bats.clear()
	for i in 3:
		var bat := Bat.new()
		bat.prepare(i)
		bat.contacted.connect(_on_contact)
		$Actors.add_child(bat)
		bat.hide()
		bats.append(bat)
	gun_pivot = commander.position + grip_for(aim)
	_update_art(Vector2.ZERO)
	effects.queue_redraw()


func _add_boundary(points: Array) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = SOLID_MASK
	body.collision_mask = 0
	for i in points.size():
		var edge := SegmentShape2D.new()
		edge.a = points[i]
		edge.b = points[(i + 1) % points.size()]
		var collision := CollisionShape2D.new()
		collision.shape = edge
		body.add_child(collision)
	add_child(body)


func _physics_process(delta: float) -> void:
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var fire := _fire_pressed or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not over_ui)
	_fire_pressed = false
	step(_movement_input(), get_global_mouse_position(), fire, delta)


func _movement_input() -> Vector2:
	var left := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var up := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	return Vector2(float(right) - float(left), float(down) - float(up))


func step(move: Vector2, target: Vector2, fire: bool, delta: float) -> void:
	var previous := commander.position
	var ground_move := (GROUND * move).normalized() * minf(move.length(), 1.0)
	commander.velocity = ISO * ground_move * SPEED
	commander.move_and_slide()
	var travel := commander.position - previous
	var camera_error := commander.position + CAMERA_BIAS - camera.position
	camera_error -= camera_error.clamp(-CAMERA_LEEWAY, CAMERA_LEEWAY)
	camera.position += camera_error * (1.0 - exp(-9.0 * delta))
	_track_aim(target)
	_update_art(travel)
	_update_encounter(delta)
	_update_shots(fire, delta)


static func grip_for(direction: Vector2) -> Vector2:
	# Match the painted hands without shifting the actor or snapping the gun
	# as the picture changes. Rear views carry the stock lower behind the arm.
	var rear := maxf(-direction.y, 0.0)
	var front := maxf(direction.y, 0.0)
	return Vector2(0, -100.0 + 28.0 * rear - 21.0 * pow(rear, 4.0) - 4.0 * front)


func _track_aim(target: Vector2) -> void:
	var heading := commander.position.direction_to(target - AIM_PIVOT)
	for i in 3:
		heading = (commander.position + grip_for(heading)).direction_to(target)
	gun_pivot = commander.position + grip_for(heading)
	if gun_pivot.distance_squared_to(target) > 1.0:
		aim = gun_pivot.direction_to(target)


func _update_art(travel: Vector2) -> void:
	var feet := commander.position
	var shade := smoothstep(1190.0, 1440.0, feet.x)
	cavern.modulate.a = smoothstep(1000.0, 1165.0, feet.x)
	roof.modulate.a = 1.0 - smoothstep(1240.0, 1360.0, feet.x)
	hero.light = Color.WHITE.lerp(Color(0.86, 0.83, 0.91), shade)
	hero.pivot = gun_pivot - feet
	hero.direction = aim
	hero.moving = travel.length_squared() > 0.04
	hero.distance_walked += (GROUND * travel).length()
	var reach := RIFLE_REACH / (GROUND * aim).length() + 8.0 * pow(absf(aim.y), 4.0)
	muzzle = gun_pivot + aim * reach
	hero.muzzle = muzzle - feet
	hero.update_look()
	if rough or guides:
		queue_redraw()


func _update_encounter(delta: float) -> void:
	var in_chamber := commander.position.x > BAT_ROOM_START
	if not _encounter_started and commander.position.x > 1350.0:
		_encounter_started = true
		for bat in bats:
			bat.show()
	if _encounter_started:
		for bat in bats:
			bat.update_flight(delta, commander.position, in_chamber)
	if _clear_notice > 0.0:
		_clear_notice = maxf(0.0, _clear_notice - delta)
		clear_label.modulate.a = minf(_clear_notice * 1.5, 1.0)
		clear_label.visible = _clear_notice > 0.0


func _update_shots(fire: bool, delta: float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var spark := _sparks[i]
		spark.age += delta
		if spark.age >= spark.duration:
			_sparks.remove_at(i)

	for i in range(bolts.size() - 1, -1, -1):
		if _advance_bolt(bolts[i], delta):
			bolts.remove_at(i)

	fire_delay = maxf(fire_delay - delta, 0.0)
	if fire and fire_delay <= 0.0:
		_fire()
		fire_delay = FIRE_INTERVAL
	effects.queue_redraw()


func _fire() -> void:
	shot_count += 1
	_sparks.append(Spark.new(muzzle, aim, FLASH, 0.082, Vector2(53, 35)))
	var bolt := Bolt.new(gun_pivot, aim, BOLT_SPEED / (GROUND * aim).length())
	# Test the barrel's span too, so a low bat just in front of the hands
	# can be hit and standing right against a wall cannot bypass it.
	if not _advance_bolt(bolt, gun_pivot.distance_to(muzzle) / bolt.speed):
		bolt.position = muzzle
		bolt.distance = 0.0
		bolts.append(bolt)


func _advance_bolt(bolt: Bolt, delta: float) -> bool:
	var start := bolt.position
	var end := start + bolt.direction * bolt.speed * delta
	var wall := _cast_wall(start + SHOT_HEIGHT, end + SHOT_HEIGHT)
	var stop_at := start.distance_to(end)
	if not wall.is_empty():
		stop_at = start.distance_to(wall.position - SHOT_HEIGHT)

	var victim: Bat
	if _encounter_started:
		for bat in bats:
			if not bat.hittable():
				continue
			var offset := bat.body_center() - start
			var along := offset.dot(bolt.direction)
			var side := offset.cross(bolt.direction)
			var chord_squared := Bat.HIT_RADIUS * Bat.HIT_RADIUS - side * side
			if chord_squared <= 0.0:
				continue
			var half_chord := sqrt(chord_squared)
			var first := maxf(0.0, along - half_chord)
			if along + half_chord >= 0.0 and first < stop_at:
				stop_at = first
				victim = bat
	if victim != null:
		victim.hit(bolt.direction)
		bats_killed += 1
		_sparks.append(Spark.new(start + bolt.direction * stop_at, bolt.direction, IMPACT, 0.29, Vector2(76, 76)))
		if bats_killed == bats.size():
			_clear_notice = 2.8
		return true
	if not wall.is_empty():
		_wall_impact(wall.position - SHOT_HEIGHT)
		return true
	bolt.position = end
	bolt.distance += start.distance_to(end)
	return bolt.distance > 1550.0


func _cast_wall(from: Vector2, to: Vector2) -> Dictionary:
	var ray := PhysicsRayQueryParameters2D.create(from, to, SOLID_MASK)
	return get_world_2d().direct_space_state.intersect_ray(ray)


func _wall_impact(at: Vector2) -> void:
	blocked_count += 1
	_sparks.append(Spark.new(at, Vector2.RIGHT, IMPACT, 0.16, Vector2(42, 42)))


func _on_contact(at: Vector2) -> void:
	contact_count += 1
	_sparks.append(Spark.new(at, Vector2.RIGHT, ARMOUR_SPARK, 0.29, Vector2(104, 104)))


func _set_rough(enabled: bool) -> void:
	rough = enabled
	outdoor.visible = not rough
	cavern.visible = not rough
	roof.visible = not rough
	$Actors/Tree.visible = not rough
	$Actors/Fence.visible = not rough
	$Actors/Boulder.visible = not rough
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_fire_pressed = true


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_G:
			guides = not guides
			queue_redraw()
		KEY_F2:
			_set_rough(not rough)
		KEY_R:
			reset()
		KEY_ESCAPE:
			var launcher := get_node_or_null("/root/BuildLauncher")
			if launcher == null or not launcher.is_build_active():
				get_tree().quit()


func _draw_effects() -> void:
	for bolt in bolts:
		effects.draw_set_transform(bolt.position, bolt.direction.angle())
		var length := clampf(bolt.distance + 14.0, 14.0, 68.0)
		effects.draw_texture_rect(BOLT, Rect2(-length, -12, length, 24), false)
	for spark in _sparks:
		effects.draw_set_transform(spark.position, spark.direction.angle())
		var alpha := 1.0 - smoothstep(0.03, spark.duration, spark.age)
		var rect := Rect2(spark.size * -0.5, spark.size)
		if spark.texture == FLASH:
			rect.position.x = -12.0
		effects.draw_texture_rect(spark.texture, rect, false, Color(1, 1, 1, alpha))


func _draw() -> void:
	if rough:
		draw_rect(Rect2(-500, -1250, 3900, 2600), Color("303c4d"))
		draw_colored_polygon(PackedVector2Array(Layout.FLOOR), Color("967453"))
		draw_colored_polygon(PackedVector2Array(Layout.ROCK), Color("343141"))
		draw_line(Layout.DOOR + Vector2(-49, -68), Layout.DOOR + Vector2(48, 67), Color("54614d"), 12)
	if guides or rough:
		for i in range(-55, 56):
			var color := Color(0.85, 0.93, 0.88, 0.21)
			draw_line(ISO * Vector2(i * 80, -4400), ISO * Vector2(i * 80, 4400), color)
			draw_line(ISO * Vector2(-4400, i * 80), ISO * Vector2(4400, i * 80), color)
		for boundary in [Layout.FLOOR, Layout.ROCK]:
			for i in boundary.size():
				draw_line(boundary[i], boundary[(i + 1) % boundary.size()], Color("dfd7a7"), 2.0, true)
