extends RefCounted
## Lateral offset and distance uphill are measured in ground units.
## At boot depth, a ground unit across the road projects to one art pixel.

const BOOTS := Vector2(511, 325)
const HORIZON := 96.0
const DEPTH := 388.0
const ROAD_START := -155.0
const ROAD_END := 825.0
const SHRUB := Vector2(-98, -95)
const SCOUT := Vector2(86, 148)
const BLOCKED_AT := 223.75
const BEND_AT := 385.0
const OVERLOOK_AT := 690.0
const ARCH := Vector2(12, 868)

# Each row marks distance uphill, centre of the road, and half its paved width.
const MARKS := [
	Vector3(-440, -78, 140), Vector3(0, 0, 132), Vector3(165, 52, 124),
	Vector3(275, 156, 110), Vector3(420, 178, 103), Vector3(570, 82, 119),
	Vector3(755, 43, 149), Vector3(930, 104, 146), Vector3(1500, 330, 105),
	Vector3(3200, 700, 90),
]


static func road(distance: float) -> Vector2:
	for index in range(1, MARKS.size()):
		var after: Vector3 = MARKS[index]
		if distance <= after.x:
			var before: Vector3 = MARKS[index - 1]
			var weight := smoothstep(before.x, after.x, distance)
			return Vector2(before.y, before.z).lerp(Vector2(after.y, after.z), weight)
	var last: Vector3 = MARKS[-1]
	return Vector2(last.y, last.z)


static func scale_at(distance: float, camera_distance: float) -> float:
	return DEPTH / maxf(DEPTH + distance - camera_distance, 1.0)


static func project(ground: Vector2, camera_distance: float, camera_center: float) -> Vector2:
	var view_scale := scale_at(ground.y, camera_distance)
	return Vector2(
		BOOTS.x + (ground.x + road(ground.y).x - camera_center) * view_scale,
		HORIZON + (BOOTS.y - HORIZON) * view_scale
	)


static func distance_at(art_y: float) -> float:
	return DEPTH * ((BOOTS.y - HORIZON) / (art_y - HORIZON) - 1.0)


static func region(texture: Texture2D, area: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = area
	atlas.filter_clip = true
	return atlas
