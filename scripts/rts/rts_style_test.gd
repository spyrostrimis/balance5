extends Node2D
## RTS style test: one screen with every art layer, to judge the look against the reference.
## Built by tools/python/make_rts_style_test.py. Keys toggle layers so each one's effect shows:
##   T cycles test 1 (procedural) / 2 (painted textures) / 3 (sand relief, kitbash scatter)   1 dunes   2 road   3 rocks   4 scatter
##   5 units   R reference (same scale)   G 32 px tile grid
##   Z art pixel = 2 screen pixels at 1080p (zoom 4/3) vs 1 (zoom 2/3)

const GRID_COLOR := Color(0, 0, 0, 0.18)
const TESTS := ["Test1", "Test2", "Test3"]
const TEST_NAMES := ["1 procedural", "2 painted", "3 sand relief"]

var _show_grid := false

@onready var _help: Label = $HUD/Help
@onready var _camera: Camera2D = $Camera


func _ready() -> void:
	_update_help()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_T:
			var next := (_current_test() + 1) % TESTS.size()
			for i in TESTS.size():
				(get_node(TESTS[i]) as CanvasItem).visible = i == next
		KEY_1:
			_toggle_layer("Dunes")
		KEY_2:
			_toggle_layer("Road")
		KEY_3:
			_toggle_layer("Rocks")
		KEY_4:
			_toggle_layer("Scatter")
		KEY_5:
			_toggle($Units)
		KEY_R:
			_toggle($Reference)
		KEY_G:
			_show_grid = not _show_grid
			queue_redraw()
		KEY_Z:
			var z := 2.0 / 3.0 if _camera.zoom.x > 1.0 else 4.0 / 3.0
			_camera.zoom = Vector2(z, z)
		_:
			return
	get_viewport().set_input_as_handled()
	_update_help()


## Layers exist once per test; switch them together so T compares like with like.
func _toggle_layer(layer: String) -> void:
	for test in TESTS:
		_toggle(get_node("%s/%s" % [test, layer]))


func _current_test() -> int:
	for i in TESTS.size():
		if (get_node(TESTS[i]) as CanvasItem).visible:
			return i
	return 0


func _toggle(node: CanvasItem) -> void:
	node.visible = not node.visible


func _draw() -> void:
	if not _show_grid:
		return
	for x in range(0, 961, 32):
		draw_line(Vector2(x, 0), Vector2(x, 540), GRID_COLOR, 1.0)
	for y in range(0, 541, 32):
		draw_line(Vector2(0, y), Vector2(960, y), GRID_COLOR, 1.0)


func _update_help() -> void:
	var test: String = TEST_NAMES[_current_test()]
	var on := func(path: String) -> String: return "on" if (get_node(path) as CanvasItem).visible else "off"
	_help.text = "T test %s · 1 dunes %s · 2 road %s · 3 rocks %s · 4 scatter %s · 5 units %s · R reference %s · G grid · Z zoom %.2f · Esc back" % [
		test, on.call("Test3/Dunes"), on.call("Test3/Road"), on.call("Test3/Rocks"), on.call("Test3/Scatter"),
		on.call("Units"), on.call("Reference"), _camera.zoom.x]
