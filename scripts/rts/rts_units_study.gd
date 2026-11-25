extends Node2D
## The display can change density while one battlefield keeps running.

const FIELD_SIZE := Vector2i(960, 540)
const RENDER_SIZES := [Vector2i(1920, 1080), FIELD_SIZE, Vector2i(640, 360)]
const LOOK_NAMES := ["Painted HD", "Pixel art", "Pixel art · 640 × 360 proof"]
const MAP_ART := "res://assets/textures/rts/units_motion/"
const MotionUnit := preload("res://scripts/rts/rts_motion_unit.gd")
const ORIGINAL := preload("res://scenes/maps/rts_units_test.tscn")

var look := 0
var map: Node2D
var _camera: RtsCamera
var _show_time := 0.0
var _original_ground: Array[Texture2D] = []
var _painted_ground: Array[Texture2D] = []
var _effects: Array[bool]
var _layers: Array[Sprite2D] = []

@onready var screen: SubViewportContainer = $Screen
@onready var field: SubViewport = $Screen/Field
@onready var help: Label = $HUD/Help
@onready var notice: Label = $HUD/Notice


func _ready() -> void:
	_effects = [RtsLook.shadows, RtsLook.ground_light, RtsLook.marks, RtsLook.dust]
	map = ORIGINAL.instantiate()
	for unit: RtsUnit in map.get_node("Units").get_children():
		var stats := unit.stats
		unit.set_script(MotionUnit)
		unit.stats = stats
		field_unit_art(unit)
	for layer in ["Ground", "Road", "Rocks", "Scatter"]:
		var sprite := map.get_node(layer) as Sprite2D
		_layers.append(sprite)
		_original_ground.append(sprite.texture)
		_painted_ground.append(load(MAP_ART + layer.to_lower() + "_hd.png"))
	map.get_node("HUD").visible = false
	field.add_child(map)
	_camera = map.get_node("Camera")
	_camera.set_scroll_bounds(Rect2(Vector2.ZERO, Vector2(FIELD_SIZE)))
	_camera.look_at_point(Vector2(FIELD_SIZE) * 0.5)
	get_viewport().size_changed.connect(_fit_screen)
	map.controls_changed.connect(_update_help)
	set_look(0, false)


func _exit_tree() -> void:
	if _effects.size() == 4:
		RtsLook.shadows = _effects[0]
		RtsLook.ground_light = _effects[1]
		RtsLook.marks = _effects[2]
		RtsLook.dust = _effects[3]


func field_unit_art(unit: RtsUnit) -> void:
	var faction := "blue" if unit.stats.faction == UnitStats.Faction.BLUE else "red"
	var kind := "squad"
	if unit.stats.vehicle:
		kind = "tank"
	elif unit.stats.kind == UnitStats.Kind.COMMANDER:
		kind = "commander"
	var hd := MAP_ART + faction + "_" + kind + "_hd.png"
	var pixel := MAP_ART + faction + "_" + kind + "_pixel.png"
	if ResourceLoader.exists(hd) and ResourceLoader.exists(pixel):
		unit.art_hd = load(hd)
		unit.art_pixel = load(pixel)


## 2 is available to the capture harness for a matched 3× proof.
func set_look(mode: int, announce := true) -> void:
	var old_density := float(field.size.x) / FIELD_SIZE.x
	var density := float(RENDER_SIZES[mode].x) / FIELD_SIZE.x
	var world_zoom := _camera.zoom.x / old_density
	if not is_equal_approx(_camera.zoom_min, old_density):
		world_zoom = 1.0  # The original map's camera was set up for a 1280-wide viewport.
	look = mode
	field.size = RENDER_SIZES[mode]
	_camera.zoom = Vector2.ONE * world_zoom * density
	_camera.zoom_min = density
	_camera.zoom_max = density * 2.25
	_camera.scroll_speed = 600.0 * density
	_camera.edge_margin = 10.0 * density
	_camera.clamp_to_map()
	_camera.force_update_scroll()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if mode == 0 else CanvasItem.TEXTURE_FILTER_NEAREST
	field.snap_2d_transforms_to_pixel = mode != 0
	field.snap_2d_vertices_to_pixel = mode != 0
	for i in _layers.size():
		var layer := _layers[i]
		layer.texture = _painted_ground[i] if mode == 0 else _original_ground[i]
		layer.scale = Vector2.ONE * (0.5 if mode == 0 else 1.0)
		layer.texture_filter = screen.texture_filter
	for unit: RtsUnit in map.get_node("Units").get_children():
		unit.painted = mode == 0
		unit.texture_filter = screen.texture_filter
		unit.queue_redraw()
	_fit_screen()
	_update_help()
	if announce:
		notice.text = LOOK_NAMES[mode]
		notice.show()
		_show_time = 1.45


func _fit_screen() -> void:
	var available := get_viewport_rect().size
	var fit := minf(available.x / field.size.x, available.y / field.size.y)
	screen.custom_minimum_size = Vector2(field.size)
	screen.size = Vector2(field.size)
	screen.scale = Vector2.ONE * fit
	screen.position = (available - Vector2(field.size) * fit) * 0.5


func _process(delta: float) -> void:
	if _show_time > 0.0:
		_show_time -= delta
		if _show_time <= 0.0:
			notice.hide()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_V:
		set_look(1 if look == 0 else 0)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and not get_node("/root/BuildLauncher").is_build_active():
		get_tree().quit()


func _update_help() -> void:
	var status := "   ·   P patrol %s   K shadows %s   L light %s   M marks %s   N dust %s   F1 tiles %s" % [
		_on(map.patrol), _on(RtsLook.shadows), _on(RtsLook.ground_light), _on(RtsLook.marks),
		_on(RtsLook.dust), _on(map.grid.show_debug)]
	var caption := "%s   ·   V switch   ·   Select / drag   Shift add   Right-click order   S stop\n" % LOOK_NAMES[look]
	help.text = caption + "Arrows / middle drag pan   Wheel zoom   Esc back" + status


func _on(value: bool) -> String:
	return "on" if value else "off"
