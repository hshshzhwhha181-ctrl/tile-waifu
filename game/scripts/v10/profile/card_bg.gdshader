shader_type canvas_item;
// COLOR in fragment() is already texture × modulate in Godot 4: keep the vertex colour from vertex() instead
varying vec4 vcol;
void vertex() { vcol = COLOR; }
// V10 profile card backdrop: rounded mask, cover-fit crop around `focus`, soft blur (13 taps), brightness / tint,
// a reading shade towards the bottom, vignette and a slow drift (drift 0 = static).
uniform vec2 size = vec2(660.0, 880.0);
uniform float radius = 30.0;
uniform vec2 tex_size = vec2(1080.0, 1920.0);
uniform vec2 focus = vec2(0.5, 0.4);
uniform float zoom = 1.0;
uniform float blur = 2.0;
uniform float bright = 0.62;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 shade_color : source_color = vec4(0.05, 0.035, 0.05, 1.0);
uniform float shade = 0.75;
uniform float shade_from = 0.42;
uniform float vignette = 0.45;
uniform float drift = 0.0;
uniform float gray = 0.0;

float sd_rbox(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }

void fragment() {
	vec4 m = vcol;
	vec2 p = UV * size;
	float d = sd_rbox(p - size * 0.5, size * 0.5, radius);
	float a = 1.0 - smoothstep(-0.8, 0.8, d);
	float sa = size.x / size.y, ta = tex_size.x / tex_size.y;
	vec2 sc = sa > ta ? vec2(1.0, ta / sa) : vec2(sa / ta, 1.0);
	sc /= zoom;
	vec2 ctr = clamp(focus + vec2(sin(TIME * 0.11), cos(TIME * 0.087)) * 0.012 * drift, sc * 0.5, vec2(1.0) - sc * 0.5);
	vec2 uv = ctr + (UV - 0.5) * sc;
	vec2 px = blur / tex_size;
	vec3 col = texture(TEXTURE, uv).rgb * 0.2;
	col += texture(TEXTURE, uv + vec2(px.x, 0.0)).rgb * 0.1;
	col += texture(TEXTURE, uv - vec2(px.x, 0.0)).rgb * 0.1;
	col += texture(TEXTURE, uv + vec2(0.0, px.y)).rgb * 0.1;
	col += texture(TEXTURE, uv - vec2(0.0, px.y)).rgb * 0.1;
	col += texture(TEXTURE, uv + px * 2.0).rgb * 0.05;
	col += texture(TEXTURE, uv - px * 2.0).rgb * 0.05;
	col += texture(TEXTURE, uv + vec2(px.x, -px.y) * 2.0).rgb * 0.05;
	col += texture(TEXTURE, uv + vec2(-px.x, px.y) * 2.0).rgb * 0.05;
	col += texture(TEXTURE, uv + vec2(px.x * 3.0, 0.0)).rgb * 0.05;
	col += texture(TEXTURE, uv - vec2(px.x * 3.0, 0.0)).rgb * 0.05;
	col += texture(TEXTURE, uv + vec2(0.0, px.y * 3.0)).rgb * 0.05;
	col += texture(TEXTURE, uv - vec2(0.0, px.y * 3.0)).rgb * 0.05;
	col *= bright * tint.rgb;
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(g), gray);
	col = mix(col, shade_color.rgb, shade * smoothstep(shade_from, 1.0, UV.y));
	vec2 vq = UV - 0.5;
	col *= 1.0 - vignette * smoothstep(0.25, 0.75, length(vq * vec2(1.0, 0.9)));
	COLOR = vec4(col, a) * m;
}
