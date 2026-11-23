shader_type canvas_item;
// v07:album — photo mode color filters over the whole screen (below the frame and captions).
// mode: 1 warm evening, 2 night, 3 film (sepia-ish fade + grain). 0 = rect hidden.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform int mode = 1;
uniform float t = 0.0;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	float l = luma(c);
	if (mode == 1) {
		c = c * vec3(1.07, 1.0, 0.86) + vec3(0.035, 0.012, 0.0);
		c = mix(vec3(luma(c)), c, 1.12);
	} else if (mode == 2) {
		c = mix(c, vec3(l) * vec3(0.72, 0.84, 1.28), 0.5) * 0.9 + vec3(0.015, 0.0, 0.045);
	} else if (mode == 3) {
		c = mix(c, vec3(l) * vec3(1.12, 1.0, 0.8), 0.6);
		c = c * 0.88 + 0.07;
		float g = fract(sin(dot(SCREEN_UV * 911.0 + vec2(t * 3.1, t * 1.7), vec2(12.9898, 78.233))) * 43758.5453);
		c += (g - 0.5) * 0.06;
	}
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * 0.85;
	COLOR = vec4(c, 1.0);
}
