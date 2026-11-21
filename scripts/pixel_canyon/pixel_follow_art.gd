extends Node2D
## Source paintings are broken into depth layers. Every prop has a route anchor.

const Route := preload("res://scripts/pixel_canyon/pixel_follow_route.gd")
const BACKDROP := preload("res://assets/textures/pixel_canyon/follow/backdrop.png")
const PAVING := preload("res://assets/textures/pixel_canyon/follow/paving.png")
const VERGE := preload("res://assets/textures/pixel_canyon/follow/verge.png")
const PROPS := preload("res://assets/textures/pixel_canyon/follow/props.png")
const SHRUB := preload("res://assets/textures/pixel_canyon/shrub.png")
const GroundShader := preload("res://assets/shaders/pixel_canyon/ground.gdshader")

const LOWER_RUIN := [Rect2(2, 2, 285, 327), Vector2(177, 286)]
const UPPER_RUIN := [Rect2(291, 2, 335, 219), Vector2(176, 199)]
const RIGHT_RUIN := [Rect2(630, 2, 343, 305), Vector2(177, 279)]
const SUNLIT_LEDGE := [Rect2(2, 333, 185, 247), Vector2(91, 196)]
const OCHRE_ROCKS := [Rect2(191, 333, 131, 84), Vector2(66, 72)]
const BEND_WALL := [Rect2(326, 333, 365, 489), Vector2(128, 389)]
const TERRACE := [Rect2(695, 333, 265, 246), Vector2(166, 206)]
const OVERLOOK_LEDGE := [Rect2(2, 826, 256, 162), Vector2(97, 123)]
const SCRUB := [Rect2(373, 358, 90, 65), Vector2(41, 48)]

# Region and pivot, lateral offset, distance uphill, art scale, optional mirror.
const PLACEMENTS := [
	[SUNLIT_LEDGE, -354.0, -185.0, 1.43, false],
	[OVERLOOK_LEDGE, 292.0, -138.0, 1.40, false],
	[LOWER_RUIN, -305.0, -46.0, 1.14, false],
	[SUNLIT_LEDGE, -490.0, -5.0, 2.10, false],
	[OCHRE_ROCKS, -215.0, 37.0, 0.95, false],
	[OCHRE_ROCKS, -187.0, -66.0, 0.47, true],
	[RIGHT_RUIN, 450.0, 60.0, 1.24, false],
	[SCRUB, 161.0, -24.0, 0.42, true],
	[BEND_WALL, 496.0, -30.0, 1.90, false],
	[OVERLOOK_LEDGE, 226.0, 95.0, 0.96, false],
	[SCRUB, -157.0, 119.0, 0.53, false],
	[UPPER_RUIN, -278.0, 175.0, 1.32, false],
	[OCHRE_ROCKS, 186.0, 211.0, 0.65, true],
	[BEND_WALL, -301.0, 319.0, 1.34, true],
	[SUNLIT_LEDGE, -193.0, 354.0, 0.90, true],
	[LOWER_RUIN, -418.0, 333.0, 1.78, false],
	[BEND_WALL, 382.0, 335.0, 1.65, false],
	[OVERLOOK_LEDGE, 202.0, 402.0, 0.86, true],
	[OCHRE_ROCKS, -150.0, 443.0, 0.60, false],
	[SCRUB, 178.0, 464.0, 0.41, false],
	[OCHRE_ROCKS, -195.0, 528.0, 0.52, true],
	[BEND_WALL, 385.0, 552.0, 1.65, false],
	[OVERLOOK_LEDGE, 223.0, 621.0, 0.92, false],
	[TERRACE, -212.0, 713.0, 1.25, false],
	[SCRUB, -158.0, 658.0, 0.55, true],
	[OCHRE_ROCKS, -167.0, 770.0, 0.48, true],
	[BEND_WALL, 328.0, 790.0, 1.23, false],
	[OCHRE_ROCKS, 206.0, 848.0, 0.82, false],
	[SCRUB, 180.0, 759.0, 0.61, false],
	[UPPER_RUIN, 298.0, 1130.0, 1.68, false],
	[SUNLIT_LEDGE, -225.0, 1045.0, 1.15, true],
	[BEND_WALL, 444.0, 1250.0, 2.35, false],
	[RIGHT_RUIN, 224.0, 1810.0, 2.10, false],
]

var _props: Array[Sprite2D] = []
var _surface := ShaderMaterial.new()
var _camera_distance := INF

@onready var _depth: Node2D = $"../Depth"
@onready var _sky: Sprite2D = $Backdrop
@onready var _ground: ColorRect = $Paving


func _ready() -> void:
	_sky.texture = BACKDROP
	_surface.shader = GroundShader
	_surface.set_shader_parameter("paving", PAVING)
	_surface.set_shader_parameter("verge", VERGE)
	_surface.set_shader_parameter("road_marks", PackedVector3Array(Route.MARKS))
	_surface.set_shader_parameter("depth", Route.DEPTH)
	_surface.set_shader_parameter("boots", Route.BOOTS)
	_surface.set_shader_parameter("horizon", Route.HORIZON)
	_ground.material = _surface
	for placement in PLACEMENTS:
		var prop := Sprite2D.new()
		prop.centered = false
		prop.flip_h = placement[4]
		var atlas := SHRUB if placement[0] == SCRUB else PROPS
		prop.texture = Route.region(atlas, placement[0][0])
		_props.append(prop)
		_depth.call_deferred("add_child", prop)


func apply_view(camera_distance: float, camera_center: float, painted: bool) -> void:
	if _camera_distance == camera_distance and visible == painted:
		return
	_camera_distance = camera_distance
	visible = painted
	# The far valley has less parallax than the shelf and never carries road art.
	_sky.position.x = -roundf(clampf(64.0 + camera_center * 0.28 - camera_distance * 0.025, 0.0, 192.0))
	_surface.set_shader_parameter("camera_distance", camera_distance)
	_surface.set_shader_parameter("camera_center", camera_center)
	for index in _props.size():
		var prop := _props[index]
		var placement: Array = PLACEMENTS[index]
		var ground := Vector2(placement[1], placement[2])
		# Tall walls can still be in frame after their feet pass below the view.
		prop.visible = painted and ground.y - camera_distance > 28.0 - Route.DEPTH
		if not prop.visible:
			continue
		var view_scale: float = Route.scale_at(ground.y, camera_distance) * placement[3]
		var pivot: Vector2 = placement[0][1]
		if prop.flip_h:
			pivot.x = prop.texture.get_width() - pivot.x
		prop.offset = (-pivot * view_scale).round() / view_scale
		prop.scale = Vector2.ONE * view_scale
		prop.position = Route.project(ground, camera_distance, camera_center).round()
		var haze := smoothstep(275.0, 1850.0, ground.y - camera_distance)
		prop.modulate = Color.WHITE.lerp(Color("#c9b1cf"), haze * 0.55)
