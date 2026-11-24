shader_type canvas_item;

// V10KeyArt: one soft diagonal light sweep across the heroines (masked by the cut-out's alpha), plus a warm
// rim lift from the lanterns. pos runs -0.4 → 1.9 once every few seconds; strength follows S.fx_level.
uniform float pos = -1.0;
uniform float width = 0.11;
uniform float strength = 0.32;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.74, 1.0);
uniform float lift = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = (UV.x * 0.8 + UV.y * 0.6) - pos;
	float band = exp(-(d * d) / (width * width));
	c.rgb += tint.rgb * band * strength * c.a;
	c.rgb *= 1.0 + lift;
	COLOR = c * COLOR;
}
