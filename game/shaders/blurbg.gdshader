shader_type canvas_item;
// Cover-fit background with cheap blur, brightness and tint (for scene backdrops).
uniform vec2 size = vec2(720.0, 1280.0);
uniform vec2 tex_size = vec2(1600.0, 893.0);
uniform vec2 focus = vec2(0.5, 0.5);
uniform float blur = 0.0;
uniform float bright = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float zoom = 1.0;
uniform vec2 drift = vec2(0.0);
void fragment() {
	float sa = size.x / size.y, ta = tex_size.x / tex_size.y;
	vec2 scale = sa > ta ? vec2(1.0, ta / sa) : vec2(sa / ta, 1.0);
	scale /= zoom;
	vec2 uv = focus + (UV - 0.5) * scale + drift * vec2(sin(TIME * 0.11), cos(TIME * 0.09)) * 0.01;
	vec3 col = vec3(0.0);
	if (blur > 0.0) {
		float b = blur / tex_size.x;
		float w = 0.0;
		for (int i = -2; i <= 2; i++) for (int j = -2; j <= 2; j++) {
			float k = exp(-float(i * i + j * j) / 4.0);
			col += texture(TEXTURE, uv + vec2(float(i), float(j)) * b).rgb * k; w += k;
		}
		col /= w;
	} else {
		col = texture(TEXTURE, uv).rgb;
	}
	COLOR = vec4(col * bright * tint.rgb, 1.0);
}
