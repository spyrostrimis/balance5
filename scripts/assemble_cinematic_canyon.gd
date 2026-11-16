@tool
extends SceneTree

static func get_path_center_x(z: float) -> float:
	return sin(z * 0.22) * 0.35

func make_terrace_block(size: Vector3, seed_val: int, disp: float = 0.16) -> ArrayMesh:
	var bm = BoxMesh.new()
	bm.size = size
	bm.subdivide_width = 6
	bm.subdivide_height = 8
	bm.subdivide_depth = 6

	var st = SurfaceTool.new()
	st.create_from(bm, 0)
	var arr_mesh = st.commit()
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(arr_mesh, 0)

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_val
	noise.frequency = 0.55

	for i in range(mdt.get_vertex_count()):
		var v: Vector3 = mdt.get_vertex(i)
		# Deterministic position-only displacement so shared corner vertices stay 100% watertight
		var nx: float = noise.get_noise_3d(v.x * 1.35, v.y * 0.9, v.z * 1.35)
		var nz: float = noise.get_noise_3d(v.x * 1.35 + 47.0, v.y * 0.9, v.z * 1.35 + 23.0)
		var horiz_weight_x: float = clamp(abs(v.x) / (size.x * 0.5), 0.15, 1.0)
		var horiz_weight_z: float = clamp(abs(v.z) / (size.z * 0.5), 0.15, 1.0)
		# Stepped horizontal sandstone strata ridges on vertical rock faces
		var strata_step: float = sin(v.y * 3.8 + float(seed_val) * 0.2) * (disp * 0.28)
		v.x += (nx * disp + strata_step) * horiz_weight_x
		v.z += (nz * disp + strata_step) * horiz_weight_z

		if v.y > size.y * 0.42:
			v.y = size.y * 0.5 + nx * 0.03
		elif v.y < -size.y * 0.42:
			v.y = -size.y * 0.5

		mdt.set_vertex(i, v)

	var deformed = ArrayMesh.new()
	mdt.commit_to_surface(deformed)
	st.clear()
	st.create_from(deformed, 0)
	st.generate_normals()
	return st.commit()

func _init():
	print("Assembling True 3D Stepped-Terrace HD-2D Canyon Scene...")
	var root = Node3D.new()
	root.name = "DesertCanyonTrue3D"

	# ─── 1. Load HD-2D PBR Textures & Shaders ───
	var tex_red_cliff = load("res://assets/textures/canyon_pbr/hd2d_red_cliff_albedo.png")
	var norm_red_cliff = load("res://assets/textures/canyon_pbr/hd2d_red_cliff_normal.png")
	var tex_dark_ledge = load("res://assets/textures/canyon_pbr/hd2d_dark_ledge_albedo.png")
	var norm_dark_ledge = load("res://assets/textures/canyon_pbr/hd2d_dark_ledge_normal.png")
	var tex_cobble = load("res://assets/textures/canyon_pbr/hd2d_cobble_albedo.png")
	var norm_cobble = load("res://assets/textures/canyon_pbr/hd2d_cobble_normal.png")
	var tex_sand = load("res://assets/textures/canyon_pbr/hd2d_sand_albedo.png")
	var norm_sand = load("res://assets/textures/canyon_pbr/hd2d_sand_normal.png")

	var tex_bush_1 = load("res://assets/textures/canyon_pbr/hd2d_bush_1.png")
	var tex_bush_2 = load("res://assets/textures/canyon_pbr/hd2d_bush_2.png")
	var tex_boulder_1 = load("res://assets/textures/canyon_pbr/hd2d_boulder_1.png")
	var tex_vista = load("res://assets/textures/canyon_pbr/canyon_exit_battlefield_vista.png")
	var char_tex = load("res://assets/textures/units/blue_commander_rpg.png")

	var shader_cliff = load("res://assets/shaders/hd2d_canyon_cliff.gdshader")
	var shader_ground = load("res://assets/shaders/hd2d_canyon_ground.gdshader")
	var shader_god_rays = load("res://assets/shaders/god_rays.gdshader")
	var shader_tilt_shift = load("res://assets/shaders/tilt_shift_hd2d.gdshader")

	var script_player = load("res://scripts/blue_commander_3d_player.gd")
	var script_camera = load("res://scripts/rpg_camera_3d_follow.gd")

	# ─── 2. Custom HD-2D Cliff & Ground Materials ───
	var mat_cliff = ShaderMaterial.new()
	mat_cliff.shader = shader_cliff
	mat_cliff.set_shader_parameter("red_cliff_tex", tex_red_cliff)
	mat_cliff.set_shader_parameter("red_cliff_norm", norm_red_cliff)
	mat_cliff.set_shader_parameter("dark_ledge_tex", tex_dark_ledge)
	mat_cliff.set_shader_parameter("dark_ledge_norm", norm_dark_ledge)

	var mat_ground = ShaderMaterial.new()
	mat_ground.shader = shader_ground
	mat_ground.set_shader_parameter("cobble_tex", tex_cobble)
	mat_ground.set_shader_parameter("cobble_norm", norm_cobble)
	mat_ground.set_shader_parameter("sand_tex", tex_sand)
	mat_ground.set_shader_parameter("sand_norm", norm_sand)

	# ─── 3. Solid Physical Ground & Path Boundaries (Y = 0.0) ───
	var ground_body = StaticBody3D.new()
	ground_body.name = "GroundBaseCollision"
	root.add_child(ground_body)
	ground_body.owner = root

	var floor_col = CollisionShape3D.new()
	floor_col.name = "FloorCol"
	var box_floor = BoxShape3D.new()
	box_floor.size = Vector3(60.0, 1.0, 80.0)
	floor_col.shape = box_floor
	floor_col.position = Vector3(0.0, -0.5, -5.0)
	ground_body.add_child(floor_col)
	floor_col.owner = root

	var left_bar = CollisionShape3D.new()
	left_bar.name = "LeftPathBarrier"
	var bar_shape = BoxShape3D.new()
	bar_shape.size = Vector3(2.0, 10.0, 60.0)
	left_bar.shape = bar_shape
	left_bar.position = Vector3(-2.4, 4.0, -5.0)
	ground_body.add_child(left_bar)
	left_bar.owner = root

	var right_bar = CollisionShape3D.new()
	right_bar.name = "RightPathBarrier"
	right_bar.shape = bar_shape
	right_bar.position = Vector3(2.4, 4.0, -5.0)
	ground_body.add_child(right_bar)
	right_bar.owner = root

	# ─── 4. Winding Cobblestone & Canyon Sand Ground Mesh ───
	var ground_mesh_inst = MeshInstance3D.new()
	ground_mesh_inst.name = "GroundFloorMesh"
	var pm_ground = PlaneMesh.new()
	pm_ground.size = Vector2(50.0, 70.0)
	ground_mesh_inst.mesh = pm_ground
	ground_mesh_inst.material_override = mat_ground
	ground_mesh_inst.position = Vector3(0.0, 0.0, -8.0)
	root.add_child(ground_mesh_inst)
	ground_mesh_inst.owner = root

	# ─── 5. Helper to Add Stepped Terrace Blocks ───
	var add_terrace = func(t_name: String, base_pos: Vector3, sz: Vector3, s_val: int, disp: float = 0.16) -> MeshInstance3D:
		var mi = MeshInstance3D.new()
		mi.name = t_name
		mi.mesh = make_terrace_block(sz, s_val, disp)
		mi.material_override = mat_cliff
		mi.position = base_pos + Vector3(0.0, sz.y * 0.5, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(mi)
		mi.owner = root
		return mi

	# 4 Stepped Terrace Tiers along Left & Right Walls (Z = +9.0 down to -13.5)
	var z_segments = [9.0, 4.5, 0.0, -4.5, -9.0, -13.5]
	for idx in range(z_segments.size()):
		var zc: float = z_segments[idx]
		var pcx: float = get_path_center_x(zc)
		var jitter_l: float = sin(float(idx) * 1.7) * 0.25
		var jitter_r: float = cos(float(idx) * 1.9) * 0.25

		# Left Side 4 Tiers
		add_terrace.call("L_T1_%d" % idx, Vector3(pcx - 2.65 + jitter_l * 0.5, 0.0, zc), Vector3(1.8, 1.3 + jitter_l * 0.15, 4.9), 100 + idx * 10, 0.15)
		add_terrace.call("L_T2_%d" % idx, Vector3(pcx - 4.15 + jitter_l, 0.0, zc), Vector3(2.2, 2.55 + jitter_r * 0.2, 5.0), 101 + idx * 10, 0.18)
		add_terrace.call("L_T3_%d" % idx, Vector3(pcx - 6.05 + jitter_l, 0.0, zc), Vector3(2.8, 4.6 + jitter_l * 0.3, 5.1), 102 + idx * 10, 0.22)
		add_terrace.call("L_T4_%d" % idx, Vector3(pcx - 8.55, 0.0, zc), Vector3(3.6, 8.5 + jitter_r * 0.5, 5.3), 103 + idx * 10, 0.26)

		# Right Side 4 Tiers
		add_terrace.call("R_T1_%d" % idx, Vector3(pcx + 2.65 + jitter_r * 0.5, 0.0, zc), Vector3(1.8, 1.3 + jitter_r * 0.15, 4.9), 200 + idx * 10, 0.15)
		add_terrace.call("R_T2_%d" % idx, Vector3(pcx + 4.15 + jitter_r, 0.0, zc), Vector3(2.2, 2.55 + jitter_l * 0.2, 5.0), 201 + idx * 10, 0.18)
		add_terrace.call("R_T3_%d" % idx, Vector3(pcx + 6.05 + jitter_r, 0.0, zc), Vector3(2.8, 4.6 + jitter_r * 0.3, 5.1), 202 + idx * 10, 0.22)
		add_terrace.call("R_T4_%d" % idx, Vector3(pcx + 8.55, 0.0, zc), Vector3(3.6, 8.5 + jitter_l * 0.5, 5.3), 203 + idx * 10, 0.26)

		# Protruding rock buttresses every other segment for dramatic canyon silhouettes
		if idx % 2 == 1:
			add_terrace.call("L_Buttress_%d" % idx, Vector3(pcx - 2.35, 0.0, zc + 0.6), Vector3(1.3, 2.2, 2.2), 300 + idx, 0.18)
		else:
			add_terrace.call("R_Buttress_%d" % idx, Vector3(pcx + 2.35, 0.0, zc - 0.5), Vector3(1.3, 2.1, 2.2), 350 + idx, 0.18)

	# Foreground Framing Outcroppings (Z = +9.5) — frame starting view & slide past camera on advance
	add_terrace.call("FG_Outcrop_L_Low", Vector3(-2.4, 0.0, 9.5), Vector3(1.6, 1.25, 2.8), 410, 0.16)
	add_terrace.call("FG_Outcrop_L_High", Vector3(-3.6, 0.0, 9.8), Vector3(2.0, 2.9, 3.0), 411, 0.20)
	add_terrace.call("FG_Outcrop_R_Low", Vector3(2.4, 0.0, 9.5), Vector3(1.6, 1.25, 2.8), 420, 0.16)
	add_terrace.call("FG_Outcrop_R_High", Vector3(3.6, 0.0, 9.8), Vector3(2.0, 2.9, 3.0), 421, 0.20)

	# Towering Stepped Canyon Gateway Pillars (Z = -16.2, X = ±3.1, 2.6m sunlit opening)
	add_terrace.call("Gate_Pillar_L1", Vector3(-3.3, 0.0, -16.2), Vector3(3.6, 8.2, 3.8), 501, 0.24)
	add_terrace.call("Gate_Pillar_L2", Vector3(-2.45, 0.0, -16.0), Vector3(2.0, 5.2, 2.8), 502, 0.20)
	add_terrace.call("Gate_Ledge_L", Vector3(-1.90, 0.0, -15.8), Vector3(1.3, 1.35, 2.5), 503, 0.16)

	add_terrace.call("Gate_Pillar_R1", Vector3(3.3, 0.0, -16.2), Vector3(3.6, 8.2, 3.8), 511, 0.24)
	add_terrace.call("Gate_Pillar_R2", Vector3(2.45, 0.0, -16.0), Vector3(2.0, 5.2, 2.8), 512, 0.20)
	add_terrace.call("Gate_Ledge_R", Vector3(1.90, 0.0, -15.8), Vector3(1.3, 1.35, 2.5), 513, 0.16)

	# ─── 6. 3D Curb Stones along Winding Cobblestone Path Edges ───
	var z_curb: float = 9.0
	var curb_idx: int = 0
	while z_curb >= -15.0:
		var pcx: float = get_path_center_x(z_curb)
		var c_ang_l: float = sin(float(curb_idx) * 2.1) * 18.0
		var c_ang_r: float = cos(float(curb_idx) * 2.3) * 18.0

		var curb_l = add_terrace.call("Curb_L_%d" % curb_idx, Vector3(pcx - 1.24, -0.03, z_curb), Vector3(0.28, 0.12, 0.48), 600 + curb_idx, 0.06)
		curb_l.rotation_degrees.y = c_ang_l

		var curb_r = add_terrace.call("Curb_R_%d" % curb_idx, Vector3(pcx + 1.24, -0.03, z_curb - 0.5), Vector3(0.28, 0.12, 0.48), 700 + curb_idx, 0.06)
		curb_r.rotation_degrees.y = c_ang_r

		z_curb -= 1.6
		curb_idx += 1

	# ─── 7. Sunlit Battlefield & Orichalcum Crater Beyond Gateway (Z = -34.0) ───
	var vista_mesh_inst = MeshInstance3D.new()
	vista_mesh_inst.name = "BattlefieldVistaBackdrop"
	var qm_vista = QuadMesh.new()
	qm_vista.size = Vector2(46.0, 25.0)
	vista_mesh_inst.mesh = qm_vista
	var mat_vista = StandardMaterial3D.new()
	mat_vista.albedo_texture = tex_vista
	mat_vista.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vista_mesh_inst.material_override = mat_vista
	vista_mesh_inst.position = Vector3(0.0, 9.2, -34.0)
	root.add_child(vista_mesh_inst)
	vista_mesh_inst.owner = root

	var exit_light = OmniLight3D.new()
	exit_light.name = "ExitHorizonLight"
	exit_light.light_color = Color(1.0, 0.88, 0.62)
	exit_light.light_energy = 0.75
	exit_light.omni_range = 20.0
	exit_light.position = Vector3(0.0, 4.0, -24.0)
	root.add_child(exit_light)
	exit_light.owner = root

	# ─── 8. 35+ Full-Scale HD-2D Desert Bush & Boulder Props ───
	var add_hd_prop = func(p_name: String, p_tex: Texture2D, pos: Vector3, sz: float, flip: bool = false) -> Sprite3D:
		var sp = Sprite3D.new()
		sp.name = p_name
		sp.texture = p_tex
		sp.pixel_size = sz
		sp.flip_h = flip
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.alpha_cut = Sprite3D.ALPHA_CUT_OPAQUE_PREPASS
		sp.alpha_scissor_threshold = 0.25
		sp.shaded = false
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		sp.position = pos
		root.add_child(sp)
		sp.owner = root
		return sp

	var z_prop: float = 8.5
	var p_idx: int = 0
	var bush_textures = [tex_bush_1, tex_bush_2]
	while z_prop >= -15.2:
		var pcx: float = get_path_center_x(z_prop)
		var bt_l: Texture2D = bush_textures[p_idx % 2]
		var bt_r: Texture2D = bush_textures[(p_idx + 1) % 2]
		var sz_l: float = lerp(0.0058, 0.0072, abs(sin(float(p_idx) * 1.3)))
		var sz_r: float = lerp(0.0058, 0.0072, abs(cos(float(p_idx) * 1.7)))

		# Ground-level sage bushes flanking both sides of the winding path
		add_hd_prop.call("Bush_L_%d" % p_idx, bt_l, Vector3(pcx - 1.48 - (p_idx % 2) * 0.16, 0.45, z_prop), sz_l, p_idx % 2 == 1)
		add_hd_prop.call("Bush_R_%d" % p_idx, bt_r, Vector3(pcx + 1.48 + ((p_idx + 1) % 2) * 0.16, 0.45, z_prop - 0.55), sz_r, p_idx % 2 == 0)

		# Foreground & trail boulders
		if p_idx % 2 == 0:
			add_hd_prop.call("Boulder_L_%d" % p_idx, tex_boulder_1, Vector3(pcx - 1.65, 0.36, z_prop - 0.9), 0.0062, p_idx % 4 == 0)
		else:
			add_hd_prop.call("Boulder_R_%d" % p_idx, tex_boulder_1, Vector3(pcx + 1.65, 0.36, z_prop - 0.3), 0.0060, p_idx % 3 == 0)

		# Cliff Tier 1 ledge bushes (Y = 1.65)
		if p_idx % 3 == 0:
			add_hd_prop.call("LedgeBush_L_%d" % p_idx, tex_bush_2, Vector3(pcx - 2.35, 1.65, z_prop - 0.2), 0.0056, false)
			add_hd_prop.call("LedgeBush_R_%d" % p_idx, tex_bush_1, Vector3(pcx + 2.35, 1.65, z_prop - 0.7), 0.0056, true)

		z_prop -= 1.65
		p_idx += 1

	# ─── 9. Playable Blue Commander (CharacterBody3D) ───
	var player = CharacterBody3D.new()
	player.name = "BlueCommander"
	player.set_script(script_player)
	player.position = Vector3(0.0, 0.05, 8.0)
	root.add_child(player)
	player.owner = root

	var col_shape = CollisionShape3D.new()
	col_shape.name = "PlayerCollision"
	var cap = CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	col_shape.shape = cap
	col_shape.position = Vector3(0.0, 0.9, 0.0)
	player.add_child(col_shape)
	col_shape.owner = root

	var commander_sprite = Sprite3D.new()
	commander_sprite.name = "CommanderSprite"
	commander_sprite.texture = char_tex
	commander_sprite.pixel_size = 0.00165
	commander_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	commander_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
	commander_sprite.shaded = false
	commander_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	commander_sprite.position = Vector3(0.0, 0.92, 0.0)
	player.add_child(commander_sprite)
	commander_sprite.owner = root

	var gauntlet_light = OmniLight3D.new()
	gauntlet_light.name = "GauntletGlow"
	gauntlet_light.light_color = Color(0.15, 0.95, 0.85)
	gauntlet_light.light_energy = 0.45
	gauntlet_light.omni_range = 0.65
	gauntlet_light.position = Vector3(0.28, 0.92, 0.06)
	player.add_child(gauntlet_light)
	gauntlet_light.owner = root

	# ─── 10. True 3D Dolly Follow Camera ───
	var cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.set_script(script_camera)
	cam.position = Vector3(0.0, 2.15, 12.2)
	cam.current = true
	cam.fov = 42.0
	cam.set("target_path", NodePath("../BlueCommander"))
	cam.set("follow_offset", Vector3(0.0, 2.1, 4.2))
	cam.set("look_ahead_dist", 3.8)
	root.add_child(cam)
	cam.owner = root

	# ─── 11. Sunlight & Warm HD-2D Environment ───
	var sun = DirectionalLight3D.new()
	sun.name = "DesertSun"
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.45
	sun.light_volumetric_fog_energy = 0.75
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_blur = 1.8
	sun.rotation_degrees = Vector3(-35.0, 42.0, 0.0)
	root.add_child(sun)
	sun.owner = root

	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.95, 0.86, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.74, 0.60)
	env.ambient_light_energy = 0.68

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(1.0, 0.90, 0.72)
	env.volumetric_fog_anisotropy = 0.62

	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	root.add_child(env_node)
	env_node.owner = root

	# ─── 12. img1 God Rays & Dust Motes (Layer 1) ───
	var atmo_layer = CanvasLayer.new()
	atmo_layer.name = "AtmosphereLayer"
	atmo_layer.layer = 1
	root.add_child(atmo_layer)
	atmo_layer.owner = root

	var rays_rect = ColorRect.new()
	rays_rect.name = "GodRaysOverlay"
	rays_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat_rays = ShaderMaterial.new()
	mat_rays.shader = shader_god_rays
	mat_rays.set_shader_parameter("angle", -0.42)
	mat_rays.set_shader_parameter("ray_density", 14.0)
	mat_rays.set_shader_parameter("ray_speed", 0.12)
	mat_rays.set_shader_parameter("ray_intensity", 0.22)
	mat_rays.set_shader_parameter("ray_color", Color(1.0, 0.92, 0.72, 1.0))
	rays_rect.material = mat_rays
	atmo_layer.add_child(rays_rect)
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
	atmo_layer.add_child(dust)
	dust.owner = root

	# ─── 13. img1 Tilt-Shift DOF & Vignette (Layer 2) ───
	var post_layer = CanvasLayer.new()
	post_layer.name = "PostProcessing"
	post_layer.layer = 2
	root.add_child(post_layer)
	post_layer.owner = root

	var tilt_rect = ColorRect.new()
	tilt_rect.name = "TiltShiftDof"
	tilt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tilt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat_tilt = ShaderMaterial.new()
	mat_tilt.shader = shader_tilt_shift
	mat_tilt.set_shader_parameter("focal_position_y", 0.56)
	mat_tilt.set_shader_parameter("focal_width", 0.26)
	mat_tilt.set_shader_parameter("blur_amount", 1.6)
	mat_tilt.set_shader_parameter("vignette_strength", 0.18)
	mat_tilt.set_shader_parameter("warm_tint", Color(1.02, 1.0, 0.98, 1.0))
	tilt_rect.material = mat_tilt
	post_layer.add_child(tilt_rect)
	tilt_rect.owner = root

	# ─── Save PackedScene ───
	var scene = PackedScene.new()
	var err = scene.pack(root)
	if err == OK:
		var path = "res://scenes/maps/desert_canyon_true_3d.tscn"
		ResourceSaver.save(scene, path)
		print("SUCCESS: Stepped-Terrace HD-2D 3D Canyon saved to: ", path)
	else:
		printerr("ERROR packing scene: ", err)

	quit(0)
