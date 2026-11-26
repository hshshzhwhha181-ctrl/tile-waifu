shader_type canvas_item;

// V10ComboDigit «×N» — lacquered gold (docs/HUD_V2.md §6, §7.2; scripts/v10/hudfx/README.md).
// Runs on the glyph quads of draw_string (font atlas: white × coverage, so COLOR.a = coverage × modulate.a).
// The gradient follows LOCAL y (a varying from vertex), not atlas UV, so every glyph shares one light:
//   gold.300 at the cap top → gold.500 → a touch of gold.700 at the glyph bottom, a breath brighter on the left
//   (light from the top left, §4); a thin warm inner edge on the top edges of the strokes (coverage compared a
//   few texels up), a faint lacquer bevel on their bottom edges; one diagonal sheen band (48 px, 20°, warm
//   paper.100, α ≤ 0.25) placed by `sheen_x` — the script moves it across once during «держит».
// 3 texture samples, no loops. Never white: the lightest colour is paper.100 mixed at ≤ 0.6 over gold.

uniform vec4 gold_top : source_color;
uniform vec4 gold_mid : source_color;
uniform vec4 gold_low : source_color;
uniform vec4 light : source_color;  // paper.100 — inner edge and sheen
uniform float y_top = 0.0;  // local px: cap top of the glyphs
uniform float y_base = 60.0;  // local px: baseline
uniform float x_left = 0.0;
uniform float x_right = 160.0;
uniform float edge_texels = 2.0;
uniform float edge_a : hint_range(0.0, 0.8) = 0.5;
uniform float bevel_a : hint_range(0.0, 0.6) = 0.3;
uniform float sheen_x = -10000.0;  // local x of the band centre at the baseline
uniform float sheen_w = 48.0;
uniform float sheen_a : hint_range(0.0, 0.25) = 0.0;

const float TAN20 = 0.36397;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 du = vec2(0.0, edge_texels * TEXTURE_PIXEL_SIZE.y);
	float a0 = texture(TEXTURE, UV).a;
	float up = texture(TEXTURE, UV - du).a;
	float dn = texture(TEXTURE, UV + du).a;
	float t = clamp((lp.y - y_top) / max(1.0, y_base - y_top), 0.0, 1.0);
	// lacquer body: pale gold at the cap top, warm gold through the middle, bronze touch at the foot
	vec3 c = mix(gold_top.rgb, gold_mid.rgb, smoothstep(0.0, 0.5, t));
	c = mix(c, gold_low.rgb, smoothstep(0.45, 1.1, t) * 0.62);
	// light from the top left (§4): the upper left of the number catches more of it
	float u = clamp((lp.x - x_left) / max(1.0, x_right - x_left), 0.0, 1.0);
	c = mix(c, gold_top.rgb, (1.0 - u) * (1.0 - t) * 0.45);
	// lacquer: light catches the top edges of the strokes, the bottom edges sink a little
	c = mix(c, light.rgb, a0 * (1.0 - up) * edge_a);
	c = mix(c, gold_low.rgb, a0 * (1.0 - dn) * bevel_a);
	// one sheen band «/» (20° from vertical): centre moves right as y goes up. Inside the band the lacquer
	// reflects its top colour (gold.300) and paper.100 lies over it at ≤ 0.25 — a glint, never white.
	float xc = sheen_x + (y_base - lp.y) * TAN20;
	float s = clamp(1.0 - abs(lp.x - xc) / (sheen_w * 0.5), 0.0, 1.0);
	s = s * s * (3.0 - 2.0 * s);
	float sa = clamp(sheen_a, 0.0, 0.25);
	c = mix(c, gold_top.rgb, s * sa * 3.2);
	c = mix(c, light.rgb, s * sa);
	COLOR = vec4(c, COLOR.a);
}
