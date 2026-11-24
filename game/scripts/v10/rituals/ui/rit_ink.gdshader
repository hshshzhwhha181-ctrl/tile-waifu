shader_type canvas_item;
// Ink reveal for the weekly letter (Р10): text appears as if written, line by line, left to right, with a soft
// wet edge that is slightly darker than the dry ink. progress 0..1 over the whole block.
uniform float progress : hint_range(0.0, 1.2) = 0.0;
uniform float line_h = 40.0;
uniform float block_w = 600.0;
uniform float lines = 4.0;
uniform float edge = 0.035;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float li = floor(lp.y / line_h);
	float pos = (li + clamp(lp.x / block_w, 0.0, 1.0)) / max(lines, 1.0);
	float a = 1.0 - smoothstep(progress - edge, progress, pos);
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float wet = smoothstep(progress - edge * 3.0, progress - edge * 0.5, pos) * a;
	c.rgb = mix(c.rgb, c.rgb * 0.55, wet);
	c.a *= a;
	COLOR = c;
}
