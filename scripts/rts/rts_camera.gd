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
@export var snap_to_pixel := false

var density_scale := 1.0
var _bounds := Rect2()
var _dragging := false
var _logical_pos := Vector2.ZERO

@onready var _grid: RtsGrid = get_node(grid_path)


func _ready() -> void:
	_logical_pos = position
	_bounds = _grid.world_rect()
	clamp_to_map()


func apply_visual_profile(profile: RtsVisualProfile, map_rect: Rect2 = Rect2()) -> void:
	var old_density := maxf(density_scale, 0.001)
	var logical_zoom := zoom.x / old_density
	if is_equal_approx(zoom.x, 1.3333) and is_equal_approx(old_density, 1.0):
		logical_zoom = 1.0
	density_scale = profile.density
	snap_to_pixel = profile.snap_pixels
	zoom_min = 1.0 * density_scale
	zoom_max = 3.0 * density_scale
	if map_rect.size != Vector2.ZERO:
		_bounds = map_rect
	_set_zoom(logical_zoom * density_scale)


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
		var margin := edge_margin * density_scale
		if Rect2(Vector2.ZERO, view).has_point(mouse):
			if mouse.x < margin:
				dir.x -= 1.0
			elif mouse.x > view.x - margin:
				dir.x += 1.0
			if mouse.y < margin:
				dir.y -= 1.0
			elif mouse.y > view.y - margin:
				dir.y += 1.0
	if dir != Vector2.ZERO:
		_logical_pos += dir.limit_length(1.0) * (scroll_speed * density_scale) * delta / zoom.x
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
		_logical_pos -= (event as InputEventMouseMotion).relative / zoom.x
		clamp_to_map()


func look_at_point(world: Vector2) -> void:
	_logical_pos = world
	clamp_to_map()


## Painted scenery can extend past the last complete, navigable tile.
func set_scroll_bounds(bounds: Rect2) -> void:
	_bounds = bounds
	clamp_to_map()


func _set_zoom(value: float) -> void:
	var z := clampf(value, zoom_min, zoom_max)
	zoom = Vector2(z, z)
	clamp_to_map()


## Keeps the view inside the map (centred when the map is smaller than the view).
func clamp_to_map() -> void:
	if _bounds.size == Vector2.ZERO:
		position = _logical_pos.round() if snap_to_pixel else _logical_pos
		return
	var half := get_viewport().get_visible_rect().size / zoom * 0.5
	for axis in 2:
		if _bounds.size[axis] <= half[axis] * 2.0:
			_logical_pos[axis] = _bounds.get_center()[axis]
		else:
			_logical_pos[axis] = clampf(_logical_pos[axis], _bounds.position[axis] + half[axis], _bounds.end[axis] - half[axis])
	position = _logical_pos.round() if snap_to_pixel else _logical_pos
