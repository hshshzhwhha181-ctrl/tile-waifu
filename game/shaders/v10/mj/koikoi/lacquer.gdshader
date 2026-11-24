shader_type canvas_item;

// «Лак и золото»: глубокий чёрный лак с тёплым отливом, редкая золотая пыль (насидзи), мягкая виньетка.
// Статичный (без анимации), поэтому дёшев на Mali: считается один раз на пиксель за кадр, без текстур.

uniform vec4 top_col : source_color = vec4(0.105, 0.085, 0.100, 1.0);
uniform vec4 bot_col : source_color = vec4(0.055, 0.045, 0.055, 1.0);
uniform vec4 tint : source_color = vec4(0.30, 0.16, 0.20, 1.0);
uniform float tint_amt = 0.10;
uniform vec4 dust_col : source_color = vec4(0.91, 0.77, 0.49, 1.0);
uniform float dust = 0.55;
uniform float vignette = 0.55;
uniform vec2 px_size = vec2(720.0, 1280.0);

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 c = mix(top_col.rgb, bot_col.rgb, smoothstep(0.0, 1.0, uv.y));
	// мягкое пятно отлива сверху справа (свет лампы на лаке)
	float sheen = exp(-pow(length((uv - vec2(0.78, 0.12)) * vec2(1.0, 1.6)), 2.0) * 3.0);
	c += tint.rgb * tint_amt * sheen;
	// золотая пыль: крупные редкие и мелкие частые крупинки, гуще полосами (как насидзи)
	vec2 p = uv * px_size;
	vec2 cell = floor(p / 3.0);
	float r = h21(cell);
	float band = 0.5 + 0.5 * sin(uv.y * 9.0 + uv.x * 3.0 + h21(floor(p / 160.0)) * 6.28);
	float speck = step(0.9975 - 0.0035 * band, r) * (0.55 + 0.45 * h21(cell + 7.1));
	c += dust_col.rgb * speck * dust * 0.55;
	// виньетка
	vec2 d = (uv - 0.5) * vec2(1.0, 0.8);
	c *= 1.0 - vignette * smoothstep(0.25, 0.85, length(d));
	COLOR = vec4(c, 1.0);
}
