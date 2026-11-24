shader_type canvas_item;
// Washi paper for letters: warm base, long fibres, faint gold flecks, soft vignette. Pure code (0 credits).
uniform vec4 base : source_color = vec4(0.94, 0.89, 0.81, 1.0);
uniform vec2 rect_size = vec2(640.0, 900.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0)), c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 px = UV * rect_size;
	float fib = noise(vec2(px.x * 0.02, px.y * 0.6)) * 0.5 + noise(vec2(px.x * 0.6, px.y * 0.02)) * 0.5;
	float grain = noise(px * 0.35);
	vec3 col = base.rgb * (0.95 + 0.05 * grain) - vec3(0.035) * smoothstep(0.62, 0.9, fib);
	float fleck = step(0.996, hash(floor(px / 3.0)));
	col = mix(col, vec3(0.86, 0.7, 0.4), fleck * 0.6);
	vec2 q = UV - 0.5;
	col *= 1.0 - dot(q, q) * 0.35;
	COLOR = vec4(col, base.a) * COLOR;
}
