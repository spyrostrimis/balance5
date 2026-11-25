extends RefCounted
## Projected foot positions in the two registered paintings.

const SPAWN := Vector2(652, 459)
const DOOR := Vector2(1185, 183)
const CHAMBER := Vector2(1815, 41)
const FLOOR := [
	Vector2(416, 636), Vector2(392, 591), Vector2(438, 533), Vector2(455, 465),
	Vector2(475, 399), Vector2(563, 365), Vector2(678, 331), Vector2(753, 264),
	Vector2(847, 222), Vector2(924, 226), Vector2(1030, 202), Vector2(1118, 164),
	Vector2(1182, 130), Vector2(1278, 75), Vector2(1415, -16), Vector2(1536, -70),
	Vector2(1685, -156), Vector2(1848, -175), Vector2(2030, -195), Vector2(2160, -219),
	Vector2(2317, -233), Vector2(2372, -168), Vector2(2350, -87), Vector2(2414, 12),
	Vector2(2360, 112), Vector2(2276, 184), Vector2(2071, 256), Vector2(1866, 289),
	Vector2(1693, 250), Vector2(1480, 195), Vector2(1330, 229), Vector2(1260, 248),
	Vector2(1199, 235), Vector2(1125, 267), Vector2(1055, 324), Vector2(977, 367),
	Vector2(942, 398), Vector2(910, 424), Vector2(883, 455), Vector2(857, 492), Vector2(768, 528),
	Vector2(721, 586), Vector2(635, 618), Vector2(521, 659), Vector2(456, 653),
]
const ROCK := [
	Vector2(1955, 143), Vector2(1992, 114), Vector2(2048, 104), Vector2(2124, 123),
	Vector2(2138, 144), Vector2(2102, 167), Vector2(2023, 173), Vector2(1983, 163),
]
const BAT_SPACE := [
	Vector2(1380, 133), Vector2(1570, -42), Vector2(1730, -131), Vector2(2120, -163),
	Vector2(2255, -131), Vector2(2330, 5), Vector2(2220, 178), Vector2(1880, 245),
	Vector2(1540, 161),
]


static func flight_position(target: Vector2) -> Vector2:
	if Geometry2D.is_point_in_polygon(target, PackedVector2Array(BAT_SPACE)):
		return target
	var closest := BAT_SPACE[0] as Vector2
	for i in BAT_SPACE.size():
		var point := Geometry2D.get_closest_point_to_segment(target, BAT_SPACE[i], BAT_SPACE[(i + 1) % BAT_SPACE.size()])
		if target.distance_squared_to(point) < target.distance_squared_to(closest):
			closest = point
	return closest
