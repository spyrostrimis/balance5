class_name ForestClaimUnit
extends RtsCarbonUnit
## Carbon simulates in square map pixels. Only the outer visual anchor is projected.

var _visual_anchor: Node2D
var _counter_offset: Node2D


func mount(parent: Node2D) -> void:
	_visual_anchor = Node2D.new()
	_visual_anchor.scale = Vector2.ONE * 1.26
	_counter_offset = Node2D.new()
	parent.add_child(_visual_anchor)
	_visual_anchor.add_child(_counter_offset)
	_counter_offset.add_child(self)
	sync_visual()


func sync_visual() -> void:
	_visual_anchor.position = ForestClaimProjection.point(position)
	_counter_offset.position = -position


func _exit_tree() -> void:
	if is_instance_valid(_visual_anchor) and not _visual_anchor.is_queued_for_deletion():
		_visual_anchor.queue_free()


func tick(delta: float) -> void:
	super(delta)
	sync_visual()


func command_move(world_dest: Vector2) -> void:
	var dest_cell := grid.cell_of(world_dest)
	if not grid.is_walkable(dest_cell):
		return
	if not _line_walkable(world_dest, world_dest):
		world_dest = grid.center_of(dest_cell)
	super(world_dest)


func _draw_direction(dir: Vector2) -> Vector2:
	return ForestClaimProjection.GROUND.basis_xform(dir).normalized()


func _draw_slot(slot: Vector2) -> Vector2:
	return ForestClaimProjection.GROUND.basis_xform(slot * 1.67)


func _draw_origin() -> Vector2:
	return Vector2(0.0, -3.0 if role == Role.TANK else -5.0)


func _line_walkable(a: Vector2, b: Vector2) -> bool:
	var clearance := 8.7 if role == Role.TANK else 3.5
	for c in grid.cells_along(a, b, clearance):
		if not grid.is_walkable(c):
			return false
	return true


func _may_smooth_between(a: Vector2, b: Vector2, avoid_units: bool) -> bool:
	if not _line_walkable(a, b):
		return false
	if avoid_units:
		for crossed in grid.cells_along(a, b, 0.0):
			if not grid.is_free(crossed, self):
				return false
	return true


func _tank_step(direction: Vector2, displacement: Vector2, step: float, distance: float) -> Vector2:
	var curved := position + displacement
	if _line_walkable(position, curved) and grid.is_free(grid.cell_of(curved), self):
		return curved
	var straight := position + direction * minf(step * 0.6, distance)
	if _line_walkable(position, straight) and grid.is_free(grid.cell_of(straight), self):
		return straight
	return position


func _can_fire_at(enemy: RtsCarbonUnit) -> bool:
	for crossed in grid.cells_along(position, enemy.position, 0.0):
		if not grid.is_walkable(crossed):
			return false
	return true
