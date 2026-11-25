extends Node3D
## Scatters pixel-art bushes and grass tufts (tools/python/build_kit_sprites.py) in the 3D kit canyon:
##   - in clumps on the open sand between the curbs and the cliffs, on both sides of the road,
##   - along the foot of the retaining wall,
##   - on the paved terrace and on the cliff ledges in front of each row of blocks.
## Each plant is a camera-facing card (assets/shaders/canyon_kit_sprite.gdshader) with its foot on the
## ground, a small random size change and a gentle sway. Spots too close to a boulder are skipped.

const DATA := "res://assets/textures/kit_sprites/kit_sprites.json"
const TEX := "res://assets/textures/kit_sprites/%s_%s.png"
const SPRITE_SHADER := preload("res://assets/shaders/canyon_kit_sprite.gdshader")

@export var z_start := 12.5
@export var z_end := -14.5
## Sand strip between the curbs' outer edge and the retaining wall (metres from the route centre).
@export var strip := Vector2(1.6, 2.55)
@export var clump_every := Vector2(1.0, 2.2)
@export var ledge_every := Vector2(1.6, 3.4)
@export var keep_away := 0.85
@export var random_seed := 23
@export var look := "goal":
	set(value):
		look = value
		_apply_look()

var _sprites: Array[Dictionary] = []   # {name, kind, metres: Vector2, mesh, material}
var _rng := RandomNumberGenerator.new()


## cliffs: the canyon_cliffs.gd node (for wall and ledge positions). avoid: world positions to keep clear.
func build(route: Node, cliffs: Node, avoid: Array[Vector3]) -> void:
	for child in get_children():
		child.queue_free()
	_load()
	_rng.seed = random_seed
	var count := 0
	for side in [-1.0, 1.0]:
		# Clumps on the sand strip: one big plant with smaller ones around it, or a patch of grass.
		var z := z_start
		while z > z_end:
			z -= _rng.randf_range(clump_every.x, clump_every.y)
			var lateral := _rng.randf_range(strip.x, strip.y)
			var pieces := _rng.randi_range(1, 4)
			for i in pieces:
				var kind := "bush" if (i == 0 and _rng.randf() < 0.7) else "grass"
				var dz := _rng.randf_range(-0.45, 0.45) if i > 0 else 0.0
				var dl := _rng.randf_range(-0.3, 0.3) if i > 0 else 0.0
				count += _plant(route, side, z + dz, clampf(lateral + dl, strip.x, strip.y), 0.0, kind, avoid)
		# The foot of the retaining wall: grass and small bushes against the stone.
		z = z_start
		while z > z_end:
			z -= _rng.randf_range(0.7, 1.6)
			count += _plant(route, side, z, cliffs.wall_front - 0.12, 0.0, "grass" if _rng.randf() < 0.6 else "bush", avoid, 0.8)
		# Terrace and ledges: the paved terrace (row 0) and the tread in front of each higher row.
		for k in cliffs.max_courses:
			z = z_start
			while z > z_end:
				z -= _rng.randf_range(ledge_every.x, ledge_every.y)
				if k > cliffs.courses_at(z):
					continue
				var lat: float = cliffs.wall_front + 0.25 + k * cliffs.course_setback
				var y: float = cliffs.wall_height + k * cliffs.course_rise
				count += _plant(route, side, z, lat, y, "bush" if _rng.randf() < 0.55 else "grass", avoid, 0.9)
	print("Bushes: %d plants, look=%s" % [count, look])


func _plant(route: Node, side: float, z: float, lateral: float, y: float, kind: String, avoid: Array[Vector3], scale_mult := 1.0) -> int:
	var pos := Vector3(route.center_x(z) + side * lateral, y, z)
	for p in avoid:
		if Vector2(p.x - pos.x, p.z - pos.z).length() < keep_away:
			return 0
	var options := _sprites.filter(func(s: Dictionary) -> bool: return s["kind"] == kind)
	if options.is_empty():
		return 0
	var sprite: Dictionary = options[_rng.randi() % options.size()]
	var card := MeshInstance3D.new()
	card.mesh = sprite["mesh"]
	card.material_override = sprite["material"]
	var s := _rng.randf_range(0.85, 1.15) * scale_mult
	card.transform = Transform3D(Basis.from_scale(Vector3(s * (-1.0 if _rng.randf() < 0.5 else 1.0), s, s)), pos - Vector3(0, 0.01, 0))
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(card)
	return 1


func _load() -> void:
	if not _sprites.is_empty():
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	for entry: Dictionary in data["sprites"]:
		var metres := Vector2(entry["metres"][0], entry["metres"][1])
		var quad := QuadMesh.new()
		quad.size = metres
		quad.center_offset = Vector3(0, metres.y * 0.5, 0)  # foot pivot
		var material := ShaderMaterial.new()
		material.shader = SPRITE_SHADER
		_sprites.append({"name": entry["name"], "kind": entry["kind"], "mesh": quad, "material": material})
	_apply_look()


func _apply_look() -> void:
	for sprite in _sprites:
		var path := TEX % [sprite["name"], look]
		if ResourceLoader.exists(path):
			(sprite["material"] as ShaderMaterial).set_shader_parameter("sprite_tex", load(path))
