shader_type canvas_item;
render_mode blend_add;
// V6Fx: diagonal light sweep (glint) across a rect. pos goes -0.3..1.3. Additive.
uniform vec4 color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float pos = -0.3;
uniform float width = 0.08;
uniform float slant = 0.35;
uniform float amount = 1.0;
void fragment() {
	float x = UV.x + (UV.y - 0.5) * slant;
	float b = exp(-pow((x - pos) / width, 2.0));
	float b2 = exp(-pow((x - pos + width * 2.5) / (width * 0.35), 2.0)) * 0.5;
	COLOR = vec4(color.rgb, clamp((b + b2) * amount * color.a, 0.0, 1.0));
}
