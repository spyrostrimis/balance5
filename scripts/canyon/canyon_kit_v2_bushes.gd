extends Node3D
## Unscaled 1:1 pixel-art bushes and grass tufts (64 texels/m) for 3D Kit Canyon v2.
## Every plant sits strictly flush at y=0.0 (sand verge) or shelf_y (cliff ledges) with explicit
## clearance from curbs, roadside boulders, cliff rocks, rubble, and cliff riser walls.

const MANIFEST_JSON := "res://assets/textures/kit_v2/manifest.json"
const TEX_ROOT := "res://assets/textures/kit_v2/"
const SPRITE_SHADER := preload("res://assets/shaders/canyon_kit_v2_sprite.gdshader")

@export var z_start := 12.2
@export var z_end := -14.2
@export var clump_every := Vector2(1.1, 2.2)
@export var ledge_every := Vector2(1.6, 3.0)
@export var random_seed := 23

var _sprites: Array[Dictionary] = []
var _placed: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func build(route: Node, cliffs: Node, curbs: Array[Dictionary], boulders: Array[Dictionary]) -> void:
	for child in get_children():
		child.queue_free()
	_placed.clear()
	_load_assets()
	_rng.seed = random_seed

	var rock_items: Array[Dictionary] = cliffs.get_placed_rocks() + cliffs.get_placed_rubble()
	var count := 0

	for side: float in [-1.0, 1.0]:
		# 1. Ground sand verge clumps (between curb outer edge and cliff foot)
		var z := z_start
		while z > z_end:
			z -= _rng.randf_range(clump_every.x, clump_every.y)
			var foot_lat: float = cliffs.get_cliff_foot_lat(side, z)
			var min_lat := 1.75
			var max_lat := foot_lat - 0.35
			if max_lat <= min_lat:
				continue
			var lat := _rng.randf_range(min_lat, max_lat)
			var pieces := _rng.randi_range(1, 3)
			for i in pieces:
				var kind := "bush" if (i == 0 and _rng.randf() < 0.72) else "grass"
				var pz := z + (_rng.randf_range(-0.48, 0.48) if i > 0 else 0.0)
				var p_foot: float = cliffs.get_cliff_foot_lat(side, pz)
				var p_lat := clampf(lat + (_rng.randf_range(-0.32, 0.32) if i > 0 else 0.0), min_lat, p_foot - 0.25)
				count += _try_plant_ground(route, cliffs, curbs, boulders, side, pz, p_lat, kind)

		# 2. Ground grass tufts near cliff toe
		z = z_start
		while z > z_end:
			z -= _rng.randf_range(0.8, 1.6)
			var foot_lat: float = cliffs.get_cliff_foot_lat(side, z)
			count += _try_plant_ground(route, cliffs, curbs, boulders, side, z, foot_lat - 0.28, "grass")

		# 3. Cliff shelf bushes & grass (using medium bushes and grass so cards fit shelves without clipping)
		var slices: Array[Dictionary] = cliffs.get_shelf_slices(side)
		var next_z_by_tier := {}
		for sl in slices:
			var k: int = sl["tier"]
			var sz: float = sl["z"]
			if sz > z_start or sz < z_end:
				continue
			if not next_z_by_tier.has(k):
				next_z_by_tier[k] = sz
			if sz > float(next_z_by_tier[k]):
				continue
			next_z_by_tier[k] = sz - _rng.randf_range(ledge_every.x, ledge_every.y)

			var kind := "bush_med" if _rng.randf() < 0.50 else "grass"
			var s_in: float = sl["inner"]
			var s_out: float = sl["outer"]
			var lat_mid := _rng.randf_range(s_in + 0.28, maxf(s_in + 0.28, s_out - 0.28))
			count += _try_plant_shelf(route, side, sz, lat_mid, float(sl["y"]), s_in, s_out, k, kind, rock_items)

	print("KitV2 Bushes: %d plants (all unscaled 1:1 at 64 texels/m)" % count)


func get_placed() -> Array[Dictionary]:
	return _placed


func _pick_sprite(kind: String) -> Dictionary:
	var opts: Array[Dictionary] = []
	for s in _sprites:
		if kind == "bush_med":
			if s["name"].begins_with("bush_med"):
				opts.append(s)
		elif s["kind"] == kind:
			opts.append(s)
	if opts.is_empty():
		return {}
	return opts[_rng.randi() % opts.size()]


func _try_plant_ground(route: Node, cliffs: Node, curbs: Array[Dictionary], boulders: Array[Dictionary],
		side: float, z: float, lat: float, kind: String) -> int:
	var sp := _pick_sprite(kind)
	if sp.is_empty():
		return 0
	var hw: float = float(sp["metres"].x) * 0.42
	# Check cliff foot clearance over the card's Z span
	for dz in [-0.15, 0.0, 0.15]:
		var foot: float = cliffs.get_cliff_foot_lat(side, z + dz)
		if lat + hw > foot - 0.05:
			return 0
	if lat - hw < 1.58:
		return 0

	var pos := Vector3(route.center_x(z) + side * lat, 0.0, z)
	for c in curbs:
		if Vector2((c["pos"] as Vector3).x - pos.x, (c["pos"] as Vector3).z - pos.z).length() < hw + 0.28:
			return 0
	for b in boulders:
		if Vector2((b["pos"] as Vector3).x - pos.x, (b["pos"] as Vector3).z - pos.z).length() < hw + float(b["radius"]) + 0.10:
			return 0
	for p in _placed:
		if int(p["tier"]) == -1:
			var dist := Vector2((p["pos"] as Vector3).x - pos.x, (p["pos"] as Vector3).z - pos.z).length()
			if dist < (hw + float(p["hw"])) * 0.72:
				return 0

	_spawn_card(sp, pos, hw, -1)
	return 1


func _try_plant_shelf(route: Node, side: float, z: float, lat: float, y: float, s_in: float, s_out: float,
		tier: int, kind: String, rocks: Array[Dictionary]) -> int:
	var sp := _pick_sprite(kind)
	if sp.is_empty():
		return 0
	var hw: float = float(sp["metres"].x) * 0.42
	if lat - hw < s_in + 0.04 or lat + hw > s_out - 0.06:
		return 0

	var pos := Vector3(route.center_x(z) + side * lat, y, z)
	for r in rocks:
		if int(r["tier"]) != tier or r["side"] != side:
			continue
		var rp: Vector3 = r["world_pos"]
		if Vector2(rp.x - pos.x, rp.z - pos.z).length() < hw + float(r["radius"]) + 0.06:
			return 0
	for p in _placed:
		if int(p["tier"]) == tier:
			var dist := Vector2((p["pos"] as Vector3).x - pos.x, (p["pos"] as Vector3).z - pos.z).length()
			if dist < hw + float(p["hw"]) + 0.08:
				return 0

	_spawn_card(sp, pos, hw, tier)
	return 1


func _spawn_card(sp: Dictionary, pos: Vector3, hw: float, tier: int) -> void:
	var card := MeshInstance3D.new()
	card.name = "Plant_%s_%d" % [sp["name"], _placed.size()]
	card.mesh = sp["mesh"]
	card.material_override = sp["material"]
	var flip := -1.0 if _rng.randf() < 0.5 else 1.0
	card.transform = Transform3D(Basis.from_scale(Vector3(flip, 1.0, 1.0)), pos)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(card)
	_placed.append({"label": card.name, "pos": pos, "hw": hw, "tier": tier})


func _load_assets() -> void:
	if not _sprites.is_empty():
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_JSON))
	var sprites_dict: Dictionary = manifest["sprites"]
	var names := sprites_dict.keys()
	names.sort()
	for sname: String in names:
		var entry: Dictionary = sprites_dict[sname]
		var metres := Vector2(entry["metres"][0], entry["metres"][1])
		var quad := QuadMesh.new()
		quad.size = metres
		quad.center_offset = Vector3(0, metres.y * 0.5, 0)
		var mat := ShaderMaterial.new()
		mat.shader = SPRITE_SHADER
		mat.set_shader_parameter("sprite_tex", load(TEX_ROOT + entry["albedo"]))
		_sprites.append({
			"name": sname,
			"kind": entry["kind"],
			"metres": metres,
			"mesh": quad,
			"material": mat,
		})
