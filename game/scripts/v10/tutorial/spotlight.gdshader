shader_type canvas_item;

// V10Coach spotlight: dims the whole screen except a soft-edged rounded hole around the target, with a warm
// gold rim that breathes. Drawn on one full-screen ColorRect; `size` is that rect in px (UV * size = pixel).

uniform vec2 size = vec2(720.0, 1280.0);
uniform vec4 hole = vec4(0.0, 0.0, 0.0, 0.0);   // x, y, w, h in px
uniform float radius = 26.0;
uniform float feather = 22.0;
uniform float has_hole = 1.0;                   // 0: plain dim (bubble-only step), 1: hole
uniform vec4 dim : source_color = vec4(0.035, 0.02, 0.05, 0.74);
uniform float rim = 0.0;                        // 0..1 rim strength (breathing)
uniform vec4 rim_color : source_color = vec4(1.0, 0.86, 0.56, 1.0);
uniform float amount = 1.0;                     // fade in / out of the whole layer

float sd_rrect(vec2 p, vec2 c, vec2 hs, float r) {
	vec2 q = abs(p - c) - hs + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * size;
	float a = 1.0;
	float glow = 0.0;
	if (has_hole > 0.5 && hole.z > 1.0 && hole.w > 1.0) {
		vec2 hs = hole.zw * 0.5;
		float r = min(radius, min(hs.x, hs.y));
		float d = sd_rrect(p, hole.xy + hs, hs, r);
		a = smoothstep(-feather * 0.25, feather, d);
		// a thin warm line hugging the hole, and a wide faint halo outside it
		glow = (exp(-abs(d - 3.0) / 3.5) * 0.85 + exp(-max(d, 0.0) / 38.0) * 0.18) * rim;
	}
	// the dim is a touch lighter toward the centre: a vignette, not a flat grey sheet
	vec2 uvc = UV - vec2(0.5);
	float vig = 1.0 + dot(uvc, uvc) * 0.35;
	vec4 col = vec4(dim.rgb, clamp(dim.a * a * vig, 0.0, 0.92));
	col.rgb = mix(col.rgb, rim_color.rgb, clamp(glow, 0.0, 1.0));
	col.a = max(col.a, clamp(glow, 0.0, 1.0) * rim_color.a);
	col.a *= amount;
	COLOR = col;
}
