class_name TWRound
extends RefCounted

# TWRound (P20 / WP7): the end of a round, as one pure function.
#
#   TWRound.resolve(state, mode, cfg, stats) -> TWRoundResult
#
# The award / rank / star / unlock / task / hook half of play.gd (_on_clear, _blitz_end, V6Duel.finish, _v8_record_loss, the tower's
# _award_win), with every number out of TWRewards and every mode fact out of TWModeCfg. It reads, it does not write: the shell applies
# the result (wallet grants through TWWallet, bond, tasks, G.add_rp / G.record_game, the state edits listed in `writes`) and draws it.
# The outfit of the hero is not an input anywhere (GDD 3.5.1: «наряд не влияет»); a state key `outfit` is ignored on purpose.
#
# state (a read-only snapshot, every key optional):
#   rp, ranks, yaku_table        rank points of the player and the ladders (defaults: TWRewards.RANKS / YAKU_RP)
#   afisha_mult                  the mode of the day: rank points x N (never crystals)
#   level_stars, levels_size, unlocked          the Path level in cfg: its best stars so far, the length of the Path, G.S.unlocked
#   day, daily_done              day of the month and the days of this month already cleared
#   blitz_best, combo_min, best_combo_prev      records
#   rival_first_win              duel: the first win against this rival (+100 crystals)
#   partner                      the hero at the table
#   demo                         the demo build gives 3 stars
#   hooks.path_on_win            Callable(stars, ms) -> {"gems": int, ...}: the certified Path level pays through V10PathState.on_win
# stats (what the board gave): event ("clear" | "end" | "board" | "finish" | "leave"), win, level, seed, hero, secs, tiles, fails, boosters_used,
#   max_combo, last_combo, denies, max_tray, gold_total, gold_got, sets_done, riichi, gained (pair crystals already paid),
#   blitz_score, boards_done, me, her (duel), tower {kind, floor, board, score, reward, win, secs, pairs}
#
# What it never returns: a «осталось сегодня» counter (TWRoundResult has no such field).

static func resolve(state: Dictionary, mode: String, cfg: Dictionary, stats: Dictionary) -> TWRoundResult:
	var r: = TWRoundResult.new()
	r.mode = mode
	r.source = TWModeCfg.source(mode)
	r.secs = float(stats.get("secs", 0.0))
	r.rp_before = int(state.get("rp", 0))
	r.rp_after = r.rp_before
	var ev: = String(stats.get("event", "clear"))
	if TWModeCfg.is_tower(mode):
		_tower(r, state, stats)
	elif mode == "blitz" and ev == "end":
		_blitz_end(r, state, stats)
	elif mode == "zen" and ev == "board":
		_zen_board(r, state, stats)
	elif mode == "duel" and ev == "finish":
		_duel(r, state, stats)
	elif ev == "leave":
		_lose(r, stats)
	elif ev == "clear" and mode in ["", "daily", "trial"]:
		_clear(r, state, mode, cfg, stats)
	else:
		r.outcome = "none"          # a blitz / zen / duel table cleared mid-run: the run goes on, nothing is resolved yet
	return r


# ── the table is cleared (Path, daily, trial) ─────────────────────────────────────────────────────────────────────

static func _clear(r: TWRoundResult, state: Dictionary, mode: String, cfg: Dictionary, stats: Dictionary) -> void:
	var fails: = int(stats.get("fails", 0))
	var boosters: = int(stats.get("boosters_used", 0))
	var lvl: = int(stats.get("level", 0))
	r.win = true
	r.outcome = "win"
	r.stars = 3 if bool(state.get("demo", false)) else TWRewards.story_stars(fails, boosters)
	var ys_in: = {"riichi": stats.get("riichi", false), "boosters_used": boosters, "fails": fails, "max_tray": stats.get("max_tray", 0),
		"denies": stats.get("denies", 0), "secs": r.secs, "tiles": stats.get("tiles", 0), "max_combo": stats.get("max_combo", 0),
		"gold_total": stats.get("gold_total", 0), "gold_got": stats.get("gold_got", 0), "last_combo": stats.get("last_combo", 0),
		"sets_done": stats.get("sets_done", [])}
	r.yaku = TWRewards.collect_yaku(ys_in)
	var path_paid: = false
	var reward: = 0
	if mode == "":
		r.first = int(state.get("level_stars", 0)) == 0
		var hooks: Dictionary = state.get("hooks", {})
		if cfg.has("v10_id") and hooks.get("path_on_win") is Callable:
			var pr: Dictionary = (hooks.path_on_win as Callable).call(r.stars, int(r.secs * 1000.0))
			reward = int(pr.get("gems", 0))
			path_paid = true
			r.flags["path_res"] = pr
		else:
			var lsz: = int(state.get("levels_size", 1000))
			r.writes["stars"] = {"level": lvl, "stars": maxi(int(state.get("level_stars", 0)), r.stars)}
			r.writes["unlocked"] = maxi(int(state.get("unlocked", 0)), mini(lvl + 2, lsz))
			reward = TWRewards.level_reward(cfg, r.stars)
		var rw: Dictionary = cfg.get("reward", {}) if cfg.get("reward") is Dictionary else {}
		if r.first and rw.has("item"):
			r.writes["item"] = rw.item
		if r.first and lvl == 2:
			r.flags["first_unlock_summon"] = true
			r.grant("tickets", 10, "unlock_summon")
	elif mode == "daily":
		reward = TWRewards.level_reward(cfg, r.stars)
		var day: = int(state.get("day", 1))
		var done: Array = (state.get("daily_done", []) as Array).map(func(x): return int(x))
		if not day in done:
			r.writes["daily_done_day"] = day
	var riichi_extra: = 0
	if bool(stats.get("riichi", false)):
		var rr: = TWRewards.riichi_reward(reward, int(stats.get("gained", 0)))
		riichi_extra = int(rr.extra)
		reward = int(rr.reward)
		r.flags["riichi"] = true
	r.reward = reward
	var row: = TWModeCfg.row(mode)
	if bool(row.rp):
		var yrp: = TWRewards.yaku_sum(r.yaku, state.get("yaku_table", {}))
		for y in r.yaku:
			if not String(y).begins_with("set:"):
				r.yaku_seen.append(y)
		var hard: = int(cfg.get("hard", 0)) if mode == "" else 0
		r.rp_gain = TWRewards.path_rp(r.stars, hard, yrp)
		var ranks: Array = state.get("ranks", [])
		r.rank_ups = TWRewards.rank_ups(r.rp_before, r.rp_gain, ranks)
		r.rp_after = TWRewards.rp_after(r.rp_before, r.rp_gain, ranks)
		r.record = {"source": r.source, "won": true}
		if r.source == "path":
			r.flags["starter_path_win"] = true
		if not r.rank_ups.is_empty():
			r.rank_title = String(TWRewards.rank_of(r.rp_after, ranks).title)
	if bool(row.tasks):
		r.bond.append({"hero": String(state.get("partner", stats.get("hero", ""))), "n": TWRewards.LEVEL_BOND, "src": "level_win"})
		r.tasks.append({"key": "levels", "n": 1})
		r.pass_xp = TWRewards.LEVEL_PASS_XP
		r.xp = TWRewards.LEVEL_XP
	if path_paid:
		r.grant("gems", riichi_extra, "play")
	else:
		r.grant("gems", reward, "play")
	r.writes["tut_done"] = true
	_hook(r, stats, true, r.stars, r.reward, 0, {
		"rank_up": not r.rank_ups.is_empty(), "rank_title": r.rank_title, "max_combo": int(stats.get("max_combo", 0)),
		"combo_rec": int(stats.get("max_combo", 0)) >= int(state.get("combo_min", TWRewards.COMBO_MIN_FOR_RECORD)) \
			and int(stats.get("max_combo", 0)) > int(state.get("best_combo_prev", 0)),
	})
	_events(r)


# ── a round that is over without a win ────────────────────────────────────────────────────────────────────────────

# the player leaves a lost table (or the overflow window ends it): a lost game for the modes that count it, nothing else
static func _lose(r: TWRoundResult, stats: Dictionary) -> void:
	r.win = false
	r.outcome = "lose"
	if TWBoosters.counts_loss(r.mode):
		r.record = {"source": r.source, "won": false}
	_hook(r, stats, false, 0, 0, 0, {})
	_events(r)


# ── blitz ─────────────────────────────────────────────────────────────────────────────────────────────────────────

static func _blitz_end(r: TWRoundResult, state: Dictionary, stats: Dictionary) -> void:
	var score: = int(stats.get("blitz_score", 0))
	var be: = TWRewards.blitz_end(score, int(state.get("blitz_best", 0)))
	r.win = true
	r.outcome = "end"
	r.reward = int(be.gems)
	r.grant("gems", r.reward, "play")
	if bool(be.record):
		r.writes["blitz_best"] = score
	_rank_award(r, state, int(be.rp), int(stats.get("boards_done", 0)) > 0)   # the game counts as won when at least one board was cleared
	_hook(r, stats, true, 0, r.reward, score, {})
	_events(r)


# ── zen: one cleared board ────────────────────────────────────────────────────────────────────────────────────────

static func _zen_board(r: TWRoundResult, state: Dictionary, stats: Dictionary) -> void:
	var n: = int(stats.get("boards_done", 1))
	r.win = true
	r.outcome = "board"
	r.reward = TWRewards.ZEN_CLEAR_GEMS
	r.grant("gems", r.reward, "play")
	_rank_award(r, state, V8PlayRules.zen_rp(n), true)
	_events(r)


# ── duel ──────────────────────────────────────────────────────────────────────────────────────────────────────────

static func _duel(r: TWRoundResult, state: Dictionary, stats: Dictionary) -> void:
	var d: = TWRewards.duel_result(int(stats.get("me", 0)), int(stats.get("her", 0)), bool(state.get("rival_first_win", false)))
	r.win = bool(d.win)
	r.outcome = "win" if d.win else ("draw" if d.draw else "lose")
	r.reward = int(d.gems)
	r.grant("gems", r.reward, "duel")
	var rival: = String(stats.get("rival", ""))
	r.bond.append({"hero": rival, "n": int(d.rival_bond), "src": "duel"})
	r.bond.append({"hero": String(state.get("partner", stats.get("hero", ""))), "n": int(d.partner_bond), "src": "duel"})
	r.pass_xp = int(d.pass_xp)
	if bool(d.win):
		r.flags["rival_win"] = true
	_rank_award(r, state, int(d.rp), bool(d.win))
	_hook(r, stats, bool(d.win), 0, 0, 0, {})
	_events(r)


# ── the tower family (pagoda / journey / practice) ───────────────────────────────────────────────────────────────

# the tower's own module decides the crystals (its `reward` dictionary, granted by the shell with the tower's reason); this adds the
# rank points of a cleared table, the bond, the task and the lost-run record exactly like TowerPlay._award_win did.
static func _tower(r: TWRoundResult, state: Dictionary, stats: Dictionary) -> void:
	var t: Dictionary = stats.get("tower", {})
	var kind: = String(t.get("kind", r.mode))
	var win: = bool(t.get("win", false))
	r.win = win
	r.outcome = "win" if win else "lose"
	r.secs = float(t.get("secs", r.secs))
	if kind != "practice":
		if win:
			r.bond.append({"hero": String(state.get("partner", stats.get("hero", ""))), "n": TWRewards.TOWER_BOND, "src": "mode_win"})
			r.tasks.append({"key": "levels", "n": 1})
			_rank_award(r, state, TWRewards.tower_rp(kind, int(t.get("floor", 1)), int(t.get("board", 1))), true)
		elif bool(t.get("run_over", false)):
			_rank_award(r, state, 0, false)
	r.reward = 0
	if kind != "practice":
		var rw: Dictionary = t.get("reward", {}) if t.get("reward") is Dictionary else {}
		r.hook = {"mode": kind, "win": win, "score": int(t.get("score", 0)), "stars": 3 if win else 0, "time_s": r.secs,
			"pairs": int(t.get("pairs", 0)), "hero": String(stats.get("hero", state.get("partner", ""))), "seed": int(stats.get("seed", 0)),
			"level": -1, "first": false, "rewards": rw}
	_events(r)


# ── shared pieces ─────────────────────────────────────────────────────────────────────────────────────────────────

# V8PlayRules.award: rank points (x the day's mode multiplier), the rank-ups, the game record
static func _rank_award(r: TWRoundResult, state: Dictionary, rp: int, won: bool) -> void:
	rp = TWRewards.rp_with_mult(rp, int(state.get("afisha_mult", 1)))
	var ranks: Array = state.get("ranks", [])
	r.rp_gain = rp
	if rp != 0:
		r.rank_ups = TWRewards.rank_ups(r.rp_before, rp, ranks)
		r.rp_after = TWRewards.rp_after(r.rp_before, rp, ranks)
	r.record = {"source": r.source, "won": won}
	if not r.rank_ups.is_empty():
		r.rank_title = String(TWRewards.rank_of(r.rp_after, ranks).title)


# the V10Hooks game_ended payload of a screen round (play.gd _v10_ended); `extra` is merged over it
static func _hook(r: TWRoundResult, stats: Dictionary, win: bool, stars: int, reward: int, score: int, extra: Dictionary) -> void:
	var mode: = r.mode
	var p: = {"mode": TWModeCfg.hook_mode(mode), "win": win, "score": score, "stars": stars, "time_s": r.secs,
		"pairs": int(stats.get("tiles", 0) / 2), "hero": String(stats.get("hero", "")), "seed": int(stats.get("seed", 0)),
		"level": int(stats.get("level", 0)) if mode == "" else -1, "first": r.first, "rewards": {"gems": reward},
		"max_combo": int(stats.get("max_combo", 0)),
		"clean": win and int(stats.get("boosters_used", 0)) == 0 and int(stats.get("fails", 0)) == 0,
		"dragons": 1 if win and int(stats.get("max_combo", 0)) >= 7 else 0}
	p.merge(extra, true)
	r.hook = p


static func _events(r: TWRoundResult) -> void:
	r.events.append({"t": "ROUND_ENDED", "mode": r.mode, "outcome": r.outcome, "win": r.win, "stars": r.stars, "reward": r.reward})
	for u in r.rank_ups:
		r.events.append({"t": "RANK_UP", "tier": int(u.tier), "sub": int(u.sub), "gems": int(u.gems)})
	for t in r.tasks:
		r.events.append({"t": "TASK_PROGRESS", "key": String(t.key), "n": int(t.n)})
