shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D cobble_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cobble_norm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_norm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D desert_sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D desert_sand_norm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 player_pos = vec3(0.0, 0.0, 6.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Matches BlueCommander path S-curve: sin(z * 0.22) * 0.65
	float path_cx = sin(world_pos.z * 0.22) * 0.65;
	// Dual-scale offset UV octaves break up repeating tile grid seams on cobbles and sand
	float macro_w = sin(world_pos.x * 1.1 + sin(world_pos.z * 0.7)) * 0.5 + 0.5;
	vec2 cobble_uv1 = world_pos.xz * vec2(0.82, 0.26);
	vec2 cobble_uv2 = world_pos.xz * vec2(0.57, 0.19) + vec2(0.37, 0.61);
	vec3 c_col = mix(texture(cobble_tex, cobble_uv1).rgb, texture(cobble_tex, cobble_uv2).rgb, macro_w * 0.45);
	vec3 c_norm = normalize(mix(texture(cobble_norm, cobble_uv1).rgb, texture(cobble_norm, cobble_uv2).rgb, macro_w * 0.45));

	vec2 sand_uv1 = world_pos.xz * vec2(0.46, 0.24);
	vec2 sand_uv2 = world_pos.xz * vec2(0.31, 0.17) + vec2(0.43, 0.29);
	vec3 s_col = mix(texture(sand_tex, sand_uv1).rgb, texture(sand_tex, sand_uv2).rgb, macro_w * 0.50);
	vec3 s_norm = normalize(mix(texture(sand_norm, sand_uv1).rgb, texture(sand_norm, sand_uv2).rgb, macro_w * 0.50));

	vec3 d_col = texture(desert_sand_tex, world_pos.xz * 0.24).rgb;

	float edge_noise = (c_col.r - 0.5) * 0.26 + sin(world_pos.z * 2.3 + c_col.g * 1.6) * 0.08;
	float dist = abs(world_pos.x - path_cx) + edge_noise;

	// Broad ~2.5m cobblestone trail
	float path_mask = 1.0 - smoothstep(1.10, 1.38, dist);

	// Textured flagstone curb stones bordering both sides of the trail
	float curb_band = 1.0 - smoothstep(0.0, 0.18, abs(dist - 1.22));
	float curb_breaks = smoothstep(0.25, 0.75, sin(world_pos.z * 3.8 + world_pos.x * 1.7) * 0.5 + 0.5);
	float curb_rim = curb_band * (0.35 + 0.65 * curb_breaks);

	vec3 d_norm = texture(desert_sand_norm, world_pos.xz * 0.24).rgb;

	// Smooth golden desert dune transition past canyon mouth (Z < -12.8)
	float dune_t = smoothstep(-12.8, -17.5, world_pos.z);
	float trail_keep = path_mask * (1.0 - smoothstep(-12.6, -16.0, world_pos.z));

	vec3 canyon_ground = mix(s_col * 0.94, c_col, trail_keep);
	// Weathered flagstone curb borders
	vec3 curb_tint = c_col * vec3(0.60, 0.56, 0.52);
	canyon_ground = mix(canyon_ground, curb_tint, curb_rim * (1.0 - smoothstep(-12.4, -15.6, world_pos.z)) * 0.74);

	vec3 base_col = mix(canyon_ground, d_col * 1.02, dune_t);

	// Soft side cliff-base ambient occlusion & cool-amber right gorge wall shadow
	float cliff_ao = smoothstep(1.45, 2.75, abs(world_pos.x - path_cx)) * (1.0 - dune_t) * 0.48;
	float right_shadow = smoothstep(0.55, 2.15, world_pos.x - path_cx) * (1.0 - dune_t) * 0.24;
	base_col *= (1.0 - cliff_ao) * (1.0 - right_shadow);

	// Dynamic grounded shadow directly under the Blue Commander
	vec2 p_delta = world_pos.xz - player_pos.xz;
	p_delta.x *= 1.15;
	p_delta.y *= 1.55;
	float p_dist = length(p_delta);
	float hero_shadow = (1.0 - smoothstep(0.16, 0.54, p_dist)) * 0.44;
	base_col *= (1.0 - hero_shadow);

	// Distant golden horizon mist melts ground edge seamlessly into mountain vista
	float horizon_mist = smoothstep(-26.0, -48.0, world_pos.z);
	base_col = mix(base_col, vec3(0.91, 0.72, 0.48), horizon_mist);

	vec3 canyon_norm = mix(s_norm, c_norm, trail_keep);
	ALBEDO = base_col;
	NORMAL_MAP = mix(canyon_norm, d_norm, dune_t);
	NORMAL_MAP_DEPTH = 1.45;
	ROUGHNESS = mix(0.86, 0.94, dune_t);
}
