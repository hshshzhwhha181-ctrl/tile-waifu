class_name V10EconSelftest
extends RefCounted

# Economy core selftest. Run headless:
#   flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/economy/econ_selftest.tscn -- --econ_selftest=1
# prints «ECON_SELFTEST ok/total» (exit code 0 only when every check passed) and every failed check.
# --econ_mc=N scales the Monte-Carlo sample (default 1 = 400 000 standard pulls, 300 000 limited, 20 000 beginner runs).
#
# Sections: catalog & store rules · clock anti-cheat · wallet · energy · gacha rules · Monte-Carlo vs advertised odds ·
# odds disclosure · shop purchase flow (stub provider) · refunds · restore · spending protection · pass · summon flow ·
# save/seal/migration.

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
	_energy()
	_gacha_rules()
	_monte_carlo()
	_odds()
	_shop()
	_refunds_restore()
	_spend()
	_pass()
	_summon_flow()
	_save()
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
	_near(V10Catalog.base_rub_per_pull(), 79.0 / 1.2, 0.01, "base pack ₽ per pull")
	var mx: = 0
	for s in V10Catalog.SKUS:
		mx = maxi(mx, int(s.rub))
		_check(V10Catalog.pull_value(s, false) > 0.0, "%s has a pull value for «≈ N ₽ за крутку»" % s.id)
		_check(V10Catalog.ladder_ratio(s, false) <= V10Catalog.LADDER_MAX + 1e-6, "%s ladder ≤ 3×" % s.id)
		if s.kind == "currency":
			_check(V10Catalog.ladder_ratio(s, true) <= V10Catalog.LADDER_MAX + 1e-6, "%s first purchase ≤ 3×" % s.id)
			_check(bool(s.requires_server), "%s consumable needs the server wallet" % s.id)
	_check(mx <= 4990, "no SKU above 4990 ₽")
	var month: = V10Catalog.sku("month_449")
	_near(V10Catalog.ladder_ratio(month), 3.0, 0.1, "month card ≈ 3× (CEO_PLAN §2)")
	_near(V10Catalog.ladder_ratio(V10Catalog.sku("pass_899")), 2.0, 0.15, "pass ≈ 2× (CEO_PLAN §2)")
	_check(not bool(month.get("requires_server", false)) and bool(month.restorable), "month card is restorable without the server")
	# a deliberately broken SKU is caught by the validator
	var orig: Array = V10Catalog.SKUS
	var cheap: = {"id": "evil", "kind": "starter", "rub": 149, "grant": {"moon": 12000}}
	_check(V10Catalog.ladder_ratio(cheap) > 3.0, "validator math flags a 10× offer like the old «1200 + SSR за 149 ₽»")
	_check(V10Catalog.ladder_ratio(V10Catalog.sku("moon_180"), true) <= 2.0 + 1e-6, "first purchase double ≤ 2×")
	# rate schedule = g.gd roll()
	_near(V10Catalog.ssr_rate(1), 0.03, 1e-9, "SSR 3 % at pull 1")
	_near(V10Catalog.ssr_rate(45), 0.03, 1e-9, "SSR 3 % at pull 45")
	_near(V10Catalog.ssr_rate(46), 0.09, 1e-9, "soft pity: 9 % at pull 46")
	_near(V10Catalog.ssr_rate(59), 0.87, 1e-9, "soft pity: 87 % at pull 59")
	_near(V10Catalog.ssr_rate(60), 1.0, 1e-9, "hard pity at 60")
	_near(V10Gacha.rate_at(50, 50), 1.0, 1e-9, "beginner hard pity at 50")
	_check(V10Catalog.fmt_rub(4990) == "4 990 ₽" and V10Catalog.fmt_rub(79) == "79 ₽", "ruble format")
	var tot: = V10Catalog.pass_track_total(true)
	_check(int(tot.get("wish", 0)) == 9 and int(tot.get("crystal", 0)) == 2960, "premium track total 2960 crystals + 9 wishes: %s" % str(tot))
	_check(orig.size() == V10Catalog.SKUS.size(), "catalog untouched")


# ================================================================= clock
static func _clock() -> void:
	var cs: = {}
	var c: = V10Clock.new(cs)
	c.set_manual(T0, 0)
	_check(c.now() == T0, "manual clock")
	c.set_manual(T0 + 60, 60000)
	_check(c.now() == T0 + 60, "clock follows a consistent wall + monotonic clock")
	# player moves the wall clock 10 h forward while the game runs → ignored
	c.set_manual(T0 + 36000 + 70, 70000)
	_check(c.now() == T0 + 70 and int(cs.jumps) == 1, "in-session forward jump ignored and counted (%d)" % c.now())
	c.set_manual(T0 + 36000 + 80, 80000)
	_check(c.now() == T0 + 80 and int(cs.jumps) == 1, "jump counted once, monotonic time keeps going")
	# new session with the clock rolled back a day → time frozen at the high-water mark
	c.new_session(T0 - 86400)
	_check(c.now() == T0 + 80 and int(cs.rollbacks) == 1, "rollback across sessions freezes time")
	c.set_manual(T0 - 86400 + 100, 100000)
	_check(c.now() == T0 + 80 and int(cs.rollbacks) == 1, "still frozen, rollback counted once")
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


# ================================================================= energy
static func _energy() -> void:
	var e: = _econ()
	var en: = e.energy
	_check(en.value() == 160, "tea starts full (160)")
	_check(en.next_in() == 0 and en.full_in() == 0, "no timer while full")
	_check(en.spend(40) and en.value() == 120, "spend 40 tea")
	_check(not en.spend(500), "cannot spend more than there is")
	_adv(e, 359)
	_check(en.value() == 120 and en.next_in() == 1, "no tea before 6 min")
	_adv(e, 1)
	_check(en.value() == 121, "+1 tea after 6 min")
	_check(en.full_in() == 39 * 360, "full in 39 × 6 min")
	_adv(e, 39 * 360 + 360 * 5)
	_check(en.value() == 160 and en.thermos() == 5, "overflow while full goes into the thermos (%d/%d)" % [en.value(), en.thermos()])
	_adv(e, 360 * 5000)
	_check(en.thermos() == 1200, "thermos capped at 1200")
	_check(en.take_thermos(100) == 100 and en.value() == 260, "take tea from the thermos over the cap")
	_check(en.thermos() == 1100, "thermos reduced")
	_adv(e, 3600)
	_check(en.value() == 260 and en.thermos() == 1110, "over the cap: regen goes to the thermos")
	# refills: fixed price, 2 a day, +1 ad
	e.wallet.add("crystal", 1000, "t")
	var r1: = en.refill(e.wallet)
	var r2: = en.refill(e.wallet)
	var r3: = en.refill(e.wallet)
	_check(r1.ok and r2.ok and not r3.ok and r3.reason == "daily_limit", "2 refills a day")
	_check(e.wallet.balance("crystal") == 880, "each refill costs exactly 60 crystals (no escalation)")
	_check(en.ad_refill().ok and not en.ad_refill().ok, "1 ad refill a day")
	var e2: = _econ()
	_check(not e2.energy.refill(e2.wallet).ok, "refill needs crystals")
	_adv(e, 86400)
	_check(en.refills_left() == 2 and en.ad_refills_left() == 1, "refills reset next day")
	en.refill(e.wallet)
	en.refill(e.wallet)
	# clock rolled back to yesterday in a new session: refill counters do NOT reset
	e.clock.new_session(e.clock._m_wall - 86400)
	_check(en.refills_left() == 0, "rollback cannot reset the daily refill limit")
	# in-session forward jump: no free tea
	var e3: = _econ()
	e3.energy.spend(160)
	e3.clock.set_manual(T0 + 86400 * 3, 1000)
	_check(e3.energy.value() == 0, "a wall-clock jump inside the session gives no tea")
	# across sessions the gain is bounded by the cap (no thermos fill beyond real time once rolled back)
	var e4: = _econ()
	e4.energy.spend(160)
	e4.clock.new_session(T0 + 86400 * 30)
	var v: = e4.energy.value()
	_check(v == 160, "cross-session jump fills at most the bar (%d)" % v)
	e4.clock.new_session(T0 + 100)
	var th: = e4.energy.thermos()
	e4.clock.set_manual(T0 + 100 + 86400, 86400000)
	_check(e4.energy.thermos() == th, "after rolling back, borrowed time is paid back before regen resumes")
	_check(e.energy.audit().is_empty(), "energy audit clean")


# ================================================================= gacha rules
static func _gacha() -> V10Gacha:
	var g: = V10Gacha.new({}, null)
	g.rng.seed = 12345
	return g


static func _gacha_rules() -> void:
	var g: = _gacha()
	var c: = g.counter("std")
	# pity: 2 000 pulls never go 60 without an SSR or 10 without S+
	var since: = 0
	var since_s: = 0
	var maxg: = 0
	var maxs: = 0
	for i in 2000:
		var r: = g.roll_rar(c)
		since += 1
		since_s += 1
		if r == "SSR":
			maxg = maxi(maxg, since)
			since = 0
		if r != "A":
			maxs = maxi(maxs, since_s)
			since_s = 0
	_check(maxg <= 60 and maxs <= 10, "hard pity 60 / S every 10 (%d, %d)" % [maxg, maxs])
	# forced: pity counter at 59 → next is SSR
	c.p = 59
	_check(g.roll_rar(c) == "SSR" and int(c.p) == 0, "pull #60 is SSR")
	c.s = 9
	c.p = 0
	g.rng.seed = 7
	var r10: = g.roll_rar(c)
	_check(r10 != "A" and int(c.s) == 0, "10th pull without S+ is S or SSR")
	# limited: lost 50/50 → next SSR featured
	var lg: = _gacha()
	var lc: = lg.counter("limited")
	var lost: = false
	var after_loss_ok: = true
	var cnt: = 0
	for i in 6000:
		var res: = lg.pull("lim_zlata", 1)
		var x: Dictionary = res[0]
		if x.rar != "SSR":
			continue
		cnt += 1
		if lost and not x.featured:
			after_loss_ok = false
		lost = not x.featured
		if not x.featured:
			_check(x.id != "zlata" and x.id in ["minamo", "kira", "vesper", "sigrid"], "off-banner SSR from the standard SSR pool (%s)" % x.id)
	_check(after_loss_ok and cnt > 100, "after a lost 50/50 the next SSR is the featured one (%d SSR)" % cnt)
	_check(lg.candles("lim_zlata") == 6000, "one candle per limited pull")
	_check(lg.candles("std") == 0, "standard banner has no candles")
	# spark
	var cand0: = lg.candles("lim_zlata")
	var p_before: = int(lc.p)
	var sp: = lg.spark("lim_zlata", "zlata")
	_check(sp.get("id", "") == "zlata" and lg.candles("lim_zlata") == cand0 - 200 and int(lc.p) == p_before, "spark: 200 candles → featured SSR, pity untouched")
	_check(lg.spark("lim_zlata", "kira").is_empty(), "spark only gives a featured SSR")
	var sg: = _gacha()
	sg.pull("lim_zlata", 10)
	_check(not sg.can_spark("lim_zlata") and sg.spark("lim_zlata", "zlata").is_empty(), "no spark below 200 candles")
	# rerun 3+3: target
	var rg: = _gacha()
	_check(rg.target("rerun_night") == "vesper", "rerun defaults to the first featured")
	_check(rg.set_target("rerun_night", "sigrid") and rg.target("rerun_night") == "sigrid", "player picks the rerun target")
	_check(not rg.set_target("rerun_night", "zlata"), "target must be featured on that banner")
	var feats: = {}
	for i in 3000:
		for x in rg.pull("rerun_night", 1):
			if x.featured:
				feats[x.id] = true
	_check(feats.keys() == ["sigrid"], "a won 50/50 gives the chosen target only: %s" % str(feats.keys()))
	_check(rg.counter("limited") == rg.st.ctr.limited and rg.st.ctr.size() == 1, "limited banners share one pity counter")
	# banner end → candles become wax, banner closed, idempotent
	var eg: = _gacha()
	eg.clock = V10Clock.new({})
	eg.clock.set_manual(T0, 0)
	var bs: Array = V10Catalog.BANNERS.duplicate(true)
	for b in bs:
		if b.id == "lim_zlata":
			b.end = T0 + 3600
	eg.banners = bs
	eg.pull("lim_zlata", 37)
	_check(eg.ended().is_empty(), "banner running")
	eg.clock.set_manual(T0 + 3600, 3600000)
	_check(eg.ended() == ["lim_zlata"], "banner ended by its calendar date")
	_check(eg.pull("lim_zlata", 1).is_empty(), "no pulls on an ended banner")
	_check(eg.close("lim_zlata") == 37 and eg.candles("lim_zlata") == 0, "37 unspent candles → 37 wax")
	_check(eg.close("lim_zlata") == 0, "closing twice gives nothing")
	# beginner banner: 50 pulls, SSR within them, then closed
	var ng: = _gacha()
	var got_ssr: = false
	for i in 5:
		for x in ng.pull("newbie", 10):
			got_ssr = got_ssr or x.rar == "SSR"
	_check(got_ssr and ng.newbie_left() == 0, "beginner: SSR within 50, 50 pulls used")
	_check(ng.pull("newbie", 1).is_empty() and not ng.is_open(ng.banner("newbie")), "beginner banner closes after 50")
	var ng2: = _gacha()
	ng2.pull("newbie", 45)
	_check(ng2.pull("newbie", 10).is_empty(), "cannot overshoot the 50-pull limit")
	# first SSR of choice
	var fg: = _gacha()
	_check(fg.first_options() == V10Catalog.FIRST_SSR_CHOICES, "three first-SSR options")
	_check(not fg.choose_first("zlata"), "first SSR only from the offered list")
	_check(fg.choose_first("y_queen") and fg.st.first == "y_queen", "first SSR chosen")
	_check(not fg.choose_first("n_ssr") and fg.first_options().is_empty(), "first SSR choice is final and once")
	var og: = V10Gacha.new({}, null)
	og.owns = func(id): return id == "o_dragon"
	_check(not ("o_dragon" in og.first_options()), "already owned outfit not offered")
	# outfit drops only for owned heroines
	var pg: = V10Gacha.new({}, null, [{"id": "z_gown", "rar": "SSR", "kind": "outfit", "hero": "zlata"}])
	_check(pg.eligible("SSR").filter(func(x): return x.id == "z_gown").is_empty(), "outfit of a heroine you do not own never drops")
	pg.owns = func(id): return id == "zlata"
	_check(not pg.eligible("SSR").filter(func(x): return x.id == "z_gown").is_empty(), "outfit drops once the heroine is owned")
	# history 90 days
	var hg: = _gacha()
	hg.clock = V10Clock.new({})
	hg.clock.set_manual(T0, 0)
	hg.pull("std", 10)
	hg.clock.new_session(T0 + 89 * 86400)
	hg.pull("std", 5)
	_check(hg.history("std").size() == 15, "history keeps 90 days")
	hg.clock.new_session(T0 + 91 * 86400)
	_check(hg.history().size() == 5, "history older than 90 days pruned")
	# rule change: a running counter keeps its rules; after an SSR + notice period it adopts the new ones
	var ug: = _gacha()
	ug.clock = V10Clock.new({})
	ug.clock.set_manual(T0, 0)
	ug.counter("limited").rules = "r0"
	ug.rules_current = "r1"
	ug.rules_announced = T0
	var uc: = ug.counter("limited")
	uc.p = 59
	ug.roll_rar(uc)
	_check(uc.rules == "r0", "new rules wait for the 14-day notice")
	ug.clock.new_session(T0 + 14 * 86400)
	uc.p = 30
	var rr: = ug.roll_rar(uc)
	_check(rr == "SSR" or uc.rules == "r0", "a running counter keeps its rules")
	uc.p = 59
	ug.roll_rar(uc)
	_check(uc.rules == "r1", "after the notice, a counter adopts new rules only when it resets")
	_check(g.audit().is_empty() and lg.audit().is_empty(), "gacha audits clean")
	lg.st.candles["lim_zlata"] = 999999
	_check(not lg.audit().is_empty(), "candles beyond pulls detected")


# ================================================================= Monte-Carlo vs the advertised odds
static func _monte_carlo() -> void:
	var N: = int(400000 * mc_scale)
	var g: = _gacha()
	g.rng.seed = 20271
	var c: = g.counter("std")
	var base_trials: = 0
	var base_ssr: = 0
	var s_trials: = 0
	var s_hits: = 0
	var ssr: = 0
	var srr: = 0
	var gaps: = []
	var gap: = 0
	var gap_s: = 0
	var max_gap: = 0
	var max_gap_s: = 0
	var bins: = [0, 0, 0, 0, 0, 0, 0]
	var edges: = [10, 20, 30, 45, 50, 55, 60]
	var a_items: = {}
	for i in N:
		var p_next: = int(c.p) + 1
		var s_next: = int(c.s) + 1
		var r: = g.roll_rar(c)
		gap += 1
		gap_s += 1
		if p_next < V10Catalog.SOFT_FROM:
			base_trials += 1
			if r == "SSR":
				base_ssr += 1
			if s_next < V10Catalog.S_HARD:
				s_trials += 1
				if r == "S":
					s_hits += 1
		if r == "SSR":
			ssr += 1
			gaps.append(gap)
			max_gap = maxi(max_gap, gap)
			for k in edges.size():
				if gap <= edges[k]:
					bins[k] += 1
					break
			gap = 0
		elif r == "S":
			srr += 1
		if r != "A":
			max_gap_s = maxi(max_gap_s, gap_s)
			gap_s = 0
		elif i < 50000:
			var it: = g._pick(g.eligible("A"))
			a_items[it.id] = int(a_items.get(it.id, 0)) + 1
	# advertised base rates (before soft pity / S guarantee)
	var pb: = float(base_ssr) / float(base_trials)
	_near(pb, 0.03, 5.0 * sqrt(0.03 * 0.97 / base_trials), "MC base SSR rate 3 %")
	var ps: = float(s_hits) / float(s_trials)
	_near(ps, 0.15, 5.0 * sqrt(0.15 * 0.85 / s_trials), "MC base S rate 15 %")
	# pity bounds
	_check(max_gap <= 60, "MC: never more than 60 pulls without SSR (%d)" % max_gap)
	_check(max_gap_s <= 10, "MC: never more than 10 pulls without S+ (%d)" % max_gap_s)
	# mean pulls per SSR vs the analytic distribution (5σ of the sample mean)
	var dist: = V10Odds.first_ssr_dist()
	var mu: = V10Odds.expected_to_ssr()
	var var_: = 0.0
	for k in dist.size():
		var_ += float(dist[k]) * pow(float(k + 1) - mu, 2)
	var m: = 0.0
	for x in gaps:
		m += float(x)
	m /= float(gaps.size())
	_near(m, mu, 5.0 * sqrt(var_ / gaps.size()), "MC mean pulls per SSR vs analytic %.3f" % mu)
	# consolidated rates vs the stationary chain
	var cons: = V10Odds.consolidated()
	var cs: = float(ssr) / N
	_near(cs, float(cons.SSR), 5.0 * sqrt(var_ / gaps.size()) / (mu * mu) + 1e-4, "MC consolidated SSR")
	var cS: = float(srr) / N
	_near(cS, float(cons.S), 6.0 * sqrt(float(cons.S) * (1.0 - float(cons.S)) / N), "MC consolidated S")
	_near(1.0 / mu, float(cons.SSR), 1e-6, "chain SSR share = 1 / mean pulls")
	# chi-square of when the first SSR lands
	var exp_bins: = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for k in dist.size():
		for b in edges.size():
			if k + 1 <= edges[b]:
				exp_bins[b] += float(dist[k]) * gaps.size()
				break
	var chi: = 0.0
	for b in bins.size():
		chi += pow(float(bins[b]) - exp_bins[b], 2) / exp_bins[b]
	_check(chi < 30.0, "MC SSR position distribution matches (χ² %.2f, df 6)" % chi)
	# items of one rarity equally likely
	var na: = 0
	for k in a_items:
		na += a_items[k]
	var chi_i: = 0.0
	var ei: = float(na) / a_items.size()
	for k in a_items:
		chi_i += pow(float(a_items[k]) - ei, 2) / ei
	_check(a_items.size() == 5 and chi_i < 25.0, "A items uniform (χ² %.2f, df 4)" % chi_i)
	# limited banner: featured share 2/3 of SSRs, at most 120 pulls per featured
	var L: = int(300000 * mc_scale)
	var lg: = _gacha()
	lg.rng.seed = 777
	var lssr: = 0
	var lfeat: = 0
	var since: = 0
	var max_f: = 0
	var fgaps: = 0.0
	var fsq: = 0.0
	var nf: = 0
	var lc: = lg.counter("limited")
	for i in L:
		var p_next: = int(lc.p) + 1
		var rar: = lg.roll_rar(lc)
		since += 1
		if rar != "SSR":
			continue
		lssr += 1
		var win: = bool(lc.g) or lg.rng.randf() < 0.5
		if win:
			lc.g = false
			lfeat += 1
			max_f = maxi(max_f, since)
			fgaps += since
			fsq += since * since
			nf += 1
			since = 0
		else:
			lc.g = true
	var share: = float(lfeat) / lssr
	_near(share, 2.0 / 3.0, 5.0 * sqrt((2.0 / 9.0) / lssr), "MC featured share of SSRs = 2/3")
	_check(max_f <= V10Odds.featured_worst(), "MC: featured within %d pulls (%d)" % [V10Odds.featured_worst(), max_f])
	var fm: = fgaps / nf
	_near(fm, V10Odds.featured_expected(), 5.0 * sqrt(maxf(1.0, fsq / nf - fm * fm) / nf), "MC mean pulls per featured")
	# the real pull() path agrees (smaller run, includes item choice)
	var rg: = _gacha()
	rg.rng.seed = 99
	var rf: = 0
	var rs: = 0
	for i in int(60000 * mc_scale) / 10:
		for x in rg.pull("lim_zlata", 10):
			if x.rar == "SSR":
				rs += 1
				if x.featured:
					rf += 1
	_near(float(rf) / rs, 2.0 / 3.0, 5.0 * sqrt((2.0 / 9.0) / rs), "pull(): featured share 2/3")
	# beginner banner: every run of 50 has an SSR
	var R: = int(20000 * mc_scale)
	var bad: = 0
	var first_at: = 0.0
	for i in R:
		var ng: = V10Gacha.new({}, null)
		ng.rng.seed = 5000 + i
		var res: = ng.pull("newbie", 50)
		var k: = -1
		for j in res.size():
			if res[j].rar == "SSR":
				k = j
				break
		if k < 0:
			bad += 1
		else:
			first_at += k + 1
	_check(bad == 0, "MC beginner: SSR within 50 in all %d runs" % R)
	var exp_nb: = V10Odds.expected_to_ssr(50)
	var dn: = V10Odds.first_ssr_dist(50)
	var vn: = 0.0
	for k in dn.size():
		vn += float(dn[k]) * pow(float(k + 1) - exp_nb, 2)
	_near(first_at / R, exp_nb, 5.0 * sqrt(vn / R), "MC beginner mean first SSR vs analytic %.2f" % exp_nb)


# ================================================================= odds disclosure
static func _odds() -> void:
	var mu: = V10Odds.expected_to_ssr()
	_check(mu > 20.0 and mu < 40.0, "expected pulls per SSR plausible (%.2f)" % mu)
	var cons: = V10Odds.consolidated()
	_near(float(cons.SSR) + float(cons.S) + float(cons.A), 1.0, 1e-9, "consolidated rates sum to 1")
	_check(float(cons.S) > 0.15, "S consolidated above base thanks to the 10-pull guarantee (%.4f)" % float(cons.S))
	var sum_d: = 0.0
	for x in V10Odds.first_ssr_dist():
		sum_d += float(x)
	_near(sum_d, 1.0, 1e-9, "first-SSR distribution sums to 1")
	_check(V10Odds.featured_worst() == 120, "worst case featured: 120 pulls")
	for b in V10Catalog.BANNERS:
		var d: = V10Odds.disclosure(b.id)
		_check(not d.is_empty() and d.lines.size() >= 5, "%s: odds lines (%d)" % [b.id, d.get("lines", []).size()])
		var s: = 0.0
		var sb: = 0.0
		for it in d.items:
			s += float(it.rate)
			sb += float(it.base)
		_near(s, 1.0, 1e-6, "%s: per-item consolidated rates sum to 1" % b.id)
		_near(sb, 1.0, 1e-6, "%s: per-item base rates sum to 1" % b.id)
		_check(float(d.worst_rub[0]) > 0 and float(d.worst_rub[1]) >= float(d.worst_rub[0]), "%s: worst case in ₽" % b.id)
		var txt: = "\n".join(d.lines)
		_check("₽" in txt and "%" in txt, "%s: lines show ₽ and %%" % b.id)
	var dl: = V10Odds.disclosure("lim_zlata")
	_check(dl.worst == 120 and dl.spark == 200, "limited disclosure: worst 120, spark 200")
	_check(dl.items[0].id == "zlata" and dl.items[0].featured, "featured listed first")
	var dn: = V10Odds.disclosure("newbie")
	_check(dn.worst == 50 and dn.hard == 50, "beginner disclosure: SSR within 50")
	_near(float(dn.rub_per_pull[1]), V10Catalog.base_rub_per_pull() * 0.8, 1e-6, "beginner pull shown at -20 % in ₽")
	# live data
	var g: = _gacha()
	g.pull("lim_zlata", 12)
	var live: = V10Odds.disclosure("lim_zlata", g)
	_check(live.live.candles == 12 and live.live.history.size() == 12, "live: candles and 90-day history on the odds screen")
	_check(int(live.live.pity_left) == 60 - int(g.counter("limited").p), "live: pulls left to the guarantee")
	print("ECON odds: %s" % " | ".join(V10Odds.disclosure("lim_zlata").lines))


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
	_check(r.ok and e.wallet.balance("moon") == 360, "first purchase doubled (%d)" % e.wallet.balance("moon"))
	var rc: Dictionary = sh.st.receipts[0]
	_check(rc.st == "confirmed" and rc.sku == "moon_180" and rc.rub == 79 and rc.first, "receipt written and confirmed")
	sh.buy("moon_180")
	_check(e.wallet.balance("moon") == 540, "second purchase without the first bonus")
	_check(p.confirms == 2, "every delivery confirmed with the store")
	# cancel / fail
	p.next_status = "cancelled"
	var rcan: = sh.buy("moon_900")
	_check(rcan.ok and sh.st.orders[rcan.oid].st == "cancelled" and e.wallet.balance("moon") == 540, "cancelled: nothing granted")
	p.next_status = "failed"
	var rf: = sh.buy("moon_900")
	_check(sh.st.orders[rf.oid].st == "failed" and sh.st.receipts.size() == 2, "failed: nothing granted, no receipt")
	# pending → completes later
	p.next_status = "pending"
	var rp: = sh.buy("moon_900")
	_check(sh.st.orders[rp.oid].st == "pending", "pending order")
	_check(sh.can_buy("moon_900").reason == "in_progress", "no second order while one is pending")
	p.complete(rp.oid, "paid")
	_check(sh.st.orders[rp.oid].st == "delivered" and e.wallet.balance("moon") == 540 + 1720, "pending order delivered when paid")
	# duplicate store callback → delivered once
	p.next_status = "paid"
	p.duplicate = true
	sh.buy("moon_3000")
	p.duplicate = false
	var n3: int = sh.st.receipts.filter(func(x): return x.sku == "moon_3000").size()
	_check(n3 == 1 and e.wallet.balance("moon") == 2260 + 5420, "duplicate callback delivers once")
	# crash between payment and delivery: callback lost → reconcile delivers and confirms
	p.instant = false
	sh.buy("moon_6000")
	p.restart()
	_check(e.wallet.balance("moon") == 7680, "nothing delivered before the callback")
	var done: = sh.reconcile()
	_check(done.size() == 1 and e.wallet.balance("moon") == 7680 + 10440, "reconcile delivers a paid, undelivered purchase")
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
	# once-only and windows
	_check(sh.buy("first_79").ok and e.wallet.balance("coin") == 2000, "first purchase set")
	_check(sh.can_buy("first_79").reason == "owned", "once-only set cannot be bought twice")
	var offers: = sh.offers()
	var guest: Array = offers.filter(func(o): return o.id == "guest_149")
	_check(guest.size() == 1 and int(guest[0].until) == int(sh.st.install) + 14 * 86400, "beginner set shows its end date, no countdown")
	_check(String(guest[0].per_pull).begins_with("≈ ") and String(guest[0].per_pull).ends_with("₽ за крутку"), "«≈ N ₽ за крутку» on offers")
	_check(offers.filter(func(o): return o.id == "first_79").is_empty(), "bought once-only set leaves the list")
	_adv(e, 15 * 86400)
	_check(sh.available("guest_149").reason == "expired", "beginner set gone after 14 days")
	# month card
	var m0: = e.wallet.balance("moon")
	_check(sh.buy("month_449").ok and e.wallet.balance("moon") == m0 + 300, "month card: 300 now")
	_check(sh.month_days_left() == 30 and sh.ad_free(), "30 days, ads skipped")
	var c0: = e.wallet.balance("crystal")
	_check(not sh.month_claim().is_empty() and sh.month_claim().is_empty(), "90 crystals once a day")
	_check(e.wallet.balance("crystal") == c0 + 90, "daily 90")
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
	_check(rel.is_available() == OS.is_debug_build(), "stub store only in debug builds")
	_check(e.audit().filter(func(x): return not x.begins_with("clock")).is_empty(), "economy audit clean after purchases: %s" % str(e.audit()))


static func _refunds_restore() -> void:
	var p: = _stub()
	var e: = _econ(p)
	e.shop.caps.server_wallet = true
	e.spend.set_age_verified(true)
	e.shop.buy("moon_3000")         # 5420 moon (first)
	var pid: String = e.shop.st.receipts[0].pid
	e.wallet.spend_premium(5000, "pull")
	p.refund(pid)
	_check(e.shop.receipt(pid).st == "refunded", "refund notice marks the receipt")
	_check(e.wallet.balance("moon") == 0 and e.wallet.debt("moon") == 5000, "spent refunded moonstone becomes debt (%d)" % e.wallet.debt("moon"))
	_check(e.spend.spent_30d() == 0, "refunded purchase leaves the 30-day total")
	_check(not e.shop.refund(pid), "refund is idempotent")
	_check(not e.shop.refund("nope"), "unknown refund ignored")
	e.shop.buy("moon_180")
	_check(e.wallet.debt("moon") == 5000 - 360 and e.wallet.balance("moon") == 0, "next purchase pays the debt first")
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
	_check(int(e.wallet.st.revoked.crystal) == 880, "pass refund claws back premium crystals (%d)" % int(e.wallet.st.revoked.crystal))
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
	_check(e2.pass_.tier() == 10 and e2.wallet.balance("moon") == 1500, "deluxe: +10 tiers and moonstone")


# ================================================================= summon flow (payment + grants)
static func _summon_flow() -> void:
	var e: = _econ()
	e.gacha.rng.seed = 4242
	var c: = e.can_summon("std", 10)
	_check(not c.ok and c.reason == "no_crystals" and int(c.need) == 1500, "not enough crystals → need 1500")
	e.wallet.add("wish", 3, "t")
	e.wallet.add("crystal", 600, "t")
	e.wallet.add("moon", 600, "t")
	var r: = e.summon("std", 10)
	_check(r.ok and r.res.size() == 10, "10-pull")
	_check(e.wallet.balance("wish") == 0 and e.wallet.balance("crystal") == 0 and e.wallet.balance("moon") == 150, "paid with wishes, then crystals, then moonstone")
	_check(e.pass_.st.xp == 0, "no pass XP without a season")
	var granted: = 0
	for x in r.res:
		if x.new:
			granted += 1
	_check(granted > 0 and e.st.inv.size() == granted, "new items granted")
	# newbie: wishes not used, 120 each
	e.wallet.add("wish", 5, "t")
	e.wallet.add("crystal", 1200, "t")
	var rn: = e.summon("newbie", 10)
	_check(rn.ok and e.wallet.balance("wish") == 5 and e.wallet.balance("crystal") == 0, "beginner: 120 per pull, no tickets")
	# duplicates
	var d: = _econ()
	d.st.inv["tsubame"] = true
	var x: = {"id": "tsubame", "rar": "A", "kind": "hero"}
	d._apply(x, "t")
	_check(not x.new and int(x.star) == 1 and int(d.st.const.tsubame) == 1, "duplicate heroine → Constellation ★1")
	d.st.const["tsubame"] = 5
	var y: = {"id": "tsubame", "rar": "A", "kind": "hero"}
	d._apply(y, "t")
	_check(int(y.petals) == 5 and d.wallet.balance("petal") == 5, "past ★5 → petals")
	var z: = {"id": "o_x", "rar": "SSR", "kind": "outfit"}
	d.st.inv["o_x"] = true
	d._apply(z, "t")
	_check(int(z.petals) == 60, "duplicate SSR outfit → 60 petals")
	d.st.inv["kohaku"] = true
	_check(d.buy_star("kohaku") and int(d.st.const.kohaku) == 1 and d.wallet.balance("petal") == 5, "star bought for 60 petals")
	_check(not d.buy_star("kohaku"), "not enough petals")
	_check(not d.buy_star("vesper"), "no star for a heroine you do not own")
	# first SSR
	var f: = _econ()
	var got: = []
	f.item_granted.connect(func(id, _s): got.append(id))
	_check(f.choose_first("n_ssr") and got == ["n_ssr"] and not f.choose_first("o_dragon"), "first SSR granted once")
	# spark + wax through the facade
	var s: = _econ()
	s.gacha.rng.seed = 1
	s.wallet.add("crystal", 150 * 200, "t")
	s.summon("lim_zlata", 100)
	s.summon("lim_zlata", 100)
	var sk: = s.spark("lim_zlata", "zlata")
	_check(sk.ok and s.gacha.candles("lim_zlata") == 0, "facade spark")
	s.wallet.add("crystal", 150 * 13, "t")
	s.summon("lim_zlata", 13)
	var bs: Array = V10Catalog.BANNERS.duplicate(true)
	for b in bs:
		if b.id == "lim_zlata":
			b.end = T0 + 10
	s.gacha.banners = bs
	_adv(s, 11)
	_check(s.tick().wax == 13 and s.wallet.balance("wax") == 13, "ended banner: candles → wax in the wallet")
	_check(s.tick().wax == 0, "wax once")
	_check(s.can_summon("lim_zlata", 1).reason == "closed", "closed banner refuses pulls")
	_check(s.audit().is_empty(), "audit clean after summons: %s" % str(s.audit()))


# ================================================================= save / seal / migration
static func _save() -> void:
	var p: = _stub()
	var e: = _econ(p)
	e.shop.caps.server_wallet = true
	e.wallet.add("crystal", 3000, "t")
	e.gacha.rng.seed = 3
	e.summon("lim_zlata", 10)
	e.shop.buy("moon_180")
	e.energy.spend(33)
	var d: = e.save_dict()
	var txt: = JSON.stringify(d)
	var back = JSON.parse_string(txt)
	_check(back is Dictionary and V10Econ.verify(back), "seal survives a JSON round trip (ints become floats)")
	var e2: = V10Econ.load_dict(back, p, [], "tw-econ-v1:5e1f0c2a9b", e.clock._m_wall)
	_check(e2.wallet.balance("crystal") == e.wallet.balance("crystal") and e2.wallet.balance("moon") == 360, "balances restored")
	_check(typeof(e2.st.wallet.bal.crystal) == TYPE_INT, "numbers normalised to int on load")
	_check(e2.energy.value() == 127 and e2.gacha.candles("lim_zlata") == 10, "energy and candles restored")
	_check(e2.shop.st.receipts.size() == 1 and e2.gacha.counter("limited").p == e.gacha.counter("limited").p, "receipts and pity restored")
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
	var lc: = em.gacha.counter("limited")
	_check(int(lc.p) == 37 and int(lc.s) == 4 and bool(lc.g) and lc.rules == "r0", "pity, S pity and 50/50 guarantee carried with their old rules")
	_check(em.gacha.newbie_left() == 35 and bool(em.gacha.st.newbie.ssr), "beginner: 15 used of 50, SSR already had")
	_check(em.pass_.tier() == 9 and bool(em.pass_.st.prem) and em.pass_.claimable().size() == 10, "pass progress and claims carried")
	_check(em.shop.month_days_left() == 10, "month card days carried (%d)" % em.shop.month_days_left())
	_check(em.shop.is_first(V10Catalog.sku("moon_180")), "fake 0.8 purchases do not burn the first-purchase bonus")
	_check(em.shop.available("guest_149").reason in ["expired", "server"], "beginner sets follow the original install date")
	_check(em.energy.value() == 160, "tea starts full")
	_check(em.audit().is_empty(), "migrated state audits clean: %s" % str(em.audit()))
	var empty: = V10Econ.from_legacy({"gems": 0, "unlocked": 1}, T0)
	_check(V10Econ.new(empty, null, [], T0).audit().is_empty(), "migrating a minimal save works")
