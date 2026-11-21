class_name RifleBolt2D
extends Area2D
## Strictly horizontal rifle projectile (Streets of Rage 4 combat rule) carrying a dynamic PointLight2D.

const BOLT_BLUE_TEX := preload("res://assets/textures/rpg_2d/sprites/bolt_blue.png")
const HIT_SPARK_TEX := preload("res://assets/textures/rpg_2d/sprites/hit_spark.png")

@export var speed: float = 560.0
@export var max_distance: float = 760.0
@export var damage: int = 1

var direction: Vector2 = Vector2.RIGHT
var _traveled: float = 0.0
var _sprite: Sprite2D = null
var _light: PointLight2D = null
var _spent: bool = false


static func create_radial_light_texture(size: int = 128) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(0.75, 0.92, 1.0, 0.45), Color(0.0, 0.0, 0.0, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 8
	monitoring = true
	monitorable = false

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18.0, 10.0)
	shape.shape = rect
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture = BOLT_BLUE_TEX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.flip_h = direction.x < 0.0
	add_child(_sprite)

	_light = PointLight2D.new()
	_light.texture = create_radial_light_texture(96)
	_light.color = Color(0.45, 0.95, 1.0, 1.0)
	_light.energy = 1.45
	_light.texture_scale = 1.15
	_light.height = 18.0
	add_child(_light)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func configure(origin: Vector2, dir_x: int) -> void:
	var sign_x := -1 if dir_x < 0 else 1
	direction = Vector2(float(sign_x), 0.0)
	global_position = origin
	if _sprite != null:
		_sprite.flip_h = sign_x < 0


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var step := direction * speed * delta
	global_position += step
	_traveled += step.length()
	if _traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	# Cliff walls and boulders sit above ground, but bolt is at chest height (~55px) so only solid walls/tall outcrops or troopers stop it
	_spent = true
	if body.has_method("apply_hit"):
		body.call("apply_hit", damage, int(sign(direction.x)))
	_spawn_spark()
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _spent:
		return
	var target := area.get_parent()
	if target != null and target.has_method("apply_hit"):
		_spent = true
		target.call("apply_hit", damage, int(sign(direction.x)))
		_spawn_spark()
		queue_free()


func _spawn_spark() -> void:
	var host := get_parent()
	if host == null:
		return
	var fx := Node2D.new()
	fx.global_position = global_position
	var sp := Sprite2D.new()
	sp.texture = HIT_SPARK_TEX
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.add_child(sp)
	var lt := PointLight2D.new()
	lt.texture = create_radial_light_texture(96)
	lt.color = Color(1.0, 0.92, 0.68, 1.0)
	lt.energy = 1.65
	lt.texture_scale = 1.1
	lt.height = 18.0
	fx.add_child(lt)
	host.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(sp, "modulate:a", 0.0, 0.14)
	tw.parallel().tween_property(lt, "energy", 0.0, 0.14)
	tw.tween_callback(fx.queue_free)
