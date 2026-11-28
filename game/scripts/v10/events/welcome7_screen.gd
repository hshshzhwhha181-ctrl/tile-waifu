class_name V10Welcome7Screen
extends Control

# Screen "v10welcome7" — «7 Дней · Подарок хозяйки» (0.13.0). 7 daily gifts, SSR outfit «Королева лунной ночи» on day 7.
# Save: G.S["v10_welcome7"] = {days_claimed, last_day_key, start_day_key}. One claim per calendar day (V10Meta.day_key).

const SAVE_KEY: = "v10_welcome7"
const DAYS: = 7
const SSR_ID: = "y_queen"
const SSR_FALLBACK_GEMS: = 1600
const SSR_ART: = "res://assets/outfits/yue_queen.webp"
const DRAGON_ART: = SSR_ART

const REWARDS: Array[Dictionary] = [
	{"day": 1, "title": "10 Билетов\nжеланий", "icon": "ticket", "tickets": 10},
	{"day": 2, "title": "2 000 монет\n+ 300 кристаллов", "icon": "coin_gem", "coins": 2000, "gems": 300},
	{"day": 3, "title": "Подарок «Шёлковый\nвеер» (+120 ♥)", "icon": "fan", "gift": "gift_silk_fan"},
	{"day": 4, "title": "500 кристаллов", "icon": "crystal", "gems": 500},
	{"day": 5, "title": "5 Билетов\nжеланий", "icon": "ticket", "tickets": 5},
	{"day": 6, "title": "Подарок «Нефритовая\nзаколка» (+300 ♥)", "icon": "pin", "gift": "gift_jade_pin"},
	{"day": 7, "title": "SSR-наряд\n«Королева лунной ночи»", "icon": "ssr", "outfit": "y_queen", "fallback_gems": 1600},
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
	if int(r.get("coins", 0)) > 0:
		V10Money.grant({"coins": int(r.coins)}, "welcome7")
		lines.append("+%d монет" % int(r.coins))
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
			lines.append("SSR-наряд «Королева лунной ночи»!")
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
	var safe_t: = _safe_top()
	var safe_b: = _safe_bot()
	_build_header(safe_t)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 96.0 + safe_t)
	_scroll.size = Vector2(W, H - (96.0 + safe_t) - (150.0 + safe_b))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_content = Control.new()
	_content.custom_minimum_size = Vector2(W, 1330)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_content)
	_btn_holder = Control.new()
	_btn_holder.position = Vector2(0, H - 140.0 - safe_b)
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


func _safe_top() -> float:
	if main != null and main.get("safe_top") != null:
		return maxf(0.0, float(main.safe_top) - position.y)
	return maxf(0.0, float(V10Layout.safe_insets(size).get("top", 0.0)) - position.y)


func _safe_bot() -> float:
	var vp_h: = get_viewport_rect().size.y if is_inside_tree() else H
	var extra: = maxf(0.0, vp_h - (position.y + size.y))
	if main != null and main.get("safe_bottom") != null:
		return maxf(0.0, float(main.safe_bottom) - extra)
	return maxf(0.0, float(V10Layout.safe_insets(size).get("bottom", 0.0)) - extra)


func _build_header(safe_t: float = 0.0) -> void:
	var back_b: = V10VipBoudoirScreen._pill(Rect2(16, 16 + safe_t, 64, 56), Color(0.13, 0.06, 0.19, 0.9), Color("#E8C47E"), 18)
	back_b.mouse_filter = Control.MOUSE_FILTER_STOP
	back_b.add_child(UI.center_label(UI.label("‹", 34, Color("#FFF4DE"), Color(0.06, 0.02, 0.1), 3, "body", 900), Rect2(0, -3, 64, 56)))
	back_b.gui_input.connect(func(e: InputEvent) -> void:
		if V10VipBoudoirScreen._is_tap(e):
			back_b.accept_event()
			V9Feel.press(back_b, "tap")
			_back())
	add_child(back_b)
	var t: = UI.center_label(UI.label("7 Дней · Подарок хозяйки", 32, Color("#FFE9A6"), Color(0.2, 0.03, 0.1), 6, "body", 900), Rect2(88, 20 + safe_t, W - 176, 48))
	add_child(t)


func _build_banner() -> void:
	var bn_rect: = Rect2(18, 4, W - 36, 360)
	var bn: = Panel.new()
	bn.position = bn_rect.position
	bn.size = bn_rect.size
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color("#24081A")
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	bn.add_theme_stylebox_override("panel", sb)
	bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(bn)
	var art_x: = maxf(256.0, bn.size.x * 0.39)
	var tex: Texture2D = V10VipBoudoirScreen._load_tex(SSR_ART)
	if tex != null:
		var art: = Common.card_art(tex, Rect2(art_x, 6, bn.size.x - art_x - 6.0, bn.size.y - 12.0), Vector2(0.5, 0.17), 1.0, 18.0)
		(art.material as ShaderMaterial).set_shader_parameter("bottom_shade", 0.14)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bn.add_child(art)
	var grad: = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.14, 0.44, 0.74, 1.0])
	grad.colors = PackedColorArray([
		Color("#24081A"),
		Color(0.141, 0.031, 0.102, 0.96),
		Color(0.141, 0.031, 0.102, 0.66),
		Color(0.141, 0.031, 0.102, 0.18),
		Color(0.141, 0.031, 0.102, 0.0),
	])
	var gtex: = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.0, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 8
	var shade: = TextureRect.new()
	shade.texture = gtex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.position = Vector2(art_x - 6.0, 3.0)
	shade.size = Vector2(minf(280.0, bn.size.x - art_x - 22.0), bn.size.y - 6.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bn.add_child(shade)
	var left_w: = minf(320.0, bn.size.x * 0.48)
	var badge: = V10VipBoudoirScreen._pill(Rect2(16, 16, 308, 66), Color(0.64, 0.10, 0.24, 0.98), Color("#FFE49C"), 18)
	bn.add_child(badge)
	var bl: = UI.center_label(UI.label("БЕСПЛАТНЫЙ SSR\nНА 7-Й ДЕНЬ", 21, Color("#FFF7E6"), Color(0.25, 0.03, 0.1), 4, "body", 900), Rect2(0, 0, 308, 66))
	bl.label_settings.line_spacing = -2.0
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(bl)
	var nm1: = Common.fit_line(UI.label("Юэ · Царица луны", 28, Color("#FFF3D6"), Color(0.1, 0.02, 0.08), 5, "body", 900), left_w, 20)
	nm1.position = Vector2(18, 92)
	nm1.size.y = 36
	bn.add_child(nm1)
	var nm2: = Common.fit_line(UI.label("«Королева лунной ночи»", 22, Color("#F8D686"), Color(0.1, 0.02, 0.08), 4, "body", 800), left_w, 16)
	nm2.position = Vector2(18, 128)
	nm2.size.y = 30
	bn.add_child(nm2)
	var shown: = days_claimed() if not can_claim_today() else days_claimed() + 1
	_day_lbl = Common.fit_line(UI.label("День %d из %d" % [clampi(shown, 1, DAYS), DAYS], 34, Color("#FFD36E"), Color(0.2, 0.03, 0.1), 6, "body", 900), left_w, 24)
	_day_lbl.position = Vector2(18, 168)
	_day_lbl.size.y = 44
	bn.add_child(_day_lbl)
	var dc: = days_claimed()
	for i in DAYS:
		var d: = Panel.new()
		d.position = Vector2(18 + i * 36, 224)
		d.size = Vector2(26, 26)
		var ds: = StyleBoxFlat.new()
		ds.bg_color = Color("#FFD36E") if i < dc else Color(0.2, 0.1, 0.2, 0.9)
		ds.border_color = Color("#FFE9A6")
		ds.set_border_width_all(2)
		ds.set_corner_radius_all(13)
		d.add_theme_stylebox_override("panel", ds)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bn.add_child(d)
	var sub: = UI.label("Заходи каждый день —\nнаграды сыплются сами", 18, Color("#F4D48A"), Color(0.08, 0.02, 0.12), 4, "body", 800)
	sub.label_settings.line_spacing = -1.0
	Common.fit_words(sub, left_w, 2, 15)
	sub.position = Vector2(18, 266)
	sub.size.y = 58
	bn.add_child(sub)
	var rim: = Panel.new()
	rim.position = bn_rect.position
	rim.size = bn_rect.size
	var rsb: = StyleBoxFlat.new()
	rsb.draw_center = false
	rsb.border_color = Color("#F6D484")
	rsb.set_border_width_all(3)
	rsb.set_corner_radius_all(28)
	rim.add_theme_stylebox_override("panel", rsb)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(rim)


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
		var gl: = _flat_panel(Rect2(Vector2.ZERO, r.size), Color(1.0, 0.8, 0.3, 0.16), 24)
		card.add_child(gl)
		_glow.append(gl)
	var dl: = UI.label("ДЕНЬ %d" % day, 22 if not grand else 28, Color("#FFD36E"), Color(0.1, 0.02, 0.08), 4, "body", 900)
	dl.position = Vector2(16, 10)
	dl.size = Vector2(150, 34)
	card.add_child(dl)
	var ic: = _make_reward_icon(str(rw.icon), grand)
	ic.position = Vector2(r.size.x - ic.size.x - 10.0, 8.0) if not grand else Vector2(r.size.x - ic.size.x - 18.0, (r.size.y - ic.size.y) * 0.5)
	card.add_child(ic)
	var tl: = UI.label(str(rw.title), 21 if not grand else 28, Color("#FFF6E4"), Color(0.08, 0.02, 0.1), 4, "body", 800)
	tl.position = Vector2(16, 102 if not grand else 70)
	var tw_max: = r.size.x - 32.0 if not grand else r.size.x - 196.0
	tl.size = Vector2(tw_max, 78 if not grand else 120)
	V10VipBoudoirScreen.wrap_size(tl, Vector2(tw_max, 78 if not grand else 120))
	card.add_child(tl)
	if grand:
		var tag: = Common.fit_line(UI.label("ИМПЕРАТОРСКИЙ SSR · бесплатно", 22, Color("#FF9EBE"), Color(0.1, 0.02, 0.08), 4, "body", 900), r.size.x - 196.0, 16)
		tag.position = Vector2(16, 196)
		tag.size.y = 34
		card.add_child(tag)
	if stt == "claimed":
		var dim: = _flat_panel(Rect2(Vector2.ZERO, r.size), Color(0.05, 0.02, 0.08, 0.55), 24)
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
			_do_claim()
		else:
			V9Feel.deny(b)
			if main != null and main.has_method("toast"):
				main.toast("Все 7 дней получены" if not is_active() else "Сегодняшний подарок уже получен — заходи завтра", "lock"))
	_btn_holder.add_child(b)
	if can:
		b.breathing = true


func _do_claim() -> void:
	var res: = claim_today()
	if not bool(res.get("ok", false)):
		return
	var day: = int(res.day)
	Sfx.play("reveal_ssr" if day == DAYS else "win", 1.0, -4.0)
	Sfx.say("yue" if day == DAYS else "mc", "ssr" if day == DAYS else "win")
	if day == DAYS:
		V10UltVideo.play(self, "yue", SSR_ID, "Затмение")
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


static func _flat_panel(r: Rect2, col: Color, rad: int) -> Panel:
	var p: = Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(rad)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _make_reward_icon(kind: String, grand: bool) -> Control:
	var box: = Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if grand:
		box.size = Vector2(152, 196)
		var aura: = Sprite2D.new()
		aura.texture = G.fx("glow")
		aura.material = Fx.add_mat()
		aura.position = Vector2(76, 86)
		aura.scale = Vector2.ONE * 2.25
		aura.modulate = Color(1.0, 0.84, 0.36, 0.62)
		box.add_child(aura)
		var pulse: = _flat_panel(Rect2(4, 14, 144, 144), Color(1.0, 0.84, 0.38, 0.22), 72)
		box.add_child(pulse)
		_glow.append(pulse)
		var med: = V10VipBoudoirScreen._pill(Rect2(12, 22, 128, 128), Color(0.42, 0.10, 0.20, 0.96), Color("#FFE49C"), 64)
		med.get_theme_stylebox("panel").set_border_width_all(3)
		box.add_child(med)
		box.add_child(V8Art.star_rect(true, Rect2(22, 30, 108, 108)))
		var badge: = V10VipBoudoirScreen._pill(Rect2(34, 138, 84, 30), Color(0.68, 0.10, 0.24, 0.98), Color("#FFE9A6"), 15)
		badge.add_child(UI.center_label(UI.label("SSR", 18, Color("#FFF7E4"), Color(0.22, 0.02, 0.08), 4, "body", 900), Rect2(0, -1, 84, 30)))
		box.add_child(badge)
		return box
	if kind == "coin_gem":
		box.size = Vector2(124, 88)
		var tg: = Sprite2D.new()
		tg.texture = G.fx("glow")
		tg.material = Fx.add_mat()
		tg.position = Vector2(62, 44)
		tg.scale = Vector2.ONE * 1.25
		tg.modulate = Color(1.0, 0.82, 0.44, 0.28)
		box.add_child(tg)
		box.add_child(V8Art.rect(V8Art.icon("visits"), Rect2(0, 4, 78, 78)))
		box.add_child(V8Art.rect(V8Art.cur("gem"), Rect2(60, 24, 60, 60)))
		return box
	box.size = Vector2(88, 88)
	var glow: = Sprite2D.new()
	glow.texture = G.fx("glow")
	glow.material = Fx.add_mat()
	glow.position = Vector2(44, 44)
	glow.scale = Vector2.ONE * 1.15
	match kind:
		"ticket":
			glow.modulate = Color(1.0, 0.80, 0.42, 0.28)
			box.add_child(glow)
			box.add_child(V8Art.rect(V8Art.cur("ticket"), Rect2(0, 0, 88, 88)))
		"crystal":
			glow.modulate = Color(1.0, 0.62, 0.84, 0.30)
			box.add_child(glow)
			box.add_child(V8Art.rect(V8Art.cur("gem"), Rect2(1, 1, 86, 86)))
		"fan", "pin":
			glow.modulate = Color(1.0, 0.68, 0.80, 0.30)
			box.add_child(glow)
			box.add_child(V8Art.rect(V8Art.icon("gift"), Rect2(3, 3, 82, 82)))
		_:
			glow.modulate = Color(1.0, 0.84, 0.38, 0.32)
			box.add_child(glow)
			box.add_child(V8Art.star_rect(true, Rect2(2, 2, 84, 84)))
	return box
