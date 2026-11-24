shader_type canvas_item;
// v10/mj/look — the heroine's table (V10MjTableView): her cloth (tiled texture or one sheet), a lacquered frame
// with an inlay line in her trim colour, a lamp pool in her lamp colour, inner shadow, a soft drop shadow and
// vignette. The cloth's luminance is capped (max_lum) so a tile face always keeps ≥ 4.5:1 against it.
uniform vec2 size = vec2(700.0, 900.0);       // ColorRect px (table + 2*margin)
uniform float margin = 36.0;
uniform float radius = 22.0;
uniform float frame_w = 14.0;
uniform sampler2D cloth : filter_linear_mipmap, repeat_enable;
uniform float cloth_scale = 340.0;            // px per texture repeat; 0 = one sheet stretched over the table
uniform vec4 cloth_tint : source_color = vec4(1.0);
uniform vec4 frame_a : source_color = vec4(0.35, 0.18, 0.12, 1.0);
uniform vec4 frame_b : source_color = vec4(0.12, 0.05, 0.04, 1.0);
uniform vec4 trim : source_color = vec4(0.9, 0.74, 0.45, 1.0);
uniform vec2 lamp_uv = vec2(0.32, 0.1);
uniform vec4 lamp_col : source_color = vec4(1.0, 0.92, 0.8, 1.0);
uniform float lamp_k = 0.3;
uniform float max_lum = 0.34;                 // sRGB luma cap of the cloth
uniform float shadow_a = 0.55;

float sd_rbox(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - h + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px = UV * size;
	vec2 c = size * 0.5;
	vec2 half_t = size * 0.5 - vec2(margin);
	float d = sd_rbox(px - c, half_t, radius);
	// drop shadow under the whole table (offset down)
	float ds = sd_rbox(px - c - vec2(0.0, 10.0), half_t, radius);
	float sh = (1.0 - smoothstep(-6.0, margin * 0.9, ds)) * shadow_a;
	vec4 outc = vec4(0.0, 0.0, 0.0, sh);
	if (d < 0.5) {
		vec2 tuv = (px - c + half_t) / (half_t * 2.0);
		vec3 col;
		float inner = d + frame_w;              // < 0 inside the cloth
		if (inner < 0.0) {
			vec2 cuv = cloth_scale > 0.0 ? (px / cloth_scale) : tuv;
			col = texture(cloth, cuv).rgb * cloth_tint.rgb;
			// lamp pool + falloff to the corners
			float ld = length((tuv - lamp_uv) * vec2(1.0, size.y / size.x));
			col *= 0.78 + 0.22 * (1.0 - smoothstep(0.0, 1.1, length(tuv - 0.5) * 1.4));
			col += lamp_col.rgb * lamp_k * exp(-ld * ld * 3.2) * 0.35;
			// inner shadow along the frame
			col *= 1.0 - 0.38 * smoothstep(-22.0, 0.0, inner);
			float l = dot(col, vec3(0.299, 0.587, 0.114));
			col *= min(1.0, max_lum / max(l, 0.001));
		} else {
			// lacquered frame: bevel by distance across the frame width, gold inlay line, lamp sheen
			float t = clamp(inner / frame_w, 0.0, 1.0);
			float bev = sin(t * 3.14159);
			col = mix(frame_b.rgb, frame_a.rgb, 0.35 + 0.65 * bev);
			float inlay = 1.0 - smoothstep(0.6, 1.4, abs(inner - frame_w * 0.42));
			col = mix(col, trim.rgb * (0.85 + 0.3 * bev), inlay * 0.9);
			float sheen = exp(-pow((tuv.x + tuv.y * 0.4 - lamp_uv.x - 0.1) / 0.18, 2.0)) * bev;
			col += lamp_col.rgb * sheen * 0.16;
			// outer edge darkening
			col *= 1.0 - 0.35 * smoothstep(frame_w - 3.0, frame_w, inner);
		}
		float a = 1.0 - smoothstep(-0.5, 0.5, d);
		outc = mix(outc, vec4(col, 1.0), a);
	}
	COLOR = outc;
}
