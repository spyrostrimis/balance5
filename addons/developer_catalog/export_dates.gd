@tool
extends EditorPlugin


class CatalogDatesExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "DeveloperCatalogDates"

	func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
		var opening := load("res://scenes/ui/opening_screen.tscn") as PackedScene
		var state := opening.get_state()
		var dates := ConfigFile.new()
		for index in state.get_node_property_count(0):
			if state.get_node_property_name(0, index) != &"builds":
				continue
			for build: DeveloperBuild in state.get_node_property_value(0, index):
				if build != null and build.listed and not build.scene_path.is_empty():
					dates.set_value("dates", build.scene_path, build.build_time())
			break
		add_file("res://developer_build_dates.cfg", dates.encode_to_text().to_utf8_buffer(), false)


var _exporter := CatalogDatesExport.new()


func _enter_tree() -> void:
	add_export_plugin(_exporter)


func _exit_tree() -> void:
	remove_export_plugin(_exporter)
