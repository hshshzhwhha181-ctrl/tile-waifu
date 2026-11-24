shader_type canvas_item;
// v10/mj/look — a parallax layer of the heroine's table backdrop (V10MjTableView).
// far: darkened toward the bottom so the board area stays calm (and a gentle grade to the table's mood);
// near: out-of-focus foreground that is NEVER drawn over the sacred zone (docs/MODES.md §3.1): alpha → 0 inside the
// sacred rect grown by `pad`, with a soft `feather`.
uniform int mode = 0;                        // 0 far, 1 near
uniform vec4 sacred = vec4(0.0);             // x, y, w, h in the layer's local px
uniform float pad = 8.0;
uniform float feather = 28.0;
uniform vec2 rect_size = vec2(720.0, 1280.0);   // the view's size (layer px are view-local)
uniform float dark_from = 0.32;              // far: start darkening at this height (0 top … 1 bottom)
uniform float dark_k = 0.55;
uniform vec4 grade : source_color = vec4(1.0);
uniform float alpha_k = 1.0;
uniform float top_scrim = 0.45;

varying vec2 lpos;

void vertex() {
	lpos = VERTEX;
}

float sd_box(vec2 p, vec2 h) {
	vec2 q = abs(p) - h;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = lpos;
	vec2 su = lpos / rect_size;
	if (mode == 0) {
		float v = smoothstep(dark_from, 1.0, su.y);
		c.rgb *= 1.0 - dark_k * v;
		// top scrim: her band carries the HUD line and the title, keep text ≥ 4.5:1 over a bright moon or lamp
		c.rgb *= 1.0 - top_scrim * (1.0 - smoothstep(0.0, 150.0, px.y));
		c.rgb *= grade.rgb;
		// edge vignette
		float vig = length((su - vec2(0.5, 0.42)) * vec2(1.0, 0.8));
		c.rgb *= 1.0 - 0.35 * smoothstep(0.35, 0.85, vig);
	} else {
		if (sacred.z > 0.0) {
			float d = sd_box(px - (sacred.xy + sacred.zw * 0.5), sacred.zw * 0.5 + vec2(pad));
			c.a *= smoothstep(0.0, feather, d);
		}
		c.a *= alpha_k;
		c.a *= 1.0 - 0.5 * (1.0 - smoothstep(40.0, 150.0, px.y)) * step(0.5, top_scrim);
	}
	COLOR = c;
}
