extends Node2D
## RTS test map: wires the grid, units, commands and camera together.
## The ground is a TileMapLayer you can repaint in the editor; tiles carry a "walkable" flag.
## Built once by tools/godot/build_rts_test_map.gd. F1 toggles the tile overlay.

@onready var grid: RtsGrid = $Grid
@onready var units: Node2D = $Units
@onready var commands: RtsCommands = $Commands
@onready var camera: RtsCamera = $Camera
@onready var _help: Label = $HUD/Help


func _ready() -> void:
	for node in units.get_children():
		if node is RtsUnit:
			(node as RtsUnit).setup(grid)
	var commander := units.get_node_or_null("BlueCommander") as Node2D
	if commander != null:
		camera.look_at_point(commander.position + Vector2(260, 60))
	_help.text = (
		"Left-click or drag: select Blue  ·  Shift: add  ·  Right-click: move / attack  ·  S: stop  ·  "
		+ "Arrows, screen edge or middle-drag: scroll  ·  Wheel: zoom  ·  F1: tiles  ·  Esc: back"
	)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F1:
		grid.show_debug = not grid.show_debug
		get_viewport().set_input_as_handled()
