shader_type canvas_item;

uniform sampler2D mask;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec4 m = texture(mask, UV);
    vec4 screen = texture(screen_texture, SCREEN_UV);
    
    // Blur logic (simplistic box blur for performance)
    vec4 blur = vec4(0.0);
    if (m.r < 0.5) {
        float size = 0.002;
        blur += texture(screen_texture, SCREEN_UV + vec2(-size, -size));
        blur += texture(screen_texture, SCREEN_UV + vec2(0, -size));
        blur += texture(screen_texture, SCREEN_UV + vec2(size, -size));
        blur += texture(screen_texture, SCREEN_UV + vec2(-size, 0));
        blur += texture(screen_texture, SCREEN_UV + vec2(0, 0));
        blur += texture(screen_texture, SCREEN_UV + vec2(size, 0));
        blur += texture(screen_texture, SCREEN_UV + vec2(-size, size));
        blur += texture(screen_texture, SCREEN_UV + vec2(0, size));
        blur += texture(screen_texture, SCREEN_UV + vec2(size, size));
        blur /= 9.0;
        COLOR = blur * vec4(0.5, 0.5, 0.5, 1.0); // Dim non-selected
    } else {
        COLOR = screen;
        
        // Simple Edge detection for white outline
        float edge = 0.0;
        float d = 0.005;
        edge += texture(mask, UV + vec2(d, 0)).r;
        edge += texture(mask, UV + vec2(-d, 0)).r;
        edge += texture(mask, UV + vec2(0, d)).r;
        edge += texture(mask, UV + vec2(0, -d)).r;
        
        if (edge < 4.0) {
            COLOR = mix(COLOR, vec4(1.0, 1.0, 1.0, 1.0), 0.8);
        }
    }
}
