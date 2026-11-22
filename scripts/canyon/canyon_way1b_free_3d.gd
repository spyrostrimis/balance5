extends "res://scripts/canyon/canyon_level.gd"
## 3D Canyon · Way 1B Free 3D Modules (scenes/maps/canyon_way1b_free_3d.tscn)
##
## Assembles a short, polished 3D canyon bend exclusively from curated free 3D photogrammetry and
## kit modules while preserving:
##   - the existing BlueCommander (scenes/actors/blue_commander_3d.tscn),
##   - the two large layered Trellis boulders from "ChatGPT AI Boulders", and
##   - the pale, photo-textured Grand Canyon rock from "Free packs in the canyon".
##
## Free 3D modules by canyon role:
##   1. 3D cobblestone path: Namaqualand Stones 01 (5 distinct stone shapes) + Moon Rock 04 (broad worn crown)
##   2. Curb blocks:         Rock 07 (long sides, chipped corner) + Namaqualand Boulder 03 (flat-topped broken end block) + Boulder 05
##   3. Cliffs left & right: Namaqualand Cliff 02 (projecting bend nose) + Rock Face 01 (horizontal shelves)
##                           + Namaqualand Cliff 01 + Rock Face 02 + Namaqualand Boulder 02 / 03 lower ledges
##   4. Plants & verge:      Cheiridopsis Succulent (6 3D plant clusters) + Sand Rocks Small 01 + Namaqualand Rocks 01
##   5. Exit view:           Canyon River Terrain (distant gorge) + Mountain Desert 009 (natural sandstone arch) + Plateau Desert 002
##
## Interactive keys:
##   G  Toggle harmonized warm canyon palette grading vs raw native scan colours
##   R  Toggle 3D scanned cobblestone meshes on/off
##   K  Toggle 3D scanned curb blocks on/off
##   B  Toggle 3D succulent plants & verge rocks on/off
##   W  Toggle 3D scanned cliffs on/off
##   V  Toggle 3D exit vista (arch & river gorge) on/off

const SCAN_SHADER := preload("res://assets/shaders/way1b_scan_rock.gdshader")
const SUCCULENT_SHADER := preload("res://assets/shaders/way1b_succulent.gdshader")
const ROCK_MATERIAL := preload("res://assets/materials/canyon_rock.tres")
const STRATA_ALB := preload("res://assets/textures/canyon_pbr/d_sandstone_strata_albedo.png")
const STRATA_NRM := preload("res://assets/textures/canyon_pbr/d_sandstone_strata_normal.png")

const MODEL_DIR := "res://assets/models/way1b_free_3d/"
const TEX_DIR := "res://assets/textures/way1b_free_3d/"
const GRAND_CANYON_SCAN := "res://assets/models/way1b_free_3d/grand_canyon_rock.glb"
const CRAFTPIX_MESA := "res://assets/models/packs/craftpix_desert/Plateau_desert_002.glb"

var _cliffs_root: Node3D
var _curbs_root: Node3D
var _cobbles_root: Node3D
var _verge_root: Node3D
var _vista_root: Node3D
var _anchors_root: Node3D

var _graded_materials: Array[ShaderMaterial] = []
var _default_grades: Array[float] = []
var _harmonized := true
var _shadow_disc_mat: ShaderMaterial


func _ready() -> void:
	super()
	var route := get_node(route_path)
	var ground := get_node(ground_path) as MeshInstance3D
	var gmat := ground.get_surface_override_material(0) as ShaderMaterial
	if gmat:
		gmat.set_shader_parameter("painted_right_shadow_strength", 0.12)

	_init_shadow_disc_material()
	_build_kept_anchors(route)
	var boulder_2d := _kept_boulder_footprints(route)

	_cliffs_root = Node3D.new()
	_cliffs_root.name = "Way1BCliffs"
	add_child(_cliffs_root)
	_build_cliffs(route)

	_curbs_root = Node3D.new()
	_curbs_root.name = "Way1BCurbs"
	add_child(_curbs_root)
	_build_curbs(route, boulder_2d)

	_cobbles_root = Node3D.new()
	_cobbles_root.name = "Way1BCobbles"
	add_child(_cobbles_root)
	_build_3d_cobble_path(route, boulder_2d)

	_verge_root = Node3D.new()
	_verge_root.name = "Way1BVerge"
	add_child(_verge_root)
	_build_plants_and_verge(route, boulder_2d)

	_vista_root = Node3D.new()
	_vista_root.name = "Way1BVista"
	add_child(_vista_root)
	_build_exit_vista(route)

	if OS.get_environment("WAY1B_RAW_COLORS") == "1":
		_set_harmonized(false)
	if OS.get_environment("WAY1B_COBBLES") == "0":
		_cobbles_root.visible = false


func _process(_delta: float) -> void:
	var commander := get_node_or_null(commander_path) as Node3D
	var ground := get_node_or_null(ground_path) as MeshInstance3D
	if commander and ground:
		var gmat := ground.get_surface_override_material(0) as ShaderMaterial
		if gmat:
			gmat.set_shader_parameter("player_pos", commander.global_position)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_G:
		_set_harmonized(not _harmonized)
		get_viewport().set_input_as_handled()
	elif key == KEY_R:
		_cobbles_root.visible = not _cobbles_root.visible
		get_viewport().set_input_as_handled()
	elif key == KEY_K:
		_curbs_root.visible = not _curbs_root.visible
		get_viewport().set_input_as_handled()
	elif key == KEY_B:
		_verge_root.visible = not _verge_root.visible
		get_viewport().set_input_as_handled()
	elif key == KEY_W:
		_cliffs_root.visible = not _cliffs_root.visible
		get_viewport().set_input_as_handled()
	elif key == KEY_V:
		_vista_root.visible = not _vista_root.visible
		get_viewport().set_input_as_handled()


func _set_harmonized(on: bool) -> void:
	_harmonized = on
	for i in _graded_materials.size():
		_graded_materials[i].set_shader_parameter("grade_strength", _default_grades[i] if on else 0.0)


func _make_scan_material(prefix: String, shadow: Color, mid: Color, crown: Color, grade: float = 0.68,
		detail_blend: float = 0.18, basal_h: float = 0.45, basal_str: float = 0.42, haze: float = 0.12,
		luma_flr: float = 0.0, luma_con: float = 1.0, crown_boost: float = 0.28, cav_str: float = 0.65) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SCAN_SHADER
	var alb_path := TEX_DIR + prefix + "_albedo.jpg"
	if ResourceLoader.exists(alb_path):
		mat.set_shader_parameter("albedo_tex", load(alb_path))
	var nrm_path := TEX_DIR + prefix + "_normal.png"
	if ResourceLoader.exists(nrm_path):
		mat.set_shader_parameter("normal_tex", load(nrm_path))
	var orm_path := TEX_DIR + prefix + "_orm.png"
	if ResourceLoader.exists(orm_path):
		mat.set_shader_parameter("orm_tex", load(orm_path))
	mat.set_shader_parameter("detail_strata_tex", STRATA_ALB)
	mat.set_shader_parameter("detail_strata_norm", STRATA_NRM)
	mat.set_shader_parameter("detail_blend", detail_blend)
	mat.set_shader_parameter("grade_strength", grade)
	mat.set_shader_parameter("luma_floor", luma_flr)
	mat.set_shader_parameter("luma_contrast", luma_con)
	mat.set_shader_parameter("top_crown_boost", crown_boost)
	mat.set_shader_parameter("cavity_strength", cav_str)
	mat.set_shader_parameter("shadow_tint", shadow)
	mat.set_shader_parameter("mid_tint", mid)
	mat.set_shader_parameter("crown_tint", crown)
	mat.set_shader_parameter("basal_ao_height", basal_h)
	mat.set_shader_parameter("basal_ao_strength", basal_str)
	mat.set_shader_parameter("haze_strength", haze)
	_graded_materials.append(mat)
	_default_grades.append(grade)
	return mat


func _make_succulent_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SUCCULENT_SHADER
	mat.set_shader_parameter("albedo_tex", load(TEX_DIR + "cheiridopsis_succulent_albedo.png"))
	mat.set_shader_parameter("normal_tex", load(TEX_DIR + "cheiridopsis_succulent_normal.png"))
	mat.set_shader_parameter("orm_tex", load(TEX_DIR + "cheiridopsis_succulent_orm.png"))
	mat.set_shader_parameter("grade_strength", 0.76)
	_graded_materials.append(mat)
	_default_grades.append(0.76)
	return mat


func _init_shadow_disc_material() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float a = pow(clamp(1.0 - r, 0.0, 1.0), 2.2) * 0.42;
	ALBEDO = vec3(0.10, 0.06, 0.04);
	ALPHA = a;
}
"""
	_shadow_disc_mat = ShaderMaterial.new()
	_shadow_disc_mat.shader = sh


func _extract_meshes(glb_name: String) -> Dictionary:
	var out := {}
	var scene := load(MODEL_DIR + glb_name) as PackedScene
	if scene == null:
		return out
	var root := scene.instantiate()
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		out[String(m.name)] = m.mesh
	root.free()
	return out


func _build_kept_anchors(route: Node) -> void:
	_anchors_root = Node3D.new()
	_anchors_root.name = "KeptAnchors"
	add_child(_anchors_root)
	# Pale photo-textured Grand Canyon rock from "Free packs in the canyon"
	if ResourceLoader.exists(GRAND_CANYON_SCAN):
		var scan := (load(GRAND_CANYON_SCAN) as PackedScene).instantiate() as Node3D
		scan.name = "GrandCanyonWhiteRock"
		var z := 2.4
		scan.position = Vector3(route.center_x(z) + 1.35, 0.0, z)
		scan.rotation_degrees.y = -40.0
		scan.scale = Vector3.ONE * 0.5
		_anchors_root.add_child(scan)


func _kept_boulder_footprints(route: Node) -> Array[Vector3]:
	return [
		Vector3(route.center_x(4.85) - 1.8192, 4.85, 0.96),
		Vector3(route.center_x(4.65) + 1.4951, 4.65, 0.92),
		Vector3(route.center_x(2.40) + 1.3500, 2.40, 0.85),
	]


func _is_near_boulder(wx: float, wz: float, footprints: Array[Vector3], extra: float = 0.0) -> bool:
	var p := Vector2(wx, wz)
	for b in footprints:
		if p.distance_to(Vector2(b.x, b.y)) < (b.z + extra):
			return true
	return false


# ---------------------------------------------------------------------------
# ROLE 3: CLIFFS LEFT & RIGHT (Namaqualand Cliff 02, Rock Face 01, Cliff 01, Rock Face 02, Lower Stepped Ledges)
# ---------------------------------------------------------------------------
func _build_cliffs(route: Node) -> void:
	var m_cliff02 := _extract_meshes("namaqualand_cliff_02.glb").get("namaqualand_cliff_02") as Mesh
	var m_cliff01 := _extract_meshes("namaqualand_cliff_01.glb").get("namaqualand_cliff_01") as Mesh
	var m_rf01 := _extract_meshes("rock_face_01.glb").get("rock_face_01") as Mesh
	var m_rf02 := _extract_meshes("rock_face_02.glb").get("rock_face_02") as Mesh
	var m_bld02 := _extract_meshes("namaqualand_boulder_02.glb").get("namaqualand_boulder_02") as Mesh
	var m_bld03 := _extract_meshes("namaqualand_boulder_03.glb").get("namaqualand_boulder_03") as Mesh

	# Upper cliffs: rich warm terracotta-sandstone crowns with deep cool umber-violet crevices
	var upper_shadow := Color(0.22, 0.13, 0.14)
	var upper_mid := Color(0.73, 0.44, 0.28)
	var upper_crown := Color(0.97, 0.74, 0.50)

	var mat_cliff02 := _make_scan_material("namaqualand_cliff_02", upper_shadow, upper_mid, upper_crown, 0.64, 0.24, 0.65, 0.42)
	var mat_cliff01 := _make_scan_material("namaqualand_cliff_01", upper_shadow, upper_mid, upper_crown, 0.62, 0.20, 0.55, 0.42)
	var mat_rf01 := _make_scan_material("rock_face_01", upper_shadow, Color(0.70, 0.42, 0.27), upper_crown, 0.74, 0.22, 0.55, 0.42)
	var mat_rf02 := _make_scan_material("rock_face_02", upper_shadow, Color(0.68, 0.40, 0.26), upper_crown, 0.74, 0.22, 0.55, 0.42)

	# Lower stepped retaining tier: darker weathered slate-sandstone (watertight 3D boulders, zero open top edges)
	var low_shadow := Color(0.14, 0.10, 0.11)
	var low_mid := Color(0.42, 0.32, 0.26)
	var low_crown := Color(0.68, 0.55, 0.43)
	var mat_bld02 := _make_scan_material("namaqualand_boulder_02", low_shadow, low_mid, low_crown, 0.70, 0.14, 0.28, 0.40)
	var mat_bld03 := _make_scan_material("namaqualand_boulder_03", low_shadow, Color(0.39, 0.30, 0.24), low_crown, 0.72, 0.14, 0.28, 0.40)

	# 1. Continuous lower stepped retaining ledges on both sides (two overlapping courses so no sand leaks behind)
	var z_step := 12.2
	var idx := 0
	while z_step > -14.2:
		var use_b03 := (idx % 3 == 1)
		var m_low := m_bld03 if use_b03 else m_bld02
		var mat_low := mat_bld03 if use_b03 else mat_bld02
		var sc_low := Vector3(0.85, 0.72, 0.95) if use_b03 else Vector3(0.95, 1.05, 1.05)
		_place_cliff_mesh(route, m_low, mat_low, -1.0, z_step, 2.75, -0.04, 2.0 if (idx % 2 == 0) else -2.0, sc_low)
		_place_cliff_mesh(route, m_low, mat_low, 1.0, z_step - 0.35, 2.72, -0.04, -2.0 if (idx % 2 == 0) else 2.0, sc_low)
		# Second higher/outer course of stepped blocks filling any undercut below the main cliff scans
		_place_cliff_mesh(route, m_bld03, mat_bld03, -1.0, z_step - 0.5, 3.85, 0.35, -4.0, Vector3(1.15, 1.15, 1.10))
		_place_cliff_mesh(route, m_bld03, mat_bld03, 1.0, z_step - 0.8, 3.65, 0.35, 4.0, Vector3(1.15, 1.15, 1.10))
		z_step -= 2.20
		idx += 1

	# 2. LEFT WALL (Outer curve, backlit by sun): Rock Face 01 horizontal shelves + Namaqualand Cliff 01/02
	var left_cliffs := [
		[m_cliff01, mat_cliff01, 11.8, 3.85, -0.25, 4.0, Vector3(0.95, 1.05, 1.05)],
		[m_rf01, mat_rf01, 5.2, 3.75, -0.25, -3.0, Vector3(0.95, 1.08, 1.05)],
		[m_cliff02, mat_cliff02, -1.5, 3.65, -0.35, -2.0, Vector3(0.95, 1.04, 1.02)],
		[m_rf01, mat_rf01, -7.2, 3.62, -0.25, -4.0, Vector3(0.95, 1.06, 1.05)],
		[m_cliff01, mat_cliff01, -12.6, 3.65, -0.25, 3.0, Vector3(0.92, 0.98, 0.98)],
		# Upper left bluff backdrop
		[m_cliff02, mat_cliff02, 2.0, 5.80, 1.65, 2.0, Vector3(0.95, 0.95, 1.10)],
	]
	for c in left_cliffs:
		_place_cliff_mesh(route, c[0], c[1], -1.0, c[2], c[3], c[4], c[5], c[6])

	# 3. RIGHT WALL (Inner bend): Namaqualand Cliff 02 with projecting nose + Rock Face 01 filling the spawn-right undercut
	var right_cliffs := [
		[m_cliff01, mat_cliff01, 11.8, 3.05, -0.25, -4.0, Vector3(0.95, 1.08, 1.05)],
		[m_rf01, mat_rf01, 6.4, 3.00, -0.35, 3.0, Vector3(0.98, 1.08, 1.08)],
		[m_cliff02, mat_cliff02, -0.2, 2.82, -0.38, 2.5, Vector3(0.94, 1.02, 1.04)],
		# Inner bend buttress nose at Z=-8.9 (occludes crater glint at Z=+6 spawn, clears by Z=-3.5 midway)
		[m_rf02, mat_rf02, -8.9, 2.15, -0.10, 12.0, Vector3(0.94, 1.10, 1.05)],
		[m_bld03, mat_cliff01, -9.1, 3.12, 1.15, -15.0, Vector3(1.05, 1.25, 1.05)],
		[m_rf01, mat_rf01, -13.8, 3.15, -0.20, 10.0, Vector3(0.90, 0.92, 0.95)],
		# Upper right tier
		[m_cliff01, mat_cliff01, 5.5, 4.75, 1.75, -3.0, Vector3(1.05, 1.08, 1.15)],
		[m_rf01, mat_rf01, -4.5, 4.95, 1.65, 4.0, Vector3(1.05, 1.05, 1.12)],
	]
	for c in right_cliffs:
		_place_cliff_mesh(route, c[0], c[1], 1.0, c[2], c[3], c[4], c[5], c[6])


func _place_cliff_mesh(route: Node, mesh: Mesh, mat: Material, side: float, z: float,
		lateral: float, y: float, yaw_deg: float, sc: Vector3) -> void:
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(route.center_x(z) + side * lateral, y, z)
	var base_yaw: float = route.heading(z) + (PI if side > 0.0 else 0.0)
	mi.rotation.y = base_yaw + deg_to_rad(yaw_deg)
	mi.scale = sc
	_cliffs_root.add_child(mi)


# ---------------------------------------------------------------------------
# ROLE 2: CURB BLOCKS (Rock 07 + Namaqualand Boulder 03 broken end blocks + Boulder 05)
# ---------------------------------------------------------------------------
func _build_curbs(route: Node, boulder_footprints: Array[Vector3]) -> void:
	var m_r07 := _extract_meshes("rock_07.glb").get("rock_07") as Mesh
	var m_b03 := _extract_meshes("namaqualand_boulder_03.glb").get("namaqualand_boulder_03") as Mesh
	var m_b05 := _extract_meshes("namaqualand_boulder_05.glb").get("namaqualand_boulder_05") as Mesh
	if m_r07 == null or m_b03 == null:
		return

	# Weathered warm sandstone-taupe curb palette (slightly darker than the pale cobbles for crisp border framing)
	var curb_shadow := Color(0.24, 0.17, 0.14)
	var curb_mid := Color(0.58, 0.46, 0.36)
	var curb_crown := Color(0.84, 0.71, 0.55)
	var mat_r07 := _make_scan_material("rock_07", curb_shadow, curb_mid, curb_crown, 0.62, 0.0, 0.06, 0.36, 0.12, 0.24, 0.65, 0.34)
	var mat_b03 := _make_scan_material("namaqualand_boulder_03", curb_shadow, Color(0.55, 0.43, 0.33), curb_crown, 0.62, 0.0, 0.07, 0.36, 0.12, 0.24, 0.65, 0.34)
	var mat_b05 := _make_scan_material("namaqualand_boulder_05", curb_shadow, curb_mid, curb_crown, 0.58, 0.0, 0.06, 0.36, 0.12, 0.24, 0.65, 0.34)

	var aabb_r07 := m_r07.get_aabb().size
	var aabb_b03 := m_b03.get_aabb().size
	var aabb_b05 := m_b05.get_aabb().size if m_b05 else Vector3.ONE

	var rng := RandomNumberGenerator.new()
	rng.seed = 4107

	for side: float in [-1.0, 1.0]:
		var z := 11.2
		var idx := 0
		while z > -13.6:
			var step := rng.randf_range(0.66, 0.72)
			var z_next := z - step
			var cx: float = route.center_x(z)
			var lat := 1.24 + rng.randf_range(-0.015, 0.02)
			var wx := cx + side * lat

			if _is_near_boulder(wx, z, boulder_footprints, 0.08):
				z = z_next
				idx += 1
				continue

			if rng.randf() < 0.04:
				z = z_next
				idx += 1
				continue

			var near_gap := _is_near_boulder(cx + side * lat, z - step, boulder_footprints, 0.10) or (idx % 7 == 5)
			var mi := MeshInstance3D.new()
			var yaw: float = route.heading(z) + deg_to_rad(rng.randf_range(-1.8, 1.8))
			if rng.randf() < 0.5:
				yaw += PI

			if near_gap:
				mi.mesh = m_b03
				mi.material_override = mat_b03
				var target := Vector3(rng.randf_range(0.36, 0.41), rng.randf_range(0.18, 0.21), rng.randf_range(0.60, 0.66))
				mi.scale = Vector3(target.x / aabb_b03.x, target.y / aabb_b03.y, target.z / aabb_b03.z)
			elif m_b05 and (idx % 5 == 2):
				mi.mesh = m_b05
				mi.material_override = mat_b05
				var target := Vector3(rng.randf_range(0.32, 0.36), rng.randf_range(0.16, 0.19), rng.randf_range(0.66, 0.72))
				mi.scale = Vector3(target.x / aabb_b05.x, target.y / aabb_b05.y, target.z / aabb_b05.z)
			else:
				mi.mesh = m_r07
				mi.material_override = mat_r07
				var target := Vector3(rng.randf_range(0.31, 0.35), rng.randf_range(0.15, 0.18), rng.randf_range(0.64, 0.70))
				mi.scale = Vector3(target.x / aabb_r07.x, target.y / aabb_r07.y, target.z / aabb_r07.z)

			var sink := rng.randf_range(-0.015, 0.003)
			mi.position = Vector3(wx, sink, z)
			mi.rotation = Vector3(deg_to_rad(rng.randf_range(-0.9, 0.9)), yaw, deg_to_rad(rng.randf_range(-1.1, 1.1)))
			_curbs_root.add_child(mi)

			z = z_next
			idx += 1


# ---------------------------------------------------------------------------
# ROLE 1: 3D COBBLESTONE PATH (Namaqualand Stones 01 a..e + Moon Rock 04 broad worn crown)
# ---------------------------------------------------------------------------
func _build_3d_cobble_path(route: Node, boulder_footprints: Array[Vector3]) -> void:
	var stones_dict := _extract_meshes("namaqualand_stones_01.glb")
	var m_moon := _extract_meshes("moon_rock_04.glb").get("moon_rock_04") as Mesh
	if stones_dict.is_empty() or m_moon == null:
		return

	# Sun-bleached warm golden-buff cobblestones with a dark 8mm basal mortar rim so each individual stone
	# separates cleanly from its neighbours without turning white/pillowy
	var cob_shadow := Color(0.34, 0.24, 0.16)
	var cob_mid := Color(0.75, 0.61, 0.45)
	var cob_crown := Color(0.95, 0.84, 0.65)
	var mat_stones := _make_scan_material("namaqualand_stones_01", cob_shadow, cob_mid, cob_crown, 0.54, 0.0, 0.009, 0.56, 0.12, 0.32, 0.64, 0.32, 0.78)
	var mat_moon := _make_scan_material("moon_rock_04", cob_shadow, Color(0.72, 0.58, 0.43), cob_crown, 0.68, 0.0, 0.009, 0.56, 0.12, 0.34, 0.62, 0.32, 0.78)

	var variants: Array[Mesh] = []
	var mats: Array[Material] = []
	var aabbs: Array[Vector3] = []
	for k in ["stone_a", "stone_b", "stone_c", "stone_d", "stone_e"]:
		if stones_dict.has(k):
			var m := stones_dict[k] as Mesh
			variants.append(m)
			mats.append(mat_stones)
			aabbs.append(m.get_aabb().size)
	var moon_idx := variants.size()
	variants.append(m_moon)
	mats.append(mat_moon)
	aabbs.append(m_moon.get_aabb().size)

	var xforms_per_variant: Array[Array] = []
	for i in variants.size():
		xforms_per_variant.append([])

	var rng := RandomNumberGenerator.new()
	rng.seed = 9021

	var z := 10.6
	var row := 0
	while z > -15.2:
		var dz := rng.randf_range(0.29, 0.34)
		var heading: float = route.heading(z)
		var row_shift := 0.14 if (row % 2 == 1) else 0.0
		var lat := -0.96 + row_shift
		# Smooth taper into the desert dunes between Z=-12.6 and Z=-15.2
		var exit_fade := clampf((-12.4 - z) / 2.8, 0.0, 1.0)
		while lat <= 0.98:
			var jz := z + rng.randf_range(-0.028, 0.028)
			var jlat := lat + rng.randf_range(-0.025, 0.025)
			var wx: float = route.center_x(jz) + jlat

			var edge_t := absf(jlat) / 1.04
			if (edge_t > 0.82 and rng.randf() < 0.25) or (exit_fade > 0.0 and rng.randf() < exit_fade * 0.85) or _is_near_boulder(wx, jz, boulder_footprints, -0.15):
				lat += rng.randf_range(0.29, 0.34)
				continue

			var use_moon := (rng.randf() < 0.20)
			var v_idx := moon_idx if use_moon else (rng.randi() % moon_idx)
			var aabb := aabbs[v_idx]

			# Sized slightly smaller than the 0.31m grid cell so a 3-5cm dark mortar joint shows around every stone
			var w_x := rng.randf_range(0.29, 0.36) if use_moon else rng.randf_range(0.21, 0.27)
			var l_z := rng.randf_range(0.31, 0.38) if use_moon else rng.randf_range(0.23, 0.30)
			var h_y := rng.randf_range(0.015, 0.022) * (1.0 - exit_fade * 0.45)

			var sc := Vector3(w_x / aabb.x, h_y / aabb.y, l_z / aabb.z)
			var yaw := heading + deg_to_rad(rng.randf_range(-18.0, 18.0)) + (PI if rng.randf() < 0.5 else 0.0)
			var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(sc)
			var xform := Transform3D(basis, Vector3(wx, 0.001, jz))
			xforms_per_variant[v_idx].append(xform)

			lat += (0.35 if use_moon else 0.29) + rng.randf_range(-0.015, 0.02)
		z -= dz
		row += 1

	for v_idx in variants.size():
		var list: Array = xforms_per_variant[v_idx]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = variants[v_idx]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "CobbleMultiMesh_%d" % v_idx
		mmi.multimesh = mm
		mmi.material_override = mats[v_idx]
		_cobbles_root.add_child(mmi)


# ---------------------------------------------------------------------------
# ROLE 4: PLANTS & SANDY VERGE (Cheiridopsis Succulent + Sand Rocks Small 01 + Namaqualand Rocks 01)
# ---------------------------------------------------------------------------
func _build_plants_and_verge(route: Node, boulder_footprints: Array[Vector3]) -> void:
	var succ_dict := _extract_meshes("cheiridopsis_succulent.glb")
	var m_sand_rocks := _extract_meshes("sand_rocks_small_01.glb").get("sand_rocks_small_01") as Mesh
	var verge_rocks_dict := _extract_meshes("namaqualand_rocks_01.glb")
	if succ_dict.is_empty():
		return

	var mat_succ := _make_succulent_material()
	var mat_sand_rocks := _make_scan_material("sand_rocks_small_01",
		Color(0.36, 0.24, 0.16), Color(0.76, 0.56, 0.37), Color(0.96, 0.78, 0.55), 0.76, 0.0, 0.10, 0.35, 0.12, 0.28, 0.70, 0.22)
	var mat_verge_rocks := _make_scan_material("namaqualand_rocks_01",
		Color(0.28, 0.18, 0.15), Color(0.68, 0.45, 0.31), Color(0.92, 0.71, 0.50), 0.68, 0.0, 0.06, 0.30, 0.12, 0.25, 0.70, 0.25)

	# 1. Sand Rocks Small 01: settled loose rocks in sand pockets where the curb breaks and along the verge
	if m_sand_rocks:
		var sr_spots := [
			[-1.0, 7.6, 1.92, 6.0, Vector3(0.34, 0.34, 0.40)],
			[1.0, 6.8, 1.90, -8.0, Vector3(0.34, 0.34, 0.38)],
			[-1.0, 1.8, 1.95, 12.0, Vector3(0.36, 0.35, 0.42)],
			[1.0, -0.4, 1.90, -5.0, Vector3(0.34, 0.34, 0.40)],
			[-1.0, -4.2, 1.92, -10.0, Vector3(0.34, 0.34, 0.38)],
			[1.0, -5.8, 1.88, 9.0, Vector3(0.32, 0.32, 0.38)],
			[-1.0, -9.4, 1.92, 4.0, Vector3(0.34, 0.34, 0.38)],
			[1.0, -11.2, 1.90, -6.0, Vector3(0.32, 0.32, 0.36)],
		]
		for sp in sr_spots:
			var z: float = sp[1]
			var side: float = sp[0]
			var mi := MeshInstance3D.new()
			mi.mesh = m_sand_rocks
			mi.material_override = mat_sand_rocks
			mi.position = Vector3(route.center_x(z) + side * float(sp[2]), -0.04, z)
			mi.rotation.y = route.heading(z) + deg_to_rad(float(sp[3]))
			mi.scale = sp[4]
			_verge_root.add_child(mi)

	var big_succs: Array[Mesh] = []
	for k in ["succulent_h", "succulent_i", "succulent_f", "succulent_d"]:
		if succ_dict.has(k):
			big_succs.append(succ_dict[k])
	var small_succs: Array[Mesh] = []
	for k in ["succulent_a", "succulent_c", "succulent_d"]:
		if succ_dict.has(k):
			small_succs.append(succ_dict[k])
	var v_rocks: Array[Mesh] = []
	for k in ["verge_rock_a", "verge_rock_b", "verge_rock_c", "verge_rock_d"]:
		if verge_rocks_dict.has(k):
			v_rocks.append(verge_rocks_dict[k])

	var rng := RandomNumberGenerator.new()
	rng.seed = 7731

	# 2. Curated clusters of Cheiridopsis Succulent bushes + Namaqualand Rocks 01 in the sandy verge (between curbs & cliffs)
	for side: float in [-1.0, 1.0]:
		var z := 10.2
		while z > -12.6:
			var step := rng.randf_range(1.40, 1.90)
			var z_spot := z + rng.randf_range(-0.2, 0.2)
			var lat := rng.randf_range(1.66, 2.22)
			var wx: float = route.center_x(z_spot) + side * lat

			if _is_near_boulder(wx, z_spot, boulder_footprints, 0.28):
				z -= step
				continue

			var main_m := big_succs[rng.randi() % big_succs.size()]
			var sc_main := rng.randf_range(1.35, 1.75)
			_place_succulent_with_shadow(main_m, mat_succ, Vector3(wx, 0.0, z_spot),
				rng.randf_range(0.0, TAU), Vector3(sc_main, sc_main * 1.18, sc_main), 0.56 * sc_main)

			var n_sat := rng.randi_range(1, 2)
			for s_i in n_sat:
				var ang := rng.randf_range(0.0, TAU)
				var dist := rng.randf_range(0.26, 0.44)
				var sx := wx + cos(ang) * dist
				var sz := z_spot + sin(ang) * dist
				var sm := small_succs[rng.randi() % small_succs.size()]
				var sc_s := rng.randf_range(1.05, 1.38)
				_place_succulent_with_shadow(sm, mat_succ, Vector3(sx, 0.0, sz),
					rng.randf_range(0.0, TAU), Vector3(sc_s, sc_s * 1.12, sc_s), 0.28 * sc_s)

			if not v_rocks.is_empty():
				var n_r := rng.randi_range(1, 2)
				for r_i in n_r:
					var ang := rng.randf_range(0.0, TAU)
					var dist := rng.randf_range(0.20, 0.40)
					var rx := wx + cos(ang) * dist
					var rz := z_spot + sin(ang) * dist
					var rm := v_rocks[rng.randi() % v_rocks.size()]
					var rmi := MeshInstance3D.new()
					rmi.mesh = rm
					rmi.material_override = mat_verge_rocks
					rmi.position = Vector3(rx, -0.005, rz)
					rmi.rotation.y = rng.randf_range(0.0, TAU)
					rmi.scale = Vector3.ONE * rng.randf_range(0.90, 1.35)
					_verge_root.add_child(rmi)

			z -= step

	# 3. Cliff ledge accent succulents on the lower stepped boulder shelves (y = 0.72..0.92m)
	for side: float in [-1.0, 1.0]:
		for z_shelf: float in [8.4, 3.8, -0.8, -5.4, -9.8]:
			var wx: float = route.center_x(z_shelf) + side * rng.randf_range(2.65, 2.95)
			var sm := big_succs[rng.randi() % big_succs.size()]
			var sc := rng.randf_range(1.15, 1.45)
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			mi.material_override = mat_succ
			mi.position = Vector3(wx, rng.randf_range(0.72, 0.86), z_shelf)
			mi.rotation.y = rng.randf_range(0.0, TAU)
			mi.scale = Vector3(sc, sc * 1.15, sc)
			_verge_root.add_child(mi)


func _place_succulent_with_shadow(mesh: Mesh, mat: Material, pos: Vector3, yaw: float, sc: Vector3, disc_size: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = sc
	_verge_root.add_child(mi)

	var disc := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(disc_size, disc_size)
	disc.mesh = q
	disc.material_override = _shadow_disc_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = Vector3(pos.x, pos.y + 0.010, pos.z)
	disc.rotation.x = -PI * 0.5
	_verge_root.add_child(disc)


# ---------------------------------------------------------------------------
# ROLE 5: EXIT VIEW (Canyon River Terrain Gorge + Mountain Desert 009 Arch + Distant Mesa)
# ---------------------------------------------------------------------------
func _build_exit_vista(_route: Node) -> void:
	var m_river := _extract_meshes("canyon_river_terrain.glb").get("canyon_river_terrain") as Mesh
	var m_arch := _extract_meshes("mountain_desert_009.glb").get("mountain_desert_009") as Mesh

	# 1. Mountain Desert 009: Natural sandstone arch placed at y=-3.2, z=-33.0, rotated -72 deg so its
	#    upper arch window (+78% height) sits inside the -21 deg camera frustum and frames the sky
	if m_arch:
		var mat_arch := _make_scan_material("namaqualand_cliff_01",
			Color(0.26, 0.16, 0.15), Color(0.75, 0.47, 0.30), Color(0.97, 0.76, 0.52), 0.72, 0.45, 0.5, 0.25, 0.28)
		var arch_mi := MeshInstance3D.new()
		arch_mi.name = "MountainDesert009Arch"
		arch_mi.mesh = m_arch
		arch_mi.material_override = mat_arch
		arch_mi.position = Vector3(-7.2, -4.1, -34.0)
		arch_mi.rotation_degrees.y = -72.0
		arch_mi.scale = Vector3(0.84, 0.64, 0.84)
		_vista_root.add_child(arch_mi)

	# 2. Canyon River Terrain: Distant river gorge set behind Z=-38 (well past the Z=-22.2 Orichalcum crater)
	if m_river:
		var mat_river := _make_scan_material("canyon_river_terrain",
			Color(0.32, 0.20, 0.16), Color(0.76, 0.49, 0.31), Color(0.97, 0.76, 0.52), 0.86, 0.18, 0.5, 0.20, 0.30)
		var river_mi := MeshInstance3D.new()
		river_mi.name = "CanyonRiverTerrainVista"
		river_mi.mesh = m_river
		river_mi.material_override = mat_river
		river_mi.position = Vector3(1.5, -6.5, -66.0)
		river_mi.rotation_degrees.y = -18.0
		river_mi.scale = Vector3(1.15, 0.82, 0.82)
		_vista_root.add_child(river_mi)

	# 3. Distant right mesa silhouette (CraftPix Plateau 002)
	if ResourceLoader.exists(CRAFTPIX_MESA):
		var mesa := (load(CRAFTPIX_MESA) as PackedScene).instantiate() as Node3D
		mesa.name = "PlateauDesert002Vista"
		mesa.position = Vector3(11.0, -0.3, -44.0)
		mesa.rotation_degrees.y = -15.0
		mesa.scale = Vector3.ONE * 1.55
		for m: MeshInstance3D in mesa.find_children("*", "MeshInstance3D", true, false):
			m.set_surface_override_material(0, ROCK_MATERIAL)
		_vista_root.add_child(mesa)
