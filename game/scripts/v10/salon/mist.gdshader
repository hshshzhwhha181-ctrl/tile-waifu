shader_type canvas_item;

// Dust and mist over the unrestored part of a salon zone (spec §Р1 п.3). `amount` follows how ruined the zone is
// (1 = untouched, 0 = finished). Drifting fbm haze + slow dust motes catching the light. At fx «mid/min» the
// owner sets `still = 1`: the same picture, frozen (a static texture in effect).

uniform float amount = 1.0;
uniform float still = 0.0;
uniform float time_s = 0.0;
uniform vec4 tint : source_color = vec4(0.62, 0.64, 0.72, 1.0);
uniform vec2 aspect = vec2(1.34, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void fragment() {
	float t = time_s * (1.0 - still);
	vec2 p = UV * aspect * 2.4;
	float m = fbm(p + vec2(t * 0.035, t * 0.012));
	m = smoothstep(0.38, 0.85, m + 0.18 * fbm(p * 2.0 - vec2(t * 0.05, 0.0)));
	// heavier near the floor and the edges
	float edge = smoothstep(0.35, 1.0, UV.y) * 0.5 + smoothstep(0.25, 0.0, UV.x) * 0.25 + smoothstep(0.75, 1.0, UV.x) * 0.25;
	float haze = (m * 0.55 + edge * 0.35) * amount;
	// dust motes: sparse cells, each mote drifts and twinkles
	vec2 g = UV * aspect * 26.0 + vec2(t * 0.25, -t * 0.4);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float h = hash(cell);
	vec2 mp = vec2(hash(cell + 3.1), hash(cell + 7.7));
	float mote = smoothstep(0.09, 0.0, length(f - mp)) * step(0.86, h);
	mote *= 0.5 + 0.5 * sin(t * (1.5 + h * 3.0) + h * 40.0);
	vec3 col = tint.rgb;
	float a = clamp(haze * 0.62 + mote * 0.55 * amount, 0.0, 0.85);
	COLOR = vec4(mix(col, vec3(1.0, 0.95, 0.85), mote), a);
}
