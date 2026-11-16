extends Camera3D

@export var target_path: NodePath = NodePath("../BlueCommander")
@export var follow_offset: Vector3 = Vector3(0.0, 2.1, 4.2)
@export var look_ahead_dist: float = 3.8
@export var follow_smooth_speed: float = 6.0

var target: Node3D

func _ready():
	fov = 42.0
	if has_node(target_path):
		target = get_node(target_path) as Node3D
		if target:
			global_position = target.global_position + follow_offset
			var look_at_pt = target.global_position + Vector3(0.0, 1.15, -look_ahead_dist)
			look_at(look_at_pt, Vector3.UP)

func _process(delta: float):
	if target:
		var desired_pos = target.global_position + follow_offset
		global_position = global_position.lerp(desired_pos, clamp(follow_smooth_speed * delta, 0.0, 1.0))
		var look_at_pt = target.global_position + Vector3(0.0, 1.15, -look_ahead_dist)
		look_at(look_at_pt, Vector3.UP)
