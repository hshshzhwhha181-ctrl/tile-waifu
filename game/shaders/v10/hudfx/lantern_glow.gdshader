shader_type canvas_item;
render_mode blend_add;

// V10LanternFx inner light (scripts/v10/hudfx/lantern_fx.gd): a warm glow inside the painted lantern's own
// silhouette, drawn over the lantern with the same texture and rect. One texture sample (in a Godot 4 canvas
// fragment COLOR already holds texel × modulate).
// Head-room add: the light never pushes a channel past what the lantern pixel under it (texel × its tint `under`)
// has left, so the painted bright core never clips to white and the hue stays warm (no white flashes, HUD_V2 §6).
// While the lantern is still dark the head-room is large, so the light «catches» first and settles as the paint
// brightens.

uniform vec4 core : source_color;            // gold, value ≤ 0.8 (V10HudFx.warm_light)
uniform vec4 rim : source_color;             // ember-warm edge of the light pool
uniform vec4 under : source_color = vec4(1.0);  // the lantern's own tint (its self_modulate)
uniform float amount : hint_range(0.0, 0.55) = 0.0;   // light alpha (≤ 0.55)
uniform float spread : hint_range(0.3, 1.2) = 1.0;    // the pool grows 0.55 → 1.0 while the lantern catches
uniform vec2 center = vec2(0.5, 0.45);       // the candle: a little under the paper body centre (UV)
uniform vec2 radius = vec2(0.42, 0.25);      // light pool half-size in UV (inside the paper body)

void fragment() {
	vec4 base = COLOR;
	vec2 d = (UV - center) / (radius * spread);
	float f = clamp(1.0 - dot(d, d), 0.0, 1.0);
	f = f * f * (3.0 - 2.0 * f);
	vec3 px = base.rgb * under.rgb;
	float room = 1.0 - max(px.r, max(px.g, px.b));
	vec3 light = mix(rim.rgb, core.rgb, f);
	float peak = max(light.r, max(light.g, light.b));
	float s = min(amount * f, 0.85 * room / max(peak, 0.01));
	COLOR = vec4(light * s, base.a);
}
