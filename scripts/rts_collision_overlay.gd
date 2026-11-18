extends Node2D
## Draws crisp color-coded collision outlines for water, buildings, cliffs, and units.

var _scene_root: Node2D


func setup(scene_root: Node2D) -> void:
	_scene_root = scene_root


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if _scene_root == null:
		return

	var obstacles := _scene_root.get_node_or_null("Obstacles")
	if obstacles != null:
		for child in obstacles.get_children():
			var color := _color_for_obstacle(child.name)
			_draw_body_shapes(child, color)

	var units := _scene_root.get_node_or_null("Units")
	if units != null:
		for faction in units.get_children():
			for unit in faction.get_children():
				var unit_color := Color(0.2, 0.95, 0.45, 0.9) if unit.name == "BlueTank" else Color(1.0, 0.78, 0.25, 0.85)
				_draw_unit_shapes(unit, unit_color)


func _color_for_obstacle(node_name: String) -> Color:
	if "Water" in node_name:
		return Color(0.15, 0.75, 1.0, 0.95)
	if "Turret" in node_name or "Building" in node_name:
		return Color(1.0, 0.25, 0.25, 0.95)
	return Color(1.0, 0.45, 0.9, 0.9)


func _draw_unit_shapes(node: Node, color: Color) -> void:
	_draw_body_shapes(node, color)
	for child in node.get_children():
		if child is StaticBody2D or child is CharacterBody2D:
			_draw_body_shapes(child, color)


func _draw_body_shapes(body: Node, color: Color) -> void:
	if not (body is CollisionObject2D):
		return
	var fill := Color(color.r, color.g, color.b, 0.16)
	for child in body.get_children():
		if child is CollisionPolygon2D and child.polygon.size() >= 3:
			var pts := PackedVector2Array()
			for p in child.polygon:
				pts.append(to_local(child.to_global(p)))
			draw_colored_polygon(pts, fill)
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, color, 2.0, true)
		elif child is CollisionShape2D and child.shape is CircleShape2D:
			var circle := child.shape as CircleShape2D
			var center := to_local(child.global_position)
			draw_circle(center, circle.radius, fill)
			draw_arc(center, circle.radius, 0.0, TAU, 32, color, 2.0, true)
