@tool
extends ItemList
## Lets a palette item be dragged like a file from the FileSystem dock, so dropping it on the
## 2D view instances the scene under the selected node at the drop point.


func _get_drag_data(at_position: Vector2) -> Variant:
	var idx := get_item_at_position(at_position, true)
	if idx < 0:
		return null
	var preview := TextureRect.new()
	preview.texture = get_item_icon(idx)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(72, 72)
	preview.size = Vector2(72, 72)
	set_drag_preview(preview)
	return {"type": "files", "files": [String(get_item_metadata(idx))], "from": self}
