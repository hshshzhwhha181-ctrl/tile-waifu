class_name V10Sku
extends RefCounted

# V10Sku — the ONLY place in the client that formats ₽ prices, per-wish ruble equivalents, spend-cap ruble reasons,
# and 3× ladder ratios over the unified spec catalog (docs/0.10-spec.md §2.2, docs/INTEGRATION_0.10.md §3.6).
# Reference pack: 1 190 ₽ = 1 090 Лунного камня → 1190 / 1090 * 150 ≈ 163.76 ₽ («≈ 164 ₽ за желание»).

const REF_SKU: = "moon_3000"


static func num(n: int) -> String:
	var s: = str(absi(n))
	var out: = ""
	while s.length() > 3:
		out = "\u00a0" + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func rub(n: float) -> String:
	return num(int(round(n))) + "\u00a0₽"


static func fmt_rub(n: float) -> String:
	var i: = int(round(n))
	var t: = str(i)
	if i >= 1000:
		t = "%d %03d" % [i / 1000, i % 1000]
	return t + " ₽"


static func per_wish(rub_per: float) -> String:
	return "≈ %s за желание" % rub(rub_per)


static func sku(id: String) -> Dictionary:
	return V10Catalog.sku(id)


static func ref_rub_per_pull() -> float:
	var s: = V10Catalog.sku(REF_SKU)
	if s.is_empty():
		return 1190.0 / 1090.0 * float(V10Catalog.PULL_COST)
	return V10Catalog.rub_per_pull(s, false)


static func pull_value(s: Dictionary, first: bool = false) -> float:
	return V10Catalog.pull_value(s, first)


static func rub_per_pull(s: Dictionary, first: bool = false) -> float:
	return V10Catalog.rub_per_pull(s, first)


static func ratio(s: Dictionary, first: bool = false) -> float:
	var r: = rub_per_pull(s, first)
	return 0.0 if r == INF else ref_rub_per_pull() / r


static func cover(need_moon: int, is_first_fn: Callable = Callable()) -> Dictionary:
	var best: = {}
	for s in V10Catalog.SKUS:
		if String(s.get("kind", "")) != "currency":
			continue
		var first: = bool(is_first_fn.call(s)) if is_first_fn.is_valid() else true
		var got: = int(V10Catalog.sku_grant(s, first).get("moon", 0))
		if got >= need_moon:
			return s
		best = s
	return best


static func reason_txt(r: String) -> String:
	match r:
		"server":
			return "Откроется вместе с облачным сохранением"
		"no_provider":
			return "Покупки недоступны в этой сборке"
		"age_limit":
			return "Лимит %s за 30 дней, пока возраст не подтверждён" % rub(V10Catalog.AGE_LIMIT_RUB_30D)
		"own_limit":
			return "Твой лимит трат на 30 дней"
		"paused":
			return "Покупки на паузе"
		"cooldown":
			return "Покупки на паузе до завтра"
		"in_progress":
			return "Ждём подтверждения банка"
		"owned":
			return "Уже твоё"
		"month_max":
			return "Абонемент уже продлён на %d дней" % V10Catalog.MONTH_STACK_MAX
		"no_season":
			return "Сезон ещё не начался"
		"teen_one":
			return "До 18 лет — не дороже %s за покупку" % rub(V10ShopData.TEEN_ONE_RUB)
		"teen_month":
			return "До 18 лет — не больше %s за 30 дней" % rub(V10ShopData.TEEN_MONTH_RUB)
		"age_unset":
			return "Сначала укажи год рождения"
		"age_child":
			return "Покупки недоступны"
	return ""
