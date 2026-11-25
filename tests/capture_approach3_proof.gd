extends SceneTree
## Reproduce the flat-light modular entrance comparison at native picture size.

const OUTPUT := "res://render_captures/approach3/"
const REFERENCE := preload("res://assets/textures/rpg_2d/approach3/commander_front_idle.png")
const PICTURE := Vector2i(1360, 765)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1376, 768)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var study := preload("res://scenes/rpg_2d/canyon_approach2_modular.tscn").instantiate() as Canyon2DStudy
	root.add_child(study)
	study.set_hud_visible(false)
	study.reset_hero_position(1560.0)
	study.hero.use_script_input = true
	study.god_rays_on = false
	study._apply_god_rays_state()
	study.normals_lighting_on = false
	study._apply_lighting_state()
	study.world_viewport.size = PICTURE
	var zoom_factor := PICTURE.y / 540.0
	study.camera.set_resolution_zoom(zoom_factor, PICTURE)
	study.viewport_display.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	study.viewport_display.position = ((Vector2(root.size) - Vector2(PICTURE)) * 0.5).floor()
	study.viewport_display.size = PICTURE

	var original: Sprite2D = study.hero.get_node("Sprite")
	var candidate := Sprite2D.new()
	candidate.texture = REFERENCE
	candidate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	candidate.centered = false
	candidate.scale = Vector2.ONE / zoom_factor
	# Same optical offset and boot line as the handoff proof.
	candidate.position = Vector2(-10.0, -1.0) - Vector2(37.0, 149.0) / zoom_factor
	study.hero.add_child(candidate)
	for use_reference in [false, true]:
		original.visible = not use_reference
		candidate.visible = use_reference
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var name := "proof_reference.png" if use_reference else "proof_original.png"
		var result := root.get_texture().get_image().save_png(OUTPUT + name)
		if result != OK:
			push_error(error_string(result))
			quit(1)
			return
	print("Proof captured at 1360x765 with reference height ", REFERENCE.get_height())
	quit()
