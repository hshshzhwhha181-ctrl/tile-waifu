shader_type canvas_item;
// Mastery I palettes (spec Г8): hue shift + saturation + value on the outfit art. Skin tones are protected by
// a soft mask on warm low-saturation pixels so only the costume recolours.
uniform float hue = 0.0;
uniform float sat = 1.0;
uniform float val = 1.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec3 h = rgb2hsv(col.rgb);
	// skin: hue 0.0–0.11, saturation 0.12–0.55, bright → keep
	float skin = smoothstep(0.13, 0.08, h.x) * smoothstep(0.08, 0.16, h.y) * smoothstep(0.62, 0.5, h.y) * smoothstep(0.45, 0.65, h.z);
	vec3 n = vec3(fract(h.x + hue), clamp(h.y * sat, 0.0, 1.0), clamp(h.z * val, 0.0, 1.0));
	col.rgb = mix(hsv2rgb(n), col.rgb, skin);
	COLOR = col * COLOR;
}
