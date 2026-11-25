// Pixel-art plant card for the 3D kit canyon.
// - Turns around the vertical axis to face the camera (Y billboard), keeping its size; pivot at its foot.
// - The upper part sways gently in the wind, in whole texels so pixels stay square.
// - Lit like the cliff kit: sun plus a violet fill in shade; the normal leans up so bushes catch the sun
//   from above instead of going dark when it is behind them. The base is a little darker (ground contact).
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, depth_prepass_alpha;

uniform sampler2D sprite_tex : source_color, filter_nearest, repeat_disable;
uniform float texel_m = 0.015625;       // metres per texel (1/64)
uniform float sway_texels = 1.0;
uniform float sway_speed = 1.3;
uniform vec3 shade_fill : source_color = vec3(0.34, 0.22, 0.42);
uniform float shade_strength = 0.8;
uniform float brightness = 0.78;

void vertex() {
	float top = clamp(UV.y < 1.0 ? 1.0 - UV.y : 0.0, 0.0, 1.0);
	vec3 origin = NODE_POSITION_WORLD;
	float wave = sin(TIME * sway_speed + origin.x * 1.7 + origin.z * 2.3);
	VERTEX.x += round(wave * sway_texels * top * top) * texel_m;
	// Y billboard that keeps the node's scale.
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	mat4 bb = mat4(vec4(right * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(-fwd * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(sprite_tex, UV);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = c.rgb * brightness * mix(0.72, 1.0, smoothstep(1.0, 0.7, UV.y));
	// Lean the card's normal toward the sky.
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.35));
}

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += shade_fill * shade_strength * (1.0 - lit) * length(LIGHT_COLOR) / PI;
	}
}
