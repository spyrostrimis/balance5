@tool
extends Resource
## Ordered list of route-relative module placements for one canyon.

const Placement := preload("res://scripts/canyon/canyon_placement.gd")

@export var placements: Array[Placement] = []
