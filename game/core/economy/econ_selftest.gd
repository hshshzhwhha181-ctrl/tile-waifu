class_name V10EconSelftest
extends RefCounted

# Economy core selftest. Run headless:
#   flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/economy/econ_selftest.tscn -- --econ_selftest=1
# prints «ECON_SELFTEST ok/total» (exit code 0 only when every check passed) and every failed check.
# --econ_mc=N is kept for the runner's fast mode (the gacha Monte-Carlo moved to TWGACHA_SELFTEST / GACHA_SELFTEST in P09).
#
# Sections: catalog & store rules · clock anti-cheat · wallet · shop purchase flow (stub provider) · refunds · restore ·
# spending protection · pass · Constellation stars · save/seal/migration. The summon engine (rules, odds, payment) is
# TWGacha.pull over V10Gacha2: see TWGACHA_SELFTEST and GACHA_SELFTEST.

static var ok: = 0
static var total: = 0
static var fails: = []
static var T0: = 0
static var mc_scale: = 1.0


static func _check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		printerr("ECON_SELFTEST FAIL: " + what)


static func _near(a: float, b: float, tol: float, what: String) -> void:
	_check(absf(a - b) <= tol, "%s: %f vs %f (tol %f)" % [what, a, b, tol])


static func run(scale: float = 1.0) -> int:
	ok = 0
	total = 0
	fails = []
	mc_scale = scale
	T0 = int(Time.get_unix_time_from_datetime_string("2027-03-01T09:00:00"))   # 12:00 MSK
	var t: = Time.get_ticks_msec()
	_catalog()
	_clock()
	_wallet()
	_tw_wallet()
	_tw_wallet_property()
	_shop()
	_refunds_restore()
	_spend()
	_pass()
	_summon_flow()
	_save()
	_review()
	print("ECON_SELFTEST %d/%d (%.1f s)" % [ok, total, float(Time.get_ticks_msec() - t) / 1000.0])
	return ok


# ---------------------------------------------------------------- helpers
static func _econ(prov: V10PaymentProvider = null, state: Dictionary = {}) -> V10Econ:
	return V10Econ.new(state, prov, [], T0)


static func _adv(e: V10Econ, sec: int) -> void:
	e.clock.set_manual(e.clock._m_wall + sec, e.clock._m_mono + sec * 1000)


static func _stub() -> V10StubPay:
	var p: = V10StubPay.new()
	p.force = true
	p.t = T0
	return p


# ================================================================= catalog
static func _catalog() -> void:
	var bad: = V10Catalog.validate()
	_check(bad.is_empty(), "catalog passes the store rules: %s" % str(bad))
	_near(V10Catalog.base_rub_per_pull(), 1190.0 / 1090.0 * 150.0, 0.01, "reference pack ₽ per wish (spec §2.2)")
	var mx: = 0
	for s in V10Catalog.SKUS:
		mx = maxi(mx, int(s.rub))
		_check(V10Catalog.pull_value(s, false) > 0.0, "%s has a pull value for «≈ N ₽ за желание»" % s.id)
		_check(V10Catalog.ladder_ratio(s, false) <= V10Catalog.LADDER_MAX + 1e-6, "%s ladder ≤ 3×" % s.id)
		if s.kind == "currency":
			_check(V10Catalog.ladder_ratio(s, true) <= V10Catalog.LADDER_MAX + 1e-6, "%s first purchase ≤ 3×" % s.id)
			_check(bool(s.requires_server), "%s consumable needs the server wallet" % s.id)
	_check(mx <= 4990, "no SKU above 4990 ₽")
	var month: = V10Catalog.sku("month_449")
	_near(V10Catalog.ladder_ratio(month), 2.92, 0.1, "month card ≈ 2.92× (spec Л4)")
	_near(V10Catalog.ladder_ratio(V10Catalog.sku("pass_899")), 2.13, 0.15, "pass ≈ 2.13× (spec Л5)")
	_check(not bool(month.get("requires_server", false)) and bool(month.restorable), "month card is restorable without the server")
	# a deliberately broken SKU is caught by the validator
	var orig: Array = V10Catalog.SKUS
	var cheap: = {"id": "evil", "kind": "starter", "rub": 149, "grant": {"moon": 12000}}
	_check(V10Catalog.ladder_ratio(cheap) > 3.0, "validator math flags a 10× offer like the old «1200 + SSR за 149 ₽»")
	_check(V10Catalog.ladder_ratio(V10Catalog.sku("moon_180"), true) <= 2.0 + 1e-6, "first purchase double ≤ 2×")
	# rate schedule = V10Rates v2 (spec Г1)
	_near(V10Catalog.ssr_rate(1), 0.016, 1e-9, "SSR 1.6 % at pull 1")
	_near(V10Catalog.ssr_rate(45), 0.016, 1e-9, "SSR 1.6 % at pull 45")
	_near(V10Catalog.ssr_rate(46), 0.076, 1e-9, "soft pity: 7.6 % at pull 46")
	_near(V10Catalog.ssr_rate(59), 0.856, 1e-9, "soft pity: 85.6 % at pull 59")
	_near(V10Catalog.ssr_rate(60), 1.0, 1e-9, "hard pity at 60")
	_check(V10Catalog.fmt_rub(4990) == "4 990 ₽" and V10Catalog.fmt_rub(79) == "79 ₽", "ruble format")
	var tot: = V10Catalog.pass_track_total(true)
	_check(int(tot.get("wish", 0)) == 5 and int(tot.get("crystal", 0)) == 1000, "premium track total 1000 crystals + 5 wishes (spec Л5): %s" % str(tot))
	_check(orig.size() == V10Catalog.SKUS.size(), "catalog untouched")


# ================================================================= clock
static func _clock() -> void:
	var cs: = {}
	var c: = V10Clock.new(cs)
	c.set_manual(T0, 0)
	_check(c.now() == T0, "manual clock")
	c.set_manual(T0 + 60, 60000)
	_check(c.now() == T0 + 60, "clock follows a consistent wall + monotonic clock")
	# player moves the wall clock 1 h back while the game runs → ignored, monotonic time keeps going
	c.set_manual(T0 - 3600 + 70, 70000)
	_check(c.now() == T0 + 70 and int(cs.jumps) == 1, "in-session backward jump ignored and counted (%d)" % c.now())
	c.set_manual(T0 - 3600 + 80, 80000)
	_check(c.now() == T0 + 80 and int(cs.jumps) == 1, "jump counted once, monotonic time keeps going")
	# … and moved forward again to the real time: no gain (re-anchors on the wall clock)
	c.set_manual(T0 + 90, 90000)
	_check(c.now() == T0 + 90 and int(cs.fwd) == 1, "back-then-forward gives no extra time (%d)" % c.now())
	# device slept 8 h with the game in background: wall ran ahead, Android's monotonic clock stood still → accepted
	c.set_manual(T0 + 90 + 8 * 3600, 91000)
	_check(c.now() == T0 + 90 + 8 * 3600 and int(cs.fwd) == 2, "sleep with the game in background counts (%d)" % c.now())
	c.set_manual(T0 + 100 + 8 * 3600, 101000)
	_check(c.now() == T0 + 100 + 8 * 3600, "after the sleep time follows the monotonic clock again")
	var hwm: = T0 + 100 + 8 * 3600
	# new session with the clock rolled back a day → time frozen at the high-water mark
	c.new_session(T0 - 86400)
	_check(c.now() == hwm and int(cs.rollbacks) == 1, "rollback across sessions freezes time")
	c.set_manual(T0 - 86400 + 100, 100000)
	_check(c.now() == hwm and int(cs.rollbacks) == 1, "still frozen, rollback counted once")
	# resume() drops server time (monotonic clock missed the sleep) until the next sync
	var c3: = V10Clock.new({})
	c3.new_session(T0)
	c3.sync_server(T0 + 10)
	c3.set_manual(T0 + 7200, 1000)
	c3.resume()
	_check(not c3.trusted() and c3.now() == T0 + 7200, "resume: back to the wall clock until the next server sync")
	# a small NTP correction is not a rollback
	var c2: = V10Clock.new({})
	c2.new_session(T0)
	c2.now()
	c2.new_session(T0 - 3)
	_check(c2.now() == T0 and int(c2.st.rollbacks) == 0, "3 s NTP correction is not a rollback")
	# server time wins
	c.sync_server(T0 + 500)
	_check(c.trusted() and c.now() == T0 + 500, "server time overrides the device clock")
	c.set_manual(T0, 110000)
	_check(c.now() == T0 + 510, "server time advances with the monotonic clock")
	# Moscow day boundary: 20:59 UTC and 21:00 UTC are different days
	var d1: = int(Time.get_unix_time_from_datetime_string("2027-03-01T20:59:00"))
	_check(V10Clock.day_key(d1) == "2027-03-01" and V10Clock.day_key(d1 + 60) == "2027-03-02", "daily reset at 00:00 MSK")
	_check(V10Clock.day_index(d1 + 60) == V10Clock.day_index(d1) + 1, "day index steps at midnight MSK")


# ================================================================= wallet
static func _wallet() -> void:
	var w: = V10Wallet.new({})
	_check(w.add("crystal", 100, "t") == 100 and w.balance("crystal") == 100, "add crystals")
	_check(w.add("nope", 5) == 0, "unknown currency ignored")
	_check(not w.spend("crystal", 101), "cannot overspend")
	_check(w.balance("crystal") == 100, "failed spend changes nothing")
	w.add("moon", 200, "buy")
	var p: = w.spend_premium(150, "pull")
	_check(p.get("crystal", -1) == 100 and p.get("moon", -1) == 50, "free crystals spent before paid moonstone")
	_check(w.spend_premium(1000).is_empty(), "premium overspend refused")
	var d: = w.revoke("moon", 500, "refund")
	_check(d == 350 and w.balance("moon") == 0 and w.debt("moon") == 350, "refund clawback → debt, never negative")
	_check(w.add("moon", 400, "buy") == 50 and w.balance("moon") == 50 and w.debt("moon") == 0, "new moonstone pays the debt first")
	_check(w.audit().is_empty(), "wallet invariant holds: %s" % str(w.audit()))
	w.st.bal.crystal = 99999
	_check(not w.audit().is_empty(), "edited balance breaks the invariant")
	_check(w.st.log.size() > 0 and w.st.log.size() <= V10Wallet.LOG_MAX, "operation log kept and capped")


# ================================================================= TWWallet (P10): the typed API, errors, the property test
static func _tw_wallet() -> void:
	var S: = {"gems": 100, "coins": 50, "unlocked": 3}
	var tw: = TWWallet.for_state(S)
	_check(tw.bal("gems") == 100 and tw.bal("coins") == 50 and tw.bal("crystal") == 100, "TWWallet: opens with the 0.9 balances (glossary and wallet keys)")
	_check(S.econ is Dictionary and V10Wallet.new(S.econ.wallet).audit().is_empty(), "TWWallet: the wallet lives in S.econ.wallet, invariant holds")
	var g: = tw.grant({"gems": 25, "tickets": 2}, "t")
	_check(bool(g.ok) and g.events.size() == 2 and str(g.events[0].type) == "WALLET_CHANGED" and int(g.events[0].delta) == 25 and int(g.events[0].bal) == 125,
		"TWWallet.grant returns WALLET_CHANGED events {cur, delta, bal, src}")
	_check(int(S.gems) == 125 and int(S.tickets) == 2, "TWWallet: the snapshot S.gems / S.tickets follows the wallet")
	var sp: = tw.spend({"gems": 25, "coins": 10}, "t")
	_check(bool(sp.ok) and sp.events.size() == 2 and int(sp.events[1].delta) == -10 and tw.bal("gems") == 100 and tw.bal("coins") == 40, "TWWallet.spend pays all lines")
	var snap: = JSON.stringify(S.econ.wallet)
	var ins: = tw.spend({"gems": 10, "coins": 41}, "t")
	_check(not bool(ins.ok) and str(ins.error) == "insufficient" and ins.events.is_empty() and JSON.stringify(S.econ.wallet) == snap, "TWWallet.spend is all or nothing (insufficient: nothing moved)")
	var e0: = TWWallet.errors
	var ng: = tw.grant({"gems": -5}, "t")
	_check(not bool(ng.ok) and str(ng.error) == "negative_amount" and TWWallet.errors == e0 + 1 and TWWallet.last_error.begins_with("negative_amount"),
		"a NEGATIVE grant is an error (reported, counted), not a silent clamp")
	_check(JSON.stringify(S.econ.wallet) == snap and int(S.gems) == 100, "...and it changes nothing")
	var mix: = tw.grant({"gems": 7, "coins": -1}, "t")
	_check(not bool(mix.ok) and JSON.stringify(S.econ.wallet) == snap, "a bundle with one negative line applies none of it")
	_check(str(tw.grant({"nope": 5}, "t").error) == "unknown_currency" and JSON.stringify(S.econ.wallet) == snap, "an unknown currency is an error, nothing changes")
	_check(bool(tw.grant({"gems": 0}, "t").ok) and bool(tw.grant({"tea": 3}, "t").ok) and JSON.stringify(S.econ.wallet) == snap, "zero and the legacy 'tea' key are no-ops")
	_check(str(tw.spend({"gems": -5}, "t").error) == "negative_amount" and JSON.stringify(S.econ.wallet) == snap, "a negative spend is an error too (it would be a grant in disguise)")
	var w0: = V10Wallet.errors
	_check(tw.w.add("crystal", -9, "t") == 0 and V10Wallet.errors == w0 + 1 and tw.bal("gems") == 100, "V10Wallet.add(-n) is refused and counted, not clamped")
	var sb: = tw.set_balance("gems", 12450, "dev")
	_check(bool(sb.ok) and tw.bal("gems") == 12450 and int(S.gems) == 12450 and tw.audit().is_empty(), "set_balance moves the balance through wallet operations")
	_check(bool(tw.set_balance("gems", 3, "dev").ok) and tw.bal("gems") == 3 and tw.audit().is_empty() and not bool(tw.set_balance("gems", -1).ok), "set_balance down is a spend; a negative target is refused")
	# a direct write of the snapshot is undone and counted, never turned into money
	var dw0: = TWWallet.direct_writes
	S.gems = 99999   # wallet-lint: ok the test of the guard itself
	_check(tw.bal("gems") == 3 and int(S.gems) == 3 and TWWallet.direct_writes == dw0 + 1, "a direct write of S.gems is undone (wallet is the truth) and counted")
	# the save round trip keeps the wallet (JSON in, JSON out)
	var back = JSON.parse_string(JSON.stringify(S))
	TWWallet.forget()
	var tw2: = TWWallet.for_state(back)
	_check(tw2.bal("gems") == 3 and tw2.bal("coins") == 40 and tw2.bal("tickets") == 2 and tw2.audit().is_empty(), "save -> load: the same balances, invariant holds")
	TWWallet.forget()


# 12000 random operations on one wallet against an independent shadow ledger. After EVERY operation:
#   balance - debt == earned - spent - revoked (audit), no negative number, the snapshot == the wallet, the shadow == the wallet;
#   an invalid operation (negative, unknown currency) changes nothing.
static func _tw_wallet_property() -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 20261128
	var S: = {"gems": 500, "coins": 200}
	var tw: = TWWallet.for_state(S)
	var keys: = ["gems", "coins", "moon", "tickets", "petals"]
	var wk: = {"gems": "crystal", "coins": "coin", "moon": "moon", "tickets": "wish", "petals": "petal"}
	var sh_b: = {}      # shadow balance / debt / earned / spent / revoked
	var sh_d: = {}
	var sh_e: = {}
	var sh_s: = {}
	var sh_r: = {}
	for k in keys:
		var c: String = wk[k]
		sh_b[c] = tw.bal(k)
		sh_d[c] = 0
		sh_e[c] = int(tw.w.st.earned[c])
		sh_s[c] = 0
		sh_r[c] = 0
	var n_ops: = 12000
	var bad_inv: = 0
	var bad_shadow: = 0
	var bad_snap: = 0
	var bad_invalid: = 0
	var denied: = 0
	var done_by: = {"grant": 0, "spend": 0, "revoke": 0, "premium": 0, "set": 0, "invalid": 0}
	for i in n_ops:
		var op: = rng.randi_range(0, 99)
		var k: String = keys[rng.randi_range(0, keys.size() - 1)]
		var c: String = wk[k]
		var n: = rng.randi_range(0, 400) if rng.randi_range(0, 9) != 0 else rng.randi_range(0, 100000)
		if op < 34:
			done_by.grant += 1
			var r: = tw.grant({k: n}, "p")
			var pay: = mini(int(sh_d[c]), n)
			sh_d[c] -= pay
			sh_b[c] += n - pay
			sh_e[c] += n
			if not bool(r.ok):
				bad_shadow += 1
		elif op < 62:
			done_by.spend += 1
			var r2: = tw.spend({k: n}, "p")
			if int(sh_b[c]) >= n:
				sh_b[c] -= n
				sh_s[c] += n
				if not bool(r2.ok):
					bad_shadow += 1
			else:
				denied += 1
				if bool(r2.ok) or str(r2.error) != "insufficient":
					bad_shadow += 1
		elif op < 72:
			done_by.revoke += 1
			tw.w.revoke(c, n, "refund")
			var take: = mini(int(sh_b[c]), n)
			sh_b[c] -= take
			sh_d[c] += n - take
			sh_r[c] += n
			tw.write_mirrors()
		elif op < 80:
			done_by.premium += 1
			var pr: = tw.w.spend_premium(n, "p")
			if int(sh_b["crystal"]) + int(sh_b["moon"]) >= n:
				var a: = mini(int(sh_b["crystal"]), n)
				sh_b["crystal"] -= a
				sh_s["crystal"] += a
				sh_b["moon"] -= n - a
				sh_s["moon"] += n - a
				if pr.is_empty() and n > 0:
					bad_shadow += 1
			elif not pr.is_empty():
				bad_shadow += 1
			tw.write_mirrors()
		elif op < 88:
			done_by.set += 1
			var target: = rng.randi_range(0, 3000)
			tw.set_balance(k, target, "p")
			var d: = target - int(sh_b[c])
			if d > 0:
				var pay2: = mini(int(sh_d[c]), d)
				sh_d[c] -= pay2
				sh_b[c] += d - pay2
				sh_e[c] += d
			elif d < 0:
				sh_b[c] += d
				sh_s[c] -= d
		else:
			done_by.invalid += 1
			var before: = JSON.stringify(tw.w.st)
			var inv: Dictionary
			match rng.randi_range(0, 3):
				0: inv = tw.grant({k: -rng.randi_range(1, 500)}, "p")
				1: inv = tw.grant({"bogus": rng.randi_range(1, 500)}, "p")
				2: inv = tw.spend({k: -rng.randi_range(1, 500)}, "p")
				_: inv = tw.grant({k: n, "coins": -1}, "p")
			if bool(inv.ok) or JSON.stringify(tw.w.st) != before:
				bad_invalid += 1
		# the invariants, after every operation
		if not tw.audit().is_empty():
			bad_inv += 1
		for k2 in keys:
			var c2: String = wk[k2]
			if tw.bal(k2) != int(sh_b[c2]) or tw.w.debt(c2) != int(sh_d[c2]) or int(tw.w.st.earned[c2]) != int(sh_e[c2]) \
					or int(tw.w.st.spent[c2]) != int(sh_s[c2]) or int(tw.w.st.revoked[c2]) != int(sh_r[c2]):
				bad_shadow += 1
			if tw.bal(k2) < 0 or tw.w.debt(c2) < 0:
				bad_inv += 1
			if (k2 in ["gems", "coins"] or S.has(k2)) and int(S[k2]) != tw.bal(k2):
				bad_snap += 1
	_check(n_ops >= 10000, "wallet property test: %d random operations (grant %d, spend %d [%d denied], revoke %d, premium %d, set_balance %d, invalid %d)" % [
		n_ops, done_by.grant, done_by.spend, denied, done_by.revoke, done_by.premium, done_by.set, done_by.invalid])
	_check(bad_inv == 0, "wallet property test: balance - debt == earned - spent - revoked and no negative number after every operation (%d violations)" % bad_inv)
	_check(bad_shadow == 0, "wallet property test: the wallet equals an independent shadow ledger after every operation (%d differences)" % bad_shadow)
	_check(bad_snap == 0, "wallet property test: the S.gems / S.coins snapshot equals the wallet after every operation (%d differences)" % bad_snap)
	_check(bad_invalid == 0, "wallet property test: every negative / unknown-currency operation was refused and changed nothing (%d leaks)" % bad_invalid)
	_check(int(done_by.revoke) > 500 and int(done_by.premium) > 500 and denied > 500, "wallet property test: refund, premium-spend and denied-spend paths were all exercised")
	TWWallet.forget()


# ================================================================= shop & purchase flow
static func _shop() -> void:
	var p: = _stub()
	var e: = _econ(p)
	var sh: = e.shop
	_check(sh.available("moon_180").reason == "server", "consumables locked until the server wallet exists")
	_check(sh.can_buy("month_449").ok, "month card sellable before the server (restorable)")
	_check(sh.available("pass_899").reason == "no_season", "no pass without a season")
	sh.caps.server_wallet = true
	e.spend.set_age_verified(true)
	# first pack: double; second: normal bonus
	var r: = sh.buy("moon_180")
	_check(r.ok and e.wallet.balance("moon") == 120, "first purchase doubled (%d)" % e.wallet.balance("moon"))
	var rc: Dictionary = sh.st.receipts[0]
	_check(rc.st == "confirmed" and rc.sku == "moon_180" and rc.rub == 79 and rc.first, "receipt written and confirmed")
	sh.buy("moon_180")
	_check(e.wallet.balance("moon") == 180, "second purchase without the first bonus")
	_check(p.confirms == 2, "every delivery confirmed with the store")
	# cancel / fail
	p.next_status = "cancelled"
	var rcan: = sh.buy("moon_900")
	_check(rcan.ok and sh.st.orders[rcan.oid].st == "cancelled" and e.wallet.balance("moon") == 180, "cancelled: nothing granted")
	p.next_status = "failed"
	var rf: = sh.buy("moon_900")
	_check(sh.st.orders[rf.oid].st == "failed" and sh.st.receipts.size() == 2, "failed: nothing granted, no receipt")
	# pending → completes later
	p.next_status = "pending"
	var rp: = sh.buy("moon_900")
	_check(sh.st.orders[rp.oid].st == "pending", "pending order")
	_check(sh.can_buy("moon_900").reason == "in_progress", "no second order while one is pending")
	p.complete(rp.oid, "paid")
	_check(sh.st.orders[rp.oid].st == "delivered" and e.wallet.balance("moon") == 180 + 600, "pending order delivered when paid")
	# duplicate store callback → delivered once
	p.next_status = "paid"
	p.duplicate = true
	sh.buy("moon_3000")
	p.duplicate = false
	var n3: int = sh.st.receipts.filter(func(x): return x.sku == "moon_3000").size()
	_check(n3 == 1 and e.wallet.balance("moon") == 780 + 1960, "duplicate callback delivers once")
	# crash between payment and delivery: callback lost → reconcile delivers and confirms
	p.instant = false
	sh.buy("moon_6000")
	p.restart()
	_check(e.wallet.balance("moon") == 2740, "nothing delivered before the callback")
	var done: = sh.reconcile()
	_check(done.size() == 1 and e.wallet.balance("moon") == 2740 + 3960, "reconcile delivers a paid, undelivered purchase")
	_check(sh.st.receipts[-1].st == "confirmed", "and confirms it")
	_check(sh.reconcile().is_empty(), "reconcile is idempotent")
	p.instant = true
	# confirm fails (crash after delivery) → reconcile only confirms
	p.fail_confirm = true
	sh.buy("moon_180")
	_check(sh.st.receipts[-1].st == "delivered", "delivered but unconfirmed")
	var before: = e.wallet.balance("moon")
	p.fail_confirm = false
	sh.reconcile()
	_check(sh.st.receipts[-1].st == "confirmed" and e.wallet.balance("moon") == before, "reconcile confirms without re-delivering")
	# once-only and progress gates (spec Л3: no calendar expiry on starter sets)
	_check(sh.buy("first_79").ok and e.wallet.balance("coin") == 2000, "first purchase set")
	_check(sh.can_buy("first_79").reason == "owned", "once-only set cannot be bought twice")
	var offers: = sh.offers()
	var guest: Array = offers.filter(func(o): return o.id == "guest_149")
	_check(guest.size() == 1 and int(guest[0].until) == 0, "beginner set has no calendar expiry (gated by Path level)")
	_check(String(guest[0].per_pull).begins_with("≈ ") and String(guest[0].per_pull).ends_with("₽ за желание"), "«≈ N ₽ за желание» on offers")
	_check(offers.filter(func(o): return o.id == "first_79").is_empty(), "bought once-only set leaves the list")
	_adv(e, 15 * 86400)
	_check(sh.available("guest_149").ok, "beginner set remains available until bought (no 14-day timer)")
	# month card
	var m0: = e.wallet.balance("moon")
	_check(sh.buy("month_449").ok and e.wallet.balance("moon") == m0 + 300, "month card: 300 now")
	_check(sh.month_days_left() == 30 and sh.ad_free(), "30 days, ads skipped")
	var c0: = e.wallet.balance("crystal")
	_check(not sh.month_claim().is_empty() and sh.month_claim().is_empty(), "30 crystals once a day")
	_check(e.wallet.balance("crystal") == c0 + 30, "daily 30 (spec Л4)")
	_adv(e, 86400)
	_check(not sh.month_claim().is_empty() and sh.month_days_left() == 29, "next day claim, 29 days left")
	for i in 4:
		sh.buy("month_449")
	_check(sh.month_days_left() == 149, "month cards stack (%d)" % sh.month_days_left())
	_check(sh.buy("month_449").ok and sh.can_buy("month_449").reason == "month_max", "stack capped at 180 days")
	_check(sh.month_days_left() == 179, "179 days")
	_adv(e, 200 * 86400)
	_check(sh.month_days_left() == 0 and not sh.ad_free() and sh.month_claim().is_empty(), "month card expires")
	# provider missing / release build
	var e2: = _econ(null)
	_check(e2.shop.can_buy("month_449").reason == "no_provider", "no provider → no purchase")
	var rel: = V10StubPay.new()
	_check(rel.is_available() == OS.has_feature("editor"), "stub store only in the editor, never in an exported APK")
	_check(e.audit().filter(func(x): return not x.begins_with("clock")).is_empty(), "economy audit clean after purchases: %s" % str(e.audit()))


static func _refunds_restore() -> void:
	var p: = _stub()
	var e: = _econ(p)
	e.shop.caps.server_wallet = true
	e.spend.set_age_verified(true)
	e.shop.buy("moon_3000")         # 1960 moon (first)
	var pid: String = e.shop.st.receipts[0].pid
	e.wallet.spend_premium(1800, "pull")
	p.refund(pid)
	_check(e.shop.receipt(pid).st == "refunded", "refund notice marks the receipt")
	_check(e.wallet.balance("moon") == 0 and e.wallet.debt("moon") == 1800, "spent refunded moonstone becomes debt (%d)" % e.wallet.debt("moon"))
	_check(e.spend.spent_30d() == 0, "refunded purchase leaves the 30-day total")
	_check(not e.shop.refund(pid), "refund is idempotent")
	_check(not e.shop.refund("nope"), "unknown refund ignored")
	e.shop.buy("moon_180")
	_check(e.wallet.debt("moon") == 1800 - 120 and e.wallet.balance("moon") == 0, "next purchase pays the debt first")
	_check(e.wallet.audit().is_empty(), "wallet invariant after refunds")
	# month card refund
	e.shop.buy("month_449")
	e.shop.buy("month_449")
	var mpid: String = e.shop.st.receipts[-1].pid
	e.shop.refund(mpid)
	_check(e.shop.month_days_left() == 30, "refunded month card removes its 30 days")
	# pass refund claws back claimed premium rewards
	e.pass_.rollover("s1", T0, T0 + 42 * 86400)
	e.pass_.add_xp(1000)
	e.shop.buy("pass_899")
	var ppid: String = e.shop.st.receipts[-1].pid
	var cr0: = e.wallet.balance("crystal")
	for g in e.pass_.claim_all():
		e.grant(g, "pass")
	var got: = e.wallet.balance("crystal") - cr0
	_check(got > 0, "pass rewards claimed")
	var revoked: = []
	e.item_revoked.connect(func(id, _s): revoked.append(id))
	e.shop.refund(ppid)
	_check(not bool(e.pass_.st.prem) and int(e.pass_.st.cp) == 0, "pass refund: premium off")
	_check(int(e.wallet.st.revoked.crystal) == 306, "pass refund claws back premium crystals (%d)" % int(e.wallet.st.revoked.crystal))
	# restore on a fresh install: entitlements back, currency not re-granted
	var p2: = _stub()
	var e3: = _econ(p2)
	e3.pass_.rollover("s1", T0, T0 + 42 * 86400)
	e3.shop.buy("month_449")
	e3.shop.buy("pass_1490")
	var fresh: = _econ(p2)
	fresh.pass_.rollover("s1", T0, T0 + 42 * 86400)
	_adv(fresh, 3 * 86400)
	var res: = fresh.shop.reconcile()
	_check(res.size() == 2, "restore month card + pass on a fresh install (%d)" % res.size())
	_check(fresh.shop.month_days_left() == 27 and bool(fresh.pass_.st.prem) and bool(fresh.pass_.st.deluxe), "restored: remaining days and premium")
	_check(fresh.wallet.balance("moon") == 0, "restore never re-grants currency")
	_check(fresh.shop.reconcile().is_empty(), "restore once")


# ================================================================= spending protection
static func _spend() -> void:
	var p: = _stub()
	var e: = _econ(p)
	e.shop.caps.server_wallet = true
	var sp: = e.spend
	_check(sp.room() == 3000, "unverified: 3000 ₽ per 30 days")
	_check(e.shop.buy("moon_6000").ok, "2290 ₽ ok")
	_check(e.shop.buy("month_449").ok, "449 ₽ ok (2739)")
	var c: = e.shop.can_buy("moon_900")
	_check(not c.ok and c.reason == "age_limit" and int(c.room) == 261, "limit until 18+ is verified (%s)" % str(c))
	_adv(e, 31 * 86400)
	_check(e.shop.can_buy("moon_900").ok, "rolling 30-day window frees the limit")
	sp.set_age_verified(true)
	_check(sp.room() == -1, "verified adult without own limit: no cap")
	sp.set_limit(500)
	_check(sp.limit() == 500 and sp.check(1190).reason == "own_limit", "own limit applies at once when lowered")
	sp.set_limit(5000)
	_check(sp.limit() == 500, "raising the own limit waits 24 h")
	_adv(e, 86400)
	_check(sp.limit() == 5000, "raised after 24 h")
	sp.set_limit(0)
	_check(sp.limit() == 5000, "removing the limit also waits")
	_adv(e, 86400)
	_check(sp.limit() == 0, "removed after 24 h")
	sp.pause(7)
	_check(e.shop.can_buy("moon_180").reason == "paused", "voluntary pause blocks purchases")
	_adv(e, 7 * 86400)
	_check(e.shop.can_buy("moon_180").ok, "pause over")
	sp.set_cooldown(true)
	e.shop.buy("moon_3000")
	_check(e.shop.can_buy("moon_180").ok, "no cooldown after a small purchase")
	e.shop.buy("moon_6000")
	_check(e.shop.can_buy("moon_180").reason == "cooldown", "24 h cool-down after a big purchase (opt-in)")
	_adv(e, 86400)
	_check(e.shop.can_buy("moon_180").ok, "cool-down over")


# ================================================================= pass
static func _pass() -> void:
	var e: = _econ(_stub())
	var ps: = e.pass_
	_check(ps.add_xp(100) == 0, "no XP without a season")
	ps.rollover("s1", T0, T0 + 42 * 86400)
	_check(ps.add_xp(250) == 250 and ps.tier() == 2, "tier 2")
	_check(ps.claimable().size() == 2, "free rewards claimable")
	_check(not ps.claim(1, "free").is_empty() and ps.claim(1, "free").is_empty(), "claim once")
	_check(ps.claim(1, "prem").is_empty(), "premium locked without the pass")
	_adv(e, 33 * 86400)
	_check(ps.late() and ps.add_xp(100) == 200, "×2 XP in the last 10 days")
	_check(e.shop.buy("pass_899").ok, "buy late")
	var prem: = ps.claimable().filter(func(x): return x.track == "prem")
	_check(prem.size() == 4, "late purchase unlocks all reached premium tiers (%d)" % prem.size())
	_check(e.shop.can_buy("pass_1490").reason == "owned", "one pass per season")
	ps.add_xp(5000)
	_check(ps.tier() == 30, "capped at tier 30")
	e.season_outfit = "zz_season"
	var got: = []
	e.item_granted.connect(func(id, _s): got.append(id))
	var left: = ps.rollover("s2", T0 + 42 * 86400, T0 + 84 * 86400)
	for g in left:
		e.grant(g, "rollover")
	_check(left.size() == 59, "season end: every unclaimed reward delivered automatically (%d)" % left.size())
	_check("zz_season" in got, "tier-30 exclusive outfit delivered")
	_check(ps.tier() == 0 and not bool(ps.st.prem), "new season starts clean")
	var e2: = _econ(_stub())
	e2.pass_.rollover("s1", T0, T0 + 42 * 86400)
	e2.shop.buy("pass_1490")
	_check(e2.pass_.tier() == 10 and e2.wallet.balance("moon") == 300, "deluxe: +10 tiers and moonstone")


# ================================================================= Constellation stars (the summon flow itself lives in TWGacha: TWGACHA_SELFTEST)
static func _summon_flow() -> void:
	var d: = _econ()
	d.st.inv["kohaku"] = true
	d.wallet.add("petal", 65, "t")
	_check(d.buy_star("kohaku") and int(d.st.const.kohaku) == 1 and d.wallet.balance("petal") == 5, "star bought for 60 petals")
	_check(not d.buy_star("kohaku"), "not enough petals")
	_check(not d.buy_star("vesper"), "no star for a heroine you do not own")
	_check(d.audit().is_empty(), "audit clean after a star: %s" % str(d.audit()))


# ================================================================= save / seal / migration
static func _save() -> void:
	var p: = _stub()
	var e: = _econ(p)
	e.shop.caps.server_wallet = true
	e.wallet.add("crystal", 3000, "t")
	e.shop.buy("moon_180")
	var d: = e.save_dict()
	var txt: = JSON.stringify(d)
	var back = JSON.parse_string(txt)
	_check(back is Dictionary and V10Econ.verify(back), "seal survives a JSON round trip (ints become floats)")
	var e2: = V10Econ.load_dict(back, p, [], "tw-econ-v1:5e1f0c2a9b", e.clock._m_wall)
	_check(e2.wallet.balance("crystal") == e.wallet.balance("crystal") and e2.wallet.balance("moon") == 120, "balances restored")
	_check(typeof(e2.st.wallet.bal.crystal) == TYPE_INT, "numbers normalised to int on load")
	_check(e2.shop.st.receipts.size() == 1, "receipts restored")
	_check(e2.audit().is_empty(), "restored state audits clean: %s" % str(e2.audit()))
	# tamper
	var bad = JSON.parse_string(txt)
	bad.wallet.bal.moon = 999999
	var e3: = V10Econ.load_dict(bad, null, [], "tw-econ-v1:5e1f0c2a9b", e.clock._m_wall)
	_check(bool(e3.st.flags.tampered), "edited save flagged by the seal")
	var a3: = e3.audit()
	_check(a3.size() >= 2, "audit reports seal + broken invariant: %s" % str(a3))
	_check(not V10Econ.verify(back, "other-key"), "seal depends on the key")
	# migration from a 0.9 save (G.S ver 7)
	var legacy: = {"ver": 7, "gems": 4321, "coins": 2400, "pity": 37, "sr_pity": 4, "guar": true, "pulls": 80,
		"newbie_left": 5, "newbie_ssr": true, "pass": {"owned": true, "xp": 950, "claimed": 4},
		"month_card": {"until": "2027-03-10", "last": "2027-02-28"}, "first_buy": {"0": true, "first": true},
		"profile": {"created": T0 - 86400 * 40}}
	var ms: = V10Econ.from_legacy(legacy, T0)
	var em: = V10Econ.new(ms, null, [], T0)
	_check(em.wallet.balance("crystal") == 4321 and em.wallet.balance("moon") == 0, "legacy gems stay free crystals, moonstone starts at 0")
	_check(em.wallet.balance("coin") == 2400, "coins carried")
	# the legacy counters are kept in the (inert) economy subtree so the save format and its hashes do not move
	var lc: Dictionary = em.st.gacha.ctr.limited
	_check(int(lc.p) == 37 and int(lc.s) == 4 and bool(lc.g) and lc.rules == "r0", "pity, S pity and 50/50 guarantee carried with their old rules")
	_check(int(em.st.gacha.newbie.n) == 15 and bool(em.st.gacha.newbie.ssr), "beginner: 15 used of 50, SSR already had")
	_check(em.pass_.tier() == 9 and bool(em.pass_.st.prem) and em.pass_.claimable().size() == 10, "pass progress and claims carried")
	_check(em.shop.month_days_left() == 10, "month card days carried (%d)" % em.shop.month_days_left())
	_check(em.shop.is_first(V10Catalog.sku("moon_180")), "fake 0.8 purchases do not burn the first-purchase bonus")
	_check(em.shop.available("guest_149").reason in ["expired", "server"], "beginner sets follow the original install date")
	_check(em.audit().is_empty(), "migrated state audits clean: %s" % str(em.audit()))
	var empty: = V10Econ.from_legacy({"gems": 0, "unlocked": 1}, T0)
	_check(V10Econ.new(empty, null, [], T0).audit().is_empty(), "migrating a minimal save works")


# ================================================================= review fixes (edge cases)
static func _review() -> void:
	var e: = _econ()
	e.wallet.add("crystal", 500, "t")
	_check(e.audit().is_empty(), "a fresh economy audits clean")
	# an order the store never answered stops blocking the SKU after ORDER_STALE_SEC; a late payment is still delivered
	var p: = _stub()
	var e2: = _econ(p)
	e2.spend.set_age_verified(true)
	p.instant = false
	var b1: = e2.shop.buy("month_449")
	_check(b1.ok and e2.shop.can_buy("month_449").reason == "in_progress", "unanswered order blocks a second one at first")
	_adv(e2, V10Catalog.ORDER_STALE_SEC + 1)
	_check(e2.shop.can_buy("month_449").ok, "stale unanswered order no longer locks the SKU")
	p.flush()
	_check(e2.shop.st.orders[b1.oid].st == "delivered" and e2.shop.month_days_left() == 30, "late payment of the stale order still delivered")
