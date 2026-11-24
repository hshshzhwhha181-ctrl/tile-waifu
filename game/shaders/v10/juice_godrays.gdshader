shader_type canvas_item;
render_mode blend_add;
// V10Juice: god-rays from `origin` (UV): two counter-rotating ray sets with soft noisy widths, radial falloff,
// optional cone (spread < 1 limits them around `aim`, an angle in radians; -PI/2 = up). Additive, warm, capped.
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.45, 1.0);
uniform vec2 origin = vec2(0.5, 0.5);
uniform float intensity = 0.0;
uniform float count = 14.0;
uniform float speed = 0.12;
uniform float spread = 1.0;
uniform float aim = -1.5708;
uniform float falloff = 1.2;

float hash(float x) { return fract(sin(x * 91.7) * 43758.5453); }

void fragment() {
	vec2 q = UV - origin;
	float d = length(q) * 2.0;
	float ang = atan(q.y, q.x);
	float t = TIME * speed;
	float r1 = pow(max(0.0, sin(ang * count + t * 6.2832)), 6.0);
	float r2 = pow(max(0.0, sin(ang * (count * 0.5 + 3.0) - t * 4.0 + 1.3)), 10.0) * 0.7;
	float w = 0.6 + 0.4 * sin(ang * 3.0 + t * 2.0);
	float rays = (r1 * w + r2) * 0.8;
	float da = abs(mod(ang - aim + 3.14159, 6.28318) - 3.14159);
	float cone = spread >= 1.0 ? 1.0 : 1.0 - smoothstep(spread * 3.14159 * 0.6, spread * 3.14159, da);
	float core = exp(-d * d * 18.0) * 0.6;
	float fall = pow(max(0.0, 1.0 - d), falloff);
	float a = clamp((rays * fall + core) * cone * intensity, 0.0, 0.85);
	COLOR = vec4(color.rgb * a, a);
}
