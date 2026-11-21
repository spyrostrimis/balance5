shader_type canvas_item;
render_mode unshaded;

uniform sampler2D cobble_tex : source_color, repeat_enable, filter_nearest_mipmap;
uniform sampler2D sand_tex : source_color, repeat_enable, filter_nearest_mipmap;
uniform sampler2D curb_tex : source_color, repeat_enable, filter_nearest_mipmap;

uniform vec3 road_marks[12];
uniform float camera_distance = 0.0;
uniform float camera_center = 0.0;
uniform float depth = 260.0;
uniform vec2 boots = vec2(486.0, 320.0);
uniform float horizon = 88.0;
uniform vec2 render_size = vec2(960.0, 540.0);

vec2 road_at(float distance_uphill) {
	for (int i = 1; i < 12; i++) {
		if (distance_uphill <= road_marks[i].x) {
			vec3 a = road_marks[i - 1];
			vec3 b = road_marks[i];
			return mix(a.yz, b.yz, smoothstep(a.x, b.x, distance_uphill));
		}
	}
	return road_marks[11].yz;
}

void fragment() {
	// Snap cleanly to the active SubViewport pixel grid (960x540 or 640x360), then project in 960x540 space.
	vec2 snapped = floor(UV * render_size) + vec2(0.5);
	vec2 screen = snapped * (vec2(960.0, 540.0) / render_size);

	float apparent = max((screen.y - horizon) / (boots.y - horizon), 0.001);
	float ahead = depth * (1.0 / apparent - 1.0);
	float distance_uphill = camera_distance + ahead;

	vec2 road = road_at(distance_uphill);
	float world_x = (screen.x - boots.x) / apparent + camera_center;
	float lateral = world_x - road.x;
	float side = abs(lateral) - road.y;

	float mip_lod = clamp(log2(1.0 / max(apparent, 0.06)) * 0.72, 0.0, 3.0);

	// 1. Base Image-9 sand verge sampled in world ground space
	vec2 sand_uv = vec2(world_x + 120.0, -distance_uphill) / 185.0;
	vec3 sand = textureLod(sand_tex, sand_uv, mip_lod).rgb;

	// Warm sunlit left verge -> cooler shaded right cliff verge (matching Image 9 lighting)
	float cliff_shade = smoothstep(55.0, 210.0, lateral);
	sand *= mix(vec3(1.04, 1.01, 0.96), vec3(0.68, 0.56, 0.58), cliff_shade);

	vec3 surface = sand;

	// 2. Cobble road surface sampled in undistorted world ground space (zero S-curve shearing!)
	if (side <= 0.5) {
		vec2 cobble_uv = vec2(world_x + 192.0, -distance_uphill * 1.10) / 235.0;
		vec3 cobble = textureLod(cobble_tex, cobble_uv, mip_lod).rgb;
		// Subtle warm-to-cool shadow across the right side of the road as in Image 9
		float road_shade = smoothstep(14.0, 92.0, lateral);
		cobble *= mix(vec3(1.03, 1.01, 0.98), vec3(0.76, 0.71, 0.78), road_shade);
		surface = cobble;
	}

	// 3. Dressed Image-9 curb stones lining both edges of the S-curve road
	float curb_width = 19.0;
	if (side > -1.5 && side <= curb_width) {
		float along = distance_uphill + (lateral < 0.0 ? 0.0 : 14.0);
		float block_len = 28.0;
		float block_local = mod(along, block_len);
		float mortar_gap = 1.0 - smoothstep(0.0, 2.2, min(block_local, block_len - block_local));
		float u = clamp((side + 1.5) / (curb_width + 1.5), 0.0, 1.0);
		// Map across the crisp sunlit stone top & shaded outer bevel of Image-9 curb_strip
		float sample_u = mix(0.24, 0.88, lateral < 0.0 ? (1.0 - u) : u);
		float v = along / 224.0;
		vec3 curb = textureLod(curb_tex, vec2(sample_u, v), mip_lod * 0.5).rgb;
		// Crisp dark pixel-art outline on inner/outer bevels and between individual curb blocks
		float inner_edge = 1.0 - smoothstep(-1.5, 0.8, side);
		float outer_edge = smoothstep(curb_width - 2.6, curb_width, side);
		float outline = max(max(inner_edge * 0.78, outer_edge * 0.88), mortar_gap * 0.85);
		curb *= mix(vec3(1.04, 1.01, 0.97), vec3(0.26, 0.19, 0.21), outline);
		// Right-side curbs sit in cool canyon wall shadow
		if (lateral > 0.0) {
			curb *= vec3(0.84, 0.78, 0.84);
		}
		surface = curb;
	} else if (side > curb_width && side <= curb_width + 6.0) {
		// Soft cast contact shadow immediately outside the dressed curb stones onto the sand
		float drop = 1.0 - smoothstep(curb_width, curb_width + 6.0, side);
		surface *= mix(vec3(1.0), vec3(0.60, 0.45, 0.46), drop * 0.74);
	}

	// 4. Warm golden sunlit canyon-mouth atmospheric haze at far distance
	float far_haze = smoothstep(320.0, 1850.0, ahead);
	surface = mix(surface, vec3(0.80, 0.64, 0.50), far_haze * 0.68);

	// 5. Seamless horizon fade into horizon_backdrop.png pinned near Y = 88
	float opaque = smoothstep(horizon + 7.0, horizon + 23.0, screen.y);
	COLOR = vec4(surface, opaque);
}
