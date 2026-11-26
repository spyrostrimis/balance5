extends RtsCarbonBattlefield
## Playable Mission 1 desert battlefield for RTS Reusable 4.
## Carries forward Carbon's gameplay, zooms, and live Detailed/Pixel switch while adding:
## - Canopy transparency + overhead troop indicators when selected units pass beneath oasis trees
## - Camera jump keys (1: Opening & HQ, 2: Sheltered Spring, 3: Roadside Pool & Fork, 4: Forked Dune Field)
## - Minimap landmark colours for Blue Field Headquarters and both modular oases

@onready var sheltered_spring: Node2D = get_node_or_null("YSortWorld/ShelteredSpring")
@onready var roadside_pool: Node2D = get_node_or_null("YSortWorld/RoadsidePool")

var _trees: Array[RtsCarbonPiece] = []
var _canopy_covered_units: Array[RtsCarbonUnit] = []


func _ready() -> void:
	super._ready()
	_trees.clear()
	for piece in _pieces:
		if piece.piece_id == "oasis_tree":
			_trees.append(piece)
	# Frame opening to show Blue Squads, Commander, Tank, HQ on road, Dunes, and Central Orichalcum!
	set_camera_focus(Vector2(520.0, 418.0))


func rebuild_navigation_and_minimap() -> void:
	_collect_pieces()
	_build_blocked_and_calm_masks()
	_setup_ground_shader()
	apply_visual_mode(pixel_mode)
	hud.minimap_tex = _build_minimap_texture()
	hud.request_repaint()


func _process(delta: float) -> void:
	super._process(delta)
	_canopy_covered_units.clear()
	for tree in _trees:
		if not is_instance_valid(tree):
			continue
		var canopy := Rect2(tree.draw_offset - tree.world_size * 0.46, tree.world_size * 0.92)
		var obscures_selected := false
		for unit in selection:
			if not is_instance_valid(unit) or not unit.alive:
				continue
			var foot := tree.to_local(unit.global_position)
			if foot.y < 6.0 and canopy.has_point(foot):
				obscures_selected = true
				if unit not in _canopy_covered_units:
					_canopy_covered_units.append(unit)
		var target_alpha := 0.40 if obscures_selected else 1.0
		if absf(tree.modulate.a - target_alpha) > 0.004:
			tree.modulate.a = move_toward(tree.modulate.a, target_alpha, delta * 4.5)
	if not _canopy_covered_units.is_empty():
		overlay_layer.queue_redraw()


func _draw_selection_overlay() -> void:
	super._draw_selection_overlay()
	# Keep a subtle tactical chevron above any selected unit passing beneath an overhanging tree crown
	for unit in _canopy_covered_units:
		if not is_instance_valid(unit) or not unit.alive:
			continue
		var tip := unit.global_position + Vector2(0.0, -24.0)
		overlay_layer.draw_line(tip + Vector2(-5.0, -4.0), tip, Color(0.38, 1.0, 0.56, 0.95), 1.8)
		overlay_layer.draw_line(tip + Vector2(5.0, -4.0), tip, Color(0.38, 1.0, 0.56, 0.95), 1.8)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		match ke.keycode:
			KEY_1:
				set_camera_focus(Vector2(520.0, 418.0))
				get_viewport().set_input_as_handled()
				return
			KEY_2:
				if sheltered_spring != null:
					set_camera_focus(sheltered_spring.global_position + Vector2(16.0, 36.0))
					get_viewport().set_input_as_handled()
					return
			KEY_3:
				if roadside_pool != null:
					set_camera_focus(roadside_pool.global_position + Vector2(-96.0, -56.0))
					get_viewport().set_input_as_handled()
					return
			KEY_4:
				set_camera_focus(Vector2(384.0, 648.0))
				get_viewport().set_input_as_handled()
				return
			KEY_ESCAPE:
				var launcher := get_tree().root.get_node_or_null("BuildLauncher")
				if launcher != null and bool(launcher.call("is_build_active")):
					return
	super._unhandled_input(event)


func _build_minimap_texture() -> ImageTexture:
	var mw := 184
	var mh := 118
	var img := Image.create_empty(mw, mh, false, Image.FORMAT_RGBA8)
	var segments := _road_segments()
	for y in range(mh):
		for x in range(mw):
			var wpt := Vector2((float(x) + 0.5) / float(mw) * WORLD_SIZE.x, (float(y) + 0.5) / float(mh) * WORLD_SIZE.y)
			var col := Color(0.84, 0.52, 0.18)
			if height_at(wpt) > 0.12:
				col = Color(0.92, 0.64, 0.24)
			var rd := wpt.distance_to(_orichalcum_pos)
			if rd < 126.0:
				col = Color(0.78, 0.63, 0.46)
			else:
				for seg in segments:
					var nearest := Geometry2D.get_closest_point_to_segment(wpt, Vector2(seg.x, seg.y), Vector2(seg.z, seg.w))
					if wpt.distance_to(nearest) < 23.0:
						col = Color(0.76, 0.60, 0.44)
						break
			for p in _pieces:
				if p.blocks_world_point(wpt):
					col = Color(0.34, 0.23, 0.17)
					if p.piece_id == "outpost_pad":
						col = Color(0.52, 0.54, 0.58)
					elif p.piece_id == "blue_field_hq":
						col = Color(0.28, 0.50, 0.80)
					elif p.layer_role == "water":
						col = Color(0.18, 0.78, 0.74)
					break
			for p in _pieces:
				if p.is_orichalcum and wpt.distance_to(p.global_position) < 42.0:
					col = Color(0.98, 0.78, 0.20)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
