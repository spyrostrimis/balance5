// GENERATED from assets/shaders/hd2d_canyon_ground_crisp.gdshader by tools/python/make_pixel_shader_variants.py.
// Nearest-filter samplers and uniform repeat scales for pixel-art textures. Edit the source, then regenerate.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D cobble_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D cobble_norm : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D cobble_orm : hint_default_white, filter_nearest_mipmap, repeat_enable;

// Optional comparison control texture (e.g. handlaid_sandstone) when compare_mode == 1
uniform sampler2D patch_compare_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D patch_compare_norm : hint_normal, filter_nearest_mipmap, repeat_enable;

uniform sampler2D sand_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D sand_norm : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D desert_sand_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D desert_sand_norm : hint_normal, filter_nearest_mipmap, repeat_enable;

uniform vec3 player_pos = vec3(0.0, 0.0, 6.0);
uniform float painted_right_shadow_strength : hint_range(0.0, 1.0) = 0.42;
uniform float cobble_tile_metres = 4.0;
uniform float cobble_verge_wear : hint_range(0.0, 1.0) = 0.94;
uniform int compare_mode = 0; // 0 = full road ultra-crisp, 1 = center comparison patch over patch_compare_tex
// Route centre x = route_amplitude * sin(z * route_frequency + route_phase). Defaults match D4b.
uniform float route_amplitude = 0.65;
uniform float route_frequency = 0.22;
uniform float route_phase = 0.0;
// route_mode 1 samples an authored Path3D route written by canyon_route_path.gd.
uniform int route_mode = 0;
uniform float route_lookup[64];
uniform float route_lookup_z0 = 0.0;
uniform float route_lookup_dz = 1.0;

// Repeat scales exposed for authored pixel sets (defaults match the source shader).
uniform vec2 sand_scale = vec2(0.46, 0.24); // verge sand, repeats per metre (x, z)
uniform vec2 sand_scale_detail = vec2(0.31, 0.17); // second sand octave
uniform float desert_scale = 0.24; // open dunes
uniform sampler2D cobble_height : hint_default_black, filter_linear_mipmap, repeat_enable; // relief_height.py
uniform float relief_depth = 0.0; // metres a stone top rises above its joints; 0 = flat (source behaviour)
uniform float relief_side_shade : hint_range(0.0, 1.0) = 0.55; // darken stone sides like the painted joints
varying float relief_side;
uniform vec2 cliff_ao_range = vec2(1.35, 2.65); // painted shading toward the walls (from, to), metres from the route
uniform float curb_dust = 0.0; // darkening of the sand just outside the curbs; 0 = off (source behaviour)
uniform vec2 curb_dust_range = vec2(1.45, 2.1); // darkest at x, gone by y, metres from the route

float route_center(float z) {
	if (route_mode == 0) {
		return sin(z * route_frequency + route_phase) * route_amplitude;
	}
	float f = clamp((z - route_lookup_z0) / route_lookup_dz, 0.0, 63.0);
	int i = int(floor(f));
	int j = min(i + 1, 63);
	return mix(route_lookup[i], route_lookup[j], f - float(i));
}

varying vec3 world_pos;

float relief_at(vec2 xz) {
	float path_cx = route_center(xz.y);
	vec2 uv = xz / cobble_tile_metres;
	float h = textureLod(cobble_height, uv, 0.0).r;
	vec3 c_col = textureLod(cobble_tex, uv, 0.0).rgb * mix(0.40, 1.06, textureLod(cobble_orm, uv, 0.0).r);
	float edge_noise = (c_col.r - 0.5) * 0.22 + sin(xz.y * 2.3 + c_col.g * 1.6) * 0.07;
	float dist = abs(xz.x - path_cx) + edge_noise;
	float keep = (1.0 - smoothstep(1.10, 1.38, dist)) * (1.0 - smoothstep(-12.6, -16.0, xz.y));
	if (cobble_verge_wear > 0.0) {
		float edge = smoothstep(0.76, 1.27, abs(xz.x - path_cx));
		float pockets = 0.56 * sin(xz.y * 1.71 + sin(xz.x * 2.9 + xz.y * 0.37))
			+ 0.29 * sin(xz.y * 4.45 - xz.x * 5.2)
			+ 0.15 * sin(xz.y * 8.3 + xz.x * 6.3);
		keep *= 1.0 - cobble_verge_wear * edge * smoothstep(-0.05, 0.72, pockets);
	}
	return h * keep * relief_depth;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	relief_side = 0.0;
	if (relief_depth > 0.0) {
		// The relief mesh sits at the origin, so local and world axes agree.
		float e = 0.01;
		float h = relief_at(world_pos.xz);
		float dx = (relief_at(world_pos.xz + vec2(e, 0.0)) - relief_at(world_pos.xz - vec2(e, 0.0))) / (2.0 * e);
		float dz = (relief_at(world_pos.xz + vec2(0.0, e)) - relief_at(world_pos.xz - vec2(0.0, e))) / (2.0 * e);
		VERTEX.y += h;
		world_pos.y += h;
		NORMAL = normalize(vec3(-dx, 1.0, -dz));
		// Steep sides take the joint's place on screen, so they carry its darkness (dirt and occlusion).
		relief_side = clamp(length(vec2(dx, dz)) * 0.9, 0.0, 1.0);
		TANGENT = normalize(vec3(1.0, dx, 0.0));
		BINORMAL = normalize(cross(NORMAL, TANGENT));
	}
}

void fragment() {
	float path_cx = route_center(world_pos.z);
	float macro_w = sin(world_pos.x * 1.1 + sin(world_pos.z * 0.7)) * 0.5 + 0.5;
	vec2 cobble_uv = world_pos.xz / cobble_tile_metres;

	vec3 crisp_col = texture(cobble_tex, cobble_uv).rgb;
	vec3 crisp_norm = texture(cobble_norm, cobble_uv).rgb;
	vec3 crisp_orm = texture(cobble_orm, cobble_uv).rgb;

	// Deep cavity AO baked cleanly into albedo + ORM AO channel so sky ambient cannot milk out stone crevices
	float cav_ao = crisp_orm.r;
	crisp_col *= mix(0.40, 1.06, cav_ao);
	// Slight crisp rim micro-boost from ORM.b
	crisp_col *= 1.0 + crisp_orm.b * 0.06;

	vec3 c_col = crisp_col;
	vec3 c_norm = crisp_norm;
	float c_ao = cav_ao;
	float c_rough = crisp_orm.g;

	if (compare_mode == 1) {
		// Split comparison around Commander's Spawn (Z=2.0..8.6) so crisp stones sit right beside Session 3 control
		float x_rel = world_pos.x - (path_cx - 0.10);
		float edge_x = 0.68 - abs(x_rel);
		float edge_z = 3.2 - abs(world_pos.z - 5.4);
		float in_patch = smoothstep(0.0, 0.02, min(edge_x, edge_z));

		vec3 base_cmp_col = texture(patch_compare_tex, cobble_uv).rgb;
		vec3 base_cmp_norm = texture(patch_compare_norm, cobble_uv).rgb;

		c_col = mix(base_cmp_col, crisp_col, in_patch);
		c_norm = mix(base_cmp_norm, crisp_norm, in_patch);
		c_ao = mix(1.0, cav_ao, in_patch);
		c_rough = mix(0.86, crisp_orm.g, in_patch);
	}

	vec2 sand_uv1 = world_pos.xz * sand_scale;
	vec2 sand_uv2 = world_pos.xz * sand_scale_detail + vec2(0.43, 0.29);
	vec3 s_col = mix(texture(sand_tex, sand_uv1).rgb, texture(sand_tex, sand_uv2).rgb, macro_w * 0.50);
	vec3 s_norm = normalize(mix(texture(sand_norm, sand_uv1).rgb, texture(sand_norm, sand_uv2).rgb, macro_w * 0.50));

	vec3 d_col = texture(desert_sand_tex, world_pos.xz * desert_scale).rgb;
	vec3 d_norm = texture(desert_sand_norm, world_pos.xz * desert_scale).rgb;

	float edge_noise = (c_col.r - 0.5) * 0.22 + sin(world_pos.z * 2.3 + c_col.g * 1.6) * 0.07;
	float dist = abs(world_pos.x - path_cx) + edge_noise;

	float path_mask = 1.0 - smoothstep(1.10, 1.38, dist);
	float curb_band = 1.0 - smoothstep(0.0, 0.18, abs(dist - 1.22));
	float curb_breaks = smoothstep(0.25, 0.75, sin(world_pos.z * 3.8 + world_pos.x * 1.7) * 0.5 + 0.5);
	float curb_rim = curb_band * (0.35 + 0.65 * curb_breaks);

	float dune_t = smoothstep(-12.8, -17.5, world_pos.z);
	float trail_keep = path_mask * (1.0 - smoothstep(-12.6, -16.0, world_pos.z));
	if (cobble_verge_wear > 0.0) {
		float edge = smoothstep(0.76, 1.27, abs(world_pos.x - path_cx));
		float pockets = 0.56 * sin(world_pos.z * 1.71 + sin(world_pos.x * 2.9 + world_pos.z * 0.37))
			+ 0.29 * sin(world_pos.z * 4.45 - world_pos.x * 5.2)
			+ 0.15 * sin(world_pos.z * 8.3 + world_pos.x * 6.3);
		float sand_wear = cobble_verge_wear * edge * smoothstep(-0.05, 0.72, pockets);
		trail_keep *= 1.0 - sand_wear;
		curb_rim *= 1.0 - sand_wear;
	}

	vec3 canyon_ground = mix(s_col * 0.90, c_col, trail_keep);
	vec3 curb_tint = c_col * vec3(0.56, 0.52, 0.48);
	canyon_ground = mix(canyon_ground, curb_tint, curb_rim * (1.0 - smoothstep(-12.4, -15.6, world_pos.z)) * 0.78);

	vec3 base_col = mix(canyon_ground, d_col * 1.02, dune_t);

	// Grounded ambient occlusion under ledges + organic diagonal right-edge wall shadow matching Concept road detail
	float cliff_ao = smoothstep(cliff_ao_range.x, cliff_ao_range.y, abs(world_pos.x - path_cx)) * (1.0 - dune_t) * 0.46;
	float shadow_wobble = sin(world_pos.z * 1.45) * 0.22 + sin(world_pos.z * 3.7) * 0.09;
	float right_shadow = smoothstep(0.42 + shadow_wobble, 1.35 + shadow_wobble, world_pos.x - path_cx) * (1.0 - dune_t) * painted_right_shadow_strength;
	base_col *= (1.0 - cliff_ao) * (1.0 - right_shadow);
	float curb_d = abs(world_pos.x - path_cx);
	base_col *= 1.0 - curb_dust * smoothstep(curb_dust_range.y, curb_dust_range.x, curb_d)
		* smoothstep(curb_dust_range.x - 0.15, curb_dust_range.x, curb_d) * (1.0 - dune_t);

	vec2 p_delta = world_pos.xz - player_pos.xz;
	p_delta.x *= 1.15;
	p_delta.y *= 1.55;
	float p_dist = length(p_delta);
	float hero_shadow = (1.0 - smoothstep(0.16, 0.54, p_dist)) * 0.44;
	base_col *= (1.0 - hero_shadow);

	float horizon_mist = smoothstep(-26.0, -48.0, world_pos.z);
	base_col = mix(base_col, vec3(0.91, 0.72, 0.48), horizon_mist);

	vec3 canyon_norm = mix(s_norm, c_norm, trail_keep);
	ALBEDO = base_col * (1.0 - relief_side_shade * relief_side);
	NORMAL_MAP = mix(canyon_norm, d_norm, dune_t);
	NORMAL_MAP_DEPTH = mix(1.40, 2.15, trail_keep);
	ROUGHNESS = mix(mix(0.88, c_rough, trail_keep), 0.94, dune_t);
	SPECULAR = mix(mix(0.18, 0.52 * (1.0 - c_rough) + 0.18, trail_keep), 0.14, dune_t);
	AO = mix(1.0, c_ao, trail_keep * (1.0 - dune_t));
	AO_LIGHT_AFFECT = 0.75;
}
