shader_type canvas_item;
render_mode blend_add;

// V10RigSheen specular sweep (docs/LEGWEAR.md §4.2, §5.1; scripts/v10/rig/DATA.md).
// Drawn on a duplicate of a skinned Polygon2D layer so the band follows the rig bones.
// Warm light only (value <= 0.80, alpha <= 0.85, never white) and strictly below knee_y.

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform vec2 layer_origin = vec2(0.0, 0.0);
uniform float knee_y = 1290.0;
uniform vec2 band_from = vec2(600.0, 1290.0);
uniform vec2 band_to = vec2(600.0, 1396.0);
uniform float band_width = 18.0;
uniform float phase = -1.0;
uniform float strength = 0.35;
uniform vec3 sheen_color = vec3(0.80, 0.74, 0.64);

void fragment() {
	vec2 tex_px = UV / TEXTURE_PIXEL_SIZE;
	vec2 body_p = tex_px + layer_origin;
	if (phase <= 0.0 || phase >= 1.0 || body_p.y < knee_y) {
		COLOR = vec4(0.0);
	} else {
		float base_a = texture(TEXTURE, UV).a;
		float m = texture(mask_tex, UV).r;
		vec2 span = band_to - band_from;
		float total = max(length(span), 1.0);
		vec2 dir = span / total;
		float center = mix(-band_width * 1.5, total + band_width * 1.5, phase);
		float proj = dot(body_p - band_from, dir);
		float d = (proj - center) / max(band_width, 1.0);
		float band = exp(-d * d * 2.0) * sin(phase * 3.14159265);
		float knee_gate = smoothstep(knee_y, knee_y + 10.0, body_p.y);
		float a = clamp(base_a * m * knee_gate * band * strength, 0.0, 0.85);
		vec3 col = min(sheen_color, vec3(0.80));
		COLOR = vec4(col, a);
	}
}
