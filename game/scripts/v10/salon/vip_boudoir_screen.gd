class_name V10VipBoudoirScreen
extends Control

# Screen "v10boudoir" — VIP-Будуары Салона (0.11.0 AAA 16+ luxury suites powered by Higgsfield art).
# 4 bespoke suites (Маджонг-тян, Рин, Юэ, Нова) with slow camera breathing, warm petals, heroine 16+ CG
# portrait, JP voice lines, interactive V10AffCurve affection gift giving, milestone tracker, and Hide-UI mode.

const VIP_DIR: = "res://assets/v10/salon_vip/"
const CG_DIR: = "res://assets/v10/cg_16/"

const SUITES: Array[Dictionary] = [
	{
		"id": "mc",
		"hero": "mc",
		"name": "Алый будуар хозяйки",
		"sub": "Бархат, свечи и закрытый стол на двоих",
		"bg": "boudoir_mc.webp",
		"cg": "intro_mc_table.webp",
		"accent": Color("#F6B464"),
		"lines": [
			"Запирай дверь на засов. После полуночи здесь действуют только мои правила~",
			"Шёлковые чулки чуть жмут… подашь мне бокал чая и сядешь поближе?",
			"Если выдержишь мой взгляд, покажу тебе тайный расклад хозяйки.",
		],
	},
	{
		"id": "rin",
		"hero": "rin",
		"name": "Полуночный бар Рин",
		"sub": "Нефритовый свет, редкий улун и приватная стойка",
		"bg": "teabar_rin.webp",
		"cg": "rin.webp",
		"accent": Color("#FF799A"),
		"lines": [
			"Гости уже разошлись. Я оставила для тебя самое тёплое место у стойки.",
			"Не отводи глаз… мой наряд сегодня и правда чуть смелее обычного.",
			"Выпьешь со мной за закрытыми ставнями? Очки снимать я не буду.",
		],
	},
	{
		"id": "yue",
		"hero": "yue",
		"name": "Лунные купальни Юэ",
		"sub": "Серебряный пар, лепестки и шёлковая вуаль",
		"bg": "moonbath_yue.webp",
		"cg": "intro_yue_moon.webp",
		"accent": Color("#C7A6FF"),
		"lines": [
			"Вода сегодня тёплая, как лунный свет. Осторожнее — шёлк легко соскальзывает.",
			"Шепни мне желание, пока лепестки касаются воды… я никому не расскажу.",
			"Твои пальцы дрожат, когда ты берёшь кость. Позволь согреть тебя.",
		],
	},
	{
		"id": "nova",
		"hero": "nova",
		"name": "Пентхаус Новы",
		"sub": "Неоновая панорама города и приватный диван",
		"bg": "penthouse_nova.webp",
		"cg": "nova_roof.webp",
		"accent": Color("#6EE7FF"),
		"lines": [
			"Весь мегаполис внизу, а сигнал камер я уже отключила. Мы одни.",
			"Любишь этот блестящий костюм? Задержись — покажу ещё пару ракурсов.",
			"Забудь про статистику на час. Сейчас моя единственная цель — ты.",
		],
	},
]

var main
var W: = 720.0
var H: = 1280.0
var _idx: = 0
var _line_i: = 0
var _ui_hidden: = false
var _t: = 0.0

var _bg_tex: TextureRect
var _cg_tex: TextureRect
var _ui_layer: Control
var _tabs_box: Control
var _tab_btns: Array[Control] = []
var _suite_title: Label
var _suite_sub: Label
var _hero_name_lbl: Label
var _dlg_lbl: Label
var _aff_lbl: Label
var _aff_bar_fill: ColorRect
var _mile_lbl: Label
var _gift_tray: Control
var _gift_btns: Array[Control] = []
var _hide_btn: Panel
var _hide_lbl: Label
var _fx_layer: Control


func build(m, args: Dictionary) -> void:
	main = m
	W = size.x
	H = size.y
	if main != null and main.has_method("show_chrome"):
		main.show_chrome(false, false)
	Sfx.music("menu")
	var req_h: = String(args.get("hero", G.S.get("partner", "mc")))
	for i in SUITES.size():
		if String(SUITES[i].hero) == req_h or String(SUITES[i].id) == req_h:
			_idx = i
			break
	var br: = V10Layout.bleed_rect(self)
	var base: = ColorRect.new()
	base.color = Color("#120816")
	base.position = br.position
	base.size = br.size
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	_bg_tex = TextureRect.new()
	_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_tex.position = br.position - Vector2(20, 20)
	_bg_tex.size = br.size + Vector2(40, 40)
	_bg_tex.pivot_offset = _bg_tex.size * 0.5
	_bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_tex)

	# Warm atmospheric vignette keeping the boudoir art vivid & glowing
	var vig: = Common.vignette(self, size, Color(0.10, 0.03, 0.12), 0.34)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Heroine 16+ CG card floating softly in the upper-center luxury frame
	_cg_tex = TextureRect.new()
	_cg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cg_tex.position = Vector2(0, 128)
	_cg_tex.size = Vector2(W, H - 560)
	_cg_tex.visible = false
	_cg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cg_tex)

	Fx.ambient(self, "petals", size)

	_fx_layer = Control.new()
	_fx_layer.size = size
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.z_index = 40
	add_child(_fx_layer)

	_ui_layer = Control.new()
	_ui_layer.size = size
	_ui_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui_layer.z_index = 20
	add_child(_ui_layer)

	_build_header()
	_build_suite_tabs()
	_build_bottom_panel()

	# Always-on Hide-UI toggle button in top-right (visible even when UI is hidden)
	_hide_btn = _pill(Rect2(W - 118, 20, 102, 48), Color(0.12, 0.06, 0.18, 0.88), Color("#F4D484"), 24)
	_hide_btn.z_index = 60
	_hide_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_hide_lbl = UI.center_label(UI.label("Арт", 18, Color("#FFE7A8"), Color(0.06, 0.02, 0.10), 3, "body", 900), Rect2(0, 0, 102, 48))
	_hide_btn.add_child(_hide_lbl)
	_hide_btn.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			_hide_btn.accept_event()
			_toggle_ui())
	add_child(_hide_btn)

	# Tap anywhere on the room while UI is hidden restores UI; while visible triggers a flirty line!
	gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			if _ui_hidden:
				_toggle_ui()
			else:
				_next_line(true))

	set_meta("v8_back", _back)
	_apply_suite(false)


func _process(dt: float) -> void:
	_t += dt
	if _bg_tex != null and is_instance_valid(_bg_tex):
		var sc: = 1.025 + sin(_t * 0.55) * 0.014
		_bg_tex.scale = Vector2(sc, sc)
		_bg_tex.rotation = sin(_t * 0.32) * 0.004


func _build_header() -> void:
	var back_b: = _pill(Rect2(16, 18, 56, 52), Color(0.13, 0.06, 0.19, 0.90), Color("#E8C47E"), 16)
	back_b.mouse_filter = Control.MOUSE_FILTER_STOP
	back_b.add_child(UI.center_label(UI.label("‹", 32, Color("#FFF4DE"), Color(0.06, 0.02, 0.10), 3, "body", 900), Rect2(0, -3, 56, 52)))
	back_b.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			back_b.accept_event()
			_back())
	_ui_layer.add_child(back_b)

	var tag: = _pill(Rect2(84, 18, 126, 30), Color(0.56, 0.10, 0.28, 0.94), Color("#FFD984"), 15)
	tag.add_child(UI.center_label(UI.label("VIP · 16+", 15, Color("#FFF6E6"), Color(0.24, 0.04, 0.12), 2, "body", 900), Rect2(0, 0, 126, 30)))
	_ui_layer.add_child(tag)

	_suite_title = UI.label("", 28, Color("#FFF7E8"), Color(0.08, 0.02, 0.12), 5, "body", 900)
	_suite_title.position = Vector2(84, 48)
	_suite_title.size = Vector2(W - 220, 36)
	_ui_layer.add_child(_suite_title)

	_suite_sub = UI.label("", 17, Color("#F4D48A"), Color(0.08, 0.02, 0.12), 3, "body", 700)
	_suite_sub.position = Vector2(84, 84)
	_suite_sub.size = Vector2(W - 110, 24)
	_ui_layer.add_child(_suite_sub)

	# Quick toggle to switch to restoration Salon map
	var map_b: = _pill(Rect2(W - 236, 20, 108, 48), Color(0.14, 0.07, 0.21, 0.88), Color("#D8B878"), 24)
	map_b.mouse_filter = Control.MOUSE_FILTER_STOP
	map_b.add_child(UI.center_label(UI.label("Салон ›", 17, Color("#F5E7CF"), Color(0.06, 0.02, 0.10), 3, "body", 800), Rect2(0, 0, 108, 48)))
	map_b.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			map_b.accept_event()
			if main != null and main.has_method("go"):
				main.go("v10salon"))
	_ui_layer.add_child(map_b)


func _build_suite_tabs() -> void:
	_tabs_box = Control.new()
	_tabs_box.position = Vector2(18, 120)
	_tabs_box.size = Vector2(W - 36, 86)
	_ui_layer.add_child(_tabs_box)
	var gap: = 10.0
	var bw: = (W - 36.0 - gap * float(SUITES.size() - 1)) / float(SUITES.size())
	_tab_btns.clear()
	for i in SUITES.size():
		var s: Dictionary = SUITES[i]
		var idx: = i
		var p: = _pill(Rect2(float(i) * (bw + gap), 0, bw, 82), Color(0.11, 0.05, 0.17, 0.88), Color("#9B7A4B"), 18)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		var hid_t: = String(s.hero)
		var hname: = String(G.HEROES.get(hid_t, {}).get("name", hid_t))
		var av_ok: = false
		if main != null and main.has_method("_avatar"):
			var av_c: Control = main._avatar(hid_t, Rect2(8, 14, 52, 52))
			if av_c != null:
				av_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
				p.add_child(av_c)
				av_ok = true
		if not av_ok:
			var av_p: = V8Art.emotion_path(hid_t, "happy") if V8Art.has_emotion(hid_t, "happy") else "res://assets/hero/%s.png" % hid_t
			if ResourceLoader.exists(av_p):
				var av: = TextureRect.new()
				av.texture = load(av_p)
				av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				av.position = Vector2(8, 14)
				av.size = Vector2(52, 52)
				av.mouse_filter = Control.MOUSE_FILTER_IGNORE
				p.add_child(av)
		var short_nm: = "Хозяйка" if hid_t == "mc" else hname
		var nl: = UI.label(short_nm, 16, Color("#FFF3DE"), Color(0.06, 0.02, 0.10), 3, "body", 900)
		nl.position = Vector2(64, 18)
		nl.size = Vector2(bw - 70, 24)
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		p.add_child(nl)
		var sl: = UI.label("Ур. %d" % G.aff_level(hid_t), 15, Color("#F6CE78"), Color(0.06, 0.02, 0.10), 2, "body", 800)
		sl.name = "LvLbl"
		sl.position = Vector2(64, 44)
		sl.size = Vector2(bw - 70, 22)
		p.add_child(sl)
		p.gui_input.connect(func(e: InputEvent) -> void:
			if _is_tap(e):
				p.accept_event()
				_idx = idx
				_line_i = 0
				V9Feel.press(p, "tap")
				_apply_suite(true))
		_tabs_box.add_child(p)
		_tab_btns.append(p)


func _build_bottom_panel() -> void:
	var panel_h: = 408.0
	var py: = H - panel_h - 18.0
	var box: = _pill(Rect2(18, py, W - 36, panel_h), Color(0.11, 0.04, 0.16, 0.93), Color("#F6D484"), 26)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_layer.add_child(box)

	# Nameplate badge + Talk button
	var name_pl: = _pill(Rect2(20, -22, 232, 44), Color(0.46, 0.11, 0.28, 0.98), Color("#FFE49C"), 22)
	box.add_child(name_pl)
	_hero_name_lbl = UI.center_label(UI.label("", 22, Color("#FFF7EA"), Color(0.16, 0.03, 0.10), 3, "body", 900), Rect2(8, 0, 216, 44))
	name_pl.add_child(_hero_name_lbl)

	var talk_b: = _pill(Rect2(box.size.x - 196, -20, 176, 42), Color(0.18, 0.09, 0.26, 0.96), Color("#EED089"), 21)
	talk_b.mouse_filter = Control.MOUSE_FILTER_STOP
	talk_b.add_child(UI.center_label(UI.label("Поговорить ›", 17, Color("#FFE8AE"), Color(0.06, 0.02, 0.10), 3, "body", 900), Rect2(0, 0, 176, 42)))
	talk_b.gui_input.connect(func(e: InputEvent) -> void:
		if _is_tap(e):
			talk_b.accept_event()
			V9Feel.press(talk_b, "tap")
			_next_line(true))
	box.add_child(talk_b)

	# Dialogue text (25px bold)
	_dlg_lbl = UI.label("", 24, Color("#FFF8EE"), Color(0.05, 0.02, 0.08), 4, "body", 800)
	_dlg_lbl.position = Vector2(22, 34)
	_dlg_lbl.size = Vector2(box.size.x - 44, 102)
	_dlg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_dlg_lbl)

	# Affection bar + next 16+ milestone
	_aff_lbl = UI.label("", 18, Color("#FFABC4"), Color(0.06, 0.02, 0.10), 3, "body", 900)
	_aff_lbl.position = Vector2(22, 144)
	_aff_lbl.size = Vector2(box.size.x - 44, 26)
	box.add_child(_aff_lbl)

	var bar_bg: = ColorRect.new()
	bar_bg.color = Color(0.24, 0.12, 0.30, 0.95)
	bar_bg.position = Vector2(22, 174)
	bar_bg.size = Vector2(box.size.x - 44, 12)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar_bg)

	_aff_bar_fill = ColorRect.new()
	_aff_bar_fill.color = Color("#FF6F9E")
	_aff_bar_fill.position = Vector2(22, 174)
	_aff_bar_fill.size = Vector2(0, 12)
	_aff_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_aff_bar_fill)

	_mile_lbl = UI.label("", 16, Color("#F6D68B"), Color(0.06, 0.02, 0.10), 3, "body", 800)
	_mile_lbl.position = Vector2(22, 192)
	_mile_lbl.size = Vector2(box.size.x - 44, 24)
	_mile_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_mile_lbl)

	# Gift Tray (3 gifts from V10AffCurve.GIFTS)
	var cap: = UI.label("Подарить подарок хозяйке · Симпатия", 17, Color("#EDE0CE"), Color(0.06, 0.02, 0.10), 3, "body", 900)
	cap.position = Vector2(22, 224)
	cap.size = Vector2(box.size.x - 44, 24)
	box.add_child(cap)

	_gift_tray = Control.new()
	_gift_tray.position = Vector2(18, 254)
	_gift_tray.size = Vector2(box.size.x - 36, 138)
	box.add_child(_gift_tray)
	_build_gift_cards()


func _build_gift_cards() -> void:
	for c in _gift_tray.get_children():
		c.queue_free()
	_gift_btns.clear()
	var gifts: Array = V10AffCurve.GIFTS
	var gap: = 10.0
	var cw: = (_gift_tray.size.x - gap * float(gifts.size() - 1)) / float(gifts.size())
	for i in gifts.size():
		var gd: Dictionary = gifts[i]
		var gid: = String(gd.id)
		var card: = _pill(Rect2(float(i) * (cw + gap), 0, cw, 134), Color(0.18, 0.08, 0.25, 0.95), Color("#DFB968"), 18)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var aff_l: = UI.center_label(UI.label("+%d ♥" % int(gd.aff), 20, Color("#FF9EBE"), Color(0.08, 0.02, 0.10), 3, "body", 900), Rect2(4, 8, cw - 8, 26))
		card.add_child(aff_l)
		var nm_l: = UI.center_label(UI.label(String(gd.name), 16, Color("#FFF6E8"), Color(0.06, 0.02, 0.10), 3, "body", 800), Rect2(6, 38, cw - 12, 38))
		nm_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(nm_l)
		var inv_n: = V10AffCurve.gift_count(gid)
		var price_s: = ("В сумке: %d" % inv_n) if inv_n > 0 else ("%d %s" % [int(gd.price), "монет" if String(gd.cur) == "coins" else "крист."])
		var pr_bg: = _pill(Rect2(10, 86, cw - 20, 36), Color(0.46, 0.12, 0.28, 0.95) if inv_n > 0 else Color(0.24, 0.14, 0.32, 0.96), Color("#F6D686"), 14)
		var pr_l: = UI.center_label(UI.label(price_s, 15, Color("#FFEBA8"), Color(0.06, 0.02, 0.10), 2, "body", 900), Rect2(0, 0, cw - 20, 36))
		pr_l.name = "PriceLbl"
		pr_bg.add_child(pr_l)
		card.add_child(pr_bg)
		card.gui_input.connect(func(e: InputEvent) -> void:
			if _is_tap(e):
				card.accept_event()
				V9Feel.press(card, "tap")
				_give_gift(gid, card.get_global_rect().get_center()))
		_gift_tray.add_child(card)
		_gift_btns.append(card)


func _apply_suite(play_voice: bool) -> void:
	var s: Dictionary = SUITES[clampi(_idx, 0, SUITES.size() - 1)]
	var bg_p: = VIP_DIR + String(s.bg)
	var tex: Texture2D = _load_tex(bg_p)
	if tex != null:
		_bg_tex.texture = tex
	_suite_title.text = String(s.name)
	_suite_sub.text = String(s.sub)
	var hid: = String(s.hero)
	_hero_name_lbl.text = String(G.HEROES.get(hid, {}).get("name", hid))
	for i in _tab_btns.size():
		var sb: = _tab_btns[i].get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.border_color = Color("#FFE391") if i == _idx else Color("#7B5E42")
			sb.set_border_width_all(3 if i == _idx else 1)
			sb.bg_color = Color(0.32, 0.10, 0.26, 0.94) if i == _idx else Color(0.11, 0.05, 0.17, 0.84)
		var lv_n: = _tab_btns[i].get_node_or_null("LvLbl") as Label
		if lv_n != null:
			lv_n.text = "Ур. %d" % G.aff_level(String(SUITES[i].hero))
	_refresh_aff()
	_next_line(play_voice)


func _refresh_aff() -> void:
	var s: Dictionary = SUITES[clampi(_idx, 0, SUITES.size() - 1)]
	var hid: = String(s.hero)
	var info: Dictionary = V10AffCurve.hero_progress(hid)
	var lv: = int(info.get("level", 1))
	var into: = int(info.get("into", 0))
	var need: = int(info.get("need", 120))
	var ratio: = float(info.get("ratio", 0.0))
	_aff_lbl.text = "♥ Симпатия · Ур. %d   (%d / %d)" % [lv, into, need]
	_aff_bar_fill.size.x = (W - 80.0) * clampf(ratio, 0.0, 1.0)
	var nm: Dictionary = info.get("next_milestone", {})
	if not nm.is_empty():
		_mile_lbl.text = "Рубеж Ур. %d: %s" % [int(nm.level), String(nm.title)]
	else:
		_mile_lbl.text = "Максимальный уровень близости достигнут"
	_build_gift_cards()


func _next_line(play_voice: bool) -> void:
	var s: Dictionary = SUITES[clampi(_idx, 0, SUITES.size() - 1)]
	var lines: Array = s.lines
	var txt: = String(lines[_line_i % lines.size()])
	_line_i += 1
	_dlg_lbl.text = txt
	if play_voice:
		Sfx.say(String(s.hero), "greet")


func _give_gift(gid: String, from_pos: Vector2) -> void:
	var s: Dictionary = SUITES[clampi(_idx, 0, SUITES.size() - 1)]
	var hid: = String(s.hero)
	var res: Dictionary = V10AffCurve.buy_and_give_gift(gid, hid)
	if not bool(res.get("ok", false)):
		if main != null and main.has_method("toast"):
			main.toast("Не хватает валюты для подарка", "lock")
		return
	G.save()
	Sfx.play("win", 1.15, -6.0)
	Sfx.say(hid, "win")
	if main != null and main.has_method("refresh_currency"):
		main.refresh_currency(true)
	Fx.burst(_fx_layer, from_pos, "heart", 14)
	var ms: Dictionary = res.get("milestone", {})
	if not ms.is_empty() and main != null and main.has_method("toast"):
		main.toast("Новый рубеж: %s!" % String(ms.get("title", "")), "star")
	elif main != null and main.has_method("toast"):
		main.toast("+%d симпатии (%s)" % [int(res.get("aff", 0)), String(G.HEROES.get(hid, {}).get("name", hid))], "heart")
	_refresh_aff()


func _toggle_ui() -> void:
	_ui_hidden = not _ui_hidden
	_ui_layer.visible = not _ui_hidden
	_hide_lbl.text = "Показать" if _ui_hidden else "Арт"


func _back() -> void:
	if _ui_hidden:
		_toggle_ui()
		return
	if main != null and main.has_method("back"):
		main.back()


static func _load_tex(p: String) -> Texture2D:
	if ResourceLoader.exists(p):
		var t: = load(p) as Texture2D
		if t != null:
			return t
	var gp: = ProjectSettings.globalize_path(p)
	if FileAccess.file_exists(gp):
		var im: = Image.load_from_file(gp)
		if im != null and not im.is_empty():
			return ImageTexture.create_from_image(im)
	return null


static func _pill(r: Rect2, bg: Color, border: Color, rad: int) -> Panel:
	var p: = Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(rad)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)
	return p


static func _is_tap(e: InputEvent) -> bool:
	return (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
