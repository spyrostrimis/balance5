extends CharacterBody3D

signal reached_canyon_exit(is_at_exit: bool)

@export var move_speed: float = 3.6
@export var canyon_mesh_path: NodePath = NodePath("../CanyonProjectedMesh")

@onready var sprite: Sprite3D = $CommanderSprite
@onready var gauntlet_light: OmniLight3D = $GauntletGlow

var canyon_material: ShaderMaterial = null
var base_sprite_y: float = 0.59
var walk_time: float = 0.0
var idle_time: float = 0.0
var facing_right: bool = true
var at_exit_triggered: bool = false
var input_override: Vector2 = Vector2.ZERO

static func get_path_center_x(z: float) -> float:
	# Exact 3D floor centerline matching the painted cobblestones in desert_approach_rpg_albedo.png
	if z >= 4.4:
		return lerp(0.15, 0.10, clamp((z - 4.4) / 1.3, 0.0, 1.0))
	elif z >= 2.0:
		return lerp(-0.30, 0.15, (z - 2.0) / 2.4)
	elif z >= 0.0:
		return lerp(-0.55, -0.30, z / 2.0)
	elif z >= -2.65:
		return lerp(-0.05, -0.55, (z - (-2.65)) / 2.65)
	elif z >= -5.9:
		return lerp(-0.20, -0.05, (z - (-5.9)) / 3.25)
	else:
		return lerp(-0.42, -0.20, clamp((z - (-9.5)) / 3.6, 0.0, 1.0))

func _ready():
	global_position.y = 0.0
	if sprite:
		base_sprite_y = sprite.position.y
	if has_node(canyon_mesh_path):
		var mesh_inst = get_node(canyon_mesh_path) as MeshInstance3D
		if mesh_inst and mesh_inst.material_override is ShaderMaterial:
			canyon_material = mesh_inst.material_override as ShaderMaterial
			canyon_material.set_shader_parameter("player_pos", global_position)
	print("Blue Commander 3D initialized at: ", global_position)

func _physics_process(delta: float):
	# ─── 1. Movement Input (WASD + Arrow Keys or input_override) ───
	var input_dir = input_override
	if input_dir == Vector2.ZERO:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input_dir.y -= 1.0 # Forward (-Z)
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input_dir.y += 1.0 # Backward (+Z)
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_dir.x -= 1.0 # Left (-X)
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_dir.x += 1.0 # Right (+X)

	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()
		velocity.x = input_dir.x * move_speed
		velocity.z = input_dir.y * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 10.0 * delta)

	velocity.y = 0.0
	move_and_slide()

	# ─── 2. Strict Grounding & Cobblestone Path Guidance ───
	global_position.z = clamp(global_position.z, -9.5, 5.2)
	var p = clamp((5.2 - global_position.z) / 14.7, 0.0, 1.0)
	var cx = get_path_center_x(global_position.z)
	if abs(input_dir.x) < 0.05 and abs(input_dir.y) > 0.05:
		global_position.x = move_toward(global_position.x, cx, move_speed * 0.35 * delta)
	var half_walk_w = lerp(0.75, 0.30, p)
	global_position.x = clamp(global_position.x, cx - half_walk_w, cx + half_walk_w)
	global_position.y = 0.0

	# Update ground contact shadow & gauntlet light uniform in canyon shader
	if canyon_material:
		canyon_material.set_shader_parameter("player_pos", global_position)

	# ─── 3. Facing & Sprite Orientation ───
	if velocity.x > 0.2:
		facing_right = true
	elif velocity.x < -0.2:
		facing_right = false

	if sprite:
		sprite.flip_h = not facing_right

	# ─── 4. Procedural Walk Animation (Step Bobbing) ───
	var horiz_speed = Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.25:
		walk_time += delta * 12.0
		var step_bob = abs(sin(walk_time)) * 0.035
		if sprite:
			sprite.position.y = base_sprite_y + step_bob
			var tilt_dir = 1.0 if facing_right else -1.0
			sprite.rotation.z = sin(walk_time * 0.5) * 0.03 * tilt_dir
	else:
		idle_time += delta * 2.5
		if sprite:
			sprite.position.y = lerp(sprite.position.y, base_sprite_y, delta * 10.0)
			sprite.rotation.z = lerp(sprite.rotation.z, 0.0, delta * 10.0)
			sprite.scale.y = 1.0 + sin(idle_time) * 0.012

	# ─── 5. Gauntlet Cyan Light Pulse ───
	if gauntlet_light:
		var lx = 0.18 if facing_right else -0.18
		gauntlet_light.position = Vector3(lx, base_sprite_y * 1.02, 0.04)
		gauntlet_light.light_energy = 0.7 + sin(idle_time * 4.0) * 0.15

	# ─── 6. Canyon Exit Threshold (Z <= -9.0) ───
	var at_exit = (global_position.z <= -9.0)
	if at_exit != at_exit_triggered:
		at_exit_triggered = at_exit
		reached_canyon_exit.emit(at_exit)
		if at_exit:
			print("Commander has reached the Canyon Exit opening! (Z = ", global_position.z, ")")
