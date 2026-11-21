extends Node2D

signal shot_resolved(hit: bool)

const Route := preload("res://scripts/pixel_canyon/pixel_follow_route.gd")
const Commander := preload("res://scripts/pixel_canyon/pixel_commander.gd")
const SHRUB_TEXTURE := preload("res://assets/textures/pixel_canyon/shrub.png")
const SCOUT_TEXTURE := preload("res://assets/textures/pixel_canyon/sentry.png")
const ARCH_TEXTURE := preload("res://assets/textures/pixel_canyon/arch.png")
const SHRUB_REGION := Rect2(373, 358, 90, 65)
const ARCH_REGION := Rect2(548, 25, 242, 142)
const BOOT_RADIUS := 6.0
const ROOTS_RADIUS := Vector2(29, 19)
const SHOT_SPEED := 650.0
const LANE_TOLERANCE := 17.0
const MUZZLE := Commander.RIFLE_MUZZLE

class Shot:
	var ground: Vector2
	var origin_x: float
	var facing: int

	func _init(boots: Vector2, direction: int) -> void:
		ground = boots + Vector2(MUZZLE.x * direction, 0)
		origin_x = ground.x
		facing = direction

@export_range(0.0, 16.0, 1.0) var follow_leeway := 8.0
@export var rough_art := false

var ground := Vector2.ZERO
var camera_distance := 0.0
var camera_center := 0.0
var encounter_clear := false
var showing_reference := false

var _hint_time := 0.0
var _cooldown := 0.0
var _impact_time := 0.0
var _shots: Array[Shot] = []

@onready var commander: Commander = $Depth/Commander
@onready var _shrub: Sprite2D = $Depth/Shrub
@onready var _scout: Sprite2D = $Depth/Sentry
@onready var _arch: Sprite2D = $Depth/Arch
@onready var _shadows := $Shadows
@onready var _ground_art: Node2D = $Ground
@onready var _painted_art := $PaintedArt
@onready var _effects: Node2D = $Effects
@onready var _master: Sprite2D = $"../Screen/VisualMaster"
@onready var _hint: Label = $"../Screen/Interface/Hint"


func _ready() -> void:
	_shadows.commander = commander
	_shadows.sentry = _scout
	_effects.draw.connect(_draw_shots)
	_ground_art.draw.connect(_draw_rough_ground)
	_shrub.texture = Route.region(SHRUB_TEXTURE, SHRUB_REGION)
	_scout.texture = SCOUT_TEXTURE
	_arch.texture = Route.region(ARCH_TEXTURE, ARCH_REGION)
	if "--exact" in OS.get_cmdline_user_args():
		follow_leeway = 0.0
	if "--rough" in OS.get_cmdline_user_args():
		rough_art = true
	if "--clean" not in OS.get_cmdline_user_args():
		show_controls()
	else:
		_hint.hide()
	_update_view()


func _physics_process(delta: float) -> void:
	if showing_reference:
		return
	_hint_time = maxf(_hint_time - delta, 0.0)
	_hint.visible = _hint_time > 0.0
	_cooldown = maxf(_cooldown - delta, 0.0)
	_impact_time = maxf(_impact_time - delta, 0.0)

	if not commander.advance_fire_pose(delta):
		var direction := _direction()
		if direction.x != 0.0:
			commander.facing = 1 if direction.x > 0.0 else -1
		var previous := ground
		_move(direction * Commander.WALK_SPEED * delta)
		commander.animate_stride(ground.distance_to(previous))
	if _cooldown == 0.0 and Input.is_action_just_pressed("ui_accept"):
		commander.fire()
		_shots.append(Shot.new(ground, commander.facing))
		_cooldown = 0.31
	_advance_shots(delta)
	_update_view()


func _move(step: Vector2) -> void:
	var limit := Route.ROAD_END if encounter_clear else Route.BLOCKED_AT
	var next_distance := clampf(ground.y + step.y, Route.ROAD_START, limit)
	var next_width: float = Route.road(next_distance).y - BOOT_RADIUS
	# Resolve each axis separately so boots can slide around the edge of the roots.
	var current_width: float = Route.road(ground.y).y - BOOT_RADIUS
	var sideways := Vector2(clampf(ground.x + step.x, -current_width, current_width), ground.y)
	if _outside_roots(sideways):
		ground.x = sideways.x
	var forward := Vector2(clampf(ground.x, -next_width, next_width), next_distance)
	if _outside_roots(forward):
		ground = forward
	if step.y > 0.0 and ground.y == Route.BLOCKED_AT and not encounter_clear:
		_hint.text = "The scout holds the bend. Line up your boots, then fire across the road."
		_hint_time = 2.0


func _outside_roots(point: Vector2) -> bool:
	return ((point - Route.SHRUB) / ROOTS_RADIUS).length_squared() >= 1.0


func _direction() -> Vector2:
	var left := Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)
	var right := Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D)
	var up := Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W)
	var down := Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S)
	return Vector2(int(right) - int(left), int(up) - int(down)).normalized()


func set_leeway(pixels: float) -> void:
	follow_leeway = pixels
	_update_view()
	show_controls()


func set_reference(enabled: bool) -> void:
	showing_reference = enabled
	_master.visible = enabled
	_hint.visible = not enabled and _hint_time > 0.0


func show_controls() -> void:
	if showing_reference:
		return
	var follow := "Exact follow" if follow_leeway == 0.0 else "%d px leeway" % follow_leeway
	_hint.text = "%s    •    Arrows / WASD  Move    Space  Fire    1 / 2  Follow    F2  Reference    F3  Rough art    F11  Fullscreen" % follow
	_hint_time = 5.0
	_hint.show()


func set_rough_art(enabled: bool) -> void:
	rough_art = enabled
	_update_view()


func _update_view() -> void:
	var far := Route.distance_at(Route.BOOTS.y - follow_leeway)
	var near := Route.distance_at(Route.BOOTS.y + follow_leeway)
	camera_distance = clampf(camera_distance, ground.y - far, ground.y - near)
	camera_center = Route.road(camera_distance).x

	commander.set_projection(project(ground), Route.scale_at(ground.y, camera_distance))
	_place_sprite(_shrub, Route.SHRUB, Vector2(41, 48), 1.0)
	if not encounter_clear:
		_place_sprite(_scout, Route.SCOUT, Commander.PIVOT, 1.0)
	_arch.visible = false
	if not rough_art:
		_place_sprite(_arch, Route.ARCH, Vector2(121, 134), 1.68)
	_shadows.queue_redraw()
	_effects.queue_redraw()
	_ground_art.visible = rough_art
	_ground_art.queue_redraw()
	_painted_art.apply_view(camera_distance, camera_center, not rough_art)


func project(point: Vector2) -> Vector2:
	return Route.project(point, camera_distance, camera_center)


func _place_sprite(sprite: Sprite2D, point: Vector2, pivot: Vector2, size: float) -> void:
	sprite.visible = point.y - camera_distance > Route.distance_at(740)
	if not sprite.visible:
		return
	var view_scale := Route.scale_at(point.y, camera_distance) * size
	sprite.position = project(point).round()
	sprite.scale = Vector2.ONE * view_scale
	sprite.offset = (-pivot * view_scale).round() / view_scale


func _advance_shots(delta: float) -> void:
	for index in range(_shots.size() - 1, -1, -1):
		var shot := _shots[index]
		var previous_x := shot.ground.x
		shot.ground.x += shot.facing * SHOT_SPEED * delta
		if not encounter_clear and absf(shot.ground.y - Route.SCOUT.y) <= LANE_TOLERANCE \
			and Route.SCOUT.x >= minf(previous_x, shot.ground.x) \
			and Route.SCOUT.x <= maxf(previous_x, shot.ground.x):
			encounter_clear = true
			_scout.hide()
			_shadows.sentry = null
			_impact_time = 0.28
			_shots.remove_at(index)
			shot_resolved.emit(true)
		elif absf(shot.ground.x - shot.origin_x) > 510.0:
			_shots.remove_at(index)
			shot_resolved.emit(false)


func _draw_shots() -> void:
	for shot in _shots:
		var view_scale := Route.scale_at(shot.ground.y, camera_distance)
		var elevation := Vector2(0, MUZZLE.y * view_scale)
		var head := (project(shot.ground) + elevation).round()
		var origin := (project(Vector2(shot.origin_x, shot.ground.y)) + elevation).round()
		var tail := move_toward(head.x, origin.x, 21.0 * view_scale)
		var strip := Rect2(minf(tail, head.x), head.y - 1.0, absf(head.x - tail) + 1.0, 3.0)
		_effects.draw_rect(strip, Color("#c36c3b"))
		_effects.draw_rect(Rect2(strip.position + Vector2(1, 1), Vector2(maxf(strip.size.x - 2.0, 2.0), 1)), Color("#fff0b0"))
		if absf(head.x - origin.x) < 40.0:
			_effects.draw_rect(Rect2(origin - Vector2(4, 3), Vector2(9, 6)), Color("#ef9d50"))
			_effects.draw_rect(Rect2(origin - Vector2(2, 1), Vector2(12, 3)), Color("#fff0b0"))
	if _impact_time > 0.0:
		var view_scale := Route.scale_at(Route.SCOUT.y, camera_distance)
		var impact := project(Route.SCOUT) + Vector2(0, MUZZLE.y * view_scale)
		var spread := 4.0 + (0.28 - _impact_time) * 61.0
		for ray: Vector2 in [Vector2(-1, -1), Vector2(1, -0.6), Vector2(0.5, 1), Vector2(-0.9, 0.45)]:
			_effects.draw_rect(Rect2((impact + ray * spread * view_scale).round(), Vector2(4, 3)), Color("#ffc87a"))


func _draw_rough_ground() -> void:
	_ground_art.draw_rect(Rect2(0, 0, 960, 540), Color("#b9999c"))
	var near_row := floori((camera_distance + Route.distance_at(545)) / 24.0)
	var far_row := ceili((camera_distance + 3600.0) / 24.0)
	for row in range(far_row, near_row - 1, -1):
		var back := row * 24.0 + 24.0
		var front := row * 24.0
		if roundf(project(Vector2(0, back)).y) == roundf(project(Vector2(0, front)).y):
			continue
		var left_far: float = -Route.road(back).y
		var left_near: float = -Route.road(front).y
		_ground_art.draw_colored_polygon(_quad(-1100, 1100, -1100, 1100, back, front), Color("#755567"))
		_ground_art.draw_colored_polygon(_quad(left_far, -left_far, left_near, -left_near, back, front),
			Color("#bd8d69") if posmod(row, 2) == 0 else Color("#b48766"))
		for side: float in [-1.0, 1.0]:
			_ground_art.draw_colored_polygon(_quad(
				side * -left_far, side * (-left_far + 12), side * -left_near, side * (-left_near + 12), back, front),
				Color("#e2b383") if posmod(row, 3) == 0 else Color("#9b6d66"))
	var arch := project(Route.ARCH).round()
	var view_scale := Route.scale_at(Route.ARCH.y, camera_distance)
	for column: int in [-160, 0, 160]:
		_ground_art.draw_rect(Rect2((arch + Vector2(column - 13, -200) * view_scale).round(), (Vector2(26, 200) * view_scale).round()), Color("#755055"))
	_ground_art.draw_rect(Rect2((arch + Vector2(-173, -207) * view_scale).round(), (Vector2(346, 27) * view_scale).round()), Color("#936568"))
	for distance: float in [555.0, 485.0, 405.0, 335.0, 270.0]:
		if distance - camera_distance < Route.distance_at(600):
			continue
		var side := -1.0 if distance < 460.0 else 1.0
		var rock := project(Vector2(side * (Route.road(distance).y + 58.0), distance))
		var scale := Route.scale_at(distance, camera_distance)
		_ground_art.draw_rect(Rect2((rock - Vector2(85, 252) * scale).round(), (Vector2(170, 252) * scale).round()), Color("#735063"))


func _quad(left_far: float, right_far: float, left_near: float, right_near: float, back: float, front: float) -> PackedVector2Array:
	return PackedVector2Array([
		project(Vector2(left_far, back)).round(), project(Vector2(right_far, back)).round(),
		project(Vector2(right_near, front)).round(), project(Vector2(left_near, front)).round(),
	])
