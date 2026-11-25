shader_type canvas_item;

uniform sampler2D sand_tex : source_color, repeat_enable;
uniform sampler2D calm_mask_tex : filter_linear;
uniform sampler2D tread_tex : filter_linear;
uniform vec2 world_size = vec2(1408.0, 896.0);
uniform bool pixel_mode = false;
uniform bool show_treads = true;
uniform bool painted_sand = false;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec3 eval_desert_sand(vec2 wpos, float calm) {
	vec2 sample_pos = pixel_mode ? (floor(wpos) + vec2(0.5)) : wpos;
	vec3 base = texture(sand_tex, sample_pos / 256.0).rgb;

	// Wind-aligned broad swells (SW to NE, calm near roads & infantry lanes)
	vec2 wind_uv = vec2(
		sample_pos.x * 0.94 + sample_pos.y * 0.34,
		-sample_pos.x * 0.34 + sample_pos.y * 0.94
	);
	if (painted_sand) {
		float swell = sin(wind_uv.y * 0.027 + sin(wind_uv.x * 0.011) * 0.72);
		float drift = sin(dot(sample_pos, vec2(0.005, -0.008)));
		return base * (1.0 + (swell * 0.037 + drift * 0.016) * mix(1.0, 0.3, calm));
	}
	float swell = value_noise(wind_uv / vec2(190.0, 78.0)) - 0.5;
	float drift = value_noise(sample_pos / 320.0) - 0.5;
	float open_factor = mix(1.0, 0.25, calm);
	float relief = swell * 0.16 * open_factor;
	if (pixel_mode) {
		relief = round(relief * 18.0) / 18.0;
		drift = round(drift * 10.0) / 10.0;
	}

	vec3 warm_shift = vec3(1.0 + drift * 0.08, 1.0 + drift * 0.03, 1.0 - drift * 0.10);
	vec3 col = base * warm_shift * (1.0 + relief);
	return clamp(col, vec3(0.0), vec3(1.0));
}

void fragment() {
	vec2 wpos = UV * world_size;
	vec2 uv_clamped = clamp(UV, vec2(0.001), vec2(0.999));
	float calm = texture(calm_mask_tex, uv_clamped).r;
	vec3 col = eval_desert_sand(wpos, calm);

	if (show_treads) {
		vec2 tuv = pixel_mode ? ((floor(wpos) + vec2(0.5)) / world_size) : uv_clamped;
		float tread = texture(tread_tex, tuv).r;
		if (pixel_mode) {
			tread = step(0.26, tread) * 0.78;
		}
		col = mix(col, col * vec3(0.70, 0.62, 0.52), tread * 0.55);
	}

	COLOR = vec4(col, 1.0);
}
