extends Node3D
## Organic sculpted canyon cliffs with flush, non-intersecting sandstone rocks and rubble.
##
## Builds two distinct elements per side:
##   1. Sculpted organic bedrock (CoreLeft / CoreRight): wavy meandering toe along Z, 4 continuous
##      smoothstep-tapered tiers with 5-point battered sedimentary risers (~73 deg slope, organic
##      bulges and shoulder bevels — never 90 deg flat concrete) and undulating cracked sandstone shelves.
##   2. Unscaled 1:1 metric sandstone rocks (cliff_rock_0..5) and small rubble (rubble_0..3), each with
##      a strictly flat base at local y=0.0, seated flush on locally levelled shelf pads with guaranteed
##      clearance from back risers, front lips, and neighboring rocks.

const MESHES_GLB := "res://assets/models/kit_v2/kit_v2_meshes.glb"
const MESHES_JSON := "res://assets/models/kit_v2/kit_v2_meshes.json"
const MANIFEST_JSON := "res://assets/textures/kit_v2/manifest.json"
const ROCK_SHADER := preload("res://assets/shaders/canyon_kit_v2_rock.gdshader")
const TEX_ROOT := "res://assets/textures/kit_v2/"

const Z_START := 14.5
const Z_END := -24.0
const Z_STEP := 0.25
const TIERS := 4
const RISER_PTS := 5
const SHELF_PTS := 4

@export var random_seed := 17

var _rock_meshes: Array[Mesh] = []
var _rock_meta: Array[Dictionary] = []
var _rubble_meshes: Array[Mesh] = []
var _rubble_meta: Array[Dictionary] = []

var _strata_material := ShaderMaterial.new()
var _ledge_material := ShaderMaterial.new()
var _rock_side_material := ShaderMaterial.new()
var _rock_top_material := ShaderMaterial.new()

var _strata_tile := Vector2(2.9375, 1.390625)
var _ledge_tile := Vector2(2.0, 2.0)

## Per-side lattice: _lattice[side_idx] = {iz -> tier_data}
var _sides: Dictionary = {}
var _placed_rocks: Array[Dictionary] = []
var _placed_rubble: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func build(route: Node) -> void:
	for child in get_children():
		child.queue_free()
	_placed_rocks.clear()
	_placed_rubble.clear()
	_sides.clear()
	_load_assets()
	_rng.seed = random_seed

	for side: float in [-1.0, 1.0]:
		var lat := _generate_lattice(route, side)
		_sides[side] = lat
		_place_tier_rocks(route, side, lat)
		_place_shelf_rubble(route, side, lat)
		_build_bedrock_mesh(route, side, lat)

	print("KitV2 Cliffs: %d rocks, %d rubble (all unscaled 1:1 metric, flush seated)" % [
		_placed_rocks.size(), _placed_rubble.size()
	])


func get_cliff_foot_lat(side: float, z: float) -> float:
	var phase := 0.0 if side < 0.0 else 2.15
	var flare_t := clampf((-12.0 - z) / 10.0, 0.0, 1.0)
	var flare := flare_t * flare_t * (3.0 - 2.0 * flare_t) * 8.5
	return 3.05 + flare + 0.38 * sin(z * 0.28 + phase) + 0.20 * cos(z * 0.63 - phase * 0.6) + 0.08 * sin(z * 1.25 + phase * 1.3)


func get_placed_rocks() -> Array[Dictionary]:
	return _placed_rocks


func get_placed_rubble() -> Array[Dictionary]:
	return _placed_rubble


## Return valid shelf planting spots {world_pos, lateral, y, z, shelf_inner, shelf_outer} for bushes.
func get_shelf_slices(side: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _sides.has(side):
		return out
	var lat: Dictionary = _sides[side]
	var zs: Array = lat["z"]
	var tiers: Array = lat["tiers"]
	for iz in zs.size():
		for k in TIERS:
			var td: Dictionary = tiers[k]
			if td["dh"][iz] < 0.35:
				continue
			out.append({
				"z": zs[iz],
				"tier": k,
				"y": td["shelf_y"][iz],
				"inner": td["shelf_inner"][iz],
				"outer": td["shelf_outer"][iz],
			})
	return out


## Audit all placed cliff rocks & rubble against lattice risers, shelf lips, and pairwise overlaps.
## Returns an empty array on 100% pass, or descriptive violation strings.
func audit_clearances() -> Array[String]:
	var issues: Array[String] = []
	for item in _placed_rocks + _placed_rubble:
		var side: float = item["side"]
		var k: int = item["tier"]
		var lat: Dictionary = _sides[side]
		var z: float = item["z"]
		var half_l: float = item["half_l"]
		var half_d: float = item["half_d"]
		var rock_lat: float = item["lateral"]
		var bounds := _shelf_span_bounds(lat, k, z - half_l, z + half_l, true)
		if bounds.is_empty():
			issues.append("%s at z=%.2f side=%.0f tier=%d has invalid shelf span" % [item["label"], z, side, k])
			continue
		var front_clear := (rock_lat - half_d) - float(bounds["max_inner"])
		var back_clear := float(bounds["min_outer"]) - (rock_lat + half_d)
		if front_clear < 0.025:
			issues.append("%s lip overhang (front_clear=%.3f m)" % [item["label"], front_clear])
		if back_clear < 0.045:
			issues.append("%s clips back riser (back_clear=%.3f m)" % [item["label"], back_clear])
		var y_diff := absf(float(item["y"]) - float(bounds["mid_y"]))
		if y_diff > 0.006:
			issues.append("%s not flush on pad (y=%.3f vs pad=%.3f)" % [item["label"], item["y"], bounds["mid_y"]])

	# Pairwise overlap check per side & tier
	var all_items := _placed_rocks + _placed_rubble
	for i in all_items.size():
		var a := all_items[i]
		for j in range(i + 1, all_items.size()):
			var b := all_items[j]
			if a["side"] != b["side"] or a["tier"] != b["tier"]:
				continue
			var dist := Vector2(float(a["world_pos"].x) - float(b["world_pos"].x),
				float(a["world_pos"].z) - float(b["world_pos"].z)).length()
			var min_dist := float(a["radius"]) + float(b["radius"]) + 0.05
			if dist < min_dist:
				issues.append("Overlap %s vs %s: dist=%.3f < %.3f" % [a["label"], b["label"], dist, min_dist])
	return issues


func _generate_lattice(route: Node, side: float) -> Dictionary:
	var n_z := int(round((Z_START - Z_END) / Z_STEP)) + 1
	var zs: Array[float] = []
	for iz in n_z:
		zs.append(Z_START - iz * Z_STEP)

	var phase := 0.0 if side < 0.0 else 2.15
	var nominal_rise := [0.92, 1.15, 1.25, 1.32]
	var taper_starts := [-14.0, -12.5, -10.5, -8.5]
	var taper_ends := [-23.5, -21.0, -18.5, -16.0]

	var tiers: Array[Dictionary] = []
	for k in TIERS:
		var td := {}
		for key in ["dh", "foot_lat", "lip_lat", "shelf_inner", "shelf_outer", "shelf_y"]:
			var arr: Array[float] = []
			arr.resize(n_z)
			arr.fill(0.0)
			td[key] = arr
		var locked: Array[int] = []
		locked.resize(n_z)
		locked.fill(0)
		td["locked"] = locked
		tiers.append(td)

	for iz in n_z:
		var z := zs[iz]
		var foot := get_cliff_foot_lat(side, z)
		var h_accum := 0.0
		for k in TIERS:
			# Smooth continuous tier taper toward exit vista
			var t_raw := clampf((z - taper_ends[k]) / (taper_starts[k] - taper_ends[k]), 0.0, 1.0)
			var taper := t_raw * t_raw * (3.0 - 2.0 * t_raw)
			var wave := 0.90 + 0.16 * sin(z * 0.33 + k * 1.7 + phase) + 0.08 * cos(z * 0.78 - k * 1.1)
			var dh: float = nominal_rise[k] * wave * taper
			if dh < 0.04:
				dh = 0.0
			var setback := dh * 0.34
			var lip := foot + setback
			var inner := lip + (0.07 if dh > 0.0 else 0.0)
			var shelf_w := 0.0
			if dh > 0.0:
				shelf_w = 1.18 + 0.30 * sin(z * 0.29 + k * 2.1 + phase) + 0.14 * cos(z * 0.67 - k * 1.4)
				shelf_w *= clampf(dh / 0.45, 0.35, 1.0)
			var outer := inner + shelf_w
			h_accum += dh
			var sy := h_accum + (0.035 * sin(z * 0.52 + k * 2.1 + phase) if dh > 0.25 else 0.0)
			tiers[k]["dh"][iz] = dh
			tiers[k]["foot_lat"][iz] = foot
			tiers[k]["lip_lat"][iz] = lip
			tiers[k]["shelf_inner"][iz] = inner
			tiers[k]["shelf_outer"][iz] = outer
			tiers[k]["shelf_y"][iz] = maxf(0.0, sy)
			foot = outer

	return {"z": zs, "tiers": tiers, "phase": phase}


func _shelf_span_bounds(lat: Dictionary, k: int, z_min: float, z_max: float, allow_locked: bool = false) -> Dictionary:
	var zs: Array[float] = lat["z"]
	var td: Dictionary = lat["tiers"][k]
	var max_inner := -INF
	var min_outer := INF
	var min_dh := INF
	var sum_y := 0.0
	var cnt := 0
	for iz in zs.size():
		var z := zs[iz]
		if z < z_min - Z_STEP * 0.5 or z > z_max + Z_STEP * 0.5:
			continue
		if not allow_locked and td["locked"][iz] != 0:
			return {}
		max_inner = maxf(max_inner, td["shelf_inner"][iz])
		min_outer = minf(min_outer, td["shelf_outer"][iz])
		min_dh = minf(min_dh, td["dh"][iz])
		sum_y += td["shelf_y"][iz]
		cnt += 1
	if cnt == 0 or min_dh < 0.42:
		return {}
	return {"max_inner": max_inner, "min_outer": min_outer, "mid_y": sum_y / float(cnt)}


func _level_shelf_pad(lat: Dictionary, k: int, z_mid: float, half_l: float, seat_y: float) -> void:
	var zs: Array[float] = lat["z"]
	var td: Dictionary = lat["tiers"][k]
	var pad_lo := z_mid - half_l - Z_STEP * 0.5
	var pad_hi := z_mid + half_l + Z_STEP * 0.5
	var blend_margin := 0.32
	for iz in zs.size():
		var z := zs[iz]
		if z >= pad_lo and z <= pad_hi:
			td["shelf_y"][iz] = seat_y
			td["locked"][iz] = 1
		elif td["locked"][iz] == 0:
			var dist := pad_lo - z if z < pad_lo else z - pad_hi
			if dist < blend_margin:
				var t := 1.0 - dist / blend_margin
				var smooth_t := t * t * (3.0 - 2.0 * t)
				td["shelf_y"][iz] = lerpf(td["shelf_y"][iz], seat_y, smooth_t)


func _place_tier_rocks(route: Node, side: float, lat: Dictionary) -> void:
	var prefix := "L" if side < 0.0 else "R"
	var count := 0
	for k in TIERS:
		var z := Z_START - _rng.randf_range(0.8, 1.5)
		while z > Z_END + 1.5:
			var variant := _rng.randi() % _rock_meshes.size()
			var m: Dictionary = _rock_meta[variant]
			var slope: float = (route.center_x(z - 0.05) - route.center_x(z + 0.05)) / 0.1
			var facing := Vector3(-side, 0.0, side * slope).normalized()
			var base_yaw := atan2(facing.x, facing.z)
			var yaw_off := deg_to_rad(_rng.randf_range(-16.0, 16.0))
			var yaw := base_yaw + yaw_off

			# Conservative rotated 2D footprint extents relative to canyon wall axes
			# Local rock X runs roughly along Z (wall), local rock Z runs roughly along X (across shelf)
			var local_wx: float = m["width_x"]
			var local_dz: float = m["depth_z"]
			var ca := absf(cos(yaw_off))
			var sa := absf(sin(yaw_off))
			var half_l := 0.5 * (local_wx * ca + local_dz * sa)
			var half_d := 0.5 * (local_wx * sa + local_dz * ca)
			var rad: float = m["radius_xz"]

			var bounds := _shelf_span_bounds(lat, k, z - half_l, z + half_l)
			if bounds.is_empty():
				z -= _rng.randf_range(0.7, 1.2)
				continue

			var min_lat := float(bounds["max_inner"]) + half_d + 0.07
			var max_lat := float(bounds["min_outer"]) - half_d - 0.09
			if max_lat < min_lat:
				# Try a smaller rock variant before skipping
				var smaller := maxi(3, variant)
				if smaller != variant:
					m = _rock_meta[smaller]
					variant = smaller
					half_l = 0.5 * (float(m["width_x"]) * ca + float(m["depth_z"]) * sa)
					half_d = 0.5 * (float(m["width_x"]) * sa + float(m["depth_z"]) * ca)
					rad = m["radius_xz"]
					bounds = _shelf_span_bounds(lat, k, z - half_l, z + half_l)
					if bounds.is_empty():
						z -= _rng.randf_range(0.7, 1.2)
						continue
					min_lat = float(bounds["max_inner"]) + half_d + 0.07
					max_lat = float(bounds["min_outer"]) - half_d - 0.09
			if max_lat < min_lat:
				z -= _rng.randf_range(0.7, 1.2)
				continue

			var rock_lat := lerpf(min_lat, max_lat, _rng.randf_range(0.35, 0.85))
			var world_x: float = route.center_x(z) + side * rock_lat
			if _overlaps_tier(side, k, world_x, z, rad + 0.14):
				z -= _rng.randf_range(0.6, 1.0)
				continue

			# Ensure pad vertices aren't already locked at a conflicting height
			var seat_y := float(bounds["mid_y"])
			_level_shelf_pad(lat, k, z, half_l, seat_y)

			var node := MeshInstance3D.new()
			node.name = "CliffRock_%s_T%d_%d" % [prefix, k, count]
			node.mesh = _rock_meshes[variant]
			node.set_surface_override_material(0, _rock_side_material)
			node.set_surface_override_material(1, _rock_top_material)
			node.set_instance_shader_parameter("block_height", float(m["height_y"]))
			node.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(world_x, seat_y, z))
			add_child(node)

			_placed_rocks.append({
				"label": node.name,
				"side": side,
				"tier": k,
				"z": z,
				"y": seat_y,
				"lateral": rock_lat,
				"half_l": half_l,
				"half_d": half_d,
				"radius": rad,
				"world_pos": Vector3(world_x, seat_y, z),
			})
			count += 1
			z -= (half_l * 2.0 + _rng.randf_range(0.18, 0.48))


func _place_shelf_rubble(route: Node, side: float, lat: Dictionary) -> void:
	var prefix := "L" if side < 0.0 else "R"
	var count := 0
	for k in TIERS:
		var z := Z_START - _rng.randf_range(0.9, 1.8)
		while z > Z_END + 2.0:
			z -= _rng.randf_range(1.1, 2.3)
			var variant := _rng.randi() % _rubble_meshes.size()
			var m: Dictionary = _rubble_meta[variant]
			var yaw := _rng.randf_range(0.0, TAU)
			var half_l := float(m["radius_xz"])
			var half_d := float(m["radius_xz"])
			var rad := float(m["radius_xz"])

			var bounds := _shelf_span_bounds(lat, k, z - half_l, z + half_l)
			if bounds.is_empty():
				continue
			var min_lat := float(bounds["max_inner"]) + half_d + 0.06
			var max_lat := float(bounds["min_outer"]) - half_d - 0.08
			if max_lat < min_lat:
				continue
			var rub_lat := lerpf(min_lat, max_lat, _rng.randf_range(0.15, 0.70))
			var world_x: float = route.center_x(z) + side * rub_lat
			if _overlaps_tier(side, k, world_x, z, rad + 0.12):
				continue

			var seat_y := float(bounds["mid_y"])
			_level_shelf_pad(lat, k, z, half_l, seat_y)

			var node := MeshInstance3D.new()
			node.name = "CliffRubble_%s_T%d_%d" % [prefix, k, count]
			node.mesh = _rubble_meshes[variant]
			node.set_surface_override_material(0, _rock_side_material)
			node.set_surface_override_material(1, _rock_top_material)
			node.set_instance_shader_parameter("block_height", float(m["height_y"]))
			node.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(world_x, seat_y, z))
			add_child(node)

			_placed_rubble.append({
				"label": node.name,
				"side": side,
				"tier": k,
				"z": z,
				"y": seat_y,
				"lateral": rub_lat,
				"half_l": half_l,
				"half_d": half_d,
				"radius": rad,
				"world_pos": Vector3(world_x, seat_y, z),
			})
			count += 1


func _overlaps_tier(side: float, tier: int, world_x: float, z: float, min_gap_radius: float) -> bool:
	for item in _placed_rocks + _placed_rubble:
		if item["side"] != side or item["tier"] != tier:
			continue
		var p: Vector3 = item["world_pos"]
		if Vector2(p.x - world_x, p.z - z).length() < float(item["radius"]) + min_gap_radius:
			return true
	return false


func _build_bedrock_mesh(route: Node, side: float, lat: Dictionary) -> void:
	var zs: Array[float] = lat["z"]
	var tiers: Array = lat["tiers"]
	var phase: float = lat["phase"]
	var n_z := zs.size()

	var strata_st := SurfaceTool.new()
	var ledge_st := SurfaceTool.new()
	strata_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	ledge_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build per-tier organic riser strips (Surface 0 = strata) and shelf strips (Surface 1 = ledge)
	for k in TIERS:
		var td: Dictionary = tiers[k]
		var prev_td: Dictionary = tiers[k - 1] if k > 0 else {}
		var riser_grid: Array = []  # [iz][p_idx] -> Vector3
		var shelf_grid: Array = []  # [iz][s_idx] -> Vector3

		for iz in n_z:
			var z := zs[iz]
			var cx: float = route.center_x(z)
			var dh: float = td["dh"][iz]
			var h_bot := 0.0 if k == 0 else float(prev_td["shelf_y"][iz])
			var h_top: float = td["shelf_y"][iz]
			var f_lat: float = td["foot_lat"][iz]
			var l_lat: float = td["lip_lat"][iz]
			var s_in: float = td["shelf_inner"][iz]
			var s_out: float = td["shelf_outer"][iz]
			var setback := l_lat - f_lat

			# 5-point battered organic rock profile with natural middle bulges
			var b1 := 0.03 * sin(z * 0.95 + k * 2.1 + phase) if dh > 0.25 else 0.0
			var b2 := 0.06 * sin(z * 0.75 + k * 3.3 + phase) if dh > 0.25 else 0.0
			var b3 := 0.03 * cos(z * 1.15 + k * 1.4 + phase) if dh > 0.25 else 0.0
			var dy := h_top - h_bot
			var r_pts: Array[Vector3] = [
				Vector3(cx + side * f_lat, h_bot, z),
				Vector3(cx + side * (f_lat + setback * 0.18 + b1), h_bot + dy * 0.24, z),
				Vector3(cx + side * (f_lat + setback * 0.46 + b2), h_bot + dy * 0.56, z),
				Vector3(cx + side * (f_lat + setback * 0.78 + b3), h_bot + dy * 0.85, z),
				Vector3(cx + side * l_lat, maxf(h_bot, h_top - (0.035 if dh > 0.1 else 0.0)), z),
			]
			riser_grid.append(r_pts)

			# Shelf strip: shoulder lip bevel (l_lat -> s_in) + flat/padded shelf + outer plateau on topmost active tier
			var s_mid := 0.5 * (s_in + s_out)
			var s_pts: Array[Vector3] = [
				r_pts[4],
				Vector3(cx + side * s_in, h_top, z),
				Vector3(cx + side * s_mid, h_top, z),
				Vector3(cx + side * s_out, h_top, z),
			]
			if k == TIERS - 1:
				# Outer undulating canyon rim plateau (+6.5 m outward)
				for extra: float in [1.8, 3.8, 6.5]:
					var p_lat: float = s_out + extra
					var p_y := h_top + (0.08 * sin(p_lat * 0.6 + z * 0.25 + phase) if h_top > 0.2 else 0.0)
					s_pts.append(Vector3(cx + side * p_lat, maxf(0.0, p_y), z))
			shelf_grid.append(s_pts)

		_emit_strata_grid(strata_st, riser_grid, side)
		_emit_ledge_grid(ledge_st, shelf_grid, side)

	var core := MeshInstance3D.new()
	core.name = "CoreLeft" if side < 0.0 else "CoreRight"
	var mesh := ArrayMesh.new()
	strata_st.generate_tangents()
	strata_st.commit(mesh)
	mesh.surface_set_material(0, _strata_material)
	ledge_st.generate_tangents()
	ledge_st.commit(mesh)
	mesh.surface_set_material(1, _ledge_material)
	core.mesh = mesh
	add_child(core)


func _emit_strata_grid(st: SurfaceTool, grid: Array, side: float) -> void:
	var n_z := grid.size()
	var n_p: int = (grid[0] as Array).size()
	# Compute arc-length U (along Z) and arc-length V (up riser) per lattice vertex
	var u_arr := PackedFloat32Array()
	u_arr.resize(n_z)
	u_arr[0] = 0.0
	for iz in range(1, n_z):
		var step_len: float = (grid[iz][2] as Vector3).distance_to(grid[iz - 1][2])
		u_arr[iz] = u_arr[iz - 1] + step_len / _strata_tile.x

	var v_grid: Array = []
	for iz in n_z:
		var vs := PackedFloat32Array()
		vs.resize(n_p)
		for ip in n_p:
			# World-Y sedimentary bedding: strata lines stay horizontal across tapers and curved toes.
			vs[ip] = -(grid[iz][ip] as Vector3).y / _strata_tile.y
		v_grid.append(vs)

	var normals := _smooth_grid_normals(grid, Vector3(-side, 0.15, 0.0).normalized(), side < 0.0)
	for iz in n_z - 1:
		for ip in n_p - 1:
			var p00: Vector3 = grid[iz][ip]
			var p01: Vector3 = grid[iz][ip + 1]
			var p11: Vector3 = grid[iz + 1][ip + 1]
			var p10: Vector3 = grid[iz + 1][ip]
			if p00.distance_to(p01) < 0.002 and p10.distance_to(p11) < 0.002:
				continue
			var uv00 := Vector2(u_arr[iz], v_grid[iz][ip])
			var uv01 := Vector2(u_arr[iz], v_grid[iz][ip + 1])
			var uv11 := Vector2(u_arr[iz + 1], v_grid[iz + 1][ip + 1])
			var uv10 := Vector2(u_arr[iz + 1], v_grid[iz + 1][ip])
			var n00: Vector3 = normals[iz][ip]
			var n01: Vector3 = normals[iz][ip + 1]
			var n11: Vector3 = normals[iz + 1][ip + 1]
			var n10: Vector3 = normals[iz + 1][ip]
			_add_quad(st, [p00, p01, p11, p10], [uv00, uv01, uv11, uv10], [n00, n01, n11, n10], Vector3(-side, 0.0, 0.0))


func _emit_ledge_grid(st: SurfaceTool, grid: Array, side: float) -> void:
	var n_z := grid.size()
	var n_p: int = (grid[0] as Array).size()
	var normals := _smooth_grid_normals(grid, Vector3.UP, side > 0.0)
	for iz in n_z - 1:
		for ip in n_p - 1:
			var p00: Vector3 = grid[iz][ip]
			var p01: Vector3 = grid[iz][ip + 1]
			var p11: Vector3 = grid[iz + 1][ip + 1]
			var p10: Vector3 = grid[iz + 1][ip]
			if p00.distance_to(p01) < 0.002 and p10.distance_to(p11) < 0.002:
				continue
			if p00.y < 0.03 and p01.y < 0.03 and p11.y < 0.03 and p10.y < 0.03:
				continue
			var uv00 := Vector2(p00.x / _ledge_tile.x, p00.z / _ledge_tile.y)
			var uv01 := Vector2(p01.x / _ledge_tile.x, p01.z / _ledge_tile.y)
			var uv11 := Vector2(p11.x / _ledge_tile.x, p11.z / _ledge_tile.y)
			var uv10 := Vector2(p10.x / _ledge_tile.x, p10.z / _ledge_tile.y)
			var n00: Vector3 = normals[iz][ip]
			var n01: Vector3 = normals[iz][ip + 1]
			var n11: Vector3 = normals[iz + 1][ip + 1]
			var n10: Vector3 = normals[iz + 1][ip]
			_add_quad(st, [p00, p01, p11, p10], [uv00, uv01, uv11, uv10], [n00, n01, n11, n10], Vector3.UP)


func _smooth_grid_normals(grid: Array, fallback: Vector3, flip_cross: bool) -> Array:
	var n_z := grid.size()
	var n_p: int = (grid[0] as Array).size()
	var acc: Array = []
	for iz in n_z:
		var row: Array[Vector3] = []
		row.resize(n_p)
		row.fill(Vector3.ZERO)
		acc.append(row)
	for iz in n_z - 1:
		for ip in n_p - 1:
			var a: Vector3 = grid[iz][ip]
			var b: Vector3 = grid[iz][ip + 1]
			var c: Vector3 = grid[iz + 1][ip + 1]
			var d: Vector3 = grid[iz + 1][ip]
			var n1 := (b - a).cross(c - a)
			if n1.length_squared() > 1e-8:
				var fn := n1.normalized()
				if fn.dot(fallback) < 0.0:
					fn = -fn
				acc[iz][ip] += fn
				acc[iz][ip + 1] += fn
				acc[iz + 1][ip + 1] += fn
				acc[iz + 1][ip] += fn
			var n2 := (c - a).cross(d - a)
			if n2.length_squared() > 1e-8:
				var fn2 := n2.normalized()
				if fn2.dot(fallback) < 0.0:
					fn2 = -fn2
				acc[iz][ip] += fn2
				acc[iz + 1][ip + 1] += fn2
				acc[iz + 1][ip] += fn2
	for iz in n_z:
		for ip in n_p:
			var v: Vector3 = acc[iz][ip]
			acc[iz][ip] = v.normalized() if v.length_squared() > 1e-8 else fallback
	return acc


func _add_quad(st: SurfaceTool, pts: Array, uvs: Array, nrms: Array, want_dir: Vector3) -> void:
	var face_n: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0])
	if face_n.length_squared() < 1e-10:
		face_n = (pts[2] - pts[0]).cross(pts[3] - pts[0])
	var order := [0, 1, 2, 0, 2, 3]
	if face_n.dot(want_dir) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for idx: int in order:
		st.set_normal(nrms[idx])
		st.set_uv(uvs[idx])
		st.add_vertex(pts[idx])


func _load_assets() -> void:
	if _rock_meshes.is_empty():
		var mesh_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MESHES_JSON))["meshes"]
		var glb: Node = (load(MESHES_GLB) as PackedScene).instantiate()
		for i in 6:
			var k := "cliff_rock_%d" % i
			var mi := glb.find_child(k, true, false) as MeshInstance3D
			if mi:
				_rock_meshes.append(mi.mesh)
				_rock_meta.append(mesh_data[k])
		for i in 4:
			var k := "rubble_%d" % i
			var mi := glb.find_child(k, true, false) as MeshInstance3D
			if mi:
				_rubble_meshes.append(mi.mesh)
				_rubble_meta.append(mesh_data[k])
		glb.free()

	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_JSON))
	_strata_tile = Vector2(manifest["cliff_strata"]["tile_m"][0], manifest["cliff_strata"]["tile_m"][1])
	_ledge_tile = Vector2(manifest["cliff_ledge"]["tile_m"][0], manifest["cliff_ledge"]["tile_m"][1])

	_setup_mat(_strata_material, "cliff_strata_albedo.png", "cliff_strata_normal.png", 0.0, 0.78)
	_setup_mat(_ledge_material, "cliff_ledge_albedo.png", "cliff_ledge_normal.png", 0.0, 0.72)
	_setup_mat(_rock_side_material, "cliff_rock_side_albedo.png", "cliff_rock_side_normal.png", 0.30, 0.84)
	_setup_mat(_rock_top_material, "cliff_rock_top_albedo.png", "cliff_rock_top_normal.png", 0.0, 0.84)


func _setup_mat(mat: ShaderMaterial, alb: String, nrm: String, base_ao: float, bright: float) -> void:
	mat.shader = ROCK_SHADER
	mat.set_shader_parameter("albedo_tex", load(TEX_ROOT + alb))
	mat.set_shader_parameter("normal_tex", load(TEX_ROOT + nrm))
	mat.set_shader_parameter("base_ao", base_ao)
	mat.set_shader_parameter("brightness", bright)
	mat.set_shader_parameter("normal_depth", 0.65)
