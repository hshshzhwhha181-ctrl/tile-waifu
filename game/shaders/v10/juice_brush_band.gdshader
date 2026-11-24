shader_type canvas_item;
// V10Juice: calligraphy brush stroke (combo banner backing). The stroke is painted left→right by `reveal`
// (0..1) with dry-brush streaks, a ragged tail and gold flecks; `fade` takes it away (1 = gone, from the tail).
uniform float reveal = 0.0;
uniform float fade = 0.0;
uniform vec4 ink : source_color = vec4(0.09, 0.06, 0.08, 1.0);
uniform vec4 tint : source_color = vec4(0.42, 0.1, 0.16, 1.0);
uniform vec4 fleck : source_color = vec4(0.92, 0.74, 0.42, 1.0);
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// modulate (and a parent fade) reaches the output: this shader writes COLOR itself
varying vec4 vcol;
void vertex() { vcol = COLOR; }

void fragment() {
	vec2 uv = UV;
	// stroke thickness profile: fat at the start, thinner and ragged at the tail
	float prof = mix(0.46, 0.3, smoothstep(0.1, 1.0, uv.x)) + (vnoise(vec2(uv.x * 7.0 + seed, 1.0)) - 0.5) * 0.08;
	float centre = 0.5 + (vnoise(vec2(uv.x * 2.5 + seed, 3.0)) - 0.5) * 0.08;
	float dy = abs(uv.y - centre);
	float body = 1.0 - smoothstep(prof - 0.03, prof + 0.01, dy);
	// round-ish head on the left
	float head = smoothstep(0.0, 0.06, uv.x + (0.5 - dy) * 0.04);
	// dry-brush streaks: long thin gaps that grow toward the tail
	float streak = vnoise(vec2(uv.x * 3.0 + seed, uv.y * 46.0));
	float dry = 1.0 - smoothstep(0.0, 0.55, streak - smoothstep(0.55, 1.0, uv.x) * 0.55 - dy * 0.6);
	dry = mix(1.0, dry, smoothstep(0.35, 1.0, uv.x) + smoothstep(0.25, 0.46, dy));
	float paint = smoothstep(uv.x - 0.02, uv.x + 0.02, reveal * 1.08);
	float gone = smoothstep(1.05 - fade * 1.15 - 0.05, 1.05 - fade * 1.15 + 0.05, uv.x);
	float a = body * head * clamp(dry, 0.0, 1.0) * paint * (1.0 - gone);
	vec3 col = mix(ink.rgb, tint.rgb, smoothstep(0.0, 0.5, 0.5 - dy) * 0.75 + (vnoise(uv * vec2(30.0, 4.0)) - 0.5) * 0.15);
	// bristle streaks: thin lighter lines running along the stroke
	float bristle = smoothstep(0.62, 0.9, vnoise(vec2(uv.x * 2.0 + seed, uv.y * 70.0)));
	col = mix(col, tint.rgb * 1.6, bristle * 0.18 * body);
	// gold leaf flecks: small round dots
	vec2 fg = uv * vec2(70.0, 16.0);
	vec2 fid = floor(fg);
	vec2 ff = fract(fg) - 0.5 + (vec2(hash(fid + 1.7), hash(fid + 4.1)) - 0.5) * 0.5;
	float fl = step(0.9, hash(fid + seed)) * (1.0 - smoothstep(0.16, 0.26, length(ff))) * body;
	col = mix(col, fleck.rgb * 0.9, fl * 0.85);
	COLOR = vec4(col, a * 0.94);
	COLOR *= vcol;
}
