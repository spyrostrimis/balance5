extends "res://tests/test_true_3d_walk.gd"
## Walk harness for the composition test. Adds whole-scene landmark occlusion and variant switches.
## Environment variables select a variant without changing the shared harness options:
##   COMPOSITION_CAMERA=original|composition  COMPOSITION_ATMOSPHERE=volumetric|overlay|off
##   COMPOSITION_SUN=backlit|d4b

var _occluders: Array[Dictionary] = []


func _initialize() -> void:
	super()
	if _scene == null:
		return
	if _scene.has_method("set_atmosphere"):
		var atmosphere := OS.get_environment("COMPOSITION_ATMOSPHERE")
		if not atmosphere.is_empty():
			_scene.call_deferred("set_atmosphere", atmosphere)
		var sun := OS.get_environment("COMPOSITION_SUN")
		if not sun.is_empty():
			_scene.call_deferred("set_backlit_sun", sun == "backlit")
		# Diagnostics only. Applied after the scene's _ready has duplicated its environment.
		var world := _scene.get_node("WorldEnvironment") as WorldEnvironment
		var diagnostics := func() -> void:
			if OS.get_environment("COMPOSITION_FOG") == "off":
				world.environment.fog_enabled = false
			if OS.get_environment("COMPOSITION_GLOW") == "off":
				world.environment.glow_enabled = false
			if OS.get_environment("COMPOSITION_DOF") == "off":
				_cam.attributes = null
		diagnostics.call_deferred()
		var camera := OS.get_environment("COMPOSITION_CAMERA")
		if not camera.is_empty():
			_cam.call_deferred("set_original", camera == "original")
	print("Variant | Camera=%s | Atmosphere=%s | Sun=%s" % [
		OS.get_environment("COMPOSITION_CAMERA"), OS.get_environment("COMPOSITION_ATMOSPHERE"),
		OS.get_environment("COMPOSITION_SUN")
	])


func _capture(label: String) -> bool:
	if not super(label):
		return false
	print("CameraPose | Origin=%s | RotationDeg=%s" % [_cam.global_position, _cam.rotation_degrees])
	if _landmark.is_finite():
		var blocker := _first_occluder(_cam.global_position, _landmark)
		print("LandmarkScene | Pixel=%s | Occluder=%s" % [_cam.unproject_position(_landmark), blocker])
	return true


func _first_occluder(from: Vector3, to: Vector3) -> String:
	if _occluders.is_empty():
		_collect_occluders(_scene)
	var best := INF
	var best_name := "clear"
	for entry in _occluders:
		var mesh := entry["node"] as MeshInstance3D
		if not mesh.is_visible_in_tree():
			continue
		var local_from := mesh.to_local(from)
		var hit: Dictionary = (entry["triangles"] as TriangleMesh).intersect_segment(local_from, mesh.to_local(to))
		if hit.is_empty():
			continue
		var distance := from.distance_to(mesh.to_global(hit["position"]))
		if distance < best:
			best = distance
			best_name = "%s at %.2fm" % [mesh.name, distance]
	return best_name


func _collect_occluders(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh and mesh.mesh and node.name not in ["GroundFloorMesh", "OrichalcumCraterGround", "BattlefieldVistaBackdrop"]:
		_occluders.append({"node": mesh, "triangles": mesh.mesh.generate_triangle_mesh()})
	for child in node.get_children():
		_collect_occluders(child)
