shader_type canvas_item;
render_mode blend_add;
// V10Juice: diagonal sheen band clipped to a rounded rect (premium buttons, cards). pos -0.4..1.4 drives one
// pass; with period > 0 it repeats by itself. Additive and capped by color.a — a sheen, never a flash.
uniform vec4 color : source_color = vec4(1.0, 0.88, 0.6, 0.5);
uniform float pos = -0.4;
uniform float width = 0.08;
uniform float slant = 0.45;
uniform vec2 size = vec2(300.0, 100.0);
uniform float radius = 20.0;
uniform float period = 0.0;
uniform float pause = 0.65;

float sd_rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	float p = pos;
	if (period > 0.0) {
		float ph = fract(TIME / period);
		p = mix(-0.4, 1.4, clamp(ph / max(0.05, 1.0 - pause), 0.0, 1.0));
	}
	vec2 q = UV * size - size * 0.5;
	float inside = 1.0 - smoothstep(-1.0, 1.0, sd_rbox(q, size * 0.5, radius));
	float x = UV.x + (UV.y - 0.5) * slant * size.y / max(size.x, 1.0) * 2.0;
	float b = exp(-pow((x - p) / width, 2.0)) + 0.45 * exp(-pow((x - p + width * 2.6) / (width * 0.3), 2.0));
	float a = clamp(b * color.a * inside, 0.0, 0.6);
	COLOR = vec4(color.rgb * a, a);
}
