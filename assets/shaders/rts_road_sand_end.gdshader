shader_type canvas_item;

uniform vec2 end_point;
uniform vec2 end_direction = vec2(1.0, 0.0);
uniform float fade_length = 68.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 grit_pixel = floor(local_pos * 0.7);
	float grain = fract(sin(dot(grit_pixel, vec2(35.13, 72.81))) * 43758.55);
	float remaining = dot(end_point - local_pos, end_direction);
	float stone = texture(TEXTURE, UV).r;
	float fade = smoothstep(0.04, 0.98, remaining / fade_length
		+ (grain - 0.5) * 0.29 + (stone - 0.64) * 0.5);
	COLOR.a *= fade;
}
