shader_type canvas_item;
render_mode blend_add;
// V10Juice: expanding ripple (gold ripple of a match, chest / crest shock ring). t 0..1 drives radius and fade.
// Two rings (main + echo) with a shimmering caustic band. Additive and capped: a warm ripple, never a white disc.
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.38, 1.0);
uniform float t = 0.0;
uniform float thickness = 0.06;
uniform float echo = 0.55;
uniform float shimmer = 1.0;

// modulate (and a parent fade) reaches the output: this shader writes COLOR itself
varying vec4 vcol;
void vertex() { vcol = COLOR; }

void fragment() {
	vec2 q = UV - 0.5;
	float d = length(q) * 2.0;
	float ang = atan(q.y, q.x);
	float e = 1.0 - pow(1.0 - t, 3.0);
	float r = e * 0.95;
	float fade = (1.0 - t) * (1.0 - t);
	float th = thickness * (0.6 + 0.8 * (1.0 - t));
	float ring = exp(-pow((d - r) / th, 2.0));
	float r2 = e * 0.95 * 0.72;
	float ring2 = exp(-pow((d - r2) / (th * 0.6), 2.0)) * echo;
	float caus = 0.75 + 0.25 * sin(ang * 22.0 + t * 18.0) * shimmer;
	float inner = (1.0 - smoothstep(0.0, r, d)) * 0.12 * (1.0 - t);
	float a = clamp((ring * caus + ring2 + inner) * fade, 0.0, 0.8);
	COLOR = vec4(color.rgb * a, a);
	COLOR *= vcol;
}
