class_name V10MjClassicGen
extends RefCounted

# «Классика» generator, rules and bots — pure data, no nodes (the selftest and the board share it).
#
# Free rule (MODES §4.1): a tile is free when nothing lies on it (any higher tile closer than one tile in x and y —
# so the Turtle's half-offset crown covers the four under it) and its left OR right edge is open (a tile of the same
# layer exactly one tile to the side and overlapping in y blocks that edge; half-offset rows block both rows they
# touch).
#
# Reverse placement = certificate of solvability: start from an empty table and put the tiles down two at a time,
# each pair only onto positions that are free in the current partial stack (everything a tile rests on is already
# down, and an edge stays open). Taking the pairs back in the opposite order is then always legal, so a deal made
# this way can be cleared. Faces are given per certificate pair; four of a kind = two certificate pairs.
#
# Difficulty = share of «traps»: quads whose two certificate pairs lie in one column (a tile of one pair covers or is
# covered by a tile of the other: twins stacked over each other). easy 0 %, normal 20 %, master 45 %.

const TRAPS: = {"easy": 0.0, "normal": 0.20, "master": 0.45}


class Geo:
	extends RefCounted
	var n: = 0
	var pos: Array[Vector3i] = []
	var cover: Array = []   # [i] -> PackedInt32Array of tiles lying on i
	var below: Array = []   # [i] -> PackedInt32Array of tiles i lies on
	var left: Array = []
	var right: Array = []
	var col: Array = []     # [i] -> cover ∪ below (the «same column» relation of traps)

	func setup(p: Array[Vector3i]) -> void:
		pos = p
		n = p.size()
		for i in n:
			cover.append(PackedInt32Array())
			below.append(PackedInt32Array())
			left.append(PackedInt32Array())
			right.append(PackedInt32Array())
		for i in n:
			var a: = p[i]
			for j in n:
				if i == j:
					continue
				var b: = p[j]
				var dx: = b.x - a.x
				var dy: = b.y - a.y
				if absi(dx) < 2 and absi(dy) < 2:
					if b.z > a.z:
						cover[i].append(j)
					elif b.z < a.z:
						below[i].append(j)
				elif b.z == a.z and absi(dy) < 2:
					if dx == -2:
						left[i].append(j)
					elif dx == 2:
						right[i].append(j)
		for i in n:
			var c: = PackedInt32Array(cover[i])
			c.append_array(below[i])
			col.append(c)
		# rows: tiles of one layer chained by their edges (a half-offset tile joins the two rows it touches)
		comp.resize(n)
		for i in n:
			comp[i] = i
		for i in n:
			for j in right[i]:
				var ri: = _root(i)
				var rj: = _root(j)
				if ri != rj:
					comp[ri] = rj
		for i in n:
			comp[i] = _root(i)

	var comp: = PackedInt32Array()

	func _root(i: int) -> int:
		while comp[i] != i:
			comp[i] = comp[comp[i]]
			i = comp[i]
		return i

	func free_in(i: int, alive: PackedByteArray) -> bool:
		for j in cover[i]:
			if alive[j]:
				return false
		var l: = false
		for j in left[i]:
			if alive[j]:
				l = true
				break
		if not l:
			return true
		for j in right[i]:
			if alive[j]:
				return false
		return true

	# why a tile is closed (for the «show what blocks it» hint): the covering tiles, else both side neighbours
	func blockers(i: int, alive: PackedByteArray) -> PackedInt32Array:
		var out: = PackedInt32Array()
		for j in cover[i]:
			if alive[j]:
				out.append(j)
		if not out.is_empty():
			return out
		for j in left[i]:
			if alive[j]:
				out.append(j)
		for j in right[i]:
			if alive[j]:
				out.append(j)
		return out


static func geo(pos: Array[Vector3i]) -> Geo:
	var g: = Geo.new()
	g.setup(pos)
	return g


static func zeros(n: int) -> PackedByteArray:
	var a: = PackedByteArray()
	a.resize(n)
	a.fill(0)
	return a


static func ones(n: int) -> PackedByteArray:
	var a: = PackedByteArray()
	a.resize(n)
	a.fill(1)
	return a


# ---- reverse placement ----------------------------------------------------------------------------------------

static func _side_any(g: Geo, lst: PackedInt32Array, placed: PackedByteArray) -> bool:
	for j in lst:
		if placed[j]:
			return true
	return false


# placing `i` (already marked in `placed`) must not leave an unplaced neighbour with both edges shut: it could never
# be put down later as a free tile
static func _dooms(g: Geo, subset: PackedByteArray, placed: PackedByteArray, i: int) -> bool:
	for side in [g.left[i], g.right[i]]:
		for q in side:
			if subset[q] and not placed[q]:
				if _side_any(g, g.left[q], placed) and _side_any(g, g.right[q], placed):
					return true
	return false


# a row is built outward from one seed: a second seed in the same row would leave a gap whose last tile has both
# edges shut
static func _row_ok(g: Geo, placed: PackedByteArray, comp_n: Dictionary, i: int) -> bool:
	if int(comp_n.get(g.comp[i], 0)) == 0:
		return true
	return _side_any(g, g.left[i], placed) or _side_any(g, g.right[i], placed)


static func _ready_to_place(g: Geo, subset: PackedByteArray, placed: PackedByteArray, i: int) -> bool:
	if not subset[i] or placed[i]:
		return false
	for j in g.below[i]:
		if subset[j] and not placed[j]:
			return false
	return true


static func _touch_any(g: Geo, x: int, A: Array) -> bool:
	for t in A:
		if t in g.col[x] or g.comp[t] == g.comp[x]:
			return true
	return false


static func _covers_any(g: Geo, x: int, A: Array) -> bool:
	for t in A:
		if t in g.below[x]:
			return true
	return false


# plan (optional): per quad of two consecutive pairs, 1 = clean (the second pair touches the first neither in a
# column nor in a row), 2 = trap (a tile of the second pair lies on a tile of the first: twins in one column).
# Quads made of consecutive certificate pairs can be mismatched freely when clean: the twins left over are always
# taken together where the first pair would have been.
static func build_order(g: Geo, subset: PackedByteArray, rng: RandomNumberGenerator, tries: = 60, plan: = PackedByteArray()) -> PackedInt32Array:
	var members: = 0
	for i in g.n:
		if subset[i]:
			members += 1
	if members % 2 == 1 or members == 0:
		return PackedInt32Array()
	for attempt in tries:
		var placed: = zeros(g.n)
		var comp_n: = {}
		var order: = PackedInt32Array()
		var left_n: = members
		var ok: = true
		while left_n > 0:
			var cands: Array = []
			for i in g.n:
				if not _ready_to_place(g, subset, placed, i) or not _row_ok(g, placed, comp_n, i):
					continue
				placed[i] = 1
				var good: = g.free_in(i, placed) and not _dooms(g, subset, placed, i)
				placed[i] = 0
				if good:
					cands.append([float(g.pos[i].z) + rng.randf() * 1.6, i])
			if cands.size() < 2:
				ok = false
				break
			cands.sort_custom(func(x, y): return x[0] < y[0])
			var want: = 0
			var A: Array = []
			var pidx: = order.size() / 2
			if not plan.is_empty() and pidx % 2 == 1 and pidx / 2 < plan.size():
				want = plan[pidx / 2]
				A = [order[order.size() - 2], order[order.size() - 1]]
			var alist: Array = cands
			if want == 1:
				var good_c: = cands.filter(func(c): return not _touch_any(g, c[1], A))
				alist = good_c + cands.filter(func(c): return _touch_any(g, c[1], A))
			elif want >= 2:
				alist = cands.filter(func(c): return _covers_any(g, c[1], A)) + cands.filter(func(c): return not _covers_any(g, c[1], A))
			var done: = false
			var ta: = 0
			for ca in alist:
				ta += 1
				if ta > 10:
					break
				var a: int = ca[1]
				placed[a] = 1
				comp_n[g.comp[a]] = int(comp_n.get(g.comp[a], 0)) + 1
				var bl: Array = cands.duplicate()
				_shuffle(bl, rng)
				var ca_comp: int = g.comp[a]
				bl.sort_custom(func(x, y): return int(g.comp[x[1]] == ca_comp) < int(g.comp[y[1]] == ca_comp))
				if want == 1:
					bl = bl.filter(func(c): return not _touch_any(g, c[1], A)) + bl.filter(func(c): return _touch_any(g, c[1], A))
				elif want == 3:
					# both twins stacked: the second tile lies on the other tile of the first pair
					var rest_a: Array = A.filter(func(t): return not t in g.below[a])
					bl = bl.filter(func(c): return _covers_any(g, c[1], rest_a)) + bl.filter(func(c): return not _covers_any(g, c[1], rest_a))
				var tb: = 0
				for cb in bl:
					var b: int = cb[1]
					if b == a:
						continue
					tb += 1
					if tb > 14:
						break
					if not _ready_to_place(g, subset, placed, b) or not _row_ok(g, placed, comp_n, b):
						continue
					placed[b] = 1
					if g.free_in(a, placed) and g.free_in(b, placed) and not _dooms(g, subset, placed, a) and not _dooms(g, subset, placed, b):
						order.append(a)
						order.append(b)
						comp_n[g.comp[b]] = int(comp_n.get(g.comp[b], 0)) + 1
						done = true
						break
					placed[b] = 0
				if done:
					break
				placed[a] = 0
				comp_n[g.comp[a]] = int(comp_n[g.comp[a]]) - 1
			if not done:
				ok = false
				break
			left_n -= 2
		if ok:
			return order
	return PackedInt32Array()


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j: = rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# ---- faces ----------------------------------------------------------------------------------------------------

# a trap: twins in one column (a tile of one pair lies over a tile of the other)
static func _pair_conflict(g: Geo, order: PackedInt32Array, p: int, q: int) -> bool:
	for a in [order[2 * p], order[2 * p + 1]]:
		for b in [order[2 * q], order[2 * q + 1]]:
			if b in g.col[a]:
				return true
	return false


# a clean quad also keeps its four tiles out of one row (twins side by side lock each other's edges)
static func _pair_touch(g: Geo, order: PackedInt32Array, p: int, q: int) -> bool:
	if _pair_conflict(g, order, p, q):
		return true
	for a in [order[2 * p], order[2 * p + 1]]:
		for b in [order[2 * q], order[2 * q + 1]]:
			if g.comp[a] == g.comp[b]:
				return true
	return false


# -> {faces: PackedInt32Array (per position, -1 = no tile), keys, traps: int, quads: int}
# near: the two pairs of a kind are neighbours in the certificate (they come free together — four of a kind on top
# at once, nothing to guess: the easy deal)
static func assign(g: Geo, order: PackedInt32Array, rng: RandomNumberGenerator, trap_frac: float, near: = false) -> Dictionary:
	var m: = order.size() / 2
	var nq: = m / 2
	var want: = int(round(trap_frac * nq))
	var best: = {}
	for attempt in 12:
		var idx: Array = range(m)
		_shuffle(idx, rng)
		var used: = {}
		var quads: Array = []   # [p, q, trap]
		var traps: = 0
		# traps first: twins in one column
		for p in idx:
			if traps >= want:
				break
			if used.has(p):
				continue
			var qs: Array = idx.duplicate()
			_shuffle(qs, rng)
			for q in qs:
				if q == p or used.has(q):
					continue
				if _pair_conflict(g, order, p, q):
					used[p] = true
					used[q] = true
					quads.append([p, q, true])
					traps += 1
					break
		var rest: Array = idx.filter(func(p): return not used.has(p))
		var accidental: = 0
		if near:
			rest.sort()
			rest.reverse()
		while rest.size() >= 2:
			var p: int = rest.pop_back()
			var pick: = -1
			for k in range(rest.size() - 1, -1, -1):
				# easy / normal: a clean quad (no column, no row twins); master: row twins welcome
				if _pair_touch(g, order, p, rest[k]) != near:
					pick = k
					break
			if pick < 0 and not near:
				pick = rest.size() - 1
			if pick < 0:
				for k in range(rest.size() - 1, -1, -1):
					if not _pair_conflict(g, order, p, rest[k]):
						pick = k
						break
			if pick < 0:
				pick = rest.size() - 1
				accidental += 1
			var q: int = rest[pick]
			rest.remove_at(pick)
			quads.append([p, q, _pair_conflict(g, order, p, q)])
		var single: int = rest[0] if rest.size() == 1 else -1
		var res: = {"quads": quads, "single": single, "traps": traps + accidental}
		if best.is_empty() or abs(res.traps - want) < abs(best.traps - want):
			best = res
		if res.traps == want:
			break
	# faces: two clean quads become flowers and seasons (four different faces each, pair within the group)
	var faces: = PackedInt32Array()
	faces.resize(g.n)
	faces.fill(-1)
	var quads: Array = best.quads
	var regular: Array = V10MjClassicLayouts.regular_faces()
	_shuffle(regular, rng)
	var groups: Array = []
	if quads.size() >= 6:
		var clean: Array = []
		for k in quads.size():
			if not quads[k][2]:
				clean.append(k)
		_shuffle(clean, rng)
		for k in clean.slice(0, 2):
			groups.append(k)
	var ri: = 0
	var gi: = 0
	for k in quads.size():
		var q: Array = quads[k]
		var tiles: = [order[2 * q[0]], order[2 * q[0] + 1], order[2 * q[1]], order[2 * q[1] + 1]]
		if k in groups:
			var grp: Array = (V10MjClassicLayouts.FLOWERS if gi == 0 else V10MjClassicLayouts.SEASONS).duplicate()
			gi += 1
			_shuffle(grp, rng)
			for t in 4:
				faces[tiles[t]] = grp[t]
		else:
			var f: int = regular[ri % regular.size()]
			if ri >= regular.size() and near:
				# a face used twice (8 tiles): put the second quad where it never meets the first one
				for tryk in regular.size():
					var cand: int = regular[(ri + tryk) % regular.size()]
					if not _face_meets(g, faces, tiles, cand):
						f = cand
						break
			ri += 1
			for t in tiles:
				faces[t] = f
	if best.single >= 0:
		var f: int = regular[ri % regular.size()]
		faces[order[2 * best.single]] = f
		faces[order[2 * best.single + 1]] = f
	return {"faces": faces, "keys": keys_of(faces), "traps": best.traps, "quads": quads.size(), "want": want}


# faces for a structured certificate: quad j = pairs 2j and 2j+1 (consecutive). Two clean quads become flowers and
# seasons; when a form has more quads than regular faces, a face comes back only ~28 quads later in the certificate
# (the two never lie open together in practice).
static func assign_quads(g: Geo, order: PackedInt32Array, rng: RandomNumberGenerator) -> Dictionary:
	var m: = order.size() / 2
	var nq: = m / 2
	var faces: = PackedInt32Array()
	faces.resize(g.n)
	faces.fill(-1)
	var traps: = 0
	var clean: Array = []
	for j in nq:
		if _pair_conflict(g, order, 2 * j, 2 * j + 1):
			traps += 1
		elif not _pair_touch(g, order, 2 * j, 2 * j + 1):
			clean.append(j)
	var groups: Array = []
	if nq >= 6:
		_shuffle(clean, rng)
		groups = clean.slice(0, 2)
		if groups.size() < 2:
			var all_q: Array = range(nq)
			_shuffle(all_q, rng)
			for j in all_q:
				if groups.size() >= 2:
					break
				if not j in groups and not _pair_conflict(g, order, 2 * j, 2 * j + 1):
					groups.append(j)
	var regular: Array = V10MjClassicLayouts.regular_faces()
	_shuffle(regular, rng)
	var c: = 0
	var gi: = 0
	for j in nq:
		var tiles: = [order[4 * j], order[4 * j + 1], order[4 * j + 2], order[4 * j + 3]]
		if j in groups:
			var grp: Array = (V10MjClassicLayouts.FLOWERS if gi == 0 else V10MjClassicLayouts.SEASONS).duplicate()
			gi += 1
			_shuffle(grp, rng)
			for t in 4:
				faces[tiles[t]] = grp[t]
		else:
			var f: int = regular[c % regular.size()]
			c += 1
			for t in tiles:
				faces[t] = f
	if m % 2 == 1:
		var f2: int = regular[c % regular.size()]
		faces[order[2 * (m - 1)]] = f2
		faces[order[2 * (m - 1) + 1]] = f2
	return {"faces": faces, "keys": keys_of(faces), "traps": traps, "quads": nq}


static func _face_meets(g: Geo, faces: PackedInt32Array, tiles: Array, f: int) -> bool:
	for i in g.n:
		if faces[i] != f:
			continue
		for t in tiles:
			if i in g.col[t] or g.comp[i] == g.comp[t]:
				return true
	return false


static func keys_of(faces: PackedInt32Array) -> PackedInt32Array:
	var k: = PackedInt32Array()
	k.resize(faces.size())
	for i in faces.size():
		k[i] = V10MjClassicLayouts.match_key(faces[i]) if faces[i] >= 0 else -1
	return k


# the whole deal of a form: {pos, geo, order, faces, keys, traps, quads, diff, seed}
static func generate(form: Dictionary, seed_: int, diff: = "normal") -> Dictionary:
	var pos: Array[Vector3i] = form.pos
	var g: = geo(pos)
	var rng: = RandomNumberGenerator.new()
	rng.seed = seed_
	var nq: = g.n / 4
	var plan: = PackedByteArray()
	plan.resize(nq)
	plan.fill(0 if diff == "master" else 1)
	var want: = int(round(float(TRAPS.get(diff, 0.2)) * nq))
	var qi: Array = range(nq)
	_shuffle(qi, rng)
	for k in want:
		plan[qi[k]] = 3 if diff == "normal" else 2
	# the share of traps is the difficulty: rebuild a few times until the deal carries it (easy: none at all)
	var best: = {}
	for attempt in 8:
		var order: = build_order(g, ones(g.n), rng, 80, plan)
		if order.is_empty():
			order = build_order(g, ones(g.n), rng, 80)
		if order.is_empty():
			continue
		var a: = assign_quads(g, order, rng)
		a["order"] = order
		var err: = absi(int(a.traps) - want)
		if best.is_empty() or err < int(best.err):
			best = a
			best["err"] = err
		if err == 0 or (diff != "easy" and err <= maxi(1, nq / 20)):
			break
	if best.is_empty():
		push_error("V10MjClassicGen: no order for %s seed %d" % [form.get("id", "?"), seed_])
		return {}
	var a: = best
	var order: PackedInt32Array = best.order
	return {"pos": pos, "geo": g, "order": order, "faces": a.faces, "keys": a.keys, "traps": a.traps, "quads": a.quads,
		"want": want, "diff": diff, "seed": seed_, "form": String(form.get("id", ""))}


# reverse the certificate: every pair must be free and alike at its turn
static func certify(g: Geo, order: PackedInt32Array, keys: PackedInt32Array, alive0 = null) -> bool:
	var alive: PackedByteArray = ones(g.n) if alive0 == null else PackedByteArray(alive0)
	var m: = order.size() / 2
	for k in range(m - 1, -1, -1):
		var a: = order[2 * k]
		var b: = order[2 * k + 1]
		if not (alive[a] and alive[b]) or keys[a] != keys[b] or keys[a] < 0:
			return false
		if not (g.free_in(a, alive) and g.free_in(b, alive)):
			return false
		alive[a] = 0
		alive[b] = 0
	for i in g.n:
		if alive[i]:
			return false
	return true


static func free_list(g: Geo, alive: PackedByteArray) -> PackedInt32Array:
	var out: = PackedInt32Array()
	for i in g.n:
		if alive[i] and g.free_in(i, alive):
			out.append(i)
	return out


static func available_pairs(g: Geo, alive: PackedByteArray, keys: PackedInt32Array) -> Array:
	var fr: = free_list(g, alive)
	var by: = {}
	for i in fr:
		var k: = keys[i]
		if not by.has(k):
			by[k] = []
		by[k].append(i)
	var out: = []
	for k in by:
		var l: Array = by[k]
		for x in l.size():
			for y in range(x + 1, l.size()):
				out.append([l[x], l[y]])
	return out


static func count_alive(alive: PackedByteArray) -> int:
	var c: = 0
	for v in alive:
		c += v
	return c


# ---- shuffle that keeps the table solvable --------------------------------------------------------------------
# -> {alive, faces, keys, order, relocated}. The tiles left keep their faces (as a multiset); they are dealt again
# onto a fresh certificate built on the positions they occupy. If those positions cannot hold a clearable stack
# (two last tiles stacked in one column), the tiles move to the first positions of the original certificate.
static func reshuffle(g: Geo, alive: PackedByteArray, faces: PackedInt32Array, rng: RandomNumberGenerator, base_order: PackedInt32Array) -> Dictionary:
	var k: = count_alive(alive)
	var subset: = PackedByteArray(alive)
	var order: = build_order(g, subset, rng, 40)
	var relocated: = false
	if order.is_empty():
		relocated = true
		subset = zeros(g.n)
		order = base_order.slice(0, k)
		for i in order:
			subset[i] = 1
	var by: = {}
	for i in g.n:
		if alive[i]:
			var key: = V10MjClassicLayouts.match_key(faces[i])
			if not by.has(key):
				by[key] = []
			by[key].append(faces[i])
	var pairs: Array = []
	for key in by:
		var l: Array = by[key]
		_shuffle(l, rng)
		for x in range(0, l.size() - 1, 2):
			pairs.append([l[x], l[x + 1]])
	_shuffle(pairs, rng)
	var nf: = PackedInt32Array()
	nf.resize(g.n)
	nf.fill(-1)
	for p in order.size() / 2:
		nf[order[2 * p]] = pairs[p][0]
		nf[order[2 * p + 1]] = pairs[p][1]
	return {"alive": subset, "faces": nf, "keys": keys_of(nf), "order": order, "relocated": relocated}


# ---- solver (hint) and bots -----------------------------------------------------------------------------------

# a pair is «safe» when every tile of its kind still on the table is free: taking any two of them cannot lock the rest
static func _safe(g: Geo, alive: PackedByteArray, keys: PackedInt32Array, key: int, fr: PackedInt32Array) -> bool:
	var tot: = 0
	var fre: = 0
	for i in g.n:
		if alive[i] and keys[i] == key:
			tot += 1
	for i in fr:
		if keys[i] == key:
			fre += 1
	return tot == fre


static func _order_moves(g: Geo, alive: PackedByteArray, keys: PackedInt32Array, pairs: Array) -> Array:
	var fr: = free_list(g, alive)
	var scored: = []
	for p in pairs:
		var s: = 0.0
		if _safe(g, alive, keys, keys[p[0]], fr):
			s += 100.0
		s += g.pos[p[0]].z + g.pos[p[1]].z
		s += (g.cover[p[0]].size() + g.cover[p[1]].size()) * 0.0
		# freeing: tiles lying under or beside these two
		s += 0.5 * (g.below[p[0]].size() + g.below[p[1]].size())
		scored.append([s, p])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	return scored.map(func(x): return x[1])


# depth-first with memo; returns the move sequence (flat pairs) or empty if none found within `budget` states
static func solve(g: Geo, alive0: PackedByteArray, keys: PackedInt32Array, budget: = 4000) -> PackedInt32Array:
	var st: = {"left": budget, "seen": {}}
	var path: = PackedInt32Array()
	if _dfs(g, PackedByteArray(alive0), keys, st, path):
		return path
	return PackedInt32Array()


static func _dfs(g: Geo, alive: PackedByteArray, keys: PackedInt32Array, st: Dictionary, path: PackedInt32Array) -> bool:
	if count_alive(alive) == 0:
		return true
	if st.left <= 0:
		return false
	st.left -= 1
	var h: = alive.hex_encode()
	if st.seen.has(h):
		return false
	st.seen[h] = true
	var pairs: = available_pairs(g, alive, keys)
	if pairs.is_empty():
		return false
	var moves: = _order_moves(g, alive, keys, pairs)
	# a safe move needs no branching
	if _safe(g, alive, keys, keys[moves[0][0]], free_list(g, alive)):
		moves = [moves[0]]
	for p in moves.slice(0, 6):
		alive[p[0]] = 0
		alive[p[1]] = 0
		path.append(p[0])
		path.append(p[1])
		if _dfs(g, alive, keys, st, path):
			return true
		path.resize(path.size() - 2)
		alive[p[0]] = 1
		alive[p[1]] = 1
	return false


# a casual player: no undo, no shuffle. Takes an obvious pair (every tile of that kind is free) when she sees one;
# otherwise the pair that opens the most of the table, with some noise (she does not count tiles).
# -> {win, moves, left}
static func bot_play(g: Geo, alive0: PackedByteArray, keys: PackedInt32Array, rng: RandomNumberGenerator, see_safe: = 0.9, noise: = 1.5) -> Dictionary:
	var alive: = PackedByteArray(alive0)
	var moves: = 0
	while true:
		var left: = count_alive(alive)
		if left == 0:
			return {"win": true, "moves": moves, "left": 0}
		var pairs: = available_pairs(g, alive, keys)
		if pairs.is_empty():
			return {"win": false, "moves": moves, "left": left}
		var fr: = free_list(g, alive)
		var pick = null
		if rng.randf() < see_safe:
			var safe: = pairs.filter(func(p): return _safe(g, alive, keys, keys[p[0]], fr))
			if not safe.is_empty():
				pick = safe[rng.randi_range(0, safe.size() - 1)]
		if pick == null:
			var best: = -INF
			for p in pairs:
				var sc: = rng.randf() * noise
				for t in p:
					sc += 1.2 * g.pos[t].z
				for t in p:
					for j in g.below[t]:
						sc += 0.5 * alive[j]
					for j in g.left[t]:
						sc += 0.3 * alive[j]
					for j in g.right[t]:
						sc += 0.3 * alive[j]
				if sc > best:
					best = sc
					pick = p
		alive[pick[0]] = 0
		alive[pick[1]] = 0
		moves += 1
	return {}


# the same casual player, but she uses «Отмена» when stuck: depth-first over her own choices (casual order, ≤ 3
# alternatives per move), at most `budget` positions looked at. -> {win, nodes}
static func bot_play_undo(g: Geo, alive0: PackedByteArray, keys: PackedInt32Array, rng: RandomNumberGenerator, budget: = 400) -> Dictionary:
	var st: = {"left": budget, "seen": {}, "rng": rng}
	var ok: = _casual_dfs(g, PackedByteArray(alive0), keys, st)
	return {"win": ok, "nodes": budget - int(st.left)}


static func _casual_dfs(g: Geo, alive: PackedByteArray, keys: PackedInt32Array, st: Dictionary) -> bool:
	if count_alive(alive) == 0:
		return true
	if st.left <= 0:
		return false
	st.left -= 1
	var h: = alive.hex_encode()
	if st.seen.has(h):
		return false
	st.seen[h] = true
	var pairs: = available_pairs(g, alive, keys)
	if pairs.is_empty():
		return false
	var fr: = free_list(g, alive)
	var rng: RandomNumberGenerator = st.rng
	var scored: = []
	for p in pairs:
		var sc: = rng.randf() * 1.5
		if _safe(g, alive, keys, keys[p[0]], fr):
			sc += 100.0
		for t in p:
			for j in g.below[t]:
				sc += 0.5 * alive[j]
			for j in g.left[t]:
				sc += 0.3 * alive[j]
			for j in g.right[t]:
				sc += 0.3 * alive[j]
		scored.append([sc, p])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var tries: = 1 if scored[0][0] >= 100.0 else 4
	for k in mini(tries, scored.size()):
		var p: Array = scored[k][1]
		alive[p[0]] = 0
		alive[p[1]] = 0
		if _casual_dfs(g, alive, keys, st):
			return true
		alive[p[0]] = 1
		alive[p[1]] = 1
	return false
