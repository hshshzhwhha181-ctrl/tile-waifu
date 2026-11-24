shader_type canvas_item;
// V10Juice: vermilion hanko seal (combo stamp, rank crest base). A rounded square frame + inner field, eroded
// by paper-grain noise like a real stamp impression. The text sits on top as a Label.
uniform vec4 color : source_color = vec4(0.78, 0.16, 0.14, 1.0);
uniform float frame = 0.1;
uniform float erosion = 0.32;
uniform float seed = 0.0;
uniform float fill = 0.55;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float sd_rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// modulate (and a parent fade) reaches the output: this shader writes COLOR itself
varying vec4 vcol;
void vertex() { vcol = COLOR; }

void fragment() {
	vec2 p = UV - 0.5;
	float d = sd_rbox(p, vec2(0.44), 0.07);
	float outer = 1.0 - smoothstep(-0.005, 0.005, d);
	float inner_edge = 1.0 - smoothstep(-0.005, 0.005, d + frame);
	float frame_m = outer - inner_edge * (1.0 - smoothstep(-0.005, 0.005, d + frame + 0.035));
	float field = (1.0 - smoothstep(-0.005, 0.005, d + frame + 0.035)) * fill;
	float n = vnoise(UV * 18.0 + seed) * 0.6 + vnoise(UV * 60.0 - seed) * 0.4;
	float ink = clamp(max(frame_m, field), 0.0, 1.0) * smoothstep(erosion - 0.08, erosion + 0.08, n + 0.25);
	COLOR = vec4(color.rgb * (0.9 + 0.1 * n), ink * color.a);
	COLOR *= vcol;
}
