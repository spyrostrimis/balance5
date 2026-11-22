// Sharp-pixel anti-aliased rock/cliff/curb/boulder shader for 3D Kit Canyon v2.
// Supports exact UV sampling (1 UV unit = tile_m) and hard dominant-axis world mapping (for distant mesas).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float normal_depth = 0.7;
uniform float brightness = 0.78;
uniform vec3 shade_fill : source_color = vec3(0.34, 0.22, 0.42);
uniform float shade_strength = 0.78;
instance uniform float block_height = 0.0;
uniform float base_ao = 0.35;
uniform float roughness = 0.92;
uniform vec3 haze_color : source_color = vec3(0.95, 0.78, 0.52);
uniform float haze_strength : hint_range(0.0, 1.0) = 0.08;

// Optional hard dominant-axis world mapping (used for distant Craftpix mesas at exact 64 texels/m)
uniform bool use_world_triplanar = false;
uniform vec2 world_tile_m = vec2(2.9375, 1.390625);
uniform sampler2D top_albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 top_tile_m = vec2(2.0, 2.0);

varying float local_h;
varying vec3 world_pos;
varying vec3 world_nrm;

vec2 pixel_aa_uv(vec2 uv, vec2 tex_size) {
	vec2 p = uv * tex_size;
	vec2 fw = max(fwidth(p), vec2(0.0001));
	vec2 seam = floor(p + 0.5);
	vec2 delta = (p - seam) / fw;
	vec2 snapped = seam + clamp(delta, vec2(-0.5), vec2(0.5));
	vec2 blend_t = smoothstep(vec2(0.8), vec2(1.5), fw);
	return mix(snapped, p, blend_t) / tex_size;
}

vec4 sample_pixel_aa(sampler2D tex, vec2 uv) {
	vec2 ts = vec2(textureSize(tex, 0));
	return textureGrad(tex, pixel_aa_uv(uv, ts), dFdx(uv), dFdy(uv));
}

void vertex() {
	local_h = block_height > 0.0 ? clamp(VERTEX.y / block_height, 0.0, 1.0) : 1.0;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col;
	vec3 nrm_sample;
	vec3 orm = vec3(1.0, roughness, 0.0);

	if (use_world_triplanar) {
		vec3 an = abs(normalize(world_nrm));
		if (an.y >= an.x && an.y >= an.z && an.y > 0.55) {
			vec2 uv_top = world_pos.xz / top_tile_m;
			col = sample_pixel_aa(top_albedo_tex, uv_top).rgb;
			nrm_sample = sample_pixel_aa(top_normal_tex, uv_top).rgb;
		} else if (an.x >= an.z) {
			vec2 uv_x = vec2(-world_pos.z / world_tile_m.x, -world_pos.y / world_tile_m.y);
			col = sample_pixel_aa(albedo_tex, uv_x).rgb;
			nrm_sample = sample_pixel_aa(normal_tex, uv_x).rgb;
		} else {
			vec2 uv_z = vec2(world_pos.x / world_tile_m.x, -world_pos.y / world_tile_m.y);
			col = sample_pixel_aa(albedo_tex, uv_z).rgb;
			nrm_sample = sample_pixel_aa(normal_tex, uv_z).rgb;
		}
	} else {
		col = sample_pixel_aa(albedo_tex, UV).rgb;
		nrm_sample = sample_pixel_aa(normal_tex, UV).rgb;
		orm = sample_pixel_aa(orm_tex, UV).rgb;
	}

	col *= brightness * mix(0.55, 1.04, orm.r);
	float cam_dist = length(CAMERA_POSITION_WORLD - world_pos);
	float haze_t = smoothstep(20.0, 56.0, cam_dist) * haze_strength;

	ALBEDO = mix(col, haze_color, haze_t);
	NORMAL_MAP = nrm_sample;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = mix(roughness, orm.g, 0.5);
	AO = mix(1.0 - base_ao, 1.0, smoothstep(0.0, 0.45, local_h)) * mix(0.65, 1.0, orm.r);
	AO_LIGHT_AFFECT = 0.35;
}

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += shade_fill * shade_strength * (1.0 - lit) * length(LIGHT_COLOR) / PI;
	}
}
