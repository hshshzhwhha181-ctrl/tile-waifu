shader_type canvas_item;
// V10Juice: soft outer glow around a texture's silhouette (12 taps on a ring, 2 radii), plus an optional pulse.
// The texture needs transparent margin for the glow to show (a heroine cut-out, a crest, an icon).
uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.36, 1.0);
uniform float radius = 10.0;
uniform float strength = 0.9;
uniform float pulse = 0.0;
uniform float pulse_speed = 2.4;

void fragment() {
	vec4 c = COLOR; // Godot 4: COLOR already holds texture × modulate
	vec2 px = TEXTURE_PIXEL_SIZE;
	float a = 0.0;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * 0.5236;
		vec2 d = vec2(cos(ang), sin(ang));
		a += texture(TEXTURE, UV + d * px * radius).a;
		a += texture(TEXTURE, UV + d * px * radius * 0.5).a * 0.8;
	}
	a = clamp(a / 13.0, 0.0, 1.0);
	float k = strength * (1.0 - pulse * 0.5 + pulse * 0.5 * sin(TIME * pulse_speed * 6.2832));
	float g = a * (1.0 - c.a) * k;
	COLOR = vec4(mix(glow_color.rgb, c.rgb, c.a), clamp(c.a + g * glow_color.a, 0.0, 1.0));
}
