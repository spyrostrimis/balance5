// GENERATED from assets/shaders/hd2d_chatgpt_boulder.gdshader by tools/python/make_pixel_shader_variants.py.
// Source filtering and uniform repeat scales for high-resolution authored textures. Edit the source, then regenerate.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float tile_metres : hint_range(0.4, 6.0) = 1.65;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.35;
uniform float crown_ochre_lift : hint_range(0.0, 1.0) = 0.45;
uniform float desaturate_amount : hint_range(0.0, 1.0) = 0.28;
uniform vec3 albedo_tint : source_color = vec3(0.88, 0.84, 0.80);
uniform vec3 haze_color : source_color = vec3(0.95, 0.78, 0.52);
uniform float haze_strength : hint_range(0.0, 1.0) = 0.24;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 unpack_tan_normal(sampler2D tex, vec2 uv) {
	vec3 n = texture(tex, uv).xyz * 2.0 - 1.0;
	n.xy *= normal_strength;
	return normalize(n);
}

void fragment() {
	vec3 nrm = normalize(world_nrm);
	vec3 w = pow(abs(nrm), vec3(5.0));
	w /= (w.x + w.y + w.z + 0.0001);

	float inv_scale = 1.0 / tile_metres;
	// Keep image UP (+V_up = -v) aligned with Godot world +Y on both vertical projection planes
	vec2 uv_x = vec2(world_pos.z, -world_pos.y) * inv_scale;
	vec2 uv_y = vec2(world_pos.x, world_pos.z) * inv_scale;
	vec2 uv_z = vec2(world_pos.x, -world_pos.y) * inv_scale;

	vec3 alb = texture(albedo_tex, uv_x).rgb * w.x
		+ texture(albedo_tex, uv_y).rgb * w.y
		+ texture(albedo_tex, uv_z).rgb * w.z;

	vec3 orm = texture(orm_tex, uv_x).rgb * w.x
		+ texture(orm_tex, uv_y).rgb * w.y
		+ texture(orm_tex, uv_z).rgb * w.z;

	// UDN triplanar world-space normal perturbation (consistent slope directions on all 6 faces)
	vec3 tnx = unpack_tan_normal(normal_tex, uv_x);
	vec3 tny = unpack_tan_normal(normal_tex, uv_y);
	vec3 tnz = unpack_tan_normal(normal_tex, uv_z);

	vec3 world_nx = vec3(nrm.x, nrm.y + tnx.y, nrm.z + tnx.x);
	vec3 world_ny = vec3(nrm.x + tny.x, nrm.y, nrm.z - tny.y);
	vec3 world_nz = vec3(nrm.x + tnz.x, nrm.y + tnz.y, nrm.z);
	vec3 perturbed_world_nrm = normalize(world_nx * w.x + world_ny * w.y + world_nz * w.z);

	// Match Balance5 dusty desert palette + warm sunlit ochre crown lift + deep cavity AO in cracks
	float luma = dot(alb, vec3(0.299, 0.587, 0.114));
	vec3 balanced = mix(alb, vec3(luma), desaturate_amount) * albedo_tint;
	float crown_t = smoothstep(0.28, 0.82, nrm.y) * crown_ochre_lift;
	vec3 graded = mix(balanced, balanced * vec3(1.14, 1.22, 1.06), crown_t);
	float cav_ao = orm.r;
	float base_ao = clamp(COLOR.g, 0.50, 1.0);
	graded *= mix(0.44, 1.06, cav_ao) * base_ao;
	graded *= 1.0 + orm.b * 0.06;

	float cam_dist = length(CAMERA_POSITION_WORLD - world_pos);
	float haze_t = smoothstep(16.0, 44.0, cam_dist) * haze_strength;

	ALBEDO = mix(graded, haze_color, haze_t);
	NORMAL = normalize((VIEW_MATRIX * vec4(perturbed_world_nrm, 0.0)).xyz);
	ROUGHNESS = orm.g;
	AO = mix(0.45, 1.0, cav_ao * base_ao);
}
