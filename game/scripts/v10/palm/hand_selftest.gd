extends Node

# Selftest of «Чтение руки» (spec 0.10 R4). Standalone runner scene (main.gd untouched):
#   flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/palm/hand_selftest.tscn -- --hand_selftest=1
# Other flags:
#   --hand_gen=365          write data/hands.json (365 days from V10HandGen.ORIGIN_IDX) and exit
#   --hand_probe=N          print N generated days (--hand_from=offset)
#   --hand_real=N           real V10HandBoard instances to check (default: every day of the table)
# Output: "HAND_SELFTEST ok/total" (+ per-group lines); exit 0 only at 100 %.
#
# The uniqueness proof is re-done by an INDEPENDENT brute force written here (own complete-hand test, own
# enumeration of the closed positions), not by V8Mj or V10HandGen.

const U: = preload("res://scripts/v10/palm/hand_util.gd")
const GEN: = preload("res://scripts/v10/palm/hand_gen.gd")
const ST: = preload("res://scripts/v10/palm/hand_state.gd")
const T: = preload("res://scripts/v10/palm/hand_text.gd")
const H: = preload("res://scripts/v10/palm/hand.gd")
const L: = preload("res://scripts/v10/palm/hand_lessons.gd")
const BOARD: = preload("res://scripts/v10/palm/hand_board.gd")

const FILES: = ["hand_util.gd", "hand_gen.gd", "hand_state.gd", "hand_text.gd", "hand.gd", "hand_lessons.gd", "hand_board.gd"]

var ok: = 0
var total: = 0
var g_ok: = {}
var g_total: = {}
var cur: = ""
var fails: = []
var args: = {}
var table: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv: = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	if args.has("hand_gen"):
		var st: = GEN.write_table(int(args.hand_gen))
		print("HAND_GEN days=%d fails=%s forms=%s ms=%d -> %s" % [st.days, str(st.fails), str(st.forms), st.ms, st.path])
		get_tree().quit(0 if (st.fails as Array).is_empty() else 1)
		return
	if args.has("hand_probe"):
		_probe(int(args.hand_probe))
		get_tree().quit(0)
		return
	if args.get("hand_selftest", "0") != "1":
		print("HAND_SELFTEST: pass --hand_selftest=1")
		get_tree().quit(2)
		return
	var t0: = Time.get_ticks_msec()
	_isolate()
	_data()
	_unique()
	await _boards()
	_dim()
	_mult()
	_days()
	_state()
	_texts()
	_lessons()
	_misc()
	_restore_env()
	for g in g_total:
		print("  %-8s %d/%d" % [g, int(g_ok.get(g, 0)), int(g_total[g])])
	for f in fails.slice(0, 40):
		print("  FAIL ", f)
	print("HAND_SELFTEST %d/%d (%.1f s)" % [ok, total, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(0 if ok == total and total > 0 else 1)


func check(cond: bool, what: String) -> void:
	total += 1
	g_total[cur] = int(g_total.get(cur, 0)) + 1
	if cond:
		ok += 1
		g_ok[cur] = int(g_ok.get(cur, 0)) + 1
	else:
		fails.append("[%s] %s" % [cur, what])


# ================================================================== environment

var _meta: = {}
var _sink_log: Array = []


func _isolate() -> void:
	ST._test_S = {"unlocked": 30}
	_meta = {}
	V10Meta.bind(_meta)
	V10Meta.set_tz(0)
	U.sink = func(kind, value, src): _sink_log.append({"kind": kind, "value": value, "src": src})


func _restore_env() -> void:
	ST._test_S = null
	U.sink = Callable()
	V10Meta.clear_now()
	V10Meta.clear_tz()
	V10Meta.unbind()
	GEN.use_file = true


func _unix(key: String, h: int, m: int = 0) -> int:
	return int(Time.get_unix_time_from_datetime_string(key + "T00:00:00")) + h * 3600 + m * 60


# ================================================================== independent brute force

func _c14_complete(c: Array) -> bool:
	var pairs: = 0
	var only_pairs: = true
	for k in 34:
		if c[k] == 2:
			pairs += 1
		elif c[k] != 0:
			only_pairs = false
	if only_pairs and pairs == 7:
		return true
	var orphans: = [0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33]
	var all13: = true
	var n13: = 0
	for k in 34:
		if k in orphans:
			if c[k] == 0:
				all13 = false
			n13 += c[k]
		elif c[k] != 0:
			all13 = false
	if all13 and n13 == 14:
		return true
	for p in 34:
		if c[p] >= 2:
			c[p] -= 2
			var good: = _melds(c, 0)
			c[p] += 2
			if good:
				return true
	return false


func _melds(c: Array, i: int) -> bool:
	while i < 34 and c[i] == 0:
		i += 1
	if i >= 34:
		return true
	if c[i] >= 3:
		c[i] -= 3
		var a: = _melds(c, i)
		c[i] += 3
		if a:
			return true
	if i < 27 and i % 9 <= 6 and c[i + 1] > 0 and c[i + 2] > 0:
		c[i] -= 1
		c[i + 1] -= 1
		c[i + 2] -= 1
		var b: = _melds(c, i)
		c[i] += 1
		c[i + 1] += 1
		c[i + 2] += 1
		if b:
			return true
	return false


func _cnt(tiles: Array) -> Array:
	var c: = []
	c.resize(34)
	c.fill(0)
	for t in tiles:
		c[int(t)] += 1
	return c


# {tenpai: bool (some tile completes it, copies aside), waits: those with a copy left (hand + board < 4)}
func _bf_waits(c: Array, board: Array) -> Dictionary:
	var any: = false
	var w: = []
	for k in 34:
		c[k] += 1
		var done: = _c14_complete(c)
		c[k] -= 1
		if done:
			any = true
			if c[k] + int(board[k]) < 4:
				w.append(k)
	return {"tenpai": any, "waits": w}


# every filling of the closed positions the player cannot rule out at the fully revealed state
func _bf_unique(hand: Array, sleeve: Array, known_absent: Array, board: Array, waits: Array) -> Dictionary:
	var open_k: = {}
	for i in 13:
		if not (i in sleeve):
			open_k[int(hand[i])] = true
	var res: = {"fill": 0, "tenpai": 0, "bad": 0, "true_seen": false}
	var cur_h: = hand.duplicate()
	_bf_fill(0, sleeve, cur_h, open_k, known_absent, board, waits, res, hand)
	return res


func _bf_fill(j: int, sleeve: Array, cur_h: Array, open_k: Dictionary, absent: Array, board: Array, waits: Array, res: Dictionary, truth: Array) -> void:
	if j == sleeve.size():
		# the whole row must read sorted, as the HUD shows it
		for i in 12:
			if int(cur_h[i]) > int(cur_h[i + 1]):
				return
		var c: = _cnt(cur_h)
		for k in 34:
			if c[k] + int(board[k]) > 4:
				return
		res.fill += 1
		if cur_h == truth:
			res.true_seen = true
		var bw: = _bf_waits(c, board)
		if not bw.tenpai:
			return
		res.tenpai += 1
		var a: Array = bw.waits
		var b: = waits.duplicate()
		a.sort()
		b.sort()
		if a != b:
			res.bad += 1
		return
	var p: int = sleeve[j]
	var lo: = int(cur_h[p - 1]) if p > 0 else 0
	for k in range(lo, 34):
		if open_k.has(k) or k in absent:
			continue
		cur_h[p] = k
		_bf_fill(j + 1, sleeve, cur_h, open_k, absent, board, waits, res, truth)
	cur_h[p] = truth[p]


func _board_of(e: Dictionary) -> Array:
	var b: = []
	b.resize(34)
	b.fill(0)
	for k in e.pairs:
		b[int(k)] += 2
	return b


# ================================================================== the table

func _data() -> void:
	cur = "data"
	var t: = GEN.load_table()
	check(not t.is_empty(), "data/hands.json present with gen_ver %d (run --hand_gen=365)" % GEN.GEN_VER)
	if t.is_empty():
		return
	check(int(t.get("days", 0)) == 365 and (t.entries as Array).size() == 365, "365 entries")
	check(int(t.origin_idx) == V10Meta.day_index(GEN.ORIGIN_KEY) and U.weekday(int(t.origin_idx)) == 0, "origin is a Monday, index matches the key")
	for i in (t.entries as Array).size():
		table.append(GEN.norm(t.entries[i]))
	var bad: = {}
	var forms: = {}
	var wd_forms: = {}
	var by_wd: = {}
	for e in table:
		var d: int = e.i
		var c: = _cnt(e.hand)
		var b: = _board_of(e)
		var why: = ""
		if d != int(t.origin_idx) + table.find(e):
			why = "index"
		elif int(e.wd) != U.weekday(d):
			why = "weekday"
		elif (e.hand as Array).size() != 13:
			why = "13 cards"
		else:
			var srt: Array = (e.hand as Array).duplicate()
			srt.sort()
			if srt != e.hand:
				why = "sorted"
		if why == "":
			for k in 34:
				if c[k] + b[k] > 4:
					why = "copies %d" % k
		if why == "":
			var mw: = V8Mj.waits(c.duplicate())
			var ws: Array = e.waits
			if V8Mj.shanten(c.duplicate()) != 0:
				why = "not tenpai"
			elif ws.is_empty() or ws.size() > 3:
				why = "1-3 waits"
			elif mw != ws:
				why = "waits differ from V8Mj.waits %s" % str(mw)
			elif GEN.real_waits(c.duplicate(), b) != ws:
				why = "a wait is karaten"
		if why == "":
			for w in e.waits:
				if b[int(w)] > 0:
					why = "wait %d on the board" % int(w)
		if why == "":
			var sl: Array = e.sleeve
			if sl.size() < 1 or sl.size() > 3:
				why = "sleeve 1-3"
			for k in 34:
				var in_sl: = 0
				for p in sl:
					if int(e.hand[p]) == k:
						in_sl += 1
				if in_sl > 0 and in_sl != c[k]:
					why = "sleeve holds part of a kind"
				if c[k] >= 3 and in_sl != c[k]:
					why = "three of a kind not in the sleeve"
				if c[k] > 0 and k in e.waits and in_sl == 0:
					why = "a wait she holds is open"
				if c[k] > 0 and in_sl == 0 and b[k] != 2:
					why = "open kind %d needs exactly one pair on the board" % k
				if c[k] > 0 and in_sl > 0 and b[k] != 0:
					why = "sleeve kind on the board"
				if c[k] == 0 and b[k] > 0 and not (k in e.decoys):
					why = "board kind not explained"
		if why == "":
			for k in e.decoys:
				if c[k] > 0 or k in e.waits:
					why = "decoy in hand / a wait"
			for k in e.doubles:
				if b[int(k)] != 4:
					why = "double is not 4 copies"
			var absent: = 0
			for k in 34:
				if c[k] == 0 and not (k in e.waits):
					absent += 1
			if float((e.decoys as Array).size()) / float(absent) < GEN.COVER_MIN - 0.001:
				why = "decoys cover only %d/%d" % [(e.decoys as Array).size(), absent]
		if why == "":
			var np: = (e.pairs as Array).size()
			if np < GEN.PAIRS_MIN or np > GEN.PAIRS_TARGET_MAX + 2:
				why = "board %d pairs" % np
		if why != "":
			bad[d] = why
		forms[e.form] = int(forms.get(e.form, 0)) + 1
		if not wd_forms.has(e.wd):
			wd_forms[e.wd] = {}
		wd_forms[e.wd][e.form] = true
		if not by_wd.has(e.wd):
			by_wd[e.wd] = []
		by_wd[e.wd].append(int(e.sleeve_n) + 2 * int(e.unc_reach) + (int(e.alts) - 1))
	check(bad.is_empty(), "365 days: 13 sorted cards, tenpai, 1-3 waits (= V8Mj.waits, none karaten), waits never on the board, sleeve 1-3 whole kinds incl. triplets and held waits, one pair per open kind, copies ≤ 4, decoys ≥ %.2f of the absent kinds, %d-%d pairs: %s" % [GEN.COVER_MIN, GEN.PAIRS_MIN, GEN.PAIRS_TARGET_MAX + 2, str(_first(bad, 4))])
	var nd: = 0
	for e in table:
		if not (e.doubles as Array).is_empty():
			nd += 1
	check(nd >= 300, "some decoys come twice (all 4 copies visible) on most days: %d/365" % nd)
	for f in ["ryanmen", "kanchan", "penchan", "tanki", "nobetan", "sanmen", "chiitoi"]:
		check(int(forms.get(f, 0)) >= 5, "form %s appears over the year (%d)" % [f, int(forms.get(f, 0))])
	print("  forms over the year: ", forms)
	var wd_ok: = true
	for wd in 7:
		if (wd_forms.get(wd, {}) as Dictionary).size() < 2:
			wd_ok = false
	check(wd_ok, "every weekday sees at least 2 forms")
	var avg: = []
	for wd in 7:
		var s: = 0.0
		for x in by_wd.get(wd, []):
			s += float(x)
		avg.append(s / maxf(1.0, float((by_wd.get(wd, []) as Array).size())))
	print("  difficulty by weekday (sleeve + 2×uncovered in reach + extra fillings): ", avg.map(func(x): return snappedf(x, 0.01)))
	check(avg[0] < avg[3] and avg[3] < avg[6] and avg[0] <= avg[1] + 0.3 and avg[5] <= avg[6] + 0.3, "difficulty rises over the week (Mon < Thu < Sun)")
	# determinism: one regenerated day per weekday equals the file
	var diff: = []
	for i in [0, 8, 16, 24, 32, 40, 48, 200]:
		var g: = GEN.norm(JSON.parse_string(JSON.stringify(GEN.generate(GEN.ORIGIN_IDX + i))))
		var f: Dictionary = table[i]
		for k in ["hand", "sleeve", "waits", "pairs", "deal_seed", "layout", "decoys", "doubles"]:
			if str(g.get(k)) != str(f.get(k)):
				diff.append("%d %s: %s vs %s" % [i, k, str(g.get(k)), str(f.get(k))])
	check(diff.is_empty(), "generation is deterministic (8 regenerated days = the file): %s" % str(diff.slice(0, 3)))
	# runtime lookup picks the file entry by day index
	var e0: = GEN.entry_for(GEN.ORIGIN_IDX + 100)
	check(str(e0.hand) == str(table[100].hand) and int(e0.i) == GEN.ORIGIN_IDX + 100, "entry_for(day) reads the file by day index")


func _first(d: Dictionary, n: int) -> Dictionary:
	var o: = {}
	for k in d:
		if o.size() >= n:
			break
		o[k] = d[k]
	return o


# ================================================================== uniqueness (independent)

func _unique() -> void:
	cur = "unique"
	var bad: = {}
	var multi: = 0
	for e in table:
		var b: = _board_of(e)
		var r: = _bf_unique(e.hand, e.sleeve, e.decoys, b, e.waits)
		if not r.true_seen:
			bad[e.i] = "true hand not among the fillings"
		elif r.bad > 0:
			bad[e.i] = "%d fillings with other waits" % r.bad
		elif r.tenpai < 1:
			bad[e.i] = "no tenpai filling"
		if r.tenpai > 1:
			multi += 1
		# the generator's own count agrees
		var g: = GEN.check_unique(e.hand, e.sleeve, e.decoys, b, e.waits)
		if not g.ok or int(g.tenpai) != int(r.tenpai):
			bad[e.i] = "generator says ok=%s tenpai=%d, brute force tenpai=%d" % [g.ok, g.tenpai, r.tenpai]
	check(bad.is_empty(), "365 days: every filling of the closed cards consistent with sorted order, «Не у неё» and copy limits that leaves her tenpai has exactly her waits (independent brute force): %s" % str(_first(bad, 4)))
	print("  days with more than one tenpai filling (the reading needs the waits, not the cards): %d" % multi)
	# the brute force is not blind: a hand made ambiguous on purpose is caught
	# 1-2-3 4-5-6 7-8-9 ман, 1-1 пин, 4-5 пин waits 3 and 6 пин; with 4-5 пин closed and nothing known absent,
	# 2-3 пин (waits 1 and 4 пин) reads the same row
	var none: Array = []
	var amb: = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 9, 12, 13]
	var r0: = _bf_unique(amb, [11, 12], none, GEN.zeros(), [11, 14])
	var g0: = GEN.check_unique(amb, [11, 12], none, GEN.zeros(), [11, 14])
	check(r0.bad > 0 and r0.true_seen and not g0.ok and int(g0.tenpai) == int(r0.tenpai), "brute force and generator both catch an ambiguous reading (4-5 пин closed, nothing known absent): %d bad fillings" % r0.bad)
	# real_waits(c, []) == V8Mj.waits(c) on every hand of the year and on the brute force's own waits
	var mism: = 0
	for x in table:
		var c: = _cnt(x.hand)
		if GEN.real_waits(c.duplicate()) != V8Mj.waits(c.duplicate()) or _bf_waits(c.duplicate(), GEN.zeros()).waits != V8Mj.waits(c.duplicate()):
			mism += 1
	check(mism == 0, "three wait computations agree on 365 hands (generator, V8Mj, brute force)")


# ================================================================== boards

func _boards() -> void:
	cur = "board"
	var bad_model: = []
	for e in table:
		var m: = GEN.deal(GEN.board_cfg(e))
		if (m.pos as Array).size() != 2 * (e.pairs as Array).size():
			bad_model.append("%d size" % e.i)
		elif not GEN.step_order_ok(m):
			bad_model.append("%d steps" % e.i)
		else:
			var cnt: = {}
			for f in m.face:
				cnt[int(f)] = int(cnt.get(int(f), 0)) + 1
			var b: = _board_of(e)
			for k in 34:
				if int(cnt.get(k, 0)) != b[k]:
					bad_model.append("%d faces" % e.i)
					break
	check(bad_model.is_empty(), "365 board models: layout of exactly the planned pairs, faces = the plan, solvable by the step order: %s" % str(bad_model.slice(0, 4)))
	# the real V10HandBoard: same layout, same free rule, same faces, solvable, riichi art, no clarity marks
	var n_real: = int(args.get("hand_real", str(table.size())))
	var bad: = []
	var checked: = 0
	for idx in mini(n_real, table.size()):
		var e: Dictionary = table[idx]
		var cfg: = GEN.board_cfg(e)
		var m: = GEN.deal(cfg)
		var tb: = BOARD.new()
		add_child(tb)
		tb.setup(cfg)
		checked += 1
		var why: = ""
		if tb.tiles.size() != (m.pos as Array).size():
			why = "tile count"
		else:
			for t in tb.tiles:
				var j: = (m.pos as Array).find(Vector3i(t.gx, t.gy, t.gz))
				if j < 0 or int(m.face[j]) != t.face or int(m.step[j]) != t.step:
					why = "face/step differs from the model"
					break
				if t.gold or t.ice > 0 or t.shard != "" or t.secret:
					why = "special tile"
					break
				if t.face_spr.texture != BOARD.face_tex(t.face) or t.get_node_or_null("V10Marks") != null:
					why = "face art"
					break
		if why == "":
			# clear by the step order on the real board, with its own free rule
			var order: = tb.tiles.duplicate()
			order.sort_custom(func(a, b): return a.step < b.step)
			var i: = 0
			while i < order.size() and why == "":
				var a: Tile = order[i]
				var b: Tile = order[i + 1]
				if a.face != b.face:
					why = "pair faces"
				elif tb.is_free(a):
					a.alive = false
					if not tb.is_free(b):
						why = "step %d blocked" % a.step
				elif tb.is_free(b):
					b.alive = false
					if not tb.is_free(a):
						why = "step %d blocked" % a.step
				else:
					why = "step %d blocked" % a.step
				a.alive = false
				b.alive = false
				i += 2
		if why != "":
			bad.append("%d %s" % [e.i, why])
		tb.queue_free()
		if idx % 12 == 11:
			await get_tree().process_frame
	check(bad.is_empty() and checked == mini(n_real, table.size()), "%d real V10HandBoard deals = the model, riichi faces, no specials, cleared by the step order: %s" % [checked, str(bad.slice(0, 4))])
	# a real playthrough: taps through TrayBoard.tap, kind_taken feeds the session to the fully revealed state
	for idx in [3, 6]:
		await _play(table[idx])


func _play(e: Dictionary) -> void:
	var tb: = BOARD.new()
	add_child(tb)
	var slots: Array[Vector2] = []
	for i in BOARD.SLOTS_HAND:
		slots.append(Vector2(100 + i * 90, 1100))
	tb.slot_pos = slots
	tb.slots = BOARD.SLOTS_HAND
	tb.setup(GEN.board_cfg(e))
	var s: = H.for_entry(e, "rin")
	var got: = []
	tb.kind_taken.connect(func(k): got.append(k); s.reveal(k))
	var state: = {"done": false, "failed": false}
	tb.cleared.connect(func(): state.done = true)
	tb.failed.connect(func(): state.failed = true)
	tb.input_on = true
	Engine.time_scale = 16.0
	var guard: = 0
	while not state.done and not state.failed and guard < 400:
		guard += 1
		var t: Tile = tb.solver_move()
		if t and tb.tray.size() < tb.slots - 1:
			tb.tap(t)
		await get_tree().create_timer(0.05).timeout
	for i in 20:
		if state.done:
			break
		await get_tree().create_timer(0.05).timeout
	Engine.time_scale = 1.0
	var plan: Array = (e.pairs as Array).duplicate()
	plan.sort()
	got.sort()
	check(state.done and not state.failed, "day %d: the real board is cleared by taps (TrayBoard.tap, tray ≤ %d)" % [e.i, BOARD.SLOTS_HAND])
	check(got == plan, "day %d: kind_taken reports every planned pair once" % e.i)
	var strip_ok: = true
	for k in e.decoys:
		if not (k in s.strip):
			strip_ok = false
	check(s.hidden_count() == (e.sleeve as Array).size() and strip_ok and s.strip.size() == (e.decoys as Array).size(), "day %d: fully revealed — only the sleeve stays closed, every decoy is «Не у неё»" % e.i)
	tb.queue_free()


# ================================================================== the shutter

func _dim() -> void:
	cur = "dim"
	var bad: = []
	for e in table:
		var s: = H.for_entry(e)
		var b: = _board_of(e)
		var steps: Array = (e.pairs as Array).duplicate()
		var r: = U.rng(int(e.i), "selftest-dim")
		U.shuffle(steps, r)
		var states: = [0, steps.size() / 2, steps.size()]
		var done_n: = 0
		for target in states:
			while done_n < target:
				s.reveal(int(steps[done_n]))
				done_n += 1
			var rows: = s.shutter()
			if rows.size() != 34:
				bad.append("%d rows" % e.i)
				break
			for k in 34:
				var seen: int = int(b[k])
				for i in 13:
					if s.is_open_pos(i) and int(e.hand[i]) == k:
						seen += 1
				var should: bool = seen >= 4
				if bool(rows[k].dim) != should or s.impossible(k) != should:
					bad.append("%d kind %d after %d pairs" % [e.i, k, done_n])
				if bool(rows[k].dim) and k in e.waits:
					bad.append("%d dims a wait" % e.i)
		for k in e.doubles:
			if not H.for_entry(e).impossible(int(k)):
				bad.append("%d double not dim at start" % e.i)
	check(bad.is_empty(), "365 days × 3 states: a kind is dimmed exactly when its 4 copies are visible (table + flipped cards); waits never; doubles from the start: %s" % str(bad.slice(0, 4)))
	# flips and the strip
	var e: Dictionary = table[10]
	var s: = H.for_entry(e)
	var k_open: int = e.open[0]
	var r1: = s.reveal(k_open)
	var all_k: = true
	for i in 13:
		if int(e.hand[i]) == k_open and not s.is_open_pos(i):
			all_k = false
	check(r1.in_hand and all_k and not r1.strip and (r1.positions as Array).size() > 0, "a pair of a kind she holds flips every copy of it")
	var r2: = s.reveal(int(e.decoys[0]))
	check(not r2.in_hand and r2.strip and int(e.decoys[0]) in s.strip and (r2.positions as Array).is_empty(), "a pair she does not hold goes to «Не у неё»")
	for k in e.pairs:
		s.reveal(int(k))
	var sl_closed: = true
	for p in e.sleeve:
		if s.is_open_pos(int(p)):
			sl_closed = false
	check(sl_closed and s.hidden_count() == (e.sleeve as Array).size(), "the sleeve never opens")


# ================================================================== boldness

func _mult() -> void:
	cur = "mult"
	var m: = {}
	for h in [13, 8, 7, 6, 5, 4, 3, 2, 1, 0]:
		m[h] = ST.mult_for(h)
	check(m[13] == 3 and m[8] == 3 and m[7] == 3, "≥ 7 closed: ×3 (boundary 7)")
	check(m[6] == 2 and m[5] == 2 and m[4] == 2, "4–6 closed: ×2 (boundary 4)")
	check(m[3] == 1 and m[1] == 1 and m[0] == 1, "fewer than 4 closed: ×1")
	check(ST.gems_for(true, 1) == 10 and ST.gems_for(true, 2) == 20 and ST.gems_for(true, 3) == 30 and ST.gems_for(false, 3) == 5 and ST.gems_for(false, 1) == 5, "crystals: right 10/20/30, wrong 5")
	# the session's multiplier follows the closed count across the boundaries 7 and 4
	var e: Dictionary = table[0]
	for x in table:
		if (x.sleeve as Array).size() <= 3:
			e = x
			break
	var s: = H.for_entry(e)
	var seen: = {}
	seen[s.hidden_count()] = s.mult()
	for k in e.open:
		s.reveal(int(k))
		seen[s.hidden_count()] = s.mult()
	var walk_ok: = true
	for h in seen:
		if int(seen[h]) != ST.mult_for(int(h)):
			walk_ok = false
	check(walk_ok and seen.has(13) and int(seen[13]) == 3, "the session's boldness follows the closed count while pairs are taken: %s" % str(seen))


# ================================================================== one guess a day

func _guess_day(key: String, h: int, m: = 0, right: = true) -> Dictionary:
	V10Meta.set_now(_unix(key, h, m))
	var s: = H.today()
	var k: int = s.waits[0] if right else _wrong(s)
	return s.guess(k)


func _wrong(s) -> int:
	for k in 34:
		if not (k in s.waits):
			return k
	return 0


func _days() -> void:
	cur = "day"
	ST._test_S = {"unlocked": 30}
	_meta.clear()
	V10Meta.bind(_meta)
	_sink_log.clear()
	V10Meta.set_now(_unix("2026-11-24", 10))
	var s: = H.today()
	check(s.key == "2026-11-24" and s.status().state == "open" and s.can_guess(), "a new day is open")
	var r: = s.guess(s.waits[0])
	check(r.ok and r.correct, "the guess is accepted")
	var r2: = s.guess(s.waits[0])
	check(not r2.ok and r2.reason == "done", "a second guess in the same session is refused")
	var s2: = H.today()
	check(s2.status().state == "done" and not s2.can_guess() and not s2.guess(s2.waits[0]).ok, "a second guess the same day (new session) is refused")
	check(bool(s2.result.get("restored", false)) and s2.result.correct, "the played day restores its verdict")
	V10Meta.set_now(_unix("2026-11-25", 3, 59))
	check(H.today().key == "2026-11-24" and not H.today().can_guess(), "03:59 is still the played day")
	V10Meta.set_now(_unix("2026-11-25", 4, 0))
	var s3: = H.today()
	check(s3.key == "2026-11-25" and s3.can_guess(), "04:00 phone time opens the next day")
	check(s3.guess(_wrong(s3)).ok, "the next day's guess is accepted")
	V10Meta.tick()
	# clock moved back a day: the meta key is monotonic and the played day stays played
	V10Meta.set_now(_unix("2026-11-24", 12))
	check(not V10Meta.clock_ok(), "moving the clock back is seen by V10Meta.clock_ok()")
	var s4: = H.today()
	check(s4.key == "2026-11-25" and not s4.can_guess(), "clock back with clock_ok() false: no day reopens")
	# even without the meta state (a fresh install of the meta key, the unclamped raw day)
	V10Meta.bind({})
	V10Meta.set_now(_unix("2026-11-24", 12))
	var s5: = H.today()
	check(s5.key == "2026-11-24" and not s5.can_guess() and s5.status().state == "done", "clock back below the last played day (unbound meta): still played")
	V10Meta.set_now(_unix("2026-11-23", 23))
	check(not H.today().can_guess(), "a day before any played day is never opened")
	# clock forward: a later day can be met early — once
	V10Meta.bind(_meta)
	V10Meta.set_now(_unix("2026-11-27", 10))
	var s6: = H.today()
	check(s6.key == "2026-11-27" and s6.can_guess() and s6.guess(s6.waits[0]).ok, "clock forward: the later day plays once")
	V10Meta.tick()
	V10Meta.set_now(_unix("2026-11-26", 10))
	check(not H.today().can_guess(), "back from the forward jump: no replay (meta clamps to the played day)")
	V10Meta.bind({})
	V10Meta.set_now(_unix("2026-11-26", 10))
	check(not H.today().can_guess(), "back from the forward jump, unbound meta: no replay")
	V10Meta.bind(_meta)
	# locked below L30
	ST._test_S = {"unlocked": 29}
	V10Meta.set_now(_unix("2026-12-01", 10))
	var s7: = H.today()
	check(s7.status().state == "locked" and not s7.guess(0).ok and ST.lock_text() == "Откроется на уровне 30", "closed before L30 with «Откроется на уровне 30»")
	ST._test_S = {"unlocked": 30}
	check(ST.is_open(), "open from L30")


# ================================================================== save, rewards, streak, cosmetics

func _state() -> void:
	cur = "state"
	ST._test_S = {"unlocked": 30}
	_meta.clear()
	V10Meta.bind(_meta)
	_sink_log.clear()
	var r: = _guess_day("2026-12-07", 10)
	var hid: int = r.hidden
	check(r.ok and r.correct and r.gems == ST.gems_for(true, ST.mult_for(hid)) and r.mult == ST.mult_for(hid), "a right guess pays 10 × boldness")
	var got_g: = 0
	var got_a: = {}
	for x in _sink_log:
		if x.kind == "gems":
			got_g += int(x.value)
		if x.kind == "aff":
			got_a.merge(x.value)
			check(String(x.src) in V10Bond.SOFT, "affection goes as a soft V10Bond source (%s)" % x.src)
	check(got_g == r.gems and int(got_a.get(r.hero, 0)) == 2, "rewards applied once through V10HandUtil.grant: %d crystals, +2 affection to %s" % [got_g, r.hero])
	_sink_log.clear()
	var w: = _guess_day("2026-12-08", 10, 0, false)
	check(w.ok and not w.correct and w.gems == 5, "a wrong guess pays 5 crystals")
	check(int(ST.st().streak) == 0, "a wrong guess ends the streak")
	for i in 4:
		_guess_day(U.key_of_index(V10Meta.day_index("2026-12-09") + i), 10)
	check(int(ST.st().streak) == 4 and int(ST.st().best_streak) == 4, "streak counts right guesses in a row")
	check(int(ST.st().played) == 6 and int(ST.st().school) == 6 and ST.school_on(), "the first 7 played days are «С подсказкой»")
	_guess_day("2026-12-13", 10)
	check(int(ST.st().school) == 7 and not ST.school_on(), "from the 8th played day the hint week is over")
	check(H.today().school == false, "a session after the hint week has school = false")
	# 30 right guesses → frame + title, once
	ST.st().total_correct = 29
	_sink_log.clear()
	var r30: = _guess_day("2026-12-14", 10)
	var cos: = []
	for x in _sink_log:
		if x.kind == "cos":
			cos.append(x.value)
	check(r30.cos_new == ["fr_palm", "t_palm"] and cos == ["fr_palm", "t_palm"], "the 30th right guess unlocks «Читающая руки» and the title")
	var r31: = _guess_day("2026-12-15", 10)
	check((r31.cos_new as Array).is_empty(), "cosmetics are granted once")
	var pc: = U.cls("V10ProfileCos")
	check(pc != null and bool(pc.call("has", "fr_palm", "frame")) and bool(pc.call("has", "t_palm", "title")), "V10ProfileCos knows fr_palm / t_palm")
	check(ST.register_cos().is_empty(), "register_cos() adds nothing when the profile lane has them")
	for e2 in ST.cos_defs():
		if pc:
			check(String(pc.call("check_entry", e2.merged({"sim_ok": false, "price": 0}))) == "", "cos def %s passes V10ProfileCos.check_entry" % e2.id)
	# the day's progress survives leaving the screen
	V10Meta.set_now(_unix("2026-12-20", 10))
	var s: = H.today()
	var k0: int = s.entry.open[0]
	s.reveal(k0)
	s.reveal(int(s.entry.decoys[0]))
	var back: = H.today()
	check(back.hidden_count() == s.hidden_count() and back.strip == s.strip, "pairs taken today are restored on re-entry")
	back.close_table()
	var again: = H.today()
	check(again.closed and again.can_guess() and again.reveal(int(s.entry.decoys[1])).hidden == again.hidden_count() and not (int(s.entry.decoys[1]) in again.strip), "«Стол закрыт» persists for the day, no reveals after it, the guess stays available")
	check(again.guess(again.waits[0]).ok, "the guess works after the table closed")
	# repair of a broken save
	ST._test_S = {"unlocked": 30, "v10_hand": {"day": 5, "done": "x", "kind": 99, "mult": 7, "streak": -3, "today": [], "lessons": {"1": 99}, "cos": ["evil", "fr_palm"], "hist": 3}}
	var d: = ST.st()
	check(d.day == "" and d.done == false and d.kind == 33 and d.mult == 3 and d.streak == 0 and d.today is Dictionary and int(d.lessons["1"]) == 7 and d.cos == ["fr_palm"] and d.hist is Array, "a broken save is repaired in place")
	var d2: = ST.defaults()
	for k in ["day", "done", "correct", "kind", "hidden_at_guess", "streak", "total_correct", "school"]:
		check(d2.has(k), "S.v10_hand has %s" % k)
	ST._test_S = {"unlocked": 30}


# ================================================================== words

func _texts() -> void:
	cur = "text"
	var all: Array = T.all_strings() + L.all_strings()
	all.append_array([ST.lock_text(), ST.intro_line("mc"), ST.intro_line("nova"), ST.intro_line("zlata")])
	for f in GEN.FORM_TITLE:
		all.append(String(GEN.FORM_TITLE[f]))
	for e2 in ST.cos_defs():
		all.append(String(e2.name))
		all.append(String(e2.src.hint))
	var shares: = []
	var expl: = []
	for e in table:
		var s: = H.for_entry(e)
		expl.append(s.explain())
		for right in [true, false]:
			for hid in [13, 8, 4, 1]:
				shares.append(ST.share_text(String(e.key), right, hid, int(e.i) % 9))
		for k in 34:
			all.append(T.ASK % GEN.name(k))
	all.append_array(expl)
	all.append_array(shares)
	var dirty: = U.lint(all)
	check(dirty.is_empty(), "%d visible strings pass V10Lint + UX §4.3 + own stop words: %s" % [all.size(), str(dirty.slice(0, 4))])
	var hero_dirty: = V10Lint.scan(T.hero_lines())
	check(hero_dirty.is_empty(), "heroine lines pass V10Lint.BANNED")
	# share text: no tile names, no answer
	var names: = []
	for k in 34:
		names.append(GEN.name(k).to_lower())
		names.append(V8Mj.short_ru(k).to_lower())
	var leak: = []
	var suit_re: = RegEx.new()
	suit_re.compile("(\\d|^|\\s)(ман|пин|со)($|[\\s·,.!?])")
	for sh in shares:
		var low: = String(sh).to_lower()
		for n in names:
			if low.find(n) >= 0 and n.length() > 2:
				leak.append([sh, n])
		if suit_re.search(low) != null:
			leak.append([sh, suit_re.search(low).get_string()])
		for word in ["дракон", "восток", "запад", "север", " юг"]:
			if low.find(word) >= 0:
				leak.append([sh, word])
	check(leak.is_empty(), "«Поделиться» never names a tile (%d texts): %s" % [shares.size(), str(leak.slice(0, 3))])
	check(String(shares[0]).begins_with("Чтение руки · ") and String(shares[0]).find("закрыто 13 из 13") > 0, "share text reads «Чтение руки · дата · вердикт · закрыто N из 13»: %s" % shares[0])
	# every explanation names the waits and its form words
	var exp_bad: = []
	for i in table.size():
		var e: Dictionary = table[i]
		if String(expl[i]).find(GEN.kinds_text(e.waits)) < 0:
			exp_bad.append(e.i)
	check(exp_bad.is_empty(), "every explanation names her waits («Она ждала 3 и 6 пин: …»)")
	check(GEN.explain([3, 4, 10, 11, 12, 12, 13, 13, 14, 24, 24, 24, 31], []) != "" and GEN.explain([12, 13, 0, 0, 0, 1, 2, 3, 22, 22, 22, 31, 31], [11, 14]).begins_with("Она ждала 3 и 6 пин: 4-5 пин ждут с двух сторон"), "the spec example reads «Она ждала 3 и 6 пин: 4-5 пин ждут с двух сторон»")
	# buttons: verb + what, ≤ 18 characters
	for b in [T.BTN_GUESS, T.BTN_YES, T.BTN_NO, T.BTN_SHARE, T.BTN_DONE, T.BTN_LESSONS, T.BTN_LESSON_CHECK, T.BTN_LESSON_NEXT]:
		check(String(b).length() <= 18, "button «%s» ≤ 18 characters" % b)
	# no «ставк» / «пари» anywhere in the module's strings (source scan, code-only strings included)
	var src_bad: = []
	for f in FILES:
		for lit in _literals("res://scripts/v10/palm/" + f):
			var low2: = String(lit).to_lower()
			for w in ["ставк", "ставок", "пари"]:
				if low2.find(w) >= 0:
					src_bad.append([f, lit])
	check(src_bad.is_empty(), "no «ставк» / «пари» in any string literal of the module: %s" % str(src_bad.slice(0, 3)))
	# no «%» and no «₽» in any visible string
	var pct: = []
	for t in all:
		if String(t).find("%") >= 0 or String(t).find("₽") >= 0:
			pct.append(t)
	check(pct.is_empty(), "no «%» / «₽» in visible strings")
	check(T.GLOSSARY.size() >= 5 and T.GLOSSARY.all(func(g): return g.has("id") and g.has("name") and g.has("why") and g.has("how")), "glossary entries in the V10Glossary format")


# string literals of a GDScript file (comments skipped; the stop-word list of hand_util is the one exception)
func _literals(path: String) -> Array:
	var out: = []
	var txt: = FileAccess.get_file_as_string(path)
	for line in txt.split("\n"):
		if line.find("OWN_BANNED") >= 0 or line.strip_edges().begins_with("\"темпай\""):
			continue
		var i: = 0
		var q: = ""
		var buf: = ""
		while i < line.length():
			var ch: = line[i]
			if q == "":
				if ch == "#":
					break
				if ch == "\"" or ch == "'":
					q = ch
					buf = ""
			else:
				if ch == "\\":
					i += 1
				elif ch == q:
					out.append(buf)
					q = ""
				else:
					buf += ch
			i += 1
	return out


# ================================================================== «Разбор ожиданий»

func _lessons() -> void:
	cur = "lessons"
	ST._test_S = {"unlocked": 30}
	check(L.LESSONS.size() == 7, "7 разборов")
	var bad: = []
	for l in L.LESSONS:
		for i in L.TASKS:
			var t: = L.task(int(l.n), i)
			if t.is_empty():
				bad.append("%d.%d empty" % [l.n, i])
				continue
			var c: = _cnt(t.hand)
			if V8Mj.shanten(c.duplicate()) != 0 or V8Mj.waits(c.duplicate()) != t.waits:
				bad.append("%d.%d waits" % [l.n, i])
			if String(GEN.classify(t.hand, t.waits).form) != String(GEN.TPL_FORM.get(String(l.form), l.form)):
				bad.append("%d.%d form" % [l.n, i])
			if (t.sleeve as Array).size() != int(l.hidden):
				bad.append("%d.%d hidden" % [l.n, i])
			if int(l.hidden) > 0:
				var r: = _bf_unique(t.hand, t.sleeve, t.notin, GEN.zeros(), t.waits)
				if r.bad > 0 or not r.true_seen:
					bad.append("%d.%d not unique" % [l.n, i])
			var right: = L.check(int(l.n), i, t.waits)
			var wrong_k: = 0
			while wrong_k in t.waits:
				wrong_k += 1
			var miss: = L.check(int(l.n), i, (t.waits as Array).slice(0, (t.waits as Array).size() - 1) + [wrong_k])
			if not right.ok or miss.ok or (miss.extra as Array).is_empty() or (miss.missing as Array).is_empty():
				bad.append("%d.%d check" % [l.n, i])
	check(bad.is_empty(), "21 hands: tenpai, the lesson's form, answer = all waits, 1 closed-card lesson unique (brute force), wrong sets rejected: %s" % str(bad.slice(0, 4)))
	check(L.is_open(1) and not L.is_open(2) and L.lock_text(2) == "Откроется после разбора 1", "разборы open one after another")
	for i in L.TASKS:
		L.mark(1, i, L.check(1, i, L.task(1, i).waits).ok)
	check(L.done(1) and L.is_open(2) and L.progress()[0] == 3 and L.progress()[1] == 0, "solving 3 hands completes a разбор and opens the next")
	var miss_text: = String(L.check(2, 0, []).text)
	check(miss_text.begins_with("Не все: ещё "), "a short answer says what is missing: %s" % miss_text)


# ================================================================== the rest

func _misc() -> void:
	cur = "misc"
	# heroine of the day: founders in turn, deterministic
	var pool: = U.FOUNDERS
	var seq: = []
	for d in range(GEN.ORIGIN_IDX, GEN.ORIGIN_IDX + 10):
		seq.append(U.hero_for_day(d, pool))
	check(seq.slice(0, 5).duplicate() == seq.slice(5, 10) and seq.slice(0, 5).all(func(h): return h in pool) and _uniq(seq.slice(0, 5)) == 5, "the heroine of the day rotates over the 5 founders")
	check(U.released().slice(0, 5) == U.FOUNDERS, "released heroines start with the founders (later ones join from G.HEROES)")
	check(U.hero_for_day(GEN.ORIGIN_IDX + 3) == U.hero_for_day(GEN.ORIGIN_IDX + 3), "same day, same heroine")
	# no global randomness in the module (deals are seeded)
	var glob: = []
	var re: = RegEx.new()
	re.compile("(^|[^\\w\\.])(randi|randf|randi_range|randf_range|randomize)\\(|\\.shuffle\\(\\)")
	for f in FILES:
		var txt: = FileAccess.get_file_as_string("res://scripts/v10/palm/" + f)
		for line in txt.split("\n"):
			var code: = line.split("#")[0]
			if re.search(code) != null:
				glob.append([f, line.strip_edges()])
	check(glob.is_empty(), "no global randi / randf / shuffle in the module: %s" % str(glob.slice(0, 3)))
	# the fallback: no file → generated on the fly, same rules
	GEN.use_file = false
	var e: = GEN.entry_for(GEN.ORIGIN_IDX + 400)
	GEN.use_file = true
	var fine: = not e.is_empty() and V8Mj.shanten(_cnt(e.hand)) == 0
	if fine:
		var r: = _bf_unique(e.hand, e.sleeve, e.decoys, _board_of(e), e.waits)
		fine = r.bad == 0 and r.true_seen and GEN.step_order_ok(GEN.deal(GEN.board_cfg(e)))
	check(fine, "a day outside the file is generated on the fly (tenpai, unique, solvable)")
	check(U.h32("tw") == U.h32("tw") and U.h32("a") != U.h32("b") and U.h32("tw-palm") == 996219459, "FNV-1a hash is stable (%d)" % U.h32("tw-palm"))
	# school hints: 4–6 candidates incl. the waits, form positions inside the hand
	var cand_bad: = []
	for e2 in table:
		var s: = H.for_entry(e2, "mc", true)
		var c: = s.candidates()
		if c.size() < 4 or c.size() > 6:
			cand_bad.append("%d size %d" % [e2.i, c.size()])
		for w in e2.waits:
			if not (w in c):
				cand_bad.append("%d misses a wait" % e2.i)
		for k in c:
			if s.impossible(int(k)):
				cand_bad.append("%d dim candidate" % e2.i)
		var sf: = s.school_form()
		if (sf.positions as Array).is_empty() or String(sf.title) == "":
			cand_bad.append("%d form" % e2.i)
		var rows: = s.shutter()
		var lit: = rows.filter(func(x): return x.cand).size()
		if lit != c.size():
			cand_bad.append("%d shutter" % e2.i)
	check(cand_bad.is_empty(), "«С подсказкой»: 4–6 candidates incl. every wait, none dimmed, the form's cards highlighted: %s" % str(cand_bad.slice(0, 4)))
	check(H.for_entry(table[0]).shutter().filter(func(x): return x.cand).is_empty(), "no candidates outside the hint week")
	# economy numbers and gate
	check(int(U.econ("hand.gate_level")) == 30 and (U.econ("hand.gems") as Array) == [10, 20, 30] and int(U.econ("hand.gems_wrong")) == 5 and int(U.econ("hand.bond")) == 2, "numbers of spec §2.3 / R4")
	check(U.bond_src() in V10Bond.SOFT, "the affection source is a registered soft source (%s)" % U.bond_src())
	check(U.date_text("2026-11-24") == "24 ноября", "date text «24 ноября»")
	var gl: = ST.glossary()
	check(gl.size() == T.GLOSSARY.size() and String(gl[0].id) == "hand.mode", "glossary() hands the entries over")


func _uniq(a: Array) -> int:
	var d: = {}
	for x in a:
		d[x] = true
	return d.size()


func _probe(n: int) -> void:
	var t0: = Time.get_ticks_msec()
	var forms: = {}
	var tmax: = 0
	for i in n:
		var t1: = Time.get_ticks_msec()
		var e: = GEN.generate(GEN.ORIGIN_IDX + int(args.get("hand_from", "0")) + i)
		var dt: = Time.get_ticks_msec() - t1
		tmax = maxi(tmax, dt)
		if e.is_empty():
			print("FAIL day ", i)
			continue
		forms[e.form] = int(forms.get(e.form, 0)) + 1
		print("d%02d wd%d %-9s hand=%s sl=%s w=%s pairs=%d unc=%d reach_unc=%d reach=%d dbl=%d cover=%.2f alts=%d ms=%d" % [i, e.wd, e.form, str(e.hand), str(e.sleeve), str(e.waits), e.pairs.size(), e.uncovered.size(), e.unc_reach, e.reach, e.doubles.size(), e.cover, e.alts, dt])
		print("     ", GEN.explain(e.hand, e.waits))
	print(forms, " max ms ", tmax, " total ", Time.get_ticks_msec() - t0)
