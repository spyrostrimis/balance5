extends Node2D
## Command-scale preview of Reusable 4's two editable oasis layouts and two modular Orichalcum deposits.
## Press V to switch Detailed Painted (2x) and Pixel (1x); Esc returns to Developers Page.

const ART_DIR := "res://assets/textures/rts/reusable_4"

@onready var sand_sprite: Sprite2D = $Sand
@onready var shadow_layer: Node2D = $CastShadows
@onready var mode_label: Label = $ModeHint

var pixel_mode := false
var _pieces: Array[RtsCarbonPiece] = []
var _shadow_tex: Texture2D
var _sand_hd: Texture2D
var _sand_px: Texture2D


func _ready() -> void:
	_shadow_tex = preload("res://assets/textures/rts/carbon/soft_shadow.png")
	_sand_hd = preload("res://assets/textures/rts/carbon/sand_tile_hd.png")
	_sand_px = preload("res://assets/textures/rts/carbon/sand_tile_pixel.png")
	_collect(self)
	shadow_layer.draw.connect(_draw_shadows)
	apply_visual_mode(false)


func _collect(root_node: Node) -> void:
	for child in root_node.get_children():
		var p := child as RtsCarbonPiece
		if p != null:
			_pieces.append(p)
		_collect(child)


func apply_visual_mode(use_pixel: bool) -> void:
	pixel_mode = use_pixel
	sand_sprite.texture = _sand_px if use_pixel else _sand_hd
	sand_sprite.scale = Vector2.ONE if use_pixel else Vector2(0.5, 0.5)
	sand_sprite.region_rect = Rect2(0, 0, 1200, 800) if use_pixel else Rect2(0, 0, 2400, 1600)
	sand_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if use_pixel else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for p in _pieces:
		p.apply_visual_mode(use_pixel, null, null, null, null, Vector2(1408, 896), false, ART_DIR, false)
	if mode_label != null:
		mode_label.text = "[V] Mode: 960×540 Pixel  ·  [Esc] Developers Page" if use_pixel else "[V] Mode: Detailed Painted HD  ·  [Esc] Developers Page"
	shadow_layer.queue_redraw()


func _draw_shadows() -> void:
	if _shadow_tex == null:
		return
	for p in _pieces:
		if p.shadow_alpha <= 0.01 or p.shadow_size == Vector2.ZERO:
			continue
		var c := shadow_layer.to_local(p.to_global(p.shadow_offset))
		var sz := p.shadow_size * p.global_scale.abs()
		shadow_layer.draw_texture_rect(_shadow_tex, Rect2(c - sz * 0.5, sz), false, Color(1, 1, 1, p.shadow_alpha))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if ke.keycode == KEY_V:
			apply_visual_mode(not pixel_mode)
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_ESCAPE:
			var launcher := get_tree().root.get_node_or_null("BuildLauncher")
			if launcher != null and bool(launcher.call("is_build_active")):
				return
			if ResourceLoader.exists("res://scenes/ui/opening_screen.tscn"):
				get_tree().change_scene_to_file("res://scenes/ui/opening_screen.tscn")
			else:
				get_tree().quit()
