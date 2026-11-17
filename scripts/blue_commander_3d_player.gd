extends CharacterBody3D

signal reached_canyon_exit(is_at_exit: bool)

enum Mode { EXPLORATION, COMBAT_LOCKED }

@export var current_mode: Mode = Mode.EXPLORATION
@export var move_speed: float = 4.5
@export var gravity: float = 18.0
@export var ground_mesh_path: NodePath = NodePath("../GroundFloorMesh")

@onready var sprite: Sprite3D = $CommanderSprite
@onready var gauntlet_light: OmniLight3D = $GauntletGlow

var idle_time: float = 0.0
var walk_cycle: float = 0.0
var was_at_exit: bool = false
var _ground_mat: ShaderMaterial = null


static func get_path_center_x(z: float) -> float:
	return sin(z * 0.22) * 0.65


func _ready() -> void:
	var ground_mesh := get_node_or_null(ground_mesh_path) as MeshInstance3D
	if ground_mesh:
		var mat := ground_mesh.get_surface_override_material(0)
		if mat == null and ground_mesh.mesh:
			mat = ground_mesh.mesh.surface_get_material(0)
		if mat is ShaderMaterial:
			_ground_mat = mat
			_ground_mat.set_shader_parameter("player_pos", global_position)


func _read_move_input() -> Vector2:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir.length_squared() < 0.001:
		var ix: float = 0.0
		var iz: float = 0.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			ix -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			ix += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			iz -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			iz += 1.0
		dir = Vector2(ix, iz)
		if dir.length() > 1.0:
			dir = dir.normalized()
	return dir


func _physics_process(delta: float) -> void:
	# 1. Gravity keeps feet solidly grounded on Y = 0.0 floor
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# 2. Movement strictly by Mode (Step 1 uses Mode.EXPLORATION only)
	var input_dir := Vector2.ZERO
	if current_mode == Mode.EXPLORATION:
		input_dir = _read_move_input()

	velocity.x = input_dir.x * move_speed
	velocity.z = input_dir.y * move_speed

	move_and_slide()

	# 3. Clamp smoothly inside winding cobblestone canyon trail
	global_position.z = clampf(global_position.z, -14.5, 7.5)
	var cx: float = get_path_center_x(global_position.z)
	global_position.x = clampf(global_position.x, cx - 1.15, cx + 1.15)

	# 4. Update dynamic grounded contact shadow under boots
	if _ground_mat:
		_ground_mat.set_shader_parameter("player_pos", global_position)

	# 5. Subtle sprite walk cadence, facing flip, idle breathing & gauntlet glow
	if absf(velocity.x) > 0.08:
		sprite.flip_h = (velocity.x < 0.0)

	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.25:
		walk_cycle += delta * 11.5
		sprite.position.y = 0.64 + absf(sin(walk_cycle)) * 0.032
		sprite.rotation_degrees.z = sin(walk_cycle) * 2.2
	else:
		idle_time += delta
		sprite.position.y = 0.64 + sin(idle_time * 2.4) * 0.006
		sprite.rotation_degrees.z = lerpf(sprite.rotation_degrees.z, 0.0, delta * 10.0)

	if gauntlet_light:
		gauntlet_light.light_energy = 0.35 + sin(Time.get_ticks_msec() * 0.004) * 0.08

	# 6. Canyon Exit Threshold (Z <= -13.5)
	var at_exit: bool = (global_position.z <= -13.5)
	if at_exit != was_at_exit:
		was_at_exit = at_exit
		reached_canyon_exit.emit(at_exit)
