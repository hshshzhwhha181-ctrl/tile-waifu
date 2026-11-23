shader_type canvas_item;
// v06:hud — diamond (mahjong-lattice) wipe in graphite with a gold rim on every growing diamond.
// progress 0 = clear, 1 = fully covered.
uniform float progress = 0.0;
uniform vec4 color_a : source_color = vec4(0.17, 0.155, 0.18, 1.0);
uniform vec4 color_b : source_color = vec4(0.075, 0.065, 0.08, 1.0);
uniform vec4 rim : source_color = vec4(0.93, 0.78, 0.48, 1.0);
uniform vec4 rose : source_color = vec4(0.78, 0.5, 0.58, 1.0);
uniform vec2 size = vec2(720.0, 1280.0);
uniform float cell = 72.0;
void fragment() {
	vec2 p = UV * size;
	vec2 g = p / cell;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float delay = (id.y * cell / size.y) * 0.55 + abs(id.x * cell / size.x - 0.5) * 0.3;
	float t = clamp((progress * 1.8 - delay), 0.0, 1.0);
	float dm = abs(f.x) + abs(f.y);
	float edge = t * 1.05;
	float a = 1.0 - smoothstep(edge - 0.025, edge, dm);
	float band = (1.0 - smoothstep(0.0, 0.05, abs(dm - edge + 0.03))) * step(0.02, t) * (1.0 - step(0.999, t));
	vec3 col = mix(color_a.rgb, color_b.rgb, UV.y);
	col = mix(col, rose.rgb * 0.45, 0.25 * (1.0 - smoothstep(0.0, 0.9, length(UV - vec2(0.5, 0.45)))));
	col += 0.018 * sin((p.x - p.y) * 0.09);
	col = mix(col, rim.rgb, band * 0.9);
	COLOR = vec4(col, max(a, band));
}
