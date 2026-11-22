// Sharp-pixel anti-aliased ground shader for 3D Kit Canyon v2.
// Samples cobble (img1), verge sand (art_gemini) and dune sand (art_gemini) once each at exact
// 64 texels/m using derivative-clamped texel-edge AA + hardware anisotropic mipmaps.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D cobble_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_norm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 cobble_tile_m = vec2(2.5, 2.5);

uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_norm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 sand_tile_m = vec2(3.125, 2.6875);

uniform sampler2D dune_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dune_norm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 dune_tile_m = vec2(1.5625, 1.4375);

uniform vec3 player_pos = vec3(0.0, 0.0, 6.0);
uniform float cobble_verge_wear : hint_range(0.0, 1.0) = 0.85;

// Route centre lookup written by canyon_route_path.gd
uniform float route_amplitude = 0.65;
uniform float route_frequency = 0.22;
uniform float route_phase = 0.0;
uniform int route_mode = 0;
uniform float route_lookup[64];
uniform float route_lookup_z0 = 0.0;
uniform float route_lookup_dz = 1.0;

uniform vec2 cliff_ao_range = vec2(2.5, 3.6);
uniform float curb_dust = 0.24;
uniform vec2 curb_dust_range = vec2(1.56, 2.15);
uniform vec3 shade_fill : source_color = vec3(0.34, 0.22, 0.42);
uniform float shade_strength = 0.36;

varying vec3 world_pos;

float route_center(float z) {
	if (route_mode == 0) {
		return sin(z * route_frequency + route_phase) * route_amplitude;
	}
	float f = clamp((z - route_lookup_z0) / route_lookup_dz, 0.0, 63.0);
	int i = int(floor(f));
	int j = min(i + 1, 63);
	return mix(route_lookup[i], route_lookup[j], f - float(i));
}

vec2 pixel_aa_uv(vec2 uv, vec2 tex_size) {
	vec2 p = uv * tex_size;
	vec2 fw = max(fwidth(p), vec2(0.0001));
	vec2 seam = floor(p + 0.5);
	vec2 delta = (p - seam) / fw;
	vec2 snapped = seam + clamp(delta, vec2(-0.5), vec2(0.5));
	// Smoothly hand off to anisotropic mipmaps when minification exceeds 1 texel per pixel.
	vec2 blend_t = smoothstep(vec2(0.8), vec2(1.5), fw);
	return mix(snapped, p, blend_t) / tex_size;
}

vec4 sample_pixel_aa(sampler2D tex, vec2 uv) {
	vec2 ts = vec2(textureSize(tex, 0));
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	return textureGrad(tex, pixel_aa_uv(uv, ts), dx, dy);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float path_cx = route_center(world_pos.z);

	vec2 cobble_uv = world_pos.xz / cobble_tile_m;
	vec3 c_col = sample_pixel_aa(cobble_tex, cobble_uv).rgb;
	vec3 c_norm = sample_pixel_aa(cobble_norm, cobble_uv).rgb;
	vec3 c_orm = sample_pixel_aa(cobble_orm, cobble_uv).rgb;

	float cav_ao = c_orm.r;
	c_col *= mix(0.45, 1.05, cav_ao);
	c_col *= 1.0 + c_orm.b * 0.05;

	vec2 sand_uv = world_pos.xz / sand_tile_m;
	vec3 s_col = sample_pixel_aa(sand_tex, sand_uv).rgb;
	vec3 s_norm = sample_pixel_aa(sand_norm, sand_uv).rgb;

	vec2 dune_uv = world_pos.xz / dune_tile_m;
	vec3 d_col = sample_pixel_aa(dune_tex, dune_uv).rgb;
	vec3 d_norm = sample_pixel_aa(dune_norm, dune_uv).rgb;

	// Stone-shaped edge mask so cobbles tuck cleanly under the 3D curbs (centered at 1.38 m)
	float stone_edge = (cav_ao - 0.68) * 0.22 + sin(world_pos.z * 2.1 + c_col.r * 1.4) * 0.05;
	float dist = abs(world_pos.x - path_cx) + stone_edge;
	float path_mask = 1.0 - smoothstep(1.16, 1.36, dist);

	float dune_t = smoothstep(-12.6, -16.8, world_pos.z);
	// Taper road into exit dunes along stone edges rather than uniform grey fade
	float exit_cut = smoothstep(-12.2, -15.4, world_pos.z) + (0.65 - cav_ao) * 0.35;
	float trail_keep = path_mask * (1.0 - smoothstep(0.35, 0.85, exit_cut));
	if (cobble_verge_wear > 0.0) {
		float edge = smoothstep(0.95, 1.34, abs(world_pos.x - path_cx));
		float pockets = 0.56 * sin(world_pos.z * 1.71 + sin(world_pos.x * 2.9 + world_pos.z * 0.37))
			+ 0.29 * sin(world_pos.z * 4.45 - world_pos.x * 5.2);
		float sand_wear = cobble_verge_wear * edge * smoothstep(-0.05, 0.72, pockets);
		trail_keep *= 1.0 - sand_wear;
	}

	vec3 canyon_ground = mix(s_col * 0.92, c_col, trail_keep);
	vec3 base_col = mix(canyon_ground, d_col * 0.98, dune_t);

	// Soft cliff-foot ambient darkening & curb-side dust strip
	float cliff_ao = smoothstep(cliff_ao_range.x, cliff_ao_range.y, abs(world_pos.x - path_cx)) * (1.0 - dune_t) * 0.42;
	base_col *= (1.0 - cliff_ao);
	float curb_d = abs(world_pos.x - path_cx);
	base_col *= 1.0 - curb_dust * smoothstep(curb_dust_range.y, curb_dust_range.x, curb_d)
		* smoothstep(curb_dust_range.x - 0.14, curb_dust_range.x, curb_d) * (1.0 - dune_t);

	// Grounded contact shadow under Blue Commander
	vec2 p_delta = world_pos.xz - player_pos.xz;
	p_delta.x *= 1.15;
	p_delta.y *= 1.55;
	float hero_shadow = (1.0 - smoothstep(0.16, 0.52, length(p_delta))) * 0.42;
	base_col *= (1.0 - hero_shadow);

	float horizon_mist = smoothstep(-32.0, -64.0, world_pos.z);
	base_col = mix(base_col, vec3(0.91, 0.72, 0.48), horizon_mist * 0.65);

	vec3 canyon_norm = mix(s_norm, c_norm, trail_keep);
	ALBEDO = base_col;
	NORMAL_MAP = mix(canyon_norm, d_norm, dune_t);
	NORMAL_MAP_DEPTH = mix(1.20, 1.85, trail_keep);
	ROUGHNESS = mix(mix(0.90, c_orm.g, trail_keep), 0.94, dune_t);
	SPECULAR = mix(mix(0.12, 0.35 * (1.0 - c_orm.g) + 0.12, trail_keep), 0.10, dune_t);
	AO = mix(1.0, cav_ao, trail_keep * (1.0 - dune_t));
	AO_LIGHT_AFFECT = 0.70;
}

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += shade_fill * shade_strength * (1.0 - lit) * length(LIGHT_COLOR) / PI;
	}
}
