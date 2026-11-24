shader_type canvas_item;
// V10Juice: glint sweep masked by the item's own alpha (a sheen across a button, a card, a crest, a heroine).
// pos -0.4..1.4 drives one pass; with period > 0 it repeats by itself (zero script cost, idle shine).
// The band adds a warm tint with a cap (max_add) so a white button never clips to a flash.
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float pos = -0.4;
uniform float width = 0.09;
uniform float slant = 0.4;
uniform float amount = 0.55;
uniform float max_add = 0.35;
uniform float period = 0.0;
uniform float pause = 0.6;

void fragment() {
	vec4 c = COLOR; // Godot 4: COLOR already holds texture × modulate
	float p = pos;
	if (period > 0.0) {
		float ph = fract(TIME / period);
		p = mix(-0.4, 1.4, clamp(ph / max(0.05, 1.0 - pause), 0.0, 1.0));
	}
	float x = UV.x + (UV.y - 0.5) * slant;
	float b = exp(-pow((x - p) / width, 2.0)) + 0.45 * exp(-pow((x - p + width * 2.6) / (width * 0.32), 2.0));
	vec3 add = color.rgb * b * amount * color.a;
	c.rgb += min(add, vec3(max_add));
	COLOR = c;
}
