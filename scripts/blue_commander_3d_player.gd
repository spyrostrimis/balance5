extends CharacterBody3D

signal reached_canyon_exit(is_at_exit: bool)

@export var move_speed: float = 4.8
@export var gravity: float = 18.0

@onready var sprite: Sprite3D = $CommanderSprite
@onready var gauntlet_light: OmniLight3D = $GauntletGlow
var dust_particles: Node3D = null

var walk_time: float = 0.0
var idle_time: float = 0.0
var facing_right: bool = true
var at_exit_triggered: bool = false
var input_override: Vector2 = Vector2.ZERO

func _ready():
	print("Blue Commander 3D initialized at: ", global_position)

func _physics_process(delta: float):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# ─── 1. Movement Input (WASD + Arrow Keys) ───
	# In Godot 3D: -Z is forward (down the canyon path), +Z is backward, +X is right, -X is left
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

	move_and_slide()

	# ─── 2. Facing & Sprite Orientation ───
	if velocity.x > 0.2:
		facing_right = true
	elif velocity.x < -0.2:
		facing_right = false

	if sprite:
		sprite.flip_h = not facing_right

	# ─── 3. Procedural Walk Animation (Step Bobbing & Dust) ───
	var horiz_speed = Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.3:
		walk_time += delta * 12.0
		# Step bobbing on Y axis
		var step_bob = -abs(sin(walk_time)) * 0.06
		if sprite:
			sprite.position.y = 0.95 + step_bob
			# Subtle stride tilt
			var tilt_dir = 1.0 if facing_right else -1.0
			sprite.rotation.z = sin(walk_time * 0.5) * 0.035 * tilt_dir

		if dust_particles and not dust_particles.emitting:
			dust_particles.emitting = true
	else:
		# Idle breathing
		idle_time += delta * 2.5
		if sprite:
			sprite.position.y = lerp(sprite.position.y, 0.95, delta * 10.0)
			sprite.rotation.z = lerp(sprite.rotation.z, 0.0, delta * 10.0)
			var breath = 1.0 + sin(idle_time) * 0.012
			sprite.scale.y = breath

		if dust_particles and dust_particles.emitting:
			dust_particles.emitting = false

	# ─── 4. Gauntlet Cyan Light Position & Pulse ───
	if gauntlet_light:
		var lx = 0.28 if facing_right else -0.28
		gauntlet_light.position = Vector3(lx, 0.9, 0.05)
		gauntlet_light.light_energy = 1.2 + sin(idle_time * 4.0) * 0.2

	# ─── 5. Canyon Exit Threshold (Z <= -14.0) ───
	var at_exit = (global_position.z <= -14.0)
	if at_exit != at_exit_triggered:
		at_exit_triggered = at_exit
		reached_canyon_exit.emit(at_exit)
		if at_exit:
			print("Commander has reached the Canyon Exit opening! (Z = ", global_position.z, ")")
