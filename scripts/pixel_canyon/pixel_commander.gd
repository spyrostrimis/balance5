extends CharacterBody2D
## The body origin is the ground point shared by every sprite frame.

const PIVOT := Vector2(64, 135)
const FRAME_SIZE := Vector2(128, 144)
const BOOT_TRAVEL_PER_CEL := 3.0
const WALK_CELS := 30
const WALK_SPEED := 75.0
const REFERENCE_HEIGHT := 125.0
## (Boot Y, standing art height above the boots), ordered from far to near.
const DEPTH_MARKS := [Vector2(165, 65), Vector2(217, 89), Vector2(325, 125), Vector2(425, 146)]

var facing := 1
var perspective := 1.0
var calibrated_depth := false
var _stride := 0.0
var _firing := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	place(position)


func place(ground_point: Vector2) -> void:
	position = ground_point
	velocity = Vector2.ZERO
	_stride = 0.0
	_firing = 0.0
	_pose(0)


func walk(direction: Vector2, delta: float) -> void:
	if _firing > 0.0:
		_firing = maxf(_firing - delta, 0.0)
		_pose(32 if _firing > 0.09 else (31 if _firing > 0.0 else 0))
		return
	if direction.x != 0.0:
		facing = 1 if direction.x > 0.0 else -1
	# The painted road is foreshortened in depth.
	velocity = direction * Vector2(1.0, 0.59) * WALK_SPEED * perspective
	move_and_slide()
	var travel := (get_position_delta() / Vector2(1.0, 0.59)).length()
	if travel > 0.01:
		_stride = fposmod(_stride + travel / perspective, BOOT_TRAVEL_PER_CEL * WALK_CELS)
		_pose(1 + floori(_stride / BOOT_TRAVEL_PER_CEL))
	else:
		_stride = 0.0
		_pose(0)


func fire() -> Vector2:
	_firing = 0.18
	_pose(32)
	return position + Vector2(46.0 * facing, -81.0) * perspective


static func size_at(ground_y: float) -> float:
	if ground_y < 177.0:
		return 0.76
	if ground_y < 222.0:
		return 0.84
	if ground_y < 274.0:
		return 0.92
	if ground_y > 399.0:
		return 1.06
	return 1.0


static func calibrated_size_at(ground_y: float) -> float:
	for index in range(1, DEPTH_MARKS.size()):
		var near: Vector2 = DEPTH_MARKS[index]
		if ground_y <= near.x:
			var far: Vector2 = DEPTH_MARKS[index - 1]
			var weight := clampf(inverse_lerp(far.x, near.x, ground_y), 0.0, 1.0)
			return lerpf(far.y, near.y, weight) / REFERENCE_HEIGHT
	return DEPTH_MARKS[-1].y / REFERENCE_HEIGHT


func set_calibrated_depth(enabled: bool) -> void:
	calibrated_depth = enabled
	_pose(sprite.frame)


func _pose(index: int) -> void:
	perspective = calibrated_size_at(position.y) if calibrated_depth else size_at(position.y)
	sprite.frame = index
	sprite.flip_h = facing < 0
	sprite.scale = Vector2.ONE * perspective
	# Keep the pivot fixed when facing left, and snap the painted origin to a pixel.
	var left := PIVOT.x if facing > 0 else FRAME_SIZE.x - PIVOT.x
	var origin := position.round() - (Vector2(left, PIVOT.y) * perspective).round()
	sprite.position = origin - position
