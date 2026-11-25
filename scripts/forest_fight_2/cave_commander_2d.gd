class_name CaveCommander2D
extends Node2D
## Streets of Rage 4 side-profile Blue Commander for the cave arena:
## - Moves freely in X and floor depth Y (including diagonals).
## - Strictly two facings: Left (-1) or Right (+1). Pure depth movement never flips facing.
## - Fires strictly horizontal bolts from her visible muzzle regardless of mouse cursor position.
## - Zero health loss / wounds; bat contact triggers a crisp cyan-blue armour deflection spark.

signal shot_spawned(bolt: ForestFight2Bolt)
signal armour_contacted(total_contacts: int)

const HD_COMBAT_TEX := preload("res://assets/textures/forest_fight_2/commander_hd_combat.png")
const SHADOW_TEX := preload("res://assets/textures/rpg_2d/sprites/contact_shadow.png")
const MUZZLE_FLASH_TEX := preload("res://assets/textures/forest_fight_2/muzzle_flash_hd.png")
const ARMOUR_SPARK_TEX := preload("res://assets/textures/forest_fight_2/armour_spark_hd.png")

## Cell is 360x360 with boot soles anchored at (180, 342) -> offset (0, -162).
## Unscaled visible character height = 308 px. Scale 0.8961 -> 276.0 px (35.9% of 768 px viewport).
const SOURCE_IDLE_HEIGHT := 308.0
const TARGET_MID_HEIGHT := 276.0
const BASE_SPRITE_SCALE := TARGET_MID_HEIGHT / SOURCE_IDLE_HEIGHT
const MUZZLE_REL_BOOT_UNSCALED := Vector2(166.0, -242.0)

const DEPTH_MIN_Y := 636.0
const DEPTH_MAX_Y := 906.0
const FLOOR_RIGHT_X := 1426.0

const SPEED_X := 310.0
const SPEED_Y := 215.0
const WALK_FPS := 8.2
const FIRE_COOLDOWN := 0.22
const RECOIL_DURATION := 0.12

var combat_facing: int = 1  # Strictly -1 (left) or +1 (right)
var depth_y: float = 770.0
var controls_enabled: bool = false
var contact_count: int = 0
var actors_host: Node2D = null
var bats_ref: Array = []

var _walk_phase: float = 0.0
var _cooldown_timer: float = 0.0
var _recoil_timer: float = 0.0
var _armour_flash_timer: float = 0.0

var sprite: Sprite2D
var shadow: Sprite2D


static func floor_left_limit(y_lane: float) -> float:
	# Follows the angled sunlit entrance rock base on the left (x=122 at back wall -> x=88 near front)
	var t := clampf(inverse_lerp(DEPTH_MIN_Y, DEPTH_MAX_Y, y_lane), 0.0, 1.0)
	return lerpf(122.0, 88.0, t)


static func depth_scale_factor(y_lane: float) -> float:
	# Subtle Streets of Rage 4 depth scale (~0.94 at back wall, 1.00 at middle 770, ~1.05 near front)
	var t := clampf(inverse_lerp(DEPTH_MIN_Y, DEPTH_MAX_Y, y_lane), 0.0, 1.0)
	return lerpf(0.94, 1.05, t)


func _ready() -> void:
	shadow = Sprite2D.new()
	shadow.texture = SHADOW_TEX
	shadow.position = Vector2(0.0, -3.0)
	shadow.scale = Vector2(2.35, 1.45)
	shadow.modulate = Color(0.08, 0.06, 0.05, 0.64)
	add_child(shadow)

	sprite = Sprite2D.new()
	sprite.texture = HD_COMBAT_TEX
	sprite.hframes = 6
	sprite.vframes = 1
	sprite.offset = Vector2(0.0, -162.0)
	add_child(sprite)

	set_floor_position(Vector2(305.0, 770.0), 1)
	_apply_visuals(false)


func set_floor_position(pos: Vector2, facing_sign: int = 0) -> void:
	depth_y = clampf(pos.y, DEPTH_MIN_Y, DEPTH_MAX_Y)
	var x_clamped := clampf(pos.x, floor_left_limit(depth_y), FLOOR_RIGHT_X)
	position = Vector2(x_clamped, depth_y)
	if facing_sign != 0:
		combat_facing = -1 if facing_sign < 0 else 1
	_apply_visuals(false)


func current_sprite_scale() -> float:
	return BASE_SPRITE_SCALE * depth_scale_factor(depth_y)


func rendered_height_px() -> float:
	return SOURCE_IDLE_HEIGHT * current_sprite_scale()


func muzzle_altitude() -> float:
	return absf(MUZZLE_REL_BOOT_UNSCALED.y) * current_sprite_scale()


func muzzle_world_x(dir_sign: int) -> float:
	return position.x + MUZZLE_REL_BOOT_UNSCALED.x * current_sprite_scale() * float(dir_sign)


func step_combat(input_dir: Vector2, delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	if _recoil_timer > 0.0:
		_recoil_timer = maxf(0.0, _recoil_timer - delta)
	if _armour_flash_timer > 0.0:
		_armour_flash_timer = maxf(0.0, _armour_flash_timer - delta)

	var move := input_dir.limit_length(1.0)
	# Strictly two facings: pure vertical/depth movement NEVER changes combat_facing!
	if move.x < -0.08:
		combat_facing = -1
	elif move.x > 0.08:
		combat_facing = 1

	var prev := position
	var d_factor := depth_scale_factor(depth_y)
	var next_y := clampf(prev.y + move.y * SPEED_Y * d_factor * delta, DEPTH_MIN_Y, DEPTH_MAX_Y)
	var next_x := clampf(
		prev.x + move.x * SPEED_X * d_factor * delta,
		floor_left_limit(next_y),
		FLOOR_RIGHT_X
	)
	position = Vector2(next_x, next_y)
	depth_y = next_y

	var moved := (position - prev).length_squared() > 0.01
	if moved:
		_walk_phase = fposmod(_walk_phase + delta * WALK_FPS, 4.0)
	else:
		_walk_phase = 0.0

	_apply_visuals(moved)


func step_scripted_walk(target: Vector2, speed: float, delta: float) -> bool:
	if _armour_flash_timer > 0.0:
		_armour_flash_timer = maxf(0.0, _armour_flash_timer - delta)
	var to_target := target - position
	var dist := to_target.length()
	if dist <= 1.5:
		position = target
		depth_y = target.y
		_walk_phase = 0.0
		_apply_visuals(false)
		return true
	var step := to_target.normalized() * minf(dist, speed * delta)
	if absf(step.x) > 0.05:
		combat_facing = -1 if step.x < 0.0 else 1
	position += step
	depth_y = position.y
	_walk_phase = fposmod(_walk_phase + delta * WALK_FPS, 4.0)
	_apply_visuals(true)
	return false


func fire_horizontal_shot() -> ForestFight2Bolt:
	if not controls_enabled or _cooldown_timer > 0.0:
		return null
	_cooldown_timer = FIRE_COOLDOWN
	_recoil_timer = RECOIL_DURATION

	var dir_sign := -1 if combat_facing < 0 else 1
	var shot_alt := muzzle_altitude()
	var origin_x := muzzle_world_x(dir_sign)

	var bolt := ForestFight2Bolt.new()
	bolt.configure(origin_x, depth_y, shot_alt, dir_sign, 56.0, 1480.0, bats_ref)
	if actors_host != null:
		actors_host.add_child(bolt)

	_spawn_muzzle_flash(origin_x, depth_y, shot_alt, dir_sign)
	_apply_visuals(false)
	shot_spawned.emit(bolt)
	return bolt


func register_bat_contact(impact_x: float, impact_alt: float) -> void:
	contact_count += 1
	_armour_flash_timer = 0.16
	var spark_x := lerpf(position.x, impact_x, 0.35)
	var spark_alt := clampf(impact_alt, 130.0, 235.0)
	ForestFight2Bolt.spawn_impact_spark(
		actors_host,
		spark_x,
		depth_y + 1.0,
		spark_alt,
		0.92,
		ARMOUR_SPARK_TEX,
		Color(0.55, 0.90, 1.0, 1.0)
	)
	_apply_visuals(false)
	armour_contacted.emit(contact_count)


func _spawn_muzzle_flash(origin_x: float, lane_y: float, alt: float, dir_sign: int) -> void:
	if actors_host == null:
		return
	var fx := Node2D.new()
	fx.position = Vector2(origin_x, lane_y + 1.0)

	var sp := Sprite2D.new()
	sp.texture = MUZZLE_FLASH_TEX
	sp.position = Vector2(22.0 * float(dir_sign), -alt)
	sp.flip_h = dir_sign < 0
	fx.add_child(sp)

	var lt := PointLight2D.new()
	lt.texture = ForestFight2Bolt.create_radial_light(128)
	lt.position = Vector2(12.0 * float(dir_sign), -alt)
	lt.color = Color(0.50, 0.94, 1.0, 1.0)
	lt.energy = 1.75
	lt.texture_scale = 1.9
	fx.add_child(lt)

	actors_host.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(sp, "modulate:a", 0.0, 0.09)
	tw.parallel().tween_property(lt, "energy", 0.0, 0.09)
	tw.tween_callback(fx.queue_free)


func _apply_visuals(moving: bool) -> void:
	if sprite == null:
		return
	var s := current_sprite_scale()
	sprite.scale = Vector2.ONE * s
	shadow.scale = Vector2(2.35, 1.45) * depth_scale_factor(depth_y)

	var frame_idx := 0
	if _recoil_timer > 0.0:
		frame_idx = 5
	elif moving:
		frame_idx = 1 + (int(floor(_walk_phase)) % 4)
	sprite.frame = frame_idx
	sprite.flip_h = combat_facing < 0

	# Blend warm golden jungle doorway light on the left into cool slate-teal cavern bounce deeper inside
	var sun_blend := clampf(inverse_lerp(520.0, 165.0, position.x), 0.0, 1.0)
	var base_tint := Color(0.96, 0.98, 1.03).lerp(Color(1.08, 0.99, 0.88), sun_blend)
	if _armour_flash_timer > 0.0:
		base_tint = base_tint.lerp(Color(0.65, 1.18, 1.45), 0.65)
	sprite.modulate = base_tint
