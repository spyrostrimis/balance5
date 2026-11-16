shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D splatmap : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_normal : hint_normal, filter_linear_mipmap, repeat_enable;

uniform vec2 uv_scale_sand = vec2(1.2, 1.2);
uniform vec2 uv_scale_rock = vec2(8.0, 8.0);
uniform vec2 uv_scale_path = vec2(24.0, 24.0);

uniform float dune_height_scale = 0.55;
uniform float rock_height_scale = 0.85;

void vertex() {
	vec4 splat = texture(splatmap, UV);
	
	// Gentle elevation for dunes
	float dune_swell = sin(UV.x * 6.0 + UV.y * 4.5) * cos(UV.x * 3.0) * dune_height_scale * splat.r;
	
	// Elevated cliffs
	float elevation = splat.b * rock_height_scale + dune_swell;
	
	// Oasis depression
	elevation -= splat.a * 0.45;
	
	VERTEX.y += elevation;
}

void fragment() {
	vec4 splat = texture(splatmap, UV);
	
	vec3 s_alb = texture(sand_albedo, UV * uv_scale_sand).rgb;
	vec3 s_nrm = texture(sand_normal, UV * uv_scale_sand).rgb;
	
	vec3 r_alb = texture(rock_albedo, UV * uv_scale_rock).rgb;
	vec3 r_nrm = texture(rock_normal, UV * uv_scale_rock).rgb;
	
	vec3 p_alb = texture(path_albedo, UV * uv_scale_path).rgb;
	vec3 p_nrm = texture(path_normal, UV * uv_scale_path).rgb;
	
	// Earthy desert cobblestone tint (prevents sun overexposure)
	p_alb = p_alb * vec3(0.58, 0.52, 0.46);
	
	vec3 final_albedo = s_alb;
	vec3 final_normal = s_nrm;
	float final_roughness = 0.84;
	
	// Blend Bedrock (Blue channel)
	float rock_w = smoothstep(0.12, 0.52, splat.b);
	final_albedo = mix(final_albedo, r_alb, rock_w);
	final_normal = mix(final_normal, r_nrm, rock_w);
	final_roughness = mix(final_roughness, 0.90, rock_w);
	
	// Blend Flagstone Path (Green channel)
	float path_w = smoothstep(0.14, 0.48, splat.g);
	final_albedo = mix(final_albedo, p_alb, path_w);
	final_normal = mix(final_normal, p_nrm, path_w);
	final_roughness = mix(final_roughness, 0.72, path_w);
	
	// Blend Oasis pool (Alpha channel)
	if (splat.a > 0.04) {
		float water_w = smoothstep(0.06, 0.35, splat.a);
		vec3 water_col = vec3(0.05, 0.55, 0.75); // Radiant turquoise
		vec3 grass_rim = vec3(0.18, 0.52, 0.12); // Lush foliage
		vec3 oasis_col = mix(grass_rim, water_col, smoothstep(0.08, 0.38, splat.a));
		final_albedo = mix(final_albedo, oasis_col, water_w);
		final_roughness = mix(final_roughness, 0.02, water_w);
	}
	
	ALBEDO = final_albedo;
	NORMAL_MAP = final_normal;
	NORMAL_MAP_DEPTH = 1.9;
	ROUGHNESS = final_roughness;
	SPECULAR = 0.22;
}
