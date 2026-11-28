class_name TWParitySelftest
extends RefCounted

# P17 (WP5): TWBoard parity with the legacy TrayBoard, by recorded games (the legacy _assign is unseeded, so a seed cannot prove
# anything: the corpus stores the legacy DEAL (layout + faces + ice/gold/secret/shard) and the legacy JOURNAL (every operation
# with the state the legacy board showed after it)). Pure core: no TrayBoard, no scene tree. The corpus lives in
# tests/fixtures/replays/corpus_NN.json and is written by the recorder (scripts/v10/rules/parity_record_runner.gd) from the
# real TrayBoard; the lockstep fuzz against a live TrayBoard is scripts/v10/rules/parity_legacy.gd (the shell side).
#
#   A  corpus     500 games: one check per game = 0 divergences in legality and outcome across its whole journal
#   B  layouts    the stored layout of every game == TWFree.positions(cfg) (the gen_layout path) and its initial free set
#   C  levels     V10LevelGen certificate of every Path level replays on TWBoard (1000/1000)
#   D  fuzz       (shell side) 5000 random operations in lockstep with a live TrayBoard: the free set, tray, counters equal
#
# What is compared after every journal entry (legacy value recorded vs TWBoard value): result kind of a tap (deny / ice crack /
# to tray / match / tray full / ignored), board count, tray size and the tray tile ids in order, combo, cracks, max tray, the
# FREE set (count + hash of ascending ids), undo / rescue effect, and the pairs picked by the ults. Operations that the legacy
# does with the unseeded engine RNG (shuffle) are checked structurally on TWBoard (same tiles, same faces, a twin on the table for
# every tray tile) and then the recorded legacy faces are applied so the rest of the journal stays comparable.
#
# Prints "TWPARITY_SELFTEST ok/total" (FAIL lines first). Args of run(env): games_n (500), levels_n (1000).

const E = preload("res://core/rules/tw_events_board.gd")
const DIR: = "res://tests/fixtures/replays/"

# tap result kinds
const K_DENY: = 0
const K_CRACK: = 1
const K_TRAY: = 2
const K_MATCH: = 3
const K_FULL: = 4
const K_IGNORED: = 5

static var _pass: = 0
static var _fail: = 0
static var stats: = {}


static func begin() -> void:
	_pass = 0
	_fail = 0
	stats = {}


static func check(name: String, ok: bool, info: String = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("FAIL ", name, ("  " + info) if info != "" else "")


static func stat_add(key: String, v: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + v


static func finish() -> Array:
	var total: = _pass + _fail
	print("TWPARITY_SELFTEST %d/%d" % [_pass, total])
	return [_pass, total]


static func run(env: Dictionary = {}) -> Array:
	begin()
	run_core(env)
	return finish()


# the parts that need no legacy board (corpus replay, layouts, level certificates); the runner adds the live fuzz around it
static func run_core(env: Dictionary = {}) -> void:
	var t0: = Time.get_ticks_msec()
	run_corpus(int(env.get("games_n", 500)))
	run_levels(int(env.get("levels_n", 1000)))
	print("INFO core parity (%.1f s)  %s" % [(Time.get_ticks_msec() - t0) / 1000.0, str(stats)])


# ------------------------------------------------------------------ helpers shared with the recorder / the fuzz

# one number for an id list (the list is sorted by the caller or by construction)
static func fhash(ids) -> int:
	var h: = 17
	for x in ids:
		h = (h * 31 + int(x) + 1) % 2147483629
	return h


static func _ints(a: Array) -> PackedInt32Array:
	var out: = PackedInt32Array()
	out.resize(a.size())
	for i in a.size():
		out[i] = int(a[i])
	return out


static func _bytes(a: Array) -> PackedByteArray:
	var out: = PackedByteArray()
	out.resize(a.size())
	for i in a.size():
		out[i] = int(a[i])
	return out


# the level dict of a recorded game: a payload of the legacy deal, as V10LevelGen.build would hand it to TWBoard.from_level
static func level_of(g: Dictionary) -> Dictionary:
	var flat: Array = g.pos
	var n: int = flat.size() / 3
	return {
		"code": "parity_%d" % int(g.g), "seed": int(g.g), "slots": int(g.slots), "shard": str(g.get("shard_hero", "")),
		"v10": {
			"n": n, "pos": _ints(flat), "face": _ints(g.face), "step": _ints(g.step), "gold": _bytes(g.gold), "ice": _bytes(g.ice),
			"secret": _bytes(g.sec), "shard": _bytes(g.shard), "spec": [],
		},
	}


static func positions_of(g: Dictionary) -> Array:
	var flat: Array = g.pos
	var out: = []
	for k in flat.size() / 3:
		out.append(Vector3i(int(flat[3 * k]), int(flat[3 * k + 1]), int(flat[3 * k + 2])))
	return out


static func load_games(max_n: int = 100000) -> Array:
	var out: = []
	var d: = DirAccess.open(DIR)
	if d == null:
		return out
	var names: = []
	for f in d.get_files():
		if f.begins_with("corpus_") and f.ends_with(".json"):
			names.append(f)
	names.sort()
	for f in names:
		var fa: = FileAccess.open(DIR + f, FileAccess.READ)
		if fa == null:
			continue
		var data: Variant = JSON.parse_string(fa.get_as_text())
		if typeof(data) != TYPE_DICTIONARY:
			continue
		for g in data.games:
			out.append(g)
			if out.size() >= max_n:
				return out
	return out


# the state vector of a TWBoard in the recorder's layout: [bc, tray_n, combo, cracks, max_tray, nfree, free_hash]
static func state_of(b: TWBoard) -> Array:
	var fr: = Array(b.free_tiles())
	return [b.board_count(), b.tray.size(), b.combo, b.cracks, b.max_tray, fr.size(), fhash(fr)]


static func tap_kind(ev: Array) -> int:
	if ev.is_empty():
		return K_IGNORED
	if E.has(ev, E.DENY):
		return K_DENY
	if E.has(ev, E.ICE_CRACK):
		return K_CRACK
	if E.has(ev, E.MATCH):
		return K_MATCH
	if E.has(ev, E.TRAY_FULL):
		return K_FULL
	if E.has(ev, E.TO_TRAY):
		return K_TRAY
	return K_IGNORED


# hint priority class of a tile: 1 = makes a pair with a tray tile, 2 = has a free twin, 3 = anything else
static func hint_class(b: TWBoard, t: int) -> int:
	if t < 0:
		return 0
	for x in b.tray:
		if b.face[x] == b.face[t]:
			return 1
	for o in b.free_tiles():
		if o != t and b.face[o] == b.face[t]:
			return 2
	return 3


# ------------------------------------------------------------------ A, B: the corpus

static func run_corpus(games_n: int) -> void:
	var games: = load_games(games_n)
	check("corpus: %d games present" % games_n, games.size() >= games_n, "found %d" % games.size())
	var ops_total: = 0
	var taps_total: = 0
	var layout_ok: = 0
	var games_ok: = 0
	var outcomes: = {"cleared": 0, "failed": 0, "open": 0}
	var kinds: = [0, 0, 0, 0, 0, 0]
	for g in games:
		# B: layout + deal
		var cfg: Dictionary = g.cfg
		var want: Array = TWFree.positions(cfg)
		var have: Array = positions_of(g)
		var lay: bool = want == have
		check("game %d: stored layout == TWFree.positions(cfg)" % int(g.g), lay)
		if lay:
			layout_ok += 1
		# A: the journal
		var res: = replay_game(g)
		ops_total += int(res.ops)
		taps_total += int(res.taps)
		for k in 6:
			kinds[k] += int(res.kinds[k])
		check("game %d (%s, %d tiles, %d ops): 0 divergences" % [int(g.g), str(g.code), int(g.n), int(res.ops)], res.bad.is_empty(), "; ".join(res.bad.slice(0, 3)))
		if res.bad.is_empty():
			games_ok += 1
		stat_add("hint_exact", int(res.hint_exact))
		stat_add("hint_n", int(res.hint_n))
		stat_add("pair_ties", int(res.pair_ties))
		stat_add("legacy_shuffle_odd", int(res.legacy_shuffle_odd))
		stat_add("shuffles", int(res.shuffles))
		outcomes[str(g.end)] = int(outcomes.get(str(g.end), 0)) + 1
	stats["games"] = games.size()
	stats["games_ok"] = games_ok
	stats["layout_ok"] = layout_ok
	stats["ops"] = ops_total
	stats["taps"] = taps_total
	stats["tap_kinds(deny,crack,tray,match,full,ignored)"] = kinds
	stats["outcomes"] = outcomes


static func new_result() -> Dictionary:
	return {"bad": [], "ops": 0, "taps": 0, "kinds": [0, 0, 0, 0, 0, 0], "hint_exact": 0, "hint_n": 0, "pair_ties": 0,
		"shuffles": 0, "legacy_shuffle_odd": 0}


# Replay one recorded game on TWBoard; returns {bad: [msg], ops, taps, kinds, hint_exact, hint_n, pair_ties, shuffles, legacy_shuffle_odd}
static func replay_game(g: Dictionary) -> Dictionary:
	var r: = new_result()
	var bad: Array = r.bad
	var lv: = level_of(g)
	var b: = TWBoard.from_level(lv)
	if b.n != int(g.n):
		bad.append("tile count %d vs %d" % [b.n, int(g.n)])
		return r
	var st0: = state_of(b)
	if int(st0[5]) != int(g.free0[0]) or int(st0[6]) != int(g.free0[1]):
		bad.append("initial free set differs: %s vs %s" % [str([st0[5], st0[6]]), str(g.free0)])
		return r
	var ops: Array = g.ops
	var exp: Array = g.exp
	var ended: = ""
	for k in ops.size():
		apply_op(b, ops[k], exp[k], k, r)
		if bad.size() >= 3:
			return r
		if b.cleared:
			ended = "cleared"
		elif b.failed:
			ended = "failed"
		else:
			ended = "open"
	if ended != str(g.end):
		bad.append("outcome %s vs legacy %s" % [ended, str(g.end)])
	return r


# Apply ONE journal entry to a TWBoard and compare it with what the legacy recorded (`ex`: [res, board, tray_n, combo, cracks,
# max_tray, free_n, free_hash, [tray ids]]). Divergences are appended to r.bad. Used by the corpus replay and by the live fuzz.
static func apply_op(b: TWBoard, op: Array, ex: Array, k: int, r: Dictionary) -> void:
	var bad: Array = r.bad
	var code: String = op[0]
	r.ops += 1
	var got_res: = 0
	match code:
		"t":
			r.taps += 1
			b.time = float(op[2])
			var ev: = b.tap(int(op[1]))
			got_res = tap_kind(ev)
			r.kinds[got_res] += 1
		"u":
			var ev: = b.undo()
			got_res = 0 if ev.is_empty() else 1
		"r":
			var before: = b.tray.size()
			b.return_tray(int(op[1]))
			got_res = before - b.tray.size()
		"s":
			r.shuffles += 1
			got_res = _shuffle_step(b, op[1], r)
		"v":
			got_res = _vanish_step(b, int(op[1]), op[2], r)
		"h":
			got_res = _hack_step(b, op[1], r)
		"m":
			b.moonlight()
			got_res = 0
		"i":
			var tb: = b.best_move()
			var hc: = hint_class(b, tb)
			got_res = hc
			r.hint_n += 1
			if tb == int(op[1]):
				r.hint_exact += 1
			# the class of the LEGACY pick judged on the TWBoard state must be the class of TWBoard's own pick
			var lc: = hint_class(b, int(op[1]))
			if lc != hc:
				bad.append("op %d hint: legacy tile %d class %d, TWBoard tile %d class %d" % [k, int(op[1]), lc, tb, hc])
		_:
			bad.append("op %d: unknown code %s" % [k, code])
	if got_res != int(ex[0]):
		bad.append("op %d %s %s: result %d vs legacy %d" % [k, code, str(op.slice(1, 3)), got_res, int(ex[0])])
	var st: = state_of(b)
	var names: = ["board", "tray", "combo", "cracks", "max_tray", "free_n", "free_set"]
	for q in 7:
		if int(st[q]) != int(ex[1 + q]):
			bad.append("op %d %s %s: %s %d vs legacy %d" % [k, code, str(op.slice(1, 3)), names[q], int(st[q]), int(ex[1 + q])])
	var tray_ids: = Array(b.tray)
	var exp_tray: Array = ex[8]
	var tr_ok: = tray_ids.size() == exp_tray.size()
	if tr_ok:
		for q in tray_ids.size():
			if tray_ids[q] != int(exp_tray[q]):
				tr_ok = false
	if not tr_ok:
		bad.append("op %d %s: tray %s vs legacy %s" % [k, code, str(tray_ids), str(exp_tray)])


# shuffle: the legacy deal-again is unseeded. TWBoard must (1) keep the faces of the affected tiles as a multiset, (2) keep a
# twin on the table for every tray tile, (3) touch no tile outside the legacy set; then the recorded legacy faces are applied.
static func _shuffle_step(b: TWBoard, rec: Dictionary, r: Dictionary) -> int:
	var before: = {}
	var ids: = []
	for t in b.n:
		if b.present[t] == 1 and b.shard_f[t] == 0 and b.face[t] != TWBoard.JOKER:
			ids.append(t)
			before[b.face[t]] = int(before.get(b.face[t], 0)) + 1
	var snap_face: = b.face.duplicate()
	b.shuffle()
	var after: = {}
	for t in ids:
		after[b.face[t]] = int(after.get(b.face[t], 0)) + 1
	var bad: Array = r.bad
	if before != after:
		bad.append("shuffle: TWBoard changed the face multiset")
	for t in b.n:
		if not ids.has(t) and b.face[t] != snap_face[t]:
			bad.append("shuffle: TWBoard touched tile %d outside the table set" % t)
			break
	# the tray tiles must still have a twin on the table (clearable)
	for x in b.tray:
		var has: = false
		for t in ids:
			if b.face[t] == b.face[x] and b.present[t] == 1:
				has = true
				break
		if not has and before.has(b.face[x]):
			bad.append("shuffle: tray tile %d lost its twin on the table" % x)
	# legacy deal-again: how many odd faces did the legacy leave (its known gold bug)
	var cnt: = {}
	var lf: Array = rec.face
	for t in b.n:
		if b.present[t] == 1 and b.shard_f[t] == 0:
			cnt[int(lf[t])] = int(cnt.get(int(lf[t]), 0)) + 1
	for x in b.tray:
		cnt[int(lf[x])] = int(cnt.get(int(lf[x]), 0)) + 1
	var odd: = false
	for f in cnt:
		if int(cnt[f]) % 2 == 1:
			odd = true
	if odd:
		r.legacy_shuffle_odd += 1
	# apply the recorded legacy faces (every tile of the table; the legacy touches only the table set)
	var ls: Array = rec.step
	var lg: Array = rec.gold
	for t in b.n:
		if b.alive[t] == 1:
			b.face[t] = int(lf[t])
			b.step[t] = int(ls[t])
			b.gold[t] = int(lg[t])
	return 0


# the ult "vanish k pairs" (TrayBoard.auto_pairs): the pair list must contain the legacy pick and the pick must be in the first
# class of ties (same lowest step); the legacy pick is then removed on TWBoard
static func _vanish_step(b: TWBoard, k: int, picks: Array, r: Dictionary) -> int:
	var done: = 0
	for q in picks.size():
		var pr: Array = picks[q]
		var ps: = b.pairs_on_board()
		if ps.is_empty():
			r.bad.append("vanish: TWBoard has no pair, legacy removed %s" % str(pr))
			return done
		var first: Array = ps[0]
		var a: int = int(pr[0])
		var c: int = int(pr[1])
		var found: = false
		for p in ps:
			if (p[0] == a and p[1] == c) or (p[0] == c and p[1] == a):
				found = true
		if not found:
			r.bad.append("vanish: legacy pair %s is not a pair on TWBoard" % str(pr))
			return done
		var step_first: = mini(b.step[first[0]], b.step[first[1]])
		var step_pick: = mini(b.step[a], b.step[c])
		if step_first != step_pick:
			r.bad.append("vanish: legacy pair %s has lowest step %d, TWBoard's first pair %d" % [str(pr), step_pick, step_first])
			return done
		if not ((first[0] == a and first[1] == c) or (first[0] == c and first[1] == a)):
			r.pair_ties += 1
		var ev: Array = []
		b._vanish(a, c, ev)
		done += 1
	if not picks.is_empty():
		var ev2: Array = []
		b._check_clear(ev2)
	else:
		# the legacy found nothing to vanish: TWBoard must find nothing either
		if not b.pairs_on_board().is_empty():
			r.bad.append("vanish: legacy found no pair, TWBoard has %d" % b.pairs_on_board().size())
	return done


static func _hack_step(b: TWBoard, pick: Array, r: Dictionary) -> int:
	var ps: = b.pairs_on_board()
	if pick.is_empty():
		if not ps.is_empty():
			r.bad.append("hack: legacy found no pair, TWBoard has %d" % ps.size())
		return 0
	if ps.is_empty():
		r.bad.append("hack: TWBoard has no pair, legacy removed %s" % str(pick))
		return 0
	var a: int = int(pick[0])
	var c: int = int(pick[1])
	var found: = false
	for p in ps:
		if (p[0] == a and p[1] == c) or (p[0] == c and p[1] == a):
			found = true
	if not found:
		r.bad.append("hack: legacy pair %s is not a pair on TWBoard" % str(pick))
		return 0
	var last: Array = ps[ps.size() - 1]
	if mini(b.step[last[0]], b.step[last[1]]) != mini(b.step[a], b.step[c]):
		r.bad.append("hack: legacy pair %s step differs from TWBoard's deepest pair" % str(pick))
	if not ((last[0] == a and last[1] == c) or (last[0] == c and last[1] == a)):
		r.pair_ties += 1
	var ev: Array = []
	b._vanish(a, c, ev)
	b._check_clear(ev)
	return 1


# ------------------------------------------------------------------ C: certificates of the Path levels on TWBoard

static func run_levels(n_levels: int) -> void:
	var sim: = V10LevelSim.new()
	var ok: = 0
	var tiles: = 0
	var t0: = Time.get_ticks_msec()
	for i in n_levels:
		var lv: Dictionary = V10LevelGen.build(i, -1, sim)
		var b: = TWBoard.from_level(lv)
		var vc: = b.verify_certificate()
		var same: bool = b.cert == lv.v10.cert and b.n == int(lv.v10.n)
		check("level %d: generator certificate replays on TWBoard" % i, vc.is_empty() and same, str(vc))
		if vc.is_empty() and same:
			ok += 1
		tiles += b.n
	stats["level_certs_ok"] = ok
	stats["level_certs_n"] = n_levels
	stats["level_tiles"] = tiles
	stats["level_cert_s"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1)
