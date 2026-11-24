shader_type canvas_item;

// «Стоп-кадр с дыханием» (spec §Р2 п.1): a still heroine that breathes until her rig exists. Works on a cutout
// (mask = its own alpha) or on a full scene image with a separate cutout as `mask` (only she moves, the room
// stays). Breathing lifts the chest/shoulder band, the head follows a little later, the braid/hair sways,
// and a tap «hop» squashes and stretches her from the feet. Tiny amplitudes: 1–3 px at 720 px wide.

uniform float t = 0.0;
uniform float breath = 0.0;       // 0..1 (eased in GDScript)
uniform float hop = 0.0;          // −1..1 squash (−) / stretch (+)
uniform float sway = 0.0;         // −1..1 hair sway
uniform float use_mask = 0.0;
uniform sampler2D mask : filter_linear;
uniform vec4 mask_rect = vec4(0.0, 0.0, 1.0, 1.0);  // where the cutout sits inside this texture (uv)
uniform vec2 chest = vec2(0.30, 0.42);   // uv y band of the chest
uniform float head_y = 0.16;             // uv y of the head centre
uniform vec2 hair_x = vec2(0.55, 0.80);  // uv x band of the braid
uniform vec2 px = vec2(0.0014, 0.0008);  // one art pixel in uv

void fragment() {
	vec2 uv = UV;
	float m = 1.0;
	if (use_mask > 0.5) {
		vec2 mu = (uv - mask_rect.xy) / mask_rect.zw;
		m = (mu.x < 0.0 || mu.y < 0.0 || mu.x > 1.0 || mu.y > 1.0) ? 0.0 : texture(mask, mu).a;
		m = smoothstep(0.0, 0.6, m);
	}
	float b = breath;
	// chest band rises and widens slightly
	float cb = smoothstep(chest.x - 0.08, chest.x, uv.y) * (1.0 - smoothstep(chest.y, chest.y + 0.12, uv.y));
	float above = 1.0 - smoothstep(chest.x - 0.1, chest.y, uv.y);
	vec2 off = vec2(0.0);
	off.y += (cb * 2.2 + above * 1.6) * b * px.y;
	// head follows with a tiny nod
	float hb = 1.0 - smoothstep(head_y, head_y + 0.14, uv.y);
	off.y += hb * sin(t * 0.9) * 1.2 * px.y;
	off.x += hb * sin(t * 0.63 + 1.0) * 1.4 * px.x;
	// hair/braid sway grows downwards
	float hx = smoothstep(hair_x.x - 0.05, hair_x.x, uv.x) * (1.0 - smoothstep(hair_x.y, hair_x.y + 0.05, uv.x));
	off.x += hx * smoothstep(head_y, 0.7, uv.y) * (sin(t * 1.1) * 2.2 + sway * 6.0) * px.x;
	// hop: scale about the feet
	float s = 1.0 + hop * 0.03;
	vec2 feet = vec2(0.5, 1.0);
	vec2 huv = feet + (uv - feet) * vec2(1.0 / (1.0 - hop * 0.012), 1.0 / s);
	vec2 suv = mix(uv, huv, m) + off * m;
	COLOR = texture(TEXTURE, suv) * COLOR;
}
