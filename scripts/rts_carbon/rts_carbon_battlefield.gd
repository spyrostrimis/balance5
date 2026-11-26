class_name RtsCarbonBattlefield
extends Node2D
## Root controller for "RTS Reusable 2 Carbon" (scenes/maps/rts_reusable_2_carbon.tscn).
## Demonstrates a playable Mission 1 desert stretch assembled from reusable painted ChatGPT pieces
## over continuous wind-swelled sand, with live instant switching between:
##   - Detailed Painted (2x HD, linear+mipmaps) and Dune II Pixel (960x540 1x, nearest) on [V]
##   - Command View (~21x14 playable cells) and Close View (~15x10 playable cells) on [Z]
##   - Dune II HUD frame on [H], Red AI Skirmish on [G], Mend on [E], Grid debug on [F1].

const WORLD_SIZE := Vector2(1408.0, 896.0)
const CELL_SIZE := 32
const GRID_W := 44
const GRID_H := 28
const TREAD_W := 704
const TREAD_H := 448
const GROUND_SHADER := preload("res://assets/shaders/rts_carbon_ground.gdshader")
const DUNE_SHADER := preload("res://assets/shaders/rts_carbon_dune.gdshader")
const HOLD_RADIUS := 138.0
const HOLD_DURATION := 30.0

@export var start_pixel_mode := false
@export var start_close_zoom := false
@export_dir var detailed_art_directory := ""
@export var art_directory_has_painted_sand := true
@export_range(1.0, 1.4) var visual_squad_spacing := 1.0

var pixel_mode := false
var close_zoom := false
var red_ai_active := false
var show_treads := true
var disturbed_tread_pixels := 0

var selection: Array[RtsCarbonUnit] = []
var hold_seconds_left := HOLD_DURATION
var hold_owner := 0
var match_finished := false

var _pieces: Array[RtsCarbonPiece] = []
var _dune_pieces: Array[RtsCarbonPiece] = []
var _shade_pieces: Array[RtsCarbonPiece] = []
var _orichalcum_pos := Vector2(704.0, 448.0)

var _sand_hd: Texture2D
var _sand_px: Texture2D
var _road_hd: Texture2D
var _road_px: Texture2D
var _shadow_tex: Texture2D
var _calm_tex: ImageTexture
var _tread_img: Image
var _tread_tex: ImageTexture
var _tread_dirty := false
var _tread_sync_clock := 0.0
var _tread_fade_clock := 0.0
var _ground_mat := ShaderMaterial.new()

# Selection box & FX state
var _dragging_box := false
var _press_screen := Vector2.ZERO
var _press_world := Vector2.ZERO
var _drag_world := Vector2.ZERO
var _pan_dragging := false
var _cam_center := Vector2(560.0, 430.0)
var _custom_zoom_mult := 1.0
var _ai_clock := 0.0

var _markers: Array[Dictionary] = []     # {pos, age, max_age, color}
var _tracers: Array[Dictionary] = []     # {a, b, age, max_age, blue, heavy}
var _flashes: Array[Dictionary] = []     # {pos, age, max_age, radius, color}
var _dust: Array[Dictionary] = []        # {pos, vel, age, max_age, size}
var _footprints: Array[Dictionary] = []  # {pos, age}
var _mend_rings: Array[Dictionary] = []  # {pos, radius, age}
var _initial_unit_spawns: Array[Dictionary] = []

@onready var ground_rect: ColorRect = get_node_or_null("GroundFloor")
@onready var dune_layer: Node2D = get_node_or_null("Dunes")
@onready var decal_layer: Node2D = get_node_or_null("GroundDecals")
@onready var road_line: Line2D = get_node_or_null("RoadNetwork/MainRoad")
@onready var shadow_layer: Node2D = get_node_or_null("CastShadows")
@onready var tracks_layer: Node2D = $SurfaceMarks
@onready var world_ysort: Node2D = $YSortWorld
@onready var fx_layer: Node2D = $CombatFx
@onready var overlay_layer: Node2D = $SelectionOverlay
@onready var grid: RtsGrid = $Grid
@onready var camera: Camera2D = $Camera
@onready var hud: RtsCarbonHud = $Hud


func _ready() -> void:
	_parse_cli_flags()
	_sand_hd = RtsCarbonArt.texture("sand_tile", false, detailed_art_directory)
	_sand_px = RtsCarbonArt.texture("sand_tile", true)
	_road_hd = RtsCarbonArt.texture("road_strip", false, detailed_art_directory)
	_road_px = RtsCarbonArt.texture("road_strip", true)
	_shadow_tex = preload("res://assets/textures/rts/carbon/soft_shadow.png")

	_collect_pieces()
	_build_blocked_and_calm_masks()
	_init_tread_buffer()
	_setup_ground_shader()

	shadow_layer.draw.connect(_draw_cast_shadows)
	tracks_layer.draw.connect(_draw_surface_marks)
	fx_layer.draw.connect(_draw_combat_fx)
	overlay_layer.draw.connect(_draw_selection_overlay)

	hud.world_size = WORLD_SIZE
	hud.minimap_tex = _build_minimap_texture()
	hud.load_portraits(detailed_art_directory)
	hud.command_button_pressed.connect(_on_hud_command)
	hud.minimap_pan_requested.connect(func(wpos: Vector2) -> void: set_camera_focus(wpos))
	hud.minimap_order_requested.connect(func(wpos: Vector2) -> void: issue_order_at(wpos))
	hud.toggle_requested.connect(_on_hud_toggle)

	_record_initial_spawns()
	_setup_units()

	pixel_mode = start_pixel_mode
	close_zoom = start_close_zoom
	apply_visual_mode(pixel_mode)
	apply_zoom_framing()
	# Start framed on the signature encounter: Blue Squad, Commander, Tank, Dune, Road, Orichalcum & Cliff!
	set_camera_focus(Vector2(548.0, 432.0))
	_select_initial_group()


func _parse_cli_flags() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--pixel":
			start_pixel_mode = true
		elif arg == "--hd":
			start_pixel_mode = false
		elif arg == "--close-zoom":
			start_close_zoom = true


func _collect_pieces() -> void:
	_pieces.clear()
	_dune_pieces.clear()
	_shade_pieces.clear()
	for container in [dune_layer, decal_layer, world_ysort]:
		_collect_pieces_in(container)


func _collect_pieces_in(container: Node) -> void:
	for child in container.get_children():
		var p := child as RtsCarbonPiece
		if p != null:
			_pieces.append(p)
			if p.layer_role == "dune":
				_dune_pieces.append(p)
			if p.shade_strength > 0.0:
				_shade_pieces.append(p)
			if p.is_orichalcum:
				_orichalcum_pos = p.global_position
		else:
			_collect_pieces_in(child)


func _road_paths() -> Array[Line2D]:
	var lines: Array[Line2D] = []
	for child in road_line.get_parent().get_children():
		if child is Line2D:
			lines.append(child)
	return lines


func _road_segments() -> Array[Vector4]:
	var segments: Array[Vector4] = []
	for line in _road_paths():
		for i in range(line.get_point_count() - 1):
			var a := line.to_global(line.get_point_position(i))
			var b := line.to_global(line.get_point_position(i + 1))
			segments.append(Vector4(a.x, a.y, b.x, b.y))
	return segments


func _build_blocked_and_calm_masks() -> void:
	var mask := Image.create_empty(GRID_W, GRID_H, false, Image.FORMAT_L8)
	for cy in range(GRID_H):
		for cx in range(GRID_W):
			var wpt := Vector2(float(cx) * CELL_SIZE + 16.0, float(cy) * CELL_SIZE + 16.0)
			var blocked := false
			for p in _pieces:
				if p.blocks_world_point(wpt):
					blocked = true
					break
			mask.set_pixel(cx, cy, Color.WHITE if blocked else Color.BLACK)
	grid.cell_pixels = Vector2i(CELL_SIZE, CELL_SIZE)
	grid.blocked_cells = ImageTexture.create_from_image(mask)
	grid.setup()

	# Calm sand mask: 1.0 near road & central plaza so sand stays quiet behind infantry!
	var cw := 176
	var ch := 112
	var calm_img := Image.create_empty(cw, ch, false, Image.FORMAT_L8)
	var segments := _road_segments()
	for y in range(ch):
		for x in range(cw):
			var wpt := Vector2((float(x) + 0.5) / float(cw) * WORLD_SIZE.x, (float(y) + 0.5) / float(ch) * WORLD_SIZE.y)
			var min_d := wpt.distance_to(_orichalcum_pos) - 90.0
			for seg in segments:
				var seg_pt := Geometry2D.get_closest_point_to_segment(wpt, Vector2(seg.x, seg.y), Vector2(seg.z, seg.w))
				min_d = minf(min_d, wpt.distance_to(seg_pt))
			var calm := 1.0 - smoothstep(38.0, 145.0, min_d)
			calm_img.set_pixel(x, y, Color(calm, calm, calm, 1.0))
	_calm_tex = ImageTexture.create_from_image(calm_img)


func _init_tread_buffer() -> void:
	_tread_img = Image.create_empty(TREAD_W, TREAD_H, false, Image.FORMAT_L8)
	_tread_tex = ImageTexture.create_from_image(_tread_img)
	disturbed_tread_pixels = 0


func _setup_ground_shader() -> void:
	ground_rect.position = Vector2.ZERO
	ground_rect.size = WORLD_SIZE
	_ground_mat.shader = GROUND_SHADER
	_ground_mat.set_shader_parameter("calm_mask_tex", _calm_tex)
	_ground_mat.set_shader_parameter("tread_tex", _tread_tex)
	_ground_mat.set_shader_parameter("world_size", WORLD_SIZE)
	ground_rect.material = _ground_mat


func _record_initial_spawns() -> void:
	_initial_unit_spawns.clear()
	for child in world_ysort.get_children():
		var u := child as RtsCarbonUnit
		if u == null:
			continue
		_initial_unit_spawns.append({
			"display_name": u.display_name,
			"subtitle": u.subtitle,
			"portrait_key": u.portrait_key,
			"sprite_key": u.sprite_key,
			"team": u.team,
			"role": u.role,
			"max_health": u.max_health,
			"attack_damage": u.attack_damage,
			"armour": u.armour,
			"attack_range_cells": u.attack_range_cells,
			"guard_range_cells": u.guard_range_cells,
			"attack_cooldown": u.attack_cooldown,
			"speed_px": u.speed_px,
			"turn_rate": u.turn_rate,
			"pos": u.position,
		})


func _setup_units() -> void:
	for child in world_ysort.get_children():
		var u := child as RtsCarbonUnit
		if u != null:
			u.setup(self, grid, pixel_mode, detailed_art_directory, visual_squad_spacing)


func _select_initial_group() -> void:
	var starter: Array[RtsCarbonUnit] = []
	for u in get_living_units():
		if u.team == RtsCarbonUnit.Team.BLUE and u.role == RtsCarbonUnit.Role.COMMANDER:
			starter.append(u)
			break
	set_selection(starter)


func get_living_units() -> Array[RtsCarbonUnit]:
	var out: Array[RtsCarbonUnit] = []
	for node in get_tree().get_nodes_in_group("rts_carbon_units"):
		var u := node as RtsCarbonUnit
		if u != null and is_instance_valid(u) and u.alive:
			out.append(u)
	return out


func apply_visual_mode(use_pixel: bool) -> void:
	pixel_mode = use_pixel
	var stex := _sand_px if use_pixel else _sand_hd
	var use_painted_sand := not use_pixel and art_directory_has_painted_sand and not detailed_art_directory.is_empty()
	_ground_mat.set_shader_parameter("sand_tex", stex)
	_ground_mat.set_shader_parameter("pixel_mode", use_pixel)
	_ground_mat.set_shader_parameter("painted_sand", use_painted_sand)
	_ground_mat.set_shader_parameter("show_treads", show_treads)

	for line in _road_paths():
		line.texture = _road_px if use_pixel else _road_hd
		line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if use_pixel else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	for p in _pieces:
		p.apply_visual_mode(use_pixel, DUNE_SHADER, stex, _calm_tex, _tread_tex, WORLD_SIZE,
				show_treads, detailed_art_directory, use_painted_sand)

	for u in get_living_units():
		u.apply_visual_mode(use_pixel)

	hud.pixel_mode = use_pixel
	hud.request_repaint()
	shadow_layer.queue_redraw()
	tracks_layer.queue_redraw()
	fx_layer.queue_redraw()
	overlay_layer.queue_redraw()
	_sync_camera_transform()


func apply_zoom_framing() -> void:
	hud.close_zoom = close_zoom
	_custom_zoom_mult = 1.0
	_sync_camera_transform()
	hud.request_repaint()


func _target_cells_width() -> float:
	# Preset 1: ~21.0 x 13.8 playable cells (Dune II Mission 1 Command Framing)
	# Preset 2: ~15.0 x 10.0 playable cells (Codex Close Tactical Framing)
	return 15.0 if close_zoom else 21.0


func _sync_camera_transform() -> void:
	if camera == null or hud == null:
		return
	var play_rect := hud.playable_screen_rect()
	var desired_world_w := (_target_cells_width() * float(CELL_SIZE)) / maxf(_custom_zoom_mult, 0.45)
	var z := play_rect.size.x / maxf(desired_world_w, 128.0)
	camera.zoom = Vector2(z, z)

	var vis_world_size := play_rect.size / z
	var half := vis_world_size * 0.5
	_cam_center.x = clampf(_cam_center.x, half.x, maxf(half.x, WORLD_SIZE.x - half.x))
	_cam_center.y = clampf(_cam_center.y, half.y, maxf(half.y, WORLD_SIZE.y - half.y))

	var snapped_center := _cam_center.round() if pixel_mode else _cam_center
	# Offset Camera2D so _cam_center lands at the exact center of play_rect (not covered by HUD sidebar!)
	var vp_center := get_viewport().get_visible_rect().size * 0.5
	var play_center := play_rect.get_center()
	var screen_shift := vp_center - play_center
	camera.position = snapped_center + screen_shift / z

	hud.camera_world_rect = Rect2(snapped_center - half, vis_world_size)
	hud.request_repaint()


func set_camera_focus(world_pt: Vector2) -> void:
	_cam_center = world_pt
	_sync_camera_transform()


# --- Terrain queries & live tracks ---------------------------------------------------------

func height_at(world_pt: Vector2) -> float:
	var h := 0.0
	for d in _dune_pieces:
		h = maxf(h, d.height_at(world_pt))
	return h


func grade_at(world_pt: Vector2, dir: Vector2) -> float:
	return (height_at(world_pt + dir * 8.0) - height_at(world_pt - dir * 8.0)) / 16.0


func shade_at(world_pt: Vector2) -> float:
	var light := 1.0
	for sp in _shade_pieces:
		light *= (1.0 - sp.shade_at(world_pt))
	return clampf(1.0 - light, 0.0, 0.65)


func record_tank_treads(prev_pos: Vector2, prev_dir: Vector2, next_pos: Vector2, next_dir: Vector2) -> void:
	if _tread_img == null:
		return
	var scale_uv := Vector2(float(TREAD_W) / WORLD_SIZE.x, float(TREAD_H) / WORLD_SIZE.y)
	for side in [-6.2, 6.2]:
		var a := (prev_pos - prev_dir * 4.0 + prev_dir.orthogonal() * float(side)) * scale_uv
		var b := (next_pos - next_dir * 4.0 + next_dir.orthogonal() * float(side)) * scale_uv
		var x0 := clampi(int(floor(minf(a.x, b.x) - 3.0)), 0, TREAD_W - 1)
		var y0 := clampi(int(floor(minf(a.y, b.y) - 3.0)), 0, TREAD_H - 1)
		var x1 := clampi(int(ceil(maxf(a.x, b.x) + 3.0)), 0, TREAD_W)
		var y1 := clampi(int(ceil(maxf(a.y, b.y) + 3.0)), 0, TREAD_H)
		for py in range(y0, y1):
			for px in range(x0, x1):
				var pt := Vector2(float(px) + 0.5, float(py) + 0.5)
				var near := Geometry2D.get_closest_point_to_segment(pt, a, b)
				var d := pt.distance_to(near)
				if d > 2.2:
					continue
				# Lighter scuff on stone road/plaza, deep twin compression on sand & dunes!
				var wpt := pt / scale_uv
				var on_plaza := wpt.distance_to(_orichalcum_pos) < 130.0
				var strength := (1.0 - smoothstep(0.65, 2.2, d)) * (0.32 if on_plaza else 0.95)
				var cur := _tread_img.get_pixel(px, py).r
				if strength > cur + 0.02:
					if cur < 0.05:
						disturbed_tread_pixels += 1
					_tread_img.set_pixel(px, py, Color(strength, 0.0, 0.0, 1.0))
					_tread_dirty = true


func spawn_dust(pos: Vector2, away: Vector2) -> void:
	var vel := away * randf_range(5.0, 11.0) + Vector2(randf_range(-3.0, 3.0), randf_range(-3.5, 1.0))
	_dust.append({"pos": pos, "vel": vel, "age": 0.0, "max_age": 0.65, "size": randf_range(2.0, 3.6)})


func spawn_footprint(pos: Vector2, dir: Vector2) -> void:
	var side := dir.orthogonal() * (1.8 if (_footprints.size() % 2 == 0) else -1.8)
	_footprints.append({"pos": pos + side, "age": 0.0})


func spawn_weapon_fire(from_pos: Vector2, to_pos: Vector2, is_blue: bool, heavy_shell: bool) -> void:
	_tracers.append({
		"a": from_pos,
		"b": to_pos,
		"age": 0.0,
		"max_age": 0.14 if heavy_shell else 0.09,
		"blue": is_blue,
		"heavy": heavy_shell,
	})
	_flashes.append({
		"pos": from_pos,
		"age": 0.0,
		"max_age": 0.10,
		"radius": 5.5 if heavy_shell else 3.2,
		"color": Color(1.0, 0.92, 0.55, 0.95),
	})
	if heavy_shell:
		_flashes.append({
			"pos": to_pos,
			"age": 0.0,
			"max_age": 0.22,
			"radius": 11.0,
			"color": Color(1.0, 0.62, 0.22, 0.90),
		})


func spawn_mend_pulse(center: Vector2, radius: float) -> void:
	_mend_rings.append({"pos": center, "radius": radius, "age": 0.0})


# --- Process loop, Objective Hold Timer & Optional Red AI ----------------------------------

func _process(delta: float) -> void:
	_handle_camera_pan_keys(delta)
	_tick_fx_and_treads(delta)
	_tick_objective(delta)
	if red_ai_active and not match_finished:
		_tick_red_ai(delta)
	_sync_hud_state()


func _handle_camera_pan_keys(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		_cam_center += dir.normalized() * (420.0 / maxf(camera.zoom.x, 0.5)) * delta
		_sync_camera_transform()


func _tick_fx_and_treads(delta: float) -> void:
	_tread_sync_clock += delta
	_tread_fade_clock += delta
	if _tread_fade_clock >= 0.85:
		_tread_fade_clock = 0.0
		# Gentle desert breeze slowly softens old tracks over ~28s
		for y in range(TREAD_H):
			for x in range(TREAD_W):
				var v := _tread_img.get_pixel(x, y).r
				if v > 0.005:
					_tread_img.set_pixel(x, y, Color(maxf(0.0, v - 0.025), 0.0, 0.0, 1.0))
					_tread_dirty = true
	if _tread_dirty and _tread_sync_clock >= 0.05:
		_tread_tex.update(_tread_img)
		_tread_dirty = false
		_tread_sync_clock = 0.0

	_tick_effects(delta)


func _tick_effects(delta: float) -> void:
	var dirty_marks := false
	for fp in _footprints:
		fp["age"] = float(fp["age"]) + delta
		dirty_marks = true
	_footprints = _footprints.filter(func(d: Dictionary) -> bool: return float(d["age"]) < 5.5)
	if dirty_marks:
		tracks_layer.queue_redraw()

	var dirty_fx := false
	for list_ref in [_markers, _tracers, _flashes, _dust, _mend_rings]:
		if not list_ref.is_empty():
			dirty_fx = true
	for m in _markers:
		m["age"] = float(m["age"]) + delta
	_markers = _markers.filter(func(d: Dictionary) -> bool: return float(d["age"]) < float(d["max_age"]))

	for tr in _tracers:
		tr["age"] = float(tr["age"]) + delta
	_tracers = _tracers.filter(func(d: Dictionary) -> bool: return float(d["age"]) < float(d["max_age"]))

	for fl in _flashes:
		fl["age"] = float(fl["age"]) + delta
	_flashes = _flashes.filter(func(d: Dictionary) -> bool: return float(d["age"]) < float(d["max_age"]))

	for du in _dust:
		du["age"] = float(du["age"]) + delta
		du["pos"] = (du["pos"] as Vector2) + (du["vel"] as Vector2) * delta
	_dust = _dust.filter(func(d: Dictionary) -> bool: return float(d["age"]) < float(d["max_age"]))

	for mr in _mend_rings:
		mr["age"] = float(mr["age"]) + delta
	_mend_rings = _mend_rings.filter(func(d: Dictionary) -> bool: return float(d["age"]) < 0.65)

	if dirty_fx:
		fx_layer.queue_redraw()


func _tick_objective(delta: float) -> void:
	var units := get_living_units()
	var blue_total := 0
	var red_total := 0
	var blue_near := 0
	var red_near := 0
	for u in units:
		if u.team == RtsCarbonUnit.Team.BLUE:
			blue_total += 1
			if u.position.distance_to(_orichalcum_pos) <= HOLD_RADIUS:
				blue_near += 1
		else:
			red_total += 1
			if u.position.distance_to(_orichalcum_pos) <= HOLD_RADIUS:
				red_near += 1

	hud.blue_alive = blue_total
	if match_finished:
		return
	if red_total == 0:
		match_finished = true
		hold_owner = 1
		hold_seconds_left = 0.0
		hud.hold_state = "Victory! Red Eliminated"
		return
	if blue_total == 0:
		match_finished = true
		hold_owner = 2
		hud.hold_state = "Defeat · Blue Fallen"
		return

	if blue_near > 0 and red_near > 0:
		hud.hold_state = "Contested! Clear the Plaza"
	elif blue_near > 0:
		if hold_owner != 1:
			hold_owner = 1
			hold_seconds_left = HOLD_DURATION
		hold_seconds_left = maxf(0.0, hold_seconds_left - delta)
		hud.hold_state = "Blue Holding (%d near rock)" % blue_near
		if hold_seconds_left <= 0.0:
			match_finished = true
			hud.hold_state = "Victory! Orichalcum Claimed"
	elif red_near > 0:
		if hold_owner != 2:
			hold_owner = 2
			hold_seconds_left = HOLD_DURATION
		hold_seconds_left = maxf(0.0, hold_seconds_left - delta)
		hud.hold_state = "Red Holding! Contest Now"
		if hold_seconds_left <= 0.0:
			match_finished = true
			hud.hold_state = "Defeat · Red Claimed Rock"
	else:
		hold_seconds_left = minf(HOLD_DURATION, hold_seconds_left + delta * 0.35)
		if hold_seconds_left >= HOLD_DURATION - 0.1:
			hold_owner = 0
		hud.hold_state = "Uncontested · Advance to Rock"


func _tick_red_ai(delta: float) -> void:
	_ai_clock -= delta
	if _ai_clock > 0.0:
		return
	_ai_clock = 1.6
	var units := get_living_units()
	for u in units:
		if u.team != RtsCarbonUnit.Team.RED:
			continue
		if u.order == RtsCarbonUnit.Order.NONE:
			var offset := Vector2(randf_range(-75.0, 95.0), randf_range(-55.0, 75.0))
			u.command_move(_orichalcum_pos + offset)


func _sync_hud_state() -> void:
	for i in range(selection.size() - 1, -1, -1):
		if not is_instance_valid(selection[i]) or not selection[i].alive:
			selection.remove_at(i)
	hud.selected_units = selection
	hud.all_units = get_living_units()
	hud.hold_seconds_left = hold_seconds_left
	hud.hold_owner = hold_owner
	hud.red_ai_active = red_ai_active
	hud.request_repaint()


# --- Input, Selection & Commands -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			match k.keycode:
				KEY_ESCAPE:
					_exit_scene()
					get_viewport().set_input_as_handled()
					return
				KEY_V:
					apply_visual_mode(not pixel_mode)
					get_viewport().set_input_as_handled()
					return
				KEY_Z:
					close_zoom = not close_zoom
					apply_zoom_framing()
					get_viewport().set_input_as_handled()
					return
				KEY_H:
					hud.hud_visible = not hud.hud_visible
					_sync_camera_transform()
					get_viewport().set_input_as_handled()
					return
				KEY_G:
					red_ai_active = not red_ai_active
					hud.request_repaint()
					get_viewport().set_input_as_handled()
					return
				KEY_E:
					_trigger_mend()
					get_viewport().set_input_as_handled()
					return
				KEY_S:
					for u in selection:
						u.command_stop()
					hud.command_cursor_mode = ""
					get_viewport().set_input_as_handled()
					return
				KEY_T:
					_toggle_hold_selected()
					get_viewport().set_input_as_handled()
					return
				KEY_M:
					hud.command_cursor_mode = "move" if hud.command_cursor_mode != "move" else ""
					get_viewport().set_input_as_handled()
					return
				KEY_F1:
					grid.show_debug = not grid.show_debug
					get_viewport().set_input_as_handled()
					return
				KEY_R:
					reset_encounter()
					get_viewport().set_input_as_handled()
					return
				KEY_1:
					set_camera_focus(Vector2(548.0, 432.0))
					get_viewport().set_input_as_handled()
					return
				KEY_2:
					set_camera_focus(Vector2(980.0, 290.0))
					get_viewport().set_input_as_handled()
					return
				KEY_3:
					set_camera_focus(Vector2(920.0, 585.0))
					get_viewport().set_input_as_handled()
					return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if hud.consumes_screen_point(mb.position):
			return
		var wpos := get_canvas_transform().affine_inverse() * mb.position
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_dragging = mb.pressed
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_custom_zoom_mult = clampf(_custom_zoom_mult * 1.12, 0.72, 1.85)
			_sync_camera_transform()
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_custom_zoom_mult = clampf(_custom_zoom_mult / 1.12, 0.72, 1.85)
			_sync_camera_transform()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if hud.command_cursor_mode != "":
					issue_order_at(wpos, hud.command_cursor_mode)
					hud.command_cursor_mode = ""
					get_viewport().set_input_as_handled()
					return
				_dragging_box = false
				_press_screen = mb.position
				_press_world = wpos
				_drag_world = wpos
			else:
				if _dragging_box:
					_select_in_box(Rect2(_press_world, Vector2.ZERO).expand(wpos), mb.shift_pressed)
				else:
					_click_select(wpos, mb.shift_pressed)
				_dragging_box = false
				overlay_layer.queue_redraw()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			hud.command_cursor_mode = ""
			issue_order_at(wpos)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pan_dragging:
			_cam_center -= mm.relative / maxf(camera.zoom.x, 0.25)
			_sync_camera_transform()
			get_viewport().set_input_as_handled()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not hud.consumes_screen_point(mm.position):
			_drag_world = get_canvas_transform().affine_inverse() * mm.position
			if not _dragging_box and mm.position.distance_to(_press_screen) > 6.0:
				_dragging_box = true
			if _dragging_box:
				overlay_layer.queue_redraw()


func _unit_under(world_pt: Vector2) -> RtsCarbonUnit:
	var best: RtsCarbonUnit = null
	var best_d := INF
	for u in get_living_units():
		var d := u.position.distance_to(world_pt)
		if d <= u.select_radius() + 5.0 and d < best_d:
			best_d = d
			best = u
	return best


func _click_select(world_pt: Vector2, additive: bool) -> void:
	var u := _unit_under(world_pt)
	if u != null and u.team == RtsCarbonUnit.Team.BLUE:
		if not additive:
			set_selection([u])
		elif u in selection:
			set_selection(selection.filter(func(x: RtsCarbonUnit) -> bool: return x != u))
		else:
			var next_sel := selection.duplicate()
			next_sel.append(u)
			set_selection(next_sel)
	elif not additive:
		set_selection([])


func _select_in_box(box: Rect2, additive: bool) -> void:
	var picked: Array[RtsCarbonUnit] = []
	if additive:
		picked.assign(selection)
	for u in get_living_units():
		if u.team == RtsCarbonUnit.Team.BLUE and box.grow(u.select_radius() * 0.45).has_point(u.position):
			if not (u in picked):
				picked.append(u)
	set_selection(picked)


func set_selection(units_list: Array[RtsCarbonUnit]) -> void:
	for old_u in selection:
		if is_instance_valid(old_u):
			old_u.selected = false
	selection.clear()
	for u in units_list:
		if is_instance_valid(u) and u.alive:
			selection.append(u)
			u.selected = true
	hud.selected_units = selection
	hud.request_repaint()


func issue_order_at(world_pt: Vector2, forced_mode := "") -> void:
	if selection.is_empty():
		return
	var clicked := _unit_under(world_pt)
	if forced_mode == "attack" or (forced_mode == "" and clicked != null and clicked.team != RtsCarbonUnit.Team.BLUE):
		var enemy := clicked
		if enemy == null or enemy.team == RtsCarbonUnit.Team.BLUE:
			# Attack-click ground: target nearest enemy to cursor if close
			var best_e: RtsCarbonUnit = null
			var best_d := 128.0
			for u in get_living_units():
				if u.team != RtsCarbonUnit.Team.BLUE and u.position.distance_to(world_pt) < best_d:
					best_d = u.position.distance_to(world_pt)
					best_e = u
			enemy = best_e
		if enemy != null:
			for u in selection:
				u.command_attack(enemy)
			_markers.append({"pos": enemy.position, "age": 0.0, "max_age": 0.45, "color": Color(1.0, 0.28, 0.22)})
			return

	# Group formation move around destination cell
	var center_cell := grid.cell_of(world_pt)
	if selection.size() == 1:
		selection[0].command_move(world_pt)
	else:
		var spots := grid.free_cells_near(center_cell, selection.size(), selection)
		var remaining: Array[RtsCarbonUnit] = selection.duplicate()
		for spot in spots:
			var spot_w := grid.center_of(spot)
			var best_u: RtsCarbonUnit = null
			var best_d2 := INF
			for cand in remaining:
				var d2: float = cand.position.distance_squared_to(spot_w)
				if d2 < best_d2:
					best_d2 = d2
					best_u = cand
			if best_u != null:
				remaining.erase(best_u)
				best_u.command_move(spot_w)
	_markers.append({"pos": world_pt, "age": 0.0, "max_age": 0.45, "color": Color(0.36, 1.0, 0.42)})


func _on_hud_command(cmd: String) -> void:
	match cmd:
		"move":
			hud.command_cursor_mode = "move" if hud.command_cursor_mode != "move" else ""
		"attack":
			hud.command_cursor_mode = "attack" if hud.command_cursor_mode != "attack" else ""
		"hold":
			_toggle_hold_selected()
		"mend":
			_trigger_mend()
	hud.request_repaint()


func _on_hud_toggle(which: String) -> void:
	match which:
		"style":
			apply_visual_mode(not pixel_mode)
		"zoom":
			close_zoom = not close_zoom
			apply_zoom_framing()
		"ai":
			red_ai_active = not red_ai_active
			hud.request_repaint()


func _toggle_hold_selected() -> void:
	if selection.is_empty():
		return
	var next_hold := not selection[0].hold_position
	for u in selection:
		u.hold_position = next_hold
		if next_hold:
			u.command_stop()
			u.hold_position = true


func _trigger_mend() -> void:
	for u in get_living_units():
		if u.team == RtsCarbonUnit.Team.BLUE and u.can_mend():
			u.cast_mend()
			return


func reset_encounter() -> void:
	for u in get_living_units():
		if grid != null and u._claimed_cell.x >= 0:
			grid.release(u._claimed_cell, u)
		u.queue_free()
	selection.clear()
	_tracers.clear()
	_flashes.clear()
	_dust.clear()
	_footprints.clear()
	_mend_rings.clear()
	_tread_img.fill(Color.BLACK)
	_tread_tex.update(_tread_img)
	disturbed_tread_pixels = 0
	hold_seconds_left = HOLD_DURATION
	hold_owner = 0
	match_finished = false

	for sp in _initial_unit_spawns:
		var nu := RtsCarbonUnit.new()
		nu.display_name = String(sp["display_name"])
		nu.subtitle = String(sp["subtitle"])
		nu.portrait_key = String(sp["portrait_key"])
		nu.sprite_key = String(sp["sprite_key"])
		nu.team = sp["team"] as RtsCarbonUnit.Team
		nu.role = sp["role"] as RtsCarbonUnit.Role
		nu.max_health = int(sp["max_health"])
		nu.attack_damage = int(sp["attack_damage"])
		nu.armour = int(sp["armour"])
		nu.attack_range_cells = float(sp["attack_range_cells"])
		nu.guard_range_cells = float(sp["guard_range_cells"])
		nu.attack_cooldown = float(sp["attack_cooldown"])
		nu.speed_px = float(sp["speed_px"])
		nu.turn_rate = float(sp["turn_rate"])
		nu.position = sp["pos"] as Vector2
		world_ysort.add_child(nu)
		nu.setup(self, grid, pixel_mode, detailed_art_directory, visual_squad_spacing)

	set_camera_focus(Vector2(548.0, 432.0))
	_select_initial_group()


func _exit_scene() -> void:
	if ResourceLoader.exists("res://scenes/ui/opening_screen.tscn") and get_tree().root.get_child_count() > 0:
		get_tree().change_scene_to_file("res://scenes/ui/opening_screen.tscn")
	else:
		get_tree().quit()


# --- Custom Layer Drawing & Minimap Builder ------------------------------------------------

func _draw_cast_shadows() -> void:
	if _shadow_tex == null:
		return
	for p in _pieces:
		if p.shadow_alpha <= 0.01 or p.shadow_size == Vector2.ZERO:
			continue
		var c := p.to_global(p.shadow_offset)
		var size := p.shadow_size * p.global_scale.abs()
		shadow_layer.draw_texture_rect(_shadow_tex, Rect2(c - size * 0.5, size),
			false, Color(1.0, 1.0, 1.0, p.shadow_alpha))


func _draw_surface_marks() -> void:
	for fp in _footprints:
		var fade := 1.0 - float(fp["age"]) / 5.5
		var pos := (fp["pos"] as Vector2).round() if pixel_mode else (fp["pos"] as Vector2)
		tracks_layer.draw_rect(Rect2(pos, Vector2(1.4, 1.4)), Color(0.35, 0.16, 0.04, 0.44 * fade))


func _draw_combat_fx() -> void:
	# Subtle dotted golden ring showing the contested Orichalcum control zone
	fx_layer.draw_arc(_orichalcum_pos, HOLD_RADIUS, 0.0, TAU, 56, Color(0.98, 0.80, 0.30, 0.18), 1.4)

	for du in _dust:
		var t := float(du["age"]) / float(du["max_age"])
		var r := float(du["size"]) * (1.0 + t * 1.6)
		fx_layer.draw_circle(du["pos"] as Vector2, r, Color(0.94, 0.74, 0.44, 0.42 * (1.0 - t)))

	for mr in _mend_rings:
		var mt := float(mr["age"]) / 0.65
		var rad := lerpf(16.0, float(mr["radius"]), mt)
		fx_layer.draw_arc(mr["pos"] as Vector2, rad, 0.0, TAU, 48, Color(0.35, 0.96, 1.0, 0.78 * (1.0 - mt)), 2.2)

	for tr in _tracers:
		var tt := 1.0 - float(tr["age"]) / float(tr["max_age"])
		var is_b: bool = bool(tr["blue"])
		var heavy: bool = bool(tr["heavy"])
		var col := Color(0.62, 0.94, 1.0, tt) if is_b else Color(1.0, 0.56, 0.28, tt)
		if heavy:
			col = Color(1.0, 0.88, 0.42, tt)
		fx_layer.draw_line(tr["a"] as Vector2, tr["b"] as Vector2, col, 2.4 if heavy else 1.5)

	for fl in _flashes:
		var ft := 1.0 - float(fl["age"]) / float(fl["max_age"])
		var fc: Color = fl["color"] as Color
		fx_layer.draw_circle(fl["pos"] as Vector2, float(fl["radius"]) * (0.6 + 0.5 * (1.0 - ft)), Color(fc.r, fc.g, fc.b, fc.a * ft))

	for m in _markers:
		var mt2 := float(m["age"]) / float(m["max_age"])
		var mc: Color = m["color"] as Color
		fx_layer.draw_arc(m["pos"] as Vector2, lerpf(4.0, 14.0, mt2), 0.0, TAU, 24, Color(mc.r, mc.g, mc.b, 0.85 * (1.0 - mt2)), 1.5)


func _draw_selection_overlay() -> void:
	if not _dragging_box:
		return
	var r := Rect2(_press_world, Vector2.ZERO).expand(_drag_world)
	overlay_layer.draw_rect(r, Color(0.35, 1.0, 0.40, 0.12), true)
	overlay_layer.draw_rect(r, Color(0.35, 1.0, 0.40, 0.92), false, 1.4)


func _build_minimap_texture() -> ImageTexture:
	var mw := 184
	var mh := 118
	var img := Image.create_empty(mw, mh, false, Image.FORMAT_RGBA8)
	var segments := _road_segments()
	for y in range(mh):
		for x in range(mw):
			var wpt := Vector2((float(x) + 0.5) / float(mw) * WORLD_SIZE.x, (float(y) + 0.5) / float(mh) * WORLD_SIZE.y)
			var col := Color(0.84, 0.52, 0.18)  # warm desert sand
			if height_at(wpt) > 0.12:
				col = Color(0.92, 0.64, 0.24)  # golden dune cluster
			# Road & plaza check
			var rd := wpt.distance_to(_orichalcum_pos)
			if rd < 126.0:
				col = Color(0.78, 0.63, 0.46)
			else:
				for seg in segments:
					var nearest := Geometry2D.get_closest_point_to_segment(wpt, Vector2(seg.x, seg.y), Vector2(seg.z, seg.w))
					if wpt.distance_to(nearest) < 24.0:
						col = Color(0.76, 0.60, 0.44)
						break
			# Cliffs & rocks
			for p in _pieces:
				if p.blocks_world_point(wpt):
					col = Color(0.34, 0.23, 0.17)
					if p.piece_id == "outpost_pad":
						col = Color(0.52, 0.54, 0.58)
					elif p.layer_role == "water":
						col = Color(0.18, 0.78, 0.74)
					break
			# Highlight NE Oasis turquoise spring & central golden Orichalcum!
			for p in _pieces:
				if p.piece_id == "cliff_oasis":
					var oasis_pool := p.global_position + Vector2(-78.0, 68.0)
					if wpt.distance_to(oasis_pool) < 42.0:
						col = Color(0.18, 0.78, 0.74)
				elif p.is_orichalcum and wpt.distance_to(p.global_position) < 42.0:
					col = Color(0.98, 0.78, 0.20)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_inside_tree():
		_sync_camera_transform()
