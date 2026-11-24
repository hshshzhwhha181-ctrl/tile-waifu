shader_type canvas_item;
// v10:look — themed tile body («рубашка» band + kromka) for V10TileTheme. ONE material per theme, shared by every
// tile of the board (no per-tile uniforms -> batching on gl_compatibility). Reads the v06 baked body map
// (assets/v06/board/tile_body.png): R shade, G band (0 ivory face block -> 1 coloured back), B gloss.
// Uniforms lamp / lamp_col / gloss / shade keep the V6TileLook names so V6TileLook.relight() can drive them.
varying vec4 vcol;
varying vec2 wpos;
uniform vec4 ivory : source_color = vec4(0.96, 0.92, 0.86, 1.0);
uniform vec4 back : source_color = vec4(0.25, 0.6, 0.5, 1.0);   // band, top
uniform vec4 back2 : source_color = vec4(0.12, 0.3, 0.25, 1.0); // band, bottom (lacquer depth)
uniform vec4 line : source_color = vec4(1.0, 0.84, 0.45, 1.0);  // kromka + pattern ink
uniform int pattern = 0;      // 0 plain, 1 gold flakes, 2 frost, 3 finish stripes, 4 stars, 5 circuit, 6 petals, 7 feather vine
uniform float pat_alpha = 0.0;
uniform float edge = 0.0;     // gold kromka between ivory block and band
uniform float neon = 0.0;
uniform vec2 lamp = vec2(250.0, 330.0);
uniform vec3 lamp_col = vec3(1.0, 0.94, 0.84);
uniform float gloss = 1.0;
uniform float shade = 1.0;
uniform float anim = 1.0;     // 0 at fx «минимум»: no TIME-driven terms

void vertex() {
	vcol = COLOR;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float pat(vec2 uv, float t) {
	if (pattern == 1) {
		// gold leaf flakes, sparse cells
		vec2 g = uv * vec2(22.0, 26.0);
		vec2 c = floor(g);
		float h = hash(c);
		float d = length(fract(g) - vec2(hash(c + 3.1), hash(c + 7.7)));
		return step(0.72, h) * (1.0 - smoothstep(0.08, 0.22, d)) * (0.75 + 0.25 * sin(t * 2.0 + h * 30.0));
	} else if (pattern == 2) {
		// frost creeping from the lower edge: crystalline streaks
		float s = abs(sin(uv.x * 61.0 + sin(uv.y * 37.0) * 2.0)) * abs(sin(uv.y * 53.0 - uv.x * 19.0));
		return smoothstep(0.55, 0.95, s) * smoothstep(0.55, 1.0, uv.y);
	} else if (pattern == 3) {
		// finish-line checker band at the bottom + diagonal speed stripes
		vec2 g = floor(uv * vec2(14.0, 30.0));
		float chk = mod(g.x + g.y, 2.0) * step(0.86, uv.y);
		float st = step(0.5, fract((uv.x + uv.y * 0.6) * 9.0)) * step(uv.y, 0.86) * 0.35;
		return max(chk, st);
	} else if (pattern == 4) {
		vec2 g = uv * vec2(18.0, 22.0);
		vec2 c = floor(g);
		float h = hash(c);
		float d = length(fract(g) - 0.5);
		float tw = 0.55 + 0.45 * sin(t * 1.7 + h * 40.0);
		return step(0.82, h) * (1.0 - smoothstep(0.04, 0.16, d)) * tw;
	} else if (pattern == 5) {
		// circuit traces with a travelling pulse
		vec2 g = uv * vec2(9.0, 11.0);
		vec2 f = fract(g);
		float h = hash(floor(g));
		float tr = h > 0.5 ? 1.0 - smoothstep(0.03, 0.08, abs(f.y - 0.5)) : 1.0 - smoothstep(0.03, 0.08, abs(f.x - 0.5));
		float pulse = 0.35 + 0.65 * smoothstep(0.85, 1.0, fract(uv.x * 0.7 + uv.y * 0.4 - t * 0.35));
		return tr * pulse;
	} else if (pattern == 6) {
		vec2 g = uv * vec2(10.0, 12.0);
		vec2 c = floor(g);
		vec2 f = fract(g) - 0.5;
		float a = hash(c) * 6.283;
		f = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * f;
		float petal = 1.0 - smoothstep(0.12, 0.2, length(f * vec2(1.0, 2.2)));
		return petal * step(0.55, hash(c + 1.3));
	} else if (pattern == 7) {
		// gold vine: a sine stem with leaf blobs (lacquer miniature)
		float stem = 1.0 - smoothstep(0.012, 0.03, abs(uv.y - 0.78 - 0.06 * sin(uv.x * 18.0)));
		vec2 g = vec2(fract(uv.x * 9.0) - 0.5, (uv.y - 0.78 - 0.06 * sin(uv.x * 18.0)) * 9.0);
		float leaf = 1.0 - smoothstep(0.18, 0.28, length(g * vec2(1.0, 1.6) - vec2(0.0, 0.32)));
		return max(stem, leaf * 0.8);
	}
	return 0.0;
}

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	float t = TIME * anim;
	vec3 band = mix(back.rgb, back2.rgb, smoothstep(0.25, 1.0, UV.y));
	float p = clamp(pat(UV, t), 0.0, 1.0) * pat_alpha;
	band = mix(band, line.rgb, p * m.g);
	vec3 base = mix(ivory.rgb, band, m.g);
	vec3 col = base * (m.r * 1.08);
	col = mix(col, col * (base / max(max(base.r, base.g), max(base.b, 0.001))), (1.0 - m.r) * 0.35 * m.g);
	// kromka: a thin metal line where the ivory block meets the lacquer band
	float k = (1.0 - smoothstep(0.0, 0.18, abs(m.g - 0.5))) * edge;
	col = mix(col, line.rgb * (0.85 + 0.3 * m.r), k);
	float dist = length(lamp - wpos);
	float near = 1.0 - smoothstep(150.0, 1100.0, dist);
	col += m.b * lamp_col * gloss * (0.16 + 0.22 * near);
	col += neon * m.g * line.rgb * 0.35 * (0.7 + 0.3 * sin(t * 3.0));
	col *= shade;
	COLOR = vec4(col, m.a) * vcol;
}
