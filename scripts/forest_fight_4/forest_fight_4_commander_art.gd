extends Node2D

const RIFLE := preload("res://assets/textures/forest_fight_4/rifle.png")
const POSES := [0, 3, 4, 3, 0, 1, 2, 1]
const MIRROR := [false, false, false, true, true, true, false, false]

var direction := Vector2.RIGHT
var pivot := Vector2.ZERO
var muzzle := Vector2.ZERO
var distance_walked := 0.0
var moving := false
var light := Color.WHITE

@onready var pose: Sprite2D = $Pose


func update_look() -> void:
	var facing := posmod(roundi(direction.angle() / (PI / 4.0)), 8)
	var frame := 1 + posmod(floori(distance_walked / 17.0), 6) if moving else 0
	pose.frame_coords = Vector2i(frame, POSES[facing])
	pose.flip_h = MIRROR[facing]
	pose.modulate = light
	# The rifle projects behind the head when pointing away. The barrel
	# location follows the same continuous angle on either side of a pose change.
	pose.show_behind_parent = direction.y >= -0.64
	queue_redraw()


func _draw() -> void:
	var foreshorten := pivot.distance_to(muzzle)
	draw_set_transform(pivot, direction.angle(), Vector2((foreshorten + 8.0) / 152.0, 0.31 if direction.x >= 0.0 else -0.31))
	draw_texture(RIFLE, Vector2(-8.0 * 152.0 / (foreshorten + 8.0), -18), light)
