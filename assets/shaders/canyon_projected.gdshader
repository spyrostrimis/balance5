shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D detail_path_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 player_pos = vec3(-0.3, 0.0, 2.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb;

	// Zero-mean high-frequency detail transfer for the far canyon as the player walks forward:
	// At start (player_pos.z = 2.0), walk_progress = 0.0 -> 100% untouched img1!
	// As player approaches exit (player_pos.z -> -9.5), walk_progress -> 1.0 -> brings far rocks & cobbles into sharp focus!
	float walk_progress = clamp((2.0 - player_pos.z) / 11.5, 0.0, 1.0);
	float far_region = clamp((1.5 - world_pos.z) / 7.5, 0.0, 1.0);
	float detail_weight = walk_progress * far_region;

	if (detail_weight > 0.001) {
		float floor_mask = clamp(1.0 - world_pos.y * 8.0, 0.0, 1.0);

		// Floor high-frequency cobblestone detail (zero-mean: sharp minus blurred)
		vec2 path_uv = world_pos.xz * vec2(0.75, 0.75);
		vec3 path_sharp = textureLod(detail_path_tex, path_uv, 0.0).rgb;
		vec3 path_blur = textureLod(detail_path_tex, path_uv, 3.5).rgb;
		vec3 path_hf = (path_sharp - path_blur) * 0.55;

		// Cliff wall high-frequency stratified sandstone detail (zero-mean)
		vec2 rock_uv = vec2(world_pos.z * 0.28 + world_pos.x * 0.15, world_pos.y * 0.38);
		vec3 rock_sharp = textureLod(detail_rock_tex, rock_uv, 0.0).rgb;
		vec3 rock_blur = textureLod(detail_rock_tex, rock_uv, 3.5).rgb;
		vec3 rock_hf = (rock_sharp - rock_blur) * 0.50;

		col += mix(rock_hf, path_hf, floor_mask) * detail_weight;
	}

	// Soft elliptical contact shadow directly under Blue Commander's feet
	vec2 d_xz = world_pos.xz - (player_pos.xz + vec2(-0.06, 0.0));
	float sh = exp(-(d_xz.x * d_xz.x / 0.09 + d_xz.y * d_xz.y / 0.035));
	col *= mix(1.0, 0.35, sh * clamp(1.0 - world_pos.y * 8.0, 0.0, 1.0));

	// Subtle cyan gauntlet point light glow on nearby ground & cliffs
	float g_dist = length(world_pos - (player_pos + vec3(0.18, 0.65, 0.08)));
	col += vec3(0.05, 0.45, 0.42) * exp(-g_dist * g_dist * 2.2) * 0.22;

	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
}
