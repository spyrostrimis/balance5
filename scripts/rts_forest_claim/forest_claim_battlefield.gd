extends RtsCarbonBattlefield
## The desert study's orders, units and objective run on a square logical grid.
## This study only projects their presentation and inputs.

const SPAWNS := [
	[Vector2(4.1, 11.35), RtsCarbonUnit.Team.BLUE, RtsCarbonUnit.Role.COMMANDER],
	[Vector2(4.4, 12.35), RtsCarbonUnit.Team.BLUE, RtsCarbonUnit.Role.SQUAD],
	[Vector2(4.5, 13.5), RtsCarbonUnit.Team.BLUE, RtsCarbonUnit.Role.TANK],
	[Vector2(17.4, 7.4), RtsCarbonUnit.Team.RED, RtsCarbonUnit.Role.COMMANDER],
	[Vector2(17.4, 8.5), RtsCarbonUnit.Team.RED, RtsCarbonUnit.Role.SQUAD],
	[Vector2(19.1, 6.85), RtsCarbonUnit.Team.RED, RtsCarbonUnit.Role.TANK],
]
const TEAM_BLUE := Color("#81d6ff")
const TEAM_RED := Color("#ff8264")
const AMBER := Color("#ffd170")

@export var layout: ForestClaimLayout

@onready var landscape: ForestClaimLandscape = $Landscape
var _map_outline := Rect2()
var _home := Vector2.ZERO
var _pointer_down := false
var _last_order := Vector2(-1, -1)
var _last_minimap_order := Vector2(-1, -1)
var _track_stamps: Array[Dictionary] = []


func _ready() -> void:
	landscape.build(layout, world_ysort)
	_orichalcum_pos = landscape.objective
	grid.blocked_cells = landscape.blocked_image()
	grid.setup()

	var far := Vector2(layout.size()) * ForestClaimProjection.CELL
	_map_outline = Rect2(ForestClaimProjection.point(Vector2(0, far.y)), Vector2.ZERO)
	for corner in [Vector2.ZERO, Vector2(far.x, 0), far]:
		_map_outline = _map_outline.expand(ForestClaimProjection.point(corner))
	_home = ForestClaimProjection.point(_orichalcum_pos) + Vector2(-27, 31)
	hud.world_size = far
	hud.mission_title = "Forest Claim  ·  " + layout.label
	hud.fixed_painted_style = true
	hud.tank_caption = "Two routes around the shelf"
	hud.minimap_projection = ForestClaimProjection.GROUND
	hud.minimap_map_bounds = _map_outline
	hud.minimap_tex = landscape.minimap(_map_outline)
	hud.load_portraits("")
	hud.blue_total = 3
	hud.orichalcum = 0
	hud.command_button_pressed.connect(_on_hud_command)
	hud.toggle_requested.connect(_on_hud_toggle)
	hud.minimap_pan_requested.connect(set_camera_focus)
	hud.minimap_order_requested.connect(_on_minimap_order)
	fx_layer.draw.connect(_draw_combat_fx)
	tracks_layer.draw.connect(_draw_surface_marks)
	overlay_layer.draw.connect(_draw_selection_overlay)

	red_ai_active = true
	reset_encounter()


func reset_encounter() -> void:
	var units := get_living_units()
	set_selection([])
	for unit in units:
		grid.release(unit._claimed_cell, unit)
		unit.remove_from_group("rts_carbon_units")
		unit.set_physics_process(false)
		unit._visual_anchor.queue_free()
	_markers.clear()
	_tracers.clear()
	_flashes.clear()
	_dust.clear()
	_footprints.clear()
	_mend_rings.clear()
	_track_stamps.clear()
	hold_seconds_left = HOLD_DURATION
	hold_owner = 0
	match_finished = false
	hud.command_cursor_mode = ""
	_ai_clock = 8.0
	for spawn in SPAWNS:
		_add_unit(Vector2(spawn[0]) * ForestClaimProjection.CELL, spawn[1], spawn[2])
	_cam_center = _home
	close_zoom = false
	apply_zoom_framing()
	_select_initial_group()
	_sync_hud_state()
	fx_layer.queue_redraw()
	tracks_layer.queue_redraw()


func _add_unit(at: Vector2, team: RtsCarbonUnit.Team, role: RtsCarbonUnit.Role) -> void:
	var unit := ForestClaimUnit.new()
	unit.position = at
	unit.team = team
	unit.role = role
	var blue := team == RtsCarbonUnit.Team.BLUE
	var faction := "Blue" if blue else "Red"
	var prefix := faction.to_lower() + "_"
	match role:
		RtsCarbonUnit.Role.COMMANDER:
			unit.display_name = faction + " Commander"
			unit.subtitle = "Royal Guard · Mend" if blue else "Order Field Leader"
			unit.portrait_key = prefix + "commander"
			unit.sprite_key = unit.portrait_key
			unit.max_health = 96 if blue else 92
			unit.attack_damage = 16
			unit.armour = 4
			unit.attack_range_cells = 4.6
			unit.guard_range_cells = 5.2
			unit.attack_cooldown = 0.90
			unit.speed_px = 69.0
		RtsCarbonUnit.Role.SQUAD:
			unit.display_name = "Rifle Squad" if blue else "Legionaries"
			unit.subtitle = faction + " Infantry"
			unit.portrait_key = prefix + "squad"
			unit.sprite_key = prefix + "soldier"
			unit.max_health = 68 if blue else 64
			unit.attack_damage = 13 if blue else 12
			unit.attack_range_cells = 4.2
			unit.guard_range_cells = 4.8
			unit.speed_px = 72.0
		RtsCarbonUnit.Role.TANK:
			unit.display_name = "Vanguard Tank" if blue else "Ironclad Tank"
			unit.subtitle = faction + " Heavy Armour"
			unit.portrait_key = prefix + "tank"
			unit.sprite_key = unit.portrait_key
			unit.max_health = 135 if blue else 130
			unit.attack_damage = 22 if blue else 20
			unit.armour = 6
			unit.attack_range_cells = 4.9
			unit.guard_range_cells = 5.5
			unit.attack_cooldown = 1.35
			unit.speed_px = 78.0
			unit.turn_rate = 5.5
	unit.mount(world_ysort)
	unit.setup(self, grid, false)
	unit.facing = Vector2(0.87, -0.49) * (1.0 if blue else -1.0)
	unit.hull_angle = unit.facing.angle()
	unit.turret_angle = unit.hull_angle
	unit.sync_visual()


func ground_to_screen(at: Vector2) -> Vector2:
	return get_canvas_transform() * ForestClaimProjection.point(at)


func screen_to_ground(at: Vector2) -> Vector2:
	return ForestClaimProjection.world(get_canvas_transform().affine_inverse() * at)


func set_camera_focus(world_pt: Vector2) -> void:
	_cam_center = ForestClaimProjection.point(world_pt)
	_sync_camera_transform()


func _sync_camera_transform() -> void:
	if camera == null or hud == null or not _map_outline.has_area():
		return
	var play := hud.playable_screen_rect()
	var z := play.size.x / (568.0 if close_zoom else 938.0) * _custom_zoom_mult
	camera.zoom = Vector2.ONE * z
	_cam_center = _cam_center.clamp(_map_outline.position, _map_outline.end)
	camera.position = _cam_center + (get_viewport_rect().size * 0.5 - play.get_center()) / z
	camera.force_update_scroll()
	var size := play.size / z
	hud.camera_world_rect = Rect2(_cam_center - size * 0.5, size)
	hud.request_repaint()


func _on_hud_toggle(which: String) -> void:
	if which == "menu":
		_exit_scene()
	elif which != "style":
		super(which)


func _exit_scene() -> void:
	var launcher := get_node_or_null("/root/BuildLauncher")
	if launcher != null and launcher.is_build_active():
		launcher._return_to_developers_page()
	else:
		super()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_V:
				return
			KEY_1:
				_cam_center = _home
				_sync_camera_transform()
				return
			KEY_2:
				set_camera_focus(_orichalcum_pos)
				return
			KEY_3:
				set_camera_focus(Vector2(SPAWNS[0][0]) * ForestClaimProjection.CELL)
				return
			KEY_F1:
				grid.show_debug = not grid.show_debug
				overlay_layer.queue_redraw()
				return
	if event is InputEventKey:
		super(event)


func _input(event: InputEvent) -> void:
	if hud == null or not is_instance_valid(grid) or not grid.is_node_ready():
		return
	var play := hud.playable_screen_rect()
	if event is InputEventMouseButton:
		var inside := play.has_point(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _pointer_down:
			_pointer_down = false
			var iso := ForestClaimProjection.point(screen_to_ground(event.position.clamp(play.position, play.end)))
			if _dragging_box:
				_select_in_box(Rect2(_press_world, Vector2.ZERO).expand(iso), event.shift_pressed)
			elif inside:
				_click_select(ForestClaimProjection.world(iso), event.shift_pressed)
			_dragging_box = false
			overlay_layer.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed and _pan_dragging:
			_pan_dragging = false
		elif not inside or not event.pressed:
			return
		else:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					if hud.command_cursor_mode != "":
						_issue_screen_order(event.position, hud.command_cursor_mode)
						hud.command_cursor_mode = ""
					else:
						_pointer_down = true
						_press_screen = event.position
						_press_world = ForestClaimProjection.point(screen_to_ground(event.position))
						_drag_world = _press_world
				MOUSE_BUTTON_RIGHT:
					hud.command_cursor_mode = ""
					_issue_screen_order(event.position)
				MOUSE_BUTTON_MIDDLE:
					_pan_dragging = true
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
					var before := ForestClaimProjection.point(screen_to_ground(event.position))
					var factor := 1.14 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.14
					_custom_zoom_mult = clampf(_custom_zoom_mult * factor, 0.83, 2.02)
					_sync_camera_transform()
					_cam_center += before - ForestClaimProjection.point(screen_to_ground(event.position))
					_sync_camera_transform()
				_:
					return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _pan_dragging:
			_cam_center -= event.relative / camera.zoom.x
			_sync_camera_transform()
			get_viewport().set_input_as_handled()
		elif _pointer_down:
			var clamped := Vector2(event.position).clamp(play.position, play.end)
			_drag_world = ForestClaimProjection.point(screen_to_ground(clamped))
			_dragging_box = _dragging_box or clamped.distance_to(_press_screen) > 6.0
			overlay_layer.queue_redraw()
			get_viewport().set_input_as_handled()


func _unit_under(world_pt: Vector2) -> RtsCarbonUnit:
	var iso := ForestClaimProjection.point(world_pt)
	var units := get_living_units()
	var best: RtsCarbonUnit
	var distance := INF
	for unit in units:
		var offset := iso - ForestClaimProjection.point(unit.position)
		var pick := Vector2(offset.x, offset.y + 6.0)
		if absf(pick.x) <= unit.select_radius() + 1.0 and pick.y > -21.0 and pick.y < 15.0:
			var d := pick.length_squared()
			if d < distance:
				best = unit
				distance = d
	return best


func _select_in_box(box: Rect2, additive: bool) -> void:
	var picked: Array[RtsCarbonUnit] = []
	if additive:
		picked.assign(selection)
	for unit in get_living_units():
		if unit.team != RtsCarbonUnit.Team.BLUE or unit in picked:
			continue
		if box.grow(unit.select_radius() * 0.55).has_point(ForestClaimProjection.point(unit.position) - Vector2(0, 5)):
			picked.append(unit)
	set_selection(picked)


func _issue_screen_order(screen: Vector2, forced_mode := "") -> void:
	var world := screen_to_ground(screen)
	var clicked := _unit_under(world)
	var attack := forced_mode == "attack" or (forced_mode == "" and clicked != null and clicked.team == RtsCarbonUnit.Team.RED)
	if not attack and not selection.is_empty() and landscape.hits_cliff(ForestClaimProjection.point(world)):
		_mark_blocked(world)
		return
	issue_order_at(world, forced_mode)


func _mark_blocked(at: Vector2) -> void:
	_markers.append({"pos": at, "age": 0.0, "max_age": 0.5, "color": Color("#f99176"), "blocked": true})


func issue_order_at(world_pt: Vector2, forced_mode := "") -> void:
	if selection.is_empty():
		return
	var clicked := _unit_under(world_pt)
	var attack := forced_mode == "attack" or (forced_mode == "" and clicked != null and clicked.team == RtsCarbonUnit.Team.RED)
	if not attack and not grid.is_walkable(grid.cell_of(world_pt)):
		_mark_blocked(world_pt)
		return
	_last_order = world_pt
	var marker_count := _markers.size()
	super(world_pt, forced_mode)
	if not attack and selection.size() == 1 and _markers.size() > marker_count:
		_markers[-1].pos = selection[0].move_goal_world


func _on_minimap_order(at: Vector2) -> void:
	_last_minimap_order = at
	issue_order_at(at, "move")


func _tick_red_ai(delta: float) -> void:
	_ai_clock -= delta
	if _ai_clock > 0.0:
		return
	_ai_clock = 1.8
	var red_slots := [Vector2(14.5, 9.5), Vector2(14.2, 10.9), Vector2(15.0, 8.0)]
	for unit in get_living_units():
		if unit.team == RtsCarbonUnit.Team.RED and unit.order == RtsCarbonUnit.Order.NONE:
			var goal: Vector2 = red_slots[unit.role] * ForestClaimProjection.CELL
			if unit.position.distance_to(goal) > 12.0:
				unit.command_move(goal)


func shade_at(world_pt: Vector2) -> float:
	return landscape.shade(world_pt)


func record_tank_treads(prev_pos: Vector2, prev_dir: Vector2, next_pos: Vector2, next_dir: Vector2) -> void:
	var span := 9.0
	for side in [-1.0, 1.0]:
		_track_stamps.append({"a": ForestClaimProjection.point(prev_pos + prev_dir.orthogonal() * span * side),
			"b": ForestClaimProjection.point(next_pos + next_dir.orthogonal() * span * side), "age": 0.0})


func _tick_fx_and_treads(delta: float) -> void:
	_tick_effects(delta)
	if not _track_stamps.is_empty():
		for stamp in _track_stamps:
			stamp.age += delta
		_track_stamps = _track_stamps.filter(func(stamp: Dictionary) -> bool: return float(stamp.age) < 7.0)
		tracks_layer.queue_redraw()
	overlay_layer.queue_redraw()
	_update_canopy_fade(delta)


func _update_canopy_fade(delta: float) -> void:
	for instance in landscape.scenery:
		if not ForestClaimKit.PIECES[instance.piece].tree:
			continue
		var art: Sprite2D = instance.art
		var covered := false
		for unit in selection:
			if is_instance_valid(unit) and landscape.covers(instance, unit.position):
				covered = true
				break
		art.modulate.a = move_toward(art.modulate.a, 0.32 if covered else 1.0, delta * 4.0)


func _draw_surface_marks() -> void:
	for stamp in _track_stamps:
		tracks_layer.draw_line(stamp.a, stamp.b, Color(0.17, 0.13, 0.08, 0.24 * (1.0 - float(stamp.age) / 7.0)), 1.65, true)
	for fp in _footprints:
		var at := ForestClaimProjection.point(fp.pos)
		tracks_layer.draw_circle(at, 0.85, Color(0.16, 0.14, 0.08, 0.40 * (1.0 - float(fp.age) / 5.5)))


func _projected_arc(at: Vector2, radius: float, color: Color, width: float, dotted := false) -> void:
	var points := PackedVector2Array()
	for i in range(65):
		var p := ForestClaimProjection.point(at + Vector2.from_angle(float(i) * TAU / 64.0) * radius)
		if dotted:
			fx_layer.draw_circle(p, 1.45, color, true, -1, true)
		else:
			points.append(p)
	if not dotted:
		fx_layer.draw_polyline(points, color, width, true)


func _draw_combat_fx() -> void:
	var ring := AMBER if hold_owner == 0 else (TEAM_BLUE if hold_owner == 1 else TEAM_RED)
	ring.a = 0.75
	_projected_arc(_orichalcum_pos, HOLD_RADIUS, ring, 1.0, true)
	for m in _markers:
		var strength := 1.0 - float(m.age) / float(m.max_age)
		var p := ForestClaimProjection.point(m.pos)
		var color: Color = m.color
		color.a = strength
		if m.get("blocked", false):
			fx_layer.draw_line(p - Vector2(5, 5), p + Vector2(5, 5), color, 2.0, true)
			fx_layer.draw_line(p - Vector2(5, -5), p + Vector2(5, -5), color, 2.0, true)
		else:
			_projected_arc(m.pos, lerpf(19.0, 6.0, strength), color, 1.5)
			fx_layer.draw_circle(p, 2.1, color, true, -1, true)
	for mend in _mend_rings:
		var t := float(mend.age) / 0.65
		_projected_arc(mend.pos, lerpf(16.0, float(mend.radius), t), Color(0.41, 0.98, 1.0, 0.95 * (1.0 - t)), 2.2)
	for trail in _tracers:
		var strength := 1.0 - float(trail.age) / float(trail.max_age)
		var a := ForestClaimProjection.point(trail.a, 8.0)
		var b := ForestClaimProjection.point(trail.b, 7.0)
		var color := TEAM_BLUE if trail.blue else TEAM_RED
		if trail.heavy:
			color = AMBER
		color.a = strength
		fx_layer.draw_line(a, b, color, 2.5 if trail.heavy else 1.5, true)
	for flash in _flashes:
		var t := float(flash.age) / float(flash.max_age)
		var color: Color = flash.color
		color.a *= 1.0 - t
		fx_layer.draw_circle(ForestClaimProjection.point(flash.pos, 8.0), float(flash.radius) * (0.5 + t * 0.4), color, true, -1, true)
	for dust in _dust:
		var t := float(dust.age) / float(dust.max_age)
		fx_layer.draw_circle(ForestClaimProjection.point(dust.pos), float(dust.size) * (0.9 + t * 0.9),
			Color(0.81, 0.70, 0.46, 0.28 * (1.0 - t)))


func _draw_selection_overlay() -> void:
	if _dragging_box:
		super()
	for unit in selection:
		if not is_instance_valid(unit):
			continue
		var at := ForestClaimProjection.point(unit.position)
		var top := at + Vector2(0, -31)
		overlay_layer.draw_polyline(PackedVector2Array([top + Vector2(-5, -3), top + Vector2(0, 2), top + Vector2(5, -3)]),
			TEAM_BLUE, 1.9, true)
	if grid.show_debug:
		for cell: Vector2i in landscape.occupied:
			var point := ForestClaimProjection.point(grid.center_of(cell))
			overlay_layer.draw_circle(point, 2.5, Color(1, 0.35, 0.23, 0.62))
