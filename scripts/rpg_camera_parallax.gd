extends Camera2D

@export var target_path: NodePath
@export var foreground_path: NodePath
@export var horizon_glow_path: NodePath
@export var post_processing_path: NodePath

var target: Node2D
var foreground: Node2D
var horizon_glow: Node2D
var tilt_material: ShaderMaterial

# Parallax intensity factors
const FG_PARALLAX: float = 0.12 # Foreground shifts faster
const BG_PARALLAX: float = -0.06 # Distant horizon shifts slower

var map_center: Vector2 = Vector2(1376.0 / 2.0, 768.0 / 2.0)

func _ready():
	if has_node(target_path):
		target = get_node(target_path) as Node2D
	if has_node(foreground_path):
		foreground = get_node(foreground_path) as Node2D
	if has_node(horizon_glow_path):
		horizon_glow = get_node(horizon_glow_path) as Node2D
	if has_node(post_processing_path):
		var post_rect = get_node(post_processing_path) as ColorRect
		if post_rect and post_rect.material is ShaderMaterial:
			tilt_material = post_rect.material as ShaderMaterial

func _process(delta: float):
	if target:
		# Smooth camera tracking
		global_position = global_position.lerp(target.global_position, 4.5 * delta)
		
		# Clamp camera position so viewport stays inside the 1376x768 canyon bounds
		var vp_rect = get_viewport_rect()
		var vp_half = (vp_rect.size / zoom) * 0.5
		global_position.x = clamp(global_position.x, vp_half.x, 1376.0 - vp_half.x)
		global_position.y = clamp(global_position.y, vp_half.y, 768.0 - vp_half.y)
		
		# Parallax displacement relative to map center
		var cam_offset = global_position - map_center
		
		if foreground:
			foreground.position = cam_offset * FG_PARALLAX
			
		if horizon_glow:
			horizon_glow.position = Vector2(688, 180) + (cam_offset * BG_PARALLAX)
			
		# Dynamic Focus Pulling: keeps the Commander razor-sharp wherever she walks!
		if tilt_material:
			# Calculate target's position in normalized screen coordinates (0.0 to 1.0)
			var screen_top = global_position.y - vp_half.y
			var screen_h = vp_half.y * 2.0
			var char_screen_y = (target.global_position.y - 30.0 - screen_top) / screen_h
			tilt_material.set_shader_parameter("focal_position_y", clamp(char_screen_y, 0.25, 0.85))

