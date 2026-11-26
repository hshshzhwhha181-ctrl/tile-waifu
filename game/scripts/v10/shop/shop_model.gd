class_name V10ShopModel
extends RefCounted

# V10ShopModel — everything Лавка 2 shows, computed from v10-economy (V10Econ / V10Catalog / V10Shop / V10Spend /
# V10Pass) plus the shop-UI state in S.v10_shop. Screens never compute prices or values themselves (spec §2.2):
# they render the dictionaries returned here.
#
#   card(sku)       -> {id, kind, overline, title, lines[≤3], rub, price, wishes, eq, per_wish_rub, per_wish, first,
#                       first_txt, available, reason, reason_txt, art, once, best}
#   topup()         -> 6 moonstone cards; best = true on at most one: the lowest real ₽ per wish, and only when that
#                      is visibly true (its rounded «≈ N ₽» is below every other pack's — no label on a tie)
#   ladder()        -> {"current": card|{}, "next": {title, unlock}|{}}  — gated by Path level, no dates
#   vitrina()       -> ≤ 3 paid cards (ladder step, month card, season pass) — the gift is separate
#   outfits(mode)   -> outfit cards for «за кристаллы» / «за лепестки»
#   need(deficit)   -> {free:[{text, go}], moon_note, pack: card}  (go: "gift" | "pass" | an id for free_paths_go)
#   cash_visible()  -> false in the store build AND before Path level 8 (UX §3.5, С-2: no «₽» before L8)
#   buy(sku)        -> age layer + econ.shop.buy (one entry point for every ₽ button)
#
# S.v10_shop (registered via V10Registry/V10Save at integration): {"gift": {"day", "x2"}, "age": {...},
#   "offers": {...}, "ads": {...}, "cool_asked": bool, "crystal_noask": bool}

signal changed

var econ: V10Econ
var st: Dictionary
var level_fn: Callable            # () -> int, Path level (V10Path / G.S.level)
var items_fn: Callable            # () -> Array of outfit dicts {id, name, rar, hero, img, shop}
var owns_fn: Callable             # (id) -> bool
var free_paths_fn: Callable       # () -> Array of {"text": "Задания дня: ещё 50 кристаллов", "go": "today"} (other modules;
                                  # no «ещё N сегодня» wording — UX §4.1.7)
var free_paths_go: Callable       # (go: String) -> void, opens the screen of an outside free path (integrator)
var ads: V10Ads
var ads_stub: V10AdsStub


func _init(e: V10Econ, state: Dictionary) -> void:
	econ = e
	st = state
	ensure()
	for x in V10ShopData.EXTRA_SKUS:
		if econ.shop.sku(String(x.id)).is_empty():
			econ.shop.extra_skus.append(x.duplicate(true))
	ads_stub = V10AdsStub.new()
	ads = V10Ads.new(st, econ.clock.today, econ.shop.ad_free)
	ads.provider = ads_stub
	econ.changed.connect(func(): changed.emit())


func ensure() -> void:
	if not (st.get("gift") is Dictionary):
		st["gift"] = {}
	st.gift["day"] = int(st.gift.get("day", -1))
	st.gift["x2"] = bool(st.gift.get("x2", false))
	st["cool_asked"] = bool(st.get("cool_asked", false))
	st["crystal_noask"] = bool(st.get("crystal_noask", false))
	V10Age.ensure(st)
	if econ != null:
		V10Age.refresh(st, now())     # a 17-year-old turns 18: the stored band follows the calendar
	V10Offers.ensure(st)


static func defaults() -> Dictionary:
	var d: = {}
	var m: = {"gift": {}, "cool_asked": false, "crystal_noask": false}
	d.merge(m)
	V10Age.ensure(d)
	V10Offers.ensure(d)
	d["ads"] = {"day": -1, "n": 0, "slots": {}}
	return d


# ================================================================ basics
func now() -> int:
	return econ.clock.now()


func level() -> int:
	return int(level_fn.call()) if level_fn.is_valid() else 0


func bal(cur: String) -> int:
	return econ.wallet.balance(cur)


func provider() -> V10PaymentProvider:
	return econ.shop.provider


func cash_visible() -> bool:
	return level() >= V10ShopData.SHOP_FROM_LEVEL and V10ShopPay.cash_visible(provider())


# «= N желаний · ≈ N ₽ за желание» — the one value line under every ₽ price (UX §5.2.2, С-3)
static func value_line(c: Dictionary) -> String:
	var parts: = []
	for k in ["eq", "per_wish"]:
		if String(c.get(k, "")) != "":
			parts.append(String(c[k]))
	return " · ".join(parts)


# wishes a SKU is worth: unified in V10Sku / V10Catalog (boosters included at their crystal value, spec Л3)
func pull_value(s: Dictionary, first: bool) -> float:
	return V10Sku.pull_value(s, first)


func ratio(s: Dictionary, first: = false) -> float:
	return V10Sku.ratio(s, first)


func reason_txt(r: String) -> String:
	return V10Sku.reason_txt(r)


# ================================================================ cards
func card(id: String) -> Dictionary:
	var s: = econ.shop.sku(id)
	if s.is_empty():
		return {}
	var first: = econ.shop.is_first(s)
	var g: = V10Catalog.sku_grant(s, first)
	var v: = pull_value(s, first)
	var a: = econ.shop.available(id)
	var c: = {"id": id, "kind": String(s.kind), "rub": int(s.rub), "price": V10ShopTxt.rub(float(s.rub)),
		"wishes": v, "eq": V10ShopTxt.eq_wishes(v) if v > 0.0 else "", "per_wish_rub": float(s.rub) / v if v > 0.0 else INF,
		"per_wish": V10ShopTxt.per_wish(float(s.rub) / v) if v > 0.0 else "", "first": first, "first_txt": "",
		"available": bool(a.ok), "reason": String(a.get("reason", "")), "once": bool(s.get("once", false)),
		"best": false, "lines": [], "overline": "", "title": "", "art": "", "grant": g}
	c.reason_txt = reason_txt(c.reason)
	match String(s.kind):
		"currency":
			var base: = int(s.base.get("moon", 0))
			var got: = int(g.get("moon", 0))
			c.title = V10ShopTxt.amount("moon", got)
			c.overline = "ЛУННЫЙ КАМЕНЬ"
			if first:
				c.first_txt = "Первая покупка: %s + %s" % [V10ShopTxt.num(base), V10ShopTxt.num(base)]
			elif int(s.get("bonus", {}).get("moon", 0)) > 0:
				c.first_txt = "%s + %s в подарок" % [V10ShopTxt.num(base), V10ShopTxt.num(int(s.bonus.moon))]
			c.lines = [c.eq]
			c["sum_txt"] = V10ShopTxt.num(got)
			var idx: = _currency_index(id)
			c.art = V10ShopData.PACK_ART[clampi(idx, 0, 5)]
		"starter":
			c.overline = _ladder_name(id).to_upper()
			c.title = _content_title(g)
			var rest: = _content_parts(g).slice(2)
			c.lines = ([", ".join(rest)] if not rest.is_empty() else []) + ["Один раз, без срока"]
			c.art = _ladder_art(id)
		"month":
			c.overline = "ЛУННЫЙ АБОНЕМЕНТ · 30 ДНЕЙ"
			c.title = "%s сразу + %s в день" % [V10ShopTxt.amount("moon", int(V10Catalog.MONTH_NOW.moon)),
				V10ShopTxt.amount("crystal", int(V10Catalog.MONTH_DAILY.crystal))]
			c.lines = ["Не подписка, без автопродления", "Награды за ролики — без ролика"]
			c.art = "item_month"
		"pass":
			var deluxe: = bool(s.get("deluxe", false))
			var tot: = V10Catalog.pass_track_total(true)
			c.overline = "ПРОПУСК СЕЗОНА+" if deluxe else "ПРОПУСК СЕЗОНА"
			c.title = "Премиум-дорожка: %s + %s" % [V10ShopTxt.amount("crystal", int(tot.get("crystal", 0))),
				V10ShopTxt.amount("wish", int(tot.get("wish", 0)))]
			c.lines = ["SSR-наряд сезона на 30-м уровне"]
			if deluxe:
				c.lines.append("+10 уровней сразу и %s" % V10ShopTxt.amount("moon", int(s.get("grant", {}).get("moon", 0))))
			c.lines.append("Пройденное откроется сразу")
			c.art = "item_pass"
		"outfit":
			c.overline = "НАРЯД"
			c.title = String(s.get("name", id))
			c.lines = ["Навсегда, без случайности"]
	match String(s.kind):
		"currency":
			c["name"] = String(c.title)
		"starter":
			c["name"] = _ladder_name(id)
		"month":
			c["name"] = "Лунный абонемент"
		"pass":
			c["name"] = "Пропуск сезона+" if bool(s.get("deluxe", false)) else "Пропуск сезона"
		_:
			c["name"] = String(s.get("name", id))
	return c


func _currency_index(id: String) -> int:
	var i: = 0
	for s in V10Catalog.SKUS:
		if s.kind == "currency":
			if s.id == id:
				return i
			i += 1
	return 0


func _ladder_entry(id: String) -> Dictionary:
	for e in V10ShopData.LADDER:
		if e.sku == id:
			return e
	return {}


func _ladder_name(id: String) -> String:
	var e: = _ladder_entry(id)
	return String(e.get("name", econ.shop.sku(id).get("name", id)))


func _ladder_art(id: String) -> String:
	return String(_ladder_entry(id).get("art", "set_cup"))


# «450 Лунного камня + 2 000 монет» — the name says what is inside (UX §5.2.3), ≤ 3 kinds
func _content_title(g: Dictionary) -> String:
	var parts: = _content_parts(g)
	return " + ".join(parts.slice(0, 2)) + (" + …" if parts.size() > 2 else "")


func _content_parts(g: Dictionary) -> Array:
	var parts: = []
	for k in ["moon", "crystal", "wish", "coin", "petal", "tea"]:
		if int(g.get(k, 0)) > 0:
			parts.append(V10ShopTxt.amount(k, int(g[k])))
	if g.has("items"):
		parts.append_array(V10ShopTxt.items_line(g.items))
	return parts


func _content_lines(g: Dictionary) -> Array:
	var out: = []
	for p in _content_parts(g):
		out.append(String(p))
	if out.size() > 3:
		out = out.slice(0, 3)
	return out


# ≤ 3 «Ты получишь» lines with real units (UX §5.3)
func receive_lines(c: Dictionary) -> Array:
	var g: Dictionary = c.get("grant", {})
	var out: = []
	match String(c.kind):
		"currency":
			out.append("%s  %s" % [V10ShopTxt.amount("moon", int(g.get("moon", 0))), c.eq])
			if String(c.first_txt) != "":
				out.append(String(c.first_txt))
		"month":
			out.append("%s сразу" % V10ShopTxt.amount("moon", int(V10Catalog.MONTH_NOW.moon)))
			out.append("+%s каждый день, 30 дней (в утреннем подносе)" % V10ShopTxt.amount("crystal", int(V10Catalog.MONTH_DAILY.crystal)))
			out.append("Не подписка, без автопродления")
		"pass":
			out = (c.lines as Array).duplicate()
		_:
			for p in _content_parts(g):
				var line: = String(p)
				if out.size() == 0 and int(g.get("moon", 0)) > 0:
					line += "  = " + V10ShopTxt.wishes(float(g.moon) / float(V10Catalog.PULL_COST))
				out.append(line)
	return out.slice(0, 3)


# ================================================================ tabs
func topup() -> Array:
	var out: = []
	if not cash_visible():
		return out
	for s in V10Catalog.SKUS:
		if s.kind == "currency":
			out.append(card(String(s.id)))
	var bi: = -1
	for i in out.size():
		if bi < 0 or float(out[i].per_wish_rub) < float(out[bi].per_wish_rub) - 0.001:
			bi = i
	# «самый низкий ₽ за желание» only if it is true on the screen too (UX §5.2.3, HUD_V2 §8.5): the best pack's
	# rounded «≈ N ₽» must be below every other pack's. With the first-purchase double every pack reads «≈ 33 ₽» —
	# a label there would nudge a new player to the 3 790 ₽ pack over a 0,01 ₽ difference.
	if bi >= 0:
		var shown_best: = roundi(float(out[bi].per_wish_rub))
		var unique: = true
		for i in out.size():
			if i != bi and roundi(float(out[i].per_wish_rub)) <= shown_best:
				unique = false
		out[bi].best = unique
	return out


func ladder() -> Dictionary:
	var res: = {"current": {}, "next": {}}
	if not cash_visible():
		return res
	var lv: = level()
	var open: = []
	var later: = []
	for e in V10ShopData.LADDER:
		var a: = econ.shop.available(String(e.sku))
		if String(a.get("reason", "")) in ["owned", "expired", "unknown"]:
			continue
		var to: = int(e.to)
		if lv >= int(e.from) and (to == 0 or lv < to):
			open.append(e)
		elif lv < int(e.from):
			later.append(e)
	if not open.is_empty():
		res.current = card(String(open[0].sku))
		if open.size() > 1:
			res.next = {"title": String(open[1].name), "unlock": "Откроется после этой ступени", "art": String(open[1].art)}
	if res.next.is_empty() and not later.is_empty():
		res.next = {"title": String(later[0].name), "unlock": "Откроется: после %d-го уровня" % int(later[0].from), "art": String(later[0].art)}
	return res


func vitrina() -> Array:
	var out: = []
	if not cash_visible():
		return out
	var l: = ladder()
	if not (l.current as Dictionary).is_empty():
		out.append(l.current)
	var m: = card("month_449")
	if not m.is_empty():
		out.append(m)
	if econ.pass_.active() and not bool(econ.pass_.st.prem):
		out.append(card("pass_899"))
	return out.slice(0, 3)


func outfits_petals_open() -> bool:
	return bal("petal") > 0 or int(econ.wallet.st.earned.get("petal", 0)) > 0


func outfits(mode: String = "crystal") -> Array:
	var out: = []
	var src: Array = items_fn.call() if items_fn.is_valid() else []
	for it in src:
		var rar: = String(V10ShopData.RAR_MAP.get(String(it.get("rar", "A")), "A"))
		var price: = 0
		if mode == "petal":
			price = int(V10ShopData.PETAL_PRICE.get(rar, 0))
			if price <= 0:
				continue
		else:
			price = int(it.get("shop", 0))
			if price <= 0:
				continue
		var owned: = owns_fn.is_valid() and bool(owns_fn.call(String(it.id)))
		out.append({"id": String(it.id), "name": String(it.get("name", it.id)), "rar": rar, "hero": String(it.get("hero", "")),
			"img": String(it.get("img", "")), "price": price, "cur": mode, "owned": owned,
			"price_txt": V10ShopTxt.num(price), "eq": V10ShopTxt.eq_wishes(float(price) / float(V10Catalog.PULL_COST)) if mode == "crystal" else ""})
	return out


# crystals/moonstone split for a crystal price (UX §5.3 «Спишется: … → …»)
func crystal_split(price: int) -> Dictionary:
	var c: = mini(bal("crystal"), price)
	var m: = mini(bal("moon"), price - c)
	return {"crystal": c, "moon": m, "short": price - c - m}


func buy_outfit(it: Dictionary) -> Dictionary:
	if bool(it.get("owned", false)):
		return {"ok": false, "reason": "owned"}
	var price: = int(it.price)
	if String(it.cur) == "petal":
		if not econ.wallet.spend("petal", price, "outfit:" + String(it.id)):
			return {"ok": false, "reason": "need", "short": price - bal("petal")}
	else:
		var sp: = crystal_split(price)
		if int(sp.short) > 0:
			return {"ok": false, "reason": "need", "short": int(sp.short)}
		econ.wallet.spend_premium(price, "outfit:" + String(it.id))
	econ.grant({"items": [String(it.id)]}, "shop_outfit")
	return {"ok": true}


# ================================================================ purchase
func spent_30d() -> int:
	return econ.spend.spent_30d()


func cap_30d() -> int:
	return V10Age.cap_30d(st, econ.spend)


func can_buy(id: String) -> Dictionary:
	var s: = econ.shop.sku(id)
	if s.is_empty():
		return {"ok": false, "reason": "unknown"}
	var ag: = V10Age.check(st, int(s.rub), spent_30d())
	if not ag.ok:
		return ag
	return econ.shop.can_buy(id)


func buy(id: String) -> Dictionary:
	var c: = can_buy(id)
	if not c.ok:
		return c
	return econ.shop.buy(id)


func set_test_outcome(status: String) -> void:
	var p: = provider()
	if p is V10StubPay:
		(p as V10StubPay).next_status = status


func pending_orders() -> Array:
	var out: = []
	for oid in econ.shop.st.orders:
		var o: Dictionary = econ.shop.st.orders[oid]
		if String(o.st) == "pending":
			out.append(o)
	return out


func should_ask_pause(receipt: Dictionary) -> bool:
	return not bool(st.cool_asked) and int(receipt.get("rub", 0)) >= V10ShopData.BIG_BUY_ASK_RUB


func answer_pause(yes: bool) -> void:
	st.cool_asked = true
	if yes:
		econ.spend.pause(1)


# ================================================================ «Не хватает»
# smallest pack whose real grant (first-purchase double included) covers the deficit; else the biggest
func cover(deficit: int) -> Dictionary:
	var best: = {}
	for s in V10Catalog.SKUS:
		if s.kind != "currency":
			continue
		var got: = int(V10Catalog.sku_grant(s, econ.shop.is_first(s)).get("moon", 0))
		best = s
		if got >= deficit:
			return card(String(s.id))
	return card(String(best.get("id", ""))) if not best.is_empty() else {}


func need(deficit: int) -> Dictionary:
	var free: = []
	if free_paths_fn.is_valid():
		for f in free_paths_fn.call():
			free.append(f)
	var claim: = econ.pass_.claimable().size() if econ.pass_.active() else 0
	if claim > 0:
		free.append({"text": "Пропуск: %d %s" % [claim, V10ShopTxt.plural(claim, "награда ждёт", "награды ждут", "наград ждут")], "go": "pass"})
	if gift_ready():
		free.append({"text": "Подарок дня: +%s" % V10ShopTxt.amount("crystal", int(V10ShopData.GIFT_DAILY.crystal)), "go": "gift"})
	var w: = bal("wish")
	free.append({"text": "Билеты: %d" % w, "go": ""})
	var res: = {"free": free, "free_none": free.size() <= 1 and w == 0, "moon_note": "", "pack": {}}
	if bal("moon") > 0:
		res.moon_note = "Лунный камень работает как кристаллы"
	if cash_visible():
		res.pack = cover(deficit)
	return res


# ================================================================ gift of the day + ads
func gift_ready() -> bool:
	return int(st.gift.day) != econ.clock.today()


func gift_claim(x2: bool, done: Callable) -> void:
	if not gift_ready():
		done.call({})
		return
	var give: = func(mult: int) -> void:
		var g: = {}
		for k in V10ShopData.GIFT_DAILY:
			g[k] = int(V10ShopData.GIFT_DAILY[k]) * mult
		st.gift.day = econ.clock.today()
		st.gift.x2 = mult > 1
		econ.grant(g, "gift_daily")
		done.call(g)
	if not x2:
		give.call(1)
		return
	ads.show("gift", func(ok: bool):
		give.call(V10ShopData.GIFT_AD_MULT if ok else 1))


# ================================================================ pass
func pass_rows() -> Array:
	var rows: = []
	var p: = econ.pass_
	var tier: = p.tier()
	for i in range(1, V10Catalog.PASS_TIERS + 1):
		var bit: = 1 << (i - 1)
		rows.append({"tier": i, "free": V10Catalog.pass_free(i), "prem": V10Catalog.pass_prem(i), "reached": i <= tier,
			"free_got": (int(p.st.cf) & bit) != 0, "prem_got": (int(p.st.cp) & bit) != 0})
	return rows


func pass_claim_all() -> Array:
	var gs: = econ.pass_.claim_all()
	for g in gs:
		econ.grant(g, "pass")
	return gs


static func grant_text(g: Dictionary) -> String:
	var parts: = []
	for k in ["crystal", "moon", "wish", "coin", "petal", "tea"]:
		if int(g.get(k, 0)) > 0:
			parts.append(V10ShopTxt.amount(k, int(g[k])))
	if g.has("items"):
		for i in g.items:
			parts.append("SSR-наряд сезона" if String(i) == "@season_outfit" else String(i))
	return " + ".join(parts)


# ================================================================ my purchases
func receipts() -> Array:
	var out: = []
	for r in econ.shop.st.receipts:
		out.append(r)
	out.reverse()
	return out


func sku_title(id: String) -> String:
	var c: = card(id)
	if c.is_empty():
		return id
	return String(c.name)


# what the purchase actually gave (a first currency purchase is doubled — the history shows 1 720, not today's 900)
func receipt_title(r: Dictionary) -> String:
	var s: = econ.shop.sku(String(r.get("sku", "")))
	var g: Dictionary = r.get("grant", {}) if r.get("grant") is Dictionary else {}
	if String(s.get("kind", "")) == "currency" and int(g.get("moon", 0)) > 0:
		return V10ShopTxt.amount("moon", int(g.moon))
	return sku_title(String(r.get("sku", "")))
