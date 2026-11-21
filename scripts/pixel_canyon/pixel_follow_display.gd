extends "res://scripts/pixel_canyon/pixel_display.gd"


func _handle_study_key(key: Key) -> void:
	var world = $Canvas/World
	match key:
		KEY_1:
			world.set_leeway(0.0)
		KEY_2:
			world.set_leeway(8.0)
		KEY_F3:
			world.set_rough_art(not world.rough_art)
