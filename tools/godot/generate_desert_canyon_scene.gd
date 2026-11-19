@tool
extends SceneTree

func _init():
	if not preload("res://tools/godot/tool_guard.gd").confirm(self, PackedStringArray(["res://scenes/maps/desert_canyon_rpg.tscn"])):
		return
	print("Building Desert Canyon RPG Scene (Step 3 HD-2D)...")
	var root = Node3D.new()
	root.name = "DesertCanyonRPG"

	# ─── Load Textures ───
	var tex_sand = load("res://assets/textures/maps/tex_sand_albedo_seamless.png")
	var norm_sand = load("res://assets/textures/maps/tex_sand_normal.png")
	var tex_rock = load("res://assets/textures/maps/tex_rock_albedo_seamless.png")
	var norm_rock = load("res://assets/textures/maps/tex_rock_normal.png")
	var tex_path = load("res://assets/textures/maps/tex_path_albedo_seamless.png")
	var norm_path = load("res://assets/textures/maps/tex_path_normal.png")
	var tex_bush = load("res://assets/textures/maps/prop_bush.png")
	var tex_rock_prop = load("res://assets/textures/maps/prop_rock.png")

	# ─── Materials ───
	var mat_sand = StandardMaterial3D.new()
	mat_sand.albedo_texture = tex_sand
	mat_sand.normal_enabled = true
	mat_sand.normal_texture = norm_sand
	mat_sand.uv1_scale = Vector3(8, 12, 1)
	mat_sand.roughness = 0.9

	var mat_rock = StandardMaterial3D.new()
	mat_rock.albedo_texture = tex_rock
	mat_rock.normal_enabled = true
	mat_rock.normal_texture = norm_rock
	mat_rock.uv1_scale = Vector3(3, 3, 1)
	mat_rock.roughness = 0.85

	var mat_path = StandardMaterial3D.new()
	mat_path.albedo_texture = tex_path
	mat_path.normal_enabled = true
	mat_path.normal_texture = norm_path
	mat_path.uv1_scale = Vector3(2, 8, 1)
	mat_path.roughness = 0.95

	# ─── Ground Plane ───
	var ground = MeshInstance3D.new()
	ground.name = "GroundSand"
	var ground_mesh = PlaneMesh.new()
	ground_mesh.size = Vector2(40, 50)
	ground.mesh = ground_mesh
	ground.material_override = mat_sand
	ground.position = Vector3(0, 0, 0)
	root.add_child(ground)
	ground.owner = root

	# ─── Center Winding Trail ───
	# Curved segments along Z axis from Z=14 to Z=-20
	var trail_points = [
		Vector3(0.0, 0.02, 12.0),
		Vector3(0.3, 0.02, 8.0),
		Vector3(-0.4, 0.02, 4.0),
		Vector3(0.2, 0.02, 0.0),
		Vector3(0.6, 0.02, -4.0),
		Vector3(0.1, 0.02, -8.0),
		Vector3(-0.3, 0.02, -12.0),
		Vector3(0.0, 0.02, -16.0),
	]
	for i in range(trail_points.size()):
		var pt = trail_points[i]
		var t_mesh = BoxMesh.new()
		t_mesh.size = Vector3(2.8, 0.04, 4.5)
		var t_inst = MeshInstance3D.new()
		t_inst.name = "Trail_%d" % i
		t_inst.mesh = t_mesh
		t_inst.material_override = mat_path
		t_inst.position = pt
		root.add_child(t_inst)
		t_inst.owner = root

	# ─── Terraced Canyon Walls (Octopath Stepped Shelves) ───
	# Helper for cliff blocks
	var make_cliff = func(node_name: String, pos: Vector3, sz: Vector3) -> MeshInstance3D:
		var c_mesh = BoxMesh.new()
		c_mesh.size = sz
		var c_inst = MeshInstance3D.new()
		c_inst.name = node_name
		c_inst.mesh = c_mesh
		c_inst.material_override = mat_rock
		c_inst.position = pos + Vector3(0, sz.y / 2.0, 0)
		root.add_child(c_inst)
		c_inst.owner = root
		return c_inst

	# LEFT CLIFF TIERS (X negative)
	# Tier 1 (Low shelf along trail, height 1.2)
	make_cliff.call("L_Tier1_A", Vector3(-4.2, 0, 10), Vector3(3.5, 1.2, 6.0))
	make_cliff.call("L_Tier1_B", Vector3(-4.0, 0, 4), Vector3(3.2, 1.5, 6.5))
	make_cliff.call("L_Tier1_C", Vector3(-4.4, 0, -2), Vector3(3.6, 1.8, 6.0))
	make_cliff.call("L_Tier1_D", Vector3(-4.1, 0, -8), Vector3(3.4, 1.4, 6.5))
	make_cliff.call("L_Tier1_E", Vector3(-4.5, 0, -14), Vector3(3.5, 1.6, 6.0))

	# Tier 2 (Mid shelf, height 2.8)
	make_cliff.call("L_Tier2_A", Vector3(-7.2, 0, 8), Vector3(4.0, 2.8, 8.0))
	make_cliff.call("L_Tier2_B", Vector3(-7.0, 0, 0), Vector3(4.2, 3.2, 9.0))
	make_cliff.call("L_Tier2_C", Vector3(-7.5, 0, -8), Vector3(4.0, 3.0, 8.5))

	# Tier 3 (High canyon wall backdrop, height 5.5)
	make_cliff.call("L_Tier3_A", Vector3(-10.5, 0, 6), Vector3(4.5, 5.5, 14.0))
	make_cliff.call("L_Tier3_B", Vector3(-10.8, 0, -6), Vector3(4.5, 6.0, 14.0))

	# RIGHT CLIFF TIERS (X positive)
	# Tier 1
	make_cliff.call("R_Tier1_A", Vector3(4.2, 0, 10), Vector3(3.4, 1.0, 6.0))
	make_cliff.call("R_Tier1_B", Vector3(4.0, 0, 4), Vector3(3.2, 1.4, 6.5))
	make_cliff.call("R_Tier1_C", Vector3(4.3, 0, -2), Vector3(3.5, 1.6, 6.0))
	make_cliff.call("R_Tier1_D", Vector3(4.1, 0, -8), Vector3(3.3, 1.5, 6.5))
	make_cliff.call("R_Tier1_E", Vector3(4.4, 0, -14), Vector3(3.5, 1.7, 6.0))

	# Tier 2
	make_cliff.call("R_Tier2_A", Vector3(7.0, 0, 8), Vector3(4.0, 2.6, 8.0))
	make_cliff.call("R_Tier2_B", Vector3(6.8, 0, 0), Vector3(4.0, 3.0, 9.0))
	make_cliff.call("R_Tier2_C", Vector3(7.2, 0, -8), Vector3(4.2, 3.2, 8.5))

	# Tier 3
	make_cliff.call("R_Tier3_A", Vector3(10.2, 0, 6), Vector3(4.5, 5.2, 14.0))
	make_cliff.call("R_Tier3_B", Vector3(10.5, 0, -6), Vector3(4.5, 5.8, 14.0))

	# Distant canyon gate / exit into sunlit clearing (at Z = -22)
	make_cliff.call("Gate_L", Vector3(-6.0, 0, -20), Vector3(5.0, 6.5, 4.0))
	make_cliff.call("Gate_R", Vector3(6.0, 0, -20), Vector3(5.0, 6.5, 4.0))
	make_cliff.call("Dist_Plateau", Vector3(0.0, 0, -28), Vector3(20.0, 3.0, 8.0))

	# ─── Props: Bushes & Rocks (Sprite3D Billboards) ───
	var add_sprite_prop = func(p_name: String, tex: Texture2D, pos: Vector3, pixel_size: float = 0.02) -> Sprite3D:
		var sp = Sprite3D.new()
		sp.name = p_name
		sp.texture = tex
		sp.pixel_size = pixel_size
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		sp.position = pos
		root.add_child(sp)
		sp.owner = root
		return sp

	# Foreground blurred props (close to camera, Z ~ 10 to 12)
	add_sprite_prop.call("FG_Rock_L", tex_rock_prop, Vector3(-1.8, 0.4, 11.0), 0.035)
	add_sprite_prop.call("FG_Rock_R", tex_rock_prop, Vector3(2.0, 0.4, 10.5), 0.03)

	# Midground props along trail & on shelves (Z ~ 8 to -5)
	add_sprite_prop.call("Bush_L1", tex_bush, Vector3(-2.0, 0.35, 7.0), 0.025)
	add_sprite_prop.call("Bush_R1", tex_bush, Vector3(1.9, 0.35, 5.5), 0.022)
	add_sprite_prop.call("Rock_Mid1", tex_rock_prop, Vector3(-1.9, 0.3, 3.0), 0.025)
	add_sprite_prop.call("Bush_L2", tex_bush, Vector3(-2.1, 0.35, 1.0), 0.028)
	add_sprite_prop.call("Bush_R2", tex_bush, Vector3(2.0, 0.35, -2.5), 0.026)
	add_sprite_prop.call("Rock_Mid2", tex_rock_prop, Vector3(1.8, 0.3, -5.0), 0.025)

	# Bushes on cliff ledges
	add_sprite_prop.call("Cliff_Bush_L1", tex_bush, Vector3(-3.2, 1.5, 4.0), 0.03)
	add_sprite_prop.call("Cliff_Bush_R1", tex_bush, Vector3(3.2, 1.4, 3.5), 0.028)
	add_sprite_prop.call("Cliff_Bush_L2", tex_bush, Vector3(-3.5, 1.8, -2.0), 0.032)
	add_sprite_prop.call("Cliff_Bush_R2", tex_bush, Vector3(3.5, 1.6, -7.0), 0.028)

	# ─── Lighting Setup ───
	# Directional Sun Light (Warm diagonal sunlight with volumetric rays)
	var sun = DirectionalLight3D.new()
	sun.name = "DesertSun"
	sun.light_color = Color(1.0, 0.93, 0.78)
	sun.light_energy = 4.5
	sun.light_volumetric_fog_energy = 3.5 # God Rays!
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.rotation_degrees = Vector3(-42, 145, 0)
	root.add_child(sun)
	sun.owner = root

	# Golden Clearing Glow (OmniLight3D in the distance)
	var exit_glow = OmniLight3D.new()
	exit_glow.name = "ExitGlow"
	exit_glow.light_color = Color(1.0, 0.82, 0.45)
	exit_glow.light_energy = 8.0
	exit_glow.light_volumetric_fog_energy = 4.0
	exit_glow.omni_range = 25.0
	exit_glow.position = Vector3(0, 3.0, -20.0)
	root.add_child(exit_glow)
	exit_glow.owner = root

	# ─── WorldEnvironment ───
	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.96, 0.88, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.88, 0.76, 0.62)
	env.ambient_light_energy = 0.6

	# Volumetric Fog (Octopath atmospheric haze & light shafts)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.045
	env.volumetric_fog_albedo = Color(1.0, 0.92, 0.75)
	env.volumetric_fog_emission = Color(0.12, 0.09, 0.03)
	env.volumetric_fog_anisotropy = 0.65

	# Glow & Bloom
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Color Grading (ACES tonemapping + rich contrast)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.18
	env.adjustment_saturation = 1.22

	env_node.environment = env
	root.add_child(env_node)
	env_node.owner = root

	# ─── Camera (Octopath Low-Angle Tilt-Shift) ───
	var cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0.0, 3.2, 13.0)
	cam.rotation_degrees = Vector3(-16, 0, 0)
	cam.fov = 52.0

	# Practical Camera Attributes for Depth of Field
	var cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 15.0 # Sharp up to mid trail
	cam_attr.dof_blur_far_transition = 7.0
	cam_attr.dof_blur_near_enabled = true
	cam_attr.dof_blur_near_distance = 4.0 # Blurs close rocks
	cam_attr.dof_blur_near_transition = 2.0
	cam_attr.dof_blur_amount = 0.18 # Rich tilt-shift miniature feel
	cam.attributes = cam_attr

	root.add_child(cam)
	cam.owner = root

	# ─── Save PackedScene ───
	var scene = PackedScene.new()
	var result = scene.pack(root)
	if result == OK:
		var scene_path = "res://scenes/maps/desert_canyon_rpg.tscn"
		ResourceSaver.save(scene, scene_path)
		print("Scene saved successfully to: ", scene_path)
	else:
		printerr("Failed to pack scene, error code: ", result)

	quit(0)
