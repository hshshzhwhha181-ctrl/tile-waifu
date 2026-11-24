shader_type canvas_item;
// v10:look — heroine art that leaves the frame softly (magazine cover, UX §6.8): the left edge and the bottom
// dissolve into the menu background instead of showing the card's rectangle.
uniform float left = 0.22;   // share of the width that fades in from the left edge
uniform float bottom = 0.18; // share of the height that fades out toward the bottom
uniform float top = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = smoothstep(0.0, left, UV.x) * (1.0 - smoothstep(1.0 - bottom, 1.0, UV.y));
	if (top > 0.0) { a *= smoothstep(0.0, top, UV.y); }
	COLOR = vec4(c.rgb, c.a * a) * COLOR;
}
