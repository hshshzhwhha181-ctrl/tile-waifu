shader_type canvas_item;
// Rotating god rays from center.
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform float count = 14.0;
uniform float speed = 0.25;
uniform float intensity = 1.0;
uniform float softness = 0.6;
void fragment() {
	vec2 p = UV - 0.5;
	float a = atan(p.y, p.x);
	float r = length(p) * 2.0;
	float rays = pow(0.5 + 0.5 * sin(a * count + TIME * speed * 6.2831), 3.0);
	rays += 0.5 * pow(0.5 + 0.5 * sin(a * count * 0.5 - TIME * speed * 4.0 + 1.3), 4.0);
	float fall = (1.0 - smoothstep(0.0, 1.0, r)) ;
	float core = exp(-r * r * 18.0);
	float v = (rays * fall * softness + core) * intensity;
	COLOR = vec4(color.rgb, clamp(v * color.a, 0.0, 1.0));
}
