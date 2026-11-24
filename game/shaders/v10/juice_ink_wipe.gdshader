shader_type canvas_item;
// V10Juice: ink-wash wipe between tabs. Sumi ink blooms from `origin` (UV, may lie outside 0..1) across rice paper,
// with a feathered bleeding front, pooled darker edge, a few droplets ahead of the front and a faint warm sheen.
// progress 0 = clear, 1 = fully covered. No light is added: the screen only darkens (no white flash).
uniform float progress = 0.0;
uniform vec2 size = vec2(720.0, 1280.0);
uniform vec2 origin = vec2(0.5, 1.12);
uniform float seed = 0.0;
uniform vec4 ink : source_color = vec4(0.075, 0.062, 0.085, 1.0);
uniform vec4 ink_deep : source_color = vec4(0.03, 0.022, 0.04, 1.0);
uniform vec4 sheen : source_color = vec4(0.55, 0.36, 0.42, 1.0);
uniform vec4 rim : source_color = vec4(0.82, 0.66, 0.4, 1.0);

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
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float asp = size.x / size.y;
	vec2 p = vec2(UV.x * asp, UV.y);
	vec2 o = vec2(origin.x * asp, origin.y);
	float d = length(p - o);
	// farthest corner from the origin
	float far = max(max(length(vec2(0.0, 0.0) - o), length(vec2(asp, 0.0) - o)), max(length(vec2(0.0, 1.0) - o), length(vec2(asp, 1.0) - o)));
	float n = fbm(p * 3.2 + seed);
	float n2 = fbm(p * 11.0 - seed * 1.3);
	float field = d + (n - 0.5) * 0.42 + (n2 - 0.5) * 0.08;
	float r = progress * (far + 0.32) - 0.02;
	float inside = 1.0 - smoothstep(r - 0.006, r + 0.006, field);
	// feathered bleed into the paper ahead of the front
	float ahead = field - r;
	float bleed = (1.0 - smoothstep(0.0, 0.05, ahead)) * step(0.0, ahead) * smoothstep(0.35, 0.75, n2) * 0.65;
	// droplets flicked ahead of the front
	vec2 cell = floor(p * 26.0);
	vec2 fc = fract(p * 26.0) - 0.5;
	float h = hash(cell + seed);
	float drop = (1.0 - smoothstep(0.12, 0.2, length(fc + (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.4)))
		* step(0.93, h) * step(0.0, ahead) * (1.0 - smoothstep(0.03, 0.13, ahead));
	float a = clamp(max(inside, max(bleed, drop * 0.9)), 0.0, 1.0);
	// pooled darker edge just behind the front, sheen in the wet middle
	float behind = r - field;
	float pool = (1.0 - smoothstep(0.0, 0.06, behind)) * inside;
	vec3 col = mix(ink.rgb, ink_deep.rgb, clamp(pool * 0.9 + (1.0 - n) * 0.35, 0.0, 1.0));
	col = mix(col, sheen.rgb * 0.32, smoothstep(0.55, 0.85, n) * 0.35 * (1.0 - pool));
	// a hairline of warm light on the very front while it moves (fades out when fully covered)
	float front = (1.0 - smoothstep(0.0, 0.012, abs(behind - 0.008))) * (1.0 - smoothstep(0.85, 1.0, progress)) * step(0.01, progress);
	col = mix(col, rim.rgb * 0.8, front * 0.55);
	// rice-paper fibres
	col += 0.012 * (vnoise(p * vec2(260.0, 40.0)) - 0.5);
	COLOR = vec4(col, a);
}
