extends RtsUnit
## The second units study shares orders, combat and health with the original.
## A* supplies the navigable corridor. Travel and artwork use world distances inside it.

const CLEARANCE := 8.0
const CORNER_REACH := 10.0
const TURN_SPEED := 5.6
const FORMATION := [Vector2(-7, -6), Vector2(6, -5), Vector2(-6, 7), Vector2(8, 8)]
const PHASE := [0.0, 0.39, 0.67, 0.18]
const WALK_ROWS := 16

var art_hd: Texture2D
var art_pixel: Texture2D
var painted := true
var distance_walked := 0.0

var _route: Array[Vector2] = []
var _extra_claims: Array[Vector2i] = []
var _moving_now := false
var _track_start := Vector2.ZERO
var _track_heading := Vector2.RIGHT
var _turn_delta := 0.0


func _reset_route() -> void:
	super._reset_route()
	_route.clear()
	_moving_now = false
	if stats.vehicle:
		_mark_distance = 0.0
	queue_redraw()


func is_moving() -> bool:
	return not _route.is_empty()


func tick(delta: float) -> void:
	var was_moving := _moving_now
	_moving_now = false
	_turn_delta = delta
	super.tick(delta)
	if was_moving or _moving_now:
		queue_redraw()


func _walk_toward(dest: Vector2i, delta: float, is_move_order: bool) -> void:
	if dest != _path_dest or _route.is_empty():
		_plan_route(dest, false)
		if _route.is_empty():
			_wait_for_space(dest, delta, is_move_order)
			return
	var offset := _route[0] - position
	var desired := offset.normalized()
	if stats.vehicle:
		var error := absf(angle_difference(_facing.angle(), desired.angle()))
		_facing = Vector2.from_angle(rotate_toward(_facing.angle(), desired.angle(), TURN_SPEED * delta))
		queue_redraw()
		if error > PI / 3.0:
			return
	else:
		_facing = desired
	var speed := stats.move_speed * grid.tile_size.x
	if stats.vehicle:
		speed *= maxf(0.48, _facing.dot(desired))
	var next := position.move_toward(_route[0], speed * delta)
	var claims := grid.cells_along(position, next, CLEARANCE)
	for tile in claims:
		if not grid.is_free(tile, self):
			_wait_for_space(dest, delta, is_move_order)
			return
	for tile in claims:
		grid.claim(tile, self)
	var previous := position
	position = next
	cell = grid.cell_of(position)
	# Keep every cell still under the unit, even if a command stops it on a boundary.
	var standing := grid.cells_along(position, position, CLEARANCE)
	for tile in _extra_claims + claims:
		if tile not in standing:
			grid.release(tile, self)
	_extra_claims = standing
	_blocked_time = 0.0
	if position.is_equal_approx(_route[0]):
		_route.pop_front()
	_leave_distance_marks(previous)


func _tick_move(delta: float) -> void:
	if position.is_equal_approx(grid.center_of(goal)):
		command_stop()
		return
	_walk_toward(goal, delta, true)


func _wait_for_space(dest: Vector2i, delta: float, move_order: bool) -> void:
	_blocked_time += delta
	var holder := grid.unit_at(dest) as RtsUnit
	if move_order and holder != null and holder != self and not holder.is_moving():
		var spots := grid.free_cells_near(dest, 1, [self])
		goal = spots[0] if not spots.is_empty() else cell
		_route.clear()
		return
	if _blocked_time >= GIVE_UP_TIME:
		if move_order:
			command_stop()
		else:
			_reset_route()
		return
	if _blocked_time >= BLOCKED_WAIT and _repath_timer <= 0.0:
		_repath_timer = BLOCKED_WAIT
		var current_route := _route.duplicate()
		_plan_route(dest, true)
		if _route.is_empty() or (move_order and not _route.back().is_equal_approx(grid.center_of(dest))):
			_route = current_route
	else:
		_repath_timer -= delta


func _plan_route(dest: Vector2i, avoid_units: bool) -> void:
	_path_dest = dest
	_route.clear()
	var tiles := grid.find_path(cell, dest, self, avoid_units)
	if not avoid_units and not grid.is_walkable(dest):
		return
	# Attack destinations are occupied. The normal combat tick stops travel in range.
	var waypoints: Array[Vector2] = [position, grid.center_of(cell)]
	for tile in tiles:
		waypoints.append(grid.center_of(tile))
	if position.is_equal_approx(waypoints[1]):
		waypoints.remove_at(1)
	var straight: Array[Vector2] = [position]
	var i := 0
	while i < waypoints.size() - 1:
		var next := waypoints.size() - 1
		while next > i and not _can_cross(waypoints[i], waypoints[next], avoid_units):
			next -= 1
		if next == i:
			break
		straight.append(waypoints[next])
		i = next
	if straight.size() < 2:
		return
	for index in range(1, straight.size() - 1):
		var corner := straight[index]
		var before := corner.move_toward(straight[index - 1], minf(CORNER_REACH, corner.distance_to(straight[index - 1]) * 0.35))
		var after := corner.move_toward(straight[index + 1], minf(CORNER_REACH, corner.distance_to(straight[index + 1]) * 0.35))
		var last := _route.back() as Vector2 if not _route.is_empty() else position
		if stats.vehicle and _can_cross(last, before, avoid_units) and _can_cross(before, after, avoid_units):
			_route.append(before)
			for weight in [0.25, 0.5, 0.75, 1.0]:
				var sample := before.lerp(corner, weight).lerp(corner.lerp(after, weight), weight)
				if not _can_cross(_route.back(), sample, avoid_units):
					while not _route.back().is_equal_approx(before):
						_route.pop_back()
					_route.pop_back()
					_route.append(corner)
					break
				_route.append(sample)
		else:
			_route.append(corner)
	_route.append(straight.back())


func _can_cross(from: Vector2, to: Vector2, avoid_units: bool) -> bool:
	for tile in grid.cells_along(from, to, CLEARANCE):
		if not grid.is_walkable(tile) or (avoid_units and not grid.is_free(tile, self)):
			return false
	return true


func _fire_at(enemy: RtsUnit) -> void:
	_route.clear()
	if stats.vehicle:
		var bearing := position.angle_to_point(enemy.position)
		_facing = Vector2.from_angle(rotate_toward(_facing.angle(), bearing, TURN_SPEED * _turn_delta))
		queue_redraw()
		if absf(angle_difference(_facing.angle(), bearing)) > 0.06:
			return
	super._fire_at(enemy)
	queue_redraw()


func _die() -> void:
	for tile in _extra_claims:
		grid.release(tile, self)
	super._die()


func _leave_distance_marks(previous: Vector2) -> void:
	var moved := position.distance_to(previous)
	if moved <= 0.0001:
		return
	_moving_now = true
	distance_walked += moved
	if RtsLook.instance == null:
		return
	if stats.vehicle:
		if _mark_distance == 0.0:
			_track_start = previous
			_track_heading = _facing
		_mark_distance += moved
		if _mark_distance >= 1.6:
			RtsLook.instance.add_track_pair(_track_start, _track_heading, position, _facing)
			_mark_distance = 0.0
		_dust_timer += moved
		if _dust_timer >= 4.0:
			_dust_timer = fmod(_dust_timer, 4.0)
			RtsLook.instance.add_dust(position - _facing * 10.0, -_facing)
	else:
		var stride := _stride()
		for index in _figure_count():
			var phase: float = PHASE[index] if _figure_count() == 4 else 0.0
			var p := distance_walked / stride + phase
			if floori(p * 2.0) != floori((p - moved / stride) * 2.0):
				var side := -1.0 if floori(p * 2.0) % 2 == 0 else 1.0
				var foot := position + _figure_at(index) + _facing * (stride * 0.25)
				RtsLook.instance.add_footprints(foot + _facing.orthogonal() * side * 1.5)


func _stride() -> float:
	return 8.0 if stats.kind == UnitStats.Kind.TROOP else 9.0


func _figure_count() -> int:
	return 4 if stats.kind == UnitStats.Kind.TROOP else 1


func _figure_at(index: int) -> Vector2:
	return FORMATION[index] + Vector2(0, 4) if _figure_count() == 4 else Vector2(0, 5)


func radius() -> float:
	if stats.vehicle or stats.kind == UnitStats.Kind.TROOP:
		return 14.0
	return 12.0


func _draw_sprite_unit(_radius: float) -> void:
	var atlas := art_hd if painted else art_pixel
	if atlas == null:
		super._draw_sprite_unit(_radius)
		return
	var facing := _facing.angle()
	var col := posmod(roundi(facing / (PI / 4.0)), 8)
	var light := RtsLook.light_at(position)
	var tint := Color(light, light, light).lerp(Color(2, 2, 2), 0.75 if _flash > 0.0 else 0.0)
	if stats.vehicle:
		_draw_vehicle(atlas, col, facing, tint)
	else:
		_draw_figures(atlas, col, tint)


func _draw_vehicle(atlas: Texture2D, col: int, heading: float, tint: Color) -> void:
	_draw_contact(Vector2(0, 1), 12.0, 0.55)
	var frame := Vector2(atlas.get_width() / 8.0, atlas.get_height() / 3.0)
	var size := Vector2(38, 38)
	var row := posmod(floori(distance_walked / 2.0), 3)
	var turn := angle_difference(col * PI / 4.0, heading)
	draw_set_transform(Vector2.ZERO, turn)
	draw_texture_rect_region(atlas, Rect2(-size * 0.5, size), Rect2(Vector2(col, row) * frame, frame), tint)
	draw_set_transform(Vector2.ZERO)


func _draw_figures(atlas: Texture2D, col: int, tint: Color) -> void:
	var frame := Vector2(atlas.get_width() / 8.0, atlas.get_height() / float(WALK_ROWS + 1))
	for index in _figure_count():
		_draw_contact(_figure_at(index), 3.2, 0.55)
	for index in _figure_count():
		var foot := _figure_at(index)
		var row := 0
		if _moving_now:
			var phase: float = PHASE[index] if _figure_count() == 4 else 0.0
			row = 1 + posmod(floori((distance_walked / _stride() + phase) * WALK_ROWS), WALK_ROWS)
		var origin := Vector2(9, 15)
		draw_texture_rect_region(atlas, Rect2(foot - origin, Vector2(18, 20)),
			Rect2(Vector2(col, row) * frame, frame), tint)


func _draw_contact(foot: Vector2, spread: float, squash: float) -> void:
	if not RtsLook.shadows:
		return
	draw_set_transform(foot + Vector2(2, 2), 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, spread, Color(0.16, 0.06, 0.0, 0.28), painted)
	draw_set_transform(foot, 0.0, Vector2(1.0, squash * 0.73))
	draw_circle(Vector2.ZERO, spread * 0.77, Color(0.1, 0.03, 0.0, 0.37), painted)
	draw_set_transform(Vector2.ZERO)
