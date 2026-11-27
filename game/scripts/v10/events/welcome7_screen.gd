class_name V10Welcome7Screen
extends Control

# Screen "v10welcome7" — «7 Дней · Подарок хозяйки» (0.12.0). 7 daily gifts, SSR outfit on day 7.
# Save: G.S["v10_welcome7"] = {days_claimed, last_day_key, start_day_key}. One claim per calendar day (V10Meta.day_key).

const SAVE_KEY: = "v10_welcome7"
const DAYS: = 7
const SSR_ID: = "o_dragon"
const SSR_FALLBACK_GEMS: = 1600
const DRAGON_ART: = "res://assets/outfits/mc_dragon.webp"

const REWARDS: Array[Dictionary] = [
	{"day": 1, "title": "10 Билетов\nжеланий", "icon": "ticket", "tickets": 10},
	{"day": 2, "title": "200 Чашек чая\n+ 300 кристаллов", "icon": "tea", "tea": 200, "gems": 300},
	{"day": 3, "title": "Подарок «Шёлковый\nвеер» (+120 ♥)", "icon": "fan", "gift": "gift_silk_fan"},
	{"day": 4, "title": "500 кристаллов", "icon": "crystal", "gems": 500},
	{"day": 5, "title": "5 Билетов\nжеланий", "icon": "ticket", "tickets": 5},
	{"day": 6, "title": "Подарок «Нефритовая\nзаколка» (+300 ♥)", "icon": "pin", "gift": "gift_jade_pin"},
	{"day": 7, "title": "SSR-наряд\n«Императрица дракона»", "icon": "ssr", "outfit": "o_dragon", "fallback_gems": 1600},
]

var main
var W: = 720.0
var H: = 1280.0
var _t: = 0.0
var _scroll: ScrollContainer
var _content: Control
var _cards: Dictionary = {}
var _day_lbl: Label
var _dots: Control
var _btn_holder: Control
var _fx: Control
var _glow: Array = []


# ── logic (static, testable) ─────────────────────────────────────────────────────────────────────────────────────

static func state() -> Dictionary:
	var root: Dictionary = G.S
	if not (root.get(SAVE_KEY) is Dictionary):
		root[SAVE_KEY] = {}
	var st: Dictionary = root[SAVE_KEY]
	st["days_claimed"] = clampi(int(st.get("days_claimed", 0)), 0, DAYS)
	st["last_day_key"] = str(st.get("last_day_key", ""))
	st["start_day_key"] = str(st.get("start_day_key", ""))
	return st


static func ensure_started() -> void:
	var st: = state()
	if str(st.start_day_key) == "":
		st["start_day_key"] = V10Meta.day_key()


static func days_claimed() -> int:
	return int(state().days_claimed)


static func is_active() -> bool:
	return days_claimed() < DAYS


static func can_claim_today() -> bool:
	var st: = state()
	return int(st.days_claimed) < DAYS and str(st.last_day_key) != V10Meta.day_key()


static func next_day() -> int:
	return mini(DAYS, days_claimed() + 1)


static func reward_for(day: int) -> Dictionary:
	return REWARDS[clampi(day, 1, DAYS) - 1]


static func claim_today() -> Dictionary:
	if not can_claim_today():
		return {"ok": false, "reason": "claimed" if is_active() else "done"}
	var st: = state()
	ensure_started()
	var day: = int(st.days_claimed) + 1
	var r: Dictionary = reward_for(day)
	var lines: Array = []
	var converted: = false
	if int(r.get("tickets", 0)) > 0:
		V10Money.grant({"tickets": int(r.tickets)}, "welcome7")
		lines.append("+%d Билетов желаний" % int(r.tickets))
	if int(r.get("gems", 0)) > 0:
		V10Money.grant({"gems": int(r.gems)}, "welcome7")
		lines.append("+%d кристаллов" % int(r.gems))
	if int(r.get("tea", 0)) > 0:
		V10Stamina.grant(int(r.tea))
		lines.append("+%d Чашек чая" % int(r.tea))
	if str(r.get("gift", "")) != "":
		V10AffCurve.grant_gift(str(r.gift), 1)
		lines.append("Подарок «%s»" % str(V10AffCurve.gift_def(str(r.gift)).get("name", r.gift)))
	if str(r.get("outfit", "")) != "":
		if G.owns(str(r.outfit)):
			converted = true
			V10Money.grant({"gems": int(r.fallback_gems)}, "welcome7")
			lines.append("Наряд уже есть: +%d кристаллов" % int(r.fallback_gems))
		else:
			G.give_new(str(r.outfit))
			lines.append("SSR-наряд «Императрица дракона»!")
	st["days_claimed"] = day
	st["last_day_key"] = V10Meta.day_key()
	G.save()
	return {"ok": true, "day": day, "lines": lines, "converted": converted}


# ── UI ───────────────────────────────────────────────────────────────────────────────────────────────────────────

func build(m, _args: Dictionary) -> void:
	main = m
	W = size.x
	H = size.y
	if main != null and main.has_method("show_chrome"):
		main.show_chrome(false, false)
	Sfx.music("menu")
	ensure_started()
	var br: = V10Layout.bleed_rect(self)
	var base: = ColorRect.new()
	base.color = Color("#150711")
	base.position = br.position
	base.size = br.size
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	Common.vignette(self, size, Color(0.30, 0.04, 0.10), 0.5).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Fx.ambient(self, "petals", size)
	_build_header()
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 96)
	_scroll.size = Vector2(W, H - 96 - 150)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_content = Control.new()
	_content.custom_minimum_size = Vector2(W, 1330)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_content)
	_btn_holder = Control.new()
	_btn_holder.position = Vector2(0, H - 140)
	_btn_holder.size = Vector2(W, 130)
	add_child(_btn_holder)
	_fx = Control.new()
	_fx.size = size
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.z_index = 60
	add_child(_fx)
	set_meta("v8_back", _back)
	_refresh()


func _process(dt: float) -> void:
	_t += dt
	for g in _glow:
		if is_instance_valid(g):
			(g as Control).modulate.a = 0.55 + 0.45 * sin(_t * 3.2)


func _refresh() -> void:
	for c in _content.get_children():
		c.queue_free()
	_cards.clear()
	_glow.clear()
	_build_banner()
	_build_cards()
	_build_button()
	_scroll.scroll_vertical = 0


func _build_header() -> void:
	var back_b: = V10VipBoudoirScreen._pill(Rect2(16, 18, 56, 52), Color(0.13, 0.06, 0.19, 0.9), Color("#E8C47E"), 16)
	back_b.mouse_filter = Control.MOUSE_FILTER_STOP
	back_b.add_child(UI.center_label(UI.label("‹", 32, Color("#FFF4DE"), Color(0.06, 0.02, 0.1), 3, "body", 900), Rect2(0, -3, 56, 52)))
	back_b.gui_input.connect(func(e: InputEvent) -> void:
		if V10VipBoudoirScreen._is_tap(e):
			back_b.accept_event()
			_back())
	add_child(back_b)
	var t: = UI.center_label(UI.label("7 Дней · Подарок хозяйки", 32, Color("#FFE9A6"), Color(0.2, 0.03, 0.1), 6, "body", 900), Rect2(80, 22, W - 160, 48))
	add_child(t)


func _build_banner() -> void:
	var bn: = Panel.new()
	bn.position = Vector2(18, 4)
	bn.size = Vector2(W - 36, 360)
	bn.clip_contents = true
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color("#2A0B1E")
	sb.border_color = Color("#F6D484")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(28)
	bn.add_theme_stylebox_override("panel", sb)
	bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(bn)
	var tex: Texture2D = V10VipBoudoirScreen._load_tex(DRAGON_ART)
	if tex != null:
		var tr: = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.position = Vector2(bn.size.x * 0.46, -10)
		tr.size = Vector2(bn.size.x * 0.54, bn.size.y + 20)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bn.add_child(tr)
	var shade: = ColorRect.new()
	shade.color = Color(0.1, 0.02, 0.07, 0.55)
	shade.size = Vector2(bn.size.x * 0.48, bn.size.y)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bn.add_child(shade)
	var badge: = V10VipBoudoirScreen._pill(Rect2(16, 18, 330, 74), Color(0.62, 0.1, 0.24, 0.98), Color("#FFE49C"), 20)
	bn.add_child(badge)
	var bl: = UI.center_label(UI.label("БЕСПЛАТНЫЙ SSR\nНА 7-Й ДЕНЬ", 25, Color("#FFF7E6"), Color(0.25, 0.03, 0.1), 4, "body", 900), Rect2(0, 0, 330, 74))
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(bl)
	var nm: = UI.label("Маджонг-тян\n«Императрица дракона»", 28, Color("#FFF1CF"), Color(0.1, 0.02, 0.08), 5, "body", 900)
	nm.position = Vector2(20, 112)
	nm.size = Vector2(bn.size.x * 0.5, 80)
	bn.add_child(nm)
	var shown: = days_claimed() if not can_claim_today() else days_claimed() + 1
	_day_lbl = UI.label("День %d из %d" % [clampi(shown, 1, DAYS), DAYS], 36, Color("#FFD36E"), Color(0.2, 0.03, 0.1), 6, "body", 900)
	_day_lbl.position = Vector2(20, 214)
	_day_lbl.size = Vector2(bn.size.x * 0.5, 48)
	bn.add_child(_day_lbl)
	var dc: = days_claimed()
	for i in DAYS:
		var d: = Panel.new()
		d.position = Vector2(24 + i * 36, 282)
		d.size = Vector2(26, 26)
		var ds: = StyleBoxFlat.new()
		ds.bg_color = Color("#FFD36E") if i < dc else Color(0.2, 0.1, 0.2, 0.9)
		ds.border_color = Color("#FFE9A6")
		ds.set_border_width_all(2)
		ds.set_corner_radius_all(13)
		d.add_theme_stylebox_override("panel", ds)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bn.add_child(d)
	var sub: = UI.label("Заходи каждый день — награды сыплются сами", 17, Color("#F4D48A"), Color(0.08, 0.02, 0.12), 3, "body", 700)
	sub.position = Vector2(20, 322)
	sub.size = Vector2(bn.size.x - 40, 26)
	bn.add_child(sub)


func _build_cards() -> void:
	var cw: = (W - 36.0 - 12.0) / 2.0
	for i in 6:
		var r: = Rect2(18.0 + float(i % 2) * (cw + 12.0), 380.0 + float(i / 2) * 202.0, cw, 190)
		_make_card(i + 1, r)
	_make_card(7, Rect2(18, 380.0 + 3.0 * 202.0, W - 36.0, 250))


func _day_state(day: int) -> String:
	var dc: = days_claimed()
	if day <= dc:
		return "claimed"
	if day == dc + 1 and can_claim_today():
		return "today"
	return "locked"


func _make_card(day: int, r: Rect2) -> void:
	var rw: Dictionary = reward_for(day)
	var stt: = _day_state(day)
	var grand: = day == DAYS
	var bg: = Color(0.36, 0.1, 0.2, 0.96) if grand else Color(0.2, 0.08, 0.17, 0.95)
	var bd: = Color("#FFD36E") if stt != "locked" or grand else Color("#9B7A4B")
	var card: = V10VipBoudoirScreen._pill(r, bg, bd, 24)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.get_theme_stylebox("panel").set_border_width_all(4 if stt == "today" or grand else 2)
	_content.add_child(card)
	_cards[day] = card
	if stt == "today":
		var gl: = ColorRect.new()
		gl.color = Color(1.0, 0.8, 0.3, 0.16)
		gl.size = r.size
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(gl)
		_glow.append(gl)
	var dl: = UI.label("ДЕНЬ %d" % day, 22 if not grand else 28, Color("#FFD36E"), Color(0.1, 0.02, 0.08), 4, "body", 900)
	dl.position = Vector2(16, 10)
	dl.size = Vector2(150, 34)
	card.add_child(dl)
	var ic: = _Icon.new()
	ic.kind = str(rw.icon)
	ic.size = Vector2(80, 80) if not grand else Vector2(130, 130)
	ic.position = Vector2(r.size.x - ic.size.x - 14, 14) if not grand else Vector2(r.size.x - 150, 20)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(ic)
	var tl: = UI.label(str(rw.title), 21 if not grand else 30, Color("#FFF6E4"), Color(0.08, 0.02, 0.1), 4, "body", 800)
	tl.position = Vector2(16, 100 if not grand else 70)
	tl.size = Vector2(r.size.x - 32 if not grand else r.size.x - 180, 80 if not grand else 120)
	V10VipBoudoirScreen.wrap_size(tl, Vector2(r.size.x - 32 if not grand else r.size.x - 180, 80 if not grand else 120))
	card.add_child(tl)
	if grand:
		var tag: = UI.label("GRAND SSR · бесплатно", 22, Color("#FF9EBE"), Color(0.1, 0.02, 0.08), 4, "body", 900)
		tag.position = Vector2(16, 196)
		tag.size = Vector2(r.size.x - 32, 34)
		card.add_child(tag)
	if stt == "claimed":
		var dim: = ColorRect.new()
		dim.color = Color(0.05, 0.02, 0.08, 0.55)
		dim.size = r.size
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(dim)
		var seal: = V10VipBoudoirScreen._pill(Rect2(r.size.x * 0.5 - 90, r.size.y * 0.5 - 28, 180, 56), Color(0.7, 0.08, 0.16, 0.92), Color("#FFE9A6"), 12)
		seal.name = "Seal"
		seal.pivot_offset = Vector2(90, 28)
		seal.rotation = -0.18
		seal.add_child(UI.center_label(UI.label("Получено ✓", 25, Color("#FFF6E6"), Color(0.2, 0.0, 0.05), 3, "body", 900), Rect2(0, 0, 180, 56)))
		card.add_child(seal)
	card.gui_input.connect(func(e: InputEvent) -> void:
		if V10VipBoudoirScreen._is_tap(e) and _day_state(day) == "today":
			card.accept_event()
			_do_claim())


func _build_button() -> void:
	for c in _btn_holder.get_children():
		c.queue_free()
	var can: = can_claim_today()
	var txt: = "Забрать День %d" % next_day() if can else ("Все 7 дней получены ✓" if not is_active() else "Завтра — День %d" % next_day())
	var b: = V10Button.make("play", txt, Vector2(600, 100))
	b.position = Vector2((W - 600.0) * 0.5, 14)
	b.modulate = Color.WHITE if can else Color(0.7, 0.7, 0.75, 0.9)
	b.pressed.connect(func() -> void:
		if can_claim_today():
			_do_claim())
	_btn_holder.add_child(b)
	if can:
		b.breathing = true


func _do_claim() -> void:
	var res: = claim_today()
	if not bool(res.get("ok", false)):
		return
	var day: = int(res.day)
	Sfx.play("reveal_ssr" if day == DAYS else "win", 1.0, -4.0)
	Sfx.say("mc", "ssr" if day == DAYS else "win")
	if main != null and main.has_method("refresh_currency"):
		main.refresh_currency(true)
	_refresh()
	var card: Control = _cards.get(day)
	var center: = Vector2(W * 0.5, H * 0.5)
	if card != null:
		center = card.global_position + card.size * 0.5 - global_position + Vector2(0, -float(_scroll.scroll_vertical) * 0.0)
		var seal: Control = card.get_node_or_null("Seal")
		if seal != null:
			seal.scale = Vector2(2.6, 2.6)
			seal.modulate.a = 0.0
			var tw: = create_tween().set_parallel(true)
			tw.tween_property(seal, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(seal, "modulate:a", 1.0, 0.18)
	Fx.burst(_fx, center, "sparkle", 40 if day == DAYS else 24)
	Fx.burst(_fx, center, "heart", 14)
	if day == DAYS:
		Fx.flash_glow(_fx, Vector2(W * 0.5, H * 0.4), Color(1, 0.85, 0.5), 4.0, 0.7)
	if main != null and main.has_method("toast"):
		main.toast(" · ".join(PackedStringArray(res.lines)), "star")


func _back() -> void:
	if main != null and main.has_method("back"):
		main.back()


class _Icon extends Control:
	var kind: = "crystal"

	func _draw() -> void:
		var c: = size * 0.5
		var s: = minf(size.x, size.y) * 0.5
		var gold: = Color("#FFD36E")
		var line: = Color("#FFF2C0")
		match kind:
			"crystal":
				var pts: = PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, -s * 0.2), c + Vector2(0, s), c + Vector2(-s * 0.8, -s * 0.2)])
				draw_colored_polygon(pts, Color("#FF6FA8"))
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), line, 3.0)
				draw_line(c + Vector2(-s * 0.8, -s * 0.2), c + Vector2(s * 0.8, -s * 0.2), line, 2.0)
			"ticket":
				var r: = Rect2(c - Vector2(s, s * 0.6), Vector2(s * 2, s * 1.2))
				draw_rect(r, Color("#E24A6E"))
				draw_rect(r, line, false, 3.0)
				draw_circle(Vector2(r.position.x, c.y), s * 0.18, Color("#150711"))
				draw_circle(Vector2(r.end.x, c.y), s * 0.18, Color("#150711"))
				draw_string(ThemeDB.fallback_font, Vector2(c.x - s * 0.3, c.y + s * 0.22), "♥", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.7), gold)
			"tea":
				draw_circle(c + Vector2(0, s * 0.1), s * 0.7, Color("#F4EAD8"))
				draw_circle(c + Vector2(0, s * 0.05), s * 0.52, Color("#7FBF6A"))
				draw_arc(c + Vector2(s * 0.75, 0), s * 0.28, -1.4, 1.4, 12, gold, 4.0)
			"fan":
				for i in 7:
					var a: = -2.5 + float(i) * 0.33
					draw_line(c + Vector2(0, s * 0.8), c + Vector2(cos(a), sin(a)) * s * 1.05 + Vector2(0, s * 0.8), Color("#FF8FB8") if i % 2 == 0 else gold, 9.0)
			"pin":
				draw_line(c + Vector2(-s * 0.8, s * 0.8), c + Vector2(s * 0.6, -s * 0.6), Color("#7FE0B8"), 8.0)
				draw_circle(c + Vector2(s * 0.7, -s * 0.7), s * 0.28, Color("#3FD09A"))
				draw_arc(c + Vector2(s * 0.7, -s * 0.7), s * 0.28, 0, TAU, 16, line, 2.5)
			_:
				var pts2: = PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.28, -s * 0.3), c + Vector2(s, -s * 0.2), c + Vector2(s * 0.45, s * 0.25), c + Vector2(s * 0.6, s), c + Vector2(0, s * 0.55), c + Vector2(-s * 0.6, s), c + Vector2(-s * 0.45, s * 0.25), c + Vector2(-s, -s * 0.2), c + Vector2(-s * 0.28, -s * 0.3)])
				draw_colored_polygon(pts2, gold)
				draw_polyline(pts2, line, 3.0)
				draw_string(ThemeDB.fallback_font, Vector2(c.x - s * 0.55, c.y + s * 0.2), "SSR", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.55), Color("#8A1030"))
