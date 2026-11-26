class_name V10MjConnectBoard
extends RefCounted

# Связи — модель стола без сцены (docs/MODES.md §4.3). Плоская сетка w × h (8×10 … 12×14) и пустая рамка
# вокруг: внутри модели координаты «с рамкой» (x 1..w, y 1..h; 0 и w+1 / h+1 — рамка).
#
# Варианты (variant):
#   "static" — фишки стоят на месте;
#   "rain"   — «Ливень»: после снятия фишки столбца падают вниз (столбец = стопка снизу вверх);
#   "shift"  — «Сдвиг»: ряды сдвигаются к центру (левая половина ряда — стопка от центра влево, правая — вправо).
# Любой вариант описан «стопками»: упорядоченными списками клеток от якоря наружу; после снятия живые фишки
# стопки прижимаются к якорю в прежнем порядке (compact). У "static" стопок нет.
#
# Препятствия (с 6-й главы, MODES §5.2): lock[t] > 0 — «Брандмауэр»: фишка под сеткой, открывается, когда снято
# lock[t] пар всего (≤ 3 хода); ice[t] = 1 — «Лёд»: тает, когда рядом (по стороне) снята пара.
#
#   load_payload(p)           p = V10MjConnectGen.build(...)
#   selectable(t) -> bool     жива, не под сеткой, не во льду
#   path_for(a, b) -> Array   углы пути или [] (фишки с одинаковым лицом и выбираемые)
#   remove(a, b) -> Dictionary  {path, moves: [[t, from, to]], thawed: [t], opened: [t]}  (снимок для отмены)
#   undo() -> bool
#   moves(limit = 0) -> Array  доступные пары [[a, b], …]
#   any_move() -> bool, hint() -> {a, b, path} | {}
#   shuffle(rng) -> bool      перемешать лица живых фишек с гарантией хода (true, если ход есть)
#   left() -> int             живых фишек

const VARIANTS: = ["static", "rain", "shift"]

var w: = 8
var h: = 10
var pw: = 10
var ph: = 12
var variant: = "static"
var occ: = PackedInt32Array()
var face: = PackedInt32Array()
var pos: Array = []  # Vector2i per tile (padded coords)
var alive: = PackedByteArray()
var lock: = PackedInt32Array()
var ice: = PackedByteArray()
var stacks: Array = []  # Array[Array[Vector2i]]
var stack_of: = {}  # cell index -> stack index
var removed_pairs: = 0
var history: Array = []
var n_tiles: = 0


func setup(cols: int, rows: int, var_name: = "static") -> V10MjConnectBoard:
	w = cols
	h = rows
	pw = w + 2
	ph = h + 2
	variant = var_name if var_name in VARIANTS else "static"
	occ = PackedInt32Array()
	occ.resize(pw * ph)
	occ.fill(-1)
	stacks = make_stacks(w, h, variant)
	stack_of = {}
	for si in stacks.size():
		for c in stacks[si]:
			stack_of[c.y * pw + c.x] = si
	return self


static func make_stacks(cols: int, rows: int, var_name: String) -> Array:
	var out: Array = []
	match var_name:
		"rain":
			for x in range(1, cols + 1):
				var s: Array = []
				for y in range(rows, 0, -1):
					s.append(Vector2i(x, y))
				out.append(s)
		"shift":
			var half: = cols / 2
			for y in range(1, rows + 1):
				var l: Array = []
				for x in range(half, 0, -1):
					l.append(Vector2i(x, y))
				out.append(l)
				var r: Array = []
				for x in range(half + 1, cols + 1):
					r.append(Vector2i(x, y))
				out.append(r)
	return out


func load_payload(p: Dictionary) -> V10MjConnectBoard:
	setup(int(p.cols), int(p.rows), String(p.get("variant", "static")))
	n_tiles = int(p.n)
	face = PackedInt32Array(p.face)
	pos = []
	var flat: Array = p.pos
	for i in n_tiles:
		pos.append(Vector2i(int(flat[i * 2]), int(flat[i * 2 + 1])))
	alive = PackedByteArray()
	alive.resize(n_tiles)
	alive.fill(1)
	lock = PackedInt32Array()
	lock.resize(n_tiles)
	ice = PackedByteArray()
	ice.resize(n_tiles)
	for e in p.get("lock", []):
		lock[int(e[0])] = int(e[1])
	for t in p.get("ice", []):
		ice[int(t)] = 1
	for i in n_tiles:
		occ[pos[i].y * pw + pos[i].x] = i
	removed_pairs = 0
	history.clear()
	return self


func left() -> int:
	var n: = 0
	for i in n_tiles:
		n += alive[i]
	return n


func at(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= pw or c.y >= ph:
		return -1
	return occ[c.y * pw + c.x]


func selectable(t: int) -> bool:
	return t >= 0 and t < n_tiles and alive[t] == 1 and lock[t] <= removed_pairs and ice[t] == 0


func locked(t: int) -> bool:
	return lock[t] > removed_pairs


func path_for(a: int, b: int) -> Array:
	if a == b or not selectable(a) or not selectable(b) or face[a] != face[b]:
		return []
	return V10MjConnectPath.find(occ, pw, ph, pos[a], pos[b])


func _snapshot() -> Dictionary:
	return {"occ": occ.duplicate(), "pos": pos.duplicate(), "alive": alive.duplicate(), "ice": ice.duplicate(),
		"face": face.duplicate(), "removed": removed_pairs}


func remove(a: int, b: int, path: Array = []) -> Dictionary:
	if path.is_empty():
		path = path_for(a, b)
	if path.is_empty():
		return {}
	history.append(_snapshot())
	var pa: Vector2i = pos[a]
	var pb: Vector2i = pos[b]
	# ice next to either removed tile melts (positions before the removal)
	var thawed: Array = []
	for c in [pa, pb]:
		for d in V10MjConnectPath.DIRS:
			var t: = at(c + d)
			if t >= 0 and t != a and t != b and ice[t] == 1:
				ice[t] = 0
				thawed.append(t)
	alive[a] = 0
	alive[b] = 0
	occ[pa.y * pw + pa.x] = -1
	occ[pb.y * pw + pb.x] = -1
	var was_locked: Array = []
	for t in n_tiles:
		if alive[t] == 1 and lock[t] > removed_pairs:
			was_locked.append(t)
	removed_pairs += 1
	var opened: Array = []
	for t in was_locked:
		if lock[t] <= removed_pairs:
			opened.append(t)
	var mv: = compact([pa, pb])
	return {"path": path, "moves": mv, "thawed": thawed, "opened": opened, "a": a, "b": b, "from_a": pa, "from_b": pb}


# pack the live tiles of the stacks that held the given cells toward their anchors; returns [[t, from, to], …]
func compact(cells_hit: Array) -> Array:
	var out: Array = []
	if stacks.is_empty():
		return out
	var touched: = {}
	for c in cells_hit:
		var k: int = c.y * pw + c.x
		if stack_of.has(k):
			touched[stack_of[k]] = true
	for si in touched:
		var cells: Array = stacks[si]
		var ids: Array = []
		for c in cells:
			var t: int = occ[c.y * pw + c.x]
			if t >= 0:
				ids.append(t)
			occ[c.y * pw + c.x] = -1
		for i in ids.size():
			var t: int = ids[i]
			var nc: Vector2i = cells[i]
			if pos[t] != nc:
				out.append([t, pos[t], nc])
				pos[t] = nc
			occ[nc.y * pw + nc.x] = t
	return out


func undo() -> bool:
	if history.is_empty():
		return false
	var s: Dictionary = history.pop_back()
	occ = s.occ
	pos = s.pos
	alive = s.alive
	ice = s.ice
	face = s.face
	removed_pairs = s.removed
	return true


# available pairs; limit > 0 stops early
func moves(limit: = 0) -> Array:
	var out: Array = []
	var by_face: = {}
	for t in n_tiles:
		if selectable(t):
			var f: = face[t]
			if not by_face.has(f):
				by_face[f] = []
			by_face[f].append(t)
	for f in by_face:
		var g: Array = by_face[f]
		for i in g.size():
			for j in range(i + 1, g.size()):
				if V10MjConnectPath.can_link(occ, pw, ph, pos[g[i]], pos[g[j]]):
					out.append([g[i], g[j]])
					if limit > 0 and out.size() >= limit:
						return out
	return out


func any_move() -> bool:
	return not moves(1).is_empty()


# the friendliest pair: fewest turns, then shortest
func hint() -> Dictionary:
	var best: = {}
	var best_k: = 1 << 30
	for m in moves():
		var p: = V10MjConnectPath.find(occ, pw, ph, pos[m[0]], pos[m[1]])
		if p.is_empty():
			continue
		var k: = V10MjConnectPath.turns_of(p) * 1000 + V10MjConnectPath.length_of(p)
		if k < best_k:
			best_k = k
			best = {"a": m[0], "b": m[1], "path": p}
	return best


# permute faces of live tiles (positions stay) so that a move exists. Locked/iced tiles keep their faces.
# Guarantee: if no move appears after a few random tries, two linkable selectable cells get a common face.
func shuffle(rng: RandomNumberGenerator) -> bool:
	var ids: Array = []
	for t in n_tiles:
		if selectable(t):
			ids.append(t)
	if ids.size() < 2:
		# nothing to choose from: open the nets and melt the ice (the rule «≤ 3 хода» never leaves a dead table)
		for t in n_tiles:
			if alive[t] == 1:
				ice[t] = 0
				lock[t] = mini(lock[t], removed_pairs)
		ids.clear()
		for t in n_tiles:
			if selectable(t):
				ids.append(t)
	var faces: Array = []
	for t in ids:
		faces.append(face[t])
	for attempt in 4:
		for i in range(faces.size() - 1, 0, -1):
			var j: = rng.randi_range(0, i)
			var tmp = faces[i]
			faces[i] = faces[j]
			faces[j] = tmp
		for i in ids.size():
			face[ids[i]] = faces[i]
		if any_move():
			return true
	# guarantee: find two linkable cells (faces ignored) and give them one face
	var order: Array = ids.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j: = rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for i in order.size():
		for j in range(i + 1, order.size()):
			var p: int = order[i]
			var q: int = order[j]
			if not V10MjConnectPath.can_link(occ, pw, ph, pos[p], pos[q]):
				continue
			var f: = face[p]
			if face[q] == f:
				return true
			for r in ids:
				if r != p and r != q and face[r] == f:
					face[r] = face[q]
					face[q] = f
					return any_move()
	return any_move()


# headless replay of a removal order (the certificate); returns the index of the first failing step or −1
func replay(order: Array) -> int:
	for i in order.size():
		var pr: Array = order[i]
		if path_for(int(pr[0]), int(pr[1])).is_empty():
			return i
		remove(int(pr[0]), int(pr[1]))
	return -1
