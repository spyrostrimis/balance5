extends "res://scripts/canyon/canyon_level.gd"
## Standalone playable study: "3D Kit Canyon · v2".
## No debug toggles, no mode switching, no option HUD — pure playable canyon with:
##   - img1 cobblestone road, art_gemini sand & dunes, art_road_goal organic cliffs & flush rocks,
##   - uniform 64 texels/m seamless pixel art across every mesh and sprite (<= 32 colors/object),
##   - 4x MSAA, 8x anisotropic filtering, and sharp-pixel shader + alpha-to-coverage anti-aliasing.

const MESHES_GLB := "res://assets/models/kit_v2/kit_v2_meshes.glb"
const MESHES_JSON := "res://assets/models/kit_v2/kit_v2_meshes.json"
const MANIFEST_JSON := "res://assets/textures/kit_v2/manifest.json"
const ROCK_SHADER := preload("res://assets/shaders/canyon_kit_v2_rock.gdshader")
const COMMANDER_SHADER := preload("res://assets/shaders/canyon_kit_v2_commander.gdshader")
const COMMANDER_TEX := preload("res://assets/textures/kit_v2/blue_commander_v2.png")
const TEX_ROOT := "res://assets/textures/kit_v2/"
const CRAFTPIX := "res://assets/models/packs/craftpix_desert/%s.glb"

## Candidate roadside boulder spots: [side, z, variant_idx, yaw_deg]
const BOULDER_CANDIDATES := [
	[-1.0, 9.2, 0, 22.0],
	[-1.0, 4.9, 2, -14.0],
	[-1.0, -3.5, 1, 35.0],
	[-1.0, -9.8, 0, -28.0],
	[1.0, 8.2, 1, -24.0],
	[1.0, 1.8, 2, 18.0],
	[1.0, -4.8, 0, -15.0],
	[1.0, -10.6, 1, 28.0],
]

## Distant desert mesas beyond the cliff plateaus (all unscaled 1:1, wearing 64 texels/m cliff textures)
const MESA_PLACEMENTS := [
	["Plateau_desert_002", -46.0, 16.5, -15.0],
	["Mountain_desert_008", -12.0, 20.5, -80.0],
	["Mountain_desert_002", -28.0, -19.5, 20.0],
]

var _curbs: Node3D
var _cliffs: Node3D
var _bushes: Node3D
var _boulders_root: Node3D
var _mesas_root: Node3D
var _placed_boulders: Array[Dictionary] = []

var _prev_msaa := Viewport.MSAA_DISABLED
var _prev_aniso := Viewport.ANISOTROPY_4X


func _ready() -> void:
	var vp := get_viewport()
	_prev_msaa = vp.msaa_3d
	_prev_aniso = vp.anisotropic_filtering_level
	vp.msaa_3d = Viewport.MSAA_4X
	vp.anisotropic_filtering_level = Viewport.ANISOTROPY_8X

	var route := get_node(route_path)

	_curbs = preload("res://scripts/canyon/canyon_kit_v2_curbs.gd").new()
	_curbs.name = "Curbs"
	add_child(_curbs)
	_curbs.build(route)

	_cliffs = preload("res://scripts/canyon/canyon_kit_v2_cliffs.gd").new()
	_cliffs.name = "Cliffs"
	add_child(_cliffs)
	_cliffs.build(route)

	_boulders_root = get_node_or_null("RoadsideBoulders")
	if _boulders_root == null:
		_boulders_root = Node3D.new()
		_boulders_root.name = "RoadsideBoulders"
		add_child(_boulders_root)
	_build_roadside_boulders(route)

	_bushes = preload("res://scripts/canyon/canyon_kit_v2_bushes.gd").new()
	_bushes.name = "Bushes"
	add_child(_bushes)
	_bushes.build(route, _cliffs, _curbs.get_placed(), _placed_boulders)

	_mesas_root = Node3D.new()
	_mesas_root.name = "DistantMesas"
	add_child(_mesas_root)
	_build_distant_mesas(route)

	_apply_commander_v2()
	super()


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = _prev_msaa
		vp.anisotropic_filtering_level = _prev_aniso


func get_placed_boulders() -> Array[Dictionary]:
	return _placed_boulders


func _build_roadside_boulders(route: Node) -> void:
	for child in _boulders_root.get_children():
		child.queue_free()
	_placed_boulders.clear()

	var mesh_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MESHES_JSON))["meshes"]
	var glb: Node = (load(MESHES_GLB) as PackedScene).instantiate()
	var boulder_meshes: Array[Mesh] = []
	var boulder_meta: Array[Dictionary] = []
	for i in 3:
		var k := "road_boulder_%d" % i
		var mi := glb.find_child(k, true, false) as MeshInstance3D
		if mi:
			boulder_meshes.append(mi.mesh)
			boulder_meta.append(mesh_data[k])
	glb.free()

	var mat := ShaderMaterial.new()
	mat.shader = ROCK_SHADER
	mat.set_shader_parameter("albedo_tex", load(TEX_ROOT + "road_boulder_albedo.png"))
	mat.set_shader_parameter("normal_tex", load(TEX_ROOT + "road_boulder_normal.png"))
	mat.set_shader_parameter("orm_tex", load(TEX_ROOT + "road_boulder_orm.png"))
	mat.set_shader_parameter("brightness", 0.84)
	mat.set_shader_parameter("base_ao", 0.35)
	mat.set_shader_parameter("normal_depth", 0.75)

	var curb_outer := 1.58
	for entry: Array in BOULDER_CANDIDATES:
		var side: float = entry[0]
		var z: float = entry[1]
		var variant: int = entry[2] % boulder_meshes.size()
		var yaw := deg_to_rad(float(entry[3]))
		var m: Dictionary = boulder_meta[variant]
		var r: float = float(m["radius_xz"])
		var h: float = float(m["height_y"])

		# Check tightest cliff foot across [z - r, z + r] so boulder clears BOTH curb and cliff toe
		var min_foot := INF
		for dz in [-r, 0.0, r]:
			min_foot = minf(min_foot, _cliffs.get_cliff_foot_lat(side, z + dz))
		var min_lat := curb_outer + r + 0.14
		var max_lat := min_foot - r - 0.14
		if max_lat < min_lat:
			continue
		var lat := 0.5 * (min_lat + max_lat)
		var pos := Vector3(route.center_x(z) + side * lat, 0.0, z)

		var conflict := false
		for prev in _placed_boulders:
			if Vector2((prev["pos"] as Vector3).x - pos.x, (prev["pos"] as Vector3).z - pos.z).length() < r + float(prev["radius"]) + 0.25:
				conflict = true
				break
		if conflict:
			continue

		var holder := Node3D.new()
		holder.name = "Boulder_%s_%d" % ["L" if side < 0.0 else "R", _placed_boulders.size()]
		holder.transform = Transform3D(Basis(Vector3.UP, yaw), pos)

		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = boulder_meshes[variant]
		mi.set_surface_override_material(0, mat)
		mi.set_instance_shader_parameter("block_height", h)
		holder.add_child(mi)

		var body := StaticBody3D.new()
		body.name = "Blocker"
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = h
		col.shape = cyl
		col.position = Vector3(0.0, h * 0.5, 0.0)
		body.add_child(col)
		holder.add_child(body)

		_boulders_root.add_child(holder)
		_placed_boulders.append({
			"label": holder.name,
			"side": side,
			"z": z,
			"lateral": lat,
			"pos": pos,
			"radius": r,
			"height": h,
		})
	print("KitV2 Boulders: %d roadside boulders placed clear of curbs and cliffs" % _placed_boulders.size())


func _build_distant_mesas(route: Node) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_JSON))
	var strata_tile := Vector2(manifest["cliff_strata"]["tile_m"][0], manifest["cliff_strata"]["tile_m"][1])
	var ledge_tile := Vector2(manifest["cliff_ledge"]["tile_m"][0], manifest["cliff_ledge"]["tile_m"][1])

	var mat := ShaderMaterial.new()
	mat.shader = ROCK_SHADER
	mat.set_shader_parameter("use_world_triplanar", true)
	mat.set_shader_parameter("albedo_tex", load(TEX_ROOT + "cliff_strata_albedo.png"))
	mat.set_shader_parameter("normal_tex", load(TEX_ROOT + "cliff_strata_normal.png"))
	mat.set_shader_parameter("world_tile_m", strata_tile)
	mat.set_shader_parameter("top_albedo_tex", load(TEX_ROOT + "cliff_ledge_albedo.png"))
	mat.set_shader_parameter("top_normal_tex", load(TEX_ROOT + "cliff_ledge_normal.png"))
	mat.set_shader_parameter("top_tile_m", ledge_tile)
	mat.set_shader_parameter("brightness", 0.78)
	mat.set_shader_parameter("base_ao", 0.0)
	mat.set_shader_parameter("haze_strength", 0.14)

	for entry: Array in MESA_PLACEMENTS:
		var path := CRAFTPIX % entry[0]
		if not ResourceLoader.exists(path):
			continue
		var model := (load(path) as PackedScene).instantiate() as Node3D
		var z: float = entry[1]
		model.position = Vector3(route.center_x(z) + float(entry[2]), 0.0, z)
		model.rotation_degrees.y = float(entry[3])
		model.scale = Vector3.ONE
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			mesh.set_surface_override_material(0, mat)
		_mesas_root.add_child(model)


func _apply_commander_v2() -> void:
	var commander := get_node_or_null(commander_path)
	if commander == null:
		return
	var sprite := commander.get_node_or_null("CommanderSprite") as Sprite3D
	if sprite == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = COMMANDER_SHADER
	mat.set_shader_parameter("sprite_tex", COMMANDER_TEX)
	mat.set_shader_parameter("brightness", 1.0)
	sprite.texture = COMMANDER_TEX
	sprite.pixel_size = 1.0 / 64.0
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.material_override = mat
