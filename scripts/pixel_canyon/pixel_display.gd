extends Control

const ART_SIZE := Vector2i(960, 540)

var _window: Window
var _previous_scale_mode: Window.ContentScaleMode

@onready var canvas: SubViewport = $Canvas
@onready var picture: TextureRect = $Picture


func _ready() -> void:
	_window = get_window()
	_previous_scale_mode = _window.content_scale_mode
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	picture.texture = canvas.get_texture()
	resized.connect(_fit_picture)
	_fit_picture()


func _exit_tree() -> void:
	if is_instance_valid(_window):
		_window.content_scale_mode = _previous_scale_mode


func _fit_picture() -> void:
	var fit := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	var zoom := floorf(fit) if fit >= 1.0 else fit
	picture.size = (Vector2(ART_SIZE) * zoom).floor()
	picture.position = ((size - picture.size) * 0.5).floor()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var world = $Canvas/World
	match event.keycode:
		KEY_F1:
			world.show_controls()
		KEY_F2:
			world.set_reference(not world.showing_reference)
		KEY_1, KEY_2, KEY_3:
			if world.top_extension:
				world.set_comparison(event.keycode - KEY_1)
		KEY_F11:
			if _window.mode == Window.MODE_FULLSCREEN or _window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
				_window.mode = Window.MODE_WINDOWED
			else:
				_window.mode = Window.MODE_FULLSCREEN
