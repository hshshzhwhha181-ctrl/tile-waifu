class_name V10MjStageSettings
extends RefCounted

# V10MjStageSettings — the three player choices of docs/MODES.md §3.5, as data + ready-made rows for the
# integrator (Настройки → Звук и Картинка, and the pause sheet). Saved in G.S["v10_mj_stage"] (DEFAULTS + st(),
# like V6ModesData.st(); SAVE_VER is the integrator's, the dictionary is created on first read).
#
#   V10MjStageSettings.st() -> Dictionary          {mode, inserts, voice}
#   V10MjStageSettings.set_value(key, value)       writes + emits nothing (the presence reads st() on attach and
#                                                  the pause sheet calls presence.apply_settings())
#   V10MjStageSettings.build_rows(parent, width) -> Array[Control]   three rows: label + segmented choice /
#                                                  switch, hit zones ≥ 80 px (UX §6.1), names from UX §4 (plain)
#   V10MjStageSettings.ROWS                         the data, if the host draws rows itself

const KEY: = "v10_mj_stage"
const DEFAULTS: = {"mode": "live", "inserts": "always", "voice": true}

const ROWS: = [
	{"key": "mode", "title": "Героиня в партии", "kind": "choice",
		"options": [["live", "Живая"], ["quiet", "Тихая"], ["finish_only", "Только финиш"]],
		"hint": {"live": "Реагирует на ходы, говорит, выглядывает между волнами",
			"quiet": "Только окно и кольцо Приёма, без голоса",
			"finish_only": "Появляется только в конце партии"}},
	{"key": "inserts", "title": "Вставки за столом", "kind": "choice",
		"options": [["always", "Всегда"], ["mine", "Только мои"], ["first_day", "Первая за день"], ["off", "Выкл"]],
		"hint": {"always": "Лента и портрет на каждое объявление",
			"mine": "Только на твои объявления",
			"first_day": "Каждый вид вставки — раз в день",
			"off": "Без вставок, только голос"}},
	{"key": "voice", "title": "Голос героини", "kind": "switch"},
]


static func _g():
	var tree: = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("G") if tree else null


static func st() -> Dictionary:
	var g = _g()
	if g == null or not (g.get("S") is Dictionary):
		return DEFAULTS.duplicate()
	var d: Dictionary = (g.S as Dictionary).get(KEY, {})
	for k in DEFAULTS:
		if not d.has(k):
			d[k] = DEFAULTS[k]
	g.S[KEY] = d
	return d


static func set_value(key: String, value) -> void:
	var d: = st()
	d[key] = value
	var g = _g()
	if g and g.get("S") is Dictionary:
		g.S[KEY] = d


# Ready rows: Nunito labels from the project theme, a segmented control of the plain options. Colours are the
# UX §6.2 tokens; the active segment is gold.300 text on night.600 (not rose: rose is only the main game action).
static func build_rows(parent: Control, width: = 672.0) -> Array:
	var out: = []
	var y: = 0.0
	for row in ROWS:
		var box: = Control.new()
		box.name = "StageRow_" + String(row.key)
		box.position = Vector2(0, y)
		box.size = Vector2(width, 136 if row.kind == "choice" else 88)
		parent.add_child(box)
		var title: = Label.new()
		title.text = row.title
		title.position = Vector2(0, 4)
		title.size = Vector2(width, 36)
		title.add_theme_font_size_override("font_size", 22)
		title.add_theme_color_override("font_color", V10MjStageData.TOK.paper100)
		box.add_child(title)
		if row.kind == "switch":
			var cb: = CheckButton.new()
			cb.button_pressed = bool(st().get(row.key, true))
			cb.position = Vector2(width - 120, 0)
			cb.size = Vector2(120, 80)
			cb.toggled.connect(func(on): set_value(String(row.key), on))
			box.add_child(cb)
		else:
			var opts: Array = row.options
			var seg_w: = width / opts.size()
			var cur: = String(st().get(row.key, ""))
			var buttons: = []
			for i in opts.size():
				var b: = Button.new()
				b.text = opts[i][1]
				b.toggle_mode = true
				b.button_pressed = String(opts[i][0]) == cur
				b.position = Vector2(seg_w * i, 44)
				b.size = Vector2(seg_w - 4.0, 80)
				b.add_theme_font_size_override("font_size", 20)
				b.add_theme_color_override("font_color", V10MjStageData.TOK.paper300)
				b.add_theme_color_override("font_pressed_color", V10MjStageData.TOK.gold300)
				box.add_child(b)
				buttons.append(b)
			for i in buttons.size():
				var val: String = opts[i][0]
				buttons[i].pressed.connect(func():
					set_value(String(row.key), val)
					for j in buttons.size():
						buttons[j].set_pressed_no_signal(j == i)
					V9Feel.press(buttons[i]))
		out.append(box)
		y += box.size.y + 16.0
	return out


static func texts() -> Array:
	var out: = []
	for row in ROWS:
		out.append(row.title)
		for o in row.get("options", []):
			out.append(o[1])
		for k in row.get("hint", {}):
			out.append(row.hint[k])
	return out
