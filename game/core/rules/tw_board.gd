class_name TWBoard
extends RefCounted

# TWBoard (P16 / WP5): the ONE rules engine of the tray solitaire (tile table + 4-slot tray), as pure RefCounted code.
# It merges the rules of tray_board (tap / tray / pair / ice / secret / gold / shard / undo / hint / shuffle / return_tray),
# V6SpecialBoard (key, lock, chain, joker, bomb, gift, unstick) and V10LevelSim (the compact integer representation, the
# certificate replay) into one engine that has
#   * integer tile ids (index into `pos`, the order of tray_board.setup / V10LevelGen payloads),
#   * a seeded deal (TWRng): faces, gold, ice, secret, shard and the specials are a function of the seed,
#   * an injected clock (`clock` Callable, else `time`) for the combo window,
#   * no Node, no Tile, no Tween, no await, no G: every operation returns the EVENTS it caused (TWBoardEvents) and the
#     view animates them,
#   * state_hash / certificate / fork, so a game can be compared, replayed and proven.
# tray_board.gd (P18) is the thin view over this engine: it syncs its tiles in, calls an operation here and animates the events.
#
#   TWBoard.from_cfg(cfg)      a fresh seeded deal of a board config (cols, rows, layers, faces, gold, ice, hidden, shard,
#                              seed, specials plan in cfg.plan or cfg.v10_plan)
#   TWBoard.from_level(lv)     a Path level with its precomputed payload (V10LevelGen.build(i)); same board as V10LevelBoard
#   tap(id) -> [Event]         the whole move; undo() / return_tray(n) / shuffle() / vanish_pairs(n) / hack_deepest() /
#                              moonlight() / open_tile(id) -> [Event]
#   hint() -> [id, id] / best_move() / solver_move() / free_tiles() / is_free(id) / takeable(id)
#   state_hash() -> int        one int over everything that decides the game
#   certificate() / verify_certificate() / fork_fresh() / snapshot() / restore()

const E = preload("res://core/rules/tw_events_board.gd")

const JOKER: = 300
const SHARD_FACE: = 100
const K_NONE: = 0
const K_KEY: = 1
const K_LOCK: = 2
const K_CHAIN: = 3
const K_JOKER: = 4
const K_BOMB: = 5
const K_GIFT: = 6
const KIND_NAMES: = ["", "key", "lock", "chain", "joker", "bomb", "gift"]
const GROUPS: = 16

# ---- topology (immutable after build; shared by forks) ----
var n: = 0
var pos: Array = []                  # Vector3i per tile id
var cov_by: Array = []
var covers: Array = []
var lft: Array = []
var rgt: Array = []
var lft_of: Array = []
var rgt_of: Array = []

# ---- content of the deal (what reset() starts from) ----
var face0: = PackedInt32Array()
var step0: = PackedInt32Array()
var gold0: = PackedByteArray()
var ice0: = PackedByteArray()
var secret0: = PackedByteArray()
var shard0: = PackedByteArray()
var kind: = PackedByteArray()
var arg: = PackedInt32Array()
var mate: = PackedInt32Array()
var shard_hero: = ""
var cert: = PackedInt32Array()       # a take order that clears the initial deal (tile ids; ice tiles are flipped on the way)
var code: = ""
var deal_seed: = 0

# ---- rules switches ----
var slots: = 4
var combo_window: = 5.0
var blasts: = true                   # bomb pairs blast their neighbours (V10LevelSim does not; the verifier switches it off)
var clock: Callable                  # () -> float seconds; when not valid `time` is used (tests drive it by hand)
var time: = 0.0
var rng: TWRng                       # runtime randomness (shuffle); seeded from the deal seed

# ---- state ----
var present: = PackedByteArray()     # on the table (not taken, not in the tray)
var alive: = PackedByteArray()       # not matched yet (the tray counts as alive)
var covcnt: = PackedInt32Array()
var lcnt: = PackedInt32Array()
var rcnt: = PackedInt32Array()
var face: = PackedInt32Array()
var step: = PackedInt32Array()
var gold: = PackedByteArray()
var ice: = PackedByteArray()
var sec: = PackedByteArray()         # still hidden
var shard_f: = PackedByteArray()
var kind_now: = PackedByteArray()
var opened: = PackedByteArray()      # forced free (open_tile)
var tray: = PackedInt32Array()
var history: = PackedInt32Array()    # tray tiles in the order they came (undo pops the last)
var key_open: = PackedByteArray()
var taps: = PackedInt32Array()       # every tap that changed something (flips and takes): the replay log
var pairs_done: = 0
var unstuck: = false
var on_board: = 0
var alive_n: = 0
var sec_left: = 0
var moves: = 0
var combo: = 0
var last_match: = -10.0
var last_face: = -1
var last_gift: = false
var cracks: = 0
var max_tray: = 0
var failed: = false
var cleared: = false
var shuffled: = false
var has_locks: = false


# =================================================================== construction

static func from_positions(positions: Array, slots_: int = 4) -> TWBoard:
	var b: = TWBoard.new()
	b.slots = slots_
	b.n = positions.size()
	b.pos = positions
	var t: = TWFree.topology(positions)
	b.cov_by = t.cov_by
	b.covers = t.covers
	b.lft = t.lft
	b.rgt = t.rgt
	b.lft_of = t.lft_of
	b.rgt_of = t.rgt_of
	var nn: = b.n
	# resize() leaves new elements uninitialised: every array is filled
	b.face0.resize(nn)
	b.face0.fill(0)
	b.step0.resize(nn)
	b.step0.fill(0)
	b.arg.resize(nn)
	b.arg.fill(0)
	b.gold0.resize(nn)
	b.gold0.fill(0)
	b.ice0.resize(nn)
	b.ice0.fill(0)
	b.secret0.resize(nn)
	b.secret0.fill(0)
	b.shard0.resize(nn)
	b.shard0.fill(0)
	b.kind.resize(nn)
	b.kind.fill(0)
	b.mate.resize(nn)
	b.mate.fill(-1)
	b.rng = TWRng.make(1, 2)
	return b


# the seeded deal of a board config; same cfg => same board on every run
static func from_cfg(cfg: Dictionary) -> TWBoard:
	var b: = from_positions(TWFree.positions(cfg), int(cfg.get("slots", 4)))
	b.deal(cfg)
	return b


# deal this table's faces / steps / ice / gold / secret / shard (and the specials of cfg.plan) from cfg.deal_seed (else cfg.seed);
# same cfg => same deal. The table keeps its topology; the state goes back to the start of the game.
func deal(cfg: Dictionary, with_plan: bool = true) -> void:
	code = str(cfg.get("code", ""))
	deal_seed = int(cfg.get("deal_seed", cfg.get("seed", 1)))
	shard_hero = str(cfg.get("shard", ""))
	face0.fill(0)
	step0.fill(0)
	gold0.fill(0)
	ice0.fill(0)
	secret0.fill(0)
	shard0.fill(0)
	kind.fill(0)
	arg.fill(0)
	mate.fill(-1)
	rng = TWRng.make(deal_seed, 2)
	var r: = TWRng.make(deal_seed, 1)
	_deal(cfg, r)
	var plan: Dictionary = cfg.get("plan", cfg.get("v10_plan", {})) if with_plan else {}
	if not plan.is_empty():
		_specials(plan, r)
	reset()


# the combo counter after a pair at time `tnow`: continues inside the window, else starts again at 1
static func next_combo(combo_: int, last: float, tnow: float, window: float) -> int:
	return combo_ + 1 if tnow - last < window else 1


# a Path level with its payload (lv.v10 from V10LevelGen.build); the layout must match the payload
static func from_level(lv: Dictionary) -> TWBoard:
	var p: Dictionary = lv.v10
	var fp: PackedInt32Array = p.pos
	var positions: = []
	for k in int(p.n):
		positions.append(Vector3i(fp[3 * k], fp[3 * k + 1], fp[3 * k + 2]))
	var b: = from_positions(positions, int(lv.get("slots", 4)))
	b.code = str(lv.get("code", ""))
	b.deal_seed = int(lv.get("seed", 1))
	b.shard_hero = str(lv.get("shard", ""))
	b.rng = TWRng.make(b.deal_seed, 2)
	b.face0 = (p.face as PackedInt32Array).duplicate()
	b.step0 = (p.step as PackedInt32Array).duplicate()
	b.gold0 = (p.gold as PackedByteArray).duplicate()
	b.ice0 = (p.ice as PackedByteArray).duplicate()
	b.secret0 = (p.secret as PackedByteArray).duplicate()
	b.shard0 = (p.shard as PackedByteArray).duplicate()
	for e in p.spec:
		var kd: int = int(e[2])
		for t in [int(e[0]), int(e[1])]:
			b.kind[t] = kd
			b.arg[t] = int(e[3])
			if kd == K_JOKER:
				b.face0[t] = JOKER
		b.mate[int(e[0])] = int(e[1])
		b.mate[int(e[1])] = int(e[0])
	b.cert = (p.cert as PackedInt32Array).duplicate() if p.has("cert") else PackedInt32Array()
	b.reset()
	return b


# ---- the deal: tray_board._assign with TWRng ----

# A random removal order: a free tile each step (a legal order to clear the table from the given counts).
func _removal_order(ids: Array, covc: PackedInt32Array, lc: PackedInt32Array, rc: PackedInt32Array, r: TWRng, respect_opened: bool) -> Array:
	var left: Array = ids.duplicate()
	var order: = []
	while not left.is_empty():
		var fr: = []
		for t in left:
			if (respect_opened and opened.size() == n and opened[t] == 1) or (covc[t] == 0 and not (lc[t] > 0 and rc[t] > 0)):
				fr.append(t)
		if fr.is_empty():
			fr = left
		var pick: int = fr[r.below(fr.size())]
		order.append(pick)
		left.erase(pick)
		for c in covers[pick]:
			covc[c] -= 1
		for t in lft_of[pick]:
			lc[t] -= 1
		for t in rgt_of[pick]:
			rc[t] -= 1
	return order


func _full_counts() -> Array:
	var covc: = PackedInt32Array()
	var lc: = PackedInt32Array()
	var rc: = PackedInt32Array()
	covc.resize(n)
	lc.resize(n)
	rc.resize(n)
	for i in n:
		covc[i] = (cov_by[i] as Array).size()
		lc[i] = (lft[i] as Array).size()
		rc[i] = (rgt[i] as Array).size()
	return [covc, lc, rc]


func _deal(cfg: Dictionary, r: TWRng) -> void:
	var nf: int = clampi(int(cfg.get("faces", 12)), 1, 36)
	var faces: Array = range(36)
	r.shuffle(faces)
	faces = faces.slice(0, nf)
	var ids: = []
	for i in n:
		ids.append(i)
	var cn: Array = _full_counts()
	var order: Array = _removal_order(ids, cn[0], cn[1], cn[2], r, false)
	var npairs: = n / 2
	cert = PackedInt32Array(order)
	for k in npairs:
		var a: int = order[2 * k]
		var b: int = order[2 * k + 1]
		face0[a] = faces[k % nf]
		face0[b] = face0[a]
		step0[a] = k
		step0[b] = k
	var sh: = str(cfg.get("shard", ""))
	var shard_k: = -1
	if sh != "" and npairs > 4:
		shard_k = npairs - 2 - r.below(3)
		for t in [order[2 * shard_k], order[2 * shard_k + 1]]:
			shard0[t] = 1
			face0[t] = SHARD_FACE
	var n_gold: int = int(cfg.get("gold", 0))
	if n_gold > 0:
		var cand: Array = []
		for k in npairs:
			if k != shard_k:
				cand.append(k)
		r.shuffle(cand)
		for q in mini(n_gold / 2, cand.size()):
			gold0[order[2 * cand[q]]] = 1
			gold0[order[2 * cand[q] + 1]] = 1
	var n_ice: = int(round(float(cfg.get("ice", 0)) * 1.5))
	if n_ice > 0:
		var ic: Array = []
		for t in order:
			if shard0[t] == 0 and gold0[t] == 0:
				ic.append(t)
		r.shuffle(ic)
		var top: Array = []
		var rest: Array = []
		for t in ic:
			if (cov_by[t] as Array).is_empty():
				top.append(t)
			else:
				rest.append(t)
		var n_top: = mini(top.size(), maxi(1, int(n_ice * 0.6)))
		for q in n_top:
			ice0[top[q]] = 1
		r.shuffle(rest)
		for q in mini(n_ice - n_top, rest.size()):
			ice0[rest[q]] = 1
	if bool(cfg.get("hidden", false)):
		for t in n:
			if not (cov_by[t] as Array).is_empty() and shard0[t] == 0 and ice0[t] == 0:
				secret0[t] = 1


# ---- the specials: V6SpecialBoard.apply_specials (plan keys: lock, lock_n, chain, joker, bomb, gift) ----

func _specials(p: Dictionary, r: TWRng) -> void:
	var by: = {}
	for t in n:
		by[step0[t]] = by.get(step0[t], []) + [t]
	var steps: Array = []
	for k in by:
		var pr: Array = by[k]
		if pr.size() == 2 and _ok_special(pr[0]) and _ok_special(pr[1]):
			steps.append(k)
	steps.sort()
	var npairs: = n / 2
	if npairs < 8 or steps.size() < 6:
		return
	var budget: = maxi(1, npairs / 3)
	var used: = {}
	var taken_kind: = {}
	var pick: = func(lo: float, hi: float, min_step: int = 0) -> int:
		var c: Array = steps.filter( func(k): return not used.has(k) and k >= min_step and k >= int(lo * npairs) and k <= int(hi * npairs))
		if c.is_empty():
			return -1
		var k: int = c[r.below(c.size())]
		used[k] = true
		return k
	var put: = func(k: int, kd: int, a: int = 0) -> void:
		var pr: Array = by[k]
		for t in pr:
			kind[t] = kd
			arg[t] = a
			taken_kind[t] = true
		mate[pr[0]] = pr[1]
		mate[pr[1]] = pr[0]
	for g in mini(int(p.get("lock", 0)), GROUPS):
		if budget < 2:
			break
		var kk: int = pick.call(0.05, 0.45)
		if kk < 0:
			break
		put.call(kk, K_KEY, g)
		budget -= 1
		for j in maxi(1, int(p.get("lock_n", 1))):
			var lk: int = pick.call(0.0, 0.95, kk + 3)
			if lk < 0:
				break
			put.call(lk, K_LOCK, g)
			budget -= 1
	for i in int(p.get("chain", 0)):
		if budget < 1:
			break
		var ck: int = pick.call(0.25, 0.9, 6)
		if ck < 0:
			break
		put.call(ck, K_CHAIN, clampi(int(ck * 0.5), 3, mini(ck - 2, 9)))
		budget -= 1
	for i in int(p.get("joker", 0)):
		if budget < 1:
			break
		for k in steps:
			if secret0[by[k][0]] == 1 or secret0[by[k][1]] == 1:
				used[k] = true
		var jk: int = pick.call(0.2, 0.8)
		for k in steps:
			if (secret0[by[k][0]] == 1 or secret0[by[k][1]] == 1) and k != jk and not taken_kind.has(by[k][0]):
				used.erase(k)
		if jk < 0:
			break
		put.call(jk, K_JOKER)
		for t in by[jk]:
			face0[t] = JOKER
		budget -= 1
	for i in int(p.get("bomb", 0)):
		if budget < 1:
			break
		var bk: int = pick.call(0.1, 0.7)
		if bk < 0:
			break
		put.call(bk, K_BOMB)
		budget -= 1
	for i in int(p.get("gift", 0)):
		if budget < 1:
			break
		var gk: int = pick.call(0.1, 0.95)
		if gk < 0:
			break
		put.call(gk, K_GIFT)
		budget -= 1


func _ok_special(t: int) -> bool:
	return shard0[t] == 0 and gold0[t] == 0 and ice0[t] == 0 and kind[t] == K_NONE and face0[t] < 36


# =================================================================== state

# back to the initial deal
func reset() -> void:
	present.resize(n)
	present.fill(1)
	alive.resize(n)
	alive.fill(1)
	covcnt.resize(n)
	lcnt.resize(n)
	rcnt.resize(n)
	for i in n:
		covcnt[i] = (cov_by[i] as Array).size()
		lcnt[i] = (lft[i] as Array).size()
		rcnt[i] = (rgt[i] as Array).size()
	face = face0.duplicate()
	step = step0.duplicate()
	gold = gold0.duplicate()
	ice = ice0.duplicate()
	sec = secret0.duplicate()
	shard_f = shard0.duplicate()
	kind_now = kind.duplicate()
	opened.resize(n)
	opened.fill(0)
	tray = PackedInt32Array()
	history = PackedInt32Array()
	taps = PackedInt32Array()
	key_open.resize(GROUPS)
	key_open.fill(0)
	pairs_done = 0
	unstuck = false
	on_board = n
	alive_n = n
	moves = 0
	combo = 0
	last_match = -10.0
	last_face = -1
	last_gift = false
	cracks = 0
	max_tray = 0
	failed = false
	cleared = false
	shuffled = false
	has_locks = false
	for i in n:
		if kind[i] == K_LOCK or kind[i] == K_CHAIN:
			has_locks = true
			break
	sec_left = 0
	for i in n:
		if sec[i] == 1:
			if is_free(i):
				sec[i] = 0
			else:
				sec_left += 1
	rng = TWRng.make(deal_seed, 2)


# Take the table a VIEW holds (per tile id: on the table / not matched / face / step / gold / ice / hidden / shard / forced free,
# plus the tray and the undo history as tile ids) as this board's state; the counters are rebuilt. A view whose tiles are changed
# from outside (skills, ults) calls this before every rule operation, so the rules never run on a stale copy.
func load_view(v: Dictionary) -> void:
	present = v.present
	alive = v.alive
	face = v.face
	step = v.step
	gold = v.gold
	ice = v.ice
	sec = v.sec
	shard_f = v.shard
	opened = v.opened
	tray = v.tray
	history = v.history
	covcnt.resize(n)
	covcnt.fill(0)
	lcnt.resize(n)
	lcnt.fill(0)
	rcnt.resize(n)
	rcnt.fill(0)
	on_board = 0
	alive_n = 0
	sec_left = 0
	for j in n:
		if alive[j] == 1:
			alive_n += 1
		if sec[j] == 1:
			sec_left += 1
		if present[j] == 1:
			on_board += 1
			for c in covers[j]:
				covcnt[c] += 1
			for t in lft_of[j]:
				lcnt[t] += 1
			for t in rgt_of[j]:
				rcnt[t] += 1
	failed = false
	cleared = false


func now() -> float:
	return float(clock.call()) if clock.is_valid() else time


# a new board sharing the topology, with the same deal in its initial state
func fork_fresh() -> TWBoard:
	var b: = TWBoard.new()
	b.slots = slots
	b.n = n
	b.pos = pos
	b.cov_by = cov_by
	b.covers = covers
	b.lft = lft
	b.rgt = rgt
	b.lft_of = lft_of
	b.rgt_of = rgt_of
	b.face0 = face0
	b.step0 = step0
	b.gold0 = gold0
	b.ice0 = ice0
	b.secret0 = secret0
	b.shard0 = shard0
	b.kind = kind
	b.arg = arg
	b.mate = mate
	b.shard_hero = shard_hero
	b.cert = cert
	b.code = code
	b.deal_seed = deal_seed
	b.combo_window = combo_window
	b.blasts = blasts
	b.reset()
	return b


func snapshot() -> Dictionary:
	return {"present": present.duplicate(), "alive": alive.duplicate(), "covcnt": covcnt.duplicate(), "lcnt": lcnt.duplicate(),
		"rcnt": rcnt.duplicate(), "face": face.duplicate(), "step": step.duplicate(), "gold": gold.duplicate(), "ice": ice.duplicate(),
		"sec": sec.duplicate(), "shard_f": shard_f.duplicate(), "kind_now": kind_now.duplicate(), "opened": opened.duplicate(),
		"tray": tray.duplicate(), "history": history.duplicate(), "taps": taps.duplicate(), "key_open": key_open.duplicate(),
		"pairs_done": pairs_done, "unstuck": unstuck, "on_board": on_board, "alive_n": alive_n, "sec_left": sec_left,
		"moves": moves, "combo": combo, "last_match": last_match, "last_face": last_face, "last_gift": last_gift, "cracks": cracks,
		"max_tray": max_tray, "failed": failed, "cleared": cleared, "shuffled": shuffled, "rng": rng.state}


func restore(s: Dictionary) -> void:
	present = (s.present as PackedByteArray).duplicate()
	alive = (s.alive as PackedByteArray).duplicate()
	covcnt = (s.covcnt as PackedInt32Array).duplicate()
	lcnt = (s.lcnt as PackedInt32Array).duplicate()
	rcnt = (s.rcnt as PackedInt32Array).duplicate()
	face = (s.face as PackedInt32Array).duplicate()
	step = (s.step as PackedInt32Array).duplicate()
	gold = (s.gold as PackedByteArray).duplicate()
	ice = (s.ice as PackedByteArray).duplicate()
	sec = (s.sec as PackedByteArray).duplicate()
	shard_f = (s.shard_f as PackedByteArray).duplicate()
	kind_now = (s.kind_now as PackedByteArray).duplicate()
	opened = (s.opened as PackedByteArray).duplicate()
	tray = (s.tray as PackedInt32Array).duplicate()
	history = (s.history as PackedInt32Array).duplicate()
	taps = (s.taps as PackedInt32Array).duplicate()
	key_open = (s.key_open as PackedByteArray).duplicate()
	pairs_done = int(s.pairs_done)
	unstuck = bool(s.unstuck)
	on_board = int(s.on_board)
	alive_n = int(s.alive_n)
	sec_left = int(s.sec_left)
	moves = int(s.moves)
	combo = int(s.combo)
	last_match = float(s.last_match)
	last_face = int(s.last_face)
	last_gift = bool(s.last_gift)
	cracks = int(s.cracks)
	max_tray = int(s.max_tray)
	failed = bool(s.failed)
	cleared = bool(s.cleared)
	shuffled = bool(s.shuffled)
	rng.state = int(s.rng)


# one int over everything that decides the game (not the clock, not the combo)
func state_hash() -> int:
	var h: = TWRng.FNV_BASIS
	h = TWRng.fnv(h, n)
	for i in n:
		var flags: = present[i] | (alive[i] << 1) | (sec[i] << 2) | (gold[i] << 3) | (shard_f[i] << 4) | (opened[i] << 5)
		h = TWRng.fnv(h, flags | (ice[i] << 8) | (kind_now[i] << 12))
		h = TWRng.fnv(h, face[i])
		h = TWRng.fnv(h, step[i])
	h = TWRng.fnv(h, tray.size())
	for t in tray:
		h = TWRng.fnv(h, t)
	for t in history:
		h = TWRng.fnv(h, t + 7919)
	for g in GROUPS:
		h = TWRng.fnv(h, key_open[g])
	h = TWRng.fnv(h, pairs_done)
	h = TWRng.fnv(h, 1 if unstuck else 0)
	h = TWRng.fnv(h, (1 if failed else 0) | (2 if cleared else 0))
	return h


# =================================================================== queries

func is_free(i: int) -> bool:
	return present[i] == 1 and (opened[i] == 1 or (covcnt[i] == 0 and not (lcnt[i] > 0 and rcnt[i] > 0)))


func takeable(i: int) -> bool:
	var k: = kind_now[i]
	if k == K_LOCK:
		return unstuck or key_open[arg[i]] == 1
	if k == K_CHAIN:
		return unstuck or pairs_done >= arg[i]
	return true


# on the table, free, and not held by a lock / chain: what a tap can act on (an ice tile counts: the tap flips it)
func free_tiles() -> PackedInt32Array:
	var out: = PackedInt32Array()
	for i in n:
		if is_free(i) and (not has_locks or takeable(i)):
			out.append(i)
	return out


# free tiles including locked / chained ones
func free_all() -> PackedInt32Array:
	var out: = PackedInt32Array()
	for i in n:
		if is_free(i):
			out.append(i)
	return out


func board_count() -> int:
	return on_board


func tray_faces() -> PackedInt32Array:
	var out: = PackedInt32Array()
	for t in tray:
		out.append(face[t])
	return out


func kinds() -> Array:
	var out: = []
	for i in n:
		if alive[i] == 1 and kind[i] != K_NONE:
			var nm: String = KIND_NAMES[kind[i]]
			if nm == "key":
				nm = "lock"
			if not out.has(nm):
				out.append(nm)
	return out


# the pair-to-be a tile makes: the twin in the tray, else -1
func tray_twin(i: int) -> int:
	for x in tray:
		if face[x] == face[i]:
			return x
	return -1


func best_move() -> int:
	return best_move_from(free_tiles())


# best_move over a given free list (a view that filters the free tiles by its own locks passes its list)
func best_move_from(fr: PackedInt32Array) -> int:
	if fr.is_empty():
		return -1
	if not tray.is_empty():
		for t in fr:
			if face[t] == JOKER:
				return t
	for t in fr:
		for x in tray:
			if face[x] == face[t]:
				return t
	var by_face: = {}
	for t in fr:
		by_face[face[t]] = by_face.get(face[t], []) + [t]
	var fk: Array = by_face.keys()
	fk.sort()
	for f in fk:
		if (by_face[f] as Array).size() >= 2:
			return by_face[f][0]
	var best: = -1
	var best_d: = 999
	for t in fr:
		for o in n:
			if o != t and present[o] == 1 and face[o] == face[t]:
				var d: = 0
				for c in cov_by[o]:
					if present[c] == 1:
						d += 1
				if d < best_d:
					best_d = d
					best = t
	return best if best >= 0 else fr[0]


# [tile] or [tile, its free twin on the table]: the glints of the hint; [] when there is no move
func hint() -> Array:
	return hint_from(free_tiles())


func hint_from(fr: PackedInt32Array) -> Array:
	var t: = best_move_from(fr)
	if t < 0:
		return []
	var out: = [t]
	for o in fr:
		if o != t and face[o] == face[t]:
			out.append(o)
			break
	return out


# the auto-player (V10LevelBoard.solver_move): the twin of a tray tile (same step), the next tile of the certificate while it
# is still valid, any tile with the tray's face, else the lowest step
func solver_move() -> int:
	return solver_move_from(free_tiles())


func solver_move_from(fr: PackedInt32Array, use_cert: bool = true) -> int:
	if fr.is_empty():
		return -1
	for x in tray:
		for t in fr:
			if face[t] == face[x] and step[t] == step[x]:
				return t
	if use_cert and not shuffled:
		for idx in cert:
			if present[idx] == 1:
				if fr.has(idx):
					return idx
				break
	for x in tray:
		for t in fr:
			if face[t] == face[x]:
				return t
	var best: = -1
	for t in fr:
		if best < 0 or step[t] < step[best]:
			best = t
	return best


# play the solver until the board is cleared, lost or stuck: {cleared, failed, taps, left}
func play_solver(max_taps: int = 2000) -> Dictionary:
	var guard: = 0
	while not cleared and not failed and guard < max_taps:
		guard += 1
		var t: = solver_move()
		if t < 0:
			break
		if tap(t).is_empty():
			break
	return {"cleared": cleared, "failed": failed, "taps": guard, "left": alive_n}


# =================================================================== tap

func tap(i: int) -> Array:
	var ev: Array = []
	if i < 0 or i >= n or present[i] == 0 or failed or cleared:
		return ev
	if not is_free(i):
		ev.append(E.make(E.DENY, {"id": i, "why": "covered"}))
		return ev
	if not takeable(i):
		ev.append(E.make(E.BLOCKED, {"id": i, "kind": KIND_NAMES[kind_now[i]]}))
		return ev
	taps.append(i)
	moves += 1
	if ice[i] > 0:
		ice[i] -= 1
		cracks += 1
		ev.append(E.make(E.ICE_CRACK, {"id": i, "left": ice[i]}))
		return ev
	var f: = face[i]
	# jokers pair with anything, tray first (V6SpecialBoard.tap)
	if f == JOKER:
		for x in tray:
			if face[x] != JOKER:
				face[i] = face[x]
				f = face[i]
				ev.append(E.make(E.JOKER, {"id": i, "face": f}))
				break
	elif tray_twin(i) < 0:
		for x in tray:
			if face[x] == JOKER:
				face[x] = f
				ev.append(E.make(E.JOKER, {"id": x, "face": f}))
				break
	var tw: = -1
	for k in tray.size():
		if face[tray[k]] == f:
			tw = k
			break
	_leave(i)
	if tw >= 0:
		var a: = tray[tw]
		tray.remove_at(tw)
		var hi: = history.find(a)
		if hi >= 0:
			history.remove_at(hi)
		_match(a, i, ev)
	else:
		tray.append(i)
		history.append(i)
		max_tray = maxi(max_tray, tray.size())
		ev.append(E.make(E.TO_TRAY, {"id": i, "slot": tray.size() - 1, "face": face[i]}))
		if tray.size() >= slots:
			failed = true
			ev.append(E.make(E.TRAY_FULL, {"tray": Array(tray)}))
			return ev
		if slots >= 4 and tray.size() == slots - 1:
			ev.append(E.make(E.TRAY_WARN, {"left": 1}))
		_reveal(ev)
		_unstick(ev)
	return ev


func _match(a: int, b: int, ev: Array) -> void:
	var tnow: = now()
	combo = next_combo(combo, last_match, tnow, combo_window)
	last_match = tnow
	last_face = face[a]
	last_gift = kind[a] == K_GIFT or kind[b] == K_GIFT
	var mid: = (TWFree.world(pos[a]) + TWFree.world(pos[b])) * 0.5
	ev.append(E.make(E.MATCH, {"a": a, "b": b, "face": face[a], "combo": combo, "gold": gold[a] == 1 or gold[b] == 1,
		"shard": shard_hero if (shard_f[a] == 1 or shard_f[b] == 1) else "", "gift": last_gift, "mid": mid}))
	_pair_gone(a, b, true, ev)
	_reveal(ev)
	_unstick(ev)
	_check_clear(ev)


func _check_clear(ev: Array) -> void:
	if alive_n == 0 and not cleared:
		cleared = true
		ev.append(E.make(E.CLEARED))


# a pair (a, b) left the game: counters, joker mates, keys, gifts, bombs, chains
func _pair_gone(a: int, b: int, by_match: bool, ev: Array) -> void:
	alive[a] = 0
	alive[b] = 0
	alive_n -= 2
	pairs_done += 1
	for pr in [[a, b], [b, a]]:
		var j: int = pr[0]
		var o: int = pr[1]
		if kind[j] == K_JOKER and kind[o] != K_JOKER:
			var m: = mate[j]
			if m >= 0 and alive[m] == 1 and face[m] == JOKER:
				face[m] = face[o]
				step[m] = step[o]
				kind_now[m] = K_NONE
				if shard_f[o] == 1:
					shard_f[m] = 1
					face[m] = SHARD_FACE
				ev.append(E.make(E.JOKER, {"id": m, "face": face[m]}))
	var key_t: = -1
	if kind[a] == K_KEY:
		key_t = a
	elif kind[b] == K_KEY:
		key_t = b
	if key_t >= 0:
		var g: = arg[key_t]
		if key_open[g] == 0:
			key_open[g] = 1
			var ids: = []
			for t in n:
				if kind_now[t] == K_LOCK and arg[t] == g and alive[t] == 1:
					ids.append(t)
			ev.append(E.make(E.UNLOCK, {"group": g, "ids": ids}))
	if kind[a] == K_GIFT or kind[b] == K_GIFT:
		ev.append(E.make(E.GIFT, {"a": a, "b": b}))
	for t in n:
		if kind_now[t] == K_CHAIN and alive[t] == 1 and arg[t] == pairs_done and t != a and t != b:
			ev.append(E.make(E.UNCHAIN, {"id": t}))
	if by_match and blasts and (kind[a] == K_BOMB or kind[b] == K_BOMB):
		_blast(a, b, ev)


# V6SpecialBoard._blast: up to 3 nearby pairs (table distance < 1.75 tiles from the bomb pair) go with it
func _blast(a: int, b: int, ev: Array) -> void:
	var ha: = TWFree.world(pos[a])
	var hb: = TWFree.world(pos[b])
	var cand: = []
	for t in n:
		if present[t] == 0 or shard_f[t] == 1:
			continue
		var h: = TWFree.world(pos[t])
		var d: = minf((h - ha).length(), (h - hb).length())
		if d < TWFree.TW * 1.75:
			cand.append([d - pos[t].z * 30.0, t])
	cand.sort_custom( func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	var taken: = {}
	var prs: = []
	for c in cand:
		if prs.size() >= 3:
			break
		var t: int = c[1]
		if taken.has(t):
			continue
		var twin: = -1
		for o in n:
			if o != t and alive[o] == 1 and step[o] == step[t] and face[o] == face[t] and not taken.has(o) and o != a and o != b:
				twin = o
				break
		if twin < 0:
			continue
		taken[t] = true
		taken[twin] = true
		prs.append([t, twin])
	var mid: = (ha + hb) * 0.5
	ev.append(E.make(E.BLAST, {"at": [a, b], "pairs": prs, "mid": mid}))
	for pr in prs:
		for t in pr:
			var ti: = tray.find(t)
			if ti >= 0:
				tray.remove_at(ti)
				var hi: = history.find(t)
				if hi >= 0:
					history.remove_at(hi)
			elif present[t] == 1:
				_leave(t)
		_pair_gone(pr[0], pr[1], false, ev)


# V6SpecialBoard.unstick: nothing takeable is left on the table, so every lock and chain opens (no softlock)
func _unstick(ev: Array) -> void:
	if not has_locks or unstuck or on_board == 0:
		return
	if not free_tiles().is_empty():
		return
	var any: = false
	for t in n:
		if alive[t] == 1 and ((kind_now[t] == K_LOCK and key_open[arg[t]] == 0) or (kind_now[t] == K_CHAIN and pairs_done < arg[t])):
			any = true
			break
	unstuck = true
	if any:
		ev.append(E.make(E.UNSTICK))


# secret tiles that became free show their faces: the REVEAL events
func reveal_events() -> Array:
	var ev: Array = []
	_reveal(ev)
	return ev


func _reveal(ev: Array) -> void:
	if sec_left <= 0:
		return
	for i in n:
		if sec[i] == 1 and is_free(i):
			sec[i] = 0
			sec_left -= 1
			ev.append(E.make(E.REVEAL, {"id": i}))


func _leave(j: int) -> void:
	present[j] = 0
	on_board -= 1
	for c in covers[j]:
		covcnt[c] -= 1
	for t in lft_of[j]:
		lcnt[t] -= 1
	for t in rgt_of[j]:
		rcnt[t] -= 1


func _enter(j: int) -> void:
	present[j] = 1
	on_board += 1
	for c in covers[j]:
		covcnt[c] += 1
	for t in lft_of[j]:
		lcnt[t] += 1
	for t in rgt_of[j]:
		rcnt[t] += 1


# =================================================================== undo, rescue, shuffle

# the last tile that went to the tray goes back to its place; [] when there is nothing to undo
func undo() -> Array:
	var ev: Array = []
	if history.is_empty():
		return ev
	var t: = history[history.size() - 1]
	history.remove_at(history.size() - 1)
	var ti: = tray.find(t)
	if ti >= 0:
		tray.remove_at(ti)
	_enter(t)
	failed = false
	ev.append(E.make(E.UNDO, {"id": t}))
	_reveal(ev)
	return ev


# the rescue: the last k tray tiles go back to the table and the round goes on
func return_tray(k: int = 3) -> Array:
	var ev: Array = []
	var ids: = []
	for q in mini(k, tray.size()):
		var t: = tray[tray.size() - 1]
		tray.remove_at(tray.size() - 1)
		var hi: = history.find(t)
		if hi >= 0:
			history.remove_at(hi)
		_enter(t)
		ids.append(t)
	if ids.is_empty():
		return ev
	failed = false
	ev.append(E.make(E.RETURN, {"ids": ids}))
	_reveal(ev)
	return ev


# tray_board.reassign_faces + V6SpecialBoard.shuffle_board: the faces of the table (not shards, not jokers) are dealt again
# from a removal order of the CURRENT table, so the new deal is solvable; tray tiles keep a twin on the table
func shuffle(r: TWRng = null) -> Array:
	var ts: Array = []
	for t in n:
		if present[t] == 1 and shard_f[t] == 0 and face[t] != JOKER:
			ts.append(t)
	return reassign(ts, r)


# deal the faces of the given tiles (ids on the table) again, solvable from the current table
func reassign(ts: Array, r: TWRng = null) -> Array:
	var ev: Array = []
	if r == null:
		r = rng
	if ts.is_empty():
		return ev
	var mine: = {}
	for t in ts:
		mine[t] = true
	var ids: Array = []
	for t in n:
		if present[t] == 1:
			ids.append(t)
	var covc: = covcnt.duplicate()
	var lc: = lcnt.duplicate()
	var rc: = rcnt.duplicate()
	var order: Array = _removal_order(ids, covc, lc, rc, r, true)
	var cnt: = {}
	for t in ts:
		cnt[face[t]] = cnt.get(face[t], []) + [gold[t] == 1]
	var top_step: = 0
	for t in n:
		top_step = maxi(top_step, step[t])
	var plan: = []
	for x in tray:
		if cnt.has(face[x]) and not (cnt[face[x]] as Array).is_empty():
			plan.append([face[x], (cnt[face[x]] as Array).pop_back(), step[x]])
	var prs: = []
	var odd: = []
	var fkeys: Array = cnt.keys()
	fkeys.sort()
	for f in fkeys:
		var gs: Array = cnt[f]
		gs.sort_custom( func(a, b): return int(a) < int(b))   # gold tiles last: they pair with each other first
		while gs.size() >= 2:
			var g1: bool = gs.pop_back()
			var g2: bool = gs.pop_back()
			prs.append([f, g1 and g2])
		for g in gs:
			odd.append([f, g])
	r.shuffle(prs)
	for pr in prs:
		top_step += 1
		plan.append([pr[0], pr[1], top_step])
		plan.append([pr[0], pr[1], top_step])
	for o in odd:
		top_step += 1
		plan.append([o[0], o[1], top_step])
	var k: = 0
	for t in order:
		if not mine.has(t) or k >= plan.size():
			continue
		var p: Array = plan[k]
		k += 1
		face[t] = p[0]
		gold[t] = 1 if p[1] else 0
		step[t] = p[2]
	shuffled = true
	ev.append(E.make(E.SHUFFLE, {"ids": ts}))
	_reveal(ev)
	return ev


# =================================================================== ults and skills (tray_board.auto_pairs / hack_deepest / moonlight)

# the pairs lying on the table: by step when both tiles agree, else by face; earliest step first
func pairs_on_board() -> Array:
	var by: = {}
	for t in n:
		if present[t] == 1 and shard_f[t] == 0:
			by[step[t]] = by.get(step[t], []) + [t]
	var out: = []
	var single: = {}
	var sk: Array = by.keys()
	sk.sort()
	for k in sk:
		var g: Array = by[k]
		if g.size() == 2 and face[g[0]] == face[g[1]]:
			out.append(g)
		else:
			for t in g:
				single[face[t]] = single.get(face[t], []) + [t]
	var fk: Array = single.keys()
	fk.sort()
	for f in fk:
		var g: Array = single[f]
		for i in range(0, g.size() - 1, 2):
			out.append([g[i], g[i + 1]])
	out.sort_custom( func(x, y):
		var kx: = mini(step[x[0]], step[x[1]])
		var ky: = mini(step[y[0]], step[y[1]])
		return kx < ky or (kx == ky and x[0] < y[0]))
	return out


func _vanish(a: int, b: int, ev: Array) -> void:
	_leave(a)
	_leave(b)
	last_face = face[a]
	last_gift = false
	ev.append(E.make(E.VANISH, {"a": a, "b": b, "face": face[a], "mid": (TWFree.world(pos[a]) + TWFree.world(pos[b])) * 0.5}))
	_pair_gone(a, b, false, ev)
	_reveal(ev)
	_unstick(ev)


func vanish_pairs(k: int) -> Array:
	var ev: Array = []
	if failed or cleared:
		return ev
	for q in k:
		var ps: = pairs_on_board()
		if ps.is_empty():
			break
		_vanish(ps[0][0], ps[0][1], ev)
	_check_clear(ev)
	return ev


func hack_deepest() -> Array:
	var ev: Array = []
	if failed or cleared:
		return ev
	var ps: = pairs_on_board()
	if ps.is_empty():
		return ev
	var best: Array = ps[ps.size() - 1]
	_vanish(best[0], best[1], ev)
	_check_clear(ev)
	return ev


func moonlight() -> Array:
	var ev: Array = []
	var shown: = []
	var thawed: = []
	for t in n:
		if alive[t] == 1 and sec[t] == 1:
			sec[t] = 0
			sec_left -= 1
			shown.append(t)
		if alive[t] == 1 and ice[t] > 0:
			ice[t] = 0
			thawed.append(t)
	ev.append(E.make(E.MOONLIGHT, {"revealed": shown, "thawed": thawed}))
	return ev


func open_tile(i: int) -> Array:
	var ev: Array = []
	if i < 0 or i >= n or present[i] == 0:
		return ev
	opened[i] = 1
	_reveal(ev)
	return ev


# =================================================================== certificate

func certificate() -> PackedInt32Array:
	return cert


# Replay a take order (tile ids) on a fresh fork of this deal, without blasts (as V10LevelSim): {} on success or {why, at}.
func verify_certificate(order: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	if order.is_empty():
		order = cert
	var b: = fork_fresh()
	b.blasts = false
	for k in order.size():
		var t: = order[k]
		if t < 0 or t >= b.n or b.present[t] == 0:
			return {"why": "tile %d gone" % t, "at": k}
		if not b.is_free(t):
			return {"why": "tile %d not free" % t, "at": k}
		if not b.takeable(t):
			return {"why": "tile %d locked" % t, "at": k}
		while b.ice[t] > 0:
			b.tap(t)
		b.tap(t)
		if b.failed:
			return {"why": "tray overflow", "at": k}
	if not b.cleared:
		return {"why": "board not clear (%d left)" % b.alive_n, "at": order.size()}
	return {}


# the replay log of the game so far: the deal (code, seed) and every tap that did something
func export_replay() -> Dictionary:
	return {"code": code, "seed": deal_seed, "taps": Array(taps)}


# apply a replay log to this board (reset first); returns every event in order
func play_replay(log: Array) -> Array:
	reset()
	var ev: Array = []
	for t in log:
		ev.append_array(tap(int(t)))
	return ev
