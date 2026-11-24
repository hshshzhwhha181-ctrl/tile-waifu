shader_type canvas_item;

// V10ComboShowcase sprite (docs/HUD_V2.md §7.2-7.3).
//  * board mask: over board_rect the heroine draws at board_alpha (T1: 0.45, T2/T3: 1.0);
//    inside the central pair zone (centre 60 % x 60 % of the board) at center_alpha (T1: 0.0) with a soft
//    `feather` px edge OUTSIDE the zone, so no pixel inside the zone ever exceeds center_alpha.
//  * rim: backlight in the heroine's accent along the silhouette (T3, 0.6 s sweep) — no white, ≤ 70 % brightness.
// Rects are in canvas (viewport base) px; MODEL_MATRIX maps the TextureRect's local px into that space.

uniform vec4 board_rect = vec4(0.0);
uniform vec4 center_rect = vec4(0.0);
uniform float board_alpha = 1.0;
uniform float center_alpha = 1.0;
uniform float feather = 24.0;
uniform float board_feather = 64.0;  // soft edge of the board mask, outside the board (no hard line across her)
uniform vec4 rim_color : source_color = vec4(1.0, 0.7, 0.8, 1.0);
uniform float rim = 0.0;
uniform float rim_phase = 0.0;  // 0..1 sweep position (top -> bottom)

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float outside_dist(vec4 r, vec2 p) {
	vec2 d = max(r.xy - p, p - (r.xy + r.zw));
	return max(d.x, d.y);  // < 0 inside, > 0 outside (px)
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float a = 1.0;
	if (board_rect.z > 0.0) {
		float db = outside_dist(board_rect, wpos);
		a = mix(board_alpha, 1.0, clamp(db / max(board_feather, 0.001), 0.0, 1.0));
	}
	if (center_rect.z > 0.0) {
		float dc = outside_dist(center_rect, wpos);
		float k = clamp(dc / max(feather, 0.001), 0.0, 1.0);  // 0 inside the zone, 1 at feather px outside
		a = min(a, mix(center_alpha, 1.0, k));
	}
	if (rim > 0.0) {
		vec2 o = TEXTURE_PIXEL_SIZE * 7.0;
		float m = min(min(texture(TEXTURE, UV + vec2(o.x, 0.0)).a, texture(TEXTURE, UV - vec2(o.x, 0.0)).a),
				min(texture(TEXTURE, UV + vec2(0.0, o.y)).a, texture(TEXTURE, UV - vec2(0.0, o.y)).a));
		float edge = clamp(c.a - m, 0.0, 1.0);
		float band = 1.0 - smoothstep(0.0, 0.22, abs(UV.y - rim_phase));
		c.rgb = mix(c.rgb, rim_color.rgb * 0.7 + c.rgb * 0.3, edge * rim * (0.35 + 0.65 * band));
	}
	COLOR = vec4(c.rgb, c.a * a);
}
