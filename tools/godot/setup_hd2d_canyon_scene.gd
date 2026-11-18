@tool
extends SceneTree

func _init():
	print("Building Cinematic HD-2D Multiplane Canyon Scene...")
	var root = Node3D.new()
	root.name = "DesertCanyonTrue3D"

	# ─── 1. Textures ───
	var tex_path = load("res://assets/textures/canyon_layers/canyon_path_seamless.png")
	var norm_path = load("res://assets/textures/canyon_layers/canyon_path_normal.png")
	var tex_sand = load("res://assets/textures/canyon_layers/canyon_sand_seamless.png")
	var tex_fg_l = load("res://assets/textures/canyon_layers/fg_cliff_left.png")
	var tex_fg_r = load("res://assets/textures/canyon_layers/fg_cliff_right.png")
	var tex_mid_l = load("res://assets/textures/canyon_layers/mid_cliff_left.png")
	var tex_mid_r = load("res://assets/textures/canyon_layers/mid_cliff_right.png")
	var tex_gate_l = load("res://assets/textures/canyon_layers/gate_pillar_left.png")
	var tex_gate_r = load("res://assets/textures/canyon_layers/gate_pillar_right.png")
	var tex_vista = load("res://assets/textures/canyon_layers/canyon_vista_backdrop.png")
	var tex_rays = load("res://assets/textures/canyon_layers/god_rays.png")
	var tex_bush = load("res://assets/textures/maps/prop_bush.png")
	var tex_rock = load("res://assets/textures/maps/prop_rock.png")
	var char_tex = load("res://assets/textures/units/blue_commander_rpg.png")

	# ─── 2. Physical Ground & Boundaries ───
	var ground_body = StaticBody3D.new()
	ground_body.name = "GroundBaseCollision"
	root.add_child(ground_body)
	ground_body.owner = root

	var floor_col = CollisionShape3D.new()
	floor_col.name = "FloorCol"
	var box_floor = BoxShape3D.new()
	box_floor.size = Vector3(40.0, 1.0, 60.0)
	floor_col.shape = box_floor
	floor_col.position = Vector3(0, -0.5, -4.0)
	ground_body.add_child(floor_col)
	floor_col.owner = root

	# Left & Right invisible barrier walls
	var left_bar = CollisionShape3D.new()
	left_bar.name = "LeftBarrier"
	var b_shape = BoxShape3D.new()
	b_shape.size = Vector3(2.0, 8.0, 60.0)
	left_bar.shape = b_shape
	left_bar.position = Vector3(-2.8, 3.0, -4.0)
	ground_body.add_child(left_bar)
	left_bar.owner = root

	var right_bar = CollisionShape3D.new()
	right_bar.name = "RightBarrier"
	right_bar.shape = b_shape
	right_bar.position = Vector3(2.8, 3.0, -4.0)
	ground_body.add_child(right_bar)
	right_bar.owner = root

	# ─── 3. Ground Visual Meshes ───
	# Desert Sand Floor
	var sand_mesh_inst = MeshInstance3D.new()
	sand_mesh_inst.name = "SandFloor"
	var plane_sand = PlaneMesh.new()
	plane_sand.size = Vector2(30.0, 50.0)
	sand_mesh_inst.mesh = plane_sand
	var mat_sand = StandardMaterial3D.new()
	mat_sand.albedo_texture = tex_sand
	mat_sand.uv1_scale = Vector3(12.0, 20.0, 1.0)
	mat_sand.roughness = 0.95
	sand_mesh_inst.material_override = mat_sand
	sand_mesh_inst.position = Vector3(0, 0.0, -4.0)
	root.add_child(sand_mesh_inst)
	sand_mesh_inst.owner = root

	# Cobblestone Path
	var path_mesh_inst = MeshInstance3D.new()
	path_mesh_inst.name = "CobblestonePath"
	var plane_path = PlaneMesh.new()
	plane_path.size = Vector2(2.6, 42.0)
	path_mesh_inst.mesh = plane_path
	var mat_path = StandardMaterial3D.new()
	mat_path.albedo_texture = tex_path
	mat_path.normal_enabled = true
	mat_path.normal_texture = norm_path
	mat_path.uv1_scale = Vector3(1.5, 24.0, 1.0)
	mat_path.roughness = 0.85
	path_mesh_inst.material_override = mat_path
	path_mesh_inst.position = Vector3(0, 0.02, -4.0)
	root.add_child(path_mesh_inst)
	path_mesh_inst.owner = root

	# Helper to create multiplane Sprite3D cards
	var make_card = func(c_name: String, tex: Texture2D, pos: Vector3, sz: float, rot_y: float = 0.0, alpha_cut: int = Sprite3D.ALPHA_CUT_DISCARD) -> Sprite3D:
		var sp = Sprite3D.new()
		sp.name = c_name
		sp.texture = tex
		sp.pixel_size = sz
		sp.position = pos
		sp.rotation_degrees.y = rot_y
		sp.alpha_cut = alpha_cut
		sp.shaded = true
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		root.add_child(sp)
		sp.owner = root
		return sp

	# ─── 4. Layered 3D Multiplane Canyon Walls ───
	# Foreground (Z = 5.0): Framed close to camera, slides past as we walk
	var fg_l = make_card.call("FG_Cliff_Left", tex_fg_l, Vector3(-3.2, 2.0, 4.8), 0.0075, 12.0)
	var fg_r = make_card.call("FG_Cliff_Right", tex_fg_r, Vector3(3.2, 2.0, 4.8), 0.0075, -12.0)

	# Midground Tier 1 (Z = 0.0)
	var mid_l1 = make_card.call("Mid_Cliff_L1", tex_mid_l, Vector3(-3.6, 3.2, 0.5), 0.009, 8.0)
	var mid_r1 = make_card.call("Mid_Cliff_R1", tex_mid_r, Vector3(3.6, 3.2, 0.5), 0.009, -8.0)

	# Midground Tier 2 (Z = -6.0)
	var mid_l2 = make_card.call("Mid_Cliff_L2", tex_mid_l, Vector3(-3.3, 3.6, -6.0), 0.010, 5.0)
	mid_l2.flip_h = true
	var mid_r2 = make_card.call("Mid_Cliff_R2", tex_mid_r, Vector3(3.3, 3.6, -6.0), 0.010, -5.0)

	# Midground Tier 3 (Z = -11.0)
	var mid_l3 = make_card.call("Mid_Cliff_L3", tex_mid_l, Vector3(-2.8, 4.0, -11.0), 0.011, 4.0)
	var mid_r3 = make_card.call("Mid_Cliff_R3", tex_mid_r, Vector3(2.8, 4.0, -11.0), 0.011, -4.0)
	mid_r3.flip_h = true

	# Canyon Gateway Pillars (The Opening at Z = -15.5)
	var gate_l = make_card.call("Gate_Pillar_L", tex_gate_l, Vector3(-1.8, 3.6, -15.5), 0.013, 0.0)
	var gate_r = make_card.call("Gate_Pillar_R", tex_gate_r, Vector3(1.8, 3.6, -15.5), 0.013, 0.0)

	# Distant Vista Backdrop (Beyond the opening at Z = -26.0)
	var vista_sp = Sprite3D.new()
	vista_sp.name = "VistaBackdrop"
	vista_sp.texture = tex_vista
	vista_sp.pixel_size = 0.024
	vista_sp.position = Vector3(0.0, 4.2, -26.0)
	vista_sp.shaded = false # Self-luminous sunlit desert sky
	root.add_child(vista_sp)
	vista_sp.owner = root

	# Atmospheric God Rays
	var rays_sp = Sprite3D.new()
	rays_sp.name = "GodRays"
	rays_sp.texture = tex_rays
	rays_sp.pixel_size = 0.009
	rays_sp.position = Vector3(0.8, 3.2, -1.0)
	rays_sp.rotation_degrees = Vector3(-15.0, -20.0, 0.0)
	rays_sp.modulate = Color(1.0, 0.92, 0.72, 0.70)
	rays_sp.shaded = false
	root.add_child(rays_sp)
	rays_sp.owner = root

	# ─── 5. Props: Bushes & Small Rocks along Path ───
	var make_prop = func(p_name: String, p_tex: Texture2D, pos: Vector3, sz: float) -> Sprite3D:
		var sp = Sprite3D.new()
		sp.name = p_name
		sp.texture = p_tex
		sp.pixel_size = sz
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		sp.position = pos
		root.add_child(sp)
		sp.owner = root
		return sp

	make_prop.call("Bush_1", tex_bush, Vector3(-1.5, 0.35, 5.0), 0.0035)
	make_prop.call("Rock_1", tex_rock, Vector3(1.5, 0.25, 4.0), 0.0030)
	make_prop.call("Bush_2", tex_bush, Vector3(1.6, 0.35, 1.5), 0.0035)
	make_prop.call("Rock_2", tex_rock, Vector3(-1.6, 0.25, -1.5), 0.0030)
	make_prop.call("Bush_3", tex_bush, Vector3(-1.5, 0.35, -4.5), 0.0038)
	make_prop.call("Bush_4", tex_bush, Vector3(1.5, 0.35, -8.0), 0.0035)
	make_prop.call("Rock_3", tex_rock, Vector3(1.4, 0.25, -11.0), 0.0030)
	make_prop.call("Gate_Bush_L", tex_bush, Vector3(-1.5, 0.35, -14.5), 0.0040)
	make_prop.call("Gate_Bush_R", tex_bush, Vector3(1.5, 0.35, -14.5), 0.0040)

	# ─── 6. Blue Commander (Player) ───
	var script_player = load("res://scripts/blue_commander_3d_player.gd")
	var player = CharacterBody3D.new()
	player.name = "BlueCommander"
	player.set_script(script_player)
	player.position = Vector3(0.0, 0.05, 6.0) # Starts at beginning of canyon trail
	root.add_child(player)
	player.owner = root

	var col_shape = CollisionShape3D.new()
	col_shape.name = "PlayerCollision"
	var cap = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col_shape.shape = cap
	col_shape.position = Vector3(0, 0.9, 0)
	player.add_child(col_shape)
	col_shape.owner = root

	var commander_sprite = Sprite3D.new()
	commander_sprite.name = "CommanderSprite"
	commander_sprite.texture = char_tex
	commander_sprite.pixel_size = 0.00165
	commander_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	commander_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
	commander_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	commander_sprite.position = Vector3(0, 0.95, 0)
	player.add_child(commander_sprite)
	commander_sprite.owner = root

	var gauntlet_light = OmniLight3D.new()
	gauntlet_light.name = "GauntletGlow"
	gauntlet_light.light_color = Color(0.15, 0.95, 0.85)
	gauntlet_light.light_energy = 1.4
	gauntlet_light.omni_range = 1.8
	gauntlet_light.position = Vector3(0.28, 0.9, 0.05)
	player.add_child(gauntlet_light)
	gauntlet_light.owner = root

	# ─── 7. Camera 3D Follow ───
	var script_camera = load("res://scripts/rpg_camera_3d_follow.gd")
	var cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.set_script(script_camera)
	cam.position = Vector3(0.0, 2.0, 9.8) # Behind player
	cam.current = true
	cam.fov = 46.0
	cam.set("target_path", NodePath("../BlueCommander"))
	cam.set("follow_offset", Vector3(0.0, 2.0, 3.8))
	cam.set("look_ahead_dist", 4.0)

	var cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 22.0
	cam_attr.dof_blur_far_transition = 10.0
	cam_attr.dof_blur_amount = 0.05
	cam.attributes = cam_attr
	root.add_child(cam)
	cam.owner = root

	# ─── 8. Directional Sunlight & World Environment ───
	var sun = DirectionalLight3D.new()
	sun.name = "DesertSun"
	sun.light_color = Color(1.0, 0.94, 0.85)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.rotation_degrees = Vector3(-34, 45, 0)
	root.add_child(sun)
	sun.owner = root

	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.96, 0.88, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.75, 0.62)
	env.ambient_light_energy = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.15
	env_node.environment = env
	root.add_child(env_node)
	env_node.owner = root

	# Save PackedScene
	var scene = PackedScene.new()
	var err = scene.pack(root)
	if err == OK:
		var path = "res://scenes/maps/desert_canyon_true_3d.tscn"
		ResourceSaver.save(scene, path)
		print("SUCCESS: HD-2D Multiplane Canyon Scene saved to: ", path)
	else:
		printerr("ERROR packing scene: ", err)

	quit(0)
