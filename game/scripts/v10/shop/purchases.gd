class_name V10Purchases
extends Control

# V10Purchases — «Мои покупки» (spec 0.10 Л2, UX §3.2 footer). Only the player sees this (never in profile, posters,
# letters). Spent in 30 days + cap, the list of receipts (pending ones with «Ждём подтверждения банка»), own limit
# (нет / 1 000 / 3 000 / 5 000 / 10 000 ₽: raising after 24 h, lowering at once), a pause of all purchases
# (1 / 7 / 30 days), «остыть 24 часа после покупки от 1 490 ₽», «Восстановить покупки». Limits and pause live in
# V10Spend (v10-economy); the 16–17 caps in V10Age.

signal go_screen(id: String, args: Dictionary)

var m: V10ShopModel
var vs: = Vector2(720, 1280)


static func make(model: V10ShopModel) -> V10Purchases:
	var p: = V10Purchases.new()
	p.m = model
	p.name = "V10Purchases"
	return p


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(build)
	build()


func refresh() -> void:
	build()


func build() -> void:
	V10ShopKit.clear(self)          # keeps an open sheet and the toast («Восстановлено …»)
	vs = get_viewport_rect().size
	size = vs
	var base: = ColorRect.new()
	base.color = V10DS.NIGHT_900
	base.size = vs
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	V10Header.make(self, "Мои покупки", func(): go_screen.emit("back", {}))
	var y: = V10Header.content_y(vs)
	var cw: = minf(vs.x, 720.0) - 48.0
	var cx: = (vs.x - cw) * 0.5
	var sp: = m.econ.spend
	# spent
	var ov: = V10ShopKit.lbl("ПОТРАЧЕНО ЗА 30 ДНЕЙ", "overline", 15, V10DS.GOLD_500)
	ov.position = Vector2(cx, y)
	ov.size = Vector2(cw, 20)
	add_child(ov)
	y += 24
	var cap: = m.cap_30d()
	var big: = V10ShopKit.lbl(V10ShopTxt.rub(m.spent_30d()), "num", 40, V10DS.GOLD_300)
	big.name = "Spent"
	big.position = Vector2(cx, y)
	big.size = Vector2(cw * 0.5, 48)
	add_child(big)
	if cap > 0:
		var of: = V10ShopKit.lbl("из " + V10ShopTxt.rub(cap), "ui", 22, V10DS.PAPER_300)
		of.position = Vector2(cx + cw * 0.5, y + 8)
		of.size = Vector2(cw * 0.5, 40)
		of.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(of)
	y += 52
	if cap > 0:
		var bar: = V10ShopW.Bar.new()
		bar.position = Vector2(cx, y)
		bar.size = Vector2(cw, 12)
		bar.k = float(m.spent_30d()) / float(cap)
		add_child(bar)
		y += 20
	var why: = _cap_reason()
	if why != "":
		var wl: = V10ShopKit.wrap(V10ShopKit.lbl(why, "ui", 18, V10DS.PAPER_500), 2)
		wl.position = Vector2(cx, y)
		wl.size = Vector2(cw, 52)
		add_child(wl)
		y += 60
	y += 8
	# settings rows (each opens one choice sheet)
	var lim: = sp.limit()
	var lim_txt: = "нет" if lim <= 0 else V10ShopTxt.rub(lim)
	if int(sp.st.limit_next) >= 0:
		lim_txt += " → %s с %s" % ["нет" if int(sp.st.limit_next) == 0 else V10ShopTxt.rub(int(sp.st.limit_next)), V10ShopTxt.date_msk(int(sp.st.limit_at))]
	y = _row(cx, cw, y, "Мой лимит на 30 дней", lim_txt, "Limit", _pick_limit)
	var now: = m.now()
	var pause_txt: = "нет" if now >= int(sp.st.pause_until) else "до " + V10ShopTxt.date_msk(int(sp.st.pause_until))
	y = _row(cx, cw, y, "Пауза покупок", pause_txt, "Pause", _pick_pause)
	y = _row(cx, cw, y, "Остыть 24 часа после покупки от %s" % V10ShopTxt.rub(V10Catalog.BIG_PURCHASE_RUB),
		"вкл" if bool(sp.st.cool_on) else "выкл", "Cool", func():
			sp.set_cooldown(not bool(sp.st.cool_on))
			build())
	y += 16
	# receipts
	var hl: = V10ShopKit.lbl("ИСТОРИЯ", "overline", 15, V10DS.GOLD_500)
	hl.position = Vector2(cx, y)
	hl.size = Vector2(cw, 20)
	add_child(hl)
	y += 28
	var list: = ScrollContainer.new()
	list.name = "Receipts"
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var ins: = V10Hud2Util.safe_insets(vs)
	var bottom: = vs.y - float(ins.bottom) - 104
	list.position = Vector2(cx, y)
	list.size = Vector2(cw, maxf(120.0, bottom - y - 16))
	add_child(list)
	var box: = Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var ly: = 0.0
	var rows: Array = []
	for o in m.pending_orders():
		rows.append({"t": int(o.t), "sku": String(o.sku), "rub": int(o.rub), "st": "pending", "grant": {}})
	for r in m.receipts():
		rows.append(r)
	if rows.is_empty():
		var e: = V10ShopKit.lbl("Покупок пока нет", "ui", 22, V10DS.PAPER_500)
		e.size = Vector2(cw, 40)
		box.add_child(e)
		ly = 40
	for r in rows:
		var st_txt: String = {"delivered": "зачислено", "confirmed": "зачислено", "restored": "восстановлено",
			"refunded": "возврат", "pending": "ждём подтверждения банка"}.get(String(r.st), String(r.st))
		var a: = V10ShopKit.lbl(m.receipt_title(r), "ui", 22, V10DS.PAPER_100)
		a.position = Vector2(0, ly)
		a.size = Vector2(cw * 0.66, 32)
		box.add_child(a)
		var pr: = V10ShopKit.lbl(V10ShopTxt.rub(int(r.rub)), "num", 22, V10DS.PAPER_100)
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pr.position = Vector2(cw * 0.66, ly)
		pr.size = Vector2(cw * 0.34, 32)
		box.add_child(pr)
		var d: = V10ShopKit.lbl("%s · %s" % [V10ShopTxt.date_short(int(r.t)), st_txt], "ui", 18,
			V10DS.GOLD_300 if String(r.st) == "pending" else V10DS.PAPER_500)
		d.position = Vector2(0, ly + 32)
		d.size = Vector2(cw, 26)
		box.add_child(d)
		ly += 72
	box.custom_minimum_size = Vector2(cw, ly)
	list.add_child(box)
	var rs: = V10Button.make("secondary", "Восстановить покупки", Vector2(cw, 80))
	rs.name = "Restore"
	rs.position = Vector2(cx, bottom + 8)
	rs.set_meta("ux_role", "secondary")
	rs.pressed.connect(func():
		V10ShopKit.press(rs)
		var done: = m.econ.shop.reconcile()
		build()
		V10ShopKit.toast(self, "Восстановлено покупок: %d" % done.size() if not done.is_empty() else "Всё уже на месте"))
	add_child(rs)
	V10ShopKit.raise_fx(self)


func _cap_reason() -> String:
	var b: = V10Age.band(m.st)
	if b == "teen":
		return "До 18 лет: не больше %s за 30 дней и %s за покупку." % [V10ShopTxt.rub(V10ShopData.TEEN_MONTH_RUB), V10ShopTxt.rub(V10ShopData.TEEN_ONE_RUB)]
	if not bool(m.econ.spend.st.age_ok):
		return "Пока возраст не подтверждён через VK ID или Яндекс ID — не больше %s за 30 дней." % V10ShopTxt.rub(V10Catalog.AGE_LIMIT_RUB_30D)
	return ""


func _row(cx: float, cw: float, y: float, title: String, val: String, nm: String, cb: Callable) -> float:
	var t: = V10ShopW.Tap.new()
	t.name = nm
	t.dip = false
	t.position = Vector2(cx, y)
	t.size = Vector2(cw, 80)
	t.set_meta("ux_role", "row")      # a settings list row, not one of the screen's ≤ 2 secondary actions
	var l: = V10ShopKit.lbl("", "ui", 22, V10DS.PAPER_100)
	V10Type.fit(l, title, "text_l", cw * 0.6, 1, V10DS.PAPER_100)
	l.size = Vector2(cw * 0.6, 80)
	t.add_child(l)
	var v: = V10ShopKit.lbl("", "ui", 22, V10DS.GOLD_300)
	V10Type.fit(v, val + "  ›", "text_l", cw * 0.4, 1, V10DS.GOLD_300)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.position = Vector2(cw * 0.6, 0)
	v.size = Vector2(cw * 0.4, 80)
	t.add_child(v)
	var rl: = V10ShopSheet.Rule.new()
	rl.position = Vector2(0, 79)
	rl.size = Vector2(cw, 2)
	t.add_child(rl)
	t.pressed.connect(cb)
	add_child(t)
	return y + 80


func _pick_limit() -> void:
	var opts: = []
	var cur: = 0
	var lim: = m.econ.spend.limit()
	for i in V10ShopData.OWN_LIMITS.size():
		var v: int = V10ShopData.OWN_LIMITS[i]
		opts.append("Без лимита" if v == 0 else V10ShopTxt.rub(v))
		if v == lim:
			cur = i
	V10ShopFlow.choose(self, "Мой лимит на 30 дней", "Снижение — сразу. Повышение и снятие — через 24 часа.", opts, cur, func(i: int):
		m.econ.spend.set_limit(int(V10ShopData.OWN_LIMITS[i]))
		build())


func _pick_pause() -> void:
	var opts: = []
	for d in V10ShopData.PAUSE_DAYS:
		opts.append("%d %s" % [d, V10ShopTxt.plural(d, "день", "дня", "дней")])
	V10ShopFlow.choose(self, "Пауза покупок", "Во время паузы купить ничего нельзя. Отменить раньше нельзя.", opts, -1, func(i: int):
		m.econ.spend.pause(int(V10ShopData.PAUSE_DAYS[i]))
		build())
