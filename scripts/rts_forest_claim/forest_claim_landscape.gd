class_name ForestClaimLandscape
extends Node2D

const GROUND_SHADER := preload("res://assets/shaders/forest_claim_ground.gdshader")
const HAZE_SHADER := preload("res://assets/shaders/forest_claim_haze.gdshader")
const EARTH := preload("res://assets/textures/rts/forest_claim/earth.webp")
const FLOOR := preload("res://assets/textures/rts/forest_claim/forest_floor.webp")
const CLIFF_COOL := preload("res://assets/textures/rts/forest_claim/cliff_cool.webp")
const CLIFF_WARM := preload("res://assets/textures/rts/forest_claim/cliff_warm.webp")
const SOFT_SHADOW := preload("res://assets/textures/rts/carbon/soft_shadow.png")

var layout: ForestClaimLayout
var occupied := {}
var scenery: Array[Dictionary] = []
var objective := Vector2.ZERO
var _textures := {}
var _tree_alpha := {}
var _cliff_polygons: Array[PackedVector2Array] = []


func build(data: ForestClaimLayout, depth_sort: Node2D) -> void:
	layout = data
	var extent := layout.size()
	var terrain_map := Image.create_empty(extent.x, extent.y, false, Image.FORMAT_RGBA8)
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			var tile := layout.tile(cell)
			if tile in ["~", "#"]:
				occupied[cell] = "cliff"
			terrain_map.set_pixelv(cell, Color(1.0 if tile == "." else 0.0, 1.0 if tile == "#" else 0.0, 0.0))

	var ground_material := ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground_material.set_shader_parameter("earth_tex", EARTH)
	ground_material.set_shader_parameter("forest_tex", FLOOR)
	ground_material.set_shader_parameter("terrain", ImageTexture.create_from_image(terrain_map))
	ground_material.set_shader_parameter("map_size", Vector2(extent))

	var backdrop := ColorRect.new()
	backdrop.position = Vector2(-1800, -730)
	backdrop.size = Vector2(3700, 1900)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var haze := ShaderMaterial.new()
	haze.shader = HAZE_SHADER
	backdrop.material = haze
	add_child(backdrop)
	_add_ravine_canopy()
	var mist := backdrop.duplicate() as ColorRect
	mist.position = Vector2(-620, -140)
	mist.size = Vector2(1370, 920)
	var veil := haze.duplicate() as ShaderMaterial
	veil.set_shader_parameter("veil", true)
	mist.material = veil
	add_child(mist)

	var drop := Node2D.new()
	drop.name = "ShelfFaces"
	drop.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(drop)
	var ground := Node2D.new()
	ground.name = "ShelfFloor"
	ground.material = ground_material
	add_child(ground)
	var shadow := Node2D.new()
	add_child(shadow)
	shadow.draw.connect(_draw_shadows.bind(shadow))

	var shelf: Array[Vector2i] = []
	var drops: Array[Vector2i] = []
	for y in extent.y:
		for x in extent.x:
			var cell := Vector2i(x, y)
			var height := layout.height(cell)
			if height == 0.0:
				shelf.append(cell)
				if layout.height(cell + Vector2i.RIGHT) < 0.0 or layout.height(cell + Vector2i.DOWN) < 0.0:
					drops.append(cell)
					_cache_cliff_hit(cell)
			elif height > 0.0:
				_cache_cliff_hit(cell)
				_cliff_polygons.append(_top_points(cell))
				_add_raised_cell(depth_sort, cell, ground_material)
	ground.draw.connect(_draw_tops.bind(ground, shelf))
	drop.draw.connect(_draw_drops.bind(drop, drops))

	for placement in layout.scenery:
		var piece := String(placement.piece)
		var at := Vector2(placement.at) * ForestClaimProjection.CELL
		var cell := Vector2i((at / ForestClaimProjection.CELL).floor())
		assert(ForestClaimKit.PIECES.has(piece) and layout.tile(cell) != "~", "Scenery must have a module and ground contact: %s" % placement)
		for solid in ForestClaimKit.occupied_cells(piece, cell):
			if not occupied.has(solid):
				occupied[solid] = piece
		var height := layout.height(cell)
		var size_factor := float(placement.scale)
		var tex := _texture(piece)
		var rect := ForestClaimKit.sprite_rect(piece, tex, size_factor)
		var anchor := ForestClaimProjection.point(at, height)
		var depth := _piece_depth(at, cell, height)
		var art := Sprite2D.new()
		art.name = piece
		art.texture = tex
		art.centered = false
		art.offset = (rect.position + anchor - depth) / (rect.size.x / tex.get_width())
		art.scale = Vector2.ONE * (rect.size.x / tex.get_width())
		art.position = depth
		depth_sort.add_child(art)
		scenery.append({"piece": piece, "at": at, "anchor": anchor, "depth": depth,
			"rect": Rect2(rect.position + anchor, rect.size), "art": art, "height": height})
		if piece == "orichalcum":
			objective = at


func _texture(piece: String) -> Texture2D:
	if not _textures.has(piece):
		_textures[piece] = ForestClaimKit.sprite_texture(piece)
	return _textures[piece]


func covers(instance: Dictionary, world: Vector2) -> bool:
	var unit := ForestClaimProjection.point(world)
	if Vector2(instance.depth).y < unit.y:
		return false
	var rect: Rect2 = instance.rect
	var sample := unit - Vector2(0, 11)
	if not rect.has_point(sample):
		return false
	var piece: String = instance.piece
	if not _tree_alpha.has(piece):
		_tree_alpha[piece] = _texture(piece).get_image()
	var mask: Image = _tree_alpha[piece]
	var pixel := Vector2i((sample - rect.position) / rect.size * Vector2(mask.get_size()))
	return mask.get_pixelv(pixel).a > 0.56


func _add_ravine_canopy() -> void:
	var far_forest := Node2D.new()
	far_forest.name = "CanopyBelowShelf"
	far_forest.y_sort_enabled = true
	add_child(far_forest)
	var extent := layout.size()
	var random := RandomNumberGenerator.new()
	random.seed = 7313
	for y in range(-10, extent.y + 12, 2):
		for x in range(-10, extent.x + 12, 2):
			var cell := Vector2(x + random.randf(), y + random.randf())
			if x > 2 and y > 1 and x < extent.x - 4 and y < extent.y - 6:
				continue
			var distance_from_shelf := maxf(maxf(-cell.x, -cell.y),
				maxf(cell.x - extent.x, cell.y - extent.y))
			var piece: String = ForestClaimKit.TREES[random.randi_range(0, ForestClaimKit.TREES.size() - 1)]
			var canopy := Sprite2D.new()
			canopy.texture = _texture(piece)
			canopy.centered = false
			var rect := ForestClaimKit.sprite_rect(piece, canopy.texture, random.randf_range(0.61, 1.18))
			var factor := rect.size.x / canopy.texture.get_width()
			canopy.scale = Vector2.ONE * factor
			canopy.offset = rect.position / factor
			var depth := -270.0 if distance_from_shelf < 0.0 else -224.0
			canopy.position = ForestClaimProjection.point(cell * ForestClaimProjection.CELL, depth + random.randf_range(-24, 24))
			var tint := random.randf_range(0.76, 1.18)
			canopy.modulate = Color(0.39 * tint, 0.60 * tint, 0.74 * tint, 0.91)
			far_forest.add_child(canopy)


func _piece_depth(at: Vector2, cell: Vector2i, height: float) -> Vector2:
	if height > 0.0:
		# A tree rooted atop a ridge sorts just after the ridge's front foot.
		return Vector2(ForestClaimProjection.point(at).x, _raised_depth(cell).y + 0.25)
	return ForestClaimProjection.point(at)


func _raised_depth(cell: Vector2i) -> Vector2:
	return ForestClaimProjection.point((Vector2(cell) + Vector2.ONE) * ForestClaimProjection.CELL)


func _add_raised_cell(parent: Node2D, cell: Vector2i, material: ShaderMaterial) -> void:
	var piece := Node2D.new()
	piece.position = _raised_depth(cell)
	piece.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	parent.add_child(piece)
	piece.draw.connect(_draw_face_pair.bind(piece, cell, piece.position))
	var top := Node2D.new()
	top.material = material
	piece.add_child(top)
	top.draw.connect(_draw_top.bind(top, cell, piece.position))


func _draw_tops(canvas: Node2D, cells: Array[Vector2i]) -> void:
	for cell in cells:
		_draw_top(canvas, cell, Vector2.ZERO)


func _top_points(cell: Vector2i, origin := Vector2.ZERO) -> PackedVector2Array:
	var h := layout.height(cell)
	var points := PackedVector2Array()
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
		points.append(_vertex(cell + offset, h) - origin)
	return points


func _draw_top(canvas: Node2D, cell: Vector2i, origin: Vector2) -> void:
	var uv := PackedVector2Array()
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
		uv.append(Vector2(cell + offset) / Vector2(layout.size()))
	canvas.draw_polygon(_top_points(cell, origin), PackedColorArray([Color.WHITE]), uv)


func _face_points(cell: Vector2i, side: Vector2i, origin := Vector2.ZERO) -> PackedVector2Array:
	var top := layout.height(cell)
	var bottom := layout.height(cell + side)
	var a := cell + side
	var b := a + (Vector2i.DOWN if side == Vector2i.RIGHT else Vector2i.RIGHT)
	return PackedVector2Array([_vertex(a, top) - origin, _vertex(b, top) - origin,
		_vertex(b, bottom) - origin, _vertex(a, bottom) - origin])


func _cache_cliff_hit(cell: Vector2i) -> void:
	for side: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		if layout.height(cell) > layout.height(cell + side):
			_cliff_polygons.append(_face_points(cell, side))


func hits_cliff(iso: Vector2) -> bool:
	for polygon in _cliff_polygons:
		if Geometry2D.is_point_in_polygon(iso, polygon):
			return true
	return false


func _draw_drops(canvas: Node2D, cells: Array[Vector2i]) -> void:
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
	for cell in cells:
		_draw_face_pair(canvas, cell, Vector2.ZERO)


func _draw_face_pair(canvas: Node2D, cell: Vector2i, origin: Vector2) -> void:
	for side: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		var h := layout.height(cell)
		var below := layout.height(cell + side)
		if h <= below:
			continue
		var along := Vector2i.DOWN if side == Vector2i.RIGHT else Vector2i.RIGHT
		var a := cell + side
		var tex := CLIFF_WARM if side == Vector2i.DOWN else CLIFF_COOL
		var start := (float(a.x * along.x + a.y * along.y) + 0.37 * float(a.x * side.x + a.y * side.y)) / 3.9
		# One repeating strip per axis, with shared corners and consistent stone size.
		var finish := start + 1.0 / 3.9
		var depth_uv := clampf((h - below) / 144.0, 0.46, 1.0)
		var rim := Color(1.0, 1.0, 0.92) if side == Vector2i.DOWN else Color(0.83, 0.93, 0.98)
		var foot := Color(0.81, 0.92, 0.97) if below == 0.0 else Color(0.57, 0.81, 0.89)
		canvas.draw_polygon(_face_points(cell, side, origin), PackedColorArray([rim, rim, foot, foot]),
			PackedVector2Array([Vector2(start, 0), Vector2(finish, 0),
				Vector2(finish, depth_uv), Vector2(start, depth_uv)]), tex)


func _vertex(cell: Vector2i, height: float) -> Vector2:
	# Shared perturbed vertices hold straight sections, turns and end caps together.
	var bend := Vector2(sin(cell.x * 7.75 + cell.y * 9.21), cos(cell.x * 11.9 - cell.y * 8.7))
	var profile := height
	if height > 0.0:
		profile += 5.5 * sin(cell.x * 4.1 + cell.y * 9.2)
	elif height < 0.0:
		profile += 10.0 * sin(cell.x * 6.5 - cell.y * 8.9)
	return ForestClaimProjection.point(Vector2(cell) * ForestClaimProjection.CELL + bend * 3.8, profile)


func _draw_shadows(canvas: Node2D) -> void:
	for instance in scenery:
		var contact := Vector2(instance.anchor)
		var rect: Rect2 = instance.rect
		var tree: bool = ForestClaimKit.PIECES[instance.piece].tree
		var size := Vector2(rect.size.x * (0.88 if tree else 0.90), rect.size.y * (0.27 if tree else 0.28))
		var shift := Vector2(size.x * 0.27, size.y * 0.26)
		var tint := Color(0.32, 0.40, 0.32, 0.65 if tree else 0.51)
		if instance.height > 0.0:
			continue
		canvas.draw_texture_rect(SOFT_SHADOW, Rect2(contact + shift - size * 0.5, size), false, tint)
		canvas.draw_texture_rect(SOFT_SHADOW, Rect2(contact - size * 0.27, size * 0.54), false, Color(0.37, 0.42, 0.28, 0.70))


func blocked_image() -> ImageTexture:
	var extent := layout.size()
	var mask := Image.create_empty(extent.x, extent.y, false, Image.FORMAT_RGBA8)
	mask.fill(Color.BLACK)
	for cell: Vector2i in occupied:
		if Rect2i(Vector2i.ZERO, extent).has_point(cell):
			mask.set_pixelv(cell, Color.WHITE)
	return ImageTexture.create_from_image(mask)


func minimap(bounds: Rect2) -> ImageTexture:
	var image := Image.create_empty(216, 124, false, Image.FORMAT_RGBA8)
	var size := Vector2(image.get_size())
	for y in image.get_height():
		for x in image.get_width():
			var iso := bounds.position + (Vector2(x, y) + Vector2(0.5, 0.5)) / size * bounds.size
			var logical := ForestClaimProjection.world(iso)
			var cell := Vector2i((logical / ForestClaimProjection.CELL).floor())
			var color := Color("#162d31")
			match layout.tile(cell):
				"m": color = Color("#6d8151")
				".": color = Color("#bf9b57")
				"#": color = Color("#49564b")
			if occupied.get(cell) in ForestClaimKit.TREES:
				color = Color("#2a4a37")
			elif occupied.get(cell) in ["boulder", "rocks"]:
				color = Color("#595a46")
			if logical.distance_to(objective) < 26.0:
				color = Color("#ffca54")
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func shade(world: Vector2) -> float:
	var point := ForestClaimProjection.point(world)
	var result := 0.0
	for instance in scenery:
		if not ForestClaimKit.PIECES[instance.piece].tree or instance.height > 0.0:
			continue
		var rect: Rect2 = instance.rect
		var offset := point - Vector2(instance.anchor) - Vector2(22.0, 8.0)
		var distance := (offset / Vector2(rect.size.x * 0.43, rect.size.y * 0.19)).length()
		result = maxf(result, 0.37 * (1.0 - smoothstep(0.07, 1.0, distance)))
	return result
