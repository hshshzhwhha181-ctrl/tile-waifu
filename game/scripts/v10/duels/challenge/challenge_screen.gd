class_name V10ChallengeScreen
extends Control

# «Вызов по коду» (spec 0.10 R5) — the screen behind Столы → Соперницы and the quiet icon of Дуэли.
#   home : «Вставить» (primary; reads the clipboard only on that tap and finds the code in any text),
#          «Ввести вручную» (secondary, a sheet with one field), the last 20 challenges (taken and sent)
#   card : the decoded challenge — mode, table, author, time, stars, «время не проверено сервером», what a win
#          pays; «Играть» (primary) starts the very same deal, «Вставить другой» (secondary)
# plus the «Бросить вызов» sheet for win screens: open_throw(host, ctx) — poster preview, «Скопировать текст»
# (primary), «Сохранить в альбом» (secondary).
#
#   main.go("challenge", {code?: text, throw?: ctx, back_to?: screen id})        build(main, args)
#   V10ChallengeScreen.open_throw(host, ctx) -> V10ChallengeUI.Sheet             ctx from V10ChallengeRun.ctx_from_play()
#
# Budgets (UX §3.7, work screen): one «Игра», ≤ 2 secondary, ≤ 2 quiet (‹ and ?), ≤ 10 tappable, ≤ 60 words,
# 4 type sizes (44 header · 32 · 22 · 18), hit zones ≥ 80, no «%» and no «₽».

const U: = preload("res://scripts/v10/duels/challenge/challenge_util.gd")
const C: = preload("res://scripts/v10/duels/challenge/challenge_code.gd")
const D: = preload("res://scripts/v10/duels/challenge/challenge_deal.gd")
const ST: = preload("res://scripts/v10/duels/challenge/challenge_state.gd")
const UI2: = preload("res://scripts/v10/duels/challenge/challenge_ui.gd")
const P: = preload("res://scripts/v10/duels/challenge/challenge_poster.gd")

const ROWS_VISIBLE: = 4
const ROW_H: = 88.0
const RESULT_WORD: = {"win": "Победа", "lose": "Пока нет", "": "Не сыгран", "sent": "Отправлен"}

var main
var args: = {}
var vs: = Vector2(720, 1280)
var cx: = 0.0
var T: = 0.0
var B: = 0.0
var header: V10Header
var page: Control
var state: = "home"
var cur: = {}  # {dc: decode result, deal: resolve result}
var last_error: = ""
var btn_primary: V10Button
var btn_second: V10Button

# ---------------------------------------------------------------- build

func build(m, a: Dictionary) -> void:
	main = m
	args = a
	ST.register_save()
	if main and main.has_method("show_chrome"):
		main.show_chrome(false, false)
	vs = size if size.x > 0 else get_viewport_rect().size
	cx = UI2.col_x(vs)
	var ins: = V10Hud2Util.safe_insets(vs)
	T = float(ins.top)
	B = float(ins.bottom)
	var bg: = _Bg.new()
	bg.size = vs
	add_child(bg)
	header = V10Header.make(self, "Вызов по коду", _back, _help)
	for b in [header.back_btn, header.help_btn]:
		if b:
			b.set_meta("ux_role", "tertiary")
			b.pressed.connect(func(): U.press(b))
	U.music("play_screen", ["duels"])
	if a.has("code") and String(a.code) != "":
		take_text(String(a.code))
	else:
		show_home()
	if a.has("throw") and a.throw is Dictionary:
		open_throw(self, a.throw)


func handle_back() -> bool:
	if UI2.Sheet.current != null and is_instance_valid(UI2.Sheet.current):
		UI2.Sheet.current.close()
		return true
	if state == "card":
		show_home()
		return true
	return false


func _back() -> void:
	if handle_back():
		return
	var to: = String(args.get("back_to", ""))
	if main == null:
		return
	if to != "" and main.get("SCREENS") is Dictionary and (main.SCREENS as Dictionary).has(to):
		main.go(to)
	elif main.has_method("back"):
		main.back()


func _help() -> void:
	var s: = UI2.Sheet.open(self, "Как устроен вызов")
	var y: = 104.0
	var lines: = [
		"Код хранит стол и время автора. Вставь его — сыграешь ту же раскладку.",
		"Победа — быстрее автора и не меньше звёзд. Помощь стоит звезду.",
		"За победу над чужим вызовом — %s, до %d раз в день." % [U.gems_text(ST.win_gems()), ST.daily_cap()],
	]
	for t in lines:
		var l: = UI2.text(t, "ui", 22, V10DS.PAPER_300, UI2.W - 2 * UI2.M, 2)
		l.position = Vector2(UI2.M, y)
		s.body.add_child(l)
		y += 80.0
	var ok: = UI2.btn("play", "Понятно", Vector2(560, 104), func(): s.close())
	ok.breathing = false
	ok.position = Vector2((UI2.W - 560) * 0.5, y + 16)
	s.body.add_child(ok)
	s.finish(y + 16 + 104 + 32)


func _clear_page() -> void:
	if page and is_instance_valid(page):
		page.free()
	page = Control.new()
	page.name = "Page"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.position = Vector2(cx, 0)
	page.size = Vector2(UI2.W, vs.y)
	add_child(page)
	move_child(page, header.get_index())


func _y0() -> float:
	return V10Header.content_y(vs)


# the action row: primary 560×104 in the bottom third, the secondary 80 under it
func _actions(primary: String, on_primary: Callable, second: String, on_second: Callable) -> void:
	var yb: = vs.y - B - 24.0
	btn_second = null
	if second != "":
		btn_second = UI2.btn("secondary", second, Vector2(560, 80), on_second)
		btn_second.position = Vector2((UI2.W - 560) * 0.5, yb - 80)
		page.add_child(btn_second)
		yb -= 80 + 8
	btn_primary = UI2.btn("play", primary, Vector2(560, 104), on_primary)
	btn_primary.position = Vector2((UI2.W - 560) * 0.5, yb - 104)
	page.add_child(btn_primary)

# ---------------------------------------------------------------- home

func show_home() -> void:
	state = "home"
	cur = {}
	_clear_page()
	var y: = _y0()
	var ents: Array = ST.entries()
	var inhale: = []
	if ents.is_empty():
		_hero_cover()
		var t1: = UI2.text("Друг прислал код?", "display", 32, V10DS.PAPER_100, 360)
		t1.name = "EmptyTitle"
		t1.position = Vector2(UI2.M, y + 24)
		page.add_child(t1)
		t1.set_deferred("size", Vector2(360, V10Type.line_h(32)))
		var t2: = UI2.text("Скопируй его сообщение целиком и вставь сюда. Сыграешь тот же стол и сравнишь время.",
			"ui", 22, V10DS.PAPER_300, 360, 4)
		t2.name = "EmptyBody"
		t2.position = Vector2(UI2.M, y + 80)
		page.add_child(t2)
		t2.set_deferred("size", Vector2(360, V10Type.line_h(22) * 4))
		inhale += [t1, t2]
	else:
		var t3: = UI2.text("Вставь код друга: сыграешь тот же стол и сравнишь время.", "ui", 22, V10DS.PAPER_300, UI2.W - 2 * UI2.M, 2)
		t3.position = Vector2(UI2.M, y + 8)
		page.add_child(t3)
		inhale.append(t3)
	# the code slot: where the code lands; shows a typo or an empty clipboard right here
	var slot_y: = y + 236.0 if ents.is_empty() else y + 88.0
	if ents.is_empty():
		slot_y = vs.y - B - 24.0 - 80 - 8 - 104 - 24 - 136
	var slot: = _slot(last_error)
	slot.position = Vector2(UI2.M, slot_y)
	page.add_child(slot)
	inhale.append(slot)
	if not ents.is_empty():
		var lh: = UI2.text("Недавние вызовы", "ui", 18, V10DS.PAPER_500, 400)
		lh.position = Vector2(UI2.M, slot_y + 152)
		page.add_child(lh)
		var list: = _list(ents, slot_y + 184)
		page.add_child(list)
		inhale += [lh, list]
	_actions("Вставить", paste, "Ввести вручную", open_manual)
	for i in inhale.size():
		U.silk_in(inhale[i], Vector2(0, 12), 0.24, 0.04 * mini(i, 4))


func _hero_cover() -> void:
	var gg: = U.g()
	var hero: = String(gg.S.get("level_partner", "mc")) if gg else "mc"
	var art: = P.outfit_art(hero, P._equipped(hero))
	if art.kind != "cutout":
		art = P.outfit_art(hero, "")
	var tex: Texture2D = V8Art.tex(String(art.path))
	if tex == null:
		return
	var tr: = TextureRect.new()
	tr.name = "Heroine"
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fw: = float(V8Art.RIG_FACE_W.get(hero, 90.0))
	var s: = 96.0 / fw
	var face_at: = Vector2(548, _y0() + 344)
	tr.size = tex.get_size() * s
	tr.position = face_at - V8Art.rig_face(hero) * s
	page.add_child(tr)
	var shade: = _Shade.new()
	shade.size = Vector2(UI2.W, vs.y)
	page.add_child(shade)
	page.set_meta("face_rect", Rect2(cx + face_at.x - 58, face_at.y - 72, 116, 144))


func _slot(err: String) -> Control:
	var box: = UI2.Plate.new(Color(V10DS.NIGHT_800, V10DS.ON_ART_A))
	box.name = "CodeSlot"
	box.size = Vector2(UI2.W - 2 * UI2.M, 128)
	var ph: = UI2.text("TW-····-····-·····", "num", 32, V10DS.PAPER_700, box.size.x - 48)
	ph.position = Vector2(24, 18)
	box.add_child(ph)
	var cap: = UI2.text(err if err != "" else "Код найдётся в любом тексте: ссылка и подписи не мешают", "ui", 18,
		V10DS.EMBER if err != "" else V10DS.PAPER_500, box.size.x - 48, 2)
	cap.name = "SlotCaption"
	cap.position = Vector2(24, 66)
	box.add_child(cap)
	if err != "":
		box.accent = V10DS.EMBER
	return box


func _list(ents: Array, y: float) -> Control:
	var sc: = ScrollContainer.new()
	sc.name = "List"
	sc.position = Vector2(UI2.M, y)
	var room: = vs.y - B - 24.0 - 80 - 8 - 104 - 24 - y
	var rows: = clampi(int(room / ROW_H), 1, ROWS_VISIBLE)
	sc.size = Vector2(UI2.W - 2 * UI2.M, rows * ROW_H)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.custom_minimum_size = Vector2(sc.size.x, 0)
	sc.add_child(vb)
	for e in ents:
		vb.add_child(_row(e, sc.size.x))
	return sc


func _row(e: Dictionary, w: float) -> Control:
	var r: = _Row.new()
	r.name = "Row_" + String(e.get("core", ""))
	r.custom_minimum_size = Vector2(w, ROW_H)
	r.size = Vector2(w, ROW_H)
	var sent: = String(e.get("kind", "")) == "sent"
	var res: = "sent" if sent else String(e.get("result", ""))
	var who: = "Твой вызов" if sent else String(e.get("author", ""))
	if who == "":
		who = "Без подписи"
	var l1: = UI2.text("%s · %s" % [who, _short_table(e)], "ui", 22, V10DS.PAPER_100, w - 200)
	l1.position = Vector2(16, 12)
	r.add_child(l1)
	var l2t: = ""
	if sent:
		l2t = "%s · %s" % [U.fmt_time(int(e.author_t)), U.date_text(U.stamp_of(int(e.get("at", 0))).substr(0, 10))]
	elif int(e.get("my_t", 0)) > 0:
		l2t = "автор %s · ты %s" % [U.fmt_time(int(e.author_t)), U.fmt_time(int(e.my_t))]
	else:
		l2t = "время автора %s" % U.fmt_time(int(e.author_t))
	var l2: = UI2.text(l2t, "ui", 18, V10DS.PAPER_500, w - 200)
	l2.position = Vector2(16, 48)
	r.add_child(l2)
	var col: = {"win": V10DS.JADE_300, "lose": V10DS.PAPER_500, "": V10DS.PAPER_700, "sent": V10DS.GOLD_300}
	var rw: = UI2.text(String(RESULT_WORD.get(res, "")), "ui", 18, col.get(res, V10DS.PAPER_500), 150)
	rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rw.position = Vector2(w - 166, 30)
	r.add_child(rw)
	r.accent = col.get(res, V10DS.PAPER_700) if res in ["win", "sent"] else Color(0, 0, 0, 0)
	r.tapped.connect(func():
		U.press(r)
		if sent:
			open_throw(self, ctx_from_entry(e))
		else:
			take_entry(e))
	return r


func _short_table(e: Dictionary) -> String:
	var t: = String(e.get("title", ""))
	return t if t != "" else String(D.MODE_NAMES.get(int(e.get("mode", 1)), ""))

# ---------------------------------------------------------------- paste and manual entry

# «Вставить»: the clipboard is read here and only here — on the player's tap
func paste() -> void:
	take_text(U.clip_get(), btn_primary)


func take_text(text: String, from: Control = null) -> void:
	var d: = C.extract(text)
	if not d.ok:
		last_error = String(d.err_text) if String(d.get("err", "")) != "empty" else "Буфер пуст. Скопируй сообщение друга с кодом"
		U.sfx("tile_deny")
		if from:
			V9Feel.haptic("deny")
		show_home()
		return
	last_error = ""
	take(d)


func take_entry(e: Dictionary) -> void:
	var p: = {"mode": int(e.mode), "gen": int(e.gen), "key": int(e.key), "tenths": int(e.author_t), "stars": int(e.author_stars)}
	var d: = C.decode(C.encode(p))
	d.nick = String(e.get("author", ""))
	take(d)


# a decoded code → the card
func take(dc: Dictionary) -> void:
	var deal: = D.resolve(dc)
	cur = {"dc": dc, "deal": deal}
	if deal.ok:
		dc.title = String(deal.table)
		ST.record_taken(dc, {"title": String(deal.table)})
		U.save_game()
	show_card()


func open_manual() -> void:
	var s: = UI2.Sheet.open(self, "Ввести код")
	var y: = 100.0
	var le: = LineEdit.new()
	le.name = "CodeField"
	le.placeholder_text = "TW-XXXX-XXXX-XXXXX"
	le.position = Vector2(UI2.M, y)
	le.size = Vector2(UI2.W - 2 * UI2.M, 88)
	le.max_length = 64
	le.add_theme_font_override("font", V10Type.font("num"))
	le.add_theme_font_size_override("font_size", 32)
	le.add_theme_color_override("font_color", V10DS.PAPER_100)
	le.add_theme_color_override("font_placeholder_color", V10DS.PAPER_700)
	le.add_theme_color_override("caret_color", V10DS.GOLD_500)
	le.add_theme_color_override("selection_color", Color(V10DS.GOLD_700, 0.5))
	for k in ["normal", "focus", "read_only"]:
		var sb: = StyleBoxFlat.new()
		sb.bg_color = V10DS.NIGHT_700
		sb.set_corner_radius_all(V10DS.RADIUS)
		sb.set_border_width_all(2 if k == "focus" else 1)
		sb.border_color = V10DS.GOLD_500 if k == "focus" else V10DS.hair()
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		le.add_theme_stylebox_override(k, sb)
	le.set_meta("ux_role", "field")
	s.body.add_child(le)
	var cap: = UI2.text("Буквы и цифры с любыми пробелами и дефисами. Можно вставить сообщение целиком.", "ui", 18, V10DS.PAPER_500, UI2.W - 2 * UI2.M, 2)
	cap.name = "FieldCaption"
	cap.position = Vector2(UI2.M, y + 100)
	s.body.add_child(cap)
	var ok: = UI2.btn("play", "Готово", Vector2(560, 104), func(): _manual_done(s, le, cap))
	ok.breathing = false
	ok.position = Vector2((UI2.W - 560) * 0.5, y + 176)
	s.body.add_child(ok)
	le.text_changed.connect(func(t: String): _manual_live(t, cap))
	le.text_submitted.connect(func(_t): _manual_done(s, le, cap))
	s.finish(y + 176 + 104 + 32)
	if DisplayServer.get_name() != "headless":
		le.grab_focus.call_deferred()


func _manual_live(t: String, cap: Label) -> void:
	var d: = C.extract(t)
	if d.ok:
		cap.text = "Код верный: %s" % String(d.code)
		cap.label_settings = V10Type.settings("ui", 18, V10DS.JADE_300)
	elif C.normalize(t.get_slice(":", 0)).core.length() >= C.SYMBOLS:
		cap.text = String(d.err_text)
		cap.label_settings = V10Type.settings("ui", 18, V10DS.EMBER)
	else:
		cap.text = "Буквы и цифры с любыми пробелами и дефисами. Можно вставить сообщение целиком."
		cap.label_settings = V10Type.settings("ui", 18, V10DS.PAPER_500)


func _manual_done(s, le: LineEdit, cap: Label) -> void:
	var d: = C.extract(le.text)
	if not d.ok:
		cap.text = String(d.err_text)
		cap.label_settings = V10Type.settings("ui", 18, V10DS.EMBER)
		U.sfx("tile_deny")
		return
	s.close()
	last_error = ""
	take(d)

# ---------------------------------------------------------------- the challenge card

func show_card() -> void:
	state = "card"
	_clear_page()
	var dc: Dictionary = cur.dc
	var deal: Dictionary = cur.deal
	var y: = _y0()
	var card: = UI2.Plate.new(V10DS.NIGHT_800)
	card.name = "Card"
	card.position = Vector2(UI2.M, y + 8)
	var w: = UI2.W - 2 * UI2.M
	var own: = ST.is_own(String(dc.core))
	var nick: = String(dc.get("nick", ""))
	var who: = "Твой вызов" if own else ("Вызов от %s" % nick if nick != "" else "Вызов без подписи")
	var cy: = 20.0
	var l_who: = UI2.text(who, "ui", 18, V10DS.GOLD_500, w - 48)
	l_who.position = Vector2(24, cy)
	card.add_child(l_who)
	cy += 30
	if not deal.ok:
		var l_bad: = UI2.text(String(deal.err_text), "display", 32, V10DS.PAPER_100, w - 48, 3)
		l_bad.position = Vector2(24, cy)
		card.add_child(l_bad)
		cy += 40 * 3 + 8
		var hint: = _gen_hint(dc, deal)
		var l_h: = UI2.text(hint, "ui", 18, V10DS.EMBER, w - 48, 2)
		l_h.position = Vector2(24, cy)
		card.add_child(l_h)
		cy += 60
		card.size = Vector2(w, cy + 12)
		page.add_child(card)
		U.silk_in(card, Vector2(0, 12))
		_actions("Вставить другой", paste, "Ввести вручную", open_manual)
		return
	var l_tab: = UI2.text(String(deal.table), "display", 32, V10DS.PAPER_100, w - 48)
	l_tab.position = Vector2(24, cy)
	card.add_child(l_tab)
	cy += 48
	var l_mode: = UI2.text("%s · %d %s" % [String(deal.mode_name), int(deal.pairs), U.plural(int(deal.pairs), "пара", "пары", "пар")],
		"ui", 18, V10DS.PAPER_500, w - 48)
	l_mode.position = Vector2(24, cy)
	card.add_child(l_mode)
	cy += 40
	var hr: = UI2.Hair.new(w - 48)
	hr.position = Vector2(24, cy)
	card.add_child(hr)
	cy += 20
	# the author's result
	var l_a: = UI2.text("Время автора" if not own else "Твоё время", "ui", 22, V10DS.PAPER_300, 300)
	l_a.position = Vector2(24, cy + 4)
	card.add_child(l_a)
	var l_t: = UI2.text(U.fmt_time_full(int(dc.tenths)), "num", 32, V10DS.PAPER_100, 200)
	l_t.name = "AuthorTime"
	l_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l_t.position = Vector2(w - 24 - 124 - 200, cy)
	card.add_child(l_t)
	var stars: = UI2.Stars.new(int(dc.stars), 3, 18.0)
	stars.position = Vector2(w - 24 - 124, cy + 2)
	card.add_child(stars)
	cy += 52
	var e: = ST.find(String(dc.core))
	if not e.is_empty() and int(e.get("my_t", 0)) > 0 and String(e.kind) == "taken":
		var l_m: = UI2.text("Твой лучший", "ui", 22, V10DS.PAPER_300, 300)
		l_m.position = Vector2(24, cy + 4)
		card.add_child(l_m)
		var l_mt: = UI2.text(U.fmt_time_full(int(e.my_t)), "num", 32, V10DS.JADE_300 if String(e.result) == "win" else V10DS.PAPER_100, 200)
		l_mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l_mt.position = Vector2(w - 24 - 124 - 200, cy)
		card.add_child(l_mt)
		var st2: = UI2.Stars.new(int(e.my_stars), 3, 18.0)
		st2.position = Vector2(w - 24 - 124, cy + 2)
		card.add_child(st2)
		cy += 52
	var l_srv: = UI2.text("Время не проверено сервером", "ui", 18, V10DS.PAPER_500, w - 48)
	l_srv.position = Vector2(24, cy)
	card.add_child(l_srv)
	cy += 36
	var hr2: = UI2.Hair.new(w - 48)
	hr2.position = Vector2(24, cy)
	card.add_child(hr2)
	cy += 18
	var l_rule: = UI2.text("Победа — быстрее автора и не меньше звёзд", "ui", 22, V10DS.PAPER_100, w - 48)
	l_rule.position = Vector2(24, cy)
	card.add_child(l_rule)
	cy += 38
	var why: = ST.no_pay_reason(String(dc.core))
	var pay: = UI2.text("Награда: %s" % U.gems_text(ST.win_gems()) if why == "" else String(ST.REASON_TEXT.get(why, "")),
		"ui", 18, V10DS.GOLD_300 if why == "" else V10DS.PAPER_500, w - 48, 2)
	pay.name = "PayLine"
	pay.position = Vector2(24, cy)
	card.add_child(pay)
	cy += 52
	card.size = Vector2(w, cy + 8)
	page.add_child(card)
	U.silk_in(card, Vector2(0, 12))
	_actions("Играть", play, "Вставить другой", paste)
	U.sfx("card_flip")


func _gen_hint(dc: Dictionary, deal: Dictionary) -> String:
	if String(deal.get("err", "")) == "gen":
		var here: = int(deal.get("gen_here", 0))
		var there: = int(deal.get("gen_code", 0))
		return "Версия стола в коде: %d, у тебя: %d" % [there, here]
	return "Код %s" % String(dc.get("code", ""))


func play() -> void:
	if cur.is_empty() or not cur.deal.ok:
		return
	var dc: Dictionary = cur.dc
	var ch: = {"mode": int(dc.mode), "gen": int(dc.gen), "key": int(dc.key), "tenths": int(dc.tenths), "stars": int(dc.stars),
		"core": String(dc.core), "code": String(dc.code), "nick": String(dc.get("nick", "")), "title": String(cur.deal.table)}
	var gg: = U.g()
	U.go_play(main, {"challenge": ch, "partner": String(gg.S.get("level_partner", "mc")) if gg else "mc"})

# ---------------------------------------------------------------- «Бросить вызов»

# ctx = {p: {mode, gen, key, tenths, stars}, deal: resolve() fields (mode_name, table), hero, outfit, nick}
static func ctx_from_entry(e: Dictionary) -> Dictionary:
	var p: = {"mode": int(e.mode), "gen": int(e.gen), "key": int(e.key), "tenths": int(e.author_t), "stars": int(e.author_stars)}
	var deal: = D.resolve(p)
	var gg: = U.g()
	var hero: = String(gg.S.get("level_partner", "mc")) if gg else "mc"
	return {"p": p, "deal": deal if deal.ok else {"mode_name": D.MODE_NAMES.get(int(e.mode), ""), "table": String(e.get("title", ""))},
		"hero": hero, "outfit": P._equipped(hero), "nick": U.my_nick()}


const VICTORY_MIN_UNLOCKED: = 16  # UX_RULES §3.5: «Вызов» in Victory «⋯» appears after level 15 (unlocked >= 16)


static func can_throw_from_victory(save_d: Dictionary = {}) -> bool:
	var s: Dictionary = save_d
	if s.is_empty():
		var gg: = U.g()
		if gg and gg.get("S") is Dictionary:
			s = gg.S
	return int(s.get("unlocked", 1)) >= VICTORY_MIN_UNLOCKED


# W4 hook for Victory «⋯» menu (V10HudVictory / play.gd): returns {} before L15 or on non-challengeable modes,
# else {id: "challenge", label: "Бросить вызов", action: Callable} opening ThrowSheet in 1 layer.
static func victory_more_item(play: Node, secs: float, stars: int, save_d: Dictionary = {}) -> Dictionary:
	if not can_throw_from_victory(save_d):
		return {}
	var run_s: Script = load("res://scripts/v10/duels/challenge/challenge_run.gd")
	var ctx: Dictionary = run_s.call("ctx_from_play", play, secs, stars) if run_s else {}
	if not bool(ctx.get("ok", false)):
		return {}
	return {
		"id": "challenge",
		"label": "Бросить вызов",
		"action": func(): open_throw(play, ctx),
	}


static func open_throw(host: Node, ctx: Dictionary) -> UI2.Sheet:
	var p: Dictionary = ctx.p
	var deal: Dictionary = ctx.get("deal", {})
	var code: = C.encode(p)
	var core: = C.core(p)
	if code == "":
		return null
	var inf: = P.info(p, deal, ctx)
	var s: = UI2.Sheet.open(host, "Бросить вызов")
	s.name = "ThrowSheet"
	var y: = 104.0
	# the poster preview: the poster is drawn in its own viewport and shown at 0.4 (its texts are not UI)
	var vp: = SubViewport.new()
	vp.name = "PosterVP"
	vp.size = Vector2i(P.SIZE)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(P.make(inf))
	s.body.add_child(vp)
	var prev: = TextureRect.new()
	prev.name = "PosterPreview"
	prev.texture = vp.get_texture()
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_SCALE
	prev.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev.position = Vector2(UI2.M, y)
	prev.size = P.SIZE * 0.4
	s.body.add_child(prev)
	var frame: = UI2.Plate.new(Color(0, 0, 0, 0))
	frame.position = prev.position
	frame.size = prev.size
	s.body.add_child(frame)
	var rx: = UI2.M + prev.size.x + 24.0
	var rw: = UI2.W - rx - UI2.M
	var l1: = UI2.text(String(inf.line), "display", 32, V10DS.PAPER_100, rw, 3)
	l1.position = Vector2(rx, y)
	s.body.add_child(l1)
	var l2: = UI2.text(String(inf.table), "ui", 22, V10DS.PAPER_300, rw, 2)
	l2.position = Vector2(rx, y + 132)
	s.body.add_child(l2)
	var l3: = UI2.text("Код вызова", "ui", 18, V10DS.PAPER_500, rw)
	l3.position = Vector2(rx, y + 216)
	s.body.add_child(l3)
	var l4: = UI2.text(code, "num", 22, V10DS.GOLD_300, rw)
	l4.name = "ThrowCode"
	l4.position = Vector2(rx, y + 244)
	s.body.add_child(l4)
	var l5: = UI2.text("Код сработает и без подписи: ник просто подскажет другу, чей это стол.", "ui", 18, V10DS.PAPER_500, rw, 4)
	l5.name = "ThrowNote"
	l5.position = Vector2(rx, y + 292)
	s.body.add_child(l5)
	var by: = y + prev.size.y + 32.0
	var note_at: = Vector2(UI2.M, by + 104 + 80 + 12)
	var recorded: = [false]
	var record: = func():
		if not recorded[0]:
			recorded[0] = true
			ST.record_sent(p, core, {"title": String(inf.table)})
			U.save_game()
	var b1: = UI2.btn("play", "Скопировать текст", Vector2(560, 104), func():
		U.clip_set(C.share_text(p, {"mode_name": inf.mode_name, "table": inf.table, "nick": inf.nick}))
		record.call()
		U.sfx("reward_pop")
		l5.text = "Текст с кодом скопирован. Отправь его другу в любом мессенджере."
		l5.label_settings = V10Type.settings("ui", 18, V10DS.JADE_300))
	b1.name = "Btn_Copy"
	b1.breathing = false
	b1.position = Vector2((UI2.W - 560) * 0.5, by)
	s.body.add_child(b1)
	var b2: = UI2.btn("secondary", "Сохранить в альбом", Vector2(560, 80), func(): pass)
	b2.name = "Btn_Save"
	b2.position = Vector2((UI2.W - 560) * 0.5, by + 104 + 8)
	s.body.add_child(b2)
	b2.pressed.connect(func():
		var img: Image = await P.render(inf, s)
		var path: = U.save_poster(img, core)
		if path == "":
			l5.text = "Постер не сохранился. Попробуй ещё раз."
			l5.label_settings = V10Type.settings("ui", 18, V10DS.EMBER)
			return
		record.call()
		s.set_meta("saved_path", path)
		l5.text = "Постер в альбоме, раздел «Снимки»."
		l5.label_settings = V10Type.settings("ui", 18, V10DS.JADE_300))
	s.set_meta("ctx", ctx)
	s.finish(by + 104 + 8 + 80 + 24)
	return s

# ---------------------------------------------------------------- painted pieces

class _Bg:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: = size.x
		var h: = size.y
		var a: = V10DS.NIGHT_800
		var b: = V10DS.NIGHT_900
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([a, a, b, b]))
		var f: = V10DS.FELT_HI
		for i in 9:
			draw_circle(Vector2(w * 0.5, h + 160), 260.0 + i * 52.0, Color(f, 0.045), true, -1.0, true)


class _Shade:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n: = V10DS.NIGHT_900
		var h: = size.y
		var c0: = Color(n, 0.0)
		var c1: = Color(n, 0.85)
		# the text column on the left, and the floor under the actions
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(430, 0), Vector2(430, h), Vector2(0, h)]), PackedColorArray([c1, c0, c0, c1]))
		draw_polygon(PackedVector2Array([Vector2(0, h - 520), Vector2(size.x, h - 520), Vector2(size.x, h), Vector2(0, h)]), PackedColorArray([c0, c0, Color(n, 0.96), Color(n, 0.96)]))


class _Row:
	extends Control
	signal tapped
	var accent: = Color(0, 0, 0, 0)
	var _down: = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		set_meta("ux_tap", true)

	func _draw() -> void:
		if _down:
			draw_rect(Rect2(Vector2.ZERO, size), Color(V10DS.NIGHT_600, 0.6))
		draw_rect(Rect2(16, size.y - 1, size.x - 32, 1), V10DS.hair())
		if accent.a > 0.0:
			draw_rect(Rect2(0, 16, 4, size.y - 32), accent)

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
			if e.pressed:
				_down = true
				queue_redraw()
			elif _down:
				_down = false
				queue_redraw()
				if Rect2(Vector2.ZERO, size).has_point(e.position):
					tapped.emit()
