extends SceneTree
## One-time bootstrap for the flat canyon_v2 scene. Run headless from the project root:
##   Godot --path . --headless --script res://tools/godot/build_canyon_v2.gd
## It extracts shared resources from the D4b chain, converts the composition-test arrangement
## into route-relative placements and packs scenes/maps/canyon_v2.tscn. After that the outputs are
## ordinary files to edit by hand; rerunning overwrites them.

const D4B := "res://scenes/maps/desert_canyon_true_3d.tscn"
const ROAD := "res://scenes/maps/desert_canyon_chatgpt_road_test.tscn"
const BEND := "res://scenes/maps/desert_canyon_bend.tscn"
const Route := preload("res://scripts/canyon/canyon_route_path.gd")
const Layout := preload("res://scripts/canyon/canyon_layout.gd")
const LayoutData := preload("res://scripts/canyon/canyon_layout_data.gd")
const Placement := preload("res://scripts/canyon/canyon_placement.gd")
const Level := preload("res://scripts/canyon/canyon_level.gd")
const Camera := preload("res://scripts/canyon/canyon_camera.gd")

## Composition-test route: 2.0 * sin(0.22 z), sampled into an editable Bezier curve.
const ROUTE_AMPLITUDE := 2.0
const ROUTE_FREQUENCY := 0.22
const ROUTE_Z := Vector2(18.0, -30.0)
const ROUTE_STEP := 4.0

const MESH_SCENES := {
	"canyon_kit_test_d_TerraceLeftModule": "terrace_tall_a",
	"canyon_kit_test_d_TerraceLeftModuleB": "terrace_tall_b",
	"canyon_kit_test_d_GatewayBluffLeft": "gateway_bluff",
	"canyon_kit_test_d_BoulderCluster": "boulder_cluster",
	"canyon_kit_test_d_CurbStoneStrip": "curb_strip",
}
const SPRITE_SCENES := {
	"res://assets/textures/canyon_pbr/hd2d_bush_cluster.png": "bush_cluster",
	"res://assets/textures/canyon_pbr/d_sage_bush_2.png": "bush_sage",
}
## D4b modules hidden in the integrated scene or replaced by the right wall.
const SKIP := ["BoulderLeft_1", "BoulderRight_1", "BoulderLeft_2"]
const RIGHT_WALL_Z: Array[float] = [11.7, 5.5, -0.7, -6.4]


func _init() -> void:
	var ok := _build()
	quit(0 if ok else 1)


func _d4b_cx(z: float) -> float:
	return sin(z * 0.22) * 0.65


func _d4b_heading(z: float) -> float:
	return atan((_d4b_cx(z + 2.0) - _d4b_cx(z - 2.0)) / 4.0)


func _save(resource: Resource, path: String) -> bool:
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		push_error("Could not save %s: %s" % [path, error_string(err)])
		return false
	print("Saved ", path)
	return true


func _build() -> bool:
	var d4b := (load(D4B) as PackedScene).instantiate()
	var road := (load(ROAD) as PackedScene).instantiate()
	var bend := (load(BEND) as PackedScene).instantiate()

	# Shared resources.
	var rock := (d4b.get_node("Roadside3DKits/TerraceLeft_0") as MeshInstance3D).get_surface_override_material(0).duplicate() as ShaderMaterial
	rock.set_shader_parameter("haze_strength", 0.1)
	var ground := (road.get_node("GroundFloorMesh") as MeshInstance3D).get_surface_override_material(0).duplicate() as ShaderMaterial
	ground.resource_local_to_scene = false
	ground.set_shader_parameter("painted_right_shadow_strength", 0.0)
	var environment := (d4b.get_node("WorldEnvironment") as WorldEnvironment).environment.duplicate(true) as Environment
	environment.fog_enabled = false
	var lens := (bend.get_node("CameraRig") as Camera3D).attributes.duplicate() as CameraAttributesPractical
	var crater_material := (d4b.get_node("OrichalcumCraterGround") as MeshInstance3D).get_surface_override_material(0).duplicate()
	var vista_material := (d4b.get_node("BattlefieldVistaBackdrop") as MeshInstance3D).get_surface_override_material(0).duplicate()
	for pair in [
		[rock, "res://assets/materials/canyon_rock.tres"],
		[ground, "res://assets/materials/canyon_road_chatgpt.tres"],
		[environment, "res://assets/environments/canyon_clear_air.tres"],
		[lens, "res://assets/environments/canyon_lens.tres"],
		[crater_material, "res://assets/materials/orichalcum_crater_ground.tres"],
		[vista_material, "res://assets/materials/canyon_vista_backdrop.tres"],
	]:
		if not _save(pair[0], pair[1]):
			return false

	# Actors.
	var commander := d4b.get_node("BlueCommander").duplicate() as Node3D
	commander.transform = Transform3D.IDENTITY
	for child in commander.get_children():
		child.owner = commander
	var actor := PackedScene.new()
	actor.pack(commander)
	if not _save(actor, "res://scenes/actors/blue_commander_3d.tscn"):
		return false
	var camera := Camera3D.new()
	camera.name = "CameraRig"
	camera.set_script(Camera)
	camera.current = true
	camera.fov = 30.0
	camera.near = 0.2
	camera.far = 250.0
	camera.attributes = load("res://assets/environments/canyon_lens.tres")
	var camera_scene := PackedScene.new()
	camera_scene.pack(camera)
	if not _save(camera_scene, "res://scenes/actors/canyon_camera.tscn"):
		return false

	# Layout data converted to route-relative placements.
	var data := LayoutData.new()
	for node in d4b.get_node("Roadside3DKits").get_children():
		var mesh := node as MeshInstance3D
		if mesh.name.begins_with("TerraceRight_") or mesh.name in SKIP:
			continue
		var key := mesh.mesh.resource_name
		if not MESH_SCENES.has(key):
			push_error("No module scene for %s (%s)" % [mesh.name, key])
			return false
		var z := mesh.position.z
		# The D4b assembler stored yaw = -heading; keep each module's own offset from that.
		data.placements.append(_placement(mesh.name, MESH_SCENES[key], z, mesh.position.x - _d4b_cx(z),
			mesh.rotation.y + _d4b_heading(z), mesh.scale))
	for i in RIGHT_WALL_Z.size():
		data.placements.append(_placement("TerraceRightTall_%d" % i,
			"terrace_tall_b" if i % 2 == 0 else "terrace_tall_a", RIGHT_WALL_Z[i], 1.54, PI, Vector3.ONE))
	data.placements.append(_placement("GatewayBluffRight", "gateway_bluff", -15.6, 1.54, PI + 0.12, Vector3.ONE))
	for path in ["res://scenes/maps/right_buttress.tscn|RightButtress|1.2|-9.3|1.0",
			"res://scenes/maps/chatgpt_boulder_hf_trellis2.tscn|ChatGPTBoulder_HF_Trellis2|-1.25|4.85|0.75",
			"res://scenes/maps/chatgpt_boulder_trellis3dnet.tscn|ChatGPTBoulder_Trellis3DNet|2.05|4.65|0.8"]:
		var parts: PackedStringArray = (path as String).split("|")
		var z := float(parts[3])
		var p := _placement(parts[1], "", z, float(parts[2]) - _d4b_cx(z), -_d4b_heading(z), Vector3.ONE * float(parts[4]))
		p.scene = load(parts[0])
		data.placements.append(p)
	for node in d4b.get_node("DioramaProps").get_children():
		var sprite := node as Sprite3D
		var texture := sprite.texture.resource_path
		if not SPRITE_SCENES.has(texture):
			push_error("No bush scene for " + texture)
			return false
		var z := sprite.position.z
		var p := _placement(sprite.name, SPRITE_SCENES[texture], z, sprite.position.x - _d4b_cx(z), 0.0,
			Vector3.ONE * sprite.pixel_size / 0.005)
		p.align_to_route = false
		p.height = sprite.position.y
		p.tint = sprite.modulate
		p.flip_h = sprite.flip_h
		data.placements.append(p)
	if not _save(data, "res://scenes/canyon/canyon_v2_layout.tres"):
		return false

	# Level scene.
	var level := Node3D.new()
	level.name = "CanyonV2"
	level.set_script(Level)
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = load("res://assets/environments/canyon_clear_air.tres")
	_add(level, world)
	var sun := d4b.get_node("DesertSun").duplicate() as DirectionalLight3D
	# Backlit: same 42° elevation as D4b, from ahead-right toward the camera.
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-42.0), deg_to_rad(145.0), 0.0)), Vector3.ZERO)
	_add(level, sun)
	var route := Path3D.new()
	route.name = "Route"
	route.set_script(Route)
	route.curve = _route_curve()
	_add(level, route)
	var floor_body := d4b.get_node("GroundFloor").duplicate() as Node3D
	_add(level, floor_body)
	floor_body.get_child(0).owner = level
	var ground_mesh := d4b.get_node("GroundFloorMesh").duplicate() as MeshInstance3D
	ground_mesh.set_surface_override_material(0, load("res://assets/materials/canyon_road_chatgpt.tres"))
	_add(level, ground_mesh)
	var layout := Node3D.new()
	layout.name = "Layout"
	layout.set_script(Layout)
	_add(level, layout)
	layout.route_path = NodePath("../Route")
	layout.data = load("res://scenes/canyon/canyon_v2_layout.tres")
	for name in ["OrichalcumCraterGround", "CraterOrichalcumGlow", "BattlefieldVistaBackdrop"]:
		var vista := d4b.get_node(name).duplicate() as Node3D
		_add(level, vista)
	(level.get_node("OrichalcumCraterGround") as MeshInstance3D).set_surface_override_material(0, load("res://assets/materials/orichalcum_crater_ground.tres"))
	(level.get_node("BattlefieldVistaBackdrop") as MeshInstance3D).set_surface_override_material(0, load("res://assets/materials/canyon_vista_backdrop.tres"))
	var hero := (load("res://scenes/actors/blue_commander_3d.tscn") as PackedScene).instantiate() as Node3D
	hero.position = Vector3(0.0, 0.02, 6.0)
	_add(level, hero)
	var rig := (load("res://scenes/actors/canyon_camera.tscn") as PackedScene).instantiate() as Node3D
	rig.position = Vector3(0.0, 5.5, 17.9)
	_add(level, rig)
	var packed := PackedScene.new()
	if packed.pack(level) != OK:
		push_error("Could not pack canyon_v2")
		return false
	for n in [d4b, road, bend, level, commander, camera]:
		n.free()
	return _save(packed, "res://scenes/maps/canyon_v2.tscn")


func _add(level: Node, child: Node) -> void:
	level.add_child(child)
	child.owner = level


func _placement(label: String, scene_name: String, z: float, lateral: float, yaw: float, scale: Vector3) -> Resource:
	var p := Placement.new()
	p.label = label
	if not scene_name.is_empty():
		p.scene = load("res://scenes/canyon/modules/%s.tscn" % scene_name)
	p.z = z
	p.lateral = snappedf(lateral, 0.0001)
	p.yaw_offset_deg = snappedf(rad_to_deg(yaw), 0.001)
	p.scale = scale.snappedf(0.0001)
	return p


func _route_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	var z := ROUTE_Z.x
	while z >= ROUTE_Z.y - 0.001:
		var x := ROUTE_AMPLITUDE * sin(z * ROUTE_FREQUENCY)
		var dx_dz := ROUTE_AMPLITUDE * ROUTE_FREQUENCY * cos(z * ROUTE_FREQUENCY)
		# Bezier handles one third of a step along the tangent, walking toward -Z.
		var handle := Vector3(-dx_dz, 0.0, -1.0) * (ROUTE_STEP / 3.0)
		curve.add_point(Vector3(x, 0.0, z), -handle, handle)
		z -= ROUTE_STEP
	return curve
