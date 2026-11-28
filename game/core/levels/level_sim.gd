class_name V10LevelSim
extends RefCounted

# 0.10 levels: a compact, headless rules engine for the tray board (tray_board + V6SpecialBoard rules), used by the
# generator (removal orders), the verifier (certificate replay, independent DFS solver) and the difficulty bots.
#
# Rules mirrored from tray_board.gd / special_board.gd:
#  - a tile is free when no present tile covers it (higher z, |dx|<2, |dy|<2) and not both of its sides
#    (same z, dx = ±2, |dy|<2) are present; «present» = alive and not in the tray;
#  - tapping a free ice tile only flips it (one move, no tray slot);
#  - a free tile goes to the tray; if the tray holds the same face, both vanish (a pair);
#    if the tray reaches `slots` tiles, the round is lost;
#  - lock tiles are takeable after a key pair of their group is matched, chain tiles after N pairs are gone;
#    after a match (or a tile into the tray, V10LevelBoard.tap) with no free takeable tile left, every lock/chain
#    opens (V6SpecialBoard.unstick);
#  - jokers pair with anything (tray-first, as V6SpecialBoard.tap), and the other joker becomes the twin;
#  - the bomb blast (removes up to 3 nearby pairs) is NOT simulated: it only ever helps, so every verdict here is
#    conservative (a board solvable without blasts is solvable with them).

const JOKER: = 300
const K_NONE: = 0
const K_KEY: = 1
const K_LOCK: = 2
const K_CHAIN: = 3
const K_JOKER: = 4
const K_BOMB: = 5
const K_GIFT: = 6
const KIND_NAMES: = ["", "key", "lock", "chain", "joker", "bomb", "gift"]

const GW: = 18
const GH: = 24
const GZ: = 9

# --- topology ---
var n: = 0
var px: = PackedInt32Array()
var py: = PackedInt32Array()
var pz: = PackedInt32Array()
var cov_by: = []    # i -> Array of tiles covering i
var covers: = []    # j -> Array of tiles j covers
var lft: = []       # i -> left neighbours
var rgt: = []       # i -> right neighbours
var lft_of: = []    # j -> tiles that have j as a left neighbour
var rgt_of: = []
var _grid: = PackedInt32Array()

# --- content ---
var face0: = PackedInt32Array()
var ice0: = PackedByteArray()
var secret0: = PackedByteArray()
var kind: = PackedByteArray()
var arg: = PackedInt32Array()       # key/lock group, chain n
var mate: = PackedInt32Array()      # pair mate for specials (jokers)
var slots: = 4
var tag: = ""

# --- state ---
var present: = PackedByteArray()
var alive: = PackedByteArray()
var covcnt: = PackedInt32Array()
var lcnt: = PackedInt32Array()
var rcnt: = PackedInt32Array()
var face: = PackedInt32Array()
var ice: = PackedByteArray()
var sec: = PackedByteArray()
var kind_now: = PackedByteArray()
var tray: = PackedInt32Array()
var freel: = PackedInt32Array()     # free tiles (incremental, unordered)
var in_free: = PackedByteArray()
var free_since: = PackedInt32Array()  # generator bookkeeping: the take index from which a tile is free
var clock: = 0
var key_open: = PackedByteArray()
var pairs_done: = 0
var unstuck: = false
var on_board: = 0
var alive_n: = 0
var moves: = 0
var failed: = false
var has_locks: = false


# Build the topology from positions (Array of Vector3i in tray_board.setup order).
func build(positions: Array) -> void :
	n = positions.size()
	tag = ""
	px.resize(n)
	py.resize(n)
	pz.resize(n)
	if _grid.size() != GW * GH * GZ:
		_grid.resize(GW * GH * GZ)
	_grid.fill(-1)
	for i in n:
		var p: Vector3i = positions[i]
		px[i] = p.x
		py[i] = p.y
		pz[i] = p.z
		_grid[_cell(p.x, p.y, p.z)] = i
	cov_by = []
	covers = []
	lft = []
	rgt = []
	lft_of = []
	rgt_of = []
	cov_by.resize(n)
	covers.resize(n)
	lft.resize(n)
	rgt.resize(n)
	lft_of.resize(n)
	rgt_of.resize(n)
	for i in n:
		cov_by[i] = []
		covers[i] = []
		lft[i] = []
		rgt[i] = []
		lft_of[i] = []
		rgt_of[i] = []
	var maxz: = 0
	for i in n:
		maxz = maxi(maxz, pz[i])
	# layer z sits on the (z mod 2) lattice, so a tile dz layers up can only cover from the 4 diagonals (odd dz)
	# or straight above (even dz); grid coordinates stay inside the padded grid, no bounds checks needed
	for i in n:
		var x: = px[i]
		var y: = py[i]
		var z: = pz[i]
		for zz in range(z + 1, maxz + 1):
			if (zz - z) % 2 == 1:
				for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
					var o: = _grid[((zz * GH) + y + d.y + 3) * GW + x + d.x + 3]
					if o >= 0:
						cov_by[i].append(o)
						covers[o].append(i)
			else:
				var o2: = _grid[((zz * GH) + y + 3) * GW + x + 3]
				if o2 >= 0:
					cov_by[i].append(o2)
					covers[o2].append(i)
		for dy in 3:
			var l: = _at(x - 2, y + dy - 1, z)
			if l >= 0:
				lft[i].append(l)
				lft_of[l].append(i)
			var r: = _at(x + 2, y + dy - 1, z)
			if r >= 0:
				rgt[i].append(r)
				rgt_of[r].append(i)
	face0.resize(n)
	face0.fill(0)
	ice0.resize(n)
	ice0.fill(0)
	secret0.resize(n)
	secret0.fill(0)
	kind.resize(n)
	kind.fill(0)
	arg.resize(n)
	arg.fill(0)
	mate.resize(n)
	mate.fill(-1)


func _cell(x: int, y: int, z: int) -> int:
	return (z * GH + (y + 3)) * GW + (x + 3)


func _at(x: int, y: int, z: int) -> int:
	if x < -3 or y < -3 or z < 0 or x + 3 >= GW or y + 3 >= GH or z >= GZ:
		return -1
	return _grid[_cell(x, y, z)]


func reset() -> void :
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
	ice = ice0.duplicate()
	sec = secret0.duplicate()
	kind_now = kind.duplicate()
	tray = PackedInt32Array()
	key_open.resize(8)
	key_open.fill(0)
	pairs_done = 0
	unstuck = false
	on_board = n
	alive_n = n
	moves = 0
	failed = false
	has_locks = false
	for i in n:
		if kind[i] == K_LOCK or kind[i] == K_CHAIN:
			has_locks = true
			break
	freel = PackedInt32Array()
	in_free.resize(n)
	in_free.fill(0)
	free_since.resize(n)
	free_since.fill(0)
	clock = 0
	for i in n:
		if is_free(i):
			freel.append(i)
			in_free[i] = 1
			sec[i] = 0


func is_free(i: int) -> bool:
	return present[i] == 1 and covcnt[i] == 0 and not (lcnt[i] > 0 and rcnt[i] > 0)


func takeable(i: int) -> bool:
	var k: = kind_now[i]
	if k == K_LOCK:
		return unstuck or key_open[arg[i]] == 1
	if k == K_CHAIN:
		return unstuck or pairs_done >= arg[i]
	return true


func visible(i: int) -> bool:
	return sec[i] == 0 and ice[i] == 0


# free tiles that can be tapped right now
func moves_now() -> PackedInt32Array:
	if not has_locks or unstuck:
		return freel
	var out: = PackedInt32Array()
	for i in freel:
		if takeable(i):
			out.append(i)
	return out


func _touch(t: int) -> void :
	if in_free[t] == 0 and is_free(t):
		in_free[t] = 1
		freel.append(t)
		sec[t] = 0
		free_since[t] = clock


# take a tile off the board without tray logic (removal orders)
func remove(j: int) -> void :
	_leave(j)


func _leave(j: int) -> void :
	present[j] = 0
	on_board -= 1
	if in_free[j] == 1:
		in_free[j] = 0
		var k: = freel.find(j)
		if k >= 0:
			freel.remove_at(k)
	for c in covers[j]:
		covcnt[c] -= 1
		_touch(c)
	for t in lft_of[j]:
		lcnt[t] -= 1
		_touch(t)
	for t in rgt_of[j]:
		rcnt[t] -= 1
		_touch(t)


# Tap tile i (the caller makes sure it is free and takeable). Returns 2 = flipped, 1 = pair, 0 = to tray, -1 = lost.
func tap(i: int) -> int:
	moves += 1
	if ice[i] > 0:
		ice[i] -= 1
		return 2
	var f: = face[i]
	if f == JOKER:
		for x in tray:
			if face[x] != JOKER:
				face[i] = face[x]
				f = face[i]
				break
	else:
		var has: = false
		for x in tray:
			if face[x] == f:
				has = true
				break
		if not has:
			for x in tray:
				if face[x] == JOKER:
					face[x] = f
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
		_pair_gone(a, i)
		if on_board > 0 and has_locks and not unstuck and moves_now().is_empty():
			unstuck = true
		return 1
	tray.append(i)
	if tray.size() >= slots:
		failed = true
		return -1
	# V10LevelBoard.tap: a tile into the tray with no takeable free tile left opens every lock/chain (softlock guard)
	if on_board > 0 and has_locks and not unstuck and moves_now().is_empty():
		unstuck = true
	return 0


func _pair_gone(a: int, b: int) -> void :
	pairs_done += 1
	alive[a] = 0
	alive[b] = 0
	alive_n -= 2
	for pr in [[a, b], [b, a]]:
		var j: int = pr[0]
		var o: int = pr[1]
		if kind[j] == K_JOKER and kind[o] != K_JOKER:
			var m: = mate[j]
			if m >= 0 and alive[m] == 1 and face[m] == JOKER:
				face[m] = face[o]
				kind_now[m] = K_NONE
	for t in [a, b]:
		if kind[t] == K_KEY:
			key_open[arg[t]] = 1


func won() -> bool:
	return alive_n == 0


# ---------------------------------------------------------------- certificate

# Replay a take order (tile ids; ice tiles are flipped automatically). Returns {} on success or {why, at}.
func replay(order: PackedInt32Array) -> Dictionary:
	reset()
	for k in order.size():
		var t: = order[k]
		if present[t] == 0:
			return {"why": "tile %d gone" % t, "at": k}
		if not is_free(t):
			return {"why": "tile %d not free" % t, "at": k}
		if not takeable(t):
			return {"why": "tile %d locked" % t, "at": k}
		while ice[t] > 0:
			tap(t)
		if tap(t) < 0:
			return {"why": "tray overflow", "at": k}
	if not won():
		return {"why": "board not clear (%d left)" % alive_n, "at": order.size()}
	return {}


# ---------------------------------------------------------------- bots

# profile: 0 random-legal, 1 novice, 2 regular, 3 expert. Returns {win, moves, holds, branch_sum, branch_n, max_tray}
func playout(rng: RandomNumberGenerator, profile: int) -> Dictionary:
	reset()
	var holds: = 0
	var bsum: = 0
	var bn: = 0
	var maxt: = 0
	var noise: float = [0.0, 1.6, 0.7, 0.22][profile]
	var guard: = n * 3 + 10
	while alive_n > 0 and guard > 0:
		guard -= 1
		var mv: = moves_now()
		if mv.is_empty():
			break
		var pick: = -1
		# flips first: free information
		for t in mv:
			if ice[t] > 0:
				pick = t
				break
		if pick >= 0:
			tap(pick)
			continue
		# a tile that pairs with the tray
		var tray_joker: = false
		var tray_real: = false
		for x in tray:
			if face[x] == JOKER:
				tray_joker = true
			else:
				tray_real = true
		for t in mv:
			var f: = face[t]
			if f == JOKER and tray_real:
				pick = t
				break
			for x in tray:
				if face[x] == f:
					pick = t
					break
			if pick >= 0:
				break
		if pick < 0 and tray_joker:
			pick = _choose(mv, rng, noise, profile)
		if pick >= 0:
			tap(pick)
			continue
		if tray.size() > slots - 2:
			break
		# a pair lying free on the board
		if profile != 0:
			var seen_f: = {}
			for t in mv:
				if seen_f.has(face[t]):
					pick = t
					break
				seen_f[face[t]] = true
		if pick < 0:
			bsum += mv.size()
			bn += 1
			holds += 1
			if profile == 0:
				pick = mv[rng.randi() % mv.size()]
			else:
				pick = _choose(mv, rng, noise, profile)
		if tap(pick) < 0:
			break
		maxt = maxi(maxt, tray.size())
	return {"win": alive_n == 0 and not failed, "moves": moves, "holds": holds, "bsum": bsum, "bn": bn, "maxt": maxt}


func _dig(o: int, deep: bool) -> float:
	var c: = float(covcnt[o])
	if lcnt[o] > 0 and rcnt[o] > 0:
		c += 1.0
	if deep:
		for a in cov_by[o]:
			if present[a] == 1:
				c += 0.5 * covcnt[a]
	if not takeable(o):
		c += 1.5
	return c


func _choose(mv: PackedInt32Array, rng: RandomNumberGenerator, noise: float, profile: int) -> int:
	var best: = -1
	var best_s: = -1e9
	var deep: = profile >= 3
	for t in mv:
		var f: = face[t]
		var cost: = 9.0
		var unknown: = false
		if f == JOKER:
			cost = 0.0
		else:
			for o in n:
				if o == t or alive[o] == 0 or present[o] == 0:
					continue
				if face[o] != f and visible(o):
					continue
				if not visible(o):
					unknown = true
					continue
				cost = minf(cost, _dig(o, deep))
			if cost > 8.0 and unknown:
				cost = 2.5
		var s: = - cost + 0.15 * (covers[t] as Array).size()
		if noise > 0.0:
			var u: = clampf(rng.randf(), 1e-6, 1.0 - 1e-6)
			s += noise * (- log(- log(u)))
		if s > best_s:
			best_s = s
			best = t
	return best


# ---------------------------------------------------------------- solver

# Independent depth-first solver (perfect information, no certificate). Forced moves: flips, and a tile that
# pairs with the tray. Returns {ok, nodes, order}. `cap` = max tiles held in the tray (<= slots - 1).
func solve(budget: int, cap: int = -1) -> Dictionary:
	if cap < 0:
		cap = slots - 1
	reset()
	var visited: = {}
	var ctx: = {"nodes": 0, "budget": budget, "cap": cap, "visited": visited}
	var path: = PackedInt32Array()
	var ok: = _dfs(ctx, path)
	return {"ok": ok, "nodes": ctx.nodes, "order": path, "exhausted": int(ctx.nodes) >= budget}


func _snap() -> Array:
	return [present.duplicate(), alive.duplicate(), covcnt.duplicate(), lcnt.duplicate(), rcnt.duplicate(), face.duplicate(),
		ice.duplicate(), sec.duplicate(), kind_now.duplicate(), tray.duplicate(), freel.duplicate(), in_free.duplicate(),
		key_open.duplicate(), pairs_done, unstuck, on_board, alive_n, moves, failed]


func _restore(s: Array) -> void :
	present = s[0]
	alive = s[1]
	covcnt = s[2]
	lcnt = s[3]
	rcnt = s[4]
	face = s[5]
	ice = s[6]
	sec = s[7]
	kind_now = s[8]
	tray = s[9]
	freel = s[10]
	in_free = s[11]
	key_open = s[12]
	pairs_done = s[13]
	unstuck = s[14]
	on_board = s[15]
	alive_n = s[16]
	moves = s[17]
	failed = s[18]


func _forced(path: PackedInt32Array) -> bool:
	# apply flips and tray pairs until none; false if lost
	var again: = true
	while again:
		again = false
		var mv: = moves_now()
		for t in mv:
			if ice[t] > 0:
				tap(t)
				again = true
				break
		if again:
			continue
		for t in mv:
			var f: = face[t]
			var hit: = false
			for x in tray:
				if face[x] == f or face[x] == JOKER or (f == JOKER):
					hit = true
					break
			if hit:
				path.append(t)
				if tap(t) < 0:
					return false
				again = true
				break
	return true


func _key() -> String:
	var tr: = tray.duplicate()
	tr.sort()
	return alive.hex_encode() + ":" + present.hex_encode() + ":" + str(tr) + (":u" if unstuck else "")


func _dfs(ctx: Dictionary, path: PackedInt32Array) -> bool:
	ctx.nodes = int(ctx.nodes) + 1
	if int(ctx.nodes) > int(ctx.budget):
		return false
	var plen: = path.size()
	if not _forced(path):
		path.resize(plen)
		return false
	if alive_n == 0:
		return true
	var plen2: = path.size()
	if tray.size() >= int(ctx.cap):
		path.resize(plen)
		return false
	var k: = _key()
	if (ctx.visited as Dictionary).has(k):
		path.resize(plen)
		return false
	ctx.visited[k] = true
	var mv: = moves_now()
	if mv.is_empty():
		path.resize(plen)
		return false
	# order: tiles with a free same-face mate first, then by how buried their nearest mate is
	var cand: = []
	for t in mv:
		var f: = face[t]
		var best: = 99.0
		for o in n:
			if o != t and alive[o] == 1 and present[o] == 1 and face[o] == f:
				best = minf(best, _dig(o, false) - (5.0 if in_free[o] == 1 and takeable(o) else 0.0))
		cand.append([best, t])
	cand.sort_custom( func(a, b): return a[0] < b[0])
	var snap: = _snap()
	for c in cand:
		var t: int = c[1]
		path.append(t)
		if tap(t) >= 0 and _dfs(ctx, path):
			return true
		path.resize(plen2)
		_restore(snap)
		snap = _snap()
		if int(ctx.nodes) > int(ctx.budget):
			path.resize(plen)
			return false
	path.resize(plen)
	return false
