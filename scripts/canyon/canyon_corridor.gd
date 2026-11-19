extends Node3D
## Builds the walkable corridor from the route at runtime:
## - a StaticBody3D with a continuous wall ribbon along both edges plus end caps, so movement is stopped by
##   physics instead of a position clamp, for the commander and for any later units;
## - a NavigationRegion3D baked from the static colliders (floor, these walls and module blockers),
##   so paths stay in the corridor and route around boulders.
## Rebuilds when the route changes.

const NAVIGATION_GROUP := &"canyon_navigation_source"

@export var route_path := NodePath("../Route")
## Walkable span along Z. Matches the commander's D4b limits.
@export var z_limits := Vector2(-14.5, 7.5)
## Radius of the agents the walls must contain. The commander capsule is 0.28 m.
@export var agent_radius := 0.28
## Spacing of the wall ribbon's vertical edges along Z.
@export var ribbon_step := 0.25
@export var wall_thickness := 0.5
@export var wall_height := 3.0
## Static colliders outside this node that shape the navigation mesh.
@export var navigation_sources: Array[NodePath] = [NodePath("../GroundFloor"), NodePath("../Layout")]
## Navigation cell size. Recast erodes by whole cells, so keep it well below agent_radius.
@export var navigation_cell := 0.1
## Navigation polygons above this height (blocker and wall tops) are discarded after baking.
@export var max_floor_height := 0.5

var _route: Node
var _body: StaticBody3D
var _region: NavigationRegion3D


func _ready() -> void:
	_route = get_node(route_path)
	_route.route_changed.connect(rebuild)
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, navigation_cell)
	NavigationServer3D.map_set_cell_height(map, navigation_cell)
	for path in navigation_sources:
		var source := get_node_or_null(path)
		if source:
			source.add_to_group(NAVIGATION_GROUP)
	rebuild()


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_body = StaticBody3D.new()
	_body.name = "Walls"
	add_child(_body)
	_region = NavigationRegion3D.new()
	_region.name = "Navigation"
	add_child(_region)

	var half_width: float = _route.half_width
	var inner := half_width + agent_radius
	# One continuous double-sided ribbon per side. Separate rotated boxes left seams on the curves
	# that caught the capsule. The ribbon runs past both ends so the caps close the corners.
	var ribbon := PackedVector3Array()
	var samples := maxi(2, ceili((z_limits.y - z_limits.x + 2.0) / ribbon_step))
	var ribbon_step_z := (z_limits.y - z_limits.x + 2.0) / float(samples)
	for side: float in [-1.0, 1.0]:
		for i in samples:
			var z0 := z_limits.x - 1.0 + ribbon_step_z * float(i)
			var z1 := z0 + ribbon_step_z
			var x0: float = _route.center_x(z0) + side * inner
			var x1: float = _route.center_x(z1) + side * inner
			var a := Vector3(x0, -0.5, z0)
			var b := Vector3(x1, -0.5, z1)
			var c := Vector3(x1, wall_height, z1)
			var d := Vector3(x0, wall_height, z0)
			ribbon.append_array([a, b, c, a, c, d])
	var faces := ConcavePolygonShape3D.new()
	faces.backface_collision = true
	faces.set_faces(ribbon)
	var shape := CollisionShape3D.new()
	shape.name = "Edges"
	shape.shape = faces
	_body.add_child(shape)
	for end_z: float in [z_limits.x - agent_radius - wall_thickness * 0.5, z_limits.y + agent_radius + wall_thickness * 0.5]:
		var z := end_z
		_add_box(Vector3(inner * 2.0 + wall_thickness * 2.0, wall_height, wall_thickness),
			Transform3D(Basis.IDENTITY, Vector3(_route.center_x(z), wall_height * 0.5, z)))

	_body.add_to_group(NAVIGATION_GROUP)
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = NAVIGATION_GROUP
	mesh.cell_size = navigation_cell
	mesh.cell_height = navigation_cell
	mesh.agent_radius = ceilf(agent_radius / navigation_cell - 0.001) * navigation_cell
	mesh.agent_height = 1.2
	mesh.agent_max_climb = 0.2
	var min_x := INF
	var max_x := -INF
	for i in samples + 1:
		var cx: float = _route.center_x(z_limits.x - 1.0 + ribbon_step_z * float(i))
		min_x = minf(min_x, cx)
		max_x = maxf(max_x, cx)
	var margin := inner + wall_thickness
	mesh.filter_baking_aabb = AABB(Vector3(min_x - margin, -1.0, z_limits.x - 1.0),
		Vector3(max_x - min_x + margin * 2.0, wall_height + 2.0, z_limits.y - z_limits.x + 2.0))
	_region.navigation_mesh = mesh
	_region.bake_finished.connect(_keep_floor_polygons)
	# Bake after the Layout has instanced its modules and their blockers.
	_region.bake_navigation_mesh.call_deferred(false)


## Recast also marks the flat tops of blockers and walls as walkable islands. Keep only polygons on
## the canyon floor so closest-point queries and move orders never land on a boulder.
func _keep_floor_polygons() -> void:
	var baked := _region.navigation_mesh
	var vertices := baked.vertices
	var kept := NavigationMesh.new()
	kept.cell_size = baked.cell_size
	kept.cell_height = baked.cell_height
	kept.agent_radius = baked.agent_radius
	kept.agent_height = baked.agent_height
	kept.agent_max_climb = baked.agent_max_climb
	kept.vertices = vertices
	for i in baked.get_polygon_count():
		var polygon := baked.get_polygon(i)
		var on_floor := true
		for index in polygon:
			if vertices[index].y > max_floor_height:
				on_floor = false
				break
		if on_floor:
			kept.add_polygon(polygon)
	_region.navigation_mesh = kept


func _add_box(size: Vector3, xform: Transform3D) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = xform
	_body.add_child(shape)
