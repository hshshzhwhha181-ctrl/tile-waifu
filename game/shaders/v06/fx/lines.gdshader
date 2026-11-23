shader_type canvas_item;
render_mode blend_add;
// V6Fx: anime speed lines converging on `focus` (UV). Additive; amount 0..1 drives density and reach.
uniform vec4 color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform vec2 focus = vec2(0.5, 0.45);
uniform float amount = 0.0;
uniform float aspect = 0.5625;
uniform float seed = 0.0;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 p = UV - focus;
	p.x /= aspect;
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float r = length(p);
	float n = 140.0;
	float id = floor(a * n);
	float f = fract(a * n);
	float t = floor(TIME * 18.0) + seed;               // re-roll lines 18x per second, like hand-drawn frames
	float on = step(0.55 - amount * 0.25, hash(id * 13.17 + t * 7.31));
	float w = 0.18 + 0.5 * hash(id * 3.7 + t);
	float line = smoothstep(w, 0.0, abs(f - 0.5) * 2.0);
	float start = mix(0.75, 0.32, amount) + 0.12 * hash(id + t * 1.3);
	float reach = smoothstep(start, start + 0.25, r);
	float v = on * line * reach * amount;
	COLOR = vec4(color.rgb, clamp(v * color.a, 0.0, 1.0));
}
