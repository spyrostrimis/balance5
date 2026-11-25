shader_type canvas_item;
render_mode unshaded;

uniform sampler2D earth_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D terrain : filter_linear, repeat_disable;
uniform vec2 map_size;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 t = f * f * (3.0 - 2.0 * f);
	return mix(mix(grain(i), grain(i + vec2(1.0, 0.0)), t.x),
		mix(grain(i + vec2(0.0, 1.0)), grain(i + vec2(1.0, 1.0)), t.x), t.y);
}

void fragment() {
	vec2 cell = UV * map_size;
	vec2 sample_uv = cell * 0.185 + vec2(0.08, 0.26);
	vec3 earth = texture(earth_tex, sample_uv).rgb;
	vec3 forest = texture(forest_tex, sample_uv * 0.89).rgb;
	vec2 ground = texture(terrain, UV).rg;
	float edge = 0.31 * (noise(cell * 2.0) - 0.5) + 0.18 * (noise(cell * 4.8) - 0.5);
	float blend = smoothstep(0.19, 0.79, ground.r + edge);
	float broad_light = mix(0.79, 1.14, noise(cell * 0.28));
	vec3 shaded = mix(forest * vec3(0.77, 0.88, 0.95), earth * vec3(1.12, 1.04, 0.90), blend);
	shaded *= broad_light;
	shaded = mix(shaded, forest * vec3(0.91, 0.96, 0.81), ground.g * 0.76);
	COLOR = vec4(shaded, 1.0);
}
