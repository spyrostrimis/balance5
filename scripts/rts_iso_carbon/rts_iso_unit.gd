class_name RtsIsoUnit
extends Node2D
## Playable isometric RTS unit (4-soldier Rifle/Legionary Squad, Commander with Mend,
## or 8-facing Tank with independent Hull + Turret).
## Movement, distances, footprints, Mend radius, and AStarGrid2D pathfinding run strictly
## in isotropic logical map coordinates (u, v); drawing projects through RtsIsoTransform.

signal died(unit: RtsIsoUnit)

enum Team { BLUE = 0, RED = 1 }
enum Role { SQUAD = 0, COMMANDER = 1, TANK = 2 }
enum Order { NONE = 0, MOVE = 1, ATTACK = 2 }

const MEND_COOLDOWN := 8.0
const MEND_RADIUS := 120.0  # 3.75 logical cells
const MEND_AMOUNT := 30

## Logical-space 4-soldier squad diamond offsets so formation stays spacious at every heading
const SQUAD_MAP_SLOTS := [
	Vector2(-6.5, -5.5),
	Vector2(6.5, -5.5),
	Vector2(-6.5, 6.5),
	Vector2(6.5, 6.5),
]

@export var display_name := "Rifle Squad"
@export var subtitle := "Blue Infantry"
@export var portrait_key := "blue_squad"
@export var sprite_key := "blue_soldier"
@export var team: Team = Team.BLUE
@export var role: Role = Role.SQUAD

@export var max_health := 68
@export var attack_damage := 13
@export var armour := 3
@export var attack_range_cells := 4.8
@export var guard_range_cells := 6.4
@export var attack_cooldown := 1.0
@export var speed_map_px := 64.0
@export var turn_rate := 4.8

var battlefield: Node2D
var grid: RtsGrid
var map_pos := Vector2.ZERO
var health := 68
var alive := true
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var hold_position := false:
	set(v):
		hold_position = v
		queue_redraw()
var peaceful := false

var cell := Vector2i.ZERO
var order: Order = Order.NONE
var target_enemy: RtsIsoUnit = null
var move_goal_map := Vector2.ZERO

var map_facing := Vector2(1.0, 0.0)
var hull_iso_angle := 0.5236     # +30 deg iso axis
var turret_iso_angle := 0.5236
var mend_timer := 0.0

var _waypoints_map: Array[Vector2] = []
var _claimed_cell := Vector2i(-999, -999)
var _attack_timer := 0.0
var _repath_timer := 0.0
var _stuck_timer := 0.0
var _hit_flash := 0.0
var _stride_dist := 0.0
var _tread_dist := 0.0
var _prev_tread_map := Vector2.ZERO
var _prev_tread_dir := Vector2.RIGHT
var _has_prev_tread := false
var _moving_now := false

var _tex_main: Texture2D
var _tex_turret: Texture2D


func setup(p_battlefield: Node2D, p_grid: RtsGrid, start_map_pos: Vector2) -> void:
	battlefield = p_battlefield
	grid = p_grid
	map_pos = start_map_pos
	health = max_health
	alive = true
	position = RtsIsoTransform.map_to_iso(map_pos)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	if team == Team.RED:
		map_facing = Vector2(-1.0, 0.0)
	else:
		map_facing = Vector2(1.0, 0.0)
	var iso_f := RtsIsoTransform.map_to_iso(map_facing)
	hull_iso_angle = iso_f.angle()
	turret_iso_angle = hull_iso_angle

	if role == Role.TANK:
		_tex_main = RtsIsoKit.texture(sprite_key + "_hull")
		_tex_turret = RtsIsoKit.texture(sprite_key + "_turret")
	else:
		_tex_main = RtsIsoKit.texture(sprite_key)

	_update_cell_claim()
	queue_redraw()


func select_radius_map() -> float:
	match role:
		Role.TANK:
			return 18.0
		Role.COMMANDER:
			return 13.5
		_:
			return 15.0


func visual_center_iso_offset() -> Vector2:
	match role:
		Role.TANK:
			return Vector2(0.0, -4.0)
		Role.COMMANDER:
			return Vector2(0.0, -16.0)
		_:
			return Vector2(0.0, -13.0)


func fit_count() -> int:
	if role != Role.SQUAD:
		return 1 if alive else 0
	if not alive or health <= 0:
		return 0
	return clampi(ceili(float(health) / float(max_health) * 4.0), 1, 4)


func is_enemy(other: RtsIsoUnit) -> bool:
	return other != null and other.alive and other.team != team


func attack_range_map() -> float:
	return attack_range_cells * RtsIsoTransform.CELL_SIZE


func guard_range_map() -> float:
	return guard_range_cells * RtsIsoTransform.CELL_SIZE


func can_mend() -> bool:
	return alive and team == Team.BLUE and role == Role.COMMANDER


func command_move(dest_map: Vector2) -> void:
	if not alive or grid == null:
		return
	hold_position = false
	order = Order.MOVE
	target_enemy = null
	var clamped := RtsIsoTransform.clamp_map_point(dest_map, 18.0)
	var dest_cell := RtsIsoTransform.cell_of(clamped)
	if not grid.is_walkable(dest_cell):
		var near := grid.free_cells_near(dest_cell, 1, [self])
		if not near.is_empty():
			dest_cell = near[0]
			clamped = RtsIsoTransform.center_of(dest_cell)
	move_goal_map = clamped
	_build_smooth_route(dest_cell, clamped, false)


func command_attack(enemy: RtsIsoUnit) -> void:
	if not alive or enemy == null or not enemy.alive:
		return
	order = Order.ATTACK
	target_enemy = enemy
	_repath_timer = 0.0


func command_stop() -> void:
	order = Order.NONE
	target_enemy = null
	_waypoints_map.clear()
	_moving_now = false
	queue_redraw()


func cast_mend() -> int:
	if not can_mend() or mend_timer > 0.0 or battlefield == null:
		return 0
	var healed_units := 0
	for u: RtsIsoUnit in battlefield.call("get_living_units"):
		if u.team == team and u.health < u.max_health and u.map_pos.distance_to(map_pos) <= MEND_RADIUS:
			u.heal(MEND_AMOUNT)
			healed_units += 1
	mend_timer = MEND_COOLDOWN
	battlefield.call("spawn_mend_pulse", map_pos, MEND_RADIUS)
	queue_redraw()
	return maxi(healed_units, 1)


func heal(amount: int) -> void:
	if not alive:
		return
	health = mini(max_health, health + amount)
	queue_redraw()


func take_damage(amount: int, attacker: RtsIsoUnit) -> void:
	if not alive:
		return
	var dealt := maxi(1, amount - armour)
	health = maxi(0, health - dealt)
	_hit_flash = 0.14
	if order == Order.NONE and not peaceful and is_enemy(attacker):
		target_enemy = attacker
	if health <= 0:
		_die()
	else:
		queue_redraw()


func _die() -> void:
	alive = false
	selected = false
	if grid != null and _claimed_cell.x >= 0:
		grid.release(_claimed_cell, self)
		_claimed_cell = Vector2i(-999, -999)
	if battlefield != null:
		battlefield.call("spawn_unit_burst", map_pos, role == Role.TANK)
	died.emit(self)
	hide()


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not alive:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_repath_timer = maxf(0.0, _repath_timer - delta)
	mend_timer = maxf(0.0, mend_timer - delta)
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)

	var was_moving := _moving_now
	_moving_now = false

	match order:
		Order.MOVE:
			_tick_move(delta)
		Order.ATTACK:
			_tick_attack(delta)
		Order.NONE:
			_tick_guard(delta)

	position = RtsIsoTransform.map_to_iso(map_pos)
	if _moving_now or was_moving or _hit_flash > 0.0 or role == Role.TANK:
		queue_redraw()


func _tick_move(delta: float) -> void:
	if _waypoints_map.is_empty():
		order = Order.NONE
		_has_prev_tread = false
		return
	_advance_along_waypoints(delta, true)


func _tick_attack(delta: float) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy) or not target_enemy.alive:
		order = Order.NONE
		target_enemy = null
		_waypoints_map.clear()
		return
	var dist := map_pos.distance_to(target_enemy.map_pos)
	if dist <= attack_range_map():
		_waypoints_map.clear()
		_aim_and_fire(target_enemy, delta)
	elif hold_position:
		order = Order.NONE
		target_enemy = null
	else:
		if _repath_timer <= 0.0 or _waypoints_map.is_empty():
			_repath_timer = 0.45
			var near := grid.free_cells_near(RtsIsoTransform.cell_of(target_enemy.map_pos), 1, [self])
			var goal_c := near[0] if not near.is_empty() else RtsIsoTransform.cell_of(target_enemy.map_pos)
			_build_smooth_route(goal_c, RtsIsoTransform.center_of(goal_c), true)
		_advance_along_waypoints(delta, false)


func _tick_guard(delta: float) -> void:
	if peaceful:
		return
	var enemy := _find_nearest_enemy()
	if enemy == null:
		return
	var dist := map_pos.distance_to(enemy.map_pos)
	if dist <= attack_range_map():
		_aim_and_fire(enemy, delta)
	elif not hold_position and dist <= guard_range_map():
		command_attack(enemy)


func _find_nearest_enemy() -> RtsIsoUnit:
	if battlefield == null:
		return null
	var best: RtsIsoUnit = null
	var best_d := INF
	for u: RtsIsoUnit in battlefield.call("get_living_units"):
		if is_enemy(u):
			var d := map_pos.distance_to(u.map_pos)
			if d < best_d:
				best_d = d
				best = u
	return best


func _aim_and_fire(enemy: RtsIsoUnit, delta: float) -> void:
	var to_enemy := enemy.map_pos - map_pos
	if to_enemy.length_squared() > 1.0:
		map_facing = to_enemy.normalized()
		var target_iso_ang := RtsIsoTransform.map_to_iso(map_facing).angle()
		if role == Role.TANK:
			turret_iso_angle = rotate_toward(turret_iso_angle, target_iso_ang, turn_rate * 1.65 * delta)
		else:
			hull_iso_angle = target_iso_ang
			turret_iso_angle = target_iso_ang

	if _attack_timer <= 0.0:
		if role == Role.TANK:
			var aim_diff := absf(angle_difference(turret_iso_angle, RtsIsoTransform.map_to_iso(map_facing).angle()))
			if aim_diff > 0.35:
				return
		_attack_timer = attack_cooldown
		var dmg := attack_damage
		if role == Role.SQUAD:
			dmg = maxi(4, roundi(float(attack_damage) * float(fit_count()) / 4.0))
		enemy.take_damage(dmg, self)
		if battlefield != null:
			battlefield.call("spawn_weapon_fire", map_pos, enemy.map_pos, team == Team.BLUE, role == Role.TANK)


func _build_smooth_route(dest_cell: Vector2i, exact_dest: Vector2, avoid_units: bool) -> void:
	_waypoints_map.clear()
	var start_cell := RtsIsoTransform.cell_of(map_pos)
	var raw_cells := grid.find_path(start_cell, dest_cell, self, avoid_units)
	if raw_cells.is_empty():
		if start_cell == dest_cell and grid.is_walkable(dest_cell):
			_waypoints_map.append(exact_dest)
		return

	var pts: Array[Vector2] = [map_pos]
	for i in range(raw_cells.size()):
		if i == raw_cells.size() - 1 and raw_cells[i] == dest_cell:
			pts.append(exact_dest)
		else:
			pts.append(RtsIsoTransform.center_of(raw_cells[i]))

	# String-pull line-of-sight smoothing in logical map coordinates so units glide naturally
	var smooth: Array[Vector2] = []
	var anchor := 0
	while anchor < pts.size() - 1:
		var furthest := anchor + 1
		for probe in range(pts.size() - 1, anchor + 1, -1):
			if _line_walkable(pts[anchor], pts[probe], avoid_units):
				furthest = probe
				break
		smooth.append(pts[furthest])
		anchor = furthest
	_waypoints_map = smooth
	_stuck_timer = 0.0


func _line_walkable(a: Vector2, b: Vector2, avoid_units := false) -> bool:
	var clearance := 9.0 if role == Role.TANK else 6.0
	for c in grid.cells_along(a, b, clearance):
		if avoid_units:
			if not grid.is_free(c, self):
				return false
		elif not grid.is_walkable(c):
			return false
	return true


func _advance_along_waypoints(delta: float, is_move_order: bool) -> void:
	if _waypoints_map.is_empty():
		return
	var wp := _waypoints_map[0]
	var to_wp := wp - map_pos
	var dist := to_wp.length()
	if dist <= 3.0:
		map_pos = wp
		_waypoints_map.remove_at(0)
		_update_cell_claim()
		if _waypoints_map.is_empty() and is_move_order:
			order = Order.NONE
			_has_prev_tread = false
		return

	var dir_map := to_wp / dist
	var next_cell := RtsIsoTransform.cell_of(map_pos + dir_map * 18.0)
	if next_cell != _claimed_cell and not grid.is_free(next_cell, self):
		_stuck_timer += delta
		if _stuck_timer > 0.28:
			var goal := _waypoints_map[_waypoints_map.size() - 1]
			var near := grid.free_cells_near(RtsIsoTransform.cell_of(goal), 1, [self])
			var gc := near[0] if not near.is_empty() else RtsIsoTransform.cell_of(goal)
			_build_smooth_route(gc, goal if gc == RtsIsoTransform.cell_of(goal) else RtsIsoTransform.center_of(gc), true)
		return
	_stuck_timer = 0.0

	var move_dir_map := dir_map
	var throttle := 1.0
	if role == Role.TANK:
		var desired_iso_ang := RtsIsoTransform.map_to_iso(dir_map).angle()
		var diff := absf(angle_difference(hull_iso_angle, desired_iso_ang))
		hull_iso_angle = rotate_toward(hull_iso_angle, desired_iso_ang, turn_rate * delta)
		turret_iso_angle = rotate_toward(turret_iso_angle, desired_iso_ang, turn_rate * 1.25 * delta)
		throttle = clampf(1.0 - diff * 0.52, 0.32, 1.0)
		var iso_forward := Vector2.from_angle(hull_iso_angle)
		var map_forward := RtsIsoTransform.iso_to_map(iso_forward).normalized()
		if diff < 0.95:
			var candidate := map_pos + map_forward * minf(dist, speed_map_px * throttle * delta)
			if grid.is_walkable(RtsIsoTransform.cell_of(candidate)):
				move_dir_map = map_forward
	else:
		map_facing = dir_map

	var step := minf(dist, speed_map_px * throttle * delta)
	var old_map := map_pos
	var next_map := map_pos + move_dir_map * step
	if grid.is_walkable(RtsIsoTransform.cell_of(next_map)):
		map_pos = next_map
		_moving_now = true
		_stride_dist += step
		_update_cell_claim()
		if role == Role.TANK and battlefield != null:
			_tread_dist += step
			if not _has_prev_tread:
				_prev_tread_map = old_map
				_prev_tread_dir = move_dir_map
				_has_prev_tread = true
			elif _tread_dist >= 3.5:
				battlefield.call("record_tank_treads", _prev_tread_map, _prev_tread_dir, map_pos, move_dir_map)
				_prev_tread_map = map_pos
				_prev_tread_dir = move_dir_map
				_tread_dist = 0.0


func _update_cell_claim() -> void:
	if grid == null:
		return
	var c := RtsIsoTransform.cell_of(map_pos)
	cell = c
	if c == _claimed_cell:
		return
	if _claimed_cell.x >= 0:
		grid.release(_claimed_cell, self)
	if grid.claim(c, self):
		_claimed_cell = c
	else:
		_claimed_cell = Vector2i(-999, -999)


func _draw() -> void:
	if _tex_main == null:
		return

	var shade := 0.0
	if battlefield != null:
		shade = float(battlefield.call("shade_at_iso", position))
	# Cool lavender-blue Fight-4 shadow tint when passing under forest canopy or cliff lee shade!
	var lit := clampf(1.0 - shade * 0.62, 0.58, 1.0)
	var tint := Color(lit * 0.98, lit * 0.99, minf(1.0, lit * 1.08 + shade * 0.06), 1.0)
	if _hit_flash > 0.0:
		tint = tint.lerp(Color.WHITE, 0.72)

	if selected:
		_draw_iso_selection_ring()
	else:
		_draw_subtle_faction_foot_cue()

	match role:
		Role.TANK:
			_draw_tank(tint)
		Role.SQUAD:
			_draw_squad(tint)
		Role.COMMANDER:
			_draw_commander(tint)

	if selected or health < max_health:
		_draw_health_bar()


func _draw_contact_shadow(offset: Vector2, rx: float, ry: float) -> void:
	draw_set_transform(offset + Vector2(3.0, 2.0), 0.0, Vector2(1.0, ry / maxf(rx, 1.0)))
	draw_circle(Vector2.ZERO, rx, Color(0.10, 0.12, 0.22, 0.28))
	draw_set_transform(offset + Vector2(0.8, 0.6), 0.0, Vector2(1.0, (ry * 0.65) / maxf(rx, 1.0)))
	draw_circle(Vector2.ZERO, rx * 0.68, Color(0.06, 0.07, 0.15, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tank(tint: Color) -> void:
	_draw_contact_shadow(Vector2(0.0, 4.0), 21.0, 12.0)
	var cw := _tex_main.get_width() / 8.0
	var ch := _tex_main.get_height() / 2.0
	var h_col := RtsIsoTransform.iso_angle_to_col8(hull_iso_angle)
	var h_row := (int(_stride_dist / 4.5) % 2) if _moving_now else 0
	var dst := Rect2(Vector2(-29.0, -32.0), Vector2(58.0, 58.0))
	draw_texture_rect_region(_tex_main, dst, Rect2(Vector2(h_col * cw, h_row * ch), Vector2(cw, ch)), tint)

	if _tex_turret != null:
		var tw := _tex_turret.get_width() / 8.0
		var th := float(_tex_turret.get_height())
		var t_col := RtsIsoTransform.iso_angle_to_col8(turret_iso_angle)
		draw_texture_rect_region(_tex_turret, dst, Rect2(Vector2(t_col * tw, 0.0), Vector2(tw, th)), tint)


func _draw_commander(tint: Color) -> void:
	_draw_contact_shadow(Vector2(0.0, 1.5), 9.0, 5.2)
	var cw := _tex_main.get_width() / 8.0
	var ch := _tex_main.get_height() / 4.0
	var col := RtsIsoTransform.map_dir_to_col8(map_facing)
	var row := (1 + int(_stride_dist / 5.5) % 3) if _moving_now else 0
	var dst := Rect2(Vector2(-17.0, -36.0), Vector2(34.0, 39.0))
	draw_texture_rect_region(_tex_main, dst, Rect2(Vector2(col * cw, row * ch), Vector2(cw, ch)), tint)


func _draw_squad(tint: Color) -> void:
	var cw := _tex_main.get_width() / 8.0
	var ch := _tex_main.get_height() / 4.0
	var col := RtsIsoTransform.map_dir_to_col8(map_facing)
	var count := fit_count()
	var rot := map_facing.angle()
	var members: Array[Dictionary] = []
	for i in range(count):
		var slot_map: Vector2 = (SQUAD_MAP_SLOTS[i] as Vector2).rotated(rot * 0.25)
		var slot_iso := RtsIsoTransform.map_to_iso(slot_map)
		var row := (1 + int((_stride_dist + float(i) * 3.9) / 5.2) % 3) if _moving_now else 0
		members.append({"iso": slot_iso, "row": row})
	members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["iso"] as Vector2).y < (b["iso"] as Vector2).y
	)
	for m in members:
		var off: Vector2 = m["iso"]
		_draw_contact_shadow(off + Vector2(0.0, 1.0), 6.8, 3.8)
		var r_idx := int(m["row"])
		var dst := Rect2(off + Vector2(-13.5, -29.0), Vector2(27.0, 31.0))
		draw_texture_rect_region(_tex_main, dst, Rect2(Vector2(col * cw, r_idx * ch), Vector2(cw, ch)), tint)


func _draw_subtle_faction_foot_cue() -> void:
	# Quiet faction ground ring so Blue vs Red reads instantaneously at Command zoom
	var r := select_radius_map() * 0.76
	var col := Color(0.26, 0.78, 1.0, 0.42) if team == Team.BLUE else Color(1.0, 0.34, 0.28, 0.56)
	var pts := PackedVector2Array()
	for i in range(17):
		var a := float(i) / 16.0 * TAU
		pts.append(RtsIsoTransform.map_to_iso(Vector2(cos(a), sin(a)) * r))
	draw_polyline(pts, col, 1.3, true)


func _draw_iso_selection_ring() -> void:
	var r := select_radius_map()
	var col := Color(0.36, 0.96, 1.0, 0.92) if team == Team.BLUE else Color(1.0, 0.44, 0.36, 0.92)
	# Project an isometric diamond/ellipse ring in true ground space!
	var pts := PackedVector2Array()
	for i in range(25):
		var a := float(i) / 24.0 * TAU
		pts.append(RtsIsoTransform.map_to_iso(Vector2(cos(a), sin(a)) * r))
	draw_polyline(pts, col, 1.6, true)
	if hold_position:
		var inner := PackedVector2Array()
		for i in range(25):
			var a := float(i) / 24.0 * TAU
			inner.append(RtsIsoTransform.map_to_iso(Vector2(cos(a), sin(a)) * (r * 0.78)))
		draw_polyline(inner, Color(0.98, 0.84, 0.32, 0.78), 1.3, true)


func _draw_health_bar() -> void:
	var w := 30.0 if role == Role.TANK else 24.0
	var top_y := -38.0 if role == Role.TANK else (-42.0 if role == Role.COMMANDER else -38.0)
	var top := Vector2(-w * 0.5, top_y)
	var ratio := clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)
	var fill := Color(0.28, 0.92, 0.40) if ratio > 0.5 else (Color(0.96, 0.78, 0.22) if ratio > 0.25 else Color(0.94, 0.24, 0.20))
	draw_rect(Rect2(top - Vector2.ONE, Vector2(w + 2.0, 5.0)), Color(0.06, 0.05, 0.08, 0.88))
	draw_rect(Rect2(top, Vector2(w * ratio, 3.0)), fill)
