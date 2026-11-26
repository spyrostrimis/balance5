class_name IsoCommander2D
extends Node2D
## Unified Single-Mode Strictly-Isometric Blue Commander (“One Mode for All”):
## - Constant sprite scale everywhere (zero perspective shrink, identical in Forest & Cavern).
## - Free 360-degree movement inside the active isometric floor polygon with smooth edge sliding.
## - All-around 360-degree aiming & shooting (Mouse cursor 360° aim/click OR 8-way WASD + Space/J).
## - Zero health loss; bat contacts spark harmless cyan-blue armour energy.

signal shot_spawned(bolt: IsoBolt2D)
signal armour_contacted(total_contacts: int)

const ISO_ATLAS_TEX := preload("res://assets/textures/forest_fight_3/commander_iso_8way.png")
const SHADOW_TEX := preload("res://assets/textures/rpg_2d/sprites/contact_shadow.png")
const MUZZLE_FLASH_TEX := preload("res://assets/textures/forest_fight_2/muzzle_flash_hd.png")
const ARMOUR_SPARK_TEX := preload("res://assets/textures/forest_fight_2/armour_spark_hd.png")

## Cell is 320x320 with boots anchored at (160, 296) -> offset (0, -136).
## Unscaled character height = 256 px. Scale 0.565 -> 144.6 px (18.8% of 768 px viewport, loyal to reference!).
const UNSCALED_IDLE_HEIGHT := 256.0
const SPRITE_SCALE := 0.565
const RIFLE_ALTITUDE := 84.0
const MUZZLE_RADIUS := 42.0

## Isometric ground speed (4:3 X:Y ratio matches ~30-deg 2:1 isometric projection naturally)
const MOVE_SPEED := Vector2(264.0, 198.0)
const WALK_FPS := 8.5
const FIRE_COOLDOWN := 0.20

var aim_dir: Vector2 = Vector2(0.866, -0.5).normalized()  # Default NE up the isometric trail!
var controls_enabled: bool = true
var contact_count: int = 0
var walk_polygon: PackedVector2Array = PackedVector2Array()
var actors_host: Node2D = null
var bats_ref: Array = []

var _walk_phase: float = 0.0
var _cooldown_timer: float = 0.0
var _mouse_aim_hold: float = 0.0
var _armour_flash_timer: float = 0.0

var sprite: Sprite2D
var shadow: Sprite2D


func _ready() -> void:
	shadow = Sprite2D.new()
	shadow.texture = SHADOW_TEX
	shadow.position = Vector2(0.0, -2.0)
	shadow.scale = Vector2(1.42, 0.88)
	shadow.modulate = Color(0.14, 0.11, 0.09, 0.56)
	add_child(shadow)

	sprite = Sprite2D.new()
	sprite.texture = ISO_ATLAS_TEX
	sprite.hframes = 3
	sprite.vframes = 5
	sprite.offset = Vector2(0.0, -136.0)
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(sprite)

	_apply_visuals(false)


func rendered_height_px() -> float:
	return UNSCALED_IDLE_HEIGHT * SPRITE_SCALE


func rifle_pivot_screen_world() -> Vector2:
	return Vector2(position.x, position.y - RIFLE_ALTITUDE)


func aim_toward_world_point(world_target: Vector2) -> void:
	var delta_v := world_target - rifle_pivot_screen_world()
	if delta_v.length_squared() > 4.0:
		aim_dir = delta_v.normalized()
		_mouse_aim_hold = 0.65
		_apply_visuals(false)


func step_hero(move_input: Vector2, delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	if _mouse_aim_hold > 0.0:
		_mouse_aim_hold = maxf(0.0, _mouse_aim_hold - delta)
	if _armour_flash_timer > 0.0:
		_armour_flash_timer = maxf(0.0, _armour_flash_timer - delta)

	var dir := move_input.limit_length(1.0)
	if dir.length_squared() > 0.01 and _mouse_aim_hold <= 0.0:
		aim_dir = dir.normalized()

	var prev := position
	if dir.length_squared() > 0.0001 and controls_enabled:
		var step_vec := Vector2(dir.x * MOVE_SPEED.x, dir.y * MOVE_SPEED.y) * delta
		position = _move_inside_polygon(prev, step_vec)

	var moved := (position - prev).length_squared() > 0.01
	if moved:
		_walk_phase = fposmod(_walk_phase + delta * WALK_FPS, 4.0)
	else:
		_walk_phase = 0.0

	_apply_visuals(moved)


func step_scripted_to(target: Vector2, speed: float, delta: float) -> bool:
	var to_t := target - position
	var d := to_t.length()
	if d <= 1.5:
		position = target
		_walk_phase = 0.0
		_apply_visuals(false)
		return true
	var step_v := to_t.normalized() * minf(d, speed * delta)
	aim_dir = to_t.normalized()
	position += step_v
	_walk_phase = fposmod(_walk_phase + delta * WALK_FPS, 4.0)
	_apply_visuals(true)
	return false


func fire_shot_in_direction(custom_dir: Vector2 = Vector2.ZERO) -> IsoBolt2D:
	if not controls_enabled or _cooldown_timer > 0.0:
		return null
	var shot_dir := custom_dir.normalized() if custom_dir.length_squared() > 0.001 else aim_dir.normalized()
	if shot_dir.length_squared() < 0.001:
		shot_dir = Vector2.RIGHT

	aim_dir = shot_dir
	_cooldown_timer = FIRE_COOLDOWN

	var start_ground := position + shot_dir * MUZZLE_RADIUS
	var bolt := IsoBolt2D.new()
	bolt.configure(start_ground, shot_dir, RIFLE_ALTITUDE, walk_polygon, bats_ref)
	if actors_host != null:
		actors_host.add_child(bolt)

	_spawn_directional_muzzle_flash(start_ground, shot_dir)
	_apply_visuals(false)
	shot_spawned.emit(bolt)
	return bolt


func fire_at_world_point(world_target: Vector2) -> IsoBolt2D:
	var v := world_target - rifle_pivot_screen_world()
	var d := v.normalized() if v.length_squared() > 4.0 else aim_dir
	_mouse_aim_hold = 0.70
	return fire_shot_in_direction(d)


func register_bat_contact(bat_ground: Vector2) -> void:
	contact_count += 1
	_armour_flash_timer = 0.16
	var spark_pos := position.lerp(bat_ground, 0.35)
	ForestFight2Bolt.spawn_impact_spark(
		actors_host,
		spark_pos.x,
		spark_pos.y + 1.0,
		RIFLE_ALTITUDE + 6.0,
		0.72,
		ARMOUR_SPARK_TEX,
		Color(0.55, 0.92, 1.0, 1.0)
	)
	_apply_visuals(false)
	armour_contacted.emit(contact_count)


func _move_inside_polygon(from_pos: Vector2, step_vec: Vector2) -> Vector2:
	if walk_polygon.is_empty():
		return from_pos + step_vec
	var candidate := from_pos + step_vec
	if Geometry2D.is_point_in_polygon(candidate, walk_polygon):
		return candidate

	# Try sliding along nearest polygon edge tangent so diagonal isometric borders feel buttery smooth!
	var best_edge_a := walk_polygon[0]
	var best_edge_b := walk_polygon[1]
	var best_dist := INF
	var n := walk_polygon.size()
	for i in n:
		var a := walk_polygon[i]
		var b := walk_polygon[(i + 1) % n]
		var cp := Geometry2D.get_closest_point_to_segment(candidate, a, b)
		var d := candidate.distance_to(cp)
		if d < best_dist:
			best_dist = d
			best_edge_a = a
			best_edge_b = b

	var tangent: Vector2 = (best_edge_b - best_edge_a).normalized()
	var slide_step: Vector2 = tangent * step_vec.dot(tangent)
	var scales: Array[float] = [1.0, 0.65, 0.35]
	for scale_try in scales:
		var slid: Vector2 = from_pos + slide_step * scale_try
		if Geometry2D.is_point_in_polygon(slid, walk_polygon):
			return slid
	return from_pos


func _spawn_directional_muzzle_flash(ground_origin: Vector2, shot_dir: Vector2) -> void:
	if actors_host == null:
		return
	var fx := Node2D.new()
	fx.position = ground_origin + Vector2(0.0, 1.0)

	var sp := Sprite2D.new()
	sp.texture = MUZZLE_FLASH_TEX
	sp.position = Vector2(0.0, -RIFLE_ALTITUDE) + shot_dir * 12.0
	sp.scale = Vector2.ONE * 0.68
	sp.rotation = shot_dir.angle()
	fx.add_child(sp)

	var lt := PointLight2D.new()
	lt.texture = ForestFight2Bolt.create_radial_light(128)
	lt.position = Vector2(0.0, -RIFLE_ALTITUDE)
	lt.color = Color(0.55, 0.94, 1.0, 1.0)
	lt.energy = 1.35
	lt.texture_scale = 1.35
	fx.add_child(lt)

	actors_host.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(sp, "modulate:a", 0.0, 0.09)
	tw.parallel().tween_property(lt, "energy", 0.0, 0.09)
	tw.tween_callback(fx.queue_free)


func octant_for_direction(dir: Vector2) -> int:
	return posmod(int(round(atan2(dir.y, dir.x) / (PI * 0.25))), 8)


func _apply_visuals(moving: bool) -> void:
	if sprite == null:
		return
	sprite.scale = Vector2.ONE * SPRITE_SCALE

	# Map 8 compass octants (0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE)
	# to commander_iso_8way.png rows (0=SE, 1=NE, 2=E, 3=S, 4=N) + flip_h
	var oct := octant_for_direction(aim_dir)
	var row := 0
	var flip := false
	match oct:
		0: # East
			row = 2
			flip = false
		1: # South-East
			row = 0
			flip = false
		2: # South
			row = 3
			flip = false
		3: # South-West
			row = 0
			flip = true
		4: # West
			row = 2
			flip = true
		5: # North-West
			row = 1
			flip = true
		6: # North
			row = 4
			flip = false
		7: # North-East
			row = 1
			flip = false

	var seq: Array[int] = [1, 0, 2, 0]
	var col: int = seq[int(floor(_walk_phase)) % 4] if moving else 0
	sprite.frame_coords = Vector2i(col, row)
	sprite.flip_h = flip

	var base_col := Color.WHITE
	if _armour_flash_timer > 0.0:
		base_col = base_col.lerp(Color(0.62, 1.18, 1.48, 1.0), 0.68)
	sprite.modulate = base_col
