shader_type canvas_item;
// v06:board — premium tile face: baked bevel normals lit by a table lamp, porcelain gradient,
// clear-coat gloss, rim specular. Keeps every uniform of shaders/tile.gdshader (dim/sel/flash/shine/
// ice/gold/shade/neon) so old code that sets them keeps working.
varying vec4 vcol;
varying vec2 wpos;
varying vec2 buv;
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
uniform sampler2D bevel : filter_linear;
uniform float bevel_on = 1.0;
uniform vec2 quad = vec2(185.0, 192.0);     // local size of the quad the bevel map covers
uniform vec2 lamp = vec2(250.0, 330.0);     // table lamp in canvas px (set by V6BoardTable)
uniform vec3 lamp_col = vec3(1.0, 0.94, 0.84);
uniform float gloss = 1.0;                  // per-theme clear-coat strength
uniform vec3 ambient = vec3(0.0);           // theme bounce light added to edges

void vertex() {
	vcol = COLOR;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	buv = VERTEX / quad + 0.5;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 col = c.rgb;
	vec4 bv = texture(bevel, buv);
	vec3 n = vec3(bv.rg * 2.0 - 1.0, 0.0);
	n.z = sqrt(max(0.0, 1.0 - dot(n.xy, n.xy)));
	n = normalize(mix(vec3(0.0, 0.0, 1.0), n, bevel_on));
	vec3 L = normalize(vec3(lamp - wpos, 520.0));
	vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
	float flat_d = L.z;
	float d = dot(n, L);
	// porcelain: cooler top, warmer bottom, a touch of subsurface
	col *= mix(vec3(1.03, 1.03, 1.05), vec3(0.97, 0.95, 0.91), smoothstep(0.1, 1.0, buv.y));
	// bevel shading relative to the flat plateau
	col *= 1.0 + (d - flat_d) * 1.35 * bevel_on;
	col *= 1.0 - bv.b * 0.22 * bevel_on;                  // edge cavity
	col += ambient * bv.b * 0.6 * bevel_on;
	// rim specular (sharp) and clear coat (broad, distance falloff from the lamp)
	float rim = pow(max(dot(n, H), 0.0), 70.0) * smoothstep(0.02, 0.3, 1.0 - n.z) * 1.2;
	float dist = length(lamp - wpos);
	float coat = pow(max(dot(n, H), 0.0), 6.0) * 0.16 * (1.0 - smoothstep(120.0, 900.0, dist));
	// soft studio reflection: diagonal window band
	float win = smoothstep(0.08, 0.0, abs(buv.x * 0.8 + buv.y - 0.42 - wpos.x * 0.00025)) * 0.07;
	col += (rim + coat + win) * lamp_col * gloss * bevel_on;
	// v0.5 states
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum) * vec3(0.97, 0.95, 1.0), dim * 0.32);
	col *= 1.0 - dim * 0.2;
	col *= shade;
	col = mix(col, col * 1.06 + vec3(0.08, 0.05, -0.02), sel);
	float fr = sin(UV.x * 40.0 + sin(UV.y * 23.0) * 2.0) * sin(UV.y * 37.0 - UV.x * 11.0);
	vec3 icec = mix(vec3(0.72, 0.88, 1.0), vec3(0.95, 0.99, 1.0), smoothstep(-0.2, 1.0, fr));
	col = mix(col, icec, ice * 0.62);
	// gold: brushed metal face with lamp glint
	float gl = exp(-pow((buv.x + buv.y * 0.6 - fract(TIME * 0.35) * 2.4 + 0.4) / 0.1, 2.0));
	vec3 gcol = col * vec3(1.15, 1.0, 0.62) + vec3(0.12, 0.08, 0.0);
	gcol += pow(max(dot(n, H), 0.0), 30.0) * vec3(1.0, 0.85, 0.45) * 0.6;
	col = mix(col, gcol, gold * 0.6);
	col += gold * gl * vec3(1.0, 0.9, 0.55) * 0.5;
	float edge = 1.0 - smoothstep(0.0, 0.12, min(min(buv.x, 1.0 - buv.x), min(buv.y, 1.0 - buv.y)));
	col += neon * edge * vec3(0.2, 0.9, 1.0) * (0.6 + 0.4 * sin(TIME * 3.0));
	float band = exp(-pow((buv.x + buv.y * 0.5 - shine) / 0.09, 2.0));
	col += band * 0.45;
	float fl = clamp(flash, 0.0, 1.0);
	col = mix(col, col * 0.7 + flash_col * 0.5, fl * 0.38);
	col += fl * edge * flash_col * 0.55;
	COLOR = vec4(col, c.a) * vcol;
}
