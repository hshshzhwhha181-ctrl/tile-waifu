shader_type canvas_item;
varying vec4 vcol;
void vertex() { vcol = COLOR; }
// Living heroine: zone-based deformation of a single cutout (breathing, head sway,
// twin-tail/hair sway, squash reaction, blinking eyelids, talking mouth) + warm rim light.
// All coordinates are in texture pixels.
uniform vec2 tex_size = vec2(848.0, 1264.0);
uniform vec2 head_c = vec2(440.0, 210.0);
uniform float head_r = 170.0;
uniform vec2 neck = vec2(445.0, 300.0);
uniform vec2 chest_c = vec2(440.0, 430.0);
uniform vec2 chest_r = vec2(150.0, 110.0);
uniform float waist_y = 700.0;
uniform vec2 feet = vec2(440.0, 1230.0);
uniform vec4 hair_l = vec4(0.0, 0.0, 0.0, 0.0);  // x_max, y_min, falloff, amp
uniform vec4 hair_r = vec4(0.0, 0.0, 0.0, 0.0);  // x_min, y_min, falloff, amp
uniform vec4 eye_l = vec4(400.0, 225.0, 17.0, 13.0);
uniform vec4 eye_r = vec4(468.0, 228.0, 17.0, 12.0);
uniform vec4 mouth = vec4(440.0, 270.0, 22.0, 14.0);
// optional closed-lid skin: two sample points (x1, y1, x2, y2) on the upper-lid skin, blended across the eye
// (inner → outer); x1 <= 0 keeps the legacy cheek sample below the eye. lid_tilt = eye axis slant (rad) per eye.
uniform vec4 lid_l = vec4(0.0);
uniform vec4 lid_r = vec4(0.0);
uniform vec2 lid_tilt = vec2(0.0);
uniform vec4 lash_color : source_color = vec4(0.36, 0.17, 0.2, 1.0);
uniform float blink = 0.0;
uniform float talk = 0.0;
uniform float bounce = 0.0;
uniform float tilt = 0.0;
uniform float sway = 1.0;
uniform float phase = 0.0;
uniform float breath_amp = 1.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.75, 1.0);
uniform float rim = 0.45;
uniform float flash = 0.0;
uniform float silhouette = 0.0;

vec2 rot(vec2 v, float a) { float c = cos(a), s = sin(a); return vec2(c * v.x - s * v.y, s * v.x + c * v.y); }

vec2 src_pos(vec2 p) {
	float t = TIME + phase;
	float br = 0.5 + 0.5 * sin(t * 1.9);
	vec2 s = p;
	// squash & stretch around the feet (reaction)
	vec2 rel = s - feet;
	s = feet + rel * vec2(1.0 + bounce * 0.035, 1.0 - bounce * 0.05);
	// breathing: upper body rises, chest expands slightly
	float wl = 1.0 - smoothstep(chest_c.y - 40.0, waist_y, p.y);
	s.y += 2.6 * br * wl * breath_amp;
	vec2 q = (p - chest_c) / chest_r;
	float wc = 1.0 - smoothstep(0.35, 1.0, length(q));
	s -= (p - chest_c) * 0.018 * br * wc * breath_amp;
	// head rotation around the neck pivot
	float ang = (0.022 * sin(t * 0.83) + 0.01 * sin(t * 1.7 + 1.0)) * sway + tilt;
	float wh = (1.0 - smoothstep(head_r * 0.92, head_r * 1.18, distance(p, head_c)));
	wh *= 1.0 - smoothstep(neck.y - 25.0, neck.y + 25.0, p.y);
	s = mix(s, neck + rot(s - neck, -ang), wh);
	// hair sway, amplitude grows toward the tips
	if (hair_l.w > 0.0) {
		float w = (1.0 - smoothstep(hair_l.x - hair_l.z, hair_l.x + hair_l.z, p.x)) * smoothstep(hair_l.y, hair_l.y + 80.0, p.y);
		float k = clamp((p.y - hair_l.y) / 520.0, 0.0, 1.0);
		s.x -= w * hair_l.w * pow(k, 1.4) * sin(t * 1.35 - p.y * 0.009) * sway;
		s.x -= w * hair_l.w * pow(k, 1.4) * ang * 30.0;
	}
	if (hair_r.w > 0.0) {
		float w = smoothstep(hair_r.x - hair_r.z, hair_r.x + hair_r.z, p.x) * smoothstep(hair_r.y, hair_r.y + 80.0, p.y);
		float k = clamp((p.y - hair_r.y) / 520.0, 0.0, 1.0);
		s.x -= w * hair_r.w * pow(k, 1.4) * sin(t * 1.27 - p.y * 0.009 + 1.1) * sway;
		s.x -= w * hair_r.w * pow(k, 1.4) * ang * 30.0;
	}
	// talking mouth: squash the mouth shape vertically from its top edge
	if (mouth.z > 0.0) {
		vec2 mq = (p - mouth.xy) / mouth.zw;
		float wm = 1.0 - smoothstep(0.55, 1.0, length(mq));
		float top = mouth.y - mouth.w;
		s.y += (p.y - top) * talk * 0.42 * wm;
	}
	return s;
}

vec3 skin_at(sampler2D tex, vec2 c) {
	return (texture(tex, (c + vec2(-1.5, 0.0)) / tex_size).rgb + texture(tex, (c + vec2(1.5, 0.0)) / tex_size).rgb
		+ texture(tex, (c + vec2(0.0, -1.5)) / tex_size).rgb + texture(tex, (c + vec2(0.0, 1.5)) / tex_size).rgb) * 0.25;
}

vec4 eyelid(sampler2D tex, vec2 p0, vec2 s, vec4 e, vec4 lid_s, float tl, vec4 col) {
	if (e.z <= 0.0 || blink <= 0.001) return col;
	// work in the eye's own frame (slanted eyes get a slanted lid)
	vec2 p = e.xy + rot(p0 - e.xy, -tl);
	vec2 q = (p - e.xy) / (e.zw * vec2(1.25, 1.45));
	float er = length(q);
	if (er > 1.0) return col;
	float u = clamp((p.x - e.x) / (e.z * 1.25), -1.0, 1.0);
	float lid = e.y - e.w * 1.4 + (e.w * 2.0) * blink + 0.35 * e.w * (1.0 - u * u) * blink;
	vec3 skin;
	if (lid_s.x > 0.0) {
		skin = mix(skin_at(tex, lid_s.xy), skin_at(tex, lid_s.zw), clamp(u * 0.5 + 0.5, 0.0, 1.0));
	} else {
		float cy = e.y + e.w * 2.5;
		skin = (texture(tex, vec2(e.x - e.z * 0.5, cy) / tex_size).rgb + texture(tex, vec2(e.x, cy) / tex_size).rgb
			+ texture(tex, vec2(e.x + e.z * 0.5, cy) / tex_size).rgb + texture(tex, vec2(e.x, cy + e.w * 0.6) / tex_size).rgb) * 0.25;
		skin = mix(skin, texture(tex, vec2(s.x, cy) / tex_size).rgb, 0.25);
	}
	float feather = 1.0 - smoothstep(0.82, 1.0, er);
	float above = (1.0 - smoothstep(lid - 1.0, lid + 1.0, p.y)) * feather;
	col.rgb = mix(col.rgb, skin, above);
	float lw = 1.7 + 1.3 * smoothstep(0.2, 1.0, abs(u));
	float lash = exp(-pow((p.y - lid) / lw, 2.0)) * smoothstep(0.35, 0.8, blink) * (1.0 - smoothstep(0.9, 1.0, abs(u) * 0.95));
	col.rgb = mix(col.rgb, lash_color.rgb, lash * feather);
	return col;
}

void fragment() {
	vec2 p = UV * tex_size;
	vec2 s = src_pos(p);
	vec2 suv = s / tex_size;
	vec4 col = texture(TEXTURE, suv);
	if (suv.x < 0.0 || suv.y < 0.0 || suv.x > 1.0 || suv.y > 1.0) col.a = 0.0;
	col = eyelid(TEXTURE, s, s, eye_l, lid_l, lid_tilt.x, col);
	col = eyelid(TEXTURE, s, s, eye_r, lid_r, lid_tilt.y, col);
	// warm rim light from upper left: where alpha drops nearby
	float o = 7.0 / tex_size.x;
	float al = texture(TEXTURE, suv + vec2(-o, 0.0)).a;
	float at = texture(TEXTURE, suv + vec2(0.0, -o * 0.8)).a;
	float edge = clamp(1.0 - min(al, at), 0.0, 1.0) * col.a;
	col.rgb += rim_color.rgb * edge * rim;
	col.rgb = mix(col.rgb, vec3(1.0), flash);
	col.rgb = mix(col.rgb, vec3(0.08, 0.05, 0.12), silhouette);
	COLOR = col * vcol;
}
