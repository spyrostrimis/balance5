extends SceneTree
## Windowed capture of the RTS style test at the game's real viewport (1280x720, zoom 4/3).
##   Godot --path . --script res://tests/capture_rts_style_test.gd
## Saves render_captures/rts_style/style_test.png, style_reference.png (R key) and style_grid.png (G key).

const SCENE := "res://scenes/maps/rts_style_test.tscn"
const DIR := "res://render_captures/rts_style"


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void: quit(1))
	_run.call_deferred()


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	root.push_input(ev)


func _capture(file: String) -> void:
	for i in 4:
		await process_frame
	DirAccess.make_dir_recursive_absolute(DIR)
	var img := root.get_texture().get_image()
	img.save_png(DIR + "/" + file)
	print("Captured ", file, " ", img.get_size())


func _run() -> void:
	root.add_child((load(SCENE) as PackedScene).instantiate())
	await _capture("style_test.png")
	_key(KEY_R)
	await _capture("style_reference.png")
	_key(KEY_R)
	_key(KEY_G)
	await _capture("style_grid.png")
	quit(0)
