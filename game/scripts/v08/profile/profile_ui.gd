class_name V8ProfileUI
extends RefCounted

# Shared pieces of the 0.8 profile: strings, nick field, avatar row, recovery-code panels,
# optional hooks into Stream B classes (V8Population, V8League) looked up by name so this
# module compiles and works before they exist.

const T: = {
	"card.title": "Карточка игрока",
	"card.ask": "Как тебя называть?",
	"card.why": "Ник видят в лиге и в рейтинге квартала.",
	"card.hint": "От 3 до 16 символов",
	"card.ph": "Твой ник",
	"card.avatar": "Аватар",
	"card.play": "Играть офлайн",
	"card.play_sub": "прогресс хранится на телефоне",
	"card.note": "Сменить телефон поможет код восстановления: он всегда есть в профиле.",
	"card.have_code": "У меня есть код",
	"card.imported": "Прогресс перенесён. Осталось выбрать ник.",
	"card.imported_ok": "Прогресс перенесён!",
	"dice": "Случайный ник",
	"code.title": "Код восстановления",
	"code.enter_d": "Вставь код со старого телефона. Прогресс на этом телефоне заменится прогрессом из кода.",
	"code.ph": "TW8-…",
	"code.paste": "Вставить",
	"code.go": "Перенести прогресс",
	"code.back": "Назад",
	"code.empty": "Сначала вставь код",
	"code.show_d": "Нажми «Скопировать» и сохрани код в заметках или отправь себе в мессенджер. На новом телефоне: «Профиль» → «Ввести код» → «Вставить». Не показывай код другим: по нему можно забрать твой прогресс.",
	"code.len": "%d %s · переносится копированием, вручную не набирается",
	"code.copy": "Скопировать",
	"code.copied": "Код скопирован",
	"code.confirm_t": "Перенести прогресс?",
	"code.confirm": "Прогресс на этом телефоне заменится прогрессом из кода. Текущий прогресс сохранится в резервную копию.",
	"code.confirm_yes": "Перенести",
	"code.done": "Прогресс перенесён",
	"profile.title": "Профиль",
	"profile.nick_edit": "Сменить ник",
	"profile.avatar_edit": "Сменить аватар",
	"profile.avatar_t": "Аватар",
	"profile.nick_t": "Ник",
	"profile.save": "Сохранить",
	"profile.saved": "Профиль сохранён",
	"profile.since": "ID %s · в чайной с %s",
	"profile.rank_total": "Очки ранга: %d",
	"profile.rank_next": "%d / %d до ранга %s",
	"profile.rank_top": "Высшая ступень",
	"profile.rank_note": "Очки ранга дают все режимы. Ниже начала ступени ранг не опускается.",
	"profile.ranked_outfits": "В рейтинге наряды не дают силы: ульты без модификаторов, заряд с нуля.",
	"profile.league": "Лига и квартал",
	"profile.week": "Лига недели",
	"profile.quarter": "Квартал",
	"profile.place": "#%s из %s",
	"profile.pts": "%s очк.",
	"profile.league_none": "Сыграй стол турнира",
	"profile.league_open": "Открыть турнир",
	"profile.stats": "Статистика",
	"profile.stats_sum": "Пройдено столов Пути: %d · звёзд: %d · яку: %d из %d",
	"profile.col_mode": "Режим",
	"profile.col_games": "Партий",
	"profile.col_wins": "Побед",
	"profile.col_rp": "Очки",
	"profile.stats_new": "Статистика по режимам ведётся с версии 0.8.",
	"profile.ladder": "Лестница рангов",
	"profile.code": "Код восстановления",
	"profile.code_d": "Перенеси прогресс на другой телефон без аккаунта и интернета.",
	"profile.code_show": "Показать код",
	"profile.code_enter": "Ввести код",
	"profile.settings": "Настройки",
}

const MODES: = [
	["path", "Путь"], ["daily", "Раскладка дня"], ["duel", "Дуэль"], ["blitz", "Блиц"], ["zen", "Сад"],
	["etude", "Этюды"], ["event", "Ивент"], ["tourney", "Турнир недели"], ["table", "Стол риичи"], ["other", "Прочее"],
]
const ALWAYS_SHOWN: = ["path", "daily", "duel", "blitz", "zen", "etude", "event", "tourney"]


static func s(key: String) -> String:
	return str(T.get(key, key))


# ---- optional Stream B classes -------------------------------------------------------------

static func cls(name: String) -> Script:
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == name:
			var p: = str(c.get("path", ""))
			if p != "" and ResourceLoader.exists(p):
				return load(p) as Script
	return null


static func random_nick() -> String:
	# shared with the population generator (Stream B): same style, never a population nick
	return V8Population.random_nick()


# {week: {league_tier, place, points, group_size, ...}, quarter: {place, total, points, ...}}
static func league_info() -> Dictionary:
	return {"week": V8League.my_week(), "quarter": V8League.my_quarter()}


# ---- 0.8 art backdrop ------------------------------------------------------------------------

# Full-screen backdrop from the 0.8 art set (V8Art.bg: "profile", "tourney"), drawn like Common.backdrop
# (blur / brightness / tint / slow drift) — Common.backdrop only knows res://assets/bg.
static func backdrop(parent: Control, bg: String, size: Vector2, blur: = 0.0, bright: = 1.0, tint: = Color.WHITE, focus: = Vector2(0.5, 0.5)) -> TextureRect:
	var tex: = V8Art.bg(bg)
	var r: = UI.tex(tex, Rect2(Vector2.ZERO, size), false)
	r.name = "Backdrop"
	if tex != null:
		var m: = ShaderMaterial.new()
		m.shader = preload("res://shaders/blurbg.gdshader")
		m.set_shader_parameter("size", size)
		m.set_shader_parameter("tex_size", Vector2(tex.get_width(), tex.get_height()))
		m.set_shader_parameter("blur", blur)
		m.set_shader_parameter("bright", bright)
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("focus", focus)
		m.set_shader_parameter("zoom", 1.04)
		m.set_shader_parameter("drift", Vector2(1, 1))
		r.material = m
	parent.add_child(r)
	return r


# The player's own avatar (profile hero id) in the gold frame; the ornate frame from Дракон up.
static func my_avatar(parent: Control, r: Rect2, hero: = "") -> Control:
	if hero == "":
		hero = str(G.profile().get("avatar", "mc"))
	if not G.HEROES.has(hero):
		hero = "mc"
	return V8Art.avatar(parent, hero, r, V8Art.top_tier(V8League.my_tier()))


# ---- title screen ----------------------------------------------------------------------------

# Centered pill under the logo: avatar + nick + rank. rect = area to center in.
static func title_chip(rect: Rect2) -> Control:
	var c: = Control.new()
	c.position = rect.position
	c.size = rect.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nick: = G.nick()
	var rk: = G.rank_of(int(G.S.get("rp", 0)))
	var h: = rect.size.y
	var f: = UI.font("body", 900)
	var nw: = minf(f.get_string_size(nick, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x, 300.0)
	var rw: = f.get_string_size(rk.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var w: = h + 14 + maxf(nw, rw) + 30
	var x0: = (rect.size.x - w) * 0.5
	var pill: = UI.rbox("plum", Rect2(x0, 0, w, h), h * 0.5, 3, 8)
	pill.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(pill)
	my_avatar(c, Rect2(x0 - 6, -8, h + 12, h + 12))
	var nl: = UI.label(nick, 26, Color.WHITE, UI.DARK, 3, "body", 900)
	nl.position = Vector2(x0 + h + 8, 0)
	nl.size = Vector2(maxf(nw, rw) + 10, 36)
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(nl)
	var rl: = UI.label(rk.title, 18, G.RANKS[rk.tier].color, UI.DARK, 2, "body", 900)
	rl.position = Vector2(x0 + h + 9, 33)
	c.add_child(rl)
	return c


# ---- inputs ----------------------------------------------------------------------------------

static func _box_style(focus: bool) -> StyleBoxFlat:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.055, 0.065, 0.92)
	sb.border_color = Color("e8c47e") if focus else Color(0.75, 0.6, 0.35, 0.55)
	sb.set_border_width_all(3 if focus else 2)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func _style_input(c: Control, fsize: int) -> void :
	c.add_theme_stylebox_override("normal", _box_style(false))
	c.add_theme_stylebox_override("focus", _box_style(true))
	c.add_theme_stylebox_override("read_only", _box_style(false))
	c.add_theme_font_override("font", UI.font("body", 800))
	c.add_theme_font_size_override("font_size", fsize)
	c.add_theme_color_override("font_color", UI.INK)
	c.add_theme_color_override("font_readonly_color", UI.INK)
	c.add_theme_color_override("font_placeholder_color", Color(0.75, 0.7, 0.65, 0.45))
	c.add_theme_color_override("caret_color", UI.GOLD)
	c.add_theme_color_override("selection_color", Color(0.9, 0.75, 0.45, 0.35))


static func nick_field(rect: Rect2, text: = "") -> LineEdit:
	var le: = LineEdit.new()
	le.position = rect.position
	le.size = rect.size
	le.max_length = G.NICK_MAX
	le.placeholder_text = s("card.ph")
	le.text = text
	le.context_menu_enabled = false
	le.select_all_on_focus = false
	le.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_style_input(le, 30)
	le.text_submitted.connect( func(_t): le.release_focus())
	return le


static func code_field(rect: Rect2, editable: = true) -> TextEdit:
	var te: = TextEdit.new()
	te.position = rect.position
	te.size = rect.size
	te.editable = editable
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	te.placeholder_text = s("code.ph")
	te.context_menu_enabled = true
	_style_input(te, 19)
	return te


# Round button with a drawn die (no emoji font on device).
static func dice_button(rect: Rect2) -> JButton:
	var b: = JButton.make("", "gold", rect, null, 24, 24)
	var d: = _Die.new()
	var sz: = minf(rect.size.x, rect.size.y) * 0.56
	d.position = (rect.size - Vector2(sz, sz)) * 0.5
	d.size = Vector2(sz, sz)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(d)
	b.set_meta("die", d)
	return b


static func roll(b: JButton) -> void :
	var d: Control = b.get_meta("die", null)
	if d == null:
		return
	d.pivot_offset = d.size * 0.5
	d.rotation = 0.0
	var t: = d.create_tween()
	t.tween_property(d, "rotation", TAU, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if d.has_method("next"):
		d.next()


class _Die extends Control:
	var face: = 5
	const PIPS: = {
		1: [Vector2(0.5, 0.5)],
		2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
		3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
		4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
		5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
		6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
	}

	func next() -> void :
		face = (face % 6) + 1 if randf() < 0.5 else randi_range(1, 6)
		queue_redraw()

	func _draw() -> void :
		var r: = Rect2(Vector2.ZERO, size)
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color("fff6e4")
		sb.border_color = Color("3a2410")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(size.x * 0.22))
		draw_style_box(sb, r)
		for p in PIPS[face]:
			draw_circle(p * size, size.x * 0.085, Color("3a2410" if face != 1 else "c0304a"))


# ---- avatar row ------------------------------------------------------------------------------

class AvatarRow extends Control:
	signal picked(hero: String)
	var selected: = "mc"
	var slot: = 120.0
	var avs: = {}

	func setup(sel: String, w: float) -> AvatarRow:
		selected = sel if G.HEROES.has(sel) else "mc"
		size = Vector2(w, 150)
		slot = w / G.HERO_ORDER.size()
		mouse_filter = Control.MOUSE_FILTER_PASS
		_fill()
		return self

	func select(h: String) -> void :
		if not G.HEROES.has(h):
			return
		selected = h
		_fill()

	func _fill() -> void :
		avs.clear()
		for c in get_children():
			remove_child(c)
			c.queue_free()
		var av: = minf(slot - 16, 104.0)
		for i in G.HERO_ORDER.size():
			var h: String = G.HERO_ORDER[i]
			var on: = h == selected
			var x: = i * slot + (slot - av) * 0.5
			var hit: = Control.new()
			hit.position = Vector2(i * slot, 0)
			hit.size = Vector2(slot, size.y)
			hit.mouse_filter = Control.MOUSE_FILTER_STOP
			add_child(hit)
			if on:
				# soft gold glow behind the chosen one (the frame hole sits a little above the box centre)
				var hr: = V8Art.hole_rect(Vector2(av, av))
				var glow: = Sprite2D.new()
				glow.texture = G.fx("glow")
				glow.material = Fx.add_mat()
				glow.position = Vector2(x, 8) + hr.get_center()
				glow.scale = Vector2.ONE * av / 70.0
				glow.modulate = Color(1.0, 0.82, 0.45, 0.55)
				add_child(glow)
			var a: = V8Art.avatar(self, h, Rect2(x, 8, av, av))
			avs[h] = a
			if not on:
				a.modulate = Color(0.62, 0.58, 0.6, 0.92)
				a.scale = Vector2(0.9, 0.9)
			var nm: = UI.center_label(UI.label(G.HEROES[h].name, 16, UI.GOLD if on else UI.MUTED, UI.DARK, 3, "body", 900), Rect2(i * slot - 4, av + 14, slot + 8, 26))
			add_child(nm)
			hit.gui_input.connect( func(e):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					# 0.9: V9Feel press (dip + spring, click, haptic) on the newly selected avatar (_fill rebuilt it)
					if h != selected:
						select(h)
						V9Feel.press(avs.get(h) as CanvasItem)
						picked.emit(h)
					else:
						V9Feel.press(a, "", "tap"))


static func avatar_row(sel: String, rect: Rect2) -> AvatarRow:
	var r: = AvatarRow.new()
	r.position = rect.position
	r.setup(sel, rect.size.x)
	return r


# ---- recovery code ---------------------------------------------------------------------------

static func copy_code(main, code: String) -> void :
	DisplayServer.clipboard_set(code)
	Sfx.play("pop")
	if main != null and main.has_method("toast"):
		main.toast(s("code.copied"), "gift")


# Popup with the player's code (profile screen).
static func show_code_popup(main) -> RBox:
	var code: = V8Recovery.export_code()
	var p: = Common.popup(main, s("code.title"), 760)
	var w: = p.size.x
	var d: = UI.label(s("code.show_d"), 20, UI.INK, UI.DARK, 2, "body", 800)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.position = Vector2(36, 60)
	d.size = Vector2(w - 72, 140)
	p.add_child(d)
	var te: = code_field(Rect2(36, 212, w - 72, 356), false)
	te.text = code
	p.add_child(te)
	var info: = UI.label(s("code.len") % [code.length(), V8PlayRules.plural(code.length(), "символ", "символа", "символов")], 16, UI.MUTED)
	info.position = Vector2(40, 580)
	info.size = Vector2(w - 80, 24)
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	p.add_child(info)
	var cp: = JButton.make(s("code.copy"), "gold", Rect2(60, 630, w - 120, 96), null, 30)
	cp.pressed.connect( func(): copy_code(main, code))
	p.add_child(cp)
	return p


# Code entry panel inside any parent (card or popup). on_code(code: String) is called on «Перенести».
# Returns {field, error, go}.
static func code_entry(parent: Control, rect: Rect2, on_code: Callable, on_back: = Callable()) -> Dictionary:
	var x: = rect.position.x
	var y: = rect.position.y
	var w: = rect.size.x
	var d: = UI.label(s("code.enter_d"), 20, UI.INK, UI.DARK, 2, "body", 800)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.position = Vector2(x, y)
	d.size = Vector2(w, 84)
	parent.add_child(d)
	var te: = code_field(Rect2(x, y + 96, w, 300))
	parent.add_child(te)
	var err: = UI.label("", 19, Color("ff9a9a"), UI.DARK, 2, "body", 900)
	err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	err.position = Vector2(x + 210, y + 410)
	err.size = Vector2(w - 210, 60)
	err.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(err)
	var paste: = JButton.make(s("code.paste"), "glass", Rect2(x, y + 408, 190, 64), null, 22)
	paste.pressed.connect( func():
		var c: = DisplayServer.clipboard_get()
		if c.strip_edges() != "":
			te.text = c.strip_edges()
			err.text = "")
	parent.add_child(paste)
	var by: = y + 490
	var go: JButton
	if on_back.is_valid():
		var bw: = (w - 16) * 0.38
		var back: = JButton.make(s("code.back"), "glass", Rect2(x, by, bw, 88), null, 26)
		back.pressed.connect(on_back)
		parent.add_child(back)
		go = JButton.make(s("code.go"), "gold", Rect2(x + bw + 16, by, w - bw - 16, 88), null, 26)
	else:
		go = JButton.make(s("code.go"), "gold", Rect2(x, by, w, 88), null, 28)
	go.pressed.connect( func():
		var c: = te.text.strip_edges()
		on_code.call(c))
	# 0.9: an empty or malformed code is refused by the gate (V8Recovery.decode is pure): the tap gets only the deny,
	# the error line says why — never the gold button's success pop followed by a shaking field
	go.set_gate( func(): return te.text.strip_edges() != "" and bool(V8Recovery.decode(te.text).get("ok", false)), func():
		if te.text.strip_edges() == "":
			err.text = s("code.empty")
		else:
			V8Recovery.decode(te.text)
			err.text = V8Recovery.last_error
		V9Feel.deny(te))
	parent.add_child(go)
	return {"field": te, "error": err, "go": go}


# Popup flow for the profile screen: enter → confirm → import → rebuild.
static func enter_code_popup(main) -> RBox:
	var p: = Common.popup(main, s("code.title"), 660)
	var ui: = {}
	var on_code: = func(code: String):
		var chk: = V8Recovery.decode(code)
		if not chk.get("ok", false):
			ui.error.text = V8Recovery.last_error if V8Recovery.last_error != "" else str(chk.get("err", ""))
			V9Feel.deny(ui.field)
			return
		var do_import: = func():
			if V8Recovery.import_code(code):
				Common.close_popup(p)
				Sfx.play("reveal_sr", 1.0, -4)
				main.screen_id = ""
				main.go("profile", {"from": "home"}, false)
				main.refresh_currency()
				main.toast(s("code.done"), "gift")
			else:
				ui.error.text = V8Recovery.last_error
		Common.confirm(main, s("code.confirm_t"), s("code.confirm"), "", 0, do_import, {"yes_text": s("code.confirm_yes")})
	ui.merge(code_entry(p, Rect2(36, 60, p.size.x - 72, 580), on_code))
	return p
