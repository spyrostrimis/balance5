class_name ForestFight2Bolt
extends Node2D
## Strictly horizontal rifle bolt in 2.5D cave space:
## - node.position = Vector2(x, depth_y) so Y-sort orders bolts naturally by floor depth lane!
## - visual sprite & PointLight2D sit at y = -altitude.
## - Stops at the first valid in-lane bat OR solid left/right cave wall.

const BOLT_TEX := preload("res://assets/textures/forest_fight_2/bolt_hd.png")
const HIT_SPARK_TEX := preload("res://assets/textures/forest_fight_2/bat_hit_spark_hd.png")

const SPEED := 920.0
const DEPTH_LANE_TOLERANCE := 36.0
const ALTITUDE_TOLERANCE := 66.0
const BAT_HALF_WIDTH := 54.0

var dir_x: int = 1
var depth_y: float = 770.0
var altitude: float = 216.0
var wall_left_x: float = 68.0
var wall_right_x: float = 1468.0
var bats_ref: Array = []
var spent: bool = false
var stopped_on_wall: bool = false
var hit_bat: bool = false

var _sprite: Sprite2D
var _light: PointLight2D


static func create_radial_light(size: int = 128) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.45, 0.92, 1.0, 0.48),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


func configure(
	start_x: float,
	lane_depth_y: float,
	shot_altitude: float,
	facing_dir: int,
	left_wall: float,
	right_wall: float,
	bats: Array
) -> void:
	dir_x = -1 if facing_dir < 0 else 1
	depth_y = lane_depth_y
	altitude = shot_altitude
	wall_left_x = left_wall
	wall_right_x = right_wall
	bats_ref = bats
	position = Vector2(start_x, depth_y)


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = BOLT_TEX
	_sprite.position = Vector2(0.0, -altitude)
	_sprite.flip_h = dir_x < 0
	add_child(_sprite)

	_light = PointLight2D.new()
	_light.texture = create_radial_light(128)
	_light.position = Vector2(0.0, -altitude)
	_light.color = Color(0.42, 0.94, 1.0, 1.0)
	_light.energy = 1.35
	_light.texture_scale = 1.45
	add_child(_light)


func step_bolt(delta: float) -> void:
	if spent:
		return
	var prev_x := position.x
	var next_x := prev_x + float(dir_x) * SPEED * delta

	# Sweep-check all living bats in front of the bolt along the horizontal segment [prev_x, next_x]
	var seg_min := minf(prev_x, next_x) - BAT_HALF_WIDTH
	var seg_max := maxf(prev_x, next_x) + BAT_HALF_WIDTH
	var best_bat: Node2D = null
	var best_dist := INF

	for bat in bats_ref:
		if not is_instance_valid(bat) or not bat.alive:
			continue
		if absf(bat.depth_y - depth_y) > DEPTH_LANE_TOLERANCE:
			continue
		if absf(bat.altitude - altitude) > ALTITUDE_TOLERANCE:
			continue
		if bat.position.x < seg_min or bat.position.x > seg_max:
			continue
		var d := absf(bat.position.x - prev_x)
		if d < best_dist:
			best_dist = d
			best_bat = bat

	if best_bat != null:
		position.x = best_bat.position.x
		spent = true
		hit_bat = true
		best_bat.apply_hit(dir_x)
		spawn_impact_spark(get_parent(), position.x, depth_y, altitude, 1.0)
		queue_free()
		return

	if (dir_x < 0 and next_x <= wall_left_x) or (dir_x > 0 and next_x >= wall_right_x):
		position.x = clampf(next_x, wall_left_x, wall_right_x)
		spent = true
		stopped_on_wall = true
		spawn_impact_spark(get_parent(), position.x, depth_y, altitude, 0.68)
		queue_free()
		return

	position.x = next_x


static func spawn_impact_spark(
	host: Node,
	world_x: float,
	lane_y: float,
	alt: float,
	scale_mult: float = 1.0,
	custom_tex: Texture2D = null,
	tint: Color = Color.WHITE
) -> void:
	if host == null:
		return
	var fx := Node2D.new()
	fx.position = Vector2(world_x, lane_y)

	var sp := Sprite2D.new()
	sp.texture = custom_tex if custom_tex != null else HIT_SPARK_TEX
	sp.position = Vector2(0.0, -alt)
	sp.scale = Vector2.ONE * scale_mult
	sp.modulate = tint
	fx.add_child(sp)

	var lt := PointLight2D.new()
	lt.texture = create_radial_light(128)
	lt.position = Vector2(0.0, -alt)
	lt.color = Color(0.45, 0.95, 1.0, 1.0)
	lt.energy = 1.6 * scale_mult
	lt.texture_scale = 1.5 * scale_mult
	fx.add_child(lt)

	host.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(sp, "scale", Vector2.ONE * (scale_mult * 1.35), 0.16)
	tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.16)
	tw.parallel().tween_property(lt, "energy", 0.0, 0.16)
	tw.tween_callback(fx.queue_free)
