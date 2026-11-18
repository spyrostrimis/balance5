extends SceneTree

func _init():
	var bm = BoxMesh.new()
	bm.size = Vector3(3, 4, 3)
	bm.subdivide_width = 8
	bm.subdivide_height = 10
	bm.subdivide_depth = 8
	
	var st = SurfaceTool.new()
	st.create_from(bm, 0)
	var arr_mesh = st.commit()
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(arr_mesh, 0)
	
	var noise = FastNoiseLite.new()
	noise.seed = 1234
	noise.frequency = 0.4
	
	for i in range(mdt.get_vertex_count()):
		var v = mdt.get_vertex(i)
		var n = noise.get_noise_3dv(v * 1.5) * 0.4
		v += mdt.get_vertex_normal(i) * n
		mdt.set_vertex(i, v)
		
	var final_mesh = ArrayMesh.new()
	mdt.commit_to_surface(final_mesh)
	st.clear()
	st.create_from(final_mesh, 0)
	st.generate_normals()
	final_mesh = st.commit()
	
	print("Organic rock mesh created successfully! Vertices: ", mdt.get_vertex_count())
	quit(0)
