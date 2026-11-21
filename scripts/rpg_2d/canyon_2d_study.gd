class_name Canyon2DStudy
extends Control
## Standalone 100% 2D Parallel-Projection Pixel-Art RPG Canyon Study (Option C).
## Supports live A/B switching (Tab or M) between:
##   - Approach 1: One Continuous, Uncut 2D Artwork + In-Place Walk-Behind Cutouts
##   - Approach 2: Modular Stitched Ground/Road + Y-Sorted Cliff Terraces, Archways, Boulders & Bushes
## Plus live 960x540 <-> 640x360 resolution switching (1/2/V), framing zoom (Z), Laigter normal lighting (L),
## diagonal sunbeams (G), and Explore (8-way) <-> Profile (C) walking modes.

@export_range(1, 2, 1) var active_approach: int = 1

# Sampled every 100 px from y = 0..2000 in 960x1967 world coordinates
const APPROACH1_ROAD_X := [
	329.0, 414.0, 504.0, 474.0, 374.0,
	439.0, 554.0, 514.0, 379.0, 414.0,
	514.0, 469.0, 384.0, 494.0, 599.0,
	494.0, 364.0, 424.0, 564.0, 559.0, 509.0
]

const APPROACH2_ROAD_X := [
	510.0, 441.0, 484.5, 512.5, 480.0,
	460.0, 518.0, 496.0, 449.5, 505.0,
	500.0, 442.5, 477.5, 513.0, 486.0,
	444.0, 516.0, 492.5, 440.0, 464.5, 485.0
]

var current_res: Vector2i = Vector2i(960, 540)
var framed_uncut_zoom: bool = false
var matched_framing_at_640: bool = true
var normals_lighting_on: bool = true
var god_rays_on: bool = true
var hud_visible: bool = true

@onready var world_viewport: SubViewport = $WorldViewport
@onready var viewport_display: TextureRect = $ViewportDisplay
@onready var hero: Hero2DController = $WorldViewport/CanyonWorld/YSortWorld/Hero2D
@onready var camera: PixelCamera2D = $WorldViewport/CanyonWorld/PixelCamera
@onready var dir_light: DirectionalLight2D = $WorldViewport/CanyonWorld/SunLight2D
@onready var canvas_mod: CanvasModulate = $WorldViewport/CanyonWorld/AmbientModulate
@onready var god_rays_rect: ColorRect = $WorldViewport/AtmosphereLayer/GodRaysRect
@onready var dust_particles: GPUParticles2D = $WorldViewport/AtmosphereLayer/DustParticles
@onready var y_sort_world: Node2D = $WorldViewport/CanyonWorld/YSortWorld
@onready var a1_ground: Sprite2D = $WorldViewport/CanyonWorld/Approach1Ground
@onready var a2_ground: Sprite2D = $WorldViewport/CanyonWorld/Approach2Ground
@onready var a1_collider: StaticBody2D = $WorldViewport/CanyonWorld/Approach1Collider
@onready var a2_collider: StaticBody2D = $WorldViewport/CanyonWorld/Approach2Collider
@onready var status_label: Label = $HUD/Panel/Margin/VBox/StatusLabel
@onready var prompt_label: Label = $HUD/Panel/Margin/VBox/PromptLabel
@onready var hud_layer: CanvasLayer = $HUD

var _a1_ysort_nodes: Array[Node2D] = []
var _a2_ysort_nodes: Array[Node2D] = []


static func get_road_center_x(approach_id: int, y_pos: float) -> float:
	var table := APPROACH1_ROAD_X if approach_id == 1 else APPROACH2_ROAD_X
	var cy := clampf(y_pos, 0.0, 1967.0)
	var idx_f := cy / 100.0
	var i0 := clampi(int(floor(idx_f)), 0, table.size() - 2)
	var t := idx_f - float(i0)
	return lerpf(float(table[i0]), float(table[i0 + 1]), t)


func _ready() -> void:
	if world_viewport != null and viewport_display != null:
		viewport_display.texture = world_viewport.get_texture()
		viewport_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		world_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		world_viewport.snap_2d_transforms_to_pixel = true
		world_viewport.snap_2d_vertices_to_pixel = true

	if y_sort_world != null:
		for child in y_sort_world.get_children():
			if child is Node2D and child != hero:
				var n2d := child as Node2D
				var app_tag := int(n2d.get_meta("approach", 0))
				if app_tag == 1:
					_a1_ysort_nodes.append(n2d)
				elif app_tag == 2:
					_a2_ysort_nodes.append(n2d)

	if hero != null:
		hero.mode_changed.connect(_on_hero_mode_changed)

	if camera != null and hero != null:
		camera.set_target(hero)

	set_approach(active_approach, false)
	set_resolution_preset(960, 540)
	_apply_lighting_state()
	_apply_god_rays_state()
	_refresh_hud()


func set_approach(new_approach: int,preserve_road_offset: bool = true) -> void:
	var prev_approach := active_approach
	active_approach = 1 if new_approach <= 1 else 2

	if hero != null and preserve_road_offset and prev_approach != active_approach:
		var y_now := hero.global_position.y
		var old_cx := get_road_center_x(prev_approach, y_now)
		var new_cx := get_road_center_x(active_approach, y_now)
		var dx := clampf(hero.global_position.x - old_cx, -85.0, 85.0)
		hero.global_position.x = new_cx + dx
		if camera != null:
			camera.snap_immediately()

	if a1_ground != null:
		a1_ground.visible = (active_approach == 1)
	if a2_ground != null:
		a2_ground.visible = (active_approach == 2)
	if a1_collider != null:
		a1_collider.collision_layer = 1 if active_approach == 1 else 0
	if a2_collider != null:
		a2_collider.collision_layer = 1 if active_approach == 2 else 0

	for n in _a1_ysort_nodes:
		if n != null:
			n.visible = (active_approach == 1)
			if n is StaticBody2D:
				(n as StaticBody2D).collision_layer = 1 if active_approach == 1 else 0
	for n in _a2_ysort_nodes:
		if n != null:
			n.visible = (active_approach == 2)
			if n is StaticBody2D:
				(n as StaticBody2D).collision_layer = 1 if active_approach == 2 else 0

	_refresh_hud()


func toggle_approach() -> void:
	set_approach(2 if active_approach == 1 else 1, true)


func set_resolution_preset(w: int, h: int) -> void:
	current_res = Vector2i(w, h)
	if world_viewport != null:
		world_viewport.size = current_res
	var base_zoom := 1.4076 if framed_uncut_zoom else 1.0
	var zoom_scale := base_zoom
	if w == 640 and matched_framing_at_640:
		zoom_scale = base_zoom * (640.0 / 960.0)
	if camera != null:
		camera.set_resolution_zoom(zoom_scale, current_res)
	if god_rays_rect != null:
		god_rays_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	if dust_particles != null:
		dust_particles.position = Vector2(current_res) * Vector2(0.58, 0.40)
	_refresh_hud()


func toggle_resolution() -> void:
	if current_res.x == 960:
		set_resolution_preset(640, 360)
	else:
		set_resolution_preset(960, 540)


func set_hud_visible(show_hud: bool) -> void:
	hud_visible = show_hud
	if hud_layer != null:
		hud_layer.visible = hud_visible


func reset_hero_position(y_target: float = 1720.0) -> void:
	if hero != null:
		hero.global_position = Vector2(get_road_center_x(active_approach, y_target), y_target)
		hero.facing_dir_8way = Vector2.DOWN
		hero.set_mode(Hero2DController.Mode.EXPLORE)
	if camera != null:
		camera.snap_immediately()
	_refresh_hud()


func _process(_delta: float) -> void:
	_refresh_hud()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.is_action("ui_cancel"):
		return

	match k.keycode:
		KEY_TAB, KEY_M:
			toggle_approach()
			get_viewport().set_input_as_handled()
		KEY_1:
			set_resolution_preset(960, 540)
			get_viewport().set_input_as_handled()
		KEY_2:
			set_resolution_preset(640, 360)
			get_viewport().set_input_as_handled()
		KEY_V:
			toggle_resolution()
			get_viewport().set_input_as_handled()
		KEY_Z:
			framed_uncut_zoom = not framed_uncut_zoom
			set_resolution_preset(current_res.x, current_res.y)
			get_viewport().set_input_as_handled()
		KEY_L:
			normals_lighting_on = not normals_lighting_on
			_apply_lighting_state()
			get_viewport().set_input_as_handled()
		KEY_G:
			god_rays_on = not god_rays_on
			_apply_god_rays_state()
			get_viewport().set_input_as_handled()
		KEY_R:
			reset_hero_position(1720.0)
			get_viewport().set_input_as_handled()
		KEY_H:
			set_hud_visible(not hud_visible)
			get_viewport().set_input_as_handled()


func _apply_lighting_state() -> void:
	if dir_light != null:
		dir_light.enabled = normals_lighting_on
	if canvas_mod != null:
		canvas_mod.color = Color(0.95, 0.92, 0.90, 1.0) if normals_lighting_on else Color.WHITE


func _apply_god_rays_state() -> void:
	if god_rays_rect != null:
		god_rays_rect.visible = god_rays_on
	if dust_particles != null:
		dust_particles.emitting = god_rays_on
		dust_particles.visible = god_rays_on


func _on_hero_mode_changed(_new_mode: int) -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	if status_label == null or hero == null:
		return
	var app_str := (
		"APPROACH 1: UNCUT 2D ARTWORK"
		if active_approach == 1
		else "APPROACH 2: MODULAR STITCHED 2D KIT"
	)
	var mode_str := "EXPLORE (8-WAY)" if hero.mode == Hero2DController.Mode.EXPLORE else "PROFILE (L/R LOCKED)"
	var zoom_tag := "682px Framed" if framed_uncut_zoom else ("Matched" if current_res.x == 640 else "960px 1:1")

	status_label.text = (
		"%s  |  RES: %dx%d (%s)  |  WALK: %s (%s)  |  NORMALS: %s  |  RAYS: %s"
		% [
			app_str,
			current_res.x,
			current_res.y,
			zoom_tag,
			mode_str,
			hero.get_facing_label(),
			"ON" if normals_lighting_on else "OFF",
			"ON" if god_rays_on else "OFF",
		]
	)

	if prompt_label != null:
		prompt_label.text = (
			"WASD/Arrows: Walk Canyon · Tab/M: Switch Approach 1 <-> Approach 2 · 1/2/V: 960x540 vs 640x360 · Z: Framing Zoom · C: 8-Way/Profile · L: Normals · G: Rays · H: Hide HUD · R: Reset · Esc: Menu"
		)
		prompt_label.modulate = Color(0.95, 0.90, 0.82, 0.95)
