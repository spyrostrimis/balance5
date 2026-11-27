@tool
extends Line2D
## Keeps the sand-fade shader and trailing broken-stone EndCap attached to the last grip of an editable road Line2D.

@export var end_cap_path: NodePath

var _fade_end := Vector2.INF
var _fade_direction := Vector2.ZERO


func _ready() -> void:
	_sync_fade()
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	_sync_fade()


func _sync_fade() -> void:
	var count := get_point_count()
	if count < 2:
		return
	var finish := to_global(get_point_position(count - 1))
	var prev := to_global(get_point_position(count - 2))
	var direction := (finish - prev).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.DOWN
	if finish != _fade_end or direction != _fade_direction:
		var sm := material as ShaderMaterial
		if sm != null:
			sm.set_shader_parameter("end_point", finish)
			sm.set_shader_parameter("end_direction", direction)
		if not end_cap_path.is_empty():
			var cap := get_node_or_null(end_cap_path) as Node2D
			if cap != null:
				cap.global_position = finish - direction * 8.0
				cap.global_rotation = direction.angle()
		_fade_end = finish
		_fade_direction = direction
