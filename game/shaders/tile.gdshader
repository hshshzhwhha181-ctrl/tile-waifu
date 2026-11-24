shader_type canvas_item;
varying vec4 vcol;
void vertex() { vcol = COLOR; }
// Tile face: blocked dim, select warmth, unlock shine sweep, tinted match glow, ice and gold overlays.
uniform float dim = 0.0;
uniform float sel = 0.0;
uniform float flash = 0.0;
// flash never whites the tile out (HEROINES §2 «без белых вспышек»): a palette glaze capped at 38% + rim glow
uniform vec3 flash_col = vec3(1.0, 0.8, 0.52);
uniform float shine = -1.0;
uniform float ice = 0.0;
uniform float gold = 0.0;
uniform float shade = 1.0;
uniform float neon = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 col = c.rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum) * vec3(0.97, 0.95, 1.0), dim * 0.32);
	col *= 1.0 - dim * 0.2;
	col *= shade;
	col = mix(col, col * 1.06 + vec3(0.08, 0.05, -0.02), sel);
	// ice: frosted blue glaze with cracks-ish noise
	float fr = sin(UV.x * 40.0 + sin(UV.y * 23.0) * 2.0) * sin(UV.y * 37.0 - UV.x * 11.0);
	vec3 icec = mix(vec3(0.72, 0.88, 1.0), vec3(0.95, 0.99, 1.0), smoothstep(-0.2, 1.0, fr));
	col = mix(col, icec, ice * 0.62);
	col += ice * 0.25 * vec3(pow(max(0.0, 1.0 - abs(UV.x - UV.y + 0.2) * 6.0), 3.0));
	// gold: warm metallic tint with moving glint
	float gl = exp(-pow((UV.x + UV.y * 0.6 - fract(TIME * 0.35) * 2.4 + 0.4) / 0.1, 2.0));
	col = mix(col, col * vec3(1.15, 1.0, 0.62) + vec3(0.12, 0.08, 0.0), gold * 0.55);
	col += gold * gl * vec3(1.0, 0.9, 0.55) * 0.55;
	// neon rim
	float edge = 1.0 - smoothstep(0.0, 0.12, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	col += neon * edge * vec3(0.2, 0.9, 1.0) * (0.6 + 0.4 * sin(TIME * 3.0));
	float band = exp(-pow((UV.x + UV.y * 0.5 - shine) / 0.09, 2.0));
	col += band * 0.45;
	float fl = clamp(flash, 0.0, 1.0);
	col = mix(col, col * 0.7 + flash_col * 0.5, fl * 0.38);
	col += fl * edge * flash_col * 0.55;
	COLOR = vec4(col, c.a) * vcol;
}
