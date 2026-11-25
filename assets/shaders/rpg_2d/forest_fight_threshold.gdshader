shader_type canvas_item;
render_mode unshaded;

uniform float passage : hint_range(0.0, 1.0) = 0.0;
varying float height_from_boot;

void vertex() {
	height_from_boot = -VERTEX.y - abs(VERTEX.x) * 0.10;
}

void fragment() {
	float edge = mix(-17.0, 165.0, passage);
	float into_shadow = smoothstep(edge - 22.0, edge + 24.0, height_from_boot);
	COLOR.rgb *= mix(vec3(0.17, 0.16, 0.22), vec3(1.0), into_shadow);
	COLOR.a *= smoothstep(edge - 7.0, edge + 8.0, height_from_boot);
}
