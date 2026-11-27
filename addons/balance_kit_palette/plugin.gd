@tool
extends EditorPlugin
## Adds the "Kit Palette" dock (bottom-left, beside FileSystem).

const Dock := preload("res://addons/balance_kit_palette/kit_palette_dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.name = "Kit Palette"
	add_control_to_dock(DOCK_SLOT_LEFT_BR, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
