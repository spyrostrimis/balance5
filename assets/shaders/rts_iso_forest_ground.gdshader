shader_type canvas_item;
// Seamless isometric splat terrain, organic moss-to-ochre tuft transitions,
// dappled leaf-cluster canopy shade, live dual tank tracks, and Fight-4 valley mist abyss.

uniform sampler2D ochre_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D splat_tex : filter_linear, repeat_disable;
uniform sampler2D tread_tex : filter_linear, repeat_disable;

uniform vec2 iso_rect_pos = vec2(-1320.0, -380.0);
uniform vec2 iso_rect_size = vec2(2640.0, 1780.0);
uniform vec2 map_size = vec2(1152.0, 1152.0);
uniform bool show_treads = true;

vec2 iso_to_map(vec2 iso_p) {
	return vec2(
		0.70710678 * iso_p.x + 1.22474487 * iso_p.y,
		-0.70710678 * iso_p.x + 1.22474487 * iso_p.y
	);
}

void fragment() {
	vec2 iso_pos = iso_rect_pos + UV * iso_rect_size;
	vec2 map_pos = iso_to_map(iso_pos);
	vec2 map_uv = map_pos / map_size;

	// Upper-left, North, and Upper-right extend infinitely as lush woodland hillside (like forest.png!);
	// ONLY the foreground South-West (map_uv.y > shelf) and South-East (map_uv.x > shelf) drop into valley mist!
	vec2 clamped_uv = clamp(map_uv, vec2(0.003), vec2(0.997));
	vec4 splat = texture(splat_tex, clamped_uv);
	float south_dropoff = (1.0 - smoothstep(0.96, 1.02, map_uv.x)) * (1.0 - smoothstep(0.96, 1.02, map_uv.y));
	float shelf_raw = splat.r * south_dropoff;

	// Dual-scale seamless sampling in isometric screen space so painted strokes match forest.png
	vec2 uv_a = iso_pos / 310.0;
	vec2 uv_b = vec2(iso_pos.x * 0.41 - iso_pos.y * 0.28, iso_pos.x * 0.28 + iso_pos.y * 0.41) / 260.0 + vec2(0.37, 0.61);

	vec3 ochre_a = texture(ochre_tex, uv_a).rgb;
	vec3 ochre_b = texture(ochre_tex, uv_b).rgb;
	vec3 ochre = mix(ochre_a, ochre_b, 0.36);

	vec3 moss_a = texture(moss_tex, uv_a * 1.08).rgb;
	vec3 moss_b = texture(moss_tex, uv_b * 1.05).rgb;
	vec3 moss = mix(moss_a, moss_b, 0.38);

	vec3 det_a = texture(detail_tex, uv_a * 1.25).rgb;
	vec3 det_b = texture(detail_tex, uv_b * 0.85).rgb;
	float tuft_height = mix(det_a.r, det_b.r, 0.42);
	float leaf_dapple = mix(det_a.g, det_b.g, 0.45);

	// Beyond upper-left/north/upper-right map border, fade smoothly into deep shaded woodland canopy turf
	float outer_north_wood = clamp(max(-map_uv.x, -map_uv.y) * 3.5, 0.0, 1.0);
	float ochre_w = splat.g * (1.0 - outer_north_wood);
	float is_ochre = clamp(smoothstep(0.22, 0.78, ochre_w + (0.5 - tuft_height) * 0.34), 0.0, 1.0);

	// Warm yellow-green sunlit verge highlight right where moss meets warm ochre earth (forest.png signature!)
	float verge_band = sin(is_ochre * 3.14159265);
	vec3 sunlit_verge_moss = moss * vec3(1.16, 1.18, 0.88);
	vec3 ground_rgb = mix(moss, sunlit_verge_moss, verge_band * 0.52);
	ground_rgb = mix(ground_rgb, ochre, is_ochre);

	// Subtle large-scale upper-left warm sunlight drift across the clearing
	float sun_grad = clamp(1.0 - (iso_pos.x * 0.00010 + iso_pos.y * 0.00014), 0.93, 1.07);
	ground_rgb *= vec3(sun_grad * 1.02, sun_grad, 2.0 - sun_grad);

	// Live dual tank tracks compacting soil & moss
	if (show_treads && map_uv.x >= 0.0 && map_uv.y >= 0.0 && map_uv.x <= 1.0 && map_uv.y <= 1.0) {
		float tread = texture(tread_tex, clamped_uv).r;
		vec3 track_tint = mix(vec3(0.68, 0.72, 0.64), vec3(0.74, 0.65, 0.58), is_ochre);
		ground_rgb = mix(ground_rgb, ground_rgb * track_tint, clamp(tread * 0.82, 0.0, 0.65));
	}

	// Dappled leaf-cluster canopy & cliff lee shadows (cool lavender-blue shadows, warm sun pools!)
	float shade_field = clamp(splat.b + outer_north_wood * 0.58, 0.0, 0.90);
	float dappled = clamp(shade_field * (0.62 + 0.68 * leaf_dapple), 0.0, 0.86);
	float border_dapple = (1.0 - is_ochre * 0.68) * smoothstep(0.56, 0.88, leaf_dapple) * 0.16;
	float total_shade = clamp(dappled + border_dapple, 0.0, 0.84);
	vec3 cool_shadow_rgb = ground_rgb * vec3(0.50, 0.58, 0.76);
	ground_rgb = mix(ground_rgb, cool_shadow_rgb, total_shade * 0.74);

	// Shelf edge rim darkening before dropping into valley mist
	float shelf_mask = smoothstep(0.36, 0.64, shelf_raw + (tuft_height - 0.5) * 0.14);
	float rim_lip = smoothstep(0.30, 0.55, shelf_raw) * (1.0 - smoothstep(0.55, 0.82, shelf_raw));
	ground_rgb = mix(ground_rgb, ground_rgb * vec3(0.72, 0.74, 0.80), rim_lip * 0.52);

	// Soft atmospheric Fight-4 blue valley mist & distant lower-valley canopy (non-repeating multi-scale!)
	vec2 m_uv1 = iso_pos / 1180.0 + vec2(TIME * 0.0025, -TIME * 0.0012);
	vec2 m_uv2 = vec2(iso_pos.x * 0.62 + iso_pos.y * 0.34, -iso_pos.x * 0.34 + iso_pos.y * 0.62) / 790.0 - vec2(TIME * 0.0018, 0.0);
	vec2 m_uv3 = iso_pos / 430.0 + vec2(0.27, 0.51);
	float m1 = texture(detail_tex, m_uv1).b;
	float m2 = texture(detail_tex, m_uv2).b;
	float m3 = texture(detail_tex, m_uv3).g;

	// Distance below cliff shelf in screen Y drives smooth atmospheric fog depth (just like forest.png!)
	float depth_into_abyss = clamp((1.0 - shelf_raw) * 1.15, 0.0, 1.0);
	vec3 deep_pine_abyss = vec3(0.15, 0.28, 0.37);
	vec3 distant_boughs = vec3(0.21, 0.38, 0.42) * (0.82 + 0.36 * m3);
	vec3 valley_base = mix(deep_pine_abyss, distant_boughs, smoothstep(0.35, 0.78, m3) * 0.55);

	float cloud_soft = smoothstep(0.22, 0.84, m1 * 0.60 + m2 * 0.40);
	// Bright cool-cyan mist bank pooling right beneath the cliff wall!
	float cliff_mist_bank = smoothstep(0.0, 0.65, 1.0 - shelf_raw) * (1.0 - smoothstep(0.55, 1.0, depth_into_abyss * 0.65));
	vec3 mist_mid = vec3(0.45, 0.66, 0.79);
	vec3 mist_haze = vec3(0.66, 0.82, 0.90);
	vec3 valley_rgb = mix(valley_base, mist_mid, clamp(cloud_soft * 0.58 + cliff_mist_bank * 0.52, 0.0, 0.92));
	valley_rgb = mix(valley_rgb, mist_haze, clamp(cliff_mist_bank * cloud_soft * 0.68, 0.0, 0.65));

	COLOR = vec4(mix(valley_rgb, ground_rgb, shelf_mask), 1.0);
}
