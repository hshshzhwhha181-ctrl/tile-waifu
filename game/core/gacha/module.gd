extends RefCounted

# Module manifest "gacha" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "gacha", "order": 190, "step": 3, "selftest": {"scene": "res://scripts/v10/gacha/gacha_demo.tscn", "args": ["--gacha_selftest=1"],
		"fast_args": ["--gacha_selftest=1", "--mc=0.5"], "marker": "GACHA_SELFTEST"},
		"screens": {"summon": "res://scripts/v10/gacha/ui/wish_screen.gd", "odds": "res://scripts/v10/gacha/ui/odds_screen.gd"},
		"nav": {"odds": ["summon", "shop"]},
		"save": {"tickets": 0, "petals": 0, "candles": 0, "pity_std": 0, "s_pity_std": 0, "rates_ver": 2,
			"ostars": {}, "targets": {}, "mastery": {}, "first_pick": "", "first_pick_t": 0,
			"seven": {"days": [], "claimed": [false, false, false, false, false, false, false]}, "v10_gacha": {}},
		"migrator": func(S: Dictionary, _now: int) -> void:
			if int(S.get("ex", 0)) > 0:
				S["petals"] = int(S.get("petals", 0)) + int(S.ex)   # wallet-lint: ok legacy migrator, raw 0.9 dict before any wallet
				S["ex"] = 0
			if bool(S.get("free10", false)):
				S["tickets"] = int(S.get("tickets", 0)) + 10   # wallet-lint: ok legacy migrator, raw 0.9 dict before any wallet
				S["free10"] = false,
		"ensure": func(S: Dictionary) -> void:
			var bk: = V10GachaBank.new(S)
			if is_same(S, G.S):
				bk.live_money = true
				bk.give_fn = func(id: String) -> bool: return G.give_new(id)
			V10Gacha2.new(S, G.ITEMS, bk).ensure(),
		"wire": func() -> void:
			V10Salon.season_cb = func() -> bool:
				return G.econ != null and bool(G.econ.pass_.st.get("prem", false))
			var odds_sc = load("res://scripts/v10/gacha/ui/odds_screen.gd")
			if odds_sc:
				odds_sc.rub_ok_fn = func() -> bool:
					return maxi(0, int(G.S.get("unlocked", 1)) - 1) >= V10ShopData.SHOP_FROM_LEVEL and G.econ != null and V10ShopPay.cash_visible((G.econ as V10Econ).shop.provider)
				odds_sc.register("chest", func(_a: Dictionary) -> Array:
					return [
						{"name": "Сундук главы Пути", "text": "фиксированные кристаллы и монеты"},
						{"name": "Звёздный сундук главы", "text": "фиксированные кристаллы и Лепестки"},
						{"name": "Сундук зоны Салона", "text": "фиксированные награды зоны"},
						{"name": "Лестница возврата", "text": "фиксированные подарки по дням"},
					])
			var seven_fn: = func(_key: String) -> Array:
				if int(G.S.get("unlocked", 1)) < 4 and V10Seven.claimable(G.S).is_empty():
					return []
				var give_fn: = func(rw: Dictionary) -> void:
					var kd: = String(rw.get("kind", ""))
					if kd in ["tickets", "gems", "coins"]:
						V10Money.grant({kd: int(rw.get("n", 0))}, "seven")
					elif kd == "item":
						G.give_new(String(rw.get("id", "")))
					elif kd == "cos":
						V10ProfileCos.grant(G.S, String(rw.get("id", "")))
				var rows: = V10Seven.tray_items(G.S, give_fn)
				for c in rows:
					var ic: = String(c.get("icon", "ticket"))
					c["icon"] = V8Art.cur(ic) if ic in ["ticket", "gem", "coin"] else V8Art.icon("gift")
					c["rewards"] = {}
				return rows
			V10Tray.register("seven", seven_fn, 70)
			var month_fn: = func(_key: String) -> Dictionary:
				if G.econ == null or not G.econ.shop.month_can_claim():
					return {}
				var n: = int(V10Catalog.MONTH_DAILY.crystal)
				return {"icon": "res://assets/v10/shop/item_month.png", "title": "Лунный абонемент",
					"text": "+%d кристаллов" % n, "rewards": {},
					"claim": func() -> void:
						G.econ.shop.month_claim()
						V10Money.sync(G.S)}
			V10Tray.register("month_card", month_fn, 75)
	}
