shader_type canvas_item;
// V10Juice: fake bloom for GL Compatibility (no post-processing, no SCREEN_TEXTURE). Bright parts of the item's own
// texture are blurred with 16 taps (two rings) and added back, tinted warm. No chromatic aberration.
// The added light is capped (cap) so highlights glow instead of clipping to white.
uniform float threshold = 0.62;
uniform float intensity = 0.55;
uniform float spread = 6.0;
uniform float cap = 0.28;
uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.7, 1.0);

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec4 c = COLOR; // Godot 4: COLOR already holds texture × modulate
	vec2 px = TEXTURE_PIXEL_SIZE * spread;
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7854;
		vec2 d = vec2(cos(ang), sin(ang));
		vec4 s1 = texture(TEXTURE, UV + d * px);
		vec4 s2 = texture(TEXTURE, UV + d * px * 2.2 + d.yx * px * 0.4);
		acc += s1.rgb * s1.a * max(0.0, lum(s1.rgb) - threshold);
		acc += s2.rgb * s2.a * max(0.0, lum(s2.rgb) - threshold) * 0.6;
	}
	vec3 b = acc / (8.0 * 1.6) / max(0.001, 1.0 - threshold) * intensity * tint.rgb;
	c.rgb += min(b, vec3(cap));
	COLOR = c;
}
