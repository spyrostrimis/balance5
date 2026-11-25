extends RifleBolt2D

var lane: float


func _ready() -> void:
	super._ready()
	monitoring = false
	collision_mask = 0
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2(1.65, 1.3)
	_light.energy = 0.8
	speed = 2100.0


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var next_x := global_position.x + direction.x * speed * delta
	var encounter := get_parent()
	var hit: Dictionary = encounter.trace_shot(global_position, next_x, lane)
	if hit.is_empty():
		global_position.x = next_x
		return
	_spent = true
	global_position.x = hit.x
	encounter.stop_shot(hit, global_position)
	_spawn_spark()
	queue_free()
