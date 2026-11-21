extends "res://scripts/canyon/canyon_packs_test.gd"
## 3D kit study (Option 2): real modelled pieces with pixel textures on canyon v2, building on the
## free-packs scene (boulders and the scan rock stay). Pieces so far:
##   K  real curb blocks along both road edges (scripts/canyon/canyon_curbs.gd); KIT_CURBS=0 starts hidden.
##   W  new stepped cliffs (scripts/canyon/canyon_cliffs.gd) or the old kitbash walls; KIT_CLIFFS=0 starts
##      with the old walls.
## The curbs follow the surface set: art* sets use the ChatGPT colours, every other mode the goal palette.

var _curbs: Node3D
var _cliffs: Node3D
const OLD_WALLS := ["Terrace", "Gateway", "RightButtress"]


func _ready() -> void:
	_curbs = preload("res://scripts/canyon/canyon_curbs.gd").new()
	_curbs.name = "Curbs"
	add_child(_curbs)
	_curbs.build(get_node(route_path))
	_cliffs = preload("res://scripts/canyon/canyon_cliffs.gd").new()
	_cliffs.name = "Cliffs"
	add_child(_cliffs)
	_cliffs.build(get_node(route_path))
	super()
	_curbs.visible = OS.get_environment("KIT_CURBS") != "0"
	_set_curb_colliders(_curbs.visible)
	_show_new_cliffs(OS.get_environment("KIT_CLIFFS") != "0")


func set_mode(value: String) -> void:
	super(value)
	if _curbs:
		_curbs.look = "gpt" if value.begins_with("art") else "goal"
	if _cliffs:
		_cliffs.look = "gpt" if value.begins_with("art") else "goal"


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_W:
		_show_new_cliffs(not _cliffs.visible)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		_curbs.visible = not _curbs.visible
		_set_curb_colliders(_curbs.visible)
		get_viewport().set_input_as_handled()
		return
	super(event)


func _set_curb_colliders(on: bool) -> void:
	var body := _curbs.get_node_or_null("CurbColliders") as StaticBody3D
	if body:
		body.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _show_new_cliffs(on: bool) -> void:
	_cliffs.visible = on
	for child in get_node("Layout").get_children():
		for prefix: String in OLD_WALLS:
			if String(child.name).begins_with(prefix):
				(child as Node3D).visible = not on
