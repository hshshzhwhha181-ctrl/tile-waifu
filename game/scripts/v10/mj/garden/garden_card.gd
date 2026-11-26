class_name V10MjGardenCard
extends Control

# Карточка Сада 2.0 на полке «Столы» (docs/MODES.md §4.9, §6.2):
#   тумблер «Ночной стол», выбор фона (Дождь / Ручей / Бамбук), «?», главная кнопка «Играть».

signal play_requested(opts: Dictionary)

const T: = V10MjGardenLook.TOK

var save_d: = {}
var night_btn: Button
var amb_btns: = {}
var play_btn: Button
var help_btn: Button


func setup(S = null) -> V10MjGardenCard:
	save_d = V10MjGardenSave.st(S)
	custom_minimum_size = Vector2(672, 260)
	size = Vector2(672, 260)
	_build()
	return self


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg: = Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.size = size
	var sb: = StyleBoxFlat.new()
	sb.bg_color = T.night800
	sb.set_corner_radius_all(V10DS.RADIUS)
	sb.border_color = V10DS.hair()
	sb.border_width_top = 1
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)

	var h1: = V10MjGardenLook.label(V10MjGardenInfo.INFO.name, 32, T.paper100, "title", 700)
	h1.position = Vector2(24, 18)
	add_child(h1)
	var sub: = V10MjGardenLook.label(V10MjGardenInfo.INFO.line, 18, T.paper500, "body", 600)
	sub.position = Vector2(24, 60)
	add_child(sub)

	help_btn = Button.new()
	help_btn.name = "HelpBtn"
	help_btn.flat = true
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.size = Vector2(80, 80)
	help_btn.custom_minimum_size = Vector2(80, 80)
	help_btn.position = Vector2(size.x - 92, 10)
	help_btn.set_meta("ux_role", "tertiary")
	var hic: = V10MjGardenIcon.new("help", T.paper300)
	hic.position = Vector2(16, 16)
	help_btn.add_child(hic)
	help_btn.button_down.connect(func(): V9Feel.press(help_btn, "pop", "button"))
	add_child(help_btn)

	night_btn = Button.new()
	night_btn.name = "NightBtn"
	night_btn.flat = true
	night_btn.focus_mode = Control.FOCUS_NONE
	night_btn.size = Vector2(236, 80)
	night_btn.custom_minimum_size = Vector2(236, 80)
	night_btn.position = Vector2(24, 92)
	night_btn.set_meta("ux_role", "secondary")
	var nic: = V10MjGardenIcon.new("moon", T.gold300)
	nic.name = "Icon"
	nic.position = Vector2(8, 16)
	night_btn.add_child(nic)
	var nlbl: = V10MjGardenLook.label("Ночной стол", 20, T.paper100, "body", 700)
	nlbl.name = "Lbl"
	nlbl.position = Vector2(64, 26)
	night_btn.add_child(nlbl)
	night_btn.button_down.connect(func(): V9Feel.press(night_btn, "pop", "button"))
	night_btn.pressed.connect(func():
		save_d.night = not bool(save_d.night)
		_sync())
	add_child(night_btn)

	for i in V10MjGardenSave.AMBIENTS.size():
		var ak: String = V10MjGardenSave.AMBIENTS[i]
		var b: = Button.new()
		b.name = "Amb_" + ak
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.size = Vector2(120, 80)
		b.custom_minimum_size = Vector2(120, 80)
		b.position = Vector2(280 + i * 124, 92)
		b.set_meta("ux_role", "tertiary")
		b.text = V10MjGardenSave.AMB_NAMES[ak]
		b.add_theme_font_override("font", V10MjGardenLook.font("body", 700))
		b.add_theme_font_size_override("font_size", 18)
		b.button_down.connect(func(): V9Feel.press(b, "pop", "button"))
		b.pressed.connect(func():
			save_d.ambient = ak
			_sync())
		add_child(b)
		amb_btns[ak] = b

	play_btn = Button.new()
	play_btn.name = "PlayBtn"
	play_btn.text = "Продолжить" if V10MjGardenSave.has_run(save_d) else "Играть"
	play_btn.focus_mode = Control.FOCUS_NONE
	play_btn.size = Vector2(460, 104)
	play_btn.custom_minimum_size = Vector2(460, 104)
	play_btn.position = Vector2((size.x - 460) * 0.5, 150)
	play_btn.set_meta("ux_role", "primary")
	for st_k in ["normal", "hover", "pressed", "focus"]:
		var psb: = StyleBoxFlat.new()
		psb.bg_color = T.rose700 if st_k == "pressed" else T.rose500
		psb.set_corner_radius_all(52)
		play_btn.add_theme_stylebox_override(st_k, psb)
	play_btn.add_theme_font_override("font", V10MjGardenLook.font("title", 600))
	play_btn.add_theme_font_size_override("font_size", 32)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		play_btn.add_theme_color_override(cn, T.night900)
	play_btn.button_down.connect(func(): V9Feel.press(play_btn, "pop", "button"))
	play_btn.pressed.connect(func(): play_requested.emit({"night": bool(save_d.night), "ambient": String(save_d.ambient)}))
	add_child(play_btn)
	_sync()


func _sync() -> void:
	var on: = bool(save_d.night)
	(night_btn.get_node("Icon") as V10MjGardenIcon).set_col(T.gold300 if on else T.paper500)
	(night_btn.get_node("Lbl") as Label).label_settings.font_color = T.gold300 if on else T.paper300
	for ak in amb_btns:
		var b: Button = amb_btns[ak]
		var sel: bool = (String(ak) == "rain") if on else (String(save_d.ambient) == String(ak))
		b.disabled = on and String(ak) != "rain"
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			b.add_theme_color_override(cn, T.gold300 if sel else T.paper500)
