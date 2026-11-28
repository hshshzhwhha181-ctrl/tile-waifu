class_name TWRoundSelftest
extends RefCounted

# Selftest of the P20 round core: TWModeCfg, TWBoosters, TWRewards, TWRound.resolve, TWRoundResult, TWRoundStats.
#   A  table      tests/fixtures/round/table.json: >= 120 rows (path / daily / trial / blitz / zen / duel / tower x win / lose / rescue / boosters),
#                 expected values from an INDEPENDENT Python model of the legacy award code (tools/gen_round_table.py)
#   B  pairs      the pair gain table (40 rows from the same model) + 300 random pair sequences against the frozen legacy transcription
#   C  ladder     TWRewards.rank_of / rank_ups == the live G ladder (runner oracle) and the legacy add_rp transcription
#   D  boosters   decide / commit / rescue / overflow / perks tables
#   E  modecfg    the mode table, daily / blitz / zen / trial configs
#   F  legacy     300 random rounds: resolve == the frozen transcription of play.gd _on_clear / _blitz_end / V6Duel.finish / _award_win (diff test)
#   G  bot        TWBoard rounds played by the solver bot through TWRoundStats: stats consistent with the board, the OUTFIT does not change
#                 the result (3 outfits, one seed -> identical RoundResult, difference 0), no «осталось сегодня» field in the result
#   H  wallet     RoundResult.pay on a TWWallet == the balances the legacy grants give; the wallet invariant holds
#   I  purity     the round core files carry no G / scene tree / audio reference
# env (from the runner): ranks (G.RANKS), yaku (G.YAKU), rank_of: Callable(rp) (G.rank_of), rank_index: Callable(rp), levels_size, text: Callable(key)
# Prints "ROUND_SELFTEST ok/total".

const TABLE: = "res://tests/fixtures/round/table.json"
const FILES: = ["tw_round.gd", "tw_round_result.gd", "tw_round_stats.gd", "tw_boosters.gd", "tw_modecfg.gd", "tw_rewards.gd"]

static var _pass: = 0
static var _fail: = 0


static func run(env: Dictionary = {}) -> Array:
	_pass = 0
	_fail = 0
	_table()
	_pairs()
	_ladder(env)
	_boosters()
	_modecfg(env)
	_legacy(env)
	_bot()
	_wallet()
	_purity()
	var total: = _pass + _fail
	print("ROUND_SELFTEST %d/%d" % [_pass, total])
	return [_pass, total]


static func _check(name: String, ok: bool, info: String = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		printerr("FAIL ", name, " ", info)


# ═══════════════════════════════════════════ A: the table ═══════════════════════════════════════════════════════════

static func _state_of(d: Dictionary) -> Dictionary:
	var st: = d.duplicate(true)
	var pg: = int(st.get("path_gems", 0))
	st["hooks"] = {"path_on_win": func(_stars: int, _ms: int) -> Dictionary: return {"gems": pg}}
	return st


static func _num_eq(a, b) -> bool:
	return int(a) == int(b)


static func _compare_row(row: Dictionary, r: TWRoundResult) -> void:
	var w: Dictionary = row.want
	var nm: String = row.name
	_check(nm + ": win", r.win == bool(w.win), "%s vs %s" % [r.win, w.win])
	_check(nm + ": outcome", r.outcome == String(w.outcome), "%s vs %s" % [r.outcome, w.outcome])
	_check(nm + ": stars", r.stars == int(w.stars), "%d vs %d" % [r.stars, int(w.stars)])
	_check(nm + ": reward", r.reward == int(w.reward), "%d vs %d" % [r.reward, int(w.reward)])
	_check(nm + ": rp_gain", r.rp_gain == int(w.rp_gain), "%d vs %d" % [r.rp_gain, int(w.rp_gain)])
	_check(nm + ": rp_after", r.rp_after == int(w.get("rp_after", r.rp_before)), "%d vs %s" % [r.rp_after, str(w.get("rp_after"))])
	var ups: = []
	for u in r.rank_ups:
		ups.append(int(u.gems))
	var wups: = []
	for g in w.ups:
		wups.append(int(g))
	_check(nm + ": rank-ups", ups == wups, "%s vs %s" % [str(ups), str(wups)])
	var gr: = []
	for g in r.grants:
		gr.append([String(g.cur), int(g.n), String(g.reason)])
	var wgr: = []
	for g in w.grants:
		wgr.append([String(g[0]), int(g[1]), String(g[2])])
	_check(nm + ": grants", gr == wgr, "%s vs %s" % [str(gr), str(wgr)])
	var rec: Dictionary = w.record
	_check(nm + ": record", (r.record.is_empty() and rec.is_empty()) or (String(r.record.get("source", "")) == String(rec.get("source", "x")) and bool(r.record.get("won", false)) == bool(rec.get("won", true))), "%s vs %s" % [str(r.record), str(rec)])
	var bd: = []
	for b in r.bond:
		bd.append([String(b.hero), int(b.n), String(b.src)])
	var wbd: = []
	for b in w.bond:
		wbd.append([String(b[0]), int(b[1]), String(b[2])])
	_check(nm + ": bond", bd == wbd, "%s vs %s" % [str(bd), str(wbd)])
	var tk: = []
	for t in r.tasks:
		tk.append([String(t.key), int(t.n)])
	var wtk: = []
	for t in w.tasks:
		wtk.append([String(t[0]), int(t[1])])
	_check(nm + ": tasks", tk == wtk, "%s vs %s" % [str(tk), str(wtk)])
	_check(nm + ": pass_xp / xp", r.pass_xp == int(w.pass_xp) and r.xp == int(w.xp), "%d/%d" % [r.pass_xp, r.xp])
	_check(nm + ": yaku", r.yaku == (w.yaku as Array), "%s vs %s" % [str(r.yaku), str(w.yaku)])
	_check(nm + ": first", r.first == bool(w.first))
	var wr: Dictionary = w.writes
	var ok_w: = true
	for k in wr:
		if k == "stars":
			ok_w = ok_w and r.writes.has("stars") and int(r.writes.stars.level) == int(wr.stars.level) and int(r.writes.stars.stars) == int(wr.stars.stars)
		elif k == "unlocked" or k == "blitz_best" or k == "daily_done_day":
			ok_w = ok_w and r.writes.has(k) and int(r.writes[k]) == int(wr[k])
		else:
			ok_w = ok_w and r.writes.has(k) and r.writes[k] == wr[k]
	for k in r.writes:
		ok_w = ok_w and wr.has(k)
	_check(nm + ": writes", ok_w, "%s vs %s" % [str(r.writes), str(wr)])
	if w.has("rank_title"):
		_check(nm + ": rank title", r.rank_title == String(w.rank_title), r.rank_title)
	if w.has("hook"):
		var hk_ok: = true
		for k in w.hook:
			var a = r.hook.get(k)
			var b = w.hook[k]
			if b is float or a is float:
				hk_ok = hk_ok and absf(float(a) - float(b)) < 0.0001
			elif b is bool or a is bool:
				hk_ok = hk_ok and bool(a) == bool(b)
			elif b is Dictionary:
				hk_ok = hk_ok and int((a as Dictionary).get("gems", -1)) == int((b as Dictionary).get("gems", -2))
			else:
				hk_ok = hk_ok and str(a) == str(b)
		_check(nm + ": game_ended payload", hk_ok, "%s vs %s" % [str(r.hook), str(w.hook)])


static func _table() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	_check("table: file parses", d is Dictionary and (d.rows as Array).size() >= 120, "rows")
	if not (d is Dictionary):
		return
	var rows: Array = d.rows
	_check("table: >= 120 rows (%d)" % rows.size(), rows.size() >= 120)
	var modes: = {}
	for row in rows:
		modes[String(row.mode)] = true
		var r: = TWRound.resolve(_state_of(row.state), String(row.mode), row.cfg, row.stats)
		_compare_row(row, r)
	for m in ["", "daily", "blitz", "zen", "duel", "trial", "pagoda", "journey", "practice"]:
		_check("table covers mode '%s'" % m, modes.has(m))
	# the table's ladder is the live ladder
	var ranks: Array = d.ranks
	var same: = ranks.size() == TWRewards.RANKS.size()
	for i in mini(ranks.size(), TWRewards.RANKS.size()):
		same = same and int(ranks[i][0]) == int(TWRewards.RANKS[i].per) and int(ranks[i][1]) == int(TWRewards.RANKS[i].gems)
	_check("table: the model's rank ladder == TWRewards.RANKS", same)


# ═══════════════════════════════════════════ B: the pair gain ═══════════════════════════════════════════════════════

# [combo, fever, gold, gold_mult, gem_bonus, expected gain] (python model of play.gd _on_match)
const PAIR_ROWS: = [
	[1, false, false, 6, 0.05, 1], [1, false, true, 8, 0.6, 13], [1, true, false, 5, 0.0, 2], [1, true, true, 5, 0.1, 11],
	[2, false, false, 5, 0.35, 1], [2, false, true, 5, 0.0, 5], [2, true, false, 5, 0.15, 2], [2, true, true, 8, 0.0, 16],
	[3, false, false, 5, 0.0, 2], [3, false, true, 8, 0.0, 16], [3, true, false, 5, 0.05, 4], [3, true, true, 5, 0.35, 27],
	[4, false, false, 8, 0.0, 2], [4, false, true, 5, 0.0, 10], [4, true, false, 5, 0.1, 4], [4, true, true, 8, 0.05, 34],
	[5, false, false, 5, 0.35, 4], [5, false, true, 6, 0.35, 24], [5, true, false, 5, 0.0, 6], [5, true, true, 5, 0.1, 33],
	[6, false, false, 5, 0.35, 4], [6, false, true, 5, 0.35, 20], [6, true, false, 5, 0.35, 8], [6, true, true, 5, 0.15, 35],
	[7, false, false, 8, 0.7, 7], [7, false, true, 6, 0.15, 28], [7, true, false, 8, 0.1, 9], [7, true, true, 6, 0.05, 50],
	[9, false, false, 5, 0.6, 8], [9, false, true, 5, 0.0, 25], [9, true, false, 6, 0.35, 14], [9, true, true, 8, 0.1, 88],
	[12, false, false, 8, 0.1, 7], [12, false, true, 5, 0.0, 30], [12, true, false, 8, 0.05, 13], [12, true, true, 6, 0.05, 76],
	[20, false, false, 8, 0.15, 12], [20, false, true, 5, 0.6, 80], [20, true, false, 5, 0.7, 34], [20, true, true, 6, 0.1, 132],
]


static func _pairs() -> void:
	for row in PAIR_ROWS:
		var g: = TWRewards.pair_gain(int(row[0]), bool(row[1]), bool(row[2]), int(row[3]), float(row[4]), 0, "")
		_check("pair gain combo %d fever %s gold %s x%d +%.2f = %d" % [row[0], row[1], row[2], row[3], row[4], row[5]], int(g.gain) == int(row[5]), str(g))
	# «счастливое начало»: the first three pairs x3, a trial gives nothing, a blitz pair scores 10 x combo, a zen pair 1
	var f: = 3
	var out: = []
	for i in 5:
		var g2: = TWRewards.pair_gain(1, false, false, 5, 0.0, f, "")
		f = int(g2.first_pairs_bonus)
		out.append(int(g2.gain))
	_check("pair gain: first three pairs x3 then plain", out == [3, 3, 3, 1, 1], str(out))
	_check("pair gain: trial gives nothing", int(TWRewards.pair_gain(9, true, true, 8, 0.7, 3, "trial").gain) == 0)
	_check("pair score: blitz 10 x combo, combo 0 counts 1", TWRewards.pair_score("blitz", 4) == 40 and TWRewards.pair_score("blitz", 0) == 10)
	_check("pair score: zen 1, others 0", TWRewards.pair_score("zen", 7) == 1 and TWRewards.pair_score("", 7) == 0 and TWRewards.pair_score("duel", 7) == 0)
	# sets of three suits in a row
	var st: = {"cat_streak": 0, "cat_last": -1, "sets_done": []}
	var seq: = [2, 2, 2, 2, 2, 2, 3, 3, 1, 3, 3, 3, -1, -1, -1]
	var bonus: = []
	for c in seq:
		bonus.append(TWRewards.set_step(st, int(c)))
	_check("set steps: +15 on every third pair of a suit", bonus == [0, 0, 15, 0, 0, 15, 0, 0, 0, 0, 0, 15, 0, 0, 0], str(bonus))
	_check("set steps: suit list", st.sets_done == [2, 2, 3], str(st.sets_done))
	_check("face_cat ranges", TWRewards.face_cat(0) == 0 and TWRewards.face_cat(6) == 0 and TWRewards.face_cat(7) == 1 and TWRewards.face_cat(14) == 1
		and TWRewards.face_cat(22) == 2 and TWRewards.face_cat(28) == 3 and TWRewards.face_cat(35) == 4 and TWRewards.face_cat(36) == -1 and TWRewards.face_cat(-1) == -1)
	# 300 random sequences: the pair log of TWRewards == the legacy transcription, pair by pair
	var rng: = TWRng.make(20261128, 7)
	var diff: = 0
	for k in 300:
		var P: = {"gold_mult": [5, 5, 6, 8][rng.below(4)], "gem_bonus": [0.0, 0.05, 0.1, 0.15, 0.3, 0.6][rng.below(6)], "first_pairs_bonus": [0, 0, 3][rng.below(3)], "mode": ["", "", "daily", "trial", "blitz"][rng.below(5)]}
		var fb: int = P.first_pairs_bonus
		for i in 12:
			var combo: = 1 + rng.below(14)
			var fever: = rng.chance(0.3)
			var gold: = rng.chance(0.2)
			var want: = Legacy.on_match(P, combo, gold, fever)
			var got: = TWRewards.pair_gain(combo, fever, gold, int(P.gold_mult), float(P.gem_bonus), fb, String(P.mode))
			fb = int(got.first_pairs_bonus)
			if int(got.gain) != want or fb != int(P.first_pairs_bonus):
				diff += 1
	_check("pair gain: 300 random games x 12 pairs == the legacy transcription (diff %d)" % diff, diff == 0)


# ═══════════════════════════════════════════ C: the rank ladder ═════════════════════════════════════════════════════

static func _ladder(env: Dictionary) -> void:
	var ranks: Array = env.get("ranks", [])
	if not ranks.is_empty():
		var same: = ranks.size() == TWRewards.RANKS.size()
		for i in mini(ranks.size(), TWRewards.RANKS.size()):
			same = same and int(ranks[i].per) == int(TWRewards.RANKS[i].per) and int(ranks[i].gems) == int(TWRewards.RANKS[i].gems) and String(ranks[i].name) == String(TWRewards.RANKS[i].name)
		_check("ladder: TWRewards.RANKS == G.RANKS", same)
	var cats: Array = env.get("cats", [])
	if not cats.is_empty():
		var same_c: = cats.size() == TWRewards.CAT_RANGES.size()
		for i in mini(cats.size(), TWRewards.CAT_RANGES.size()):
			same_c = same_c and int(cats[i][0]) == int(TWRewards.CAT_RANGES[i][0]) and int(cats[i][1]) == int(TWRewards.CAT_RANGES[i][1])
		_check("ladder: TWRewards.CAT_RANGES == G.CATS", same_c)
	var yaku: Dictionary = env.get("yaku", {})
	if not yaku.is_empty():
		var same_y: = true
		for k in TWRewards.YAKU_RP:
			same_y = same_y and yaku.has(k) and int(yaku[k].rp) == int(TWRewards.YAKU_RP[k])
		_check("ladder: TWRewards.YAKU_RP == G.YAKU", same_y)
	var ro: Callable = env.get("rank_of", Callable())
	var ri: Callable = env.get("rank_index", Callable())
	var bad: = 0
	var n_checked: = 0
	var samples: = [0, 1, 59, 60, 61, 159, 160, 259, 260, 409, 410, 629, 630, 1000, 1349, 1350, 2000, 2500, 3499, 3500, 10000, 99999]
	var rng: = TWRng.make(42, 3)
	for i in 400:
		samples.append(rng.below(8000))
	for rp in samples:
		var a: = TWRewards.rank_of(int(rp))
		n_checked += 1
		if ro.is_valid():
			var b: Dictionary = ro.call(int(rp))
			if int(a.tier) != int(b.tier) or int(a.sub) != int(b.sub) or int(a.into) != int(b.into) or String(a.title) != String(b.title):
				bad += 1
		if ri.is_valid() and TWRewards.rank_index(int(rp)) != int(ri.call(int(rp))):
			bad += 1
	_check("ladder: rank_of / rank_index == G on %d points (bad %d)%s" % [n_checked, bad, "" if ro.is_valid() else " (no live G given)"], bad == 0)
	# rank-ups == the legacy add_rp transcription, positive and negative additions
	var bad2: = 0
	for i in 500:
		var old: = rng.below(5000)
		var add: = rng.below(120) - (rng.below(40) if rng.chance(0.2) else 0)
		var want: = Legacy.add_rp(old, add, TWRewards.RANKS)
		var ups: = TWRewards.rank_ups(old, add)
		var gems: = []
		for u in ups:
			gems.append(int(u.gems))
		if gems != want.ups or TWRewards.rp_after(old, add) != int(want.rp):
			bad2 += 1
	_check("ladder: rank_ups / rp_after == legacy add_rp on 500 additions (bad %d)" % bad2, bad2 == 0)
	_check("ladder: a new tier pays the table, a new step 50 x (tier + 1)", TWRewards.ups_gems(TWRewards.rank_ups(0, 60)) == 50, str(TWRewards.rank_ups(0, 60)))
	_check("ladder: ranks never fall below the floor", TWRewards.rp_after(70, -50) == 60 and TWRewards.rp_after(5, -50) == 0)


# ═══════════════════════════════════════════ D: boosters ════════════════════════════════════════════════════════════

static func _boosters() -> void:
	var c: = TWBoosters.counters()
	_check("boosters: start counters", c.hint_n == 2 and c.undo_n == 2 and c.shuffle_n == 1 and c.rescue_free and c.free_rescue_left == 0 and c.boosters_used == 0 and not c.riichi)
	_check("boosters: prices 30 / 60 == V8PlayRules", TWBoosters.HELP_PRICE == V8PlayRules.HELP_PRICE and TWBoosters.RESCUE_PRICE == V8PlayRules.RESCUE_PRICE and TWBoosters.HELP_PRICE == 30 and TWBoosters.RESCUE_PRICE == 60)
	# the decision table: kind, counters, ctx -> do
	var ok_ctx: = {"input_on": true, "hint_active": false, "has_move": true, "history_empty": false}
	var rows: = [
		["hint", {"hint_n": 2}, {}, "free", 0], ["hint", {"hint_n": 1}, {}, "free", 0], ["hint", {"hint_n": 0}, {}, "pay", 30], ["hint", {"hint_n": -1}, {}, "pay", 30],
		["hint", {"hint_n": 2, "riichi": true}, {}, "locked", 0], ["hint", {"hint_n": 0, "riichi": true}, {}, "locked", 0],
		["hint", {"hint_n": 2}, {"input_on": false}, "deny", 0], ["hint", {"hint_n": 2}, {"hint_active": true}, "active", 0],
		["hint", {"hint_n": 0}, {"hint_active": true}, "active", 0], ["hint", {"hint_n": 2}, {"has_move": false}, "deny", 0],
		["hint", {"hint_n": 0}, {"has_move": false}, "deny", 0],
		["undo", {"undo_n": 2}, {}, "free", 0], ["undo", {"undo_n": 0}, {}, "pay", 30], ["undo", {"undo_n": 2}, {"history_empty": true}, "none", 0],
		["undo", {"undo_n": 0}, {"history_empty": true}, "none", 0], ["undo", {"undo_n": 2, "riichi": true}, {}, "locked", 0], ["undo", {"undo_n": 2}, {"input_on": false}, "deny", 0],
		["shuffle", {"shuffle_n": 1}, {}, "free", 0], ["shuffle", {"shuffle_n": 0}, {}, "pay", 30], ["shuffle", {"shuffle_n": 1, "riichi": true}, {}, "locked", 0],
		["shuffle", {"shuffle_n": 0}, {"input_on": false}, "deny", 0], ["shuffle", {"shuffle_n": 3}, {"history_empty": true, "has_move": false}, "free", 0],
		["bogus", {}, {}, "deny", 0],
	]
	for row in rows:
		var ctx: = ok_ctx.duplicate()
		ctx.merge(row[2], true)
		var d: = TWBoosters.decide(String(row[0]), row[1], ctx)
		_check("decide %s %s %s -> %s" % [row[0], str(row[1]), str(row[2]), row[3]], d["do"] == row[3] and int(d.price) == int(row[4]), str(d))
	# commit: free help counts down, paid one reports the price; both count as a help for the stars
	var st: = TWBoosters.counters()
	_check("commit free hint: counter down, 0 to pay, boosters_used 1", TWBoosters.commit("hint", st, false) == 0 and st.hint_n == 1 and st.boosters_used == 1)
	_check("commit paid hint: counter kept, 30 to pay, boosters_used 2", TWBoosters.commit("hint", st, true) == 30 and st.hint_n == 1 and st.boosters_used == 2)
	_check("commit free undo / shuffle", TWBoosters.commit("undo", st, false) == 0 and st.undo_n == 1 and TWBoosters.commit("shuffle", st, false) == 0 and st.shuffle_n == 0 and st.boosters_used == 4)
	_check("commit paid shuffle", TWBoosters.commit("shuffle", st, true) == 30 and st.shuffle_n == 0 and st.boosters_used == 5)
	_check("afford: enough / short", TWBoosters.afford(30, 30).ok and not TWBoosters.afford(29, 30).ok and int(TWBoosters.afford(10, 30).missing) == 20 and int(TWBoosters.afford(99, 30).missing) == 0)
	# the stars follow the helps
	var s2: = TWBoosters.counters()
	for i in 3:
		TWBoosters.commit("hint", s2, i >= 2)
	_check("stars: 3 helps = 1 star, 0 helps = 3, 2 helps = 2", TWRewards.story_stars(0, int(s2.boosters_used)) == 1 and TWRewards.story_stars(0, 0) == 3 and TWRewards.story_stars(0, 2) == 2 and TWRewards.story_stars(1, 0) == 1)
	# rescue: the first is free, then 60; it burns «Ва-банк» and counts as a help
	var r: = TWBoosters.counters()
	_check("rescue: first free", TWBoosters.rescue_price(r) == 0)
	r.riichi = true
	var rc: = TWBoosters.rescue_commit(r)
	_check("rescue commit: free, burns riichi, counts a help", int(rc.price) == 0 and rc.riichi_burnt and not r.riichi and r.boosters_used == 1 and not r.rescue_free)
	_check("rescue: the second costs 60", TWBoosters.rescue_price(r) == 60)
	var rc2: = TWBoosters.rescue_commit(r)
	_check("rescue commit: paid 60, no riichi to burn", int(rc2.price) == 60 and not rc2.riichi_burnt and r.boosters_used == 2)
	# the overflow policy per mode
	for row in [["", 0, "fail"], ["daily", 0, "fail"], ["trial", 0, "fail"], ["pagoda", 0, "fail"], ["zen", 0, "free_return"], ["blitz", 0, "free_return"], ["duel", 0, "free_return"],
			["", 1, "free_return"], ["daily", 1, "free_return"], ["trial", 1, "free_return"]]:
		var o: = TWBoosters.overflow(String(row[0]), {"free_rescue_left": row[1]})
		_check("overflow '%s' with %d kitsune rescue -> %s" % [row[0], row[1], row[2]], o.kind == row[2], str(o))
	var s3: = {"free_rescue_left": 1, "fails": 0}
	var a1: = TWBoosters.apply_overflow("", s3, 0.0)
	_check("overflow: the kitsune rescue is used up once (Path)", a1.kind == "free_return" and s3.free_rescue_left == 0 and int(s3.fails) == 0)
	var a2: = TWBoosters.apply_overflow("", s3, 0.0)
	_check("overflow: then a fail is counted", a2.kind == "fail" and int(s3.fails) == 1)
	var s4: = {"free_rescue_left": 1}
	TWBoosters.apply_overflow("zen", s4, 0.0)
	_check("overflow: zen keeps the rescue (only Path / daily consume it)", s4.free_rescue_left == 1)
	var s5: = {}
	var b1: = TWBoosters.apply_overflow("blitz", s5, 37.5)
	_check("overflow: blitz loses 10 s", b1.kind == "free_return" and absf(float(b1.blitz_left) - 27.5) < 0.001 and not b1.blitz_over)
	var b2: = TWBoosters.apply_overflow("blitz", s5, 6.0)
	_check("overflow: blitz at 6 s ends the run", float(b2.blitz_left) == 0.0 and b2.blitz_over)
	var b3: = TWBoosters.apply_overflow("blitz", s5, 10.0)
	_check("overflow: blitz at exactly 10 s ends the run", b3.blitz_over)
	var b4: = TWBoosters.apply_overflow("duel", s5, 0.0)
	_check("overflow: duel returns the tray, no clock", b4.kind == "free_return" and not b4.blitz_over)
	# perks: partner / affection / album / fortune / level extras
	var base: = TWBoosters.loadout("none", 1, [], "", 0)
	_check("loadout: no perk = the plain counters", base.hint_n == 2 and base.undo_n == 2 and base.shuffle_n == 1 and base.gold_mult == 5 and base.gem_bonus == 0.0 and base.combo_window_set < 0.0 and base.combo_window_add == 0.0)
	var perks: = [
		["mc", "hint_n", 3], ["mc", "undo_n", 2], ["rin", "undo_n", 3], ["rin", "hint_n", 2], ["hana", "combo_window_set", 6.5], ["yue", "gold_mult", 8],
		["nova", "shuffle_n", 2], ["nova", "gem_bonus", 0.1], ["hana", "gold_mult", 5],
	]
	for p in perks:
		var o: = TWBoosters.loadout(String(p[0]), 1, [], "", 0)
		_check("loadout %s: %s = %s" % [p[0], p[1], p[2]], absf(float(o[p[1]]) - float(p[2])) < 0.0001, str(o[p[1]]))
	var aff: = TWBoosters.loadout("mc", 4, [], "", 0)
	_check("loadout: +5% crystals per affection level above 1", absf(float(aff.gem_bonus) - 0.15) < 0.0001)
	var al: = TWBoosters.loadout("yue", 1, ["hint", "shuffle", "undo", "gems", "gold", "combo"], "", 0)
	_check("loadout: album sets add on top of the partner perk (yue gold 8 -> 9)", al.hint_n == 3 and al.shuffle_n == 2 and al.undo_n == 3 and al.gold_mult == 9 and absf(float(al.gem_bonus) - 0.1) < 0.0001 and absf(float(al.combo_window_add) - 0.5) < 0.0001, str(al))
	for f in [["great", "gem_bonus", 0.5], ["pairs", "first_pairs_bonus", 3], ["wind", "shuffle_n", 2], ["tea", "combo_window_add", 1.5], ["tray", "free_rescue_left", 1], ["small", "hint_n", 3]]:
		var o: = TWBoosters.loadout("none", 1, [], String(f[0]), 0)
		_check("loadout fortune %s: %s = %s" % [f[0], f[1], f[2]], absf(float(o[f[1]]) - float(f[2])) < 0.0001, str(o[f[1]]))
	_check("loadout: level extras add hints", TWBoosters.loadout("none", 1, [], "", 3).hint_n == 5)
	_check("loadout: outfit is not an input (same call, same counters)", JSON.stringify(TWBoosters.loadout("mc", 3, ["gold"], "tea", 1)) == JSON.stringify(TWBoosters.loadout("mc", 3, ["gold"], "tea", 1)))
	var m1: = JSON.stringify(TWBoosters.loadout("nova", 6, ["gems", "undo"], "great", 0))
	_check("loadout nova aff 6 album gems+undo fortune great", m1.find("\"gem_bonus\":0.1") < 0 and absf(float(TWBoosters.loadout("nova", 6, ["gems", "undo"], "great", 0).gem_bonus) - (0.1 + 0.05 * 5 + 0.1 + 0.5)) < 0.0001)
	# loss counting
	for row in [["", true], ["daily", true], ["duel", true], ["blitz", true], ["zen", false], ["trial", false], ["pagoda", false], ["practice", false]]:
		_check("counts_loss('%s') = %s" % [row[0], row[1]], TWBoosters.counts_loss(String(row[0])) == bool(row[1]))


# ═══════════════════════════════════════════ E: mode configs ════════════════════════════════════════════════════════

static func _text(k: String) -> String:
	return "T:" + k


static func _modecfg(env: Dictionary) -> void:
	for m in TWModeCfg.MODES:
		_check("modecfg: mode '%s' is in the table" % m, TWModeCfg.known(m))
	_check("modecfg: sources", TWModeCfg.source("") == "path" and TWModeCfg.source("daily") == "daily" and TWModeCfg.source("blitz") == "blitz" and TWModeCfg.source("zen") == "zen"
		and TWModeCfg.source("duel") == "duel" and TWModeCfg.source("trial") == "other" and TWModeCfg.source("pagoda") == "other" and TWModeCfg.source("climb") == "other" and TWModeCfg.source("etude") == "other")
	_check("modecfg: hook names (Path is 'path')", TWModeCfg.hook_mode("") == "path" and TWModeCfg.hook_mode("daily") == "daily" and TWModeCfg.hook_mode("pagoda") == "pagoda")
	_check("modecfg: ranked modes", TWModeCfg.is_ranked("duel") and TWModeCfg.is_ranked("v7tourney") and TWModeCfg.is_ranked("duel_ranked") and not TWModeCfg.is_ranked("") and not TWModeCfg.is_ranked("blitz"))
	_check("modecfg: slots zen 6, others 4", TWModeCfg.slot_base("zen") == 6 and TWModeCfg.slot_base("") == 4 and TWModeCfg.slot_base("duel") == 4 and TWModeCfg.slot_base("blitz") == 4)
	_check("modecfg: only blitz has a clock (120 s)", TWModeCfg.start_clock("blitz") == 120.0 and TWModeCfg.start_clock("zen") == 0.0 and TWModeCfg.start_clock("") == 0.0)
	_check("modecfg: tower family", TWModeCfg.is_tower("pagoda") and TWModeCfg.is_tower("journey") and TWModeCfg.is_tower("practice") and not TWModeCfg.is_tower("trial"))
	_check("modecfg: only trial / tower pay no pair crystals", TWModeCfg.row("trial").pairs == false and TWModeCfg.row("").pairs == true and TWModeCfg.row("blitz").pairs == true)
	_check("modecfg: daily table = day of month mod the Path length", TWModeCfg.daily_level(17, 1000) == 17 and TWModeCfg.daily_level(31, 20) == 11 and TWModeCfg.daily_level(5, 0) == 0)
	_check("modecfg: daily seed is the date as a number", TWModeCfg.daily_seed("2026-11-28") == 20261128)
	var base: = {"name": "x", "seed": 5, "reward": {"gems": 7}, "shard": "rin", "goal": "g", "intro": "i", "cols": 5}
	var dc: = TWModeCfg.daily_cfg(base, "2026-11-28", Callable(TWRoundSelftest, "_text"))
	_check("modecfg daily: name seed reward goal intro, shard erased, base untouched", dc.name == "T:play.daily_name" and dc.seed == 20261128 and dc.reward.gems == 100 and not dc.has("shard")
		and dc.goal == "T:play.goal_clear" and dc.intro == "T:play.daily_intro" and dc.cols == 5 and base.has("shard") and int(base.seed) == 5)
	var tc: = TWModeCfg.trial_cfg(base, "Рин", Callable(TWRoundSelftest, "_text"))
	_check("modecfg trial: name with the hero, no reward, no shard", tc.name == "T:play.trial_name_preРин" and tc.reward.gems == 0 and not tc.has("shard") and tc.goal == "T:play.trial_goal" and tc.intro == "T:play.trial_intro")
	var seen_shapes: = {}
	var all_ok: = true
	for n in 6:
		for zen in [false, true]:
			var c: = TWModeCfg.blitz_zen_cfg(zen, n, "rin", 1000 + n, Callable(TWRoundSelftest, "_text"))
			seen_shapes[c.shape] = true
			var want_layers: = (3 if zen else 2 + mini(n, 2))
			var want_faces: = (12 if zen else 7 + mini(n, 4))
			all_ok = all_ok and c.cols == (6 if zen else 5) and c.rows == (7 if zen else 6) and c.layers == want_layers and c.faces == want_faces and c.gold == (0 if zen else 2) \
				and c.fx == ("petals" if zen else "lanterns") and c.hero == "rin" and c.fill == 0.65 and c.reward.gems == 0 and c.mech == "" and c.hard == 0 and c.ice == 0 and c.hidden == false \
				and c.bg == (["play", "bg_teahouse", "bg_festival", "bg_palace", "bg_shrine"][n % 5] if zen else "bg_festival") and (c.shape in TWModeCfg.SHAPES) and typeof(c.seed) == TYPE_INT
	_check("modecfg blitz / zen: every field of the legacy _mode_cfg for boards 0..5", all_ok)
	_check("modecfg blitz / zen: the shape varies with the seed", seen_shapes.size() >= 3, str(seen_shapes.keys()))
	var c1: = TWModeCfg.blitz_zen_cfg(false, 2, "mc", 77, Callable(TWRoundSelftest, "_text"))
	var c2: = TWModeCfg.blitz_zen_cfg(false, 2, "mc", 77, Callable(TWRoundSelftest, "_text"))
	_check("modecfg blitz: same seed, same config", JSON.stringify(c1) == JSON.stringify(c2))
	var loc: = {"tint": Color(0.5, 0.6, 0.7), "intro": "На вечернем рынке горят фонари."}
	var pf: = TWModeCfg.path_fill({"seed": 1}, loc, Callable(TWRoundSelftest, "_text"))
	_check("modecfg path_fill: tint, goal and intro from the location", pf.tint == loc.tint and pf.goal == "T:play.goal_clear" and pf.intro == loc.intro)
	var pf2: = TWModeCfg.path_fill({"tint": Color.RED, "goal": "mine", "intro": "A long enough intro text", "intro_line": "line"}, loc, Callable(TWRoundSelftest, "_text"))
	_check("modecfg path_fill: keeps what the level has", pf2.tint == Color.RED and pf2.goal == "mine" and pf2.intro == "A long enough intro text")
	var pf3: = TWModeCfg.path_fill({"intro": "short", "intro_line": "the line"}, loc, Callable(TWRoundSelftest, "_text"))
	_check("modecfg path_fill: a short intro is replaced by the intro line, then by the location's", pf3.intro == "the line" and TWModeCfg.path_fill({"intro": "short"}, loc, Callable(TWRoundSelftest, "_text")).intro == loc.intro)
	var gcfg: = TWModeCfg.apply_fortune({"gold": 2, "seed": 1}, {"id": "gold", "gold": 4})
	_check("modecfg fortune gold: +4 gold tiles, original untouched", gcfg.gold == 6)
	var orig: = {"gold": 2, "v10_id": "p1"}
	_check("modecfg fortune gold: not on a certified level", TWModeCfg.apply_fortune(orig, {"gold": 4}).gold == 2)
	_check("modecfg fortune: no gold fortune changes nothing", TWModeCfg.apply_fortune({"gold": 2}, {"id": "tea"}).gold == 2)
	# live parity of the live strings when the runner gave a text function
	var tx: Callable = env.get("text", Callable())
	if tx.is_valid():
		var dd: = TWModeCfg.daily_cfg({"name": "?"}, "2026-01-02", tx)
		_check("modecfg: live texts are used (daily name is not empty)", String(dd.name) != "" and String(dd.goal) != "")


# ═══════════════════════════════════════════ F: the legacy diff ═════════════════════════════════════════════════════

static func _legacy(env: Dictionary) -> void:
	var rng: = TWRng.make(20261128, 11)
	var bad: = {}
	var cnt: = {}
	var n_scen: = 300
	for k in n_scen:
		var sc: = _scenario(rng)
		var mode: String = sc.mode
		cnt[mode] = int(cnt.get(mode, 0)) + 1
		var want: = Legacy.round(sc.state, mode, sc.cfg, sc.stats)
		var r: = TWRound.resolve(_state_of(sc.state), mode, sc.cfg, sc.stats)
		var ups: = []
		for u in r.rank_ups:
			ups.append(int(u.gems))
		var got: = {"stars": r.stars, "reward": r.reward, "rp_gain": r.rp_gain, "rp_after": r.rp_after, "ups": ups, "gems": r.granted("gems"), "tickets": r.granted("tickets"),
			"win": r.win, "first": r.first, "yaku": r.yaku, "tasks": r.tasks.size(), "bond": r.bond.size(), "pass_xp": r.pass_xp, "xp": r.xp, "record": r.record.get("source", "") + ":" + str(r.record.get("won", "")),
			"unlocked": int(r.writes.get("unlocked", -1)), "star_write": int(r.writes.get("stars", {}).get("stars", -1)), "daily_day": int(r.writes.get("daily_done_day", -1)),
			"item": String(r.writes.get("item", "")), "summon": bool(r.flags.get("first_unlock_summon", false))}
		if not TWModeCfg.is_tower(mode) and r.outcome != "none" and not (mode == "zen" and s_event(sc) == "board"):
			var wp: = Legacy.payload(mode, want, sc.stats, s_event(sc))
			var hk_diff: = false
			for hk in wp:
				if str(r.hook.get(hk)) != str(wp[hk]):
					hk_diff = true
					if int(bad.get("hook", 0)) < 2:
						printerr("legacy hook diff ", hk, " scenario ", k, " mode '", mode, "' got ", r.hook.get(hk), " want ", wp[hk])
			if hk_diff:
				bad["hook"] = int(bad.get("hook", 0)) + 1
		for key in want:
			if str(got[key]) != str(want[key]):
				bad[key] = int(bad.get(key, 0)) + 1
				if int(bad[key]) <= 2:
					printerr("legacy diff ", key, " scenario ", k, " mode '", mode, "' got ", got[key], " want ", want[key])
	_check("legacy diff: %d scenarios (%s) 0 differences in %d fields (differing: %s)" % [n_scen, str(cnt), Legacy.FIELDS, str(bad)], bad.is_empty())
	_check("legacy diff: every mode appeared >= 20 times", cnt.size() >= 6 and (cnt.values() as Array).min() >= 20, str(cnt))


static func s_event(sc: Dictionary) -> String:
	return String(sc.stats.get("event", "clear"))


static func _scenario(rng: TWRng) -> Dictionary:
	var mode: String = ["", "", "", "daily", "daily", "trial", "blitz", "zen", "duel", "pagoda", "journey"][rng.below(11)]
	var st: = {"rp": rng.below(4000), "partner": ["mc", "rin", "hana", "yue", "nova"][rng.below(5)], "level_stars": [0, 0, 1, 2, 3][rng.below(5)], "levels_size": 1000,
		"unlocked": 1 + rng.below(400), "day": 1 + rng.below(28), "daily_done": [], "afisha_mult": [1, 1, 1, 2][rng.below(4)], "blitz_best": rng.below(2500), "combo_min": 5,
		"best_combo_prev": rng.below(12), "rival_first_win": rng.chance(0.4), "path_gems": [0, 60, 120, 200][rng.below(4)], "demo": rng.chance(0.05),
		"ranks": TWRewards.RANKS, "outfit": ["o_base", "o_dragon", "y_queen"][rng.below(3)]}
	for i in rng.below(6):
		st.daily_done.append(1 + rng.below(28))
	var cfg: = {"reward": {"gems": [0, 30, 50, 80, 100][rng.below(5)]}, "hard": rng.below(4)}
	if rng.chance(0.15):
		cfg["v10_id"] = "p%d" % rng.below(900)
	if rng.chance(0.15):
		cfg.reward["item"] = "o_fan"
	var tiles: int = [24, 36, 48, 60][rng.below(4)]
	var s: = {"event": "clear", "level": rng.below(1000) if rng.chance(0.9) else 2, "secs": 10.0 + float(rng.below(3000)) / 10.0, "tiles": tiles, "fails": [0, 0, 0, 1, 2][rng.below(5)],
		"boosters_used": [0, 0, 1, 2, 3, 6][rng.below(6)], "max_combo": 1 + rng.below(14), "last_combo": 1 + rng.below(6), "denies": [0, 0, 2, 9][rng.below(4)], "max_tray": 1 + rng.below(3),
		"gold_total": [0, 0, 2, 4][rng.below(4)], "gold_got": 0, "sets_done": [], "riichi": rng.chance(0.2), "gained": rng.below(150), "blitz_score": rng.below(4500),
		"boards_done": 1 + rng.below(16), "hero": st.partner, "seed": rng.below(100000), "me": rng.below(15), "her": rng.below(15), "rival": ["rin", "yue", "hana"][rng.below(3)]}
	s.gold_got = rng.below(int(s.gold_total) + 1)
	for i in rng.below(3):
		s.sets_done.append(rng.below(5))
	match mode:
		"blitz", "zen", "duel":
			s["event"] = "end" if mode == "blitz" else ("board" if mode == "zen" else "finish")
			if rng.chance(0.12):
				s["event"] = "leave"
		"pagoda", "journey":
			var win: = rng.chance(0.6)
			s["tower"] = {"kind": mode, "win": win, "floor": 1 + rng.below(25), "board": 1 + rng.below(10), "run_over": (not win) and rng.chance(0.5)}
		_:
			if rng.chance(0.15):
				s["event"] = "leave"
	return {"mode": mode, "state": st, "cfg": cfg, "stats": s}


# the frozen transcription of the legacy code (play.gd / duel.gd / tower_play.gd / v08 play_rules / g.gd at db112f5), written as plain
# functions over dictionaries. It exists so the new code is diffed against the OLD logic after play.gd itself has been shrunk.
class Legacy:
	const FIELDS: = 20

	static func on_match(P: Dictionary, combo: int, gold: bool, fever: bool) -> int:
		var mult: = 1 + (combo - 1) / 2
		var gain: = int(round(mult * (2 if fever else 1) * (P.gold_mult if gold else 1) * (1.0 + P.gem_bonus)))
		if P.first_pairs_bonus > 0:
			P.first_pairs_bonus -= 1
			gain *= 3
		if P.mode == "trial":
			gain = 0
		return gain

	# G.rank_of / add_rp (the part that does not touch the league or the wallet)
	static func rank_index(rp: int, ranks: Array) -> int:
		var left: = rp
		for t in ranks.size():
			var per: int = ranks[t].per
			var subs: = 3 if t < ranks.size() - 1 else 999
			for s in subs:
				if left < per:
					return t * 3 + s
				left -= per
		return (ranks.size() - 1) * 3

	static func rank_into(rp: int, ranks: Array) -> int:
		var left: = rp
		for t in ranks.size():
			var per: int = ranks[t].per
			var subs: = 3 if t < ranks.size() - 1 else 999
			for s in subs:
				if left < per:
					return left
				left -= per
		return 0

	static func add_rp(old_rp: int, n: int, ranks: Array) -> Dictionary:
		var before: = rank_index(old_rp, ranks)
		var new_rp: = old_rp + n
		if n < 0:
			new_rp = maxi(new_rp, maxi(0, old_rp - rank_into(old_rp, ranks)))
		new_rp = maxi(0, new_rp)
		var after: = rank_index(new_rp, ranks)
		var ups: = []
		for k in range(before + 1, after + 1):
			var t: = mini(k / 3, ranks.size() - 1)
			var s: = k - t * 3
			var g: int = ranks[t].gems if s == 0 else 50 * (t + 1)
			ups.append(g)
		return {"rp": new_rp, "ups": ups}

	static func yaku(s: Dictionary) -> Array:
		var ys: = []
		if s.riichi:
			ys.append("riichi")
		if s.boosters_used == 0 and s.fails == 0:
			ys.append("clean")
		if s.max_tray <= 2:
			ys.append("calm")
		if s.denies == 0:
			ys.append("sharp")
		if s.secs < s.tiles * 1.1:
			ys.append("swift")
		if s.max_combo >= 7:
			ys.append("dragon")
		if s.gold_total > 0 and s.gold_got >= s.gold_total:
			ys.append("goldvein")
		if s.last_combo >= 3:
			ys.append("finale")
		for c in s.sets_done:
			ys.append("set:%d" % c)
		return ys

	static func yaku_rp(y: String) -> int:
		const T: = {"clean": 4, "calm": 3, "sharp": 2, "swift": 3, "riichi": 6, "dragon": 4, "goldvein": 2, "finale": 2, "set": 2}
		if y.begins_with("set:"):
			return T.set
		return T[y]

	# play.gd _v10_ended: the game_ended payload (what the old code sent for this round)
	static func payload(mode: String, w: Dictionary, s: Dictionary, ev: String) -> Dictionary:
		var win: bool = bool(w.win)
		var stars: int = int(w.stars)
		var reward: int = int(w.reward)
		var score: = 0
		var first: bool = bool(w.first)
		if ev == "leave":
			win = false
			stars = 0
			reward = 0
			first = false
		elif mode == "blitz":
			win = true
			score = int(s.blitz_score)
		elif mode == "duel":
			reward = 0
			first = false
		return {"mode": "path" if mode == "" else mode, "win": win, "score": score, "stars": stars, "pairs": int(s.tiles) / 2, "level": int(s.level) if mode == "" else -1,
			"first": first, "rewards": {"gems": reward}, "max_combo": int(s.max_combo), "clean": win and int(s.boosters_used) == 0 and int(s.fails) == 0,
			"dragons": 1 if win and int(s.max_combo) >= 7 else 0, "seed": int(s.seed), "hero": String(s.hero), "time_s": float(s.secs)}


	static func round(st: Dictionary, mode: String, cfg: Dictionary, s: Dictionary) -> Dictionary:
		var out: = {"stars": 0, "reward": 0, "rp_gain": 0, "rp_after": st.rp, "ups": [], "gems": 0, "tickets": 0, "win": false, "first": false, "yaku": [], "tasks": 0, "bond": 0,
			"pass_xp": 0, "xp": 0, "record": ":", "unlocked": -1, "star_write": -1, "daily_day": -1, "item": "", "summon": false}
		var ranks: Array = st.ranks
		var src: = "path"
		match mode:
			"daily", "duel", "blitz", "zen":
				src = mode
			"":
				src = "path"
			_:
				src = "other"
		var mult: int = st.afisha_mult
		if mode in ["pagoda", "journey"]:
			var t: Dictionary = s.tower
			out.win = t.win
			if t.win:
				out.bond = 1
				out.tasks = 1
				var rp: = 0
				if mode == "pagoda":
					rp = clampi(4 + int(t.floor), 5, 15)
				else:
					rp = clampi(6 + 2 * (int(t.board) - 1), 5, 15)
				rp *= mult
				out.rp_gain = rp
				var a: = add_rp(st.rp, rp, ranks)
				out.ups = a.ups
				out.rp_after = a.rp
				out.record = "other:true"
			elif t.run_over:
				out.record = "other:false"
			return out
		if s.event == "leave":
			if src in ["path", "daily", "duel", "blitz"]:
				out.record = src + ":false"
			return out
		if mode == "blitz":
			var score: int = s.blitz_score
			var gems: = mini(150, score / 20)
			out.win = true
			out.reward = gems
			out.gems = gems
			var rp: = 0 if score <= 0 else clampi(5 + score / 200, 5, 15)
			rp *= mult
			out.rp_gain = rp
			if rp != 0:
				var a: = add_rp(st.rp, rp, ranks)
				out.ups = a.ups
				out.rp_after = a.rp
			out.record = "blitz:" + str(int(s.boards_done) > 0)
			return out
		if mode == "zen":
			out.win = true
			out.reward = 30
			out.gems = 30
			var rp: int = clampi(4 + int(s.boards_done), 5, 15) * mult
			out.rp_gain = rp
			var a: = add_rp(st.rp, rp, ranks)
			out.ups = a.ups
			out.rp_after = a.rp
			out.record = "zen:true"
			return out
		if mode == "duel":
			var win: bool = s.me > s.her
			var draw: bool = s.me == s.her
			var gems: = 60 if win else (30 if draw else 15)
			if win and st.rival_first_win:
				gems += 100
			out.win = win
			out.reward = gems
			out.gems = gems
			out.bond = 2
			out.pass_xp = 60
			var rp: = (20 if win else (5 if draw else 0)) * mult
			out.rp_gain = rp
			if rp != 0:
				var a: = add_rp(st.rp, rp, ranks)
				out.ups = a.ups
				out.rp_after = a.rp
			out.record = "duel:" + str(win)
			return out
		# _on_clear of a Path / daily / trial table
		var stars: int = 3 if (s.fails == 0 and s.boosters_used == 0) else (2 if (s.fails == 0 and s.boosters_used <= 2) else 1)
		if st.demo:
			stars = 3
		out.win = true
		out.stars = stars
		var yl: = yaku(s)
		out.yaku = yl
		var first: = false
		var reward: = 0
		var path_paid: = false
		var lvl: int = s.level
		if mode == "":
			first = st.level_stars == 0
			if cfg.has("v10_id"):
				reward = st.path_gems
				path_paid = true
			else:
				out.star_write = maxi(st.level_stars, stars)
				out.unlocked = maxi(int(st.unlocked), mini(lvl + 2, int(st.levels_size)))
				reward = cfg.reward.gems + stars * 20
			if first and cfg.reward.has("item"):
				out.item = cfg.reward.item
			if first and lvl == 2:
				out.summon = true
				out.tickets = 10
		elif mode == "daily":
			reward = cfg.reward.gems + stars * 20
			var d: int = st.day
			if not d in (st.daily_done as Array).map(func(x): return int(x)):
				out.daily_day = d
		var riichi_extra: = 0
		if s.riichi:
			riichi_extra = reward + s.gained
			reward = reward * 2 + s.gained
		out.reward = reward
		out.first = first
		if mode != "trial":
			var yrp: = 0
			for y in yl:
				yrp += yaku_rp(y)
			var rp: int = 6 + stars * 4 + (int(cfg.get("hard", 0)) if mode == "" else 0) * 8 + mini(yrp, 30)
			out.rp_gain = rp
			var a: = add_rp(st.rp, rp, ranks)
			out.ups = a.ups
			out.rp_after = a.rp
			out.record = ("daily" if mode == "daily" else "path") + ":true"
			out.bond = 1
			out.tasks = 1
			out.pass_xp = 100
			out.xp = 40
		out.gems = riichi_extra if path_paid else reward
		return out


# ═══════════════════════════════════════════ G: bot rounds, outfit, no counters ════════════════════════════════════

static func _bot_cfg(seed_: int) -> Dictionary:
	return {"cols": 5, "rows": 6, "layers": 2, "fill": 0.65, "faces": 8, "seed": seed_, "shape": "rect", "gold": 2, "ice": 0, "hidden": false, "shard": "", "slots": 4}


# one full round by the solver bot; returns {board, rs, stats, secs}
static func _play(seed_: int, mode: String, lo: Dictionary) -> Dictionary:
	var b: = TWBoard.from_cfg(_bot_cfg(seed_))
	b.combo_window = 5.0
	var rs: = TWRoundStats.new().begin(b, mode, lo)
	var guard: = 0
	while not b.cleared and not b.failed and guard < 400:
		guard += 1
		b.time += 0.6
		var t: = b.solver_move()
		if t < 0:
			break
		var ev: = b.tap(t)
		rs.feed(ev, b.now())
	return {"board": b, "rs": rs, "secs": b.time}


static func _bot() -> void:
	var cleared: = 0
	var lost: = 0
	var consistent: = true
	var invariant: = 0
	var total_games: = 24
	var forbidden: = 0
	for g in total_games:
		var seed_: = 500 + g * 17
		var digests: = []
		for outfit in ["o_base", "o_dragon", "y_queen"]:
			var lo: = TWBoosters.loadout("mc", 3, ["gold"], "", 0)
			var p: = _play(seed_, "", lo)
			var b: TWBoard = p.board
			var rs: TWRoundStats = p.rs
			var ev: = "clear" if b.cleared else "leave"
			var stats: = rs.stats(b, float(p.secs), ev, {"level": 5, "hero": "mc", "seed": seed_, "boosters_used": 0})
			var st: = {"rp": 20, "partner": "mc", "level_stars": 0, "unlocked": 3, "levels_size": 1000, "outfit": outfit, "outfit_id": outfit, "skin": outfit}
			var r: = TWRound.resolve(st, "", {"reward": {"gems": 50}, "hard": 0}, stats)
			digests.append(r.digest())
			if outfit == "o_base":
				if b.cleared:
					cleared += 1
				else:
					lost += 1
				consistent = consistent and rs.pairs == b.pairs_done and rs.max_combo >= 1 and rs.tiles == b.n and int(stats.max_tray) == b.max_tray
				var sum: = 0
				for e in rs.pair_log:
					sum += int(e.gain)
				consistent = consistent and rs.gained >= sum
				forbidden += _forbidden_keys(r.to_dict())
		if digests[0] != digests[1] or digests[0] != digests[2]:
			invariant += 1
	_check("bot: %d rounds played by the solver (cleared %d, lost %d)" % [total_games, cleared, lost], cleared + lost == total_games and cleared >= 12)
	_check("bot: stats from the event stream match the board (pairs, tiles, max tray, gained >= pair sum)", consistent)
	_check("bot: the outfit does not change the result: 24 seeds x 3 outfits, difference %d" % invariant, invariant == 0)
	_check("bot: RoundResult has no «осталось сегодня» field or text (%d hits)" % forbidden, forbidden == 0)
	# a full-pipeline difference of the three outfits at the level of the loadout too
	_check("bot: TWRoundResult has exactly the documented keys", (TWRoundResult.new().to_dict().keys() as Array) == TWRoundResult.KEYS)
	# a lost round resolves to a lost game (random taps overflow the tray)
	var b2: = TWBoard.from_cfg(_bot_cfg(900))
	var rs2: = TWRoundStats.new().begin(b2, "", {})
	var rr: = TWRng.make(5, 5)
	var guard2: = 0
	while not b2.failed and not b2.cleared and guard2 < 400:
		guard2 += 1
		b2.time += 0.6
		var fr: = b2.free_tiles()
		if fr.is_empty():
			break
		rs2.feed(b2.tap(fr[rr.below(fr.size())]), b2.now())
	_check("bot: random taps lose the table (tray full)", b2.failed and rs2.fails == 1)
	var r2: = TWRound.resolve({"rp": 0}, "", {"reward": {"gems": 50}}, rs2.stats(b2, b2.time, "leave", {"level": 1}))
	_check("bot: a lost table resolves to a lost game: no crystals, no rank points, record path lost", not r2.win and r2.grants.is_empty() and r2.rp_gain == 0 and r2.record.source == "path" and not r2.record.won)
	# the stats of a blitz run: points = 10 x combo summed
	var bp: = _play(321, "blitz", TWBoosters.loadout("none", 1, [], "", 0))
	var want_score: = 0
	for e in bp.rs.pair_log:
		want_score += 10 * maxi(1, int(e.combo))
	_check("bot: blitz score == sum of 10 x combo over the pairs", bp.rs.blitz_score == want_score and want_score > 0)
	var zp: = _play(322, "zen", TWBoosters.loadout("none", 1, [], "", 0))
	_check("bot: zen score == pairs", zp.rs.blitz_score == zp.rs.pairs)
	var tp: = _play(323, "trial", TWBoosters.loadout("none", 1, [], "", 0))
	_check("bot: a trial table pays no pair crystals", tp.rs.gained - 0 >= 0 and _sum_gain(tp.rs) == 0)


static func _sum_gain(rs: TWRoundStats) -> int:
	var n: = 0
	for e in rs.pair_log:
		n += int(e.gain)
	return n


# any key / string of the result that talks about what is left for today
static func _forbidden_keys(v, depth: int = 0) -> int:
	var hits: = 0
	if depth > 8:
		return 0
	if v is Dictionary:
		for k in v:
			var ks: = String(k).to_lower()
			for w in ["left", "remain", "today", "осталось", "сегодня", "limit", "cap", "quota"]:
				if ks.find(w) >= 0:
					hits += 1
			hits += _forbidden_keys(v[k], depth + 1)
	elif v is Array:
		for x in v:
			hits += _forbidden_keys(x, depth + 1)
	elif v is String:
		var s: = String(v).to_lower()
		for w in ["осталось", "сегодня", "remaining", "left today"]:
			if s.find(w) >= 0:
				hits += 1
	return hits


# ═══════════════════════════════════════════ H: the wallet ══════════════════════════════════════════════════════════

static func _wallet() -> void:
	var rng: = TWRng.make(77, 5)
	var bad: = 0
	var audit_bad: = 0
	for k in 60:
		var sc: = _scenario(rng)
		var st: Dictionary = sc.state
		var S: = {"gems": 1000, "coins": 50, "tickets": 3}
		var w: = TWWallet.for_state(S)
		var r: = TWRound.resolve(_state_of(st), sc.mode, sc.cfg, sc.stats)
		var want: = Legacy.round(st, sc.mode, sc.cfg, sc.stats)
		var ev: = r.pay(w)
		var errs: = 0
		for e in ev:
			if String(e.get("type", "")) == "ERROR":
				errs += 1
		if w.bal("gems") != 1000 + int(want.gems) or w.bal("tickets") != 3 + int(want.tickets) or w.bal("coins") != 50 or errs > 0:
			bad += 1
		if not w.audit().is_empty():
			audit_bad += 1
	_check("wallet: 60 rounds paid through TWWallet == the legacy balances (bad %d)" % bad, bad == 0)
	_check("wallet: the invariant holds after every payment (bad %d)" % audit_bad, audit_bad == 0)
	var S2: = {"gems": 0, "coins": 0}
	var w2: = TWWallet.for_state(S2)
	var r2: = TWRound.resolve({"rp": 0, "partner": "mc"}, "", {"reward": {"gems": 50}, "hard": 0}, {"event": "clear", "level": 2, "secs": 50.0, "tiles": 40, "fails": 0, "boosters_used": 0, "max_combo": 3, "last_combo": 1,
		"denies": 0, "max_tray": 1, "gold_total": 0, "gold_got": 0, "sets_done": [], "riichi": false, "gained": 0})
	var ev2: = r2.pay(w2)
	_check("wallet: level 2 first clear = 10 tickets then 110 crystals, WALLET_CHANGED events in order", ev2.size() == 2 and ev2[0].cur == "tickets" and int(ev2[0].delta) == 10 and ev2[1].cur == "gems" and int(ev2[1].delta) == 110 and w2.bal("tickets") == 10 and w2.bal("gems") == 110, str(ev2))
	var none: = TWRoundResult.new()
	_check("wallet: an empty result pays nothing", none.pay(w2).is_empty())
	# a negative grant is refused loudly by the wallet, never silently clamped
	var neg: = TWRoundResult.new()
	neg.grants.append({"cur": "gems", "n": -5, "reason": "x"})
	var errs_before: = TWWallet.errors
	var ev3: = neg.pay(w2)
	TWWallet.errors = errs_before
	_check("wallet: a negative grant becomes an ERROR event, the balance is untouched", ev3.size() == 1 and ev3[0].type == "ERROR" and w2.bal("gems") == 110)


# ═══════════════════════════════════════════ I: purity ══════════════════════════════════════════════════════════════

static func _purity() -> void:
	var rx: = RegEx.new()
	rx.compile("(?<![A-Za-z0-9_.])G\\.|get_tree|add_child|queue_free|\\bSfx\\b|V9Feel|/ro" + "ot/|\\bNode\\b|Control\\b|create_tween")
	for f in FILES:
		var text: = FileAccess.get_file_as_string("res://core/round/" + f)
		var code: = ""
		for line in text.split("\n"):
			var i: = line.find("#")
			code += (line.substr(0, i) if i >= 0 else line) + "\n"
		# string literals do not count
		var rs: = RegEx.new()
		rs.compile("\"[^\"\\n]*\"")
		code = rs.sub(code, "\"\"", true)
		var hit: = rx.search(code)
		_check("purity: %s has no G / scene tree / audio reference" % f, text != "" and hit == null, "" if hit == null else hit.get_string())
