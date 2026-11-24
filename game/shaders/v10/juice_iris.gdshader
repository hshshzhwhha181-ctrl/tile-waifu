shader_type canvas_item;
// V10Juice: lantern-light iris. The night closes in around `center` (pixels) like a paper lantern's pool of light:
// warm amber rim with lantern ribs, dark outside. progress 0 = open, 1 = closed (fully dark).
// The rim stays below 0.8 value: warm glow, never a white flash.
uniform float progress = 0.0;
uniform vec2 size = vec2(720.0, 1280.0);
uniform vec2 center = vec2(360.0, 640.0);
uniform vec4 night : source_color = vec4(0.055, 0.045, 0.065, 1.0);
uniform vec4 night_far : source_color = vec4(0.025, 0.02, 0.035, 1.0);
uniform vec4 glow : source_color = vec4(0.86, 0.55, 0.26, 1.0);
uniform vec4 glow_deep : source_color = vec4(0.62, 0.2, 0.18, 1.0);
uniform float ribs = 18.0;

void fragment() {
	vec2 p = UV * size;
	vec2 q = p - center;
	float d = length(q);
	float far = max(max(length(center), length(center - vec2(size.x, 0.0))), max(length(center - vec2(0.0, size.y)), length(center - size)));
	float e = 1.0 - progress;
	// ease so the last 20 % close quickly (the hole lingers on the lantern a beat)
	float r = far * 1.05 * e * e * (3.0 - 2.0 * e) - 6.0;
	float ang = atan(q.y, q.x);
	// paper-lantern ribs: a slow wobble of the rim
	float wob = 1.0 + 0.025 * sin(ang * ribs + progress * 6.0) + 0.015 * sin(ang * 5.0 - progress * 4.0);
	float rr = r * wob;
	float outside = smoothstep(rr - 2.0, rr + 2.0, d);
	float band = exp(-pow((d - rr) / (18.0 + r * 0.025), 2.0));
	float inner = exp(-pow((d - rr + 24.0) / 40.0, 2.0)) * (1.0 - outside);
	vec3 dark = mix(night.rgb, night_far.rgb, clamp(d / far, 0.0, 1.0));
	vec3 col = dark;
	float rib = 0.75 + 0.25 * smoothstep(0.3, 1.0, abs(sin(ang * ribs * 0.5)));
	vec3 warm = mix(glow_deep.rgb, glow.rgb, band) * rib;
	float on = step(0.002, progress) * (1.0 - smoothstep(0.93, 1.0, progress));
	col = mix(col, warm, band * 0.8 * on * outside);
	float a = max(outside, (band * 0.45 + inner * 0.12) * on);
	vec3 c2 = mix(warm, col, outside);
	COLOR = vec4(mix(c2, col, outside), a);
}
