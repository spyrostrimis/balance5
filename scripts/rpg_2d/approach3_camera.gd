extends PixelCamera2D
## Preserve fractional follow and put the final canvas origin on render pixels.

@export var lookout_lead := 180.0


func _ready() -> void:
	super._ready()
	process_priority = -10


func _process(delta: float) -> void:
	if _target == null:
		return
	var weight := 1.0 - exp(-follow_smooth * delta)
	_logical_pos = _logical_pos.lerp(_lookout_focus(), weight)
	_apply_clamped_snapped_pos()
	force_update_scroll()


func snap_immediately() -> void:
	if _target != null:
		_logical_pos = _lookout_focus()
	_apply_clamped_snapped_pos()
	force_update_scroll()


func _lookout_focus() -> Vector2:
	var focus := _target.global_position
	focus.y -= lookout_lead * (1.0 - smoothstep(360.0, 630.0, focus.y))
	# Hold the gate in frame as the upper bend opens out.
	return focus


func snap_position(point: Vector2) -> Vector2:
	var half_picture := _viewport_size * 0.5
	return ((point * zoom - half_picture).round() + half_picture) / zoom
