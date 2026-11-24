class_name PixelCamera2D
extends Camera2D
## Smooth pixel-snapped orthographic camera for the 2D RPG canyon study.
## Clamps within map bounds and rounds final coordinates to whole art pixels to prevent shimmer.

@export var target_path: NodePath
@export var follow_smooth: float = 10.0
@export var map_bounds: Rect2 = Rect2(0.0, 0.0, 1536.0, 1472.0)

var _target: Node2D = null
var _logical_pos: Vector2 = Vector2.ZERO
var _viewport_size: Vector2 = Vector2(960.0, 540.0)


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D
	if _target != null:
		_logical_pos = _target.global_position
		_apply_clamped_snapped_pos()


func set_target(node: Node2D) -> void:
	_target = node
	if _target != null:
		_logical_pos = _target.global_position
		_apply_clamped_snapped_pos()


func snap_immediately() -> void:
	if _target != null:
		_logical_pos = _target.global_position
	_apply_clamped_snapped_pos()


func set_resolution_zoom(zoom_scale: float, viewport_sz: Vector2i) -> void:
	zoom = Vector2(zoom_scale, zoom_scale)
	_viewport_size = Vector2(viewport_sz)
	_apply_clamped_snapped_pos()


func _process(delta: float) -> void:
	if _target == null:
		return
	var weight: float = 1.0 - exp(-follow_smooth * delta)
	_logical_pos = _logical_pos.lerp(_target.global_position, weight)
	_apply_clamped_snapped_pos()


func _apply_clamped_snapped_pos() -> void:
	var half_view := (_viewport_size * 0.5) / maxf(zoom.x, 0.01)
	var min_x := map_bounds.position.x + half_view.x
	var max_x := map_bounds.end.x - half_view.x
	var min_y := map_bounds.position.y + half_view.y
	var max_y := map_bounds.end.y - half_view.y

	var clamped := _logical_pos
	if max_x >= min_x:
		clamped.x = clampf(clamped.x, min_x, max_x)
	else:
		clamped.x = map_bounds.get_center().x
	if max_y >= min_y:
		clamped.y = clampf(clamped.y, min_y, max_y)
	else:
		clamped.y = map_bounds.get_center().y

	global_position = snap_position(clamped)


func snap_position(point: Vector2) -> Vector2:
	return point.round()
