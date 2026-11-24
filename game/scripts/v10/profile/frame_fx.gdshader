shader_type canvas_item;
// COLOR in fragment() is already texture × modulate in Godot 4: keep the vertex colour from vertex() instead
varying vec4 vcol;
void vertex() { vcol = COLOR; }
// V10 profile frame recolour + sheen (V10FrameView). Recolours the painted 0.8 avatar frames (frame/avatar,
// frame/avatar_top) by hue masks: antique gold -> `metal`, sakura pink -> `petal`, amethyst -> `violet`
// (alpha 0 = keep the painted colour). Luminance is kept, so the hand-painted shading survives any tint.
// sheen_speed > 0: a slow diagonal glint (animated frames); 0 = static (fx «минимум», league rows).
// flash: one-shot glint position (-1 = off) driven by a tween on tap. desat: locked preview (grey).
uniform vec4 metal : source_color = vec4(0.0);
uniform vec4 petal : source_color = vec4(0.0);
uniform vec4 violet : source_color = vec4(0.0);
uniform float sheen_speed = 0.0;
uniform vec4 sheen_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float sheen_amount = 0.55;
uniform float flash = -1.0;
uniform float desat = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// sakura pink -> the target colour, keeping the painted shading: value scales the colour, the paler (less
// saturated) parts of a petal lean to a lighter tint of it, so highlights stay highlights
vec3 tint_petal(vec3 t, vec3 hsv) {
	vec3 base = t * clamp(hsv.z * 1.06, 0.0, 1.0);
	return mix(base, mix(t, vec3(1.0), 0.6) * hsv.z, clamp((0.45 - hsv.y) * 1.4, 0.0, 0.6));
}

vec3 tint_metal(vec3 t, float v) {
	vec3 c = mix(t * 0.22, t, smoothstep(0.12, 0.78, v));
	return mix(c, mix(t, vec3(1.0), 0.72), smoothstep(0.8, 1.0, v));
}

void fragment() {
	vec4 m = vcol;
	vec4 c = texture(TEXTURE, UV);
	vec3 col = c.rgb;
	vec3 hsv = rgb2hsv(col);
	float h = hsv.x;
	float s = hsv.y;
	float v = hsv.z;
	float gold = smoothstep(0.035, 0.065, h) * (1.0 - smoothstep(0.16, 0.2, h)) * smoothstep(0.1, 0.28, s);
	float pink = max(smoothstep(0.85, 0.9, h), 1.0 - smoothstep(0.015, 0.045, h)) * smoothstep(0.08, 0.22, s);
	float vio = smoothstep(0.64, 0.69, h) * (1.0 - smoothstep(0.85, 0.89, h)) * smoothstep(0.1, 0.22, s);
	if (metal.a > 0.0) col = mix(col, tint_metal(metal.rgb, v), gold * metal.a);
	if (petal.a > 0.0) col = mix(col, tint_petal(petal.rgb, hsv), pink * petal.a);
	if (violet.a > 0.0) col = mix(col, tint_metal(violet.rgb, v), vio * violet.a);
	float shiny = clamp(gold + vio * 0.7 + 0.15, 0.0, 1.0);
	if (sheen_speed > 0.0) {
		float ph = fract(TIME * sheen_speed);
		float pos = ph * 3.2 - 1.0;
		float band = exp(-pow((UV.x * 0.8 + UV.y * 0.6 - pos) / 0.07, 2.0));
		col += sheen_color.rgb * band * sheen_amount * shiny;
	}
	if (flash > -0.9) {
		float band2 = exp(-pow((UV.x * 0.8 + UV.y * 0.6 - flash) / 0.09, 2.0));
		col += sheen_color.rgb * band2 * 0.8 * shiny;
	}
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(g) * vec3(0.82, 0.8, 0.86), desat);
	// the painted halo of frame/avatar_top ends at the texture's square edge: fade it out there, and keep
	// half-transparent halo pixels quieter so a light recolour never shows a pale square
	float edge = smoothstep(0.0, 0.07, min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y)));
	float alpha = c.a * edge * mix(0.5, 1.0, smoothstep(0.3, 0.75, c.a));
	COLOR = vec4(col, alpha) * m;
}
