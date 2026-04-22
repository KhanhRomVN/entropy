shader_type canvas_item;

uniform vec4 water_color : source_color = vec4(0.235, 0.424, 0.62, 1.0);
uniform float wave_speed : hint_range(0.0, 10.0) = 1.0;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;

void vertex() {
	// local_pos no longer used, we use UV in fragment
}

void fragment() {
    // Water detection via alternative tile alpha (0.5). Land is 1.0.
    if (COLOR.a < 0.9) {
        vec2 p;
        p.x = (UV.x - 0.5) * 2.0; 
        p.y = (UV.y - (2373.0 / 5000.0)) * (5000.0 / 250.0);
        
        float wave = sin(TIME * wave_speed + UV.x * 10.0) * wave_amplitude;
        p.y += wave;
        
        float dx = abs(p.x);
        float dy = p.y;
        bool inside = false;
        
        if (dx * 0.5 + abs(dy + 0.25) < 0.5) inside = true;
        if (dx < 0.5 && dy > -0.25 && dy < 0.75 - dx * 0.5) inside = true;

        if (inside) {
            COLOR = water_color;
        } else {
            discard;
        }
    } else {
        // Normal land tile
        vec4 tex_color = texture(TEXTURE, UV);
        if (tex_color.a < 0.1) discard; // Handle transparency in atlas
        COLOR = tex_color * COLOR;
    }
}
