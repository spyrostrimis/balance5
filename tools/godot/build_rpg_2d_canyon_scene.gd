@tool
extends SceneTree
## Builds the standalone 100% 2D parallel-projection pixel-art RPG canyon scenes:
##   - res://scenes/rpg_2d/canyon_orthographic_study.tscn (A/B study, Tab/M switches Approach 1 <-> 2)
##   - res://scenes/rpg_2d/canyon_approach1_uncut.tscn    (Approach 1: Continuous Uncut 2D Artwork)
##   - res://scenes/rpg_2d/canyon_approach2_modular.tscn  (Approach 2: Modular Stitched 2D Kit)
##
## Run from repo root:
##   C:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/godot/build_rpg_2d_canyon_scene.gd

const OUT_STUDY_SCENE := "res://scenes/rpg_2d/canyon_orthographic_study.tscn"
const OUT_A1_SCENE := "res://scenes/rpg_2d/canyon_approach1_uncut.tscn"
const OUT_A2_SCENE := "res://scenes/rpg_2d/canyon_approach2_modular.tscn"

const TEX_DIR := "res://assets/textures/rpg_2d/"
const MOD_DIR := "res://assets/textures/rpg_2d/modular/"
const SPRITES_DIR := "res://assets/textures/rpg_2d/sprites/"

const GOD_RAYS_SHADER := preload("res://assets/shaders/rpg_2d/god_rays_2d.gdshader")
const BUSH_SWAY_SHADER := preload("res://assets/shaders/rpg_2d/bush_sway_2d.gdshader")

const STUDY_SCRIPT := preload("res://scripts/rpg_2d/canyon_2d_study.gd")
const HERO_SCRIPT := preload("res://scripts/rpg_2d/hero_2d_controller.gd")
const CAMERA_SCRIPT := preload("res://scripts/rpg_2d/pixel_camera_2d.gd")

const MAP_W := 960.0
const MAP_H := 1967.0


func _make_canvas_tex(diff_path: String, norm_path: String = "") -> CanvasTexture:
	var ct := CanvasTexture.new()
	ct.diffuse_texture = load(diff_path) as Texture2D
	if not norm_path.is_empty() and ResourceLoader.exists(norm_path):
		ct.normal_texture = load(norm_path) as Texture2D
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return ct


func _make_dust_texture() -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.93, 0.72, 0.85))
	return ImageTexture.create_from_image(img)


func _set_owner_recursive(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		child.owner = root_node
		_set_owner_recursive(child, root_node)


func _build_corridor_collider(body_name: String, approach_id: int, half_walk_w: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0

	# Left canyon wall polygon hugging the left stepped dry-stone terrace wall
	var left_pts := PackedVector2Array()
	left_pts.append(Vector2(0.0, 0.0))
	for i in range(21):
		var y := minf(float(i) * 100.0, MAP_H)
		var cx := Canyon2DStudy.get_road_center_x(approach_id, y)
		var lx := clampf(minf(285.0, cx - half_walk_w), 180.0, 295.0)
		left_pts.append(Vector2(lx, y))
	left_pts.append(Vector2(0.0, MAP_H))

	var left_col := CollisionPolygon2D.new()
	left_col.name = "LeftCanyonWall"
	left_col.polygon = left_pts
	body.add_child(left_col)

	# Right canyon wall polygon hugging the right stepped dry-stone terrace wall
	var right_pts := PackedVector2Array()
	right_pts.append(Vector2(MAP_W, 0.0))
	for i in range(21):
		var y := minf(float(i) * 100.0, MAP_H)
		var cx := Canyon2DStudy.get_road_center_x(approach_id, y)
		var rx := clampf(maxf(675.0, cx + half_walk_w), 665.0, 780.0)
		right_pts.append(Vector2(rx, y))
	right_pts.append(Vector2(MAP_W, MAP_H))

	var right_col := CollisionPolygon2D.new()
	right_col.name = "RightCanyonWall"
	right_col.polygon = right_pts
	body.add_child(right_col)

	# North & South end barriers
	var north_col := CollisionShape2D.new()
	north_col.name = "NorthEndCap"
	var n_rect := RectangleShape2D.new()
	n_rect.size = Vector2(MAP_W, 24.0)
	north_col.shape = n_rect
	north_col.position = Vector2(MAP_W * 0.5, 64.0)
	body.add_child(north_col)

	var south_col := CollisionShape2D.new()
	south_col.name = "SouthEndCap"
	var s_rect := RectangleShape2D.new()
	s_rect.size = Vector2(MAP_W, 24.0)
	south_col.shape = s_rect
	south_col.position = Vector2(MAP_W * 0.5, MAP_H - 36.0)
	body.add_child(south_col)

	return body


func _build_study_tree(default_approach: int) -> Control:
	var root_ctrl := Control.new()
	root_ctrl.name = "Canyon2DStudy"
	root_ctrl.set_script(STUDY_SCRIPT)
	root_ctrl.set("active_approach", default_approach)
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var bg := ColorRect.new()
	bg.name = "BackdropFill"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.05, 0.04, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(bg)

	var vp := SubViewport.new()
	vp.name = "WorldViewport"
	vp.size = Vector2i(960, 540)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.snap_2d_transforms_to_pixel = true
	vp.snap_2d_vertices_to_pixel = true
	vp.handle_input_locally = false
	root_ctrl.add_child(vp)

	var disp := TextureRect.new()
	disp.name = "ViewportDisplay"
	disp.set_anchors_preset(Control.PRESET_FULL_RECT)
	disp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	disp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	disp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(disp)

	var world := Node2D.new()
	world.name = "CanyonWorld"
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vp.add_child(world)

	# Approach 1 Uncut Master Ground Plate (960x1967)
	var a1_ground := Sprite2D.new()
	a1_ground.name = "Approach1Ground"
	a1_ground.texture = _make_canvas_tex(TEX_DIR + "approach1_uncut_canvas.png", TEX_DIR + "approach1_uncut_canvas_n.png")
	a1_ground.centered = false
	a1_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a1_ground.z_index = 0
	a1_ground.visible = (default_approach == 1)
	world.add_child(a1_ground)

	# Approach 2 Stitched Ground + S-Curve Cobblestone Road Plate (960x1967)
	var a2_ground := Sprite2D.new()
	a2_ground.name = "Approach2Ground"
	a2_ground.texture = _make_canvas_tex(TEX_DIR + "approach2_ground_road_canvas.png", TEX_DIR + "approach2_ground_road_canvas_n.png")
	a2_ground.centered = false
	a2_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a2_ground.z_index = 0
	a2_ground.visible = (default_approach == 2)
	world.add_child(a2_ground)

	# Approach 1 & Approach 2 Curved Canyon Corridor Colliders
	var a1_col := _build_corridor_collider("Approach1Collider", 1, 108.0)
	a1_col.collision_layer = 1 if default_approach == 1 else 0
	world.add_child(a1_col)

	var a2_col := _build_corridor_collider("Approach2Collider", 2, 114.0)
	a2_col.collision_layer = 1 if default_approach == 2 else 0
	world.add_child(a2_col)

	# Y-Sorted Entity World (Hero + Approach 1 Walk-Behind Cutouts + Approach 2 Modular Cliffs & Props)
	var ysort := Node2D.new()
	ysort.name = "YSortWorld"
	ysort.y_sort_enabled = true
	ysort.z_index = 4
	world.add_child(ysort)

	var tex_cache: Dictionary = {}
	var get_mod_tex := func(stem: String) -> CanvasTexture:
		if tex_cache.has(stem):
			return tex_cache[stem]
		var ct := _make_canvas_tex(MOD_DIR + stem + ".png", MOD_DIR + stem + "_n.png")
		tex_cache[stem] = ct
		return ct

	# --- APPROACH 1 IN-PLACE WALK-BEHIND CUTOUTS ---
	# Exact centers and bottom Y pivots matching build_approach1_assets() cutout boxes:
	var a1_cutouts := [
		["a1_cutout_00", 365, 225, 458, 305],
		["a1_cutout_01", 318, 495, 422, 578],
		["a1_cutout_02", 495, 765, 598, 845],
		["a1_cutout_03", 555, 1095, 668, 1185],
		["a1_cutout_04", 365, 1275, 472, 1365],
		["a1_cutout_05", 520, 1525, 635, 1615],
		["a1_cutout_06", 268, 1675, 385, 1765],
		["a1_cutout_07", 290, 1785, 405, 1882],
	]
	for i in range(a1_cutouts.size()):
		var cinfo: Array = a1_cutouts[i]
		var cname := str(cinfo[0])
		var x0 := float(cinfo[1])
		var y0 := float(cinfo[2])
		var x1 := float(cinfo[3])
		var y1 := float(cinfo[4])
		var w := x1 - x0
		var h := y1 - y0
		var sp := Sprite2D.new()
		sp.name = "A1Cutout_%02d" % i
		sp.texture = get_mod_tex.call(cname)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Anchor at bottom-center (y1 - 8) so Y-sort places hero behind the top 85% of the boulder/bush
		var pivot_y := y1 - 8.0
		sp.position = Vector2(x0 + w * 0.5, pivot_y)
		sp.offset = Vector2(0.0, (y0 + h * 0.5) - pivot_y)
		sp.set_meta("approach", 1)
		sp.visible = (default_approach == 1)
		ysort.add_child(sp)

	# --- APPROACH 2 MODULAR CLIFFS, TERRACES, RUINED ARCHWAYS, BOULDERS & BUSHES ---
	# Format: [stem, center_x, bottom_y, kind]
	var a2_placements := [
		# Left Canyon Wall Modular Terraces & Carved Stone Staircases (y = 140..1950)
		["cliff_left_large", 190.0, 210.0, "cliff"],
		["cliff_stair_ruin", 172.0, 395.0, "cliff"],
		["cliff_outcrop_wide", 202.0, 580.0, "cliff"],
		["cliff_left_large", 184.0, 760.0, "cliff"],
		["cliff_corner_mid", 188.0, 935.0, "cliff"],
		["cliff_stair_ruin", 170.0, 1115.0, "cliff"],
		["cliff_outcrop_wide", 204.0, 1300.0, "cliff"],
		["cliff_left_large", 186.0, 1485.0, "cliff"],
		["cliff_stair_ruin", 174.0, 1670.0, "cliff"],
		["cliff_outcrop_wide", 200.0, 1855.0, "cliff"],
		["cliff_left_large", 185.0, 2020.0, "cliff"],

		# Right Canyon Wall Modular Terraces & Jutting Buttresses (y = 150..1950)
		["cliff_right_large", 782.0, 220.0, "cliff"],
		["cliff_buttress_right", 766.0, 390.0, "cliff"],
		["cliff_right_large", 786.0, 570.0, "cliff"],
		["cliff_buttress_right", 770.0, 745.0, "cliff"],
		["cliff_right_large", 780.0, 925.0, "cliff"],
		["cliff_buttress_right", 764.0, 1105.0, "cliff"],
		["cliff_right_large", 785.0, 1290.0, "cliff"],
		["cliff_buttress_right", 768.0, 1465.0, "cliff"],
		["cliff_right_large", 782.0, 1650.0, "cliff"],
		["cliff_buttress_right", 766.0, 1830.0, "cliff"],
		["cliff_right_large", 784.0, 2010.0, "cliff"],

		# Weathered 3/4 Dry-Stone Ruined Archways on the Stepped Stone Terraces
		["ruined_archway", 285.0, 265.0, "arch"],
		["ruined_archway", 285.0, 985.0, "arch"],
		["ruined_archway", 285.0, 1535.0, "arch"],

		# Left Sandy Shoulder Boulders, Olive Sagebushes & Grass Tufts (safely outside left road curb)
		["bush_large_a", 356.0, 185.0, "bush"],
		["boulder_large_a", 336.0, 325.0, "boulder"],
		["bush_med_a", 315.0, 385.0, "bush"],
		["bush_large_b", 332.0, 475.0, "bush"],
		["boulder_med_a", 370.0, 550.0, "boulder"],
		["grass_tuft_large", 325.0, 610.0, "grass"],
		["bush_large_a", 345.0, 700.0, "bush"],
		["boulder_large_b", 322.0, 815.0, "boulder"],
		["bush_med_b", 355.0, 905.0, "bush"],
		["boulder_large_a", 335.0, 1045.0, "boulder"],
		["bush_large_b", 318.0, 1140.0, "bush"],
		["grass_tuft_med", 348.0, 1215.0, "grass"],
		["bush_large_a", 358.0, 1320.0, "bush"],
		["boulder_med_b", 338.0, 1410.0, "boulder"],
		["bush_med_a", 316.0, 1490.0, "bush"],
		["boulder_large_a", 342.0, 1605.0, "boulder"],
		["bush_large_b", 334.0, 1715.0, "bush"],
		["boulder_med_a", 318.0, 1805.0, "boulder"],
		["bush_large_a", 335.0, 1895.0, "bush"],
		["grass_tuft_small", 355.0, 1935.0, "grass"],

		# Right Sandy Shoulder Boulders, Olive Sagebushes & Grass Tufts (safely outside right road curb)
		["boulder_large_b", 638.0, 175.0, "boulder"],
		["bush_large_b", 614.0, 275.0, "bush"],
		["boulder_med_b", 628.0, 365.0, "boulder"],
		["bush_med_b", 616.0, 435.0, "bush"],
		["bush_large_a", 628.0, 525.0, "bush"],
		["grass_tuft_med", 596.0, 595.0, "grass"],
		["boulder_large_a", 632.0, 685.0, "boulder"],
		["bush_large_b", 605.0, 785.0, "bush"],
		["boulder_med_a", 626.0, 880.0, "boulder"],
		["bush_med_a", 618.0, 965.0, "bush"],
		["bush_large_a", 628.0, 1065.0, "bush"],
		["boulder_large_b", 602.0, 1165.0, "boulder"],
		["grass_tuft_large", 615.0, 1245.0, "grass"],
		["bush_large_b", 635.0, 1345.0, "bush"],
		["boulder_med_b", 614.0, 1435.0, "boulder"],
		["bush_med_b", 595.0, 1515.0, "bush"],
		["bush_large_a", 632.0, 1625.0, "bush"],
		["boulder_large_a", 618.0, 1735.0, "boulder"],
		["bush_large_b", 596.0, 1825.0, "bush"],
		["boulder_med_a", 616.0, 1905.0, "boulder"],
	]

	for i in range(a2_placements.size()):
		var item: Array = a2_placements[i]
		var stem := str(item[0])
		var cx := float(item[1])
		var by := float(item[2])
		var kind := str(item[3])
		var tex: CanvasTexture = get_mod_tex.call(stem)
		var tex_sz: Vector2 = tex.diffuse_texture.get_size()

		var sp := Sprite2D.new()
		sp.name = "A2_%s_%02d" % [kind, i]
		sp.texture = tex
		sp.position = Vector2(cx, by)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Visual base is 10px above bottom of shadow-padded sprite
		sp.offset = Vector2(0.0, -tex_sz.y * 0.5 + 10.0)
		sp.set_meta("approach", 2)
		sp.visible = (default_approach == 2)
		if kind == "bush":
			var bmat := ShaderMaterial.new()
			bmat.shader = BUSH_SWAY_SHADER
			bmat.set_shader_parameter("phase_offset", float(i) * 0.9)
			bmat.set_shader_parameter("sway_px", 1.0)
			sp.material = bmat
		ysort.add_child(sp)

	# Hero (Blue Commander)
	var hero := CharacterBody2D.new()
	hero.name = "Hero2D"
	hero.set_script(HERO_SCRIPT)
	var spawn_y := 1720.0
	var spawn_x := Canyon2DStudy.get_road_center_x(default_approach, spawn_y)
	hero.position = Vector2(spawn_x, spawn_y)
	hero.collision_layer = 2
	hero.collision_mask = 1
	ysort.add_child(hero)

	var h_shd := Sprite2D.new()
	h_shd.name = "Shadow"
	h_shd.texture = load(SPRITES_DIR + "contact_shadow.png") as Texture2D
	h_shd.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h_shd.position = Vector2(0.0, -2.0)
	hero.add_child(h_shd)

	var h_sp := Sprite2D.new()
	h_sp.name = "Sprite"
	h_sp.texture = _make_canvas_tex(SPRITES_DIR + "blue_commander_sheet.png", SPRITES_DIR + "blue_commander_sheet_n.png")
	h_sp.hframes = 4
	h_sp.vframes = 4
	h_sp.frame_coords = Vector2i(0, 0)
	h_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h_sp.offset = Vector2(0.0, -54.0)
	hero.add_child(h_sp)

	var h_col := CollisionShape2D.new()
	h_col.name = "CollisionShape2D"
	var h_rect := RectangleShape2D.new()
	h_rect.size = Vector2(22.0, 14.0)
	h_col.shape = h_rect
	h_col.position = Vector2(0.0, -5.0)
	hero.add_child(h_col)

	var h_muzzle := Marker2D.new()
	h_muzzle.name = "MuzzleRight"
	h_muzzle.position = Vector2(28.0, -55.0)
	hero.add_child(h_muzzle)

	# Pixel-snapped Locked Following Camera2D
	var cam := Camera2D.new()
	cam.name = "PixelCamera"
	cam.set_script(CAMERA_SCRIPT)
	cam.set("target_path", NodePath("../YSortWorld/Hero2D"))
	cam.set("map_bounds", Rect2(0.0, 0.0, MAP_W, MAP_H))
	cam.position = hero.position
	cam.enabled = true
	world.add_child(cam)

	# 2D Lighting (Laigter Normals)
	var cmod := CanvasModulate.new()
	cmod.name = "AmbientModulate"
	cmod.color = Color(0.95, 0.92, 0.90, 1.0)
	world.add_child(cmod)

	var dlight := DirectionalLight2D.new()
	dlight.name = "SunLight2D"
	dlight.color = Color(1.0, 0.90, 0.74, 1.0)
	dlight.energy = 0.18
	dlight.height = 0.45
	dlight.rotation_degrees = 38.0
	world.add_child(dlight)

	# Atmosphere Layer inside WorldViewport (God Rays + Golden Dust Motes)
	var atmo := CanvasLayer.new()
	atmo.name = "AtmosphereLayer"
	atmo.layer = 5
	vp.add_child(atmo)

	var rays := ColorRect.new()
	rays.name = "GodRaysRect"
	rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rmat := ShaderMaterial.new()
	rmat.shader = GOD_RAYS_SHADER
	rays.material = rmat
	atmo.add_child(rays)

	var dust := GPUParticles2D.new()
	dust.name = "DustParticles"
	dust.position = Vector2(560.0, 210.0)
	dust.amount = 32
	dust.lifetime = 4.2
	dust.texture = _make_dust_texture()
	dust.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(420.0, 220.0, 1.0)
	pmat.direction = Vector3(-0.7, 0.7, 0.0)
	pmat.spread = 20.0
	pmat.initial_velocity_min = 6.0
	pmat.initial_velocity_max = 16.0
	pmat.gravity = Vector3(0.0, 0.0, 0.0)
	pmat.scale_min = 1.0
	pmat.scale_max = 1.5
	dust.process_material = pmat
	atmo.add_child(dust)

	# Compact HUD outside WorldViewport
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	root_ctrl.add_child(hud)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(12.0, 10.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.05, 0.76)
	sb.border_color = Color(0.78, 0.56, 0.34, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	hud.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.add_theme_font_size_override("font_size", 14)
	status_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.84, 1.0))
	vbox.add_child(status_lbl)

	var prompt_lbl := Label.new()
	prompt_lbl.name = "PromptLabel"
	prompt_lbl.add_theme_font_size_override("font_size", 12)
	prompt_lbl.add_theme_color_override("font_color", Color(0.92, 0.86, 0.78, 0.92))
	vbox.add_child(prompt_lbl)

	_set_owner_recursive(root_ctrl, root_ctrl)
	return root_ctrl


func _save_scene(default_approach: int, out_path: String) -> bool:
	var tree_root := _build_study_tree(default_approach)
	var packed := PackedScene.new()
	var pack_err := packed.pack(tree_root)
	tree_root.free()
	if pack_err != OK:
		push_error("Failed to pack " + out_path + ": " + error_string(pack_err))
		return false
	var save_err := ResourceSaver.save(packed, out_path)
	if save_err != OK:
		push_error("Failed to save " + out_path + ": " + error_string(save_err))
		return false
	print("PASS: Built ", out_path, " (default_approach=", default_approach, ")")
	return true


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/rpg_2d"))
	var ok1 := _save_scene(1, OUT_STUDY_SCENE)
	var ok2 := _save_scene(1, OUT_A1_SCENE)
	var ok3 := _save_scene(2, OUT_A2_SCENE)
	quit(0 if (ok1 and ok2 and ok3) else 1)
