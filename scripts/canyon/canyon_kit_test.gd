extends "res://scripts/canyon/canyon_packs_test.gd"
## 3D kit study (Option 2): real modelled pieces with pixel textures on canyon v2, building on the
## free-packs scene (boulders and the scan rock stay). Pieces so far:
##   K  real curb blocks along both road edges (scripts/canyon/canyon_curbs.gd); KIT_CURBS=0 starts hidden.
##   B  new pixel bushes and grass (scripts/canyon/canyon_bushes.gd) or the old bush cards; KIT_BUSHES=0
##      starts with the old ones.
##   N  new road and sand tiles (tools/python/build_road_tiles.py, sets art_road_goal / art_road_gpt) or
##      the previous road of the same look.
##   M  goal colours: every kit piece repainted with five colour ramps from the goal image (art_road_ramp)
##   W  new stepped cliffs (scripts/canyon/canyon_cliffs.gd) or the old kitbash walls; KIT_CLIFFS=0 starts
##      with the old walls.
## The kit pieces follow the surface set: art* sets use the ChatGPT colours (except art_road_goal), every
## other mode the goal palette. The ground's painted wall shading moves out with the cliffs, and the sand
## just outside the curbs is darker (curb_dust).

var _curbs: Node3D
var _cliffs: Node3D
var _bushes: Node3D
const ROAD_SWAP := {"B64": "art_road_goal", "art_road_goal": "B64", "art_gpt": "art_road_gpt", "art_road_gpt": "art_gpt"}
## M toggles the goal-colour look (art_road_ramp) and back to the mode before it.
var _before_ramp := "B64"
@export var curb_dust := 0.3
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
	_bushes = preload("res://scripts/canyon/canyon_bushes.gd").new()
	_bushes.name = "Bushes"
	add_child(_bushes)
	_bushes.build(get_node(route_path), _cliffs, _boulder_positions())
	super()
	_curbs.visible = OS.get_environment("KIT_CURBS") != "0"
	_set_curb_colliders(_curbs.visible)
	_show_new_cliffs(OS.get_environment("KIT_CLIFFS") != "0")
	_show_new_bushes(OS.get_environment("KIT_BUSHES") != "0")


func set_mode(value: String) -> void:
	super(value)
	var kit_look := "gpt" if value.begins_with("art") and not value.ends_with("goal") else "goal"
	if value.ends_with("ramp"):
		kit_look = "ramp"  # five colour families from the goal image (tools/python/recolor_kit.py)
	if _curbs:
		_curbs.look = kit_look
	if _bushes:
		_bushes.look = kit_look
	if _cliffs:
		_cliffs.look = kit_look
	if value != "A" and not _floor_slot.is_empty():
		var ground := _material_for(_floor_slot["original"], value)
		ground.set_shader_parameter("cliff_ao_range", Vector2(2.3, 3.4))
		ground.set_shader_parameter("curb_dust", curb_dust)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		if mode == "art_road_ramp":
			set_mode(_before_ramp)
		else:
			_before_ramp = mode
			set_mode("art_road_ramp")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		if ROAD_SWAP.has(mode):
			set_mode(ROAD_SWAP[mode])
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		_show_new_bushes(not _bushes.visible)
		get_viewport().set_input_as_handled()
		return
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


func _show_new_bushes(on: bool) -> void:
	_bushes.visible = on
	for child in get_node("Layout").get_children():
		if String(child.name).begins_with("Bush"):
			(child as Node3D).visible = not on


## Boulders the plants should keep clear of: the layout's boulders and the pack rocks.
func _boulder_positions() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for child in get_node("Layout").get_children():
		var n := String(child.name)
		if n.begins_with("Boulder") or n.begins_with("ChatGPTBoulder"):
			points.append((child as Node3D).global_position)
	var packs := get_node_or_null("PackModels")
	if packs:
		for child in packs.get_children():
			points.append((child as Node3D).global_position)
	return points
