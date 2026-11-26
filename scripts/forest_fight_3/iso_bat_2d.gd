class_name IsoBat2D
extends Node2D
## Strictly-Isometric 2.5D Alien-Mutant Bat:
## - Supports BOTH sleeping upside-down under a forest tree branch (waking up when approached!)
##   AND 360-degree Miyazaki cavern swoop archetypes.
## - Uses 4-quadrant isometric sprites (SW/SE front-iso flap & dive + NW/NE dorsal rear view + Frame 4 sleep roost).
## - Constant isometric scale everywhere; grounded floor shadow tightens beneath it during swoops.

signal woke_up(bat: IsoBat2D)
signal died(bat: IsoBat2D)

enum State {
	SLEEPING_BRANCH,
	WAKING_UP,
	INTRO_PERCH,
	ORBIT,
	DIVE_TELL,
	SWOOP_PASS,
	RECOVER,
	DYING,
}

const BAT_ISO_TEX := preload("res://assets/textures/forest_fight_3/bat_iso_sheet.png")
const SHADOW_TEX := preload("res://assets/textures/rpg_2d/sprites/contact_shadow.png")

const BASE_SCALE := 0.34
const RIFLE_ALTITUDE := 86.0
const WAKE_RADIUS := 175.0

var archetype: int = 0
var altitude: float = 190.0
var alive: bool = true
var state: State = State.ORBIT
var target_hero: IsoCommander2D = null
var stage_poly: PackedVector2Array = PackedVector2Array()
var contacted_this_pass: bool = false
var combat_active: bool = true

var _timer: float = 0.0
var _flap_time: float = 0.0
var _orbit_anchor := Vector2(960.0, 640.0)
var _orbit_phase: float = 0.0
var _pass_count: int = 0
var _vel_dir := Vector2(-0.8, 0.6)
var _dive_start_ground := Vector2.ZERO
var _dive_start_alt := 190.0
var _swoop_start := Vector2.ZERO
var _swoop_end := Vector2.ZERO
var _swoop_duration := 1.28
var _hit_vel := Vector2.ZERO
var _hit_alt_vel := 0.0

var body_sprite: Sprite2D
var shadow_sprite: Sprite2D
var sleep_label: Label


func _ready() -> void:
	shadow_sprite = Sprite2D.new()
	shadow_sprite.texture = SHADOW_TEX
	add_child(shadow_sprite)

	body_sprite = Sprite2D.new()
	body_sprite.texture = BAT_ISO_TEX
	body_sprite.hframes = 5
	body_sprite.vframes = 1
	add_child(body_sprite)

	sleep_label = Label.new()
	sleep_label.text = "zZz"
	sleep_label.visible = false
	sleep_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.88))
	sleep_label.add_theme_color_override("font_outline_color", Color(0.10, 0.14, 0.20, 0.92))
	sleep_label.add_theme_constant_override("outline_size", 4)
	sleep_label.add_theme_font_size_override("font_size", 15)
	add_child(sleep_label)

	_update_visuals()


func setup_sleeping_forest_bat(branch_ground: Vector2, branch_alt: float, hero: IsoCommander2D, poly: PackedVector2Array) -> void:
	archetype = -1
	position = branch_ground
	_orbit_anchor = branch_ground + Vector2(30.0, 35.0)
	altitude = branch_alt
	target_hero = hero
	stage_poly = poly
	alive = true
	combat_active = true
	contacted_this_pass = false
	state = State.SLEEPING_BRANCH
	_vel_dir = Vector2(-0.78, 0.62)
	if is_node_ready():
		_update_visuals()


func setup_cavern_bat(index: int, hero: IsoCommander2D, poly: PackedVector2Array) -> void:
	archetype = index
	target_hero = hero
	stage_poly = poly
	alive = true
	combat_active = false
	contacted_this_pass = false
	state = State.INTRO_PERCH
	_pass_count = 0

	match archetype:
		0: # NE Skylight Sunbeam Bat -> swoops NE to SW
			position = Vector2(1375.0, 445.0)
			_orbit_anchor = Vector2(1310.0, 485.0)
			altitude = 205.0
			_orbit_phase = 0.4
			_vel_dir = Vector2(-0.85, 0.52)
		1: # NW Emerald Crystal Ledge Bat -> swoops NW to SE across cavern
			position = Vector2(735.0, 595.0)
			_orbit_anchor = Vector2(785.0, 625.0)
			altitude = 195.0
			_orbit_phase = 2.4
			_vel_dir = Vector2(0.75, 0.66)
		_: # SE Turquoise Pool Bat -> rises from pool side & swoops SE to NW / Dorsal!
			position = Vector2(1195.0, 745.0)
			_orbit_anchor = Vector2(1145.0, 725.0)
			altitude = 185.0
			_orbit_phase = 4.3
			_vel_dir = Vector2(-0.72, -0.69)

	_flap_time = float(index) * 1.4
	if is_node_ready():
		_update_visuals()


func awaken_cavern_bat(initial_delay: float) -> void:
	combat_active = true
	state = State.ORBIT
	_timer = initial_delay


func step_bat(delta: float) -> void:
	_flap_time += delta * 9.2

	if state == State.DYING:
		position += _hit_vel * delta
		_hit_alt_vel -= 680.0 * delta
		altitude = maxf(12.0, altitude + _hit_alt_vel * delta)
		_timer -= delta
		body_sprite.modulate.a = clampf(_timer / 0.25, 0.0, 1.0)
		shadow_sprite.modulate.a = 0.42 * body_sprite.modulate.a
		_update_visuals()
		if _timer <= 0.0:
			queue_free()
		return

	if state == State.SLEEPING_BRANCH:
		# Peaceful breathing under the sunlit tree branch until the Commander walks close!
		if target_hero != null and position.distance_to(target_hero.position) <= WAKE_RADIUS:
			state = State.WAKING_UP
			_timer = 0.48
			sleep_label.text = "!"
			sleep_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32, 1.0))
			woke_up.emit(self)
		_update_visuals()
		return

	if state == State.WAKING_UP:
		_timer -= delta
		var wt := 1.0 - clampf(_timer / 0.48, 0.0, 1.0)
		altitude = lerpf(232.0, 155.0, ease(wt, -1.8))
		if target_hero != null:
			var d_to_h := target_hero.position - position
			if d_to_h.length_squared() > 1.0:
				_vel_dir = d_to_h.normalized()
		if _timer <= 0.0:
			sleep_label.visible = false
			_begin_dive_tell()
		_update_visuals()
		return

	if not combat_active:
		altitude += sin(_flap_time * 0.5) * 12.0 * delta
		_update_visuals()
		return

	match state:
		State.ORBIT:
			_orbit_phase += delta * 1.75
			var desired := _orbit_anchor + Vector2(cos(_orbit_phase) * 125.0, sin(_orbit_phase * 0.9) * 78.0)
			var delta_p := desired - position
			if delta_p.length_squared() > 4.0:
				_vel_dir = _vel_dir.lerp(delta_p.normalized(), 1.0 - exp(-6.0 * delta)).normalized()
			position = position.lerp(desired, 1.0 - exp(-3.5 * delta))
			altitude = lerpf(altitude, 192.0 + 14.0 * sin(_flap_time * 0.6), 1.0 - exp(-4.2 * delta))
			_timer -= delta
			if _timer <= 0.0:
				_begin_dive_tell()

		State.DIVE_TELL:
			_timer -= delta
			var t := 1.0 - clampf(_timer / 0.46, 0.0, 1.0)
			position = _dive_start_ground.lerp(_swoop_start, ease(t, -1.8))
			altitude = lerpf(_dive_start_alt, RIFLE_ALTITUDE + 22.0, ease(t, -1.8))
			var swoop_v := _swoop_end - _swoop_start
			if swoop_v.length_squared() > 1.0:
				_vel_dir = swoop_v.normalized()
			if _timer <= 0.0:
				state = State.SWOOP_PASS
				_timer = _swoop_duration
				contacted_this_pass = false

		State.SWOOP_PASS:
			_timer -= delta
			var u := 1.0 - clampf(_timer / _swoop_duration, 0.0, 1.0)
			position = _swoop_start.lerp(_swoop_end, u)
			altitude = lerpf(118.0, RIFLE_ALTITUDE, sin(u * PI))
			var swoop_v := _swoop_end - _swoop_start
			if swoop_v.length_squared() > 1.0:
				_vel_dir = swoop_v.normalized()
			_check_hero_contact()
			if _timer <= 0.0:
				state = State.RECOVER
				_timer = 0.58
				_pass_count += 1

		State.RECOVER:
			_timer -= delta
			var to_a := _orbit_anchor - position
			if to_a.length_squared() > 4.0:
				_vel_dir = _vel_dir.lerp(to_a.normalized(), 1.0 - exp(-5.0 * delta)).normalized()
			position = position.lerp(_orbit_anchor, 1.0 - exp(-2.8 * delta))
			altitude = lerpf(altitude, 195.0, 1.0 - exp(-4.2 * delta))
			if _timer <= 0.0:
				state = State.ORBIT
				_timer = 0.80 + 0.22 * float(maxi(0, archetype))

	_update_visuals()


func _begin_dive_tell() -> void:
	state = State.DIVE_TELL
	_timer = 0.46
	_dive_start_ground = position
	_dive_start_alt = altitude

	var hero_pos := target_hero.position if target_hero != null else _orbit_anchor
	if archetype == -1:
		# Forest trail ambush bat: swoops directly through the hero's position along the trail!
		var approach_dir := (hero_pos - position).normalized()
		if approach_dir.length_squared() < 0.01:
			approach_dir = Vector2(-0.85, 0.52)
		_swoop_start = position.lerp(hero_pos - approach_dir * 165.0, 0.55)
		_swoop_end = hero_pos + approach_dir * 215.0
		_swoop_duration = 1.18
		_orbit_anchor = hero_pos + Vector2(140.0, -90.0)
		return

	# Cavern bats dive from full 360-degree isometric directions through or beside the Commander!
	var angle_presets := [
		deg_to_rad(150.0),  # NE -> SW along main cavern axis
		deg_to_rad(38.0),   # NW -> SE across terrace toward crystal pool
		deg_to_rad(-132.0), # SE -> NW dorsal upward swoop!
	]
	var base_ang: float = angle_presets[(archetype + _pass_count) % angle_presets.size()]
	var attack_dir := Vector2(cos(base_ang), sin(base_ang))
	var perp := Vector2(-attack_dir.y, attack_dir.x)
	var offsets: Array[float] = [0.0, 42.0, -42.0]
	var flank_offset: float = offsets[(_pass_count + archetype) % 3]
	var pass_center: Vector2 = hero_pos + perp * flank_offset
	_swoop_start = pass_center - attack_dir * 285.0
	_swoop_end = pass_center + attack_dir * 285.0
	_swoop_duration = 1.32


func _check_hero_contact() -> void:
	if contacted_this_pass or not alive or target_hero == null:
		return
	if position.distance_to(target_hero.position) > 44.0:
		return
	if absf(altitude - IsoCommander2D.RIFLE_ALTITUDE) > 54.0:
		return
	contacted_this_pass = true
	altitude += 22.0
	target_hero.register_bat_contact(position)


func apply_hit(shot_dir: Vector2) -> void:
	if not alive:
		return
	alive = false
	sleep_label.visible = false
	state = State.DYING
	_timer = 0.40
	_hit_vel = shot_dir.normalized() * 210.0
	_hit_alt_vel = 85.0
	_update_visuals()
	died.emit(self)


func _update_visuals() -> void:
	if body_sprite == null or shadow_sprite == null:
		return

	body_sprite.position = Vector2(0.0, -altitude)

	if state == State.SLEEPING_BRANCH:
		var breath := 1.0 + 0.03 * sin(_flap_time * 0.28)
		body_sprite.scale = Vector2(BASE_SCALE * 0.92, BASE_SCALE * breath)
		body_sprite.frame = 4
		body_sprite.flip_h = false
		body_sprite.modulate = Color(0.92, 0.90, 0.98, 1.0)
		sleep_label.visible = true
		sleep_label.position = Vector2(28.0, -altitude - 22.0 - 4.0 * sin(_flap_time * 0.3))
		shadow_sprite.scale = Vector2(0.75, 0.45)
		shadow_sprite.modulate = Color(0.08, 0.06, 0.06, 0.18)
		return

	if state == State.WAKING_UP:
		body_sprite.scale = Vector2.ONE * (BASE_SCALE * 1.06)
		body_sprite.frame = 0
		body_sprite.flip_h = _vel_dir.x > 0.0
		body_sprite.modulate = Color(1.18, 1.08, 1.15, 1.0)
		sleep_label.visible = true
		sleep_label.position = Vector2(12.0, -altitude - 62.0)
		shadow_sprite.scale = Vector2(1.05, 0.64)
		shadow_sprite.modulate = Color(0.08, 0.06, 0.08, 0.34)
		return

	body_sprite.scale = Vector2.ONE * BASE_SCALE
	# Choose front-iso (frames 0/1/2) vs dorsal rear-iso (frame 3) when flying northward!
	var flying_north := _vel_dir.y < -0.28
	body_sprite.flip_h = _vel_dir.x > 0.0

	if state == State.DYING:
		body_sprite.frame = 0
		body_sprite.rotation = (0.40 - _timer) * 4.5 * (1.0 if _vel_dir.x >= 0.0 else -1.0)
	elif flying_north:
		body_sprite.frame = 3
		body_sprite.rotation = 0.0
		# Subtle wingbeat pulse on dorsal frame
		var pulse := 1.0 + 0.05 * sin(_flap_time * PI)
		body_sprite.scale = Vector2(BASE_SCALE * pulse, BASE_SCALE / pulse)
	elif state == State.DIVE_TELL or state == State.SWOOP_PASS:
		body_sprite.frame = 2
		body_sprite.rotation = 0.0
	else:
		body_sprite.frame = 0 if (int(floor(_flap_time)) % 2 == 0) else 1
		body_sprite.rotation = 0.0

	if state == State.DIVE_TELL:
		body_sprite.modulate = Color(1.16, 1.06, 1.18, body_sprite.modulate.a)
	elif state != State.DYING:
		body_sprite.modulate = Color.WHITE

	var alt_ratio := clampf((altitude - RIFLE_ALTITUDE) / 135.0, 0.0, 1.0)
	var sh_s := lerpf(1.38, 0.82, alt_ratio)
	shadow_sprite.scale = Vector2(sh_s, sh_s * 0.60)
	if state != State.DYING:
		shadow_sprite.modulate = Color(0.08, 0.06, 0.10, lerpf(0.58, 0.22, alt_ratio))
