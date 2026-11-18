extends Node3D
## Wires a flat canyon level together: the Route drives the ground shader, commander clamp and camera.
## Modules are placed by the Layout node from its layout data, so this script holds no geometry.

@export var route_path := NodePath("Route")
@export var ground_path := NodePath("GroundFloorMesh")
@export var commander_path := NodePath("BlueCommander")
@export var camera_path := NodePath("CameraRig")


func _ready() -> void:
	var route := get_node(route_path)
	var ground := get_node(ground_path) as MeshInstance3D
	route.apply_to_material(ground.get_surface_override_material(0) as ShaderMaterial)

	var commander := get_node(commander_path) as Node3D
	commander.route = route
	commander.global_position.x = route.center_x(commander.global_position.z)

	var camera := get_node(camera_path) as Node3D
	camera.route = route
	camera.snap()
