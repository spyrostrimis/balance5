extends RtsCarbonBattlefield

@onready var spring: Node2D = $YSortWorld/ShelteredSpring
@onready var roadside: Node2D = $YSortWorld/RoadsidePool

var _trees: Array[RtsCarbonPiece] = []


func _ready() -> void:
	super._ready()
	for piece in _pieces:
		if piece.piece_id == "spring_tree":
			_trees.append(piece)


func _process(delta: float) -> void:
	super._process(delta)
	for tree in _trees:
		var canopy := Rect2(tree.draw_offset - tree.world_size * 0.44, tree.world_size * 0.88)
		var obscures_selected := false
		for unit in selection:
			if not is_instance_valid(unit):
				continue
			var foot := tree.to_local(unit.global_position)
			if foot.y < 0.0 and canopy.has_point(foot):
				obscures_selected = true
				break
		tree.modulate.a = move_toward(tree.modulate.a, 0.38 if obscures_selected else 1.0, delta * 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_2:
				set_camera_focus(spring.global_position + Vector2(0, 44))
				get_viewport().set_input_as_handled()
				return
			KEY_3:
				set_camera_focus(roadside.global_position + Vector2(-64, -65))
				get_viewport().set_input_as_handled()
				return
	super._unhandled_input(event)
