extends Control
## Approach 3 uses an independent window presentation and a fixed logical map.

signal reached_lookout

const LOGICAL_HEIGHT := 540.0
const PICTURE_ASPECT := Vector2i(16, 9)
const NORTH_EDGE := 78.0
const SOUTH_EDGE := 1934.0
# Each surveyed cross-section holds Y, road center X, left edge X and right edge X.
const ROAD_SECTIONS := [
	Vector4(78, 473, 392, 550), Vector4(160, 486, 397, 565),
	Vector4(230, 508, 382, 652), Vector4(360, 502, 347, 670),
	Vector4(460, 459, 304, 651), Vector4(520, 426, 260, 630),
	Vector4(570, 399, 252, 595), Vector4(625, 396, 244, 564),
	Vector4(670, 407, 242, 573), Vector4(720, 430, 257, 596),
	Vector4(780, 465, 295, 623), Vector4(850, 513, 374, 662),
	Vector4(920, 529, 430, 691), Vector4(1010, 539, 434, 703),
	Vector4(1090, 503, 384, 685), Vector4(1200, 446, 280, 648),
	Vector4(1260, 402, 230, 619), Vector4(1360, 387, 226, 604),
	Vector4(1500, 443, 302, 650), Vector4(1560, 485, 309, 664),
	Vector4(1660, 501, 302, 669), Vector4(1720, 495, 283, 655),
	Vector4(1840, 457, 298, 622), Vector4(1934, 429, 302, 580),
]

var arrived := false
var _window: Window
var _original_scale_mode: Window.ContentScaleMode

@onready var world_viewport: SubViewport = %WorldViewport
@onready var picture: TextureRect = %Picture
@onready var hero: Approach3Commander = %Commander
@onready var camera: PixelCamera2D = %Camera
@onready var sun: DirectionalLight2D = %Sun
@onready var ambient: CanvasModulate = %Ambient
@onready var shafts: ColorRect = %Shafts
@onready var controls: Label = %Controls
@onready var arrival: Label = %Arrival


func _ready() -> void:
	_window = get_window()
	_original_scale_mode = _window.content_scale_mode
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	picture.texture = world_viewport.get_texture()
	hero.projectiles_parent = %Depth
	for zone in %Shade.get_children():
		hero.shadow_polygons.append(zone as Polygon2D)
	_build_corridor()
	resized.connect(_fit_picture)
	_fit_picture()
	set_surface_lighting(true)


func _exit_tree() -> void:
	if is_instance_valid(_window):
		_window.content_scale_mode = _original_scale_mode


func _fit_picture() -> void:
	var whole_units := floori(minf(size.x / PICTURE_ASPECT.x, size.y / PICTURE_ASPECT.y))
	var render_size := PICTURE_ASPECT * maxi(1, whole_units)
	world_viewport.size = render_size
	picture.position = ((size - Vector2(render_size)) * 0.5).floor()
	picture.size = Vector2(render_size)
	camera.set_resolution_zoom(render_size.y / LOGICAL_HEIGHT, render_size)
	camera.force_update_scroll()
	hero.set_picture_height(render_size.y)


func set_surface_lighting(enabled: bool) -> void:
	sun.enabled = enabled
	ambient.color = Color(0.92, 0.91, 0.92) if enabled else Color.WHITE
	hero.painted_shade_on = enabled


func _physics_process(_delta: float) -> void:
	if not arrived and hero.position.y <= NORTH_EDGE + 13.0:
		arrived = true
		arrival.visible = controls.visible
		reached_lookout.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				hero.toggle_mode()
			KEY_SPACE, KEY_J:
				hero.fire_horizontal_shot()
			KEY_L:
				set_surface_lighting(not sun.enabled)
			KEY_G:
				shafts.visible = not shafts.visible
			KEY_H:
				controls.visible = not controls.visible
				arrival.visible = controls.visible and arrived
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if picture.get_rect().has_point(event.position) and hero.fire_horizontal_shot() != null:
			get_viewport().set_input_as_handled()


static func road_center_x(y: float) -> float:
	for i in range(1, ROAD_SECTIONS.size()):
		var next: Vector4 = ROAD_SECTIONS[i]
		if y <= next.x:
			var prev: Vector4 = ROAD_SECTIONS[i - 1]
			return remap(clampf(y, prev.x, next.x), prev.x, next.x, prev.y, next.y)
	return ROAD_SECTIONS.back().y


func _build_corridor() -> void:
	var left := PackedVector2Array([Vector2(-32, NORTH_EDGE)])
	var right := PackedVector2Array([Vector2(992, NORTH_EDGE)])
	for section in ROAD_SECTIONS:
		left.append(Vector2(section.z, section.x))
		right.append(Vector2(section.w, section.x))
	left.append(Vector2(-32, SOUTH_EDGE))
	right.append(Vector2(992, SOUTH_EDGE))
	var corridor: StaticBody2D = %Corridor
	for points in [left, right]:
		var wall := CollisionPolygon2D.new()
		wall.polygon = points
		corridor.add_child(wall)
	for barrier in [Rect2(-32, NORTH_EDGE - 32, 1024, 32), Rect2(-32, SOUTH_EDGE, 1024, 32)]:
		var cap := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = barrier.size
		cap.shape = shape
		cap.position = barrier.get_center()
		corridor.add_child(cap)
