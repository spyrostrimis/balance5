shader_type canvas_item;

uniform vec2 end_point = vec2(944.0, 808.0);
uniform vec2 end_direction = vec2(0.10, 0.995);
uniform float fade_length = 82.0;
uniform vec3 sand_tint : source_color = vec3(0.894, 0.529, 0.157);

varying vec2 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 dir = normalize(end_direction);
	vec2 fade_start = end_point - dir * fade_length;
	float along = dot(v_world_pos - fade_start, dir) / max(fade_length, 1.0);
	float t = clamp(along, 0.0, 1.15);

	// Let brighter stone centers survive slightly longer than cracks so stones break up into sand
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float stone_keep = clamp((lum - 0.45) * 0.65, -0.14, 0.16);
	float fade_alpha = 1.0 - smoothstep(0.18 + stone_keep, 0.98 + stone_keep * 0.5, t);
	float sand_mix = smoothstep(0.08, 0.88, t) * 0.62;

	vec3 rgb = mix(tex.rgb, sand_tint, sand_mix);
	COLOR = vec4(rgb, tex.a * fade_alpha);
}
