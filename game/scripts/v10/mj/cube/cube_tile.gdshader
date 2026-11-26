// Куб: фишка-кубик в MultiMesh (docs/MODES.md §4.4). Mobile / gl_compatibility: без теней, одна направленная лампа,
// fake-AO запечён в атлас (края лица) и в UV фаски, никакой прозрачности.
// INSTANCE_CUSTOM: r = символ / 64 (0…35), g = свободна (0/1), b = 0 · подсказка 0.5 · выбрана 1, a = вспышка снятия.
// UV: на лице 0…1; на фаске (−1, −AO) — лицо и фаска различаются по знаку UV.x.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 body_col : source_color = vec3(0.24, 0.61, 0.49);
uniform vec3 accent : source_color = vec3(0.31, 0.89, 1.0);
uniform float cells = 6.0;
uniform float pad = 0.035;
uniform float blocked_dim = 0.70;
uniform float show_free = 1.0;
uniform float pulse_on = 1.0;
uniform float face_light = 1.0;

varying flat vec4 cust;

void vertex() {
	cust = INSTANCE_CUSTOM;
}

void fragment() {
	float plate = step(-0.5, UV.x);
	float vao = mix(-UV.y, 1.0, plate);
	vec2 uv = clamp(UV, vec2(0.0), vec2(1.0));
	float fi = floor(cust.r * 64.0 + 0.5);
	vec2 cell = vec2(mod(fi, cells), floor(fi / cells));
	vec2 auv = (cell + vec2(pad) + uv * (1.0 - 2.0 * pad)) / cells;
	vec3 face = texture(atlas, auv).rgb * face_light;
	vec3 col = mix(body_col, face, plate);
	col *= mix(0.72, 1.0, vao);
	float fr = step(0.5, cust.g);
	col *= mix(blocked_dim, 1.0, max(fr, 1.0 - show_free));
	float sel = step(0.75, cust.b);
	float hint = step(0.25, cust.b) * (1.0 - sel);
	float pulse = mix(0.65, 0.5 + 0.5 * sin(TIME * 5.5), pulse_on);
	vec3 em = accent * (sel * 0.30 + hint * 0.34 * pulse);
	em += accent * (1.0 - plate) * (sel * 0.85 + hint * 0.6 * pulse);
	em += accent * cust.a * 1.4;
	ALBEDO = col;
	EMISSION = em;
	ROUGHNESS = mix(0.5, 0.42, plate);
	SPECULAR = mix(0.45, 0.28, plate);
}
