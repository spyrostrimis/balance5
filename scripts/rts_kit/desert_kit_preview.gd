extends Node2D
## Command-scale preview of the shared desert kit: the two oasis groups, the two Orichalcum deposits,
## and every single piece in a labelled palette row. Press V for Pixel; Esc returns.

@export_dir var art_directory := "res://assets/textures/rts/desert_kit"
## World area the sand sprite covers (both pages).
@export var sand_area := Vector2(1664, 1856)
## Every .tscn in this folder appears on page 2, so a new piece shows up without editing this scene.
@export_dir var pieces_directory := "res://scenes/rts/desert_kit/pieces"
@export var palette_columns := 9
## Shown in page 2's title ("Desert Kit", "Forest Kit").
@export var kit_title := "Desert Kit"
## Page 2: centre each painting in its cell even when it is drawn above its pivot (forest crowns).
@export var centre_paintings := false
@export var palette_cell := Vector2(150, 140)

const DUNE_SHADER := preload("res://assets/shaders/rts_carbon_dune.gdshader")

@onready var sand_sprite: Sprite2D = $Sand
@onready var shadow_layer: Node2D = $CastShadows
@onready var mode_label: Label = get_node_or_null("ModeHint")

var pixel_mode := false
var _pieces: Array[RtsCarbonPiece] = []
var _shadow_tex: Texture2D
var _sand_hd: Texture2D
var _sand_px: Texture2D
var _blank: ImageTexture


func _ready() -> void:
	_shadow_tex = preload("res://assets/textures/rts/carbon/soft_shadow.png")
	_sand_hd = RtsCarbonArt.texture("sand_tile", false, art_directory)
	_sand_px = RtsCarbonArt.texture("sand_tile", true, art_directory)
	var black := Image.create_empty(4, 4, false, Image.FORMAT_L8)
	_blank = ImageTexture.create_from_image(black)
	_build_palette()
	_collect(self)
	shadow_layer.draw.connect(_draw_shadows)
	var args := OS.get_cmdline_user_args()
	apply_visual_mode("--pixel" in args)
	show_page(1 if "--pieces" in args else 0)


## Page 0: the two oasis groups and two Orichalcum deposits at Command scale.
## Page 1: every single piece scene, shrunk to fit a labelled palette cell.
func show_page(page: int) -> void:
	var cam := get_node_or_null("Camera") as Camera2D
	var marker := get_node_or_null("Views/Arrangements" if page == 0 else "Views/Pieces") as Marker2D
	if cam == null or marker == null:
		return
	cam.position = marker.position
	var z := float(marker.get_meta("zoom", 1.0))
	cam.zoom = Vector2(z, z)


func _build_palette() -> void:
	var palette := get_node_or_null("Palette") as Node2D
	var page := get_node_or_null("Views/Pieces") as Marker2D
	if palette == null or page == null:
		return
	var files: Array[String] = []
	for f in DirAccess.get_files_at(pieces_directory):
		f = f.trim_suffix(".remap")  # exported builds list scenes as *.tscn.remap
		if f.ends_with(".tscn") and f not in files:
			files.append(f)
	files.sort()
	var rows := ceili(float(files.size()) / palette_columns)
	var grid_size := Vector2(palette_columns, rows) * palette_cell
	var origin := page.position - grid_size * 0.5 + palette_cell * 0.5 + Vector2(0, 28)
	var title := _make_label("%s · every piece (%d) · %s · 1 = arrangements" % [kit_title, files.size(), pieces_directory.trim_prefix("res://")], 18, 1000)
	title.position = Vector2(page.position.x - 500, page.position.y - grid_size.y * 0.5 - 18)
	add_child(title)
	for i in files.size():
		var piece := (load(pieces_directory.path_join(files[i])) as PackedScene).instantiate() as RtsCarbonPiece
		if piece == null:
			continue
		var cell_centre := origin + Vector2(i % palette_columns, i / palette_columns) * palette_cell
		var fit := minf(1.0, minf((palette_cell.x - 14.0) / piece.world_size.x, (palette_cell.y - 36.0) / piece.world_size.y))
		piece.position = cell_centre + Vector2(0, -8) - (piece.draw_offset * fit if centre_paintings else Vector2.ZERO)
		piece.scale = Vector2(fit, fit)
		piece.z_index = 0
		palette.add_child(piece)
		var label := _make_label(files[i].get_basename(), 11, palette_cell.x)
		label.position = cell_centre + Vector2(-palette_cell.x * 0.5, palette_cell.y * 0.5 - 24)
		add_child(label)


func _make_label(text: String, size: int, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.z_index = 4
	l.size = Vector2(width, size + 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(1, 0.91, 0.72))
	l.add_theme_color_override("font_outline_color", Color(0.18, 0.09, 0.04))
	l.add_theme_constant_override("outline_size", 6 if size > 13 else 4)
	l.add_theme_font_size_override("font_size", size)
	return l


func _collect(root_node: Node) -> void:
	for child in root_node.get_children():
		var p := child as RtsCarbonPiece
		if p != null:
			_pieces.append(p)
		_collect(child)


func apply_visual_mode(use_pixel: bool) -> void:
	pixel_mode = use_pixel
	sand_sprite.texture = _sand_px if use_pixel else _sand_hd
	sand_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if use_pixel else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var scale_factor := 1.0 if use_pixel else 0.5
	sand_sprite.scale = Vector2(scale_factor, scale_factor)
	sand_sprite.region_rect = Rect2(Vector2.ZERO, sand_area / scale_factor)
	for p in _pieces:
		p.apply_visual_mode(use_pixel, DUNE_SHADER, sand_sprite.texture, _blank, _blank, Vector2(1408, 896), false, art_directory, false)
	if mode_label != null:
		mode_label.text = "[V] 960×540 Pixel  ·  [Esc] Developers Page" if use_pixel else "[V] Detailed Painted  ·  [Esc] Developers Page"
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
		elif ke.keycode == KEY_1 or ke.keycode == KEY_2:
			show_page(0 if ke.keycode == KEY_1 else 1)
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_ESCAPE:
			var launcher := get_tree().root.get_node_or_null("BuildLauncher")
			if launcher != null and bool(launcher.call("is_build_active")):
				return
			if ResourceLoader.exists("res://scenes/ui/opening_screen.tscn"):
				get_tree().change_scene_to_file("res://scenes/ui/opening_screen.tscn")
			else:
				get_tree().quit()
