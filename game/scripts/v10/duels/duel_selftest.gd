extends Node

# The selftest of «Дуэли 2.0» (run by duel_selftest.tscn, README «Как запустить»).
#   --duel_selftest=1                     all checks, the last line: DUEL_SELFTEST ok/total (exit 0 when all pass)
#   --duel_calibrate=1 [--duel_cal_games=32 --duel_cal_heroes=all|released --duel_cal_write=1]   the race sim
#   --duel_shots=<dir> [--duel_shot_tag=720x1280]   a real ranked match with the auto bot, PNGs of its beats
#   --duel_race_debug=1 --duel_h=nova --duel_f=5     per-bot race totals of one heroine-form
# The real-match part instantiates main.tscn: run it with --save=user://duel_selftest.json --save_wipe=1.

const U: = preload("res://scripts/v10/duels/duel_util.gd")
const F: = preload("res://scripts/v10/duels/duel_forms.gd")
const R: = preload("res://scripts/v10/duels/duel_rank.gd")
const C: = preload("res://scripts/v10/duels/duel_cfg.gd")
const D: = preload("res://scripts/v10/duels/duel_state.gd")
const SIM: = preload("res://scripts/v10/duels/duel_sim.gd")
const RUN: = preload("res://scripts/v10/duels/duel_run.gd")
const PLAY2: = preload("res://scripts/v10/duels/duel_play.gd")

var args: = {}
var ok: = 0
var total: = 0
var main: Node
var paid: = []
var errs: = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv: = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	_run.call_deferred()


func check(name: String, cond: bool, info: = "") -> void:
	total += 1
	if cond:
		ok += 1
	else:
		print("DUEL_FAIL %s %s" % [name, info])


func _run() -> void:
	if args.has("duel_calibrate"):
		_calibrate()
		return
	if args.has("duel_race_debug"):
		_race_debug()
		return
	if args.has("duel_shots"):
		await _shots(String(args.duel_shots))
		get_tree().quit(0)
		return
	var t0: = Time.get_ticks_msec()
	U.no_disk = true
	_elo()
	_seasons()
	_forms()
	await _deals()
	_offers()
	_calibration()
	_state_flow()
	_caps()
	_weekly()
	_texts()
	_reset_test_state()
	U.no_disk = false
	await _real_matches()
	print("DUEL_SELFTEST time %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("DUEL_SELFTEST %d/%d" % [ok, total])
	get_tree().quit(0 if ok == total else 1)


func _reset_test_state() -> void:
	U.test_S = null
	U.fake_now = 0
	U.sink = Callable()
	D.reset_session()


func _fresh(rp: = 2000) -> Dictionary:
	var S: = {"rp": rp, "gems": 0, "petals": 0}
	U.test_S = S
	paid.clear()
	U.sink = func(rw, src): paid.append([rw, src])
	D.reset_session()
	return S


func _paid_sum(key: String) -> int:
	var n: = 0
	for p in paid:
		n += int(p[0].get(key, 0))
	return n


# ---------------------------------------------------------------- Elo

func _elo() -> void:
	check("elo expected even", is_equal_approx(R.expected(1000, 1000), 0.5))
	check("elo expected +200", absf(R.expected(1200, 1000) - 0.7597) < 0.001, str(R.expected(1200, 1000)))
	check("elo K 40 for the first 20", R.k_for(0) == 40 and R.k_for(19) == 40)
	check("elo K 24 after 20", R.k_for(20) == 24 and R.k_for(300) == 24)
	check("elo win even new", R.delta(1000, 1000, 1.0, 0) == 20)
	check("elo loss even new", R.delta(1000, 1000, 0.0, 0) == -20)
	check("elo draw even", R.delta(1000, 1000, 0.5, 5) == 0)
	check("elo win even settled", R.delta(1000, 1000, 1.0, 25) == 12)
	check("elo zero sum", R.delta(1100, 1250, 1.0, 30) + R.delta(1250, 1100, 0.0, 30) == 0)
	check("elo win never below +1", R.delta(2400, 600, 1.0, 40) >= 1)
	check("elo loss never above -1", R.delta(600, 2400, 0.0, 40) <= -1)
	check("chance text", R.chance_text(1000, 1000) == "50 из 100", R.chance_text(1000, 1000))
	check("chance bounds", R.chance(3000, 100) == 99 and R.chance(100, 3000) == 1)
	check("tiers 6", R.TIERS.size() == 6 and R.tier_name(0) == "Бронзовый веер" and R.tier_name(5) == "Небесный веер")
	check("tier edges", R.tier_of(999) == 0 and R.tier_of(1000) == 1 and R.tier_of(1799) == 4 and R.tier_of(1800) == 5)
	check("rating text", R.rating_text(1040) == "Рейтинг " + U.fmt_int(1040) and U.fmt_int(1040).length() == 5)
	check("soft reset", R.soft_reset(1400) == 1200 and R.soft_reset(800) == 900 and R.soft_reset(1000) == 1000)
	check("season rewards by tier", R.season_reward(0).gems == 50 and R.season_reward(3).frame == "fr_duel_cinnabar"
		and R.season_reward(4).title == "t_duel_pearl" and R.season_reward(5).gems == 500)
	var cos: = R.cos_defs()
	check("season cosmetics never sold", cos.all(func(e): return String(e.src.type) == "grant") and cos.size() == 4)
	check("sky frame animated", cos.filter(func(e): return e.id == "fr_duel_sky")[0].look.get("anim", false) == true)


# ---------------------------------------------------------------- seasons

func _seasons() -> void:
	var s1: = U.season_start(U.SEASON_ONE)
	check("season 1 starts Mon 23 Nov 2026 04:00 MSK", s1 == Time.get_unix_time_from_datetime_string("2026-11-23T01:00:00"), str(s1))
	check("season is 28 days", U.season_end(U.SEASON_ONE) - s1 == 28 * 86400)
	check("season id at its edges", U.season_id(s1) == U.SEASON_ONE and U.season_id(s1 - 1) == U.SEASON_ONE - 1)
	check("season num", U.season_num(U.SEASON_ONE) == 1 and U.season_num(U.SEASON_ONE + 1) == 2)
	check("season end text", U.until_text(U.season_end(U.SEASON_ONE)) == "до " + U.date_msk(U.season_end(U.SEASON_ONE)))
	check("countdown only last 48 h", U.countdown(s1 + 100 * 3600, s1) == "" and U.countdown(s1 + 47 * 3600, s1) == "47:00")
	var S: = _fresh()
	U.fake_now = s1 + 3600
	var d: = D.st()
	check("season set on first open", int(d.season) == U.SEASON_ONE)
	d.dr = 1450
	d.peak_tier = 3
	d.peak_dr = 1450
	d.season_games = 5
	d.dr = 1300  # peak counts, not the rating at the end
	U.fake_now = U.season_end(U.SEASON_ONE) + 60
	D.st()
	check("season end pays once", paid.size() == 1 and _paid_sum("gems") == 250, str(paid))
	check("season end by peak tier frame", paid.size() == 1 and String(paid[0][0].get("frame", "")) == "fr_duel_cinnabar")
	check("soft reset applied", int(S.v10_duel.dr) == R.clamp_dr(1150), str(S.v10_duel.dr))
	D.st()
	U.fake_now += 3 * 86400
	D.st()
	check("season reward never twice", paid.size() == 1, str(paid.size()))
	U.fake_now = s1 + 3600  # the clock moved back: never a second reward
	D.st()
	check("moved clock pays nothing", paid.size() == 1)
	var sr: = D.take_season_reward()
	check("season ceremony once", int(sr.get("tier", -1)) == 3 and D.take_season_reward().is_empty())
	U.fake_now = U.season_end(U.SEASON_ONE + 1) + 60
	D.st()
	check("no games no season reward", paid.size() == 1)
	var info: = D.season_info()
	check("season info text", String(info.text).begins_with("Сезон 3 · до "), String(info.text))


# ---------------------------------------------------------------- forms

func _forms() -> void:
	var hs: Array = F.heroes(true)
	check("roster 20 with forms", hs.size() == 20)
	var cap_ok: = true
	var tele_ok: = true
	var pace_ok: = true
	var rb_ok: = true
	for h in hs:
		for f in range(1, F.FORMS + 1):
			for kind in ["ranked", "friendly", "weekly"]:
				var p: = F.run_params(h, f, kind, 0)
				if int(p.trick_n) > F.TRICK_CAP or int(p.trick_n) < 1:
					cap_ok = false
				if float(p.telegraph) < 0.7 or float(p.telegraph) > 1.2:
					tele_ok = false
			if F.run_params(h, f, "ranked", 0).pace != F.run_params(h, f, "ranked", 60).pace:
				pace_ok = false
			if f > 1 and float(F.form(h, f).pace) >= float(F.form(h, f - 1).pace):
				pace_ok = false
			if F.run_params(h, f, "friendly", 5).pace >= F.run_params(h, f, "friendly", 0).pace:
				rb_ok = false
	check("trick count within cap 2", cap_ok)
	check("telegraph 0.7-1.2 s", tele_ok)
	check("ranked pace independent of wins", pace_ok)
	check("friendly keeps the rubber band", rb_ok)
	check("trick text", F.trick_text("yue", 4) == "Лунная вуаль · 2 раза", F.trick_text("yue", 4))
	var rel: = F.heroes()
	check("released only in lists", rel.all(func(h): return U.is_released(h)) and not rel.has("tsubame"))
	var wr: = {}
	for w in range(2960, 2970):
		wr[F.weekly_rival(w)] = true
	check("weekly rival rotates over released", wr.size() == rel.size() and wr.keys().all(func(h): return rel.has(h)))
	check("weekly rival of a week fixed", F.weekly_rival(2968) == F.weekly_rival(2968))


# ---------------------------------------------------------------- deals

func _deals() -> void:
	var day: = "2026-11-24"
	var a: = C.deal_seed("ranked", day, "rin", 3)
	check("deal seed stable", a == C.deal_seed("ranked", day, "rin", 3))
	check("deal seed per form", a != C.deal_seed("ranked", day, "rin", 4))
	check("deal seed per rival", a != C.deal_seed("ranked", day, "hana", 3))
	check("deal seed per day", a != C.deal_seed("ranked", "2026-11-25", "rin", 3))
	check("friendly never today's ranked table", a != C.deal_seed("friendly", day, "rin", 3))
	var c1: = C.cfg_for({"duel2": true, "kind": "ranked", "rival": "rin", "form": 3, "seed": a}, "mc")
	var c2: = C.cfg_for({"duel2": true, "kind": "ranked", "rival": "rin", "form": 3, "seed": a}, "hana")
	check("cfg seed locked", int(c1.seed) == a and bool(c1.seed_locked) and c1.shape == c2.shape)
	check("cfg normalized ranked", bool(c1.normalized) and C.normalized({"duel2": true, "kind": "ranked"}))
	check("friendly not normalized", not C.normalized({"duel2": true, "kind": "friendly"}))
	check("ranked helps 1/0/0", C.helps_for({"duel2": true, "kind": "ranked"}) == {"hint": 1, "undo": 0, "shuffle": 0})
	var wc: = C.cfg_for({"duel2": true, "kind": "weekly", "rival": "mc", "form": 3, "seed": 5}, "mc")
	check("weekly rule on the table", int(wc.gold) == 16 and String(wc.rule) == "gold")
	# the real TrayBoard: the same seed gives the same faces (hook H2: seed right before the deal)
	var f1: = await _faces(c1)
	var f2: = await _faces(c1)
	var c3: = c1.duplicate()
	c3.seed = a + 1
	var f3: = await _faces(c3)
	check("one deal per seed: same faces", f1 == f2 and f1.size() > 20, "%d %d" % [f1.size(), f2.size()])
	check("other seed other deal", f1 != f3)


func _faces(cfg: Dictionary) -> Array:
	var b: = V6SpecialBoard.new()
	add_child(b)
	await get_tree().process_frame
	seed(int(cfg.seed))
	b.setup(cfg)
	var out: = []
	for t in b.tiles:
		out.append([t.gx, t.gy, t.gz, t.face, t.gold])
	b.queue_free()
	return out


# ---------------------------------------------------------------- offers

func _offers() -> void:
	var day: = "2026-11-24"
	var bd: = R.bounds()
	check("rating band covers the tiers", bd.x <= 900 and bd.y >= 1850, str(bd))
	var all_ok: = true
	var info: = ""
	var x: = bd.x
	while x <= bd.y:
		var o: = R.offers(x, day, {}, 0)
		if o.size() != 3:
			all_ok = false
			info = "%d: %d offers" % [x, o.size()]
		for e in o:
			if absi(int(e.dr_opp) - x) > R.WINDOW or not U.is_released(String(e.rival)) or int(e.price) != 0:
				all_ok = false
				info = "%d: %s" % [x, str(e.id)]
		x += 17
	check("3 offers within ±150 everywhere", all_ok, info)
	var o1: = R.offers(1000, day, {}, 0)
	var o2: = R.offers(1000, day, {}, 0)
	check("offers deterministic", JSON.stringify(o1) == JSON.stringify(o2))
	var hs: = {}
	for e in o1:
		hs[e.rival] = true
	check("offers distinct heroines", hs.size() == 3)
	check("offer seed is the day's deal", int(o1[0].seed) == C.deal_seed("ranked", day, String(o1[0].rival), int(o1[0].form), 0))
	check("offer badge", o1.all(func(e): return String(e.badge) == "ИИ · героиня"))
	var used: = {"%s|%d" % [o1[0].rival, o1[0].form]: 0}
	var o3: = R.offers(1000, day, used, 0)
	check("played offer not offered again", not o3.any(func(e): return e.rival == o1[0].rival and int(e.form) == int(o1[0].form) and int(e.round) == 0))
	check("clamp keeps rating in the band", R.clamp_dr(100) == bd.x and R.clamp_dr(9000) == bd.y)
	var badge_ok: = true
	for h in F.heroes():
		for f in range(1, F.FORMS + 1):
			if String(R.make_offer("ranked", h, f, day, 1000).badge) != "ИИ · героиня":
				badge_ok = false
	check("every rival has the AI badge", badge_ok)


# ---------------------------------------------------------------- calibration

func _calibration() -> void:
	R.reload()
	var f: = FileAccess.open(R.RATINGS_PATH, FileAccess.READ)
	check("ratings file in the repo", f != null)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	check("ratings file parses", data is Dictionary and data.get("ratings") is Dictionary)
	if not (data is Dictionary):
		return
	var mono: = true
	var info: = ""
	for h in F.heroes(true):
		var r = data.ratings.get(h)
		if not (r is Array) or r.size() != F.FORMS:
			mono = false
			info = h
			continue
		for i in range(1, F.FORMS):
			if int(r[i]) <= int(r[i - 1]):
				mono = false
				info = "%s %s" % [h, str(r)]
	check("calibration strictly monotone in form", mono, info)
	check("calibration games per cell", int(data.get("games_per_cell", 0)) >= 24)
	check("calibration anchor", String(data.anchor.bot) == "casual" and int(data.bots.casual) == 1000)
	check("rating reads the file", R.rating("rin", 3) == int(data.ratings.rin[2]))
	check("monotone fix", SIM.monotone([1000, 900, 1100, 1090, 1300]).reduce(func(acc, v): return [acc[1] < v, v] if acc[0] else [false, v], [true, -99999])[0])
	var cfg: = SIM.table_cfg("nova", 3, 77)
	var o: = SIM.race(cfg, F.run_params("nova", 3, "ranked"), "steady", U.rng(1, "t"))
	check("race sim plays a table", int(o.me) + int(o.her) >= 15 and float(o.secs) > 20.0, str(o))


# ---------------------------------------------------------------- start → pending → finish

func _state_flow() -> void:
	var S: = _fresh()
	U.fake_now = U.season_start(U.SEASON_ONE) + 5 * 86400 + 3600 * 10
	check("ranked open at rp 2000", D.ranked_open())
	var offs: = D.offers()
	check("3 stored offers", offs.size() == 3)
	check("offers stable in a day", JSON.stringify(D.offers()) == JSON.stringify(offs))
	check("offer stake text", String(offs[0].stake_text).begins_with("Победа +"))
	var bad: Dictionary = offs[0].duplicate()
	bad.id = "ranked|forged"
	check("forged offer refused", D.start(bad).has("error"))
	var a: = D.start(offs[0], "mc")
	check("start returns match args", String(a.get("mode", "")) == "duel" and bool(a.duel2) and int(a.seed) == int(offs[0].seed))
	var d: Dictionary = S.v10_duel
	check("pending written before the match", String(d.pending.get("id", "")) == String(a.duel_id))
	check("offer consumed", (d.offers.list as Array).is_empty())
	# the app was killed: the next open settles the match as a loss
	D.live_id = ""
	D.st()
	check("killed match = loss", int(d.losses) == 1 and (d.pending as Dictionary).is_empty() and bool(d.last_result.killed))
	check("killed loss rating", int(d.dr) == 1000 + int(offs[0].lose_delta), "%d %d" % [int(d.dr), int(offs[0].lose_delta)])
	var offs2: = D.offers()
	check("played offer gone", not offs2.any(func(e): return e.rival == offs[0].rival and int(e.form) == int(offs[0].form) and int(e.round) == 0))
	var a2: = D.start(offs2[1], "mc")
	var r_wrong: = D.finish("nope", 9, 0)
	check("wrong id settles nothing", r_wrong.is_empty() and not (d.pending as Dictionary).is_empty())
	var dr0: = int(d.dr)
	var res: = D.finish(String(a2.duel_id), 9, 4, {"steals": 2})
	check("finish win", bool(res.win) and int(d.wins) == 1 and int(d.games) == 2)
	check("finish rating delta shown", int(res.rating.delta) == int(d.dr) - dr0 and int(res.rating.delta) == int(offs2[1].win_delta))
	check("finish idempotent", JSON.stringify(D.finish(String(a2.duel_id), 9, 4)) == JSON.stringify(res) and int(d.games) == 2)
	check("result rows", (res.rows as Array).size() == 1 and int(res.rewards.gems) == 5)
	check("history", (d.history as Array).size() == 2 and bool(d.history[0].win))
	var a3: = D.start(D.offers()[0], "mc")
	var r3: = D.abandon(String(a3.duel_id), 3, 1)
	check("exit = loss even ahead", bool(r3.exit) and not bool(r3.win) and int(d.losses) == 2)
	check("leave text names the rating", D.leave_text() == "Выход засчитается поражением")
	D.start(D.offers()[0], "mc")
	check("leave text ranked", D.leave_text().begins_with("Выход засчитается поражением: рейтинг −"), D.leave_text())
	D.abandon(String(d.pending.id))
	for i in 30:
		var o: = D.offers()
		var aa: = D.start(o[0], "mc")
		D.finish(String(aa.duel_id), 0, 9)
	check("rating stays in the band", int(d.dr) >= R.bounds().x)
	check("history capped 20", (d.history as Array).size() == 20)
	# the gate
	_fresh(0)
	U.fake_now = U.season_start(U.SEASON_ONE) + 86400
	check("ranked locked at rp 0", not D.ranked_open() and D.start(R.make_offer("ranked", "rin", 2, U.cal_key(), 1000)).has("error"))
	check("menu locked at rp 0", not D.menu_open() and D.lock_text() == "Откроется на ранге Нефрит III")
	check("Нефрит III index", R.jade3_index() == 5 and G.rank_title(1, 2) == "Нефрит III")


# ---------------------------------------------------------------- caps

func _caps() -> void:
	var S: = _fresh()
	U.fake_now = U.season_start(U.SEASON_ONE) + 2 * 86400 + 3600 * 12
	for i in 4:
		var a: = D.start(D.offers()[0], "mc")
		D.finish(String(a.duel_id), 9, 1)
	check("ranked: crystals for 3 wins a day", _paid_sum("gems") == 15, str(_paid_sum("gems")))
	check("ranked cap text", D.caps().ranked_left == 0 and String(D.caps().ranked_text).contains("завтра"))
	U.fake_now += 86400
	var a2: = D.start(D.offers()[0], "mc")
	D.finish(String(a2.duel_id), 9, 1)
	check("ranked cap new day", _paid_sum("gems") == 20)
	paid.clear()
	var aff: = 0
	for i in 4:
		var fo: = D.friendly_offers("hana")
		var a: = D.start(fo[1], "rin")
		var r: = D.finish(String(a.duel_id), 9, 2)
		aff += int(r.rewards.get("aff", {}).get("hana", 0))
	check("friendly: 3 crystals for 3 wins a day", _paid_sum("gems") == 9, str(_paid_sum("gems")))
	check("friendly: +1 affection each win", aff == 4)
	check("friendly forms II-IV", D.friendly_offers("hana").map(func(o): return int(o.form)) == [2, 3, 4])
	check("friendly form V refused", D.start(R.make_offer("friendly", "hana", 5, U.cal_key(), 1000)).has("error"))
	_fresh(0)
	U.fake_now = U.season_start(U.SEASON_ONE) + 3 * 86400
	var unlocked: = false
	for i in 10:
		var a: = D.start(D.friendly_offers("rin")[0], "mc")
		var r: = D.finish(String(a.duel_id), 9, 0)
		if bool(r.unlocked_ranked):
			unlocked = i == 9
	check("10 friendly wins open ranked", unlocked and D.ranked_open())
	S = _fresh(0)
	S["v6_heroines"] = {"duel_wins": {"rin": 4, "hana": 3}}
	check("0.6 duel wins migrate", int(D.st().casual_wins) == 7)


# ---------------------------------------------------------------- weekly

func _weekly() -> void:
	_fresh()
	U.fake_now = U.season_start(U.SEASON_ONE) + 86400
	var w: = D.weekly_offer()
	check("weekly rival of the week", String(w.rival) == F.weekly_rival(U.week_id(U.fake_now)))
	check("weekly texts", String(w.until_text).begins_with("до ") and String(w.progress_text) == "0 из 3 побед")
	var res: = {}
	for i in 4:
		var a: = D.start(D.weekly_offer(), "mc")
		if a.has("error"):
			check("weekly closed after claim", i == 3, str(a))
			break
		res = D.finish(String(a.duel_id), 9, 0)
	check("weekly 3 wins pay once", _paid_sum("gems") == 100 and _paid_sum("petals") == 30 and paid.size() == 1, str(paid))
	check("weekly just done", bool(res.weekly.get("just_done", false)))
	U.fake_now += 7 * 86400
	var w2: = D.weekly_offer()
	check("new week resets", int(w2.wins) == 0 and not bool(w2.claimed))
	var a3: = D.start(w2, "mc")
	U.fake_now += 7 * 86400
	var r3: = D.finish(String(a3.duel_id), 9, 0)
	check("a game across the week edge counts nowhere", int(D.weekly_offer().wins) == 0 and _paid_sum("gems") == 100, str(r3.weekly))


# ---------------------------------------------------------------- texts

func _texts() -> void:
	_fresh()
	var ts: Array = []
	ts.append_array(F.all_texts())
	ts.append_array(R.all_texts())
	ts.append_array(C.all_texts())
	ts.append_array(D.all_texts())
	ts.append_array(RUN.T_HELP_RANKED.values())
	ts.append_array(RUN.T_HELP_OUT.values())
	ts.append_array([RUN.BADGE, "Перехват!", "Вдвое быстрее · 7 секунд", "Лоток полон: пара сопернице", "Выйти из партии?",
		"Дальше", "Новая ступень: Лаковый веер", "Дуэль недели · 2 из 3 побед", "ТЫ", "ПАРЫ", "Форма III"])
	for r in U.reward_rows({"gems": 5, "petals": 30, "aff": {"rin": 1}, "frame": "fr_duel_sky", "title": "t_duel_pearl"}):
		ts.append(String(r.text))
	ts.append(D.season_info().text)
	ts.append(D.weekly_offer().until_text)
	var bad: = []
	for t in ts:
		var b: = U.lint(String(t))
		if not b.is_empty():
			bad.append("%s %s" % [t, str(b)])
	check("strings lint-clean (no %, ₽, ДР, stop words)", bad.is_empty(), str(bad))
	check("lint catches", not U.lint("Скидка 50%").is_empty() and not U.lint("ДР 1040").is_empty())


# ---------------------------------------------------------------- the real play screen

func _boot_main() -> void:
	main = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 4:
		await get_tree().process_frame
	_clear_main()


func _clear_main() -> void:
	for c in main.overlay.get_children():
		c.queue_free()
	for c in main.get_children():
		if c in [main.screen_root, main.topbar, main.navbar, main.overlay, main.trans, main.finger]:
			continue
		if c is CanvasItem and not c.name.begins_with("V"):
			c.queue_free()


func _wait_end(run, secs: float) -> bool:
	var t0: = Time.get_ticks_msec()
	while is_instance_valid(run) and not run.finished and (Time.get_ticks_msec() - t0) < secs * 1000.0:
		await get_tree().process_frame
	return is_instance_valid(run) and run.finished


func _real_matches() -> void:
	await _boot_main()
	G.S.rp = 2000
	G.S.level_partner = "mc"
	G.S.gems = 500
	var d: = D.st()
	RUN.auto_gap = 0.32
	RUN.auto_notice = 0.6
	Engine.time_scale = 4.0
	# ---- route «adopt»: main.go("play", args) of today's play.gd, then the swap (no edits to play.gd)
	var offs: = D.offers()
	var off: Dictionary = offs[0]
	var a: = D.start(off, "mc")
	var gems0: = int(G.S.gems)
	var run = await RUN.launch(main, a)
	check("adopt: run node on the real play screen", run != null and main.screen.duel == run and main.screen.get_node_or_null("V10DuelRun") != null)
	if run == null:
		Engine.time_scale = 1.0
		return
	var play: Control = main.screen
	check("adopt: V6Duel gone", play.get_children().filter(func(c): return c.get_script() == V6Duel and not c.is_queued_for_deletion()).is_empty())
	check("adopt: fixed seed", int(play.cfg.seed) == int(off.seed) and int(play.cfg.seed) == C.deal_seed("ranked", U.cal_key(), String(off.rival), int(off.form)))
	check("adopt: ranked 4 slots for mc", play.board.slots == 4 and play.slot_rects.size() == 4, "%d %d" % [play.board.slots, play.slot_rects.size()])
	check("adopt: helps 1/0/0", play.hint_n == 1 and play.undo_n == 0 and play.shuffle_n == 0)
	check("adopt: no outfit passives", play.get_node_or_null("V7PassiveRun") == null)
	check("adopt: no gifts or streak", (play.board.spec as Dictionary).is_empty() and play.get_node("V6Specials").plan.get("streak", true) == false)
	check("adopt: pace is the form's", is_equal_approx(run.pace, float(F.form(String(off.rival), int(off.form)).pace)))
	check("adopt: AI badge on her stage", run.badge != null and String(run.badge.get_node("Text").text) == "ИИ · ГЕРОИНЯ")
	check("adopt: Приём ranked", play.ult.ranked and play.ult.mod == "")
	await get_tree().create_timer(2.5).timeout
	var faces_adopt: Array = play.board.tiles.map(func(t): return [t.gx, t.gy, t.gz, t.face])
	var caps_ok: = [btn_caps(play)]
	play.btn_undo.activate()
	await get_tree().process_frame
	check("ranked: exhausted help denies with no price", int(G.S.gems) == gems0 and not _overlay_has_price() and String(play.btn_undo.get_node("Cap").text) == V6Txt.s("play.undo") + " · 0", play.btn_undo.get_node("Cap").text)
	var ended: = await _wait_end(run, 120.0)
	caps_ok.append(btn_caps(play))
	check("ranked: no price on help buttons", caps_ok.all(func(x): return x), str(caps_ok))
	check("adopt: match ended", ended)
	check("adopt: tricks within cap", run.tricks <= run.trick_n and run.trick_n <= 2, "%d/%d" % [run.tricks, run.trick_n])
	var res: Dictionary = play.get_meta("v10_duel_result", {})
	check("adopt: result recorded", not res.is_empty() and (d.pending as Dictionary).is_empty() and int(d.games) == 1)
	check("adopt: score on the result", int(res.get("me", -1)) == run.me and int(res.get("her", -1)) == run.her)
	var want_gems: = 5 if bool(res.get("win", false)) else 0
	check("adopt: no crystals per pair, cap reward only", int(G.S.gems) - gems0 == want_gems, "%d vs %d (%s)" % [int(G.S.gems) - gems0, want_gems, str(res.get("rewards"))])
	print("DUEL_SELFTEST adopt match %d:%d steals %d tricks %d" % [run.me, run.her, run.steals, run.tricks])
	await get_tree().create_timer(1.6).timeout
	check("fallback result sheet (no ceremony set)", play.get_node_or_null("V10DuelSheet") != null)
	check("no 0.8 result window", play.get_node_or_null("V8Result") == null)
	var sheet: Node = play.get_node_or_null("V10DuelSheet")
	var prim: = 0
	if sheet:
		for n in sheet.find_children("*", "", true, false):
			if n.get_meta("ux_role", "") == "primary":
				prim += 1
	check("result sheet: exactly one primary", prim == 1)
	# ---- route A: duel_play.gd (play.gd subclass) with the same args and seed deals the same table
	var same: = a.duplicate()
	same.duel_id = ""
	var p2: = _mount(same)
	await get_tree().create_timer(2.5).timeout
	var faces_a: Array = p2.board.tiles.map(func(t): return [t.gx, t.gy, t.gz, t.face])
	check("same (day, rival, form): same table in both routes", faces_a == faces_adopt and faces_a.size() > 20, "%d %d" % [faces_a.size(), faces_adopt.size()])
	check("route A: run node", p2.duel is V10DuelRun and p2.board.slots == 4 and p2.hint_n == 1)
	# ---- route A: a friendly match to the end, the ceremony contract
	var got: = []
	RUN.ceremony = func(pp, rr): got.append([pp, rr])
	var fo: Dictionary = D.friendly_offers("hana")[1]
	var gems1: = int(G.S.gems)
	var aff0: = int(G.aff_level("hana")) if G.has_method("aff_level") else 0
	var fa: = D.start(fo, "rin")
	var p3: = _mount(fa)
	var run3 = p3.duel
	var sig: = []
	run3.result_ready.connect(func(rr): sig.append(rr))
	check("friendly: not normalized", p3.board.slots == V7Passives.slots("rin", 4) and not p3.ult.ranked)
	var ended3: = await _wait_end(run3, 120.0)
	check("route A: friendly match ended", ended3)
	await get_tree().create_timer(1.6).timeout
	check("result_ready signal", sig.size() == 1 and String(sig[0].get("kind", "")) == "friendly")
	check("ceremony called once with the result", got.size() == 1 and got[0][0] == p3 and String(got[0][1].get("id", "")) == String(fa.duel_id))
	var fr: Dictionary = got[0][1] if not got.is_empty() else {}
	var fw: = bool(fr.get("win", false))
	check("friendly reward", int(G.S.gems) - gems1 == (3 if fw else 0), "%d win=%s" % [int(G.S.gems) - gems1, fw])
	print("DUEL_SELFTEST friendly match %d:%d affection %d" % [run3.me, run3.her, aff0])
	RUN.ceremony = Callable()
	# ---- exit = loss through the real leave (home button / Android back → confirm → «Выйти»)
	var a4: = D.start(D.offers()[0], "mc")
	var p4: = _mount(a4)
	await get_tree().create_timer(1.0).timeout
	var losses0: = int(d.losses)
	(p4.get_meta("v8_back") as Callable).call()
	await get_tree().process_frame
	var yes: JButton = null
	var said: = ""
	for n in main.overlay.find_children("*", "", true, false):
		if n is JButton and (n as JButton).lbl and (n as JButton).lbl.text == "Выйти":
			yes = n
		if n is Label and String((n as Label).text).begins_with("Выход засчитается поражением"):
			said = (n as Label).text
	check("leave confirm says exit = loss", said.begins_with("Выход засчитается поражением: рейтинг −"), said)
	if yes:
		yes.pressed.emit()
	await get_tree().create_timer(1.2).timeout
	check("exit = loss in the real match", int(d.losses) == losses0 + 1 and (d.pending as Dictionary).is_empty() and bool(d.last_result.exit))
	Engine.time_scale = 1.0
	RUN.auto_gap = 0.0


func btn_caps(play) -> bool:
	for k in ["hint", "undo", "shuffle"]:
		var cap: String = play.get("btn_" + k).get_node("Cap").text
		if cap.contains("кр") or cap.contains("30"):
			return false
	return true


func _overlay_has_price() -> bool:
	for n in main.overlay.find_children("*", "Label", true, false):
		if String((n as Label).text).contains("30"):
			return true
	return false


# main.go for a screen main.SCREENS does not list yet (Route A before the integrator registers "duel2")
func _mount(a: Dictionary) -> Control:
	for c in main.overlay.get_children():
		c.queue_free()
	if main.screen and is_instance_valid(main.screen):
		main.screen.queue_free()
	var s: = Control.new()
	s.set_script(PLAY2)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.position = main.CR.position
	s.size = main.CR.size
	s.set_meta("v8_args", a.duplicate())
	main.screen_root.add_child(s)
	main.screen = s
	main.screen_id = "play"
	s.call("build", main, a)
	return s


# ---------------------------------------------------------------- screenshots (rendered run)

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var tag: = String(args.get("duel_shot_tag", "%dx%d" % [int(get_viewport().get_visible_rect().size.x), int(get_viewport().get_visible_rect().size.y)]))
	await _boot_main()
	G.S.rp = 2000
	G.S.level_partner = "mc"
	var off: Dictionary = D.offers()[0]
	for o in D.offers():
		if String(o.rival) == String(args.get("duel_h", "yue")):
			off = o
	RUN.auto_gap = 0.55
	RUN.auto_notice = 0.35
	var a: = D.start(off, "mc")
	var p: = _mount(a)
	var run = p.duel
	var t0: = Time.get_ticks_msec()
	while is_instance_valid(run) and run.target.is_empty() and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	await _snap(dir, "duel_mark_" + tag)
	while is_instance_valid(run) and not run.casting and not run.finished and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	await _snap(dir, "duel_trick_" + tag)
	Engine.time_scale = 3.0
	while is_instance_valid(run) and not run.finished and Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	await get_tree().create_timer(2.2).timeout
	await _snap(dir, "duel_result_" + tag)
	RUN.auto_gap = 0.0


func _snap(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	var path: = dir.path_join(name + ".png")
	img.save_png(path)
	print("DUEL_SHOT " + path)


# ---------------------------------------------------------------- calibration / debug entry points

func _calibrate() -> void:
	var games: = int(args.get("duel_cal_games", "32"))
	var hs: Array = F.heroes(true) if String(args.get("duel_cal_heroes", "all")) == "all" else F.heroes()
	if args.has("duel_cal_only"):
		hs = Array(String(args.duel_cal_only).split(","))
	var t0: = Time.get_ticks_msec()
	var data: = SIM.calibrate(games, hs, true)
	for h in hs:
		print("DUEL_CAL %s %s raw %s" % [h, str(data.ratings[h]), str(data.raw[h])])
		if args.has("duel_cal_debug"):
			for fi in F.FORMS:
				print("   form %d her score x100 %s" % [fi + 1, str(data.her_score_x100[h][fi])])
	print("DUEL_CAL bots %s" % str(data.bots))
	if String(args.get("duel_cal_write", "1")) == "1":
		var okw: = SIM.write(ProjectSettings.globalize_path(R.RATINGS_PATH), data)
		print("DUEL_CAL wrote %s %s" % [R.RATINGS_PATH, okw])
	print("DUEL_CAL done %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit(0)


func _race_debug() -> void:
	var h: = String(args.get("duel_h", "nova"))
	var f: = int(args.get("duel_f", "5"))
	for bot in SIM.BOT_ORDER:
		var hp: = F.run_params(h, f, "ranked")
		var tot: = {"me": 0, "her": 0, "steals": 0, "tricks": 0, "secs": 0.0, "w": 0}
		for g in 20:
			var o: = SIM.race(SIM.table_cfg(h, f, 100 + g), hp, bot, U.rng(g, "dbg"))
			for k in ["me", "her", "steals", "tricks"]:
				tot[k] += int(o[k])
			tot.secs += float(o.secs)
			tot.w += 1 if o.win else 0
		print("RACE %s me %.1f her %.1f steals %.1f tricks %.1f secs %.0f wins %d/20" % [bot, tot.me / 20.0, tot.her / 20.0, tot.steals / 20.0, tot.tricks / 20.0, tot.secs / 20.0, tot.w])
	get_tree().quit(0)
