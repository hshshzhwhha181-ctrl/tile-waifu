shader_type canvas_item;
varying vec4 vcol;
void vertex() { vcol = COLOR; }
// 0.8 portrait-shard tile face: the heroine's face cropped to a circle in a gold ring on the ivory tile, a small
// gold shard glyph in the corner and a slow shimmer. Same state uniforms as tile.gdshader (dim, sel, flash,
// shine, ice, gold) so the board drives it the same way. `region` = the face crop in normalized atlas UV.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float dim = 0.0;
uniform float sel = 0.0;
uniform float flash = 0.0;
uniform float shine = -1.0;
uniform float ice = 0.0;
uniform float gold = 0.0;
uniform float shade = 1.0;
uniform float neon = 0.0;
void fragment() {
	vec2 l = (UV - region.xy) / region.zw;
	vec2 d = l - vec2(0.5);
	float r = length(d);
	float aa = 0.012;
	vec4 c = texture(TEXTURE, UV);
	// portrait over a soft rose backing, full saturation
	vec3 backing = mix(vec3(0.99, 0.88, 0.9), vec3(0.93, 0.74, 0.8), smoothstep(0.0, 0.45, r));
	vec3 col = mix(backing, c.rgb, c.a);
	float inside = 1.0 - smoothstep(0.405 - aa, 0.405, r);
	// gold ring with a top-lit bevel
	float ring = smoothstep(0.4 - aa, 0.4, r) * (1.0 - smoothstep(0.47, 0.47 + aa, r));
	vec3 goldc = mix(vec3(0.98, 0.88, 0.58), vec3(0.72, 0.5, 0.2), clamp(l.y * 1.1, 0.0, 1.0));
	goldc += 0.18 * smoothstep(0.02, -0.06, abs(r - 0.435) - 0.012);
	// rose hairline just outside the ring
	float hair = smoothstep(0.47, 0.47 + aa, r) * (1.0 - smoothstep(0.485, 0.485 + aa, r));
	// shard glyph: a small gold diamond in the lower-right corner
	vec2 g = l - vec2(0.86, 0.86);
	float dia = 1.0 - smoothstep(0.085, 0.085 + aa * 1.5, abs(g.x) * 1.25 + abs(g.y));
	float dia_hi = 1.0 - smoothstep(0.0, 0.04, abs(g.x + g.y * 0.2 + 0.015));
	vec3 diac = mix(vec3(0.96, 0.74, 0.32), vec3(1.0, 0.96, 0.8), dia_hi * 0.8);
	float a = max(max(inside, ring), max(hair * 0.9, dia));
	vec3 outc = col;
	outc = mix(outc, goldc, ring);
	outc = mix(outc, vec3(0.86, 0.56, 0.64), hair * (1.0 - ring));
	outc = mix(outc, diac, dia * (1.0 - inside));
	// slow shimmer across the portrait and ring
	float sh = exp(-pow((l.x + l.y * 0.6 - fract(TIME * 0.22) * 2.6 + 0.5) / 0.12, 2.0));
	outc += sh * 0.22 * vec3(1.0, 0.95, 0.85) * max(inside * 0.6, ring);
	outc += gold * 0.0;
	// board states (same as tile.gdshader)
	float lum = dot(outc, vec3(0.299, 0.587, 0.114));
	outc = mix(outc, vec3(lum) * vec3(0.97, 0.95, 1.0), dim * 0.32);
	outc *= 1.0 - dim * 0.2;
	outc *= shade;
	outc = mix(outc, outc * 1.06 + vec3(0.08, 0.05, -0.02), sel);
	float fr = sin(l.x * 40.0 + sin(l.y * 23.0) * 2.0) * sin(l.y * 37.0 - l.x * 11.0);
	vec3 icec = mix(vec3(0.72, 0.88, 1.0), vec3(0.95, 0.99, 1.0), smoothstep(-0.2, 1.0, fr));
	outc = mix(outc, icec, ice * 0.62);
	float band = exp(-pow((l.x + l.y * 0.5 - shine) / 0.09, 2.0));
	outc += band * 0.45;
	outc = mix(outc, vec3(1.0, 0.98, 0.94), flash);
	COLOR = vec4(outc, a) * vcol;
}
