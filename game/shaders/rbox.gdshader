shader_type canvas_item;
varying vec4 vcol;
void vertex() { vcol = COLOR; }
// Rounded box with gradient fill, gold gradient border, inner highlight, gloss, shine sweep and drop shadow.
uniform vec2 size = vec2(200.0, 80.0);
uniform float margin = 14.0;
uniform float radius = 30.0;
uniform vec4 top_color : source_color = vec4(1.0, 0.72, 0.82, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.95, 0.45, 0.62, 1.0);
uniform float border = 4.0;
uniform vec4 border_top : source_color = vec4(0.97, 0.89, 0.66, 1.0); // v06:hud antique gold
uniform vec4 border_bottom : source_color = vec4(0.62, 0.45, 0.2, 1.0);
uniform float inner_line = 2.0;
uniform vec4 inner_color : source_color = vec4(1.0, 0.95, 0.88, 0.22);
uniform float gloss = 0.16;
uniform float shine_pos = -1.0;
uniform float pressed = 0.0;
uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.03, 0.02, 0.03, 0.42);
uniform vec2 shadow_offset = vec2(0.0, 6.0);
uniform float shadow_blur = 10.0;
uniform float pattern = 0.0; // faint lattice pattern (v06:hud)
uniform float grain = 1.0; // v06:hud subtle film grain so flat fills read as material

float sd_rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * size;
	vec2 c = size * 0.5;
	vec2 hb = max(c - vec2(margin), vec2(1.0));
	float r = min(radius, min(hb.x, hb.y));
	float d = sd_rbox(p - c, hb, r);
	float aa = max(fwidth(d), 0.6);
	float ds = sd_rbox(p - c - shadow_offset, hb, r);
	float sh = (1.0 - smoothstep(-shadow_blur * 0.4, shadow_blur, ds)) * shadow_color.a;
	float gl = glow * exp(-max(d, 0.0) / 9.0) * step(0.0, d);
	float ty = clamp((p.y - (c.y - hb.y)) / (2.0 * hb.y), 0.0, 1.0);
	float tx = clamp((p.x - (c.x - hb.x)) / (2.0 * hb.x), 0.0, 1.0);
	vec3 body = mix(top_color.rgb, bottom_color.rgb, ty);
	// v06:hud: quiet asanoha-like lattice + top rim light + grain instead of candy stripes
	vec2 lp = p / 22.0;
	float lat = max(1.0 - smoothstep(0.0, 0.08, abs(fract(lp.x + lp.y) - 0.5)), 1.0 - smoothstep(0.0, 0.08, abs(fract(lp.x - lp.y) - 0.5)));
	body += pattern * 0.022 * lat;
	body += vec3(0.07) * (1.0 - smoothstep(0.0, 10.0, -d - border)) * (1.0 - smoothstep(0.0, 0.25, ty));
	body += grain * (fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.018;
	float g = gloss * (1.0 - smoothstep(0.0, 0.5, ty)) * smoothstep(0.0, 6.0, -d - border);
	body = mix(body, vec3(1.0), g * 0.55);
	float sx = tx + (ty - 0.5) * 0.25 * (2.0 * hb.y) / (2.0 * hb.x);
	body += vec3(exp(-pow((sx - shine_pos) / 0.07, 2.0)) * 0.42);
	body *= 1.0 - pressed * 0.14;
	vec3 bcol = mix(border_top.rgb, border_bottom.rgb, smoothstep(0.0, 1.0, ty));
	bcol += vec3(0.25) * (1.0 - smoothstep(0.0, 0.35, ty));
	float in_border = border > 0.0 ? smoothstep(-border - aa, -border + aa, d) : 0.0;
	vec3 fill = mix(body, bcol, in_border);
	float il = (1.0 - smoothstep(inner_line * 0.5, inner_line * 0.5 + aa, abs(d + border + inner_line * 0.5 + 0.5))) * inner_color.a;
	fill = mix(fill, inner_color.rgb, il * (1.0 - in_border) * step(0.01, inner_line));
	float body_a = (1.0 - smoothstep(-aa, aa, d));
	float fa = mix(top_color.a, bottom_color.a, ty);
	float a = body_a * max(fa, in_border * border_top.a);
	vec4 under = vec4(mix(shadow_color.rgb, glow_color.rgb, clamp(gl * 3.0, 0.0, 1.0)), max(sh, gl));
	vec3 rgb = mix(under.rgb, fill, a);
	float outa = a + under.a * (1.0 - a);
	COLOR = vec4(rgb, outa) * vcol;
}
