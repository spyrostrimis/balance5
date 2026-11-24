extends Node2D
## RTS units test: units walking, driving and fighting on the style test 5 map, to judge whether
## they look grounded or float. Built by tools/python/make_rts_units_test.py.
## Controls are the RTS test map's (select, right-click move/attack, S stop, wheel zoom). Keys:
##   P patrol (units wander peacefully)   K shadows   L ground light   M tracks and footprints
##   N dust   F1 blocked tiles

signal controls_changed

@onready var grid: RtsGrid = $Grid
@onready var units: Node2D = $Units
@onready var _help: Label = $HUD/Help

var patrol := false
var _patrol_timer := 0.0


func _ready() -> void:
	for node in units.get_children():
		if node is RtsUnit:
			(node as RtsUnit).setup(grid)
	_update_help()


func _process(delta: float) -> void:
	if not patrol:
		return
	_patrol_timer -= delta
	if _patrol_timer > 0.0:
		return
	_patrol_timer = 0.4
	for node in units.get_children():
		var unit := node as RtsUnit
		if unit == null or not unit.alive or unit.order != RtsUnit.Order.NONE or unit.is_moving():
			continue
		if randf() < 0.35:
			var target := unit.cell + Vector2i(randi_range(-8, 8), randi_range(-6, 6))
			var spots := grid.free_cells_near(target, 1)
			if not spots.is_empty():
				unit.command_move(spots[0])


func set_patrol(on: bool) -> void:
	patrol = on
	for node in units.get_children():
		if node is RtsUnit:
			(node as RtsUnit).peaceful = on
	_update_help()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_P:
			set_patrol(not patrol)
		KEY_K:
			RtsLook.shadows = not RtsLook.shadows
		KEY_L:
			RtsLook.ground_light = not RtsLook.ground_light
		KEY_M:
			RtsLook.marks = not RtsLook.marks
		KEY_N:
			RtsLook.dust = not RtsLook.dust
		KEY_F1:
			grid.show_debug = not grid.show_debug
		_:
			return
	get_viewport().set_input_as_handled()
	for node in units.get_children():
		(node as CanvasItem).queue_redraw()
	_update_help()


func _update_help() -> void:
	var on := func(v: bool) -> String: return "on" if v else "off"
	_help.text = "P patrol %s · K shadows %s · L ground light %s · M tracks %s · N dust %s · F1 tiles · select + right-click to move · Esc back" % [
		on.call(patrol), on.call(RtsLook.shadows), on.call(RtsLook.ground_light), on.call(RtsLook.marks), on.call(RtsLook.dust)]
	controls_changed.emit()
