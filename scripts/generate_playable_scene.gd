@tool
extends SceneTree

func _init():
	print("Generating Playable Desert Canyon Scene...")
	var root = Node2D.new()
	root.name = "DesertCanyonPlayable"

	# ─── Load Assets ───
	var albedo_map = load("res://assets/textures/maps/desert_approach_rpg_albedo.png")
	var normal_map = load("res://assets/textures/maps/desert_approach_rpg_normal.png")
	var fg_map = load("res://assets/textures/maps/desert_approach_rpg_foreground.png")
	var radial_light = load("res://assets/textures/effects/light_radial.png")
	var shader_god_rays = load("res://assets/shaders/god_rays.gdshader")
	var shader_tilt_shift = load("res://assets/shaders/tilt_shift_hd2d.gdshader")

	var char_albedo = load("res://assets/textures/units/blue_commander_rpg.png")
	var char_normal = load("res://assets/textures/units/blue_commander_rpg_normal.png")
	var char_shadow = load("res://assets/textures/units/blue_commander_shadow.png")

	var script_player = load("res://scripts/blue_commander_player.gd")
	var script_camera = load("res://scripts/rpg_camera_parallax.gd")

	# ─── 1. Background Terrain ───
	var canvas_tex = CanvasTexture.new()
	canvas_tex.diffuse_texture = albedo_map
	canvas_tex.normal_texture = normal_map
	canvas_tex.specular_shininess = 0.25

	var terrain = Sprite2D.new()
	terrain.name = "TerrainBackground"
	terrain.texture = canvas_tex
	terrain.centered = false
	terrain.position = Vector2(0, 0)
	root.add_child(terrain)
	terrain.owner = root

	# ─── 2. Canyon Cliff Collision Boundaries ───
	# Stops Commander from walking up sheer vertical cliffs, guiding her down the stone trail
	var walls_body = StaticBody2D.new()
	walls_body.name = "CanyonWallsCollision"
	root.add_child(walls_body)
	walls_body.owner = root

	# Left Wall Collision Polygon
	var col_left = CollisionPolygon2D.new()
	col_left.name = "LeftWall"
	var pts_l = PackedVector2Array([
		Vector2(0, 0),
		Vector2(620, 0),
		Vector2(600, 260),
		Vector2(530, 420),
		Vector2(480, 560),
		Vector2(380, 768),
		Vector2(0, 768)
	])
	col_left.polygon = pts_l
	walls_body.add_child(col_left)
	col_left.owner = root

	# Right Wall Collision Polygon
	var col_right = CollisionPolygon2D.new()
	col_right.name = "RightWall"
	var pts_r = PackedVector2Array([
		Vector2(730, 0),
		Vector2(1376, 0),
		Vector2(1376, 768),
		Vector2(950, 768),
		Vector2(850, 600),
		Vector2(780, 420),
		Vector2(720, 260)
	])
	col_right.polygon = pts_r
	walls_body.add_child(col_right)
	col_right.owner = root

	# ─── 3. Playable Blue Commander (CharacterBody2D) ───
	var player = CharacterBody2D.new()
	player.name = "BlueCommander"
	player.set_script(script_player)
	player.position = Vector2(650, 480)
	player.z_index = 2
	root.add_child(player)
	player.owner = root

	# Collision Shape at feet
	var player_col = CollisionShape2D.new()
	player_col.name = "FeetCollision"
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 14.0
	player_col.shape = circle_shape
	player.add_child(player_col)
	player_col.owner = root

	# Contact Shadow
	var shadow_sp = Sprite2D.new()
	shadow_sp.name = "ContactShadow"
	shadow_sp.texture = char_shadow
	shadow_sp.position = Vector2(-8, 5)
	shadow_sp.scale = Vector2(0.9, 0.45)
	shadow_sp.modulate = Color(0.15, 0.1, 0.08, 0.75)
	player.add_child(shadow_sp)
	shadow_sp.owner = root

	# Footstep Dust Particles
	var foot_dust = CPUParticles2D.new()
	foot_dust.name = "FootstepDust"
	foot_dust.position = Vector2(0, 8)
	foot_dust.emitting = false
	foot_dust.amount = 8
	foot_dust.lifetime = 0.4
	foot_dust.direction = Vector2(0, -1)
	foot_dust.spread = 45.0
	foot_dust.gravity = Vector2(0, 20)
	foot_dust.initial_velocity_min = 10.0
	foot_dust.initial_velocity_max = 25.0
	foot_dust.scale_amount_min = 1.0
	foot_dust.scale_amount_max = 2.5
	foot_dust.color = Color(0.85, 0.72, 0.52, 0.6)
	player.add_child(foot_dust)
	foot_dust.owner = root

	# Commander Sprite with Normal Map
	var char_canvas_tex = CanvasTexture.new()
	char_canvas_tex.diffuse_texture = char_albedo
	char_canvas_tex.normal_texture = char_normal
	char_canvas_tex.specular_shininess = 0.35

	var comp_sprite = Sprite2D.new()
	comp_sprite.name = "CommanderSprite"
	comp_sprite.texture = char_canvas_tex
	comp_sprite.scale = Vector2(0.13, 0.13)
	comp_sprite.offset = Vector2(0, -540)
	player.add_child(comp_sprite)
	comp_sprite.owner = root

	# Glowing Cyan Medical Gauntlet
	var gauntlet = PointLight2D.new()
	gauntlet.name = "GauntletGlow"
	gauntlet.texture = radial_light
	gauntlet.texture_scale = 0.65
	gauntlet.color = Color(0.15, 0.95, 0.85, 1.0)
	gauntlet.energy = 1.1
	gauntlet.position = Vector2(28, -75)
	player.add_child(gauntlet)
	gauntlet.owner = root

	# ─── 4. Foreground Cliffs Layer (Parallax Depth) ───
	var fg_sprite = Sprite2D.new()
	fg_sprite.name = "ForegroundCliffs"
	fg_sprite.texture = fg_map
	fg_sprite.centered = false
	fg_sprite.position = Vector2(0, 0)
	fg_sprite.z_index = 4 # Above player so player walks behind foreground rocks
	root.add_child(fg_sprite)
	fg_sprite.owner = root

	# ─── 5. Dynamic Lighting ───
	var dir_light = DirectionalLight2D.new()
	dir_light.name = "SunLight2D"
	dir_light.color = Color(1.0, 0.95, 0.85, 1.0)
	dir_light.energy = 0.35
	dir_light.height = 0.6
	dir_light.rotation_degrees = -35.0
	root.add_child(dir_light)
	dir_light.owner = root

	var exit_light = PointLight2D.new()
	exit_light.name = "ExitHorizonGlow"
	exit_light.texture = radial_light
	exit_light.texture_scale = 3.5
	exit_light.color = Color(1.0, 0.82, 0.48, 1.0)
	exit_light.energy = 0.9
	exit_light.position = Vector2(688, 180)
	root.add_child(exit_light)
	exit_light.owner = root

	# ─── 6. Atmospheric Sunbeams / God Rays & Dust ───
	var rays_rect = ColorRect.new()
	rays_rect.name = "GodRaysOverlay"
	rays_rect.position = Vector2(0, 0)
	rays_rect.size = Vector2(1376, 768)
	rays_rect.z_index = 6
	var mat_rays = ShaderMaterial.new()
	mat_rays.shader = shader_god_rays
	mat_rays.set_shader_parameter("angle", -0.42)
	mat_rays.set_shader_parameter("ray_density", 14.0)
	mat_rays.set_shader_parameter("ray_speed", 0.12)
	mat_rays.set_shader_parameter("ray_intensity", 0.20)
	mat_rays.set_shader_parameter("ray_color", Color(1.0, 0.92, 0.72, 1.0))
	rays_rect.material = mat_rays
	root.add_child(rays_rect)
	rays_rect.owner = root

	var dust = CPUParticles2D.new()
	dust.name = "DustMotes"
	dust.position = Vector2(688, 384)
	dust.amount = 45
	dust.lifetime = 6.0
	dust.preprocess = 3.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(650, 350)
	dust.direction = Vector2(-0.8, 0.3)
	dust.spread = 25.0
	dust.gravity = Vector2(-2.0, 1.0)
	dust.initial_velocity_min = 8.0
	dust.initial_velocity_max = 20.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	dust.color = Color(1.0, 0.94, 0.78, 0.55)
	dust.z_index = 7
	root.add_child(dust)
	dust.owner = root

	# ─── 7. Smooth Tracking Camera with 2.5D Parallax ───
	var cam = Camera2D.new()
	cam.name = "Camera2D"
	cam.set_script(script_camera)
	cam.position = Vector2(650, 480)
	cam.zoom = Vector2(1.18, 1.18) # Subtle zoom for cinematic panning
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	cam.set("target_path", NodePath("../BlueCommander"))
	cam.set("foreground_path", NodePath("../ForegroundCliffs"))
	cam.set("horizon_glow_path", NodePath("../ExitHorizonGlow"))
	cam.set("post_processing_path", NodePath("../PostProcessing/TiltShiftDof"))
	root.add_child(cam)
	cam.owner = root

	# ─── 8. Tilt-Shift Post Processing ───
	var post_layer = CanvasLayer.new()
	post_layer.name = "PostProcessing"
	root.add_child(post_layer)
	post_layer.owner = root

	var tilt_rect = ColorRect.new()
	tilt_rect.name = "TiltShiftDof"
	tilt_rect.size = Vector2(1376, 768)
	var mat_tilt = ShaderMaterial.new()
	mat_tilt.shader = shader_tilt_shift
	mat_tilt.set_shader_parameter("focal_position_y", 0.58)
	mat_tilt.set_shader_parameter("focal_width", 0.22)
	mat_tilt.set_shader_parameter("blur_amount", 3.2)
	mat_tilt.set_shader_parameter("vignette_strength", 0.20)
	mat_tilt.set_shader_parameter("warm_tint", Color(1.02, 1.0, 0.98, 1.0))
	tilt_rect.material = mat_tilt
	post_layer.add_child(tilt_rect)
	tilt_rect.owner = root

	# ─── Save Scene ───
	var scene = PackedScene.new()
	var err = scene.pack(root)
	if err == OK:
		var path = "res://scenes/maps/desert_canyon_playable.tscn"
		ResourceSaver.save(scene, path)
		print("SUCCESS: Playable scene saved to: ", path)
	else:
		printerr("ERROR packing scene: ", err)

	quit(0)
