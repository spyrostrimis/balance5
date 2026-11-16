@tool
extends SceneTree

func make_organic_rock(size: Vector3, seed_val: int = 1234, disp: float = 0.35) -> ArrayMesh:
	var bm = BoxMesh.new()
	bm.size = size
	bm.subdivide_width = int(clamp(size.x * 2.0, 4, 12))
	bm.subdivide_height = int(clamp(size.y * 2.0, 6, 16))
	bm.subdivide_depth = int(clamp(size.z * 2.0, 4, 12))

	var st = SurfaceTool.new()
	st.create_from(bm, 0)
	var arr_mesh = st.commit()
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(arr_mesh, 0)

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_val
	noise.frequency = 0.30

	for i in range(mdt.get_vertex_count()):
		var v = mdt.get_vertex(i)
		var norm = mdt.get_vertex_normal(i)
		var n = noise.get_noise_3dv(v * 1.2) * disp
		var strata = sin(v.y * 3.0) * (disp * 0.3)
		v += norm * (n + strata)
		mdt.set_vertex(i, v)

	var final_mesh = ArrayMesh.new()
	mdt.commit_to_surface(final_mesh)
	st.clear()
	st.create_from(final_mesh, 0)
	st.generate_normals()
	return st.commit()

func _init():
	print("Assembling Refined Organic Stratified Sandstone Canyon...")
	var root = Node3D.new()
	root.name = "DesertCanyonTrue3D"

	# ─── 1. Load PBR Textures ───
	var tex_rock = load("res://assets/textures/canyon_pbr/sandstone_rock_albedo.png")
	var norm_rock = load("res://assets/textures/canyon_pbr/sandstone_rock_normal.png")
	var tex_path = load("res://assets/textures/canyon_pbr/canyon_path_albedo.png")
	var norm_path = load("res://assets/textures/canyon_pbr/canyon_path_normal.png")
	var tex_sand = load("res://assets/textures/canyon_pbr/pure_dune_sand_albedo.png")
	var norm_sand = load("res://assets/textures/canyon_pbr/pure_dune_sand_normal.png")
	var tex_vista = load("res://assets/textures/canyon_pbr/canyon_exit_battlefield_vista.png")
	var tex_bush = load("res://assets/textures/maps/prop_bush.png")
	var tex_rock_prop = load("res://assets/textures/maps/prop_rock.png")
	var char_tex = load("res://assets/textures/units/blue_commander_rpg.png")

	# ─── 2. Materials ───
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
	mat_sand.roughness = 0.94

	var mat_path = StandardMaterial3D.new()
	mat_path.albedo_texture = tex_path
	mat_path.normal_enabled = true
	mat_path.normal_texture = norm_path
	mat_path.uv1_scale = Vector3(1.0, 16.0, 1.0)
	mat_path.roughness = 0.82

	# ─── 3. Physical Collision Base & Barriers ───
	var ground_body = StaticBody3D.new()
	ground_body.name = "GroundBaseCollision"
	root.add_child(ground_body)
	ground_body.owner = root

	var floor_col = CollisionShape3D.new()
	floor_col.name = "FloorCol"
	var box_floor = BoxShape3D.new()
	box_floor.size = Vector3(60.0, 1.0, 80.0)
	floor_col.shape = box_floor
	floor_col.position = Vector3(0, -0.5, -6.0)
	ground_body.add_child(floor_col)
	floor_col.owner = root

	var left_bar = CollisionShape3D.new()
	left_bar.name = "LeftPathBarrier"
	var bar_shape = BoxShape3D.new()
	bar_shape.size = Vector3(2.0, 10.0, 50.0)
	left_bar.shape = bar_shape
	left_bar.position = Vector3(-2.6, 4.0, -4.0)
	ground_body.add_child(left_bar)
	left_bar.owner = root

	var right_bar = CollisionShape3D.new()
	right_bar.name = "RightPathBarrier"
	right_bar.shape = bar_shape
	right_bar.position = Vector3(2.6, 4.0, -4.0)
	ground_body.add_child(right_bar)
	right_bar.owner = root

	# ─── 4. Ground Visual Meshes ───
	var sand_plane = MeshInstance3D.new()
	sand_plane.name = "SandFloorMesh"
	var pm_sand = PlaneMesh.new()
	pm_sand.size = Vector2(50.0, 70.0)
	sand_plane.mesh = pm_sand
	sand_plane.material_override = mat_sand
	sand_plane.position = Vector3(0, 0.0, -8.0)
	root.add_child(sand_plane)
	sand_plane.owner = root

	var path_plane = MeshInstance3D.new()
	path_plane.name = "CobblestonePathMesh"
	var pm_path = PlaneMesh.new()
	pm_path.size = Vector2(2.5, 36.0)
	path_plane.mesh = pm_path
	path_plane.material_override = mat_path
	path_plane.position = Vector3(0, 0.02, -5.0)
	root.add_child(path_plane)
	path_plane.owner = root

	# ─── 5. Organic Sandstone Rock Formations ───
	var add_organic_cliff = func(r_name: String, pos: Vector3, sz: Vector3, s_val: int, disp: float = 0.35) -> MeshInstance3D:
		var mi = MeshInstance3D.new()
		mi.name = r_name
		mi.mesh = make_organic_rock(sz, s_val, disp)
		mi.material_override = mat_rock
		mi.position = pos + Vector3(0, sz.y / 2.0, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(mi)
		mi.owner = root
		return mi

	# ── Left Canyon Wall (Stepped Organic Terraces) ──
	add_organic_cliff.call("L_FG_Shelf", Vector3(-3.2, 0.0, 7.0), Vector3(2.8, 1.8, 8.5), 101, 0.30)
	add_organic_cliff.call("L_FG_Wall", Vector3(-5.2, 0.0, 7.0), Vector3(3.2, 4.4, 8.5), 102, 0.40)
	add_organic_cliff.call("L_FG_Ridge", Vector3(-8.0, 0.0, 7.0), Vector3(4.5, 8.5, 9.0), 103, 0.50)

	add_organic_cliff.call("L_Mid1_Shelf", Vector3(-3.0, 0.0, 0.0), Vector3(2.6, 2.0, 8.5), 201, 0.30)
	add_organic_cliff.call("L_Mid1_Wall", Vector3(-5.0, 0.0, 0.0), Vector3(3.2, 4.8, 8.5), 202, 0.40)
	add_organic_cliff.call("L_Mid1_Ridge", Vector3(-7.8, 0.0, 0.0), Vector3(4.5, 9.0, 9.0), 203, 0.50)

	add_organic_cliff.call("L_Mid2_Shelf", Vector3(-2.8, 0.0, -8.0), Vector3(2.5, 2.2, 8.5), 301, 0.30)
	add_organic_cliff.call("L_Mid2_Wall", Vector3(-4.8, 0.0, -8.0), Vector3(3.2, 5.4, 8.5), 302, 0.40)
	add_organic_cliff.call("L_Mid2_Ridge", Vector3(-7.6, 0.0, -8.0), Vector3(4.5, 9.5, 9.0), 303, 0.50)

	# Gateway Arch Left & Keystone (Z = -16.0)
	add_organic_cliff.call("L_Gate_Pillar", Vector3(-3.0, 0.0, -16.0), Vector3(3.8, 10.0, 5.0), 401, 0.45)
	add_organic_cliff.call("L_Gate_Arch", Vector3(-1.4, 7.2, -16.0), Vector3(2.6, 2.4, 4.5), 402, 0.35)
	add_organic_cliff.call("Arch_Keystone", Vector3(0.0, 8.0, -16.0), Vector3(2.2, 1.8, 4.0), 403, 0.30)

	# ── Right Canyon Wall (Stepped Organic Terraces) ──
	add_organic_cliff.call("R_FG_Shelf", Vector3(3.2, 0.0, 7.0), Vector3(2.8, 1.8, 8.5), 501, 0.30)
	add_organic_cliff.call("R_FG_Wall", Vector3(5.2, 0.0, 7.0), Vector3(3.2, 4.4, 8.5), 502, 0.40)
	add_organic_cliff.call("R_FG_Ridge", Vector3(8.0, 0.0, 7.0), Vector3(4.5, 8.5, 9.0), 503, 0.50)

	add_organic_cliff.call("R_Mid1_Shelf", Vector3(3.0, 0.0, 0.0), Vector3(2.6, 2.0, 8.5), 601, 0.30)
	add_organic_cliff.call("R_Mid1_Wall", Vector3(5.0, 0.0, 0.0), Vector3(3.2, 4.8, 8.5), 602, 0.40)
	add_organic_cliff.call("R_Mid1_Ridge", Vector3(7.8, 0.0, 0.0), Vector3(4.5, 9.0, 9.0), 603, 0.50)

	add_organic_cliff.call("R_Mid2_Shelf", Vector3(2.8, 0.0, -8.0), Vector3(2.5, 2.2, 8.5), 701, 0.30)
	add_organic_cliff.call("R_Mid2_Wall", Vector3(4.8, 0.0, -8.0), Vector3(3.2, 5.4, 8.5), 702, 0.40)
	add_organic_cliff.call("R_Mid2_Ridge", Vector3(7.6, 0.0, -8.0), Vector3(4.5, 9.5, 9.0), 703, 0.50)

	# Gateway Arch Right
	add_organic_cliff.call("R_Gate_Pillar", Vector3(3.0, 0.0, -16.0), Vector3(3.8, 10.0, 5.0), 801, 0.45)
	add_organic_cliff.call("R_Gate_Arch", Vector3(1.4, 7.2, -16.0), Vector3(2.6, 2.4, 4.5), 802, 0.35)

	# ─── 6. Panoramic Battlefield Vista Backdrop (Beyond Gate at Z = -34.0) ───
	var vista_mesh_inst = MeshInstance3D.new()
	vista_mesh_inst.name = "BattlefieldVistaBackdrop"
	var qm_vista = QuadMesh.new()
	qm_vista.size = Vector2(46.0, 25.0)
	vista_mesh_inst.mesh = qm_vista
	var mat_vista = StandardMaterial3D.new()
	mat_vista.albedo_texture = tex_vista
	mat_vista.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vista_mesh_inst.material_override = mat_vista
	vista_mesh_inst.position = Vector3(0.0, 9.5, -34.0)
	root.add_child(vista_mesh_inst)
	vista_mesh_inst.owner = root

	# ─── 7. Props: Bushes & Small Rocks along the Path ───
	var add_prop = func(p_name: String, p_tex: Texture2D, pos: Vector3, sz: float) -> Sprite3D:
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

	add_prop.call("Bush_1", tex_bush, Vector3(-1.5, 0.35, 6.0), 0.0035)
	add_prop.call("Rock_1", tex_rock_prop, Vector3(1.5, 0.25, 5.0), 0.0030)
	add_prop.call("Bush_2", tex_bush, Vector3(1.5, 0.35, 2.0), 0.0035)
	add_prop.call("Rock_2", tex_rock_prop, Vector3(-1.6, 0.25, -1.0), 0.0030)
	add_prop.call("Bush_3", tex_bush, Vector3(-1.5, 0.35, -4.5), 0.0038)
	add_prop.call("Bush_4", tex_bush, Vector3(1.5, 0.35, -8.0), 0.0035)
	add_prop.call("Rock_3", tex_rock_prop, Vector3(-1.5, 0.25, -11.0), 0.0030)
	add_prop.call("Gate_Bush_L", tex_bush, Vector3(-1.5, 0.35, -14.5), 0.0040)
	add_prop.call("Gate_Bush_R", tex_bush, Vector3(1.5, 0.35, -14.5), 0.0040)

	# ─── 8. Blue Commander (CharacterBody3D) ───
	var script_player = load("res://scripts/blue_commander_3d_player.gd")
	var player = CharacterBody3D.new()
	player.name = "BlueCommander"
	player.set_script(script_player)
	player.position = Vector3(0.0, 0.05, 8.0)
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
	gauntlet_light.light_energy = 0.8
	gauntlet_light.omni_range = 1.0
	gauntlet_light.position = Vector3(0.28, 0.9, 0.05)
	player.add_child(gauntlet_light)
	gauntlet_light.owner = root

	# ─── 9. Cinematic Camera3D Follow ───
	var script_camera = load("res://scripts/rpg_camera_3d_follow.gd")
	var cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.set_script(script_camera)
	cam.position = Vector3(0.0, 2.2, 12.2)
	cam.current = true
	cam.fov = 44.0
	cam.set("target_path", NodePath("../BlueCommander"))
	cam.set("follow_offset", Vector3(0.0, 2.2, 4.2))
	cam.set("look_ahead_dist", 3.8)

	var cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 25.0
	cam_attr.dof_blur_far_transition = 12.0
	cam_attr.dof_blur_amount = 0.05
	cam.attributes = cam_attr
	root.add_child(cam)
	cam.owner = root

	# ─── 10. Directional Sunlight & World Environment ───
	var sun = DirectionalLight3D.new()
	sun.name = "DesertSun"
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 2.2
	sun.light_volumetric_fog_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.rotation_degrees = Vector3(-32, 42, 0)
	root.add_child(sun)
	sun.owner = root

	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.95, 0.86, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.72, 0.58)
	env.ambient_light_energy = 0.52

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.005
	env.volumetric_fog_albedo = Color(1.0, 0.92, 0.78)
	env.volumetric_fog_anisotropy = 0.65

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

	# Save PackedScene
	var scene = PackedScene.new()
	var err = scene.pack(root)
	if err == OK:
		var path = "res://scenes/maps/desert_canyon_true_3d.tscn"
		ResourceSaver.save(scene, path)
		print("SUCCESS: Refined Organic Canyon Scene saved to: ", path)
	else:
		printerr("ERROR packing scene: ", err)

	quit(0)
