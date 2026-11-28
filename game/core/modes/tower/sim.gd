class_name V10TowerSim
extends RefCounted

# Headless table model for the tower track: the same layout as the game (TrayBoard.gen_layout, reused as is),
# the same «free» rule as TrayBoard._free_if, and a deal with the same algorithm as TrayBoard._assign
# but from a seeded stream (V10TowerUtil.rng), so a seed always gives the same table.
#
#   var b := V10TowerSim.deal(cfg)          -> SimBoard (tiles, faces, steps, ice, secret)
#   V10TowerSim.step_order_ok(b)            -> true when the table clears in step order (the existing
#                                              TrayBoard.solver_move path): proves the table is solvable
#   V10TowerSim.play(b, rules, skill, rng, opts) -> {cleared, lives, overflows, timeouts, taps, secs, pairs, max_combo}
#
# The bot plays like a player who sees the table: no hints, no boosters, no ult (spec Ф4: V10Bot uses no helps).
# skill: "expert" (sees every face that is face up, plans by the twin's depth), "casual" (sees only free faces,
# a third of its picks are careless), "novice" (half careless).
# When V10Seed / V10Bot (spec Ф4, track A+I) land, deal() should switch to V10Seed streams and play() can be
# replaced by V10Bot; the API here is kept narrow for that.

const U: = preload("res://core/modes/tower/tower_util.gd")
const M: = preload("res://core/modes/tower/mods.gd")

const SKILL: = {
	"expert": {"careless": 0.0, "miss_pair": 0.0, "sees_covered": true, "tap": 1.0, "think": 0.35, "plan": true},
	"casual": {"careless": 0.33, "miss_pair": 0.12, "sees_covered": false, "tap": 1.35, "think": 0.8},
	"novice": {"careless": 0.5, "miss_pair": 0.25, "sees_covered": false, "tap": 1.7, "think": 1.2},
}
const TIME_REFILL: = 0.5  # hourglass: after a time-out the clock refills to half
const COMBO_WINDOW: = 5.0

class SimBoard extends RefCounted:
	var pos: Array = []           # Vector3i per tile, sorted like TrayBoard.setup
	var n: = 0
	var cov: Array = []           # PackedInt32Array: tiles covering i
	var left: Array = []          # PackedInt32Array
	var right: Array = []
	var under: Array = []         # PackedInt32Array: tiles that i covers (reverse of cov)
	var face: PackedInt32Array
	var step: PackedInt32Array
	var ice: PackedInt32Array
	var secret: PackedByteArray
	var gold: PackedByteArray
	var opened: PackedByteArray
	var present: PackedByteArray  # on the table (not taken, not in the tray)
	var cfg: = {}

	func free_i(i: int) -> bool:
		if opened[i] == 1:
			return true
		for o in cov[i]:
			if present[o] == 1:
				return false
		var l: = false
		for o in left[i]:
			if present[o] == 1:
				l = true
				break
		if not l:
			return true
		for o in right[i]:
			if present[o] == 1:
				return false
		return true

	func free_list() -> Array:
		var out: = []
		for i in n:
			if present[i] == 1 and free_i(i):
				out.append(i)
		return out

	func count() -> int:
		var c: = 0
		for i in n:
			c += present[i]
		return c

	# for V10Mods.on_start: [{i, step, free, covered, secret, x, y}]
	func describe() -> Array:
		var out: = []
		for i in n:
			out.append({"i": i, "step": step[i], "free": free_i(i), "covered": not (cov[i] as PackedInt32Array).is_empty(),
				"secret": secret[i] == 1, "x": pos[i].x, "y": pos[i].y})
		return out

static func _covers(o: Vector3i, t: Vector3i) -> bool:
	return o.z > t.z and absi(o.x - t.x) < 2 and absi(o.y - t.y) < 2

# the layout of TrayBoard.setup: gen_layout, drop the first highest tile when odd, sort, covers and sides
static func layout(cfg: Dictionary) -> SimBoard:
	var b: = SimBoard.new()
	b.cfg = cfg
	var pos: Array = TrayBoard.gen_layout(cfg)
	if pos.size() % 2 == 1:
		var top: = 0
		for i in pos.size():
			if pos[i].z > pos[top].z:
				top = i
		pos.remove_at(top)
	pos.sort_custom(func(a, c): return a.z * 100000 + a.y * 100 + a.x < c.z * 100000 + c.y * 100 + c.x)
	b.pos = pos
	b.n = pos.size()
	for i in b.n:
		var me: Vector3i = pos[i]
		var cv: = PackedInt32Array()
		var l: = PackedInt32Array()
		var r: = PackedInt32Array()
		for j in b.n:
			if j == i:
				continue
			var o: Vector3i = pos[j]
			if _covers(o, me):
				cv.append(j)
			if o.z == me.z and absi(o.y - me.y) < 2:
				if o.x - me.x == -2:
					l.append(j)
				elif o.x - me.x == 2:
					r.append(j)
		b.cov.append(cv)
		b.left.append(l)
		b.right.append(r)
	var und: = []
	for i in b.n:
		und.append([])
	for i in b.n:
		for j in b.cov[i]:
			und[j].append(i)
	for i in b.n:
		b.under.append(PackedInt32Array(und[i]))
	b.face.resize(b.n)
	b.step.resize(b.n)
	b.ice.resize(b.n)
	b.secret.resize(b.n)
	b.gold.resize(b.n)
	b.opened.resize(b.n)
	b.present.resize(b.n)
	for i in b.n:
		b.present[i] = 1
	return b

# TrayBoard._assign with a seeded stream: random free-order elimination, consecutive picks are pairs
static func deal(cfg: Dictionary) -> SimBoard:
	var b: = layout(cfg)
	var r: = U.rng(int(cfg.get("seed", 1)), "deal")
	var nf: int = maxi(1, int(cfg.get("faces", 10)))
	var faces: = range(36)
	U.shuffle(faces, r)
	faces = faces.slice(0, nf)
	var gone: = PackedByteArray()
	gone.resize(b.n)
	var order: = []
	var left_n: = b.n
	for i in b.n:
		b.present[i] = 1
	while left_n > 0:
		var fr: = b.free_list()
		var pick: int = fr[r.randi() % fr.size()]
		order.append(pick)
		b.present[pick] = 0
		left_n -= 1
	for i in b.n:
		b.present[i] = 1
	var npairs: = order.size() / 2
	for k in npairs:
		var a: int = order[2 * k]
		var c: int = order[2 * k + 1]
		b.face[a] = faces[k % nf]
		b.face[c] = faces[k % nf]
		b.step[a] = k
		b.step[c] = k
	var n_gold: = int(cfg.get("gold", 0))
	if n_gold > 0:
		var cand: = range(npairs)
		U.shuffle(cand, r)
		for i in mini(n_gold / 2, cand.size()):
			b.gold[order[2 * cand[i]]] = 1
			b.gold[order[2 * cand[i] + 1]] = 1
	var n_ice: = int(round(float(cfg.get("ice", 0)) * 1.5))
	if n_ice > 0:
		var ic: = order.filter(func(t): return b.gold[t] == 0)
		U.shuffle(ic, r)
		var top: = ic.filter(func(t): return (b.cov[t] as PackedInt32Array).is_empty())
		var rest: = ic.filter(func(t): return not (b.cov[t] as PackedInt32Array).is_empty())
		var n_top: = mini(top.size(), maxi(1, int(n_ice * 0.6)))
		for i in n_top:
			b.ice[top[i]] = 1
		U.shuffle(rest, r)
		for i in mini(n_ice - n_top, rest.size()):
			b.ice[rest[i]] = 1
	if bool(cfg.get("hidden", false)):
		for i in b.n:
			if not (b.cov[i] as PackedInt32Array).is_empty() and b.ice[i] == 0:
				b.secret[i] = 1
	return b

# Load faces / steps / ice / secret from a live TrayBoard (selftest: the real deal checked by the same model)
static func from_tray(tb: TrayBoard, cfg: Dictionary) -> SimBoard:
	var b: = layout(cfg)
	var idx: = {}
	for i in b.n:
		idx[b.pos[i]] = i
	for t in tb.tiles:
		var i: int = idx.get(Vector3i(t.gx, t.gy, t.gz), -1)
		if i < 0:
			return null
		b.face[i] = t.face
		b.step[i] = t.step
		b.ice[i] = t.ice
		b.secret[i] = 1 if t.secret else 0
		b.gold[i] = 1 if t.gold else 0
	return b

# solvable: removing the pairs in step order, both tiles of every pair are free when taken (and match)
static func step_order_ok(b: SimBoard) -> bool:
	var by: = {}
	for i in b.n:
		if b.present[i] == 1:
			by[b.step[i]] = by.get(b.step[i], []) + [i]
	var ks: = by.keys()
	ks.sort()
	var saved: = b.present.duplicate()
	var ok: = true
	for k in ks:
		var g: Array = by[k]
		if g.size() != 2 or b.face[g[0]] != b.face[g[1]]:
			ok = false
			break
		# either tile of the pair may go first (the first one waits in the tray)
		var x: int = g[0]
		var y: int = g[1]
		if not b.free_i(x):
			x = g[1]
			y = g[0]
		if not b.free_i(x):
			ok = false
			break
		b.present[x] = 0
		if not b.free_i(y):
			ok = false
			break
		b.present[y] = 0
	b.present = saved
	return ok

# lowest-step pair with both tiles on the table (TrayBoard._pairs_on_board / auto_pairs)
static func _auto_pair(b: SimBoard) -> bool:
	var by: = {}
	for i in b.n:
		if b.present[i] == 1:
			by[b.step[i]] = by.get(b.step[i], []) + [i]
	var best: = -1
	for k in by:
		var g: Array = by[k]
		if g.size() == 2 and b.face[g[0]] == b.face[g[1]] and (best < 0 or int(k) < best):
			best = int(k)
	if best < 0:
		return false
	for i in by[best]:
		b.present[i] = 0
	return true

# ---------------------------------------------------------------- the bot

# opts: {lives (default rules.lives), stop_on_overflow (Journey: a heart lost restarts the table), max_secs}
static func play(b: SimBoard, rules: Dictionary, skill: String, r: RandomNumberGenerator, opts: = {}) -> Dictionary:
	var sk: Dictionary = SKILL.get(skill, SKILL.casual)
	var slots: = int(rules.get("slots", 4))
	var lives: = int(opts.get("lives", rules.get("lives", 3)))
	var stop_ov: = bool(opts.get("stop_on_overflow", false))
	var fl: = {}
	var tray: = []
	var fog: = PackedByteArray()
	fog.resize(b.n)
	var fog_left: = 0
	var secs: = 0.0
	var taps: = 0
	var pairs: = 0
	var overflows: = 0
	var timeouts: = 0
	var combo: = 0
	var max_combo: = 0
	var last_match: = -99.0
	var cw: = COMBO_WINDOW + float(rules.get("combo_window", 0.0))
	var clock: = float(M.floor_time(rules, b.count()))
	var clock_full: = clock
	for op in M.on_start(rules, b.cfg, b.describe()):
		match String(op.op):
			"auto_pairs":
				for k in int(op.n):
					_auto_pair(b)
			"open":
				for i in op.tiles:
					b.opened[int(i)] = 1
			"shroud":
				for i in op.tiles:
					b.secret[int(i)] = 1
			"fog":
				for i in op.tiles:
					fog[int(i)] = 1
				fog_left = int(op.lift)
	var guard: = 0
	while b.count() > 0 or not tray.is_empty():
		guard += 1
		if guard > 4000:
			break
		var fr: = b.free_list()
		# reveal: a secret tile shows its face once free (TrayBoard.reveal_free)
		for i in fr:
			b.secret[i] = 0
		var pick: = _choose(b, fr, tray, slots, fog, sk, r)
		if pick < 0:
			break
		var dt: = float(sk.tap) + r.randf() * float(sk.think)
		secs += dt
		taps += 1
		if clock > 0.0:
			clock -= dt
			if clock <= 0.0:
				timeouts += 1
				lives -= 1
				if lives <= 0 or stop_ov:
					return _res(false, lives, overflows, timeouts, taps, secs, pairs, max_combo)
				clock = clock_full * TIME_REFILL
		if b.ice[pick] > 0:
			b.ice[pick] -= 1
			continue
		fog[pick] = 0
		b.present[pick] = 0
		var twin: = -1
		for x in tray:
			if b.face[x] == b.face[pick]:
				twin = x
				break
		if twin >= 0:
			tray.erase(twin)
			pairs += 1
			combo = combo + 1 if secs - last_match < cw else 1
			last_match = secs
			max_combo = maxi(max_combo, combo)
			for op in M.on_pair(rules, pairs):
				match String(op.op):
					"auto_pairs":
						_auto_pair(b)
					"fog_lift":
						for i in b.n:
							fog[i] = 0
			if fog_left > 0 and pairs >= fog_left:
				for i in b.n:
					fog[i] = 0
		else:
			tray.append(pick)
			if tray.size() >= slots:
				overflows += 1
				var ov: = M.on_overflow(rules, fl)
				if ov.lose_life:
					lives -= 1
					if lives <= 0 or stop_ov:
						return _res(false, lives, overflows, timeouts, taps, secs, pairs, max_combo)
				for k in mini(int(ov.return_n), tray.size()):
					var t: int = tray.pop_back()
					b.present[t] = 1
	var ok: = b.count() == 0 and tray.is_empty()
	return _res(ok, lives, overflows, timeouts, taps, secs, pairs, max_combo)

static func _res(ok: bool, lives: int, ov: int, to: int, taps: int, secs: float, pairs: int, mc: int) -> Dictionary:
	return {"cleared": ok, "lives": lives, "overflows": ov, "timeouts": to, "taps": taps, "secs": secs, "pairs": pairs, "max_combo": mc}

static func _seen(b: SimBoard, i: int, fog: PackedByteArray) -> bool:
	return b.secret[i] == 0 and b.ice[i] == 0 and fog[i] == 0

# how far a tile is from being free: present tiles over it, plus one when it is pinned on both sides
static func _depth(b: SimBoard, i: int) -> int:
	var d: = 0
	for o in b.cov[i]:
		if b.present[o] == 1:
			d += 1
	if d == 0 and not b.free_i(i):
		d = 1
	return d

static func _choose(b: SimBoard, fr: Array, tray: Array, slots: int, fog: PackedByteArray, sk: Dictionary, r: RandomNumberGenerator) -> int:
	if fr.is_empty():
		return -1
	var tray_faces: = {}
	for x in tray:
		tray_faces[b.face[x]] = true
	var seen: = fr.filter(func(i): return _seen(b, i, fog))
	# 1. a free tile that completes a pair in the tray
	for i in seen:
		if tray_faces.has(b.face[i]):
			return i
	# 2. two free tiles of one face (room for both)
	if tray.size() <= slots - 2 and r.randf() >= float(sk.miss_pair):
		var by: = {}
		for i in seen:
			if by.has(b.face[i]):
				return int(by[b.face[i]])
			by[b.face[i]] = i
	# 3. ice: cracking costs a tap, not a slot
	var iced: = fr.filter(func(i): return b.ice[i] > 0)
	if not iced.is_empty():
		return iced[0]
	# 4. a tile whose twin is closest to free, while one slot stays open
	var room: = tray.size() < slots - 1
	var cand: = seen.filter(func(i): return not tray_faces.has(b.face[i]))
	if room and not cand.is_empty() and bool(sk.get("plan", false)):
		return _plan(b, cand, tray, slots, fog)
	if room and not cand.is_empty():
		if r.randf() < float(sk.careless):
			return cand[r.randi() % cand.size()]
		var best: = -1
		var best_s: = 1 << 30
		var by_face: = {}
		for j in b.n:
			if b.present[j] == 1:
				if not by_face.has(b.face[j]):
					by_face[b.face[j]] = []
				by_face[b.face[j]].append(j)
		for i in cand:
			var s: = 1000
			for j in by_face.get(b.face[i], []):
				if j != i:
					var vis: = bool(sk.sees_covered) and b.secret[j] == 0 and fog[j] == 0
					var d: = _depth(b, j) if vis else 3
					s = mini(s, d * 10)
			# tie-break: a tile that frees others (b.under[i] = the tiles under it)
			var frees: = 0
			for j in b.under[i]:
				if b.present[j] == 1:
					frees += 1
			s -= frees
			if s < best_s:
				best_s = s
				best = i
		return best
	# 5. unknown faces (fog / face down but free): a gamble beats a certain overflow
	var unk: = fr.filter(func(i): return not _seen(b, i, fog) and b.ice[i] == 0)
	if not unk.is_empty():
		return unk[r.randi() % unk.size()]
	if room and not seen.is_empty():
		return seen[r.randi() % seen.size()]
	# forced: anything (an overflow)
	return fr[r.randi() % fr.size()]

# expert: one-move lookahead. Every candidate is tried and the table after it is scored: matches the tray can
# make at once, free pairs, free tiles, minus the tray load and how deep the tray's twins still are.
static func _plan(b: SimBoard, cand: Array, tray: Array, slots: int, fog: PackedByteArray) -> int:
	var best: = -1
	var best_s: = -1000000.0
	for c in cand:
		b.present[c] = 0
		var t2: = tray.duplicate()
		t2.append(c)
		var sc: = _eval(b, t2, fog)
		b.present[c] = 1
		if sc > best_s:
			best_s = sc
			best = c
	return best

static func _eval(b: SimBoard, tray: Array, fog: PackedByteArray) -> float:
	var fr: = b.free_list()
	var free_seen: = {}
	var nfree: = 0
	for i in fr:
		nfree += 1
		if b.ice[i] == 0 and fog[i] == 0:
			free_seen[b.face[i]] = int(free_seen.get(b.face[i], 0)) + 1
	var a: = 0
	var depth: = 0
	for x in tray:
		var f: = b.face[x]
		if int(free_seen.get(f, 0)) > 0:
			a += 1
			continue
		var dmin: = 6
		for j in b.n:
			if b.present[j] == 1 and b.face[j] == f:
				var d: = _depth(b, j) if (b.secret[j] == 0 and fog[j] == 0) else 3
				dmin = mini(dmin, d)
		depth += dmin
	var p: = 0
	for f in free_seen:
		if int(free_seen[f]) >= 2:
			p += 1
	return 12.0 * a + 5.0 * p + 1.0 * nfree - 4.0 * depth - 6.0 * tray.size()
