class_name V10MjCubeShapes
extends RefCounted

# Куб — 40 фигур (docs/MODES.md §4.4): 5 глав по 8, каждая глава — основательница и её реликвия в сердцевине.
# Фигура = набор клеток сетки (Vector3i) + «сердцевина» (пустые клетки внутри, где лежит реликвия).
#   глава 1 · Маджонг-тян (шпилька)        3³ и малые формы
#   глава 2 · Рин (чашка)                   4³, чаша, рамки
#   глава 3 · Хана (эстафетная палочка)     4³–5, крест, ступени
#   глава 4 · Юэ (лунное зеркало)           5³ полый внутри, луна, кольцо
#   глава 5 · Нова (кристалл-ключ)          пагода, фонарь, кристалл
# Пила внутри главы (как v10-levels): 1 лёгкий · 2 обычный · 3 обычный · 4 сложный · 5 отдых · 6 обычный · 7 сложный ·
# 8 глава (фигура-глава: первая победа кладёт реликвию в витрину).
# Число фишек всегда чётное (нечётную форму чинит even(): снимается верхняя клетка у оси), не больше 125.
#
#   V10MjCubeShapes.figure(i) -> {i, name, shape, host, chapter, slot, kind, cells: Array[Vector3i],
#                                 core: Array[Vector3i], relic_at: Vector3 (центр сердцевины), dims: Vector3i}

const COUNT: = 40
const PER: = 8
const HOSTS: = ["mc", "rin", "hana", "yue", "nova"]
const KINDS: = ["easy", "normal", "normal", "hard", "rest", "normal", "hard", "boss"]
const KIND_NAMES: = {"easy": "Лёгкий", "normal": "Обычный", "hard": "Сложный", "rest": "Отдых", "boss": "Глава"}
const MAX_TILES: = 125

# [имя, форма, параметры]
const FIGS: = [
	# глава 1 · Маджонг-тян
	["Кубик", "box", [3, 3, 3, 1, 1, 1]],
	["Брусок", "box", [4, 3, 3, 2, 1, 1]],
	["Ёжик", "star", [3]],
	["Колонна", "box", [3, 5, 3, 1, 3, 1]],
	["Окошко", "frame", [5, 5, 2]],
	["Плита", "box", [4, 3, 4, 2, 1, 2]],
	["Ступени", "steps", [4]],
	["Куб четыре", "box", [4, 4, 4, 2, 2, 2]],
	# глава 2 · Рин
	["Чайный куб", "box", [4, 4, 4, 2, 2, 2]],
	["Башня", "box", [3, 6, 3, 1, 4, 1]],
	["Поднос", "box", [5, 3, 4, 3, 1, 2]],
	["Широкая рамка", "frame", [6, 6, 2]],
	["Брусок пять", "box", [5, 3, 3, 3, 1, 1]],
	["Ёж четыре", "star", [4]],
	["Плита пять", "box", [5, 3, 5, 3, 1, 3]],
	["Чаша", "bowl", [5, 4]],
	# глава 3 · Хана
	["Эстафета", "box", [3, 3, 6, 1, 1, 4]],
	["Крест", "cross", [3, 1]],
	["Пьедестал", "pagoda", [[5, 2], [3, 3], [1, 1]]],
	["Ворота", "gate", [5, 5, 2]],
	["Стадион", "frame", [6, 4, 3]],
	["Большой брусок", "box", [5, 4, 4, 3, 2, 2]],
	["Ступени пять", "steps", [5]],
	["Солнце", "star", [5]],
	# глава 4 · Юэ
	["Лунный куб", "shell", [5, 5, 5]],
	["Луна", "disk", [3, 1]],
	["Кольцо", "frame", [7, 7, 2]],
	["Лунный дом", "shell", [6, 5, 5]],
	["Полумесяц", "crescent", [3, 3]],
	["Двойная луна", "shell", [7, 4, 4]],
	["Зеркало", "disk", [3, 2]],
	["Куб пять", "shell", [5, 5, 5]],
	# глава 5 · Нова
	["Кристалл", "crystal", [3, 1]],
	["Пагода", "pagoda", [[5, 1], [3, 2], [5, 1], [3, 2], [1, 1]]],
	["Сервер", "box", [4, 6, 4, 2, 4, 2]],
	["Фонарь", "lantern", [3, 5, 2]],
	["Беседка", "pagoda", [[5, 1], [3, 2], [1, 1]]],
	["Высокая пагода", "pagoda", [[5, 1], [3, 1], [5, 1], [3, 2], [5, 1], [3, 1], [1, 1]]],
	["Кристалл-ключ", "crystal", [4, 2]],
	["Фонарь Новы", "lantern", [3, 6, 2]],
]

static var _cache: = {}


static func chapter_of(i: int) -> int:
	return clampi(i - 1, 0, COUNT - 1) / PER


static func slot_of(i: int) -> int:
	return clampi(i - 1, 0, COUNT - 1) % PER


static func host_of(i: int) -> String:
	return HOSTS[chapter_of(i)]


static func kind_of(i: int) -> String:
	return KINDS[slot_of(i)]


static func is_boss(i: int) -> bool:
	return slot_of(i) == PER - 1


# figure i (1…40)
static func figure(i: int) -> Dictionary:
	i = clampi(i, 1, COUNT)
	if _cache.has(i):
		return _cache[i]
	var f: Array = FIGS[i - 1]
	var d: = build_shape(String(f[1]), f[2])
	d.i = i
	d.name = String(f[0])
	d.chapter = chapter_of(i)
	d.slot = slot_of(i)
	d.host = host_of(i)
	d.kind = kind_of(i)
	_cache[i] = d
	return d


# a shape by name (also used by the selftest for reference configurations and the 125-tile budget cube)
static func build_shape(shape: String, p: Array) -> Dictionary:
	var cells: = {}
	var core: = {}
	match shape:
		"box":
			_box(cells, Vector3i.ZERO, Vector3i(p[0], p[1], p[2]))
			var cs: = Vector3i(p[3], p[4], p[5])
			var c0: = Vector3i((p[0] - cs.x) / 2, (p[1] - cs.y) / 2, (p[2] - cs.z) / 2)
			_carve(cells, core, c0, cs)
		"solid":
			_box(cells, Vector3i.ZERO, Vector3i(p[0], p[1], p[2]))
		"shell":
			_box(cells, Vector3i.ZERO, Vector3i(p[0], p[1], p[2]))
			_carve(cells, core, Vector3i.ONE, Vector3i(p[0] - 2, p[1] - 2, p[2] - 2))
		"star":
			var n: int = p[0]
			_box(cells, Vector3i.ZERO, Vector3i(n, n, n))
			var cs: = maxi(1, n - 2)
			_carve(cells, core, Vector3i(1, 1, 1), Vector3i(cs, cs, cs))
			# caps on the six face centres (1 cell on odd sizes, 2×2 on even)
			var cap: = 1 if n % 2 == 1 else 2
			var c0: = (n - cap) / 2
			for a in 3:
				for sgn in [-1, 1]:
					for u in cap:
						for v in cap:
							var q: = [c0 + u, c0 + v]
							var c: = Vector3i.ZERO
							c[a] = -1 if sgn < 0 else n
							c[(a + 1) % 3] = q[0]
							c[(a + 2) % 3] = q[1]
							cells[c] = true
		"frame":
			# a square ring lying in the xy plane, depth p[2]; the relic floats in the opening
			var w: int = p[0]
			var h: int = p[1]
			var dz: int = p[2]
			_box(cells, Vector3i.ZERO, Vector3i(w, h, dz))
			var hole: = 3 if w <= 5 else w - 4
			var hy: = 3 if h <= 5 else h - 4
			var o: = Vector3i((w - hole) / 2, (h - hy) / 2, 0)
			_carve(cells, core, o, Vector3i(hole, hy, dz))
		"steps":
			# a cube with the upper front-right octant cut away (a stair corner); the core peeks out at one cell
			var n: int = p[0]
			_box(cells, Vector3i.ZERO, Vector3i(n, n, n))
			var cut: = (n + 1) / 2
			for x in range(n - cut, n):
				for y in range(n - cut, n):
					for z in range(n - cut, n):
						cells.erase(Vector3i(x, y, z))
			var cs: = 2 if n % 2 == 0 else 1
			var c0: = (n - cs) / 2
			_carve(cells, core, Vector3i(c0, c0, c0), Vector3i(cs, cs, cs))
		"bowl":
			# Rin's cup: a ring of walls on a base, open at the top; the relic sits inside
			var w: int = p[0]
			var h: int = p[1]
			_box(cells, Vector3i(1, 0, 1), Vector3i(w - 2, 1, w - 2))
			for y in range(1, h):
				for x in w:
					for z in w:
						if x == 0 or z == 0 or x == w - 1 or z == w - 1:
							cells[Vector3i(x, y, z)] = true
			cells.erase(Vector3i(w / 2, 0, w / 2))
			for y in range(1, h):
				for x in range(1, w - 1):
					for z in range(1, w - 1):
						core[Vector3i(x, y, z)] = true
		"cross":
			# three orthogonal bars through a common n³ centre (arms of length p[1])
			var n: int = p[0]
			var arm: int = p[1]
			var L: = n + 2 * arm
			_box(cells, Vector3i(0, arm, arm), Vector3i(L, n, n))
			_box(cells, Vector3i(arm, 0, arm), Vector3i(n, L, n))
			_box(cells, Vector3i(arm, arm, 0), Vector3i(n, n, L))
			_carve(cells, core, Vector3i(arm + n / 2, arm + n / 2, arm + n / 2), Vector3i.ONE)
		"gate":
			# a torii-like gate: two posts and a lintel, the core in the lintel
			var w: int = p[0]
			var h: int = p[1]
			var dz: int = p[2]
			_box(cells, Vector3i(0, 0, 0), Vector3i(2, h, dz))
			_box(cells, Vector3i(w - 2, 0, 0), Vector3i(2, h, dz))
			_box(cells, Vector3i(-1, h, 0), Vector3i(w + 2, 3, dz))
			_carve(cells, core, Vector3i(w / 2 - 1, h + 1, dz / 2), Vector3i(2 if w % 2 == 0 else 3, 1, 1))
		"disk":
			# a round coin / mirror: disk of radius r in the xy plane, thickness t, hollow middle layer
			var r: int = p[0]
			var t: int = p[1] + 2
			for x in range(-r, r + 1):
				for y in range(-r, r + 1):
					if x * x + y * y <= r * r + r:
						for z in t:
							cells[Vector3i(x, y, z)] = true
			for x in range(-r + 1, r):
				for y in range(-r + 1, r):
					if x * x + y * y <= (r - 1) * (r - 1) + (r - 1) - 1:
						for z in range(1, t - 1):
							if cells.has(Vector3i(x, y, z)):
								cells.erase(Vector3i(x, y, z))
								core[Vector3i(x, y, z)] = true
		"crescent":
			var r: int = p[0]
			var t: int = p[1]
			for x in range(-r, r + 1):
				for y in range(-r, r + 1):
					var inside: = x * x + y * y <= r * r + r
					var bite: = (x - 2) * (x - 2) + (y - 1) * (y - 1) <= (r - 1) * (r - 1)
					if inside and not bite:
						for z in t:
							cells[Vector3i(x, y, z)] = true
			_carve(cells, core, Vector3i(-r + 1, -1, 1), Vector3i(1, 3, t - 2))
		"pagoda":
			# tiers bottom→top: [size, height]; wide thin roofs and narrow walls. The core is the hollow inside the
			# first wall tier (and the centre column of every wall tier ≥ 3 wide).
			var y: = 0
			var maxs: = 0
			for t in p:
				maxs = maxi(maxs, int(t[0]))
			var first_wall: = true
			for t in p:
				var s: int = t[0]
				var h: int = t[1]
				var o: = (maxs - s) / 2
				_box(cells, Vector3i(o, y, o), Vector3i(s, h, s))
				if s >= 3 and h >= 2 and first_wall:
					_carve(cells, core, Vector3i(o + 1, y, o + 1), Vector3i(s - 2, h, s - 2))
					first_wall = false
				y += h
		"lantern":
			# a paper lantern: round layers (radius bulges in the middle), hollow inside, cap on top and bottom
			var R: int = p[0]
			var H: int = p[1]
			for y in H:
				var k: = sin(PI * (y + 0.5) / H)
				var r: = maxf(1.0, R * (0.55 + 0.45 * k))
				for x in range(-R, R + 1):
					for z in range(-R, R + 1):
						if x * x + z * z <= r * r + 0.6:
							cells[Vector3i(x, y, z)] = true
			cells[Vector3i(0, H, 0)] = true
			cells[Vector3i(0, -1, 0)] = true
			_hollow(cells, core, int(p[2]) if p.size() > 2 else 1)
		"crystal":
			# an octahedron-like crystal: |x| + |z| ≤ r(y), hollow middle
			var r: int = p[0]
			for y in range(-r, r + 1):
				var ry: = r - absi(y)
				for x in range(-ry, ry + 1):
					for z in range(-ry, ry + 1):
						if absi(x) + absi(z) <= ry:
							cells[Vector3i(x, y, z)] = true
			_hollow(cells, core, int(p[1]) if p.size() > 1 else 1)
		_:
			_box(cells, Vector3i.ZERO, Vector3i(3, 3, 3))
	return _finish(cells, core)


static func _box(cells: Dictionary, o: Vector3i, s: Vector3i) -> void:
	for x in s.x:
		for y in s.y:
			for z in s.z:
				cells[o + Vector3i(x, y, z)] = true


# keep a wall `thick` cells deep (depth = steps to the outside through faces); deeper cells become the core
static func _hollow(cells: Dictionary, core: Dictionary, thick: int) -> void:
	var depth: = {}
	var front: = []
	for c in cells:
		for dv in V10MjCubeRules.DIRS:
			if not cells.has(c + dv):
				depth[c] = 1
				front.append(c)
				break
	while not front.is_empty():
		var nxt: = []
		for c in front:
			for dv in V10MjCubeRules.DIRS:
				var q: Vector3i = c + dv
				if cells.has(q) and not depth.has(q):
					depth[q] = int(depth[c]) + 1
					nxt.append(q)
		front = nxt
	for c in depth:
		if int(depth[c]) > thick:
			cells.erase(c)
			core[c] = true


static func _carve(cells: Dictionary, core: Dictionary, o: Vector3i, s: Vector3i) -> void:
	for x in s.x:
		for y in s.y:
			for z in s.z:
				var c: = o + Vector3i(x, y, z)
				cells.erase(c)
				core[c] = true


# normalise to min = 0, make the count even, sort cells (deterministic order), centre of the core
static func _finish(cells: Dictionary, core: Dictionary) -> Dictionary:
	var lo: = Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi: = -lo
	for c in cells:
		lo = Vector3i(mini(lo.x, c.x), mini(lo.y, c.y), mini(lo.z, c.z))
		hi = Vector3i(maxi(hi.x, c.x), maxi(hi.y, c.y), maxi(hi.z, c.z))
	var list: Array[Vector3i] = []
	for c in cells:
		list.append(c - lo)
	var dims: = hi - lo + Vector3i.ONE
	list = even(list, dims)
	list.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	var cl: Array[Vector3i] = []
	var cc: = Vector3.ZERO
	for c in core:
		cl.append(c - lo)
		cc += Vector3(c - lo)
	if cl.is_empty():
		cc = Vector3(dims - Vector3i.ONE) * 0.5
	else:
		cc /= float(cl.size())
	return {"cells": list, "core": cl, "relic_at": cc, "dims": dims, "n": list.size()}


# odd → drop the highest cell nearest the vertical axis (a finial), then the cap stays symmetric enough
static func even(list: Array[Vector3i], dims: Vector3i) -> Array[Vector3i]:
	if list.size() % 2 == 0:
		return list
	var mid: = Vector3(dims - Vector3i.ONE) * 0.5
	var best: = -1
	var bs: = -INF
	for k in list.size():
		var c: = list[k]
		var s: = c.y * 10.0 - absf(c.x - mid.x) - absf(c.z - mid.z)
		if s > bs:
			bs = s
			best = k
	var out: Array[Vector3i] = list.duplicate()
	out.remove_at(best)
	return out


static func chapter_name(ch: int) -> String:
	return "Глава %d" % (ch + 1)
