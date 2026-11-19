extends "res://scripts/canyon/canyon_pixel_ab.gd"
## Free-pack trial on the HD-2D Pixel A/B scene: downloaded models placed in canyon v2, with every A/B key
## still working (1-5 surface sets, R raised stones).
##   P  show / hide the pack models (PIXEL_AB_PACKS=0 starts hidden)
## craftpix low-poly desert mountains (licence: assets/models/packs/craftpix_desert/LICENSE_URL.txt) wear the
## canyon rock material, so they take the current set's strata and slate. The Grand Canyon photo scan sits by
## the road twice: left with the canyon rock material, right with its own scanned texture. The scan has no
## confirmed licence and stays local (assets/models/packs_local/, ignored by git); it is skipped when missing.

const ROCK_MATERIAL := preload("res://assets/materials/canyon_rock.tres")
const CRAFTPIX := "res://assets/models/packs/craftpix_desert/%s.glb"
const SCAN := "res://assets/models/packs_local/grand_canyon_rock/%s.glb"

## [model path, z, lateral offset from the route centre, yaw degrees, uniform scale, use canyon rock material]
const PLACEMENTS := [
	[CRAFTPIX % "Plateau_desert_002", -46.0, 7.0, -15.0, 1.6, true],  # distant mesa, right of the exit vista
	[CRAFTPIX % "Mountain_desert_008", -8.0, 12.0, -80.0, 1.1, true], # pinnacles rising behind the right wall
	[CRAFTPIX % "Mountain_desert_002", -24.0, -12.0, 20.0, 1.0, true],# bluff left of the exit vista
	[SCAN % "grand_canyon_rock_shaded", 2.8, -1.45, 30.0, 0.5, true], # scan, canyon rock material
	[SCAN % "grand_canyon_rock", 2.4, 1.35, -40.0, 0.5, false],       # scan, its own photo texture
]

var _pack_root: Node3D


func _ready() -> void:
	_pack_root = Node3D.new()
	_pack_root.name = "PackModels"
	add_child(_pack_root)
	var route := get_node(route_path)
	for entry: Array in PLACEMENTS:
		if not ResourceLoader.exists(entry[0]):
			push_warning("Pack model missing (local only?): %s" % entry[0])
			continue
		var model: Node3D = (load(entry[0]) as PackedScene).instantiate()
		var z: float = entry[1]
		model.position = Vector3(route.center_x(z) + entry[2], 0.0, z)
		model.rotation_degrees.y = entry[3]
		model.scale = Vector3.ONE * float(entry[4])
		if entry[5]:
			for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
				mesh.set_surface_override_material(0, ROCK_MATERIAL)
		_pack_root.add_child(model)
	super()
	_pack_root.visible = OS.get_environment("PIXEL_AB_PACKS") != "0"


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_pack_root.visible = not _pack_root.visible
		get_viewport().set_input_as_handled()
		return
	super(event)
