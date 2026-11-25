extends "res://scripts/rts/rts_units_study.gd"

const CROSSING := preload("res://scenes/maps/rts_desert_crossing_field.tscn")
const PIXEL_FIELD := Vector2i(720, 504)
const FRAME := Rect2(0, 48, 960, 672)
const START := Vector2(360, 264)
const SQUAD_TARGET := Vector2(464, 240)
const TANK_TARGET := Vector2(432, 240)

var terrain: RtsDesertTerrain
var _commands: RtsCommands
var _density := 1.0
var _show_route := false
var _play_area := Rect2()
var _last_selection := ""

@onready var _sidebar: Panel = $HUD/Sidebar
@onready var _top: Panel = $HUD/Top
@onready var _overview: Control = $HUD/Sidebar/Overview
@onready var _selection: Label = $HUD/Sidebar/Selection
@onready var _switch: Button = $HUD/Sidebar/Switch
@onready var _route: CheckButton = $HUD/Sidebar/Route


func _ready() -> void:
	_effects = [RtsLook.shadows, RtsLook.ground_light, RtsLook.marks, RtsLook.dust,
		RtsLook.pixel_snap, RtsLook.soft_effects]
	get_viewport().size_changed.connect(_fit_screen)
	_switch.pressed.connect(func(): set_look(1 - look, false))
	_route.toggled.connect(func(value: bool):
		_show_route = value
		_overview.queue_redraw())
	$HUD/Sidebar/Restart.pressed.connect(_restart)
	_overview.draw.connect(_draw_overview)
	_restart()


func _exit_tree() -> void:
	if _effects.size() != 6:
		return
	RtsLook.shadows = _effects[0]
	RtsLook.ground_light = _effects[1]
	RtsLook.marks = _effects[2]
	RtsLook.dust = _effects[3]
	RtsLook.pixel_snap = _effects[4]
	RtsLook.soft_effects = _effects[5]


func _restart() -> void:
	if is_instance_valid(map):
		field.remove_child(map)
		map.queue_free()
	map = CROSSING.instantiate()
	terrain = map.get_node("Terrain")
	for unit: RtsUnit in map.get_node("Units").get_children():
		field_unit_art(unit)
	field.add_child(map)
	_camera = map.get_node("Camera")
	_commands = map.get_node("Commands")
	_commands.selection_changed.connect(func(_selection_changed): _update_selection())
	map.controls_changed.connect(_update_help)
	_density = 1.0
	set_look(look, false)
	_camera.look_at_point(START)
	_camera.force_update_scroll()
	_commands.set_selection([map.get_node("Units/BlueSquad")])
	_update_help()


func set_look(mode: int, _announce := true) -> void:
	var world_zoom := _camera.zoom.x / _density
	look = mode
	_density = 2.0 if mode == 0 else 1.0
	field.size = PIXEL_FIELD * roundi(_density)
	_camera.zoom = Vector2.ONE * world_zoom * _density
	_camera.zoom_min = 1.2 * _density
	_camera.zoom_max = 2.5 * _density
	_camera.density_scale = _density
	_camera.clamp_to_map()
	_camera.force_update_scroll()
	screen.texture_filter = TEXTURE_FILTER_LINEAR if mode == 0 else TEXTURE_FILTER_NEAREST
	field.snap_2d_transforms_to_pixel = mode == 1
	field.snap_2d_vertices_to_pixel = mode == 1
	RtsLook.pixel_snap = mode == 1
	RtsLook.soft_effects = mode == 0
	terrain.apply_art(mode == 0)
	for unit: RtsUnit in map.get_node("Units").get_children():
		unit.painted = mode == 0
		unit.texture_filter = screen.texture_filter
		unit.queue_redraw()
	_switch.text = "Pixel art  [V]" if mode == 0 else "Painted HD  [V]"
	_top.get_node("Look").text = "PAINTED HD" if mode == 0 else "PIXEL ART"
	_fit_screen()


func _fit_screen() -> void:
	var available := get_viewport_rect().size
	var scale_fit := minf(available.x / 1280.0, available.y / 720.0)
	var margins := (available - Vector2(1280, 720) * scale_fit) * 0.5
	_play_area = Rect2(margins + FRAME.position * scale_fit, FRAME.size * scale_fit)
	screen.custom_minimum_size = Vector2(field.size)
	screen.size = Vector2(field.size)
	screen.scale = Vector2.ONE * (_play_area.size.x / field.size.x)
	screen.position = _play_area.position
	_top.position = margins
	_top.scale = Vector2.ONE * scale_fit
	_sidebar.position = _play_area.position + Vector2(_play_area.size.x, 0)
	_sidebar.scale = Vector2.ONE * scale_fit


func _process(_delta: float) -> void:
	_update_selection()
	_overview.queue_redraw()


func _update_help() -> void:
	terrain.refresh_effects()


func _update_selection() -> void:
	var selected := _commands.selection
	var caption := "Choose a Blue unit"
	if selected.size() == 1 and is_instance_valid(selected[0]):
		var unit := selected[0] as RtsUnit
		caption = "%s\n%d / %d health" % [unit.stats.display_name, unit.health, unit.stats.max_health]
	elif selected.size() > 1:
		caption = "%d units selected" % selected.size()
	if caption != _last_selection:
		_selection.text = caption
		_last_selection = caption


func _draw_overview() -> void:
	var ratio := _overview.size / Vector2(RtsDesertTerrain.WORLD_SIZE)
	_overview.draw_rect(Rect2(Vector2.ZERO, _overview.size), Color("#4a392f"))
	var world_grid := map.get_node("Grid") as RtsGrid
	for y in world_grid.region.size.y:
		for x in world_grid.region.size.x:
			var tile := Vector2i(x, y)
			if not world_grid.is_walkable(tile):
				var rect := Rect2(Vector2(tile * 32) * ratio, Vector2(32, 32) * ratio)
				_overview.draw_rect(rect, Color("#28271f"))
	for unit: RtsUnit in map.get_node("Units").get_children():
		if unit.alive:
			var team := Color("#74baf5") if unit.stats.faction == UnitStats.Faction.BLUE else Color("#f17a69")
			_overview.draw_circle(unit.position * ratio, 2.7, team)
	var visible_world := Vector2(field.size) / _camera.zoom
	var visible_rect := Rect2((_camera.position - visible_world * 0.5) * ratio, visible_world * ratio)
	_overview.draw_rect(visible_rect, Color("#e7c99b"), false, 1.0)
	if _show_route:
		_draw_destination(SQUAD_TARGET, ratio, "Squad", Color("#f1ce77"))
		_draw_destination(TANK_TARGET, ratio, "Tank", Color("#a8d8fa"))


func _draw_destination(point: Vector2, ratio: Vector2, label: String, color: Color) -> void:
	_overview.draw_circle(point * ratio, 3.8, color, false, 1.3, true)
	var screen_point := (map.get_canvas_transform() * point) * screen.scale + screen.position
	if not _play_area.grow(-16.0).has_point(screen_point):
		return
	var local := _overview.get_global_transform_with_canvas().affine_inverse() * screen_point
	_overview.draw_arc(local, 10.0, 0, TAU, 32, Color("#382b21"), 4.0, true)
	_overview.draw_arc(local, 10.0, 0, TAU, 32, color, 1.6, true)
	var caption_pos := local + Vector2(-15, -17)
	var font := _selection.get_theme_default_font()
	_overview.draw_string_outline(font, caption_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 5, Color("#33281c"))
	_overview.draw_string(font, caption_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_restart()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_key_input(event)
