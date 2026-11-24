shader_type canvas_item;
// v10:look — V10TileTheme tables: the v06 table (same uniforms, V6BoardTable can drive it) plus patterns 7–11
// (frost, finish lanes, moon & stars, circuit, petals) and an optional painted mat texture (Злата's lacquer casket).
// Original v06 description: the play table: soft drop shadow, lacquered frame with gold inlay and sheen,
// recessed mat (felt/silk/glass) with fibre noise, a woven traditional pattern, lamp pool,
// inner shadow, corner brackets. Drawn in screen px on a ColorRect that is `margin` larger
// than the table on every side.
uniform vec2 size = vec2(700.0, 900.0);     // ColorRect size in px (table + 2*margin)
uniform float margin = 40.0;
uniform float radius = 26.0;
uniform float frame_w = 16.0;
uniform vec4 frame_a : source_color = vec4(0.25, 0.12, 0.10, 1.0);  // lacquer light
uniform vec4 frame_b : source_color = vec4(0.10, 0.04, 0.04, 1.0);  // lacquer dark
uniform vec4 trim : source_color = vec4(1.0, 0.82, 0.45, 1.0);      // gold / silver / neon
uniform vec4 mat_a : source_color = vec4(0.22, 0.42, 0.36, 1.0);    // mat center
uniform vec4 mat_b : source_color = vec4(0.10, 0.22, 0.19, 1.0);    // mat edge
uniform vec4 pat_col : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float pat_alpha = 0.08;
uniform int pattern = 0;      // 0 seigaiha, 1 asanoha, 2 shippo, 3 uroko, 4 kikko, 5 neon grid, 6 none,
                              // 7 frost, 8 finish lanes, 9 moon & stars, 10 circuit, 11 petals
uniform sampler2D mat_tex : filter_linear_mipmap, repeat_disable;
uniform float mat_tex_on = 0.0; // 1: the mat is the painted texture (cover-fit), lamp and inner shadow still apply
uniform float mat_tex_aspect = 0.75; // texture w / h
uniform float anim = 1.0;     // 0 = static table (ranked, fx «минимум»)
uniform float pat_scale = 46.0;
uniform float fibre = 0.5;    // felt fibre strength (0 = glossy silk/glass)
uniform float neon = 0.0;     // glowing trim
uniform vec2 lamp = vec2(0.35, 0.12); // lamp pool center in table uv
uniform vec3 lamp_col = vec3(1.0, 0.92, 0.78);
uniform float lamp_k = 0.35;
uniform float shadow_a = 0.55;
uniform float t = 0.0;        // game time (G.time) for the sheen
uniform sampler2D noise : filter_linear, repeat_enable;

float sd_rbox(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - h + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float line_(float d, float w) { return 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, abs(d)); }

float seigaiha(vec2 p) {
	// rows of concentric half-circles; lower rows overlap upper ones
	vec2 g = p / pat_scale;
	float rowh = 0.25;
	int r_hi = int(floor((g.y + 0.5) / rowh));
	int r_lo = int(ceil(g.y / rowh));
	for (int row = r_hi; row >= r_lo; row--) {
		float off = mod(float(row), 2.0) * 0.5;
		vec2 c = vec2(floor(g.x - off + 0.5) + off, float(row) * rowh);
		float r = length(g - c);
		if (r <= 0.5) {
			float ring = abs(fract(r * 8.0) - 0.5);
			float v = 1.0 - smoothstep(0.1, 0.22, ring);
			v = max(v, 1.0 - smoothstep(0.012, 0.03, abs(r - 0.49)));
			return v;
		}
	}
	return 0.0;
}

float asanoha(vec2 p) {
	// triangular lattice with spokes to every triangle center: the hemp-leaf star
	vec2 g = p / pat_scale;
	float v = 0.0;
	for (int k = 0; k < 3; k++) {
		float a = float(k) * 1.0471976;
		vec2 nrm = vec2(-sin(a), cos(a));
		float d = dot(g, nrm) * 1.1547005;
		v = max(v, 1.0 - smoothstep(0.02, 0.045, abs(fract(d + 0.5) - 0.5)));
	}
	for (int k = 0; k < 3; k++) {
		float a = float(k) * 1.0471976 + 0.5235988;
		vec2 nrm = vec2(-sin(a), cos(a));
		float d = dot(g, nrm) * 2.0;
		v = max(v, (1.0 - smoothstep(0.02, 0.05, abs(fract(d + 0.5) - 0.5))) * 0.55);
	}
	return v;
}

float shippo(vec2 p) {
	vec2 g = p / pat_scale;
	vec2 b = floor(g);
	float v = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cc = b + vec2(float(i), float(j)) + 0.5;
			v = max(v, 1.0 - smoothstep(0.012, 0.035, abs(length(g - cc) - 0.7071)));
		}
	}
	return v;
}

float uroko(vec2 p) {
	// dragon scales: alternating triangles
	vec2 g = p / pat_scale;
	g.y *= 1.15;
	float row = floor(g.y);
	vec2 f = vec2(fract(g.x + mod(row, 2.0) * 0.5), fract(g.y));
	float tri = step(abs(f.x - 0.5) * 2.0, f.y);
	float edge = abs(abs(f.x - 0.5) * 2.0 - f.y);
	return tri * 0.55 + (1.0 - smoothstep(0.02, 0.06, edge)) * 0.6;
}

float kikko(vec2 p) {
	vec2 g = p / pat_scale;
	vec2 s = vec2(1.0, 1.7320508);
	vec2 a = mod(g, s) - s * 0.5;
	vec2 b = mod(g - s * 0.5, s) - s * 0.5;
	vec2 h = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(h);
	float d = max(dot(q, normalize(s)), q.x);
	float v = 1.0 - smoothstep(0.02, 0.05, abs(d - 0.44));
	v = max(v, (1.0 - smoothstep(0.02, 0.05, abs(d - 0.34))) * 0.5);
	return v;
}


float hash1(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float frost(vec2 p) {
	vec2 g = p / pat_scale;
	vec2 c = floor(g);
	vec2 f = fract(g) - 0.5;
	float v = 0.0;
	for (int k = 0; k < 3; k++) {
		float a = float(k) * 1.0471976 + hash1(c) * 0.5;
		vec2 dir = vec2(cos(a), sin(a));
		float along = dot(f, dir);
		float across = abs(dot(f, vec2(-dir.y, dir.x)));
		v = max(v, (1.0 - smoothstep(0.01, 0.03, across)) * step(abs(along), 0.38));
		// side barbs
		float b = abs(fract(along * 8.0) - 0.5);
		v = max(v, (1.0 - smoothstep(0.0, 0.04, abs(across - b * 0.12))) * step(abs(along), 0.3) * 0.6);
	}
	return v * step(0.35, hash1(c + 2.0));
}

float lanes(vec2 p) {
	vec2 g = p / pat_scale;
	float lane = 1.0 - smoothstep(0.015, 0.04, abs(fract(g.x) - 0.5));
	vec2 ck = floor(g * vec2(4.0, 4.0));
	float band = step(abs(g.y - 3.2), 0.25) * mod(ck.x + ck.y, 2.0);
	return max(lane * 0.7, band);
}

float stars(vec2 p) {
	vec2 g = p / pat_scale;
	vec2 c = floor(g);
	vec2 f = fract(g) - vec2(hash1(c), hash1(c + 9.1)) * 0.6 - 0.2;
	float h = hash1(c + 4.4);
	float tw = 0.6 + 0.4 * sin(t * anim * 1.3 + h * 50.0);
	float star = (1.0 - smoothstep(0.0, 0.05, abs(f.x) * abs(f.y) * 40.0 + length(f) * 0.4)) * step(0.55, h);
	float moon = 0.0;
	return star * tw + moon;
}

float circuit(vec2 p) {
	vec2 g = p / pat_scale;
	vec2 c = floor(g);
	vec2 f = fract(g);
	float h = hash1(c);
	float tr = h > 0.5 ? 1.0 - smoothstep(0.02, 0.05, abs(f.y - 0.5)) : 1.0 - smoothstep(0.02, 0.05, abs(f.x - 0.5));
	float pad = 1.0 - smoothstep(0.05, 0.09, length(f - 0.5));
	float pulse = 0.4 + 0.6 * smoothstep(0.9, 1.0, fract((g.x + g.y) * 0.08 - t * anim * 0.25));
	return max(tr, pad) * pulse;
}

float petals(vec2 p) {
	vec2 g = p / pat_scale;
	vec2 c = floor(g);
	vec2 f = fract(g) - 0.5;
	float a = hash1(c) * 6.283;
	f = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * f;
	float pe = 1.0 - smoothstep(0.1, 0.16, length(f * vec2(1.0, 2.4)));
	return pe * step(0.5, hash1(c + 1.7));
}

float grid(vec2 p) {
	vec2 g = p / pat_scale;
	vec2 f = abs(fract(g) - 0.5);
	float l = 1.0 - smoothstep(0.0, 0.03, 0.5 - max(f.x, f.y));
	float dots = 1.0 - smoothstep(0.03, 0.08, length(fract(g) - 0.5));
	return max(l, dots * 0.4);
}

void fragment() {
	vec2 px = UV * size;
	vec2 tsize = size - 2.0 * margin;
	vec2 c = px - size * 0.5;
	vec2 tuv = (px - margin) / tsize;
	float d = sd_rbox(c, tsize * 0.5, radius);
	// outside: soft drop shadow below the table
	float sh = 1.0 - smoothstep(-6.0, margin * 0.9, sd_rbox(c - vec2(0.0, 14.0), tsize * 0.5, radius));
	vec4 outc = vec4(0.03, 0.0, 0.03, sh * sh * shadow_a);
	float aa = 1.0 - smoothstep(-0.5, 0.8, d);
	vec3 n3 = texture(noise, px / 256.0).rgb;
	vec3 big = texture(noise, px / 900.0).rgb;
	// frame
	float din = d + frame_w;                // < 0 inside the mat
	float fx = clamp(-d / frame_w, 0.0, 1.0); // 0 outer edge -> 1 inner edge
	vec3 lac = mix(frame_a.rgb, frame_b.rgb, smoothstep(-0.2, 1.1, tuv.y + (n3.b - 0.5) * 0.15));
	// rounded profile: highlight on the outer top, shade toward the inner edge
	float prof = sin(fx * 3.14159);
	float sweep = anim > 0.5 ? fract(t / 7.0) * 3.0 - 1.0 : -2.0;
	vec2 grad_dir = normalize(c + 0.0001);
	float up = -grad_dir.y * 0.6 - grad_dir.x * 0.25;
	lac *= 0.78 + 0.4 * prof + 0.25 * up * (1.0 - fx);
	lac += (big.g - 0.5) * 0.05;
	// moving sheen on the lacquer every ~7 s
	float sheen = exp(-pow((tuv.x * 0.7 + tuv.y * 0.3 - sweep) / 0.05, 2.0)) * prof;
	lac += sheen * 0.35 * mix(vec3(1.0), trim.rgb, 0.4);
	// static window highlight on the top rail
	lac += smoothstep(0.65, 1.0, prof) * smoothstep(0.08, 0.0, tuv.y) * 0.12;
	// gold inlay lines
	// metal bands: a 3.5px lip on the outer edge, a 3px bead on the inner edge, a hairline between
	float outer_band = smoothstep(-4.2, -3.2, d);
	float inner_band = 1.0 - smoothstep(2.6, 3.6, din);
	float mid_line = line_(d + frame_w * 0.55, 0.9) * 0.6;
	float tl = max(max(outer_band, inner_band), mid_line);
	float bead = outer_band > 0.5 ? clamp((d + 3.7) / 3.7, 0.0, 1.0) : clamp(din / 3.1, 0.0, 1.0);
	float metal = 0.62 + 0.55 * pow(1.0 - abs(bead - 0.35) * 1.4, 2.0) + 0.3 * up;
	metal += 0.25 * exp(-pow((tuv.x * 0.7 + tuv.y * 0.3 - sweep) / 0.04, 2.0));
	vec3 gold = trim.rgb * metal * (0.92 + 0.12 * sin(px.x * 0.05 + px.y * 0.02 + t * anim * 0.6));
	vec3 framec = mix(lac, gold, tl);
	// mat
	float r = length((tuv - lamp) * vec2(1.0, tsize.y / tsize.x));
	vec3 matc = mix(mat_a.rgb, mat_b.rgb, smoothstep(0.0, 1.05, r));
	matc *= 1.0 + (n3.r - 0.5) * 0.12 * fibre + (n3.g - 0.5) * 0.18 * fibre;
	matc *= 1.0 + (big.b - 0.5) * 0.10;
	float pv = 0.0;
	vec2 pp = px - margin;
	if (pattern == 0) pv = seigaiha(pp);
	else if (pattern == 1) pv = asanoha(pp);
	else if (pattern == 2) pv = shippo(pp);
	else if (pattern == 3) pv = uroko(pp);
	else if (pattern == 4) pv = kikko(pp);
	else if (pattern == 5) pv = grid(pp);
	else if (pattern == 7) pv = frost(pp);
	else if (pattern == 8) pv = lanes(pp);
	else if (pattern == 9) pv = stars(pp);
	else if (pattern == 10) pv = circuit(pp);
	else if (pattern == 11) pv = petals(pp);
	float pat_fade = 1.0 - smoothstep(0.25, 0.9, r) * 0.6;
	vec3 pcol = pat_col.rgb;
	matc = mix(matc, pcol, clamp(pv, 0.0, 1.0) * pat_alpha * pat_fade);
	if (pattern == 5 || pattern == 10) {
		matc += pcol * pv * pat_alpha * (0.6 + 0.4 * sin(t * anim * 1.3 + pp.y * 0.01));
	}
	if (mat_tex_on > 0.5) {
		vec2 inner = tsize - 2.0 * frame_w;
		vec2 muv = (px - margin - frame_w) / inner;
		float ra = inner.x / inner.y;
		if (ra > mat_tex_aspect) { muv.y = (muv.y - 0.5) * mat_tex_aspect / ra + 0.5; }
		else { muv.x = (muv.x - 0.5) * ra / mat_tex_aspect + 0.5; }
		vec3 tc = texture(mat_tex, clamp(muv, 0.0, 1.0)).rgb;
		matc = mix(matc, tc * (0.9 + (n3.r - 0.5) * 0.06), 0.96);
	}
	// lamp pool
	matc += lamp_col * lamp_k * exp(-r * r * 3.2) * 0.45;
	// inner shadow: mat sits below the frame, light from the top-left
	float ish = smoothstep(-26.0, 0.0, din);
	float ish_dir = smoothstep(-16.0, 0.0, sd_rbox(c - vec2(-6.0, -10.0), tsize * 0.5 - frame_w, max(radius - frame_w, 4.0)));
	matc *= 1.0 - 0.45 * ish - 0.35 * ish_dir;
	// corner brackets in gold
	vec2 q = abs(c) - (tsize * 0.5 - frame_w - 14.0);
	float br = 0.0;
	if (q.x > -30.0 && q.y > -30.0 && q.x < 2.0 && q.y < 2.0) {
		float l1 = line_(q.y, 2.0) * step(-30.0, q.x);
		float l2 = line_(q.x, 2.0) * step(-30.0, q.y);
		float dia = 1.0 - smoothstep(3.0, 4.5, abs(q.x + 2.0) + abs(q.y + 2.0));
		br = max(max(l1, l2) * 0.85, dia);
	}
	matc = mix(matc, trim.rgb * 0.95, br * (1.0 - ish * 0.5));
	vec3 col = din < 0.0 ? matc : framec;
	// antialias frame/mat border with the inlay already covering it
	// neon trim glow
	col += neon * trim.rgb * (exp(-abs(din) / 5.0) * 0.8 + exp(-abs(d) / 7.0) * 0.5) * (0.75 + 0.25 * sin(t * anim * 2.0));
	vec4 tab = vec4(col, 1.0);
	// neon halo outside
	outc.rgb = mix(outc.rgb, trim.rgb, neon * 0.6);
	outc.a = max(outc.a, neon * exp(-max(d, 0.0) / 10.0) * 0.45);
	COLOR = mix(outc, tab, aa);
}
