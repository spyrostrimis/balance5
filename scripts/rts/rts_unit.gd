class_name RtsUnit
extends Node2D
## One RTS unit: walks tile to tile along A* routes, attacks, takes damage and dies.
## Its numbers come from `stats` (a UnitStats .tres file). Without a sprite it draws a
## placeholder disc: team colour, a facing notch, and an emblem for commanders.
## The map calls setup(grid) once; after that the unit runs itself in _physics_process.

signal died(unit: RtsUnit)

enum Order { NONE, MOVE, ATTACK }

## How often a chasing unit re-plans its route to a moving target, in seconds.
const REPATH_INTERVAL := 0.5
## How long to wait behind another unit before looking for a way around it.
const BLOCKED_WAIT := 0.35
## A move order is dropped after being stuck this long.
const GIVE_UP_TIME := 3.0
const SHOT_TIME := 0.12
const FLASH_TIME := 0.1
const OUTLINE := Color(0.08, 0.06, 0.05)
const SELECT_COLOR := Color(0.35, 1.0, 0.35)
const GOLD := Color(0.98, 0.8, 0.3)
const CYAN := Color(0.45, 1.0, 1.0)

@export var stats: UnitStats

var grid: RtsGrid
var health := 0
var alive := true
var cell := Vector2i.ZERO
var order := Order.NONE
var goal := Vector2i.ZERO
var target: RtsUnit
## Peaceful units neither shoot on their own nor hit back (used by the units test's patrol).
var peaceful := false
var selected := false:
	set(value):
		selected = value
		queue_redraw()

var _path: Array[Vector2i] = []
var _path_dest := Vector2i(-99999, -99999)
var _stepping := false
var _next_cell := Vector2i.ZERO
var _cooldown := 0.0
var _repath_timer := 0.0
var _blocked_time := 0.0
var _facing := Vector2.RIGHT
var _shot_timer := 0.0
var _shot_to := Vector2.ZERO
var _flash := 0.0
var _anim_time := 0.0
var _mark_distance := 0.0
var _dust_timer := 0.0


func setup(p_grid: RtsGrid) -> void:
	grid = p_grid
	health = stats.max_health
	cell = grid.cell_of(position)
	if not grid.is_free(cell, self):
		var spots := grid.free_cells_near(cell, 1)
		if not spots.is_empty():
			cell = spots[0]
	position = grid.center_of(cell)
	if not grid.claim(cell, self):
		push_warning("%s starts on a blocked or taken tile %s" % [name, cell])
	_facing = Vector2.RIGHT if stats.faction == UnitStats.Faction.BLUE else Vector2.LEFT
	add_to_group("rts_units")
	queue_redraw()


func radius() -> float:
	return 13.0 if stats.kind == UnitStats.Kind.COMMANDER else 10.0


func is_enemy_of(other: RtsUnit) -> bool:
	return other != null and other.stats.faction != stats.faction


func is_moving() -> bool:
	return _stepping or not _path.is_empty()


func in_range_of(other: RtsUnit) -> bool:
	return RtsGrid.tile_distance(cell, other.cell) <= stats.attack_range


# --- Orders --------------------------------------------------------------------------------

func command_move(dest: Vector2i) -> void:
	if not alive:
		return
	order = Order.MOVE
	goal = dest
	target = null
	_reset_route()


func command_attack(enemy: RtsUnit) -> void:
	if not alive or enemy == null or not enemy.alive or not is_enemy_of(enemy):
		return
	order = Order.ATTACK
	target = enemy
	_reset_route()


func command_stop() -> void:
	order = Order.NONE
	target = null
	_reset_route()


func _reset_route() -> void:
	_path.clear()
	_path_dest = Vector2i(-99999, -99999)
	_blocked_time = 0.0
	_repath_timer = 0.0


# --- Each physics frame --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if grid != null:
		tick(delta)


## One step of the unit's life. Tests call this directly to fast-forward a fight.
func tick(delta: float) -> void:
	if not alive:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if _shot_timer > 0.0 or _flash > 0.0:
		_shot_timer = maxf(0.0, _shot_timer - delta)
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()
	# A unit always finishes the tile step it has started, so it never stands between tiles.
	if _stepping:
		_advance(delta)
		if _stepping:
			return
	match order:
		Order.MOVE:
			_tick_move(delta)
		Order.ATTACK:
			_tick_attack(delta)
		Order.NONE:
			if not peaceful:
				_tick_idle()


func _tick_move(delta: float) -> void:
	if cell == goal:
		command_stop()
		return
	_walk_toward(goal, delta, true)


func _tick_attack(delta: float) -> void:
	if not is_instance_valid(target) or not target.alive:
		command_stop()
		return
	if in_range_of(target):
		_path.clear()
		_fire_at(target)
		return
	_repath_timer -= delta
	if _path_dest != target.cell and _repath_timer <= 0.0:
		_path.clear()
		_repath_timer = REPATH_INTERVAL
	_walk_toward(target.cell, delta, false)


## Idle units shoot the nearest enemy in range. Failing that, they go after the nearest enemy
## within guard range.
func _tick_idle() -> void:
	var best: RtsUnit = null
	var best_dist := 99999
	for node in get_tree().get_nodes_in_group("rts_units"):
		var other := node as RtsUnit
		if other == null or not other.alive or not is_enemy_of(other):
			continue
		var d := RtsGrid.tile_distance(cell, other.cell)
		if d < best_dist:
			best = other
			best_dist = d
	if best == null:
		return
	if best_dist <= stats.attack_range:
		_fire_at(best)
	elif best_dist <= stats.guard_range:
		command_attack(best)


func _walk_toward(dest: Vector2i, delta: float, is_move_order: bool) -> void:
	if _path.is_empty() or _path_dest != dest:
		_path = grid.find_path(cell, dest, self)
		_path_dest = dest
		if _path.is_empty():
			if is_move_order:
				command_stop()  # Nowhere to go.
			return
	var next: Vector2i = _path[0]
	if grid.claim(next, self):
		_path.pop_front()
		_start_step(next)
		return
	# Another unit holds the next tile.
	_blocked_time += delta
	var holder := grid.unit_at(next) as RtsUnit
	if is_move_order and next == dest and holder != null and not holder.is_moving():
		# Someone has settled on our destination: take the nearest free tile instead.
		var spots := grid.free_cells_near(dest, 1, [self])
		goal = spots[0] if not spots.is_empty() else cell
		_path.clear()
		return
	if _blocked_time >= BLOCKED_WAIT:
		var detour := grid.find_path(cell, dest, self, true)
		if not detour.is_empty() and detour[0] != next:
			_path = detour
			_path_dest = dest
			_blocked_time = 0.0
			return
	if _blocked_time >= GIVE_UP_TIME:
		if is_move_order:
			command_stop()
		else:
			_reset_route()


func _start_step(next: Vector2i) -> void:
	_next_cell = next
	_stepping = true
	_blocked_time = 0.0


func _advance(delta: float) -> void:
	var to := grid.center_of(_next_cell)
	var offset := to - position
	var step := stats.move_speed * float(grid.tile_size.x) * delta
	if offset.length() > 0.01:
		_facing = offset.normalized()
	_leave_marks(minf(step, offset.length()), delta)
	if offset.length() <= step:
		position = to
		grid.release(cell, self)
		cell = _next_cell
		_stepping = false
	else:
		position += offset.normalized() * step
	queue_redraw()


## Tracks or footprints every few pixels, dust behind vehicles (see RtsLook).
func _leave_marks(moved: float, delta: float) -> void:
	_anim_time += delta
	if stats.sprite == null or RtsLook.instance == null:
		return
	_mark_distance += moved
	var gap := 3.0 if stats.vehicle else 5.0
	if _mark_distance >= gap:
		_mark_distance = 0.0
		if stats.vehicle:
			RtsLook.instance.add_track(position, _facing.angle())
		else:
			var side := _facing.orthogonal() * (2.0 if int(_anim_time * 8.0) % 2 == 0 else -2.0)
			RtsLook.instance.add_footprints(position + Vector2(0, 4) + side)
	if stats.vehicle:
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			_dust_timer = 0.07
			RtsLook.instance.add_dust(position - _facing * 10.0 + Vector2(0, 3), -_facing)


# --- Combat --------------------------------------------------------------------------------

func _fire_at(enemy: RtsUnit) -> void:
	_facing = (enemy.position - position).normalized()
	if _cooldown > 0.0:
		return
	_cooldown = stats.attack_cooldown
	_shot_timer = SHOT_TIME
	_shot_to = enemy.position
	queue_redraw()
	enemy.take_damage(stats.damage_against(enemy.stats), self)


func take_damage(amount: int, attacker: RtsUnit) -> void:
	if not alive:
		return
	health -= amount
	_flash = FLASH_TIME
	queue_redraw()
	if health <= 0:
		_die()
		return
	# Hit back: an idle unit goes after whoever shot it.
	if not peaceful and order == Order.NONE and not _stepping and is_instance_valid(attacker) and attacker.alive:
		command_attack(attacker)


func _die() -> void:
	alive = false
	health = 0
	selected = false
	order = Order.NONE
	grid.release(cell, self)
	if _stepping:
		grid.release(_next_cell, self)
	remove_from_group("rts_units")
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


# --- Placeholder drawing -------------------------------------------------------------------

func _draw() -> void:
	if stats == null:
		return
	var r := radius()
	if stats.sprite != null:
		_draw_sprite_unit(r)
	else:
		# Shadow, offset down-right (light from the top-left).
		draw_set_transform(Vector2(2.5, 3.5), 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if selected:
		_draw_brackets(r + 4.0)
	var body := stats.color().lerp(Color.WHITE, 0.7 if _flash > 0.0 else 0.0)
	if stats.sprite == null:
		draw_circle(Vector2.ZERO, r, OUTLINE)
		draw_circle(Vector2.ZERO, r - 1.5, body)
		draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.35, body.lightened(0.25))  # top-left highlight
		# Facing notch.
		draw_line(_facing * r * 0.35, _facing * (r + 3.0), OUTLINE, 4.0)
		draw_line(_facing * r * 0.4, _facing * (r + 2.0), body.lightened(0.6), 2.0)
		if stats.kind == UnitStats.Kind.COMMANDER:
			draw_arc(Vector2.ZERO, r - 4.0, 0.0, TAU, 24, GOLD, 2.0)
			if stats.faction == UnitStats.Faction.BLUE:
				draw_line(Vector2(-4, 0), Vector2(4, 0), CYAN, 2.5)  # healer's cross
				draw_line(Vector2(0, -4), Vector2(0, 4), CYAN, 2.5)
			else:
				draw_colored_polygon(PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)]), GOLD)
	if selected or health < stats.max_health:
		_draw_health_bar(r)
	if _shot_timer > 0.0:
		var hit := _shot_to - position
		if stats.attack_range > 1:
			draw_line(_facing * r, hit, Color(1.0, 0.95, 0.55), 2.0)
		else:
			draw_line(hit + Vector2(-5, -5), hit + Vector2(5, 5), Color.WHITE, 2.0)
			draw_line(hit + Vector2(-5, 5), hit + Vector2(5, -5), Color.WHITE, 2.0)


## A unit drawn from its sprite, grounded on the map: soft shadow down-right and a dark contact
## line at its base, lit like the ground under it, facing where it moves, bobbing as it walks.
func _draw_sprite_unit(r: float) -> void:
	var tex := stats.sprite
	var cols := 8 if stats.sprite_directions == 8 else 1
	var frame_size := Vector2(tex.get_width() / float(cols), tex.get_height() / float(stats.sprite_frames))
	var size := frame_size * stats.sprite_scale
	var moving := is_moving()
	var foot := Vector2(0, size.y * 0.32)
	if RtsLook.shadows:
		var spread := size.x * (0.5 if stats.vehicle else 0.42)
		draw_set_transform(foot + Vector2(3, 2), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, spread, Color(0.16, 0.06, 0.0, 0.28))
		draw_set_transform(foot + Vector2(1, 1), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, spread * 0.7, Color(0.1, 0.03, 0.0, 0.32))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var col := 0
	if cols == 8:
		col = posmod(roundi(atan2(-_facing.x, _facing.y) / (PI / 4.0)), 8)
	var row := int(_anim_time * 10.0) % stats.sprite_frames if moving else 0
	var src := Rect2(Vector2(col * frame_size.x, row * frame_size.y), frame_size)
	var bob := -1.0 if (moving and not stats.vehicle and int(_anim_time * 7.0) % 2 == 0) else 0.0
	var light := RtsLook.light_at(position)
	var tint := Color(light, light, light).lerp(Color(2, 2, 2), 1.0 if _flash > 0.0 else 0.0)
	var flip := cols == 1 and _facing.x < -0.2
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	draw_texture_rect_region(tex, Rect2(-size * 0.5, size), src, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_brackets(half: float) -> void:
	var l := half * 0.55
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := Vector2(sx * half, sy * half)
			draw_line(corner, corner - Vector2(sx * l, 0), SELECT_COLOR, 2.0)
			draw_line(corner, corner - Vector2(0, sy * l), SELECT_COLOR, 2.0)


func _draw_health_bar(r: float) -> void:
	var w := r * 2.0 + 4.0
	var top_left := Vector2(-w * 0.5, -r - 9.0)
	var ratio := clampf(float(health) / float(stats.max_health), 0.0, 1.0)
	var fill := Color(0.3, 0.9, 0.3) if ratio > 0.5 else (Color(0.95, 0.8, 0.2) if ratio > 0.25 else Color(0.95, 0.25, 0.2))
	draw_rect(Rect2(top_left - Vector2.ONE, Vector2(w + 2.0, 6.0)), OUTLINE)
	draw_rect(Rect2(top_left, Vector2(w * ratio, 4.0)), fill)
