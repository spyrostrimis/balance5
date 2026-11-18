extends Node3D
## Composition test on the integrated canyon (ChatGPT road + Trellis boulders).
## Re-lays the inherited D4b modules along a stronger S-curve, replaces the painted right cards with
## stepped stone courses, closes the far road with a right gateway and changes camera, sun and atmosphere.
## Keys: C toggles the original camera, V cycles atmosphere, B toggles the sun direction.

const CanyonRoute := preload("res://scripts/canyon_route.gd")
const ATMOSPHERES: Array[String] = ["volumetric", "overlay", "off"]

## Route the D4b assembler used. Every inherited module was placed against it.
const D4B_AMPLITUDE := 0.65
const D4B_FREQUENCY := 0.22
const WALL_SETBACK := 1.54

@export var route: Resource
@export var right_wall_z: Array[float] = [11.7, 5.5, -0.7, -6.4]
@export var right_gateway_z := -15.6
## Default off: at 0.008–0.018 global volumetric fog only hazed the walls and drew no visible shafts.
@export_enum("volumetric", "overlay", "off") var atmosphere := "off"
@export var backlit_sun := true
@export var fog_density := 0.012
## Thinner exponential fog and rock distance haze. The steeper camera sees more wall beyond 16 m,
## and the D4b exponential fog washed it to a flat beige. Zero disables that fog.
@export var clear_air := true
@export var exponential_fog_density := 0.0
@export var rock_haze_strength := 0.1

var _d4b_route: Resource
var _commander: Node3D ## composition_commander.gd
var _camera: Node3D ## composition_camera.gd
var _sun: DirectionalLight3D
var _sun_d4b: Transform3D
var _environment: Environment
var _added_modules: Array[MeshInstance3D] = []


func _ready() -> void:
	_d4b_route = CanyonRoute.new()
	_d4b_route.amplitude = D4B_AMPLITUDE
	_d4b_route.frequency = D4B_FREQUENCY
	if route == null:
		route = CanyonRoute.new()

	_commander = $BlueCommander
	_camera = $CameraRig
	_sun = $DesertSun
	_sun_d4b = _sun.transform
	var world := $WorldEnvironment as WorldEnvironment
	_environment = world.environment.duplicate() as Environment
	world.environment = _environment

	_relay_modules()
	_retire_right_cards()
	_build_right_wall()
	_route_ground()
	if clear_air:
		_environment.fog_enabled = exponential_fog_density > 0.0
		_environment.fog_density = exponential_fog_density
		# One shared rock material covers the terraces, gateways and D4b boulders.
		var rock := ($Roadside3DKits/TerraceLeft_0 as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
		rock.set_shader_parameter("haze_strength", rock_haze_strength)

	_commander.route = route
	_commander.global_position.x = route.center_x(_commander.global_position.z)
	_camera.route = route
	_camera.snap()

	set_atmosphere(atmosphere)
	set_backlit_sun(backlit_sun)


func set_atmosphere(mode: String) -> void:
	atmosphere = mode
	_environment.volumetric_fog_enabled = mode == "volumetric"
	if _environment.volumetric_fog_enabled:
		_environment.volumetric_fog_density = fog_density
		_environment.volumetric_fog_albedo = Color(1.0, 0.86, 0.66)
		_environment.volumetric_fog_emission = Color.BLACK
		_environment.volumetric_fog_anisotropy = 0.7
		_environment.volumetric_fog_length = 48.0
		_environment.volumetric_fog_ambient_inject = 0.0
		_environment.volumetric_fog_sky_affect = 0.0
	($AtmosphereLayer/GodRaysOverlay as CanvasItem).visible = mode == "overlay"
	($AtmosphereLayer/DustMotes as CanvasItem).visible = mode != "off"


func set_backlit_sun(enabled: bool) -> void:
	backlit_sun = enabled
	if enabled:
		# Same 42° elevation as D4b, swung round to shine from ahead-right toward the camera.
		_sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-42.0), deg_to_rad(145.0), 0.0)), Vector3.ZERO)
	else:
		_sun.transform = _sun_d4b


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_C:
			_camera.set_original(not _camera.use_original)
		KEY_V:
			set_atmosphere(ATMOSPHERES[(ATMOSPHERES.find(atmosphere) + 1) % ATMOSPHERES.size()])
		KEY_B:
			set_backlit_sun(not backlit_sun)
		_:
			return
	get_viewport().set_input_as_handled()


## Moves every route-relative module from the D4b curve to the composition route.
func _relay_modules() -> void:
	for node in $Roadside3DKits.get_children():
		var mesh := node as MeshInstance3D
		var z := mesh.position.z
		mesh.position.x += route.center_x(z) - _d4b_route.center_x(z)
		# The assembler stored yaw = -heading. Keep each module's own offset and align it with the new heading.
		mesh.rotation.y += _d4b_route.heading(z) + route.heading(z)
	for node in $DioramaProps.get_children():
		var prop := node as Node3D
		prop.position.x += route.center_x(prop.position.z) - _d4b_route.center_x(prop.position.z)
	for path in ["RightButtress", "ChatGPTBoulder_HF_Trellis2", "ChatGPTBoulder_Trellis3DNet"]:
		var module := get_node(path) as Node3D
		var z := module.position.z
		module.position.x += route.center_x(z) - _d4b_route.center_x(z)
		module.rotation.y += route.heading(z) - _d4b_route.heading(z)


func _retire_right_cards() -> void:
	for wing in $DioramaWings.get_children():
		(wing as Node3D).visible = false
	for node in $Roadside3DKits.get_children():
		if node.name.begins_with("TerraceRight_"):
			(node as Node3D).visible = false


## Tall right courses from the left terrace meshes, turned to face the road, plus a right gateway.
func _build_right_wall() -> void:
	var left_a := $Roadside3DKits/TerraceLeft_0 as MeshInstance3D
	var left_b := $Roadside3DKits/TerraceLeft_1 as MeshInstance3D
	var bluff := $Roadside3DKits/GatewayBluffLeft as MeshInstance3D
	for i in right_wall_z.size():
		var source := left_b if i % 2 == 0 else left_a
		_add_module("TerraceRightTall_%d" % i, source, right_wall_z[i], 0.0)
	_add_module("GatewayBluffRight", bluff, right_gateway_z, 0.12)


func _add_module(module_name: String, source: MeshInstance3D, z: float, extra_yaw: float) -> void:
	var module := MeshInstance3D.new()
	module.name = module_name
	module.mesh = source.mesh
	module.set_surface_override_material(0, source.get_surface_override_material(0))
	module.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	module.position = Vector3(route.center_x(z) + WALL_SETBACK, 0.0, z)
	module.rotation.y = PI + route.heading(z) + extra_yaw
	$Roadside3DKits.add_child(module)
	_added_modules.append(module)


func _route_ground() -> void:
	var ground := $GroundFloorMesh as MeshInstance3D
	var material := ground.get_surface_override_material(0) as ShaderMaterial
	route.apply_to_ground(material)
	# The real right wall now casts the road shadow. Drop the painted stand-in.
	material.set_shader_parameter("painted_right_shadow_strength", 0.0)
