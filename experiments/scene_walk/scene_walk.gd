extends Node2D

const BASE_SIZE := Vector2i(1920, 1080)
const WINDOW_SIZE := Vector2i(1280, 720)
const START_FEET := Vector2(990, 756)
const HERO_SHARE := 0.20
const SCALE_AT_BOTTOM := 1.00
const SCALE_AT_TOP := 0.60
const SCALE_STEP := 0.02
const SPEED_AT_START := 290.0
const EDGE_EPSILON := 0.001
const DEFAULT_AREA := [
	Vector2(817, 480), Vector2(1057, 480), Vector2(1172, 1060), Vector2(856, 1060),
]
const EXPERIMENT := "res://experiments/scene_walk/"

var _walk_area := PackedVector2Array(DEFAULT_AREA)
var _draft := PackedVector2Array()
var _editing := false
var _guide_visible := true
var _bottom_scale := SCALE_AT_BOTTOM
var _top_scale := SCALE_AT_TOP
var _top_y := 0.0
var _bottom_y := 0.0
var _start_scale := 1.0

@onready var _painting: Sprite2D = $Painting
@onready var _hero: Node2D = $Hero
@onready var _hero_art: Sprite2D = $Hero/Art
@onready var _shadow: Sprite2D = $Hero/Shadow
@onready var _overlay: PanelContainer = $Overlay
@onready var _height_value: Label = $Overlay/Rows/Metrics/HeightValue
@onready var _bottom_value: Label = $Overlay/Rows/Metrics/BottomValue
@onready var _top_value: Label = $Overlay/Rows/Metrics/TopValue
@onready var _edit_hint: Label = $Overlay/Rows/EditHint


func _ready() -> void:
	var window := get_window()
	window.title = "Painted Perspective Walk Test"
	window.content_scale_size = BASE_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.unresizable = false
	window.size = WINDOW_SIZE

	_painting.texture = _load_texture("approach3_arch.png")
	_hero_art.texture = _load_texture("hero_clean.png")
	if _painting.texture == null or _hero_art.texture == null:
		get_tree().quit(1)
		set_physics_process(false)
		return
	_painting.scale = Vector2(BASE_SIZE) / _painting.texture.get_size()
	var art_size := _hero_art.texture.get_size()
	var start_height := HERO_SHARE * BASE_SIZE.y
	_hero_art.scale = Vector2.ONE * start_height / art_size.y
	# The Approach 3 pose has its boot anchor to the right of the sprite centre.
	_hero_art.offset = -art_size * Vector2(50.0 / 73.0, 1.0)
	_shadow.texture = _make_shadow()
	# With a 1.8 m standing-height reference, 0.9 m is half the sprite height.
	_shadow.scale = Vector2(start_height * 0.5, start_height * 0.125) / _shadow.texture.get_size()

	_load_settings()
	_hero.position = _point_in_area(START_FEET)
	_update_scale_range()
	_update_hero()


func _load_texture(filename: String) -> ImageTexture:
	var image := Image.load_from_file(ProjectSettings.globalize_path(EXPERIMENT + "art/" + filename))
	if image.is_empty():
		push_error("Missing walk test texture: " + filename)
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _make_shadow() -> ImageTexture:
	var image := Image.create_empty(128, 32, false, Image.FORMAT_RGBA8)
	var size := Vector2(image.get_size())
	for y in image.get_height():
		for x in image.get_width():
			var point := (Vector2(x, y) + Vector2(0.5, 0.5)) * 2.0 / size - Vector2.ONE
			var alpha := 0.4 * (1.0 - smoothstep(0.0, 1.0, point.length_squared()))
			image.set_pixel(x, y, Color(0, 0, 0, alpha))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _physics_process(delta: float) -> void:
	if _editing:
		return
	var left := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var up := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var direction := Vector2(float(right) - float(left), float(down) - float(up))
	if direction == Vector2.ZERO:
		return
	_move_feet(direction.normalized() * SPEED_AT_START * _hero.scale.x * delta)
	_update_hero()


func _move_feet(motion: Vector2) -> void:
	# Sweep the foot point to the first boundary it would cross, then slide
	# the unused movement along that edge. Repeat in case it reaches a corner.
	for slide in _walk_area.size():
		if motion.length_squared() < EDGE_EPSILON * EDGE_EPSILON:
			return
		var first_hit := 1.0
		var hit_point := Vector2.ZERO
		var hit_tangent := Vector2.ZERO
		for index in _walk_area.size():
			var start := _walk_area[index]
			var next := (index + 1) % _walk_area.size()
			var edge := _walk_area[next] - start
			var length := edge.length()
			var tangent := edge / length
			var inward := Vector2(-tangent.y, tangent.x)
			var outward_motion := -motion.dot(inward)
			if outward_motion <= EDGE_EPSILON:
				continue
			var distance := (_hero.position - start).dot(inward)
			var time := maxf(distance, 0.0) / outward_motion
			if distance < -EDGE_EPSILON or time >= first_hit:
				continue
			var along := (_hero.position + motion * time - start).dot(tangent)
			if along < -EDGE_EPSILON or along > length + EDGE_EPSILON:
				continue
			# At a concave corner either incident edge can lead back inside.
			if along <= EDGE_EPSILON and _inside_concave_corner(index, motion):
				continue
			if along >= length - EDGE_EPSILON and _inside_concave_corner(next, motion):
				continue
			first_hit = time
			hit_tangent = tangent
			hit_point = start + tangent * clampf(along, 0.0, length)
		if hit_tangent == Vector2.ZERO:
			_hero.position = _point_in_area(_hero.position + motion)
			return
		_hero.position = hit_point
		motion = (motion * (1.0 - first_hit)).project(hit_tangent)


func _inside_concave_corner(index: int, motion: Vector2) -> bool:
	var count := _walk_area.size()
	var point := _walk_area[index]
	var incoming := (point - _walk_area[(index + count - 1) % count]).normalized()
	var outgoing := (_walk_area[(index + 1) % count] - point).normalized()
	return incoming.cross(outgoing) < 0.0 and (
		incoming.cross(motion) >= 0.0 or outgoing.cross(motion) >= 0.0
	)


func _point_in_area(point: Vector2) -> Vector2:
	if Geometry2D.is_point_in_polygon(point, _walk_area):
		return point
	var nearest := _walk_area[0]
	for index in _walk_area.size():
		var start := _walk_area[index]
		var end := _walk_area[(index + 1) % _walk_area.size()]
		var candidate := Geometry2D.get_closest_point_to_segment(point, start, end)
		if point.distance_squared_to(candidate) < point.distance_squared_to(nearest):
			nearest = candidate
	return nearest


func _raw_scale(y: float) -> float:
	return lerpf(_top_scale, _bottom_scale, clampf(inverse_lerp(_top_y, _bottom_y, y), 0.0, 1.0))


func _update_scale_range() -> void:
	_top_y = _walk_area[0].y
	_bottom_y = _top_y
	for point in _walk_area:
		_top_y = minf(_top_y, point.y)
		_bottom_y = maxf(_bottom_y, point.y)
	_start_scale = _raw_scale(_point_in_area(START_FEET).y)


func _update_hero() -> void:
	var scale_ratio := _raw_scale(_hero.position.y) / _start_scale
	_hero.scale = Vector2.ONE * scale_ratio
	_height_value.text = "%.2f%%" % (100.0 * HERO_SHARE * scale_ratio)
	_bottom_value.text = "%.2f" % _bottom_scale
	_top_value.text = "%.2f" % _top_scale


func _unhandled_input(event: InputEvent) -> void:
	if _editing and event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var mouse := event as InputEventMouseButton
				var point := get_global_transform_with_canvas().affine_inverse() * mouse.position
				if Rect2(Vector2.ZERO, Vector2(BASE_SIZE)).has_point(point):
					_draft.append(point)
			MOUSE_BUTTON_RIGHT:
				if not _draft.is_empty():
					_draft.remove_at(_draft.size() - 1)
		queue_redraw()
		return

	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_7:
			_bottom_scale = maxf(SCALE_STEP, _bottom_scale - SCALE_STEP)
		KEY_8:
			_bottom_scale += SCALE_STEP
		KEY_9:
			_top_scale = maxf(SCALE_STEP, _top_scale - SCALE_STEP)
		KEY_0:
			_top_scale += SCALE_STEP
		KEY_S:
			_save_json("calib.json", {"scale_at_bottom": _bottom_scale, "scale_at_top": _top_scale})
		KEY_E:
			_toggle_edit()
		KEY_ENTER, KEY_KP_ENTER:
			if _editing:
				_save_area()
		KEY_G:
			_set_guide_visible(not _guide_visible)
		KEY_P:
			_save_screenshot()
		KEY_ESCAPE:
			get_tree().quit()
		_:
			return
	_update_scale_range()
	_update_hero()


func _toggle_edit() -> void:
	_editing = not _editing
	if _editing:
		_draft = _walk_area.duplicate()
		_edit_hint.text = "Edit mode\nLeft click adds a point · Right click removes the last\nEnter saves · E cancels"
		_set_guide_visible(true)
	_edit_hint.visible = _editing
	queue_redraw()


func _set_guide_visible(show: bool) -> void:
	_guide_visible = show
	_overlay.visible = show
	queue_redraw()


func _draw() -> void:
	if not _guide_visible:
		return
	var points := _draft if _editing else _walk_area
	var ink := Color(1, 0.78, 0.44, 0.94) if _editing else Color(0.74, 0.93, 1, 0.86)
	if points.size() > 1:
		var outline := points.duplicate()
		if points.size() > 2:
			outline.append(points[0])
		draw_polyline(outline, Color(0.08, 0.06, 0.04, 0.75), 5.0, true)
		draw_polyline(outline, ink, 2.5, true)
	if _editing:
		for point in points:
			draw_circle(point, 6.0, ink, true, -1.0, true)


func _save_area() -> void:
	if not _is_valid_area(_draft):
		_edit_hint.text = "Draw at least three points around one area.\nEdges must not cross or touch other edges."
		return
	var coordinates: Array = []
	for point in _draft:
		coordinates.append([point.x, point.y])
	if _save_json("walk_area.json", coordinates):
		_apply_area(_draft)
		_hero.position = _point_in_area(_hero.position)
		_toggle_edit()
	else:
		_edit_hint.text = "Could not save walk_area.json.\nEnter retries · E cancels"


func _apply_area(points: PackedVector2Array) -> void:
	_walk_area = points.duplicate()
	if Geometry2D.is_polygon_clockwise(_walk_area):
		_walk_area.reverse()


func _is_valid_area(points: PackedVector2Array) -> bool:
	if points.size() < 3 or Geometry2D.triangulate_polygon(points).is_empty():
		return false
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		if not a.is_finite() or a.x < 0 or a.x > BASE_SIZE.x or a.y < 0 or a.y > BASE_SIZE.y:
			return false
		if a.is_equal_approx(b):
			return false
		for j in range(i + 2, points.size()):
			# Adjacent edges share a vertex by design.
			if i == 0 and j == points.size() - 1:
				continue
			var c := points[j]
			var d := points[(j + 1) % points.size()]
			if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
				return false
			if _on_segment(c, a, b) or _on_segment(d, a, b) or _on_segment(a, c, d) or _on_segment(b, c, d):
				return false
	return true


func _on_segment(point: Vector2, start: Vector2, end: Vector2) -> bool:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end)) < EDGE_EPSILON


func _load_settings() -> void:
	var calibration: Variant = _load_json("calib.json")
	if calibration is Dictionary:
		_bottom_scale = _read_scale(calibration.get("scale_at_bottom"), SCALE_AT_BOTTOM)
		_top_scale = _read_scale(calibration.get("scale_at_top"), SCALE_AT_TOP)

	var coordinates: Variant = _load_json("walk_area.json")
	if not coordinates is Array:
		return
	var points := PackedVector2Array()
	for pair: Variant in coordinates:
		if not pair is Array or pair.size() != 2 or not _is_number(pair[0]) or not _is_number(pair[1]):
			push_warning("Ignoring invalid walk_area.json coordinates.")
			return
		points.append(Vector2(pair[0], pair[1]))
	if _is_valid_area(points):
		_apply_area(points)
	else:
		push_warning("Ignoring an invalid polygon in walk_area.json.")


func _is_number(value: Variant) -> bool:
	return value is float or value is int


func _read_scale(value: Variant, default_value: float) -> float:
	if _is_number(value) and is_finite(float(value)) and value >= SCALE_STEP:
		return float(value)
	return default_value


func _load_json(filename: String) -> Variant:
	var path := EXPERIMENT + filename
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("Ignoring unreadable " + filename)
		return null
	return json.data


func _save_json(filename: String, data: Variant) -> bool:
	var path := EXPERIMENT + filename
	var temporary := path + ".%d.tmp" % OS.get_process_id()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("Could not open " + temporary)
		return false
	var written := file.store_string(JSON.stringify(data, "  ") + "\n")
	file.close()
	if written and DirAccess.rename_absolute(temporary, path) == OK:
		return true
	DirAccess.remove_absolute(temporary)
	push_error("Could not save " + filename)
	return false


func _save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := EXPERIMENT + "shots/scene_walk_%s_%d.png" % [timestamp, Time.get_ticks_usec()]
	var result := get_viewport().get_texture().get_image().save_png(path)
	if result == OK:
		print("Saved screenshot ", ProjectSettings.globalize_path(path))
	else:
		push_error("Could not save screenshot: " + error_string(result))
