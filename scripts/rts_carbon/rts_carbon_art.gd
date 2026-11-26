class_name RtsCarbonArt
extends RefCounted
## Variants can supply local art and inherit the rest from Carbon.

const BASE_DIR := "res://assets/textures/rts/carbon/"


static func texture(key: String, pixel: bool, detailed_dir := "") -> Texture2D:
	var filename := key + ("_pixel.png" if pixel else "_hd.png")
	if not detailed_dir.is_empty():
		var local_path := detailed_dir.path_join(filename)
		if ResourceLoader.exists(local_path, "Texture2D"):
			return load(local_path) as Texture2D
	return load(BASE_DIR + filename) as Texture2D


static func detailed_texture(key: String, directory: String) -> Texture2D:
	if directory.is_empty():
		return null
	var painted_path := directory.path_join(key + "_hd.png")
	return load(painted_path) as Texture2D if ResourceLoader.exists(painted_path, "Texture2D") else null
