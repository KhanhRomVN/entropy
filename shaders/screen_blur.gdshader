shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float lod: hint_range(0.0, 5.0) = 2.5;
uniform float brightness: hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 color = textureLod(screen_texture, SCREEN_UV, lod);
	color.rgb *= brightness;
	COLOR = color;
}
