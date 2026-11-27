class_name RtsMissionHud
extends RtsCarbonHud
## Switchable HUD styles for Mission 1, from the owner's ChatGPT mockups
## (assets/source_inputs/hud/hud_E_classic.png and hud_B_holo.png):
##   "classic"      Dune II remastered: steel-and-bronze top bar and right sidebar, portrait on top,
##                  2×2 enamel command buttons, parchment objective, minimap at the bottom.
##   "holo"         Holo-glass field tablet: no sidebar; floating chamfered glass panels (status strip and
##                  objective at the top, minimap bottom-left, unit card bottom-centre, commands bottom-right).
##   "mockup_e"     The mockup itself: its painted chrome (cut by tools/python/make_hud_mockup_e.py) with
##                  names, numbers, bars, status and minimap drawn live on top.
##   "placeholder"  The original Carbon HUD, for comparison.
## U cycles styles in play. Every style keeps the same battlefield scale (see framing_width()).
## Drawing happens in Carbon's 960×540 virtual space, so clicks, minimap orders and toggles reuse
## RtsCarbonHud's input code.

const STYLES := ["mockup_e", "classic", "holo", "placeholder"]
const STYLE_LABELS := {"mockup_e": "Mockup E", "classic": "Classic", "holo": "Holo", "placeholder": "Carbon"}
const MOCK_DIR := "res://assets/textures/ui/hud_mockup_e/"
const MOCK_K := 960.0 / 1672.0  # mockup pixels -> HUD virtual units
const MOCK_SIDE_W := (1672.0 - 1262.0) * MOCK_K
const MOCK_TOP_H := 62.0 * MOCK_K
const SIDE_W := 212.0  # same as Carbon so Command framing stays 21 cells wide

var style := "mockup_e":
	set(v):
		style = v if v in STYLES else "classic"
		request_repaint()

var _fonts := {}
var _holo_hit: Array[Rect2] = []


## Width (in screen pixels) the camera uses to set its zoom. Equal for all styles, so units keep
## the same on-screen size; the holo style simply shows more battlefield around them.
func framing_width() -> float:
	var vp := get_viewport().get_visible_rect().size
	return vp.x - SIDE_W * (vp.y / VIRTUAL_H) if hud_visible else vp.x


func playable_screen_rect() -> Rect2:
	if style == "placeholder":
		return super.playable_screen_rect()
	var vp := get_viewport().get_visible_rect().size
	if not hud_visible or style == "holo":
		return Rect2(Vector2.ZERO, vp)
	var s := vp.y / VIRTUAL_H
	var top := MOCK_TOP_H if style == "mockup_e" else TOP_BAR_H
	var side := MOCK_SIDE_W if style == "mockup_e" else SIDE_W
	return Rect2(Vector2(0.0, top * s), Vector2(maxf(64.0, vp.x - side * s), maxf(64.0, vp.y - top * s)))


func consumes_screen_point(screen_pt: Vector2) -> bool:
	if not hud_visible:
		return false
	if style != "holo":
		return not playable_screen_rect().has_point(screen_pt)
	var v := screen_pt / ui_scale()
	for r in _holo_hit:
		if r.has_point(v):
			return true
	return false


func _draw_hud() -> void:
	if not hud_visible:
		return
	match style:
		"holo":
			_draw_holo()
		"classic":
			_draw_classic()
		"mockup_e":
			_draw_mockup_e()
		_:
			super._draw_hud()


# --- Shared helpers -------------------------------------------------------------------------------

func _font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f := SystemFont.new()
	match kind:
		"classic_bold":
			f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
			f.font_weight = 700
			f.font_stretch = 85
		"classic":
			f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
			f.font_weight = 500
		"holo_bold":
			f.font_names = PackedStringArray(["Segoe UI", "Bahnschrift", "Arial"])
			f.font_weight = 600
		_:
			f.font_names = PackedStringArray(["Segoe UI", "Bahnschrift", "Arial"])
			f.font_weight = 400
	f.multichannel_signed_distance_field = true
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_fonts[kind] = f
	return f


func _text(pos: Vector2, txt: String, size: int, col: Color, kind := "classic", align := HORIZONTAL_ALIGNMENT_LEFT,
		width := -1.0, outline := 0, outline_col := Color(0, 0, 0, 0.85)) -> void:
	var f := _font(kind)
	if outline > 0:
		_panel.draw_string_outline(f, pos, txt, align, width, size, outline, outline_col)
	_panel.draw_string(f, pos, txt, align, width, size, col)


func _lead() -> RtsCarbonUnit:
	for u in selected_units:
		if is_instance_valid(u) and u.alive:
			return u
	return null


func _portrait(key: String) -> Texture2D:
	var d := _portraits_px if pixel_mode else _portraits_hd
	return d.get(key) as Texture2D


func _ready_commander() -> RtsCarbonUnit:
	for u in all_units:
		if is_instance_valid(u) and u.alive and u.team == RtsCarbonUnit.Team.BLUE and u.role == RtsCarbonUnit.Role.COMMANDER:
			return u
	return null


## Mend is cast by the Blue commander whatever is selected, so the button shows her state.
func _mend_state() -> Array:
	var c := _ready_commander()
	if c == null:
		return [false, "No commander"]
	if c.can_mend():
		return [true, "Ready"]
	return [false, "%.0fs" % maxf(c.mend_timer, 0.0)]


func _hold_progress() -> float:
	return clampf(1.0 - hold_seconds_left / maxf(hold_duration, 1.0), 0.0, 1.0)


func _hold_colour() -> Color:
	return Color(0.30, 0.62, 1.0) if hold_owner == 1 else (Color(0.92, 0.28, 0.22) if hold_owner == 2 else Color(0.98, 0.76, 0.22))


func _toggle_defs() -> Array:
	return [
		["style", "V · Pixel" if pixel_mode else "V · HD"],
		["zoom", "Z · Close" if close_zoom else "Z · Command"],
		["ai", "G · Red AI" if red_ai_active else "G · Guard"],
		["hud", "U · " + String(STYLE_LABELS[style])],
	]


func _draw_minimap_content(r: Rect2) -> void:
	_minimap_rect = r
	if minimap_tex != null:
		_panel.draw_texture_rect(minimap_tex, r, false)
	for u in all_units:
		if u == null or not is_instance_valid(u) or not u.alive:
			continue
		var mpos := r.position + _minimap_uv(minimap_projection * u.position) * r.size
		var bcol := Color(0.36, 0.70, 1.0) if u.team == RtsCarbonUnit.Team.BLUE else Color(1.0, 0.30, 0.24)
		var bsz := 3.4 if u.role != RtsCarbonUnit.Role.SQUAD else 2.6
		_panel.draw_rect(Rect2(mpos - Vector2.ONE * bsz * 0.5, Vector2.ONE * bsz), bcol)
	var c_min := _minimap_uv(camera_world_rect.position).clamp(Vector2.ZERO, Vector2.ONE) * r.size
	var c_end := _minimap_uv(camera_world_rect.end).clamp(Vector2.ZERO, Vector2.ONE) * r.size
	_panel.draw_rect(Rect2(r.position + c_min, (c_end - c_min).max(Vector2(8, 6))), Color(1, 1, 1, 0.95), false, 1.1)


func _icon(c: Vector2, id: String, col: Color, k := 1.0) -> void:
	var w := 1.7 * k
	match id:
		"move":
			_panel.draw_polyline(PackedVector2Array([c + Vector2(-6, 5) * k, c + Vector2(-2, -1) * k, c + Vector2(5, -4) * k]), col, w, true)
			_panel.draw_colored_polygon(PackedVector2Array([c + Vector2(7, -5) * k, c + Vector2(2, -7) * k, c + Vector2(3, -1) * k]), col)
		"attack":
			_panel.draw_line(c + Vector2(-6, 6) * k, c + Vector2(6, -6) * k, col, w, true)
			_panel.draw_line(c + Vector2(-6, -6) * k, c + Vector2(6, 6) * k, col, w, true)
			_panel.draw_line(c + Vector2(-7, 3) * k, c + Vector2(-3, 7) * k, col, w, true)
			_panel.draw_line(c + Vector2(7, 3) * k, c + Vector2(3, 7) * k, col, w, true)
		"hold":
			var shield := PackedVector2Array([c + Vector2(-6, -6) * k, c + Vector2(6, -6) * k, c + Vector2(6, 0) * k,
				c + Vector2(0, 7) * k, c + Vector2(-6, 0) * k, c + Vector2(-6, -6) * k])
			_panel.draw_polyline(shield, col, w, true)
		"mend":
			_panel.draw_rect(Rect2(c + Vector2(-1.8, -6) * k, Vector2(3.6, 12) * k), col)
			_panel.draw_rect(Rect2(c + Vector2(-6, -1.8) * k, Vector2(12, 3.6) * k), col)
		"gem":
			_panel.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7) * k, c + Vector2(6, -1) * k, c + Vector2(0, 7) * k, c + Vector2(-6, -1) * k]), col)
			_panel.draw_line(c + Vector2(-6, -1) * k, c + Vector2(6, -1) * k, col.darkened(0.45), 1.0)
			_panel.draw_line(c + Vector2(0, -7) * k, c + Vector2(0, 7) * k, col.lightened(0.35), 1.0)
		"forces":
			_panel.draw_circle(c + Vector2(-3, -3) * k, 2.6 * k, col)
			_panel.draw_circle(c + Vector2(3, -3) * k, 2.6 * k, col)
			_panel.draw_colored_polygon(PackedVector2Array([c + Vector2(-7, 6) * k, c + Vector2(-6, 1) * k, c + Vector2(0, 0) * k, c + Vector2(6, 1) * k, c + Vector2(7, 6) * k]), col)
		"clock":
			_panel.draw_arc(c, 6.0 * k, 0.0, TAU, 24, col, w, true)
			_panel.draw_line(c, c + Vector2(0, -4) * k, col, w, true)
			_panel.draw_line(c, c + Vector2(3, 0) * k, col, w, true)
		"range":
			_panel.draw_arc(c, 5.0 * k, 0.0, TAU, 20, col, 1.2 * k, true)
			_panel.draw_line(c + Vector2(-7, 0) * k, c + Vector2(7, 0) * k, col, 1.2 * k, true)
			_panel.draw_line(c + Vector2(0, -7) * k, c + Vector2(0, 7) * k, col, 1.2 * k, true)


# --- Classic: Dune II remastered ------------------------------------------------------------------

const C_STEEL_DARK := Color(0.10, 0.11, 0.12)
const C_STEEL := Color(0.19, 0.20, 0.21)
const C_STEEL_HI := Color(0.36, 0.37, 0.38)
const C_BRONZE := Color(0.52, 0.36, 0.17)
const C_GOLD := Color(0.90, 0.70, 0.32)
const C_GOLD_HI := Color(1.0, 0.86, 0.46)
const C_SAND := Color(0.73, 0.56, 0.34)
const C_SAND_HI := Color(0.88, 0.72, 0.48)
const C_ENAMEL := Color(0.09, 0.22, 0.50)
const C_ENAMEL_HI := Color(0.20, 0.42, 0.80)
const C_PARCH := Color(0.90, 0.82, 0.64)
const C_INK := Color(0.14, 0.09, 0.05)
const C_CREAM := Color(0.97, 0.93, 0.84)


func _bevel(r: Rect2, fill: Color, light: Color, dark: Color, w := 2.0) -> void:
	_panel.draw_rect(r, fill)
	_panel.draw_line(r.position, Vector2(r.end.x, r.position.y), light, w)
	_panel.draw_line(r.position, Vector2(r.position.x, r.end.y), light, w)
	_panel.draw_line(Vector2(r.position.x, r.end.y), r.end, dark, w)
	_panel.draw_line(Vector2(r.end.x, r.position.y), r.end, dark, w)
	_panel.draw_rect(r.grow(0.5), Color(0, 0, 0, 0.55), false, 1.0)


func _framed(r: Rect2, fill: Color) -> void:
	_panel.draw_rect(r.grow(2.0), C_BRONZE)
	_panel.draw_rect(r.grow(2.0), Color(0, 0, 0, 0.6), false, 1.0)
	_panel.draw_rect(r.grow(1.0), C_GOLD, false, 1.0)
	_panel.draw_rect(r, fill)


func _rivet(c: Vector2) -> void:
	_panel.draw_circle(c, 2.2, C_BRONZE.darkened(0.3))
	_panel.draw_circle(c + Vector2(-0.5, -0.5), 1.3, C_GOLD_HI)


func _draw_classic() -> void:
	_btn_rects.clear()
	var s := ui_scale()
	var vw := _virtual_w_actual()
	var vh := VIRTUAL_H
	_panel.draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))

	# Top bar: sandstone with steel inset counters.
	var bar := Rect2(0, 0, vw, TOP_BAR_H)
	_panel.draw_rect(bar, C_SAND)
	_panel.draw_rect(Rect2(0, 0, vw, 3), C_SAND_HI)
	_panel.draw_rect(Rect2(0, TOP_BAR_H - 4, vw, 4), C_BRONZE)
	_panel.draw_line(Vector2(0, TOP_BAR_H), Vector2(vw, TOP_BAR_H), Color(0, 0, 0, 0.7), 1.0)
	for gx in [4.0, 264.0]:
		for i in 3:
			_panel.draw_line(Vector2(gx + i * 3.0, 9), Vector2(gx + i * 3.0, 25), C_BRONZE.darkened(0.3), 1.0)

	var plaque := Rect2(16, 5, 240, 24)
	_bevel(plaque, C_SAND_HI, Color(1, 0.92, 0.74), C_BRONZE)
	_text(Vector2(plaque.position.x, 23), mission_title, 15, C_INK, "classic_bold", HORIZONTAL_ALIGNMENT_CENTER, plaque.size.x)

	var counters := [
		["gem", "Orichalcum", str(orichalcum), Color(0.98, 0.70, 0.20), 150.0],
		["forces", "Forces", "%d/%d" % [blue_alive, blue_total], Color(0.38, 0.64, 1.0), 116.0],
		["clock", "Hold", "0:%02d" % int(ceil(maxf(0.0, hold_seconds_left))), C_GOLD_HI, 112.0],
	]
	var cx := 274.0
	for c in counters:
		var w: float = c[4]
		var r := Rect2(cx, 5, w, 24)
		_bevel(r, C_STEEL_DARK, C_STEEL, Color(0, 0, 0), 1.5)
		_panel.draw_rect(r, C_GOLD, false, 1.0)
		_icon(Vector2(cx + 13, 17), c[0], c[3], 0.95)
		_text(Vector2(cx + 25, 22.5), c[1], 12, C_CREAM, "classic")
		_text(Vector2(r.end.x - 8 - 44, 23), c[2], 15, C_GOLD_HI, "classic_bold", HORIZONTAL_ALIGNMENT_RIGHT, 44)
		cx += w + 6.0

	var tx := vw - 6.0
	var defs := _toggle_defs()
	defs.reverse()
	for d in defs:
		var tw := 66.0
		tx -= tw
		var tr := Rect2(tx, 7, tw, 20)
		var on: bool = (d[0] == "style" and pixel_mode) or (d[0] == "zoom" and close_zoom) or (d[0] == "ai" and red_ai_active)
		_bevel(tr, C_ENAMEL if d[0] == "hud" else (Color(0.24, 0.34, 0.18) if on else C_STEEL), C_STEEL_HI, Color(0, 0, 0), 1.0)
		_text(Vector2(tr.position.x, 21.5), d[1], 10, C_CREAM, "classic", HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
		_btn_rects[d[0]] = tr
		tx -= 4.0

	# Right sidebar.
	var sx := vw - SIDE_W
	var side := Rect2(sx, TOP_BAR_H, SIDE_W, vh - TOP_BAR_H)
	_panel.draw_rect(side, C_STEEL)
	_panel.draw_rect(Rect2(sx, TOP_BAR_H, 5, side.size.y), C_BRONZE)
	_panel.draw_line(Vector2(sx + 5, TOP_BAR_H), Vector2(sx + 5, vh), C_GOLD, 1.0)
	_panel.draw_line(Vector2(sx, TOP_BAR_H), Vector2(sx, vh), Color(0, 0, 0, 0.8), 1.0)
	var x0 := sx + 13.0
	var iw := SIDE_W - 21.0

	# 1. Unit card.
	var card := Rect2(x0, TOP_BAR_H + 8, iw, 116)
	_framed(card, C_STEEL_DARK)
	var lead := _lead()
	var port := Rect2(card.position.x + 5, card.position.y + 5, 74, 106)
	_panel.draw_rect(port, C_ENAMEL)
	var ptex := _portrait(lead.portrait_key if lead != null else "orichalcum")
	if ptex != null:
		_panel.draw_texture_rect(ptex, Rect2(port.position.x, port.position.y + (port.size.y - port.size.x) * 0.5, port.size.x, port.size.x), false)
	_panel.draw_rect(port, C_GOLD, false, 1.5)
	var ix := port.end.x + 7
	var info_w := card.end.x - ix - 5
	if lead != null:
		var title := lead.display_name if selected_units.size() <= 1 else "%s +%d" % [lead.display_name, selected_units.size() - 1]
		_text(Vector2(ix, card.position.y + 18), title, 13, C_CREAM, "classic_bold", HORIZONTAL_ALIGNMENT_LEFT, info_w)
		var hb := Rect2(ix, card.position.y + 24, info_w, 14)
		var hp := clampf(float(lead.health) / float(maxi(lead.max_health, 1)), 0.0, 1.0)
		_panel.draw_rect(hb, Color(0.05, 0.05, 0.05))
		_panel.draw_rect(Rect2(hb.position, Vector2(hb.size.x * hp, hb.size.y)), Color(0.20, 0.72, 0.24) if hp > 0.35 else Color(0.86, 0.30, 0.18))
		_panel.draw_rect(hb, C_GOLD, false, 1.0)
		_text(Vector2(hb.position.x, hb.end.y - 2.5), "%d / %d" % [lead.health, lead.max_health], 12, Color.WHITE, "classic", HORIZONTAL_ALIGNMENT_CENTER, hb.size.x, 2, Color(0.02, 0.18, 0.04, 0.9))
		var rows := [["attack", "Attack", str(lead.attack_damage)], ["hold", "Armour", str(lead.armour)], ["range", "Range", "%.1f" % lead.attack_range_cells]]
		for i in rows.size():
			var ry := card.position.y + 60 + i * 19.0
			_panel.draw_line(Vector2(ix, ry + 5), Vector2(card.end.x - 5, ry + 5), Color(1, 1, 1, 0.08), 1.0)
			_icon(Vector2(ix + 6, ry - 4), rows[i][0], Color(0.80, 0.82, 0.84), 0.62)
			_text(Vector2(ix + 15, ry), rows[i][1], 12, C_CREAM, "classic")
			_text(Vector2(ix, ry), rows[i][2], 13, C_GOLD_HI, "classic_bold", HORIZONTAL_ALIGNMENT_RIGHT, info_w)
	else:
		_text(Vector2(ix, card.position.y + 20), "Orichalcum Vein", 13, C_CREAM, "classic_bold")
		_text(Vector2(ix, card.position.y + 38), "Central outcrop", 11, C_GOLD, "classic")
		_text(Vector2(ix, card.position.y + 62), "Click or drag", 11, C_CREAM, "classic")
		_text(Vector2(ix, card.position.y + 77), "Blue forces to", 11, C_CREAM, "classic")
		_text(Vector2(ix, card.position.y + 92), "command them.", 11, C_CREAM, "classic")

	# 2. Ability / squad strip.
	var strip := Rect2(x0, card.end.y + 8, iw, 30)
	_framed(strip, C_STEEL_DARK)
	if lead != null and lead.role == RtsCarbonUnit.Role.SQUAD:
		var fit := lead.fit_count()
		_text(Vector2(strip.position.x + 8, strip.position.y + 19), "Squad  %d of 4 fit" % fit, 12, C_CREAM, "classic_bold")
		for i in 4:
			var pr := Rect2(strip.end.x - 76 + i * 17.0, strip.position.y + 6, 13, 16)
			_panel.draw_rect(pr, C_ENAMEL_HI if i < fit else Color(0.28, 0.26, 0.24))
			_panel.draw_rect(pr, C_GOLD, false, 1.0)
	elif lead != null and lead.role == RtsCarbonUnit.Role.TANK:
		_text(Vector2(strip.position.x + 8, strip.position.y + 19), "Tracked chassis · crushes dunes", 11, C_CREAM, "classic")
	else:
		var mend := _mend_state()
		var ic := Vector2(strip.position.x + 14, strip.get_center().y)
		_panel.draw_circle(ic, 9.5, C_ENAMEL_HI)
		_panel.draw_arc(ic, 9.5, 0, TAU, 20, C_GOLD, 1.0, true)
		_icon(ic, "mend", Color(0.70, 0.95, 1.0), 0.75)
		_text(Vector2(strip.position.x + 30, strip.position.y + 19), "Mend +30 HP", 12, C_CREAM, "classic_bold")
		var badge := Rect2(strip.end.x - 58, strip.position.y + 5, 52, 18)
		_panel.draw_rect(badge, Color(0.10, 0.36, 0.14) if mend[0] else Color(0.25, 0.22, 0.20))
		_panel.draw_rect(badge, Color(0.40, 0.95, 0.40) if mend[0] else C_STEEL_HI, false, 1.0)
		_text(Vector2(badge.position.x, badge.end.y - 4.5), String(mend[1]).to_upper(), 11, Color(0.55, 1.0, 0.55) if mend[0] else C_CREAM, "classic_bold", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x)

	# 3. Commands 2×2.
	var any_hold := false
	for u in selected_units:
		if is_instance_valid(u) and u.hold_position:
			any_hold = true
	var mend_ok: bool = _mend_state()[0]
	var cmds := [["move", "MOVE"], ["attack", "ATTACK"], ["hold", "HOLD"], ["mend", "MEND"]]
	var bw := (iw - 6.0) * 0.5
	var by := strip.end.y + 9
	for i in 4:
		var r := Rect2(x0 + (i % 2) * (bw + 6.0), by + (i / 2) * 46.0, bw, 40)
		var id: String = cmds[i][0]
		var lit := command_cursor_mode == id or (id == "hold" and any_hold)
		var fill := C_ENAMEL
		if lit:
			fill = Color(0.62, 0.38, 0.10)
		elif id == "mend" and not mend_ok:
			fill = Color(0.20, 0.21, 0.23)
		_bevel(r, fill, fill.lightened(0.35), Color(0, 0, 0), 2.0)
		_panel.draw_rect(r.grow(1.0), C_GOLD if not lit else C_GOLD_HI, false, 1.0)
		_icon(Vector2(r.position.x + 17, r.get_center().y), id, C_GOLD_HI if id != "mend" else Color(0.70, 0.95, 1.0), 1.0)
		_text(Vector2(r.position.x + 30, r.position.y + 26), cmds[i][1], 15, C_CREAM, "classic_bold", HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 34, 2, Color(0, 0, 0, 0.6))
		_btn_rects["cmd_" + id] = r

	# 4. Objective (parchment).
	var obj := Rect2(x0, by + 98, iw, 74)
	_framed(obj, C_PARCH)
	_text(Vector2(obj.position.x, obj.position.y + 19), "Hold the Orichalcum rock", 13, C_INK, "classic_bold", HORIZONTAL_ALIGNMENT_CENTER, obj.size.x)
	var bar_r := Rect2(obj.position.x + 10, obj.position.y + 27, obj.size.x - 20, 13)
	_panel.draw_rect(bar_r, Color(0.16, 0.11, 0.07))
	_panel.draw_rect(Rect2(bar_r.position, Vector2(bar_r.size.x * maxf(0.04, _hold_progress()), bar_r.size.y)), _hold_colour())
	_panel.draw_rect(bar_r, C_BRONZE, false, 1.0)
	_text(Vector2(obj.position.x, obj.position.y + 63), hold_state, 12, C_INK, "classic_bold", HORIZONTAL_ALIGNMENT_CENTER, obj.size.x)

	# 5. Minimap at the bottom (as in Dune II).
	var mm_h := iw * (world_size.y / world_size.x)
	var mm_frame := Rect2(x0, vh - 10 - mm_h - 10, iw, mm_h + 10)
	_framed(mm_frame, Color(0.05, 0.04, 0.03))
	_draw_minimap_content(mm_frame.grow(-5))
	for p in [Vector2(sx + 9, TOP_BAR_H + 4), Vector2(vw - 5, TOP_BAR_H + 4), Vector2(sx + 9, vh - 4), Vector2(vw - 5, vh - 4)]:
		_rivet(p)

	_panel.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Holo: field-tablet glass ---------------------------------------------------------------------

const H_GLASS := Color(0.025, 0.06, 0.075, 0.80)
const H_GLASS_HI := Color(0.06, 0.13, 0.15, 0.88)
const H_LINE := Color(0.42, 0.92, 0.96, 0.95)
const H_LINE_DIM := Color(0.42, 0.92, 0.96, 0.32)
const H_AMBER := Color(1.0, 0.72, 0.26)
const H_TEXT := Color(0.93, 0.98, 1.0)
const H_TEXT_DIM := Color(0.62, 0.80, 0.84)


func _chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(cut, 0), Vector2(r.end.x - cut, r.position.y), Vector2(r.end.x, r.position.y + cut),
		Vector2(r.end.x, r.end.y - cut), Vector2(r.end.x - cut, r.end.y), Vector2(r.position.x + cut, r.end.y),
		Vector2(r.position.x, r.end.y - cut), Vector2(r.position.x, r.position.y + cut), r.position + Vector2(cut, 0)])


func _glass(r: Rect2, cut := 7.0, line := H_LINE, fill := H_GLASS, hit := true) -> void:
	var pts := _chamfer(r, cut)
	_panel.draw_colored_polygon(pts, fill)
	_panel.draw_polyline(pts, Color(line.r, line.g, line.b, 0.10), 5.0, true)
	_panel.draw_polyline(pts, line, 1.1, true)
	var inner := _chamfer(r.grow(-3.0), maxf(cut - 2.0, 1.0))
	_panel.draw_polyline(inner, Color(line.r, line.g, line.b, 0.18), 1.0, true)
	if hit:
		_holo_hit.append(r)


func _draw_holo() -> void:
	_btn_rects.clear()
	_holo_hit.clear()
	var s := ui_scale()
	var vw := _virtual_w_actual()
	var vh := VIRTUAL_H
	_panel.draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))

	# Status strip (top centre) with angled wings.
	var strip := Rect2(vw * 0.5 - 205, 3, 410, 26)
	_panel.draw_line(Vector2(strip.position.x - 120, 4), Vector2(strip.position.x - 6, 4), H_LINE_DIM, 1.0)
	_panel.draw_line(Vector2(strip.end.x + 6, 4), Vector2(strip.end.x + 120, 4), H_LINE_DIM, 1.0)
	_glass(strip, 9.0)
	var cells := [
		["gem", "Orichalcum", str(orichalcum), H_AMBER],
		["forces", "Forces", "%d/%d" % [blue_alive, blue_total], Color(0.45, 0.72, 1.0)],
		["clock", "Hold", "0:%02d" % int(ceil(maxf(0.0, hold_seconds_left))), H_TEXT],
	]
	var cw := strip.size.x / 3.0
	for i in 3:
		var x := strip.position.x + i * cw
		if i > 0:
			_panel.draw_line(Vector2(x, strip.position.y + 5), Vector2(x, strip.end.y - 5), H_LINE_DIM, 1.0)
		_icon(Vector2(x + 18, strip.get_center().y), cells[i][0], cells[i][3], 0.85)
		_text(Vector2(x + 30, strip.position.y + 18), "%s  %s" % [cells[i][1], cells[i][2]], 13, H_TEXT, "holo")

	# Objective pill under it.
	var obj := Rect2(vw * 0.5 - 125, strip.end.y + 6, 250, 46)
	_glass(obj, 10.0, _hold_colour() if hold_owner != 0 else H_AMBER)
	_text(Vector2(obj.position.x, obj.position.y + 16), "Hold the Orichalcum rock", 13, H_TEXT, "holo_bold", HORIZONTAL_ALIGNMENT_CENTER, obj.size.x)
	var bar_r := Rect2(obj.position.x + 22, obj.position.y + 22, obj.size.x - 44, 6)
	_panel.draw_rect(bar_r, Color(0, 0, 0, 0.55))
	_panel.draw_rect(Rect2(bar_r.position, Vector2(bar_r.size.x * maxf(0.04, _hold_progress()), bar_r.size.y)), _hold_colour())
	_panel.draw_rect(bar_r, H_LINE_DIM, false, 1.0)
	_text(Vector2(obj.position.x, obj.position.y + 40), hold_state, 11, H_TEXT_DIM, "holo", HORIZONTAL_ALIGNMENT_CENTER, obj.size.x)

	# Toggles (top right).
	var tx := vw - 6.0
	var defs := _toggle_defs()
	defs.reverse()
	for d in defs:
		var tw := 70.0
		tx -= tw
		var tr := Rect2(tx, 6, tw, 18)
		var on: bool = (d[0] == "style" and pixel_mode) or (d[0] == "zoom" and close_zoom) or (d[0] == "ai" and red_ai_active) or d[0] == "hud"
		_glass(tr, 4.0, H_AMBER if on else H_LINE_DIM, H_GLASS)
		_text(Vector2(tr.position.x, tr.position.y + 13), d[1], 10, H_TEXT if on else H_TEXT_DIM, "holo", HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
		_btn_rects[d[0]] = tr
		tx -= 4.0

	# Minimap (bottom left).
	var mm_w := 176.0
	var mm_h := mm_w * (world_size.y / world_size.x)
	var mm := Rect2(8, vh - 8 - mm_h - 12, mm_w + 12, mm_h + 12)
	_glass(mm, 10.0)
	_draw_minimap_content(mm.grow(-6))
	_panel.draw_rect(_minimap_rect, H_LINE_DIM, false, 1.0)

	# Unit card (bottom centre).
	var card := Rect2(vw * 0.5 - 182, vh - 8 - 96, 364, 96)
	_glass(card, 12.0)
	var lead := _lead()
	var port := Rect2(card.position.x + 8, card.position.y + 8, 80, 80)
	_panel.draw_rect(port, Color(0.05, 0.12, 0.16, 0.9))
	var ptex := _portrait(lead.portrait_key if lead != null else "orichalcum")
	if ptex != null:
		_panel.draw_texture_rect(ptex, port, false)
	_panel.draw_rect(port, H_LINE, false, 1.0)
	var ix := port.end.x + 10
	var split := card.end.x - 116
	if lead != null:
		_text(Vector2(ix, card.position.y + 21), lead.display_name if selected_units.size() <= 1 else "%s +%d" % [lead.display_name, selected_units.size() - 1], 15, H_TEXT, "holo_bold", HORIZONTAL_ALIGNMENT_LEFT, split - ix - 6)
		var hb := Rect2(ix, card.position.y + 27, split - ix - 12, 12)
		var hp := clampf(float(lead.health) / float(maxi(lead.max_health, 1)), 0.0, 1.0)
		_panel.draw_rect(hb, Color(0, 0, 0, 0.6))
		_panel.draw_rect(Rect2(hb.position, Vector2(hb.size.x * hp, hb.size.y)), Color(0.22, 0.80, 0.32, 0.9) if hp > 0.35 else Color(0.95, 0.35, 0.22))
		_text(Vector2(hb.position.x + 5, hb.end.y - 2), "Health %d / %d" % [lead.health, lead.max_health], 10, Color.WHITE, "holo_bold", HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color(0, 0, 0, 0.6))
		var rows := [["attack", "Attack", str(lead.attack_damage)], ["hold", "Armour", str(lead.armour)], ["range", "Range", "%.1f" % lead.attack_range_cells]]
		for i in rows.size():
			var ry := card.position.y + 55 + i * 14.0
			_icon(Vector2(ix + 5, ry - 4), rows[i][0], H_TEXT_DIM, 0.55)
			_text(Vector2(ix + 15, ry), rows[i][1], 11, H_TEXT_DIM, "holo")
			_text(Vector2(ix, ry), rows[i][2], 12, H_TEXT, "holo_bold", HORIZONTAL_ALIGNMENT_RIGHT, split - ix - 14)
	else:
		_text(Vector2(ix, card.position.y + 22), "Orichalcum Vein", 15, H_TEXT, "holo_bold")
		_text(Vector2(ix, card.position.y + 40), "Central outcrop", 11, H_AMBER, "holo")
		_text(Vector2(ix, card.position.y + 62), "Click or drag Blue forces", 11, H_TEXT_DIM, "holo")
		_text(Vector2(ix, card.position.y + 76), "to command them.", 11, H_TEXT_DIM, "holo")
	_panel.draw_line(Vector2(split, card.position.y + 12), Vector2(split, card.end.y - 12), H_LINE_DIM, 1.0)
	var ax := split + 8
	if lead != null and lead.role == RtsCarbonUnit.Role.SQUAD:
		var fit := lead.fit_count()
		_text(Vector2(ax, card.position.y + 34), "Squad", 12, H_TEXT, "holo_bold")
		_text(Vector2(ax, card.position.y + 50), "%d of 4 fit" % fit, 11, H_TEXT_DIM, "holo")
		for i in 4:
			_panel.draw_circle(Vector2(ax + 8 + i * 18.0, card.position.y + 66), 5.5, Color(0.45, 0.72, 1.0) if i < fit else Color(1, 1, 1, 0.15))
	elif lead != null and lead.role == RtsCarbonUnit.Role.TANK:
		_text(Vector2(ax, card.position.y + 40), "Tracked", 12, H_TEXT, "holo_bold")
		_text(Vector2(ax, card.position.y + 56), "chassis", 11, H_TEXT_DIM, "holo")
	else:
		var mend := _mend_state()
		var ic := Vector2(ax + 10, card.position.y + 36)
		_panel.draw_arc(ic, 9.0, 0, TAU, 24, H_AMBER, 1.3, true)
		_icon(ic, "mend", H_AMBER, 0.7)
		_text(Vector2(ax + 24, card.position.y + 40), "Mend +30 HP", 11, H_TEXT, "holo_bold")
		var pill := Rect2(ax + 14, card.position.y + 54, 70, 18)
		_glass(pill, 5.0, Color(0.40, 1.0, 0.50) if mend[0] else H_LINE_DIM, Color(0.04, 0.20, 0.08, 0.85) if mend[0] else H_GLASS, false)
		_text(Vector2(pill.position.x, pill.end.y - 4.5), String(mend[1]), 11, Color(0.6, 1.0, 0.6) if mend[0] else H_TEXT_DIM, "holo_bold", HORIZONTAL_ALIGNMENT_CENTER, pill.size.x)

	# Commands 2×2 (bottom right).
	var any_hold := false
	for u in selected_units:
		if is_instance_valid(u) and u.hold_position:
			any_hold = true
	var mend_ok: bool = _mend_state()[0]
	var bw := 92.0
	var bh := 38.0
	var pad := Rect2(vw - 8 - (bw * 2 + 18), vh - 8 - (bh * 2 + 18), bw * 2 + 18, bh * 2 + 18)
	_glass(pad, 10.0, H_LINE_DIM)
	var cmds := [["move", "Move"], ["attack", "Attack"], ["hold", "Hold"], ["mend", "Mend"]]
	for i in 4:
		var r := Rect2(pad.position.x + 6 + (i % 2) * (bw + 6), pad.position.y + 6 + (i / 2) * (bh + 6), bw, bh)
		var id: String = cmds[i][0]
		var lit := command_cursor_mode == id or (id == "hold" and any_hold)
		var line := H_AMBER if lit else (H_LINE if (id != "mend" or mend_ok) else H_LINE_DIM)
		_glass(r, 6.0, line, H_GLASS_HI, false)
		_icon(Vector2(r.position.x + 20, r.get_center().y), id, line, 1.0)
		_text(Vector2(r.position.x + 34, r.position.y + 25), cmds[i][1], 14, H_TEXT if (id != "mend" or mend_ok) else H_TEXT_DIM, "holo", HORIZONTAL_ALIGNMENT_LEFT)
		_btn_rects["cmd_" + id] = r

	_panel.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Mockup E: the owner's mockup chrome with live content ------------------------------------------

var _mock_tex := {}


func _mock(key: String) -> Texture2D:
	if not _mock_tex.has(key):
		var path := MOCK_DIR + key + ".png"
		_mock_tex[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _mock_tex[key]


## Sidebar coordinates in mockup pixels, anchored to the right edge.
func _ms(vw: float, mx: float, my: float) -> Vector2:
	return Vector2(vw - (1672.0 - mx) * MOCK_K, my * MOCK_K)


func _mr(vw: float, x0: float, y0: float, x1: float, y1: float) -> Rect2:
	var a := _ms(vw, x0, y0)
	return Rect2(a, _ms(vw, x1, y1) - a)


## Top-bar coordinates in mockup pixels, stretched across the window width.
func _mt(vw: float, x0: float, y0: float, x1: float, y1: float) -> Rect2:
	var sx := vw / 960.0 * MOCK_K
	return Rect2(Vector2(x0 * sx, y0 * MOCK_K), Vector2((x1 - x0) * sx, (y1 - y0) * MOCK_K))


func _draw_mockup_e() -> void:
	_btn_rects.clear()
	var s := ui_scale()
	var vw := _virtual_w_actual()
	var top_tex := _mock("top_bar")
	var side_tex := _mock("sidebar")
	if top_tex == null or side_tex == null:
		_draw_classic()
		return
	_panel.draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	var gold := Color(1.0, 0.83, 0.30)
	var cream := Color(0.98, 0.95, 0.88)
	var ink := Color(0.12, 0.07, 0.03)
	var steel := Color(0.12, 0.13, 0.14)

	_panel.draw_texture_rect(top_tex, Rect2(0, 0, vw, MOCK_TOP_H), false)
	var values := [
		[835.0, 905.0, str(orichalcum)],
		[1133.0, 1200.0, "%d/%d" % [blue_alive, blue_total]],
		[1410.0, 1505.0, "0:%02d" % int(ceil(maxf(0.0, hold_seconds_left)))],
	]
	for v in values:
		var r := _mt(vw, v[0], 12.0, v[1], 50.0)
		_panel.draw_rect(r, Color(0.11, 0.09, 0.08))
		_text(Vector2(r.position.x, r.end.y - 4.5), v[2], 17, gold, "classic_bold", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

	var side := Rect2(vw - MOCK_SIDE_W, MOCK_TOP_H, MOCK_SIDE_W, 879.0 * MOCK_K)
	_panel.draw_texture_rect(side_tex, side, false)
	var lead := _lead()

	# Portrait: the mockup's painted commander stays for her; other selections show their portrait.
	var port := _mr(vw, 1288, 88, 1428, 268)
	var blue_commander := lead != null and lead.team == RtsCarbonUnit.Team.BLUE and lead.role == RtsCarbonUnit.Role.COMMANDER
	if not blue_commander:
		_panel.draw_rect(port, Color(0.09, 0.18, 0.40))
		var ptex := _portrait(lead.portrait_key if lead != null else "orichalcum")
		if ptex != null:
			var side_len := minf(port.size.x, port.size.y)
			_panel.draw_texture_rect(ptex, Rect2(port.get_center() - Vector2.ONE * side_len * 0.5, Vector2.ONE * side_len), false)

	# Name, health, stats.
	var name_r := _mr(vw, 1446, 84, 1660, 122)
	_panel.draw_rect(name_r, Color(0.12, 0.13, 0.14))
	var hb := _mr(vw, 1452, 128, 1654, 154)
	_panel.draw_rect(hb, Color(0.05, 0.05, 0.02))
	var vals := _mr(vw, 1598, 168, 1656, 264)
	_panel.draw_rect(vals, Color(0.085, 0.08, 0.085))
	if lead != null:
		var title := lead.display_name if selected_units.size() <= 1 else "%s +%d" % [lead.display_name, selected_units.size() - 1]
		_text(Vector2(name_r.position.x + 3, name_r.end.y - 5), title, 15, cream, "classic_bold", HORIZONTAL_ALIGNMENT_LEFT, name_r.size.x - 4)
		var hp := clampf(float(lead.health) / float(maxi(lead.max_health, 1)), 0.0, 1.0)
		var inner := hb.grow(-1.5)
		_panel.draw_rect(Rect2(inner.position, Vector2(inner.size.x * hp, inner.size.y)), Color(0.20, 0.78, 0.22) if hp > 0.35 else Color(0.90, 0.30, 0.16))
		_panel.draw_rect(hb, Color(0.62, 0.86, 0.36), false, 1.0)
		_text(Vector2(hb.position.x, hb.end.y - 3), "%d / %d" % [lead.health, lead.max_health], 13, Color.WHITE, "classic", HORIZONTAL_ALIGNMENT_CENTER, hb.size.x, 2, Color(0.02, 0.16, 0.03, 0.9))
		var stat_vals := [str(lead.attack_damage), str(lead.armour), "%.1f" % lead.attack_range_cells]
		for i in 3:
			var base := _ms(vw, 1598, 194.0 + i * 31.5)
			_text(base, stat_vals[i], 15, gold, "classic_bold", HORIZONTAL_ALIGNMENT_RIGHT, vals.size.x - 4)
	else:
		_text(Vector2(name_r.position.x + 3, name_r.end.y - 5), "Orichalcum Vein", 15, cream, "classic_bold")
		_text(Vector2(hb.position.x, hb.end.y - 3), "Central outcrop", 12, gold, "classic", HORIZONTAL_ALIGNMENT_CENTER, hb.size.x)

	# Ability / squad strip.
	var strip := _mr(vw, 1288, 288, 1652, 340)
	_panel.draw_rect(strip, Color(0.10, 0.10, 0.11))
	if lead != null and lead.role == RtsCarbonUnit.Role.SQUAD:
		var fit := lead.fit_count()
		_text(Vector2(strip.position.x + 8, strip.end.y - 9), "Squad  %d of 4 fit" % fit, 15, cream, "classic_bold")
		for i in 4:
			var pr := Rect2(strip.end.x - 78 + i * 18.0, strip.position.y + 7, 13, 16)
			_panel.draw_rect(pr, Color(0.22, 0.44, 0.85) if i < fit else Color(0.28, 0.26, 0.24))
			_panel.draw_rect(pr, gold, false, 1.0)
	elif lead != null and lead.role == RtsCarbonUnit.Role.TANK:
		_text(Vector2(strip.position.x + 8, strip.end.y - 9), "Tracked chassis", 15, cream, "classic_bold")
	else:
		var icon := _mock("mend_icon")
		if icon != null:
			_panel.draw_texture_rect(icon, _mr(vw, 1291, 289, 1362, 338), false)
		_text(_ms(vw, 1377, 324), "Mend +30 HP", 16, cream, "classic_bold")
		var mend := _mend_state()
		var badge := _mr(vw, 1556, 298, 1647, 330)
		_panel.draw_rect(badge, Color(0.10, 0.24, 0.10) if mend[0] else Color(0.18, 0.17, 0.16))
		_panel.draw_rect(badge, Color(0.45, 0.92, 0.42) if mend[0] else Color(0.45, 0.43, 0.40), false, 1.2)
		_text(Vector2(badge.position.x, badge.end.y - 4.5), String(mend[1]).to_upper(), 12, Color(0.55, 1.0, 0.5) if mend[0] else cream, "classic_bold", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x)

	# Command buttons are painted in the mockup; lit and unavailable states are overlays.
	var any_hold := false
	for u in selected_units:
		if is_instance_valid(u) and u.hold_position:
			any_hold = true
	var mend_ok: bool = _mend_state()[0]
	var buttons := {
		"move": _mr(vw, 1285, 360, 1470, 430), "attack": _mr(vw, 1477, 360, 1660, 430),
		"hold": _mr(vw, 1285, 440, 1470, 510), "mend": _mr(vw, 1477, 440, 1660, 510),
	}
	for id: String in buttons:
		var r: Rect2 = buttons[id]
		if command_cursor_mode == id or (id == "hold" and any_hold):
			_panel.draw_rect(r.grow(-2), Color(1.0, 0.66, 0.16, 0.26))
			_panel.draw_rect(r.grow(-1), Color(1.0, 0.86, 0.40), false, 1.6)
		elif id == "mend" and not mend_ok:
			_panel.draw_rect(r.grow(-2), Color(0.04, 0.04, 0.05, 0.55))
		_btn_rects["cmd_" + id] = r

	# Objective bar and state.
	var bar := _mr(vw, 1305, 580, 1645, 608)
	_panel.draw_rect(bar, Color(0.08, 0.08, 0.085))
	var inner_bar := bar.grow(-2)
	var fill_col := Color(0.98, 0.84, 0.16) if hold_owner == 0 else _hold_colour()
	_panel.draw_rect(Rect2(inner_bar.position, Vector2(inner_bar.size.x * maxf(0.04, _hold_progress()), inner_bar.size.y)), fill_col)
	_panel.draw_rect(bar, Color(0.05, 0.04, 0.03), false, 1.2)
	var state_r := _mr(vw, 1300, 612, 1648, 650)
	_panel.draw_rect(state_r, Color(0.88, 0.59, 0.29))
	_text(Vector2(state_r.position.x, state_r.end.y - 5.5), hold_state, 16, ink, "classic_bold", HORIZONTAL_ALIGNMENT_CENTER, state_r.size.x)

	# Minimap.
	_draw_minimap_content(_mr(vw, 1302, 685, 1640, 890))

	# Toggles along the bottom of the sidebar.
	var defs := [
		["style", "V · Pixel" if pixel_mode else "V · HD"],
		["zoom", "Z · 15×10" if close_zoom else "Z · 21×14"],
		["ai", "G · AI" if red_ai_active else "G · Guard"],
		["hud", "U · HUD"],
	]
	var row := _mr(vw, 1276, 900, 1660, 932)
	var cw := (row.size.x - 9.0) / 4.0
	for i in defs.size():
		var tr := Rect2(row.position.x + i * (cw + 3.0), row.position.y, cw, row.size.y)
		var on: bool = (defs[i][0] == "style" and pixel_mode) or (defs[i][0] == "zoom" and close_zoom) or (defs[i][0] == "ai" and red_ai_active)
		_panel.draw_rect(tr, Color(0.30, 0.42, 0.20) if on else (Color(0.10, 0.22, 0.48) if defs[i][0] == "hud" else steel))
		_panel.draw_rect(tr, Color(0.80, 0.60, 0.30), false, 1.0)
		_text(Vector2(tr.position.x, tr.end.y - 5), defs[i][1], 10, cream, "classic", HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
		_btn_rects[defs[i][0]] = tr

	_panel.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
