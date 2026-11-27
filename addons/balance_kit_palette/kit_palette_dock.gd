@tool
extends VBoxContainer
## Kit Palette: every piece and group in the kit folders as a sand-backed thumbnail.
## - Click tag buttons to filter (several tags = must have all). Type to search names and tags.
## - Drag an item onto the 2D view to place it (select YSortWorld, Dunes or GroundDecals first).
## - Double-click to open the piece's own scene.
## Tags live on each scene's root as metadata "tags" (Inspector → Metadata), so add or change them there.

const FOLDERS := ["res://scenes/rts/desert_kit/pieces", "res://scenes/rts/desert_kit/groups"]
const DUNE_SHADER := preload("res://assets/shaders/rts_carbon_dune.gdshader")
const SAND := preload("res://assets/textures/rts/carbon/sand_tile_hd.png")
const THUMB := 104
const ItemListScript := preload("res://addons/balance_kit_palette/kit_item_list.gd")

var _entries: Array[Dictionary] = []
var _active_tags: Dictionary = {}
var _search: LineEdit
var _tag_box: HFlowContainer
var _list: ItemList
var _status: Label
var _render_generation := 0


func _ready() -> void:
	_build_ui()
	refresh()


func _build_ui() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	_search = LineEdit.new()
	_search.placeholder_text = "Search names and tags"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _apply_filter())
	top.add_child(_search)
	var reload := Button.new()
	reload.text = "Reload"
	reload.tooltip_text = "Rescan the kit folders (after adding a piece or changing tags)"
	reload.pressed.connect(refresh)
	top.add_child(reload)

	_tag_box = HFlowContainer.new()
	add_child(_tag_box)

	_list = ItemList.new()
	_list.set_script(ItemListScript)
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.max_columns = 0
	_list.same_column_width = true
	_list.fixed_column_width = THUMB + 12
	_list.fixed_icon_size = Vector2i(THUMB, THUMB)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(0, 260)
	_list.item_activated.connect(_open_item)
	add_child(_list)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	add_child(_status)


func refresh() -> void:
	_entries.clear()
	for folder in FOLDERS:
		var files := Array(DirAccess.get_files_at(folder))
		files.sort()
		for f: String in files:
			if not f.ends_with(".tscn"):
				continue
			var path: String = folder.path_join(f)
			var inst := (load(path) as PackedScene).instantiate()
			var tags := PackedStringArray(inst.get_meta("tags", PackedStringArray()))
			inst.free()
			_entries.append({"path": path, "name": f.get_basename(), "tags": tags,
				"group": folder.ends_with("groups"), "icon": null})
	_rebuild_tags()
	_apply_filter()
	_render_thumbnails()


func _rebuild_tags() -> void:
	for c in _tag_box.get_children():
		c.queue_free()
	var counts := {}
	for e in _entries:
		for t: String in e["tags"]:
			counts[t] = int(counts.get(t, 0)) + 1
	var names := counts.keys()
	names.sort()
	for t: String in names:
		var b := Button.new()
		b.toggle_mode = true
		b.flat = false
		b.text = "%s %d" % [t, counts[t]]
		b.button_pressed = _active_tags.has(t)
		b.add_theme_font_size_override("font_size", 11)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_active_tags[t] = true
			else:
				_active_tags.erase(t)
			_apply_filter())
		_tag_box.add_child(b)


func _matches(e: Dictionary) -> bool:
	var tags: PackedStringArray = e["tags"]
	for t in _active_tags:
		if not tags.has(t):
			return false
	var q := _search.text.strip_edges().to_lower()
	if q.is_empty():
		return true
	if String(e["name"]).to_lower().contains(q):
		return true
	for t in tags:
		if t.contains(q):
			return true
	return false


func _apply_filter() -> void:
	_list.clear()
	var shown := 0
	for e in _entries:
		if not _matches(e):
			continue
		var label: String = e["name"] + ("  ▣" if e["group"] else "")
		var idx := _list.add_item(label, e["icon"])
		_list.set_item_metadata(idx, e["path"])
		_list.set_item_tooltip(idx, "%s\nTags: %s\nDrag onto the 2D view to place. Double-click to open." % [e["path"], ", ".join(e["tags"])])
		shown += 1
	_status.text = "%d of %d shown (▣ = group). Drag onto the 2D view; select YSortWorld (upright), Dunes or GroundDecals (flat) first." % [shown, _entries.size()]


func _open_item(idx: int) -> void:
	EditorInterface.open_scene_from_path(String(_list.get_item_metadata(idx)))


## Draws every entry once in an offscreen viewport over sand, the way it looks in game.
func _render_thumbnails() -> void:
	_render_generation += 1
	var generation := _render_generation
	var vp := SubViewport.new()
	vp.size = Vector2i(THUMB * 2, THUMB * 2)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var sand := Sprite2D.new()
	sand.texture = SAND
	sand.centered = false
	sand.region_enabled = true
	sand.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sand.scale = Vector2(0.5, 0.5)
	sand.region_rect = Rect2(Vector2.ZERO, Vector2(vp.size) * 2.0)
	sand.z_index = -20
	vp.add_child(sand)
	var blank := ImageTexture.create_from_image(Image.create_empty(4, 4, false, Image.FORMAT_L8))

	for e in _entries:
		if generation != _render_generation or not is_inside_tree():
			break
		var inst := (load(e["path"]) as PackedScene).instantiate() as Node2D
		vp.add_child(inst)
		var pieces: Array[RtsCarbonPiece] = []
		_collect(inst, pieces)
		var bounds := Rect2()
		for i in pieces.size():
			var p := pieces[i]
			var centre := p.global_position + p.draw_offset * p.global_scale
			var size := p.world_size * p.global_scale.abs()
			var r := Rect2(centre - size * 0.5, size)
			bounds = r if i == 0 else bounds.merge(r)
		var fit := minf(1.6, (float(vp.size.x) - 10.0) / maxf(1.0, maxf(bounds.size.x, bounds.size.y)))
		inst.scale = Vector2(fit, fit)
		inst.position = Vector2(vp.size) * 0.5 - bounds.get_center() * fit
		for p in pieces:
			p.apply_visual_mode(false, DUNE_SHADER, SAND, blank, blank, Vector2(1408, 896), false, "", false)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if generation != _render_generation:
			break
		var img := vp.get_texture().get_image()
		img.resize(THUMB, THUMB, Image.INTERPOLATE_LANCZOS)
		e["icon"] = ImageTexture.create_from_image(img)
		inst.queue_free()
		for idx in _list.item_count:
			if _list.get_item_metadata(idx) == e["path"]:
				_list.set_item_icon(idx, e["icon"])
	vp.queue_free()


func _collect(n: Node, out: Array[RtsCarbonPiece]) -> void:
	var p := n as RtsCarbonPiece
	if p != null:
		out.append(p)
	for c in n.get_children():
		_collect(c, out)
