// Sharp-pixel anti-aliased plant card shader for 3D Kit Canyon v2.
// Y-billboard with foot pivot at y=0, 1-texel sway, pixel-AA interior, and alpha-to-coverage edge AA.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D sprite_tex : source_color, filter_linear, repeat_disable;
uniform float texel_m = 0.015625;
uniform float sway_texels = 1.0;
uniform float sway_speed = 1.25;
uniform vec3 shade_fill : source_color = vec3(0.34, 0.22, 0.42);
uniform float shade_strength = 0.8;
uniform float brightness = 0.80;

vec2 pixel_aa_uv_clamped(vec2 uv, vec2 tex_size) {
	vec2 p = uv * tex_size;
	vec2 fw = max(fwidth(p), vec2(0.0001));
	vec2 seam = floor(p + 0.5);
	vec2 delta = (p - seam) / fw;
	vec2 snapped = seam + clamp(delta, vec2(-0.5), vec2(0.5));
	vec2 safe = clamp(snapped, vec2(0.5), tex_size - vec2(0.5));
	return safe / tex_size;
}

void vertex() {
	float top = clamp(1.0 - UV.y, 0.0, 1.0);
	vec3 origin = NODE_POSITION_WORLD;
	float wave = sin(TIME * sway_speed + origin.x * 1.7 + origin.z * 2.3);
	VERTEX.x += round(wave * sway_texels * top * top) * texel_m;

	// Y billboard preserving node scale (supports +/-1.0 horizontal mirror without distortion)
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	float sx = length(MODEL_MATRIX[0].xyz) * (MODEL_MATRIX[0].x < 0.0 ? -1.0 : 1.0);
	float sy = length(MODEL_MATRIX[1].xyz);
	float sz = length(MODEL_MATRIX[2].xyz);
	mat4 bb = mat4(
		vec4(right * sx, 0.0),
		vec4(0.0, sy, 0.0, 0.0),
		vec4(-fwd * sz, 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 ts = vec2(textureSize(sprite_tex, 0));
	vec4 c = texture(sprite_tex, pixel_aa_uv_clamped(UV, ts));
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.35;
	ALBEDO = c.rgb * brightness * mix(0.76, 1.0, smoothstep(1.0, 0.72, UV.y));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.35));
}

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += shade_fill * shade_strength * (1.0 - lit) * length(LIGHT_COLOR) / PI;
	}
}
