shader_type canvas_item;

uniform float sway_px : hint_range(0.0, 3.0) = 1.0;
uniform float speed : hint_range(0.2, 4.0) = 1.65;
uniform float phase_offset = 0.0;

void vertex() {
	// Sway only the upper leaves of the bush, snapped to whole pixel increments
	float top_weight = clamp(1.0 - UV.y * 1.35, 0.0, 1.0);
	if (top_weight > 0.05) {
		float wave = sin(TIME * speed + phase_offset);
		VERTEX.x += round(wave * sway_px * top_weight);
	}
}
