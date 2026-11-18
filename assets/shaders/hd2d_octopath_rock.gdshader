shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D sandstone_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sandstone_norm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D basalt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D basalt_norm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D boulder_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D boulder_norm : hint_normal, filter_linear_mipmap, repeat_enable;

uniform vec3 haze_color : source_color = vec3(0.95, 0.78, 0.52);
uniform float haze_strength : hint_range(0.0, 1.0) = 0.24;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 sample_triplanar(sampler2D tex, vec3 pos, vec3 w, float scale) {
	return texture(tex, pos.zy * scale).rgb * w.x
		+ texture(tex, pos.xz * scale).rgb * w.y
		+ texture(tex, pos.xy * scale).rgb * w.z;
}

void fragment() {
	vec3 nrm = normalize(world_nrm);
	vec3 w = pow(abs(nrm), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);

	vec3 sand_col = sample_triplanar(sandstone_tex, world_pos, w, 0.42);
	vec3 sand_nrm = sample_triplanar(sandstone_norm, world_pos, w, 0.42);

	vec3 bas_col = sample_triplanar(basalt_tex, world_pos, w, 0.58);
	vec3 bas_nrm = sample_triplanar(basalt_norm, world_pos, w, 0.58);

	vec3 bld_col = sample_triplanar(boulder_tex, world_pos, w, 0.65);
	vec3 bld_nrm = sample_triplanar(boulder_norm, world_pos, w, 0.65);

	// Vertex color: R = 0.0 sandstone / 1.0 basalt cap, G = AO, B = 1.0 on BoulderCluster (0.0..0.40 on terraces)
	float is_boulder = smoothstep(0.65, 0.90, COLOR.b);
	float is_basalt = smoothstep(0.45, 0.85, COLOR.r) * (1.0 - is_boulder);

	vec3 base_col = mix(sand_col, bld_col, is_boulder);
	vec3 base_nrm = mix(sand_nrm, bld_nrm, is_boulder);

	vec3 final_col = mix(base_col, bas_col, is_basalt);
	vec3 final_nrm = mix(base_nrm, bas_nrm, is_basalt);

	// Baked crevice & ground-contact AO from vertex color G + subtle chamfer wear / boulder crown highlight
	float ao = clamp(COLOR.g, 0.35, 1.0);
	float strata_rib = sin(world_pos.y * 12.5 + sin(world_pos.z * 1.4)) * 0.045 * (1.0 - is_basalt) * (1.0 - is_boulder);
	float edge_lift = COLOR.b * 0.35 * (1.0 - is_boulder) + is_boulder * max(0.0, nrm.y) * 0.10;
	final_col = final_col * (ao + strata_rib + edge_lift);

	float cam_dist = length(CAMERA_POSITION_WORLD - world_pos);
	float haze_t = smoothstep(16.0, 44.0, cam_dist) * haze_strength;

	ALBEDO = mix(final_col, haze_color, haze_t);
	NORMAL_MAP = normalize(final_nrm);
	NORMAL_MAP_DEPTH = 1.25;
	ROUGHNESS = mix(0.86, 0.78, is_basalt);
}
