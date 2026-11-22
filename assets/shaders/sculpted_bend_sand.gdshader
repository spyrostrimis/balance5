shader_type spatial;
render_mode specular_disabled;

uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 ground_colour : source_color = vec4(0.68, 0.47, 0.311, 1.0);
uniform vec4 grain_colour : source_color = vec4(0.43, 0.27, 0.19, 1.0);
uniform vec3 player_pos;
uniform int route_mode;
uniform float route_lookup[64];
uniform float route_lookup_z0;
uniform float route_lookup_dz = 1.0;

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float mottling(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), f.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float broad = mottling(p * 0.63);
	float grain = mottling(p * 18.0);
	float dust = mottling(p * 3.1);
	float t = clamp((p.y - route_lookup_z0) / route_lookup_dz, 0.0, 62.999);
	int i = int(t);
	float centre = mix(route_lookup[i], route_lookup[i + 1], fract(t));
	float widen = smoothstep(0.0, 4.5, -p.y - 13.8) * 0.5;
	float joints = (1.0 - smoothstep(1.28 + widen, 1.60 + widen, abs(p.x - centre) + (dust - 0.5) * 0.2));
	joints *= float(route_mode) * smoothstep(-19.5, -18.0, p.y);
	float stipple = smoothstep(0.68, 0.90, grain) * smoothstep(0.3, 0.55, dust);
	ALBEDO = mix(ground_colour.rgb, grain_colour.rgb, clamp(0.22 * broad + 0.12 * dust
		+ 0.21 * stipple + 0.48 * joints, 0.0, 1.0));
	float contact = 1.0 - smoothstep(0.07, 0.42, length((p - player_pos.xz) * vec2(1.0, 1.6)));
	vec3 sand = texture(sand_albedo, p * 0.72).rgb;
	ALBEDO *= (0.70 + sand.r * 0.80) * (1.0 - contact * 0.45);
	ROUGHNESS = 1.0;
}
