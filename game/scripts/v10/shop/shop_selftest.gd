class_name V10ShopSelftest
extends RefCounted

# V10ShopSelftest — `--shop_selftest=1` (run through shop_demo.tscn). Prints SHOP_SELFTEST ok/total and every failure.
# Logic: card texts = V10Catalog numbers, exactly one «самый низкий ₽ за желание» and it is the true minimum, 3× rule,
# ladder gates by level and «once», no time words in cards, store build → 0 ₽ cards, stub purchase in 4 outcomes +
# duplicate + pending completion, age bands and teen caps, offer popup cadence, rewarded-ad caps and month bypass,
# gift once a day, cover(), pass retro-grant.
# Layout (SubViewports at 7 aspects × 3 tabs + pass + purchases + age + sheets): nothing outside the screen width,
# hit zones ≥ 80 (UX §6.1: Tap hit rect / V10Button height), ≤ 1 primary, no rose on ₽, every ₽ price shows «= N желаний»
# and «≈ N ₽ за желание», ≤ 2 currencies, banned words absent, text ≥ 18 px (15 only for overline), ≤ 10 tappables in
# the first screenful. Regressions (review 0.10): no ₽ before L8, honest «самый низкий», carousel swipe = one card,
# pass/purchases keep the toast through a rebuild, «Не хватает» has one primary, month disc is decoration on Чайная,
# age gate re-shows for a blocked year, history shows the real grant, no closing the confirm sheet mid-payment.

static var ok: = 0
static var _word_re: RegEx = null
const WORDS_CHECK: = false
static var total: = 0
static var fails: Array = []

const ASPECTS: = [Vector2(720, 1280), Vector2(720, 1440), Vector2(720, 1560), Vector2(720, 1600), Vector2(720, 1680),
	Vector2(960, 1280), Vector2(800, 1280)]


static func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		print("  FAIL ", what)


static func run(host: Node) -> int:
	ok = 0
	total = 0
	fails = []
	V10ShopKit.mute = true
	_logic()
	await _purchase_flow(host)
	await _layouts(host)
	V10ShopKit.mute = false
	print("SHOP_SELFTEST %d/%d" % [ok, total])
	return total - ok


static func _model(opts: = {}) -> V10ShopModel:
	var m: = preload("res://scripts/v10/shop/shop_demo.gd").demo_model(opts)
	m.ads_stub.instant = true
	var p: = m.provider()
	if p is V10StubPay:
		(p as V10StubPay).instant = true
	return m


# ================================================================ logic
static func _logic() -> void:
	var m: = _model()
	# cards and «best»
	var cards: = m.topup()
	check(cards.size() == 6, "topup has 6 packs")
	var best: = 0
	var minr: = INF
	for c in cards:
		minr = minf(minr, float(c.per_wish_rub))
	var shown_min: = 0
	for c in cards:
		if roundi(float(c.per_wish_rub)) == roundi(minr):
			shown_min += 1
	for c in cards:
		var s: = V10Catalog.sku(String(c.id))
		var v: = V10Catalog.pull_value(s, bool(c.first))
		check(String(c.per_wish) == V10ShopTxt.per_wish(float(s.rub) / v), "%s per-wish from V10Catalog" % c.id)
		check(String(c.eq).find("желани") >= 0, "%s has «= N желаний»" % c.id)
		check(String(c.price) == V10ShopTxt.rub(float(s.rub)), "%s price from catalog" % c.id)
		if bool(c.best):
			best += 1
			check(absf(float(c.per_wish_rub) - minr) < 0.01, "best is the true minimum")
		check(V10ShopTxt.lint(String(c.title) + String(c.per_wish) + String(c.eq) + String(c.first_txt)).is_empty(), "%s card text lint" % c.id)
	# «самый низкий» only when it is visibly true: one pack with the lowest ROUNDED «≈ N ₽», else no label at all
	check(best == (1 if shown_min == 1 else 0), "first-purchase state: «самый низкий» only if visibly lowest (best %d, packs at min %d)" % [best, shown_min])
	var ml: = _model()
	ml.econ.spend.set_age_verified(true)      # 12 718 ₽ in one go is above the unverified 3 000 ₽ cap
	(ml.provider() as V10StubPay).next_status = "paid"
	for c in cards:
		ml.buy(String(c.id))
	var later: = ml.topup()
	var later_best: = []
	for c in later:
		if bool(c.best):
			later_best.append(String(c.id))
	check(later_best == ["moon_14000"], "after first purchases: exactly one «самый низкий» on the true best %s" % str(later_best))
	for c in later:
		if bool(c.best):
			for o in later:
				if o.id != c.id:
					check(roundi(float(o.per_wish_rub)) > roundi(float(c.per_wish_rub)), "best %s is visibly lower than %s" % [c.id, o.id])
	# 3× rule for every SKU, booster value included
	for s in m.econ.shop.all_skus():
		for first in [false, true]:
			if first and String(s.kind) != "currency":
				continue
			check(m.ratio(s, first) <= V10Catalog.LADDER_MAX + 0.0001, "%s%s ratio %.2f ≤ 3" % [s.id, " first" if first else "", m.ratio(s, first)])
	# ladder by level
	var lv: = {"v": 0}
	m.level_fn = func(): return lv.v
	# UX §3.5 / С-2: no «₽» anywhere before L8 (Желания open at L3 and reach «Не хватает»)
	for l in [0, 5, 7]:
		lv.v = l
		check(not m.cash_visible() and m.topup().is_empty() and m.vitrina().is_empty() and (m.ladder().current as Dictionary).is_empty()
			and (m.need(300).pack as Dictionary).is_empty(), "level %d: no ₽ card, pack or ladder step (С-2)" % l)
	lv.v = 8
	var l0: = m.ladder()
	check(String(l0.current.get("id", "")) == "first_79", "level 8: ladder step 1 = first_79")
	check(String(l0.next.get("title", "")) == "Набор первого гостя", "level 8: next step silhouette")
	lv.v = 35
	var ids35: = _ladder_ids(m)
	check("traveler_199" in ids35, "level 35: traveler set visible")
	lv.v = 61
	var l61: = m.ladder()
	var ids61: = _ladder_ids(m)
	check(not ("first_79" in ids61) and not ("newbie_499" in ids61), "level 61: beginner sets gone")
	check("growth_1490" in ids61, "level 61: growth visible")
	lv.v = 120
	check(not ("growth_1490" in _ladder_ids(m)), "level 120: growth gone")
	lv.v = 8
	check(String(m.ladder().next.get("unlock", "")).find("Откроется") == 0, "silhouette says «Откроется …»")
	# no time words / dates in any card
	var re: = RegEx.new()
	re.compile("(\\d+\\s?(ч|мин|сек)\\b)|(янв|фев|мар|апр|мая|июн|июл|авг|сен|окт|ноя|дек)")
	lv.v = 12
	for c in m.vitrina() + m.topup():
		var all: = String(c.title) + " " + " ".join(c.lines) + " " + String(c.per_wish)
		check(re.search(all) == null, "%s: no timers or dates in card" % c.id)
		var vl: = V10ShopModel.value_line(c)
		check(vl.find("желани") >= 0 and vl.find("за желание") >= 0 and String(c.eq).find("желани") >= 0, "%s: value line «= N желаний · ≈ N ₽ за желание» (С-3)" % c.id)
	# store build: no ₽ anywhere
	var ms: = _model({"store": true})
	check(ms.topup().is_empty() and ms.vitrina().is_empty(), "store build: no ₽ cards")
	check((ms.need(300).pack as Dictionary).is_empty(), "store build: no pack in «Не хватает»")
	check(not V10ShopPay.cash_visible(ms.provider()), "store build: cash hidden")
	V10ShopPay.force_test = true
	V10ShopPay.force_store = false
	# age bands and teen caps
	var t0: = m.now()
	var ny: = V10Age.year_now(t0)
	var st: = {}
	check(V10Age.confirm_text(0, t0) == "Выбери год рождения", "age: nothing pre-selected")
	check(V10Age.confirm_text(ny - 30, t0) == "Мне есть 18 · войти", "age: adult button text")
	check(V10Age.confirm_text(ny - 17, t0) == "Продолжить", "age: teen button text")
	V10Age.set_year(st, ny - 17, t0)
	check(V10Age.band(st) == "teen", "age: 17 → teen")
	check(not V10Age.check(st, 549, 0).ok, "teen: 549 ₽ blocked")
	check(V10Age.check(st, 499, 0).ok, "teen: 499 ₽ ok")
	check(not V10Age.check(st, 449, 1100).ok, "teen: sum over 1500 blocked")
	check(not V10Age.bold_ok(st), "teen: no 18+ delta")
	V10Age.set_year(st, ny - 12, t0)
	check(not V10Age.allowed(ny - 12, t0) and not V10Age.check(st, 79, 0).ok, "child: blocked")
	V10Age.set_year(st, ny - 25, t0)
	check(V10Age.bold_ok(st) and V10Age.check(st, 4990, 0).ok, "adult: ok + bold_ok")
	check(V10Age.band_of(ny - 18, t0) == "teen", "year-only gate is conservative at 18")
	# a blocked year must bring the stop screen back on every start (not only while the year is unset)
	var sb: = {}
	check(V10Age.needs_gate(sb, t0), "age: gate needed while unset")
	V10Age.set_year(sb, ny - 12, t0)
	check(V10Age.needs_gate(sb, t0), "age: a blocked year keeps the gate after a restart")
	V10Age.set_year(sb, ny - 30, t0)
	check(not V10Age.needs_gate(sb, t0), "age: an allowed year passes")
	var sr: = {}
	V10Age.set_year(sr, ny - 17, t0)
	V10Age.refresh(sr, t0 + 2 * 366 * 86400)
	check(V10Age.band(sr) == "adult", "age: the band follows the calendar (17 → adult two years later)")
	check(not m.econ.spend.check(V10Catalog.AGE_LIMIT_RUB_30D + 1).ok, "unverified 18+: 3000 ₽ cap (V10Spend)")
	# offers cadence
	var os: = {}
	var base: = {"now": 10000, "install": 0, "level": 20, "result": "win", "first_ssr_session": false, "day": 5}
	check(V10Offers.can_popup(os, base).ok, "popup ok after a win")
	check(not V10Offers.can_popup(os, _with(base, "result", "lose")).ok, "no popup after a loss")
	check(not V10Offers.can_popup(os, _with(base, "install", 9700)).ok, "no popup in the first 600 s")
	check(not V10Offers.can_popup(os, _with(base, "level", 7)).ok, "no popup before L8")
	check(not V10Offers.can_popup(os, _with(base, "first_ssr_session", true)).ok, "no popup in the first-SSR session")
	# «Словарь» articles for the shop terms (П-4): V10Glossary limits, clean words
	for e in V10ShopData.GLOSSARY:
		check(String(e.name).length() <= 26 and String(e.why).length() <= 74 and String(e.how).length() <= 92
			and V10ShopTxt.lint(String(e.name) + " " + String(e.why) + " " + String(e.how)).is_empty(), "glossary %s fits V10Glossary" % e.id)
	check(not V10Offers.can_popup(os, _with(base, "first_ssr_t", 10000 - 3600)).ok and V10Offers.can_popup(os, _with(_with(base, "now", 200000), "first_ssr_t", 100000)).ok,
		"no popup for 24 h after the first SSR (UX §3.5)")
	V10Offers.mark_shown(os, 5)
	check(not V10Offers.can_popup(os, base).ok, "popup once a day")
	check(V10Offers.can_popup(os, _with(base, "day", 6)).ok, "popup next day")
	# rewarded ads
	var ma: = _model()
	var n_ok: = [0]
	for i in 9:
		var slot: = "chest" if i < 4 else ("event" if i < 7 else "gift")
		ma.ads.show(slot, func(okk): pass)
	check(ma.ads.left_today() == 0 or ma.ads.st.ads.n <= V10ShopData.ADS_DAY_MAX, "ads ≤ 6 a day")
	check(int(ma.ads.st.ads.slots.get("chest", 0)) <= 3, "chest slot ≤ 3 a day")
	check(int(ma.ads.st.ads.n) <= V10ShopData.ADS_DAY_MAX, "ad counter capped")
	var mb: = _model()
	mb.econ.shop._month_extend()
	var calls0: = mb.ads.calls
	mb.ads.show("gift", func(okk): n_ok[0] += 1)
	check(mb.ads.calls == calls0 and n_ok[0] == 1, "month card: reward without the ad provider")
	# gift of the day
	var mg: = _model()
	var c0: = mg.bal("crystal")
	var got: = []
	mg.gift_claim(true, func(g): got.append(g))
	check(mg.bal("crystal") - c0 == int(V10ShopData.GIFT_DAILY.crystal) * V10ShopData.GIFT_AD_MULT, "gift ×2 for an ad")
	mg.gift_claim(false, func(g): got.append(g))
	check(not mg.gift_ready() and (got[1] as Dictionary).is_empty(), "gift once a day")
	# cover / need
	var mn: = _model()
	var cv: = mn.cover(100)
	check(String(cv.id) == "moon_180", "cover(100) → smallest pack")
	var cv2: = mn.cover(2000)
	var got2: = int(V10Catalog.sku_grant(V10Catalog.sku(String(cv2.id)), true).get("moon", 0))
	check(got2 >= 2000, "cover(2000) covers")
	var nd: = mn.need(300)
	check(not (nd.free as Array).is_empty(), "need: free paths listed")
	check(not (nd.pack as Dictionary).is_empty(), "need: one pack")
	for f in nd.free:
		check(V10ShopTxt.lint(String(f.text)).is_empty(), "need: «%s» passes the lint (no «ещё N сегодня»)" % f.text)
	check(not V10ShopTxt.lint("Задания дня: ещё 50 сегодня").is_empty() and not V10ShopTxt.lint("SR+ наряд").is_empty()
		and V10ShopTxt.lint("SSR-наряд сезона").is_empty() and V10ShopTxt.lint("через VK ID или Яндекс ID").is_empty(), "lint: §4.3 tokens with word edges")
	# purchase history shows what the purchase really gave (first purchase doubled)
	var mh: = _model()
	(mh.provider() as V10StubPay).next_status = "paid"
	mh.buy("moon_900")
	check(mh.receipt_title(mh.receipts()[0]) == V10ShopTxt.amount("moon", 1720), "history: first purchase shows 1 720, not today's 900")
	# pass retro-grant
	var mp: = _model({"pass_xp": 1240})
	var tier: = mp.econ.pass_.tier()
	mp.set_test_outcome("paid")
	var r: = mp.buy("pass_899")
	check(bool(r.get("ok", false)), "pass purchase ok")
	var prem: = 0
	for c in mp.econ.pass_.claimable():
		if String(c.track) == "prem":
			prem += 1
	check(prem == tier, "retro-grant: all %d reached premium tiers open" % tier)
	var before: = mp.bal("crystal")
	mp.pass_claim_all()
	check(mp.bal("crystal") > before and mp.econ.pass_.claimable().is_empty(), "claim all once")


static func _ladder_ids(m: V10ShopModel) -> Array:
	var out: = []
	for e in V10ShopData.LADDER:
		var a: = m.econ.shop.available(String(e.sku))
		var to: = int(e.to)
		if m.level() >= int(e.from) and (to == 0 or m.level() < to) and not (String(a.get("reason", "")) in ["owned", "expired", "unknown"]):
			out.append(String(e.sku))
	return out


static func _with(d: Dictionary, k: String, v) -> Dictionary:
	var x: = d.duplicate()
	x[k] = v
	return x


# ================================================================ purchase flow (stub, 4 outcomes)
static func _purchase_flow(host: Node) -> void:
	var m: = _model()
	var p: V10StubPay = m.provider()
	var moon0: = m.bal("moon")
	p.next_status = "paid"
	var r: = m.buy("moon_900")
	check(bool(r.ok) and m.bal("moon") - moon0 == 1720, "paid: first purchase doubles base (860+860)")
	p.next_status = "cancelled"
	var m1: = m.bal("moon")
	m.buy("moon_180")
	check(m.bal("moon") == m1, "cancelled: nothing granted")
	p.next_status = "failed"
	m.buy("moon_180")
	check(m.bal("moon") == m1, "failed: nothing granted")
	p.next_status = "pending"
	var rp: = m.buy("moon_180")
	check(m.pending_orders().size() == 1, "pending: order waits")
	p.complete(String(rp.oid), "paid")
	check(m.bal("moon") == m1 + 360 and m.pending_orders().is_empty(), "pending → paid later delivers once")
	p.next_status = "paid"
	p.duplicate = true
	var m2: = m.bal("moon")
	m.buy("moon_180")
	check(m.bal("moon") == m2 + 180, "duplicate callback delivers once")
	p.duplicate = false
	check(m.econ.shop.audit().is_empty() and m.econ.audit().is_empty(), "economy audit clean")
	# teen layer blocks before the provider
	V10Age.set_year(m.st, V10Age.year_now(m.now()) - 17, m.now())
	var orders0: int = m.econ.shop.st.orders.size()
	var rb: = m.buy("moon_3000")
	check(not bool(rb.ok) and String(rb.reason) == "teen_one" and m.econ.shop.st.orders.size() == orders0, "teen: 1190 ₽ blocked before the store")
	# big purchase → pause question once
	var mq: = _model()
	(mq.provider() as V10StubPay).next_status = "paid"
	var got: = {"r": {}}
	mq.econ.shop.delivered.connect(func(rr): got.r = rr)
	mq.buy("growth_1490")
	check(mq.should_ask_pause(got.r), "≥1490 ₽ → ask for a pause")
	mq.answer_pause(false)
	check(not mq.should_ask_pause(got.r), "pause asked only once")
	# the confirm sheet in a viewport: pay → delivered, hanko, toast
	var vp: = await _vp(host, Vector2(720, 1280))
	var mc: = _model()
	var scr: = V10Shop2.make(mc, {"tab": 2})
	vp.host.add_child(scr)
	await host.get_tree().process_frame
	var sh: = V10ShopFlow.confirm(scr, mc, "moon_180")
	await host.get_tree().process_frame
	var pay: V10ShopW.Cash = sh.body.get_node("Pay")
	check(pay != null and pay.enabled, "confirm: pay button enabled")
	check(_find_text(sh, "Оферта") and _find_text(sh, "Потрачено за 30 дней") and _find_text(sh, "за желание"), "confirm: offer, spent, per-wish lines")
	check(_find_text(sh, "ТЕСТ · деньги не списываются"), "confirm: test plate in test build")
	var mm: = mc.bal("moon")
	pay.fire()
	check(pay.loading, "confirm: spinner while waiting")
	sh.close()
	check(not sh._closing and V10ShopSheet.current == sh, "confirm: tap outside / back wait while the payment is in flight")
	pay.fire()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check(mc.bal("moon") == mm + 360, "confirm: paid once (double tap ignored)")
	await host.get_tree().create_timer(0.3).timeout
	check(_find_text(scr, "Зачислено:"), "confirm: toast «Зачислено: …»")
	check(scr.find_child("Hanko", true, false) != null, "confirm: hanko seal")
	vp.svc.queue_free()
	await _regressions(host)


# ================================================================ review regressions (screens)
static func _regressions(host: Node) -> void:
	var tree: = host.get_tree()
	# carousel: one finger = touch + emulated mouse; one swipe must move exactly one card
	var vp: = await _vp(host, Vector2(720, 1280))
	var mc: = _model()
	mc.econ.shop._month_extend()
	var scr: = V10Shop2.make(mc, {"tab": 0})
	vp.host.add_child(scr)
	await tree.process_frame
	var car: = scr.carousel
	check(car != null and car.cards.size() >= 2, "carousel has cards")
	if car and car.cards.size() >= 2:
		var p0: = Vector2(120, 150)
		for ev in [_mb(true, p0), _st(true, p0)]:
			car._gui_input(ev)
		var mm: = InputEventMouseMotion.new()
		mm.position = p0 - Vector2(180, 0)
		mm.relative = Vector2(-180, 0)
		car._gui_input(mm)
		for ev in [_mb(false, p0 - Vector2(180, 0)), _st(false, p0 - Vector2(180, 0))]:
			car._gui_input(ev)
		check(car.cur == 1, "carousel: one swipe (touch + emulated mouse) = one card (cur %d)" % car.cur)
	# «Не хватает»: the first actionable free path is the ONE primary (UX §3.4)
	var nsh: = V10ShopFlow.need(scr, mc, 320, Callable(scr, "go_topup"))
	await tree.process_frame
	var prim: = 0
	for n in _all(nsh):
		if n is Control and String((n as Control).get_meta("ux_role", "")) == "primary":
			prim += 1
	check(prim == 1, "need: exactly one primary (first free path) (%d)" % prim)
	var fp: V10Button = nsh.find_child("FreePath", true, false)
	check(fp != null and fp.kind == "play", "need: the free path is a «Забрать» button")
	check(not _find_text(nsh, "сегодня ") or _find_text(nsh, "Бесплатных путей сегодня нет"), "need: no «ещё N сегодня»")
	nsh.close(true)
	vp.svc.queue_free()
	# pass: «Забрать всё» → the toast and the hanko survive the rebuild (UX §5.2.8)
	var vp2: = await _vp(host, Vector2(720, 1280))
	var mp: = _model({"pass_xp": 1240})
	var ps: = V10PassScreen.make(mp)
	vp2.host.add_child(ps)
	await tree.process_frame
	check(ps.find_child("PremLabel", true, false) != null and String((ps.find_child("PremLabel", true, false) as Label).text).find("С ПРОПУСКОМ") > 0, "pass: one track caption instead of a lock on every tile")
	check(String((ps.find_child("XpLeft", true, false) as Label).text).begins_with("ещё "), "pass: «ещё N опыта до …», not «N / M»")
	for sku in ["pass_899", "pass_1490"]:
		var eq: Label = ps.find_child("Eq_" + sku, true, false)
		var pw: Label = ps.find_child("PerWish_" + sku, true, false)
		check(eq != null and eq.text.find("желани") >= 0 and pw != null and pw.text.find("за желание") >= 0, "pass: %s shows = N желаний and ≈ ₽ за желание" % sku)
	ps._claim_all()
	await tree.process_frame
	await tree.process_frame
	check(_find_text(ps, "Зачислено:") and ps.find_child("Hanko", true, false) != null, "pass: «Забрать всё» toast + hanko survive the rebuild")
	vp2.svc.queue_free()
	# purchases: the restore toast survives the rebuild
	var vp3: = await _vp(host, Vector2(720, 1280))
	var pu: = V10Purchases.make(_model())
	vp3.host.add_child(pu)
	await tree.process_frame
	(pu.find_child("Restore", true, false) as V10Button).pressed.emit()
	await tree.process_frame
	await tree.process_frame
	check(_find_text(pu, "Всё уже на месте") or _find_text(pu, "Восстановлено"), "purchases: restore toast survives the rebuild")
	vp3.svc.queue_free()
	# month disc on Чайная: decoration only — no tap, no dot (UX §3.3 / §3.6.4)
	var md: = V10MonthDisc.make(mc)
	host.add_child(md)
	await tree.process_frame
	check(md.mouse_filter == Control.MOUSE_FILTER_IGNORE and not md.has_meta("v10_tap"), "month disc: not tappable on Чайная")
	md.queue_free()
	# age gate: a stored blocked year shows the stop screen again
	var vp4: = await _vp(host, Vector2(720, 1280))
	var ast: = {}
	V10Age.set_year(ast, V10Age.year_now(mc.now()) - 12, mc.now())
	var ag: = V10AgeGate.make(ast, mc.now())
	vp4.host.add_child(ag)
	await tree.process_frame
	check(ag.find_child("Stop", true, false) != null and ag.drum == null, "age gate: blocked year → stop screen on restart")
	vp4.svc.queue_free()


static func _mb(down: bool, p: Vector2) -> InputEventMouseButton:
	var e: = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	return e


static func _st(down: bool, p: Vector2) -> InputEventScreenTouch:
	var e: = InputEventScreenTouch.new()
	e.pressed = down
	e.position = p
	return e


static func _find_text(n: Node, s: String) -> bool:
	if n is Label and (n as Label).text.find(s) >= 0:
		return true
	for c in n.get_children():
		if _find_text(c, s):
			return true
	return false


# ================================================================ layouts
static func _vp(host: Node, vs: Vector2) -> Dictionary:
	var svc: = SubViewportContainer.new()
	svc.size = vs
	host.add_child(svc)
	var sv: = SubViewport.new()
	sv.size = Vector2i(vs)
	sv.gui_embed_subwindows = true
	svc.add_child(sv)
	var h: = Control.new()
	h.size = vs
	sv.add_child(h)
	await host.get_tree().process_frame
	return {"svc": svc, "sv": sv, "host": h}


static func _layouts(host: Node) -> void:
	for vs in ASPECTS:
		for tab in 3:
			var vp: = await _vp(host, vs)
			var m: = _model({"petals": 40 if tab == 1 else 0})
			var scr: = V10Shop2.make(m, {"tab": tab, "bottom_reserve": 120.0})
			vp.host.add_child(scr)
			for i in 2:
				await host.get_tree().process_frame
			var tag: = "%dx%d tab%d" % [vs.x, vs.y, tab]
			_check_screen(scr, vs, tag, tab == 0)
			if tab == 2:
				# «самый низкий ₽ за желание» on screen = the model's honest best (none while every pack reads «≈ 33 ₽»)
				var bests: = scr.find_children("Best", "Label", true, false)
				var want: = 0
				for c in m.topup():
					if bool(c.best):
						want += 1
				check(want <= 1 and bests.size() == want, "%s: best labels on screen = model (%d / %d)" % [tag, bests.size(), want])
				if vs == Vector2(720, 1280) or vs == Vector2(720, 1600):
					# after the first purchases the true best is visibly lower: exactly ONE label, on that pack
					var ml: = _model()
					ml.econ.spend.set_age_verified(true)
					for c in ml.topup():
						ml.buy(String(c.id))
					var sl: = V10Shop2.make(ml, {"tab": 2, "bottom_reserve": 120.0})
					vp.host.add_child(sl)
					await host.get_tree().process_frame
					var bl: = sl.find_children("Best", "Label", true, false)
					check(bl.size() == 1 and String((bl[0] as Node).get_parent().name) == "Pack_moon_14000", "%s later: exactly one «самый низкий» label, on the true best" % tag)
					sl.queue_free()
				for p in scr.find_children("Pack_*", "", true, false):
					var pw: Label = p.get_node_or_null("PerWish")
					check(pw != null and pw.text.find("за желание") >= 0 and pw.text.find("желани") >= 0, "%s: %s shows = N желаний · ≈ ₽" % [tag, p.name])
			vp.svc.queue_free()
		# other screens at this size
		for which in ["pass", "purchases", "age"]:
			var vp2: = await _vp(host, vs)
			var m2: = _model()
			var s2: Control
			match which:
				"pass":
					s2 = V10PassScreen.make(m2)
				"purchases":
					s2 = V10Purchases.make(m2)
				"age":
					s2 = V10AgeGate.make({}, m2.now())
			vp2.host.add_child(s2)
			for i in 2:
				await host.get_tree().process_frame
			_check_screen(s2, vs, "%dx%d %s" % [vs.x, vs.y, which], false)
			if which == "age":
				var g: V10AgeGate = s2
				check(g.drum.year() == 0, "age: drum starts empty")
				var bb: = g.btn.get_global_rect()
				check(bb.end.y <= vs.y and bb.position.y >= vs.y * 0.5, "%dx%d age: button in the lower half, on screen" % [vs.x, vs.y])
			vp2.svc.queue_free()
	# sheets over the shop (each is its own «screen» for the budget): confirm, «Не хватает», outfit with moonstone
	for vs in [Vector2(720, 1280), Vector2(720, 1600)]:
		for which in ["confirm", "need", "outfit"]:
			var vp5: = await _vp(host, vs)
			var m5: = _model({"moon": 300})
			var s5: = V10Shop2.make(m5, {"tab": 0})
			vp5.host.add_child(s5)
			await host.get_tree().process_frame
			var sh: V10ShopSheet
			match which:
				"confirm":
					sh = V10ShopFlow.confirm(s5, m5, "guest_149")
				"need":
					sh = V10ShopFlow.need(s5, m5, 320, Callable(s5, "go_topup"))
				"outfit":
					for it in m5.outfits("crystal"):
						if not bool(it.owned) and int(it.price) >= 1000:
							V10ShopFlow.outfit(s5, m5, it)
							break
					sh = V10ShopSheet.current
			await host.get_tree().process_frame
			check(sh != null, "%dx%d sheet %s opens" % [vs.x, vs.y, which])
			if sh:
				_check_screen(sh, vs, "%dx%d sheet %s" % [vs.x, vs.y, which], false)
				var prim: = 0
				for n in _all(sh):
					if n is Control and String((n as Control).get_meta("ux_role", "")) in ["primary", "primary_cash"]:
						prim += 1
				check(prim == 1, "%dx%d sheet %s: exactly one primary (%d)" % [vs.x, vs.y, which, prim])
				sh.close(true)
			vp5.svc.queue_free()
	# store build screen: zero cash buttons
	var vp3: = await _vp(host, Vector2(720, 1280))
	for tab in 3:
		var ms: = _model({"store": true})
		var s3: = V10Shop2.make(ms, {"tab": tab})
		vp3.host.add_child(s3)
		await host.get_tree().process_frame
		var cash: = 0
		for n in _all(s3):
			if n.has_meta("v10_cash") and (n as Control).is_visible_in_tree():
				cash += 1
			if n is Label and (n as Label).text.find("₽") >= 0 and (n as Control).is_visible_in_tree():
				cash += 1
		check(cash == 0, "store build tab%d: 0 ₽ labels/buttons" % tab)
		s3.queue_free()
	V10ShopPay.force_test = true
	V10ShopPay.force_store = false
	vp3.svc.queue_free()


static func _all(n: Node) -> Array:
	var out: = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


static func _check_screen(scr: Control, vs: Vector2, tag: String, budget: bool) -> void:
	var out_w: = 0
	var small_hit: = []
	var primaries: = 0
	var rose_cash: = 0
	var tiny: = []
	var banned: = []
	var curs: = 0
	var taps_first: = 0
	var rub_cards: = []
	var all_text: = ""
	var words: = 0
	var sizes: = {}
	var bars: = 0
	if _word_re == null:
		_word_re = RegEx.new()
		_word_re.compile("[\\p{L}\\d]")
	var scroll: ScrollContainer = scr.get_node_or_null("Scroll")
	var view_rect: = Rect2(Vector2.ZERO, vs)
	if scroll:
		view_rect = Rect2(scroll.global_position, scroll.size)
	for n in _all(scr):
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var c: Control = n
		var r: = c.get_global_rect()
		# horizontal overflow: anything (but the pass ribbon content, which scrolls) wider than the screen
		if not _inside_hscroll(c) and (r.position.x < -1.0 or r.end.x > vs.x + 1.0) and r.size.x > 0 and not c is ScrollContainer:
			if not (c.name in ["Backdrop", "Parallax"]) and not (c is TextureRect and c.get_parent() == scr):
				out_w += 1
				print("    out: ", c.get_path(), " ", r)
		var tappable: = c.has_meta("v10_tap") or c is V10Button
		if tappable and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			var h: = c.size.y
			if c is V10Button:
				h = (c as V10Button).btn_size.y
			elif c is V10ShopW.Tap:
				h = (c as V10ShopW.Tap).hit_rect().size.y
			if h < 80.0 - 0.5 and String(c.get_meta("ux_role", "")) != "test":
				small_hit.append("%s %d" % [c.name, h])
			if budget and view_rect.encloses(r) and not c.get_parent() is V10ShopW.Seg:
				taps_first += 1
		if c.get_meta("ux_role", "") == "primary" or (c is V10Button and (c as V10Button).kind == "play"):
			if view_rect.intersects(r):
				primaries += 1
		if c.has_meta("v10_cash") and c is V10Button and (c as V10Button).kind == "play":
			rose_cash += 1
		if c is Label:
			var l: Label = c
			var ls: = l.label_settings
			if ls and l.text != "":
				var role: = String(l.get_meta("v10_role", ""))
				if ls.font_size < 18 and not (role == "overline" and ls.font_size == 15):
					tiny.append(l.text)
				var bad: = V10ShopTxt.lint(l.text)
				if not bad.is_empty():
					banned.append("%s (%s)" % [l.text, ", ".join(bad)])
		if c.name.begins_with("Cur_"):
			curs += 1
		if c.has_meta("rub_card"):
			rub_cards.append(c.get_meta("rub_card"))
		if c is Label:
			all_text += (c as Label).text + "\n"
			# §3.7 budget of the first screenful: words and font sizes of what is actually on screen
			var lt: = (c as Label).text
			if lt != "" and view_rect.intersects(r) and (c as Label).label_settings:
				sizes[(c as Label).label_settings.font_size] = true
				for wd in lt.split(" ", false):
					if _word_re.search(wd) != null:
						words += 1
		if c is V10ShopW.Bar and view_rect.intersects(r):
			bars += 1
	var no_value: = []
	for rc in rub_cards:
		if all_text.find(String(rc.get("eq", "?"))) < 0 or all_text.find(String(rc.get("per_wish", "?"))) < 0 or String(rc.get("eq", "")) == "":
			no_value.append(String(rc.get("id", "")))
	check(no_value.is_empty(), "%s: every ₽ price shows «= N желаний» and «≈ N ₽ за желание» %s" % [tag, str(no_value)])
	check(out_w == 0, "%s: nothing outside the screen width (%d)" % [tag, out_w])
	check(small_hit.is_empty(), "%s: hit zones ≥ 80 %s" % [tag, str(small_hit)])
	check(primaries <= 1, "%s: ≤ 1 primary (%d)" % [tag, primaries])
	check(rose_cash == 0, "%s: no rose on ₽" % tag)
	check(tiny.is_empty(), "%s: text ≥ 18 px %s" % [tag, str(tiny.slice(0, 3))])
	check(banned.is_empty(), "%s: banned words %s" % [tag, str(banned.slice(0, 3))])
	check(curs <= 2, "%s: ≤ 2 currencies" % tag)
	if budget:
		check(taps_first <= 10, "%s: ≤ 10 tappables in the first screenful (%d)" % [tag, taps_first])
	var sz: = sizes.keys()
	sz.sort()
	print("    BUDGET %s: words %d, sizes %s, bars %d" % [tag, words, str(sz), bars])
	if WORDS_CHECK:
		check(words <= 60, "%s: ≤ 60 words on screen (UX §3.7) (%d)" % [tag, words])
	check(bars <= 2, "%s: ≤ 2 progress bars (%d)" % [tag, bars])


static func _inside_hscroll(c: Node) -> bool:
	var p: = c.get_parent()
	while p:
		if p is ScrollContainer and (p as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return true
		if p.name == "Carousel":
			return true
		p = p.get_parent()
	return false
