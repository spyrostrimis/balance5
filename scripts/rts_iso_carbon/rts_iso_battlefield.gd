class_name RtsIsoBattlefield
extends Node2D
## Playable isometric Mission 1 study: 'RTS Isometric 2— Forest Claim Carbon'.
## Drives terrain shader splats, valley mist, shelf rims, raised bluffs, split-canopy trees,
## AStarGrid2D walkability, 8-way isometric units, occlusion silhouettes, and the isometric
## minimap strictly from editable RtsIsoLayoutData resources (Layout A and Layout B).

const GROUND_SHADER := preload("res://assets/shaders/rts_iso_forest_ground.gdshader")
const ISO_GROUND_RECT := Rect2(-1320.0, -380.0, 2640.0, 1780.0)
const SPLAT_RES := 144  # 4x4 texels per logical 36x36 cell
const TREAD_RES := 288  # 8x8 texels per logical cell
const HOLD_RADIUS_MAP := 136.0
const HOLD_DURATION := 30.0

@export var layouts: Array[RtsIsoLayoutData] = []
@export var initial_layout_index := 0
@export var start_close_zoom := false

var active_layout_index := 0
var close_zoom := false
var red_ai_active := false
var show_treads := true
var show_seam_debug := false
var disturbed_tread_pixels := 0

var selection: Array[RtsIsoUnit] = []
var hold_seconds_left := HOLD_DURATION
var hold_owner := 0
var match_finished := false

var grid: RtsGrid
var camera: Camera2D
var hud: RtsIsoHud

var _ground_rect: ColorRect
var _valley_canopy_layer: Node2D
var _shelf_rims_layer: Node2D
var _ground_decals_layer: Node2D
var _cast_shadows_layer: Node2D
var _ysort_world: Node2D
var _occlusion_layer: Node2D
var _fx_layer: Node2D
var _overlay_layer: Node2D

var _ground_mat := ShaderMaterial.new()
var _shadow_tex: Texture2D
var _splat_tex: ImageTexture
var _tread_img: Image
var _tread_tex: ImageTexture
var _tread_dirty := false
var _tread_sync_clock := 0.0

var _modules: Array[RtsIsoModule] = []
var _tree_modules: Array[RtsIsoModule] = []
var _occluder_modules: Array[RtsIsoModule] = []
var _units: Array[RtsIsoUnit] = []
var _orichalcum_map_pos := RtsIsoTransform.center_of(Vector2i(17, 18))

var _cam_iso_center := Vector2(0.0, 470.0)
var _custom_zoom_mult := 1.0
var _pan_dragging := false
var _dragging_box := false
var _press_screen := Vector2.ZERO
var _drag_screen := Vector2.ZERO
var _ai_clock := 0.0

var _markers: Array[Dictionary] = []
var _tracers: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _mend_rings: Array[Dictionary] = []


func _ready() -> void:
	RtsIsoKit.ensure_loaded()
	_shadow_tex = load("res://assets/textures/rts/carbon/soft_shadow.png") as Texture2D
	_build_scene_layers()
	_parse_cli_flags()
	close_zoom = start_close_zoom
	load_layout(initial_layout_index)


func _parse_cli_flags() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--layout-b" or a == "--layout=b":
			initial_layout_index = 1
		elif a == "--layout-a" or a == "--layout=a":
			initial_layout_index = 0
		elif a == "--close-zoom":
			start_close_zoom = true


func _build_scene_layers() -> void:
	_ground_rect = ColorRect.new()
	_ground_rect.name = "GroundShelfAndMist"
	_ground_rect.position = ISO_GROUND_RECT.position
	_ground_rect.size = ISO_GROUND_RECT.size
	_ground_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground_mat.shader = GROUND_SHADER
	_ground_mat.set_shader_parameter("iso_rect_pos", ISO_GROUND_RECT.position)
	_ground_mat.set_shader_parameter("iso_rect_size", ISO_GROUND_RECT.size)
	_ground_mat.set_shader_parameter("map_size", RtsIsoTransform.MAP_SIZE)
	_ground_mat.set_shader_parameter("ochre_tex", RtsIsoKit.texture("ground_ochre_earth"))
	_ground_mat.set_shader_parameter("moss_tex", RtsIsoKit.texture("ground_forest_moss"))
	_ground_mat.set_shader_parameter("detail_tex", RtsIsoKit.texture("ground_detail_masks"))
	_ground_rect.material = _ground_mat
	add_child(_ground_rect)

	_valley_canopy_layer = Node2D.new()
	_valley_canopy_layer.name = "LowerValleyMistCanopy"
	add_child(_valley_canopy_layer)

	_shelf_rims_layer = Node2D.new()
	_shelf_rims_layer.name = "ShelfDropoffRims"
	_shelf_rims_layer.y_sort_enabled = true
	add_child(_shelf_rims_layer)

	_ground_decals_layer = Node2D.new()
	_ground_decals_layer.name = "GroundDecals"
	add_child(_ground_decals_layer)

	_cast_shadows_layer = Node2D.new()
	_cast_shadows_layer.name = "CastShadows"
	_cast_shadows_layer.draw.connect(_draw_cast_shadows)
	add_child(_cast_shadows_layer)

	_ysort_world = Node2D.new()
	_ysort_world.name = "YSortWorld"
	_ysort_world.y_sort_enabled = true
	add_child(_ysort_world)

	_occlusion_layer = Node2D.new()
	_occlusion_layer.name = "OcclusionReadability"
	_occlusion_layer.draw.connect(_draw_occlusion_readability)
	add_child(_occlusion_layer)

	_fx_layer = Node2D.new()
	_fx_layer.name = "CombatFx"
	_fx_layer.draw.connect(_draw_combat_fx)
	add_child(_fx_layer)

	_overlay_layer = Node2D.new()
	_overlay_layer.name = "DebugAndSelectionOverlay"
	_overlay_layer.draw.connect(_draw_debug_and_selection_overlay)
	add_child(_overlay_layer)

	grid = RtsGrid.new()
	grid.name = "LogicalGrid"
	grid.cell_pixels = Vector2i(int(RtsIsoTransform.CELL_SIZE), int(RtsIsoTransform.CELL_SIZE))
	var init_mask := Image.create_empty(RtsIsoTransform.GRID_W, RtsIsoTransform.GRID_H, false, Image.FORMAT_RGBA8)
	init_mask.fill(Color(0, 0, 0, 1))
	grid.blocked_cells = ImageTexture.create_from_image(init_mask)
	grid.visible = false  # We draw the isometric projection of grid debug in _overlay_layer!
	add_child(grid)

	camera = Camera2D.new()
	camera.name = "IsometricCamera"
	camera.enabled = true
	add_child(camera)

	hud = RtsIsoHud.new()
	hud.name = "RtsIsoHud"
	hud.command_button_pressed.connect(_on_hud_command)
	hud.toggle_requested.connect(_on_hud_toggle)
	hud.minimap_pan_requested.connect(func(mpt: Vector2) -> void: set_camera_focus_map(mpt))
	hud.minimap_order_requested.connect(func(mpt: Vector2) -> void: issue_order_at_map(mpt))
	add_child(hud)


func current_layout() -> RtsIsoLayoutData:
	if layouts.is_empty():
		return null
	return layouts[clampi(active_layout_index, 0, layouts.size() - 1)]


func load_layout(index: int) -> void:
	if layouts.is_empty():
		return
	active_layout_index = posmod(index, layouts.size())
	var layout := current_layout()

	# Clear previous modules & units immediately from parent so node names never collide
	for m in _modules:
		if is_instance_valid(m):
			if m.get_parent() != null:
				m.get_parent().remove_child(m)
			m.queue_free()
	_modules.clear()
	_tree_modules.clear()
	_occluder_modules.clear()

	for u in _units:
		if is_instance_valid(u):
			if u.get_parent() != null:
				u.get_parent().remove_child(u)
			u.queue_free()
	_units.clear()
	selection.clear()

	_markers.clear()
	_tracers.clear()
	_flashes.clear()
	_mend_rings.clear()
	hold_seconds_left = HOLD_DURATION
	hold_owner = 0
	match_finished = false

	_init_tread_buffer()

	# 1. Instantiate placed modules from layout data
	_orichalcum_map_pos = RtsIsoTransform.center_of(Vector2i(17, 18))
	for p_dict: Dictionary in layout.placements:
		var mod := RtsIsoModule.new()
		mod.configure(p_dict)
		var is_valley := bool(p_dict.get("valley_below", false))
		if is_valley:
			mod.role = "valley_canopy"
			mod.has_canopy = false
			mod.tall_occluder = false
			# Use crown-only texture so misty treetops peek from below the cliff with zero exposed trunk!
			var crown_only := RtsIsoKit.texture(mod.piece_id + "_crown")
			if crown_only != null:
				mod.tex_main = crown_only
			mod.tex_trunk = null
			mod.tex_crown = null
		mod.show_seam_debug = show_seam_debug and not is_valley
		if mod.role == "valley_canopy":
			_valley_canopy_layer.add_child(mod)
		elif mod.role == "shelf_rim":
			_shelf_rims_layer.add_child(mod)
		elif mod.role == "ground_decal":
			_ground_decals_layer.add_child(mod)
		else:
			_ysort_world.add_child(mod)
		_modules.append(mod)
		if mod.has_canopy and mod.role == "tree":
			_tree_modules.append(mod)
		if mod.tall_occluder and mod.role != "tree" and mod.role != "shelf_rim" and mod.role != "valley_canopy":
			_occluder_modules.append(mod)
		if mod.is_orichalcum:
			_orichalcum_map_pos = mod.map_pos

	# 2. Build 36x36 walkability mask strictly from shelf terrain + module footprints
	var mask_img := Image.create_empty(RtsIsoTransform.GRID_W, RtsIsoTransform.GRID_H, false, Image.FORMAT_RGBA8)
	mask_img.fill(Color(0, 0, 0, 1))
	for cy in range(RtsIsoTransform.GRID_H):
		for cx in range(RtsIsoTransform.GRID_W):
			var c := Vector2i(cx, cy)
			if not layout.is_shelf_cell(c):
				mask_img.set_pixel(cx, cy, Color(1, 0, 0, 1))
	for mod in _modules:
		if mod.role == "valley_canopy":
			continue
		for bc in mod.blocked_cells():
			if RtsIsoTransform.in_bounds(bc):
				mask_img.set_pixel(bc.x, bc.y, Color(1, 0, 0, 1))
	# Keep far north/west woodland border (u < 3 or v < 3) non-walkable while visually forested
	for cy in range(RtsIsoTransform.GRID_H):
		for cx in range(RtsIsoTransform.GRID_W):
			if cx < 3 or cy < 3:
				mask_img.set_pixel(cx, cy, Color(1, 0, 0, 1))

	grid.cell_pixels = Vector2i(int(RtsIsoTransform.CELL_SIZE), int(RtsIsoTransform.CELL_SIZE))
	grid.blocked_cells = ImageTexture.create_from_image(mask_img)
	grid.setup()

	# 3. Build continuous splat + canopy/cliff shade texture for ground shader
	_build_ground_splat_texture(layout)

	# 4. Spawn Blue & Red units from layout data
	for s_dict: Dictionary in layout.unit_spawns:
		var u := _create_unit_from_spawn(s_dict)
		_ysort_world.add_child(u)
		var spawn_cell: Vector2i = s_dict.get("cell", Vector2i(12, 22))
		if not grid.is_walkable(spawn_cell):
			var near := grid.free_cells_near(spawn_cell, 1)
			if not near.is_empty():
				spawn_cell = near[0]
		u.setup(self, grid, RtsIsoTransform.center_of(spawn_cell))
		_units.append(u)

	# 5. Build isometric-aligned minimap texture strictly from the same layout data
	hud.layout_label = layout.display_name
	hud.all_units = _units
	hud.minimap_tex = _build_isometric_minimap(layout, mask_img)

	_select_initial_blue_forces()
	set_camera_focus_map(layout.camera_start_cell * RtsIsoTransform.CELL_SIZE)
	apply_zoom_framing()
	_cast_shadows_layer.queue_redraw()
	_overlay_layer.queue_redraw()
	_sync_hud_state()


func _create_unit_from_spawn(s_dict: Dictionary) -> RtsIsoUnit:
	var u := RtsIsoUnit.new()
	u.name = String(s_dict.get("node_name", "Unit"))
	var team_id := int(s_dict.get("team", 0))
	var role_id := int(s_dict.get("role", 0))
	u.team = RtsIsoUnit.Team.BLUE if team_id == 0 else RtsIsoUnit.Team.RED
	u.role = role_id as RtsIsoUnit.Role

	if u.team == RtsIsoUnit.Team.BLUE:
		match u.role:
			RtsIsoUnit.Role.COMMANDER:
				u.display_name = "Blue Commander"
				u.subtitle = "Royal Guard · Mend"
				u.portrait_key = "blue_commander"
				u.sprite_key = "blue_commander"
				u.max_health = 96
				u.attack_damage = 16
				u.armour = 4
				u.attack_range_cells = 5.2
				u.speed_map_px = 66.0
			RtsIsoUnit.Role.TANK:
				u.display_name = "Vanguard Tank"
				u.subtitle = "Blue Tracked Armour"
				u.portrait_key = "blue_tank"
				u.sprite_key = "blue_tank"
				u.max_health = 140
				u.attack_damage = 22
				u.armour = 6
				u.attack_range_cells = 5.6
				u.attack_cooldown = 1.32
				u.speed_map_px = 70.0
				u.turn_rate = 4.6
			_:
				u.display_name = "Rifle Squad"
				u.subtitle = "Blue Infantry"
				u.portrait_key = "blue_squad"
				u.sprite_key = "blue_soldier"
				u.max_health = 68
				u.attack_damage = 13
				u.armour = 3
				u.attack_range_cells = 4.8
				u.speed_map_px = 60.0
	else:
		match u.role:
			RtsIsoUnit.Role.COMMANDER:
				u.display_name = "Red Commander"
				u.subtitle = "Order Officer"
				u.portrait_key = "red_commander"
				u.sprite_key = "red_commander"
				u.max_health = 96
				u.attack_damage = 17
				u.armour = 4
				u.attack_range_cells = 5.2
				u.speed_map_px = 64.0
			RtsIsoUnit.Role.TANK:
				u.display_name = "Heavy Tank"
				u.subtitle = "Red Siege Armour"
				u.portrait_key = "red_tank"
				u.sprite_key = "red_tank"
				u.max_health = 145
				u.attack_damage = 23
				u.armour = 6
				u.attack_range_cells = 5.6
				u.attack_cooldown = 1.38
				u.speed_map_px = 66.0
				u.turn_rate = 4.4
			_:
				u.display_name = "Legionary Squad"
				u.subtitle = "Red Infantry"
				u.portrait_key = "red_squad"
				u.sprite_key = "red_soldier"
				u.max_health = 68
				u.attack_damage = 13
				u.armour = 3
				u.attack_range_cells = 4.8
				u.speed_map_px = 58.0
	u.died.connect(func(_dead: RtsIsoUnit) -> void:
		if _dead in selection:
			set_selection(selection.filter(func(x: RtsIsoUnit) -> bool: return x != _dead and x.alive))
		_sync_hud_state()
	)
	return u


func _init_tread_buffer() -> void:
	_tread_img = Image.create_empty(TREAD_RES, TREAD_RES, false, Image.FORMAT_RGBA8)
	_tread_img.fill(Color(0, 0, 0, 1))
	_tread_tex = ImageTexture.create_from_image(_tread_img)
	_ground_mat.set_shader_parameter("tread_tex", _tread_tex)
	disturbed_tread_pixels = 0
	_tread_dirty = false


func _build_ground_splat_texture(layout: RtsIsoLayoutData) -> void:
	# Sample cell grid + smooth blur so transitions between Forest/Moss/Ochre and Shelf/Mist are organic!
	var raw := Image.create_empty(SPLAT_RES, SPLAT_RES, false, Image.FORMAT_RGBA8)
	for py in range(SPLAT_RES):
		for px in range(SPLAT_RES):
			var map_pt := Vector2((float(px) + 0.5) / float(SPLAT_RES), (float(py) + 0.5) / float(SPLAT_RES)) * RtsIsoTransform.MAP_SIZE
			# Bilinear-style neighborhood average over logical cells for smooth curves
			var cf := map_pt / RtsIsoTransform.CELL_SIZE - Vector2(0.5, 0.5)
			var c0 := Vector2i(cf.floor())
			var f := cf - Vector2(c0)
			var shelf_acc := 0.0
			var ochre_acc := 0.0
			for dy in range(2):
				var wy := (1.0 - f.y) if dy == 0 else f.y
				for dx in range(2):
					var wx := (1.0 - f.x) if dx == 0 else f.x
					var cc := c0 + Vector2i(dx, dy)
					var w := wx * wy
					if RtsIsoTransform.in_bounds(cc) and layout.is_shelf_cell(cc):
						shelf_acc += w
						ochre_acc += w * layout.ochre_weight_at(cc)
			var ochre_norm := (ochre_acc / maxf(shelf_acc, 0.05)) if shelf_acc > 0.02 else 0.0
			var iso_pt := RtsIsoTransform.map_to_iso(map_pt)
			var shade := shade_at_iso(iso_pt)
			raw.set_pixel(px, py, Color(shelf_acc, ochre_norm, shade, 1.0))

	_splat_tex = ImageTexture.create_from_image(raw)
	_ground_mat.set_shader_parameter("splat_tex", _splat_tex)


func _build_isometric_minimap(layout: RtsIsoLayoutData, blocked_img: Image) -> ImageTexture:
	var mw := 184
	var mh := 108
	var img := Image.create_empty(mw, mh, false, Image.FORMAT_RGBA8)
	for y in range(mh):
		for x in range(mw):
			var uv := Vector2((float(x) + 0.5) / float(mw), (float(y) + 0.5) / float(mh))
			var map_pt := RtsIsoTransform.minimap_uv_to_map(uv)
			var c := RtsIsoTransform.cell_of(map_pt)
			var col := Color(0.20, 0.36, 0.46)  # cool blue valley mist outside shelf
			if RtsIsoTransform.in_bounds(c) and layout.is_shelf_cell(c):
				var code := layout.terrain_code_at(c)
				match code:
					"T":
						col = Color(0.84, 0.58, 0.34)
					"O":
						col = Color(0.78, 0.54, 0.32)
					"M":
						col = Color(0.42, 0.58, 0.28)
					_:
						col = Color(0.24, 0.43, 0.24)
				if blocked_img.get_pixelv(c).r > 0.5:
					col = Color(0.32, 0.28, 0.36)  # dark lavender-slate cliff / trunk obstacle
			if map_pt.distance_to(_orichalcum_map_pos) < 52.0:
				col = Color(0.99, 0.74, 0.18)      # bright amber Orichalcum crystal
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func shade_at_iso(iso_pt: Vector2) -> float:
	var lit := 1.0
	for m in _modules:
		if m.shade_strength > 0.0:
			lit *= (1.0 - m.shade_at_iso(iso_pt))
	return clampf(1.0 - lit, 0.0, 0.68)


func shade_at_map(map_pt: Vector2) -> float:
	return shade_at_iso(RtsIsoTransform.map_to_iso(map_pt))


func get_living_units() -> Array[RtsIsoUnit]:
	var out: Array[RtsIsoUnit] = []
	for u in _units:
		if is_instance_valid(u) and u.alive:
			out.append(u)
	return out


func _select_initial_blue_forces() -> void:
	var blue: Array[RtsIsoUnit] = []
	for u in get_living_units():
		if u.team == RtsIsoUnit.Team.BLUE and u.role == RtsIsoUnit.Role.COMMANDER:
			blue.append(u)
	if blue.is_empty():
		for u in get_living_units():
			if u.team == RtsIsoUnit.Team.BLUE:
				blue.append(u)
				break
	set_selection(blue)


# --- Camera & Zoom --------------------------------------------------------------------------

func apply_zoom_framing() -> void:
	hud.close_zoom = close_zoom
	_custom_zoom_mult = 1.0
	_sync_camera_transform()


func _base_zoom() -> float:
	# Command zoom = 1.00 (frames clearing, cliff rim, and both approaches at 1376x768)
	# Close inspection zoom = 1.55 (frames squad/tree/cliff brushwork up close)
	var vp_scale := get_viewport().get_visible_rect().size.y / 768.0
	return (1.55 if close_zoom else 1.00) * maxf(vp_scale, 0.5)


func _sync_camera_transform() -> void:
	if camera == null or hud == null:
		return
	var play_rect := hud.playable_screen_rect()
	var z := clampf(_base_zoom() * _custom_zoom_mult, 0.65, 2.40)
	camera.zoom = Vector2(z, z)

	var vis_iso_size := play_rect.size / z
	var half := vis_iso_size * 0.5
	var bounds := RtsIsoTransform.MINIMAP_ISO_RECT.grow(80.0)
	_cam_iso_center.x = clampf(_cam_iso_center.x, bounds.position.x + half.x * 0.55, bounds.end.x - half.x * 0.55)
	_cam_iso_center.y = clampf(_cam_iso_center.y, bounds.position.y + half.y * 0.45, bounds.end.y - half.y * 0.35)

	var vp_center := get_viewport().get_visible_rect().size * 0.5
	var play_center := play_rect.get_center()
	var screen_shift := vp_center - play_center
	camera.position = _cam_iso_center + screen_shift / z
	camera.force_update_scroll()

	hud.camera_iso_rect = Rect2(_cam_iso_center - half, vis_iso_size)
	hud.request_repaint()


func set_camera_focus_map(map_pt: Vector2) -> void:
	_cam_iso_center = RtsIsoTransform.map_to_iso(map_pt)
	_sync_camera_transform()


func screen_to_map(screen_pt: Vector2) -> Vector2:
	return RtsIsoTransform.screen_to_map(get_canvas_transform(), screen_pt)


func map_to_screen(map_pt: Vector2) -> Vector2:
	return RtsIsoTransform.map_to_screen(get_canvas_transform(), map_pt)


# --- Live Tank Tracks & Combat FX -----------------------------------------------------------

func record_tank_treads(prev_map: Vector2, prev_dir: Vector2, next_map: Vector2, next_dir: Vector2) -> void:
	if _tread_img == null:
		return
	var side_a := Vector2(-prev_dir.y, prev_dir.x).normalized() * 7.5
	var side_b := Vector2(-next_dir.y, next_dir.x).normalized() * 7.5
	for sign_f: float in [-1.0, 1.0]:
		var p0: Vector2 = (prev_map + side_a * sign_f) / RtsIsoTransform.MAP_SIZE * float(TREAD_RES)
		var p1: Vector2 = (next_map + side_b * sign_f) / RtsIsoTransform.MAP_SIZE * float(TREAD_RES)
		for s in range(5):
			var pt: Vector2 = p0.lerp(p1, float(s) / 4.0)
			var ix := clampi(roundi(pt.x), 1, TREAD_RES - 2)
			var iy := clampi(roundi(pt.y), 1, TREAD_RES - 2)
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var old_r := _tread_img.get_pixel(ix + ox, iy + oy).r
					var add_r := 0.58 if (ox == 0 and oy == 0) else 0.30
					if old_r < 0.10:
						disturbed_tread_pixels += 1
					_tread_img.set_pixel(ix + ox, iy + oy, Color(minf(1.0, old_r + add_r), 0, 0, 1))
	_tread_dirty = true


func spawn_weapon_fire(from_map: Vector2, to_map: Vector2, is_blue: bool, heavy_shell: bool) -> void:
	var a_iso := RtsIsoTransform.map_to_iso(from_map) + Vector2(0, -16)
	var b_iso := RtsIsoTransform.map_to_iso(to_map) + Vector2(0, -14)
	_tracers.append({
		"a": a_iso,
		"b": b_iso,
		"age": 0.0,
		"max_age": 0.18 if heavy_shell else 0.12,
		"blue": is_blue,
		"heavy": heavy_shell,
	})
	_flashes.append({
		"pos": b_iso,
		"age": 0.0,
		"max_age": 0.24 if heavy_shell else 0.15,
		"radius": 14.0 if heavy_shell else 7.5,
		"color": Color(1.0, 0.78, 0.32) if heavy_shell else (Color(0.45, 0.88, 1.0) if is_blue else Color(1.0, 0.45, 0.32)),
	})


func spawn_unit_burst(at_map: Vector2, heavy: bool) -> void:
	_flashes.append({
		"pos": RtsIsoTransform.map_to_iso(at_map) + Vector2(0, -10),
		"age": 0.0,
		"max_age": 0.42,
		"radius": 26.0 if heavy else 16.0,
		"color": Color(1.0, 0.66, 0.24),
	})


func spawn_mend_pulse(center_map: Vector2, radius_map: float) -> void:
	_mend_rings.append({
		"map_pos": center_map,
		"radius_map": radius_map,
		"age": 0.0,
		"max_age": 0.65,
	})


# --- Process Loop ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_handle_camera_pan_keys(delta)
	_update_canopy_transparency(delta)
	_tick_fx_and_treads(delta)
	_tick_objective(delta)
	if red_ai_active and not match_finished:
		_tick_red_ai(delta)
	_occlusion_layer.queue_redraw()
	_sync_hud_state()


func _handle_camera_pan_keys(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		pan.x -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		pan.x += 1.0
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		pan.y -= 1.0
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		# Only pan down on S if Shift isn't held and S wasn't just pressed as Stop
		if Input.is_physical_key_pressed(KEY_DOWN):
			pan.y += 1.0
	if pan.length_squared() > 0.01:
		_cam_iso_center += pan.normalized() * (420.0 / maxf(camera.zoom.x, 0.5)) * delta
		_sync_camera_transform()


func _update_canopy_transparency(delta: float) -> void:
	if _tree_modules.is_empty():
		return
	var mouse_scr := get_viewport().get_mouse_position()
	var mouse_in_play := not hud.consumes_screen_point(mouse_scr)
	var mouse_iso := RtsIsoTransform.screen_to_iso(get_canvas_transform(), mouse_scr)

	var living := get_living_units()
	for tree in _tree_modules:
		var crect := tree.canopy_iso_rect()
		var fade := 1.0
		for u in living:
			var u_head := u.position + u.visual_center_iso_offset()
			# Unit is visually overlapped by overhanging tree boughs (behind/under crown)
			if u.position.y < tree.position.y + 8.0 and crect.has_point(u_head):
				if u.selected or u.team == RtsIsoUnit.Team.BLUE:
					fade = minf(fade, 0.40)
				else:
					fade = minf(fade, 0.52)
		if mouse_in_play and not selection.is_empty() and crect.has_point(mouse_iso):
			fade = minf(fade, 0.56)
		tree.update_canopy_fade(fade, delta)


func _tick_fx_and_treads(delta: float) -> void:
	_tread_sync_clock += delta
	if _tread_dirty and _tread_sync_clock >= 0.08:
		_tread_tex.update(_tread_img)
		_tread_dirty = false
		_tread_sync_clock = 0.0

	var dirty_fx := false
	for arr: Array in [_markers, _tracers, _flashes, _mend_rings]:
		for i in range(arr.size() - 1, -1, -1):
			dirty_fx = true
			arr[i]["age"] = float(arr[i]["age"]) + delta
			if float(arr[i]["age"]) >= float(arr[i]["max_age"]):
				arr.remove_at(i)
	if dirty_fx:
		_fx_layer.queue_redraw()


func _tick_objective(delta: float) -> void:
	if match_finished:
		return
	var blue_in := 0
	var red_in := 0
	var blue_total_alive := 0
	var red_total_alive := 0
	for u in get_living_units():
		if u.team == RtsIsoUnit.Team.BLUE:
			blue_total_alive += 1
			if u.map_pos.distance_to(_orichalcum_map_pos) <= HOLD_RADIUS_MAP:
				blue_in += 1
		else:
			red_total_alive += 1
			if u.map_pos.distance_to(_orichalcum_map_pos) <= HOLD_RADIUS_MAP:
				red_in += 1

	if red_total_alive == 0 and blue_total_alive > 0:
		hold_owner = 1
		hold_seconds_left = 0.0
		match_finished = true
		hud.hold_state = "Victory! Red Eliminated"
		return
	elif blue_total_alive == 0 and red_total_alive > 0:
		hold_owner = 2
		hold_seconds_left = 0.0
		match_finished = true
		hud.hold_state = "Defeat · Forces Lost"
		return

	if blue_in > 0 and red_in == 0:
		if hold_owner != 1:
			hold_owner = 1
			hold_seconds_left = HOLD_DURATION
		hold_seconds_left = maxf(0.0, hold_seconds_left - delta)
		hud.hold_state = "Blue Holding Crystal!"
		if hold_seconds_left <= 0.0:
			match_finished = true
			hud.hold_state = "Victory! Forest Claimed"
	elif red_in > 0 and blue_in == 0:
		if hold_owner != 2:
			hold_owner = 2
			hold_seconds_left = HOLD_DURATION
		hold_seconds_left = maxf(0.0, hold_seconds_left - delta)
		hud.hold_state = "Red Holding Crystal!"
		if hold_seconds_left <= 0.0:
			match_finished = true
			hud.hold_state = "Defeat · Claim Lost"
	elif blue_in > 0 and red_in > 0:
		hud.hold_state = "Contested! Clear Red"
	else:
		hold_owner = 0
		hold_seconds_left = minf(HOLD_DURATION, hold_seconds_left + delta * 0.5)
		hud.hold_state = "Uncontested · Move to Crystal"


func _tick_red_ai(delta: float) -> void:
	_ai_clock += delta
	if _ai_clock < 1.25:
		return
	_ai_clock = 0.0
	var living := get_living_units()
	var blues: Array[RtsIsoUnit] = []
	for u in living:
		if u.team == RtsIsoUnit.Team.BLUE:
			blues.append(u)
	if blues.is_empty():
		return

	var idx := 0
	for u in living:
		if u.team != RtsIsoUnit.Team.RED or u.order == RtsIsoUnit.Order.ATTACK:
			continue
		var best_b: RtsIsoUnit = null
		var best_d := INF
		for b in blues:
			var d := u.map_pos.distance_to(b.map_pos)
			if d < best_d:
				best_d = d
				best_b = b
		if best_b != null and best_d <= 240.0:
			u.command_attack(best_b)
		elif u.map_pos.distance_to(_orichalcum_map_pos) > 96.0 and u.order == RtsIsoUnit.Order.NONE:
			var angle := float(idx) * 1.4 + 0.5
			u.command_move(_orichalcum_map_pos + Vector2(cos(angle), sin(angle)) * 68.0)
		idx += 1


func _sync_hud_state() -> void:
	var b_alive := 0
	var b_total := 0
	for u in _units:
		if is_instance_valid(u) and u.team == RtsIsoUnit.Team.BLUE:
			b_total += 1
			if u.alive:
				b_alive += 1
	hud.blue_alive = b_alive
	hud.blue_total = maxi(b_total, 1)
	hud.hold_seconds_left = hold_seconds_left
	hud.hold_duration = HOLD_DURATION
	hud.hold_owner = hold_owner
	hud.red_ai_active = red_ai_active
	hud.request_repaint()


# --- Input, Selection & Orders --------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			match k.keycode:
				KEY_ESCAPE:
					_exit_scene()
					get_viewport().set_input_as_handled()
					return
				KEY_L:
					load_layout(active_layout_index + 1)
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
				KEY_X:
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
					_overlay_layer.queue_redraw()
					get_viewport().set_input_as_handled()
					return
				KEY_F2:
					show_seam_debug = not show_seam_debug
					for m in _modules:
						m.show_seam_debug = show_seam_debug
						m.queue_redraw()
					_overlay_layer.queue_redraw()
					get_viewport().set_input_as_handled()
					return
				KEY_R:
					load_layout(active_layout_index)
					get_viewport().set_input_as_handled()
					return
				KEY_1:
					var lay := current_layout()
					if lay != null:
						set_camera_focus_map(lay.camera_start_cell * RtsIsoTransform.CELL_SIZE)
					get_viewport().set_input_as_handled()
					return
				KEY_2:
					var lay2 := current_layout()
					if lay2 != null:
						set_camera_focus_map(lay2.camera_poi_north * RtsIsoTransform.CELL_SIZE)
					get_viewport().set_input_as_handled()
					return
				KEY_3:
					var lay3 := current_layout()
					if lay3 != null:
						set_camera_focus_map(lay3.camera_poi_east * RtsIsoTransform.CELL_SIZE)
					get_viewport().set_input_as_handled()
					return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if hud.consumes_screen_point(mb.position):
			return
		var map_pt := screen_to_map(mb.position)
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_dragging = mb.pressed
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_custom_zoom_mult = clampf(_custom_zoom_mult * 1.12, 0.75, 1.80)
			_sync_camera_transform()
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_custom_zoom_mult = clampf(_custom_zoom_mult / 1.12, 0.75, 1.80)
			_sync_camera_transform()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if hud.command_cursor_mode != "":
					issue_order_at_map(map_pt, hud.command_cursor_mode)
					hud.command_cursor_mode = ""
					get_viewport().set_input_as_handled()
					return
				_dragging_box = false
				_press_screen = mb.position
				_drag_screen = mb.position
			else:
				if _dragging_box:
					var sbox := Rect2(_press_screen, Vector2.ZERO).expand(mb.position)
					select_in_screen_box(sbox, mb.shift_pressed)
				else:
					click_select_at_screen(mb.position, mb.shift_pressed)
				_dragging_box = false
				_overlay_layer.queue_redraw()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			hud.command_cursor_mode = ""
			issue_order_at_map(map_pt)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pan_dragging:
			_cam_iso_center -= mm.relative / maxf(camera.zoom.x, 0.25)
			_sync_camera_transform()
			get_viewport().set_input_as_handled()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not hud.consumes_screen_point(mm.position):
			_drag_screen = mm.position
			if not _dragging_box and mm.position.distance_to(_press_screen) > 6.0:
				_dragging_box = true
			if _dragging_box:
				_overlay_layer.queue_redraw()


func _unit_under_map(map_pt: Vector2) -> RtsIsoUnit:
	var best: RtsIsoUnit = null
	var best_d := INF
	var iso_click := RtsIsoTransform.map_to_iso(map_pt)
	for u in get_living_units():
		var d_map := u.map_pos.distance_to(map_pt)
		# Also allow clicking upper body in isometric space so tall figures feel natural to click!
		var d_body := (u.position + u.visual_center_iso_offset()).distance_to(iso_click)
		if (d_map <= u.select_radius_map() + 6.0 or d_body <= 18.0) and d_map < best_d:
			best_d = d_map
			best = u
	return best


func click_select_at_screen(screen_pt: Vector2, additive := false) -> void:
	var map_pt := screen_to_map(screen_pt)
	var u := _unit_under_map(map_pt)
	if u != null and u.team == RtsIsoUnit.Team.BLUE:
		if not additive:
			set_selection([u])
		elif u in selection:
			set_selection(selection.filter(func(x: RtsIsoUnit) -> bool: return x != u))
		else:
			var next_sel := selection.duplicate()
			next_sel.append(u)
			set_selection(next_sel)
	elif not additive:
		set_selection([])


func select_in_screen_box(screen_box: Rect2, additive := false) -> void:
	var picked: Array[RtsIsoUnit] = []
	if additive:
		picked.assign(selection)
	var cxf := get_canvas_transform()
	for u in get_living_units():
		if u.team != RtsIsoUnit.Team.BLUE:
			continue
		var scr_feet := cxf * u.position
		var scr_body := cxf * (u.position + u.visual_center_iso_offset())
		if screen_box.grow(6.0).has_point(scr_feet) or screen_box.grow(6.0).has_point(scr_body):
			if not (u in picked):
				picked.append(u)
	set_selection(picked)


func set_selection(units_list: Array[RtsIsoUnit]) -> void:
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


func issue_order_at_map(map_pt: Vector2, forced_mode := "") -> void:
	if selection.is_empty():
		return
	var enemy := _unit_under_map(map_pt)
	if forced_mode != "move" and enemy != null and enemy.team == RtsIsoUnit.Team.RED:
		for u in selection:
			u.command_attack(enemy)
		_markers.append({"map_pos": enemy.map_pos, "age": 0.0, "max_age": 0.45, "color": Color(1.0, 0.36, 0.30)})
		_fx_layer.queue_redraw()
		return

	if forced_mode == "attack":
		# Attack-move toward destination or nearest Red near click
		for u in selection:
			u.command_move(map_pt)
		_markers.append({"map_pos": map_pt, "age": 0.0, "max_age": 0.45, "color": Color(1.0, 0.56, 0.24)})
		_fx_layer.queue_redraw()
		return

	var center_cell := RtsIsoTransform.cell_of(RtsIsoTransform.clamp_map_point(map_pt, 18.0))
	var dest_cells := grid.free_cells_near(center_cell, selection.size(), selection)
	for i in range(selection.size()):
		var u := selection[i]
		if i == 0 and selection.size() == 1 and grid.is_walkable(center_cell):
			u.command_move(RtsIsoTransform.clamp_map_point(map_pt, 18.0))
		elif i < dest_cells.size():
			u.command_move(RtsIsoTransform.center_of(dest_cells[i]))
		else:
			u.command_move(map_pt)

	var marker_pos := RtsIsoTransform.center_of(dest_cells[0]) if (not grid.is_walkable(center_cell) and not dest_cells.is_empty()) else map_pt
	_markers.append({"map_pos": marker_pos, "age": 0.0, "max_age": 0.48, "color": Color(0.42, 0.98, 0.62)})
	_fx_layer.queue_redraw()


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
		"layout":
			load_layout(active_layout_index + 1)
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
		u.command_stop()
		u.hold_position = next_hold
	hud.request_repaint()


func _trigger_mend() -> void:
	for u in selection:
		if u.can_mend() and u.mend_timer <= 0.0:
			u.cast_mend()
	hud.request_repaint()


func _exit_scene() -> void:
	var launcher := get_node_or_null("/root/BuildLauncher")
	if launcher != null and launcher.has_method("is_build_active") and launcher.is_build_active():
		launcher._return_to_developers_page()
	elif FileAccess.file_exists("res://scenes/ui/opening_screen.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/opening_screen.tscn")
	else:
		get_tree().quit()


# --- Custom Drawing Passes ------------------------------------------------------------------

func _draw_cast_shadows() -> void:
	# Subtle golden Orichalcum claim zone ring in isometric ground space
	var ring := PackedVector2Array()
	for i in range(49):
		var a := float(i) / 48.0 * TAU
		ring.append(RtsIsoTransform.map_to_iso(_orichalcum_map_pos + Vector2(cos(a), sin(a)) * HOLD_RADIUS_MAP))
	var rcol := Color(0.98, 0.78, 0.28, 0.28)
	if hold_owner == 1:
		rcol = Color(0.36, 0.86, 1.0, 0.36)
	elif hold_owner == 2:
		rcol = Color(1.0, 0.38, 0.30, 0.36)
	_cast_shadows_layer.draw_polyline(ring, rcol, 1.8, true)

	if _shadow_tex == null:
		return
	for m in _modules:
		if m.shade_strength <= 0.0 or m.role == "shelf_rim" or m.role == "ground_decal":
			continue
		var srad := m.shade_radius * 0.82
		var scenter := m.position + m.shade_offset * 0.65
		var srect := Rect2(scenter - srad, srad * 2.0)
		_cast_shadows_layer.draw_texture_rect(_shadow_tex, srect, false, Color(0.10, 0.12, 0.24, m.shade_strength * 0.62))


func _draw_occlusion_readability() -> void:
	var living := get_living_units()
	for u in living:
		var u_center := u.position + u.visual_center_iso_offset()
		var occluded := false
		for m in _occluder_modules:
			# Module is in front of unit (higher iso Y) and its upper silhouette overlaps unit body
			if m.position.y > u.position.y + 4.0 and m.occluder_iso_rect().has_point(u_center):
				occluded = true
				break
		if occluded:
			var col := Color(0.32, 0.90, 1.0, 0.78) if u.team == RtsIsoUnit.Team.BLUE else Color(1.0, 0.42, 0.36, 0.78)
			var r := 14.0 if u.role == RtsIsoUnit.Role.TANK else 9.5
			_occlusion_layer.draw_arc(u_center, r, 0.0, TAU, 20, col, 1.7, true)
			_occlusion_layer.draw_circle(u_center, r * 0.55, Color(col.r, col.g, col.b, 0.22))


func _draw_combat_fx() -> void:
	for mk: Dictionary in _markers:
		var t := float(mk["age"]) / float(mk["max_age"])
		var mcol: Color = mk["color"]
		mcol.a = (1.0 - t) * 0.88
		var r := lerpf(18.0, 5.0, t)
		var ring := PackedVector2Array()
		for i in range(21):
			var a := float(i) / 20.0 * TAU
			ring.append(RtsIsoTransform.map_to_iso((mk["map_pos"] as Vector2) + Vector2(cos(a), sin(a)) * r))
		_fx_layer.draw_polyline(ring, mcol, 1.8, true)

	for tr: Dictionary in _tracers:
		var t := float(tr["age"]) / float(tr["max_age"])
		var p0 := (tr["a"] as Vector2).lerp(tr["b"] as Vector2, maxf(0.0, t - 0.38))
		var p1 := (tr["a"] as Vector2).lerp(tr["b"] as Vector2, minf(1.0, t + 0.24))
		var heavy := bool(tr["heavy"])
		var c := Color(1.0, 0.86, 0.42, 1.0 - t * 0.5) if heavy else (Color(0.56, 0.92, 1.0, 1.0 - t * 0.5) if bool(tr["blue"]) else Color(1.0, 0.46, 0.34, 1.0 - t * 0.5))
		_fx_layer.draw_line(p0, p1, c, 3.0 if heavy else 1.9, true)

	for fl: Dictionary in _flashes:
		var t := float(fl["age"]) / float(fl["max_age"])
		var fc: Color = fl["color"]
		fc.a = (1.0 - t) * 0.78
		_fx_layer.draw_circle(fl["pos"] as Vector2, float(fl["radius"]) * (0.45 + t * 0.75), fc)

	for mr: Dictionary in _mend_rings:
		var t := float(mr["age"]) / float(mr["max_age"])
		var cur_r := float(mr["radius_map"]) * smoothstep(0.0, 1.0, t)
		var mpts := PackedVector2Array()
		for i in range(37):
			var a := float(i) / 36.0 * TAU
			mpts.append(RtsIsoTransform.map_to_iso((mr["map_pos"] as Vector2) + Vector2(cos(a), sin(a)) * cur_r))
		_fx_layer.draw_polyline(mpts, Color(0.36, 0.96, 1.0, (1.0 - t) * 0.85), 2.4, true)


func _draw_debug_and_selection_overlay() -> void:
	if grid != null and grid.show_debug:
		for cy in range(RtsIsoTransform.GRID_H):
			for cx in range(RtsIsoTransform.GRID_W):
				var c := Vector2i(cx, cy)
				var tl := RtsIsoTransform.map_to_iso(Vector2(cx, cy) * RtsIsoTransform.CELL_SIZE)
				var tr := RtsIsoTransform.map_to_iso(Vector2(cx + 1, cy) * RtsIsoTransform.CELL_SIZE)
				var br := RtsIsoTransform.map_to_iso(Vector2(cx + 1, cy + 1) * RtsIsoTransform.CELL_SIZE)
				var bl := RtsIsoTransform.map_to_iso(Vector2(cx, cy + 1) * RtsIsoTransform.CELL_SIZE)
				var poly := PackedVector2Array([tl, tr, br, bl])
				if not grid.is_walkable(c):
					_overlay_layer.draw_colored_polygon(poly, Color(0.95, 0.18, 0.18, 0.30))
				elif grid.unit_at(c) != null:
					_overlay_layer.draw_colored_polygon(poly, Color(0.35, 0.95, 1.0, 0.28))
				_overlay_layer.draw_polyline(PackedVector2Array([tl, tr, br, bl, tl]), Color(0.0, 0.0, 0.0, 0.14), 1.0)

	if show_seam_debug:
		var font := ThemeDB.fallback_font
		for m in _modules:
			var lbl := m.piece_id if m.tag.is_empty() else (m.tag + " (" + m.piece_id + ")")
			_overlay_layer.draw_string(font, m.position + Vector2(-34, -8), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.95, 0.45, 0.95))

	if _dragging_box:
		var cxf_inv := get_canvas_transform().affine_inverse()
		var sbox := Rect2(_press_screen, Vector2.ZERO).expand(_drag_screen)
		var p0 := cxf_inv * sbox.position
		var p1 := cxf_inv * Vector2(sbox.end.x, sbox.position.y)
		var p2 := cxf_inv * sbox.end
		var p3 := cxf_inv * Vector2(sbox.position.x, sbox.end.y)
		_overlay_layer.draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), Color(0.36, 0.94, 0.56, 0.14))
		_overlay_layer.draw_polyline(PackedVector2Array([p0, p1, p2, p3, p0]), Color(0.45, 1.0, 0.65, 0.92), 1.4)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_inside_tree():
		_sync_camera_transform()
