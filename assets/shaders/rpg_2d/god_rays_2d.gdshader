shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 ray_color : source_color = vec4(1.0, 0.85, 0.56, 1.0);
uniform float intensity : hint_range(0.0, 0.8) = 0.22;
uniform float angle_slope : hint_range(0.4, 2.0) = 1.12;
uniform float speed : hint_range(0.0, 2.0) = 0.28;
uniform float pixel_steps : hint_range(32.0, 960.0) = 320.0;

void fragment() {
	// Snap UV gently to pixel bands so diagonal beams sit naturally in 960x540 / 640x360 pixel art
	vec2 q_uv = floor(UV * vec2(pixel_steps, pixel_steps * 0.5625)) / vec2(pixel_steps, pixel_steps * 0.5625);
	// Diagonal projection from upper-right corner
	float diag = q_uv.x + q_uv.y * angle_slope;
	float t = TIME * speed;

	float beam1 = pow(max(0.0, sin((diag - 0.62) * 14.0 + sin(t) * 0.35)), 4.0);
	float beam2 = pow(max(0.0, sin((diag - 0.88) * 21.0 - cos(t * 0.7) * 0.25)), 5.0) * 0.75;
	float beam3 = pow(max(0.0, sin((diag - 1.12) * 11.0 + sin(t * 0.5) * 0.4)), 4.0) * 0.85;

	// Concentrate beams in upper-right -> center-mid canyon corridor
	float region_mask = smoothstep(0.18, 0.72, q_uv.x) * (1.0 - smoothstep(0.52, 0.96, q_uv.y));
	float sun_falloff = smoothstep(1.35, 0.15, length(vec2(1.05, -0.05) - q_uv));

	// Discrete alpha quantization for crisp pixel-art light steps
	float raw_alpha = (beam1 + beam2 + beam3) * region_mask * sun_falloff;
	float stepped = floor(raw_alpha * 6.0 + 0.5) / 6.0;
	COLOR = vec4(ray_color.rgb, clamp(stepped * intensity, 0.0, 0.65));
}
