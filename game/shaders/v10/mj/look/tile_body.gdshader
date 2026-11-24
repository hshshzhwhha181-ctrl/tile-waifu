shader_type canvas_item;
// v10/mj/look — extruded tile body in layers (V10MjTileMaterial). Map assets/v10/mj/look/tile/body3.png:
// R = shade, G = layer (0 front slab · 0.5 seam line · 1 back), B = gloss, A = alpha. The slab takes the material's
// lip colour, the seam its inlay, the back its body colour: a real 3-layer edge like bone-and-bamboo tiles.
varying vec4 vcol;
varying vec2 wpos;
uniform vec4 slab : source_color = vec4(0.95, 0.91, 0.85, 1.0);
uniform vec4 seam : source_color = vec4(0.85, 0.70, 0.42, 1.0);
uniform vec4 back : source_color = vec4(0.25, 0.6, 0.5, 1.0);
uniform float seam_metal = 0.6;
uniform float body_alpha = 1.0;      // ice is a touch translucent
uniform float sss_k = 0.0;
uniform vec4 sss_col : source_color = vec4(0.5, 0.9, 0.7, 1.0);
uniform vec2 lamp = vec2(250.0, 330.0);
uniform vec3 lamp_col = vec3(1.0, 0.94, 0.84);
uniform float gloss = 1.0;
uniform float spec_k = 0.5;
uniform float shade = 1.0;
uniform float closed = 0.0;
uniform float breathe = 0.0;
uniform float phase = 0.0;
uniform float auto_phase = 0.0;     // 1 = phase from the node's world origin (shared materials)

void vertex() {
	VERTEX *= 1.0 + breathe * 0.005 * (1.0 - cos(TIME * 1.9634954 + mix(phase, fract(sin(dot(MODEL_MATRIX[3].xy, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831853, auto_phase)));
	vcol = COLOR;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	float g = m.g;
	vec3 base = mix(slab.rgb, seam.rgb, smoothstep(0.2, 0.45, g) * (1.0 - smoothstep(0.55, 0.8, g)));
	base = mix(base, back.rgb, smoothstep(0.55, 0.8, g));
	vec3 col = base * (m.r * 1.08);
	// back keeps saturation in shadow (lacquer, jade)
	col = mix(col, col * (base / max(max(base.r, base.g), max(base.b, 0.001))), (1.0 - m.r) * 0.35 * step(0.6, g));
	float dist = length(lamp - wpos);
	float near = 1.0 - smoothstep(150.0, 1100.0, dist);
	col += m.b * lamp_col * gloss * (0.12 + 0.22 * near) * (0.6 + spec_k * 0.8);
	float is_seam = smoothstep(0.2, 0.45, g) * (1.0 - smoothstep(0.55, 0.8, g));
	col += is_seam * lamp_col * seam_metal * 0.18 * (0.5 + near);
	col += sss_col.rgb * sss_k * 0.22 * step(0.6, g);
	// contact AO: the lowest pixels of the body darken toward the table
	col *= 1.0 - 0.28 * smoothstep(0.82, 0.98, UV.y);
	col *= shade * (1.0 - 0.18 * closed);
	COLOR = vec4(col, m.a * body_alpha) * vcol;
}
