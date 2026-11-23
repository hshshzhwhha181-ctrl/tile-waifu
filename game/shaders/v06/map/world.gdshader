shader_type canvas_item;
// v06:map — one world panel of the vertical map: fades into the world below, locked worlds are
// desaturated under drifting fog, open worlds get a slow light sweep.
varying vec4 vcol;
void vertex() { vcol = COLOR; }
uniform vec2 size = vec2(720.0, 1500.0);
uniform float fade_bottom = 180.0;
uniform float fade_top = 0.0;
uniform float gray = 0.0;
uniform float bright = 1.0;
uniform vec4 fog : source_color = vec4(1.0, 0.9, 0.95, 1.0);
uniform float fog_amt = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 col = c.rgb;
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(lum) * vec3(0.92, 0.9, 1.0), gray) * bright;
	vec2 px = UV * size;
	if (fog_amt > 0.0) {
		float n = fbm(px / 260.0 + vec2(TIME * 0.03, TIME * 0.012));
		float n2 = fbm(px / 140.0 - vec2(TIME * 0.02, 0.0));
		float f = smoothstep(0.35, 0.8, n * 0.7 + n2 * 0.45);
		col = mix(col, fog.rgb, f * fog_amt);
	} else {
		float sweep = UV.x * 0.4 + UV.y * 0.6 - fract(TIME * 0.05) * 2.0 + 0.5;
		col += vec3(1.0, 0.95, 0.85) * pow(max(0.0, 1.0 - abs(sweep) * 6.0), 3.0) * 0.06;
	}
	float a = smoothstep(0.0, fade_bottom, size.y - px.y);
	if (fade_top > 0.0) a *= smoothstep(0.0, fade_top, px.y);
	COLOR = vec4(col, c.a * a) * vcol;
}
