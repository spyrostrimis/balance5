@tool
extends SceneTree

func _init():
	var scene_res = load("res://assets/models/canyon_environment.glb")
	if scene_res:
		var inst = scene_res.instantiate()
		print("Root name: ", inst.name)
		for child in inst.get_children():
			print("Child: ", child.name, " Type: ", child.get_class())
			if child is MeshInstance3D:
				var aabb = child.get_aabb()
				print("  AABB: pos=", aabb.position, " size=", aabb.size)
	quit(0)
