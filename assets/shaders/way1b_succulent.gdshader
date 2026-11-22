shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;

uniform float grade_strength : hint_range(0.0, 1.0) = 0.75;
uniform vec3 leaf_deep_tint : source_color = vec3(0.24, 0.30, 0.16);
uniform vec3 leaf_mid_tint : source_color = vec3(0.46, 0.54, 0.30);
uniform vec3 sun_tip_tint : source_color = vec3(0.84, 0.78, 0.44);
uniform float wind_sway : hint_range(0.0, 0.03) = 0.008;

varying vec3 world_pos;
varying float local_h;

void vertex() {
	local_h = max(VERTEX.y, 0.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.85 + world_pos.z * 2.2 + world_pos.x * 1.7) * wind_sway * smoothstep(0.05, 0.28, local_h);
	VERTEX.x += sway;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.42;

	vec3 nrm_map = texture(normal_tex, UV).rgb;
	vec3 orm = texture(orm_tex, UV).rgb;

	// Distinguish fleshy green/grey succulent leaves from pink-gold flower petals
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float flower_mask = smoothstep(0.03, 0.16, (tex.r - tex.g) + (tex.b - tex.g) * 0.5);
	float tip_t = smoothstep(0.04, 0.22, local_h);

	vec3 olive_leaf = mix(leaf_deep_tint, leaf_mid_tint, smoothstep(0.18, 0.62, luma));
	olive_leaf = mix(olive_leaf, sun_tip_tint, tip_t * 0.48 * smoothstep(0.35, 0.75, luma));
	vec3 flower_col = tex.rgb * vec3(1.06, 0.96, 0.82);

	vec3 target_col = mix(olive_leaf, flower_col, flower_mask);
	vec3 col = mix(tex.rgb, target_col, grade_strength);

	// Ground root occlusion + cavity AO
	float root_ao = smoothstep(-0.01, 0.13, local_h);
	float cav_ao = mix(0.38, 1.06, orm.r) * mix(0.42, 1.0, root_ao);
	col *= cav_ao;

	ALBEDO = col;
	NORMAL_MAP = nrm_map;
	NORMAL_MAP_DEPTH = 1.25;
	ROUGHNESS = clamp(orm.g, 0.38, 0.92);
	BACKLIGHT = vec3(0.36, 0.38, 0.16) * (0.35 + 0.65 * orm.b);
	AO = cav_ao;
	AO_LIGHT_AFFECT = 0.65;
}
