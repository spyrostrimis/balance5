extends Node3D

@export var rock_mat: Material = preload("res://assets/materials/dark_basalt.tres")
@export var crystal_mat: Material = preload("res://assets/materials/orichalcum_crystal_mat.tres")

func _ready():
	if has_node("CenterMound"):
		_apply_mat_recursive(get_node("CenterMound"), rock_mat)
	if has_node("CliffRocks"):
		_apply_mat_recursive(get_node("CliffRocks"), rock_mat)
	if has_node("OrichalcumCrystals"):
		_apply_mat_recursive(get_node("OrichalcumCrystals"), crystal_mat)

func _apply_mat_recursive(node: Node, mat: Material):
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_mat_recursive(child, mat)
