class_name RtsCarbonUnit
extends Node2D
## Playable RTS unit (4-Soldier Squad, Field Commander, or Battle Tank) for RTS Reusable 2 Carbon.
## Shares identical positions, orders, stats, shade, and tracks across Detailed Painted (2x HD)
## and 960x540 Pixel (1x) modes.

signal died(unit: RtsCarbonUnit)

enum Team { BLUE, RED }
enum Role { SQUAD, COMMANDER, TANK }
enum Order { NONE, MOVE, ATTACK }

const MEND_COOLDOWN := 8.0
const MEND_RADIUS := 120.0
const MEND_AMOUNT := 30

@export var display_name := "Rifle Squad"
@export var subtitle := "Blue Infantry"
@export var portrait_key := "blue_squad"
@export var sprite_key := "blue_soldier"
@export var team: Team = Team.BLUE
@export var role: Role = Role.SQUAD

@export_group("Combat")
@export var max_health := 64
@export var attack_damage := 12
@export var armour := 3
@export var attack_range_cells := 4.8
@export var guard_range_cells := 6.5
@export var attack_cooldown := 1.05

@export_group("Movement")
@export var speed_px := 62.0
@export var turn_rate := 5.2

var battlefield: Node2D
var grid: RtsGrid
var health := 64
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
var pixel_mode := false

var cell := Vector2i.ZERO
var order: Order = Order.NONE
var target_enemy: RtsCarbonUnit = null
var move_goal_world := Vector2.ZERO

var facing := Vector2(1.0, 0.65).normalized()
var hull_angle := 0.58
var turret_angle := 0.58
var mend_timer := 0.0

var _waypoints: Array[Vector2] = []
var _claimed_cell := Vector2i(-999, -999)
var _attack_timer := 0.0
var _repath_timer := 0.0
var _stuck_timer := 0.0
var _hit_flash := 0.0
var _stride_dist := 0.0
var _tread_dist := 0.0
var _foot_dist := 0.0
var _dust_timer := 0.0
var _prev_tread_pos := Vector2.ZERO
var _prev_tread_dir := Vector2.RIGHT
var _has_prev_tread := false
var _moving_now := false

var _tex_main: Texture2D
var _tex_turret: Texture2D
var _detailed_art_directory := ""
var _squad_spacing := 1.0

# Staggered diamond offsets for 4-soldier squads (in local rotated space)
const SQUAD_SLOTS := [
	Vector2(0.0, -6.5),
	Vector2(-7.0, 0.5),
	Vector2(7.0, 0.5),
	Vector2(0.0, 6.5),
]


func setup(p_battlefield: Node2D, p_grid: RtsGrid, use_pixel: bool, detailed_art_directory := "",
		squad_spacing := 1.0) -> void:
	battlefield = p_battlefield
	grid = p_grid
	_detailed_art_directory = detailed_art_directory
	_squad_spacing = squad_spacing
	health = max_health
	cell = grid.cell_of(position)
	if not grid.is_free(cell, self):
		var free_list := grid.free_cells_near(cell, 1)
		if not free_list.is_empty():
			cell = free_list[0]
			position = grid.center_of(cell)
	if grid.claim(cell, self):
		_claimed_cell = cell
	if team == Team.BLUE:
		facing = Vector2(0.82, 0.57).normalized()
	else:
		facing = Vector2(-0.82, -0.57).normalized()
	hull_angle = facing.angle()
	turret_angle = hull_angle
	add_to_group("rts_carbon_units")
	apply_visual_mode(use_pixel)


func apply_visual_mode(use_pixel: bool) -> void:
	pixel_mode = use_pixel
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if use_pixel else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if role == Role.TANK:
		var prefix := "blue_tank" if team == Team.BLUE else "red_tank"
		_tex_main = RtsCarbonArt.texture(prefix + "_hull", use_pixel, _detailed_art_directory)
		_tex_turret = RtsCarbonArt.texture(prefix + "_turret", use_pixel, _detailed_art_directory)
	else:
		_tex_main = RtsCarbonArt.texture(sprite_key, use_pixel, _detailed_art_directory)
		_tex_turret = null
	queue_redraw()


func select_radius() -> float:
	if role == Role.TANK:
		return 16.0
	if role == Role.COMMANDER:
		return 13.0
	return 14.0


func fit_count() -> int:
	if role != Role.SQUAD:
		return 1
	return clampi(ceili(4.0 * float(health) / float(maxi(max_health, 1))), 1, 4)


func is_enemy(other: RtsCarbonUnit) -> bool:
	return other != null and other.alive and other.team != team


func attack_range_px() -> float:
	return attack_range_cells * 32.0


func guard_range_px() -> float:
	return guard_range_cells * 32.0


func can_mend() -> bool:
	return alive and role == Role.COMMANDER and team == Team.BLUE and mend_timer <= 0.0


func command_move(world_dest: Vector2) -> void:
	if not alive or grid == null:
		return
	hold_position = false
	order = Order.MOVE
	target_enemy = null
	var dest_cell := grid.cell_of(world_dest)
	if not grid.is_walkable(dest_cell):
		var near := grid.free_cells_near(dest_cell, 1, [self])
		if near.is_empty():
			return
		dest_cell = near[0]
		world_dest = grid.center_of(dest_cell)
	move_goal_world = world_dest
	_build_smooth_route(dest_cell, world_dest, false)


func command_attack(enemy: RtsCarbonUnit) -> void:
	if not alive or not is_enemy(enemy):
		return
	order = Order.ATTACK
	target_enemy = enemy
	_repath_timer = 0.0
	_waypoints.clear()


func command_stop() -> void:
	order = Order.NONE
	target_enemy = null
	_waypoints.clear()
	_moving_now = false
	_has_prev_tread = false
	queue_redraw()


func cast_mend() -> int:
	if not can_mend() or battlefield == null:
		return 0
	mend_timer = MEND_COOLDOWN
	var healed_units := 0
	for node in get_tree().get_nodes_in_group("rts_carbon_units"):
		var u := node as RtsCarbonUnit
		if u == null or not u.alive or u.team != team:
			continue
		if u.position.distance_to(position) <= MEND_RADIUS and u.health < u.max_health:
			u.heal(MEND_AMOUNT)
			healed_units += 1
	# Always emit the visual cyan aura even if squad is topped off so player gets crisp feedback
	battlefield.call("spawn_mend_pulse", position, MEND_RADIUS)
	queue_redraw()
	return healed_units


func heal(amount: int) -> void:
	if not alive:
		return
	health = mini(max_health, health + amount)
	queue_redraw()


func take_damage(amount: int, attacker: RtsCarbonUnit) -> void:
	if not alive:
		return
	var actual := maxi(1, amount - armour)
	health -= actual
	_hit_flash = 0.11
	queue_redraw()
	if health <= 0:
		_die()
		return
	if not peaceful and order == Order.NONE and is_enemy(attacker):
		if hold_position:
			if position.distance_to(attacker.position) <= attack_range_px():
				target_enemy = attacker
		else:
			command_attack(attacker)


func _die() -> void:
	alive = false
	health = 0
	selected = false
	order = Order.NONE
	if grid != null and _claimed_cell.x >= 0:
		grid.release(_claimed_cell, self)
		_claimed_cell = Vector2i(-999, -999)
	remove_from_group("rts_carbon_units")
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not alive or grid == null:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	mend_timer = maxf(0.0, mend_timer - delta)
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		queue_redraw()

	_moving_now = false
	match order:
		Order.MOVE:
			_tick_move(delta)
		Order.ATTACK:
			_tick_attack(delta)
		Order.NONE:
			if not peaceful:
				_tick_guard(delta)

	if not _moving_now:
		_has_prev_tread = false
		# Smoothly settle tank turret back toward hull facing when idle
		if role == Role.TANK and (target_enemy == null or not target_enemy.alive):
			turret_angle = lerp_angle(turret_angle, hull_angle, minf(1.0, delta * 4.0))


func _tick_move(delta: float) -> void:
	if _waypoints.is_empty():
		command_stop()
		return
	_advance_along_waypoints(delta, true)


func _tick_attack(delta: float) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy) or not target_enemy.alive:
		command_stop()
		return
	var dist := position.distance_to(target_enemy.position)
	if dist <= attack_range_px() and _can_fire_at(target_enemy):
		_waypoints.clear()
		_aim_and_fire(target_enemy, delta)
		return
	if hold_position:
		command_stop()
		return
	_repath_timer -= delta
	if _waypoints.is_empty() or _repath_timer <= 0.0:
		_repath_timer = 0.55
		_build_smooth_route(grid.cell_of(target_enemy.position), target_enemy.position, false)
	_advance_along_waypoints(delta, false)


func _tick_guard(delta: float) -> void:
	var nearest := _find_nearest_enemy()
	if nearest == null:
		return
	var dist := position.distance_to(nearest.position)
	if dist <= attack_range_px() and _can_fire_at(nearest):
		_aim_and_fire(nearest, delta)
	elif not hold_position and dist <= guard_range_px():
		command_attack(nearest)


func _can_fire_at(_enemy: RtsCarbonUnit) -> bool:
	return true


func _find_nearest_enemy() -> RtsCarbonUnit:
	var best: RtsCarbonUnit = null
	var best_d2 := INF
	for node in get_tree().get_nodes_in_group("rts_carbon_units"):
		var other := node as RtsCarbonUnit
		if not is_enemy(other):
			continue
		var d2 := position.distance_squared_to(other.position)
		if d2 < best_d2:
			best_d2 = d2
			best = other
	return best


func _aim_and_fire(enemy: RtsCarbonUnit, delta: float) -> void:
	var dir := (enemy.position - position).normalized()
	if dir.length_squared() > 0.01:
		facing = dir
		if role == Role.TANK:
			turret_angle = lerp_angle(turret_angle, dir.angle(), minf(1.0, delta * 8.5))
		else:
			hull_angle = dir.angle()
	queue_redraw()
	if _attack_timer > 0.0:
		return
	_attack_timer = attack_cooldown
	var muzzle_world := position + dir * (16.0 if role == Role.TANK else 10.0) + Vector2(0.0, -3.0)
	if battlefield != null:
		battlefield.call("spawn_weapon_fire", muzzle_world, enemy.position, team == Team.BLUE, role == Role.TANK)
	enemy.take_damage(attack_damage, self)


func _build_smooth_route(dest_cell: Vector2i, exact_dest: Vector2, avoid_units: bool) -> void:
	_waypoints.clear()
	var from_cell := grid.cell_of(position)
	var raw_cells := grid.find_path(from_cell, dest_cell, self, avoid_units)
	if raw_cells.is_empty():
		if from_cell == dest_cell and grid.is_walkable(dest_cell):
			_waypoints.append(exact_dest)
		return

	var pts: Array[Vector2] = [position]
	for i in range(raw_cells.size()):
		if raw_cells[i] == dest_cell and grid.cell_of(exact_dest) == dest_cell:
			pts.append(exact_dest)
		else:
			pts.append(grid.center_of(raw_cells[i]))

	# String-pull line of sight across walkable cells so units move at natural free angles!
	var anchor := 0
	while anchor < pts.size() - 1:
		var furthest := anchor + 1
		for probe in range(pts.size() - 1, anchor + 1, -1):
			if _may_smooth_between(pts[anchor], pts[probe], avoid_units):
				furthest = probe
				break
		_waypoints.append(pts[furthest])
		anchor = furthest


func _may_smooth_between(a: Vector2, b: Vector2, _avoid_units: bool) -> bool:
	return _line_walkable(a, b)


func _line_walkable(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var steps := maxi(2, int(ceil(dist / 10.0)))
	var perp := (b - a).normalized().orthogonal() * (11.0 if role == Role.TANK else 7.0)
	for i in range(1, steps):
		var t := float(i) / float(steps)
		var p := a.lerp(b, t)
		if not grid.is_walkable(grid.cell_of(p)):
			return false
		if not grid.is_walkable(grid.cell_of(p + perp)) or not grid.is_walkable(grid.cell_of(p - perp)):
			return false
	return true


func _advance_along_waypoints(delta: float, is_move_order: bool) -> void:
	if _waypoints.is_empty():
		return
	var wp: Vector2 = _waypoints[0]
	var to_wp := wp - position
	var dist := to_wp.length()
	if dist < 2.0:
		position = wp
		_waypoints.pop_front()
		_update_cell_claim()
		if _waypoints.is_empty() and is_move_order:
			command_stop()
		return

	var desired_dir := to_wp / dist
	# Check next cell occupancy so units neatly detour instead of overlapping
	var ahead_pos := position + desired_dir * minf(18.0, dist)
	var ahead_cell := grid.cell_of(ahead_pos)
	if ahead_cell != _claimed_cell and not grid.is_free(ahead_cell, self):
		_stuck_timer += delta
		var blocker := grid.unit_at(ahead_cell) as RtsCarbonUnit
		if is_move_order and _waypoints.size() == 1 and dist < 34.0 and blocker != null and not blocker._moving_now:
			var spots := grid.free_cells_near(grid.cell_of(move_goal_world), 1, [self])
			if not spots.is_empty():
				move_goal_world = grid.center_of(spots[0])
				_build_smooth_route(spots[0], move_goal_world, true)
			else:
				command_stop()
			return
		if _stuck_timer >= 0.30:
			_stuck_timer = 0.0
			var goal_c := grid.cell_of(_waypoints[_waypoints.size() - 1])
			_build_smooth_route(goal_c, _waypoints[_waypoints.size() - 1], true)
		return
	_stuck_timer = 0.0

	# Dune uphill step modulation: subtle shorter/slower stride climbing a dune crest!
	var grade := 0.0
	if battlefield != null:
		grade = float(battlefield.call("grade_at", position, desired_dir))
	var slope_mult := clampf(1.0 - grade * 0.65, 0.84, 1.06)

	if role == Role.TANK:
		var target_ang := desired_dir.angle()
		var ang_diff := absf(wrapf(target_ang - hull_angle, -PI, PI))
		hull_angle = lerp_angle(hull_angle, target_ang, minf(1.0, turn_rate * delta))
		facing = Vector2.from_angle(hull_angle)
		turret_angle = lerp_angle(turret_angle, hull_angle, minf(1.0, turn_rate * 1.15 * delta))
		# Tank slows slightly on sharp pivot, curves smoothly rather than snapping!
		var turn_throttle := clampf(1.0 - ang_diff * 0.42, 0.32, 1.0)
		var step := speed_px * slope_mult * turn_throttle * delta
		var move_vec := facing * minf(step, dist)
		var next_pos := _tank_step(desired_dir, move_vec, step, dist)
		var moved := next_pos.distance_to(position)
		if moved > 0.01:
			_record_motion_fx(position, next_pos, facing, moved, slope_mult, delta)
			position = next_pos
			_moving_now = true
			_update_cell_claim()
	else:
		facing = facing.lerp(desired_dir, minf(1.0, 12.0 * delta)).normalized()
		hull_angle = facing.angle()
		var step_inf := speed_px * slope_mult * delta
		var moved_inf := minf(step_inf, dist)
		var next_inf := position + desired_dir * moved_inf
		_record_motion_fx(position, next_inf, facing, moved_inf, slope_mult, delta)
		position = next_inf
		_moving_now = true
		_update_cell_claim()

	queue_redraw()


func _tank_step(direction: Vector2, displacement: Vector2, step: float, distance: float) -> Vector2:
	var next := position + displacement
	if not grid.is_walkable(grid.cell_of(next)):
		return position + direction * minf(step * 0.6, distance)
	return next


func _update_cell_claim() -> void:
	var now_cell := grid.cell_of(position)
	if now_cell == _claimed_cell:
		return
	if grid.claim(now_cell, self):
		if _claimed_cell.x >= 0:
			grid.release(_claimed_cell, self)
		_claimed_cell = now_cell
		cell = now_cell


func _record_motion_fx(old_pos: Vector2, new_pos: Vector2, dir: Vector2, moved: float, slope_mult: float, delta: float) -> void:
	# Shorter uphill stride cycles legs slightly tighter when climbing a dune
	var cadence_scale := 1.0 / maxf(slope_mult, 0.82)
	_stride_dist += moved * cadence_scale
	if battlefield == null:
		return
	if role == Role.TANK:
		_tread_dist += moved
		if not _has_prev_tread:
			_prev_tread_pos = old_pos
			_prev_tread_dir = dir
			_has_prev_tread = true
		elif _tread_dist >= 2.2:
			_tread_dist = 0.0
			battlefield.call("record_tank_treads", _prev_tread_pos, _prev_tread_dir, new_pos, dir)
			_prev_tread_pos = new_pos
			_prev_tread_dir = dir
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = 0.08
			battlefield.call("spawn_dust", new_pos - dir * 12.0 + Vector2(0.0, 3.0), -dir)
	else:
		_foot_dist += moved
		if _foot_dist >= 5.5:
			_foot_dist = 0.0
			battlefield.call("spawn_footprint", new_pos + Vector2(0.0, 4.0), dir)


static func dir_to_col(dir: Vector2) -> int:
	# 0:S, 1:SW, 2:W, 3:NW, 4:N, 5:NE, 6:E, 7:SE
	return posmod(roundi(atan2(-dir.x, dir.y) / (PI / 4.0)), 8)


func _draw() -> void:
	if _tex_main == null:
		return

	# Pixel mode snaps local draw offset so sprites sit on crisp whole logical art pixels!
	var snap_off := _draw_origin() + ((position.round() - position) if pixel_mode else Vector2.ZERO)

	# Lee shadow darkening from cliffs, mesas, outpost & Orichalcum rock!
	var shade := 0.0
	if battlefield != null:
		shade = float(battlefield.call("shade_at", position))
	var light_mult := clampf(1.0 - shade * 0.68, 0.56, 1.0)
	# Battlefields with tall terrain light the sunward slopes (upper left) and darken the far side.
	if battlefield != null and battlefield.has_method("terrain_light_at"):
		light_mult = clampf(light_mult * float(battlefield.call("terrain_light_at", position)), 0.5, 1.15)
	var tint := Color(light_mult, light_mult * 0.99, minf(1.0, light_mult * 1.04), 1.0)
	if _hit_flash > 0.0:
		tint = tint.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.72)

	if selected:
		_draw_selection_ring(snap_off)

	if role == Role.TANK:
		_draw_tank(snap_off, tint)
	elif role == Role.SQUAD:
		_draw_squad(snap_off, tint)
	else:
		_draw_commander(snap_off, tint)

	if selected or health < max_health:
		_draw_health_bar(snap_off)


func _draw_direction(dir: Vector2) -> Vector2:
	return dir


func _draw_slot(slot: Vector2) -> Vector2:
	return slot


func _draw_origin() -> Vector2:
	# Battlefields with tall terrain (hills) raise units with the ground they stand on.
	if battlefield != null and battlefield.has_method("terrain_lift_at"):
		return Vector2(0.0, -float(battlefield.call("terrain_lift_at", position)))
	return Vector2.ZERO


func _draw_unit_shadow(center: Vector2, rx: float, ry: float) -> void:
	# Soft top-left -> down-right cast shadow + tight contact patch at base
	draw_set_transform(center + Vector2(3.2, 2.4), 0.0, Vector2(1.0, ry / maxf(rx, 1.0)))
	draw_circle(Vector2.ZERO, rx, Color(0.14, 0.05, 0.01, 0.28))
	draw_set_transform(center + Vector2(0.8, 0.8), 0.0, Vector2(1.0, (ry * 0.65) / maxf(rx, 1.0)))
	draw_circle(Vector2.ZERO, rx * 0.68, Color(0.08, 0.03, 0.0, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tank(snap_off: Vector2, tint: Color) -> void:
	_draw_unit_shadow(snap_off + Vector2(0.0, 3.0), 14.5, 8.5)
	var cell_w := _tex_main.get_width() / 8.0
	var cell_h := _tex_main.get_height() / 2.0
	var hull_col := dir_to_col(_draw_direction(Vector2.from_angle(hull_angle)))
	var hull_row := (int(_stride_dist / 4.0) % 2) if _moving_now else 0
	var dst_rect := Rect2(snap_off - Vector2(18.0, 18.0), Vector2(36.0, 36.0))
	var src_hull := Rect2(Vector2(hull_col * cell_w, hull_row * cell_h), Vector2(cell_w, cell_h))
	draw_texture_rect_region(_tex_main, dst_rect, src_hull, tint)

	if _tex_turret != null:
		var t_col := dir_to_col(_draw_direction(Vector2.from_angle(turret_angle)))
		var tw := _tex_turret.get_width() / 8.0
		var th := float(_tex_turret.get_height())
		var src_tur := Rect2(Vector2(t_col * tw, 0.0), Vector2(tw, th))
		draw_texture_rect_region(_tex_turret, dst_rect, src_tur, tint)


func _draw_commander(snap_off: Vector2, tint: Color) -> void:
	_draw_unit_shadow(snap_off + Vector2(0.0, 5.5), 6.2, 3.2)
	var cw := _tex_main.get_width() / 8.0
	var ch := _tex_main.get_height() / 4.0
	var col := dir_to_col(_draw_direction(facing))
	var row := (int(_stride_dist / 5.0) % 4) if _moving_now else 0
	var dst := Rect2(snap_off - Vector2(10.0, 15.0), Vector2(20.0, 23.0))
	var src := Rect2(Vector2(col * cw, row * ch), Vector2(cw, ch))
	draw_texture_rect_region(_tex_main, dst, src, tint)


func _draw_squad(snap_off: Vector2, tint: Color) -> void:
	var cw := _tex_main.get_width() / 8.0
	var ch := _tex_main.get_height() / 4.0
	var col := dir_to_col(_draw_direction(facing))
	var count := fit_count()

	# Gently orient the 4-soldier diamond with facing, then sort back-to-front by Y!
	var rot := facing.angle() - PI * 0.5
	var members: Array[Dictionary] = []
	for i in range(count):
		var slot := _draw_slot((SQUAD_SLOTS[i] as Vector2).rotated(rot * 0.35) * _squad_spacing)
		if pixel_mode:
			slot = slot.round()
		var row := (int((_stride_dist + float(i) * 3.7) / 4.8) % 4) if _moving_now else 0
		members.append({"off": slot, "row": row})
	members.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["off"] as Vector2).y < (b["off"] as Vector2).y
	)

	for m in members:
		var m_off: Vector2 = snap_off + (m["off"] as Vector2)
		_draw_unit_shadow(m_off + Vector2(0.0, 4.5), 4.6, 2.4)
		var m_row: int = int(m["row"])
		var dst := Rect2(m_off - Vector2(8.0, 12.0), Vector2(16.0, 18.0))
		var src := Rect2(Vector2(col * cw, m_row * ch), Vector2(cw, ch))
		draw_texture_rect_region(_tex_main, dst, src, tint)


func _draw_selection_ring(snap_off: Vector2) -> void:
	var r := select_radius()
	var col := Color(0.38, 1.0, 0.42, 0.92) if team == Team.BLUE else Color(1.0, 0.42, 0.35, 0.92)
	# Crisp corner brackets matching RTS tactical readability!
	var bx := r
	var by := r * 0.72
	var leg := 4.5
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := snap_off + Vector2(sx * bx, sy * by + 2.0)
			draw_line(corner, corner + Vector2(-sx * leg, 0.0), col, 1.4)
			draw_line(corner, corner + Vector2(0.0, -sy * leg), col, 1.4)
	if hold_position:
		draw_arc(snap_off + Vector2(0.0, 2.0), r * 0.85, 0.0, TAU, 24, Color(0.98, 0.84, 0.32, 0.55), 1.1)


func _draw_health_bar(snap_off: Vector2) -> void:
	var w := 24.0 if role == Role.TANK else 20.0
	var top := snap_off + Vector2(-w * 0.5, -select_radius() - 6.0)
	var ratio := clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)
	var fill_col := Color(0.28, 0.92, 0.36) if ratio > 0.5 else (Color(0.96, 0.78, 0.22) if ratio > 0.25 else Color(0.94, 0.24, 0.20))
	draw_rect(Rect2(top - Vector2.ONE, Vector2(w + 2.0, 5.0)), Color(0.08, 0.05, 0.04, 0.88))
	draw_rect(Rect2(top, Vector2(w * ratio, 3.0)), fill_col)
