class_name IsoBolt2D
extends Node2D
## 360-degree all-around energy bolt in strictly-isometric 2.5D space:
## - node.position = ground_pos (sorted naturally by Y-sort on the isometric floor!).
## - Draws a faint cyan ground shadow at (0, 0) and the rotated bolt + PointLight2D at (0, -altitude).
## - Connects when crossing a bat's ground radius at matching swoop altitude, or stops at stage boundaries.

const BOLT_TEX := preload("res://assets/textures/forest_fight_2/bolt_hd.png")
const HIT_SPARK_TEX := preload("res://assets/textures/forest_fight_2/bat_hit_spark_hd.png")
const SHADOW_TEX := preload("res://assets/textures/rpg_2d/sprites/contact_shadow.png")

const SPEED := 880.0
const MAX_DISTANCE := 880.0
const BAT_HIT_RADIUS := 48.0
const ALTITUDE_TOLERANCE := 62.0

var dir_2d: Vector2 = Vector2.RIGHT
var altitude: float = 84.0
var bounds_poly: PackedVector2Array = PackedVector2Array()
var bats_ref: Array = []

var spent: bool = false
var hit_bat: bool = false
var stopped_on_boundary: bool = false
var _traveled: float = 0.0

var _sprite: Sprite2D
var _shadow: Sprite2D
var _light: PointLight2D


func configure(
	start_ground: Vector2,
	direction_vec: Vector2,
	shot_altitude: float,
	stage_poly: PackedVector2Array,
	bats: Array
) -> void:
	position = start_ground
	dir_2d = direction_vec.normalized() if direction_vec.length_squared() > 0.0001 else Vector2.RIGHT
	altitude = shot_altitude
	bounds_poly = stage_poly
	bats_ref = bats


func _ready() -> void:
	_shadow = Sprite2D.new()
	_shadow.texture = SHADOW_TEX
	_shadow.scale = Vector2(0.75, 0.45)
	_shadow.modulate = Color(0.20, 0.65, 0.85, 0.24)
	add_child(_shadow)

	_sprite = Sprite2D.new()
	_sprite.texture = BOLT_TEX
	_sprite.position = Vector2(0.0, -altitude)
	_sprite.scale = Vector2(0.72, 0.72)
	_sprite.rotation = dir_2d.angle()
	add_child(_sprite)

	_light = PointLight2D.new()
	_light.texture = ForestFight2Bolt.create_radial_light(128)
	_light.position = Vector2(0.0, -altitude)
	_light.color = Color(0.45, 0.94, 1.0, 1.0)
	_light.energy = 1.15
	_light.texture_scale = 1.15
	add_child(_light)


func step_bolt(delta: float) -> void:
	if spent:
		return
	var prev := position
	var step_vec := dir_2d * SPEED * delta
	var next := prev + step_vec

	# Segment-to-point distance in ground plane against all living bats within altitude tolerance
	var best_bat: Node2D = null
	var best_d := INF
	for bat_item in bats_ref:
		if not is_instance_valid(bat_item) or not bat_item.alive:
			continue
		var bat_alt: float = float(bat_item.altitude)
		if absf(bat_alt - altitude) > ALTITUDE_TOLERANCE:
			continue
		var bat_pos: Vector2 = bat_item.position
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(bat_pos, prev, next)
		var dist: float = bat_pos.distance_to(closest)
		if dist <= BAT_HIT_RADIUS:
			var along: float = prev.distance_to(closest)
			if along < best_d:
				best_d = along
				best_bat = bat_item

	if best_bat != null:
		position = best_bat.position
		spent = true
		hit_bat = true
		best_bat.apply_hit(dir_2d)
		ForestFight2Bolt.spawn_impact_spark(get_parent(), position.x, position.y, altitude, 0.85, HIT_SPARK_TEX)
		queue_free()
		return

	_traveled += step_vec.length()
	# Allow bolts to fly slightly past the walkable foot margin (~55 px) before hitting rock walls / dissipating
	var out_of_canvas := not Rect2(40.0, 40.0, 1840.0, 1200.0).has_point(next)
	var far_from_floor := (
		not bounds_poly.is_empty()
		and not Geometry2D.is_point_in_polygon(next, bounds_poly)
		and _distance_to_poly(next, bounds_poly) > 68.0
	)
	if out_of_canvas or far_from_floor or _traveled >= MAX_DISTANCE:
		position = next
		spent = true
		stopped_on_boundary = out_of_canvas or far_from_floor
		if stopped_on_boundary:
			ForestFight2Bolt.spawn_impact_spark(get_parent(), position.x, position.y, altitude, 0.55, HIT_SPARK_TEX)
		queue_free()
		return

	position = next


static func _distance_to_poly(pt: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	var n := poly.size()
	for i in n:
		var c := Geometry2D.get_closest_point_to_segment(pt, poly[i], poly[(i + 1) % n])
		best = minf(best, pt.distance_to(c))
	return best
