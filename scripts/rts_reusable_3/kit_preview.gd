extends Node2D


func _ready() -> void:
	for node in find_children("*", "Node2D"):
		var piece := node as RtsCarbonPiece
		if piece != null:
			piece.apply_visual_mode(false)
