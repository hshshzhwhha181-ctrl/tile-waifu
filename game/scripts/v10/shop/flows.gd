class_name V10ShopFlow
extends RefCounted

# V10ShopFlow — the sheets of Лавка 2. One template per job (UX §5.3):
#   confirm(host, m, sku)        purchase confirm for ₽ (V10Pay stub in test builds: 4 outcomes)
#   need(host, m, deficit, go)   «Не хватает»: free paths with numbers on top, ONE smallest covering pack below
#   outfit(host, m, it, done)    crystal / petal purchase of a known outfit (asks from 1000 crystals or if moonstone is
#                                touched; shows the split «Спишется: … → …»)
#   pause_ask(host, m)           once after a purchase from 1490 ₽: «Сделать паузу покупок на 24 часа?»
#   info(host, title, lines)     the «Что это · Откуда · На что» sheet
# host: the screen (Control). Optional host methods: currency_target(cur) -> Vector2 (fly target), refresh().

const OFFER_TXT: = "Оферта · Покупка окончательна после зачисления"


static func _refresh(host: Control) -> void:
	if host and host.has_method("refresh"):
		host.call("refresh")


static func _target(host: Control, cur: String) -> Vector2:
	if host and host.has_method("currency_target"):
		return host.call("currency_target", cur)
	return Vector2(host.size.x - 120, 80) if host else Vector2.ZERO


# ================================================================ purchase confirm
static func confirm(host: Control, m: V10ShopModel, sku: String) -> V10ShopSheet:
	var c: = m.card(sku)
	if c.is_empty():
		return null
	var sh: = V10ShopSheet.make(host, String(c.get("name", c.title)), "confirm")
	sh.set_meta("sku", sku)
	sh.title_l.text = _name_of(c)
	var y: = sh.top()
	var b: = sh.body
	var W: = sh.inner_w()
	# what you buy
	var t: = V10ShopKit.tex(String(c.art))
	if t:
		b.add_child(V10ShopKit.art(t, Rect2(V10ShopSheet.PAD, y, 96, 96)))
	var ovt: = String(c.overline)
	if ovt.to_lower() == String(c.name).to_lower() or ovt.to_lower() == _name_of(c).to_lower():
		ovt = "ОДИН РАЗ" if bool(c.once) else ("ЛУННЫЙ КАМЕНЬ" if String(c.kind) == "currency" else "")
	var ov: = V10ShopKit.lbl(ovt, "overline", 15, V10DS.GOLD_500)
	ov.position = Vector2(V10ShopSheet.PAD + 112, y + 8)
	ov.size = Vector2(W - 112, 20)
	b.add_child(ov)
	var tl: = V10ShopKit.lbl("", "ui", 22, V10DS.PAPER_100)
	V10Type.fit(tl, String(c.title), "text_l", W - 112, 2, V10DS.PAPER_100)
	tl.position = Vector2(V10ShopSheet.PAD + 112, y + 32)
	tl.size = Vector2(W - 112, 64)
	b.add_child(tl)
	y += 112
	sh.rule(y)
	y += 16
	sh.text("Ты получишь", y, "ui", 18, V10DS.PAPER_500)
	y += 30
	for line in m.receive_lines(c):
		sh.text("•  " + String(line), y, "ui", 22, V10DS.PAPER_100)
		y += 34
	y += 8
	sh.rule(y)
	y += 16
	var pl: = V10ShopKit.lbl(String(c.price), "num", 40, V10DS.GOLD_300)
	pl.position = Vector2(V10ShopSheet.PAD, y)
	pl.size = Vector2(W * 0.5, 48)
	b.add_child(pl)
	var pw: = V10ShopKit.lbl(V10ShopModel.value_line(c), "ui", 18, V10DS.PAPER_300)   # «= N желаний · ≈ N ₽ за желание»
	pw.name = "PerWish"
	pw.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pw.position = Vector2(V10ShopSheet.PAD + W * 0.4, y)
	pw.size = Vector2(W * 0.6, 48)
	b.add_child(pw)
	y += 52
	var cap: = m.cap_30d()
	var spent: = "Потрачено за 30 дней: %s" % V10ShopTxt.rub(m.spent_30d())
	if cap > 0:
		spent += " из %s" % V10ShopTxt.num(cap)
	sh.text(spent, y, "ui", 18, V10DS.PAPER_500)
	y += 34
	# test build: plate + 4 outcomes
	var outcome: = {"v": "paid"}
	if V10ShopPay.is_test():
		var tp: = V10ShopKit.lbl("ТЕСТ · деньги не списываются", "overline", 15, V10DS.EMBER)
		tp.position = Vector2(V10ShopSheet.PAD, y + 4)
		tp.size = Vector2(W, 20)
		b.add_child(tp)
		y += 28
		var seg: = V10ShopW.Seg.new().setup(["Оплачено", "Ждём банк", "Отказ", "Отмена"], 0, W)
		seg.position = Vector2(V10ShopSheet.PAD, y + 8)
		seg.name = "TestOutcome"
		for k in seg.taps:
			(k as Control).set_meta("ux_role", "test")
		for lb in seg._ls:
			(lb as Label).label_settings = V10Type.settings("ui", 18, V10DS.PAPER_300)
		seg.select(0)
		seg.changed.connect(func(i: int): outcome.v = ["paid", "pending", "failed", "cancelled"][i])
		b.add_child(seg)
		y += 72
	# status line (failure / waiting) above the button
	var status: = V10ShopKit.lbl("", "ui", 22, V10DS.PAPER_100)
	status.name = "Status"
	status.position = Vector2(V10ShopSheet.PAD, y)
	status.size = Vector2(W, 32)
	b.add_child(status)
	y += 40
	var cb: = m.can_buy(sku)
	var pay: = V10ShopW.Cash.new()
	pay.name = "Pay"
	pay.setup(String(c.price), "Оплатить", Vector2(W, 104))
	pay.position = Vector2(V10ShopSheet.PAD, y)
	pay.set_meta("ux_role", "primary_cash")
	pay.set_meta("rub_card", c)
	b.add_child(pay)
	if not cb.ok:
		pay.enabled = false
		pay._lay()
		status.text = m.reason_txt(String(cb.reason))
		status.label_settings = V10Type.settings("ui", 22, V10DS.PAPER_300)
	y += 112
	var cancel: = V10Button.make("secondary", "Отмена", Vector2(W, 80))
	cancel.position = Vector2(V10ShopSheet.PAD, y)
	cancel.set_meta("ux_role", "secondary")
	cancel.pressed.connect(func():
		V10ShopKit.press(cancel)
		sh.close())
	b.add_child(cancel)
	y += 92
	var off: = V10ShopW.Tap.new()      # 56 visible, 80 hit (12 above / below), not over «Отмена»
	off.dip = false
	off.name = "Offer"
	off.position = Vector2(V10ShopSheet.PAD, y)
	off.size = Vector2(W, 56)
	off.set_meta("ux_role", "link")
	var ol: = V10ShopKit.lbl(OFFER_TXT, "ui", 18, V10DS.PAPER_500)
	ol.size = off.size
	off.add_child(ol)
	off.pressed.connect(func(): V10ShopKit.toast(host, "Оферта откроется в браузере"))
	b.add_child(off)
	y += 64
	sh.finish(y)

	# purchase flow on the economy signals (one sheet = one order)
	var shop: = m.econ.shop
	var st: = {"oid": ""}
	var on_ok: = func(r: Dictionary) -> void:
		if String(st.oid) != "" and String(r.get("oid", "")) != String(st.oid):
			return
		# no order id yet: only a synchronous answer to OUR tap counts — an older order finishing (reconcile, a
		# pending one) while the sheet is open must not close it with someone else's hanko
		if String(st.oid) == "" and (not sh.busy or String(r.get("sku", "")) != sku):
			return
		sh.busy = false
		_delivered(host, m, sh, pay, r)
	var on_fail: = func(o: Dictionary, why: String) -> void:
		if String(o.get("oid", "")) != String(st.oid):
			return
		sh.busy = false
		pay.loading = false
		var cancelled: = String(o.get("st", "")) == "cancelled" or why == "user_cancelled"
		status.text = "Оплата отменена" if cancelled else "Оплата не прошла. Деньги не списаны"
		status.label_settings = V10Type.settings("ui", 22, V10DS.PAPER_100)
		V10ShopKit.deny(status)
	var on_pend: = func(o: Dictionary) -> void:
		if String(o.get("oid", "")) != String(st.oid):
			return
		sh.busy = false
		pay.loading = false
		pay.enabled = false
		pay._lay()
		status.text = "Ждём подтверждения банка"
		status.label_settings = V10Type.settings("ui", 22, V10DS.GOLD_300)
		V10ShopKit.toast(host, "Ждём подтверждения банка — зачислим сразу, как придёт ответ")
		_refresh(host)
	shop.delivered.connect(on_ok)
	shop.failed.connect(on_fail)
	shop.pending.connect(on_pend)
	sh.closed.connect(func():
		shop.delivered.disconnect(on_ok)
		shop.failed.disconnect(on_fail)
		shop.pending.disconnect(on_pend))
	pay.pressed.connect(func():
		if pay.loading:
			return
		status.text = ""
		m.set_test_outcome(String(outcome.v))
		pay.loading = true
		var p: = m.provider()
		if p is V10StubPay:
			(p as V10StubPay).instant = false
		sh.busy = true
		var res: = m.buy(sku)
		if not bool(res.get("ok", false)):
			sh.busy = false
			pay.loading = false
			status.text = m.reason_txt(String(res.get("reason", "")))
			return
		st.oid = String(res.oid)
		# the store answers asynchronously; the stub answers after a short «bank» pause
		if p is V10StubPay:
			host.get_tree().create_timer(0.6 if not V10ShopKit.mute else 0.0).timeout.connect(func(): (p as V10StubPay).flush()))
	return sh


static func _name_of(c: Dictionary) -> String:
	match String(c.kind):
		"currency":
			return "Пополнить"
		"month":
			return "Лунный абонемент"
		"pass":
			return "Пропуск сезона+" if String(c.id) == "pass_1490" else "Пропуск сезона"
	var o: = String(c.overline)
	return o.substr(0, 1) + o.substr(1).to_lower() if o != "" else String(c.title)


static func _delivered(host: Control, m: V10ShopModel, sh: V10ShopSheet, pay: Control, r: Dictionary) -> void:
	var from: = pay.get_global_rect().get_center() - host.get_global_rect().position if is_instance_valid(pay) else host.size * 0.5
	sh.close()
	var g: Dictionary = r.get("grant", {})
	V10ShopKit.hanko(host, host.size * Vector2(0.5, 0.45))
	var cur: = "moon" if int(g.get("moon", 0)) > 0 else ("crystal" if int(g.get("crystal", 0)) > 0 else "")
	if cur != "":
		V10ShopKit.fly(host, from, _target(host, cur), V10ShopKit.tex("moon_1" if cur == "moon" else "item_crystal"), 6)
	var what: = V10ShopModel.grant_text(g)
	var sku: = String(r.get("sku", ""))
	if what == "":
		what = _name_of(m.card(sku)) if not m.card(sku).is_empty() else sku
	var t: = "Зачислено: " + what
	if cur != "":
		t += " · баланс " + V10ShopTxt.num(m.bal(cur))
	V10ShopKit.toast(host, t)
	_refresh(host)
	if m.should_ask_pause(r):
		host.get_tree().create_timer(1.4 if not V10ShopKit.mute else 0.0).timeout.connect(func():
			if is_instance_valid(host):
				pause_ask(host, m))


# ================================================================ «Не хватает»
# UX §3.4: the main action is the FIRST free path (a «Забрать» on its row), the smallest pack is secondary, × is quiet.
# A free path is actionable when we can act on it here: «gift» (claimed in place), «pass» (the host's go_screen or
# go_free), any other «go» id through go_free (or model.free_paths_go). Rows without one stay plain text.
static func need(host: Control, m: V10ShopModel, deficit: int, go_topup: Callable = Callable(), go_free: Callable = Callable()) -> V10ShopSheet:
	var sh: = V10ShopSheet.make(host, "Не хватает кристаллов", "need")
	var n: = m.need(deficit)
	var y: = sh.top()
	var W: = sh.inner_w()
	# the number in Numerals, not in the Display title (HUD_V2 §3: every number is Numerals)
	var dl: = V10ShopKit.lbl("ещё " + V10ShopTxt.amount("crystal", deficit), "num", 28, V10DS.GOLD_300)
	dl.name = "Deficit"
	dl.position = Vector2(V10ShopSheet.PAD, y - 8)
	dl.size = Vector2(W, 36)
	sh.body.add_child(dl)
	y += 40
	sh.text("БЕСПЛАТНО", y, "overline", 15, V10DS.GOLD_500)
	y += 28
	if not go_free.is_valid() and m.free_paths_go.is_valid():
		go_free = m.free_paths_go
	if bool(n.free_none):
		sh.text("Бесплатных путей сегодня нет — загляни завтра", y, "ui", 22, V10DS.PAPER_300)
		y += 36
	else:
		var primary_done: = false
		for f in n.free:
			var go: = String((f as Dictionary).get("go", ""))
			var act: = Callable()
			if not primary_done and go != "":
				act = _free_action(host, m, sh, go, go_free)
			if act.is_valid():
				primary_done = true
				var tl: = sh.text(String(f.text), y + 20, "ui", 22, V10DS.PAPER_100)
				tl.size.x = W - 200 - 16
				var b: = V10Button.make("play", "Забрать" if go in ["gift", "pass"] else "Открыть", Vector2(200, 80))
				b.name = "FreePath"
				b.sheen = false
				b.position = Vector2(V10ShopSheet.PAD + W - 200, y)
				b.set_meta("ux_role", "primary")
				b.pressed.connect(func():
					V10ShopKit.press(b, true)
					act.call())
				sh.body.add_child(b)
				y += 88
			else:
				sh.text(String(f.text), y, "ui", 22, V10DS.PAPER_100)
				y += 36
	if String(n.moon_note) != "":
		sh.text(String(n.moon_note), y + 4, "ui", 18, V10DS.PAPER_500)
		y += 34
	var pk: Dictionary = n.pack
	if not pk.is_empty():
		y += 8
		sh.rule(y)
		y += 16
		var row: = V10ShopW.Lac.new()
		row.over_art = false
		row.position = Vector2(V10ShopSheet.PAD, y)
		row.size = Vector2(W, 112)
		sh.body.add_child(row)
		var t: = V10ShopKit.tex(String(pk.art))
		if t:
			row.add_child(V10ShopKit.art(t, Rect2(12, 16, 80, 80)))
		var tl: = V10ShopKit.lbl(String(pk.title), "ui", 22, V10DS.PAPER_100)
		tl.position = Vector2(108, 18)
		tl.size = Vector2(W - 108 - 184, 34)
		row.add_child(tl)
		var sl: = V10ShopKit.lbl("%s · %s" % [pk.eq, pk.per_wish], "ui", 18, V10DS.PAPER_300)
		sl.position = Vector2(108, 56)
		sl.size = Vector2(W - 108 - 184, 30)
		row.add_child(sl)
		var cash: = V10ShopW.Cash.new().setup(String(pk.price), "", Vector2(168, 64))
		cash.name = "Cash"
		cash.set_meta("rub_card", pk)
		cash.position = Vector2(W - 168 - 12, 24)
		cash.enabled = bool(pk.available)
		cash._lay()
		var pid: = String(pk.id)
		cash.pressed.connect(func(): confirm(host, m, pid))
		row.add_child(cash)
		y += 124
		if go_topup.is_valid():
			var all: = V10Button.make("secondary", "Все пакеты", Vector2(W, 80))
			all.name = "AllPacks"
			all.set_meta("ux_role", "secondary")
			all.position = Vector2(V10ShopSheet.PAD, y)
			all.pressed.connect(func():
				V10ShopKit.press(all)
				sh.close()
				go_topup.call())
			sh.body.add_child(all)
			y += 84
	sh.finish(y + 16)
	return sh


static func _free_action(host: Control, m: V10ShopModel, sh: V10ShopSheet, go: String, go_free: Callable) -> Callable:
	match go:
		"gift":
			if not m.gift_ready():
				return Callable()
			return func():
				sh.close()
				m.gift_claim(false, func(g: Dictionary):
					if g.is_empty() or not is_instance_valid(host):
						return
					V10ShopKit.toast(host, "Зачислено: %s · баланс %s" % [V10ShopTxt.amount("crystal", int(g.get("crystal", 0))), V10ShopTxt.num(m.bal("crystal"))])
					_refresh(host))
		"pass":
			if go_free.is_valid():
				return func():
					sh.close()
					go_free.call("pass")
			if host.has_signal("go_screen"):
				return func():
					sh.close()
					host.emit_signal("go_screen", "pass", {})
			return Callable()
	if go_free.is_valid():
		return func():
			sh.close()
			go_free.call(go)
	return Callable()


# ================================================================ known outfit for crystals / petals
static func outfit(host: Control, m: V10ShopModel, it: Dictionary, done: Callable = Callable()) -> void:
	var price: = int(it.price)
	var is_petal: = String(it.cur) == "petal"
	if is_petal:
		if m.bal("petal") < price:
			info(host, "Не хватает лепестков", ["Нужно %s, сейчас %s." % [V10ShopTxt.amount("petal", price), V10ShopTxt.num(m.bal("petal"))],
				"Лепестки приходят из повторных нарядов в Желаниях."])
			return
	else:
		var sp: = m.crystal_split(price)
		if int(sp.short) > 0:
			need(host, m, int(sp.short), Callable(host, "go_topup") if host.has_method("go_topup") else Callable())
			return
		var touches_moon: = int(sp.moon) > 0
		if not touches_moon and (price < V10ShopData.CRYSTAL_CONFIRM_FROM or bool(m.st.crystal_noask)):
			_outfit_buy(host, m, it, done)
			return
	var sh: = V10ShopSheet.make(host, String(it.name), "outfit")
	var y: = sh.top()
	var W: = sh.inner_w()
	var t: = V10ShopKit.outfit_tex(String(it.img))
	if t:
		var a: = V10ShopKit.art(t, Rect2(V10ShopSheet.PAD, y, 160, 200), true)
		a.clip_contents = true
		sh.body.add_child(a)
	var x: = V10ShopSheet.PAD + 176
	var l1: = V10ShopKit.lbl("Навсегда, без случайности", "ui", 22, V10DS.PAPER_100)
	l1.position = Vector2(x, y + 8)
	l1.size = Vector2(W - 176, 32)
	sh.body.add_child(l1)
	var l2: = V10ShopKit.lbl("В рейтинге наряды не дают силы", "ui", 18, V10DS.PAPER_500)
	l2.position = Vector2(x, y + 44)
	l2.size = Vector2(W - 176, 28)
	sh.body.add_child(l2)
	var split_txt: = ""
	if is_petal:
		split_txt = "Спишется: %s · останется %s" % [V10ShopTxt.amount("petal", price), V10ShopTxt.num(m.bal("petal") - price)]
	else:
		# UX §5.3: «Спишется: 450 кристаллов → 150 Лунного камня · останется …»
		var sp2: = m.crystal_split(price)
		split_txt = "Спишется: %s" % V10ShopTxt.amount("crystal", int(sp2.crystal))
		if int(sp2.moon) > 0:
			split_txt += " → %s · останется %s" % [V10ShopTxt.amount("moon", int(sp2.moon)), V10ShopTxt.amount("moon", m.bal("moon") - int(sp2.moon))]
		else:
			split_txt += " · останется %s" % V10ShopTxt.amount("crystal", m.bal("crystal") - int(sp2.crystal))
	var l3: = V10ShopKit.wrap(V10ShopKit.lbl(split_txt, "ui", 18, V10DS.PAPER_300), 3)
	l3.position = Vector2(x, y + 84)
	l3.size = Vector2(W - 176, 84)
	sh.body.add_child(l3)
	y += 216
	var uses_moon: = not is_petal and int(m.crystal_split(price).moon) > 0
	var btn: Control
	if uses_moon:   # moonstone is money: «Касса» class (UX §5.2.7); the number keeps its unit (UX §4.1.3)
		var cash: = V10ShopW.Cash.new().setup(V10ShopTxt.amount("crystal", price), "Купить наряд", Vector2(W, 104))
		cash.name = "Pay"
		btn = cash
		cash.pressed.connect(func():
			sh.close()
			_outfit_buy(host, m, it, done))
	else:
		var pb: = V10Button.make("play", "Купить · " + V10ShopTxt.num(price), Vector2(W, 104))
		pb.breathing = false
		pb.sheen = false      # the screen under the sheet already has its one sheen (carousel)
		pb.name = "Pay"
		btn = pb
		pb.pressed.connect(func():
			V10ShopKit.press(pb, true)
			sh.close()
			_outfit_buy(host, m, it, done))
	btn.position = Vector2(V10ShopSheet.PAD, y)
	btn.set_meta("ux_role", "primary")
	sh.body.add_child(btn)
	y += 112
	if uses_moon:   # the §5.3 template for money: «Отмена» ≥ 80 px under «Касса»
		var cancel: = V10Button.make("secondary", "Отмена", Vector2(W, 80))
		cancel.name = "Cancel"
		cancel.position = Vector2(V10ShopSheet.PAD, y)
		cancel.set_meta("ux_role", "secondary")
		cancel.pressed.connect(func():
			V10ShopKit.press(cancel)
			sh.close())
		sh.body.add_child(cancel)
		y += 84
	if not is_petal and not uses_moon:
		var na: = V10ShopW.Tap.new()      # 64 visible, 80 hit, clear of the button above
		na.dip = false
		na.name = "NoAsk"
		na.set_meta("ux_role", "tertiary")
		na.position = Vector2(V10ShopSheet.PAD, y + 4)
		na.size = Vector2(W, 64)
		var nl: = V10ShopKit.lbl("Больше не спрашивать для кристаллов", "ui", 18, V10DS.PAPER_500)
		nl.size = na.size
		na.add_child(nl)
		na.pressed.connect(func():
			m.st.crystal_noask = true
			nl.text = "✓ Больше не спрашивать для кристаллов")
		sh.body.add_child(na)
		y += 76
	sh.finish(y + 16)


static func _outfit_buy(host: Control, m: V10ShopModel, it: Dictionary, done: Callable) -> void:
	var r: = m.buy_outfit(it)
	if not bool(r.ok):
		if String(r.get("reason", "")) == "need":
			need(host, m, int(r.short))
		return
	V10ShopKit.hanko(host, host.size * Vector2(0.5, 0.45))
	V10ShopKit.toast(host, "Наряд «%s» — твой" % String(it.name))
	if done.is_valid():
		done.call()
	_refresh(host)


# ================================================================ pause ask / info / limits
static func pause_ask(host: Control, m: V10ShopModel) -> void:
	var sh: = V10ShopSheet.make(host, "Сделать паузу покупок?", "pause_ask")
	var y: = sh.top()
	var W: = sh.inner_w()
	sh.text("Можно включить паузу на 24 часа. Мы спросим один раз.", y, "ui", 22, V10DS.PAPER_300, 2)
	y += 80
	var yes: = V10Button.make("secondary", "Пауза на 24 часа", Vector2(W, 80))
	yes.position = Vector2(V10ShopSheet.PAD, y)
	yes.pressed.connect(func():
		V10ShopKit.press(yes)
		m.answer_pause(true)
		sh.close()
		V10ShopKit.toast(host, "Покупки на паузе до завтра")
		_refresh(host))
	sh.body.add_child(yes)
	y += 84
	var no: = V10Button.make("secondary", "Не нужно", Vector2(W, 80))
	no.position = Vector2(V10ShopSheet.PAD, y)
	no.pressed.connect(func():
		V10ShopKit.press(no)
		m.answer_pause(false)
		sh.close())
	sh.body.add_child(no)
	sh.finish(y + 96)


static func info(host: Control, title: String, lines: Array) -> V10ShopSheet:
	var sh: = V10ShopSheet.make(host, title, "info")
	var y: = sh.top()
	for l in lines:
		var lb: = sh.text(String(l), y, "ui", 22, V10DS.PAPER_100, 3)
		var n: = V10Type.lines_needed(String(l), "ui", 22, sh.inner_w())
		lb.size.y = V10Type.line_h(22) * mini(n, 3)
		y += V10Type.line_h(22) * mini(n, 3) + 12
	sh.finish(y + 24)
	return sh


static func choose(host: Control, title: String, note: String, options: Array, cur: int, pick: Callable) -> V10ShopSheet:
	var sh: = V10ShopSheet.make(host, title, "choose")
	var y: = sh.top()
	var W: = sh.inner_w()
	if note != "":
		sh.text(note, y, "ui", 18, V10DS.PAPER_500, 2)
		y += 60
	for i in options.size():
		var row: = V10ShopW.Tap.new()
		row.position = Vector2(V10ShopSheet.PAD, y)
		row.size = Vector2(W, 80)
		var l: = V10ShopKit.lbl(("●  " if i == cur else "○  ") + String(options[i]), "ui", 22, V10DS.GOLD_300 if i == cur else V10DS.PAPER_100)
		l.size = row.size
		row.add_child(l)
		var idx: = i
		row.pressed.connect(func():
			sh.close()
			pick.call(idx))
		sh.body.add_child(row)
		y += 80
	sh.finish(y + 24)
	return sh
