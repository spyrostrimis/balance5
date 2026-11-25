class_name Approach3Commander
extends Hero2DController
## The sheet anchors all frames at source pixel (80, 160).

const DRAW_DENSITY := 765.0 / 540.0
const CELL_HALF_HEIGHT := 84.0
const ANCHOR_Y := 160.0

@export var atlas_720: Texture2D
@export var recoil_muzzle := Vector2(70.0, -116.5)
@export var recoil_muzzle_720 := Vector2(66.0, -109.5)

var painted_shade_on := true
var _draw_scale := 1.0 / DRAW_DENSITY
var _active_muzzle := Vector2.ZERO
var _atlas_765: Texture2D


func _ready() -> void:
	_atlas_765 = _sprite.texture
	_active_muzzle = recoil_muzzle
	super._ready()


func set_picture_height(height: int) -> void:
	var native_720 := height == 720 and atlas_720 != null
	_sprite.texture = atlas_720 if native_720 else _atlas_765
	_draw_scale = 540.0 / 720.0 if native_720 else 1.0 / DRAW_DENSITY
	_active_muzzle = recoil_muzzle_720 if native_720 else recoil_muzzle
	_sprite.scale = Vector2.ONE * _draw_scale
	# Sprite offsets mirror with the sprite horizontally. X stays on the boot anchor.
	_sprite.offset = Vector2(0.0, CELL_HALF_HEIGHT - ANCHOR_Y)


func _process(_delta: float) -> void:
	_sprite.global_position = _snapped_boot()


func _snapped_boot() -> Vector2:
	var canvas := get_canvas_transform()
	return canvas.affine_inverse() * (canvas * global_position).round()


func get_shot_origin(dir_x: int) -> Vector2:
	return _snapped_boot() + Vector2(_active_muzzle.x * dir_x, _active_muzzle.y) * _draw_scale


func _update_visuals(move: Vector2) -> void:
	var moving := move.length_squared() > 0.01 and get_position_delta().length_squared() > 0.01
	if not moving:
		_anim_time = 0.0
	var phase := int(floor(_anim_time))
	if mode == Mode.COMBAT:
		var frame := 0
		if _recoil_timer > 0.0:
			frame = 3
		elif moving:
			frame = 1 + phase % 2
		_sprite.frame_coords = Vector2i(frame, 3)
		_sprite.flip_h = combat_facing < 0
		return

	var row := 2
	var mirror := facing_dir_8way.x < 0.0
	if facing_dir_8way.y < -0.35:
		row = 1
		mirror = facing_dir_8way.x > 0.15
	elif facing_dir_8way.y > 0.35:
		row = 0
	_sprite.frame_coords = Vector2i(1 + phase % 4 if moving else 0, row)
	_sprite.flip_h = mirror


func _apply_shadow_zone_tint() -> void:
	var in_shade := false
	if painted_shade_on:
		for zone in shadow_polygons:
			if Geometry2D.is_point_in_polygon(zone.to_local(global_position), zone.polygon):
				in_shade = true
				break
	var tint := Color(0.81, 0.81, 0.90) if in_shade else Color.WHITE
	_sprite.modulate = _sprite.modulate.lerp(tint, 0.24)
	_shadow.modulate.a = 0.50 if in_shade else 0.76
