shader_type canvas_item;
// Fullscreen vignette + color grade overlay.
uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.75, 1.0);
uniform float vignette = 0.35;
uniform float pulse = 0.0;
void fragment() {
	vec2 p = UV - 0.5;
	float v = smoothstep(0.25, 0.85, length(p * vec2(1.0, 0.75)));
	float a = v * vignette * (1.0 + pulse * (0.5 + 0.5 * sin(TIME * 6.0)));
	COLOR = vec4(tint.rgb, clamp(a, 0.0, 1.0) * tint.a);
}
