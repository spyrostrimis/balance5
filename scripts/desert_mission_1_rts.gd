extends Node2D
## Root controller for RTS Mission 1 (2.5D pre-rendered battlefield + playable Blue Tank).

@onready var _collision_overlay: Node2D = $CollisionOverlay
@onready var _hint_label: Label = $HUD/HintPanel/HintLabel

var _show_collisions: bool = false


func _ready() -> void:
	_collision_overlay.setup(self)
	_update_overlay()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		set_show_collisions(not _show_collisions)
		get_viewport().set_input_as_handled()


func set_show_collisions(enabled: bool) -> void:
	_show_collisions = enabled
	_update_overlay()


func is_showing_collisions() -> bool:
	return _show_collisions


func _update_overlay() -> void:
	_collision_overlay.visible = _show_collisions
	_collision_overlay.queue_redraw()
	if _hint_label != null:
		var state := "ON" if _show_collisions else "OFF"
		_hint_label.text = (
			"Left/Right Click or WASD/Arrows to drive Blue Tank  ·  "
			+ "Press C to toggle collision outlines (%s)" % state
		)
