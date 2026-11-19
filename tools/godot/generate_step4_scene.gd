@tool
extends SceneTree

func _init():
	if not preload("res://tools/godot/tool_guard.gd").confirm(self, PackedStringArray(["res://scenes/maps/desert_approach_rpg_with_commander.tscn"])):
		return
	print("Creating Desert Approach RPG Scene with Commander (Step 4)...")
	var root = Node2D.new()
	root.name = "DesertApproachRPGWithCommander"

	# ─── Load Assets ───
	var albedo_map = load("res://assets/textures/maps/desert_approach_rpg_albedo.png")
	var normal_map = load("res://assets/textures/maps/desert_approach_rpg_normal.png")
	var radial_light = load("res://assets/textures/effects/light_radial.png")
	var shader_god_rays = load("res://assets/shaders/god_rays.gdshader")
	var shader_tilt_shift = load("res://assets/shaders/tilt_shift_hd2d.gdshader")

	var char_albedo = load("res://assets/textures/units/blue_commander_rpg.png")
	var char_normal = load("res://assets/textures/units/blue_commander_rpg_normal.png")
	var char_shadow = load("res://assets/textures/units/blue_commander_shadow.png")

	# ─── 1. Background Terrain (Normal Mapped) ───
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

	# ─── 2. Commander Character Instance ───
	var char_node = Node2D.new()
	char_node.name = "BlueCommander"
	# Position on the cobblestone trail in the sharp focal plane
	char_node.position = Vector2(645, 475)
	root.add_child(char_node)
	char_node.owner = root

	# Contact Shadow (under boots, projected toward bottom-left away from sun)
	var shadow_sprite = Sprite2D.new()
	shadow_sprite.name = "ContactShadow"
	shadow_sprite.texture = char_shadow
	shadow_sprite.position = Vector2(-8, 5) # slight offset toward bottom-left
	shadow_sprite.scale = Vector2(0.9, 0.45)
	shadow_sprite.modulate = Color(0.15, 0.1, 0.08, 0.75)
	char_node.add_child(shadow_sprite)
	shadow_sprite.owner = root

	# Commander Sprite (with Normal Map)
	var char_canvas_tex = CanvasTexture.new()
	char_canvas_tex.diffuse_texture = char_albedo
	char_canvas_tex.normal_texture = char_normal
	char_canvas_tex.specular_shininess = 0.35

	var commander_sprite = Sprite2D.new()
	commander_sprite.name = "CommanderSprite"
	commander_sprite.texture = char_canvas_tex
	# Scale: 1126px * 0.13 = ~146px tall, perfectly matching trail perspective!
	commander_sprite.scale = Vector2(0.13, 0.13)
	# Anchor at bottom-center (between boots)
	commander_sprite.offset = Vector2(0, -540)
	char_node.add_child(commander_sprite)
	commander_sprite.owner = root

	# Glowing Cyan Medical Gauntlet Light (PointLight2D on her forearm!)
	var gauntlet_light = PointLight2D.new()
	gauntlet_light.name = "GauntletGlow"
	gauntlet_light.texture = radial_light
	gauntlet_light.texture_scale = 0.65
	gauntlet_light.color = Color(0.15, 0.95, 0.85, 1.0)
	gauntlet_light.energy = 1.1
	# Position at forearm coordinates relative to character root
	gauntlet_light.position = Vector2(28, -75)
	char_node.add_child(gauntlet_light)
	gauntlet_light.owner = root

	# ─── 3. Dynamic 2D Lighting ───
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
	exit_light.position = Vector2(688, 180)
	root.add_child(exit_light)
	exit_light.owner = root

	# ─── 4. Dynamic Sunbeams / God Rays ───
	var rays_rect = ColorRect.new()
	rays_rect.name = "GodRaysOverlay"
	rays_rect.position = Vector2(0, 0)
	rays_rect.size = Vector2(1376, 768)
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

	# ─── 5. Desert Dust Particles ───
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
	root.add_child(dust)
	dust.owner = root

	# ─── 6. Tilt-Shift Depth of Field & Cinematic Post-Processing ───
	var post_layer = CanvasLayer.new()
	post_layer.name = "PostProcessing"
	root.add_child(post_layer)
	post_layer.owner = root

	var tilt_rect = ColorRect.new()
	tilt_rect.name = "TiltShiftDof"
	tilt_rect.size = Vector2(1376, 768)
	var mat_tilt = ShaderMaterial.new()
	mat_tilt.shader = shader_tilt_shift
	# Focus directly on Commander's torso/head (Y ~ 420-475)
	mat_tilt.set_shader_parameter("focal_position_y", 0.58)
	mat_tilt.set_shader_parameter("focal_width", 0.22)
	mat_tilt.set_shader_parameter("blur_amount", 3.5)
	mat_tilt.set_shader_parameter("vignette_strength", 0.22)
	mat_tilt.set_shader_parameter("warm_tint", Color(1.02, 1.0, 0.98, 1.0))
	tilt_rect.material = mat_tilt
	post_layer.add_child(tilt_rect)
	tilt_rect.owner = root

	# ─── Save Scene ───
	var scene = PackedScene.new()
	var err = scene.pack(root)
	if err == OK:
		var path = "res://scenes/maps/desert_approach_rpg_with_commander.tscn"
		ResourceSaver.save(scene, path)
		print("SUCCESS: Step 4 scene saved to: ", path)
	else:
		printerr("ERROR packing scene: ", err)

	quit(0)
