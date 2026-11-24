// V10LiveRig iris: draws an eye opening (the "socket": the art with the iris painted out) and the iris texture
// on top of it at an offset, so the pupils can look around inside the opening. offset (0,0) = the original art.
shader_type canvas_item;

uniform sampler2D iris_tex : filter_linear, repeat_disable;
uniform vec2 offset_px = vec2(0.0);
uniform vec2 size_px = vec2(64.0, 32.0);

void fragment() {
	vec4 base = COLOR;  // socket texture * modulate
	vec2 iuv = UV - offset_px / size_px;
	vec4 ir = texture(iris_tex, iuv);
	float inside = step(0.0, iuv.x) * step(iuv.x, 1.0) * step(0.0, iuv.y) * step(iuv.y, 1.0);
	COLOR = vec4(mix(base.rgb, ir.rgb, ir.a * inside), base.a);
}
