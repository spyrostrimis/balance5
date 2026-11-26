@tool
extends Line2D
## Keeps the sand fade attached to the last grip of the editable road line.

var _fade_end := Vector2.INF
var _fade_direction := Vector2.ZERO


func _ready() -> void:
	_sync_fade()
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	_sync_fade()


func _sync_fade() -> void:
	var shader_material := material as ShaderMaterial
	var count := get_point_count()
	if shader_material == null or count < 2:
		return
	var finish := get_point_position(count - 1)
	var direction := (finish - get_point_position(count - 2)).normalized()
	if finish != _fade_end or direction != _fade_direction:
		shader_material.set_shader_parameter("end_point", finish)
		shader_material.set_shader_parameter("end_direction", direction)
		_fade_end = finish
		_fade_direction = direction
