extends Approach3Commander

const CaveBolt := preload("res://scripts/rpg_2d/forest_fight_bolt.gd")
const FLOOR := Rect2(174, 454, 1030, 232)
const MIDDLE_DEPTH := FLOOR.position.y + FLOOR.size.y * 0.5
const MIDDLE_HEIGHT := 277.0

# The original atlas is a fallback for the blockout. A larger atlas uses the
# same registration at a different pixel density.
@export var profile_atlas: Texture2D
@export var profile_density := 1.0
@export var profile_muzzle := Vector2(70.0, -116.5)


func _ready() -> void:
	if profile_atlas != null:
		_sprite.texture = profile_atlas
		_sprite.offset *= profile_density
	super._ready()
	_update_depth()


func tick(input_vec: Vector2, delta: float) -> void:
	script_input_dir = input_vec
	super._physics_process(delta)


func step_movement(input_vec: Vector2, delta: float) -> void:
	# Trim the requested velocity before move_and_slide so an idle pose is used
	# when the boots have actually stopped at a wall.
	var motion := input_vec.limit_length() * Vector2(combat_speed_x, combat_speed_y) * delta
	var destination := position + motion
	var inside := destination.clamp(FLOOR.position, FLOOR.end)
	if absf(input_vec.x) > 0.1:
		combat_facing = int(signf(input_vec.x))
	super.step_movement((inside - position) / (Vector2(combat_speed_x, combat_speed_y) * delta), delta)
	_update_depth()


func _update_depth() -> void:
	var factor := lerpf(0.97, 1.03, inverse_lerp(FLOOR.position.y, FLOOR.end.y, position.y))
	_sprite.scale = Vector2.ONE * (MIDDLE_HEIGHT / (149.0 * profile_density)) * factor


func get_shot_origin(dir_x: int) -> Vector2:
	# Angle stays horizontal as the figure subtly grows towards the foreground.
	return _snapped_boot() + Vector2(profile_muzzle.x * dir_x, profile_muzzle.y) * _sprite.scale


func _make_bolt() -> RifleBolt2D:
	var bolt := CaveBolt.new()
	bolt.lane = position.y
	return bolt


func _unhandled_input(_event: InputEvent) -> void:
	# The encounter owns firing and mode changes.
	pass


func _apply_shadow_zone_tint() -> void:
	var warm := 1.0 - smoothstep(240.0, 690.0, position.x)
	_sprite.modulate = Color(0.80, 0.86, 0.95).lerp(Color(1.04, 0.98, 0.86), warm)
