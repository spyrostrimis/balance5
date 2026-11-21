extends Node2D

const WALK_SPEED := 134.0
const CAMERA_LEEWAY := Vector2(12, 9)
const CAMERA_LOOK := Vector2(22, -89)
const WALK_FRAMES := [1, 0, 3, 2]

@onready var commander: CharacterBody2D = $Commander
@onready var sprite: Sprite2D = $Commander/Art/Sprite
@onready var camera: Camera2D = $Camera

var _camera_center: Vector2
var _facing := Vector2.UP
var _walk_distance := 0.0


func _ready() -> void:
	_camera_center = commander.position + CAMERA_LOOK
	_update_view(false)


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	)
	if wasd != Vector2.ZERO:
		direction = wasd.normalized()

	commander.velocity = direction * WALK_SPEED
	commander.move_and_slide()
	if direction != Vector2.ZERO:
		_facing = direction
	var distance := commander.get_position_delta().length()
	_walk_distance = _walk_distance + distance if distance > 0.01 else 0.0
	_update_view(distance > 0.01)


func _update_view(walking: bool) -> void:
	# Option C's north, south and side rows keep the boots on one pivot.
	var row := 2
	var mirrored := _facing.x < 0.0
	if _facing.y < -0.35:
		row = 1
		mirrored = _facing.x > 0.15
	elif _facing.y > 0.35:
		row = 0
	sprite.frame_coords = Vector2i(WALK_FRAMES[int(_walk_distance / 15.0) % 4] if walking else 0, row)
	sprite.flip_h = mirrored
	$Commander/Art.global_position = commander.position.round()

	var target := commander.position + CAMERA_LOOK
	var half_view := get_viewport_rect().size / 2.0
	var map_size := Vector2($Ground.texture.get_size())
	_camera_center = _camera_center.clamp(target - CAMERA_LEEWAY, target + CAMERA_LEEWAY)
	_camera_center = _camera_center.clamp(half_view, map_size - half_view)
	camera.position = _camera_center.round()
