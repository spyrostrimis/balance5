class_name RtsCommands
extends Node2D
## The player's hand: selecting units and giving orders with the mouse.
##   Left-click a unit: select it.     Shift + left-click: add or remove it.
##   Left-drag: box-select.            Left-click empty ground: clear the selection.
##   Right-click ground: move there.   Right-click an enemy: attack it.
##   S: stop.
## Only the player's own faction can be selected. Draws the drag box and order markers.

signal selection_changed(units: Array[RtsUnit])

const DRAG_THRESHOLD := 6.0  # screen pixels before a click becomes a box
const MARKER_TIME := 0.5
const BOX_LINE := Color(0.35, 1.0, 0.35)
const BOX_FILL := Color(0.35, 1.0, 0.35, 0.12)
const MOVE_MARK := Color(0.35, 1.0, 0.35)
const ATTACK_MARK := Color(1.0, 0.3, 0.25)

@export var units_path: NodePath = ^"../Units"
@export var grid_path: NodePath = ^"../Grid"
@export var player_faction: UnitStats.Faction = UnitStats.Faction.BLUE

var selection: Array[RtsUnit] = []

var _pressing := false
var _box_active := false
var _press_screen := Vector2.ZERO
var _press_world := Vector2.ZERO
var _drag_world := Vector2.ZERO
var _markers: Array[Dictionary] = []  # {pos, time, color}

@onready var _units_root: Node = get_node(units_path)
@onready var _grid: RtsGrid = get_node(grid_path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var world := _event_world(mb)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_box_active = false
				_press_screen = mb.position
				_press_world = world
				_drag_world = world
			elif _pressing:
				_pressing = false
				if _box_active:
					select_in_rect(Rect2(_press_world, Vector2.ZERO).expand(world), mb.shift_pressed)
				else:
					click_select(world, mb.shift_pressed)
				_box_active = false
				queue_redraw()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			order_at(world)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pressing:
		var motion := event as InputEventMouseMotion
		_drag_world = _event_world(motion)
		if not _box_active and motion.position.distance_to(_press_screen) > DRAG_THRESHOLD:
			_box_active = true
		queue_redraw()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_S:
			stop_selected()
			get_viewport().set_input_as_handled()


## The map position under a mouse event (this node sits at the map origin).
func _event_world(event: InputEventMouse) -> Vector2:
	return (make_input_local(event) as InputEventMouse).position


func _process(delta: float) -> void:
	var changed := false
	for i in range(selection.size() - 1, -1, -1):
		if not is_instance_valid(selection[i]) or not selection[i].alive:
			selection.remove_at(i)
			changed = true
	if changed:
		selection_changed.emit(selection)
	if not _markers.is_empty():
		for m in _markers:
			m.time -= delta
		_markers = _markers.filter(func(m: Dictionary) -> bool: return m.time > 0.0)
		queue_redraw()


# --- Selection -----------------------------------------------------------------------------

func all_units() -> Array[RtsUnit]:
	var out: Array[RtsUnit] = []
	for node in _units_root.get_children():
		var unit := node as RtsUnit
		if unit != null and unit.alive:
			out.append(unit)
	return out


## The living unit under a world position, or null.
func unit_at(world: Vector2) -> RtsUnit:
	var best: RtsUnit = null
	var best_dist := INF
	for unit in all_units():
		var d := unit.position.distance_to(world)
		if d <= unit.radius() + 4.0 and d < best_dist:
			best = unit
			best_dist = d
	return best


func click_select(world: Vector2, add := false) -> void:
	var unit := unit_at(world)
	if unit != null and unit.stats.faction == player_faction:
		if not add:
			set_selection([unit])
		elif unit in selection:
			set_selection(selection.filter(func(u: RtsUnit) -> bool: return u != unit))
		else:
			set_selection(selection + [unit])
	elif not add:
		set_selection([])


func select_in_rect(rect: Rect2, add := false) -> void:
	var picked: Array[RtsUnit] = []
	if add:
		picked.assign(selection)
	for unit in all_units():
		if unit.stats.faction == player_faction and rect.grow(unit.radius() * 0.5).has_point(unit.position) and not unit in picked:
			picked.append(unit)
	set_selection(picked)


func set_selection(units: Array) -> void:
	for unit in selection:
		if is_instance_valid(unit):
			unit.selected = false
	selection.clear()
	for unit in units:
		if is_instance_valid(unit) and unit.alive:
			selection.append(unit)
			unit.selected = true
	selection_changed.emit(selection)


# --- Orders --------------------------------------------------------------------------------

## Right-click: attack the enemy under the cursor, otherwise move there.
func order_at(world: Vector2) -> void:
	if selection.is_empty():
		return
	var clicked := unit_at(world)
	if clicked != null and clicked.stats.faction != player_faction:
		for unit in selection:
			unit.command_attack(clicked)
		_markers.append({pos = clicked.position, time = MARKER_TIME, color = ATTACK_MARK})
	else:
		move_group(selection, _grid.cell_of(world))
		_markers.append({pos = world, time = MARKER_TIME, color = MOVE_MARK})
	queue_redraw()


## Sends units to the free tiles nearest `cell`, one unit per tile, nearest unit first.
func move_group(units: Array, cell: Vector2i) -> Dictionary:
	var spots := _grid.free_cells_near(cell, units.size(), units)
	var waiting: Array = units.duplicate()
	var assigned := {}
	for spot in spots:
		var spot_pos := _grid.center_of(spot)
		var nearest: RtsUnit = null
		for unit: RtsUnit in waiting:
			if nearest == null or unit.position.distance_squared_to(spot_pos) < nearest.position.distance_squared_to(spot_pos):
				nearest = unit
		waiting.erase(nearest)
		nearest.command_move(spot)
		assigned[nearest] = spot
	for unit: RtsUnit in waiting:  # No room left: walk as close as possible.
		unit.command_move(cell)
		assigned[unit] = cell
	return assigned


func stop_selected() -> void:
	for unit in selection:
		unit.command_stop()


# --- Drawing -------------------------------------------------------------------------------

func _draw() -> void:
	var zoom := get_viewport().get_camera_2d().zoom.x if get_viewport().get_camera_2d() != null else 1.0
	var width := 1.5 / zoom
	if _pressing and _box_active:
		var rect := Rect2(_press_world, Vector2.ZERO).expand(_drag_world)
		draw_rect(rect, BOX_FILL)
		draw_rect(rect, BOX_LINE, false, width)
	for m in _markers:
		var t: float = m.time / MARKER_TIME
		var col: Color = m.color
		col.a = t
		var s := 4.0 + 8.0 * (1.0 - t)
		var p: Vector2 = m.pos
		draw_arc(p, s + 4.0, 0.0, TAU, 20, col, 2.0)
		draw_line(p + Vector2(-s, -s) * 0.5, p + Vector2(s, s) * 0.5, col, 2.0)
		draw_line(p + Vector2(-s, s) * 0.5, p + Vector2(s, -s) * 0.5, col, 2.0)
