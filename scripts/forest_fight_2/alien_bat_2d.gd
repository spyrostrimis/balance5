class_name AlienBat2D
extends Node2D
## 2.5D Alien-Mutant Cave Bat:
## - node.position = Vector2(x, depth_y) so Y-sort orders bats cleanly against the Commander & bolts.
## - Floor shadow draws at (0, 0) on the cave floor, tightening & darkening as altitude drops.
## - Body draws at (0, -altitude).
## - Three archetypes cover all angles (left sweep, right/rear curl, deep back-wall dive).
## - Signals every dive with a tucked-wing silhouette tell + tightening floor shadow, then makes
##   a readable pass at rifle height (altitude ~212 px). Dies in 1 hit; deals 0 harm on contact.

signal died(bat: AlienBat2D)

enum State { INTRO_PERCH, ORBIT, DIVE_TELL, SWOOP_PASS, RECOVER, DYING }

const BAT_TEX := preload("res://assets/textures/forest_fight_2/alien_bat_hd.png")
const SHADOW_TEX := preload("res://assets/textures/rpg_2d/sprites/contact_shadow.png")

## 512x512 cells; scale 0.34 -> ~158 px wingspan (~105 px tucked dive), crisp & readable beside 276 px hero!
const BASE_BAT_SCALE := 0.34
const RIFLE_PASS_ALTITUDE := 212.0
const DEPTH_MIN_Y := 640.0
const DEPTH_MAX_Y := 902.0

var archetype: int = 0  # 0 = Left Sweeper, 1 = Right-Flank Curler, 2 = Deep-Wall Diver
var depth_y: float = 700.0
var altitude: float = 310.0
var alive: bool = true
var state: State = State.INTRO_PERCH
var target_hero: CaveCommander2D = null
var contacted_this_pass: bool = false
var combat_active: bool = false

var _timer: float = 0.0
var _flap_time: float = 0.0
var _pass_count: int = 0
var _orbit_phase: float = 0.0
var _dive_start_pos := Vector2.ZERO
var _dive_start_alt := 290.0
var _swoop_start_x := 200.0
var _swoop_end_x := 1320.0
var _swoop_start_lane := 760.0
var _swoop_end_lane := 760.0
var _swoop_duration := 1.25
var _hit_vel := Vector2.ZERO
var _hit_alt_vel := 0.0
var _facing_dir: int = -1  # Source art faces LEFT (-1); +1 sets flip_h = true

var body_sprite: Sprite2D
var shadow_sprite: Sprite2D


func setup(bat_index: int, hero: CaveCommander2D) -> void:
	archetype = bat_index
	target_hero = hero
	alive = true
	contacted_this_pass = false
	combat_active = false
	state = State.INTRO_PERCH
	_pass_count = 0

	match archetype:
		0:
			# Left Sweeper: drops from upper-left rock shelf, sweeps in from far left
			position = Vector2(510.0, 665.0)
			altitude = 305.0
			_orbit_phase = 0.2
			_facing_dir = 1
		1:
			# Right-Flank Curler: roosts on upper-right ledge, curls from behind/right
			position = Vector2(1290.0, 660.0)
			altitude = 320.0
			_orbit_phase = 2.1
			_facing_dir = -1
		_:
			# Deep-Wall Diver: roosts near Orichalcum vein on back wall, dives across depth
			position = Vector2(935.0, 646.0)
			altitude = 335.0
			_orbit_phase = 4.0
			_facing_dir = -1
	depth_y = position.y
	_flap_time = float(archetype) * 1.37
	_update_visuals()


func _ready() -> void:
	shadow_sprite = Sprite2D.new()
	shadow_sprite.texture = SHADOW_TEX
	shadow_sprite.position = Vector2(0.0, 0.0)
	add_child(shadow_sprite)

	body_sprite = Sprite2D.new()
	body_sprite.texture = BAT_TEX
	body_sprite.hframes = 4
	body_sprite.vframes = 1
	add_child(body_sprite)

	_update_visuals()


func awaken_into_chamber(initial_orbit_delay: float) -> void:
	combat_active = true
	state = State.ORBIT
	_timer = initial_orbit_delay


func step_bat(delta: float) -> void:
	_flap_time += delta * 9.5

	if state == State.DYING:
		position.x = clampf(position.x + _hit_vel.x * delta, 70.0, 1470.0)
		depth_y = clampf(depth_y + _hit_vel.y * delta, DEPTH_MIN_Y, DEPTH_MAX_Y)
		position.y = depth_y
		_hit_alt_vel -= 760.0 * delta
		altitude = maxf(18.0, altitude + _hit_alt_vel * delta)
		_timer -= delta
		body_sprite.modulate.a = clampf(_timer / 0.26, 0.0, 1.0)
		shadow_sprite.modulate.a = 0.45 * body_sprite.modulate.a
		_update_visuals()
		if _timer <= 0.0:
			queue_free()
		return

	if not combat_active:
		# Subtle perched / waking wingbeat during Beat 2 & Beat 3 camera reveal
		altitude += sin(_flap_time * 0.5) * 14.0 * delta
		_update_visuals()
		return

	match state:
		State.ORBIT:
			_orbit_phase += delta * 1.65
			var anchor := _orbit_anchor()
			var desired := Vector2(
				anchor.x + cos(_orbit_phase) * 135.0,
				clampf(anchor.y + sin(_orbit_phase * 0.85) * 65.0, DEPTH_MIN_Y, DEPTH_MAX_Y)
			)
			var dx := desired.x - position.x
			if absf(dx) > 4.0:
				_facing_dir = 1 if dx > 0.0 else -1
			position = position.lerp(desired, 1.0 - exp(-3.4 * delta))
			depth_y = position.y
			altitude = lerpf(altitude, 295.0 + 18.0 * sin(_flap_time * 0.6), 1.0 - exp(-4.0 * delta))
			_timer -= delta
			if _timer <= 0.0:
				_begin_dive_tell()

		State.DIVE_TELL:
			# Unmistakable pre-dive tell: tuck wings, drop halfway toward rifle lane, tighten floor shadow!
			_timer -= delta
			var t := 1.0 - clampf(_timer / 0.50, 0.0, 1.0)
			var staged := Vector2(_swoop_start_x, _swoop_start_lane)
			position = _dive_start_pos.lerp(staged, ease(t, -1.8))
			depth_y = position.y
			altitude = lerpf(_dive_start_alt, RIFLE_PASS_ALTITUDE + 26.0, ease(t, -1.8))
			_facing_dir = 1 if (_swoop_end_x > _swoop_start_x) else -1
			if _timer <= 0.0:
				state = State.SWOOP_PASS
				_timer = _swoop_duration
				contacted_this_pass = false

		State.SWOOP_PASS:
			_timer -= delta
			var u := 1.0 - clampf(_timer / _swoop_duration, 0.0, 1.0)
			position.x = lerpf(_swoop_start_x, _swoop_end_x, u)
			depth_y = clampf(lerpf(_swoop_start_lane, _swoop_end_lane, u), DEPTH_MIN_Y, DEPTH_MAX_Y)
			position.y = depth_y
			# Holds readable rifle altitude through the middle 75% of the pass, dipping smoothly in/out
			var arc := sin(u * PI)
			altitude = lerpf(242.0, RIFLE_PASS_ALTITUDE, arc)
			_facing_dir = 1 if (_swoop_end_x > _swoop_start_x) else -1
			_check_commander_contact()
			if _timer <= 0.0:
				state = State.RECOVER
				_timer = 0.62
				_pass_count += 1

		State.RECOVER:
			_timer -= delta
			var anchor := _orbit_anchor()
			position = position.lerp(anchor, 1.0 - exp(-2.8 * delta))
			depth_y = position.y
			altitude = lerpf(altitude, 305.0, 1.0 - exp(-4.5 * delta))
			if _timer <= 0.0:
				state = State.ORBIT
				_timer = 0.85 + 0.25 * float(archetype)

	_update_visuals()


func _orbit_anchor() -> Vector2:
	match archetype:
		0:
			return Vector2(285.0, 725.0)
		1:
			return Vector2(1245.0, 785.0)
		_:
			return Vector2(820.0, 668.0)


func _begin_dive_tell() -> void:
	state = State.DIVE_TELL
	_timer = 0.50
	_dive_start_pos = position
	_dive_start_alt = altitude

	var hero_x := target_hero.position.x if target_hero != null else 520.0
	var hero_lane := target_hero.depth_y if target_hero != null else 770.0
	# Alternate between direct hero-lane dives and offset-lane passes so repositioning across
	# depth lanes rewards an attentive player over standing frozen in one lane!
	var lane_offsets := [0.0, -68.0, 64.0]
	var chosen_offset: float = lane_offsets[(_pass_count + archetype) % lane_offsets.size()]
	var aim_lane := clampf(hero_lane + chosen_offset, DEPTH_MIN_Y + 12.0, DEPTH_MAX_Y - 12.0)

	match archetype:
		0:
			# Sweeps in from far left across the chamber
			_swoop_start_x = 135.0
			_swoop_end_x = 1365.0
			_swoop_start_lane = aim_lane
			_swoop_end_lane = aim_lane
			_swoop_duration = 1.42
		1:
			# Curls from behind/right (approaching from right -> left with slight diagonal curl)
			_swoop_start_x = 1385.0
			_swoop_end_x = 155.0
			_swoop_start_lane = clampf(hero_lane + (52.0 if _pass_count % 2 == 0 else -56.0), DEPTH_MIN_Y + 10.0, DEPTH_MAX_Y - 10.0)
			_swoop_end_lane = clampf(hero_lane, DEPTH_MIN_Y + 10.0, DEPTH_MAX_Y - 10.0)
			_swoop_duration = 1.38
		_:
			# Dives out from the rear back-wall crevice diagonally across depth!
			var from_right := hero_x < 760.0
			_swoop_start_x = 1220.0 if from_right else 310.0
			_swoop_end_x = 180.0 if from_right else 1350.0
			_swoop_start_lane = DEPTH_MIN_Y + 8.0
			_swoop_end_lane = clampf(hero_lane + 38.0, DEPTH_MIN_Y + 20.0, DEPTH_MAX_Y - 12.0)
			_swoop_duration = 1.45


func _check_commander_contact() -> void:
	if contacted_this_pass or not alive or target_hero == null:
		return
	if absf(position.x - target_hero.position.x) > 48.0:
		return
	if absf(depth_y - target_hero.depth_y) > 32.0:
		return
	if altitude < 80.0 or altitude > 268.0:
		return

	contacted_this_pass = true
	# Brief upward recoil/fly-through on bat while Commander sparks blue armour energy unharmed!
	altitude += 26.0
	target_hero.register_bat_contact(position.x, altitude)


func apply_hit(hit_dir_x: int) -> void:
	if not alive:
		return
	alive = false
	state = State.DYING
	_timer = 0.42
	_hit_vel = Vector2(float(hit_dir_x) * 240.0, -24.0)
	_hit_alt_vel = 95.0
	_facing_dir = -hit_dir_x
	_update_visuals()
	died.emit(self)


func _update_visuals() -> void:
	if body_sprite == null or shadow_sprite == null:
		return
	var d_scale := CaveCommander2D.depth_scale_factor(depth_y)
	body_sprite.position = Vector2(0.0, -altitude)
	body_sprite.scale = Vector2.ONE * (BASE_BAT_SCALE * d_scale)
	# Source bat sheet faces LEFT (_facing_dir == -1 -> flip_h = false)
	body_sprite.flip_h = _facing_dir > 0

	match state:
		State.DYING:
			body_sprite.frame = 3
		State.DIVE_TELL, State.SWOOP_PASS:
			body_sprite.frame = 2
		_:
			body_sprite.frame = 0 if (int(floor(_flap_time)) % 2 == 0) else 1

	if state == State.DIVE_TELL:
		body_sprite.modulate = Color(1.16, 1.06, 1.18, body_sprite.modulate.a)
	elif state != State.DYING:
		body_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Floor shadow tightens & darkens as the bat drops toward rifle altitude!
	var alt_ratio := clampf((altitude - 170.0) / 170.0, 0.0, 1.0)
	var sh_scale := lerpf(1.75, 1.05, alt_ratio) * d_scale
	shadow_sprite.scale = Vector2(sh_scale, sh_scale * 0.62)
	if state != State.DYING:
		shadow_sprite.modulate = Color(0.05, 0.04, 0.06, lerpf(0.68, 0.28, alt_ratio))
