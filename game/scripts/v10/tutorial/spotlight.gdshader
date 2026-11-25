shader_type canvas_item;
render_mode unshaded;

// V10Coach spotlight (README §2.4): a night lacquer dim with ONE rounded window and a single gold hairline on its edge.
// Every length is in px of the coach's rect (= the viewport: the coach is full rect at the origin of its CanvasLayer).
// Colours come from V10DS through set_shader_parameter (no literals here).

uniform vec2 size_px = vec2(720.0, 1280.0);
uniform vec4 hole = vec4(0.0);          // x, y, w, h; w or h < 1 -> no window (plain dim)
uniform float radius = 4.0;
uniform float soft = 10.0;              // dim fades in over this many px outside the window
uniform vec4 dim_color = vec4(0.0, 0.0, 0.0, 0.72);   // rgb + alpha of the dim
uniform vec4 rim_color = vec4(1.0, 1.0, 1.0, 0.0);    // the hairline (alpha 0 = none)
uniform float rim_w = 1.5;
uniform float amount = 1.0;             // master fade 0..1 (dim and hairline)
uniform vec4 calm = vec4(0.0);          // the line's block: a soft edgeless shade behind it (no box), x y w h
uniform float calm_a = 0.0;             // its alpha (dim colour)
uniform float calm_soft = 56.0;         // how far it fades out around the block

float sd_rrect(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void fragment() {
	vec2 p = UV * size_px;
	float a_dim = dim_color.a;
	float a_rim = 0.0;
	if (calm.z >= 1.0 && calm.w >= 1.0) {
		// a stadium around the text block, fading over calm_soft px: reads as shade, never as a card
		vec2 cs = calm.zw * 0.5;
		float dc = sd_rrect(p - (calm.xy + cs), cs, min(cs.x, cs.y));
		float k = 1.0 - smoothstep(-cs.y, max(calm_soft, 1.0), dc);
		a_dim = max(a_dim, calm_a * k * k * (3.0 - 2.0 * k));
	}
	if (hole.z >= 1.0 && hole.w >= 1.0) {
		vec2 hs = hole.zw * 0.5;
		float r = clamp(radius, 0.0, min(hs.x, hs.y));
		float d = sd_rrect(p - (hole.xy + hs), hs, r);
		a_dim *= smoothstep(0.0, max(soft, 0.001), d);
		// a crisp line of rim_w px lying just outside the window edge, 1 px of anti-aliasing
		float hw = rim_w * 0.5;
		a_rim = clamp(hw + 0.5 - abs(d - hw), 0.0, 1.0) * rim_color.a;
	}
	float a = a_rim + a_dim * (1.0 - a_rim);
	vec3 rgb = dim_color.rgb;
	if (a > 0.0001) {
		rgb = (rim_color.rgb * a_rim + dim_color.rgb * a_dim * (1.0 - a_rim)) / a;
	}
	COLOR = vec4(rgb, a * clamp(amount, 0.0, 1.0));
}
