extends Node2D

const Route := preload("res://assets/scenes/forest_test/forest_route.gd")
const SPEED := Vector2(218.0, 174.0)
const FRAMES_PER_SECOND := 7.6
const IDLE_HEIGHT := 149.0
const ART_FOLDER := "res://assets/scenes/forest_test/art/"
const ATLAS_PATH := "res://assets/textures/rpg_2d/approach3/commander_765.png"
const SHADOW_PATH := "res://assets/textures/rpg_2d/sprites/contact_shadow.png"

@export var painting_file := ""
@export var painted_trail: Array[Vector3] = []

var rough := true
var guides := false
var stride_phase := 0.0
var facing := Vector2.DOWN
var _warned_about_painting := false

@onready var commander: Node2D = $Commander
@onready var pose: Sprite2D = $Commander/Pose
@onready var shadow: Sprite2D = $Commander/Shadow
@onready var camera = $Camera
@onready var painting: Sprite2D = $Painting
@onready var readout: Label = $HUD/Readout


func _ready() -> void:
	var window := get_window()
	window.title = "Balance · Painted Forest Walk"
	window.content_scale_size = Vector2i(Route.VIEW)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.size = Vector2i(Route.VIEW)

	pose.texture = _load_image(ATLAS_PATH)
	shadow.texture = _load_image(SHADOW_PATH)
	if pose.texture == null or shadow.texture == null:
		push_error("Forest walk requires the existing Approach 3 Commander atlas and contact shadow.")
		get_tree().quit(1)
		set_physics_process(false)
		return
	pose.scale = Vector2.ONE * Route.START_HEIGHT / IDLE_HEIGHT

	rough = painting_file.is_empty() or "--rough" in OS.get_cmdline_user_args()
	_show_rough(rough)
	reset_walk()


func _load_image(path: String) -> ImageTexture:
	var source := Image.load_from_file(ProjectSettings.globalize_path(path))
	if source.is_empty():
		return null
	source.generate_mipmaps()
	return ImageTexture.create_from_image(source)


func active_trail() -> Array:
	return Route.GUIDE_TRAIL if rough or painted_trail.is_empty() else painted_trail


func reset_walk() -> void:
	var limits := Route.feet_limits(Route.START_Y, active_trail())
	commander.position = Vector2((limits.x + limits.y) * 0.5, Route.START_Y)
	facing = Vector2.DOWN
	stride_phase = 0.0
	_update_pose(false)
	camera.follow(commander.position, 0.0, true)


func _physics_process(delta: float) -> void:
	step_walk(_keyboard_direction(), delta)


func _keyboard_direction() -> Vector2:
	var left := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var up := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var down := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	return Vector2(float(right) - float(left), float(down) - float(up))


func step_walk(input_direction: Vector2, delta: float) -> void:
	var previous := commander.position
	var ratio := Route.figure_scale(previous.y)
	var next := previous + input_direction.limit_length() * SPEED * ratio * delta
	next.y = clampf(next.y, Route.NORTH_Y, Route.SOUTH_Y)
	var limits := Route.feet_limits(next.y, active_trail())
	next.x = clampf(next.x, limits.x, limits.y)
	var travel := next - previous
	commander.position = next
	if not input_direction.is_zero_approx():
		facing = input_direction.normalized()
	var moving := travel.length_squared() > 0.0001
	if moving:
		# Count distance in unscaled stride lengths so smaller poses and slower
		# translation stay in time, including when sliding along a boundary.
		stride_phase = fposmod(
			stride_phase + (travel / SPEED).length() * FRAMES_PER_SECOND / ratio, 4.0
		)
	_update_pose(moving)
	camera.follow(next, delta)
	if guides:
		readout.text = "%s   |   North %.0f   |   Idle height %.1f px" % [
			Route.STRETCH_NAMES[Route.stretch(next.y)], Route.START_Y - next.y,
			Route.START_HEIGHT * commander.scale.y,
		]


func _update_pose(moving: bool) -> void:
	commander.scale = Vector2.ONE * Route.figure_scale(commander.position.y)
	var row := 2
	var mirror := facing.x < 0.0
	if facing.y < -0.35:
		row = 1
		mirror = facing.x > 0.15
	elif facing.y > 0.35:
		row = 0
	var column := 1 + int(stride_phase) if moving else 0
	pose.frame_coords = Vector2i(column, row)
	pose.flip_h = mirror
	# The authored 160 × 168 cells have a shared boot anchor at (80, 160).
	# One rear contact pose extends four source pixels below it.
	pose.offset.y = -80.0 if row == 1 and column == 1 else -76.0


func _show_rough(enabled: bool) -> void:
	if not enabled and painting.texture == null:
		if not painting_file.is_empty() and not _warned_about_painting:
			var path := ART_FOLDER + painting_file
			if FileAccess.file_exists(path):
				painting.texture = _load_image(path)
			if painting.texture == null:
				_warned_about_painting = true
				push_warning("Forest painting unavailable. Showing the rough trail.")
		if painting.texture != null:
			painting.scale = Route.CANVAS / painting.texture.get_size()
	rough = enabled or painting.texture == null
	painting.visible = not rough
	if is_node_ready():
		var limits := Route.feet_limits(commander.position.y, active_trail())
		commander.position.x = clampf(commander.position.x, limits.x, limits.y)
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_G:
			guides = not guides
			readout.visible = guides
			queue_redraw()
		KEY_F2:
			_show_rough(not rough)
		KEY_R:
			reset_walk()
		KEY_ESCAPE:
			get_tree().quit()


func _draw() -> void:
	if rough:
		_draw_rough()
	if not guides:
		return
	var trail := active_trail()
	for side in [-1, 1]:
		var line := PackedVector2Array()
		for y in range(int(Route.NORTH_Y), int(Route.SOUTH_Y) + 1, 10):
			var limits := Route.feet_limits(y, trail)
			line.append(Vector2(limits.x if side < 0 else limits.y, y))
		draw_polyline(line, Color("d6f2e5"), 2.0, true)
	for boundary in Route.BOUNDARIES:
		var y := Route.START_Y - boundary
		var limits := Route.feet_limits(y, trail)
		draw_line(Vector2(limits.x, y), Vector2(limits.y, y), Color("fee2a3"), 2.0, true)


func _draw_rough() -> void:
	draw_rect(Rect2(Vector2.ZERO, Route.CANVAS), Color("253930"))
	var polygon := PackedVector2Array()
	for row in Route.GUIDE_TRAIL:
		polygon.append(Vector2(row.y, row.x))
	for index in range(Route.GUIDE_TRAIL.size() - 1, -1, -1):
		var row: Vector3 = Route.GUIDE_TRAIL[index]
		polygon.append(Vector2(row.z, row.x))
	draw_colored_polygon(polygon, Color("8b694d"))
	for y in range(390, 2020, 82):
		var limits := Route.edges(y, Route.GUIDE_TRAIL)
		for x in [limits.x - 40.0, limits.y + 40.0]:
			draw_rect(Rect2(x - 11, y - 19, 22, 38), Color("aeb69a"))
