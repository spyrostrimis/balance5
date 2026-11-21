extends SceneTree
## Windowed capture of the RTS units test: units patrol the style test 5 map; at the same moment
## the screen is captured with all grounding effects on and all off, as an overview and zoomed in
## on units crossing dunes and passing rocks.
##   Godot --path . --script res://tests/capture_rts_units_test.gd
## Saves render_captures/rts_units/<view>_on.png and <view>_off.png.

const SCENE := "res://scenes/maps/rts_units_test.tscn"
const DIR := "res://render_captures/rts_units"

var _map: Node2D


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void: quit(1))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _set_all(on: bool) -> void:
	RtsLook.shadows = on
	RtsLook.ground_light = on
	RtsLook.marks = on
	RtsLook.dust = on
	for node in _map.get_node("Units").get_children():
		(node as CanvasItem).queue_redraw()
	_map.get_node("Look").queue_redraw()


func _capture(file: String) -> void:
	await _frames(2)
	DirAccess.make_dir_recursive_absolute(DIR)
	root.get_texture().get_image().save_png(DIR + "/" + file)
	print("Captured ", file)


func _pair(view: String) -> void:
	_set_all(true)
	await _capture(view + "_on.png")
	_set_all(false)
	await _capture(view + "_off.png")
	_set_all(true)


func _run() -> void:
	_map = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_map)
	var camera := _map.get_node("Camera") as RtsCamera
	camera.edge_scroll = false
	await _frames(5)
	_map.set_patrol(true)
	var units := _map.get_node("Units").get_children()
	for i in 600:  # about 10 s of patrol
		await physics_frame
	await _pair("overview")
	# Zoom in on a tank and on an infantry squad wherever they are now.
	for unit_name in ["BlueTank", "RedSquad2", "RedTank"]:
		var unit := _map.get_node_or_null("Units/" + unit_name) as Node2D
		if unit == null:
			continue
		camera.zoom = Vector2(3.0, 3.0)
		camera.look_at_point(unit.position)
		await _pair("zoom_" + unit_name.to_lower())
		camera.zoom = Vector2(1.3333, 1.3333)
		camera.clamp_to_map()
	print("Units: ", units.map(func(u: Node) -> String: return "%s %s" % [u.name, (u as RtsUnit).cell]))
	quit(0)
