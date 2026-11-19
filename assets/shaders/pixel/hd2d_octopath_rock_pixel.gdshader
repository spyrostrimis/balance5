// GENERATED from assets/shaders/hd2d_octopath_rock.gdshader by tools/python/make_pixel_shader_variants.py.
// Nearest-filter samplers and uniform repeat scales for pixel-art textures. Edit the source, then regenerate.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D sandstone_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D sandstone_norm : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D basalt_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D basalt_norm : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D boulder_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D boulder_norm : hint_normal, filter_nearest_mipmap, repeat_enable;

uniform vec3 haze_color : source_color = vec3(0.95, 0.78, 0.52);
uniform float haze_strength : hint_range(0.0, 1.0) = 0.24;

// Repeat scales exposed for authored pixel sets (defaults match the source shader).
uniform vec2 strata_scale = vec2(0.34, 0.72); // repeats per metre along / up the wall
uniform float basalt_scale = 1.05; // slate tops, repeats per metre
uniform vec2 basalt_side_scale = vec2(1.45, 0.52); // dark slate courses (up, along)
uniform float boulder_scale = 0.65; // ochre boulder clusters

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 sample_triplanar(sampler2D tex, vec3 pos, vec3 w, float scale) {
	return texture(tex, pos.zy * scale).rgb * w.x
		+ texture(tex, pos.xz * scale).rgb * w.y
		+ texture(tex, pos.xy * scale).rgb * w.z;
}

vec3 sample_strata_triplanar(sampler2D tex, vec3 pos, vec3 w, float scale_h, float scale_v) {
	return texture(tex, vec2(pos.z * scale_h, pos.y * scale_v)).rgb * w.x
		+ texture(tex, pos.xz * scale_h).rgb * w.y
		+ texture(tex, vec2(pos.x * scale_h, pos.y * scale_v)).rgb * w.z;
}

void fragment() {
	vec3 nrm = normalize(world_nrm);
	vec3 w = pow(abs(nrm), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);

	vec3 sand_col = sample_strata_triplanar(sandstone_tex, world_pos, w, strata_scale.x, strata_scale.y);
	vec3 sand_nrm = sample_strata_triplanar(sandstone_norm, world_pos, w, strata_scale.x, strata_scale.y);

	// Top ledges: rich weathered grey-brown granular stone (kept darker in linear space so sunlight hits Img 1 ledge_tops)
	vec3 bas_top_raw = sample_triplanar(basalt_tex, world_pos, w, basalt_scale);
	vec3 bas_top_col = mix(bas_top_raw * 0.52, sand_col * vec3(0.45, 0.42, 0.38), 0.25);
	vec3 bas_top_nrm = sample_triplanar(basalt_norm, world_pos, w, basalt_scale);

	// Vertical dark terrace walls: flipped horizontal masonry UVs + linear dark slate-umber matching Img 1 lower steps
	vec3 mas_zy = texture(basalt_tex, vec2(world_pos.y * basalt_side_scale.x, world_pos.z * basalt_side_scale.y)).rgb;
	vec3 mas_xy = texture(basalt_tex, vec2(world_pos.y * basalt_side_scale.x, world_pos.x * basalt_side_scale.y)).rgb;
	vec3 mas_side = mas_zy * (w.x / (w.x + w.z + 0.0001)) + mas_xy * (w.z / (w.x + w.z + 0.0001));
	float mas_luma = dot(mas_side, vec3(0.299, 0.587, 0.114));
	float sand_luma = dot(sand_col, vec3(0.299, 0.587, 0.114));
	float dark_blend = clamp(mas_luma * 1.35 * 0.65 + sand_luma * 0.55, 0.0, 1.0);
	vec3 bas_side_col = mix(vec3(0.024, 0.017, 0.013), vec3(0.115, 0.080, 0.055), dark_blend);

	vec3 mas_n_zy = texture(basalt_norm, vec2(world_pos.y * basalt_side_scale.x, world_pos.z * basalt_side_scale.y)).rgb;
	vec3 mas_n_xy = texture(basalt_norm, vec2(world_pos.y * basalt_side_scale.x, world_pos.x * basalt_side_scale.y)).rgb;
	vec3 bas_side_nrm = mas_n_zy * (w.x / (w.x + w.z + 0.0001)) + mas_n_xy * (w.z / (w.x + w.z + 0.0001));

	vec3 bas_col = mix(bas_side_col, bas_top_col, smoothstep(0.35, 0.75, w.y));
	vec3 bas_nrm = mix(mix(sand_nrm, bas_side_nrm, 0.55), bas_top_nrm, smoothstep(0.35, 0.75, w.y));

	vec3 bld_col = sample_triplanar(boulder_tex, world_pos, w, boulder_scale);
	vec3 bld_nrm = sample_triplanar(boulder_norm, world_pos, w, boulder_scale);

	// Vertex color: R = 0.0 sandstone / 1.0 cap or lower slate, G = AO, B = 1.0 on BoulderCluster
	float is_boulder = smoothstep(0.65, 0.90, COLOR.b);
	float is_basalt = smoothstep(0.45, 0.85, COLOR.r) * (1.0 - is_boulder);

	vec3 base_col = mix(sand_col, bld_col, is_boulder);
	vec3 base_nrm = mix(sand_nrm, bld_nrm, is_boulder);

	vec3 final_col = mix(base_col, bas_col, is_basalt);
	vec3 final_nrm = mix(base_nrm, bas_nrm, is_basalt);

	// Baked crevice & ground-contact AO + subtly varied organic sedimentary strata (no uniform zebra stripes)
	float ao = clamp(COLOR.g, 0.35, 1.0);
	float y_warp = world_pos.y + sin(world_pos.z * 0.55 + world_pos.x * 0.4) * 0.09;
	float block_tone = 1.0 + sin(world_pos.z * 0.85 + world_pos.y * 0.45) * 0.06 + cos(world_pos.z * 1.9 + world_pos.x * 1.1) * 0.04;
	float strata_rib = (
		sin(y_warp * 19.0 + sin(world_pos.z * 1.1) * 0.7) * 0.024
		+ sin(y_warp * 43.0 + 0.8) * 0.014
		+ cos(y_warp * 8.5) * 0.018
	) * (1.0 - is_basalt) * (1.0 - is_boulder);
	float bed_joint = mix(0.92, 1.0, smoothstep(0.0, 0.18, abs(sin(y_warp * 6.9115))));
	float vertical_joint_ao = mix(1.0, bed_joint, (1.0 - is_basalt) * (1.0 - is_boulder) * (1.0 - w.y));
	float edge_lift = COLOR.b * 0.35 * (1.0 - is_boulder) + is_boulder * max(0.0, nrm.y) * 0.10;
	final_col = final_col * block_tone * (ao * vertical_joint_ao + strata_rib + edge_lift);

	float cam_dist = length(CAMERA_POSITION_WORLD - world_pos);
	float haze_t = smoothstep(16.0, 44.0, cam_dist) * haze_strength;

	ALBEDO = mix(final_col, haze_color, haze_t);
	NORMAL_MAP = normalize(final_nrm);
	NORMAL_MAP_DEPTH = 1.25;
	ROUGHNESS = mix(0.86, 0.78, is_basalt);
}
