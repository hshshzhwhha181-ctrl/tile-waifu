shader_type canvas_item;
render_mode blend_add;
// V10Juice: aura around a rounded frame (fever around the board, ult-ready heartbeat around a button).
// The rect this sits on is the inner frame grown by `pad` px on every side. Everything inside the frame
// (minus `inset` px) is untouched: the board never gets covered. Additive, capped by `intensity`.
//   mode 0 = fever flames licking outward; mode 1 = smooth glow (heartbeat), beat drives the strength.
uniform vec2 size = vec2(700.0, 900.0);
uniform float pad = 48.0;
uniform float radius = 26.0;
uniform float inset = 6.0;
uniform vec4 color_a : source_color = vec4(1.0, 0.45, 0.14, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.78, 0.3, 1.0);
uniform float intensity = 0.8;
uniform float speed = 1.0;
uniform int mode = 0;
uniform float beat = 1.0;
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
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}
float sd_rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 full = size + vec2(pad * 2.0);
	vec2 p = UV * full - full * 0.5;
	float d = sd_rbox(p, size * 0.5, radius);
	if (d < -inset) {
		COLOR = vec4(0.0);
	} else {
		float t = TIME * speed;
		float od = max(d, 0.0) / pad;
		float g;
		vec3 col;
		if (mode == 0) {
			// outward normal of the box and a coordinate running along the edge
			vec2 q = p - clamp(p, -size * 0.5 + radius, size * 0.5 - radius);
			vec2 nrm = length(q) > 0.001 ? normalize(q) : vec2(0.0, -1.0);
			float along = (p.x + p.y * 1.3) / 60.0;
			float n = fbm(vec2(along * 1.4 + seed, od * 2.6 - t * 1.6) + nrm * 0.6);
			float tongue = smoothstep(0.25, 0.85, n + 0.5 - od * 1.2);
			float base = exp(-od * 4.0);
			g = clamp(tongue * (1.0 - od) * 0.9 + base * 0.55, 0.0, 1.0);
			// a hairline just inside the frame edge
			g += (1.0 - smoothstep(0.0, inset, abs(d + inset * 0.4))) * 0.35;
			col = mix(color_a.rgb, color_b.rgb, clamp(1.0 - od * 1.6 + n * 0.3, 0.0, 1.0));
			g *= 0.85 + 0.15 * sin(t * 7.0 + along);
		} else {
			float base = exp(-od * 3.2);
			float ring = exp(-pow((od - 0.08) / 0.12, 2.0));
			g = (base * 0.7 + ring * 0.5) * beat;
			g += (1.0 - smoothstep(0.0, inset, abs(d + inset * 0.4))) * 0.4 * (0.5 + 0.5 * beat);
			col = mix(color_a.rgb, color_b.rgb, ring);
		}
		g *= (1.0 - smoothstep(0.85, 1.0, od));
		COLOR = vec4(col * intensity, clamp(g, 0.0, 1.0) * intensity);
	}
}
