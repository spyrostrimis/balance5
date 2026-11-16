@tool
extends SceneTree

const REF_POS: Vector3 = Vector3(0.0, 2.4, 10.0)
const REF_PITCH_DEG: float = -11.5
const REF_FOV: float = 40.0
const ASPECT: float = 1376.0 / 768.0

func get_path_center_x(z: float) -> float:
	return -0.22 * sin((z - 6.0) * 0.32) - 0.10

func smin(a: float, b: float, k: float = 0.6) -> float:
	var h: float = max(k - abs(a - b), 0.0) / k
	return min(a, b) - h * h * k * 0.25

func build_projected_canyon_mesh() -> ArrayMesh:
	var nx: int = 240
	var ny: int = 136
	var ref_pitch: float = deg_to_rad(REF_PITCH_DEG)
	var cos_p: float = cos(ref_pitch)
	var sin_p: float = sin(ref_pitch)
	var tan_half: float = tan(deg_to_rad(REF_FOV * 0.5))

	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	verts.resize(nx * ny)
	uvs.resize(nx * ny)

	for j in range(ny):
		var v: float = float(j) / float(ny - 1)
		var ny_ndc: float = 1.0 - 2.0 * v
		for i in range(nx):
			var u: float = float(i) / float(nx - 1)
			var nx_ndc: float = 2.0 * u - 1.0

			var d_cam = Vector3(nx_ndc * ASPECT * tan_half, ny_ndc * tan_half, -1.0)
			var d = Vector3(
				d_cam.x,
				d_cam.y * cos_p - d_cam.z * sin_p,
				d_cam.y * sin_p + d_cam.z * cos_p
			).normalized()

			# 1. Ground Floor Plane (Y = 0.0)
			var t_floor: float = -REF_POS.y / d.y if d.y < -0.005 else 100.0

			# 2. Smooth Canyon Wall Depth Distribution across u
			# Central corridor (|u - 0.483| <= 0.05) stays at t_wall = 24.2m (Z = -14.0m)
			# Outside central corridor, t_wall smoothly transitions to t_edge = lerp(9.5, 5.0, v) at screen edges
			var r_eff: float = clamp((abs(u - 0.483) - 0.05) / 0.467, 0.0, 1.0)
			var t_edge: float = lerp(9.5, 5.0, v)
			var t_wall: float = lerp(24.2, t_edge, pow(r_eff, 0.80))

			# Smooth minimum transition from flat floor (Y=0) into cliff walls (k = 0.8)
			var t: float = smin(t_floor, t_wall, 0.8)
			t = clamp(t, 4.2, 25.0)

			var idx: int = j * nx + i
			verts[idx] = REF_POS + t * d
			uvs[idx] = Vector2(u, v)

	indices.resize((nx - 1) * (ny - 1) * 6)
	var k_idx: int = 0
	for j in range(ny - 1):
		for i in range(nx - 1):
			var idx00: int = j * nx + i
			var idx10: int = idx00 + 1
			var idx01: int = (j + 1) * nx + i
			var idx11: int = idx01 + 1

			indices[k_idx] = idx00
			indices[k_idx + 1] = idx10
			indices[k_idx + 2] = idx01
			indices[k_idx + 3] = idx10
			indices[k_idx + 4] = idx11
			indices[k_idx + 5] = idx01
			k_idx += 6

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arr_mesh

func _init():
	print("Assembling Frustum-Unprojected HD-2D Canyon Scene...")
	var root = Node3D.new()
	root.name = "DesertCanyonTrue3D"

	# ─── 1. Load Textures & Shaders ───
	var tex_projected = load("res://assets/textures/maps/desert_canyon_projected_albedo.png")
	var tex_detail = load("res://assets/textures/canyon_pbr/canyon_path_albedo.png")
	var tex_rock_detail = load("res://assets/textures/canyon_pbr/sandstone_rock_albedo.png")
	var char_tex = load("res://assets/textures/units/blue_commander_rpg.png")

	var shader_proj = load("res://assets/shaders/canyon_projected.gdshader")
	var shader_god_rays = load("res://assets/shaders/god_rays.gdshader")
	var shader_tilt_shift = load("res://assets/shaders/tilt_shift_hd2d.gdshader")

	var script_player = load("res://scripts/blue_commander_3d_player.gd")
	var script_camera = load("res://scripts/rpg_camera_3d_follow.gd")

	# ─── 2. Frustum-Unprojected 3D Canyon Mesh ───
	var mat_canyon = ShaderMaterial.new()
	mat_canyon.shader = shader_proj
	mat_canyon.set_shader_parameter("albedo_tex", tex_projected)
	mat_canyon.set_shader_parameter("detail_path_tex", tex_detail)
	mat_canyon.set_shader_parameter("detail_rock_tex", tex_rock_detail)
	mat_canyon.set_shader_parameter("player_pos", Vector3(-0.30, 0.0, 2.0))

	var canyon_mesh_inst = MeshInstance3D.new()
	canyon_mesh_inst.name = "CanyonProjectedMesh"
	canyon_mesh_inst.mesh = build_projected_canyon_mesh()
	canyon_mesh_inst.material_override = mat_canyon
	root.add_child(canyon_mesh_inst)
	canyon_mesh_inst.owner = root

	# ─── 3. Physical Floor Collision (keeps player strictly grounded at Y=0.0) ───
	var ground_body = StaticBody3D.new()
	ground_body.name = "GroundBaseCollision"
	root.add_child(ground_body)
	ground_body.owner = root

	var floor_col = CollisionShape3D.new()
	floor_col.name = "FloorCol"
	var box_floor = BoxShape3D.new()
	box_floor.size = Vector3(40.0, 1.0, 50.0)
	floor_col.shape = box_floor
	floor_col.position = Vector3(0.0, -0.5, -5.0)
	ground_body.add_child(floor_col)
	floor_col.owner = root

	# ─── 4. Blue Commander (CharacterBody3D) ───
	var player = CharacterBody3D.new()
	player.name = "BlueCommander"
	player.set_script(script_player)
	player.position = Vector3(-0.30, 0.0, 2.0)
	player.set("canyon_mesh_path", NodePath("../CanyonProjectedMesh"))
	root.add_child(player)
	player.owner = root

	var col_shape = CollisionShape3D.new()
	col_shape.name = "PlayerCollision"
	var cap = CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.2
	col_shape.shape = cap
	col_shape.position = Vector3(0.0, 0.6, 0.0)
	player.add_child(col_shape)
	col_shape.owner = root

	var commander_sprite = Sprite3D.new()
	commander_sprite.name = "CommanderSprite"
	commander_sprite.texture = char_tex
	commander_sprite.pixel_size = 0.00105
	commander_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	commander_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
	commander_sprite.shaded = false
	commander_sprite.position = Vector3(0.0, 0.59, 0.0)
	player.add_child(commander_sprite)
	commander_sprite.owner = root

	var gauntlet_light = OmniLight3D.new()
	gauntlet_light.name = "GauntletGlow"
	gauntlet_light.light_color = Color(0.15, 0.95, 0.85)
	gauntlet_light.light_energy = 0.7
	gauntlet_light.omni_range = 1.0
	gauntlet_light.position = Vector3(0.18, 0.60, 0.04)
	player.add_child(gauntlet_light)
	gauntlet_light.owner = root

	# ─── 5. Reference / Dolly Camera3D ───
	var cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.set_script(script_camera)
	cam.position = REF_POS
	cam.rotation_degrees = Vector3(REF_PITCH_DEG, 0.0, 0.0)
	cam.current = true
	cam.fov = REF_FOV
	cam.near = 0.2
	cam.far = 100.0
	cam.set("target_path", NodePath("../BlueCommander"))
	cam.set("post_processing_path", NodePath("../PostProcessing/TiltShiftDof"))
	root.add_child(cam)
	cam.owner = root

	# ─── 6. Neutral Environment (Linear tonemapping preserves exact painted HD-2D colors) ───
	var env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.92, 0.85, 0.74)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = env
	root.add_child(env_node)
	env_node.owner = root

	# ─── 7. Atmospheric God Rays & Dust Motes (Layer 1) ───
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
	mat_rays.set_shader_parameter("ray_intensity", 0.20)
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

	# ─── 8. Tilt-Shift Post Processing (Layer 2) ───
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
	mat_tilt.set_shader_parameter("focal_position_y", 0.58)
	mat_tilt.set_shader_parameter("focal_width", 0.22)
	mat_tilt.set_shader_parameter("blur_amount", 2.6)
	mat_tilt.set_shader_parameter("vignette_strength", 0.20)
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
		print("SUCCESS: Frustum-Unprojected Canyon Scene saved to: ", path)
	else:
		printerr("ERROR packing scene: ", err)

	quit(0)
