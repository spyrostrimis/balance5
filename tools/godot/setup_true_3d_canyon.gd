@tool
extends SceneTree

func _init():
	if not preload("res://tools/godot/tool_guard.gd").confirm(self, PackedStringArray(["res://scenes/maps/desert_canyon_true_3d.tscn"])):
		return
	print("Assembling AAA True 3D Canyon Scene with Triplanar Textures and Gateway Arch...")
	var root = Node3D.new()
	root.name = "DesertCanyonTrue3D"

	# ─── Load Textures ───
	var tex_rock = load("res://assets/textures/maps/tex_rock_clean_albedo.png")
	var norm_rock = load("res://assets/textures/maps/tex_rock_clean_normal.png")
	var tex_sand = load("res://assets/textures/maps/tex_sand_albedo_seamless.png")
	var norm_sand = load("res://assets/textures/maps/tex_sand_normal.png")
	var tex_path = load("res://assets/textures/maps/tex_path_albedo_seamless.png")
	var norm_path = load("res://assets/textures/maps/tex_path_normal.png")
	var tex_bush = load("res://assets/textures/maps/prop_bush.png")
	var tex_rock_prop = load("res://assets/textures/maps/prop_rock.png")
	var char_sprite_tex = load("res://assets/textures/units/blue_commander_rpg.png")

	# ─── Triplanar Materials (Zero Texture Stretching on Slopes/Cliffs!) ───
	var mat_rock = StandardMaterial3D.new()
	mat_rock.albedo_texture = tex_rock
	mat_rock.normal_enabled = true
	mat_rock.normal_texture = norm_rock
	mat_rock.uv1_triplanar = true
	mat_rock.uv1_scale = Vector3(0.35, 0.35, 0.35)
	mat_rock.roughness = 0.88

	var mat_sand = StandardMaterial3D.new()
	mat_sand.albedo_texture = tex_sand
	mat_sand.normal_enabled = true
	mat_sand.normal_texture = norm_sand
	mat_sand.uv1_triplanar = true
	mat_sand.uv1_scale = Vector3(0.25, 0.25, 0.25)
	mat_sand.roughness = 0.92

	var mat_path = StandardMaterial3D.new()
	mat_path.albedo_texture = tex_path
	mat_path.normal_enabled = true
	mat_path.normal_texture = norm_path
	mat_path.uv1_scale = Vector3(2.0, 8.0, 1.0)
	mat_path.roughness = 0.90

	# ─── 1. Solid Ground Base (Collision & Physics Floor) ───
	var ground_body = StaticBody3D.new()
	ground_body.name = "GroundBaseCollision"
	root.add_child(ground_body)
	ground_body.owner = root

	var ground_col = CollisionShape3D.new()
	ground_col.name = "GroundBox"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(50.0, 1.0, 80.0)
	ground_col.shape = box_shape
	ground_col.position = Vector3(0, -0.5, -12.0)
	ground_body.add_child(ground_col)
	ground_col.owner = root

	# Left and Right Canyon Wall Collision (guides hero along path)
	var left_wall_col = CollisionShape3D.new()
	left_wall_col.name = "LeftWallCol"
	var l_box = BoxShape3D.new()
	l_box.size = Vector3(12.0, 10.0, 65.0)
	left_wall_col.shape = l_box
	left_wall_col.position = Vector3(-9.2, 4.0, -10.0)
	ground_body.add_child(left_wall_col)
	left_wall_col.owner = root

	var right_wall_col = CollisionShape3D.new()
	right_wall_col.name = "RightWallCol"
	var r_box = BoxShape3D.new()
	r_box.size = Vector3(12.0, 10.0, 65.0)
	right_wall_col.shape = r_box
	right_wall_col.position = Vector3(9.2, 4.0, -10.0)
	ground_body.add_child(right_wall_col)
	right_wall_col.owner = root

	# ─── 2. Canyon Environment Model (GLB) ───
	var glb_res = load("res://assets/models/canyon_environment.glb")
	if glb_res:
		var canyon_model = glb_res.instantiate()
		canyon_model.name = "CanyonModel"
		root.add_child(canyon_model)
		canyon_model.owner = root

		var terrain_mesh = canyon_model.get_node("CanyonTerrain") as MeshInstance3D
		var path_mesh = canyon_model.get_node("CobblestonePath") as MeshInstance3D

		if terrain_mesh:
			terrain_mesh.material_override = mat_rock
		if path_mesh:
			path_mesh.material_override = mat_path

	# ─── 3. Gateway Arch & Canyon Exit (Z = -22 to -25) ───
	var add_rock_mesh = func(r_name: String, pos: Vector3, sz: Vector3) -> MeshInstance3D:
		var mi = MeshInstance3D.new()
		mi.name = r_name
		var bm = BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.material_override = mat_rock
		mi.position = pos + Vector3(0, sz.y / 2.0, 0)
		root.add_child(mi)
		mi.owner = root
		return mi

	# Arch Pillars framing the exit at Z = -22
	add_rock_mesh.call("ExitPillar_L", Vector3(-3.8, 0, -22.0), Vector3(3.2, 7.5, 3.5))
	add_rock_mesh.call("ExitPillar_R", Vector3(3.8, 0, -22.0), Vector3(3.2, 7.5, 3.5))
	add_rock_mesh.call("ExitArch_Top", Vector3(0.0, 5.5, -22.0), Vector3(7.5, 2.0, 3.0))

	# Distant sunlit desert clearing ground and mountains beyond the gate (Z = -26 to -50)
	var clearing_ground = MeshInstance3D.new()
	clearing_ground.name = "ClearingGround"
	var cl_mesh = PlaneMesh.new()
	cl_mesh.size = Vector2(60, 40)
	clearing_ground.mesh = cl_mesh
	clearing_ground.material_override = mat_sand
	clearing_ground.position = Vector3(0, 0.01, -38.0)
	root.add_child(clearing_ground)
	clearing_ground.owner = root

	# Distant mountain backdrop
	add_rock_mesh.call("DistantMountain_L", Vector3(-16.0, 0, -48.0), Vector3(20.0, 6.0, 8.0))
	add_rock_mesh.call("DistantMountain_R", Vector3(16.0, 0, -48.0), Vector3(20.0, 6.0, 8.0))

	# ─── 4. Props: Desert Bushes & Rocks (Sprite3D Billboards) ───
	var add_prop = func(p_name: String, tex: Texture2D, pos: Vector3, sz: float = 0.0035) -> Sprite3D:
		var sp = Sprite3D.new()
		sp.name = p_name
		sp.texture = tex
		sp.pixel_size = sz
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		sp.position = pos
		root.add_child(sp)
		sp.owner = root
		return sp

	add_prop.call("Bush_1", tex_bush, Vector3(-1.8, 0.4, 8.0), 0.0035)
	add_prop.call("Rock_1", tex_rock_prop, Vector3(1.7, 0.3, 5.0), 0.003)
	add_prop.call("Bush_2", tex_bush, Vector3(1.9, 0.4, 1.0), 0.0035)
	add_prop.call("Bush_3", tex_bush, Vector3(-2.0, 0.4, -4.0), 0.0038)
	add_prop.call("Rock_2", tex_rock_prop, Vector3(-1.7, 0.3, -8.0), 0.003)
	add_prop.call("Bush_4", tex_bush, Vector3(1.8, 0.4, -13.0), 0.0035)
	add_prop.call("Bush_5", tex_bush, Vector3(-1.9, 0.4, -18.0), 0.0038)
	# Props right at the gateway
	add_prop.call("Gate_Bush_L", tex_bush, Vector3(-2.4, 0.4, -21.5), 0.004)
	add_prop.call("Gate_Bush_R", tex_bush, Vector3(2.4, 0.4, -21.5), 0.004)

	# ─── 5. Playable Blue Commander (CharacterBody3D) ───
	var script_player = load("res://scripts/blue_commander_3d_player.gd")
	var player = CharacterBody3D.new()
	player.name = "BlueCommander"
	player.set_script(script_player)
	player.position = Vector3(0.0, 0.05, 10.0)
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
	commander_sprite.texture = char_sprite_tex
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
	gauntlet_light.light_energy = 1.2
	gauntlet_light.omni_range = 1.5
	gauntlet_light.position = Vector3(0.28, 0.9, 0.05)
	player.add_child(gauntlet_light)
	gauntlet_light.owner = root

	# ─── 6. Cinematic 3D Following Camera (Camera3D) ───
	var script_camera = load("res://scripts/rpg_camera_3d_follow.gd")
	var cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.set_script(script_camera)
	cam.position = Vector3(0.0, 2.5, 14.8)
	cam.current = true
	cam.fov = 48.0
	cam.set("target_path", NodePath("../BlueCommander"))

	var cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 28.0
	cam_attr.dof_blur_far_transition = 12.0
	cam_attr.dof_blur_near_enabled = true
	cam_attr.dof_blur_near_distance = 2.0
	cam_attr.dof_blur_near_transition = 1.2
	cam_attr.dof_blur_amount = 0.06
	cam.attributes = cam_attr
	root.add_child(cam)
	cam.owner = root

	# ─── 7. Balanced Lighting (No Whiteout!) ───
	var sun = DirectionalLight3D.new()
	sun.name = "DesertSun"
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 2.0
	sun.light_volumetric_fog_energy = 0.8
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.rotation_degrees = Vector3(-38, 48, 0)
	root.add_child(sun)
	sun.owner = root

	# Subtle golden glow through the gateway
	var exit_light = OmniLight3D.new()
	exit_light.name = "ExitHorizonLight"
	exit_light.light_color = Color(1.0, 0.86, 0.55)
	exit_light.light_energy = 1.8
	exit_light.omni_range = 30.0
	exit_light.position = Vector3(0, 3.5, -24.0)
	root.add_child(exit_light)
	exit_light.owner = root

	# ─── 8. WorldEnvironment ───
	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.96, 0.88, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.74, 0.60)
	env.ambient_light_energy = 0.55

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.005
	env.volumetric_fog_albedo = Color(1.0, 0.93, 0.76)
	env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	env.volumetric_fog_anisotropy = 0.6

	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.15

	env_node.environment = env
	root.add_child(env_node)
	env_node.owner = root

	# ─── Save Scene ───
	var scene = PackedScene.new()
	var err = scene.pack(root)
	if err == OK:
		var path = "res://scenes/maps/desert_canyon_true_3d.tscn"
		ResourceSaver.save(scene, path)
		print("SUCCESS: True 3D Canyon Scene saved to: ", path)
	else:
		printerr("ERROR packing scene: ", err)

	quit(0)
