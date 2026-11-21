shader_type canvas_item;
render_mode unshaded;

uniform sampler2D paving : source_color, repeat_enable, filter_nearest_mipmap;
uniform sampler2D verge : source_color, repeat_enable, filter_nearest_mipmap;
uniform vec3 road_marks[10];
uniform float camera_distance = 0.0;
uniform float camera_center = 0.0;
uniform float depth = 388.0;
uniform vec2 boots = vec2(511.0, 325.0);
uniform float horizon = 96.0;

vec2 road_at(float distance_uphill) {
	for (int i = 1; i < 10; i++) {
		if (distance_uphill <= road_marks[i].x) {
			vec3 a = road_marks[i - 1];
			vec3 b = road_marks[i];
			return mix(a.yz, b.yz, smoothstep(a.x, b.x, distance_uphill));
		}
	}
	return road_marks[9].yz;
}

float grain(vec2 position) {
	vec3 bits = fract(vec3(position.xyx) * 0.1031);
	bits += dot(bits, bits.yzx + 33.33);
	return fract((bits.x + bits.y) * bits.z);
}

void fragment() {
	vec2 screen = floor(UV * vec2(960.0, 540.0)) + vec2(0.5);
	float apparent = max((screen.y - horizon) / (boots.y - horizon), 0.001);
	float ahead = depth * (1.0 / apparent - 1.0);
	float distance_uphill = camera_distance + ahead;
	vec2 road = road_at(distance_uphill);
	float world_x = (screen.x - boots.x) / apparent + camera_center;
	float lateral = world_x - road.x;
	float side = abs(lateral) - road.y;
	vec2 ground = vec2(world_x, -distance_uphill);
	float detail = max(log2(1.0 / apparent), 0.0);
	vec3 stone = textureLod(paving, (ground + vec2(290.0, 300.0)) / 544.0, detail).rgb;

	float fleck = grain(floor(ground / 3.0));
	float sun = smoothstep(-180.0, 210.0, lateral);
	vec3 soil = textureLod(verge, (ground + vec2(45.0, 119.0)) / 256.0, detail).rgb;
	soil *= mix(vec3(0.78, 0.73, 0.86), vec3(1.18, 1.03, 0.91), sun);
	vec3 surface = soil;
	if (side <= 1.0) {
		float shade = smoothstep(-120.0, 55.0, lateral);
		surface = stone * mix(vec3(0.79, 0.77, 0.85), vec3(1.00, 0.96, 0.93), shade);
	}
	// The irregular shoulder stones and their seams are fixed to distance along the road.
	float shifted = distance_uphill + 2.0 * sin(distance_uphill / 12.0);
	shifted += (lateral < 0.0 ? 0.0 : 13.0) + side * 0.17;
	float block = floor(shifted / 25.0);
	float mortar = mod(shifted, 25.0);
	float chip = grain(vec2(block, sign(lateral)));
	float edge_chip = (1.0 - smoothstep(0.0, 5.0, min(mortar, 25.0 - mortar))) * 3.0;
	float curb_end = 11.0 + chip * 7.0 - edge_chip;
	if (side >= -2.0 + edge_chip && side <= curb_end && mortar > 1.6 + chip && chip > 0.10) {
		float face = smoothstep(curb_end - 4.5, curb_end, side);
		vec3 curb_top = mix(vec3(0.58, 0.39, 0.36), vec3(0.89, 0.68, 0.49), chip);
		curb_top *= 0.70 + 0.22 * fleck + stone.r * 0.20;
		surface = mix(curb_top, curb_top * vec3(0.73, 0.66, 0.72), face);
	}
	float bend_shadow = (smoothstep(175.0, 340.0, distance_uphill) - smoothstep(460.0, 640.0, distance_uphill));
	surface *= mix(vec3(1.0), vec3(0.70, 0.68, 0.76), bend_shadow * (1.0 - smoothstep(-140.0, 55.0, lateral)));
	float haze = smoothstep(280.0, 2600.0, ahead);
	surface = mix(surface, vec3(0.66, 0.47, 0.49), haze * 0.72);

	// The paved shelf continues along the open rim. The valley shows beyond its lip.
	float opening = smoothstep(405.0, 680.0, distance_uphill);
	float cliff_lip = mix(790.0, 61.0, opening) + 5.0 * sin(distance_uphill / 36.0);
	float opaque = 1.0;
	if (lateral < 0.0 && side > cliff_lip) {
		float beyond = side - cliff_lip;
		opaque = 1.0 - smoothstep(7.0, 15.0, beyond);
		surface = mix(vec3(0.58, 0.32, 0.29), vec3(0.35, 0.20, 0.25), min(beyond / 11.0, 1.0));
		surface += (fleck - 0.5) * 0.08;
	}
	opaque *= smoothstep(106.0, 126.0, screen.y);
	COLOR = vec4(surface, opaque);
}
