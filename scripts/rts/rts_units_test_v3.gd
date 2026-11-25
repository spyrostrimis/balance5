extends Node2D
## RTS units test: units walking, driving and fighting on the style test 5 map, with a scene-local
## visual profile switch (F4) between "pixel" (1x 960x540 integer) and "hd_painted" (2x 1920x1080 smooth)
## on the exact same 32x32 logical tile grid. Built by tools/python/make_rts_units_test.py.
## Controls:
##   P patrol   K shadows   L ground light   M tracks/footprints   N dust
##   F1 blocked tiles   F3 debug & GPU perf overlay   F4 pixel / hd_painted look
##   Left-click/drag select   Right-click move/attack   S stop   Wheel zoom   Esc back

signal controls_changed
signal profile_changed(profile: RtsVisualProfile)

const MAP_LOGICAL_RECT := Rect2(0, 0, 960, 540)
const T5_PIXEL_DIR := "res://assets/textures/rts/style_test/t5/"
const T5_HD_DIR := "res://assets/textures/rts/style_test/t5_hd/"
const LAYER_FILES := {
	"Ground": "sand_dunes.png",
	"Road": "road.png",
	"Rocks": "rocks.png",
	"Scatter": "scatter.png",
}
const ORICHALCUM_POS := Vector2(318.0, 216.0)

@onready var grid: RtsGrid = $Grid
@onready var look: RtsLook = $Look
@onready var units: Node2D = $Units
@onready var camera: RtsCamera = $Camera
@onready var hud: CanvasLayer = $HUD
@onready var _help: Label = $HUD/Help

var patrol := false
var debug_overlay_visible := false
var profile: RtsVisualProfile
var _patrol_timer := 0.0
var _glow_phase := 0.0
var _saved_window_state: Dictionary = {}
var _owns_window_policy := false
var _pixel_textures: Dictionary = {}
var _hd_textures: Dictionary = {}
var _crystal_glow: Node2D
var _vignette: Control
var _debug_panel: PanelContainer
var _debug_label: Label


class OrichalcumGlowNode extends Sprite2D:
	var pulse := 0.0

	func _init() -> void:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.32, 0.68, 1.0])
		grad.colors = PackedColorArray([
			Color(1.0, 0.92, 0.55, 0.30),
			Color(1.0, 0.78, 0.28, 0.16),
			Color(1.0, 0.65, 0.16, 0.05),
			Color(1.0, 0.60, 0.12, 0.0),
		])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.width = 160
		tex.height = 112
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		texture = tex


	func set_pulse(p: float) -> void:
		pulse = p
		var s := 1.0 + 0.06 * sin(pulse)
		scale = Vector2(s, s)
		modulate.a = 0.88 + 0.12 * sin(pulse)


class VignetteOverlay extends Control:
	func _draw() -> void:
		var sz := size
		if sz.x <= 1.0 or sz.y <= 1.0:
			sz = Vector2(RtsVisualProfile.LOGICAL_VIEW_SIZE)
		var steps := 10
		var max_band := 68.0
		for i in steps:
			var t := float(i) / float(steps)
			var band := max_band * (1.0 - t)
			var alpha := 0.018 * (1.0 - t)
			var col := Color(0.09, 0.04, 0.01, alpha)
			draw_rect(Rect2(0, 0, sz.x, band), col)
			draw_rect(Rect2(0, sz.y - band, sz.x, band), col)
			draw_rect(Rect2(0, band, band, sz.y - band * 2.0), col)
			draw_rect(Rect2(sz.x - band, band, band, sz.y - band * 2.0), col)


func _ready() -> void:
	for node_name: String in LAYER_FILES:
		var fname: String = LAYER_FILES[node_name]
		_pixel_textures[node_name] = load(T5_PIXEL_DIR + fname)
		if ResourceLoader.exists(T5_HD_DIR + fname):
			_hd_textures[node_name] = load(T5_HD_DIR + fname)

	_setup_atmosphere_and_debug_nodes()

	# Only apply Window-level content scaling when running as the main viewport scene
	# (not when embedded inside another scene's SubViewport).
	_owns_window_policy = (get_viewport() == get_window())
	if _owns_window_policy:
		_saved_window_state = RtsVisualProfile.capture_window_state(get_window())
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

	for node in units.get_children():
		if node is RtsUnit:
			(node as RtsUnit).setup(grid)

	set_visual_profile(RtsVisualProfile.from_cmdline(RtsVisualProfile.ID_PIXEL))


func _exit_tree() -> void:
	RtsLook.pixel_snap = false
	RtsLook.soft_effects = false
	if _owns_window_policy and not _saved_window_state.is_empty():
		RtsVisualProfile.restore_window_state(get_window(), _saved_window_state)


func _setup_atmosphere_and_debug_nodes() -> void:
	_crystal_glow = OrichalcumGlowNode.new()
	_crystal_glow.name = "OrichalcumGlow"
	_crystal_glow.position = ORICHALCUM_POS
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_crystal_glow.material = glow_mat
	add_child(_crystal_glow)
	move_child(_crystal_glow, $Rocks.get_index() + 1)

	_vignette = VignetteOverlay.new()
	_vignette.name = "Vignette"
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.size = Vector2(RtsVisualProfile.LOGICAL_VIEW_SIZE)
	hud.add_child(_vignette)
	hud.move_child(_vignette, 0)

	# Anchor Help label at the bottom so it never collides with BuildLauncher's top-left Return button.
	_help.offset_left = 10.0
	_help.offset_top = 514.0
	_help.offset_right = 950.0
	_help.offset_bottom = 536.0

	_debug_panel = PanelContainer.new()
	_debug_panel.name = "DebugOverlay"
	_debug_panel.visible = debug_overlay_visible
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_panel.offset_left = 620.0
	_debug_panel.offset_top = 8.0
	_debug_panel.offset_right = 952.0
	_debug_panel.offset_bottom = 142.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.04, 0.82)
	style.border_color = Color(0.85, 0.68, 0.34, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_debug_panel.add_theme_stylebox_override("panel", style)

	_debug_label = Label.new()
	_debug_label.name = "Readout"
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.add_theme_font_size_override("font_size", 12)
	_debug_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	_debug_panel.add_child(_debug_label)
	hud.add_child(_debug_panel)


func set_visual_profile(new_profile: RtsVisualProfile) -> void:
	if new_profile == null:
		return
	profile = new_profile
	if _owns_window_policy:
		profile.apply_to_window(get_window())
	texture_filter = profile.canvas_texture_filter

	var use_hd := profile.is_hd_painted()
	for node_name: String in LAYER_FILES:
		var spr := get_node_or_null(node_name) as Sprite2D
		if spr == null:
			continue
		if use_hd and _hd_textures.has(node_name):
			spr.texture = _hd_textures[node_name]
			spr.scale = Vector2(0.5, 0.5)
		else:
			spr.texture = _pixel_textures[node_name]
			spr.scale = Vector2.ONE
		spr.texture_filter = profile.canvas_texture_filter

	if look != null:
		look.apply_visual_profile(profile)
	for node in units.get_children():
		if node is RtsUnit:
			(node as RtsUnit).apply_visual_profile(profile)
	if camera != null:
		camera.apply_visual_profile(profile, MAP_LOGICAL_RECT)
	if _crystal_glow != null:
		_crystal_glow.visible = profile.atmosphere_enabled
	if _vignette != null:
		_vignette.visible = profile.atmosphere_enabled
		_vignette.queue_redraw()
	if hud != null:
		hud.scale = Vector2.ONE * profile.density

	_update_help()
	_update_debug_overlay()
	profile_changed.emit(profile)


func toggle_visual_profile() -> void:
	set_visual_profile(profile.toggled() if profile != null else RtsVisualProfile.create_hd_painted())


func set_debug_overlay(on: bool) -> void:
	debug_overlay_visible = on
	if _debug_panel != null:
		_debug_panel.visible = on
	if on:
		_update_debug_overlay()
	_update_help()


func get_perf_metrics() -> Dictionary:
	var p := profile if profile != null else RtsVisualProfile.create_pixel()
	var scale_info := p.effective_scale_info(get_window() if _owns_window_policy else null)
	var vp_rid := get_viewport().get_viewport_rid()
	var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
	var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
	var active_units := 0
	for node in units.get_children():
		var u := node as RtsUnit
		if u != null and u.alive:
			active_units += 1
	return {
		"profile_id": p.id,
		"profile_name": p.display_name,
		"window_size": scale_info["window_size"],
		"viewport_size": scale_info["viewport_size"],
		"scale_factor": scale_info["scale"].x,
		"logical_pixel_scale": scale_info["logical_pixel_scale"],
		"is_integer": scale_info["is_integer"],
		"margin": scale_info["margin"],
		"fps": Engine.get_frames_per_second(),
		"gpu_ms": gpu_ms,
		"cpu_ms": cpu_ms,
		"unit_count": active_units,
	}


func _update_debug_overlay() -> void:
	if _debug_label == null or not debug_overlay_visible:
		return
	var m := get_perf_metrics()
	var win: Vector2i = m["window_size"]
	var vp: Vector2 = m["viewport_size"]
	var int_tag := "INTEGER" if m["is_integer"] else "FRACTIONAL"
	_debug_label.text = (
		"Profile (F4): %s\n" % m["profile_name"]
		+ "Window: %d×%d  |  Viewport: %.0f×%.0f\n" % [win.x, win.y, vp.x, vp.y]
		+ "Scale: %.2fx (%s)  |  Art px: %.2fx\n" % [m["scale_factor"], int_tag, m["logical_pixel_scale"]]
		+ "FPS: %.0f  |  GPU: %.2f ms  |  CPU: %.2f ms\n" % [m["fps"], m["gpu_ms"], m["cpu_ms"]]
		+ "Active units: %d  |  Grid: %d×%d (%d px)" % [
			m["unit_count"], grid.region.size.x, grid.region.size.y, grid.tile_size.x
		]
	)


func _process(delta: float) -> void:
	if _crystal_glow != null and _crystal_glow.visible:
		_glow_phase += delta * 2.2
		(_crystal_glow as OrichalcumGlowNode).set_pulse(_glow_phase)
	if debug_overlay_visible:
		_update_debug_overlay()
	if not patrol:
		return
	_patrol_timer -= delta
	if _patrol_timer > 0.0:
		return
	_patrol_timer = 0.4
	for node in units.get_children():
		var unit := node as RtsUnit
		if unit == null or not unit.alive or unit.order != RtsUnit.Order.NONE or unit.is_moving():
			continue
		if randf() < 0.35:
			var target := unit.cell + Vector2i(randi_range(-8, 8), randi_range(-6, 6))
			var spots := grid.free_cells_near(target, 1)
			if not spots.is_empty():
				unit.command_move(spots[0])


func set_patrol(on: bool) -> void:
	patrol = on
	for node in units.get_children():
		if node is RtsUnit:
			(node as RtsUnit).peaceful = on
	_update_help()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_P:
			set_patrol(not patrol)
		KEY_K:
			RtsLook.shadows = not RtsLook.shadows
		KEY_L:
			RtsLook.ground_light = not RtsLook.ground_light
		KEY_M:
			RtsLook.marks = not RtsLook.marks
		KEY_N:
			RtsLook.dust = not RtsLook.dust
		KEY_F1:
			grid.show_debug = not grid.show_debug
		KEY_F3:
			set_debug_overlay(not debug_overlay_visible)
		KEY_F4:
			toggle_visual_profile()
		_:
			return
	get_viewport().set_input_as_handled()
	for node in units.get_children():
		(node as CanvasItem).queue_redraw()
	if look != null:
		look.queue_redraw()
	_update_help()


func _update_help() -> void:
	var on := func(v: bool) -> String: return "on" if v else "off"
	var mode_tag := profile.id if profile != null else "pixel"
	_help.text = (
		"F4 look: %s · F3 perf %s · P patrol %s · K shadows %s · L light %s · M tracks %s · N dust %s · F1 tiles · Esc back"
		% [
			mode_tag, on.call(debug_overlay_visible), on.call(patrol),
			on.call(RtsLook.shadows), on.call(RtsLook.ground_light),
			on.call(RtsLook.marks), on.call(RtsLook.dust),
		]
	)
	controls_changed.emit()
