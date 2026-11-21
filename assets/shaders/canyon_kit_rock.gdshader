// Pixel-textured rock for the 3D kit canyon (cliff blocks, cliff core, curbs).
// - Nearest filtering keeps the texels square (64 per metre).
// - Shade is cool and purple, like the 2D canyon paintings: where the sun does not reach (facing away or in
//   shadow) a violet fill replaces the flat grey ambient.
// - base_ao darkens the lower part of each block (its local height), so rows read as separate stones with
//   crevices between them. Set block_height 0 for meshes that are not single blocks.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform float normal_depth = 0.6;
uniform float brightness = 0.74;
uniform vec3 shade_fill : source_color = vec3(0.34, 0.22, 0.42);
uniform float shade_strength = 0.8;
instance uniform float block_height = 0.0;
uniform float base_ao = 0.45;
uniform float roughness = 0.93;

varying float local_h;

void vertex() {
	local_h = block_height > 0.0 ? clamp(VERTEX.y / block_height, 0.0, 1.0) : 1.0;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * brightness;
	ALBEDO = c;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = roughness;
	AO = mix(1.0 - base_ao, 1.0, smoothstep(0.0, 0.55, local_h));
	AO_LIGHT_AFFECT = 0.35;
}

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += shade_fill * shade_strength * (1.0 - lit) * length(LIGHT_COLOR) / PI;
	}
}
