shader_type canvas_item;
// Reusable RTS faction team-colour mask shader.
// Supports Blue, Red, Green, and Palatinate (docs/GAME_DESIGN.md §3) from a single
// neutral sprite sheet + mask texture while preserving the crisp dark outline (#221814)
// so units stay readable on bright orange desert sand and dark tropical forest grass.
//
// Mask channels (mask_tex):
//   R: primary team armour/paint weight (0 = neutral steel/skin/outline, 1 = team armour)
//   G: shading ramp value (0 = shadow -> 0.5 = mid body -> 1 = top-left specular highlight)
//   B: secondary trim / emblem weight (0..0.6 = scarf/trim, >0.6 = faction emblem/insignia)

uniform bool use_mask = false;
uniform sampler2D mask_tex : filter_nearest;
uniform vec4 team_dark : source_color = vec4(0.09, 0.17, 0.47, 1.0);
uniform vec4 team_mid : source_color = vec4(0.18, 0.38, 0.87, 1.0);
uniform vec4 team_light : source_color = vec4(0.51, 0.69, 1.00, 1.0);
uniform vec4 trim_color : source_color = vec4(0.93, 0.89, 0.81, 1.0);
uniform vec4 emblem_color : source_color = vec4(0.43, 0.94, 0.94, 1.0);
uniform vec4 outline_color : source_color = vec4(0.133, 0.094, 0.078, 1.0);
uniform float outline_protect : hint_range(0.0, 1.0) = 0.22;
uniform float ground_light : hint_range(0.5, 1.5) = 1.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Pass primitive draw calls (draw_circle, draw_line, draw_rect use 1x1 default white texture)
	// directly through with their vertex colour.
	if (!use_mask || TEXTURE_PIXEL_SIZE.x > 0.5) {
		COLOR = tex * v_modulate;
	} else if (tex.a < 0.01) {
		COLOR = vec4(0.0);
	} else {
		vec4 m = texture(mask_tex, UV);
		float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		// Protect dark outlines so silhouettes never wash out on sand or grass.
		float is_outline = 1.0 - smoothstep(outline_protect * 0.65, outline_protect, lum);

		// 3-stop team colour ramp from mask.g (or base luminance if mask.g is 0).
		float shade = (m.g > 0.01) ? m.g : clamp((lum - 0.15) / 0.75, 0.0, 1.0);
		vec3 ramp_low = mix(team_dark.rgb, team_mid.rgb, clamp(shade * 2.0, 0.0, 1.0));
		vec3 ramp_high = mix(team_mid.rgb, team_light.rgb, clamp((shade - 0.5) * 2.0, 0.0, 1.0));
		vec3 team_rgb = (shade < 0.5) ? ramp_low : ramp_high;

		vec3 rgb = mix(tex.rgb, team_rgb, m.r * (1.0 - is_outline));

		// Secondary trim (scarf / cloak / officer trim) and emblem (cyan cross / gold crest).
		if (m.b > 0.02) {
			float is_emblem = smoothstep(0.60, 0.85, m.b);
			float trim_w = clamp(m.b * 2.0, 0.0, 1.0) * (1.0 - is_emblem);
			vec3 shaded_trim = trim_color.rgb * mix(0.75, 1.12, shade);
			vec3 shaded_emblem = emblem_color.rgb * mix(0.85, 1.15, shade);
			rgb = mix(rgb, shaded_trim, trim_w * (1.0 - is_outline));
			rgb = mix(rgb, shaded_emblem, is_emblem * (1.0 - is_outline));
		}

		// Keep crisp dark outline colour at the silhouette boundary.
		rgb = mix(rgb, outline_color.rgb, is_outline * 0.65);

		// Apply ground light and damage flash.
		rgb *= ground_light;
		rgb = mix(rgb, vec3(1.0), hit_flash * 0.72);
		COLOR = vec4(clamp(rgb, 0.0, 1.0), tex.a * v_modulate.a);
	}
}
