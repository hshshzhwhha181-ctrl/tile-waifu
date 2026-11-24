shader_type canvas_item;
// V10Juice: noise dissolve with a burning (warm, never white) edge. amount 0 = fully visible, 1 = gone.
// Use reveal = true to run it backwards (materialise). Works on Sprite2D / TextureRect / any textured item.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width = 0.045;
uniform vec4 edge_color : source_color = vec4(0.86, 0.32, 0.16, 1.0);
uniform vec4 edge_core : source_color = vec4(1.0, 0.7, 0.36, 1.0);
uniform float scale = 6.0;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec4 c = COLOR; // Godot 4: COLOR already holds texture × modulate
	float n = fbm(UV * scale + seed) * 0.85 + (1.0 - UV.y) * 0.15;
	float th = amount * (1.0 + edge_width * 2.0) - edge_width;
	float keep = smoothstep(th, th + 0.01, n);
	float e = (1.0 - smoothstep(0.0, edge_width, n - th)) * step(th, n) * step(0.001, amount) * step(amount, 0.999);
	vec3 ec = mix(edge_color.rgb, edge_core.rgb, 1.0 - smoothstep(0.0, edge_width * 0.4, n - th));
	c.rgb = mix(c.rgb, ec, e * 0.85);
	c.a *= max(keep, e * c.a);
	COLOR = c;
}
