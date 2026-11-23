shader_type canvas_item;
// V6Fx: screen-space shockwaves (up to 3 at once). Each ring travels outward from its center,
// bending the picture under it and splitting RGB slightly at the crest.
// waves[i] = (center.x px, center.y px, radius px, strength px); strength 0 = off.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 size = vec2(720.0, 1280.0);
uniform vec4 waves[3];
uniform float width = 64.0;
uniform float chroma = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.92, 0.7, 1.0);
uniform float glow = 0.22;
void fragment() {
	vec2 px = UV * size;
	vec2 off = vec2(0.0);
	vec2 ca = vec2(0.0);
	float shine = 0.0;
	float far = max(size.x, size.y) * 0.9;
	for (int i = 0; i < 3; i++) {
		vec4 w = waves[i];
		if (w.w <= 0.0) continue;
		vec2 d = px - w.xy;
		float dist = length(d);
		float x = (dist - w.z) / width;
		float ring = exp(-x * x * 3.0);
		float fade = 1.0 - smoothstep(0.0, 1.0, w.z / far);
		vec2 dir = dist > 0.001 ? d / dist : vec2(0.0);
		off += dir * w.w * ring * (-x) * 1.6 * fade;
		ca += dir * chroma * ring * fade * 3.0 * min(w.w / 16.0, 1.5);
		shine += ring * fade * min(w.w / 16.0, 1.0);
	}
	vec2 suv = SCREEN_UV - off / size;
	vec2 cuv = ca / size;
	vec3 col;
	col.r = texture(screen_tex, suv + cuv).r;
	col.g = texture(screen_tex, suv).g;
	col.b = texture(screen_tex, suv - cuv).b;
	col += tint.rgb * shine * glow;
	COLOR = vec4(col, 1.0);
}
