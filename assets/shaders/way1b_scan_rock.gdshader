shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D detail_strata_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_strata_norm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_blend : hint_range(0.0, 1.0) = 0.22;
uniform float detail_scale : hint_range(0.1, 4.0) = 0.55;

uniform float grade_strength : hint_range(0.0, 1.0) = 0.68;
uniform float luma_floor : hint_range(0.0, 0.7) = 0.0;
uniform float luma_contrast : hint_range(0.2, 2.0) = 1.0;
uniform vec3 shadow_tint : source_color = vec3(0.24, 0.15, 0.14);
uniform vec3 mid_tint : source_color = vec3(0.68, 0.44, 0.30);
uniform vec3 crown_tint : source_color = vec3(0.94, 0.73, 0.52);

uniform float normal_strength : hint_range(0.0, 3.0) = 1.30;
uniform float cavity_strength : hint_range(0.0, 1.0) = 0.65;
uniform float ridge_highlight : hint_range(0.0, 0.6) = 0.18;
uniform float top_crown_boost : hint_range(0.0, 0.8) = 0.28;
uniform float basal_ao_height : hint_range(0.0, 2.0) = 0.45;
uniform float basal_ao_strength : hint_range(0.0, 1.0) = 0.42;

uniform vec3 haze_color : source_color = vec3(0.95, 0.78, 0.52);
uniform float haze_strength : hint_range(0.0, 1.0) = 0.12;

varying vec3 world_pos;
varying vec3 world_nrm;
varying float local_y;

void vertex() {
	local_y = VERTEX.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 sample_triplanar(sampler2D tex, vec3 pos, vec3 w, float scale) {
	return texture(tex, pos.zy * scale).rgb * w.x
		+ texture(tex, pos.xz * scale).rgb * w.y
		+ texture(tex, pos.xy * scale).rgb * w.z;
}

void fragment() {
	vec3 alb = texture(albedo_tex, UV).rgb;
	vec3 nrm_map = texture(normal_tex, UV).rgb;
	vec3 orm = texture(orm_tex, UV).rgb;

	vec3 nrm = normalize(world_nrm);
	vec3 w = pow(abs(nrm), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);

	// Optional world-space sandstone detail for huge 7-20m cliff scans so walking-height texel density stays razor sharp
	if (detail_blend > 0.001) {
		vec3 det_col = sample_triplanar(detail_strata_tex, world_pos, w, detail_scale);
		vec3 det_nrm = sample_triplanar(detail_strata_norm, world_pos, w, detail_scale);
		float det_luma = dot(det_col, vec3(0.299, 0.587, 0.114));
		alb *= mix(1.0, clamp(det_luma * 1.45 + 0.30, 0.65, 1.35), detail_blend);
		nrm_map = normalize(mix(nrm_map * 2.0 - 1.0, (nrm_map * 2.0 - 1.0) + (det_nrm * 2.0 - 1.0) * 0.55, detail_blend) * 0.5 + 0.5);
	}

	// Luminance-preserving desert palette harmonization
	float raw_luma = dot(alb, vec3(0.299, 0.587, 0.114));
	float luma = clamp(mix(luma_floor, 1.0, pow(clamp(raw_luma, 0.01, 1.0), luma_contrast)), 0.0, 1.0);
	float t_low = smoothstep(0.06, 0.44, luma);
	float t_high = smoothstep(0.40, 0.86, luma);
	vec3 ramp_col = mix(shadow_tint, mid_tint, t_low);
	ramp_col = mix(ramp_col, crown_tint, t_high);
	vec3 chroma = alb - vec3(raw_luma);
	vec3 harmonized = clamp(ramp_col + chroma * vec3(0.42, 0.28, 0.18), vec3(0.02), vec3(1.0));
	vec3 col = mix(alb, harmonized, grade_strength);

	// Sunlit top shelf / stone crown warmth vs shaded vertical stone sides
	float up_face = smoothstep(0.32, 0.84, nrm.y);
	col = mix(col * (1.0 - top_crown_boost * 0.35), col * (1.0 + top_crown_boost), up_face);

	// Multi-scale crevice cavity AO (orm.r) + convex ridge rim highlight (orm.b)
	float cav_ao = mix(1.0, orm.r, cavity_strength);
	float vtx_ao = mix(1.0, clamp(COLOR.g, 0.42, 1.0), basal_ao_strength);
	float ground_ao = mix(1.0 - basal_ao_strength, 1.0, smoothstep(0.0, max(basal_ao_height, 0.005), max(local_y, 0.0)));
	float total_ao = cav_ao * vtx_ao * ground_ao;

	col *= mix(0.42, 1.05, total_ao);
	col += col * (orm.b * ridge_highlight);

	// Cool violet-umber shadow fill on faces turned away from the backlit sun
	float shade_face = clamp(1.0 - max(nrm.y, 0.0) * 0.7 - max(-nrm.z, 0.0) * 0.4, 0.0, 1.0);
	col = mix(col, col * vec3(0.90, 0.84, 0.96), shade_face * 0.18);

	float cam_dist = length(CAMERA_POSITION_WORLD - world_pos);
	float haze_t = smoothstep(16.0, 46.0, cam_dist) * haze_strength;

	ALBEDO = mix(col, haze_color, haze_t);
	NORMAL_MAP = nrm_map;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = clamp(orm.g, 0.25, 0.98);
	SPECULAR = 0.22 * (1.0 - orm.g * 0.5);
	AO = total_ao;
	AO_LIGHT_AFFECT = 0.68;
}
