class_name ForestFight2Route
extends RefCounted
## Extends the Forest Walk route (res://assets/scenes/forest_test/forest_route.gd) northward
## so the Blue Commander can approach the cave mouth in the clearing, stop or back away,
## and cross the visible threshold (Y <= 312) under the overhanging stone lip.

const BaseRoute := preload("res://assets/scenes/forest_test/forest_route.gd")

const CANVAS := Vector2(1536, 2048)
const VIEW := Vector2(1376, 768)
const START_Y := 1720.0
const SOUTH_Y := 1780.0
## Free exploration stops only when crossing CAVE_THRESHOLD_Y (312.0); Beat 1 walks to CAVE_THROAT_Y (216.0).
const CAVE_APPROACH_VISIBLE_Y := 620.0
const CAVE_THRESHOLD_Y := 312.0
const CAVE_THROAT_Y := 216.0
const CAVE_CENTER_X := 726.0
const START_HEIGHT := 153.6

## Fitted painted trail matching ForestWalk's 27 south-to-clearing rows + 4 cave-approach rows.
const PAINTED_CAVE_TRAIL: Array[Vector3] = [
	Vector3(1880, 480, 1048), Vector3(1780, 512, 1020), Vector3(1720, 528, 1005),
	Vector3(1660, 545, 1000), Vector3(1600, 550, 1007), Vector3(1520, 565, 1018),
	Vector3(1450, 586, 1005), Vector3(1380, 610, 993), Vector3(1300, 631, 991),
	Vector3(1240, 634, 990), Vector3(1180, 631, 1020), Vector3(1100, 626, 1028),
	Vector3(1070, 623, 1024), Vector3(1000, 605, 1000), Vector3(930, 596, 966),
	Vector3(880, 608, 936), Vector3(825, 633, 926), Vector3(780, 648, 921),
	Vector3(730, 648, 919), Vector3(670, 639, 916), Vector3(615, 620, 904),
	Vector3(550, 610, 902), Vector3(490, 604, 896), Vector3(440, 585, 854),
	Vector3(394, 590, 846), Vector3(346, 618, 834), Vector3(312, 646, 806),
	Vector3(265, 672, 780), Vector3(210, 690, 762),
]


static func edges(y: float) -> Vector2:
	return BaseRoute.edges(y, PAINTED_CAVE_TRAIL)


static func feet_limits(y: float) -> Vector2:
	var inset := 22.0 * figure_scale(y)
	return edges(y) + Vector2(inset, -inset)


static func figure_scale(y: float) -> float:
	var base := BaseRoute.figure_scale(maxf(y, 440.0))
	if y >= 440.0:
		return base
	# Slight natural perspective recession as she steps into the cave throat (440 -> 216)
	var t := clampf(inverse_lerp(440.0, CAVE_THROAT_Y, y), 0.0, 1.0)
	return base * lerpf(1.0, 0.90, t)


static func camera_lead(y: float) -> float:
	return BaseRoute.camera_lead(maxf(y, 440.0))
