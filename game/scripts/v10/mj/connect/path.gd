class_name V10MjConnectPath
extends RefCounted

# Связи (Шисэн-сё) — поиск пути (docs/MODES.md §4.3). Сетка «с рамкой»: pw × ph = (w + 2) × (h + 2), клетки
# рамки всегда пусты. occ[y * pw + x] < 0 — пусто, иначе id фишки. Пара снимается, если между фишками есть
# ломаная не больше чем из 3 отрезков (≤ 2 поворотов) по пустым клеткам и рамке.
#
#   find(occ, pw, ph, a, b, max_turns = 2) -> Array[Vector2i]   углы ломаной [a, …, b] (2–4 точки) или []
#        BFS по направлениям с подсчётом поворотов (Дейкстра по (клетка, направление), цена = поворот×1000 + шаг):
#        из всех путей с минимумом поворотов — самый короткий. Им рисуется нить.
#   turns(occ, pw, ph, a, b) -> int      0 / 1 / 2 — минимум поворотов, −1 — пути нет (быстрая проверка)
#   can_link(occ, pw, ph, a, b) -> bool  быстрая проверка «сканом» (боты, генератор)
#   oracle(occ, pw, ph, a, b) -> bool    независимый перебор ломаных a→c1→c2→b (только для самотеста)
#   cells(path) -> Array[Vector2i]       все клетки ломаной (для «линия не проходит через фишки»)

const DIRS: = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const TURN: = 1000


static func _empty(occ: PackedInt32Array, pw: int, ph: int, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < pw and c.y < ph and occ[c.y * pw + c.x] < 0


# ── BFS по направлениям (канонический путь) ───────────────────────────────────────────────────────────────
static func find(occ: PackedInt32Array, pw: int, ph: int, a: Vector2i, b: Vector2i, max_turns: = 2) -> Array:
	if a == b:
		return []
	var n: = pw * ph * 4
	var dist: = PackedInt32Array()
	dist.resize(n)
	dist.fill(0x3fffffff)
	var par: = PackedInt32Array()
	par.resize(n)
	par.fill(-1)
	var heap: Array = []  # [cost, state]
	var goal: = -1
	for d in 4:
		var c: Vector2i = a + DIRS[d]
		if c.x < 0 or c.y < 0 or c.x >= pw or c.y >= ph:
			continue
		var s: = (c.y * pw + c.x) * 4 + d
		if c == b or occ[c.y * pw + c.x] < 0:
			dist[s] = 1
			par[s] = -2 - d
			_push(heap, 1, s)
	while not heap.is_empty():
		var top: Array = _pop(heap)
		var cost: int = top[0]
		var s: int = top[1]
		if cost != dist[s]:
			continue
		var ci: = s >> 2
		var d: = s & 3
		var c: = Vector2i(ci % pw, ci / pw)
		if c == b:
			goal = s
			break
		for nd in 4:
			if nd == (d + 2) % 4:
				continue
			var nc: Vector2i = c + DIRS[nd]
			if nc.x < 0 or nc.y < 0 or nc.x >= pw or nc.y >= ph:
				continue
			if nc != b and occ[nc.y * pw + nc.x] >= 0:
				continue
			var ncost: = cost + 1 + (TURN if nd != d else 0)
			if ncost / TURN > max_turns:
				continue
			var ns: = (nc.y * pw + nc.x) * 4 + nd
			if ncost < dist[ns]:
				dist[ns] = ncost
				par[ns] = s
				_push(heap, ncost, ns)
	if goal < 0:
		return []
	var rev: Array = []
	var s2: = goal
	while s2 >= 0:
		var ci2: = s2 >> 2
		rev.append(Vector2i(ci2 % pw, ci2 / pw))
		var p: = par[s2]
		if p <= -2:
			break
		s2 = p
	rev.append(a)
	rev.reverse()
	return corners(rev)


# a dense cell list → its corner points (keeps both ends)
static func corners(cells: Array) -> Array:
	if cells.size() <= 2:
		return cells.duplicate()
	var out: Array = [cells[0]]
	for i in range(1, cells.size() - 1):
		var d1: Vector2i = cells[i] - cells[i - 1]
		var d2: Vector2i = cells[i + 1] - cells[i]
		if d1 != d2:
			out.append(cells[i])
	out.append(cells[cells.size() - 1])
	return out


# every cell of a corner polyline (ends included)
static func cells(path: Array) -> Array:
	var out: Array = []
	if path.is_empty():
		return out
	out.append(path[0])
	for i in range(1, path.size()):
		var p: Vector2i = path[i - 1]
		var q: Vector2i = path[i]
		var st: = Vector2i(signi(q.x - p.x), signi(q.y - p.y))
		var c: = p
		while c != q:
			c += st
			out.append(c)
	return out


static func turns_of(path: Array) -> int:
	return maxi(0, path.size() - 2)


static func length_of(path: Array) -> int:
	var l: = 0
	for i in range(1, path.size()):
		l += absi(path[i].x - path[i - 1].x) + absi(path[i].y - path[i - 1].y)
	return l


# ── быстрая проверка (скан строк и столбцов) ────────────────────────────────────────────────────────────
static func can_link(occ: PackedInt32Array, pw: int, ph: int, a: Vector2i, b: Vector2i) -> bool:
	return turns(occ, pw, ph, a, b) >= 0


# minimal turns 0/1/2, −1 = no link
static func turns(occ: PackedInt32Array, pw: int, ph: int, a: Vector2i, b: Vector2i) -> int:
	if a == b:
		return -1
	var ia: = a.y * pw + a.x
	var ib: = b.y * pw + b.x
	var va: = occ[ia]
	var vb: = occ[ib]
	occ[ia] = -1
	occ[ib] = -1
	var r: = _turns(occ, pw, ph, a, b)
	occ[ia] = va
	occ[ib] = vb
	return r


static func _turns(occ: PackedInt32Array, pw: int, ph: int, a: Vector2i, b: Vector2i) -> int:
	# 0 turns
	if a.y == b.y and _hclear(occ, pw, a.y, a.x, b.x):
		return 0
	if a.x == b.x and _vclear(occ, pw, a.x, a.y, b.y):
		return 0
	# 1 turn: corner (b.x, a.y) or (a.x, b.y)
	if occ[a.y * pw + b.x] < 0 and _hclear(occ, pw, a.y, a.x, b.x) and _vclear(occ, pw, b.x, a.y, b.y):
		return 1
	if occ[b.y * pw + a.x] < 0 and _vclear(occ, pw, a.x, a.y, b.y) and _hclear(occ, pw, b.y, a.x, b.x):
		return 1
	# 2 turns: H-V-H through column x
	var ax0: = a.x
	var ax1: = a.x
	while ax0 - 1 >= 0 and occ[a.y * pw + ax0 - 1] < 0:
		ax0 -= 1
	while ax1 + 1 < pw and occ[a.y * pw + ax1 + 1] < 0:
		ax1 += 1
	var bx0: = b.x
	var bx1: = b.x
	while bx0 - 1 >= 0 and occ[b.y * pw + bx0 - 1] < 0:
		bx0 -= 1
	while bx1 + 1 < pw and occ[b.y * pw + bx1 + 1] < 0:
		bx1 += 1
	for x in range(maxi(ax0, bx0), mini(ax1, bx1) + 1):
		if x == a.x or x == b.x:
			continue
		if occ[a.y * pw + x] < 0 and occ[b.y * pw + x] < 0 and _vclear(occ, pw, x, a.y, b.y):
			return 2
	# V-H-V through row y
	var ay0: = a.y
	var ay1: = a.y
	while ay0 - 1 >= 0 and occ[(ay0 - 1) * pw + a.x] < 0:
		ay0 -= 1
	while ay1 + 1 < ph and occ[(ay1 + 1) * pw + a.x] < 0:
		ay1 += 1
	var by0: = b.y
	var by1: = b.y
	while by0 - 1 >= 0 and occ[(by0 - 1) * pw + b.x] < 0:
		by0 -= 1
	while by1 + 1 < ph and occ[(by1 + 1) * pw + b.x] < 0:
		by1 += 1
	for y in range(maxi(ay0, by0), mini(ay1, by1) + 1):
		if y == a.y or y == b.y:
			continue
		if occ[y * pw + a.x] < 0 and occ[y * pw + b.x] < 0 and _hclear(occ, pw, y, a.x, b.x):
			return 2
	return -1


# cells strictly between x0 and x1 on row y are empty
static func _hclear(occ: PackedInt32Array, pw: int, y: int, x0: int, x1: int) -> bool:
	var lo: = mini(x0, x1)
	var hi: = maxi(x0, x1)
	var base: = y * pw
	for x in range(lo + 1, hi):
		if occ[base + x] >= 0:
			return false
	return true


static func _vclear(occ: PackedInt32Array, pw: int, x: int, y0: int, y1: int) -> bool:
	var lo: = mini(y0, y1)
	var hi: = maxi(y0, y1)
	for y in range(lo + 1, hi):
		if occ[y * pw + x] >= 0:
			return false
	return true


# ── независимый оракул (самотест): перебор ломаных a → c1 → c2 → b ──────────────────────────────────────
static func oracle(occ: PackedInt32Array, pw: int, ph: int, a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return false
	var c1s: Array = []
	for x in pw:
		c1s.append(Vector2i(x, a.y))
	for y in ph:
		c1s.append(Vector2i(a.x, y))
	for c1 in c1s:
		for c2 in [Vector2i(c1.x, b.y), Vector2i(b.x, c1.y)]:
			if _seg_ok(occ, pw, a, c1, a, b) and _seg_ok(occ, pw, c1, c2, a, b) and _seg_ok(occ, pw, c2, b, a, b):
				return true
	return false


# every cell of segment p..q (both ends included) is empty, except the endpoints a and b themselves
static func _seg_ok(occ: PackedInt32Array, pw: int, p: Vector2i, q: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	if p.x != q.x and p.y != q.y:
		return false
	var st: = Vector2i(signi(q.x - p.x), signi(q.y - p.y))
	var c: = p
	while true:
		if c != a and c != b and occ[c.y * pw + c.x] >= 0:
			return false
		# a segment may start at a/b, but must not pass THROUGH b (or a) in its middle
		if (c == b or c == a) and c != p and c != q:
			return false
		if c == q:
			break
		c += st
	return true


# ── tiny binary heap of [cost, state] ─────────────────────────────────────────────────────────────────
static func _push(h: Array, cost: int, s: int) -> void:
	h.append([cost, s])
	var i: = h.size() - 1
	while i > 0:
		var p: = (i - 1) >> 1
		if h[p][0] <= h[i][0]:
			break
		var t = h[p]
		h[p] = h[i]
		h[i] = t
		i = p


static func _pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Array = h.pop_back()
	if h.is_empty():
		return top
	h[0] = last
	var i: = 0
	var n: = h.size()
	while true:
		var l: = i * 2 + 1
		var r: = l + 1
		var m: = i
		if l < n and h[l][0] < h[m][0]:
			m = l
		if r < n and h[r][0] < h[m][0]:
			m = r
		if m == i:
			break
		var t = h[m]
		h[m] = h[i]
		h[i] = t
		i = m
	return top
