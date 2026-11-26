class_name V10HandGen
extends RefCounted

# «Чтение руки» (spec 0.10 R4) — the hand of the day and its table. Built on V8Mj (counts / shanten / waits /
# decompose); the deal uses the very layout and free rule of TrayBoard.
#
# KINDS  riichi kinds 0..33: 0–8 ман, 9–17 пин, 18–26 со, 27–33 Восток Юг Запад Север Белый Зелёный Красный (V8Mj).
#        The hand is shown SORTED (ман, пин, со, honours), so the place of a closed card carries information.
#
# THE PUZZLE (one entry per day)
#   hand     13 sorted kinds, tenpai with 1–3 real waits (a kind whose 4 copies are all visible is not a wait)
#   sleeve   positions of the «рукав»: whole kinds (every copy) that never flip, 1–3 cards. Forced into it: every kind
#            she holds 3 of (the board could not hold a pair of it) and every wait she holds (waits never reach the
#            board). Extra sleeve kinds by the weekday.
#   board    one pair of every other hand kind (hand + board ≤ 4 copies) + decoy pairs of kinds NOT in her hand that
#            cover almost all absent kinds; some decoys come twice (all 4 copies visible ⇒ dimmed in the shutter).
#            Waits are never on the board. The pairs are listed in deal step order (`pairs`), the layout is
#            TrayBoard.gen_layout(`layout`) and the step order comes from `deal_seed` (see deal()).
#   accept   only if at the FULLY revealed state (every board pair taken: every non-sleeve kind flipped, every decoy
#            known «Не у неё») EVERY filling of the closed positions that is consistent with the sorted order, the
#            kinds known absent and the copy limits, and that leaves her tenpai, has EXACTLY the true wait set
#            (check_unique). The answer is unique.
#   curve    Monday → Sunday: simple shapes, 1 closed card, every absent kind covered → three-sided waits and seven
#            pairs, 3 closed cards, up to 3 absent kinds left uncovered (WEEK).
#
# API
#   V10HandGen.entry_for(day_idx) -> Dictionary     the day's entry: from data/hands.json when the day is in it (and
#                                                   the file has this GEN_VER), else generated on the fly (same result)
#   V10HandGen.generate(day_idx) -> Dictionary      deterministic generation (≈0.1–0.5 s on desktop)
#   V10HandGen.write_table(n = 365) -> Dictionary   --hand_gen=365: writes DATA_PATH, returns stats
#   V10HandGen.board_cfg(entry) -> Dictionary       cfg for V10HandBoard.setup(cfg)
#   V10HandGen.deal(cfg) -> Dictionary              pure model of that deal {pos, cov, sides, order, face, step}
#   V10HandGen.step_order_ok(model) -> bool         solvable by the step order (the free rule of TrayBoard)
#   V10HandGen.real_waits(counts, board = []) -> Array
#   V10HandGen.check_unique(hand, sleeve, absent_known, board, waits) -> {ok, tenpai, bad}
#   V10HandGen.classify(hand, waits) -> {form, partial, title}   V10HandGen.explain(hand, waits) -> String
#   V10HandGen.kinds_text(kinds) -> «3 и 6 пин»                  V10HandGen.name(kind) -> V8Mj.name_ru(kind)
#   V10HandGen.lesson_hand(form, seed, hidden) -> Dictionary      hands for «Разбор ожиданий» (no board)

const U: = preload("res://scripts/v10/palm/hand_util.gd")

const GEN_VER: = 1
const DATA_PATH: = "res://scripts/v10/palm/data/hands.json"
const ORIGIN_KEY: = "2026-11-23"   # a Monday: entry 0 of the table
const ORIGIN_IDX: = 20780          # V10Meta.day_index(ORIGIN_KEY)
const DAYS: = 365
const SALT: = "tw-palm"
const SUIT_LO: = [0, 9, 18]

# The weekly curve (0 = Monday). tpls rotate week by week, so every weekday sees every template of its row during the
# year. sleeve = closed cards wanted (forced ones may exceed it, never above 3); unc = absent kinds left uncovered
# (more unknown kinds = more to rule out); dbl = decoys shown twice.
const WEEK: = [
	{"tpls": ["ryanmen", "penchan", "ryanmen", "kanchan"], "sleeve": 1, "unc": 0, "dbl": [1, 2]},
	{"tpls": ["kanchan", "ryanmen", "tanki", "penchan"], "sleeve": 1, "unc": 1, "dbl": [1, 2]},
	{"tpls": ["tanki", "kanchan", "pair_side", "ryanmen"], "sleeve": 2, "unc": 1, "dbl": [1, 2]},
	{"tpls": ["nobetan", "tanki", "kanchan", "pair_side"], "sleeve": 2, "unc": 2, "dbl": [1, 3]},
	{"tpls": ["pair_side", "nobetan", "sanmen", "tanki"], "sleeve": 2, "unc": 2, "dbl": [1, 3]},
	{"tpls": ["sanmen", "nobetan", "pair_side", "kanchan"], "sleeve": 3, "unc": 3, "dbl": [1, 3]},
	{"tpls": ["sanmen", "chiitoi", "nobetan", "pair_side", "tanki"], "sleeve": 3, "unc": 3, "dbl": [1, 3]},
]
# the form a template must classify as (pair_side 2-2-3-4 is a two-sided wait with her pair next to it)
const TPL_FORM: = {"ryanmen": "ryanmen", "kanchan": "kanchan", "penchan": "penchan", "tanki": "tanki",
	"nobetan": "nobetan", "sanmen": "sanmen", "pair_side": "ryanmen", "chiitoi": "chiitoi"}
# templates whose waits are never in her hand: a triplet (3 forced sleeve cards) still fits
const TRIP_OK: = ["ryanmen", "kanchan", "penchan"]

const FORM_TITLE: = {"ryanmen": "Ожидание с двух сторон", "kanchan": "Ожидание в середину", "penchan": "Ожидание с края",
	"tanki": "Ожидание пары", "nobetan": "Ряд из четырёх", "sanmen": "Ожидание с трёх сторон", "chiitoi": "Семь пар",
	"shanpon": "Две пары", "mixed": "Сложная форма"}

# Layout presets [cols, rows, layers, fill, shape] — all inside TrayBoard.MAX_COLS/MAX_ROWS, no ice/gold/shards.
const LAYOUTS: = [
	[5, 5, 3, 0.85, "rect"], [6, 5, 3, 0.8, "rect"], [5, 6, 3, 0.8, "rect"], [6, 6, 2, 0.85, "rect"],
	[6, 6, 3, 0.7, "diamond"], [6, 6, 3, 0.75, "ring"], [5, 6, 3, 0.8, "butterfly"], [6, 5, 3, 0.85, "heart"],
	[6, 6, 2, 0.9, "cross"], [5, 5, 3, 0.9, "pyramid"], [6, 7, 2, 0.6, "rect"], [5, 7, 2, 0.8, "ring"],
]
const LAYOUT_SEEDS: = 24
const PAIRS_MIN: = 20
const PAIRS_MAX: = 34
const PAIRS_TARGET_MAX: = 28   # «small layout ≈20–30 pairs»; trimming stops at COVER_MIN
const COVER_MIN: = 0.75        # decoys cover at least this share of the absent kinds («almost all»)


# ================================================================== counts and waits

static func zeros() -> Array:
	var c: = []
	c.resize(34)
	c.fill(0)
	return c


static func counts(hand: Array) -> Array:
	var c: = zeros()
	for k in hand:
		c[int(k)] += 1
	return c


static func sorted_hand(c: Array) -> Array:
	var h: = []
	for k in 34:
		for i in int(c[k]):
			h.append(k)
	return h


static func name(k: int) -> String:
	return V8Mj.name_ru(k)


static func suit(k: int) -> int:
	return 3 if k >= 27 else k / 9


static func _near(c: Array, w: int) -> bool:
	if int(c[w]) > 0:
		return true
	if w >= 27:
		return false
	var b: = w - w % 9
	for d in [-2, -1, 1, 2]:
		var j: int = w + d
		if j >= b and j < b + 9 and int(c[j]) > 0:
			return true
	return false


# Waits of a 13-tile hand under V8Mj rules (regular hand, seven pairs, thirteen orphans). A kind whose 4 copies are
# all visible — in her hand plus `board` (34 counts) — is not a wait (karaten). Same set as V8Mj.waits(c) when the
# board is empty; the near-filter only skips kinds that cannot complete anything (checked by the selftest).
static func real_waits(c: Array, board: Array = []) -> Array:
	var out: = []
	var kok: = V8Mj.shanten_kokushi(c) == 0
	for w in 34:
		if int(c[w]) >= 4:
			continue
		if not _near(c, w) and not (kok and V8Mj.is_yaochu(w)):
			continue
		if not board.is_empty() and int(c[w]) + int(board[w]) >= 4:
			continue
		c[w] += 1
		var ok: = V8Mj.shanten(c) == -1
		c[w] -= 1
		if ok:
			out.append(w)
	return out


# ================================================================== shapes: classification and words

# every way a wait completes the hand: w -> [{t, p}] (t: ryanmen / kanchan / penchan / tanki / shanpon / chiitoi,
# p: the kinds of her hand that wait for it)
static func interps(c: Array, waits: Array) -> Dictionary:
	var out: = {}
	for w in waits:
		var lst: = []
		c[w] += 1
		for dec in V8Mj.decompose(c):
			if int(dec.pair) == w:
				_push(lst, {"t": "tanki", "p": [w]})
			for st in dec.sets:
				var typ: = int(st[0])
				var k: = int(st[1])
				if typ == 0 and k == w:
					_push(lst, {"t": "shanpon", "p": [w, w]})
				elif typ == 1 and k <= w and w <= k + 2:
					var p: = [k, k + 1, k + 2]
					p.erase(w)
					var t: = "ryanmen"
					if w == k + 1:
						t = "kanchan"
					elif (k % 9 == 0 and w == k + 2) or (k % 9 == 6 and w == k):
						t = "penchan"
					_push(lst, {"t": t, "p": p})
		c[w] -= 1
		if lst.is_empty() and V8Mj.shanten_chiitoi(c) == 0 and int(c[w]) == 1:
			lst.append({"t": "chiitoi", "p": [w]})
		out[w] = lst
	return out


static func _push(lst: Array, it: Dictionary) -> void:
	for x in lst:
		if x.t == it.t and x.p == it.p:
			return
	lst.append(it)


static func _has(lst: Array, t: String, p = null) -> bool:
	for x in lst:
		if x.t == t and (p == null or x.p == p):
			return true
	return false


# {form, partial (kinds of her hand that make the wait), title}
static func classify(hand: Array, waits: Array) -> Dictionary:
	var c: = counts(hand)
	var ws: = waits.duplicate()
	ws.sort()
	var it: = interps(c, ws)
	var res: = {"form": "mixed", "partial": [], "title": FORM_TITLE.mixed}
	if ws.is_empty():
		return res
	var all_chii: = true
	for w in ws:
		for x in it[w]:
			if x.t != "chiitoi":
				all_chii = false
		if (it[w] as Array).is_empty():
			all_chii = false
	if all_chii:
		res.form = "chiitoi"
		res.partial = [ws[0]] if ws.size() == 1 else ws
	elif ws.size() == 1:
		var w: int = ws[0]
		for t in ["kanchan", "penchan", "ryanmen", "tanki", "shanpon"]:
			for x in it[w]:
				if x.t == t:
					res.form = t
					res.partial = x.p
					break
			if res.form != "mixed":
				break
	elif ws.size() == 2:
		var a: int = ws[0]
		var b: int = ws[1]
		var same: = a < 27 and b < 27 and a / 9 == b / 9 and b == a + 3
		if same and _has(it[a], "ryanmen", [a + 1, a + 2]) and _has(it[b], "ryanmen", [a + 1, a + 2]):
			res.form = "ryanmen"
			res.partial = [a + 1, a + 2]
		elif same and _has(it[a], "tanki") and _has(it[b], "tanki") and c[a] >= 1 and c[a + 1] >= 1 and c[a + 2] >= 1 and c[b] >= 1:
			res.form = "nobetan"
			res.partial = [a, a + 1, a + 2, a + 3]
		elif _has(it[a], "shanpon") and _has(it[b], "shanpon"):
			res.form = "shanpon"
			res.partial = [a, a, b, b]
	elif ws.size() == 3:
		var a: int = ws[0]
		var same3: bool = ws[2] < 27 and a / 9 == int(ws[2]) / 9 and int(ws[1]) == a + 3 and int(ws[2]) == a + 6
		if same3 and c[a + 1] >= 1 and c[a + 2] >= 1 and c[a + 3] >= 1 and c[a + 4] >= 1 and c[a + 5] >= 1:
			res.form = "sanmen"
			res.partial = [a + 1, a + 2, a + 3, a + 4, a + 5]
	res.title = FORM_TITLE.get(res.form, FORM_TITLE.mixed)
	return res


# «3 и 6 пин», «2, 5 и 8 со», «3 пин и Юг» — kinds grouped by suit, player names (V8Mj.SUIT_RU / HONOR_RU)
static func kinds_text(kinds: Array) -> String:
	var ks: = kinds.duplicate()
	ks.sort()
	var groups: = []
	var cur_s: = -1
	for k in ks:
		var s: = suit(k)
		if s == 3:
			groups.append(V8Mj.name_ru(k))
			cur_s = -1
			continue
		if s != cur_s:
			groups.append([])
			cur_s = s
		(groups[groups.size() - 1] as Array).append(k)
	var parts: = []
	for g in groups:
		if g is String:
			parts.append(g)
		else:
			var nums: = []
			for k in g:
				nums.append(str(V8Mj.num(k)))
			parts.append("%s %s" % [_join_and(nums), V8Mj.SUIT_RU[suit(g[0])]])
	return _join_and(parts)


static func _join_and(items: Array) -> String:
	if items.is_empty():
		return ""
	if items.size() == 1:
		return str(items[0])
	var head: = []
	for i in items.size() - 1:
		head.append(str(items[i]))
	return "%s и %s" % [", ".join(head), str(items[items.size() - 1])]


# «4-5 пин» (a run in one suit) or the plain list
static func run_text(kinds: Array) -> String:
	if kinds.is_empty():
		return ""
	var s: = suit(kinds[0])
	if s == 3:
		return kinds_text(kinds)
	var nums: = []
	for k in kinds:
		nums.append(str(V8Mj.num(k)))
	return "%s %s" % ["-".join(nums), V8Mj.SUIT_RU[s]]


# the shape explanation shown when she opens her hand («Она ждала 3 и 6 пин: 4-5 пин ждут с двух сторон.»)
static func explain(hand: Array, waits: Array) -> String:
	var a: = classify(hand, waits)
	var w: = kinds_text(waits)
	var p: Array = a.partial
	match String(a.form):
		"ryanmen":
			return "Она ждала %s: %s ждут с двух сторон." % [w, run_text(p)]
		"kanchan":
			return "Она ждала %s: %s ждут середину." % [w, kinds_text(p)]
		"penchan":
			return "Она ждала %s: %s ждут с края." % [w, run_text(p)]
		"tanki":
			return "Она ждала %s: эта фишка осталась без пары." % w
		"nobetan":
			return "Она ждала %s: ряд %s ждёт пару с любого конца." % [w, run_text(p)]
		"sanmen":
			return "Она ждала %s: ряд %s ждёт с трёх сторон." % [w, run_text(p)]
		"chiitoi":
			return "Она ждала %s: шесть пар собраны, эта фишка ждёт седьмую." % w
		"shanpon":
			return "Она ждала %s: две пары, любая из них станет тройкой." % w
	return "Она ждала %s: рука закрывается любой из этих фишек." % w


# ================================================================== the weekly hand

static func _add_seq(c: Array, k: int) -> bool:
	if k >= 27 or k % 9 > 6:
		return false
	if int(c[k]) >= 3 or int(c[k + 1]) >= 3 or int(c[k + 2]) >= 3:
		return false
	c[k] += 1
	c[k + 1] += 1
	c[k + 2] += 1
	return true


static func _add_sets(c: Array, n: int, r: RandomNumberGenerator, trip_ok: bool) -> bool:
	var added: = 0
	var guard: = 0
	while added < n and guard < 60:
		guard += 1
		if trip_ok and r.randf() < 0.28:
			var k: = r.randi() % 34
			if int(c[k]) == 0:
				c[k] += 3
				added += 1
		else:
			if _add_seq(c, SUIT_LO[r.randi() % 3] + r.randi() % 7):
				added += 1
	return added == n


static func _add_pair(c: Array, r: RandomNumberGenerator) -> bool:
	for i in 30:
		var k: = r.randi() % 34
		if int(c[k]) == 0:
			c[k] += 2
			return true
	return false


static func _build(tpl: String, r: RandomNumberGenerator, trip_days: = true) -> Array:
	var c: = zeros()
	var lo: int = SUIT_LO[r.randi() % 3]
	var trip: = trip_days and tpl in TRIP_OK
	match tpl:
		"ryanmen":
			var n: = 1 + r.randi() % 6
			c[lo + n] += 1
			c[lo + n + 1] += 1
			if not (_add_pair(c, r) and _add_sets(c, 3, r, trip)):
				return []
		"kanchan":
			var n: = r.randi() % 7
			c[lo + n] += 1
			c[lo + n + 2] += 1
			if not (_add_pair(c, r) and _add_sets(c, 3, r, trip)):
				return []
		"penchan":
			var n: = 0 if r.randf() < 0.5 else 7
			c[lo + n] += 1
			c[lo + n + 1] += 1
			if not (_add_pair(c, r) and _add_sets(c, 3, r, trip)):
				return []
		"tanki":
			c[r.randi() % 34] += 1
			if not _add_sets(c, 4, r, false):
				return []
		"nobetan":
			var n: = r.randi() % 6
			for i in 4:
				c[lo + n + i] += 1
			if not _add_sets(c, 3, r, false):
				return []
		"sanmen":
			var n: = r.randi() % 5
			for i in 5:
				c[lo + n + i] += 1
			if not (_add_pair(c, r) and _add_sets(c, 2, r, false)):
				return []
		"pair_side":
			var n: = r.randi() % 7
			if r.randf() < 0.5:
				c[lo + n] += 2
				c[lo + n + 1] += 1
				c[lo + n + 2] += 1
			else:
				c[lo + n] += 1
				c[lo + n + 1] += 1
				c[lo + n + 2] += 2
			if not _add_sets(c, 3, r, false):
				return []
		"chiitoi":
			var ks: = range(34)
			U.shuffle(ks, r)
			for i in 6:
				c[ks[i]] += 2
			c[ks[6]] += 1
	var n_t: = 0
	for k in 34:
		if int(c[k]) > 3:
			return []
		n_t += int(c[k])
	return c if n_t == 13 else []


static func board_counts(hand_kinds_open: Array, decoys: Array, doubles: Array) -> Array:
	var b: = zeros()
	for k in hand_kinds_open:
		b[k] += 2
	for k in decoys:
		b[k] += 2
	for k in doubles:
		b[k] += 2
	return b


# ================================================================== uniqueness

# At the fully revealed state the player sees: the kind of every open position, the closed positions (their place in
# the sorted hand), every board tile (`board`, 34 counts) and the kinds known absent («Не у неё»). Enumerates every
# filling of the closed positions consistent with that (sorted order, never a flipped kind — all its copies flipped
# — never a kind known absent, hand + board ≤ 4 copies) and compares the waits of every tenpai filling with `waits`.
# Returns {ok, tenpai (fillings that are tenpai, the true one included), bad: [hands with other waits]}.
static func check_unique(hand: Array, sleeve: Array, absent_known: Array, board: Array, waits: Array, all_bad: = false) -> Dictionary:
	var hidden: = sleeve.duplicate()
	hidden.sort()
	var base: = zeros()
	var rev: = {}
	for i in hand.size():
		if not (i in hidden):
			rev[int(hand[i])] = true
			base[int(hand[i])] += 1
	var no: = {}
	for k in absent_known:
		no[int(k)] = true
	var allowed: = []
	for p in hidden:
		var lo: = 0
		var hi: = 33
		for i in range(p - 1, -1, -1):
			if not (i in hidden):
				lo = int(hand[i])
				break
		for i in range(p + 1, hand.size()):
			if not (i in hidden):
				hi = int(hand[i])
				break
		var ks: = []
		for k in range(lo, hi + 1):
			if not rev.has(k) and not no.has(k):
				ks.append(k)
		allowed.append(ks)
	var want: = waits.duplicate()
	want.sort()
	var acc: = {"tenpai": 0, "bad": [], "stop": false, "all": all_bad}
	_enum(0, 0, base, allowed, board, want, acc, [])
	return {"ok": (acc.bad as Array).is_empty(), "tenpai": acc.tenpai, "bad": acc.bad}


static func _enum(i: int, prev: int, c: Array, allowed: Array, board: Array, want: Array, acc: Dictionary, fill: Array) -> void:
	if acc.stop:
		return
	if i == allowed.size():
		if V8Mj.shanten(c) != 0:
			return
		acc.tenpai = int(acc.tenpai) + 1
		var w: = real_waits(c, board)
		if w != want:
			(acc.bad as Array).append({"fill": fill.duplicate(), "waits": w})
			if not acc.all:
				acc.stop = true
		return
	for k in allowed[i]:
		if k < prev:
			continue
		if int(c[k]) + 1 + int(board[k]) > 4:
			continue
		c[k] += 1
		fill.append(k)
		_enum(i + 1, k, c, allowed, board, want, acc, fill)
		fill.pop_back()
		c[k] -= 1


# kinds that could sit on at least one closed position (between its open neighbours in the sorted hand, never a
# flipped kind): an absent kind outside this set can never change the answer
static func reach(hand: Array, sleeve: Array) -> Array:
	var rev: = {}
	for i in hand.size():
		if not (i in sleeve):
			rev[int(hand[i])] = true
	var out: = {}
	for p in sleeve:
		var lo: = 0
		var hi: = 33
		for i in range(p - 1, -1, -1):
			if not (i in sleeve):
				lo = int(hand[i])
				break
		for i in range(p + 1, hand.size()):
			if not (i in sleeve):
				hi = int(hand[i])
				break
		for k in range(lo, hi + 1):
			if not rev.has(k):
				out[k] = true
	var ks: = out.keys()
	ks.sort()
	return ks


# ================================================================== layouts and the deal (pure model of TrayBoard)

# positions exactly as TrayBoard.setup builds them: gen_layout, odd count → drop the first top-most, sort (z, y, x)
static func positions(cfg: Dictionary) -> Array:
	var pos: Array = TrayBoard.gen_layout(cfg)
	if pos.size() % 2 == 1:
		var top: = 0
		for i in pos.size():
			if pos[i].z > pos[top].z:
				top = i
		pos.remove_at(top)
	pos.sort_custom(func(a, b): return a.z * 100000 + a.y * 100 + a.x < b.z * 100000 + b.y * 100 + b.x)
	return pos


static func _covers(o: Vector3i, t: Vector3i) -> bool:
	return o.z > t.z and absi(o.x - t.x) < 2 and absi(o.y - t.y) < 2


static func _geometry(pos: Array) -> Dictionary:
	var cov: = []
	var sides: = []
	for i in pos.size():
		var me: Vector3i = pos[i]
		var cv: = []
		var l: = []
		var rr: = []
		for j in pos.size():
			if j == i:
				continue
			var o: Vector3i = pos[j]
			if _covers(o, me):
				cv.append(j)
			if o.z == me.z and absi(o.y - me.y) < 2:
				if o.x - me.x == -2:
					l.append(j)
				elif o.x - me.x == 2:
					rr.append(j)
		cov.append(cv)
		sides.append([l, rr])
	return {"cov": cov, "sides": sides}


# TrayBoard._free_if with present = «not gone»
static func free_i(geo: Dictionary, i: int, gone: Dictionary) -> bool:
	for o in geo.cov[i]:
		if not gone.has(o):
			return false
	var sd: Array = geo.sides[i]
	var l_any: = false
	for o in sd[0]:
		if not gone.has(o):
			l_any = true
			break
	if not l_any:
		return true
	for o in sd[1]:
		if not gone.has(o):
			return false
	return true


# The deal of V10HandBoard._assign as a pure model: the same random walk over free tiles as TrayBoard._assign, but
# from RandomNumberGenerator(deal_seed); tiles order[2k], order[2k+1] get face pairs[k] and step k.
static func deal(cfg: Dictionary) -> Dictionary:
	var pos: = positions(cfg)
	var geo: = _geometry(pos)
	var r: = RandomNumberGenerator.new()
	r.seed = int(cfg.get("deal_seed", 1))
	var left: = range(pos.size())
	var gone: = {}
	var order: = []
	while not left.is_empty():
		var fr: = []
		for i in left:
			if free_i(geo, i, gone):
				fr.append(i)
		var pk: int = fr[r.randi() % fr.size()]
		order.append(pk)
		left.erase(pk)
		gone[pk] = true
	var face: = []
	var step: = []
	face.resize(pos.size())
	step.resize(pos.size())
	var pairs: Array = cfg.get("pairs", [])
	for k in order.size() / 2:
		var f: int = int(pairs[k]) if k < pairs.size() else -1
		for j in [order[2 * k], order[2 * k + 1]]:
			face[j] = f
			step[j] = k
	return {"pos": pos, "cov": geo.cov, "sides": geo.sides, "order": order, "face": face, "step": step}


# every tile is free when its turn in the step order comes (taking pair k after every pair before it)
static func step_order_ok(m: Dictionary) -> bool:
	var geo: = {"cov": m.cov, "sides": m.sides}
	var gone: = {}
	var by_step: = {}
	for i in (m.pos as Array).size():
		by_step[int(m.step[i])] = by_step.get(int(m.step[i]), []) + [i]
	for k in by_step.size():
		var two: Array = by_step.get(k, [])
		if two.size() != 2 or int(m.face[two[0]]) != int(m.face[two[1]]) or int(m.face[two[0]]) < 0:
			return false
		var a: int = two[0]
		var b: int = two[1]
		if free_i(geo, a, gone):
			gone[a] = true
			if not free_i(geo, b, gone):
				return false
		elif free_i(geo, b, gone):
			gone[b] = true
			if not free_i(geo, a, gone):
				return false
		else:
			return false
		gone[a] = true
		gone[b] = true
	return true


static var _layout_table: = {}


# pairs -> [[preset index, seed]] of every preset × seed giving exactly that many pairs (built once)
static func layout_table() -> Dictionary:
	if not _layout_table.is_empty():
		return _layout_table
	for li in LAYOUTS.size():
		for s in LAYOUT_SEEDS:
			var cfg: = layout_cfg(li, s)
			var n: = positions(cfg).size() / 2
			if n >= PAIRS_MIN and n <= PAIRS_MAX:
				if not _layout_table.has(n):
					_layout_table[n] = []
				(_layout_table[n] as Array).append([li, s])
	return _layout_table


static func layout_cfg(li: int, s: int) -> Dictionary:
	var l: Array = LAYOUTS[li]
	return {"cols": int(l[0]), "rows": int(l[1]), "layers": int(l[2]), "fill": float(l[3]), "shape": String(l[4]),
		"seed": 1000 + li * 97 + s}


# ================================================================== generation

static func generate(d: int) -> Dictionary:
	var wd: = U.weekday(d)
	var spec: Dictionary = WEEK[wd]
	var week: = floori(float(d - ORIGIN_IDX) / 7.0)
	var r: = U.rng(d, "%s|%d" % [SALT, GEN_VER])
	var tpls: Array = spec.tpls
	var table: = layout_table()
	for attempt in 600:
		var tpl: String = tpls[posmod(week + attempt / 60, tpls.size())]
		var trip_days: = int(spec.sleeve) >= 3
		var c: = _build(tpl, r, trip_days)
		if c.is_empty():
			continue
		if not trip_days and c.max() >= 3:
			continue   # three of a kind = three closed cards: only on the weekend
		var hand: = sorted_hand(c)
		var waits: = real_waits(c)
		if waits.size() < 1 or waits.size() > 3:
			continue
		var cl: = classify(hand, waits)
		if String(cl.form) != String(TPL_FORM[tpl]):
			continue
		# the sleeve: forced kinds, then extra whole kinds up to the weekday's count
		var sl_kinds: = []
		var sl_n: = 0
		for k in 34:
			if int(c[k]) >= 3 or (int(c[k]) >= 1 and k in waits):
				sl_kinds.append(k)
				sl_n += int(c[k])
		if sl_n > 3:
			continue
		var target: = clampi(int(spec.sleeve), maxi(1, sl_n), 3)
		var extra: = []
		for k in 34:
			if int(c[k]) > 0 and not (k in sl_kinds):
				extra.append(k)
		U.shuffle(extra, r)
		for k in extra:
			if sl_n + int(c[k]) <= target:
				sl_kinds.append(k)
				sl_n += int(c[k])
		if sl_n < 1:
			continue
		var sleeve: = []
		var open_kinds: = []
		for i in 13:
			if int(hand[i]) in sl_kinds:
				sleeve.append(i)
		for k in 34:
			if int(c[k]) > 0 and not (k in sl_kinds):
				open_kinds.append(k)
		var absent: = []
		for k in 34:
			if int(c[k]) == 0 and not (k in waits):
				absent.append(k)
		var got: = _place(d, r, spec, table, hand, sleeve, open_kinds, absent, waits)
		if got.is_empty():
			continue
		got.merge({"v": GEN_VER, "i": d, "key": U.key_of_index(d), "wd": wd, "tpl": tpl, "form": cl.form,
			"hand": hand, "sleeve": sleeve, "waits": waits, "sleeve_n": sleeve.size()})
		return got
	return {}


# Choose the uncovered kinds (the weekday's count), the doubles, then trim the board into the size window by leaving
# more absent kinds uncovered (each one re-checked: the answer must stay unique; coverage never below COVER_MIN),
# and pick a layout of exactly that many pairs.
static func _place(d: int, r: RandomNumberGenerator, spec: Dictionary, table: Dictionary, hand: Array, sleeve: Array,
		open_kinds: Array, absent: Array, waits: Array) -> Dictionary:
	var unc_want: = mini(int(spec.unc), absent.size() - 1)
	var dbl_rng: Array = spec.dbl
	var rch: = reach(hand, sleeve)
	for unc_n in range(unc_want, -1, -1):
		for t in (8 if unc_n > 0 else 2):
			# the weekday's uncovered kinds come from those a closed position could hold: they make the reading
			# harder (more fillings to rule out); far kinds would change nothing
			var near_pool: = []
			var far_pool: = []
			for k in absent:
				if k in rch:
					near_pool.append(k)
				else:
					far_pool.append(k)
			U.shuffle(near_pool, r)
			U.shuffle(far_pool, r)
			var pool: = near_pool + far_pool
			var unc: = pool.slice(0, unc_n)
			var decoys: = []
			for k in absent:
				if not (k in unc):
					decoys.append(k)
			var nd: = int(dbl_rng[0]) + r.randi() % (int(dbl_rng[1]) - int(dbl_rng[0]) + 1)
			nd = mini(nd, decoys.size())
			var dpool: = decoys.duplicate()
			U.shuffle(dpool, r)
			var doubles: Array = dpool.slice(0, nd)
			var u: = check_unique(hand, sleeve, decoys, board_counts(open_kinds, decoys, doubles), waits)
			if not u.ok:
				continue
			# trim: uncover more absent kinds while the board is above the window — first those no closed position can
			# hold (they never change the answer: the weekday's difficulty stays as designed), then the others
			var far: = []
			var nearby: = []
			for k in decoys:
				if k in rch:
					nearby.append(k)
				else:
					far.append(k)
			U.shuffle(far, r)
			U.shuffle(nearby, r)
			var trim: = far + nearby
			for k in trim:
				if open_kinds.size() + decoys.size() + doubles.size() <= PAIRS_TARGET_MAX:
					break
				if k in doubles or float(decoys.size() - 1) / float(absent.size()) < COVER_MIN:
					continue
				var d2: = decoys.duplicate()
				d2.erase(k)
				var u2: = check_unique(hand, sleeve, d2, board_counts(open_kinds, d2, doubles), waits)
				if u2.ok:
					decoys = d2
					unc.append(k)
					u = u2
			# exact layout size: the doubles may move by one or two (re-checked)
			var found: = false
			for dn in [0, -1, 1, -2, 2]:
				var nd2: int = doubles.size() + int(dn)
				if nd2 < 0 or nd2 > mini(4, decoys.size()):
					continue
				var pairs_n: int = open_kinds.size() + decoys.size() + nd2
				if not table.has(pairs_n) or pairs_n > PAIRS_TARGET_MAX + 2 or pairs_n < PAIRS_MIN:
					continue
				var dbl2: Array = doubles.slice(0, nd2) if dn <= 0 else doubles.duplicate()
				if dn > 0:
					var rest: = []
					for k in dpool:
						if k in decoys and not (k in dbl2):
							rest.append(k)
					for i in dn:
						if i < rest.size():
							dbl2.append(rest[i])
				if dbl2.size() != nd2:
					continue
				if dn != 0:
					var u3: = check_unique(hand, sleeve, decoys, board_counts(open_kinds, decoys, dbl2), waits)
					if not u3.ok:
						continue
					u = u3
				doubles = dbl2
				found = true
				break
			if not found:
				continue
			doubles.sort()
			unc.sort()
			decoys.sort()
			var pairs_n2: = open_kinds.size() + decoys.size() + doubles.size()
			var lays: Array = table[pairs_n2]
			var lay: Array = lays[r.randi() % lays.size()]
			var cfg: = layout_cfg(int(lay[0]), int(lay[1]))
			var plan: = []
			for k in open_kinds:
				plan.append(k)
			for k in decoys:
				plan.append(k)
			for k in doubles:
				plan.append(k)
			U.shuffle(plan, r)
			return {"open": open_kinds, "decoys": decoys, "doubles": doubles, "uncovered": unc, "absent_n": absent.size(),
				"layout": cfg, "deal_seed": int(r.randi() & 0x7FFFFFFF), "pairs": plan, "alts": int(u.tenpai),
				"unc_reach": unc.filter(func(k): return k in rch).size(), "reach": rch.size(),
				"cover": snappedf(float(decoys.size()) / float(maxi(1, absent.size())), 0.01)}
	return {}


# ================================================================== the table file

static var _file: = {}
static var _file_read: = false
static var _gen_cache: = {}
static var use_file: = true   # selftests switch the file off to test the on-the-fly fallback


static func load_table() -> Dictionary:
	if _file_read:
		return _file
	_file_read = true
	_file = {}
	if not FileAccess.file_exists(DATA_PATH):
		return _file
	var txt: = FileAccess.get_file_as_string(DATA_PATH)
	var j = JSON.parse_string(txt)
	if j is Dictionary and int(j.get("gen_ver", -1)) == GEN_VER and j.get("entries") is Array:
		_file = j
	return _file


static func reload() -> void:
	_file_read = false
	_file = {}


static func entry_for(d: int) -> Dictionary:
	if use_file:
		var t: = load_table()
		if not t.is_empty():
			var i: = d - int(t.get("origin_idx", ORIGIN_IDX))
			var es: Array = t.entries
			if i >= 0 and i < es.size():
				return norm(es[i])
	if not _gen_cache.has(d):
		_gen_cache[d] = generate(d)
	return _gen_cache[d]


# JSON turns ints into floats: back to ints
static func norm(e: Dictionary) -> Dictionary:
	var o: = e.duplicate(true)
	for k in ["v", "i", "wd", "sleeve_n", "deal_seed", "alts", "absent_n", "unc_reach", "reach"]:
		if o.has(k):
			o[k] = int(o[k])
	if o.has("cover"):
		o["cover"] = float(o["cover"])
	for k in ["hand", "sleeve", "waits", "open", "decoys", "doubles", "uncovered", "pairs"]:
		var a: = []
		for x in o.get(k, []):
			a.append(int(x))
		o[k] = a
	var l: Dictionary = o.get("layout", {})
	for k in ["cols", "rows", "layers", "seed"]:
		if l.has(k):
			l[k] = int(l[k])
	if l.has("fill"):
		l["fill"] = float(l["fill"])
	o["layout"] = l
	return o


# --hand_gen=N: N days from ORIGIN_IDX into DATA_PATH. Returns stats {days, forms, ms}.
static func write_table(n: int = DAYS) -> Dictionary:
	var t0: = Time.get_ticks_msec()
	var es: = []
	var forms: = {}
	var fails: = []
	for i in n:
		var e: = generate(ORIGIN_IDX + i)
		if e.is_empty():
			fails.append(ORIGIN_IDX + i)
		es.append(e)
		forms[String(e.get("form", "?"))] = int(forms.get(String(e.get("form", "?")), 0)) + 1
	var doc: = {"ver": 1, "gen_ver": GEN_VER, "origin": ORIGIN_KEY, "origin_idx": ORIGIN_IDX, "days": n,
		"note": "Чтение руки: one entry per day index from origin_idx (V10HandGen.write_table)", "entries": es}
	var path: = ProjectSettings.globalize_path(DATA_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(doc, "", false))
		f.close()
	reload()
	return {"days": n, "forms": forms, "fails": fails, "ms": Time.get_ticks_msec() - t0, "path": path}


static func board_cfg(e: Dictionary) -> Dictionary:
	var cfg: Dictionary = (e.get("layout", {}) as Dictionary).duplicate()
	cfg["deal_seed"] = int(e.get("deal_seed", 1))
	cfg["pairs"] = (e.get("pairs", []) as Array).duplicate()
	cfg["faces"] = 34
	cfg["gold"] = 0
	cfg["ice"] = 0
	cfg["shard"] = ""
	cfg["hidden"] = false
	return cfg


# ================================================================== lessons («Разбор ожиданий»)

# A lesson hand of a given form, no board: all 13 open (hidden = 0), or `hidden` closed cards whose answer is still
# unique given the kinds listed as «Не у неё» (every absent kind but the waits). {hand, sleeve, waits, form, notin}
static func lesson_hand(form: String, seed_v: int, hidden: = 0) -> Dictionary:
	var r: = U.rng(seed_v, "%s|lesson|%s" % [SALT, form])
	var tpl: = form
	for attempt in 400:
		var c: = _build(tpl, r)
		if c.is_empty():
			continue
		var hand: = sorted_hand(c)
		var waits: = real_waits(c)
		if waits.is_empty() or waits.size() > 3:
			continue
		if String(classify(hand, waits).form) != String(TPL_FORM.get(tpl, tpl)):
			continue
		var notin: = []
		for k in 34:
			if int(c[k]) == 0 and not (k in waits):
				notin.append(k)
		var sleeve: = []
		if hidden > 0:
			# close whole kinds that are not waits, as a real day would (never the wait itself: a lesson teaches)
			var ks: = []
			for k in 34:
				if int(c[k]) > 0 and int(c[k]) <= hidden and not (k in waits):
					ks.append(k)
			U.shuffle(ks, r)
			var n: = 0
			for k in ks:
				if n + int(c[k]) <= hidden:
					for i in 13:
						if int(hand[i]) == k:
							sleeve.append(i)
					n += int(c[k])
			if n != hidden:
				continue
			sleeve.sort()
			var board: = zeros()
			if not check_unique(hand, sleeve, notin, board, waits).ok:
				continue
		return {"hand": hand, "sleeve": sleeve, "waits": waits, "form": String(TPL_FORM.get(tpl, tpl)), "notin": notin}
	return {}
