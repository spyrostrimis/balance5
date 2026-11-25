class_name RtsCarbonHud
extends CanvasLayer
## Dune II-inspired HUD frame matching docs/references/rts_mission1_hud_goal.webp:
##   - Top bar: Scales emblem + Balance, Mission 1, Orichalcum, Squad count, Hold timer,
##     and live toggles ([V] Detailed/Pixel, [Z] 21x14 / 15x10, [G] Red Guard/AI).
##   - Right sidebar: interactive Minimap, Selected-unit portrait & stats card ("Squad 4 of 4 fit"),
##     Move / Attack / Hold / Mend buttons, and bottom Objective progress panel.

signal command_button_pressed(cmd: String)
signal minimap_pan_requested(world_pos: Vector2)
signal minimap_order_requested(world_pos: Vector2)
signal toggle_requested(which: String)

const VIRTUAL_W := 960.0
const VIRTUAL_H := 540.0
const TOP_BAR_H := 34.0
const SIDEBAR_W := 212.0

var hud_visible := true:
	set(v):
		hud_visible = v
		if _panel != null:
			_panel.visible = v

var pixel_mode := false
var close_zoom := false
var red_ai_active := false
var command_cursor_mode := ""  # "", "move", "attack"

var orichalcum := 340
var blue_alive := 5
var blue_total := 5
var hold_seconds_left := 30.0
var hold_duration := 30.0
var hold_state := "Uncontested · Move in"  # "Blue Holding", "Red Holding", "Contested!", "Victory!"
var hold_owner := 0  # 0 none, 1 Blue, 2 Red

var world_size := Vector2(1408.0, 896.0)
var camera_world_rect := Rect2(0, 0, 672, 448)
var minimap_tex: Texture2D
var selected_units: Array[RtsCarbonUnit] = []
var all_units: Array[RtsCarbonUnit] = []

var _panel: Control
var _portraits_hd := {}
var _portraits_px := {}
var _minimap_dragging := false

# Virtual-space interactive button rects (computed during draw)
var _btn_rects := {}
var _minimap_rect := Rect2()


func _ready() -> void:
	layer = 10
	_panel = Control.new()
	_panel.name = "HudCanvas"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.draw.connect(_draw_hud)
	_panel.gui_input.connect(_on_panel_gui_input)
	add_child(_panel)


func load_portraits(detailed_art_directory: String) -> void:
	for key in ["blue_squad", "blue_commander", "blue_tank", "red_squad", "red_commander", "red_tank", "orichalcum"]:
		_portraits_hd[key] = RtsCarbonArt.texture("portrait_" + key, false, detailed_art_directory)
		_portraits_px[key] = RtsCarbonArt.texture("portrait_" + key, true)


func request_repaint() -> void:
	if _panel != null:
		_panel.queue_redraw()


func ui_scale() -> float:
	var vp := get_viewport().get_visible_rect().size
	return vp.y / VIRTUAL_H


## Screen-space rectangle of the playable battlefield (excluding Top Bar & Right Sidebar when HUD is shown).
func playable_screen_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	if not hud_visible:
		return Rect2(Vector2.ZERO, vp)
	var s := vp.y / VIRTUAL_H
	var top := TOP_BAR_H * s
	var right_w := SIDEBAR_W * s
	return Rect2(Vector2(0.0, top), Vector2(maxf(64.0, vp.x - right_w), maxf(64.0, vp.y - top)))


func consumes_screen_point(screen_pt: Vector2) -> bool:
	if not hud_visible:
		return false
	return not playable_screen_rect().has_point(screen_pt)


func _screen_to_virtual(screen_pt: Vector2) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var s := vp.y / VIRTUAL_H
	# Right-anchor sidebar to right window edge; top bar spans full width
	return Vector2(screen_pt.x / s, screen_pt.y / s)


func _virtual_w_actual() -> float:
	var vp := get_viewport().get_visible_rect().size
	return vp.x / ui_scale()


func _on_panel_gui_input(event: InputEvent) -> void:
	if not hud_visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not consumes_screen_point(mb.position):
			if not mb.pressed:
				_minimap_dragging = false
			return
		var vpt := _screen_to_virtual(mb.position)
		if _minimap_rect.has_point(vpt):
			var uv := ((vpt - _minimap_rect.position) / _minimap_rect.size).clamp(Vector2.ZERO, Vector2.ONE)
			var wpos := uv * world_size
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_minimap_dragging = mb.pressed
				if mb.pressed:
					minimap_pan_requested.emit(wpos)
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				minimap_order_requested.emit(wpos)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			for id_key: String in _btn_rects:
				var r: Rect2 = _btn_rects[id_key]
				if r.has_point(vpt):
					if id_key.begins_with("cmd_"):
						command_button_pressed.emit(id_key.trim_prefix("cmd_"))
					else:
						toggle_requested.emit(id_key)
					get_viewport().set_input_as_handled()
					return
			get_viewport().set_input_as_handled()
		elif not mb.pressed:
			_minimap_dragging = false
	elif event is InputEventMouseMotion and _minimap_dragging:
		var mm := event as InputEventMouseMotion
		var vpt_m := _screen_to_virtual(mm.position)
		var uv_m := ((vpt_m - _minimap_rect.position) / _minimap_rect.size).clamp(Vector2.ZERO, Vector2.ONE)
		minimap_pan_requested.emit(uv_m * world_size)
		get_viewport().set_input_as_handled()


func _draw_hud() -> void:
	if not hud_visible:
		return
	_btn_rects.clear()
	var s := ui_scale()
	var vw := _virtual_w_actual()
	var vh := VIRTUAL_H
	var font := ThemeDB.fallback_font

	_panel.draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))

	# Palette matching rts_mission1_hud_goal.webp (warm dark bronze, brass gold bevel, parchment cards)
	var bronze_dark := Color(0.19, 0.12, 0.06, 0.98)
	var bronze_mid := Color(0.31, 0.20, 0.10, 0.98)
	var gold_trim := Color(0.78, 0.58, 0.26, 1.0)
	var gold_hi := Color(0.95, 0.79, 0.44, 1.0)
	var parch_bg := Color(0.86, 0.76, 0.58, 1.0)
	var parch_dark := Color(0.72, 0.60, 0.42, 1.0)
	var ink_dark := Color(0.16, 0.10, 0.06, 1.0)
	var text_cream := Color(0.97, 0.92, 0.80, 1.0)

	# --- 1. TOP BAR ---
	var top_rect := Rect2(0.0, 0.0, vw, TOP_BAR_H)
	_panel.draw_rect(top_rect, bronze_dark)
	_panel.draw_line(Vector2(0.0, TOP_BAR_H - 1.5), Vector2(vw, TOP_BAR_H - 1.5), gold_trim, 2.0)

	# Scales of Balance emblem medallion (top-left)
	var med_c := Vector2(18.0, 17.0)
	_panel.draw_circle(med_c, 13.5, gold_trim)
	_panel.draw_circle(med_c, 11.5, Color(0.62, 0.18, 0.12))
	_panel.draw_line(med_c + Vector2(0, -7), med_c + Vector2(0, 7), gold_hi, 1.5)
	_panel.draw_line(med_c + Vector2(-6, -3), med_c + Vector2(6, -3), gold_hi, 1.4)
	_panel.draw_line(med_c + Vector2(-4, 7), med_c + Vector2(4, 7), gold_hi, 1.5)

	_panel.draw_string(font, Vector2(37.0, 23.0), "Balance", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, gold_hi)

	# Mission parchment plaque
	var plaque := Rect2(114.0, 5.0, 178.0, 24.0)
	_draw_bevel_box(plaque, parch_bg, gold_trim)
	_panel.draw_string(font, Vector2(plaque.position.x + 10.0, 21.0), "Mission 1 · The First Claim", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink_dark)

	# Resource, Squads & Hold Timer counters
	var stat_boxes := [
		{"w": 112.0, "txt": "Orichalcum  %d" % orichalcum, "dot": Color(0.98, 0.74, 0.18)},
		{"w": 92.0, "txt": "Forces  %d/%d" % [blue_alive, blue_total], "dot": Color(0.32, 0.62, 0.96)},
		{"w": 96.0, "txt": "Hold  0:%02d" % int(ceil(maxf(0.0, hold_seconds_left))), "dot": Color(0.94, 0.86, 0.62)},
	]
	var cx := 300.0
	for sb in stat_boxes:
		var bw: float = float(sb["w"])
		var r := Rect2(cx, 5.0, bw, 24.0)
		_draw_bevel_box(r, Color(0.13, 0.08, 0.04), gold_trim)
		_panel.draw_circle(Vector2(cx + 10.0, 17.0), 4.0, sb["dot"] as Color)
		_panel.draw_string(font, Vector2(cx + 19.0, 21.0), String(sb["txt"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_cream)
		cx += bw + 6.0

	# Live interactive comparison toggles on the right of the Top Bar!
	var style_txt := "[V] Pixel 960×540" if pixel_mode else "[V] Detailed Painted"
	var zoom_txt := "[Z] Close 15×10" if close_zoom else "[Z] Command 21×14"
	var ai_txt := "[G] Red: Active AI" if red_ai_active else "[G] Red: Guard"
	var right_x := vw - 6.0
	for pair in [["ai", ai_txt, 104.0], ["zoom", zoom_txt, 118.0], ["style", style_txt, 126.0]]:
		var tid: String = String(pair[0])
		var tlabel: String = String(pair[1])
		var tw_btn: float = float(pair[2])
		right_x -= tw_btn
		var tr := Rect2(right_x, 5.0, tw_btn, 24.0)
		var active_tint := Color(0.28, 0.38, 0.22) if (tid == "style" and pixel_mode) or (tid == "zoom" and close_zoom) or (tid == "ai" and red_ai_active) else bronze_mid
		_draw_bevel_box(tr, active_tint, gold_trim)
		_panel.draw_string(font, Vector2(tr.position.x + 7.0, 21.0), tlabel, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, gold_hi)
		_btn_rects[tid] = tr
		right_x -= 5.0

	# --- 2. RIGHT SIDEBAR ---
	var sx := vw - SIDEBAR_W
	var side_rect := Rect2(sx, TOP_BAR_H, SIDEBAR_W, vh - TOP_BAR_H)
	_panel.draw_rect(side_rect, bronze_mid)
	_panel.draw_line(Vector2(sx, TOP_BAR_H), Vector2(sx, vh), gold_trim, 2.2)

	# 2a. Minimap frame
	var mm_outer := Rect2(sx + 10.0, TOP_BAR_H + 8.0, SIDEBAR_W - 20.0, 126.0)
	_draw_bevel_box(mm_outer, Color(0.08, 0.05, 0.03), gold_trim)
	_minimap_rect = mm_outer.grow(-4.0)
	if minimap_tex != null:
		_panel.draw_texture_rect(minimap_tex, _minimap_rect, false)

	# Unit blips on minimap
	for u in all_units:
		if u == null or not is_instance_valid(u) or not u.alive:
			continue
		var mpos := _minimap_rect.position + (u.position / world_size) * _minimap_rect.size
		var bcol := Color(0.32, 0.68, 1.0) if u.team == RtsCarbonUnit.Team.BLUE else Color(1.0, 0.28, 0.22)
		var bsz := 3.2 if u.role == RtsCarbonUnit.Role.COMMANDER or u.role == RtsCarbonUnit.Role.TANK else 2.4
		_panel.draw_rect(Rect2(mpos - Vector2.ONE * (bsz * 0.5), Vector2.ONE * bsz), bcol)

	# Camera viewport box on minimap
	var c_min := ((camera_world_rect.position / world_size).clamp(Vector2.ZERO, Vector2.ONE)) * _minimap_rect.size
	var c_end := ((camera_world_rect.end / world_size).clamp(Vector2.ZERO, Vector2.ONE)) * _minimap_rect.size
	_panel.draw_rect(Rect2(_minimap_rect.position + c_min, (c_end - c_min).max(Vector2(8, 6))), Color(1, 1, 1, 0.92), false, 1.2)

	# 2b. Decorative faction/command tabs row (matching HUD goal, custom crisp vector icons)
	var tab_y := mm_outer.end.y + 6.0
	var tab_w := (SIDEBAR_W - 20.0 - 16.0) / 5.0
	for i in range(5):
		var tbx := Rect2(sx + 10.0 + float(i) * (tab_w + 4.0), tab_y, tab_w, 20.0)
		_draw_bevel_box(tbx, Color(0.54, 0.18, 0.12) if i == 0 else bronze_dark, gold_trim)
		_draw_tab_icon(tbx.get_center(), i, gold_hi)

	# 2c. Selected Unit Parchment Card
	var card_y := tab_y + 26.0
	var card_rect := Rect2(sx + 10.0, card_y, SIDEBAR_W - 20.0, 170.0)
	_draw_bevel_box(card_rect, parch_bg, gold_trim)

	var lead: RtsCarbonUnit = selected_units[0] if not selected_units.is_empty() else null
	var pkey := lead.portrait_key if lead != null else "orichalcum"
	var pdict := _portraits_px if pixel_mode else _portraits_hd
	var ptex: Texture2D = pdict.get(pkey) as Texture2D

	var port_rect := Rect2(card_rect.position.x + 7.0, card_rect.position.y + 10.0, 62.0, 66.0)
	_draw_bevel_box(port_rect.grow(1.5), parch_dark, ink_dark)
	if ptex != null:
		_panel.draw_texture_rect(ptex, port_rect, false)

	var info_x := port_rect.end.x + 7.0
	var max_info_w := card_rect.end.x - info_x - 5.0
	if lead != null:
		var title_str := lead.display_name if selected_units.size() == 1 else "%s +%d" % [lead.display_name, selected_units.size() - 1]
		_panel.draw_string(font, Vector2(info_x, card_rect.position.y + 21.0), title_str, HORIZONTAL_ALIGNMENT_LEFT, max_info_w, 11, ink_dark)
		_panel.draw_string(font, Vector2(info_x, card_rect.position.y + 34.0), lead.subtitle, HORIZONTAL_ALIGNMENT_LEFT, max_info_w, 9, Color(0.36, 0.24, 0.14))

		# Health bar inside card
		var hb := Rect2(info_x, card_rect.position.y + 42.0, 96.0, 8.0)
		var hp_ratio := clampf(float(lead.health) / float(maxi(lead.max_health, 1)), 0.0, 1.0)
		_panel.draw_rect(hb, Color(0.22, 0.16, 0.10))
		_panel.draw_rect(Rect2(hb.position, Vector2(hb.size.x * hp_ratio, hb.size.y)), Color(0.24, 0.66, 0.24))
		_panel.draw_string(font, Vector2(info_x, card_rect.position.y + 62.0), "Health  %d / %d" % [lead.health, lead.max_health], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink_dark)
		_panel.draw_string(font, Vector2(info_x, card_rect.position.y + 75.0), "Attack        %d" % lead.attack_damage, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink_dark)
		_panel.draw_string(font, Vector2(info_x, card_rect.position.y + 88.0), "Armour        %d" % lead.armour, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink_dark)
		_panel.draw_string(font, Vector2(info_x, card_rect.position.y + 101.0), "Range       %.1f" % lead.attack_range_cells, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink_dark)

		# Divider + Squad fit badges / Special role info
		_panel.draw_line(Vector2(card_rect.position.x + 8.0, card_rect.position.y + 112.0),
			Vector2(card_rect.end.x - 8.0, card_rect.position.y + 112.0), parch_dark, 1.2)
		if lead.role == RtsCarbonUnit.Role.SQUAD:
			var fit := lead.fit_count()
			_panel.draw_string(font, Vector2(card_rect.position.x + 10.0, card_rect.position.y + 129.0), "Squad", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink_dark)
			_panel.draw_string(font, Vector2(card_rect.position.x + 10.0, card_rect.position.y + 152.0), "%d of 4 fit" % fit, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.32, 0.22, 0.12))
			for idx in range(4):
				var badge := Rect2(card_rect.position.x + 88.0 + float(idx) * 23.0, card_rect.position.y + 132.0, 19.0, 24.0)
				var alive_slot := idx < fit
				_draw_bevel_box(badge, Color(0.24, 0.44, 0.78) if alive_slot else Color(0.45, 0.38, 0.30), ink_dark)
				_panel.draw_circle(badge.get_center() + Vector2(0, -3), 3.5, Color(0.96, 0.90, 0.76) if alive_slot else Color(0.30, 0.25, 0.20))
				_panel.draw_rect(Rect2(badge.position.x + 5.0, badge.position.y + 12.0, 9.0, 8.0), Color(0.18, 0.32, 0.62) if alive_slot else Color(0.30, 0.25, 0.20))
		elif lead.role == RtsCarbonUnit.Role.COMMANDER:
			var mend_txt := "Mend Ready [E]" if lead.mend_timer <= 0.0 else ("Mend %.1fs" % lead.mend_timer)
			_panel.draw_string(font, Vector2(card_rect.position.x + 10.0, card_rect.position.y + 131.0), "Ability · Mend (+30 HP)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink_dark)
			_panel.draw_string(font, Vector2(card_rect.position.x + 10.0, card_rect.position.y + 150.0), mend_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.10, 0.44, 0.52))
		else:
			_panel.draw_string(font, Vector2(card_rect.position.x + 10.0, card_rect.position.y + 131.0), "Armoured Tracked Chassis", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink_dark)
			_panel.draw_string(font, Vector2(card_rect.position.x + 10.0, card_rect.position.y + 150.0), "Compresses dune ripples", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.36, 0.24, 0.14))
	else:
		_panel.draw_string(font, Vector2(info_x, card_rect.position.y + 24.0), "Orichalcum Vein", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink_dark)
		_panel.draw_string(font, Vector2(info_x, card_rect.position.y + 40.0), "Central Outcrop", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.36, 0.24, 0.14))
		_panel.draw_string(font, Vector2(info_x, card_rect.position.y + 62.0), "Click or drag Blue", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink_dark)
		_panel.draw_string(font, Vector2(info_x, card_rect.position.y + 76.0), "forces to command.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink_dark)
		_panel.draw_string(font, Vector2(card_rect.position.x + 10.0, card_rect.position.y + 130.0), "Hotkeys: V Style · Z Zoom", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink_dark)
		_panel.draw_string(font, Vector2(card_rect.position.x + 10.0, card_rect.position.y + 148.0), "H HUD · 1-3 Views · R Reset", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.36, 0.24, 0.14))

	# 2d. Four Command Buttons: Move, Attack, Hold, Mend
	var cmd_y := card_rect.end.y + 7.0
	var cmd_defs := [
		["move", "↗", "Move"],
		["attack", "⚔", "Attack"],
		["hold", "🛡", "Hold"],
		["mend", "✚", "Mend"],
	]
	var cmd_w := (SIDEBAR_W - 20.0 - 12.0) / 4.0
	var any_hold := false
	var cmd_mend_ok := false
	for u in selected_units:
		if is_instance_valid(u) and u.hold_position:
			any_hold = true
		if is_instance_valid(u) and u.can_mend():
			cmd_mend_ok = true
	for i in range(4):
		var cid: String = String(cmd_defs[i][0])
		var clabel: String = String(cmd_defs[i][2])
		var cr := Rect2(sx + 10.0 + float(i) * (cmd_w + 4.0), cmd_y, cmd_w, 46.0)
		var lit := (command_cursor_mode == cid) or (cid == "hold" and any_hold)
		var btn_col := Color(0.68, 0.24, 0.16)
		if lit:
			btn_col = Color(0.84, 0.42, 0.20)
		elif cid == "mend":
			btn_col = Color(0.16, 0.48, 0.56) if cmd_mend_ok else Color(0.24, 0.22, 0.20)
		_draw_bevel_box(cr, btn_col, gold_trim)
		_draw_cmd_icon(cr.position + Vector2(cmd_w * 0.5, 16.0), cid, gold_hi if cid != "mend" else Color(0.76, 0.98, 1.0))
		_panel.draw_string(font, Vector2(cr.position.x + 4.0, cr.position.y + 40.0), clabel, HORIZONTAL_ALIGNMENT_CENTER, cmd_w - 8.0, 9, text_cream)
		_btn_rects["cmd_" + cid] = cr

	# 2e. Bottom Objective Panel ("Hold the Orichalcum rock")
	var obj_y := cmd_y + 54.0
	var obj_rect := Rect2(sx + 10.0, obj_y, SIDEBAR_W - 20.0, vh - obj_y - 8.0)
	_draw_bevel_box(obj_rect, parch_bg, gold_trim)
	_panel.draw_string(font, Vector2(obj_rect.position.x, obj_rect.position.y + 17.0), "Objective", HORIZONTAL_ALIGNMENT_CENTER, obj_rect.size.x, 11, Color(0.62, 0.14, 0.10))
	_panel.draw_string(font, Vector2(obj_rect.position.x, obj_rect.position.y + 33.0), "Hold the Orichalcum rock", HORIZONTAL_ALIGNMENT_CENTER, obj_rect.size.x, 10, ink_dark)

	var bar_r := Rect2(obj_rect.position.x + 14.0, obj_rect.position.y + 41.0, obj_rect.size.x - 28.0, 9.0)
	_panel.draw_rect(bar_r, Color(0.24, 0.16, 0.10))
	var prog := clampf(1.0 - hold_seconds_left / maxf(hold_duration, 1.0), 0.0, 1.0)
	var prog_col := Color(0.24, 0.58, 0.92) if hold_owner == 1 else (Color(0.84, 0.24, 0.18) if hold_owner == 2 else Color(0.86, 0.66, 0.20))
	_panel.draw_rect(Rect2(bar_r.position, Vector2(bar_r.size.x * maxf(0.06, prog), bar_r.size.y)), prog_col)
	_panel.draw_string(font, Vector2(obj_rect.position.x, obj_rect.position.y + 62.0), hold_state, HORIZONTAL_ALIGNMENT_CENTER, obj_rect.size.x, 9, Color(0.32, 0.20, 0.10))

	_panel.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bevel_box(r: Rect2, fill: Color, border: Color) -> void:
	_panel.draw_rect(r, fill)
	_panel.draw_rect(r, border, false, 1.3)


func _draw_tab_icon(c: Vector2, idx: int, col: Color) -> void:
	match idx:
		0:  # Crossed blades
			_panel.draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), col, 1.5)
			_panel.draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), col, 1.5)
		1:  # Crown
			_panel.draw_polyline(PackedVector2Array([c + Vector2(-5, 4), c + Vector2(-5, -3), c + Vector2(-2, 1), c + Vector2(0, -4), c + Vector2(2, 1), c + Vector2(5, -3), c + Vector2(5, 4), c + Vector2(-5, 4)]), col, 1.3)
		2:  # Fortress crenel
			_panel.draw_polyline(PackedVector2Array([c + Vector2(-5, 4), c + Vector2(-5, -3), c + Vector2(-2, -3), c + Vector2(-2, 0), c + Vector2(2, 0), c + Vector2(2, -3), c + Vector2(5, -3), c + Vector2(5, 4), c + Vector2(-5, 4)]), col, 1.3)
		3:  # Banner flag
			_panel.draw_line(c + Vector2(-3, 5), c + Vector2(-3, -5), col, 1.5)
			_panel.draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -5), c + Vector2(5, -2), c + Vector2(-3, 1)]), col)
		_:  # Gear
			_panel.draw_arc(c, 3.6, 0.0, TAU, 12, col, 1.5)


func _draw_cmd_icon(c: Vector2, cid: String, col: Color) -> void:
	match cid:
		"move":
			_panel.draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), col, 1.8)
			_panel.draw_line(c + Vector2(5, -5), c + Vector2(0, -5), col, 1.8)
			_panel.draw_line(c + Vector2(5, -5), c + Vector2(5, 0), col, 1.8)
		"attack":
			_panel.draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), col, 1.8)
			_panel.draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), col, 1.8)
		"hold":
			_panel.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-5, -5), c + Vector2(5, -5), c + Vector2(5, 1), c + Vector2(0, 6), c + Vector2(-5, 1)
			]), col)
		"mend":
			_panel.draw_rect(Rect2(c + Vector2(-1.6, -5.5), Vector2(3.2, 11.0)), col)
			_panel.draw_rect(Rect2(c + Vector2(-5.5, -1.6), Vector2(11.0, 3.2)), col)
