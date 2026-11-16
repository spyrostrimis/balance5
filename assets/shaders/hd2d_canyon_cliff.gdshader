shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D red_cliff_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D red_cliff_norm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dark_ledge_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dark_ledge_norm : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 nrm = normalize(world_nrm);
	vec3 w = pow(abs(nrm), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);

	vec3 cliff_col =
		texture(red_cliff_tex, world_pos.zy * 0.32).rgb * w.x +
		texture(red_cliff_tex, world_pos.xz * 0.32).rgb * w.y +
		texture(red_cliff_tex, world_pos.xy * 0.32).rgb * w.z;

	vec3 cliff_norm =
		texture(red_cliff_norm, world_pos.zy * 0.32).rgb * w.x +
		texture(red_cliff_norm, world_pos.xz * 0.32).rgb * w.y +
		texture(red_cliff_norm, world_pos.xy * 0.32).rgb * w.z;

	vec3 ledge_col =
		texture(dark_ledge_tex, world_pos.zy * 0.45).rgb * w.x +
		texture(dark_ledge_tex, world_pos.xz * 0.45).rgb * w.y +
		texture(dark_ledge_tex, world_pos.xy * 0.45).rgb * w.z;

	vec3 ledge_norm =
		texture(dark_ledge_norm, world_pos.zy * 0.45).rgb * w.x +
		texture(dark_ledge_norm, world_pos.xz * 0.45).rgb * w.y +
		texture(dark_ledge_norm, world_pos.xy * 0.45).rgb * w.z;

	// Match img1's signature dark basalt terrace caps & horizontal dark courses
	float top_mask = smoothstep(0.45, 0.72, nrm.y);
	float y_wobble = sin(world_pos.z * 0.8 + world_pos.x * 0.9) * 0.06;
	float wy = world_pos.y + y_wobble;
	float band1 = smoothstep(0.80, 0.90, wy) * (1.0 - smoothstep(1.30, 1.40, wy));
	float band2 = smoothstep(2.00, 2.10, wy) * (1.0 - smoothstep(2.55, 2.65, wy));
	float dark_mask = clamp(max(top_mask, max(band1, band2) * 0.92), 0.0, 1.0);

	float strata = sin(world_pos.y * 11.0) * 0.045;
	float ao = 0.88 + 0.12 * smoothstep(0.0, 0.3, fract(world_pos.y * 0.5));

	vec3 col = mix(cliff_col * (ao + strata), ledge_col * 0.82, dark_mask);

	// Warm golden atmospheric distance haze based on distance from active dolly camera
	float cam_dist = length(world_pos - INV_VIEW_MATRIX[3].xyz);
	float haze = clamp((cam_dist - 14.0) / 20.0, 0.0, 0.34);
	col = mix(col, vec3(0.95, 0.80, 0.55), haze);

	ALBEDO = col;
	ROUGHNESS = 0.86;
	NORMAL_MAP = mix(cliff_norm, ledge_norm, dark_mask);
	NORMAL_MAP_DEPTH = 1.25;
}
