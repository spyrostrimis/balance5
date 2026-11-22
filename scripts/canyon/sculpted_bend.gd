@tool
extends Node3D
## The scene markers place imported pieces. Only the small repeated dressing is batched.

const KIT := preload("res://assets/models/sculpted_bend/bend_kit.glb")
const STRATA := preload("res://assets/shaders/sculpted_bend_strata.gdshader")
const SANDSTONE := preload("res://assets/textures/canyon_pbr/chatgpt_sandstone_albedo.png")
const ROAD_WIDTH := 3.1
const ROAD_START := 15.0

@export var road_end := -18.9
@export var start_with_painted_vista := false
@onready var _route = $Route

var _source_meshes: Dictionary[StringName, Mesh] = {}
var _road: Array[MultiMeshInstance3D] = []
var _raised_transforms: Array = []
var _flat := false


func _ready() -> void:
	var kit := KIT.instantiate()
	for part: MeshInstance3D in kit.get_children():
		_source_meshes[part.name] = part.mesh
	kit.free()
	_make_ground()
	_place_scenery()
	_make_solid_terrain()
	_make_dressing(road_end)
	set_painted_vista(start_with_painted_vista)
	if not Engine.is_editor_hint():
		_make_navigation_floor()
		$BlueCommander.route = _route
		$BlueCommander.position.x = _route.center_x($BlueCommander.position.z)
		$CameraRig.route = _route
		$CameraRig.snap()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_C:
			$CameraRig.set_parallel_view(not $CameraRig.parallel_view)
		KEY_R:
			set_road_flat(not _flat)
		KEY_V:
			set_painted_vista(not $PaintedVista.visible)
		_:
			return
	get_viewport().set_input_as_handled()


func set_painted_vista(painted: bool) -> void:
	for group: Node3D in [$Landforms, $Bedrock]:
		for element: Node3D in group.get_children():
			if element.get_meta("distant", false):
				element.visible = not painted
	$VistaArch.visible = not painted
	$PaintedVista.visible = painted


func set_road_flat(flat: bool) -> void:
	_flat = flat
	for variant in _road.size():
		for i in _road[variant].multimesh.instance_count:
			var pose: Transform3D = _raised_transforms[variant][i]
			if flat:
				pose.basis.y *= 0.075
				pose.origin.y = pose.origin.y * 0.075 + 0.002
			_road[variant].multimesh.set_instance_transform(i, pose)


func _place_scenery() -> void:
	for marker: Marker3D in $Landforms.get_children():
		var model := MeshInstance3D.new()
		model.mesh = _source_meshes[marker.get_meta("part", &"shelf0")]
		marker.add_child(model)
	for marker: Marker3D in $Succulents.get_children():
		var model := MeshInstance3D.new()
		model.mesh = _source_meshes[marker.get_meta("part", &"plant0")]
		var material := model.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.46
		material.albedo_color = Color.WHITE.lerp(Color("#77958b"), marker.get_meta("coolness", 0.25))
		model.material_override = material
		marker.add_child(model)


func _make_ground() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(58):
		for col in range(54):
			var a := _ground_point(col - 27, 20 - row)
			var b := _ground_point(col - 26, 20 - row)
			var c := _ground_point(col - 26, 19 - row)
			var d := _ground_point(col - 27, 19 - row)
			for point: Vector3 in [a, c, b, a, d, c]:
				surface.add_vertex(point)
	surface.generate_normals()
	var sand := $GroundFloorMesh.get_surface_override_material(0) as ShaderMaterial
	$GroundFloorMesh.mesh = surface.commit()
	_route.apply_to_material(sand)
	sand.set_shader_parameter("player_pos", Vector3(0, 0, 6))
	# The commander updates the existing ground contact uniform on its surface override.
	$GroundFloorMesh.set_surface_override_material(0, sand)


func _make_navigation_floor() -> void:
	# Give the navigation bake only the inside of the corridor. The collision box
	# under the walk is deliberately wider and would bake disconnected exterior islands.
	var limits: Vector2 = $Corridor.z_limits
	var half: float = _route.half_width + 0.06
	var faces := PackedVector3Array()
	var count := ceili((limits.y - limits.x) / 0.2)
	for i in count:
		var z0 := lerpf(limits.y, limits.x, float(i) / count)
		var z1 := lerpf(limits.y, limits.x, float(i + 1) / count)
		var x0: float = _route.center_x(z0)
		var x1: float = _route.center_x(z1)
		var a := Vector3(x0 - half, 0, z0)
		var b := Vector3(x0 + half, 0, z0)
		var c := Vector3(x1 + half, 0, z1)
		var d := Vector3(x1 - half, 0, z1)
		faces.append_array([a, c, b, a, d, c])
	var ribbon := ConcavePolygonShape3D.new()
	ribbon.set_faces(faces)
	var shape := CollisionShape3D.new()
	shape.shape = ribbon
	$NavigationFloor.add_child(shape)


func _ground_point(x: float, z: float) -> Vector3:
	var lip := -19.7 - 0.9 * cos((x - 6.2) * 0.57) + 0.28 * sin(x * 1.54)
	var depth := smoothstep(0.0, 7.0, lip - z) * (8.0 + 1.7 * cos(x * 0.36))
	var shoulder := smoothstep(2.2, 5.1, absf(x - _route.center_x(z))) * (0.13 + sin(z * 1.7 + x * 0.75) * 0.11)
	return Vector3(x, shoulder - depth, z)


func _make_dressing(end_z: float) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 9181
	var transforms: Array = [[], [], [], [], []]
	var colours: Array = [[], [], [], [], []]
	var z := ROAD_START
	var row := 0
	while z > end_z:
		var spacing := random.randf_range(0.255, 0.335)
		var half := _road_half_width(z)
		var across := -half
		if row % 2 == 1:
			across -= 0.17
		while across < half - 0.1:
			var width := minf(random.randf_range(0.33, 0.54), half - across)
			var lateral := across + width * 0.5
			across += width
			if width < 0.23 or (absf(lateral) > half - 0.12 and random.randf() < 0.09):
				continue
			var variant := random.randi_range(0, 4)
			var dims := Vector3(width * 1.14, random.randf_range(0.042, 0.063), spacing * random.randf_range(1.04, 1.23))
			var pose := _road_pose(z + random.randf_range(-0.026, 0.026), lateral, dims, -0.013,
				random.randf_range(-0.21, 0.21) + (PI if row % 2 == 0 else 0.0))
			transforms[variant].append(pose)
			var tint := random.randf()
			colours[variant].append(Color("#cdb8ad").lerp(Color("#fff7e3"), tint))
		row += 1
		z -= spacing
	for variant in 5:
		_road.append(_batch("Cobbles%d" % variant, "stone%d" % variant, transforms[variant], colours[variant]))
	_raised_transforms = transforms

	var curb_poses: Array[Transform3D] = []
	var curb_tints: Array[Color] = []
	for side: float in [-1.0, 1.0]:
		z = ROAD_START + side * 0.2
		while z > end_z:
			var length := random.randf_range(0.51, 0.72)
			# Intentional open joints at the first two pockets and the inside of the bend.
			if absf(z - (2.0 if side > 0.0 else 5.1)) > 0.42 and absf(z + 6.5) > 0.26:
				var bottom := -0.071 if absf(z - 3.4) < 0.42 else -0.021
				var yaw := 0.36 if absf(z - 4.0) < 0.34 else random.randf_range(-0.08, 0.08)
				curb_poses.append(_road_pose(z, side * (_road_half_width(z) + 0.08), Vector3(0.32, random.randf_range(0.11, 0.17), length),
					bottom, yaw + (PI if side < 0.0 else 0.0)))
				curb_tints.append(Color("#d6cdc1").lerp(Color("#fff4e6"), random.randf()))
			z -= length * 0.91 + 0.027
	_batch("Curb", "curb0", curb_poses, curb_tints)
	if end_z < -18.0:
		_make_overlook_rim()
	_scatter_gravel(random, end_z)


func _road_half_width(z: float) -> float:
	return ROAD_WIDTH * 0.5 + smoothstep(0.0, 4.5, -z - 13.8) * 0.58


func _make_overlook_rim() -> void:
	var poses: Array[Transform3D] = []
	var colours: Array[Color] = []
	var end_z := road_end - 0.36
	for i in 10:
		var lateral := (float(i) - 4.5) * 0.475
		var z := end_z + lateral * lateral * 0.10
		var pose := _road_pose(z, lateral, Vector3(0.34, 0.26 + (i % 3) * 0.035, 0.67), -0.046, PI * 0.5)
		poses.append(pose)
		colours.append(Color("#d0b8a6").lerp(Color("#fff8e9"), float(i % 4) / 3.0))
	_batch("OverlookRim", "curb0", poses, colours)


func _scatter_gravel(random: RandomNumberGenerator, end_z: float) -> void:
	var poses: Array[Transform3D] = []
	var colours: Array[Color] = []
	for side: float in [-1.0, 1.0]:
		for cluster in 24:
			var z := random.randf_range(end_z, 13.0)
			var lateral := side * (_road_half_width(z) + random.randf_range(0.28, 1.38))
			for pebble in random.randi_range(2, 5):
				var size := random.randf_range(0.05, 0.19)
				poses.append(_road_pose(z + random.randf_range(-0.30, 0.30),
					lateral + random.randf_range(-0.22, 0.22), Vector3(size, size * 0.29, size * 0.73),
					0.008, random.randf_range(0.0, TAU)))
				colours.append(Color("#a98b75").lerp(Color("#e8d2b2"), random.randf()))
	_batch("VergeGravel", "stone3", poses, colours)


func _road_pose(z: float, x: float, dims: Vector3, y: float, yaw: float) -> Transform3D:
	var tangent := Basis(Vector3.UP, _route.heading(z))
	return Transform3D((tangent * Basis(Vector3.UP, yaw)).scaled_local(dims),
		Vector3(_route.center_x(z), y, z) + tangent.x * x)


func _batch(label: String, part: StringName, poses: Array, colours: Array) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = _source_meshes[part]
	batch.instance_count = poses.size()
	for i in poses.size():
		batch.set_instance_transform(i, poses[i])
		batch.set_instance_color(i, colours[i])
	instance.multimesh = batch
	var material := batch.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	material.vertex_color_use_as_albedo = true
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	instance.material_override = material
	$Dressing.add_child(instance)
	return instance


func _make_solid_terrain() -> void:
	var stone := ShaderMaterial.new()
	stone.shader = STRATA
	stone.set_shader_parameter("sandstone", SANDSTONE)
	for marker: Marker3D in $Bedrock.get_children():
		var form := MeshInstance3D.new()
		var stages: int = marker.get_meta("stages", 6)
		form.mesh = _strata_mesh(marker.scale, stages, String(marker.name).hash())
		form.scale = Vector3.ONE / marker.scale
		form.material_override = stone
		marker.add_child(form)
	var arch := MeshInstance3D.new()
	arch.mesh = _arch_mesh()
	arch.material_override = stone
	$VistaArch.add_child(arch)


func _strata_mesh(size: Vector3, stages: int, seed_value: int) -> ArrayMesh:
	# Horizontal cuts and wide footings keep the cliff scans seated in solid rock.
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var ring: Array[Vector2] = []
	const SIDES := 18
	for side in SIDES:
		var a := (float(side) + random.randf_range(-0.23, 0.23)) * TAU / SIDES
		var cut := random.randf_range(0.83, 1.11)
		ring.append(Vector2(cos(a), sin(a)) * cut)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var old: Array[Vector3] = []
	for step in stages + 1:
		var t := float(step) / stages
		var taper := lerpf(0.59, 0.39, t) + (0.025 if step % 2 == 0 else -0.014)
		var next: Array[Vector3] = []
		for side in SIDES:
			var variation := random.randf_range(0.94, 1.08) * taper
			var p := ring[side] * variation + Vector2(t * 0.11, -t * 0.10)
			next.append(Vector3(p.x * size.x, (t + random.randf_range(-0.03, 0.03)) * size.y, p.y * size.z))
		if not old.is_empty():
			for side in SIDES:
				var j := (side + 1) % SIDES
				_add_quad(surface, old[side], old[j], next[j], next[side])
		old = next
	for side in SIDES:
		_add_triangle(surface, old[side], old[(side + 1) % SIDES],
			Vector3(0.11 * size.x, size.y, -0.10 * size.z))
	surface.generate_normals()
	return surface.commit()


func _arch_mesh() -> ArrayMesh:
	# Hand-shaped sandstone span. Inner and outer edges are extended down into the valley floor.
	var inner := [Vector2(-3.2, -8), Vector2(-3.0, -1.4), Vector2(-2.65, 0.65),
		Vector2(-1.55, 2.0), Vector2(-0.15, 2.48), Vector2(1.44, 2.37),
		Vector2(2.59, 1.36), Vector2(3.0, -0.43), Vector2(3.07, -8)]
	var outer := [Vector2(-7.2, -8), Vector2(-6.0, -1.32), Vector2(-5.58, 1.88),
		Vector2(-4.58, 3.67), Vector2(-2.22, 4.29), Vector2(0.60, 4.18),
		Vector2(2.87, 3.96), Vector2(5.49, 2.70), Vector2(6.32, -8)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in inner.size() - 1:
		var a := Vector3(inner[i].x, inner[i].y, 1.4 + sin(i * 2.07) * 0.41)
		var b := Vector3(outer[i].x, outer[i].y, 1.91 + cos(i * 1.7) * 0.40)
		var c := Vector3(outer[i + 1].x, outer[i + 1].y, 1.91 + cos((i + 1) * 1.7) * 0.40)
		var d := Vector3(inner[i + 1].x, inner[i + 1].y, 1.4 + sin((i + 1) * 2.07) * 0.41)
		var depth := Vector3(-0.62, 0.0, -4.1)
		var midpoint := (a + b + c + d) * 0.25 + Vector3(0, 0.17, 0.65 + cos(i * 1.3) * 0.25)
		_add_triangle(surface, a, b, midpoint)
		_add_triangle(surface, b, c, midpoint)
		_add_triangle(surface, c, d, midpoint)
		_add_triangle(surface, d, a, midpoint)
		_add_quad(surface, b, b + depth, c + depth, c)
		_add_quad(surface, a, d, d + depth, a + depth)
		_add_quad(surface, d + depth, c + depth, b + depth, a + depth)
	surface.generate_normals()
	return surface.commit()


func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_triangle(surface, a, b, c)
	_add_triangle(surface, a, c, d)


func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.set_smooth_group(-1)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
