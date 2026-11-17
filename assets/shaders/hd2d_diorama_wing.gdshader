shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D wing_tex : source_color, filter_linear_mipmap;
uniform vec3 albedo_tint = vec3(1.0, 1.0, 1.0);
uniform float alpha_clip : hint_range(0.0, 0.5) = 0.08;
uniform vec3 haze_color : source_color = vec3(0.95, 0.78, 0.52);
uniform float haze_strength : hint_range(0.0, 1.0) = 0.22;
uniform float fade_start = 15.0;
uniform float fade_end = 42.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 tex = texture(wing_tex, UV);
	float cam_dist = length(CAMERA_POSITION_WORLD - world_pos);
	float haze_t = smoothstep(fade_start, fade_end, cam_dist) * haze_strength;

	float ground_noise = sin(world_pos.z * 2.6 + world_pos.x * 1.9) * 0.08 + (tex.g - 0.5) * 0.18;
	float ground_fade = smoothstep(0.02, 0.48, world_pos.y + ground_noise);
	float near_cam_fade = smoothstep(3.0, 6.8, cam_dist);

	float final_alpha = tex.a * ground_fade * near_cam_fade;
	if (final_alpha < alpha_clip) {
		discard;
	}

	float base_ao = 1.0 - smoothstep(0.0, 0.55, world_pos.y + ground_noise);
	vec3 col = mix(tex.rgb * albedo_tint, vec3(0.58, 0.40, 0.25), base_ao * 0.45);
	ALBEDO = mix(col, haze_color, haze_t);
	ALPHA = final_alpha;
}
