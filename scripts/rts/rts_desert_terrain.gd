class_name RtsDesertTerrain
extends Node2D
## Shared layout and effects data beneath the two visual treatments.

const ART := "res://assets/textures/rts/desert_proof/"
const CELL := 32
const WORLD_SIZE := Vector2i(768, 544)
const DUNE_SURFACE := preload("res://assets/shaders/rts/desert_tread_surface.gdshader")

var painted := true
var disturbed_pixels := 0
var _pieces: Array[RtsDesertPiece] = []
var _relief: Array[RtsDesertPiece] = []
var _shade: Array[RtsDesertPiece] = []
var _textures := {}
var _sand: Texture2D
var _shadow: Texture2D
var _treads: Image
var _tread_texture: ImageTexture
var _dune_material := ShaderMaterial.new()
var _track_dirty := false
var _clock := 0.0


func prepare(grid: RtsGrid) -> void:
	for item in find_children("*", "", true, false):
		if item is RtsDesertPiece:
			_pieces.append(item)
			if item.relief_height > 0.0:
				_relief.append(item)
			if item.shade_strength > 0.0:
				_shade.append(item)
	var mask := Image.create_empty(WORLD_SIZE.x / CELL, WORLD_SIZE.y / CELL, false, Image.FORMAT_L8)
	for y in mask.get_height():
		for x in mask.get_width():
			var center := Vector2(x * CELL, y * CELL) + Vector2.ONE * (CELL * 0.5)
			for piece in _pieces:
				if piece.covers(center):
					mask.set_pixel(x, y, Color.WHITE)
					break
	grid.blocked_cells = ImageTexture.create_from_image(mask)
	_treads = Image.create_empty(WORLD_SIZE.x, WORLD_SIZE.y, false, Image.FORMAT_L8)
	_tread_texture = ImageTexture.create_from_image(_treads)
	_dune_material.shader = DUNE_SURFACE
	_dune_material.set_shader_parameter("treads", _tread_texture)
	_dune_material.set_shader_parameter("world_size", Vector2(WORLD_SIZE))
	for piece in _relief:
		piece.material = _dune_material


func _ready() -> void:
	$Shadows.draw.connect(_draw_shadows)
	apply_art(true)


func apply_art(is_painted: bool) -> void:
	painted = is_painted
	texture_filter = TEXTURE_FILTER_LINEAR if painted else TEXTURE_FILTER_NEAREST
	_sand = _load_art("sand")
	_shadow = _load_art("shadow")
	for path: Line2D in $Road.get_children():
		if path.texture_mode == Line2D.LINE_TEXTURE_TILE:
			path.texture = _load_art("paving")
	for piece in _pieces:
		piece.texture = _load_art(piece.art)
		piece.queue_redraw()
	_dune_material.set_shader_parameter("pixel_art", not painted)
	$Shadows.queue_redraw()
	queue_redraw()


func _load_art(key: String) -> Texture2D:
	var file := key + ("_hd.png" if painted else "_pixel.png")
	if not _textures.has(file):
		_textures[file] = load(ART + file)
	return _textures[file]


func _draw() -> void:
	if _sand != null:
		var density := 2.0 if painted else 1.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / density)
		draw_texture_rect(_sand, Rect2(Vector2.ZERO, Vector2(WORLD_SIZE) * density), true)
		draw_set_transform(Vector2.ZERO)


func _draw_shadows() -> void:
	if _shadow == null:
		return
	var shadows: Node2D = $Shadows
	for piece in _shade:
		var center := shadows.to_local(piece.to_global(piece.shade_offset))
		shadows.draw_texture_rect(_shadow, Rect2(center - piece.shade_size * 0.5, piece.shade_size),
			false, Color(1, 1, 1, piece.shade_strength))


func height_at(point: Vector2) -> float:
	var height := 0.0
	for piece in _relief:
		height = maxf(height, piece.height_at(point))
	return height


func grade_at(point: Vector2, direction: Vector2) -> float:
	return (height_at(point + direction * 6.0) - height_at(point - direction * 6.0)) / 12.0


func shade_at(point: Vector2) -> float:
	var light := 1.0
	for piece in _shade:
		light *= 1.0 - piece.shade_at(point) * 0.60
	return clampf(light, 0.54, 1.0)


func add_treads(previous: Vector2, previous_heading: Vector2, next: Vector2, heading: Vector2) -> void:
	for side in [-6.0, 6.0]:
		var a := previous - previous_heading * 6.0 + previous_heading.orthogonal() * float(side)
		var b := next - heading * 6.0 + heading.orthogonal() * float(side)
		var low := Vector2i((a.min(b) - Vector2.ONE * 4.0).floor()).max(Vector2i.ZERO)
		var high := Vector2i((a.max(b) + Vector2.ONE * 4.0).ceil()).min(WORLD_SIZE)
		for y in range(low.y, high.y):
			for x in range(low.x, high.x):
				var point := Vector2(x + 0.5, y + 0.5)
				if height_at(point) < 0.18:
					continue
				var nearest := Geometry2D.get_closest_point_to_segment(point, a, b)
				var strength := 1.0 - smoothstep(1.1, 3.3, nearest.distance_to(point))
				var old := _treads.get_pixel(x, y).r
				if strength > old + 0.01:
					if old == 0.0:
						disturbed_pixels += 1
					_treads.set_pixel(x, y, Color(strength, 0, 0))
					_track_dirty = true


func _process(delta: float) -> void:
	_clock += delta
	if _track_dirty and _clock >= 0.05:
		_tread_texture.update(_treads)
		_track_dirty = false
		_clock = 0.0


func refresh_effects() -> void:
	_dune_material.set_shader_parameter("show_treads", RtsLook.marks)
