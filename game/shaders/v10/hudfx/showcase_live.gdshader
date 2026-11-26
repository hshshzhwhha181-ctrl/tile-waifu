shader_type canvas_item;

// V10ShowcaseFx — the live combo-showcase sprite (docs/HUD_V2.md §7.3 «Пока держит»). A SUPERSET of
// hud2/showcase_sprite.gdshader: every uniform of it is here with the same default, and the board mask is the
// same code line for line (V10ComboShowcase.mask_alpha is its GDScript twin), so hud2 can swap materials freely.
//  * board mask — over board_rect at board_alpha (soft board_feather px outside the board); inside the central
//    pair zone at center_alpha with a `feather` px edge OUTSIDE the zone: no pixel in the zone exceeds center_alpha.
//  * sway  — hair UV displacement ≤ sway_px sprite px: sin(sway_time·2π/sway_period + uv.y·3) × hair mask × sway
//    (the hold envelope, 0 outside «держит»). Roots on the head stay, the tails move; the mask is feathered and the
//    displacement is 0 wherever the mask is 0, so there is no seam.
//  * sheen — one warm band (sheen_color, value ≤ 0.8, α ≤ 0.35) travels down the legwear (sheen_phase 0 → 1 in
//    0.6 s), strictly × leg mask (below the knee) and never above leg_guard.
//  * rim   — the hud2 T3 contour light, upgraded: accent (value ≤ 0.8), swept top → bottom (rim_phase 0 → 1);
//    edge = α − min α of 4 neighbours at rim_px (≈ 3 screen px; + a softer ring at 2×), plus a soft light wrap
//    just outside the silhouette, stronger on edges facing the light (top right, where the showcase ray comes
//    from). Zones: above the chest everything; chest → waist only her back's edge; waist → feet only hair and the
//    leg mask (below the knee) — never the chest, the crotch or a thigh.
// Light is screen-blended (never darkens, never white). ≤ 14 texture samples per fragment with the rim on, 1–2 at rest.
// Godot 4: COLOR already equals texture × modulate; TEXTURE is resampled (× vertex modulate) only where hair moves.
// Rects are in canvas (viewport base) px; MODEL_MATRIX maps the TextureRect's local px into that space.

// --- hud2/showcase_sprite.gdshader (unchanged names and defaults) ---
uniform vec4 board_rect = vec4(0.0);
uniform vec4 center_rect = vec4(0.0);
uniform float board_alpha = 1.0;
uniform float center_alpha = 1.0;
uniform float feather = 24.0;
uniform float board_feather = 64.0;  // soft edge of the board mask, outside the board (no hard line across her)
uniform vec4 rim_color : source_color = vec4(1.0, 0.7, 0.8, 1.0);
uniform float rim = 0.0;
uniform float rim_phase = 0.0;  // 0..1 sweep position (top -> bottom)

// --- live additions (V10ShowcaseFx) ---
uniform sampler2D hair_mask : hint_default_black, filter_linear;
uniform sampler2D leg_mask : hint_default_black, filter_linear;
uniform float hair_strength = 0.0;  // 0 = no hair mask: no sway, no hair rim
uniform float leg_strength = 0.0;  // 0 = no leg mask: no sheen, no calf rim
uniform vec4 face_uv = vec4(0.4, 0.08, 0.2, 0.12);  // face rect in UV (x, y, w, h)
uniform float sway = 0.0;  // hold envelope 0..1
uniform float sway_time = 0.0;  // s since the hold began
uniform float sway_px = 6.0;  // amplitude in sprite px (clamped to 6)
uniform float sway_period = 2.4;
uniform float sheen = 0.0;  // 1 while the band runs
uniform float sheen_phase = 0.0;  // 0..1 knee -> ankle
uniform vec4 sheen_color : source_color = vec4(0.8, 0.66, 0.7, 1.0);
uniform float sheen_alpha = 0.35;
uniform vec4 leg_box = vec4(0.0, 0.7, 1.0, 0.3);  // UV bbox of the leg mask
uniform float leg_guard = 0.5;  // UV y: the sheen never reaches above it
uniform float rim_px = 7.0;  // neighbour distance, sprite px (≈ 3 screen px)
uniform float rim_base = 0.25;  // contour level under the band (1.0 = steady rim without a sweep: calm)
uniform vec2 quiet_band = vec2(0.3, 0.5);  // UV y: chest top, waist (rim zones, see the rim block)
uniform float back_x = 1.0;  // +1: her back is to the right (every showcase sprite faces frame-left)

varying vec2 wpos;
varying vec4 vmod;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vmod = COLOR;
}

float outside_dist(vec4 r, vec2 p) {
	vec2 d = max(r.xy - p, p - (r.xy + r.zw));
	return max(d.x, d.y);  // < 0 inside, > 0 outside (px)
}

vec3 cap_value(vec3 c, float v) {
	float m = max(max(c.r, c.g), c.b);
	return m > v ? c * (v / m) : c;
}

vec3 screen(vec3 c, vec3 l) {
	return vec3(1.0) - (vec3(1.0) - c) * (vec3(1.0) - l);
}

void fragment() {
	vec4 c = COLOR;
	vec2 uv = UV;
	float hm = 0.0;
	if (hair_strength > 0.0) {
		hm = texture(hair_mask, UV).r * hair_strength;
		if (sway > 0.0) {  // uniform branch; d = 0 wherever the mask is 0 (no seam, same texel as COLOR)
			float root = smoothstep(face_uv.y + face_uv.w * 0.5, face_uv.y + face_uv.w * 2.0, UV.y);
			float d = sway * hm * root * sin(sway_time * TAU / max(sway_period, 0.1) + UV.y * 3.0);
			uv.x += d * min(sway_px, 6.0) * TEXTURE_PIXEL_SIZE.x;
			c = texture(TEXTURE, uv) * vmod;
		}
	}
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
	float lm = 0.0;
	if (leg_strength > 0.0 && (sheen > 0.0 || rim > 0.0)) {
		lm = texture(leg_mask, UV).r * leg_strength;
	}
	if (sheen > 0.0 && lm > 0.0) {
		// a slanted (≈ 20°) soft band, knee -> ankle across the leg mask's box, in sprite px
		vec2 px = UV / TEXTURE_PIXEL_SIZE;
		vec2 b0 = leg_box.xy / TEXTURE_PIXEL_SIZE;
		vec2 bs = max(leg_box.zw / TEXTURE_PIXEL_SIZE, vec2(1.0));
		float w = max(bs.y * 0.2, 24.0);
		float slant = 0.36;
		float y0 = b0.y - w - slant * bs.x * 0.5;
		float y1 = b0.y + bs.y + w + slant * bs.x * 0.5;
		float yl = mix(y0, y1, clamp(sheen_phase, 0.0, 1.0)) + slant * (px.x - b0.x - bs.x * 0.5);
		float band = 1.0 - smoothstep(0.0, w, abs(px.y - yl));
		float guard = smoothstep(leg_guard, leg_guard + 0.02, UV.y);
		float k = band * band * lm * guard * sheen * min(sheen_alpha, 0.35);
		c.rgb = screen(c.rgb, cap_value(sheen_color.rgb, 0.8) * k);
	}
	if (rim > 0.0) {
		// two rings of 4 samples (rim_px ≈ 3 screen px, and 2 × rim_px): a soft two-step profile inside (edge) and
		// outside (wrap). edge = α − min α of the rim_px ring (+ 40 % of the outer ring's)
		vec2 o = TEXTURE_PIXEL_SIZE * rim_px;
		vec2 o2 = o * 2.0;
		float aR = texture(TEXTURE, uv + vec2(o.x, 0.0)).a;
		float aL = texture(TEXTURE, uv - vec2(o.x, 0.0)).a;
		float aD = texture(TEXTURE, uv + vec2(0.0, o.y)).a;
		float aU = texture(TEXTURE, uv - vec2(0.0, o.y)).a;
		float bR = texture(TEXTURE, uv + vec2(o2.x, 0.0)).a;
		float bL = texture(TEXTURE, uv - vec2(o2.x, 0.0)).a;
		float bD = texture(TEXTURE, uv + vec2(0.0, o2.y)).a;
		float bU = texture(TEXTURE, uv - vec2(0.0, o2.y)).a;
		float ta = c.a / max(vmod.a, 0.001);
		float mn = 0.6 * min(min(aR, aL), min(aD, aU)) + 0.4 * min(min(bR, bL), min(bD, bU));
		float mx = 0.6 * max(max(aR, aL), max(aD, aU)) + 0.4 * max(max(bR, bL), max(bD, bU));
		float edge = clamp(ta - mn, 0.0, 1.0);
		float wrap = clamp(mx - ta, 0.0, 1.0);
		vec2 n = vec2(aL - aR + bL - bR, aU - aD + bU - bD);  // outward normal (alpha falls outward)
		float nl = length(n);
		vec2 nn = nl > 0.001 ? n / nl : vec2(0.0);
		float dirw = 0.4 + 0.6 * smoothstep(-0.3, 0.7, dot(nn, vec2(0.78 * back_x, -0.62)));
		// masks and zones are read just inside the silhouette, so the wrap is gated like the edge it hugs
		vec2 inner = UV - nn * o * 1.25;
		float hmi = hm;
		float lmi = lm;
		if (hair_strength > 0.0) {
			hmi = max(hm, texture(hair_mask, inner).r * hair_strength);
		}
		if (leg_strength > 0.0) {
			lmi = max(lm, texture(leg_mask, inner).r * leg_strength);
		}
		// zones: above the chest — all; chest → waist — only her back's edge (she faces away from back_x);
		// waist → feet — only hair and the leg mask (below the knee). Never the chest, the crotch or a thigh.
		float below_chest = smoothstep(quiet_band.x - 0.015, quiet_band.x + 0.015, inner.y);
		float below_waist = smoothstep(quiet_band.y - 0.015, quiet_band.y + 0.015, inner.y);
		float back = smoothstep(0.15, 0.55, nn.x * back_x);
		float zone = mix(1.0, mix(back, 0.0, below_waist), below_chest);
		float allow = max(max(hmi, lmi), zone);
		float yc = mix(-0.12, 1.12, clamp(rim_phase, 0.0, 1.0));
		float dy = UV.y - yc;
		float band = dy > 0.0 ? 1.0 - smoothstep(0.0, 0.07, dy) : 1.0 - smoothstep(0.0, 0.3, -dy);
		float lvl = rim * allow * dirw * (rim_base + (1.0 - rim_base) * band);
		vec3 rc = cap_value(rim_color.rgb, 0.8);
		c.rgb = screen(c.rgb, rc * min(edge * lvl, 0.85));
		// light wrap: a thin soft glow just outside the silhouette, composited under her
		float wa = min(wrap * lvl * 0.85, 0.75) * vmod.a;
		float oa = c.a + wa * (1.0 - c.a);
		c.rgb = (c.rgb * c.a + rc * wa * (1.0 - c.a)) / max(oa, 0.0001);
		c.a = oa;
	}
	COLOR = vec4(c.rgb, c.a * a);
}
