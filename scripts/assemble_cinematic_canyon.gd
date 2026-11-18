extends SceneTree


func _init() -> void:
	build_and_save_scene()
	quit(0)


func _own(node: Node, root: Node) -> Node:
	node.owner = root
	return node


func _make_wing_material(tex_path: String, tint: Color, haze_strength: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/hd2d_diorama_wing.gdshader")
	mat.set_shader_parameter("wing_tex", load(tex_path))
	mat.set_shader_parameter("albedo_tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("alpha_clip", 0.08)
	mat.set_shader_parameter("haze_color", Color(0.96, 0.80, 0.54))
	mat.set_shader_parameter("haze_strength", haze_strength)
	mat.set_shader_parameter("fade_start", 16.0)
	mat.set_shader_parameter("fade_end", 44.0)
	return mat


func _add_wing(
	parent: Node3D,
	root: Node,
	wing_name: String,
	tex_path: String,
	pos: Vector3,
	rot_deg: Vector3,
	size: Vector2,
	tint: Color,
	haze_strength: float = 0.22
) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = wing_name
	var q := QuadMesh.new()
	q.size = size
	mesh_inst.mesh = q
	mesh_inst.position = pos
	mesh_inst.rotation_degrees = rot_deg
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_inst.set_surface_override_material(0, _make_wing_material(tex_path, tint, haze_strength))
	parent.add_child(mesh_inst)
	_own(mesh_inst, root)
	return mesh_inst


func _add_prop_sprite(
	parent: Node3D,
	root: Node,
	prop_name: String,
	tex_path: String,
	pos: Vector3,
	pixel_size: float,
	rot_deg: Vector3 = Vector3(-16.0, 0.0, 0.0),
	flip_h: bool = false,
	modulate: Color = Color(1.0, 0.96, 0.90, 1.0)
) -> Sprite3D:
	var spr := Sprite3D.new()
	spr.name = prop_name
	spr.texture = load(tex_path)
	spr.pixel_size = pixel_size
	spr.flip_h = flip_h
	spr.modulate = modulate
	spr.shaded = false
	spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.alpha_scissor_threshold = 0.24
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spr.position = pos
	spr.rotation_degrees = rot_deg
	parent.add_child(spr)
	_own(spr, root)
	return spr


static func _path_cx(z: float) -> float:
	return sin(z * 0.22) * 0.65


static func _find_mesh_recursive(node: Node, target_name: String) -> Mesh:
	if node is MeshInstance3D and node.name == target_name:
		return node.mesh
	for child in node.get_children():
		var found := _find_mesh_recursive(child, target_name)
		if found:
			return found
	return null


func build_and_save_scene() -> void:
	var root := Node3D.new()
	root.name = "DesertCanyonDiorama"

	# ─── 1. WorldEnvironment & Desert Sun ───
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.64, 0.80, 0.95)
	sky_mat.sky_horizon_color = Color(0.98, 0.89, 0.74)
	sky_mat.ground_horizon_color = Color(0.95, 0.80, 0.56)
	sky_mat.ground_bottom_color = Color(0.74, 0.52, 0.30)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.glow_enabled = true
	env.glow_intensity = 0.42
	env.glow_bloom = 0.14
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.98, 0.83, 0.56)
	env.fog_light_energy = 1.05
	env.fog_density = 0.0075
	env.fog_aerial_perspective = 0.30
	env.fog_sky_affect = 0.20

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	root.add_child(world_env)
	_own(world_env, root)

	var sun := DirectionalLight3D.new()
	sun.name = "DesertSun"
	# Upper-right desert afternoon sun matching Img 1 sunbeams and right-wall shadows
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.78)
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 60.0
	root.add_child(sun)
	_own(sun, root)

	# ─── 2. Solid Walkable Ground Plane (Y = 0.0) ───
	var floor_body := StaticBody3D.new()
	floor_body.name = "GroundFloor"
	floor_body.position = Vector3(0.0, -0.5, -14.0)
	var floor_col := CollisionShape3D.new()
	floor_col.name = "FloorShape"
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(60.0, 1.0, 90.0)
	floor_col.shape = floor_box
	floor_body.add_child(floor_col)
	root.add_child(floor_body)
	_own(floor_body, root)
	_own(floor_col, root)

	var mat_ground := ShaderMaterial.new()
	mat_ground.shader = load("res://assets/shaders/hd2d_canyon_ground.gdshader")
	mat_ground.set_shader_parameter("cobble_tex", load("res://assets/textures/canyon_pbr/hd2d_cobble_albedo.png"))
	mat_ground.set_shader_parameter("cobble_norm", load("res://assets/textures/canyon_pbr/hd2d_cobble_normal.png"))
	mat_ground.set_shader_parameter("sand_tex", load("res://assets/textures/canyon_pbr/hd2d_sand_albedo.png"))
	mat_ground.set_shader_parameter("sand_norm", load("res://assets/textures/canyon_pbr/hd2d_sand_normal.png"))
	mat_ground.set_shader_parameter("desert_sand_tex", load("res://assets/textures/canyon_pbr/pure_dune_sand_albedo.png"))
	mat_ground.set_shader_parameter("desert_sand_norm", load("res://assets/textures/canyon_pbr/pure_dune_sand_normal.png"))
	mat_ground.set_shader_parameter("player_pos", Vector3(_path_cx(6.0), 0.0, 6.0))

	var ground_mesh := MeshInstance3D.new()
	ground_mesh.name = "GroundFloorMesh"
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 90.0)
	ground_mesh.mesh = plane
	ground_mesh.position = Vector3(0.0, 0.0, -14.0)
	ground_mesh.set_surface_override_material(0, mat_ground)
	root.add_child(ground_mesh)
	_own(ground_mesh, root)

	# ─── 3. Multi-Layer 2.5D Painted Diorama Cliffs ───
	var wings_root := Node3D.new()
	wings_root.name = "DioramaWings"
	root.add_child(wings_root)
	_own(wings_root, root)

	var z_slices: Array[float] = [11.5, 8.5, 5.5, 2.5, -0.5, -3.5, -6.5, -9.5, -12.5]
	var x_jitters: Array[float] = [0.0, -0.14, 0.16, -0.12, 0.14, -0.08, 0.12, 0.05, -0.10]
	for i in range(z_slices.size()):
		var z: float = z_slices[i]
		var cx: float = _path_cx(z)
		var jx: float = x_jitters[i]
		var depth_t: float = float(i) / float(z_slices.size() - 1)
		var warm_tint := Color(1.0 + depth_t * 0.04, 0.98 + depth_t * 0.03, 0.95 + depth_t * 0.02)
		var haze: float = 0.14 + depth_t * 0.18
		var exit_flare: float = maxf(0.0, (-z - 6.0) * 0.10)

		_add_wing(
			wings_root, root,
			"LeftWing_%d" % i,
			"res://assets/textures/diorama_wings/wing_left_main.png",
			Vector3(cx - 4.85 - exit_flare + jx, 4.35, z),
			Vector3(-12.0, 16.0, 0.0),
			Vector2(9.2, 8.8),
			warm_tint,
			haze
		)
		_add_wing(
			wings_root, root,
			"RightWing_%d" % i,
			"res://assets/textures/diorama_wings/wing_right_main.png",
			Vector3(cx + 4.95 + exit_flare - jx * 0.8, 4.35, z),
			Vector3(-12.0, -16.0, 0.0),
			Vector2(9.2, 8.8),
			Color(warm_tint.r * 0.96, warm_tint.g * 0.96, warm_tint.b * 0.97),
			haze
		)

	# Canyon exit gateway wings framing centered sunlit battlefield opening
	var gate_cx: float = _path_cx(-15.5)
	_add_wing(
		wings_root, root,
		"GatewayWingLeft",
		"res://assets/textures/diorama_wings/wing_gate_left.png",
		Vector3(gate_cx - 5.85, 4.35, -15.5),
		Vector3(-11.0, 10.0, 0.0),
		Vector2(9.6, 9.2),
		Color(1.04, 0.99, 0.94),
		0.24
	)
	_add_wing(
		wings_root, root,
		"GatewayWingRight",
		"res://assets/textures/diorama_wings/wing_gate_right.png",
		Vector3(gate_cx + 6.05, 4.35, -15.5),
		Vector3(-11.0, -10.0, 0.0),
		Vector2(9.6, 9.2),
		Color(1.04, 0.99, 0.94),
		0.24
	)

	# ─── 3b. Small Test D: Real 3D Blender Roadside Terraces, Boulders & Curbs ───
	var kit_root_node: Node3D = Node3D.new()
	kit_root_node.name = "Roadside3DKits"
	root.add_child(kit_root_node)
	_own(kit_root_node, root)

	var mat_rock := ShaderMaterial.new()
	mat_rock.shader = load("res://assets/shaders/hd2d_octopath_rock.gdshader")
	mat_rock.set_shader_parameter("sandstone_tex", load("res://assets/textures/canyon_pbr/d_sandstone_strata_albedo.png"))
	mat_rock.set_shader_parameter("sandstone_norm", load("res://assets/textures/canyon_pbr/d_sandstone_strata_normal.png"))
	mat_rock.set_shader_parameter("basalt_tex", load("res://assets/textures/canyon_pbr/d_basalt_cap_albedo.png"))
	mat_rock.set_shader_parameter("basalt_norm", load("res://assets/textures/canyon_pbr/d_basalt_cap_normal.png"))
	mat_rock.set_shader_parameter("boulder_tex", load("res://assets/textures/canyon_pbr/d_boulder_rock_albedo.png"))
	mat_rock.set_shader_parameter("boulder_norm", load("res://assets/textures/canyon_pbr/d_boulder_rock_normal.png"))
	mat_rock.set_shader_parameter("haze_color", Color(0.95, 0.78, 0.52))
	mat_rock.set_shader_parameter("haze_strength", 0.24)

	var kit_scene := load("res://assets/models/canyon_kit_test_d.glb") as PackedScene
	var kit_inst := kit_scene.instantiate()
	var m_left_a := _find_mesh_recursive(kit_inst, "TerraceLeftModule")
	var m_left_b := _find_mesh_recursive(kit_inst, "TerraceLeftModuleB")
	var m_right_a := _find_mesh_recursive(kit_inst, "TerraceRightModule")
	var m_right_b := _find_mesh_recursive(kit_inst, "TerraceRightModuleB")
	var m_boulder := _find_mesh_recursive(kit_inst, "BoulderCluster")
	var m_curb := _find_mesh_recursive(kit_inst, "CurbStoneStrip")
	kit_inst.free()

	var kit_z_slices: Array[float] = [10.0, 3.8, -2.4, -8.6]
	for i in range(kit_z_slices.size()):
		var kz: float = kit_z_slices[i]
		var kcx: float = _path_cx(kz)
		var slope_dx: float = _path_cx(kz + 2.0) - _path_cx(kz - 2.0)
		var yaw_rad: float = -atan2(slope_dx, 4.0)

		var m_left: Mesh = m_left_a if (i % 2 == 0 or m_left_b == null) else m_left_b
		var m_right: Mesh = m_right_a if (i % 2 == 0 or m_right_b == null) else m_right_b

		# Left and right 3D chiseled polygonal basalt + red-sandstone terrace modules (A/B alternated)
		if m_left:
			var tl := MeshInstance3D.new()
			tl.name = "TerraceLeft_%d" % i
			tl.mesh = m_left
			tl.position = Vector3(kcx - 1.58, 0.0, kz)
			tl.rotation = Vector3(0.0, yaw_rad, 0.0)
			tl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			tl.set_surface_override_material(0, mat_rock)
			kit_root_node.add_child(tl)
			_own(tl, root)

		if m_right:
			var tr := MeshInstance3D.new()
			tr.name = "TerraceRight_%d" % i
			tr.mesh = m_right
			tr.position = Vector3(kcx + 1.58, 0.0, kz)
			tr.rotation = Vector3(0.0, yaw_rad, 0.0)
			tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			tr.set_surface_override_material(0, mat_rock)
			kit_root_node.add_child(tr)
			_own(tr, root)

		# 3D Chiseled Flagstone Curbs along both path borders
		if m_curb:
			var cl := MeshInstance3D.new()
			cl.name = "CurbLeft_%d" % i
			cl.mesh = m_curb
			cl.position = Vector3(kcx - 1.24, 0.0, kz)
			cl.rotation = Vector3(0.0, yaw_rad, 0.0)
			cl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			cl.set_surface_override_material(0, mat_rock)
			kit_root_node.add_child(cl)
			_own(cl, root)

			var cr := MeshInstance3D.new()
			cr.name = "CurbRight_%d" % i
			cr.mesh = m_curb
			cr.position = Vector3(kcx + 1.24, 0.0, kz)
			cr.rotation = Vector3(0.0, yaw_rad + PI, 0.0)
			cr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			cr.set_surface_override_material(0, mat_rock)
			kit_root_node.add_child(cr)
			_own(cr, root)

		# Angular faceted golden-ochre Boulder Clusters tucked into cove notches (clear of cx +/- 1.45m)
		if m_boulder:
			var bl := MeshInstance3D.new()
			bl.name = "BoulderLeft_%d" % i
			bl.mesh = m_boulder
			var bl_z: float = kz + 1.15
			bl.position = Vector3(_path_cx(bl_z) - 2.08, 0.0, bl_z)
			bl.rotation = Vector3(0.0, 0.55 + i * 1.15, 0.0)
			bl.scale = Vector3.ONE * (0.90 + (i % 2) * 0.12)
			bl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			bl.set_surface_override_material(0, mat_rock)
			kit_root_node.add_child(bl)
			_own(bl, root)

			var br := MeshInstance3D.new()
			br.name = "BoulderRight_%d" % i
			br.mesh = m_boulder
			var br_z: float = kz - 0.85
			br.position = Vector3(_path_cx(br_z) + 2.08, 0.0, br_z)
			br.rotation = Vector3(0.0, 2.35 + i * 0.95, 0.0)
			br.scale = Vector3.ONE * (0.86 + ((i + 1) % 2) * 0.12)
			br.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			br.set_surface_override_material(0, mat_rock)
			kit_root_node.add_child(br)
			_own(br, root)

	# ─── 4. Clustered Crisp 2.5D Desert Sage Bushes Tucked in Coves & Tier 1/2 Shelves ───
	var props_root := Node3D.new()
	props_root.name = "DioramaProps"
	props_root.visible = true
	root.add_child(props_root)
	_own(props_root, root)

	var prop_defs: Array[Dictionary] = [
		{"name": "BushCoveL0", "tex": "res://assets/textures/canyon_pbr/hd2d_bush_cluster.png", "z": 9.8, "dx": -1.52, "y": 0.16, "ps": 0.0056, "flip": false},
		{"name": "BushCoveR0", "tex": "res://assets/textures/canyon_pbr/d_sage_bush_2.png", "z": 8.9, "dx": 1.48, "y": 0.22, "ps": 0.0042, "flip": true},
		{"name": "BushCoveL1", "tex": "res://assets/textures/canyon_pbr/d_sage_bush_2.png", "z": 7.4, "dx": -1.48, "y": 0.22, "ps": 0.0040, "flip": false},
		{"name": "BushCoveR1", "tex": "res://assets/textures/canyon_pbr/hd2d_bush_cluster.png", "z": 6.2, "dx": 1.54, "y": 0.17, "ps": 0.0054, "flip": false},
		{"name": "BushLedgeL0", "tex": "res://assets/textures/canyon_pbr/hd2d_bush_cluster.png", "z": 5.5, "dx": -2.18, "y": 0.56, "ps": 0.0050, "flip": true},
		{"name": "BushLedgeR0", "tex": "res://assets/textures/canyon_pbr/d_sage_bush_2.png", "z": 4.3, "dx": 2.15, "y": 0.58, "ps": 0.0038, "flip": false},
		{"name": "BushCoveL2", "tex": "res://assets/textures/canyon_pbr/hd2d_bush_cluster.png", "z": 2.5, "dx": -1.50, "y": 0.16, "ps": 0.0056, "flip": true},
		{"name": "BushCoveR2", "tex": "res://assets/textures/canyon_pbr/d_sage_bush_2.png", "z": 1.2, "dx": 1.50, "y": 0.22, "ps": 0.0042, "flip": true},
		{"name": "BushLedgeL1", "tex": "res://assets/textures/canyon_pbr/d_sage_bush_2.png", "z": -0.3, "dx": -2.25, "y": 0.60, "ps": 0.0040, "flip": false},
		{"name": "BushCoveR3", "tex": "res://assets/textures/canyon_pbr/hd2d_bush_cluster.png", "z": -1.8, "dx": 1.50, "y": 0.17, "ps": 0.0054, "flip": false},
		{"name": "BushCoveL3", "tex": "res://assets/textures/canyon_pbr/hd2d_bush_cluster.png", "z": -3.9, "dx": -1.50, "y": 0.16, "ps": 0.0056, "flip": false},
		{"name": "BushLedgeR1", "tex": "res://assets/textures/canyon_pbr/hd2d_bush_cluster.png", "z": -4.6, "dx": 2.18, "y": 0.56, "ps": 0.0050, "flip": true},
		{"name": "BushCoveR4", "tex": "res://assets/textures/canyon_pbr/d_sage_bush_2.png", "z": -6.3, "dx": 1.52, "y": 0.22, "ps": 0.0042, "flip": true},
		{"name": "BushCoveL4", "tex": "res://assets/textures/canyon_pbr/d_sage_bush_2.png", "z": -8.1, "dx": -1.50, "y": 0.22, "ps": 0.0040, "flip": true},
		{"name": "BushCoveR5", "tex": "res://assets/textures/canyon_pbr/hd2d_bush_cluster.png", "z": -9.8, "dx": 1.52, "y": 0.16, "ps": 0.0054, "flip": false},
	]
	for pd in prop_defs:
		var pz: float = pd["z"]
		var px: float = _path_cx(pz) + float(pd["dx"])
		var shaded_tint := Color(0.98, 0.94, 0.88) if float(pd["dx"]) < 0.0 else Color(0.84, 0.78, 0.72)
		_add_prop_sprite(
			props_root, root,
			pd["name"],
			pd["tex"],
			Vector3(px, float(pd["y"]), pz),
			float(pd["ps"]),
			Vector3(-18.0, 0.0, 0.0),
			bool(pd["flip"]),
			shaded_tint
		)

	# ─── 5. Sunlit Desert Exit Crater & Distant Mountain Horizon Vista ───
	# Feather-masked Orichalcum crater flat on 3D desert floor directly ahead of canyon mouth
	var crater := MeshInstance3D.new()
	crater.name = "OrichalcumCraterGround"
	var crater_quad := QuadMesh.new()
	crater_quad.size = Vector2(7.6, 5.0)
	crater.mesh = crater_quad
	crater.position = Vector3(0.25, 0.03, -22.2)
	crater.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var mat_crater := StandardMaterial3D.new()
	mat_crater.albedo_texture = load("res://assets/textures/canyon_pbr/orichalcum_crater.png")
	mat_crater.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_crater.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_crater.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	crater.set_surface_override_material(0, mat_crater)
	root.add_child(crater)
	_own(crater, root)

	var crater_glow := OmniLight3D.new()
	crater_glow.name = "CraterOrichalcumGlow"
	crater_glow.position = Vector3(0.25, 0.65, -22.2)
	crater_glow.light_color = Color(1.0, 0.74, 0.26)
	crater_glow.light_energy = 1.15
	crater_glow.omni_range = 4.5
	root.add_child(crater_glow)
	_own(crater_glow, root)

	# Distant Battlefield Mountains & Sky Vista aligned with Y = 0.0 horizon (y=42.5% of image)
	var vista := MeshInstance3D.new()
	vista.name = "BattlefieldVistaBackdrop"
	var vista_quad := QuadMesh.new()
	vista_quad.size = Vector2(72.0, 34.0)
	vista.mesh = vista_quad
	# Centered at Y = -2.4 so image horizon (y=42.5%, +0.075 * 34m = +2.55m above quad center) aligns at Y ≈ 0.15m
	vista.position = Vector3(0.0, -2.4, -52.0)
	vista.rotation_degrees = Vector3(-13.0, 0.0, 0.0)
	var mat_vista := StandardMaterial3D.new()
	mat_vista.albedo_texture = load("res://assets/textures/canyon_pbr/canyon_vista_seamless.png")
	mat_vista.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_vista.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	vista.set_surface_override_material(0, mat_vista)
	root.add_child(vista)
	_own(vista, root)

	# ─── 6. Blue Commander (CharacterBody3D on Cobblestones) ───
	var commander := CharacterBody3D.new()
	commander.name = "BlueCommander"
	commander.position = Vector3(_path_cx(6.0), 0.02, 6.0)
	commander.set_script(load("res://scripts/blue_commander_3d_player.gd"))

	var col_shape := CollisionShape3D.new()
	col_shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.2
	col_shape.shape = capsule
	col_shape.position = Vector3(0.0, 0.6, 0.0)
	commander.add_child(col_shape)

	var hero_sprite := Sprite3D.new()
	hero_sprite.name = "CommanderSprite"
	hero_sprite.texture = load("res://assets/textures/units/blue_commander_rpg.png")
	hero_sprite.pixel_size = 0.00118
	hero_sprite.position = Vector3(0.0, 0.64, 0.0)
	hero_sprite.shaded = false
	hero_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	hero_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	hero_sprite.alpha_scissor_threshold = 0.25
	hero_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hero_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hero_sprite.render_priority = 2
	commander.add_child(hero_sprite)

	var g_light := OmniLight3D.new()
	g_light.name = "GauntletGlow"
	g_light.position = Vector3(0.18, 0.68, 0.14)
	g_light.light_color = Color(0.28, 0.88, 1.0)
	g_light.light_energy = 0.35
	g_light.omni_range = 0.65
	commander.add_child(g_light)

	root.add_child(commander)
	_own(commander, root)
	_own(col_shape, root)
	_own(hero_sprite, root)
	_own(g_light, root)

	# ─── 7. Telephoto 3/4 Diorama Follow Camera ───
	var cam := Camera3D.new()
	cam.name = "CameraRig"
	cam.fov = 30.0
	cam.near = 0.2
	cam.far = 250.0
	cam.current = true
	cam.position = Vector3(_path_cx(6.0) * 0.35, 3.8, 18.6)
	cam.rotation_degrees = Vector3(-13.0, 0.0, 0.0)
	cam.set_script(load("res://scripts/rpg_camera_3d_follow.gd"))
	root.add_child(cam)
	_own(cam, root)

	# ─── 8. Atmosphere & Post-Processing Layers (God Rays + Dust Motes + Tilt-Shift DOF) ───
	var atmo_layer := CanvasLayer.new()
	atmo_layer.name = "AtmosphereLayer"
	atmo_layer.layer = 1
	root.add_child(atmo_layer)
	_own(atmo_layer, root)

	var god_rays := ColorRect.new()
	god_rays.name = "GodRaysOverlay"
	god_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	god_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat_rays := ShaderMaterial.new()
	mat_rays.shader = load("res://assets/shaders/god_rays.gdshader")
	mat_rays.set_shader_parameter("angle", -0.46)
	mat_rays.set_shader_parameter("ray_density", 11.0)
	mat_rays.set_shader_parameter("ray_speed", 0.35)
	mat_rays.set_shader_parameter("ray_intensity", 0.22)
	mat_rays.set_shader_parameter("ray_color", Color(1.0, 0.90, 0.64, 1.0))
	god_rays.material = mat_rays
	atmo_layer.add_child(god_rays)
	_own(god_rays, root)

	var dust := CPUParticles2D.new()
	dust.name = "DustMotes"
	dust.position = Vector2(688.0, 384.0)
	dust.amount = 36
	dust.lifetime = 5.5
	dust.preprocess = 3.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(688.0, 384.0)
	dust.gravity = Vector2(-12.0, -8.0)
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 18.0
	dust.scale_amount_min = 1.6
	dust.scale_amount_max = 3.4
	dust.color = Color(1.0, 0.92, 0.72, 0.42)
	atmo_layer.add_child(dust)
	_own(dust, root)

	var post_layer := CanvasLayer.new()
	post_layer.name = "PostProcessing"
	post_layer.layer = 2
	root.add_child(post_layer)
	_own(post_layer, root)

	var tilt_shift := ColorRect.new()
	tilt_shift.name = "TiltShiftDof"
	tilt_shift.set_anchors_preset(Control.PRESET_FULL_RECT)
	tilt_shift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat_tilt := ShaderMaterial.new()
	mat_tilt.shader = load("res://assets/shaders/tilt_shift_hd2d.gdshader")
	mat_tilt.set_shader_parameter("focal_position_y", 0.60)
	mat_tilt.set_shader_parameter("focal_width", 0.28)
	mat_tilt.set_shader_parameter("blur_amount", 1.25)
	mat_tilt.set_shader_parameter("vignette_strength", 0.14)
	mat_tilt.set_shader_parameter("warm_tint", 0.10)
	tilt_shift.material = mat_tilt
	post_layer.add_child(tilt_shift)
	_own(tilt_shift, root)

	# ─── 9. Pack & Save Scene ───
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Failed to pack DesertCanyonDiorama scene: %d" % err)
		return
	var save_err := ResourceSaver.save(packed, "res://scenes/maps/desert_canyon_true_3d.tscn")
	if save_err != OK:
		push_error("Failed to save desert_canyon_true_3d.tscn: %d" % save_err)
		return
	print("Successfully assembled Multi-Layer 2.5D Painted Diorama -> res://scenes/maps/desert_canyon_true_3d.tscn")
	root.free()
