class_name RtsIsoHud
extends CanvasLayer
## Dune II-inspired RTS HUD for 'RTS Isometric 2— Forest Claim Carbon'.
## Features top status & live A/B layout bar, isometric-aligned minimap (left/up on minimap
## matches left/up on screen 1:1), unit card with 4-soldier fit pips, Move/Attack/Hold/Mend
## command buttons, and the central Orichalcum hold progress bar.

signal command_button_pressed(cmd: String)
signal minimap_pan_requested(map_pos: Vector2)
signal minimap_order_requested(map_pos: Vector2)
signal toggle_requested(which: String)

const VIRTUAL_H := 540.0
const TOP_BAR_H := 34.0
const SIDEBAR_W := 212.0

var hud_visible := true:
	set(v):
		hud_visible = v
		if _panel != null:
			_panel.visible = v
			request_repaint()

var layout_label := "Layout A · Shelf"
var close_zoom := false
var red_ai_active := false
var command_cursor_mode := ""

var orichalcum := 340
var blue_alive := 4
var blue_total := 4
var hold_seconds_left := 30.0
var hold_duration := 30.0
var hold_state := "Uncontested · Advance to Crystal"
var hold_owner := 0  # 0 none, 1 Blue, 2 Red

var camera_iso_rect := Rect2(-536.0, 110.0, 1072.0, 720.0)
var minimap_tex: Texture2D
var selected_units: Array[RtsIsoUnit] = []
var all_units: Array[RtsIsoUnit] = []

var _panel: Control
var _minimap_dragging := false
var _btn_rects := {}
var _minimap_rect := Rect2()


func _ready() -> void:
	layer = 12
	_panel = Control.new()
	_panel.name = "HudPanel"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.draw.connect(_draw_hud)
	_panel.gui_input.connect(_on_panel_gui_input)
	add_child(_panel)


func request_repaint() -> void:
	if _panel != null:
		_panel.queue_redraw()


func ui_scale() -> float:
	var vp := get_viewport().get_visible_rect().size
	return maxf(vp.y / VIRTUAL_H, 0.5)


func _virtual_w_actual() -> float:
	var vp := get_viewport().get_visible_rect().size
	return vp.x / ui_scale()


func _screen_to_virtual(screen_pt: Vector2) -> Vector2:
	return screen_pt / ui_scale()


func playable_screen_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	if not hud_visible:
		return Rect2(Vector2.ZERO, vp)
	var s := ui_scale()
	var top_px := TOP_BAR_H * s
	var side_px := SIDEBAR_W * s
	return Rect2(Vector2(0.0, top_px), Vector2(maxf(128.0, vp.x - side_px), maxf(128.0, vp.y - top_px)))


func consumes_screen_point(screen_pt: Vector2) -> bool:
	if not hud_visible:
		return false
	var vpt := _screen_to_virtual(screen_pt)
	var vw := _virtual_w_actual()
	return vpt.y <= TOP_BAR_H or vpt.x >= (vw - SIDEBAR_W)


func _minimap_point_to_map(vpt: Vector2) -> Vector2:
	var uv := ((vpt - _minimap_rect.position) / _minimap_rect.size).clamp(Vector2.ZERO, Vector2.ONE)
	return RtsIsoTransform.clamp_map_point(RtsIsoTransform.minimap_uv_to_map(uv), 20.0)


func _on_panel_gui_input(event: InputEvent) -> void:
	if not hud_visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var vpt := _screen_to_virtual(mb.position)
		if not consumes_screen_point(mb.position):
			if not mb.pressed:
				_minimap_dragging = false
			return

		if _minimap_rect.has_point(vpt):
			var map_pt := _minimap_point_to_map(vpt)
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_minimap_dragging = mb.pressed
				if mb.pressed:
					minimap_pan_requested.emit(map_pt)
				_panel.accept_event()
				return
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				minimap_order_requested.emit(map_pt)
				_panel.accept_event()
				return

		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			for key: String in _btn_rects.keys():
				var r: Rect2 = _btn_rects[key]
				if r.has_point(vpt):
					if key.begins_with("cmd:"):
						command_button_pressed.emit(key.trim_prefix("cmd:"))
					elif key.begins_with("tog:"):
						toggle_requested.emit(key.trim_prefix("tog:"))
					_panel.accept_event()
					return
		if not mb.pressed:
			_minimap_dragging = false
		_panel.accept_event()

	elif event is InputEventMouseMotion and _minimap_dragging:
		var mm := event as InputEventMouseMotion
		var vpt := _screen_to_virtual(mm.position)
		minimap_pan_requested.emit(_minimap_point_to_map(vpt))
		_panel.accept_event()


func _draw_hud() -> void:
	if not hud_visible:
		return
	_btn_rects.clear()
	var s := ui_scale()
	var vw := _virtual_w_actual()
	var vh := VIRTUAL_H
	var font := ThemeDB.fallback_font

	_panel.draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))

	var wood_dark := Color(0.15, 0.11, 0.08, 0.98)
	var brass_trim := Color(0.74, 0.57, 0.28, 1.0)
	var parchment := Color(0.89, 0.83, 0.69, 1.0)
	var parchment_hi := Color(0.94, 0.90, 0.79, 1.0)
	var text_dark := Color(0.16, 0.11, 0.07, 1.0)
	var text_light := Color(0.95, 0.90, 0.77, 1.0)

	# --- 1. Top Bar ---
	_panel.draw_rect(Rect2(0, 0, vw, TOP_BAR_H), wood_dark)
	_panel.draw_line(Vector2(0, TOP_BAR_H - 1.5), Vector2(vw, TOP_BAR_H - 1.5), brass_trim, 2.0)

	# Scales emblem + Balance title
	var emb_c := Vector2(18, 17)
	_panel.draw_circle(emb_c, 12.0, Color(0.58, 0.16, 0.12))
	_panel.draw_arc(emb_c, 12.0, 0.0, TAU, 24, brass_trim, 1.5)
	_panel.draw_line(emb_c + Vector2(0, -7), emb_c + Vector2(0, 7), text_light, 1.4)
	_panel.draw_line(emb_c + Vector2(-6, -3), emb_c + Vector2(6, -3), text_light, 1.3)
	_panel.draw_string(font, Vector2(36, 22), "Balance", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.96, 0.84, 0.54))

	# Mission plaque
	var plaque := Rect2(106, 5, 198, 24)
	_draw_bevel_box(plaque, parchment, brass_trim)
	_panel.draw_string(font, Vector2(114, 21), "Mission 1 · The First Claim", HORIZONTAL_ALIGNMENT_LEFT, 184, 12, text_dark)

	# Resource, Squads & Hold Timer
	var box_ori := Rect2(310, 5, 114, 24)
	_draw_bevel_box(box_ori, Color(0.11, 0.08, 0.06), brass_trim)
	_panel.draw_circle(Vector2(321, 17), 4.2, Color(0.99, 0.72, 0.18))
	_panel.draw_string(font, Vector2(330, 21), "Orichalcum %d" % orichalcum, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_light)

	var box_sq := Rect2(430, 5, 88, 24)
	_draw_bevel_box(box_sq, Color(0.11, 0.08, 0.06), brass_trim)
	_panel.draw_circle(Vector2(441, 17), 3.8, Color(0.32, 0.72, 1.0))
	_panel.draw_string(font, Vector2(450, 21), "Forces %d/%d" % [blue_alive, blue_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_light)

	var box_hold := Rect2(524, 5, 86, 24)
	var hold_col := Color(0.35, 0.85, 1.0) if hold_owner == 1 else (Color(1.0, 0.44, 0.36) if hold_owner == 2 else Color(0.95, 0.86, 0.62))
	_draw_bevel_box(box_hold, Color(0.11, 0.08, 0.06), brass_trim)
	var secs := ceili(maxf(0.0, hold_seconds_left))
	_panel.draw_string(font, Vector2(532, 21), "Hold %d:%02d" % [secs / 60, secs % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hold_col)

	# Interactive pills: Layout A/B, Zoom, Red AI
	var pill_l := Rect2(616, 5, 122, 24)
	_draw_bevel_box(pill_l, Color(0.20, 0.28, 0.20), brass_trim)
	_panel.draw_string(font, Vector2(623, 21), "[L] " + layout_label, HORIZONTAL_ALIGNMENT_LEFT, 110, 10, Color(0.88, 0.96, 0.82))
	_btn_rects["tog:layout"] = pill_l

	var pill_z := Rect2(744, 5, 102, 24)
	_draw_bevel_box(pill_z, Color(0.22, 0.17, 0.12), brass_trim)
	_panel.draw_string(font, Vector2(751, 21), "[Z] " + ("Close Zoom" if close_zoom else "Command"), HORIZONTAL_ALIGNMENT_LEFT, 90, 10, text_light)
	_btn_rects["tog:zoom"] = pill_z

	var pill_g := Rect2(852, 5, minf(102.0, maxf(68.0, vw - 858.0)), 24)
	_draw_bevel_box(pill_g, Color(0.28, 0.14, 0.12) if red_ai_active else Color(0.20, 0.16, 0.12), brass_trim)
	_panel.draw_string(font, Vector2(859, 21), "[G] " + ("Red: AI" if red_ai_active else "Red: Guard"), HORIZONTAL_ALIGNMENT_LEFT, pill_g.size.x - 10, 10, text_light)
	_btn_rects["tog:ai"] = pill_g

	# --- 2. Right Sidebar ---
	var sx := vw - SIDEBAR_W
	_panel.draw_rect(Rect2(sx, TOP_BAR_H, SIDEBAR_W, vh - TOP_BAR_H), wood_dark)
	_panel.draw_line(Vector2(sx + 1.0, TOP_BAR_H), Vector2(sx + 1.0, vh), brass_trim, 2.0)

	# Isometric Minimap frame
	var mm_outer := Rect2(sx + 10, TOP_BAR_H + 8, SIDEBAR_W - 20, 116)
	_draw_bevel_box(mm_outer, Color(0.08, 0.11, 0.13), brass_trim)
	_minimap_rect = mm_outer.grow(-4.0)
	if minimap_tex != null:
		_panel.draw_texture_rect(minimap_tex, _minimap_rect, false)
	else:
		_panel.draw_rect(_minimap_rect, Color(0.16, 0.27, 0.32))

	# Live unit blips on isometric minimap
	for u in all_units:
		if u == null or not is_instance_valid(u) or not u.alive:
			continue
		var uv := RtsIsoTransform.map_to_minimap_uv(u.map_pos)
		if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
			continue
		var mpt := _minimap_rect.position + uv * _minimap_rect.size
		var ucol := Color(0.32, 0.82, 1.0) if u.team == RtsIsoUnit.Team.BLUE else Color(1.0, 0.34, 0.28)
		var rad := 2.9 if u.role == RtsIsoUnit.Role.TANK else (2.6 if u.role == RtsIsoUnit.Role.COMMANDER else 2.2)
		_panel.draw_circle(mpt, rad, ucol)
		if u.selected:
			_panel.draw_arc(mpt, rad + 1.4, 0.0, TAU, 12, Color(1.0, 1.0, 0.85, 0.9), 1.0)

	# Horizontal camera viewport box in isometric minimap space
	var uv_tl := RtsIsoTransform.iso_to_minimap_uv(camera_iso_rect.position).clamp(Vector2.ZERO, Vector2.ONE)
	var uv_br := RtsIsoTransform.iso_to_minimap_uv(camera_iso_rect.end).clamp(Vector2.ZERO, Vector2.ONE)
	var cam_box := Rect2(_minimap_rect.position + uv_tl * _minimap_rect.size, (uv_br - uv_tl) * _minimap_rect.size)
	_panel.draw_rect(cam_box, Color(1.0, 1.0, 1.0, 0.92), false, 1.2)

	# 5 Dune II decorative category tabs
	var tab_y := mm_outer.end.y + 6.0
	var tab_w := (SIDEBAR_W - 28.0) / 5.0
	for i in range(5):
		var tr := Rect2(sx + 10.0 + float(i) * (tab_w + 2.0), tab_y, tab_w, 20.0)
		_draw_bevel_box(tr, Color(0.46, 0.18, 0.14) if i == 0 else Color(0.22, 0.16, 0.11), brass_trim)
		_draw_tab_icon(tr.get_center(), i, text_light)

	# --- 3. Selected Unit Card ---
	var card := Rect2(sx + 10, tab_y + 26, SIDEBAR_W - 20, 162)
	_draw_bevel_box(card, parchment, brass_trim)

	var lead: RtsIsoUnit = selected_units[0] if not selected_units.is_empty() else null
	var port_rect := Rect2(card.position + Vector2(8, 8), Vector2(64, 64))
	_draw_bevel_box(port_rect.grow(1.5), Color(0.20, 0.15, 0.10), Color(0.36, 0.26, 0.14))

	var pkey := lead.portrait_key if lead != null else "orichalcum"
	var ptex := RtsIsoKit.portrait(pkey)
	if ptex != null:
		_panel.draw_texture_rect(ptex, port_rect, false)

	var tx := port_rect.end.x + 8.0
	if lead != null:
		var title_str := lead.display_name
		if selected_units.size() > 1:
			title_str = "%s +%d" % [lead.display_name, selected_units.size() - 1]
		_panel.draw_string(font, Vector2(tx, card.position.y + 22), title_str, HORIZONTAL_ALIGNMENT_LEFT, 114, 11, text_dark)
		_panel.draw_string(font, Vector2(tx, card.position.y + 35), lead.subtitle, HORIZONTAL_ALIGNMENT_LEFT, 114, 10, Color(0.38, 0.28, 0.18))

		var hbar := Rect2(tx, card.position.y + 42, 104, 8)
		var hr := clampf(float(lead.health) / float(maxi(lead.max_health, 1)), 0.0, 1.0)
		_panel.draw_rect(hbar, Color(0.22, 0.18, 0.14))
		_panel.draw_rect(Rect2(hbar.position + Vector2.ONE, Vector2((hbar.size.x - 2.0) * hr, hbar.size.y - 2.0)),
			Color(0.24, 0.72, 0.30) if hr > 0.5 else Color(0.86, 0.52, 0.16))

		_panel.draw_string(font, Vector2(tx, card.position.y + 62), "Health  %d / %d" % [lead.health, lead.max_health], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_dark)
		_panel.draw_string(font, Vector2(tx, card.position.y + 75), "Attack       %d" % lead.attack_damage, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_dark)
		_panel.draw_string(font, Vector2(tx, card.position.y + 88), "Armour       %d" % lead.armour, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_dark)
		_panel.draw_string(font, Vector2(tx, card.position.y + 101), "Range       %.1f" % lead.attack_range_cells, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, text_dark)

		if lead.role == RtsIsoUnit.Role.SQUAD:
			var fit := lead.fit_count()
			_panel.draw_string(font, Vector2(card.position.x + 10, card.position.y + 125), "Squad", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_dark)
			_panel.draw_string(font, Vector2(card.position.x + 10, card.position.y + 146), "%d of 4 fit" % fit, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.34, 0.25, 0.15))
			for i in range(4):
				var pip := Rect2(card.position.x + 86 + float(i) * 24.0, card.position.y + 128, 20, 22)
				var active := i < fit
				_draw_bevel_box(pip, Color(0.24, 0.44, 0.68) if active else Color(0.55, 0.50, 0.42), Color(0.28, 0.20, 0.12))
				_panel.draw_circle(pip.get_center() + Vector2(0, -3), 3.2, Color(0.95, 0.88, 0.76) if active else Color(0.40, 0.36, 0.32))
				_panel.draw_rect(Rect2(pip.get_center() + Vector2(-4, 1), Vector2(8, 7)), Color(0.18, 0.56, 0.92) if active else Color(0.42, 0.38, 0.34))
		elif lead.role == RtsIsoUnit.Role.COMMANDER:
			_panel.draw_string(font, Vector2(card.position.x + 10, card.position.y + 126), "Ability · Mend (+30 HP)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_dark)
			var mstatus := "Mend Ready [E]" if lead.mend_timer <= 0.0 else ("Cooldown %.1fs" % lead.mend_timer)
			_panel.draw_string(font, Vector2(card.position.x + 10, card.position.y + 145), mstatus, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.12, 0.46, 0.56))
		else:
			_panel.draw_string(font, Vector2(card.position.x + 10, card.position.y + 126), "Tracked Armour · Dual Turret", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_dark)
			_panel.draw_string(font, Vector2(card.position.x + 10, card.position.y + 145), "Blocks on trunks & cliffs", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.34, 0.25, 0.15))
	else:
		_panel.draw_string(font, Vector2(tx, card.position.y + 22), "Orichalcum Vein", HORIZONTAL_ALIGNMENT_LEFT, 108, 12, text_dark)
		_panel.draw_string(font, Vector2(tx, card.position.y + 36), "Forest Shelf Claim", HORIZONTAL_ALIGNMENT_LEFT, 108, 10, Color(0.38, 0.28, 0.18))
		_panel.draw_string(font, Vector2(card.position.x + 10, card.position.y + 98), "Drag-select Blue forces.", HORIZONTAL_ALIGNMENT_LEFT, 174, 10, text_dark)
		_panel.draw_string(font, Vector2(card.position.x + 10, card.position.y + 114), "Right-click shelf or minimap.", HORIZONTAL_ALIGNMENT_LEFT, 174, 10, text_dark)
		_panel.draw_string(font, Vector2(card.position.x + 10, card.position.y + 130), "Press L to swap Layout A / B.", HORIZONTAL_ALIGNMENT_LEFT, 174, 10, Color(0.16, 0.42, 0.22))

	# --- 4. Four Command Buttons: Move, Attack, Hold, Mend ---
	var cmd_y := card.end.y + 7.0
	var cmd_w := (SIDEBAR_W - 29.0) / 4.0
	var cmds := [
		{"id": "move", "label": "Move"},
		{"id": "attack", "label": "Attack"},
		{"id": "hold", "label": "Hold"},
		{"id": "mend", "label": "Mend"},
	]
	var any_mend_ready := false
	var any_holding := false
	for u in selected_units:
		if u.can_mend() and u.mend_timer <= 0.0:
			any_mend_ready = true
		if u.hold_position:
			any_holding = true

	for i in range(4):
		var cinfo: Dictionary = cmds[i]
		var cid: String = cinfo["id"]
		var cr := Rect2(sx + 10.0 + float(i) * (cmd_w + 3.0), cmd_y, cmd_w, 46.0)
		var bg := Color(0.58, 0.20, 0.15)
		if (cid == "move" and command_cursor_mode == "move") or (cid == "attack" and command_cursor_mode == "attack"):
			bg = Color(0.78, 0.34, 0.18)
		elif cid == "hold" and any_holding:
			bg = Color(0.68, 0.48, 0.16)
		elif cid == "mend":
			bg = Color(0.16, 0.48, 0.62) if any_mend_ready else Color(0.28, 0.25, 0.22)
		_draw_bevel_box(cr, bg, brass_trim)
		_draw_cmd_icon(cr.position + Vector2(cr.size.x * 0.5, 17.0), cid, text_light)
		_panel.draw_string(font, Vector2(cr.position.x, cr.position.y + 39), String(cinfo["label"]), HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 10, text_light)
		_btn_rects["cmd:" + cid] = cr

	# --- 5. Bottom Objective Panel ---
	var obj_y := cmd_y + 53.0
	var obj := Rect2(sx + 10.0, obj_y, SIDEBAR_W - 20.0, maxf(68.0, vh - obj_y - 8.0))
	_draw_bevel_box(obj, parchment_hi, brass_trim)
	_panel.draw_string(font, Vector2(obj.position.x, obj.position.y + 17), "Objective", HORIZONTAL_ALIGNMENT_CENTER, obj.size.x, 12, Color(0.62, 0.16, 0.12))
	_panel.draw_string(font, Vector2(obj.position.x, obj.position.y + 33), "Hold the Orichalcum rock", HORIZONTAL_ALIGNMENT_CENTER, obj.size.x, 11, text_dark)

	var pbar := Rect2(obj.position.x + 14.0, obj.position.y + 41.0, obj.size.x - 28.0, 10.0)
	_panel.draw_rect(pbar, Color(0.22, 0.16, 0.12))
	var prog := clampf(1.0 - hold_seconds_left / maxf(hold_duration, 1.0), 0.0, 1.0)
	var pcol := Color(0.22, 0.62, 0.92) if hold_owner == 1 else (Color(0.84, 0.24, 0.18) if hold_owner == 2 else Color(0.82, 0.64, 0.20))
	_panel.draw_rect(Rect2(pbar.position + Vector2.ONE, Vector2((pbar.size.x - 2.0) * maxf(prog, 0.06), pbar.size.y - 2.0)), pcol)
	_panel.draw_string(font, Vector2(obj.position.x, obj.position.y + 63), hold_state, HORIZONTAL_ALIGNMENT_CENTER, obj.size.x, 9, Color(0.36, 0.26, 0.16))

	_panel.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bevel_box(r: Rect2, fill: Color, border: Color) -> void:
	_panel.draw_rect(r, fill)
	_panel.draw_rect(r, border, false, 1.3)


func _draw_tab_icon(c: Vector2, idx: int, col: Color) -> void:
	match idx:
		0:
			_panel.draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), col, 1.4)
			_panel.draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), col, 1.4)
		1:
			_panel.draw_polyline(PackedVector2Array([c + Vector2(-5, 3), c + Vector2(-4, -3), c, c + Vector2(4, -3), c + Vector2(5, 3), c + Vector2(-5, 3)]), col, 1.3)
		2:
			_panel.draw_rect(Rect2(c - Vector2(4, 3), Vector2(8, 6)), col, false, 1.3)
		3:
			_panel.draw_line(c + Vector2(-3, 5), c + Vector2(-3, -4), col, 1.3)
			_panel.draw_rect(Rect2(c + Vector2(-3, -4), Vector2(6, 4)), col)
		4:
			_panel.draw_arc(c, 3.8, 0.0, TAU, 12, col, 1.3)


func _draw_cmd_icon(c: Vector2, cid: String, col: Color) -> void:
	match cid:
		"move":
			_panel.draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), col, 1.8)
			_panel.draw_line(c + Vector2(1, -5), c + Vector2(5, -5), col, 1.8)
			_panel.draw_line(c + Vector2(5, -1), c + Vector2(5, -5), col, 1.8)
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
