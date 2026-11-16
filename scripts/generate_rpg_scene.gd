@tool
extends SceneTree

func _init():
	print("Creating Desert Approach RPG HD-2D Scene...")
	var root = Node2D.new()
	root.name = "DesertApproachRPG"

	# ─── Load Assets ───
	var albedo = load("res://assets/textures/maps/desert_approach_rpg_albedo.png")
	var normal = load("res://assets/textures/maps/desert_approach_rpg_normal.png")
	var radial_light = load("res://assets/textures/effects/light_radial.png")
	var shader_god_rays = load("res://assets/shaders/god_rays.gdshader")
	var shader_tilt_shift = load("res://assets/shaders/tilt_shift_hd2d.gdshader")

	# ─── 1. Background Terrain with CanvasTexture (Normal Mapped) ───
	var canvas_tex = CanvasTexture.new()
	canvas_tex.diffuse_texture = albedo
	canvas_tex.normal_texture = normal
	canvas_tex.specular_shininess = 0.25

	var terrain = Sprite2D.new()
	terrain.name = "TerrainBackground"
	terrain.texture = canvas_tex
	terrain.centered = false
	terrain.position = Vector2(0, 0)
	root.add_child(terrain)
	terrain.owner = root

	# ─── 2. Dynamic 2D Lighting ───
	# Directional sunlight interacting with normal map
	var dir_light = DirectionalLight2D.new()
	dir_light.name = "SunLight2D"
	dir_light.color = Color(1.0, 0.95, 0.85, 1.0)
	dir_light.energy = 0.35
	dir_light.height = 0.6
	dir_light.rotation_degrees = -35.0
	root.add_child(dir_light)
	dir_light.owner = root

	# Distant canyon opening glow
	var exit_light = PointLight2D.new()
	exit_light.name = "ExitHorizonGlow"
	exit_light.texture = radial_light
	exit_light.texture_scale = 3.5
	exit_light.color = Color(1.0, 0.82, 0.48, 1.0)
	exit_light.energy = 0.9
	exit_light.position = Vector2(688, 180) # Center-top canyon opening
	root.add_child(exit_light)
	exit_light.owner = root

	# ─── 3. Dynamic Sunbeams / God Rays Layer ───
	var rays_rect = ColorRect.new()
	rays_rect.name = "GodRaysOverlay"
	rays_rect.position = Vector2(0, 0)
	rays_rect.size = Vector2(1376, 768)
	var mat_rays = ShaderMaterial.new()
	mat_rays.shader = shader_god_rays
	mat_rays.set_shader_parameter("angle", -0.42)
	mat_rays.set_shader_parameter("ray_density", 14.0)
	mat_rays.set_shader_parameter("ray_speed", 0.12)
	mat_rays.set_shader_parameter("ray_intensity", 0.22)
	mat_rays.set_shader_parameter("ray_color", Color(1.0, 0.92, 0.72, 1.0))
	rays_rect.material = mat_rays
	root.add_child(rays_rect)
	rays_rect.owner = root

	# ─── 4. Desert Dust Particles (Floating Motes) ───
	var dust = CPUParticles2D.new()
	dust.name = "DustMotes"
	dust.position = Vector2(688, 384)
	dust.amount = 45
	dust.lifetime = 6.0
	dust.preprocess = 3.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(650, 350)
	dust.direction = Vector2(-0.8, 0.3) # Drifting with the sunbeams
	dust.spread = 25.0
	dust.gravity = Vector2(-2.0, 1.0)
	dust.initial_velocity_min = 8.0
	dust.initial_velocity_max = 20.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	dust.color = Color(1.0, 0.94, 0.78, 0.55)
	root.add_child(dust)
	dust.owner = root

	# ─── 5. Tilt-Shift Depth of Field & Vignette Post-Processing ───
	var post_layer = CanvasLayer.new()
	post_layer.name = "PostProcessing"
	root.add_child(post_layer)
	post_layer.owner = root

	var tilt_rect = ColorRect.new()
	tilt_rect.name = "TiltShiftDof"
	tilt_rect.size = Vector2(1376, 768)
	var mat_tilt = ShaderMaterial.new()
	mat_tilt.shader = shader_tilt_shift
	mat_tilt.set_shader_parameter("focal_position_y", 0.58) # Sharp on the cobblestone path
	mat_tilt.set_shader_parameter("focal_width", 0.22)      # Generous sharp band
	mat_tilt.set_shader_parameter("blur_amount", 2.8)       # Soft cinematic bokeh
	mat_tilt.set_shader_parameter("vignette_strength", 0.22) # Subtle vignette
	mat_tilt.set_shader_parameter("warm_tint", Color(1.02, 1.0, 0.97, 1.0))
	tilt_rect.material = mat_tilt
	post_layer.add_child(tilt_rect)
	tilt_rect.owner = root

	# ─── Save Scene ───
	var scene = PackedScene.new()
	var err = scene.pack(root)
	if err == OK:
		var path = "res://scenes/maps/desert_approach_rpg_hd2d.tscn"
		ResourceSaver.save(scene, path)
		print("SUCCESS: HD-2D scene saved to: ", path)
	else:
		printerr("ERROR packing scene: ", err)

	quit(0)
