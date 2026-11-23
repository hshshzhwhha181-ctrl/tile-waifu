shader_type canvas_item;
varying vec4 vcol;
void vertex() { vcol = COLOR; }
// Card art: rounded mask, cover-fit crop, holo foil for SSR, darkening ramp at bottom.
uniform vec2 size = vec2(120.0, 170.0);
uniform float radius = 14.0;
uniform vec2 tex_size = vec2(859.0, 1280.0);
uniform vec2 focus = vec2(0.5, 0.25);
uniform float zoom = 1.0;
uniform float holo = 0.0;
uniform float bottom_shade = 0.55;
uniform float flash = 0.0;
uniform float gray = 0.0;
float sd_rbox(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
void fragment() {
	vec2 p = UV * size;
	float d = sd_rbox(p - size * 0.5, size * 0.5, radius);
	float a = 1.0 - smoothstep(-0.8, 0.8, d);
	// cover fit
	float sa = size.x / size.y, ta = tex_size.x / tex_size.y;
	vec2 scale = sa > ta ? vec2(1.0, ta / sa) : vec2(sa / ta, 1.0);
	scale /= zoom;
	vec2 ctr = clamp(focus, scale * 0.5, vec2(1.0) - scale * 0.5);
	vec2 uv = ctr + (UV - 0.5) * scale;
	uv = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 c = texture(TEXTURE, uv);
	vec3 col = c.rgb;
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(lum * 0.6), gray);
	col *= 1.0 - bottom_shade * smoothstep(0.55, 1.0, UV.y);
	float hb = UV.x * 0.7 + UV.y * 0.5 + TIME * 0.18;
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (hb + vec3(0.0, 0.33, 0.67)));
	float sheen = pow(0.5 + 0.5 * sin((UV.x - UV.y) * 9.0 + TIME * 2.2), 6.0);
	col += holo * (rainbow * 0.16 + sheen * 0.25);
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(col, a * c.a) * vcol;
}
