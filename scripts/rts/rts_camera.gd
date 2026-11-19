class_name RtsCamera
extends Camera2D
## Top-down RTS camera. Scroll with the arrow keys, by pushing the mouse against a screen edge,
## or by dragging with the middle mouse button. The mouse wheel zooms. Never leaves the map.

@export var grid_path: NodePath = ^"../Grid"
## Screen pixels per second.
@export var scroll_speed := 800.0
## How close to the window edge the mouse must be to scroll.
@export var edge_margin := 10.0
@export var edge_scroll := true
@export var zoom_min := 0.75
@export var zoom_max := 2.0
@export var zoom_step := 1.15

var _bounds := Rect2()
var _dragging := false

@onready var _grid: RtsGrid = get_node(grid_path)


func _ready() -> void:
	_bounds = _grid.world_rect()
	clamp_to_map()


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if edge_scroll and not _dragging and DisplayServer.window_is_focused():
		var view := get_viewport().get_visible_rect().size
		var mouse := get_viewport().get_mouse_position()
		if Rect2(Vector2.ZERO, view).has_point(mouse):
			if mouse.x < edge_margin:
				dir.x -= 1.0
			elif mouse.x > view.x - edge_margin:
				dir.x += 1.0
			if mouse.y < edge_margin:
				dir.y -= 1.0
			elif mouse.y > view.y - edge_margin:
				dir.y += 1.0
	if dir != Vector2.ZERO:
		position += dir.limit_length(1.0) * scroll_speed * delta / zoom.x
		clamp_to_map()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom.x * zoom_step)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x / zoom_step)
	elif event is InputEventMouseMotion and _dragging:
		position -= (event as InputEventMouseMotion).relative / zoom.x
		clamp_to_map()


func look_at_point(world: Vector2) -> void:
	position = world
	clamp_to_map()


func _set_zoom(value: float) -> void:
	var z := clampf(value, zoom_min, zoom_max)
	zoom = Vector2(z, z)
	clamp_to_map()


## Keeps the view inside the map (centred when the map is smaller than the view).
func clamp_to_map() -> void:
	if _bounds.size == Vector2.ZERO:
		return
	var half := get_viewport().get_visible_rect().size / zoom * 0.5
	for axis in 2:
		if _bounds.size[axis] <= half[axis] * 2.0:
			position[axis] = _bounds.get_center()[axis]
		else:
			position[axis] = clampf(position[axis], _bounds.position[axis] + half[axis], _bounds.end[axis] - half[axis])
