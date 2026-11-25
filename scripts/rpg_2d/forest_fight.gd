extends Node2D

signal entered_threshold
signal fight_started
signal bat_contacted(bat: Node2D)
signal shot_stopped(point: Vector2, target: Node2D)
signal cave_cleared

enum Stage { FOREST, THRESHOLD, INSIDE_DOOR, READY_RIFLE, FIGHT }

const Walk := preload("res://assets/scenes/forest_test/forest_walk.gd")
const Commander := preload("res://scripts/rpg_2d/forest_fight_commander.gd")
const Bat := preload("res://scripts/rpg_2d/forest_fight_bat.gd")
const MASK := preload("res://assets/shaders/rpg_2d/forest_fight_threshold.gdshader")
const SPARK := preload("res://assets/textures/rpg_2d/sprites/hit_spark.png")
const DOOR_X := 717.0
const THRESHOLD_Y := 440.0
const DOOR_HALF_WIDTH := 57.0
const CROSS_TIME := 0.63
const MOUTH_AREA := Rect2(-178, -217, 356, 243)
const REVERSE_TIME := 0.94
const READY_TIME := 0.33
const SPAWN := Vector2(438, Commander.MIDDLE_DEPTH)
const BAT_COUNT := 3
const SHOT_DEPTH := 30.0
const SHOT_BODY := Vector2(34, 30)
const LEFT_WALL := 39.0
const RIGHT_WALL := 1336.0

@export var mouth_art: Texture2D
@export var doorway_art: Texture2D
@export var chamber_art: Texture2D
@export var bat_art: Texture2D

var stage := Stage.FOREST
var bats: Array[Bat] = []
var killed := 0
var _elapsed := 0.0
var _door_mask: ShaderMaterial
var _rock_lip: Polygon2D
var _click_pending := false
var _blockout := false

@onready var forest: Walk = $Forest
@onready var mouth: Node2D = $Forest/Mouth
@onready var doorway: Node2D = $InsideDoor
@onready var doorway_pose: Sprite2D = $InsideDoor/Commander
@onready var doorway_shadow: Sprite2D = $InsideDoor/FootShadow
@onready var cave: Node2D = $Chamber
@onready var cave_camera: Camera2D = $Chamber/Camera
@onready var hero: Commander = $Chamber/Depth/Commander
@onready var actors: Node2D = $Chamber/Depth
@onready var curtain: ColorRect = $Overlay/Shadow
@onready var controls: Label = $Overlay/Controls
@onready var clear_message: Label = $Overlay/Clear


func _ready() -> void:
	forest.set_physics_process(false)
	forest.set_process_unhandled_key_input(false)
	forest._show_rough(false)
	get_window().title = "Balance · 2D Painted Forest Fight"
	hero.use_script_input = true
	hero.set_physics_process(false)
	hero.projectiles_parent = self
	_blockout = "--blockout" in OS.get_cmdline_user_args()
	if not _blockout:
		_set_plate(mouth, mouth_art, MOUTH_AREA)
		if mouth_art != null:
			_add_rock_lip()
		_set_plate(doorway, doorway_art, Rect2(Vector2.ZERO, Walk.Route.VIEW))
		_set_plate(cave, chamber_art, Rect2(Vector2.ZERO, Walk.Route.VIEW))


func _set_plate(layer: Node2D, texture: Texture2D, area: Rect2) -> void:
	if texture == null:
		return
	layer.get_node("Blockout").hide()
	var picture := Sprite2D.new()
	picture.z_index = -5 if layer != mouth else 0
	picture.texture = texture
	picture.centered = false
	picture.position = area.position
	picture.scale = area.size / texture.get_size()
	layer.add_child(picture)


func _add_rock_lip() -> void:
	# Resample the exterior painting on the traced underside of the roof.
	# While approaching, the Commander remains in front of the entire entrance.
	var outline := PackedVector2Array([
		Vector2(0.19, 0.16), Vector2(0.76, 0.15), Vector2(0.76, 0.42),
		Vector2(0.67, 0.38), Vector2(0.59, 0.32), Vector2(0.52, 0.315),
		Vector2(0.46, 0.35), Vector2(0.39, 0.39), Vector2(0.31, 0.48), Vector2(0.23, 0.54)
	])
	_rock_lip = Polygon2D.new()
	_rock_lip.position = MOUTH_AREA.position
	_rock_lip.z_index = 3
	_rock_lip.texture = mouth_art
	var polygon := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in outline:
		polygon.append(point * MOUTH_AREA.size)
		uv.append(point * mouth_art.get_size())
	_rock_lip.polygon = polygon
	_rock_lip.uv = uv
	_rock_lip.modulate.a = 0.0
	mouth.add_child(_rock_lip)


func _physics_process(delta: float) -> void:
	var fire := _click_pending or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_J)
	_click_pending = false
	step(forest._keyboard_direction(), fire, delta)


func step(movement: Vector2, fire: bool, delta: float) -> void:
	_elapsed += delta
	match stage:
		Stage.FOREST:
			var previous := forest.commander.position
			var near_mouth := absf(previous.x - DOOR_X) <= DOOR_HALF_WIDTH
			forest.step_walk(movement, delta, THRESHOLD_Y - 1.0 if near_mouth else THRESHOLD_Y)
			var boot := forest.commander.position
			if movement.y < 0.0 and previous.y >= THRESHOLD_Y and boot.y < THRESHOLD_Y:
				var crossing_x := lerpf(previous.x, boot.x, inverse_lerp(previous.y, boot.y, THRESHOLD_Y))
				if absf(crossing_x - DOOR_X) <= DOOR_HALF_WIDTH:
					_begin_threshold()
				else:
					forest.commander.position.y = THRESHOLD_Y
		Stage.THRESHOLD:
			forest.step_walk(Vector2(clampf((DOOR_X - forest.commander.position.x) * 0.02, -0.4, 0.4), -1),
				delta, THRESHOLD_Y - 100.0)
			var progress := clampf(_elapsed / CROSS_TIME, 0.0, 1.0)
			_door_mask.set_shader_parameter("passage", smoothstep(0.0, 1.0, progress))
			if _rock_lip != null:
				_rock_lip.modulate.a = smoothstep(0.30, 0.67, progress)
			forest.shadow.modulate.a = 0.62 * (1.0 - progress)
			_set_darkness(smoothstep(0.62, 1.0, progress))
			if progress >= 1.0:
				_show_inside_door()
		Stage.INSIDE_DOOR:
			var progress := clampf(_elapsed / REVERSE_TIME, 0.0, 1.0)
			doorway_pose.frame = 1 + int(_elapsed * 8.0) % 4
			doorway_pose.position = Vector2(545, 472).lerp(Vector2(606, 582), progress)
			doorway_pose.scale = Vector2.ONE * lerpf(0.65, 0.805, progress)
			doorway_pose.modulate = Color("b7a693").lerp(Color("939bb4"), progress)
			doorway_shadow.position = doorway_pose.position - Vector2(0.0, 4.0)
			_set_darkness(1.0 - smoothstep(0.0, 0.17, progress) + smoothstep(0.84, 1.0, progress))
			if progress >= 1.0:
				_show_chamber()
		Stage.READY_RIFLE:
			_set_darkness(1.0 - smoothstep(0.0, 0.20, _elapsed))
			if _elapsed >= READY_TIME:
				hero.set_mode(Hero2DController.Mode.COMBAT)
				hero.tick(Vector2.ZERO, delta)
				stage = Stage.FIGHT
				_elapsed = 0.0
				_show_message(controls, 4.0)
				fight_started.emit()
		Stage.FIGHT:
			hero.tick(movement, delta)
			for bat in bats:
				bat.tick(delta)
				if bat.try_contact(hero.position):
					_contact_flash()
					bat_contacted.emit(bat)
			if fire:
				hero.fire_horizontal_shot()


func _begin_threshold() -> void:
	stage = Stage.THRESHOLD
	_elapsed = 0.0
	_door_mask = ShaderMaterial.new()
	_door_mask.shader = MASK
	forest.pose.material = _door_mask
	entered_threshold.emit()


func _show_inside_door() -> void:
	stage = Stage.INSIDE_DOOR
	_elapsed = 0.0
	forest.hide()
	forest.camera.enabled = false
	cave_camera.enabled = true
	cave_camera.make_current()
	cave_camera.force_update_scroll()
	doorway.show()


func _show_chamber() -> void:
	stage = Stage.READY_RIFLE
	_elapsed = 0.0
	doorway.hide()
	cave.show()
	hero.position = SPAWN
	hero.facing_dir_8way = Vector2.RIGHT
	hero.tick(Vector2.ZERO, 1.0 / Engine.physics_ticks_per_second)
	for index in BAT_COUNT:
		var bat := Bat.new()
		bat.setup(index, null if _blockout else bat_art)
		bats.append(bat)
		actors.add_child(bat)


func trace_shot(start: Vector2, end_x: float, lane: float) -> Dictionary:
	var direction := signf(end_x - start.x)
	var wall := RIGHT_WALL if direction > 0.0 else LEFT_WALL
	# The muzzle can protrude into a wall near the walk limit.
	var stop := maxf(0.0, (wall - start.x) * direction)
	var target: Bat = null
	for bat in bats:
		if not bat.alive or absf(bat.position.y - lane) > SHOT_DEPTH:
			continue
		var height := absf(bat.body.y - start.y) / SHOT_BODY.y
		if height >= 1.0:
			continue
		var width := SHOT_BODY.x * sqrt(1.0 - height * height)
		var distance := (bat.body.x - start.x) * direction
		var entry := maxf(0.0, distance - width)
		if distance + width >= 0.0 and entry < stop:
			stop = entry
			target = bat
	if absf(end_x - start.x) < stop:
		return {}
	return {"x": start.x + direction * stop if target != null else wall, "target": target}


func stop_shot(hit: Dictionary, point: Vector2) -> void:
	var bat := hit.target as Bat
	shot_stopped.emit(point, bat)
	if bat == null:
		return
	bat.fall()
	killed += 1
	if killed == BAT_COUNT:
		_show_message(clear_message, 1.8)
		cave_cleared.emit()


func _contact_flash() -> void:
	var burst := Sprite2D.new()
	burst.texture = SPARK
	burst.modulate = Color(0.29, 0.77, 1.0)
	burst.position = Vector2(9 * hero.combat_facing, -178)
	burst.scale = Vector2.ONE * 2.1
	hero.add_child(burst)
	var animation := burst.create_tween().set_parallel()
	animation.tween_property(burst, "modulate:a", 0.0, 0.22)
	animation.tween_property(burst, "scale", Vector2.ONE * 0.85, 0.22)
	animation.chain().tween_callback(burst.queue_free)


func _set_darkness(alpha: float) -> void:
	curtain.color.a = clampf(alpha, 0.0, 1.0)


func _show_message(label: Label, seconds: float) -> void:
	label.show()
	label.modulate.a = 1.0
	var animation := label.create_tween()
	animation.tween_interval(seconds)
	animation.tween_property(label, "modulate:a", 0.0, 0.48)
	animation.tween_callback(label.hide)


func _unhandled_input(event: InputEvent) -> void:
	if stage == Stage.FIGHT and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click_pending = true
	if event.is_action_pressed("ui_cancel") and not get_node("/root/BuildLauncher").is_build_active():
		get_tree().quit()
