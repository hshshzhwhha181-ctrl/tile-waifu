shader_type canvas_item;
// v06:flip — back of a face-down tile. ready = free and waiting for a tap: the crest breathes
// and a soft light sweep crosses the lacquer every few seconds. flash = warm glaze at the flip midpoint (capped, never a white-out).
varying vec4 vcol;
void vertex() { vcol = COLOR; }
uniform float ready = 0.0;
uniform float phase = 0.0;
uniform float flash = 0.0;
uniform float shine = -1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 col = c.rgb * vcol.rgb;
	float t = TIME + phase;
	float pulse = 0.5 + 0.5 * sin(t * 3.4);
	float d = distance(UV, vec2(0.5, 0.49));
	col += ready * pulse * vec3(1.0, 0.82, 0.45) * smoothstep(0.3, 0.05, d) * 0.28;
	// periodic diagonal sweep while ready, plus a manual one (shine)
	float sw = fract(t * 0.42) * 3.2 - 0.8;
	float band = exp(-pow((UV.x + UV.y * 0.55 - sw) / 0.08, 2.0)) * ready * 0.32;
	band += exp(-pow((UV.x + UV.y * 0.55 - shine) / 0.09, 2.0)) * 0.45;
	col += band * vec3(1.0, 0.96, 0.86);
	col = mix(col, col * 0.7 + vec3(1.0, 0.8, 0.52) * 0.5, clamp(flash, 0.0, 1.0) * 0.45);
	COLOR = vec4(col, c.a * vcol.a);
}
