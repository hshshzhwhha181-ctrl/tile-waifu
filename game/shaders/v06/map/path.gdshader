shader_type canvas_item;
// v06:map — map path drawn on a Line2D (texture_mode = stretch): round stepping stones along the
// line; stones before `progress` (px) glow gold with a pulse flowing towards the current level.
uniform float len = 1000.0;
uniform float progress = 0.0;
uniform float width = 30.0;
uniform float spacing = 34.0;
uniform vec4 done_col : source_color = vec4(1.0, 0.86, 0.42, 1.0);
uniform vec4 todo_col : source_color = vec4(1.0, 0.97, 0.94, 0.62);
uniform vec4 edge_col : source_color = vec4(0.28, 0.08, 0.24, 0.75);
uniform vec4 glow_col : source_color = vec4(1.0, 0.95, 0.75, 1.0);
void fragment() {
	float d = UV.x * len;
	float across = (UV.y - 0.5) * width;
	float k = fract(d / spacing) - 0.5;
	vec2 p = vec2(k * spacing, across);
	bool done = d < progress;
	float r = width * (done ? 0.36 : 0.28);
	float sd = length(p) - r;
	float fill = 1.0 - smoothstep(-1.0, 1.0, sd);
	float rim = 1.0 - smoothstep(-1.0, 1.0, sd - 3.0);
	vec4 c = done ? done_col : todo_col;
	float hl = smoothstep(r, 0.0, length(p - vec2(-r * 0.25, -r * 0.35)));
	vec3 col = c.rgb * (0.82 + 0.35 * hl);
	if (done) {
		float w = fract(d / 260.0 - TIME * 0.45);
		col += glow_col.rgb * pow(max(0.0, 1.0 - abs(w - 0.5) * 2.0), 10.0) * 0.8;
	} else {
		// faint guiding shimmer on the road ahead, fading with distance
		float ahead = clamp(1.0 - (d - progress) / 500.0, 0.0, 1.0);
		float w = fract(d / 180.0 - TIME * 0.6);
		col += glow_col.rgb * pow(max(0.0, 1.0 - abs(w - 0.5) * 2.0), 12.0) * 0.6 * ahead;
	}
	vec4 o = mix(vec4(edge_col.rgb, edge_col.a), vec4(col, c.a), fill);
	COLOR = vec4(o.rgb, o.a * rim);
}
