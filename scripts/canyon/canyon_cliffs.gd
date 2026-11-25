extends Node3D
## Builds stepped canyon cliffs on both sides of the road from the 3D cliff kit:
##   a low dry-stone retaining wall at the road's edge, a narrow paved terrace, then rows ("courses") of
##   rounded sandstone blocks, each row set back and higher than the one below. Between the rows stand
##   vertical faces of layered sandstone (the strata texture of the current look), paved treads on top,
##   and rubble lies at the foot of each row.
## Blocks: assets/models/cliffs/cliff_blocks.glb (tools/blender/build_cliff_blocks.py). Textures:
## assets/textures/cliffs/ (tools/python/build_cliff_atlas.py), "gpt" (art_gpt colours) or "goal" (B64).
## Shading: assets/shaders/canyon_kit_rock.gdshader (purple shade, darker block bases).
## Second pass (experiment log §18b): fewer and larger blocks, strata faces between rows, rubble, darker.

const BLOCKS := "res://assets/models/cliffs/cliff_blocks.glb"
const DATA := "res://assets/textures/cliffs/cliff_blocks.json"
const TEX := "res://assets/textures/cliffs/cliff_%s_%s.png"
const TEX_NORMAL := "res://assets/textures/cliffs/cliff_%s_%s_normal.png"
const ROCK_SHADER := preload("res://assets/shaders/canyon_kit_rock.gdshader")
## Strata faces between the rows, per look: [albedo, normal, metres along, metres up].
const STRATA := {
	"gpt": ["res://assets/textures/pixel_ab/art_gpt/d_sandstone_strata_albedo.png",
		"res://assets/textures/pixel_ab/art_gpt/d_sandstone_strata_normal.png", 3.7188, 2.5469],
	"ramp": ["res://assets/textures/pixel_ab/art_road_ramp/d_sandstone_strata_albedo.png",
		"res://assets/textures/pixel_ab/art_road_ramp/d_sandstone_strata_normal.png", 3.7188, 2.5469],
	"goal": ["res://assets/textures/pixel_ab/d64/d_sandstone_strata_albedo.png",
		"res://assets/textures/pixel_ab/d64/d_sandstone_strata_normal.png", 2.9412, 1.3889],
}
const TILE_M := 2.0

@export var z_start := 14.0
@export var z_end := -17.0
## Lateral distances from the route centre, metres.
@export var wall_front := 2.7
@export var wall_height := 0.55
@export var terrace_depth := 0.5
@export var course_setback := 0.8
@export var course_rise := 0.85
@export var max_courses := 4
@export var min_courses := 2
## Block size range and how much each row grows; spacing is a share of a block's width (1 = touching).
@export var block_scale := Vector2(1.1, 1.55)
@export var spacing := Vector2(0.75, 1.15)
@export_range(0.0, 1.0) var extra_chance := 0.15
## Rubble: small pieces at the foot of the retaining wall and of each row, one every this many metres.
@export var rubble_every := Vector2(0.9, 2.2)
## Where the canyon walls drop toward the exit vista.
@export var taper_from := -11.0
@export var taper_to := -17.0
@export var plateau_depth := 6.0
@export var random_seed := 11
@export var look := "goal":
	set(value):
		look = value
		_apply_look()

var _meshes: Array[Mesh] = []
var _sizes: Array[Vector3] = []  # width (along the wall), height, depth for each block, metres
var _block_material := ShaderMaterial.new()
var _wall_material := ShaderMaterial.new()
var _strata_material := ShaderMaterial.new()
var _paving_material := ShaderMaterial.new()
var _rng := RandomNumberGenerator.new()


func build(route: Node) -> void:
	for child in get_children():
		child.queue_free()
	_load()
	for m in [_block_material, _wall_material, _strata_material, _paving_material]:
		(m as ShaderMaterial).shader = ROCK_SHADER
	_apply_look()
	_rng.seed = random_seed
	var blocks := 0
	var rubble := 0
	for side in [-1.0, 1.0]:
		_build_core(route, side)
		blocks += _build_courses(route, side)
		rubble += _build_rubble(route, side)
	print("Cliffs: %d sandstone blocks, %d rubble pieces, look=%s" % [blocks, rubble, look])


func courses_at(z: float) -> int:
	var wave := 0.5 + 0.5 * sin(z * 0.37 + 1.3) * cos(z * 0.13)
	var n := lerpf(float(min_courses), float(max_courses) + 0.99, wave)
	var taper := clampf((z - taper_to) / (taper_from - taper_to), 0.0, 1.0)
	return int(lerpf(1.0, n, taper))


## Stepped profile across the wall at z: (lateral, height) points from the road outward. Every profile has
## the same number of points; rows that are absent here get a zero-height riser, so neighbouring slices
## always join (a change in row count becomes a short ramp).
func _profile(z: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var lat := wall_front
	p.append(Vector2(lat, -0.05))
	p.append(Vector2(lat, wall_height))
	lat += terrace_depth
	var h := wall_height
	var rows := courses_at(z)
	for k in max_courses:
		# The strata face stands 0.3 m behind its row's block fronts: blocks hide part of it, the gaps show it.
		var riser := lat + 0.3
		p.append(Vector2(riser, h))
		if k < rows:
			h += course_rise
		p.append(Vector2(riser, h))
		lat += course_setback
	p.append(Vector2(lat + plateau_depth, h))
	return p


func _build_core(route: Node, side: float) -> void:
	var walls := SurfaceTool.new()
	var strata := SurfaceTool.new()
	var paving := SurfaceTool.new()
	for st in [walls, strata, paving]:
		(st as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	var tile := _strata_tile()
	var step := 0.25
	var z := z_start
	while z > z_end:
		var z2 := z - step
		var a := _profile(z)
		var b := _profile(z2)
		for i in a.size() - 1:
			var vertical := absf(a[i + 1].y - a[i].y) + absf(b[i + 1].y - b[i].y) > absf(a[i + 1].x - a[i].x) * 2.0
			var pts := [_world(route, side, z, a[i]), _world(route, side, z, a[i + 1]),
				_world(route, side, z2, b[i + 1]), _world(route, side, z2, b[i])]
			if pts[0].distance_to(pts[1]) < 0.001 and pts[3].distance_to(pts[2]) < 0.001:
				continue  # an absent row's zero-height riser
			if not vertical:
				_quad(paving, pts, Vector3.UP, Vector2(TILE_M, TILE_M))
			elif i == 0:
				_quad(walls, pts, Vector3(-side, 0, 0), Vector2(TILE_M, TILE_M))
			else:
				_quad(strata, pts, Vector3(-side, 0, 0), tile)
		z = z2
	var core := MeshInstance3D.new()
	core.name = "CoreLeft" if side < 0 else "CoreRight"
	var mesh := ArrayMesh.new()
	var index := 0
	for pair in [[walls, _wall_material], [strata, _strata_material], [paving, _paving_material]]:
		var st: SurfaceTool = pair[0]
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(index, pair[1])
		index += 1
	core.mesh = mesh
	add_child(core)


func _world(route: Node, side: float, z: float, p: Vector2) -> Vector3:
	return Vector3(route.center_x(z) + side * p.x, p.y, z)


## A quad facing `want`, its texture projected from the direction it faces (tile = metres per repeat), so
## faces across the canyon (where the number of rows changes) are not stretched into stripes.
func _quad(st: SurfaceTool, pts: Array, want: Vector3, tile: Vector2) -> void:
	var n: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	var uvs := []
	for q: Vector3 in pts:
		if absf(n.y) >= absf(n.x) and absf(n.y) >= absf(n.z):
			uvs.append(Vector2(q.x / tile.x, q.z / tile.y))
		elif absf(n.x) >= absf(n.z):
			uvs.append(Vector2(-q.z / tile.x, -q.y / tile.y))
		else:
			uvs.append(Vector2(q.x / tile.x, -q.y / tile.y))
	var order := [0, 1, 2, 0, 2, 3]
	if n.dot(want) > 0.0:
		# Godot's front faces wind clockwise as seen from the front: reverse when the cross product faces us.
		order = [0, 2, 1, 0, 3, 2]
	else:
		n = -n
	for i: int in order:
		st.set_normal(n)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


func _build_courses(route: Node, side: float) -> int:
	var count := 0
	for k in max_courses:
		var z := z_start
		while z > z_end:
			var variant := _rng.randi() % _meshes.size()
			var size := _sizes[variant]
			var s := _rng.randf_range(block_scale.x, block_scale.y) * (1.0 + 0.08 * k)
			var along := size.x * s
			var z_mid := z - along * 0.5
			z -= along * _rng.randf_range(spacing.x, spacing.y)
			if k >= courses_at(z_mid):
				continue
			var front := wall_front + terrace_depth + k * course_setback + _rng.randf_range(-0.12, 0.15)
			var base := wall_height + k * course_rise - _rng.randf_range(0.0, 0.1)
			var tall := _rng.randf_range(0.55, 0.8)
			count += _place(route, side, z_mid, front, base, variant, s, tall)
			if _rng.randf() < extra_chance:
				# A smaller block capping this one, set back a little.
				var v2 := _rng.randi() % _meshes.size()
				var s2 := s * _rng.randf_range(0.5, 0.7)
				count += _place(route, side, z_mid + _rng.randf_range(-0.3, 0.3), front + 0.25,
					base + size.y * s * tall * 0.8, v2, s2, 1.0)
	return count


## Small fallen pieces: along the foot of the retaining wall and on each row's tread, in front of the blocks.
func _build_rubble(route: Node, side: float) -> int:
	var count := 0
	for k in max_courses + 1:
		var z := z_start - _rng.randf_range(0.0, 1.0)
		while z > z_end:
			z -= _rng.randf_range(rubble_every.x, rubble_every.y)
			var front: float
			var base: float
			if k == 0:
				front = wall_front - 0.12
				base = -0.04
			else:
				if k - 1 >= courses_at(z):
					continue
				front = wall_front + terrace_depth + (k - 1) * course_setback - 0.3
				base = wall_height + (k - 1) * course_rise - 0.04
			var variant := _rng.randi() % _meshes.size()
			count += _place(route, side, z, front, base, variant, _rng.randf_range(0.18, 0.34), _rng.randf_range(0.6, 1.0))
	return count


func _place(route: Node, side: float, z: float, front: float, base: float, variant: int, s: float, tall: float) -> int:
	var size := _sizes[variant]
	var lateral := front + size.z * s * 0.5
	var slope: float = (route.center_x(z - 0.05) - route.center_x(z + 0.05)) / 0.1
	var facing := Vector3(-side, 0.0, side * slope).normalized()  # toward the road
	var yaw := atan2(facing.x, facing.z) + deg_to_rad(_rng.randf_range(-25.0, 25.0))
	var block := MeshInstance3D.new()
	block.mesh = _meshes[variant]
	block.material_override = _block_material
	block.set_instance_shader_parameter("block_height", size.y)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * tall, s))
	block.transform = Transform3D(basis, Vector3(route.center_x(z) + side * lateral, base, z))
	add_child(block)
	return 1


func _strata_tile() -> Vector2:
	var entry: Array = STRATA.get(look, STRATA["goal"])
	return Vector2(entry[2], entry[3])


func _load() -> void:
	if not _meshes.is_empty():
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var scene: Node = (load(BLOCKS) as PackedScene).instantiate()
	for i in (data["blocks"] as Array).size():
		var node := scene.find_child("cliff_block_%d" % i, true, false) as MeshInstance3D
		if node == null:
			continue
		var b: Dictionary = data["blocks"][i]
		_meshes.append(node.mesh)
		_sizes.append(Vector3(b["size_m"][0], b["height_m"], b["size_m"][1]))
	scene.free()


func _apply_look() -> void:
	var sets := [[_block_material, TEX % ["blocks", look], TEX_NORMAL % ["blocks", look]],
		[_wall_material, TEX % ["wall", look], TEX_NORMAL % ["wall", look]],
		[_paving_material, TEX % ["paving", look], TEX_NORMAL % ["paving", look]],
		[_strata_material, STRATA.get(look, STRATA["goal"])[0], STRATA.get(look, STRATA["goal"])[1]]]
	for entry in sets:
		var material: ShaderMaterial = entry[0]
		if not ResourceLoader.exists(entry[1]):
			continue
		material.set_shader_parameter("albedo_tex", load(entry[1]))
		material.set_shader_parameter("normal_tex", load(entry[2]))
	# Core faces are not single blocks: no base darkening by height.
	for material in [_wall_material, _strata_material, _paving_material]:
		(material as ShaderMaterial).set_shader_parameter("base_ao", 0.0)
