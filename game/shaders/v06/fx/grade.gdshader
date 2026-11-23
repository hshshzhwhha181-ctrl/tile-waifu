shader_type canvas_item;
// V6Fx: full-screen grade over everything: saturation, exposure, warm bloom-ish lift,
// and a tinted vignette that can pulse (danger / fever / fail). Only visible while an effect runs.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float saturation = 1.0;
uniform float exposure = 1.0;
uniform float lift = 0.0;                 // soft additive glow of bright areas
uniform vec4 vig_color : source_color = vec4(1.0, 0.2, 0.3, 1.0);
uniform float vig = 0.0;
uniform float pulse = 0.0;
uniform float pulse_speed = 6.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation) * exposure;
	vec2 px = SCREEN_PIXEL_SIZE * 9.0;
	vec3 blur = (texture(screen_tex, SCREEN_UV + vec2(px.x, px.y)).rgb + texture(screen_tex, SCREEN_UV + vec2(-px.x, px.y)).rgb
		+ texture(screen_tex, SCREEN_UV + vec2(px.x, -px.y)).rgb + texture(screen_tex, SCREEN_UV - px).rgb) * 0.25;
	c += max(blur - 0.55, 0.0) * lift * 2.0;
	vec2 p = UV - 0.5;
	float v = smoothstep(0.28, 0.85, length(p * vec2(1.0, 0.8)));
	float k = vig * (1.0 + pulse * (0.5 + 0.5 * sin(TIME * pulse_speed)));
	c = mix(c, vig_color.rgb, clamp(v * k, 0.0, 1.0));
	COLOR = vec4(c, 1.0);
}
