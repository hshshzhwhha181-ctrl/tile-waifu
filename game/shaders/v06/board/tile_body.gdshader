shader_type canvas_item;
// v06:board — extruded tile body from a baked map: R shade, G band (ivory -> colored back), B gloss.
varying vec4 vcol;
varying vec2 wpos;
uniform vec4 ivory : source_color = vec4(0.96, 0.92, 0.86, 1.0);
uniform vec4 back : source_color = vec4(0.25, 0.6, 0.5, 1.0);
uniform vec2 lamp = vec2(250.0, 330.0);
uniform vec3 lamp_col = vec3(1.0, 0.94, 0.84);
uniform float gloss = 1.0;
uniform float neon = 0.0;
uniform float shade = 1.0;

void vertex() {
	vcol = COLOR;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	vec3 base = mix(ivory.rgb, back.rgb, m.g);
	// lacquer back keeps its saturation in shadow
	vec3 col = base * (m.r * 1.08);
	col = mix(col, col * (base / max(max(base.r, base.g), max(base.b, 0.001))), (1.0 - m.r) * 0.35 * m.g);
	float dist = length(lamp - wpos);
	float near = 1.0 - smoothstep(150.0, 1100.0, dist);
	col += m.b * lamp_col * gloss * (0.16 + 0.22 * near);
	col += neon * m.g * back.rgb * 0.35 * (0.7 + 0.3 * sin(TIME * 3.0));
	col *= shade;
	COLOR = vec4(col, m.a) * vcol;
}
