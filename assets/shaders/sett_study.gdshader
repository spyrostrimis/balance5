shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D paint : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D flat_normals : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D grain_normals : hint_normal, filter_linear_mipmap, repeat_disable;
uniform bool flat_sample = false;
uniform vec3 player_pos;
varying vec3 ground_position;

void vertex() {
    ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // The paint follows world X/Z exactly as it does on the surrounding Session 3 road.
    vec2 uv = (ground_position.xz - vec2(-0.08, 6.45)) / vec2(1.2, 1.0);
    vec2 separation = (ground_position.xz - player_pos.xz) * vec2(1.15, 1.55);
    float contact = (1.0 - smoothstep(0.16, 0.54, length(separation))) * 0.44;
    ALBEDO = texture(paint, uv).rgb * (1.0 - contact);
    ROUGHNESS = 0.86;

    // Both variants have the same paint and small surface features. Only the flat
    // variant needs the crown slope from the map. The raised mesh supplies that slope.
    vec2 xy = (flat_sample ? texture(flat_normals, uv).rg : texture(grain_normals, uv).rg) * 2.0 - 1.0;
    float nz = sqrt(max(0.001, 1.0 - dot(xy, xy)));
    vec3 perturbation = mat3(VIEW_MATRIX) * vec3(xy.x, 0.0, -xy.y);
    NORMAL = normalize(NORMAL + perturbation / nz);
}

