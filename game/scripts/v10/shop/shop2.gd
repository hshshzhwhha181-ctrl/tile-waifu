class_name V10Shop2
extends Control

# V10Shop2 — «Лавка» 2 (spec 0.10 Л6 + UX_RULES §3.2/§5/§9-7 + HUD_V2 §8.5, mockup docs/concepts/hud_v2/06_shop).
# Replaces main.SCREENS["shop"] at integration (see README). Built in code, any aspect: one 720-wide column centred
# on tablets, vertical scroll inside each segment, header/segments fixed, safe insets respected.
#
#   Header   H1 «Лавка» + Caption «Ты точно знаешь, что получишь» · right: ≤ 2 currencies (info only)
#   Segments Витрина · Наряды · Пополнить (UX §4.2: «Пополнить», not «Камни»)
#   Витрина  «Подарок дня» (the screen's only rose button) · carousel of ≤ 3 paid offers (ladder step with the next
#            step as a silhouette, month card, season pass), swipe + dots, no autoplay · one featured outfit, art large
#   Наряды   «за кристаллы / за лепестки» (second appears after the first petal) · 3:4 cards with a 12 bevel ·
#            «В рейтинге наряды не дают силы»
#   Пополнить  the one-sentence currency rule (UX §5.1) · 6 packs, «= N желаний · ≈ N ₽ за желание», «самый низкий ₽ за
#            желание» on exactly one row (the true best) · first purchase shown as an explicit sum
#   Footer   Мои покупки · Восстановить покупки · Шансы и правила (inside the scroll, at the end)
# Store build without a provider: no ₽ anywhere (С-2, Ф7).

signal go_screen(id: String, args: Dictionary)   # "pass", "purchases", "odds", "back"

const TABS: = ["Витрина", "Наряды", "Пополнить"]
const M: = 24.0

var m: V10ShopModel
var tab: = 0
var outfit_mode: = "crystal"
var bottom_reserve: = 120.0
var col_x: = 0.0
var col_w: = 672.0
var vs: = Vector2(720, 1280)
var top_y: = 0.0

var seg: V10ShopW.Seg
var scroll: ScrollContainer
var content: Control
var strip: Control
var carousel: Carousel
var _cur_lbls: = {}


static func make(model: V10ShopModel, opts: = {}) -> V10Shop2:
	var s: = V10Shop2.new()
	s.m = model
	s.tab = int(opts.get("tab", 0))
	s.bottom_reserve = float(opts.get("bottom_reserve", 120.0))
	s.name = "V10Shop2"
	return s


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("v8_back", func(): go_screen.emit("back", {}))
	get_viewport().size_changed.connect(_rebuild_all)
	m.changed.connect(_on_model)
	m.econ.shop.reconcile()
	V10Hud2Util.music("play_tab", ["shop"])
	_rebuild_all()


func _on_model() -> void:
	_update_strip()


func _rebuild_all() -> void:
	for c in get_children():
		if c is V10ShopSheet:
			continue
		c.queue_free()
	vs = get_viewport_rect().size
	size = vs
	var ins: = V10Hud2Util.safe_insets(vs)
	col_w = minf(vs.x, 720.0) - M * 2.0
	col_x = (vs.x - col_w) * 0.5
	top_y = float(ins.top)
	# backdrop: the night shop, toned down to night.900 below the header (70/20/10 area rule)
	var bg: = V10ShopKit.tex("bg_shop")
	if bg:
		var b: = V10ShopKit.art(bg, Rect2(Vector2.ZERO, vs), true)
		b.name = "Backdrop"
		add_child(b)
	var shade: = Shade.new()
	shade.size = vs
	add_child(shade)
	# header
	var h1: = V10ShopKit.lbl("Лавка", "display", 44, V10DS.PAPER_100, true)
	h1.position = Vector2(col_x, top_y + 20)
	h1.size = Vector2(260, 56)
	h1.name = "H1"
	add_child(h1)
	var cap: = V10ShopKit.lbl("Ты точно знаешь, что получишь", "ui", 18, V10DS.PAPER_300, true)
	cap.position = Vector2(col_x, top_y + 76)
	cap.size = Vector2(col_w * 0.6, 26)
	add_child(cap)
	strip = Control.new()
	strip.name = "Strip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	_build_strip()
	seg = V10ShopW.Seg.new().setup(TABS, tab, col_w)
	seg.position = Vector2(col_x, top_y + 116)
	seg.name = "Segments"
	seg.changed.connect(_set_tab)
	add_child(seg)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.position = Vector2(0, top_y + 188)
	scroll.size = Vector2(vs.x, vs.y - (top_y + 188) - bottom_reserve - float(ins.bottom))
	scroll.clip_contents = true
	add_child(scroll)
	_build_tab()


func _set_tab(i: int) -> void:
	tab = i
	_build_strip()
	_build_tab()


func go_topup() -> void:
	seg.select(2)
	_set_tab(2)


func refresh() -> void:
	_build_strip()
	var keep: = scroll.scroll_vertical if is_instance_valid(scroll) else 0
	_build_tab()
	if is_instance_valid(scroll):
		scroll.set_deferred("scroll_vertical", keep)


# ---------------------------------------------------------------- currencies (≤ 2 on screen, info only)
func _strip_curs() -> Array:
	if tab == 1 and outfit_mode == "petal":
		return ["petal", "crystal"]
	return ["crystal", "moon"]


func _build_strip() -> void:
	for c in strip.get_children():
		c.queue_free()
	_cur_lbls = {}
	var x: = col_x + col_w
	var curs: = _strip_curs()
	curs.reverse()
	for cur in curs:
		var w: = 148.0
		x -= w
		var p: = V10ShopW.Lac.new()
		p.position = Vector2(x, top_y + 28)
		p.size = Vector2(w, 48)
		p.name = "Cur_" + cur
		strip.add_child(p)
		var t: = V10ShopKit.tex({"crystal": "item_crystal", "moon": "moon_1", "petal": "item_petal"}[cur])
		if t:
			p.add_child(V10ShopKit.art(t, Rect2(6, 6, 36, 36)))
		var l: = V10ShopKit.lbl(V10ShopTxt.num(m.bal(cur)), "num", 22, V10DS.PAPER_100)
		l.position = Vector2(48, 0)
		l.size = Vector2(w - 56, 48)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p.add_child(l)
		_cur_lbls[cur] = l
		x -= 8


func _update_strip() -> void:
	for cur in _cur_lbls:
		if is_instance_valid(_cur_lbls[cur]):
			(_cur_lbls[cur] as Label).text = V10ShopTxt.num(m.bal(cur))


func currency_target(cur: String) -> Vector2:
	var n: = strip.get_node_or_null("Cur_" + cur) if is_instance_valid(strip) else null
	if n:
		return (n as Control).position + Vector2(24, 24)
	return Vector2(vs.x - 100, top_y + 52)


# ---------------------------------------------------------------- tabs
func _build_tab() -> void:
	if is_instance_valid(content):
		content.queue_free()
	content = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(content)
	var y: = 0.0
	var first: = []
	match tab:
		0:
			y = _vitrina(first)
		1:
			y = _outfits(first)
		2:
			y = _topup(first)
	y = _footer(y + 24)
	content.custom_minimum_size = Vector2(vs.x, y + 24)
	content.size = content.custom_minimum_size
	V10ShopKit.inhale(first.slice(0, 5))


# ---- Витрина
func _vitrina(first: Array) -> float:
	var y: = 0.0
	var gift: = _gift_plate(y)
	first.append(gift)
	y += 104 + 16
	var cards: = m.vitrina()
	if not cards.is_empty():
		carousel = Carousel.new()
		carousel.name = "Carousel"
		carousel.position = Vector2(col_x, y)
		carousel.size = Vector2(col_w, 324)
		content.add_child(carousel)
		for c in cards:
			carousel.add_card(_offer_card(c))
		carousel.finish()
		first.append(carousel)
		y += 324 + 8
	var fo: = m.outfits("crystal")
	var pick: = {}
	for it in fo:
		if not bool(it.owned):
			pick = it
			break
	if not pick.is_empty():
		var room: = scroll.size.y - y - 128.0 - 16.0 - 104.0
		var oc: = _featured(pick, y, clampf(room, 420.0, 640.0))
		first.append(oc)
		y += oc.size.y + 16
	return y


func _gift_plate(y: float) -> Control:
	var p: = V10ShopW.Lac.new()
	p.name = "Gift"
	p.position = Vector2(col_x, y)
	p.size = Vector2(col_w, 104)
	content.add_child(p)
	var t: = V10ShopKit.tex("item_gift")
	if t:
		p.add_child(V10ShopKit.art(t, Rect2(12, 12, 80, 80)))
	var ready: = m.gift_ready()
	var tl: = V10ShopKit.lbl("Подарок дня", "display", 28, V10DS.PAPER_100 if ready else V10DS.PAPER_500)
	tl.position = Vector2(108, 14)
	tl.size = Vector2(260, 40)
	p.add_child(tl)
	var amount: = V10ShopTxt.amount("crystal", int(V10ShopData.GIFT_DAILY.crystal))
	var sub: = "+" + amount if ready else "Завтра — новый"
	var month: = m.econ.shop.ad_free()
	var ad: = m.ads.can("gift")
	if ready and bool(ad.ok) and not month:
		sub += " · ×2 за ролик"
	var sl: = V10ShopKit.lbl(sub, "ui", 18, V10DS.PAPER_300)
	sl.position = Vector2(108, 56)
	sl.size = Vector2(col_w - 108 - 300, 28)
	p.add_child(sl)
	if not ready:
		return p
	var bx: = col_w - 16
	var tw_: = 232.0 if month and bool(ad.ok) else 176.0
	var take: = V10Button.make("play", "Забрать ×2" if month and bool(ad.ok) else "Забрать", Vector2(tw_, 64))
	take.name = "GiftTake"
	take.sheen = false        # the screen keeps ONE sheen (the carousel card); the pill only breathes
	bx -= tw_
	take.position = Vector2(bx, 20)
	take.set_meta("ux_role", "primary")
	var from_x2: = month and bool(ad.ok)
	take.pressed.connect(func():
		V10ShopKit.press(take, true)
		_claim_gift(from_x2, take))
	p.add_child(take)
	if bool(ad.ok) and not month:
		var x2: = V10Button.make("secondary", "×2", Vector2(96, 64))
		x2.name = "GiftX2"
		bx -= 104
		x2.position = Vector2(bx, 20)
		x2.set_meta("ux_role", "secondary")
		x2.pressed.connect(func():
			V10ShopKit.press(x2)
			_claim_gift(true, x2))
		p.add_child(x2)
	return p


func _claim_gift(x2: bool, from: Control) -> void:
	var src: = from.get_global_rect().get_center() - get_global_rect().position
	m.ads_stub.host = self
	m.gift_claim(x2, func(g: Dictionary):
		if g.is_empty() or not is_inside_tree():
			return
		V10ShopKit.fly(self, src, currency_target("crystal"), V10ShopKit.tex("item_crystal"), 5)
		V10ShopKit.toast(self, "Зачислено: %s · баланс %s" % [V10ShopTxt.amount("crystal", int(g.crystal)), V10ShopTxt.num(m.bal("crystal"))])
		refresh())


func _offer_card(c: Dictionary) -> Control:
	var w: = col_w
	var card: = V10ShopW.Lac.new()
	card.bevel = 12.0
	card.size = Vector2(w, 300)
	card.name = "Offer_" + String(c.id)
	card.set_meta("rub_card", c)
	var t: = V10ShopKit.tex(String(c.art))
	if t:
		card.add_child(V10ShopKit.art(t, Rect2(16, 20, 208, 208)))
	var x: = 240.0
	var cw: = w - x - 16
	var ov: = V10ShopKit.lbl(String(c.overline), "overline", 15, V10DS.GOLD_500)
	ov.position = Vector2(x, 22)
	ov.size = Vector2(cw, 20)
	card.add_child(ov)
	var tl: = V10ShopKit.lbl("", "ui_strong", 22, V10DS.PAPER_100)
	V10Type.fit(tl, String(c.title), "text_l", cw, 2, V10DS.PAPER_100)
	tl.position = Vector2(x, 46)
	tl.size = Vector2(cw, 64)
	card.add_child(tl)
	var lines: Array = (c.lines as Array).duplicate()
	if String(c.kind) == "month":
		var dl: = m.econ.shop.month_days_left()
		if dl > 0:
			lines = ["Активен ещё %d %s" % [dl, V10ShopTxt.plural(dl, "день", "дня", "дней")], "+%s — в утреннем подносе" % V10ShopTxt.amount("crystal", int(V10Catalog.MONTH_DAILY.crystal))]
			if dl <= 3:
				lines[0] = "Абонемент до " + V10ShopTxt.date_short(m.now() + (dl - 1) * 86400)
	var ly: = 114.0
	for i in mini(lines.size(), 2):
		var l: = V10ShopKit.lbl(String(lines[i]), "ui", 18, V10DS.PAPER_300)
		l.position = Vector2(x, ly)
		l.size = Vector2(cw, 26)
		card.add_child(l)
		ly += 28
	var pw: = V10ShopKit.lbl(String(c.per_wish), "ui", 18, V10DS.PAPER_500)
	pw.name = "PerWish"
	pw.position = Vector2(x, 176)
	pw.size = Vector2(cw, 26)
	card.add_child(pw)
	if String(c.kind) == "pass":
		var open: = V10Button.make("secondary", "Смотреть", Vector2(200, 64))
		open.position = Vector2(w - 16 - 200, 220)
		open.set_meta("ux_role", "secondary")
		open.pressed.connect(func():
			V10ShopKit.press(open)
			go_screen.emit("pass", {}))
		card.add_child(open)
	else:
		var ext: = String(c.kind) == "month" and m.econ.shop.month_days_left() > 0
		var cwid: = 264.0 if ext else 200.0
		var cash: = V10ShopW.Cash.new().setup(String(c.price), "Продлить" if ext else "", Vector2(cwid, 64))
		cash.name = "Cash"
		cash.position = Vector2(w - 16 - cwid, 220)
		cash.enabled = bool(c.available)
		cash._lay()
		var id: = String(c.id)
		cash.pressed.connect(func(): V10ShopFlow.confirm(self, m, id))
		card.add_child(cash)
		if not bool(c.available):
			pw.text = String(c.reason_txt)
	# ladder: the next step as a silhouette (UX §6.4: closed = paper.700 + «Откроется: …»)
	if String(c.kind) == "starter":
		var nx: Dictionary = m.ladder().next
		if not nx.is_empty():
			var nl: = V10ShopKit.lbl("Дальше: " + String(nx.title), "ui", 18, V10DS.PAPER_700)
			nl.position = Vector2(16, 236)
			nl.size = Vector2(w - 16 - 200 - 32, 26)
			card.add_child(nl)
			var ul: = V10ShopKit.lbl(String(nx.unlock), "ui", 18, V10DS.PAPER_700)
			ul.position = Vector2(16, 262)
			ul.size = Vector2(w - 16 - 200 - 32, 26)
			card.add_child(ul)
	return card


func _featured(it: Dictionary, y: float, art_h: = 420.0) -> Control:
	var box: = Control.new()
	box.name = "Featured"
	box.position = Vector2(col_x, y)
	box.size = Vector2(col_w, art_h + 128)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(box)
	var t: = V10ShopKit.outfit_tex(String(it.img))
	if t:
		box.add_child(_top_crop(t, Rect2(0, 0, col_w, art_h)))
	var fade: = Fade.new()
	fade.position = Vector2(0, art_h - 120)
	fade.size = Vector2(col_w, 120)
	box.add_child(fade)
	var p: = V10ShopW.Lac.new()
	p.over_art = false
	p.position = Vector2(0, art_h)
	p.size = Vector2(col_w, 128)
	box.add_child(p)
	var nl: = V10ShopKit.lbl("", "display", 32, V10DS.PAPER_100)
	V10Type.fit(nl, "Наряд «%s»" % String(it.name), "title_l", col_w - 24 - 200 - 32, 1, V10DS.PAPER_100)
	nl.position = Vector2(24, 18)
	nl.size = Vector2(col_w - 24 - 200 - 32, 44)
	p.add_child(nl)
	var sl: = V10ShopKit.lbl("Навсегда, без случайности · %s" % String(it.eq), "ui", 18, V10DS.PAPER_300)
	sl.position = Vector2(24, 68)
	sl.size = Vector2(col_w - 24 - 200 - 32, 26)
	p.add_child(sl)
	var pill: = V10ShopW.Pill.new().setup(String(it.rar), V10ShopKit.rar_color(String(it.rar)))
	pill.position = Vector2(16, 16)
	box.add_child(pill)
	var chip: = V10ShopW.Chip.new().setup(V10ShopKit.tex("item_crystal"), String(it.price_txt), Vector2(200, 64))
	chip.name = "OutfitPrice"
	chip.position = Vector2(col_w - 16 - 200, 32)
	chip.pressed.connect(func(): V10ShopFlow.outfit(self, m, it, refresh))
	p.add_child(chip)
	return box


# top part of a portrait art (head → waist), never a low crop
static func _top_crop(t: Texture2D, r: Rect2) -> TextureRect:
	var at: = AtlasTexture.new()
	at.atlas = t
	var ts: = t.get_size()
	var h: = minf(ts.y, ts.x * r.size.y / r.size.x)
	at.region = Rect2(0, ts.y * 0.03, ts.x, h)
	var x: = V10ShopKit.art(at, r, true)
	x.clip_contents = true
	return x


# ---- Наряды
func _outfits(first: Array) -> float:
	var y: = 0.0
	var petals_open: = m.outfits_petals_open()
	if not petals_open:
		outfit_mode = "crystal"
	if petals_open:
		var tg: = V10ShopW.Seg.new().setup(["за кристаллы", "за лепестки"], 0 if outfit_mode == "crystal" else 1, 400)
		tg.name = "OutfitMode"
		tg.position = Vector2(col_x, y + 12)
		tg.changed.connect(func(i: int):
			outfit_mode = "crystal" if i == 0 else "petal"
			_build_strip()
			_build_tab())
		content.add_child(tg)
		y += 80
	var items: = m.outfits(outfit_mode)
	if outfit_mode == "petal" and m.bal("petal") <= 0:
		y = _petal_empty(y)
	var cw: = (col_w - 16) * 0.5
	var ch: = cw * 472.0 / 328.0
	for i in items.size():
		var it: Dictionary = items[i]
		var c: = _outfit_card(it, Vector2(cw, ch))
		c.position = Vector2(col_x + (i % 2) * (cw + 16), y + (i / 2) * (ch + 16))
		content.add_child(c)
		if i < 5:
			first.append(c)
	y += ceili(items.size() / 2.0) * (ch + 16)
	var fair: = V10ShopKit.lbl("В рейтинге наряды не дают силы", "ui", 18, V10DS.PAPER_500)
	fair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fair.position = Vector2(col_x, y + 8)
	fair.size = Vector2(col_w, 26)
	content.add_child(fair)
	return y + 40


func _petal_empty(y: float) -> float:
	var t: = V10ShopKit.tex("item_petal")
	if t:
		content.add_child(V10ShopKit.art(t, Rect2(col_x + col_w * 0.5 - 64, y + 8, 128, 128)))
	var l: = V10ShopKit.lbl("Лепестки приходят из повторных нарядов. Сейчас: 0", "ui", 22, V10DS.PAPER_300)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(col_x, y + 144)
	l.size = Vector2(col_w, 32)
	content.add_child(l)
	var how: = V10Button.make("secondary", "Как получить", Vector2(280, 80))
	how.position = Vector2(col_x + (col_w - 280) * 0.5, y + 180)
	how.pressed.connect(func():
		V10ShopKit.press(how)
		V10ShopFlow.info(self, "Лепестки", ["Повторный наряд из Желаний превращается в Лепестки: A — 5, S — 20, SSR — 60.",
			"За Лепестки здесь можно взять наряды прошлых сезонов и ✦ Созвездия."]))
	content.add_child(how)
	return y + 276


func _outfit_card(it: Dictionary, sz: Vector2) -> Control:
	var c: = V10ShopW.Lac.new()
	c.bevel = 12.0
	c.size = sz
	c.name = "Outfit_" + String(it.id)
	var art_h: = sz.y - 128
	var t: = V10ShopKit.outfit_tex(String(it.img))
	if t:
		var a: = _top_crop(t, Rect2(4, 4, sz.x - 8, art_h - 4))
		if bool(it.owned):
			a.modulate = Color(1, 1, 1, 0.55)
		c.add_child(a)
	var pill: = V10ShopW.Pill.new().setup(String(it.rar), V10ShopKit.rar_color(String(it.rar)))
	pill.position = Vector2(12, 12)
	c.add_child(pill)
	var nl: = V10ShopKit.lbl("", "ui_strong", 22, V10DS.PAPER_100)
	V10Type.fit(nl, String(it.name), "title_sm", sz.x - 24, 1, V10DS.PAPER_100)
	nl.position = Vector2(12, art_h + 8)
	nl.size = Vector2(sz.x - 24, 32)
	c.add_child(nl)
	if bool(it.owned):
		var ol: = V10ShopKit.lbl("Уже твоё", "ui", 18, V10DS.JADE_300)
		ol.position = Vector2(12, art_h + 60)
		ol.size = Vector2(sz.x - 24, 40)
		c.add_child(ol)
	else:
		var icon: = V10ShopKit.tex("item_crystal" if String(it.cur) == "crystal" else "item_petal")
		var chip: = V10ShopW.Chip.new().setup(icon, String(it.price_txt), Vector2(sz.x - 24, 64))
		chip.position = Vector2(12, art_h + 48)
		chip.pressed.connect(func(): V10ShopFlow.outfit(self, m, it, refresh))
		c.add_child(chip)
	return c


# ---- Пополнить
func _topup(first: Array) -> float:
	var y: = 8.0
	var rule: = V10ShopKit.wrap(V10ShopKit.lbl("Всё в игре покупается за Кристаллы. Лунный камень — те же кристаллы, только купленные за рубли: тратится после бесплатных, и мы всегда спросим. Билет — одно готовое желание.", "ui", 18, V10DS.PAPER_300), 4)
	rule.position = Vector2(col_x, y)
	rule.size = Vector2(col_w, 26 * 4)
	rule.name = "CurrencyRule"
	content.add_child(rule)
	first.append(rule)
	y += 26 * V10Type.lines_needed(rule.text, "ui", 18, col_w) + 16
	var cards: = m.topup()
	if cards.is_empty():
		var na: = V10ShopKit.lbl("Покупки недоступны в этой сборке", "ui", 22, V10DS.PAPER_300)
		na.position = Vector2(col_x, y)
		na.size = Vector2(col_w, 34)
		content.add_child(na)
		return y + 40
	for c in cards:
		var r: = _pack_row(c)
		r.position = Vector2(col_x, y)
		content.add_child(r)
		first.append(r)
		y += r.size.y + 12
	return y


func _pack_row(c: Dictionary) -> Control:
	var h: = 156.0 if bool(c.best) and String(c.first_txt) != "" else 128.0
	var p: = V10ShopW.Lac.new()
	p.size = Vector2(col_w, h)
	p.name = "Pack_" + String(c.id)
	p.set_meta("rub_card", c)
	p.selected = bool(c.best)
	var t: = V10ShopKit.tex(String(c.art))
	if t:
		p.add_child(V10ShopKit.art(t, Rect2(12, 16, 96, 96)))
	var x: = 124.0
	var tw: = col_w - x - 184 - 16
	var tl: = V10ShopKit.lbl("", "ui_strong", 22, V10DS.PAPER_100)
	V10Type.fit(tl, String(c.title), "text_l", tw, 1, V10DS.PAPER_100)
	tl.position = Vector2(x, 14)
	tl.size = Vector2(tw, 32)
	p.add_child(tl)
	var l2: = V10ShopKit.lbl("%s · %s" % [c.eq, c.per_wish], "ui", 18, V10DS.PAPER_300)
	l2.name = "PerWish"
	l2.position = Vector2(x, 48)
	l2.size = Vector2(tw, 26)
	p.add_child(l2)
	var ly: = 78.0
	if bool(c.best):
		var lb: = V10ShopKit.lbl("самый низкий ₽ за желание", "ui", 18, V10DS.JADE_300)
		lb.name = "Best"
		lb.position = Vector2(x, ly)
		lb.size = Vector2(tw, 26)
		p.add_child(lb)
		ly += 28
	if String(c.first_txt) != "":
		var l3: = V10ShopKit.lbl("", "ui", 18, V10DS.PAPER_500)
		V10Type.fit(l3, String(c.first_txt), "caption_m", tw, 1, V10DS.PAPER_500)
		l3.name = "Note"
		l3.position = Vector2(x, ly)
		l3.size = Vector2(tw, 26)
		p.add_child(l3)
	var cash: = V10ShopW.Cash.new().setup(String(c.price), "", Vector2(184, 64))
	cash.name = "Cash"
	cash.position = Vector2(col_w - 16 - 184, (h - 64) * 0.5)
	cash.enabled = bool(c.available)
	cash._lay()
	var id: = String(c.id)
	cash.pressed.connect(func(): V10ShopFlow.confirm(self, m, id))
	p.add_child(cash)
	if not bool(c.available) and String(c.reason_txt) != "":
		l2.text = String(c.reason_txt)
	return p


# ---- footer
func _footer(y: float) -> float:
	var names: = ["Мои покупки", "Восстановить покупки", "Шансы и правила"]
	var ids: = ["purchases", "restore", "odds"]
	var w: = col_w / 3.0
	for i in 3:
		var t: = V10ShopW.Tap.new()
		t.dip = false
		t.name = "Foot_" + ids[i]
		t.position = Vector2(col_x + i * w, y)
		t.size = Vector2(w, 80)
		t.set_meta("ux_role", "tertiary")
		var l: = V10ShopKit.lbl(names[i], "ui", 18, V10DS.PAPER_300)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = t.size
		t.add_child(l)
		var id: String = ids[i]
		t.pressed.connect(func(): _footer_tap(id))
		content.add_child(t)
	return y + 80


func _footer_tap(id: String) -> void:
	match id:
		"purchases":
			go_screen.emit("purchases", {})
		"restore":
			var done: = m.econ.shop.reconcile()
			V10ShopKit.toast(self, "Восстановлено покупок: %d" % done.size() if not done.is_empty() else "Всё уже на месте")
			refresh()
		"odds":
			var odds: = V10Hud2Util.opt_class("V10OddsScreen")
			if odds:
				go_screen.emit("odds", {})
			else:
				V10ShopFlow.info(self, "Шансы и правила", ["В Лавке нет случайных товаров: ты точно знаешь, что получишь.",
					"Шансы желаний — в Желаниях, кнопка ⓘ Шансы."])


# ================================================================ inner controls
class Shade:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h: = size.y
		var a: = Color(V10DS.NIGHT_900, 0.35)
		var b: = Color(V10DS.NIGHT_900, 0.93)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, h * 0.32), Vector2(0, h * 0.32)]),
			PackedColorArray([a, a, b, b]))
		draw_rect(Rect2(0, h * 0.32, size.x, h * 0.68), b)


class Fade:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var a: = Color(V10DS.NIGHT_800, 0.0)
		var b: = Color(V10DS.NIGHT_800, 0.92)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([a, a, b, b]))


# swipe carousel, dots, no autoplay; one sheen every 2.8 s on the card in focus (the screen's only one)
class Carousel:
	extends Control
	var cards: Array = []
	var cur: = 0
	var track: Control
	var dots: V10ShopW.Dots
	var _drag: = false
	var _x0: = 0.0
	var _tx0: = 0.0
	var _moved: = 0.0
	var _t: = 0.0
	var sheen: Control

	func _init() -> void:
		clip_contents = true     # neighbours never leak out of the column (tablets)
		mouse_filter = Control.MOUSE_FILTER_PASS
		track = Control.new()
		track.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(track)

	func add_card(c: Control) -> void:
		c.position = Vector2(cards.size() * (size.x + 16), 0)
		track.add_child(c)
		cards.append(c)

	func finish() -> void:
		dots = V10ShopW.Dots.new()
		dots.n = cards.size()
		dots.visible = cards.size() > 1
		dots.position = Vector2(0, 304)
		dots.size = Vector2(size.x, 16)
		dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dots)
		sheen = Sheen.new()
		sheen.size = Vector2(size.x, 300)
		add_child(sheen)
		for c in cards:
			(c as Control).visible = true
		set_process(true)

	func go(i: int) -> void:
		cur = clampi(i, 0, cards.size() - 1)
		dots.cur = cur
		dots.queue_redraw()
		var tw: = create_tween()
		tw.tween_property(track, "position:x", -cur * (size.x + 16), 0.24).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenDrag or (e is InputEventMouseMotion and _drag):
			_moved += absf(e.relative.x)
			track.position.x = _tx0 + (e.position.x - _x0)
			if _moved > 12:
				accept_event()
		elif (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
			if e.pressed:
				_drag = true
				_x0 = e.position.x
				_tx0 = track.position.x
				_moved = 0.0
			else:
				_drag = false
				var dx: float = e.position.x - _x0
				if absf(dx) > 64:
					V10Hud2Util.sfx("tab_switch")
					go(cur + (1 if dx < 0 else -1))
				else:
					go(cur)

	func _process(d: float) -> void:
		_t += d
		if sheen and V10ShopKit.fx_on():
			(sheen as Sheen).k = fmod(_t, 2.8) / 0.5
			sheen.queue_redraw()


class Sheen:
	extends Control
	var k: = -1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if k < 0.0 or k > 1.0:
			return
		var x: = lerpf(-80.0, size.x + 80.0, ease(k, -1.6))
		var c: = Color(V10DS.PAPER_100, 0.10)
		var c0: = Color(V10DS.PAPER_100, 0.0)
		var sk: = 60.0
		draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 40, 0), Vector2(x + 40 - sk, size.y), Vector2(x - sk, size.y)]),
			PackedColorArray([c0, c, c, c0]))
