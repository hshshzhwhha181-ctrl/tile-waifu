shader_type canvas_item;
// V10Juice: petal sweep. A diagonal wave of sakura petals opens cell by cell — young petals blush pink with a
// darker base and a notched tip, each turning as it grows — then they deepen to plum and close into one
// curtain. progress 0 = clear, 1 = covered. dir = sweep direction in UV. Never brighter than a dusty pink.
uniform float progress = 0.0;
uniform vec2 size = vec2(720.0, 1280.0);
uniform vec2 dir = vec2(0.55, 0.83);
uniform float cell = 96.0;
uniform vec4 blush : source_color = vec4(0.86, 0.56, 0.64, 1.0);
uniform vec4 petal_a : source_color = vec4(0.3, 0.11, 0.19, 1.0);
uniform vec4 petal_b : source_color = vec4(0.13, 0.05, 0.1, 1.0);
uniform vec4 edge : source_color = vec4(0.94, 0.72, 0.76, 1.0);
uniform vec4 gold : source_color = vec4(0.85, 0.68, 0.4, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }

// sakura petal in local coords (tip up, base down), scaled by s: a teardrop with a notch at the tip
float petal(vec2 f, float s, float rot) {
	float c = cos(rot);
	float sn = sin(rot);
	vec2 q = vec2(c * f.x - sn * f.y, sn * f.x + c * f.y) / max(s, 0.0001);
	q.y = -q.y + 0.05;
	float w = 0.62 * clamp(0.55 + q.y * 0.9, 0.18, 1.05);
	float body = length(vec2(q.x / max(w, 0.05) * 0.5, q.y * 0.95)) - 0.5;
	float notch = length(vec2(q.x * 3.2, q.y - 0.5)) - 0.12;
	return max(body, -notch);
}

// modulate (and a parent fade) reaches the output: this shader writes COLOR itself
varying vec4 vcol;
void vertex() { vcol = COLOR; }

void fragment() {
	vec2 p = UV * size;
	vec2 g = p / cell;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	vec2 cuv = (id + 0.5) * cell / size;
	vec2 nd = normalize(dir);
	float along = dot(cuv - 0.5, nd) + 0.62;
	float delay = along * 0.62 + hash(id) * 0.12;
	float t = clamp(progress * 1.95 - delay, 0.0, 1.0);
	float s = t * 2.1;
	float rot = (hash(id + 2.0) - 0.5) * 2.6 + (1.0 - t) * 2.4;
	float d = petal(f, s, rot);
	float inside = 1.0 - smoothstep(-0.015, 0.015, d);
	float solid = smoothstep(0.84, 1.0, t);
	float a = max(inside, solid);
	float rimv = (1.0 - smoothstep(0.0, 0.035, abs(d + 0.02))) * (1.0 - solid) * step(0.01, t);
	// young petals blush, grown ones deepen to plum
	float age = smoothstep(0.15, 0.85, t);
	vec3 young = mix(blush.rgb, blush.rgb * 0.7, clamp(-d * 3.0, 0.0, 1.0));
	vec3 old = mix(petal_a.rgb, petal_b.rgb, clamp(UV.y * 0.8 + length(f) * 0.4, 0.0, 1.0));
	vec3 col = mix(young, old, age);
	col = mix(col, edge.rgb * mix(1.0, 0.55, age), rimv * 0.7);
	col = mix(col, gold.rgb * 0.8, rimv * step(0.88, hash(id + 5.0)) * 0.6);
	COLOR = vec4(col, max(a, rimv * 0.8));
	COLOR *= vcol;
}
