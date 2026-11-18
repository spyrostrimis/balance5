@tool
extends Node3D
## Instances module scenes along the route from placement data.
## Generated children are not owned by the scene, so the .tscn stays small and the layout
## follows any route edit in the editor and at runtime.

const LayoutData := preload("res://scripts/canyon/canyon_layout_data.gd")

@export var route_path: NodePath:
	set(value):
		route_path = value
		_queue_rebuild()
@export var data: LayoutData:
	set(value):
		if data and data.changed.is_connected(_queue_rebuild):
			data.changed.disconnect(_queue_rebuild)
		data = value
		if data:
			data.changed.connect(_queue_rebuild)
		_queue_rebuild()

var _pending := false


func _ready() -> void:
	var route = get_node_or_null(route_path)
	if route and not route.route_changed.is_connected(_queue_rebuild):
		route.route_changed.connect(_queue_rebuild)
	rebuild()


func rebuild() -> void:
	_pending = false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var route = get_node_or_null(route_path)
	if route == null or data == null:
		return
	for placement in data.placements:
		if placement == null or placement.scene == null:
			continue
		var module := placement.scene.instantiate() as Node3D
		module.name = placement.label if not placement.label.is_empty() else module.name
		var yaw := deg_to_rad(placement.yaw_offset_deg)
		if placement.align_to_route:
			yaw += route.heading(placement.z)
		var basis := Basis(Vector3.UP, yaw) * module.transform.basis * Basis.from_scale(placement.scale)
		module.transform = Transform3D(basis, Vector3(
			route.center_x(placement.z) + placement.lateral, placement.height, placement.z
		))
		if module is SpriteBase3D:
			(module as SpriteBase3D).modulate = placement.tint
			(module as SpriteBase3D).flip_h = placement.flip_h
		add_child(module)


func _queue_rebuild() -> void:
	if _pending or not is_inside_tree():
		return
	_pending = true
	rebuild.call_deferred()
