extends RtsLook

@onready var terrain: RtsDesertTerrain = $"../Terrain"


func add_track_pair(previous: Vector2, previous_heading: Vector2, next: Vector2, heading: Vector2) -> void:
	super.add_track_pair(previous, previous_heading, next, heading)
	if marks:
		terrain.add_treads(previous, previous_heading, next, heading)
