extends Node3D
## Lays real 3D curb blocks along both edges of the canyon road.
## Blocks come from assets/models/curbs/curb_blocks.glb (tools/blender/build_curb_blocks.py) and wear a
## pixel atlas (tools/python/build_curb_atlas.py): "gpt" keeps the ChatGPT sheet's colours (art_gpt look),
## "goal" uses the shared goal palette (B64 look). Each block gets a random stone, a small gap, a slight
## lean and sink, so the row reads as laid by hand. A box collider per block keeps walkers on the road.

const BLOCKS := "res://assets/models/curbs/curb_blocks.glb"
const ATLAS := "res://assets/textures/curbs/curb_atlas_%s.png"
const ATLAS_NORMAL := "res://assets/textures/curbs/curb_atlas_%s_normal.png"
const LAYOUT := "res://assets/textures/curbs/curb_atlas.json"

## Distance from the route centre to the middle of each curb row (the road paint ends at 1.10-1.38 m).
@export var offset := 1.25
@export var z_start := 10.0
@export var z_end := -12.4
@export var gap_min := 0.02
@export var gap_max := 0.06
## Chance that a block is missing (a worn gap in the row).
@export_range(0.0, 0.5) var missing_chance := 0.05
@export var lean_deg := 2.5
@export var yaw_jitter_deg := 3.0
@export var sink_max := 0.03
@export var random_seed := 7
@export var look := "goal":
	set(value):
		look = value
		_apply_look()

var _meshes: Array[Mesh] = []
var _material := StandardMaterial3D.new()
var _block := Vector3(0.39, 0.22, 0.72)  # width, height, length in metres (from the atlas layout)


func build(route: Node) -> void:
	for child in get_children():
		child.queue_free()
	_load_meshes()
	_apply_look()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var body := StaticBody3D.new()
	body.name = "CurbColliders"
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = _block
	var count := 0
	for side in [-1.0, 1.0]:
		var z := z_start
		while z > z_end:
			var spacing := _block.z + rng.randf_range(gap_min, gap_max)
			var z_mid := _advance(route, side, z, spacing * 0.5)
			var z_next := _advance(route, side, z, spacing)
			z = z_next
			if rng.randf() < missing_chance:
				continue
			var slope: float = (route.center_x(z_mid - 0.05) - route.center_x(z_mid + 0.05)) / 0.1
			var yaw := atan(-slope) + deg_to_rad(rng.randf_range(-yaw_jitter_deg, yaw_jitter_deg))
			if rng.randf() < 0.5:
				yaw += PI  # either end can face the camera
			var basis := Basis(Vector3.UP, yaw)
			basis = basis * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-lean_deg, lean_deg)))
			basis = basis * Basis(Vector3.FORWARD, deg_to_rad(rng.randf_range(-lean_deg, lean_deg)))
			var origin := Vector3(route.center_x(z_mid) + side * offset, -rng.randf_range(0.0, sink_max), z_mid)
			var block := MeshInstance3D.new()
			block.mesh = _meshes[rng.randi() % _meshes.size()]
			block.material_override = _material
			block.transform = Transform3D(basis, origin)
			add_child(block)
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.transform = Transform3D(Basis(Vector3.UP, yaw), origin + Vector3(0, _block.y * 0.5, 0))
			body.add_child(collider)
			count += 1
	print("Curbs: %d blocks, look=%s" % [count, look])


## Z after walking `distance` metres along the curb edge (side * offset from the route centre) from z.
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


func _load_meshes() -> void:
	if not _meshes.is_empty():
		return
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if layout is Dictionary:
		var m: Array = layout["block_m"]
		_block = Vector3(m[1], m[2], m[0])
	var scene: Node = (load(BLOCKS) as PackedScene).instantiate()
	var found: Array[Node] = scene.find_children("curb_*", "MeshInstance3D", true, false)
	found.sort_custom(func(a: Node, b: Node) -> bool: return a.name < b.name)
	for node: Node in found:
		_meshes.append((node as MeshInstance3D).mesh)
	scene.free()


func _apply_look() -> void:
	if not ResourceLoader.exists(ATLAS % look):
		return
	_material.albedo_texture = load(ATLAS % look)
	_material.normal_enabled = true
	_material.normal_texture = load(ATLAS_NORMAL % look)
	_material.normal_scale = 0.6
	_material.roughness = 0.92
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
