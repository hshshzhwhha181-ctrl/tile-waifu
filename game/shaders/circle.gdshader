shader_type canvas_item;
// Procedural magic circle (rings, runes, hexagram) with glow and spin.
uniform vec4 color : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float power = 0.5;
uniform float spin = 0.2;
float ring(float r, float rad, float w) { return exp(-pow((r - rad) / w, 2.0)); }
float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return exp(-pow(length(pa - ba * h) / w, 2.0));
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = TIME * spin;
	float v = 0.0;
	v += ring(r, 0.95, 0.012) + ring(r, 0.88, 0.008) + ring(r, 0.62, 0.01) + ring(r, 0.30, 0.012);
	// rune ticks between 0.88 and 0.95
	float ticks = step(0.5, fract((a + t) * 48.0 / 6.2831)) * step(0.885, r) * step(r, 0.945);
	v += ticks * 0.45 * (0.5 + 0.5 * sin(a * 12.0 + t * 8.0));
	// hexagram rotating
	float ang = -t * 1.6;
	for (int i = 0; i < 6; i++) {
		float a0 = ang + float(i % 3) * 2.0944 + (i >= 3 ? 1.0472 : 0.0);
		float a1 = a0 + 2.0944;
		v += seg(p, 0.62 * vec2(cos(a0), sin(a0)), 0.62 * vec2(cos(a1), sin(a1)), 0.008) * 0.9;
	}
	// small orbit dots
	for (int i = 0; i < 8; i++) {
		float aa = t * 2.0 + float(i) * 0.7854;
		v += exp(-pow(length(p - 0.75 * vec2(cos(aa), sin(aa))) / 0.035, 2.0)) * 0.8;
	}
	v += exp(-r * r * 6.0) * 0.35;
	v *= smoothstep(1.0, 0.96, r);
	float glow = v * (0.35 + power * 1.4);
	vec3 col = mix(color.rgb, vec3(1.0), clamp(v * power * 0.5, 0.0, 0.4));
	COLOR = vec4(col, clamp(glow, 0.0, 1.0) * color.a);
}
