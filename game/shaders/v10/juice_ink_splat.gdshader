shader_type canvas_item;
// V10Juice: ink splash of a suit colour. A noisy blot with spiky arms and satellite droplets that bursts out
// (t 0..0.25), then soaks into the paper and fades (t 0.25..1). Normal blend, mid-tone colours: it reads on the
// light tray and on the dark table and never brightens the screen.
uniform vec4 color : source_color = vec4(0.18, 0.55, 0.42, 1.0);
uniform vec4 rim : source_color = vec4(0.9, 0.78, 0.5, 1.0);
uniform float t = 0.0;
uniform float seed = 0.0;
uniform float alpha = 0.85;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float d = length(q);
	float ang = atan(q.y, q.x);
	float grow = 1.0 - pow(1.0 - clamp(t / 0.25, 0.0, 1.0), 3.0);
	// spiky arms: angular noise
	float arms = vnoise(vec2(ang * 3.2 + seed, seed * 2.0)) * 0.55 + vnoise(vec2(ang * 9.0 - seed, 4.0)) * 0.25;
	float rad = (0.28 + arms * 0.5) * grow;
	float wobble = (vnoise(q * 9.0 + seed) - 0.5) * 0.06;
	float blot = 1.0 - smoothstep(rad - 0.02, rad + 0.02, d + wobble);
	// satellite droplets
	vec2 g = q * 4.2 + seed;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	float dr = (1.0 - smoothstep(0.09, 0.16, length(f + (vec2(hash(id + 1.3), hash(id + 2.9)) - 0.5) * 0.5)))
		* step(0.8, h) * step(d, 0.95 * grow) * step(rad * 0.85, d);
	float m = max(blot, dr);
	float soak = smoothstep(0.25, 1.0, t);
	float edge = (1.0 - smoothstep(0.0, 0.06, abs(d + wobble - rad))) * blot;
	vec3 col = mix(color.rgb, color.rgb * 0.55, edge * 0.8 + (1.0 - d) * 0.15);
	col = mix(col, rim.rgb, (1.0 - smoothstep(0.0, 0.025, abs(d + wobble - rad - 0.01))) * 0.35 * (1.0 - soak));
	float a = m * alpha * (1.0 - soak) * (0.82 + 0.18 * vnoise(q * 22.0));
	COLOR = vec4(col, a);
}
