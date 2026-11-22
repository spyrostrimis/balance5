extends Node3D
## Unscaled 1:1 metric 3D curb blocks along both edges of the road in 3D Kit Canyon v2.
## Every block sits strictly flush at y=0.0 with zero lean/sink and guaranteed non-overlapping spacing.

const MESHES_GLB := "res://assets/models/kit_v2/kit_v2_meshes.glb"
const MESHES_JSON := "res://assets/models/kit_v2/kit_v2_meshes.json"
const ROCK_SHADER := preload("res://assets/shaders/canyon_kit_v2_rock.gdshader")
const TEX_ROOT := "res://assets/textures/kit_v2/"

@export var offset := 1.38
@export var z_start := 10.0
@export var z_end := -12.4
@export var gap_min := 0.05
@export var gap_max := 0.10
@export_range(0.0, 0.5) var missing_chance := 0.05
@export var yaw_jitter_deg := 2.0
@export var random_seed := 7

var _meshes: Array[Mesh] = []
var _meta: Array[Dictionary] = []
var _material := ShaderMaterial.new()
var _placed: Array[Dictionary] = []


func build(route: Node) -> void:
	for child in get_children():
		child.queue_free()
	_placed.clear()
	_load_assets()

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var count := 0
	for side: float in [-1.0, 1.0]:
		var z := z_start
		while z > z_end:
			var variant := rng.randi() % _meshes.size()
			var m: Dictionary = _meta[variant]
			var length := float(m["depth_z"])
			var width := float(m["width_x"])
			var height := float(m["height_y"])
			var gap := rng.randf_range(gap_min, gap_max)

			var z_mid := _advance(route, side, z, length * 0.5)
			var z_next := _advance(route, side, z, length + gap)
			z = z_next
			if z_mid < z_end or rng.randf() < missing_chance:
				continue

			var slope: float = (route.center_x(z_mid - 0.05) - route.center_x(z_mid + 0.05)) / 0.1
			var yaw := atan(-slope) + deg_to_rad(rng.randf_range(-yaw_jitter_deg, yaw_jitter_deg))
			if rng.randf() < 0.5:
				yaw += PI

			var pos := Vector3(route.center_x(z_mid) + side * offset, 0.0, z_mid)
			# Ensure zero corner overlap with previous block on tight inner bends
			if _overlaps_previous(side, pos, yaw, width, length):
				continue

			var block := MeshInstance3D.new()
			block.name = "Curb_%s_%d" % ["L" if side < 0.0 else "R", count]
			block.mesh = _meshes[variant]
			block.set_surface_override_material(0, _material)
			block.set_instance_shader_parameter("block_height", height)
			block.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
			add_child(block)

			_placed.append({
				"label": block.name,
				"side": side,
				"pos": pos,
				"yaw": yaw,
				"width": width,
				"length": length,
				"radius": float(m["radius_xz"]),
			})
			count += 1
	print("KitV2 Curbs: %d blocks (flush y=0.0, unscaled 1:1)" % count)


func get_placed() -> Array[Dictionary]:
	return _placed


func _overlaps_previous(side: float, pos: Vector3, yaw: float, width: float, length: float) -> bool:
	for prev in _placed:
		if prev["side"] != side:
			continue
		var d: Vector3 = pos - (prev["pos"] as Vector3)
		if absf(d.z) > 1.2:
			continue
		if _obb_overlap_2d(
			Vector2(pos.x, pos.z), yaw, Vector2(width * 0.5, length * 0.5),
			Vector2(prev["pos"].x, prev["pos"].z), prev["yaw"], Vector2(prev["width"] * 0.5, prev["length"] * 0.5),
			0.02
		):
			return true
	return false


static func _obb_overlap_2d(c1: Vector2, yaw1: float, h1: Vector2, c2: Vector2, yaw2: float, h2: Vector2, margin: float) -> bool:
	var axes1 := [Vector2(cos(yaw1), -sin(yaw1)), Vector2(sin(yaw1), cos(yaw1))]
	var axes2 := [Vector2(cos(yaw2), -sin(yaw2)), Vector2(sin(yaw2), cos(yaw2))]
	var d := c2 - c1
	for axis: Vector2 in axes1 + axes2:
		var dist := absf(d.dot(axis))
		var r1 := h1.x * absf(axes1[0].dot(axis)) + h1.y * absf(axes1[1].dot(axis))
		var r2 := h2.x * absf(axes2[0].dot(axis)) + h2.y * absf(axes2[1].dot(axis))
		if dist > r1 + r2 + margin:
			return false
	return true


func _advance(route: Node, side: float, z: float, distance: float) -> float:
	var walked := 0.0
	var step := 0.02
	var x: float = route.center_x(z) + side * offset
	while walked < distance:
		var nz := z - step
		var nx: float = route.center_x(nz) + side * offset
		walked += Vector2(nx - x, nz - z).length()
		x = nx
		z = nz
	return z


func _load_assets() -> void:
	if _meshes.is_empty():
		var mesh_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MESHES_JSON))["meshes"]
		var glb: Node = (load(MESHES_GLB) as PackedScene).instantiate()
		for i in 6:
			var k := "curb_%d" % i
			var mi := glb.find_child(k, true, false) as MeshInstance3D
			if mi:
				_meshes.append(mi.mesh)
				_meta.append(mesh_data[k])
		glb.free()
	_material.shader = ROCK_SHADER
	_material.set_shader_parameter("albedo_tex", load(TEX_ROOT + "curb_stone_albedo.png"))
	_material.set_shader_parameter("normal_tex", load(TEX_ROOT + "curb_stone_normal.png"))
	_material.set_shader_parameter("brightness", 0.80)
	_material.set_shader_parameter("base_ao", 0.30)
	_material.set_shader_parameter("normal_depth", 0.60)
