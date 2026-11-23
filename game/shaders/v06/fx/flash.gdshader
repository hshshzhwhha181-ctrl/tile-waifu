shader_type canvas_item;
render_mode blend_add;
// V6Fx: soft radial light burst (additive). center/radius in pixels; amount 0..1.
uniform vec4 color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform vec2 center = vec2(360.0, 640.0);
uniform vec2 size = vec2(720.0, 1280.0);
uniform float radius = 400.0;
uniform float amount = 0.0;
uniform float full = 0.0;                 // 1 = whole-screen white-out component
void fragment() {
	float d = length(UV * size - center) / max(radius, 1.0);
	float core = exp(-d * d * 2.5);
	float a = (core + full) * amount;
	COLOR = vec4(color.rgb, clamp(a, 0.0, 1.0));
}
