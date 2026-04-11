shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 shadow_color : source_color = vec4(0.04, 0.04, 0.1, 1.0);
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	ALBEDO = shadow_color.rgb;
	ALPHA = 0.0;
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	// Chụp bóng đổ mượt mà từ thuộc tính ATTENUATION của ánh sáng
	float shadow_raw = clamp(1.0 - ATTENUATION, 0.0, 1.0);
	ALPHA = max(ALPHA, shadow_raw * shadow_opacity);
}
