shader_type canvas_item;
render_mode unshaded;

uniform bool veil = false;

void fragment() {
	float sky = smoothstep(0.02, 0.85, UV.y);
	float mist = 0.5 + 0.5 * sin(7.0 * UV.x + 8.0 * UV.y);
	vec3 deep = vec3(0.055, 0.144, 0.177);
	vec3 haze = vec3(0.23, 0.43, 0.48);
	COLOR = vec4(mix(deep, haze, sky * (0.79 + 0.18 * mist)), 1.0);
	if (veil) {
		float bank = smoothstep(0.11, 0.70, UV.y) * (0.25 + 0.20 * mist);
		COLOR = vec4(vec3(0.27, 0.47, 0.52), bank);
	}
}
