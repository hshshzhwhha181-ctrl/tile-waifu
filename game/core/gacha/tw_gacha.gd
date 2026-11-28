class_name TWGacha
extends RefCounted

# TWGacha (P09 / WP6): the ONE entry point of a wish. It pays, rolls, grants and writes the journal, over V10Gacha2 (the
# rules of the live game: pity counters, 50/50, candles, history log) and V10Rates (the only odds numbers). The old second
# engine (core/economy/econ_gacha.gd + econ_odds.gd, ~520 lines) and the pull / roll proxies of g.gd with their «proxy tickets»
# are gone.
#
#   TWGacha.pull(state, banner, n, opts = {}) -> Dictionary
#       state    the save dictionary (G.S in the game, any dictionary in a test)
#       banner   an element of V10Gacha2.banners() / V10Banners (kind newbie | phase | std)
#       n        number of wishes
#       opts     gacha : V10Gacha2   reuse a built engine (the Wishes screen keeps one: signals, rng, the history cache)
#                items : Array       the item list when no engine is given (default: the items of the engine's caller)
#                bank  : V10GachaBank how money and grants are routed when no engine is given (default: the plain bank on state)
#                seed  : int         fixed rng seed (tests, replays); omitted = random as before
#                free  : bool        a gifted wish: nothing is paid, the counters and the grant work as for a bought one
#                                    (replaces the old «grant n tickets then spend them» proxy)
#   returns  {ok, reason, res, paid, ledger, gacha}
#       ok       false when nothing happened: reason "bad_count" | "insufficient" (not enough tickets / crystals / moonstone,
#                or more beginner wishes than are left) | "no_free_newbie" (a gift never eats the beginner banner)
#       res      Array of V10Gacha2 results (rar A/S/SSR, id, item, new, star, petals, gems, featured, won, guaranteed ...)
#       paid     {tickets, gems, moon}: what this pull took from the wallet
#       ledger   Array of {cur, delta, src}: EVERY wallet movement of this pull in order (the payment, the petals and crystals
#                of duplicates). state balance after = balance before + sum(delta) per currency: the journal invariant
#       gacha    the engine used (counters: pity / guar / newbie_left ...)

static func engine(state: Dictionary, items: Array, bank: V10GachaBank = null) -> V10Gacha2:
	return V10Gacha2.new(state, items, bank)


static func pull(state: Dictionary, banner: Dictionary, n: int, opts: Dictionary = {}) -> Dictionary:
	var g: V10Gacha2 = opts.get("gacha", null)
	if g == null:
		g = engine(state, opts.get("items", []), opts.get("bank", null))
	var none: = {"ok": false, "reason": "", "res": [], "paid": {}, "ledger": [], "gacha": g}
	if n <= 0:
		none.reason = "bad_count"
		return none
	var free: bool = bool(opts.get("free", false))
	var sp: = {"tickets": 0, "gems": 0, "moon": 0, "ok": true}
	if free:
		if String(banner.get("kind", "")) == "newbie":
			none.reason = "no_free_newbie"
			return none
	else:
		sp = g.split(banner, n)
		if not bool(sp.ok):
			none.reason = "insufficient"
			return none
	if opts.has("seed"):
		g.rng.seed = int(opts.seed)
	var bk: = g.bank
	var was: = bk.record
	bk.record = true
	bk.ledger = []
	var res: = g.pull(banner, n, free)
	var ledger: Array = bk.ledger
	bk.ledger = []
	bk.record = was
	if res.is_empty():
		none.reason = "insufficient"
		return none
	return {"ok": true, "reason": "", "res": res, "paid": {"tickets": int(sp.tickets), "gems": int(sp.gems), "moon": int(sp.moon)},
		"ledger": ledger, "gacha": g}
