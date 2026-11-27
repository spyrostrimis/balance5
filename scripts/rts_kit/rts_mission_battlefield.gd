class_name RtsMissionBattlefield
extends RtsCarbonBattlefield
## Canonical RTS battlefield built from the shared desert kit (scenes/rts/desert_kit/).
## Carries Carbon's gameplay (selection, orders, combat, Mend, hold timer, tracks, minimap,
## Command/Close zoom, Detailed/Pixel switch) and adds what Reusable 4 proved:
## - tree crowns fade over selected troops walking beneath them, with a small chevron
## - camera views come from the Marker2D children of CameraViews (keys 1-9, first = opening)
## - seam-free wind lighting on open sand (smooth_wind)
## Make a new map by copying the mission scene and moving or adding kit pieces.

@export var smooth_wind := true

@onready var camera_views: Node2D = get_node_or_null("CameraViews")

var _trees: Array[RtsCarbonPiece] = []
var _canopy_covered_units: Array[RtsCarbonUnit] = []


func _ready() -> void:
	super._ready()
	_collect_trees()
	focus_view(0)


func _collect_trees() -> void:
	_trees.clear()
	for piece in _pieces:
		if piece.piece_id.ends_with("_tree"):
			_trees.append(piece)


## Camera focus for view `index` (0-based Marker2D under CameraViews). Returns false if absent.
func focus_view(index: int) -> bool:
	if camera_views == null:
		set_camera_focus(Vector2(548.0, 432.0))
		return false
	var markers: Array[Marker2D] = []
	for child in camera_views.get_children():
		if child is Marker2D:
			markers.append(child)
	if index < 0 or index >= markers.size():
		return false
	set_camera_focus(markers[index].global_position)
	return true


func apply_visual_mode(use_pixel: bool) -> void:
	super.apply_visual_mode(use_pixel)
	_ground_mat.set_shader_parameter("smooth_wind", smooth_wind)
	for d in _dune_pieces:
		var sm := d.material as ShaderMaterial
		if sm != null:
			sm.set_shader_parameter("smooth_wind", smooth_wind)


## Call after moving kit pieces at runtime (tests, future editors) to refresh blocked ground.
func rebuild_navigation_and_minimap() -> void:
	_collect_pieces()
	_collect_trees()
	_build_blocked_and_calm_masks()
	_setup_ground_shader()
	apply_visual_mode(pixel_mode)
	hud.minimap_tex = _build_minimap_texture()
	hud.request_repaint()


func reset_encounter() -> void:
	super.reset_encounter()
	focus_view(0)


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
	for unit in _canopy_covered_units:
		if not is_instance_valid(unit) or not unit.alive:
			continue
		var tip := unit.global_position + Vector2(0.0, -24.0)
		overlay_layer.draw_line(tip + Vector2(-5.0, -4.0), tip, Color(0.38, 1.0, 0.56, 0.95), 1.8)
		overlay_layer.draw_line(tip + Vector2(5.0, -4.0), tip, Color(0.38, 1.0, 0.56, 0.95), 1.8)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode >= KEY_1 and ke.keycode <= KEY_9:
			if focus_view(int(ke.keycode - KEY_1)):
				get_viewport().set_input_as_handled()
			return
		if ke.keycode == KEY_ESCAPE:
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
			if wpt.distance_to(_orichalcum_pos) < 126.0:
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
					elif p.piece_id.ends_with("_hq"):
						col = Color(0.28, 0.50, 0.80)
					elif p.layer_role == "water":
						col = Color(0.18, 0.78, 0.74)
					break
			for p in _pieces:
				if p.is_orichalcum and wpt.distance_to(p.global_position) < 42.0:
					col = Color(0.98, 0.78, 0.20)
				elif p.piece_id == "cliff_oasis" and wpt.distance_to(p.to_global(Vector2(-78.0, 68.0))) < 42.0:
					col = Color(0.18, 0.78, 0.74)  # Carbon's painted pool inside its cliff
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
