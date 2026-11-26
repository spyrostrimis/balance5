@tool
extends RtsCarbonPiece
## Keeps a flagstone fork hub aligned with the start point of an editable branch Line2D.

@export var spur_path: NodePath
@export var throat_offset := Vector2(12.0, 14.0)

var _last_origin := Vector2.INF


func _ready() -> void:
	_sync_fork()
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	_sync_fork()


func _sync_fork() -> void:
	if spur_path.is_empty():
		return
	var spur := get_node_or_null(spur_path) as Line2D
	if spur == null or spur.get_point_count() < 2:
		return
	var p0 := spur.to_global(spur.get_point_position(0)) + throat_offset
	if p0 != _last_origin:
		global_position = p0
		_last_origin = p0
		queue_redraw()
