@tool
extends Path3D
## Authored canyon route. Edit the curve in the editor; the commander clamp, camera, ground shader
## and module layout all read it through center_x(z) and heading(z).
## The route must run monotonically along -Z (the walking direction).

signal route_changed

const LOOKUP_SIZE := 64

## Half the walkable corridor width in metres, measured from the route centre.
@export var half_width := 1.15

var _z: PackedFloat32Array = []
var _x: PackedFloat32Array = []


func _ready() -> void:
	if not curve_changed.is_connected(_rebuild):
		curve_changed.connect(_rebuild)
	_rebuild()


## Route centre X at world Z. Ends extend flat beyond the authored curve.
func center_x(z: float) -> float:
	if _z.is_empty():
		_rebuild()
	if _z.is_empty():
		return global_position.x
	if z <= _z[0]:
		return _x[0]
	var last := _z.size() - 1
	if z >= _z[last]:
		return _x[last]
	var hi := _z.bsearch(z)
	var lo := hi - 1
	var t := (z - _z[lo]) / maxf(_z[hi] - _z[lo], 0.0001)
	return lerpf(_x[lo], _x[hi], t)


## Slope of the chord across ±2 m.
func chord_slope(z: float) -> float:
	return (center_x(z + 2.0) - center_x(z - 2.0)) / 4.0


## Yaw that aligns a module's local Z axis with the route at z.
func heading(z: float) -> float:
	return atan(chord_slope(z))


func z_range() -> Vector2:
	if _z.is_empty():
		_rebuild()
	return Vector2(_z[0], _z[_z.size() - 1]) if not _z.is_empty() else Vector2.ZERO


## Writes an evenly spaced lookup into a ground material that declares the route_lookup uniforms.
func apply_to_material(material: ShaderMaterial) -> void:
	var span := z_range()
	var step := (span.y - span.x) / float(LOOKUP_SIZE - 1)
	var values := PackedFloat32Array()
	values.resize(LOOKUP_SIZE)
	for i in LOOKUP_SIZE:
		values[i] = center_x(span.x + step * float(i))
	material.set_shader_parameter("route_mode", 1)
	material.set_shader_parameter("route_lookup", values)
	material.set_shader_parameter("route_lookup_z0", span.x)
	material.set_shader_parameter("route_lookup_dz", step)


func _rebuild() -> void:
	_z = PackedFloat32Array()
	_x = PackedFloat32Array()
	if curve == null or curve.point_count < 2:
		return
	var points := curve.get_baked_points()
	var pairs: Array[Vector2] = []
	for p in points:
		var world := global_transform * p
		pairs.append(Vector2(world.z, world.x))
	pairs.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for pair in pairs:
		if not _z.is_empty() and is_equal_approx(pair.x, _z[_z.size() - 1]):
			continue
		_z.append(pair.x)
		_x.append(pair.y)
	route_changed.emit()
