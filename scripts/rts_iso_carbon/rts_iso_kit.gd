class_name RtsIsoKit
extends RefCounted
## Loads and caches the modular Forest Claim Carbon asset catalog, split trunk/canopy
## textures, 8-direction isometric unit/tank atlases, and HUD unit portraits.

const TEX_DIR := "res://assets/textures/rts/forest_carbon/"
const PORTRAIT_MIASAKI_DIR := "res://assets/textures/rts/carbon_miasaki/"
const PORTRAIT_CARBON_DIR := "res://assets/textures/rts/carbon/"
const CATALOG_PATH := TEX_DIR + "kit_catalog.json"

static var _catalog: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func ensure_loaded() -> void:
	if not _catalog.is_empty():
		return
	if FileAccess.file_exists(CATALOG_PATH):
		var raw := FileAccess.get_file_as_string(CATALOG_PATH)
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary:
			_catalog = parsed


static func piece_meta(piece_id: String) -> Dictionary:
	ensure_loaded()
	return _catalog.get(piece_id, {}) as Dictionary


static func all_piece_ids() -> PackedStringArray:
	ensure_loaded()
	var out := PackedStringArray()
	for k in _catalog.keys():
		out.append(String(k))
	return out


static func texture(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name] as Texture2D
	var path := TEX_DIR + name + ".png"
	var tex := load(path) as Texture2D
	if tex != null:
		_tex_cache[name] = tex
	return tex


static func portrait(key: String) -> Texture2D:
	var cache_key := "portrait:" + key
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key] as Texture2D
	var p1 := PORTRAIT_MIASAKI_DIR + "portrait_" + key + "_hd.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(p1, "Texture2D"):
		tex = load(p1) as Texture2D
	if tex == null:
		var p2 := PORTRAIT_CARBON_DIR + "portrait_" + key + "_hd.png"
		if ResourceLoader.exists(p2, "Texture2D"):
			tex = load(p2) as Texture2D
	if tex != null:
		_tex_cache[cache_key] = tex
	return tex


## Returns blocked logical map cells for a placed module.
## Horizontal screen mirroring (flip_x) in true isometry swaps (du, dv) -> (dv, du)!
static func blocked_cells_for(piece_id: String, anchor_cell: Vector2i, flip_x := false) -> Array[Vector2i]:
	var meta := piece_meta(piece_id)
	var out: Array[Vector2i] = []
	var rel_list: Array = meta.get("blocked_cells", [])
	for item in rel_list:
		var du := int(item[0])
		var dv := int(item[1])
		var offset := Vector2i(dv, du) if flip_x else Vector2i(du, dv)
		var c := anchor_cell + offset
		if RtsIsoTransform.in_bounds(c):
			out.append(c)
	return out
