class_name RtsMissionBattlefield
extends RtsCarbonBattlefield
## Canonical RTS battlefield built from the shared desert kit (scenes/rts/desert_kit/).
## Carries Carbon's gameplay (selection, orders, combat, Mend, hold timer, tracks, minimap,
## Command/Close zoom, Detailed/Pixel switch) and adds what Reusable 4 proved:
## - tree crowns fade over selected troops walking beneath them, with a small chevron
## - camera views come from the Marker2D children of CameraViews (keys 1-9, first = opening)
## - seam-free wind lighting on open sand (smooth_wind)
## - planet skins: P cycles the terrain art (Desert, Miasaki, …) without touching the layout
## - HUD styles: U cycles Mockup E, Classic, Holo and the original Carbon HUD (RtsMissionHud)
## - per-piece minimap colours, canopy-fading tree masses, and fords/bridges that reopen water
##   (pieces with layer_role "crossing"), used by the forest kit; the desert sets none of them
## Make a new map by copying the mission scene and moving or adding kit pieces.

@export var smooth_wind := true
## Planet skins. Each entry: display name, skin folders (";"-separated, first match wins) and whether
## its sand uses the painted-sand lighting. Units, water, plants and buildings keep the kit's art.
@export var skin_names := PackedStringArray(["Desert", "Miasaki"])
@export var skin_paths := PackedStringArray(["", "res://assets/textures/rts/skins/miasaki;res://assets/textures/rts/carbon_miasaki"])
@export var skin_painted_sand: Array[bool] = [false, true]
@export var start_skin := 0
## Units rise by height² × this many world pixels, so low ripples barely lift them and a
## sand hill (relief ≈ 2.4) raises them about 26 px. 0 = flat movement like Carbon.
@export var unit_lift_px := 4.5
## How strongly slopes facing the upper-left sun brighten units (and the far side darkens them).
@export var slope_light := 2.6
## "mockup_e", "classic", "holo" or "placeholder" (the original Carbon HUD).
@export var start_hud_style := "mockup_e"
## Pixel view takes its ground and road from this map's art folder too (the forest's grass and dirt),
## instead of Carbon's Pixel sand and road. Off for the desert, whose Pixel art is Carbon's.
@export var pixel_ground_from_kit := false
## Minimap colour of open ground that a tree canopy overhangs (forest). Transparent = not drawn.
@export var minimap_canopy_color := Color(0.0, 0.0, 0.0, 0.0)

var skin_index := 0
var _skin_dirs := PackedStringArray()
var _mm_sand := Color(0.84, 0.52, 0.18)
var _mm_dune := Color(0.92, 0.64, 0.24)
var _mm_road := Color(0.76, 0.60, 0.44)
var _skin_banner: Label
var _skin_banner_time := 0.0

@onready var camera_views: Node2D = get_node_or_null("CameraViews")

var _trees: Array[RtsCarbonPiece] = []
var _canopy_covered_units: Array[RtsCarbonUnit] = []


func _ready() -> void:
	super._ready()
	_collect_trees()
	_make_skin_banner()
	var wanted := start_skin
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--skin="):
			var idx := Array(skin_names).map(func(n: String) -> String: return n.to_lower()).find(arg.trim_prefix("--skin=").to_lower())
			if idx >= 0:
				wanted = idx
	apply_skin(wanted, false)
	var hud_style := start_hud_style
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hud="):
			hud_style = arg.trim_prefix("--hud=")
	set_hud_style(hud_style)
	focus_view(0)


func set_hud_style(style_name: String) -> void:
	if hud.has_method("framing_width"):
		hud.set("style", style_name)
	_sync_camera_transform()


func cycle_hud_style() -> void:
	if not hud.has_method("framing_width"):
		return
	var styles := RtsMissionHud.STYLES
	set_hud_style(styles[(styles.find(hud.get("style")) + 1) % styles.size()])


## Same as Carbon's, except the zoom comes from the HUD's framing width, so every HUD style shows
## units at the same size (Holo simply shows more of the battlefield around them).
func _sync_camera_transform() -> void:
	if camera == null or hud == null:
		return
	var play_rect := hud.playable_screen_rect()
	var frame_w: float = hud.call("framing_width") if hud.has_method("framing_width") else play_rect.size.x
	var desired_world_w := (_target_cells_width() * float(CELL_SIZE)) / maxf(_custom_zoom_mult, 0.45)
	var z := frame_w / maxf(desired_world_w, 128.0)
	camera.zoom = Vector2(z, z)
	var vis_world_size := play_rect.size / z
	var half := vis_world_size * 0.5
	_cam_center.x = clampf(_cam_center.x, half.x, maxf(half.x, WORLD_SIZE.x - half.x))
	_cam_center.y = clampf(_cam_center.y, half.y, maxf(half.y, WORLD_SIZE.y - half.y))
	var snapped_center := _cam_center.round() if pixel_mode else _cam_center
	var vp_center := get_viewport().get_visible_rect().size * 0.5
	var screen_shift := vp_center - play_rect.get_center()
	camera.position = snapped_center + screen_shift / z
	hud.camera_world_rect = Rect2(snapped_center - half, vis_world_size)
	hud.request_repaint()


## Screen lift for a unit standing at world point p (see unit_lift_px).
func terrain_lift_at(p: Vector2) -> float:
	var h := height_at(p)
	return h * h * unit_lift_px


## Light multiplier from the slope under p, relative to the upper-left sun.
func terrain_light_at(p: Vector2) -> float:
	var d := Vector2(0.7071, 0.7071)
	var g := (height_at(p + d * 8.0) - height_at(p - d * 8.0)) / 16.0
	return clampf(1.0 + g * slope_light * 10.0, 0.84, 1.14)


## Click selection follows the raised sprite, not the ground point under it.
func _unit_under(world_pt: Vector2) -> RtsCarbonUnit:
	var best: RtsCarbonUnit = null
	var best_d := INF
	for u in get_living_units():
		var d := (u.position - Vector2(0.0, terrain_lift_at(u.position))).distance_to(world_pt)
		if d <= u.select_radius() + 5.0 and d < best_d:
			best_d = d
			best = u
	return best


func _on_hud_toggle(which: String) -> void:
	if which == "hud":
		cycle_hud_style()
		return
	super._on_hud_toggle(which)


## Switch the planet skin: terrain art, sand lighting and minimap colours. Layout and units stay.
func apply_skin(index: int, announce := true) -> void:
	if skin_names.is_empty():
		return
	skin_index = posmod(index, skin_names.size())
	_skin_dirs = PackedStringArray()
	if skin_index < skin_paths.size():
		for d in skin_paths[skin_index].split(";", false):
			_skin_dirs.append(d.strip_edges())
	_sand_hd = _skin_texture("sand_tile")
	_road_hd = _skin_texture("road_strip")
	if pixel_ground_from_kit:
		_sand_px = RtsCarbonArt.texture("sand_tile", true, detailed_art_directory)
		_road_px = RtsCarbonArt.texture("road_strip", true, detailed_art_directory)
	art_directory_has_painted_sand = skin_index < skin_painted_sand.size() and skin_painted_sand[skin_index]
	_measure_minimap_colours()
	apply_visual_mode(pixel_mode)
	hud.minimap_tex = _build_minimap_texture()
	hud.request_repaint()
	if announce:
		_show_skin_banner()


func skin_name() -> String:
	return skin_names[skin_index] if skin_index < skin_names.size() else ""


func _skin_texture(key: String) -> Texture2D:
	for d in _skin_dirs:
		var t := RtsCarbonArt.detailed_texture(key, d)
		if t != null:
			return t
	return RtsCarbonArt.texture(key, false, detailed_art_directory)


func _measure_minimap_colours() -> void:
	var sand_img := _sand_hd.get_image() if _sand_hd != null else null
	var road_img := _road_hd.get_image() if _road_hd != null else null
	if sand_img != null:
		if sand_img.is_compressed():
			sand_img.decompress()
		sand_img.resize(1, 1, Image.INTERPOLATE_BILINEAR)
		_mm_sand = sand_img.get_pixel(0, 0)
		_mm_dune = _mm_sand.lightened(0.16)
	if road_img != null:
		if road_img.is_compressed():
			road_img.decompress()
		road_img.resize(1, 1, Image.INTERPOLATE_BILINEAR)
		_mm_road = road_img.get_pixel(0, 0)


func _make_skin_banner() -> void:
	_skin_banner = Label.new()
	_skin_banner.add_theme_font_size_override("font_size", 22)
	_skin_banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	_skin_banner.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	_skin_banner.add_theme_constant_override("outline_size", 6)
	_skin_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skin_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_skin_banner.position = Vector2(-200, 120)
	_skin_banner.size = Vector2(400, 36)
	_skin_banner.modulate.a = 0.0
	_skin_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_skin_banner)


func _show_skin_banner() -> void:
	if _skin_banner == null:
		return
	_skin_banner.text = "Planet: %s   [P]" % skin_name()
	_skin_banner_time = 2.2


func _collect_trees() -> void:
	_trees.clear()
	for piece in _pieces:
		if piece.piece_id.ends_with("_tree") or piece.canopy_fade:
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
	for p in _pieces:
		p.skin_directories = _skin_dirs
	super.apply_visual_mode(use_pixel)
	_ground_mat.set_shader_parameter("smooth_wind", smooth_wind)
	for d in _dune_pieces:
		var sm := d.material as ShaderMaterial
		if sm != null:
			sm.set_shader_parameter("smooth_wind", smooth_wind)


## Fords and bridges (layer_role "crossing") reopen the ground their footprint covers, even over a
## river; everything else blocks as in Carbon.
func is_point_blocked(wpt: Vector2) -> bool:
	var blocked := false
	for p in _pieces:
		if p.layer_role == "crossing":
			if p.blocks_world_point(wpt):
				return false
		elif not blocked and p.blocks_world_point(wpt):
			blocked = true
	return blocked


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
	if _skin_banner != null and _skin_banner_time > 0.0:
		_skin_banner_time -= delta
		_skin_banner.modulate.a = clampf(_skin_banner_time / 0.6, 0.0, 1.0)
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
		if ke.keycode == KEY_U:
			cycle_hud_style()
			get_viewport().set_input_as_handled()
			return
		if ke.keycode == KEY_P:
			apply_skin(skin_index + 1)
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
	var patches: Array[RtsCarbonPiece] = []
	var crossings: Array[RtsCarbonPiece] = []
	var blockers: Array[RtsCarbonPiece] = []
	for p in _pieces:
		if p.layer_role == "crossing":
			crossings.append(p)
		elif p.blocked_poly.size() >= 3 or p is RtsKitRiver:
			blockers.append(p)
		elif p.minimap_color.a > 0.0:
			patches.append(p)
	var canopies: Array[RtsCarbonPiece] = _trees if minimap_canopy_color.a > 0.0 else ([] as Array[RtsCarbonPiece])
	for y in range(mh):
		for x in range(mw):
			var wpt := Vector2((float(x) + 0.5) / float(mw) * WORLD_SIZE.x, (float(y) + 0.5) / float(mh) * WORLD_SIZE.y)
			var col := _mm_sand
			if height_at(wpt) > 0.12:
				col = _mm_dune
			if wpt.distance_to(_orichalcum_pos) < 126.0:
				col = _mm_road
			else:
				for seg in segments:
					var nearest := Geometry2D.get_closest_point_to_segment(wpt, Vector2(seg.x, seg.y), Vector2(seg.z, seg.w))
					if wpt.distance_to(nearest) < 23.0:
						col = _mm_road
						break
			# Flat patches with their own colour (clearings, gravel), then canopy overhangs.
			for p in patches:
				if _in_patch(p, wpt):
					col = col.lerp(Color(p.minimap_color, 1.0), p.minimap_color.a)
			for t in canopies:
				if _in_patch(t, wpt, 0.42, true):
					col = col.lerp(Color(minimap_canopy_color, 1.0), minimap_canopy_color.a)
					break
			var crossing := false
			for p in crossings:
				if p.blocks_world_point(wpt):
					crossing = true
					col = Color(p.minimap_color, 1.0) if p.minimap_color.a > 0.0 else _mm_road
					break
			for p in blockers:
				if crossing:
					break
				if p.blocks_world_point(wpt):
					col = Color(0.34, 0.23, 0.17)
					if p.piece_id == "outpost_pad":
						col = Color(0.52, 0.54, 0.58)
					elif p.piece_id.ends_with("_hq"):
						col = Color(0.28, 0.50, 0.80)
					elif p.minimap_color.a > 0.0:
						col = Color(p.minimap_color, 1.0)
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


## Whether world point p lies in the oval a piece's painting covers (radius `fraction` of its size).
func _in_patch(piece: RtsCarbonPiece, wpt: Vector2, fraction := 0.44, use_offset := false) -> bool:
	var local := piece.to_local(wpt) - (piece.draw_offset if use_offset else Vector2.ZERO)
	var r := piece.world_size * fraction
	if r.x < 1.0 or r.y < 1.0:
		return false
	var nx := local.x / r.x
	var ny := local.y / r.y
	return nx * nx + ny * ny <= 1.0
