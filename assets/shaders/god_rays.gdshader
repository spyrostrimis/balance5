shader_type canvas_item;

// Dynamic Sun Rays / God Rays Shader for HD-2D
// Simulates diagonal sunlight streaming through the canyon

uniform float angle : hint_range(-1.0, 1.0) = -0.45;       // Ray direction
uniform float ray_density : hint_range(1.0, 50.0) = 18.0;   // Frequency of beams
uniform float ray_speed : hint_range(0.0, 2.0) = 0.15;      // Subtle drift
uniform float ray_intensity : hint_range(0.0, 1.0) = 0.35;  // Brightness of rays
uniform vec4 ray_color : source_color = vec4(1.0, 0.92, 0.72, 1.0); // Warm desert sunlight

void fragment() {
    vec2 uv = UV;
    
    // Project along ray angle
    float proj = uv.x + uv.y * angle;
    
    // Multi-octave wave for natural light beam grouping
    float t = TIME * ray_speed;
    float beam1 = sin(proj * ray_density + t) * 0.5 + 0.5;
    float beam2 = sin(proj * (ray_density * 1.7) - t * 0.7) * 0.5 + 0.5;
    float beam = pow(beam1 * beam2, 1.5);
    
    // Fade out towards the bottom and edges
    float vertical_fade = smoothstep(1.0, 0.1, uv.y);
    float edge_fade = smoothstep(0.0, 0.2, uv.x) * smoothstep(1.0, 0.7, uv.x);
    
    float alpha = beam * vertical_fade * edge_fade * ray_intensity;
    
    COLOR = vec4(ray_color.rgb, alpha);
}
