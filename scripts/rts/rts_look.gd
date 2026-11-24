class_name RtsLook
extends Node2D
## What keeps units looking grounded on the map instead of floating over it. Sits in the map
## between the ground layers and the units, and draws the marks units leave: tank tracks,
## footprints and dust. Each effect can be switched off for A/B comparisons (see rts_units_test.gd).
##   shadows       soft shadow down-right plus a dark contact line at the base (drawn by RtsUnit)
##   ground_light  a unit is lit or shaded like the sand under it (light_map, 128 = average)
##   marks         tank tracks and footprints that fade
##   dust          puffs behind moving vehicles

static var shadows := true
static var ground_light := true
static var marks := true
static var dust := true
static var pixel_snap := false
static var soft_effects := false
static var instance: RtsLook

const TRACK_LIFE := 8.0
const FOOT_LIFE := 5.0
const DUST_LIFE := 0.7
const TRACK_COLOR := Color(0.33, 0.15, 0.04)
const FOOT_COLOR := Color(0.36, 0.17, 0.05)
const DUST_COLOR := Color(0.93, 0.74, 0.47)

## Greyscale picture of how bright the ground is at each art pixel (128 = average sand).
@export var light_map: Texture2D

static var _light: Image

var _tracks: Array = []  # [position, angle, age]
var _feet: Array = []  # [position, age]
var _dust: Array = []  # [position, velocity, age, size]


func _ready() -> void:
	instance = self
	_light = light_map.get_image() if light_map != null else null


## Brightness multiplier for a unit standing at `pos`.
static func light_at(pos: Vector2) -> float:
	if not ground_light or _light == null:
		return 1.0
	var x := clampi(int(pos.x), 0, _light.get_width() - 1)
	var y := clampi(int(pos.y), 0, _light.get_height() - 1)
	return clampf(1.0 + (_light.get_pixel(x, y).r - 0.5) * 0.9, 0.72, 1.22)


func add_track(pos: Vector2, angle: float) -> void:
	if marks:
		_tracks.append([pos, angle, 0.0])


## Each sample uses the rear tread contacts at both ends of a part of the turn.
func add_track_pair(previous: Vector2, previous_heading: Vector2, next: Vector2, heading: Vector2) -> void:
	if marks:
		_tracks.append([previous, next, 0.0, previous_heading, heading])


func add_footprints(pos: Vector2) -> void:
	if marks:
		_feet.append([pos, 0.0])


func add_dust(pos: Vector2, away: Vector2) -> void:
	if dust:
		var drift := away * randf_range(4.0, 9.0) + Vector2(randf_range(-3, 3), randf_range(-3, 1))
		_dust.append([pos + Vector2(randf_range(-3, 3), randf_range(-2, 2)), drift, 0.0, randf_range(1.5, 3.0)])


func _process(delta: float) -> void:
	for t: Array in _tracks:
		t[2] += delta
	for f: Array in _feet:
		f[1] += delta
	for d: Array in _dust:
		d[0] += d[1] * delta
		d[2] += delta
	_tracks = _tracks.filter(func(t: Array) -> bool: return t[2] < TRACK_LIFE)
	_feet = _feet.filter(func(f: Array) -> bool: return f[1] < FOOT_LIFE)
	_dust = _dust.filter(func(d: Array) -> bool: return d[2] < DUST_LIFE)
	queue_redraw()


func apply_visual_profile(profile: RtsVisualProfile) -> void:
	pixel_snap = profile.snap_pixels
	soft_effects = profile.soft_effects
	texture_filter = profile.canvas_texture_filter
	queue_redraw()


func _draw() -> void:
	if marks:
		for t: Array in _tracks:
			var fade: float = 1.0 - t[2] / TRACK_LIFE
			if t.size() == 5:
				for side in [-6.0, 6.0]:
					var a: Vector2 = t[0] - t[3] * 6.0 + t[3].orthogonal() * side
					var b: Vector2 = t[1] - t[4] * 6.0 + t[4].orthogonal() * side
					if pixel_snap:
						a = a.round()
						b = b.round()
					if soft_effects:
						draw_line(a, b, Color(TRACK_COLOR, 0.22 * fade), 2.8, true)
						draw_line(a, b, Color(TRACK_COLOR, 0.42 * fade), 1.4, true)
					else:
						draw_line(a, b, Color(TRACK_COLOR, 0.46 * fade), 1.6, false)
				continue
			var along := Vector2.from_angle(t[1])
			var side := along.orthogonal()
			for s in [-5.0, 5.0]:
				var c: Vector2 = t[0] + side * s
				if pixel_snap:
					var p0 := (c - along * 1.5).round()
					var p1 := (c + along * 1.5).round()
					draw_line(p0, p1, Color(TRACK_COLOR, 0.46 * fade), 2.0, false)
				elif soft_effects:
					draw_line(c - along * 1.7, c + along * 1.7, Color(TRACK_COLOR, 0.20 * fade), 3.0, true)
					draw_line(c - along * 1.4, c + along * 1.4, Color(TRACK_COLOR, 0.40 * fade), 1.6, true)
				else:
					draw_line(c - along * 1.5, c + along * 1.5, Color(TRACK_COLOR, 0.42 * fade), 2.0)
		for f: Array in _feet:
			var fade: float = 1.0 - f[1] / FOOT_LIFE
			var fp: Vector2 = (f[0] as Vector2).round() if pixel_snap else (f[0] as Vector2)
			if soft_effects:
				draw_circle(fp + Vector2(0.5, 0.5), 0.95, Color(FOOT_COLOR, 0.38 * fade), true, -1.0, true)
			else:
				draw_rect(Rect2(fp, Vector2.ONE), Color(FOOT_COLOR, 0.48 * fade))
	if dust:
		for d: Array in _dust:
			var k: float = d[2] / DUST_LIFE
			var pos: Vector2 = (d[0] as Vector2).round() if pixel_snap else (d[0] as Vector2)
			var rad: float = d[3] * (1.0 + k * 1.6)
			if pixel_snap and not soft_effects:
				var ir := maxf(1.0, roundf(rad))
				var col := Color(DUST_COLOR, 0.45 * (1.0 - k))
				draw_rect(Rect2(pos - Vector2(ir, ir), Vector2(ir * 2.0, ir * 2.0)), col)
			elif soft_effects:
				draw_circle(pos, rad * 1.35, Color(DUST_COLOR, 0.20 * (1.0 - k)), true, -1.0, true)
				draw_circle(pos, rad * 0.85, Color(DUST_COLOR.lightened(0.08), 0.36 * (1.0 - k)), true, -1.0, true)
			else:
				draw_circle(pos, rad, Color(DUST_COLOR, 0.45 * (1.0 - k)))
