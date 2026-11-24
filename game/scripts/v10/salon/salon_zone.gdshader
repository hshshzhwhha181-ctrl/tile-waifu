shader_type canvas_item;

// One salon zone: the ruined art with the restored art revealed inside the task rects (V10SalonZone).
// Rects are listed back → front; a pixel takes the state of the front-most rect that covers it (soft edges
// blend), so a stool keeps its ruined look in front of a restored counter until the stool is restored.
// Per rect: prog (reveal 0..1, an ink bleed from the rect centre with a noisy edge), jade (Нефрит finish 0..1),
// pop (x: drop in uv, y: scale — the object «falls» 40 px and springs 1.08 → 1.0), glint (sheen sweep 0..1).
// finale: the light wave from the bottom up (0..1) that also restores what no task covers (sky, walls, floor).

#define MAXR 24

uniform sampler2D broken : source_color, filter_linear_mipmap;
uniform sampler2D done : source_color, filter_linear_mipmap;
uniform vec4 rects[MAXR];
uniform float prog[MAXR];
uniform float jade[MAXR];
uniform vec2 pop[MAXR];
uniform float glint[MAXR];
uniform int count = 0;
uniform float finale = 0.0;
uniform float feather = 0.06;
uniform float dim = 0.0;          // locked / far zones: darken
uniform float desat = 0.0;
uniform float time_s = 0.0;
uniform vec4 crop = vec4(0.0, 0.0, 1.0, 1.0);  // sub-rect of the art shown by this node (cover fit)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { return 0.55 * vnoise(p) + 0.3 * vnoise(p * 2.1) + 0.15 * vnoise(p * 4.3); }

void fragment() {
	vec2 uv = crop.xy + UV * crop.zw;
	vec4 base = texture(broken, uv);
	float reveal = 0.0;
	float jd = 0.0;
	float gl = 0.0;
	vec2 duv = uv;
	float n = fbm(uv * vec2(18.0, 13.0));
	for (int i = 0; i < MAXR; i++) {
		if (i >= count) break;
		vec4 r = rects[i];
		vec2 l = (uv - r.xy) / r.zw;
		vec2 fe = vec2(feather) / max(r.zw, vec2(0.02)) * 0.35;
		float e = smoothstep(0.0, fe.x, l.x) * smoothstep(0.0, fe.x, 1.0 - l.x)
				* smoothstep(0.0, fe.y, l.y) * smoothstep(0.0, fe.y, 1.0 - l.y);
		if (e <= 0.0) continue;
		float dr = length((l - 0.5) * 2.0) * 0.7071;
		float th = dr * 0.68 + n * 0.32;
		float v = smoothstep(th - 0.06, th + 0.06, prog[i] * 1.12);
		reveal = mix(reveal, v, e);
		jd = mix(jd, jade[i] * v, e);
		vec2 c = r.xy + r.zw * 0.5;
		vec2 puv = c + (uv - c) / max(pop[i].y, 0.01) - vec2(0.0, pop[i].x);
		duv = mix(duv, puv, e * step(0.0001, abs(pop[i].x) + abs(pop[i].y - 1.0)));
		if (glint[i] > 0.0 && glint[i] < 1.0) {
			float s = (l.x + l.y) * 0.5;
			float pos = glint[i] * 1.5 - 0.25;
			gl = max(gl, e * v * exp(-pow((s - pos) / 0.05, 2.0)) * sin(glint[i] * 3.14159));
		}
	}
	// the finale wave: a warm band climbing from the bottom; above it the zone is still as it was
	float fy = 1.12 - finale * 1.3;
	float w = smoothstep(fy - 0.05, fy + 0.05, uv.y);
	reveal = max(reveal, w * step(0.001, finale));
	vec4 d = texture(done, duv);
	// Нефрит: object surfaces (saturated pixels) take a jade glaze with a slow sheen; walls and air stay
	float lum = dot(d.rgb, vec3(0.299, 0.587, 0.114));
	float sat = max(max(d.r, d.g), d.b) - min(min(d.r, d.g), d.b);
	float jm = jd * smoothstep(0.06, 0.24, sat);
	vec3 jcol = vec3(lum) * vec3(0.66, 1.06, 0.86) + vec3(0.02, 0.07, 0.05);
	jcol += vec3(0.55, 0.85, 0.7) * 0.12 * pow(max(0.0, sin(uv.x * 9.0 - uv.y * 4.0 + time_s * 0.9)), 8.0);
	d.rgb = mix(d.rgb, mix(d.rgb, jcol, 0.62), jm);
	vec4 col = mix(base, d, reveal);
	col.rgb += vec3(1.0, 0.86, 0.6) * gl * 0.55;
	float band = exp(-pow((uv.y - fy) / 0.035, 2.0)) * step(0.001, finale) * step(finale, 0.999);
	col.rgb += vec3(1.0, 0.78, 0.5) * band * 0.45;
	float g = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(col.rgb, vec3(g), desat);
	col.rgb *= 1.0 - dim;
	COLOR = vec4(col.rgb, 1.0) * COLOR;
}
