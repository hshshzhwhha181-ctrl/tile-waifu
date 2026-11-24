shader_type canvas_item;
// v10/mj/look — material tile face (V10MjTileMaterial). A superset of shaders/v06/board/tile_face.gdshader:
// every v0.5/v06 uniform (dim/sel/flash/shine/ice/gold/shade/neon/bevel/lamp/gloss/ambient) keeps its meaning, so a
// board that drives those keeps working after the swap. Adds the six materials: a 3-layer edge (outer lip → seam →
// inner bevel), a lamp highlight with per-material sharpness, clear coat, fake AO, subsurface edge glow, grain,
// the 18% «closed» shade, the free-tile outline in the heroine accent and the 1.00↔1.01 «breathing» (vertex).
varying vec4 vcol;
varying vec2 wpos;
varying vec2 buv;
varying vec2 wcenter;

// ── v06 contract ──
uniform float dim = 0.0;
uniform float sel = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_col = vec3(1.0, 0.8, 0.52);
uniform float shine = -1.0;
uniform float ice = 0.0;
uniform float gold = 0.0;
uniform float shade = 1.0;
uniform float neon = 0.0;
uniform sampler2D bevel : filter_linear;
uniform float bevel_on = 1.0;
uniform vec2 quad = vec2(185.0, 192.0);
uniform vec2 lamp = vec2(250.0, 330.0);
uniform vec3 lamp_col = vec3(1.0, 0.94, 0.84);
uniform float gloss = 1.0;
uniform vec3 ambient = vec3(0.0);

// ── material ──
uniform vec4 mat_face : source_color = vec4(0.98, 0.95, 0.90, 1.0);   // plate tint (multiplies the ivory plate)
uniform vec4 mat_lip : source_color = vec4(0.93, 0.88, 0.80, 1.0);    // layer 1: outer lip
uniform vec4 mat_seam : source_color = vec4(0.85, 0.70, 0.42, 1.0);   // layer 2: thin seam / inlay line
uniform vec4 mat_bevel : source_color = vec4(0.90, 0.85, 0.77, 1.0);  // layer 3: inner bevel
uniform float seam_metal = 0.6;      // how much the seam catches the lamp (gold inlay = 1)
uniform float spec_pow = 60.0;       // lamp highlight sharpness
uniform float spec_k = 0.5;          // lamp highlight strength
uniform float coat_k = 0.2;          // broad clear coat
uniform float sss_k = 0.0;           // subsurface edge glow (jade, ice, amber)
uniform vec4 sss_col : source_color = vec4(0.5, 0.9, 0.7, 1.0);
uniform int grain_kind = 0;          // 0 none 1 crackle 2 veins 3 bone grain 4 ice fracture 5 inclusions 6 mirror
uniform float grain_amt = 0.0;
uniform float ao_k = 0.25;
uniform sampler2D grain_tex : filter_linear, repeat_enable;

// ── state ──
uniform float closed = 0.0;          // 1 = blocked tile: shaded 18%
uniform float outline = 0.0;         // «Подсвечивать свободные»: accent light on the rim
uniform vec4 accent : source_color = vec4(1.0, 0.56, 0.72, 1.0);
uniform float breathe = 0.0;         // free tile breathing 1.00↔1.01, period 3.2 s
uniform float phase = 0.0;
uniform float auto_phase = 0.0;     // 1 = phase from the node's world origin (shared materials)

float sd_rbox(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - h + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	float k = 1.0 + breathe * 0.005 * (1.0 - cos(TIME * 1.9634954 + mix(phase, fract(sin(dot(MODEL_MATRIX[3].xy, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831853, auto_phase)));
	VERTEX *= k;
	vcol = COLOR;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	wcenter = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	buv = VERTEX / (quad * k) + 0.5;
}

float grain(vec2 uv) {
	if (grain_kind == 0 || grain_amt <= 0.0) {
		return 0.0;
	}
	vec2 p = uv * vec2(1.0, quad.y / quad.x);
	if (grain_kind == 1) {          // porcelain crackle: thin dark network
		float n = texture(grain_tex, p * 1.7).r;
		return -smoothstep(0.03, 0.0, abs(n - 0.5)) * 0.9;
	} else if (grain_kind == 2) {   // jade veins: soft cloudy marbling
		float n = texture(grain_tex, p * 0.9 + vec2(0.13, 0.31)).r;
		float m = texture(grain_tex, p * 2.3 + vec2(n * 0.3)).r;
		return (m - 0.5) * 1.2 - smoothstep(0.05, 0.0, abs(n - 0.55)) * 0.7;
	} else if (grain_kind == 3) {   // bone: fine longitudinal grain
		float n = texture(grain_tex, vec2(p.x * 6.0, p.y * 0.6)).r;
		return (n - 0.5) * 1.4;
	} else if (grain_kind == 4) {   // ice: bright fracture lines
		float n = texture(grain_tex, p * 1.3 + vec2(0.4, 0.1)).r;
		return smoothstep(0.035, 0.0, abs(n - 0.5)) * 1.2;
	} else if (grain_kind == 5) {   // amber: warm inclusions and tiny bubbles
		float n = texture(grain_tex, p * 3.1 + vec2(0.7, 0.2)).r;
		return smoothstep(0.78, 0.86, n) * 1.2 - (texture(grain_tex, p * 0.7).r - 0.5) * 0.6;
	}
	return 0.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 col = c.rgb;

	// geometry: distance to the plate edge in quad px (negative inside)
	vec2 pp = (buv - 0.5) * quad;
	float d = sd_rbox(pp, quad * 0.5 - vec2(3.0, 2.0), 24.0);

	// ivory plate mask (symbol ink is saturated or dark: it keeps its colour for contrast)
	float lum0 = dot(col, vec3(0.299, 0.587, 0.114));
	float sat0 = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
	float plate = smoothstep(0.70, 0.84, lum0) * (1.0 - smoothstep(0.12, 0.22, sat0));

	// material tint on the plate
	vec3 ivory_ref = vec3(0.985, 0.95, 0.90);
	col = mix(col, col * (mat_face.rgb / ivory_ref), plate);
	col += plate * grain(buv) * grain_amt * vec3(0.55, 0.5, 0.45);

	// three-layer edge: lip (outer 4 px) → seam (inlay line) → bevel (inner band). The tile art bakes its own
	// border; we keep its shading (lum0) and recolour it into the material's layers.
	float lip = smoothstep(-4.5, -3.0, d);
	float seam = smoothstep(-7.5, -6.5, d) * (1.0 - smoothstep(-5.5, -4.5, d));
	float bev = smoothstep(-13.0, -10.0, d) * (1.0 - smoothstep(-7.5, -6.5, d));
	float shade_k = clamp(lum0 * 1.12, 0.35, 1.15);
	col = mix(col, mat_lip.rgb * shade_k, lip * 0.85);
	col = mix(col, mat_bevel.rgb * shade_k, bev * 0.55 * (1.0 - plate * 0.5));

	// lamp lighting on the baked bevel normals
	vec4 bv = texture(bevel, buv);
	vec3 n = vec3(bv.rg * 2.0 - 1.0, 0.0);
	n.z = sqrt(max(0.0, 1.0 - dot(n.xy, n.xy)));
	n = normalize(mix(vec3(0.0, 0.0, 1.0), n, bevel_on));
	vec3 L = normalize(vec3(lamp - wpos, 520.0));
	vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
	col *= mix(vec3(1.03, 1.03, 1.05), vec3(0.97, 0.95, 0.91), smoothstep(0.1, 1.0, buv.y));
	col *= 1.0 + (dot(n, L) - L.z) * 1.35 * bevel_on;
	col *= 1.0 - bv.b * 0.2 * bevel_on;
	col += ambient * bv.b * 0.6 * bevel_on;

	// seam inlay goes on after lighting so it reads as metal / enamel
	float nh = max(dot(n, H), 0.0);
	vec3 seam_c = mat_seam.rgb * (0.75 + 0.25 * L.z) + lamp_col * pow(nh, 18.0) * seam_metal * 0.6;
	col = mix(col, seam_c, seam * 0.9);

	// fake AO: inner edge darkening, stronger on the far (bottom-right) side
	float ao = smoothstep(-26.0, -3.0, d) * (0.6 + 0.4 * smoothstep(0.2, 1.0, (buv.x + buv.y) * 0.5));
	col *= 1.0 - ao * ao_k * 0.45;

	// highlights. A flat face under a high lamp would be «all highlight», so the lamp's reflection is a hotspot that
	// sits on the side of the face toward the lamp (farther tiles: nearer the edge), sharper for glossier materials.
	// Symbols take only a third of it, so a highlight never eats a symbol.
	vec2 ldir = lamp - wcenter;
	float dist = length(ldir);
	float near = 1.0 - smoothstep(120.0, 1100.0, dist);
	vec2 hs = vec2(0.5) + (dist > 1.0 ? ldir / dist : vec2(0.0)) * mix(0.12, 0.36, smoothstep(0.0, 700.0, dist));
	float sig = mix(0.34, 0.13, clamp((spec_pow - 16.0) / 100.0, 0.0, 1.0));
	vec2 dd = (buv - hs) * vec2(1.0, quad.y / quad.x);
	float hot = exp(-dot(dd, dd) / (sig * sig));
	float on_plate = 0.33 + 0.67 * plate;
	float spec = hot * spec_k * 0.42 * (0.55 + 0.45 * near) * on_plate;
	float rimspec = pow(nh, 70.0) * smoothstep(0.02, 0.3, 1.0 - n.z) * 1.1;
	float coat = coat_k * 0.10 * (1.0 - smoothstep(0.0, 0.9, length(dd))) * on_plate;
	float win = smoothstep(0.08, 0.0, abs(buv.x * 0.8 + buv.y - 0.42 - wpos.x * 0.00025)) * 0.035 * (0.5 + coat_k * 2.0) * on_plate;
	if (grain_kind == 6) {
		// lacquer: a mirror sweep of the lamp across the face as the tile sits on the table
		win += smoothstep(0.05, 0.0, abs(buv.x * 0.7 + buv.y * 0.9 - 0.55 - (lamp.x - wcenter.x) * 0.0006)) * 0.08 * on_plate;
	}
	col += (spec + rimspec + coat + win) * lamp_col * gloss * bevel_on;

	// subsurface: light bleeding through the edges (jade, ice, amber)
	float edge_in = smoothstep(-18.0, -2.0, d);
	col += sss_col.rgb * sss_k * edge_in * (0.35 + 0.65 * (1.0 - L.z)) * 0.35;

	// v0.5 states
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum) * vec3(0.97, 0.95, 1.0), dim * 0.32);
	col *= 1.0 - dim * 0.2;
	col *= shade;
	col *= 1.0 - 0.18 * closed;
	col = mix(col, col * 1.06 + vec3(0.08, 0.05, -0.02), sel);
	// rare states behind uniform branches (cheap on every GPU, and on the software rasteriser the selftest uses)
	if (ice > 0.0) {
		float fr = sin(UV.x * 40.0 + sin(UV.y * 23.0) * 2.0) * sin(UV.y * 37.0 - UV.x * 11.0);
		vec3 icec = mix(vec3(0.72, 0.88, 1.0), vec3(0.95, 0.99, 1.0), smoothstep(-0.2, 1.0, fr));
		col = mix(col, icec, ice * 0.62);
	}
	if (gold > 0.0) {
		float gl = exp(-pow((buv.x + buv.y * 0.6 - fract(TIME * 0.35) * 2.4 + 0.4) / 0.1, 2.0));
		vec3 gcol = col * vec3(1.15, 1.0, 0.62) + vec3(0.12, 0.08, 0.0);
		gcol += pow(nh, 30.0) * vec3(1.0, 0.85, 0.45) * 0.6;
		col = mix(col, gcol, gold * 0.6);
		col += gold * gl * vec3(1.0, 0.9, 0.55) * 0.5;
	}
	float edge = 1.0 - smoothstep(0.0, 0.12, min(min(buv.x, 1.0 - buv.x), min(buv.y, 1.0 - buv.y)));
	if (neon > 0.0) {
		col += neon * edge * vec3(0.2, 0.9, 1.0) * (0.6 + 0.4 * sin(TIME * 3.0));
	}
	if (shine > -0.5) {
		float band = exp(-pow((buv.x + buv.y * 0.5 - shine) / 0.09, 2.0));
		col += band * 0.45;
	}
	if (flash > 0.0) {
		float fl = clamp(flash, 0.0, 1.0);
		col = mix(col, col * 0.7 + flash_col * 0.5, fl * 0.38);
		col += fl * edge * flash_col * 0.55;
	}
	// free-tile outline: accent light hugging the rim, slow pulse (never white, ≤ 0.6 add)
	if (outline > 0.0) {
		float ring = smoothstep(-11.0, -2.0, d) * (1.0 - smoothstep(-1.0, 0.5, d));
		col += accent.rgb * outline * ring * (0.42 + 0.14 * sin(TIME * 2.2 + phase));
	}
	COLOR = vec4(col, c.a) * vcol;
}
