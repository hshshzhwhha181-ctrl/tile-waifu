shader_type canvas_item;

// HUD v2 table felt (docs/HUD_V2.md §8.1, §9.2 №5): no frame, the cloth runs under the board edge.
// Soft vignette from a focus point + two-octave fibre grain. Static (no animation).

uniform vec4 hi : source_color = vec4(0.11, 0.29, 0.23, 1.0);
uniform vec4 lo : source_color = vec4(0.043, 0.13, 0.106, 1.0);
uniform vec2 size_px = vec2(720.0, 900.0);
uniform vec2 focus = vec2(0.5, 0.42);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 asp = vec2(size_px.x / max(size_px.y, 1.0), 1.0);
	float d = length((UV - focus) * asp);
	float v = smoothstep(0.05, 0.85, d);
	vec3 c = mix(hi.rgb, lo.rgb, v);
	vec2 px = UV * size_px;
	float n = hash(floor(px)) * 0.55 + hash(floor(px * 0.5) + 3.1) * 0.45;
	float fib = hash(vec2(floor(px.x * 0.25), floor(px.y * 2.0)));  // faint horizontal nap
	c += (n - 0.5) * 0.03 + (fib - 0.5) * 0.012;
	COLOR = vec4(c, 1.0);
}
