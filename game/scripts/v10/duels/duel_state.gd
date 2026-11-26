class_name V10Duel
extends RefCounted

# V10Duel — the state of «Дуэли 2.0» (spec R6): S.v10_duel, offers, start → pending → finish, caps, weekly, seasons.
# The module computes and enforces every reward itself and pays through V10DuelUtil.apply_rewards (one function).
#
#   st() -> Dictionary            S.v10_duel, created and repaired lazily; rolls the day caps, the МСК week and the
#                                 28-day season (season-end reward by PEAK tier exactly once + soft reset); a pending
#                                 match that is not running in this process (app killed) is settled as a LOSS here
#   register_save()               V10Save.register("v10_duel", DEFAULTS) when V10Save exists (soft)
#   menu_open() / ranked_open() / lock_text(kind)
#   offers() -> Array[3]          ranked offers within ±150 (stored, stable until a game is played or the day turns)
#   friendly_offers(h) -> Array   forms II, III, IV of one heroine;  friendly_heroes() -> Array
#   weekly_offer() -> Dictionary  this week's heroine, her rule, wins x/3, «до пн, 30 ноября, 04:00 МСК»
#   start(offer, partner) -> Dictionary   fixes the offer, writes `pending` and SAVES before the match; returns the
#                                 args for main.go (mode "duel", duel2 true, …) or {"error": text}
#   finish(id, me, her, extra) -> Dictionary   the result dict for the UI (see README «Итог»); idempotent per id
#   abandon(id, me, her) -> Dictionary         exit before the end = loss (play's leave, _exit_tree of the run)
#   vs_plan() -> {full, secs}     the VS split: full once a session, then 0,5 s;  mark_vs_seen()
#   leave_text() -> String        line for the «Выйти из партии?» confirm (ranked: the rating it costs)
#   season_info(), caps(), history(), take_season_reward()

const U: = preload("res://scripts/v10/duels/duel_util.gd")
const F: = preload("res://scripts/v10/duels/duel_forms.gd")
const R: = preload("res://scripts/v10/duels/duel_rank.gd")
const C: = preload("res://scripts/v10/duels/duel_cfg.gd")

const KEY: = "v10_duel"
const VER: = 1
const DEFAULTS: = {
	"ver": VER, "dr": 1000, "games": 0, "wins": 0, "losses": 0, "draws": 0, "best_dr": 1000,
	"season": -1, "season_games": 0, "peak_tier": 1, "peak_dr": 1000, "season_claimed": {}, "season_reward": {},
	"wins_today": {"day": "", "ranked": 0, "friendly": 0},
	"history": [],
	"weekly": {"week": -1, "rival": "", "wins": 0, "games": 0, "claimed": false},
	"casual_wins": 0, "casual_by": {},
	"pending": {},
	"offers": {"day": "", "dr": 0, "roll": 0, "list": []},
	"used": {"day": "", "keys": {}},
	"started": 0, "last_result": {}, "migrated": false,
}

const RANKED_WIN_GEMS: = 5
const RANKED_CAP: = 3
const FRIENDLY_WIN_GEMS: = 3
const FRIENDLY_CAP: = 3
const FRIENDLY_AFF: = 1
const WEEKLY_WINS: = 3
const WEEKLY_GEMS: = 100
const WEEKLY_PETALS: = 30
const HISTORY_N: = 20
const VS_SHORT: = 0.5

static var live_id: = ""          # the match running in this process (its pending is not stale)
static var _vs_seen: = false      # session flag of the full VS split
static var _resolving: = false


# ---------------------------------------------------------------- the save

static func register_save() -> void:
	var sv: = U.klass("V10Save")
	if sv and U.has_fn(sv, "register"):
		sv.call("register", KEY, DEFAULTS.duplicate(true))


static func _dflt(k: String):
	var v = DEFAULTS[k]
	return v.duplicate(true) if (v is Dictionary or v is Array) else v


static func _repair(d: Dictionary) -> void:
	for k in DEFAULTS:
		var v = DEFAULTS[k]
		if not d.has(k):
			d[k] = _dflt(k)
		elif typeof(v) == TYPE_INT and typeof(d[k]) == TYPE_FLOAT:
			d[k] = int(d[k])
		elif typeof(d[k]) != typeof(v):
			d[k] = _dflt(k)
		elif v is Dictionary and not (v as Dictionary).is_empty():
			for k2 in v:
				if not (d[k] as Dictionary).has(k2) or (typeof(d[k][k2]) != typeof(v[k2]) and not (typeof(v[k2]) == TYPE_INT and typeof(d[k][k2]) == TYPE_FLOAT)):
					d[k][k2] = v[k2].duplicate(true) if (v[k2] is Dictionary or v[k2] is Array) else v[k2]
				elif typeof(v[k2]) == TYPE_INT:
					d[k][k2] = int(d[k][k2])
	d.dr = R.clamp_dr(int(d.dr))
	if (d.history as Array).size() > HISTORY_N:
		d.history = (d.history as Array).slice(0, HISTORY_N)


static func st() -> Dictionary:
	var S: = U.save()
	var d = S.get(KEY)
	if not (d is Dictionary):
		d = {}
	_repair(d)
	S[KEY] = d
	if not bool(d.migrated):
		# 0.6–0.9 duel wins count as friendly wins (they were friendly matches): 10 of them open the ranked duel
		d.migrated = true
		var old = S.get("v6_heroines", {})
		if old is Dictionary and old.get("duel_wins") is Dictionary:
			var n: = 0
			for h in old.duel_wins:
				n += int(old.duel_wins[h])
				d.casual_by[h] = int(d.casual_by.get(h, 0)) + int(old.duel_wins[h])
			d.casual_wins = int(d.casual_wins) + n
	_roll(d)
	if not _resolving and not (d.pending as Dictionary).is_empty() and String(d.pending.get("id", "")) != live_id:
		_resolve_pending(d)
	return d


static func _roll_day(d: Dictionary) -> void:
	var day: = U.day_key()
	if String(d.wins_today.day) != day:
		d.wins_today = {"day": day, "ranked": 0, "friendly": 0}
	var cal: = U.cal_key()
	if String(d.used.day) != cal:
		d.used = {"day": cal, "keys": {}}


static func _roll(d: Dictionary) -> void:
	_roll_day(d)
	var t: = U.now()
	var wid: = U.week_id(t)
	if int(d.weekly.week) != wid:
		d.weekly = {"week": wid, "rival": F.weekly_rival(wid), "wins": 0, "games": 0, "claimed": false}
	var sid: = U.season_id(t)
	if int(d.season) < 0:
		d.season = sid
		d.peak_tier = R.tier_of(int(d.dr))
		d.peak_dr = int(d.dr)
	elif sid > int(d.season):
		_season_end(d, sid)


# the season is over: reward by the PEAK tier of the season, exactly once (season_claimed), then the soft reset.
# The clock never rolls a season back (sid > stored only), so a moved clock cannot hand out a second reward.
static func _season_end(d: Dictionary, sid: int) -> void:
	var old: = int(d.season)
	var key: = str(old)
	if int(d.season_games) > 0 and not (d.season_claimed as Dictionary).has(key):
		d.season_claimed[key] = true
		var tier: = int(d.peak_tier)
		var rw: = R.season_reward(tier)
		var rows: = U.apply_rewards(rw, "duel_season")
		d.season_reward = {"season": old, "num": U.season_num(old), "tier": tier, "tier_name": R.tier_name(tier),
			"rewards": rw, "rows": rows, "seen": false}
	for i in mini(sid - old, 4):
		d.dr = R.soft_reset(int(d.dr))
	d.dr = R.clamp_dr(int(d.dr))
	d.season = sid
	d.season_games = 0
	d.peak_tier = R.tier_of(int(d.dr))
	d.peak_dr = int(d.dr)
	d.offers = _dflt("offers")
	U.save_game()


# the ceremony of the season end (the UI shows it once on the duel screen): returns it and marks it seen
static func take_season_reward() -> Dictionary:
	var d: = st()
	var sr: Dictionary = d.season_reward
	if sr.is_empty() or bool(sr.get("seen", false)):
		return {}
	sr.seen = true
	U.save_game()
	return sr


# ---------------------------------------------------------------- gates

static func menu_open() -> bool:
	return R.menu_open(U.save())


static func ranked_open() -> bool:
	return R.ranked_open(U.save(), int(st().casual_wins))


static func lock_text(kind: String = "menu") -> String:
	return R.T_RANKED_LOCK if kind == "ranked" else R.T_MENU_LOCK


# ---------------------------------------------------------------- offers

static func offers() -> Array:
	var d: = st()
	var o: Dictionary = d.offers
	var day: = U.cal_key()
	var stale: = String(o.day) != day or int(o.dr) != int(d.dr) or (o.list as Array).size() < R.OFFERS
	if not stale:
		for x in o.list:
			if absi(int(x.dr_opp) - int(d.dr)) > R.WINDOW:
				stale = true
	if stale:
		var roll: = int(o.roll) + (1 if String(o.day) == day else 0)
		var list: = R.offers(int(d.dr), day, d.used.keys, roll)
		for x in list:
			_annotate(d, x)
		d.offers = {"day": day, "dr": int(d.dr), "roll": roll, "list": list}
	return (d.offers.list as Array).duplicate(true)


static func _annotate(d: Dictionary, x: Dictionary) -> void:
	var dr: = int(d.dr)
	x["win_delta"] = R.delta(dr, int(x.dr_opp), 1.0, int(d.games))
	x["lose_delta"] = R.delta(dr, int(x.dr_opp), 0.0, int(d.games))
	x["stake_text"] = "Победа %s · поражение %s" % [U.fmt_delta(int(x.win_delta)), U.fmt_delta(int(x.lose_delta))]


static func friendly_heroes() -> Array:
	return F.heroes()


static func friendly_offers(h: String) -> Array:
	var d: = st()
	var out: = []
	if not F.heroes().has(h):
		return out
	for f in F.FRIENDLY_FORMS:
		var o: = R.make_offer("friendly", h, f, U.cal_key(), int(d.dr), int(d.started))
		o.erase("dr_opp_text")
		o.erase("chance_text")
		o.erase("chance")
		o["dr_opp"] = 0
		out.append(o)
	return out


static func weekly_offer() -> Dictionary:
	var d: = st()
	var w: Dictionary = d.weekly
	var h: = String(w.rival)
	var rule: = F.weekly_rule(h)
	var o: = R.make_offer("weekly", h, F.WEEKLY_FORM, "w%d" % int(w.week), int(d.dr), int(w.games))
	for k in ["dr_opp_text", "chance_text", "chance"]:
		o.erase(k)
	o["dr_opp"] = 0
	o["rule"] = rule
	o["wins"] = int(w.wins)
	o["need"] = WEEKLY_WINS
	o["claimed"] = bool(w.claimed)
	o["progress_text"] = "%d из %d побед" % [int(w.wins), WEEKLY_WINS]
	o["reward_text"] = "%d кристаллов и %d Лепестков" % [WEEKLY_GEMS, WEEKLY_PETALS]
	o["until_text"] = U.until_text(U.week_end(int(w.week)))
	o["countdown"] = U.countdown(U.week_end(int(w.week)))
	o["week"] = int(w.week)
	return o


# ---------------------------------------------------------------- start / finish

static func start(offer: Dictionary, partner: String = "mc") -> Dictionary:
	var d: = st()
	if not (d.pending as Dictionary).is_empty():
		_resolve_pending(d)
	var kind: = String(offer.get("kind", ""))
	var h: = String(offer.get("rival", ""))
	var f: = int(offer.get("form", 0))
	if not F.heroes().has(h) or not F.valid_form(f):
		return {"error": "Эта соперница пока не за столом"}
	var fixed: = {}
	match kind:
		"ranked":
			if not ranked_open():
				return {"error": R.T_RANKED_LOCK}
			# only an offer of the stored list: the rating, the trick and the seed are the ones shown on the card
			for x in d.offers.list:
				if String(x.id) == String(offer.get("id", "")):
					fixed = x.duplicate(true)
			if fixed.is_empty():
				return {"error": "Предложение обновилось, выбери снова"}
			d.used.keys["%s|%d" % [h, f]] = int(fixed.round)
			d.offers.list = []
		"friendly":
			if not (f in F.FRIENDLY_FORMS):
				return {"error": "В дружеской дуэли формы II, III и IV"}
			fixed = R.make_offer("friendly", h, f, U.cal_key(), int(d.dr), int(d.started))
		"weekly":
			var w: Dictionary = d.weekly
			if h != String(w.rival):
				return {"error": "На этой неделе за столом другая героиня"}
			if bool(w.claimed):
				return {"error": "Дуэль недели пройдена, новая — " + U.until_text(U.week_end(int(w.week))).trim_prefix("до ")}
			fixed = weekly_offer()
		_:
			return {"error": "Неизвестная дуэль"}
	d.started = int(d.started) + 1
	var id: = "%s#%d" % [String(fixed.id), int(d.started)]
	var wins_vs: = int(d.casual_by.get(h, 0)) if kind == "friendly" else 0
	d.pending = {
		"id": id, "kind": kind, "rival": h, "form": f, "seed": int(fixed.seed), "dr_opp": int(fixed.get("dr_opp", 0)),
		"dr_before": int(d.dr), "games_before": int(d.games), "t": U.now(), "partner": partner,
		"week": int(d.weekly.week), "wins_vs": wins_vs, "trick_n": int(fixed.get("trick_n", 0)),
	}
	live_id = id
	U.save_game()
	return match_args(d.pending)


static func match_args(p: Dictionary) -> Dictionary:
	return {"mode": "duel", "duel2": true, "kind": String(p.kind), "rival": String(p.rival), "form": int(p.form),
		"seed": int(p.seed), "duel_id": String(p.id), "partner": String(p.get("partner", "mc")),
		"wins_vs": int(p.get("wins_vs", 0)), "retry": int(p.seed)}


static func pending() -> Dictionary:
	return (U.save().get(KEY, {}) as Dictionary).get("pending", {}) if U.save().get(KEY) is Dictionary else {}


static func finish(id: String, me: int, her: int, extra: Dictionary = {}) -> Dictionary:
	# st() must not settle this very match as «killed» while we are finishing it
	var was: = _resolving
	_resolving = true
	var d: = st()
	_resolving = was
	var p: Dictionary = d.pending
	if p.is_empty() or String(p.get("id", "")) != id:
		var lr: Dictionary = d.last_result
		return lr.duplicate(true) if String(lr.get("id", "")) == id else {}
	var res: = _apply(d, p, me, her, extra)
	d.pending = {}
	if live_id == id:
		live_id = ""
	d.last_result = res
	# play.gd's own _v8_record_loss may have counted this exit already (extra.recorded): never twice
	if not bool(extra.get("recorded", false)):
		U.record_game(bool(res.win))
	U.save_game()
	return res.duplicate(true)


# exit before the end = loss. recorded = the play screen already counted the game (play._v8_loss_done)
static func abandon(id: String, me: int = 0, her: int = 0, recorded: = false) -> Dictionary:
	return finish(id, me, her, {"exit": true, "recorded": recorded})


static func _resolve_pending(d: Dictionary) -> void:
	_resolving = true
	var p: Dictionary = d.pending
	var res: = _apply(d, p, 0, 0, {"exit": true, "killed": true})
	d.pending = {}
	d.last_result = res
	U.record_game(false)
	U.save_game()
	_resolving = false


static func _apply(d: Dictionary, p: Dictionary, me: int, her: int, extra: Dictionary) -> Dictionary:
	_roll_day(d)
	var ex: = bool(extra.get("exit", false))
	var win: = not ex and me > her
	var draw: = not ex and me == her
	var score: = 1.0 if win else (0.5 if draw else 0.0)
	var kind: = String(p.kind)
	var h: = String(p.rival)
	var f: = int(p.form)
	var res: = {
		"id": String(p.id), "kind": kind, "kind_name": C.kind_name(kind), "rival": h, "rival_name": U.hero_name(h),
		"form": f, "roman": F.roman(f), "win": win, "draw": draw, "exit": ex, "killed": bool(extra.get("killed", false)),
		"me": me, "her": her, "steals": int(extra.get("steals", 0)), "tricks": int(extra.get("tricks", 0)),
		"seed": int(p.seed), "line": String(extra.get("line", "")), "partner": String(p.get("partner", "mc")),
		"rewards": {}, "rows": [], "rating": {}, "weekly": {}, "unlocked_ranked": false,
	}
	res["title"] = "Победа" if win else ("Ничья" if draw else ("Выход · поражение" if ex else "Победа за ней"))
	var rw: = {}
	match kind:
		"ranked":
			var before: = int(d.dr)
			var tb: = R.tier_of(before)
			var k: = R.k_for(int(d.games))
			var dl: = R.delta(before, int(p.dr_opp), score, int(d.games))
			var after: = R.clamp_dr(before + dl)
			dl = after - before
			d.dr = after
			d.games = int(d.games) + 1
			d.season_games = int(d.season_games) + 1
			if win:
				d.wins = int(d.wins) + 1
			elif draw:
				d.draws = int(d.draws) + 1
			else:
				d.losses = int(d.losses) + 1
			d.best_dr = maxi(int(d.best_dr), after)
			var ta: = R.tier_of(after)
			var new_peak: = ta > int(d.peak_tier)
			d.peak_tier = maxi(int(d.peak_tier), ta)
			d.peak_dr = maxi(int(d.peak_dr), after)
			res.rating = {"before": before, "after": after, "delta": dl, "delta_text": U.fmt_delta(dl), "k": k,
				"opp": int(p.dr_opp), "text": R.rating_text(after), "tier_before": tb, "tier_after": ta,
				"tier_up": ta > tb, "tier_down": ta < tb, "new_peak": new_peak, "peak_tier": int(d.peak_tier),
				"tier_name": R.tier_name(ta), "caption": R.tier_caption(ta)}
			if win and int(d.wins_today.ranked) < RANKED_CAP:
				d.wins_today.ranked = int(d.wins_today.ranked) + 1
				rw["gems"] = RANKED_WIN_GEMS
		"friendly":
			if win:
				var was_open: = R.ranked_open(U.save(), int(d.casual_wins))
				d.casual_wins = int(d.casual_wins) + 1
				d.casual_by[h] = int(d.casual_by.get(h, 0)) + 1
				res.unlocked_ranked = not was_open and R.ranked_open(U.save(), int(d.casual_wins))
				rw["aff"] = {h: FRIENDLY_AFF}
				if int(d.wins_today.friendly) < FRIENDLY_CAP:
					d.wins_today.friendly = int(d.wins_today.friendly) + 1
					rw["gems"] = FRIENDLY_WIN_GEMS
		"weekly":
			var w: Dictionary = d.weekly
			var same_week: = int(p.get("week", -1)) == int(w.week)
			if same_week:
				w.games = int(w.games) + 1
				if win and int(w.wins) < WEEKLY_WINS:
					w.wins = int(w.wins) + 1
				if int(w.wins) >= WEEKLY_WINS and not bool(w.claimed):
					w.claimed = true
					rw["gems"] = WEEKLY_GEMS
					rw["petals"] = WEEKLY_PETALS
					res.weekly["just_done"] = true
			res.weekly.merge({"wins": int(w.wins), "need": WEEKLY_WINS, "claimed": bool(w.claimed),
				"progress_text": "%d из %d побед" % [int(w.wins), WEEKLY_WINS]}, true)
	res.rewards = rw
	res.rows = U.apply_rewards(rw, "duel_" + kind)
	res["caps"] = caps(d)
	var hist: Array = d.history
	hist.push_front({"t": U.now(), "kind": kind, "rival": h, "form": f, "win": win, "draw": draw, "exit": ex,
		"me": me, "her": her, "delta": int(res.rating.get("delta", 0)), "dr": int(d.dr), "seed": int(p.seed)})
	if hist.size() > HISTORY_N:
		hist.resize(HISTORY_N)
	return res


# ---------------------------------------------------------------- texts and small reads

static func caps(d: Dictionary = {}) -> Dictionary:
	if d.is_empty():
		d = st()
	var rl: = maxi(0, RANKED_CAP - int(d.wins_today.ranked))
	var fl: = maxi(0, FRIENDLY_CAP - int(d.wins_today.friendly))
	return {"ranked_left": rl, "friendly_left": fl,
		"ranked_text": ("Победа: +%d кристаллов" % RANKED_WIN_GEMS) if rl > 0 else "Кристаллы за рейтинговые победы — завтра после 04:00",
		"friendly_text": ("Победа: +%d кристалла и симпатия" % FRIENDLY_WIN_GEMS) if fl > 0 else "Победа: симпатия, кристаллы — завтра после 04:00"}


static func vs_plan() -> Dictionary:
	return {"full": not _vs_seen, "secs": -1.0 if not _vs_seen else VS_SHORT}


static func mark_vs_seen() -> void:
	_vs_seen = true


static func reset_session() -> void:
	_vs_seen = false
	live_id = ""


static func leave_text() -> String:
	var p: = pending()
	if String(p.get("kind", "")) == "ranked":
		var d: Dictionary = U.save().get(KEY, {})
		var dl: = R.delta(int(d.get("dr", 1000)), int(p.dr_opp), 0.0, int(d.get("games", 0)))
		return "Выход засчитается поражением: рейтинг %s" % U.fmt_delta(dl)
	return "Выход засчитается поражением"


static func season_info() -> Dictionary:
	var d: = st()
	var sid: = int(d.season)
	var t_end: = U.season_end(sid)
	var tier: = R.tier_of(int(d.dr))
	return {"id": sid, "num": U.season_num(sid), "text": R.season_text(sid), "until_text": U.until_text(t_end),
		"countdown": U.countdown(t_end), "dr": int(d.dr), "rating_text": R.rating_text(int(d.dr)),
		"tier": tier, "tier_name": R.tier_name(tier), "caption": R.tier_caption(tier),
		"peak_tier": int(d.peak_tier), "peak_name": R.tier_name(int(d.peak_tier)),
		"next_text": R.next_tier_text(int(d.dr)), "reward": R.season_reward(int(d.peak_tier)),
		"reward_rows": U.reward_rows(R.season_reward(int(d.peak_tier))), "games": int(d.season_games)}


static func history() -> Array:
	return (st().history as Array).duplicate(true)


static func all_texts() -> Array:
	var out: = [leave_text(), "Выход засчитается поражением: рейтинг −18", "Победа", "Ничья", "Выход · поражение",
		"Победа за ней", "Эта соперница пока не за столом", "Предложение обновилось, выбери снова",
		"В дружеской дуэли формы II, III и IV", "На этой неделе за столом другая героиня", "Неизвестная дуэль",
		"%d из %d побед" % [2, WEEKLY_WINS], "%d кристаллов и %d Лепестков" % [WEEKLY_GEMS, WEEKLY_PETALS]]
	var c: = caps({"wins_today": {"ranked": 0, "friendly": 0}})
	out.append(c.ranked_text)
	out.append(c.friendly_text)
	c = caps({"wins_today": {"ranked": 3, "friendly": 3}})
	out.append(c.ranked_text)
	out.append(c.friendly_text)
	return out
