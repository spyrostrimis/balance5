extends CanvasLayer

const OPENING_SCREEN := "res://scenes/ui/opening_screen.tscn"

var _launched_scene := ""
var _returning := false

@onready var _return_button: Button = $ReturnButton


func _ready() -> void:
	_return_button.pressed.connect(_return_to_developers_page)
	get_tree().scene_changed.connect(_update_return_button)


func launch(build: DeveloperBuild) -> Error:
	if not build.is_available():
		return ERR_FILE_NOT_FOUND
	var result := get_tree().change_scene_to_file(build.scene_path)
	if result == OK:
		_launched_scene = build.scene_path
	return result


func consume_return() -> bool:
	var returning := _returning
	_returning = false
	return returning


func _update_return_button() -> void:
	_return_button.visible = is_build_active()


func is_build_active() -> bool:
	var current := get_tree().current_scene
	return current != null and not _launched_scene.is_empty() and current.scene_file_path == _launched_scene


func _unhandled_key_input(event: InputEvent) -> void:
	if _return_button.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_developers_page()


func _return_to_developers_page() -> void:
	var result := get_tree().change_scene_to_file(OPENING_SCREEN)
	if result == OK:
		_returning = true
		_launched_scene = ""
		_return_button.hide()
	else:
		push_error("Could not return to the Developers Page: " + error_string(result))
