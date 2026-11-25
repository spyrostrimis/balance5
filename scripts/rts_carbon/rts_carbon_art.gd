class_name RtsCarbonArt
extends RefCounted
## Carbon's Pixel art is shared by every battlefield variant.

const BASE_DIR := "res://assets/textures/rts/carbon/"


static func texture(key: String, pixel: bool, detailed_dir := "") -> Texture2D:
	var filename := key + ("_pixel.png" if pixel else "_hd.png")
	if not pixel:
		var painted := detailed_texture(key, detailed_dir)
		if painted != null:
			return painted
	return load(BASE_DIR + filename) as Texture2D


static func detailed_texture(key: String, directory: String) -> Texture2D:
	if directory.is_empty():
		return null
	var painted_path := directory.path_join(key + "_hd.png")
	return load(painted_path) as Texture2D if ResourceLoader.exists(painted_path, "Texture2D") else null
