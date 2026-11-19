extends SceneTree
## GPU cost of the raised-stone road in the HD-2D Pixel A/B scene: average GPU frame time at spawn with
## relief off, then on, in the same run and camera.
##   PIXEL_AB_MODE=hr_gpt Godot --path . --resolution 1376x768 --script res://tests/test_relief_cost.gd

const SCENE := "res://scenes/maps/canyon_v2_pixel_ab.tscn"
const WARMUP := 90
const SAMPLES := 240


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = load(SCENE).instantiate()
	root.add_child(level)
	var viewport_rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	for relief in [false, true]:
		level.relief = relief
		level.set_mode(level.mode)
		for i in WARMUP:
			await process_frame
		var gpu := 0.0
		var cpu := 0.0
		for i in SAMPLES:
			await process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
		print("ReliefCost mode=%s relief=%s gpu=%.3f ms cpu=%.3f ms" % [level.mode, relief, gpu / SAMPLES, cpu / SAMPLES])
	quit()
