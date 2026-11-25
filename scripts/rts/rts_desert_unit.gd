extends "res://scripts/rts/rts_motion_unit.gd"

var terrain: RtsDesertTerrain


func _terrain_speed_factor(direction: Vector2) -> float:
	var grade := terrain.grade_at(position, direction)
	if stats.vehicle:
		return clampf(1.0 - grade * 0.48, 0.83, 1.06)
	return clampf(1.0 - grade * 0.92, 0.71, 1.09)


func _footfall_rate() -> float:
	var uphill := maxf(0.0, terrain.grade_at(position, _facing))
	return 1.0 + uphill * 1.55


func _ground_light() -> float:
	return terrain.shade_at(position) if RtsLook.ground_light else 1.0
