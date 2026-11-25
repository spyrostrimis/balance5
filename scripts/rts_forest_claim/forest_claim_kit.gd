class_name ForestClaimKit
extends RefCounted
## Width is in projected pixels at 100% zoom. Contact is the normalized sprite pivot.
## Each footprint is relative to the cell containing that contact. Leaves do not block.
const ROOT := "res://assets/textures/rts/forest_claim/"
const PIECES := {
	"rooted_tree": {"width": 150.0, "contact": Vector2(0.49, 0.87), "blocks": [Vector2i.ZERO], "tree": true},
	"leaning_tree": {"width": 132.0, "contact": Vector2(0.32, 0.89), "blocks": [Vector2i.ZERO], "tree": true},
	"twin_tree": {"width": 154.0, "contact": Vector2(0.52, 0.87), "blocks": [Vector2i.ZERO], "tree": true},
	"boulder": {"width": 68.0, "contact": Vector2(0.51, 0.78), "blocks": [Vector2i.ZERO], "tree": false},
	"rocks": {"width": 59.0, "contact": Vector2(0.53, 0.82), "blocks": [Vector2i.ZERO], "tree": false},
	"fern": {"width": 38.0, "contact": Vector2(0.54, 0.84), "blocks": [], "tree": false},
	"ginger": {"width": 34.0, "contact": Vector2(0.50, 0.82), "blocks": [], "tree": false},
	"shrub": {"width": 59.0, "contact": Vector2(0.51, 0.78), "blocks": [], "tree": false},
	"orichalcum": {"width": 92.0, "contact": Vector2(0.52, 0.79), "blocks": [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP], "tree": false},
}
const TREES := ["rooted_tree", "leaning_tree", "twin_tree"]


static func sprite_rect(piece: String, texture: Texture2D, scale_factor: float) -> Rect2:
	var module: Dictionary = PIECES[piece]
	var sprite_size := texture.get_size() * (float(module.width) * scale_factor / texture.get_width())
	return Rect2(-sprite_size * Vector2(module.contact), sprite_size)


static func sprite_texture(piece: String) -> Texture2D:
	return load(ROOT + piece + ".png") as Texture2D


static func occupied_cells(piece: String, cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset: Vector2i in PIECES[piece].blocks:
		cells.append(cell + offset)
	return cells
