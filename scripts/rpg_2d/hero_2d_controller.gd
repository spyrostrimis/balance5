class_name Hero2DController
extends CharacterBody2D
## Dual-mode 2D Blue Commander:
## - EXPLORE: free 8-way movement & 8-way directional facing (South/North/Side + flip_h).
## - COMBAT: free X+Y depth movement, strictly Left/Right profile & strictly horizontal shots (Streets of Rage 4).

enum Mode { EXPLORE = 0, COMBAT = 1 }

signal mode_changed(new_mode: int)
signal shot_fired(origin: Vector2, dir: Vector2)

const MUZZLE_FLASH_TEX := preload("res://assets/textures/rpg_2d/sprites/muzzle_flash.png")

@export var mode: Mode = Mode.EXPLORE
@export var explore_speed: float = 150.0
@export var combat_speed_x: float = 145.0
@export var combat_speed_y: float = 105.0
@export var fire_cooldown: float = 0.22

var facing_dir_8way: Vector2 = Vector2.DOWN
var combat_facing: int = 1  # Strictly -1 (left) or +1 (right)
var projectiles_parent: Node2D = null
var shadow_polygons: Array[Polygon2D] = []
var script_input_dir: Vector2 = Vector2.ZERO
var use_script_input: bool = false

var _anim_time: float = 0.0
var _cooldown_timer: float = 0.0
var _recoil_timer: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _shadow: Sprite2D = $Shadow
@onready var _muzzle_point_r: Marker2D = $MuzzleRight


func _ready() -> void:
	_update_visuals(Vector2.ZERO)


func set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	if mode == Mode.COMBAT:
		# Inherit horizontal sign from current 8-way facing cleanly
		if facing_dir_8way.x < -0.15:
			combat_facing = -1
		elif facing_dir_8way.x > 0.15:
			combat_facing = 1
	_update_visuals(Vector2.ZERO)
	mode_changed.emit(int(mode))


func toggle_mode() -> void:
	set_mode(Mode.COMBAT if mode == Mode.EXPLORE else Mode.EXPLORE)


func step_movement(input_vec: Vector2, delta: float) -> void:
	"""Deterministic movement & facing step usable by both _physics_process and tests."""
	var move := input_vec
	if move.length() > 1.0:
		move = move.normalized()

	if mode == Mode.EXPLORE:
		velocity = move * explore_speed
		if move.length_squared() > 0.01:
			facing_dir_8way = _snap_8way(move)
			if absf(facing_dir_8way.x) > 0.15:
				combat_facing = -1 if facing_dir_8way.x < 0.0 else 1
	else:
		# Streets of Rage 4: free depth X+Y movement, facing strictly locked Left (-1) or Right (+1)
		velocity = Vector2(move.x * combat_speed_x, move.y * combat_speed_y)
		if move.x < -0.1:
			combat_facing = -1
		elif move.x > 0.1:
			combat_facing = 1
		# Vertical movement never alters combat_facing!

	move_and_slide()
	if move.length_squared() > 0.01:
		_anim_time += delta * 7.5
	else:
		_anim_time = 0.0
	_update_visuals(move)


func fire_horizontal_shot() -> RifleBolt2D:
	"""Fire a strictly horizontal bolt along combat_facing (+/-1, 0)."""
	if mode != Mode.COMBAT:
		return null
	if _cooldown_timer > 0.0:
		return null
	_cooldown_timer = fire_cooldown
	_recoil_timer = 0.11

	var dir_x := -1 if combat_facing < 0 else 1
	var dir := Vector2(float(dir_x), 0.0)
	var offset_x := 27.0 * float(dir_x)
	var offset_y := -55.0
	if _muzzle_point_r != null:
		offset_x = absf(_muzzle_point_r.position.x) * float(dir_x)
		offset_y = _muzzle_point_r.position.y
	var origin := global_position + Vector2(offset_x, offset_y)

	var bolt := RifleBolt2D.new()
	bolt.configure(origin, dir_x)
	var host := projectiles_parent if projectiles_parent != null else get_parent()
	if host != null:
		host.add_child(bolt)

	_spawn_muzzle_flash(origin, dir_x)
	_update_visuals(Vector2.ZERO)
	shot_fired.emit(origin, dir)
	return bolt


func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	if _recoil_timer > 0.0:
		_recoil_timer = maxf(0.0, _recoil_timer - delta)

	var move := script_input_dir if use_script_input else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if not use_script_input:
		# Also support WASD alongside Arrow keys cleanly
		var wasd := Vector2(
			(1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0),
			(1.0 if Input.is_key_pressed(KEY_S) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) else 0.0)
		)
		if wasd.length_squared() > 0.0:
			move = wasd.normalized()

	step_movement(move, delta)
	_apply_shadow_zone_tint()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_C:
				toggle_mode()
				get_viewport().set_input_as_handled()
			elif mode == Mode.COMBAT and (k.keycode == KEY_SPACE or k.keycode == KEY_J):
				fire_horizontal_shot()
				get_viewport().set_input_as_handled()
	elif mode == Mode.COMBAT and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			fire_horizontal_shot()
			get_viewport().set_input_as_handled()


func _snap_8way(v: Vector2) -> Vector2:
	var ang := atan2(v.y, v.x)
	var oct := int(round(ang / (PI * 0.25)))
	var snapped_ang := float(oct) * (PI * 0.25)
	var out := Vector2(cos(snapped_ang), sin(snapped_ang))
	if absf(out.x) < 0.01:
		out.x = 0.0
	if absf(out.y) < 0.01:
		out.y = 0.0
	return out.normalized()


func _update_visuals(move: Vector2) -> void:
	if _sprite == null:
		return
	var moving := move.length_squared() > 0.01
	var walk_col := 0
	if moving:
		var seq := [1, 0, 3, 2]
		walk_col = seq[int(floor(_anim_time)) % 4]

	if mode == Mode.EXPLORE:
		var row := 0
		var flip := false
		if facing_dir_8way.y < -0.35:
			row = 1  # Explore North / Back
			flip = facing_dir_8way.x > 0.15  # Slight horizontal mirror for NE/NW
		elif facing_dir_8way.y > 0.35:
			row = 0  # Explore South / Front
			flip = facing_dir_8way.x < -0.15
		else:
			row = 2  # Explore Side (E / W)
			flip = facing_dir_8way.x < 0.0
		_sprite.frame_coords = Vector2i(walk_col, row)
		_sprite.flip_h = flip
	else:
		# Streets of Rage 4 Combat Profile (Row 3)
		var col := 0
		if _recoil_timer > 0.0:
			col = 3
		elif moving:
			col = 1 if (int(floor(_anim_time)) % 2 == 0) else 2
		_sprite.frame_coords = Vector2i(col, 3)
		_sprite.flip_h = combat_facing < 0


func _spawn_muzzle_flash(origin: Vector2, dir_x: int) -> void:
	var host := projectiles_parent if projectiles_parent != null else get_parent()
	if host == null:
		return
	var fx := Node2D.new()
	fx.global_position = origin
	var sp := Sprite2D.new()
	sp.texture = MUZZLE_FLASH_TEX
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.flip_h = dir_x < 0
	sp.offset = Vector2(10.0 * float(dir_x), 0.0)
	fx.add_child(sp)

	var lt := PointLight2D.new()
	lt.texture = RifleBolt2D.create_radial_light_texture(128)
	lt.color = Color(0.65, 0.96, 1.0, 1.0)
	lt.energy = 1.95
	lt.texture_scale = 1.85
	lt.height = 24.0
	fx.add_child(lt)

	host.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(sp, "modulate:a", 0.0, 0.09)
	tw.parallel().tween_property(lt, "energy", 0.0, 0.09)
	tw.tween_callback(fx.queue_free)


func _apply_shadow_zone_tint() -> void:
	if _sprite == null:
		return
	var in_shadow := false
	for poly in shadow_polygons:
		if poly == null or not poly.visible:
			continue
		var local_pt := poly.to_local(global_position)
		if Geometry2D.is_point_in_polygon(local_pt, poly.polygon):
			in_shadow = true
			break
	var target_tint := Color(0.84, 0.77, 0.85, 1.0) if in_shadow else Color.WHITE
	_sprite.modulate = _sprite.modulate.lerp(target_tint, 0.22)
	if _shadow != null:
		_shadow.modulate.a = 0.65 if in_shadow else 0.92


func get_facing_label() -> String:
	if mode == Mode.COMBAT:
		return "LEFT (L/R LOCKED)" if combat_facing < 0 else "RIGHT (L/R LOCKED)"
	var f := facing_dir_8way
	if f.y < -0.5:
		if f.x < -0.4:
			return "NW"
		if f.x > 0.4:
			return "NE"
		return "N"
	if f.y > 0.5:
		if f.x < -0.4:
			return "SW"
		if f.x > 0.4:
			return "SE"
		return "S"
	return "W" if f.x < 0.0 else "E"
