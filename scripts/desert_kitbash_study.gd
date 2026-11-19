extends Control
## Renders and previews two modular 185x102 desert kitbash samples assembled via TileMapLayer + Sprite2D stamps.

const OUT_SAMPLE_1 := "res://assets/textures/maps/desert_kitbash_sample_1.png"
const OUT_SAMPLE_2 := "res://assets/textures/maps/desert_kitbash_sample_2.png"

@onready var _vp1: SubViewport = $Sample1Viewport
@onready var _vp2: SubViewport = $Sample2Viewport


func _ready() -> void:
	_populate_sand_layer($Sample1Viewport/SandBaseLayer, 0, 0)
	_populate_sand_layer($Sample2Viewport/SandBaseLayer, 2, 1)

	var preview1 := get_node_or_null("Layout/Columns/Sample1Col/Sample1Preview") as TextureRect
	var preview2 := get_node_or_null("Layout/Columns/Sample2Col/Sample2Preview") as TextureRect
	if preview1 != null:
		preview1.texture = _vp1.get_texture()
	if preview2 != null:
		preview2.texture = _vp2.get_texture()

	if "--export-samples" in OS.get_cmdline_user_args():
		call_deferred("_export_and_quit")


func _populate_sand_layer(layer: TileMapLayer, offset_x: int, offset_y: int) -> void:
	layer.clear()
	for r in range(4):
		for c in range(6):
			var atlas_coords := Vector2i((c + offset_x) % 4, (r + offset_y) % 4)
			layer.set_cell(Vector2i(c, r), 0, atlas_coords)


func _export_and_quit() -> void:
	for _i in range(6):
		await get_tree().process_frame

	var ok1 := _save_viewport(_vp1, OUT_SAMPLE_1)
	var ok2 := _save_viewport(_vp2, OUT_SAMPLE_2)
	if ok1 and ok2:
		print("SUCCESS: Exported both 185x102 kitbash samples.")
		get_tree().quit(0)
	else:
		push_error("FAILED exporting kitbash samples.")
		get_tree().quit(1)


func _save_viewport(vp: SubViewport, path: String) -> bool:
	var img := vp.get_texture().get_image()
	if img == null:
		push_error("Null viewport image for " + path)
		return false
	if img.get_width() != 185 or img.get_height() != 102:
		push_error("Unexpected size %dx%d for %s" % [img.get_width(), img.get_height(), path])
		return false
	var err := img.save_png(path)
	if err != OK:
		push_error("Failed saving %s: %s" % [path, error_string(err)])
		return false
	print("Saved %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	return true
