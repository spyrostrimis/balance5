extends RtsLook

@onready var terrain: RtsDesertTerrain = $"../Terrain"


func add_track_pair(previous: Vector2, previous_heading: Vector2, next: Vector2, heading: Vector2) -> void:
	if not terrain.is_paved(next - heading * 6.0):
		super.add_track_pair(previous, previous_heading, next, heading)
	if marks:
		terrain.add_treads(previous, previous_heading, next, heading)


func add_dust(pos: Vector2, away: Vector2) -> void:
	if not terrain.is_paved(pos):
		super.add_dust(pos, away)
