@tool
extends SceneTree

func _init():
	if not preload("res://tools/godot/tool_guard.gd").confirm(self, PackedStringArray(["res://scenes/maps/desert_canyon_3d_rpg.tscn"])):
		return
	print("Generating True 3D Desert Canyon Scene (res://scenes/maps/desert_canyon_3d_rpg.tscn)...")
	var root = Node3D.new()
	root.name = "DesertCanyon3D"

	# ─── Load Textures ───
	var tex_sand = load("res://assets/textures/maps/tex_sand_albedo_seamless.png")
	var norm_sand = load("res://assets/textures/maps/tex_sand_normal.png")
	var tex_rock = load("res://assets/textures/maps/tex_rock_albedo_seamless.png")
	var norm_rock = load("res://assets/textures/maps/tex_rock_normal.png")
	var tex_path = load("res://assets/textures/maps/tex_path_albedo_seamless.png")
	var norm_path = load("res://assets/textures/maps/tex_path_normal.png")
	var tex_bush = load("res://assets/textures/maps/prop_bush.png")
	var tex_rock_prop = load("res://assets/textures/maps/prop_rock.png")
	var char_sprite_tex = load("res://assets/textures/units/blue_commander_rpg.png")

	var script_player = load("res://scripts/blue_commander_3d_player.gd")
	var script_camera = load("res://scripts/rpg_camera_3d_follow.gd")

	# ─── Materials ───
	var mat_sand = StandardMaterial3D.new()
	mat_sand.albedo_texture = tex_sand
	mat_sand.normal_enabled = true
	mat_sand.normal_texture = norm_sand
	mat_sand.uv1_scale = Vector3(12, 24, 1)
	mat_sand.roughness = 0.9

	var mat_rock = StandardMaterial3D.new()
	mat_rock.albedo_texture = tex_rock
	mat_rock.normal_enabled = true
	mat_rock.normal_texture = norm_rock
	mat_rock.uv1_scale = Vector3(2.5, 2.5, 1)
	mat_rock.roughness = 0.85

	var mat_path = StandardMaterial3D.new()
	mat_path.albedo_texture = tex_path
	mat_path.normal_enabled = true
	mat_path.normal_texture = norm_path
	mat_path.uv1_scale = Vector3(2, 8, 1)
	mat_path.roughness = 0.92

	# ─── 1. Physical 3D Ground (Sand Plane with Collision) ───
	var ground_body = StaticBody3D.new()
	ground_body.name = "GroundBody"
	root.add_child(ground_body)
	ground_body.owner = root

	var ground_mesh_inst = MeshInstance3D.new()
	ground_mesh_inst.name = "GroundMesh"
	var ground_mesh = PlaneMesh.new()
	ground_mesh.size = Vector2(50, 90)
	ground_mesh_inst.mesh = ground_mesh
	ground_mesh_inst.material_override = mat_sand
	ground_mesh_inst.position = Vector3(0, 0, -10)
	ground_body.add_child(ground_mesh_inst)
	ground_mesh_inst.owner = root

	var ground_col = CollisionShape3D.new()
	ground_col.name = "GroundCollision"
	var ground_box = BoxShape3D.new()
	ground_box.size = Vector3(50, 0.4, 90)
	ground_col.shape = ground_box
	ground_col.position = Vector3(0, -0.2, -10)
	ground_body.add_child(ground_col)
	ground_col.owner = root

	# ─── 2. Cobblestone Stone Trail (Z = +12 down to -25) ───
	var trail_parent = Node3D.new()
	trail_parent.name = "StoneTrail"
	root.add_child(trail_parent)
	trail_parent.owner = root

	# S-curved trail segments leading toward the canyon mouth at Z = -22
	var trail_segments = [
		Vector3(0.0, 0.02, 10.0),
		Vector3(0.2, 0.02, 6.0),
		Vector3(-0.3, 0.02, 2.0),
		Vector3(0.1, 0.02, -2.0),
		Vector3(0.4, 0.02, -6.0),
		Vector3(0.2, 0.02, -10.0),
		Vector3(-0.2, 0.02, -14.0),
		Vector3(0.0, 0.02, -18.0),
		Vector3(0.1, 0.02, -22.0), # Right through the canyon mouth opening!
		Vector3(0.0, 0.02, -26.0), # Out onto the battlefield clearing!
	]
	for i in range(trail_segments.size()):
		var t_box = BoxMesh.new()
		t_box.size = Vector3(3.2, 0.04, 4.4)
		var t_inst = MeshInstance3D.new()
		t_inst.name = "Segment_%d" % i
		t_inst.mesh = t_box
		t_inst.material_override = mat_path
		t_inst.position = trail_segments[i]
		trail_parent.add_child(t_inst)
		t_inst.owner = root

	# ─── 3. Stepped 3D Canyon Walls (Left & Right Flanks) ───
	var walls_parent = Node3D.new()
	walls_parent.name = "CanyonWalls"
	root.add_child(walls_parent)
	walls_parent.owner = root

	var add_canyon_block = func(b_name: String, pos: Vector3, sz: Vector3) -> StaticBody3D:
		var sb = StaticBody3D.new()
		sb.name = b_name
		sb.position = pos + Vector3(0, sz.y / 2.0, 0)
		walls_parent.add_child(sb)
		sb.owner = root

		var mi = MeshInstance3D.new()
		mi.name = "Mesh"
		var bm = BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.material_override = mat_rock
		sb.add_child(mi)
		mi.owner = root

		var col = CollisionShape3D.new()
		col.name = "Col"
		var bs = BoxShape3D.new()
		bs.size = sz
		col.shape = bs
		sb.add_child(col)
		col.owner = root

		return sb

	# LEFT WALLS (X negative, flanking path from Z = +12 to Z = -20)
	# Tier 1 (Low shelf, height 1.6m)
	add_canyon_block.call("L_T1_A", Vector3(-4.0, 0, 8.0), Vector3(3.2, 1.6, 6.0))
	add_canyon_block.call("L_T1_B", Vector3(-3.8, 0, 2.0), Vector3(3.0, 1.8, 6.5))
	add_canyon_block.call("L_T1_C", Vector3(-4.1, 0, -4.0), Vector3(3.2, 2.0, 6.0))
	add_canyon_block.call("L_T1_D", Vector3(-3.9, 0, -10.0), Vector3(3.0, 1.7, 6.5))
	add_canyon_block.call("L_T1_E", Vector3(-4.0, 0, -16.0), Vector3(3.2, 1.9, 6.0))

	# Tier 2 (Mid shelf, height 3.5m)
	add_canyon_block.call("L_T2_A", Vector3(-6.8, 0, 6.0), Vector3(4.0, 3.5, 8.0))
	add_canyon_block.call("L_T2_B", Vector3(-6.6, 0, -2.0), Vector3(4.2, 3.8, 9.0))
	add_canyon_block.call("L_T2_C", Vector3(-6.9, 0, -10.0), Vector3(4.0, 3.6, 8.5))

	# Tier 3 (Towering ridge, height 6.5m)
	add_canyon_block.call("L_T3_A", Vector3(-10.2, 0, 4.0), Vector3(4.5, 6.5, 14.0))
	add_canyon_block.call("L_T3_B", Vector3(-10.5, 0, -8.0), Vector3(4.5, 7.0, 14.0))

	# RIGHT WALLS (X positive, flanking path from Z = +12 to Z = -20)
	# Tier 1
	add_canyon_block.call("R_T1_A", Vector3(4.0, 0, 8.0), Vector3(3.2, 1.5, 6.0))
	add_canyon_block.call("R_T1_B", Vector3(3.8, 0, 2.0), Vector3(3.0, 1.7, 6.5))
	add_canyon_block.call("R_T1_C", Vector3(4.2, 0, -4.0), Vector3(3.4, 1.9, 6.0))
	add_canyon_block.call("R_T1_D", Vector3(3.9, 0, -10.0), Vector3(3.0, 1.6, 6.5))
	add_canyon_block.call("R_T1_E", Vector3(4.1, 0, -16.0), Vector3(3.2, 1.8, 6.0))

	# Tier 2
	add_canyon_block.call("R_T2_A", Vector3(6.8, 0, 6.0), Vector3(4.0, 3.4, 8.0))
	add_canyon_block.call("R_T2_B", Vector3(6.6, 0, -2.0), Vector3(4.2, 3.7, 9.0))
	add_canyon_block.call("R_T2_C", Vector3(6.9, 0, -10.0), Vector3(4.0, 3.5, 8.5))

	# Tier 3
	add_canyon_block.call("R_T3_A", Vector3(10.2, 0, 4.0), Vector3(4.5, 6.2, 14.0))
	add_canyon_block.call("R_T3_B", Vector3(10.5, 0, -8.0), Vector3(4.5, 6.8, 14.0))

	# ─── 4. The Canyon Exit Gateway (Z = -22 to -25) ───
	# Natural rock pillars forming the canyon mouth archway
	add_canyon_block.call("ExitGate_Pillar_L", Vector3(-4.5, 0, -21.0), Vector3(4.0, 7.5, 4.0))
	add_canyon_block.call("ExitGate_Pillar_R", Vector3(4.5, 0, -21.0), Vector3(4.0, 7.5, 4.0))
	# Arch beam overhead connecting the pillars
	add_canyon_block.call("ExitGate_ArchTop", Vector3(0.0, 6.0, -21.0), Vector3(8.0, 2.0, 3.5))

	# Beyond the gate: The sunlit desert clearing plateau!
	add_canyon_block.call("Clearing_Rock_L", Vector3(-12.0, 0, -32.0), Vector3(8.0, 4.5, 12.0))
	add_canyon_block.call("Clearing_Rock_R", Vector3(12.0, 0, -32.0), Vector3(8.0, 4.5, 12.0))
	# Distant desert mountains in the sunlit horizon (Z = -45)
	add_canyon_block.call("Distant_Mountain", Vector3(0.0, 0, -45.0), Vector3(32.0, 5.0, 8.0))

	# ─── 5. Props: Bushes & Boulders (Sprite3D Billboards) ───
	var add_billboard_prop = func(p_name: String, tex: Texture2D, pos: Vector3, p_size: float = 0.0025) -> Sprite3D:
		var sp = Sprite3D.new()
		sp.name = p_name
		sp.texture = tex
		sp.pixel_size = p_size
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		sp.position = pos
		root.add_child(sp)
		sp.owner = root
		return sp

	# Bushes and rocks along the trail sides
	add_billboard_prop.call("Bush_1", tex_bush, Vector3(-1.9, 0.4, 7.0), 0.0035)
	add_billboard_prop.call("Rock_1", tex_rock_prop, Vector3(1.8, 0.3, 5.0), 0.003)
	add_billboard_prop.call("Bush_2", tex_bush, Vector3(2.0, 0.4, 1.0), 0.0035)
	add_billboard_prop.call("Bush_3", tex_bush, Vector3(-2.1, 0.4, -3.0), 0.0038)
	add_billboard_prop.call("Rock_2", tex_rock_prop, Vector3(-1.8, 0.3, -7.0), 0.003)
	add_billboard_prop.call("Bush_4", tex_bush, Vector3(1.9, 0.4, -11.0), 0.0035)
	add_billboard_prop.call("Bush_5", tex_bush, Vector3(-2.0, 0.4, -15.0), 0.0038)
	# Bush at the canyon mouth exit
	add_billboard_prop.call("Exit_Bush_L", tex_bush, Vector3(-2.2, 0.4, -20.0), 0.004)
	add_billboard_prop.call("Exit_Bush_R", tex_bush, Vector3(2.2, 0.4, -20.5), 0.004)

	# ─── 6. Playable Blue Commander (CharacterBody3D) ───
	var player = CharacterBody3D.new()
	player.name = "BlueCommander"
	player.set_script(script_player)
	# Starts near the beginning of the canyon trail (Z = 8.0)
	player.position = Vector3(0.0, 0.0, 8.0)
	root.add_child(player)
	player.owner = root

	# Collision Shape
	var col_shape = CollisionShape3D.new()
	col_shape.name = "PlayerCollision"
	var cap = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col_shape.shape = cap
	col_shape.position = Vector3(0, 0.9, 0)
	player.add_child(col_shape)
	col_shape.owner = root

	# Commander Sprite3D (Y-Billboard, casting real 3D shadow)
	var commander_sprite = Sprite3D.new()
	commander_sprite.name = "CommanderSprite"
	commander_sprite.texture = char_sprite_tex
	# 1126px * 0.00165 = ~1.85m tall in 3D world space!
	commander_sprite.pixel_size = 0.00165
	commander_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	commander_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
	commander_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	commander_sprite.position = Vector3(0, 0.95, 0)
	player.add_child(commander_sprite)
	commander_sprite.owner = root

	# Glowing Cyan Medical Gauntlet (OmniLight3D)
	var gauntlet_light = OmniLight3D.new()
	gauntlet_light.name = "GauntletGlow"
	gauntlet_light.light_color = Color(0.15, 0.95, 0.85)
	gauntlet_light.light_energy = 1.2
	gauntlet_light.omni_range = 1.4
	gauntlet_light.position = Vector3(0.28, 0.9, 0.05)
	player.add_child(gauntlet_light)
	gauntlet_light.owner = root

	# ─── 7. 3D Cinematic Following Camera ───
	var cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.set_script(script_camera)
	cam.position = Vector3(0.0, 2.5, 12.8) # 4.8m behind player
	cam.current = true
	cam.fov = 50.0
	cam.set("target_path", NodePath("../BlueCommander"))

	# Depth of Field (Tilt-shift miniature effect)
	var cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 22.0
	cam_attr.dof_blur_far_transition = 9.0
	cam_attr.dof_blur_near_enabled = true
	cam_attr.dof_blur_near_distance = 2.2
	cam_attr.dof_blur_near_transition = 1.2
	cam_attr.dof_blur_amount = 0.12
	cam.attributes = cam_attr
	root.add_child(cam)
	cam.owner = root

	# ─── 8. Directional Sunlight & Volumetric God Rays ───
	# Sun shining through the canyon opening towards the player
	var sun = DirectionalLight3D.new()
	sun.name = "DesertSun"
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 4.2
	sun.light_volumetric_fog_energy = 3.8 # God Rays streaming through the arch!
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.rotation_degrees = Vector3(-28, 172, 0)
	root.add_child(sun)
	sun.owner = root

	# Sunlit Horizon Glow at the Exit Gate
	var exit_glow = OmniLight3D.new()
	exit_glow.name = "ClearingExitGlow"
	exit_glow.light_color = Color(1.0, 0.85, 0.50)
	exit_glow.light_energy = 6.0
	exit_glow.light_volumetric_fog_energy = 4.0
	exit_glow.omni_range = 28.0
	exit_glow.position = Vector3(0, 3.5, -24.0)
	root.add_child(exit_glow)
	exit_glow.owner = root

	# ─── 9. WorldEnvironment (Volumetric Fog, Sky & ACES Tonemapping) ───
	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.96, 0.88, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.74, 0.60)
	env.ambient_light_energy = 0.5

	# Real-time Volumetric Fog (Sunbeams through canyon arch!)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.028
	env.volumetric_fog_albedo = Color(1.0, 0.93, 0.76)
	env.volumetric_fog_emission = Color(0.08, 0.06, 0.02)
	env.volumetric_fog_anisotropy = 0.72 # Light rays beam forward dramatically!

	# Bloom & Color Grading
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 1.2

	env_node.environment = env
	root.add_child(env_node)
	env_node.owner = root

	# ─── Save Scene ───
	var scene = PackedScene.new()
	var err = scene.pack(root)
	if err == OK:
		var path = "res://scenes/maps/desert_canyon_3d_rpg.tscn"
		ResourceSaver.save(scene, path)
		print("SUCCESS: True 3D Canyon Scene saved to: ", path)
	else:
		printerr("ERROR packing scene: ", err)

	quit(0)
