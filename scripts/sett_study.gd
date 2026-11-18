extends Node3D

enum Sample { CONTROL, FLAT, RAISED }

@export var initial_sample: Sample = Sample.RAISED

const PATCH_MIN := Vector2(-0.08, 6.45)
const PATCH_SIZE := Vector2(1.2, 1.0)
const STUDY_SHADER := preload("res://assets/shaders/sett_study.gdshader")
const PAINT := preload("res://assets/textures/canyon_pbr/sett_study_albedo.png")
const FLAT_NORMAL := preload("res://assets/textures/canyon_pbr/sett_study_flat_normal.png")
const GRAIN_NORMAL := preload("res://assets/textures/canyon_pbr/sett_study_grain_normal.png")

@onready var ground: MeshInstance3D = $"../GroundFloorMesh"
@onready var hero: Node3D = $"../BlueCommander"
@onready var relief: MeshInstance3D = $StoneInsert/RoadSample

var surround := Node3D.new()
var flat_insert := MeshInstance3D.new()
var paint_material := ShaderMaterial.new()


func _ready() -> void:
	add_child(surround)
	var plane := ground.mesh as PlaneMesh
	var centre := Vector2(ground.position.x, ground.position.z)
	var low := centre - plane.size / 2.0
	var high := centre + plane.size / 2.0
	var end := PATCH_MIN + PATCH_SIZE
	_add_floor(low, Vector2(high.x, PATCH_MIN.y))
	_add_floor(Vector2(low.x, end.y), high)
	_add_floor(Vector2(low.x, PATCH_MIN.y), Vector2(PATCH_MIN.x, end.y))
	_add_floor(Vector2(end.x, PATCH_MIN.y), Vector2(high.x, end.y))
	paint_material.shader = STUDY_SHADER
	paint_material.set_shader_parameter("paint", PAINT)
	paint_material.set_shader_parameter("flat_normals", FLAT_NORMAL)
	paint_material.set_shader_parameter("grain_normals", GRAIN_NORMAL)
	paint_material.set_shader_parameter("player_pos", hero.global_position)
	relief.material_override = paint_material
	var patch_centre := PATCH_MIN + PATCH_SIZE / 2.0
	var flat_plane := PlaneMesh.new()
	flat_plane.size = PATCH_SIZE
	flat_insert.mesh = flat_plane
	flat_insert.position = Vector3(patch_centre.x, ground.position.y, patch_centre.y)
	flat_insert.material_override = paint_material
	add_child(flat_insert)
	_show_sample(initial_sample)


func _add_floor(low: Vector2, high: Vector2) -> void:
	var section := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = high - low
	section.mesh = plane
	var centre := (low + high) / 2.0
	section.position = Vector3(centre.x, ground.position.y, centre.y)
	section.material_override = ground.get_surface_override_material(0)
	surround.add_child(section)


func _show_sample(sample: Sample) -> void:
	ground.visible = sample == Sample.CONTROL
	surround.visible = sample != Sample.CONTROL
	flat_insert.visible = sample == Sample.FLAT
	relief.visible = sample == Sample.RAISED
	paint_material.set_shader_parameter("flat_sample", sample == Sample.FLAT)


func _physics_process(_delta: float) -> void:
	paint_material.set_shader_parameter("player_pos", hero.global_position)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _show_sample(Sample.CONTROL)
			KEY_2: _show_sample(Sample.FLAT)
			KEY_3: _show_sample(Sample.RAISED)
			_: return
		get_viewport().set_input_as_handled()

