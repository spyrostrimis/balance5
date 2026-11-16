shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D cobble_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cobble_norm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_norm : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float path_cx = sin(world_pos.z * 0.22) * 0.35;
	vec3 c_col = texture(cobble_tex, world_pos.xz * 0.55).rgb;
	vec3 s_col = texture(sand_tex, world_pos.xz * 0.35).rgb;

	float edge_noise = (c_col.r - 0.5) * 0.30 + sin(world_pos.z * 2.3) * 0.07;
	float dist = abs(world_pos.x - path_cx) + edge_noise;
	float path_mask = 1.0 - smoothstep(1.05, 1.38, dist);
	float curb_rim = smoothstep(0.92, 1.12, dist) * (1.0 - smoothstep(1.12, 1.38, dist)) * 0.22;

	ALBEDO = mix(s_col, c_col, path_mask) * (1.0 - curb_rim);
	NORMAL_MAP = mix(
		texture(sand_norm, world_pos.xz * 0.35).rgb,
		texture(cobble_norm, world_pos.xz * 0.55).rgb,
		path_mask
	);
	NORMAL_MAP_DEPTH = 1.3;
	ROUGHNESS = 0.88;
}
