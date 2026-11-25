extends RefCounted
## Coordinates on the full painting, with north toward smaller Y.

const CANVAS := Vector2(1536, 2048)
const VIEW := Vector2(1376, 768)
const START_Y := 1720.0
const SOUTH_Y := 1780.0
const NORTH_Y := 440.0
const BOUNDARIES: Array[float] = [340.0, 650.0, 990.0]
const FEATHER := 48.0
const START_HEIGHT := 153.6
const FIRST_DROP := 0.15
const SECOND_DROP := 0.12
const STRETCH_NAMES := ["Perspective entrance", "Parallel fern grove", "Perspective rise", "Parallel clearing"]

# Each row is (Y, left trail edge, right trail edge), from south to north.
const GUIDE_TRAIL := [
	Vector3(2048, 510, 1026), Vector3(1720, 535, 1009),
	Vector3(1380, 650, 994), Vector3(1070, 664, 1008),
	Vector3(730, 669, 909), Vector3(440, 655, 895),
	Vector3(355, 697, 869), Vector3(315, 750, 818),
]


static func edges(y: float, trail: Array) -> Vector2:
	for index in range(1, trail.size()):
		var near_row: Vector3 = trail[index - 1]
		var far_row: Vector3 = trail[index]
		if y >= far_row.x:
			var blend := clampf(inverse_lerp(near_row.x, far_row.x, y), 0.0, 1.0)
			return Vector2(near_row.y, near_row.z).lerp(Vector2(far_row.y, far_row.z), blend)
	var last: Vector3 = trail.back()
	return Vector2(last.y, last.z)


static func feet_limits(y: float, trail: Array) -> Vector2:
	var inset := 22.0 * figure_scale(y)
	return edges(y, trail) + Vector2(inset, -inset)


static func stretch(y: float) -> int:
	var progress := START_Y - y
	for index in BOUNDARIES.size():
		if progress < BOUNDARIES[index]:
			return index
	return BOUNDARIES.size()


static func figure_scale(y: float) -> float:
	var depth := _depth(y)
	return 1.0 - FIRST_DROP * depth.x - SECOND_DROP * depth.y


static func camera_lead(y: float) -> float:
	var depth := _depth(y)
	return 153.6 - 101.6 * depth.x - 90.0 * depth.y


static func _depth(y: float) -> Vector2:
	var progress := START_Y - y
	return Vector2(
		_ramp(progress, FEATHER, BOUNDARIES[0]),
		_ramp(progress, BOUNDARIES[1], BOUNDARIES[2])
	)


static func _ramp(progress: float, begin: float, end: float) -> float:
	# A linear rise with a continuous slope at both ends.
	return (_soft_positive(progress - begin) - _soft_positive(progress - end)) / (end - begin)


static func _soft_positive(value: float) -> float:
	var within := clampf(value + FEATHER, 0.0, 2.0 * FEATHER)
	return within * within / (4.0 * FEATHER) + maxf(value - FEATHER, 0.0)
