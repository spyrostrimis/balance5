extends Camera3D

@export var target_path: NodePath
@export var follow_offset: Vector3 = Vector3(0.0, 2.5, 4.8)
@export var look_ahead_dist: float = 3.5
@export var follow_smooth_speed: float = 6.0

var target: Node3D

func _ready():
	if has_node(target_path):
		target = get_node(target_path) as Node3D

func _process(delta: float):
	if target:
		# Desired camera position in 3D world space
		var desired_pos = target.global_position + follow_offset
		# Smooth camera dolly
		global_position = global_position.lerp(desired_pos, follow_smooth_speed * delta)
		
		# Look slightly ahead of the character down the canyon path
		var look_at_pt = target.global_position + Vector3(0, 1.2, -look_ahead_dist)
		look_at(look_at_pt, Vector3.UP)
