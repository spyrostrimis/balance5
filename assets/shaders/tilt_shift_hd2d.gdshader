shader_type canvas_item;

// Smooth Cinematic Tilt-Shift Depth of Field Shader for HD-2D
// Uses a 16-sample golden-angle spiral disc kernel for buttery smooth lens bokeh

uniform float focal_position_y : hint_range(0.0, 1.0) = 0.58; // Sharp focal plane (path)
uniform float focal_width : hint_range(0.05, 0.5) = 0.22;      // Depth of sharp field
uniform float blur_amount : hint_range(0.0, 10.0) = 3.5;       // Bokeh intensity
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.22; // Subtle lens vignette
uniform vec4 warm_tint : source_color = vec4(1.02, 1.0, 0.98, 1.0);

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Distance from focal plane
    float dist = abs(uv.y - focal_position_y);
    float blur_factor = smoothstep(focal_width * 0.4, focal_width * 1.3, dist);
    
    vec4 col = vec4(0.0);
    
    if (blur_factor < 0.02) {
        col = texture(screen_texture, uv);
    } else {
        // Golden angle spiral disc kernel (16 samples) for silky smooth photographic bokeh
        col = texture(screen_texture, uv) * 2.0;
        float total_weight = 2.0;
        float max_radius = blur_factor * blur_amount * 0.0035;
        
        const float GOLDEN_ANGLE = 2.39996323; // ~137.5 degrees in radians
        
        for (int i = 1; i <= 16; i++) {
            float r = sqrt(float(i) / 16.0) * max_radius;
            float theta = float(i) * GOLDEN_ANGLE;
            vec2 offset = vec2(cos(theta), sin(theta)) * r;
            
            float weight = 1.0 - (float(i) / 24.0);
            col += texture(screen_texture, uv + offset) * weight;
            total_weight += weight;
        }
        col /= total_weight;
    }
    
    // Apply warm atmosphere grade
    col.rgb *= warm_tint.rgb;
    
    // Subtle cinematic vignette
    vec2 vig_uv = uv * (1.0 - uv.yx);
    float vig = clamp(pow(vig_uv.x * vig_uv.y * 15.0, vignette_strength), 0.0, 1.0);
    col.rgb *= vig;
    
    COLOR = vec4(col.rgb, 1.0);
}
