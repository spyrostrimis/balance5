class_name RedTrooper2D
extends CharacterBody2D
## Red faction canyon guard (horizontal patrol, combat alert facing, hit stagger, resettable).

signal defeated(trooper: RedTrooper2D)

@export var max_hp: int = 3
@export var patrol_range_px: float = 48.0
@export var patrol_speed: float = 46.0
@export var alert_radius: float = 280.0

var hp: int = 3
var is_defeated: bool = false
var facing: int = -1

var _spawn_pos: Vector2 = Vector2.ZERO
var _patrol_dir: int = 1
var _anim_timer: float = 0.0
var _hit_timer: float = 0.0
var _knockback_x: float = 0.0
var _alerted: bool = false
var _hero: Node2D = null

@onready var _sprite: Sprite2D = $Sprite
@onready var _shadow: Sprite2D = $Shadow
@onready var _hp_bar_fill: ColorRect = $HpBar/Fill
@onready var _hp_bar_root: Control = $HpBar
@onready var _collider: CollisionShape2D = $CollisionShape2D
@onready var _hitbox_shape: CollisionShape2D = $HitBox/CollisionShape2D


func _ready() -> void:
	_spawn_pos = global_position
	hp = max_hp
	_update_hp_bar()


func set_hero_ref(hero: Node2D) -> void:
	_hero = hero


func reset_trooper() -> void:
	is_defeated = false
	hp = max_hp
	global_position = _spawn_pos
	_patrol_dir = 1
	_hit_timer = 0.0
	_knockback_x = 0.0
	_alerted = false
	visible = true
	if _collider != null:
		_collider.set_deferred("disabled", false)
	if _hitbox_shape != null:
		_hitbox_shape.set_deferred("disabled", false)
	if _sprite != null:
		_sprite.modulate = Color.WHITE
		_sprite.frame_coords = Vector2i(0, 0)
	_update_hp_bar()


func apply_hit(dmg: int, from_dir_x: int) -> void:
	if is_defeated:
		return
	hp = maxi(0, hp - dmg)
	_hit_timer = 0.16
	_knockback_x = float(from_dir_x) * 85.0
	facing = -from_dir_x if from_dir_x != 0 else facing
	_update_hp_bar()
	if hp <= 0:
		is_defeated = true
		visible = false
		if _collider != null:
			_collider.set_deferred("disabled", true)
		if _hitbox_shape != null:
			_hitbox_shape.set_deferred("disabled", true)
		defeated.emit(self)


func _physics_process(delta: float) -> void:
	if is_defeated:
		return

	if _hit_timer > 0.0:
		_hit_timer = maxf(0.0, _hit_timer - delta)
		velocity = Vector2(_knockback_x, 0.0)
		_knockback_x = lerpf(_knockback_x, 0.0, minf(1.0, delta * 14.0))
		move_and_slide()
		if _sprite != null:
			_sprite.frame_coords = Vector2i(3, 1)
			_sprite.flip_h = facing < 0
			_sprite.modulate = Color(1.35, 1.15, 1.15, 1.0)
		return

	if _sprite != null:
		_sprite.modulate = Color.WHITE

	_alerted = false
	if _hero != null:
		var delta_to_hero := _hero.global_position - global_position
		if delta_to_hero.length() <= alert_radius:
			_alerted = true
			if absf(delta_to_hero.x) > 4.0:
				facing = -1 if delta_to_hero.x < 0.0 else 1

	if _alerted:
		velocity = Vector2.ZERO
		if _sprite != null:
			_sprite.frame_coords = Vector2i(0, 1)
			_sprite.flip_h = facing < 0
	else:
		var offset_x := global_position.x - _spawn_pos.x
		if offset_x >= patrol_range_px:
			_patrol_dir = -1
		elif offset_x <= -patrol_range_px:
			_patrol_dir = 1
		facing = _patrol_dir
		velocity = Vector2(float(_patrol_dir) * patrol_speed, 0.0)
		move_and_slide()
		if get_slide_collision_count() > 0:
			_patrol_dir *= -1

		_anim_timer += delta
		var col := int(floor(_anim_timer * 6.0)) % 4
		if _sprite != null:
			_sprite.frame_coords = Vector2i(col, 0)
			_sprite.flip_h = facing < 0


func _update_hp_bar() -> void:
	if _hp_bar_root == null or _hp_bar_fill == null:
		return
	_hp_bar_root.visible = not is_defeated and hp < max_hp
	var frac := clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	_hp_bar_fill.size.x = 24.0 * frac
