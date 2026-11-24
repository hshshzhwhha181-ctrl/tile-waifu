shader_type canvas_item;
// 0.10 Path: soft drifting fog for Peaks (card, entrance veil). `open` 0 = thick, 1 = parted from the centre.
uniform float open : hint_range(0.0, 1.0) = 0.0;
uniform float density : hint_range(0.0, 1.0) = 0.85;
uniform vec4 tint : source_color = vec4(0.86, 0.88, 0.96, 1.0);
uniform float speed = 0.05;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	float n = fbm(uv * vec2(3.0, 5.0) + vec2(t, t * 0.4)) * 0.65 + fbm(uv * vec2(6.0, 9.0) - vec2(t * 1.6, 0.0)) * 0.35;
	// parting: a hole that grows from the centre outward
	float d = abs(uv.x - 0.5) * 2.0;
	float hole = smoothstep(open * 1.25 - 0.25, open * 1.25 + 0.05, d);
	float a = clamp((n - 0.18) * 1.6, 0.0, 1.0) * density * mix(1.0, hole, step(0.001, open));
	COLOR = vec4(tint.rgb * (0.85 + 0.25 * n), a * tint.a);
}
