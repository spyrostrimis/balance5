extends SceneTree
## Headless check of the RTS test map: grid, pathfinding, selection, group moves and combat.
##   Godot --path . --headless --script res://tests/test_rts_test_map.gd
## Fast-forwards the battle by calling RtsUnit.tick() directly (60 steps per simulated second)
## and checks every step that no two units share a tile and none stands on a blocked tile.
## Exits 1 on any failure.

const SCENE := "res://scenes/maps/rts_test_map.tscn"
const DT := 1.0 / 60.0

var _map: Node2D
var _grid: RtsGrid
var _cmd: RtsCommands
var _failures := 0
var _overlap_errors := 0


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("FAIL: timed out")
		quit(1))
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		_failures += 1


func _unit(unit_name: String) -> RtsUnit:
	return _map.get_node("Units/" + unit_name) as RtsUnit


func _faction(faction: UnitStats.Faction) -> Array[RtsUnit]:
	return _cmd.all_units().filter(func(u: RtsUnit) -> bool: return u.stats.faction == faction)


## Advance the simulation; returns early when `until` returns true.
func _sim(seconds: float, until: Callable = Callable()) -> float:
	var steps := int(seconds / DT)
	for i in steps:
		for unit in _cmd.all_units():
			unit.tick(DT)
		_check_tiles()
		if until.is_valid() and until.call():
			return (i + 1) * DT
	return seconds


func _check_tiles() -> void:
	var seen := {}
	for unit in _cmd.all_units():
		if seen.has(unit.cell) or not _grid.is_walkable(unit.cell):
			_overlap_errors += 1
		seen[unit.cell] = true


func _path_ok(path: Array[Vector2i], from: Vector2i) -> bool:
	var prev := from
	for cell in path:
		if not _grid.is_walkable(cell) or RtsGrid.tile_distance(prev, cell) != 1:
			return false
		prev = cell
	return true


func _run() -> void:
	_map = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_map)
	await process_frame
	_grid = _map.get_node("Grid")
	_cmd = _map.get_node("Commands")
	for unit in _cmd.all_units():
		unit.set_physics_process(false)  # the test drives time itself

	# --- Grid and pathfinding ---
	_check(_grid.region == Rect2i(0, 0, 48, 30), "Map is 48 x 30 tiles of 32 px (region %s)" % _grid.region)
	_check(not _grid.is_walkable(Vector2i(24, 15)), "Orichalcum rock tile is blocked")
	_check(_cmd.all_units().size() == 10, "10 units on the map (5 Blue, 5 Red)")
	_check(_faction(UnitStats.Faction.BLUE).size() == 5 and _faction(UnitStats.Faction.RED).size() == 5, "5 per side")
	var around := _grid.find_path(Vector2i(19, 15), Vector2i(29, 15))
	_check(not around.is_empty() and around.back() == Vector2i(29, 15) and _path_ok(around, Vector2i(19, 15)),
		"Path west->east of the rock exists, uses only walkable neighbouring tiles")
	_check(around.size() > 10, "That path goes around the rock (%d steps, straight line would be 10)" % around.size())
	var across := _grid.find_path(Vector2i(4, 9), Vector2i(30, 9))
	_check(not across.is_empty() and _path_ok(across, Vector2i(4, 9)), "Path from Blue spawn crosses the ridge (%d steps)" % across.size())

	# --- Selection ---
	_cmd.select_in_rect(_grid.world_rect())
	_check(_cmd.selection.size() == 5 and _cmd.selection.all(func(u: RtsUnit) -> bool: return u.stats.faction == UnitStats.Faction.BLUE),
		"Box over the whole map selects only the 5 Blue units")
	_cmd.click_select(_unit("BlueCommander").position)
	_check(_cmd.selection.size() == 1 and _cmd.selection[0] == _unit("BlueCommander"), "Click selects one Blue unit")
	_cmd.click_select(_unit("BlueTroop1").position + Vector2(3, 2), true)
	_check(_cmd.selection.size() == 2, "Shift-click adds a unit")
	_cmd.click_select(_unit("RedCommander").position)
	_check(_cmd.selection.is_empty(), "Clicking a Red unit does not select it")
	_cmd.select_in_rect(Rect2(Vector2(100, 220), Vector2(200, 160)))
	_check(_cmd.selection.size() == 5, "Drag box around the Blue spawn selects all 5")

	# --- Group move onto the rock: everyone gets their own free tile next to it ---
	var assigned := _cmd.move_group(_cmd.selection, Vector2i(24, 15))
	var spots: Array = assigned.values()
	var distinct := {}
	for s: Vector2i in spots:
		distinct[s] = true
	_check(distinct.size() == 5 and spots.all(func(s: Vector2i) -> bool: return _grid.is_walkable(s)),
		"Move onto the blocked rock gives 5 different walkable tiles: %s" % [spots])
	var took := _sim(30.0, func() -> bool:
		return _faction(UnitStats.Faction.BLUE).all(func(u: RtsUnit) -> bool: return u.order == RtsUnit.Order.NONE and not u.is_moving()))
	var arrived := assigned.keys().filter(func(u: RtsUnit) -> bool: return u.cell == assigned[u])
	_check(arrived.size() == 5, "All 5 reached their tiles (%d/5 in %.1f s)" % [arrived.size(), took])
	for u: RtsUnit in assigned.keys():
		print("      %s at %s (wanted %s)" % [u.name, u.cell, assigned[u]])

	# --- Stop ---
	var trooper := _unit("BlueTroop1")
	trooper.command_move(Vector2i(10, 20))
	_sim(0.6)
	trooper.command_stop()
	_sim(0.6)
	var stopped_at := trooper.position
	_sim(1.0)
	_check(trooper.order == RtsUnit.Order.NONE and trooper.position == stopped_at and trooper.position == _grid.center_of(trooper.cell),
		"Stop halts the unit on the centre of a tile")

	# --- Attack ---
	_check(_unit("BlueTroop2").stats.damage_against(_unit("RedTroop1").stats) == 6, "Blue Trooper hits a Red Legionary for 10 - 4 = 6")
	var victim := _unit("RedTroop2")
	var victim_cell := victim.cell
	_cmd.select_in_rect(_grid.world_rect())
	_cmd.order_at(victim.position)
	_check(not _cmd.selection.is_empty() and _cmd.selection.all(func(u: RtsUnit) -> bool: return u.order == RtsUnit.Order.ATTACK and u.target == victim),
		"Right-click on a Red unit orders every selected unit to attack it")
	took = _sim(60.0, func() -> bool: return not victim.alive)
	_check(not victim.alive, "Target destroyed (%.1f s)" % took)
	_check(_grid.unit_at(victim_cell) != victim, "Dead unit's tile is released")
	var hurt_blue := _faction(UnitStats.Faction.BLUE).filter(func(u: RtsUnit) -> bool: return u.health < u.stats.max_health)
	var lost_blue := 5 - _faction(UnitStats.Faction.BLUE).size()
	_check(hurt_blue.size() + lost_blue > 0, "Red fought back (%d Blue hurt, %d lost)" % [hurt_blue.size(), lost_blue])
	var red_engaged := _faction(UnitStats.Faction.RED).filter(func(u: RtsUnit) -> bool: return u.order == RtsUnit.Order.ATTACK or u.health < u.stats.max_health)
	_check(not red_engaged.is_empty(), "Nearby Red units joined in (%d)" % red_engaged.size())

	# Let the battle play out; the fight should end with one side gone and nobody stuck.
	# Skirmish settles (survivors end up outside each other's guard range), then Blue attacks
	# whatever Red is left, one target at a time, the way a player would.
	took = _sim(20.0)
	var orders := 0
	while orders < 10 and not _faction(UnitStats.Faction.BLUE).is_empty() and not _faction(UnitStats.Faction.RED).is_empty():
		_cmd.select_in_rect(_grid.world_rect())
		_cmd.order_at(_faction(UnitStats.Faction.RED)[0].position)
		orders += 1
		took += _sim(40.0, func() -> bool: return _cmd.all_units().all(func(u: RtsUnit) -> bool: return u.order == RtsUnit.Order.NONE))
	print("      After %.1f s more: Blue %d left, Red %d left" % [took, _faction(UnitStats.Faction.BLUE).size(), _faction(UnitStats.Faction.RED).size()])
	_check(_faction(UnitStats.Faction.BLUE).is_empty() or _faction(UnitStats.Faction.RED).is_empty(),
		"Battle runs to the end with one side eliminated (nobody stuck)")
	for u in _cmd.all_units():
		print("      %s hp %d/%d at %s order %s" % [u.name, u.health, u.stats.max_health, u.cell, RtsUnit.Order.keys()[u.order]])

	_check(_overlap_errors == 0, "No two units ever shared a tile or stood on a blocked tile (%d violations)" % _overlap_errors)

	for i in 3:
		await process_frame
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
