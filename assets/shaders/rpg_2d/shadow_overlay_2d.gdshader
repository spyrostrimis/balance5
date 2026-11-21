shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 shadow_tint : source_color = vec4(0.32, 0.22, 0.29, 0.32);

void fragment() {
	COLOR = shadow_tint;
}
