shader_type canvas_item;

uniform sampler2D treads : filter_linear, repeat_disable;
uniform vec2 world_size = vec2(768.0, 544.0);
uniform bool show_treads = true;
uniform bool pixel_art = false;
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (show_treads) {
		float disturbed = texture(treads, world_position / world_size).r;
		float compression = pixel_art ? step(0.45, disturbed) : disturbed;
		COLOR.a *= 1.0 - 0.96 * compression;
	}
}
