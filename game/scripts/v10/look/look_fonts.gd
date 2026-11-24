class_name V10LookFonts
extends RefCounted

# V10LookFonts — the SSR partner's display font on her UI moments (docs/0.10-spec.md D2), on top of V10Fonts.
#
# Moments (and only these) take the partner's font: screen title, window title, Приём (ult) name, «Победа!»,
# signature under her letters. Text under 24 px and EVERY price stay Nunito (price_font()).
#
#   V10LookFonts.fit(moment, text, max_w, look = null) -> {font, size, id}
#   V10LookFonts.title(label, text, max_w, moment = "screen_title")   apply + follow V10Look.look_changed with a
#                                                                     0,25 с cross-fade (V10Fonts.XFADE)
#   V10LookFonts.price_font() -> Font                                 always Nunito 900
#   V10LookFonts.banner_font(hero) -> Font                            banner of an SSR outfit: SKIN_FONTS[hero].title

const MOMENTS: = {
	"screen_title": {"size": 44, "role": "title"},
	"window_title": {"size": 44, "role": "title"},
	"ult_name": {"size": 56, "role": "title"},
	"victory": {"size": 64, "role": "title"},
	"letter_sign": {"size": 34, "role": "text"},
}
const META: = "v10_title"


static func skin_of(look) -> String:
	if look == null:
		look = V10Look.current()
	return String((look as Dictionary).get("font", ""))


static func fit(moment: String, text: String, max_w: float, look = null) -> Dictionary:
	var m: Dictionary = MOMENTS.get(moment, MOMENTS.screen_title)
	var skin: = skin_of(look)
	if m.role == "text":
		# her signature: the SSR text face, or the founders' Caveat
		var id: = V10Fonts.skin_id(skin, "text", int(m.size)) if skin != "" else "hand"
		if id == "ui_body":
			id = "hand"
		return {"font": V10Fonts.font(id), "size": V10Fonts.px(id, int(m.size)), "id": id}
	return V10Fonts.fit_title(text, skin, int(m.size), max_w)


static func price_font() -> Font:
	return V10Fonts.font("ui_body", 900)


static func banner_font(hero: String, size: = 44) -> Font:
	return V10Fonts.skin(hero, "title", size)


static func apply(l: Label, text: String, max_w: float, moment: = "screen_title", look = null) -> void:
	var f: = fit(moment, text, max_w, look)
	l.text = text
	if l.label_settings:
		l.label_settings.font = f.font
		l.label_settings.font_size = int(f.size)
	else:
		l.add_theme_font_override("font", f.font)
		l.add_theme_font_size_override("font_size", int(f.size))
	l.set_meta("v10_font_id", f.id)


static func title(l: Label, text: String, max_w: float, moment: = "screen_title") -> void:
	apply(l, text, max_w, moment)
	l.set_meta(META, true)
	l.set_meta("v10_moment", moment)
	l.set_meta("v10_max_w", max_w)
	var hub: = V10Look.hub()
	var cb: = func(look: Dictionary): _on_look(l, look)
	hub.look_changed.connect(cb)
	l.tree_exiting.connect(func(): if hub.look_changed.is_connected(cb): hub.look_changed.disconnect(cb), CONNECT_ONE_SHOT)


static func _on_look(l: Label, look: Dictionary) -> void:
	if not is_instance_valid(l):
		return
	var moment: = String(l.get_meta("v10_moment", "screen_title"))
	var max_w: = float(l.get_meta("v10_max_w", l.size.x))
	var f: = fit(moment, l.text, max_w, look)
	if String(l.get_meta("v10_font_id", "")) == String(f.id):
		return
	var lvl: = V10HudSkin.fx_level()
	if lvl == "min" or not l.is_inside_tree():
		apply(l, l.text, max_w, moment, look)
		return
	# cross-fade: the old face fades out in a ghost copy while the new one fades in
	var ghost: Label = l.duplicate()
	if l.label_settings:
		ghost.label_settings = l.label_settings.duplicate()
	ghost.set_meta(META, false)
	l.get_parent().add_child(ghost)
	ghost.position = l.position
	apply(l, l.text, max_w, moment, look)
	l.modulate.a = 0.0
	var tw: = l.create_tween().set_parallel()
	tw.tween_property(l, "modulate:a", 1.0, V10Fonts.XFADE)
	tw.tween_property(ghost, "modulate:a", 0.0, V10Fonts.XFADE)
	tw.chain().tween_callback(ghost.queue_free)
