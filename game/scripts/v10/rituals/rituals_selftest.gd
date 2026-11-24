class_name V10RitualsSelftest
extends RefCounted

# Selftests of the rituals lane (docs/0.10-spec.md Р3–Р7, Р10). Headless-safe; never touches the real save or clock.
#   V10RitualsSelftest.run(only = "") -> int (fails)     prints «RIT_SELFTEST <module> ok/total» and a summary line
#   modules: streak, tray, comeback, bday, player_bday, week_letter, lint
# Spec flags map onto it (README): --streak_selftest=1 … --week_letter_selftest=1, --rit_selftest=all.

static var _ok: = 0
static var _n: = 0
static var _fails: = []
static var _grants: = []
const DAY: = 86400


static func _t(cond: bool, what: String) -> void:
	_n += 1
	if cond:
		_ok += 1
	else:
		_fails.append(what)
		print("  FAIL ", what)


static func _fresh(S: = {}) -> Dictionary:
	V10RitSave.bind(S)
	V10RitClock.clear()
	V10RitClock.use_meta = false
	V10RitClock.set_tz(0)
	_grants = []
	V10RitBridge.set_sink(func(r, src): _grants.append({"r": r, "src": src}))
	V10Tray.clear()
	V10Tele.reset_mem()
	V10Bday.heroes_override = ["mc", "rin", "hana", "yue", "nova"]
	return V10RitSave.root()


# unix of key at hh:mm UTC (tz pinned to 0)
static func _u(key: String, h: = 12, m: = 0) -> int:
	return V10RitClock.day_index(key) * DAY + h * 3600 + m * 60


static func _at(key: String, h: = 12) -> void:
	V10RitClock.set_now(_u(key, h))


static func run(only: = "") -> int:
	var total_ok: = 0
	var total_n: = 0
	var all_fails: = []
	var mods: = ["streak", "tray", "comeback", "bday", "player_bday", "week_letter", "lint"]
	for m in mods:
		if only != "" and only != "all" and only != m:
			continue
		_ok = 0
		_n = 0
		_fails = []
		match m:
			"streak": _streak()
			"tray": _tray()
			"comeback": _comeback()
			"bday": _bday()
			"player_bday": _player_bday()
			"week_letter": _week_letter()
			"lint": _lint()
		print("RIT_SELFTEST %s %d/%d" % [m, _ok, _n])
		total_ok += _ok
		total_n += _n
		all_fails.append_array(_fails)
	V10RitSave.unbind()
	V10RitClock.clear()
	V10RitClock.use_meta = true
	V10RitBridge.set_sink(Callable())
	V10Bday.heroes_override = []
	print("RIT_SELFTEST %d/%d%s" % [total_ok, total_n, "" if all_fails.is_empty() else " FAILS: " + ", ".join(all_fails)])
	return all_fails.size()


# ── Р3 streak ──────────────────────────────────────────────────────────────────────────────────────────────────

static func _streak() -> void:
	_fresh()
	var s: = V10Streak.st()
	# 01:30 belongs to yesterday; 04:00 starts the new day
	V10RitClock.set_now(_u("2026-03-10", 1, 30))
	_t(V10RitClock.day_key() == "2026-03-09", "01:30 → yesterday (%s)" % V10RitClock.day_key())
	V10RitClock.set_now(_u("2026-03-10", 4, 0))
	_t(V10RitClock.day_key() == "2026-03-10", "04:00 → today")
	_t(V10RitClock.weekday("2026-03-09") == 0, "2026-03-09 is Monday")
	# first run: gift leaf
	_fresh()
	s = V10Streak.st()
	_at("2026-03-10")
	V10Streak.check("2026-03-10")
	_t(int(s.leaves) == 1 and bool(s.gift), "gift leaf on first run")
	var r: = V10Streak.on_win("2026-03-10")
	_t(r.new_day and int(r.n) == 1, "first win → n=1")
	r = V10Streak.on_win("2026-03-10")
	_t(not r.new_day and int(s.n) == 1, "second win same day does not count")
	_at("2026-03-11")
	V10Streak.on_win("2026-03-11")
	_at("2026-03-12")
	r = V10Streak.on_win("2026-03-12")
	_t(int(s.n) == 3, "3 days → n=3")
	_t(r.milestones.size() == 1 and int(r.milestones[0].n) == 3 and int(_grants[-1].r.get("gems", 0)) == 50, "milestone 3 → 50 кр")
	# 1 missed day + 1 leaf → forgiven, leaf spent
	_at("2026-03-14")
	var ev: = V10Streak.check("2026-03-14")
	_t(ev.size() == 1 and ev[0].kind == "forgiven" and int(s.leaves) == 0 and int(s.n) == 3, "1 miss + 1 leaf → forgiven (%s)" % [ev])
	_t(str(s.hist.get("2026-03-13", "")) == "leaf", "missed day marked leaf")
	V10Streak.on_win("2026-03-14")
	_t(int(s.n) == 4, "streak continues after forgiveness")
	# 1 miss without leaf → repair; repair by 2 extra wins in 48 h
	_at("2026-03-16")   # Monday: +1 leaf arrives first! use it up by the rule: 1 miss, 1 leaf → forgiven
	ev = V10Streak.check("2026-03-16")
	_t(ev.size() == 1 and ev[0].kind == "forgiven" and int(s.leaves) == 0, "Monday leaf arrives before the miss is judged")
	_t(str(s.leaf_new_key) == "2026-03-16", "Monday leaf flagged for the tray")
	V10Streak.on_win("2026-03-16")
	_at("2026-03-18")
	ev = V10Streak.check("2026-03-18")
	_t(ev.size() == 1 and ev[0].kind == "cooled" and V10Streak.state_of("2026-03-18") == "cold", "1 miss, no leaf → cooled")
	var v: = V10Streak.view("2026-03-18")
	_t(str(v.repair.text).find("2 победы до пт 04:00") >= 0, "repair plate text (%s)" % v.repair.get("text", ""))
	var n_before: = int(s.n)
	V10Streak.on_win("2026-03-18")
	_t(int(s.n) == n_before + 1 and not (s.repair as Dictionary).is_empty(), "normal daily win during repair")
	V10Streak.on_win("2026-03-18")
	_at("2026-03-19")
	r = V10Streak.on_win("2026-03-19")   # new day: normal win
	r = V10Streak.on_win("2026-03-19")   # second extra → warmed
	_t(r.warmed and (s.repair as Dictionary).is_empty() and str(s.hist["2026-03-17"]) == "warm", "2 extra wins in 48 h → warmed")
	_t(int(s.n) == n_before + 3, "warmed day joins the run (%d vs %d)" % [int(s.n), n_before + 3])
	# repair expired → reset, best kept, milestones not taken back
	var best: = int(s.best)
	_at("2026-03-21")
	V10Streak.check("2026-03-21")
	_t(not (s.repair as Dictionary).is_empty(), "second cooled")
	_at("2026-03-23")   # Monday, window ended at 03-23 04:00; but the Monday leaf must not rescue an expired repair
	ev = V10Streak.check("2026-03-23")
	_t(int(s.n) == 0 and int(s.best) == best and 3 in s.got, "repair late → n=0, best intact, milestones kept (%s n=%d)" % [ev, int(s.n)])
	# 3 misses with 2 leaves → leaves kept, reset
	_fresh()
	s = V10Streak.st()
	_at("2026-04-01")
	V10Streak.check("2026-04-01")
	s.leaves = 2
	V10Streak.on_win("2026-04-01")
	_at("2026-04-05")
	ev = V10Streak.check("2026-04-05")
	_t(int(s.leaves) == 2 and int(s.n) == 0 and ev.size() == 1 and ev[0].kind == "reset", "3 misses, 2 leaves → leaves kept, reset")
	# 2 misses with 2 leaves → full cover
	_fresh()
	s = V10Streak.st()
	_at("2026-04-01")
	V10Streak.check("2026-04-01")
	s.leaves = 2
	V10Streak.on_win("2026-04-01")
	_at("2026-04-04")
	ev = V10Streak.check("2026-04-04")
	_t(int(s.leaves) == 0 and int(s.n) == 1 and ev[0].kind == "forgiven", "2 misses, 2 leaves → both spent, streak kept")
	# Monday +1 up to 2
	_fresh()
	s = V10Streak.st()
	_at("2026-04-01")   # Wednesday
	V10Streak.check("2026-04-01")
	_t(int(s.leaves) == 1, "gift 1")
	V10Streak.weekly_leaf("2026-04-06")
	_t(int(s.leaves) == 2, "Monday +1")
	V10Streak.weekly_leaf("2026-04-13")
	_t(int(s.leaves) == 2, "cap 2")
	V10Streak.weekly_leaf("2026-04-13")
	_t(int(s.leaves) == 2, "same Monday twice → no extra")
	# milestone once
	_fresh()
	s = V10Streak.st()
	for i in 8:
		var k: = V10RitClock.add_days("2026-05-01", i)
		_at(k)
		V10Streak.on_win(k)
	var m7: = _grants.filter(func(g): return g.src == "streak_milestone")
	_t(m7.size() == 2, "milestones 3 and 7 granted once each (%d)" % m7.size())
	s.n = 0
	s.last_win_key = ""
	for i in 8:
		var k: = V10RitClock.add_days("2026-06-01", i)
		_at(k)
		V10Streak.on_win(k)
	m7 = _grants.filter(func(g): return g.src == "streak_milestone")
	_t(m7.size() == 2, "milestone is once per lifetime")
	_t(V10Streak.milestone_rewards(90).get("gems", 0) == 50 and V10Streak.milestone_rewards(60).get("gems", 0) == 200, "after 30: +30 → 50 кр")
	# clock moved back → pending, applied when clock is fine
	_fresh()
	s = V10Streak.st()
	_at("2026-07-01")
	V10Streak.check("2026-07-01")
	V10RitClock.force_clock = 0
	r = V10Streak.on_win("2026-07-01")
	_t(r.pending and int(s.n) == 0 and s.pending.size() == 1, "clock back → win pending")
	V10RitClock.force_clock = 1
	V10Streak.check("2026-07-01")
	_t(int(s.n) == 1 and s.pending.is_empty(), "pending applied when the clock is back")
	# calendar
	var cal: = V10Streak.calendar("2026-07-01")
	_t(cal.size() == 35 and cal.filter(func(c): return c.today).size() == 1, "calendar 5 weeks")
	_t(V10Streak.RULE_TEXT.find("Листья не продаются") >= 0, "rule text")


# ── Р4 tray ────────────────────────────────────────────────────────────────────────────────────────────────────

static func _tray() -> void:
	_fresh()
	var calls: = {"a": 0, "b": 0}
	V10Tray.register("seven", func(k): return {"icon": "res://assets/icons/ticket.png", "title": "Семь встреч", "text": "День 2", "rewards": {"tickets": 1}, "claim": func(): calls.a += 1}, 90)
	V10Tray.register("card", func(k): return {"icon": "res://assets/icons/gem.png", "title": "Абонемент", "text": "+30", "rewards": {"gems": 30}, "claim": func(): calls.b += 1}, 70)
	V10Tray.register("none", func(k): return {}, 10)
	var cards: = V10Tray.collect("2026-03-10")
	_t(cards.size() == 2 and cards[0].id == "seven", "tray built from providers by prio (%d)" % cards.size())
	_t(V10Tray.should_show("2026-03-10"), "tray shows")
	var res: = V10Tray.claim_all("2026-03-10")
	_t(res.size() == 2 and calls.a == 1 and calls.b == 1, "claim each exactly once")
	V10Tray.claim_all("2026-03-10")
	_t(calls.a == 1 and calls.b == 1, "second claim is a no-op")
	_t(not V10Tray.should_show("2026-03-10"), "second visit same day → no tray")
	_t(V10Tray.should_show("2026-03-11"), "next day → tray again")
	V10Tray.clear()
	V10Tray.install_builtins()
	_t(not V10Tray.should_show("2026-03-12"), "nothing waiting → no tray")
	V10Streak.st().leaf_new_key = "2026-03-16"
	var before: = _grants.size()
	cards = V10Tray.collect("2026-03-16")
	_t(cards.size() == 1 and cards[0].id == "streak_leaf", "Monday leaf card")
	V10Tray.claim_all("2026-03-16")
	_t(str(V10Streak.st().leaf_new_key) == "", "leaf card acknowledged")
	_t(_grants.size() == before, "leaf card grants nothing twice (the leaf was granted by the streak)")


# ── Р5 comeback ────────────────────────────────────────────────────────────────────────────────────────────────

static func _comeback() -> void:
	for pair in [[2, ""], [3, "warm"], [6, "warm"], [7, "waited"], [12, "waited"], [20, "waited"], [29, "waited"], [30, "winds"], [90, "winds"]]:
		_t(V10Comeback.tier(int(pair[0])) == pair[1], "tier(%d) = %s" % pair)
	_t(V10Comeback.rested_add(3) == 60 and V10Comeback.rested_add(20) == 600 and V10Comeback.rested_add(2) == 0, "rested_add")
	_fresh()
	var s: = V10Comeback.st()
	_at("2026-03-01")
	V10Comeback.check("2026-03-01")
	_at("2026-03-03")
	var r: = V10Comeback.check("2026-03-03")
	_t(r.tier == "", "gap 2 → nothing")
	_at("2026-03-15")
	r = V10Comeback.check("2026-03-15")
	_t(r.tier == "waited" and r.ladder == "short" and int(s.rested) == 600, "gap 12 → waited, short ladder, Отдых (%s)" % [r])
	_t(V10Comeback.check("2026-03-15").tier == "", "second check same day → nothing")
	var sc: = V10Comeback.take_scene()
	_t(sc.tier == "waited" and V10Comeback.take_scene().is_empty(), "scene consumed once")
	# rested: ×1 in ranked, consumed per pair
	_t(V10Comeback.consume_rested(10, true) == 0 and int(s.rested) == 600, "ranked: Отдых not used")
	_t(V10Comeback.consume_rested(10) == 10 and int(s.rested) == 590, "each pair spends 1")
	# ladder: one step a day, skipped day never burns
	var lv: = V10Comeback.ladder_view("2026-03-15")
	_t(lv.days.size() == 3 and lv.can, "short ladder 3 days")
	V10Comeback.ladder_claim("2026-03-15")
	_t(V10Comeback.ladder_claim("2026-03-15").is_empty(), "one step per day")
	V10Comeback.ladder_claim("2026-03-20")
	_t(int(s.ladder.claimed) == 2, "skipped days do not burn the ladder")
	var rows: = V10Comeback.ladder_claim("2026-03-21")
	_t(rows.size() == 1 and rows[0].kind == "tickets" and int(s.ladder.claimed) == 3, "d3 = 1 билет")
	# the long ladder only once per 60 days
	_at("2026-04-10")
	r = V10Comeback.check("2026-04-10")
	_t(r.tier == "waited" and r.ladder == "", "ladder not again within 60 days (%s)" % [r])
	_at("2026-06-20")
	r = V10Comeback.check("2026-06-20")
	_t(r.tier == "winds" and r.ladder == "long", "after 60 days → long ladder")
	lv = V10Comeback.ladder_view("2026-06-20")
	_t(lv.days.size() == 7 and int(lv.days[2].rewards.get("tickets", 0)) == 10, "d3 of the long ladder = 10 билетов")
	_t(lv.days[4].rewards.has("pick_outfit") and lv.days[6].rewards.has("frame"), "d5 outfit pick, d7 frame")
	# rested never touches pass XP: the API has no pass input at all, only mastery pairs
	# backfill letters
	var away: = V10Comeback.while_away(40)
	_t(away.size() == 7 and away.all(func(l): return l.ev == "while_away"), "backfill ≤7 while_away letters")
	_t(V10Comeback.while_away(3).size() == 1, "small gap → 1 letter")
	# notify plan
	var base: = _u("2026-03-01", 20)
	var plan: = V10Comeback.notify_plan(base, true)
	var days: = plan.map(func(u): return V10RitClock.days_between("2026-03-01", V10RitClock.day_key(u)))
	_t(days == [3, 7, 11, 15, 19, 23, 27], "notify days 3,7,11…27 (%s)" % [days])
	_t(plan.all(func(u): return V10RitClock.local_hour(u) == 18), "18:30, outside quiet hours")
	_t(V10Comeback.notify_plan(base, false).is_empty(), "category off by default → empty")
	_t(plan.all(func(u): return V10RitClock.days_between("2026-03-01", V10RitClock.day_key(u)) < 30), "nothing after 30 days")
	# no price anywhere in the scene texts
	var texts: = V10Comeback.TIER_TITLE.values() + V10Comeback.NOTIFY_TEXT + V10Comeback.AWAY_SUBJ + V10Comeback.AWAY_BODY.values()
	for g in ["comeback_warm", "comeback_waited", "comeback_winds"]:
		for h in V10RitLines.L[g]:
			texts.append_array(V10RitLines.L[g][h])
	_t(texts.all(func(t): return V10RitBridge.lint(str(t)).is_empty() and str(t).find("₽") < 0), "comeback texts lint-clean, no prices")


# ── Р6 heroine birthdays ───────────────────────────────────────────────────────────────────────────────────────

static func _bday() -> void:
	_fresh()
	var pr: = V10BdayData.problems()
	_t(pr.is_empty(), "no blocked dates, ≥10 days apart (%s)" % [pr])
	_t(V10BdayData.DATES.size() == 20, "20 birthdays")
	V10Bday.heroes_override = ["mc", "rin", "hana", "yue", "nova"]
	_t(V10Bday.today_hero("2027-07-18") == "hana", "18.07 → hana")
	_t(V10Bday.window_hero("2027-07-15").get("h", "") == "hana" and V10Bday.window_hero("2027-07-21").get("h", "") == "hana", "window ±3")
	_t(V10Bday.window_hero("2027-07-22").is_empty() and V10Bday.window_hero("2027-07-14").is_empty(), "outside window")
	_t(V10Bday.today_hero("2027-03-18") == "", "unreleased heroine (zlata) does not celebrate")
	V10Bday.heroes_override = ["mc", "rin", "hana", "yue", "nova", "zlata"]
	_t(V10Bday.today_hero("2027-03-18") == "zlata", "released heroine celebrates")
	V10Bday.heroes_override = ["mc", "rin", "hana", "yue", "nova"]
	# overlay does not change the deal and is absent in ranked
	var faces: = [3, 3, 7, 7, 12, 12, 20, 20, 21, 21]
	var cfg: = {"ranked": false, "faces": faces, "seed": 42, "layout": "turtle"}
	var h0: = hash(cfg)
	var ov: = V10Bday.sig_overlay(cfg, "2027-07-18")
	_t(ov.get("h", "") == "hana" and (ov.faces as Array).size() == 2 and ov.faces[0] != ov.faces[1], "overlay: 2 face kinds")
	_t(hash(cfg) == h0, "overlay does not change the deal hash")
	_t((ov.icons as Array).size() == 2 and ov.icons[0] != ov.icons[1], "the two overlaid kinds stay distinguishable")
	_t(V10Bday.sig_overlay(cfg, "2027-07-18") == ov, "overlay deterministic")
	cfg.ranked = true
	_t(V10Bday.sig_overlay(cfg, "2027-07-18").is_empty(), "no overlay in ranked")
	cfg.ranked = false
	# goal 24 pairs, claim once a year
	for i in 30:
		V10Bday.on_pair(int(ov.faces[i % 2]), ov, "2027-07-17")
	V10Bday.on_pair(99, ov, "2027-07-17")
	var gv: = V10Bday.goal_view("2027-07-17")
	_t(int(gv.n) == 24 and gv.claimable, "goal 24/24 (%s)" % gv.get("text", ""))
	_t(str(gv.text).begins_with("Праздник Ханы: 24/24"), "goal text")
	var rows: = V10Bday.claim("2027-07-19")
	_t(rows.size() >= 4 and int(V10Streak.st().leaves) >= 1, "reward: frame, 100 кр, +30, leaf")
	var g: Dictionary = _grants[-1].r
	_t(str(g.get("frame", "")) == "bday_hana_2027" and int(g.get("gems", 0)) == 100 and int(g.aff.hana) == 30, "frame «Праздник Ханы · 2027»")
	_t(V10Bday.claim("2027-07-20").is_empty(), "frame once a year")
	for i in 24:
		V10Bday.on_pair(int(ov.faces[0]), ov, "2028-07-18")
	_t(V10Bday.goal_view("2028-07-18").claimable, "next year again")
	# letters
	_t(V10Bday.letter_order(["comeback", "bday", "combo"])[0] == "bday", "bday letter before comeback")
	_t(V10Bday.letter("rin").body != "" and V10RitBridge.lint(V10Bday.letter("rin").body).is_empty(), "bday letter lint-clean")
	_t(V10RitClock.local_hour(V10Bday.notify_at("2027-11-30")) == 10, "notify 10:30")


# ── Р7 player birthday ─────────────────────────────────────────────────────────────────────────────────────────

static func _player_bday() -> void:
	_fresh()
	var p: = V10PlayerBday.st()
	_t(not V10PlayerBday.ask_due("2026-03-02", "2026-03-01", true), "day 2 → not asked")
	_t(not V10PlayerBday.ask_due("2026-03-03", "2026-03-01", false), "day 3 before a win → not asked")
	_t(V10PlayerBday.ask_due("2026-03-03", "2026-03-01", true), "day 3 after the first win → asked")
	var r: = V10PlayerBday.set_date(5, 14, false, "2026-03-03")
	_t(not r.ok and r.err == "no_consent" and int(p.m) == 0, "no consent → nothing stored")
	r = V10PlayerBday.set_date(2, 30, true, "2026-03-03")
	_t(not r.ok and r.err == "invalid", "invalid date rejected")
	r = V10PlayerBday.set_date(3, 20, true, "2026-03-03")
	_t(r.ok and r.later and int(p.m) == 3, "date 17 days ahead → «отпразднуем в следующем году»")
	_t(not p.has("y") and not p.has("year"), "year never stored")
	_t(not V10PlayerBday.gift_due("2026-03-20"), "late date → no gift this year")
	_t(V10PlayerBday.gift_due("2027-03-20"), "gift next year")
	var rows: = V10PlayerBday.claim_gift("2027-03-20")
	_t(rows.size() == 3 and int(_grants[-1].r.tickets) == 3 and str(_grants[-1].r.frame) == "my_bday_2027", "gift: 3 билета, frame, +50")
	_t(int(_grants[-1].r.aff.values()[0]) == 50, "+50 симпатии партнёру")
	_t(V10PlayerBday.claim_gift("2027-03-20").is_empty(), "gift once a year")
	r = V10PlayerBday.set_date(6, 1, true, "2026-12-01")
	_t(not r.ok and r.err == "too_soon", "change sooner than 365 days refused")
	r = V10PlayerBday.set_date(6, 1, true, "2027-03-04")
	_t(r.ok and not r.later, "change after 365 days ok")
	V10PlayerBday.delete()
	_t(int(p.m) == 0 and int(p.d) == 0 and str(p.consent_key) == "" and not V10PlayerBday.has_date(), "delete clears the date")
	_t(V10PlayerBday.settings_text() == "Мой день рождения: не указан", "settings text after delete")
	V10PlayerBday.set_date(3, 14, true, "2028-04-01")
	_t(V10PlayerBday.settings_text() == "Мой день рождения: 14 мар · Удалить", "settings row (%s)" % V10PlayerBday.settings_text())
	V10PlayerBday.delete()
	V10PlayerBday.set_date(2, 29, true, "2029-05-01")
	_t(V10PlayerBday.gift_due("2030-02-28"), "29.02 celebrated on 28.02 in common years")
	# 152-ФЗ grep: nobody outside the rituals reads the player's date
	var leaks: = _grep("res://scripts", "v10_bday", ["res://scripts/v10/rituals"])
	_t(leaks.is_empty(), "shop/pay/analytics do not read v10_bday (%s)" % [leaks])
	_t(V10PlayerBday.PURPOSE.find("только день и месяц") >= 0, "purpose text")


static func _grep(dir: String, needle: String, skip: Array) -> Array:
	var out: = []
	var d: = DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var f: = d.get_next()
	while f != "":
		var p: = dir.path_join(f)
		if d.current_is_dir():
			if not (p in skip) and not f.begins_with("."):
				out.append_array(_grep(p, needle, skip))
		elif f.ends_with(".gd"):
			var txt: = FileAccess.get_file_as_string(p)
			if txt.find(needle) >= 0:
				out.append(p)
		f = d.get_next()
	return out


# ── Р10 weekly letter ──────────────────────────────────────────────────────────────────────────────────────────

static func _week_letter() -> void:
	_fresh()
	_t(V10RitLines.FACTS.size() == 24, "24 fact kinds")
	for h in ["mc", "rin", "hana", "yue", "nova"]:
		_t(V10RitLines.L.week_open[h].size() == 3 and V10RitLines.L.week_close[h].size() == 3, "3 voices for " + h)
	# a week with losses and night play: nothing from the black list
	var games: = [
		[{"won": false, "pairs": 20}, 2], [{"won": false, "pairs": 12}, 23], [{"won": true, "pairs": 36, "best_combo": 9, "secs": 140, "stars": 3, "hints": 0, "undos": 0, "fever": 1, "ults": 2, "hard": true}, 3],
		[{"won": true, "pairs": 36, "best_combo": 6, "secs": 200, "stars": 2, "hints": 1, "undos": 0, "fever": 2, "ults": 1}, 9],
		[{"won": true, "pairs": 36, "best_combo": 12, "secs": 95, "stars": 3, "hints": 0, "undos": 1, "fever": 1, "ults": 1, "mode": "blitz"}, 1],
	]
	var day: = 0
	for gm in games:
		var k: = V10RitClock.add_days("2026-03-09", day)
		day += 1
		_at(k)
		V10Tele.note_game(gm[0], k, int(gm[1]))
	V10Tele.add("touches", 5)
	V10Tele.flush("2026-03-14")
	var cur: Dictionary = V10Tele.st().cur
	_t(int(cur.get("losses", 0)) == 2 and int(cur.get("night_wins", 0)) == 2, "black-list counters recorded (proof)")
	var all: = V10WeekLetter.facts(cur)
	_t(all.all(func(f): return not (f.kind in ["losses", "night_wins"])), "facts never from the black list")
	var bad_words: = ["проигр", "ноч", "не было", "пропуст", "₽", "трат", "покуп", "другие игроки", "лучше, чем"]
	var clean: = true
	for seed in 40:
		var l: = V10WeekLetter.compose(cur, ["mc", "rin", "hana", "yue", "nova"][seed % 5], seed)
		if l.is_empty() or (l.facts as Array).size() != 3:
			clean = false
		var kinds: Array = l.get("kinds", [])
		if kinds.size() != 3 or kinds[0] == kinds[1] or kinds[1] == kinds[2] or kinds[0] == kinds[2]:
			clean = false
		for w in bad_words:
			if str(l.get("body", "")).to_lower().find(w) >= 0:
				clean = false
		if not V10RitBridge.lint(str(l.get("body", ""))).is_empty():
			clean = false
	_t(clean, "40 letters: 3 facts of different kinds, no black-list words, lint-clean")
	# empty week → no letter
	_t(V10WeekLetter.compose({"pairs": 10, "losses": 3}, "mc", 1).is_empty(), "0 wins → no letter")
	# due on Monday for the previous week, once
	_at("2026-03-16")
	var l2: = V10WeekLetter.due("2026-03-16", "rin")
	_t(not l2.is_empty() and str(l2.sign) == "Рин", "Monday: letter for last week")
	_t(V10WeekLetter.due("2026-03-17", "rin").is_empty(), "once a week")
	_at("2026-03-23")
	_t(V10WeekLetter.due("2026-03-23", "rin").is_empty(), "empty week after → no letter")


# ── lint over every heroine line ───────────────────────────────────────────────────────────────────────────────

static func _lint() -> void:
	var bad: = []
	for t in V10RitLines.all():
		var b: = V10RitBridge.lint(str(t))
		if not b.is_empty():
			bad.append("%s %s" % [t, b])
	_t(bad.is_empty(), "all ritual lines pass V10Lint (%s)" % [bad])
	_t(V10RitBridge.lint("Только сегодня скидка 50%!").size() >= 2, "lint catches FOMO")
	for t in [V10Streak.RULE_TEXT, V10PlayerBday.PURPOSE]:
		_t(V10RitBridge.lint(t).is_empty(), "UI text clean: " + t.substr(0, 24))
	# gendered past tense of the player is avoided (unknown gender)
	var gendered: = []
	for t in V10RitLines.all():
		for w in ["ты пришёл", "ты пришла", "ты был ", "ты была", "ты собрал ", "ты подарил ", "уходил "]:
			if str(t).to_lower().find(w) >= 0:
				gendered.append(t)
	_t(gendered.is_empty(), "no gendered past tense about the player (%s)" % [gendered])
