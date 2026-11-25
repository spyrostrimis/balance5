extends "res://scripts/rts/rts_units_test.gd"

@onready var terrain: RtsDesertTerrain = $Terrain


func _enter_tree() -> void:
	$Terrain.prepare($Grid)
	for unit in $Units.get_children():
		unit.terrain = $Terrain


func _ready() -> void:
	super._ready()
	for unit: RtsUnit in units.get_children():
		unit.peaceful = true
