shader_type spatial;
render_mode specular_disabled, cull_disabled;

uniform sampler2D sandstone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 bedding_light : source_color = vec4(0.62, 0.43, 0.34, 1.0);
uniform vec4 bedding_dark : source_color = vec4(0.39, 0.29, 0.29, 1.0);
varying vec3 world;
varying vec3 world_normal;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 weight = pow(abs(normalize(world_normal)), vec3(4.0));
	weight /= weight.x + weight.y + weight.z;
	vec3 tex = texture(sandstone, world.zy * vec2(0.51, 0.66)).rgb * weight.x
		+ texture(sandstone, world.xz * 0.53).rgb * weight.y
		+ texture(sandstone, world.xy * vec2(0.51, 0.66)).rgb * weight.z;
	float warped = world.y + sin(world.x * 0.79 + world.z * 0.44) * 0.085
		+ sin(world.x * 0.27 - world.z * 0.32) * 0.12;
	float seam = smoothstep(0.73, 0.98, sin(warped * 14.0) * 0.5 + 0.5);
	float course = sin(warped * 3.77 - 0.2) * 0.5 + 0.5;
	float colour = clamp(0.58 + course * 0.29 - seam * 0.125 + (tex.r - 0.24) * 0.42, 0.05, 1.0);
	vec3 base = mix(bedding_dark.rgb, bedding_light.rgb, colour) * (0.72 + tex.r * 0.79);
	ALBEDO = mix(base, base * vec3(0.86, 0.94, 1.08), smoothstep(0.45, 0.92, world_normal.y));
	ROUGHNESS = 1.0;
}
