extends "res://scripts/pixel_canyon/pixel_display.gd"


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F11:
		super._unhandled_key_input(event)
