// Sharp-pixel anti-aliased unshaded cutout shader for Blue Commander and Orichalcum Crater in v2.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D sprite_tex : source_color, filter_linear, repeat_disable;
uniform float brightness = 1.0;
uniform float pitch_tilt_deg = 0.0;

void vertex() {
	if (abs(pitch_tilt_deg) > 0.001) {
		float a = radians(pitch_tilt_deg);
		float c = cos(a);
		float s = sin(a);
		float py = VERTEX.y + 0.640625;
		VERTEX.y = py * c - 0.640625;
		VERTEX.z -= py * s;
	}
}

vec2 pixel_aa_uv_clamped(vec2 uv, vec2 tex_size) {
	vec2 p = uv * tex_size;
	vec2 fw = max(fwidth(p), vec2(0.0001));
	vec2 seam = floor(p + 0.5);
	vec2 delta = (p - seam) / fw;
	vec2 snapped = seam + clamp(delta, vec2(-0.5), vec2(0.5));
	vec2 safe = clamp(snapped, vec2(0.5), tex_size - vec2(0.5));
	return safe / tex_size;
}

void fragment() {
	vec2 ts = vec2(textureSize(sprite_tex, 0));
	vec4 c = texture(sprite_tex, pixel_aa_uv_clamped(UV, ts));
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.35;
	ALBEDO = c.rgb * brightness;
}
