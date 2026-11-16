extends CharacterBody2D

signal reached_canyon_opening(is_at_opening: bool)

@export var move_speed: float = 175.0

@onready var sprite: Sprite2D = $CommanderSprite
@onready var shadow: Sprite2D = $ContactShadow
@onready var gauntlet_light: PointLight2D = $GauntletGlow
@onready var dust_particles: CPUParticles2D = $FootstepDust

var walk_time: float = 0.0
var idle_time: float = 0.0
var facing_right: bool = true
var at_opening_triggered: bool = false
var input_override: Vector2 = Vector2.ZERO

# Perspective depth scaling parameters
# Path Y ranges from ~178 (canyon mouth threshold) to ~700 (foreground)
const FAR_Y: float = 178.0
const NEAR_Y: float = 700.0
# Heroic scale range: remains prominent and readable even at the canyon opening!
const SCALE_FAR: float = 0.122
const SCALE_NEAR: float = 0.142

func _ready():
	print("Blue Commander initialized at: ", global_position)

func _physics_process(delta: float):
	# ─── 1. 8-Directional Input (WASD + Arrow Keys or input_override) ───
	var input_vec = input_override
	
	if input_vec == Vector2.ZERO:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input_vec.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input_vec.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_vec.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_vec.x += 1.0
		
	if input_vec.length_squared() > 0.0:
		input_vec = input_vec.normalized()
		velocity = input_vec * move_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 9.0 * delta)
		
	move_and_slide()
	
	# Clamp inside walkable map limits (extends all the way to canyon mouth ledge at Y=178!)
	global_position.x = clamp(global_position.x, 100.0, 1276.0)
	global_position.y = clamp(global_position.y, 178.0, 720.0)

	# ─── 2. Perspective Depth Scaling (2.5D Distance) ───
	var depth_t = clamp((global_position.y - FAR_Y) / (NEAR_Y - FAR_Y), 0.0, 1.0)
	var current_scale = lerp(SCALE_FAR, SCALE_NEAR, depth_t)

	# ─── 3. Horizontal Facing & Orientation ───
	if velocity.x > 5.0:
		facing_right = true
	elif velocity.x < -5.0:
		facing_right = false
		
	var sign_x = 1.0 if facing_right else -1.0

	# ─── 4. Procedural Step Animation & Secondary Motion ───
	if velocity.length() > 10.0:
		walk_time += delta * 13.5
		# Vertical step bobbing (bounce on each footstep)
		var step_bob = -abs(sin(walk_time)) * (5.0 * depth_t + 1.5)
		sprite.position.y = step_bob
		# Subtle stride tilt
		sprite.rotation = sin(walk_time * 0.5) * 0.04 * sign_x
		sprite.scale = Vector2(current_scale * sign_x, current_scale)
		
		# Emit footstep dust
		if dust_particles and not dust_particles.emitting:
			dust_particles.emitting = true
	else:
		# Idle breathing
		idle_time += delta * 2.5
		sprite.position.y = lerp(sprite.position.y, 0.0, delta * 12.0)
		sprite.rotation = lerp(sprite.rotation, 0.0, delta * 10.0)
		var breath = 1.0 + sin(idle_time) * 0.015
		sprite.scale = Vector2(current_scale * sign_x, current_scale * breath)
		
		if dust_particles and dust_particles.emitting:
			dust_particles.emitting = false

	# ─── 5. Ground Contact Shadow Scaling ───
	if shadow:
		shadow.scale = Vector2(0.9, 0.45) * lerp(0.85, 1.15, depth_t)
		var shadow_offset_x = -8.0 if facing_right else 8.0
		shadow.position = Vector2(shadow_offset_x, 5.0)

	# ─── 6. Gauntlet Light Position ───
	if gauntlet_light:
		var light_x = 28.0 if facing_right else -28.0
		gauntlet_light.position = Vector2(light_x, -75.0 * (current_scale / 0.13))
		gauntlet_light.energy = 1.0 + sin(idle_time * 4.0) * 0.15

	# ─── 7. Canyon Opening Threshold Detection ───
	var at_opening = (global_position.y <= 190.0)
	if at_opening != at_opening_triggered:
		at_opening_triggered = at_opening
		reached_canyon_opening.emit(at_opening)
		if at_opening:
			print("Commander has arrived at the canyon opening threshold! (Y=", global_position.y, ")")
