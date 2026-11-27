extends SceneTree
## Windowed check of the Kit Palette dock outside the editor: loads every kit scene, renders all
## thumbnails, applies a tag filter and saves the dock as a PNG.
##   Godot_console.exe --path . --script res://tests/capture_kit_palette.gd

const Dock := preload("res://addons/balance_kit_palette/kit_palette_dock.gd")
const OUT := "res://render_captures/rts_mission_1/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := PanelContainer.new()
	panel.size = Vector2(560, 1000)
	root.add_child(panel)
	var dock := Dock.new()
	panel.add_child(dock)
	for _i in 240:
		await process_frame
		if dock._entries.size() > 0 and dock._entries.all(func(e: Dictionary) -> bool: return e["icon"] != null):
			break
	var missing := dock._entries.filter(func(e: Dictionary) -> bool: return e["icon"] == null).size()
	print("entries=", dock._entries.size(), " missing_icons=", missing, " items=", dock._list.item_count)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().get_region(Rect2i(0, 0, 560, 1000)).save_png(ProjectSettings.globalize_path(OUT + "kit_palette_all.png"))
	dock._active_tags = {"rock": true}
	dock._rebuild_tags()
	dock._apply_filter()
	print("rock filter items=", dock._list.item_count)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().get_region(Rect2i(0, 0, 560, 1000)).save_png(ProjectSettings.globalize_path(OUT + "kit_palette_rock.png"))
	var drag: Variant = dock._list._get_drag_data(dock._list.get_item_rect(0).get_center())
	print("drag data=", drag)
	quit(0 if missing == 0 else 1)
