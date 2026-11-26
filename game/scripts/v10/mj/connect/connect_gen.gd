class_name V10MjConnectGen
extends RefCounted

# Связи — генератор 90 уровней (9 глав × 10) с сертификатом решаемости (docs/MODES.md §4.3).
#
# Обратная укладка: стол собирается «с конца». Каждый шаг кладёт пару в две свободные позиции так, чтобы между
# ними был путь ≤ 2 поворотов по ТЕКУЩЕМУ столу. Порядок, обратный укладке, — сертификат: на каждом шаге прямой
# игры пара соединима. Для «Ливня» и «Сдвига» укладка идёт в «стопки» (столбец / половина ряда): вставка в стопку
# сдвигает фишки выше — это ровно обратная операция к «сняли и прижали». Сертификат каждого уровня, кроме того,
# проигрывается настоящей моделью V10MjConnectBoard (симуляция) — и для статичного стола, и для Ливня/Сдвига.
#
#   level(i) -> Dictionary        параметры уровня (дёшево): глава, тир, вариант, размер, плотность, доля длинных
#   build(i, seed = 0, big = false, salt = -1) -> Dictionary   payload для V10MjConnectBoard.load_payload + cert
#   verify(p) -> String           "" если сертификат проигрывается моделью (с препятствиями), иначе причина
#   bot(p, rng, kind = "casual") -> {shuffles, moves, clean}
#   bot_rate(p, games, seed) -> float     доля партий бота без перемешивания
#
# Сложность — плотность (доля занятых клеток) и доля длинных путей (2 поворота) в сертификате, плюс число разных
# лиц. Тиры и полосы бота — как в v10-levels (пила внутри главы, BANDS). «Крупные фишки»: сетка не больше 10×12.

const CHAPTERS: = 9
const PER: = 10
const COUNT: = 90
const FACES: = 36
const BIG_MAX: = Vector2i(10, 12)
const BAKE_PATH: = "res://assets/v10/mj/connect/connect_bake.json"

# пила главы (как v10-levels): 1 лёгкий · 2 обычный · 3 обычный · 4 сложный · 5 передышка · 6 обычный · 7 сложный ·
# 8 пик · 9 обычный · 10 босс
const SAW: = ["easy", "normal", "normal", "hard", "easy", "normal", "hard", "peak", "normal", "boss"]
const TIER_NAME: = {"intro": "Знакомство", "easy": "Лёгкий", "normal": "Обычный", "hard": "Сложный",
	"peak": "Очень сложный", "boss": "Испытание главы"}
# доля партий «casual»-бота без перемешивания (полосы v10-levels: обучение 0.90–1.00, лёгкий 0.85–1.00,
# обычный 0.65–0.95, сложный 0.35–0.65, очень сложный 0.12–0.35)
const BANDS: = {"intro": [0.9, 1.0], "easy": [0.85, 1.0], "normal": [0.65, 0.95], "hard": [0.35, 0.65],
	"peak": [0.12, 0.35], "boss": [0.35, 0.65]}
const TP: = {
	"intro": {"density": 0.62, "long": 0.10, "faces": 0.40},
	"easy": {"density": 0.70, "long": 0.15, "faces": 0.45},
	"normal": {"density": 0.80, "long": 0.35, "faces": 0.55},
	"hard": {"density": 0.90, "long": 0.55, "faces": 0.66},
	"peak": {"density": 1.00, "long": 0.75, "faces": 0.75},
	"boss": {"density": 0.96, "long": 0.65, "faces": 0.70},
}
const DIMS: = [Vector2i(8, 10), Vector2i(8, 10), Vector2i(9, 11), Vector2i(10, 12), Vector2i(10, 12),
	Vector2i(11, 13), Vector2i(11, 13), Vector2i(12, 14), Vector2i(12, 14)]
const CHAPTER_NAMES: = ["Первая нить", "Ливень", "Узелки", "Сдвиг", "Чайный узор", "Сетка Новы", "Иней",
	"Длинная нить", "Знак"]
const SHAPES: = ["round", "windows", "diamond", "arch", "random"]

static var _bake: = {}
static var _bake_loaded: = false


static func _load_bake() -> void:
	if _bake_loaded:
		return
	_bake_loaded = true
	if not FileAccess.file_exists(BAKE_PATH):
		return
	var j = JSON.parse_string(FileAccess.get_file_as_string(BAKE_PATH))
	if j is Dictionary:
		_bake = j


static func mech_lib() -> bool:
	# the shared mechanics library (lane `mechanics`, MODES §5) — used when it is merged; our nets/ice otherwise
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) in ["V10MjMechanics", "V10MjMech"]:
			return true
	return false


static func level(i: int) -> Dictionary:
	i = clampi(i, 0, COUNT - 1)
	var ch: = i / PER
	var p: = i % PER
	var tier: String = SAW[p]
	if ch == 0 and p == 0:
		tier = "intro"
	elif ch <= 1 and tier == "peak":
		tier = "hard"
	var variant: = "static"
	# Ливень с 2-й главы, Сдвиг с 4-й; первая партия главы-вводной — сама новинка
	if ch == 1 and p in [0, 2, 5, 8, 9]:
		variant = "rain"
	elif ch == 2 and p in [1, 3, 6, 9]:
		variant = "rain"
	elif ch == 3 and p in [0, 2, 5, 8, 9]:
		variant = "shift"
	elif ch == 3 and p in [3, 6]:
		variant = "rain"
	elif ch >= 4:
		variant = ["static", "rain", "shift"][(p + ch) % 3]
	var intro: = ""
	if ch == 1 and p == 0:
		intro = "rain"
	elif ch == 3 and p == 0:
		intro = "shift"
	elif ch == 5 and p == 0:
		intro = "net"
	elif ch == 6 and p == 0:
		intro = "ice"
	var d: Vector2i = DIMS[ch]
	if tier in ["intro", "easy"]:
		d = Vector2i(maxi(8, d.x - 1), maxi(10, d.y - 1))
	var obst: = {"net": 0, "ice": 0}
	if ch >= 5 and tier != "intro":
		obst.net = 1 if ch == 5 else (2 if tier in ["hard", "peak", "boss"] and ch >= 7 else 1)
	if ch >= 6 and tier != "intro":
		obst.ice = 0 if (ch == 6 and p == 0) else (2 + (ch - 6) * 2 if tier in ["hard", "peak", "boss"] else 2)
	if intro == "net":
		obst = {"net": 1, "ice": 0}
	if intro == "ice":
		obst = {"net": 0, "ice": 2}
	var tp: Dictionary = TP[tier]
	var dens: float = tp.density
	if intro != "":
		dens = minf(dens, 0.8)
	return {"idx": i, "id": "connect_%02d" % (i + 1), "code": "%d-%d" % [ch + 1, p + 1], "chapter": ch, "pos": p,
		"chapter_name": CHAPTER_NAMES[ch], "tier": tier, "tier_name": TIER_NAME[tier], "variant": variant,
		"intro": intro, "cols": d.x, "rows": d.y, "density": dens, "p_long": tp.long, "face_ratio": tp.faces,
		"shape": SHAPES[(i * 7 + ch) % SHAPES.size()], "obst": obst, "boss": p == 9}


static func _rng(i: int, seed: int, salt: int, tag: = "") -> RandomNumberGenerator:
	var r: = RandomNumberGenerator.new()
	r.seed = hash([i, seed, salt, "v10_mj_connect", tag])
	return r


static func build(i: int, seed: = 0, big: = false, salt: = -1) -> Dictionary:
	var L: = level(i)
	if salt < 0:
		_load_bake()
		salt = int(_bake.get(str(i), {}).get("salt", 0)) if _bake.has(str(i)) else 0
	var cols: int = L.cols
	var rows: int = L.rows
	if big:
		cols = mini(cols, BIG_MAX.x)
		rows = mini(rows, BIG_MAX.y)
	for attempt in 40:
		var rng: = _rng(i, seed, salt, str(attempt) + ("b" if big else ""))
		var tgt: = _targets(cols, rows, L.variant, L.density, L.shape, rng)
		var res: = _construct(cols, rows, L.variant, tgt, rng, L.p_long)
		if res.is_empty():
			continue
		var n: int = res.n
		var pairs: Array = res.pairs  # placement order
		var cert: Array = pairs.duplicate()
		cert.reverse()
		var face: = _faces(pairs.size(), L.face_ratio, rng)
		var f_arr: = PackedInt32Array()
		f_arr.resize(n)
		for k in pairs.size():
			f_arr[pairs[k][0]] = face[k]
			f_arr[pairs[k][1]] = face[k]
		var flat: Array = []
		for t in n:
			flat.append(res.pos[t].x)
			flat.append(res.pos[t].y)
		var p: = {"id": L.id, "idx": i, "code": L.code, "chapter": L.chapter, "tier": L.tier, "variant": L.variant,
			"intro": L.intro, "cols": cols, "rows": rows, "n": n, "face": Array(f_arr), "pos": flat, "cert": cert,
			"lock": [], "ice": [], "seed": seed, "salt": salt, "big": big, "attempt": attempt,
			"long_share": float(res.long) / maxf(1.0, pairs.size()), "density": float(n) / float(cols * rows),
			"par_s": int(round(pairs.size() * (4.6 if L.tier in ["intro", "easy"] else 3.8))),
			"mech_lib": mech_lib()}
		_obstacles(p, L.obst, rng)
		if verify(p) != "":
			p.lock = []
			p.ice = []
			if verify(p) != "":
				continue
		return p
	push_error("V10MjConnectGen: no board for level %d seed %d" % [i, seed])
	return {}


# ── target occupancy per stack ──────────────────────────────────────────────────────────────────────────
static func _targets(cols: int, rows: int, variant: String, dens: float, shape: String, rng: RandomNumberGenerator) -> Dictionary:
	var total: = cols * rows
	var want: = int(round(total * dens))
	want -= want % 2
	want = clampi(want, 16, total - (total % 2))
	match variant:
		"rain":
			var hts: Array = []
			for x in cols:
				hts.append(rows)
			var excess: = total - want
			var guard: = 0
			while excess > 0 and guard < 5000:
				guard += 1
				# skyline: lower the columns of a valley/hill profile, mirrored
				var x: = rng.randi_range(0, cols - 1)
				var mx: = cols - 1 - x
				var prof: float = absf((x + 0.5) / cols - 0.5) * 2.0  # 0 centre .. 1 edge
				var wgt: = prof if shape in ["round", "diamond", "arch"] else 1.0 - prof
				if rng.randf() > 0.25 + 0.75 * wgt:
					continue
				if hts[x] <= rows / 3:
					continue
				hts[x] -= 1
				excess -= 1
				if excess > 0 and mx != x and hts[mx] > rows / 3:
					hts[mx] -= 1
					excess -= 1
			return {"kind": "stacks", "counts": hts}
		"shift":
			var half: = cols / 2
			var cnt: Array = []
			for y in rows:
				cnt.append(half)
				cnt.append(cols - half)
			var excess2: = total - want
			var guard2: = 0
			while excess2 > 0 and guard2 < 5000:
				guard2 += 1
				var y: = rng.randi_range(0, rows - 1)
				var prof2: float = absf((y + 0.5) / rows - 0.5) * 2.0
				var wgt2: = 1.0 - prof2 if shape in ["windows", "arch"] else prof2
				if rng.randf() > 0.25 + 0.75 * wgt2:
					continue
				var side: = rng.randi_range(0, 1)
				if cnt[y * 2 + side] <= 1:
					continue
				cnt[y * 2 + side] -= 1
				excess2 -= 1
				if excess2 > 0 and cnt[y * 2 + 1 - side] > 1:
					cnt[y * 2 + 1 - side] -= 1
					excess2 -= 1
			return {"kind": "stacks", "counts": cnt}
	# static: a mirrored mask
	var pri: = {}
	var cx: = (cols + 1) * 0.5
	var cy: = (rows + 1) * 0.5
	for y in range(1, rows + 1):
		for x in range(1, cols + 1):
			var dx: = absf(x - cx) / (cols * 0.5)
			var dy: = absf(y - cy) / (rows * 0.5)
			var v: = 0.0
			match shape:
				"round":
					v = dx * dx + dy * dy
				"diamond":
					v = dx + dy
				"arch":
					v = dx * dx + (1.0 - dy if y > cy else 0.0) * 0.8 + (dy * 0.6 if y <= cy else 0.0)
				"windows":
					var wx: = posmod(x - 1, 4)
					var wy: = posmod(y - 1, 4)
					v = 1.2 if (wx in [1, 2] and wy in [1, 2] and x > 1 and y > 1 and x < cols and y < rows) else dx * 0.4 + dy * 0.4
				_:
					v = rng.randf()
			pri[Vector2i(x, y)] = v + rng.randf() * 0.18
	var order: Array = pri.keys()
	order.sort_custom(func(a, b): return pri[a] > pri[b])
	var removed: = {}
	var left: = total
	for c in order:
		if left <= want:
			break
		if removed.has(c):
			continue
		var m: = Vector2i(cols + 1 - c.x, c.y)
		if m != c and not removed.has(m) and left - 2 >= want:
			removed[c] = true
			removed[m] = true
			left -= 2
		elif m == c and left - 1 >= want:
			removed[c] = true
			left -= 1
	if left % 2 == 1:
		for c in order:
			if not removed.has(c) and c.x * 2 == cols + 1:
				removed[c] = true
				left -= 1
				break
		if left % 2 == 1:
			removed[order[0]] = true
	var cells: Array = []
	for y in range(1, rows + 1):
		for x in range(1, cols + 1):
			if not removed.has(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	if cells.size() % 2 == 1:
		cells.pop_back()
	return {"kind": "cells", "cells": cells}


# ── forward peeling construction (100% deadlock-free on static / rain / shift) ─────────────────────────
static func _construct(cols: int, rows: int, variant: String, tgt: Dictionary, rng: RandomNumberGenerator, p_long: float) -> Dictionary:
	var pos0: Array = []
	if tgt.kind == "cells":
		for c in tgt.cells:
			pos0.append(c as Vector2i)
	else:
		var stacks: Array = V10MjConnectBoard.make_stacks(cols, rows, variant)
		var counts: Array = tgt.counts
		for si in stacks.size():
			var s_cells: Array = stacks[si]
			var lim: int = mini(int(counts[si]), s_cells.size())
			for j in lim:
				pos0.append(s_cells[j] as Vector2i)
	var total: int = pos0.size()
	if total < 2 or total % 2 == 1:
		return {}
	var flat0: Array = []
	for c in pos0:
		var cv: Vector2i = c
		flat0.append(cv.x)
		flat0.append(cv.y)
	var zero: Array = []
	zero.resize(total)
	zero.fill(0)
	var sim: V10MjConnectBoard = V10MjConnectBoard.new().load_payload({
		"cols": cols, "rows": rows, "variant": variant, "n": total, "face": zero, "pos": flat0,
	})
	var cert: Array = []
	var nlong: int = 0
	var P: int = total / 2
	for _k in P:
		var alive_ids: Array = []
		for t in total:
			if sim.alive[t] == 1:
				alive_ids.append(t)
		_shuffle(alive_ids, rng)
		var want_long: bool = rng.randf() < p_long
		var best_a: int = -1
		var best_b: int = -1
		var best_t: int = -1
		var m_a: int = mini(alive_ids.size(), 14)
		for ia in m_a:
			var a: int = int(alive_ids[ia])
			var pa: Vector2i = sim.pos[a]
			var m_b: int = mini(alive_ids.size(), ia + 11)
			for ib in range(ia + 1, m_b):
				var b: int = int(alive_ids[ib])
				var t: int = V10MjConnectPath.turns(sim.occ, sim.pw, sim.ph, pa, sim.pos[b] as Vector2i)
				if t < 0:
					continue
				if best_t < 0 or (want_long and t > best_t) or (not want_long and t < best_t):
					best_a = a
					best_b = b
					best_t = t
				if (want_long and t == 2) or (not want_long and t <= 1):
					break
			if (want_long and best_t == 2) or (not want_long and best_t >= 0 and best_t <= 1):
				break
		if best_t < 0:
			var rim: Array = []
			for id_v in alive_ids:
				var tid: int = int(id_v)
				var pc: Vector2i = sim.pos[tid]
				for d in V10MjConnectPath.DIRS:
					if sim.at(pc + d) < 0:
						rim.append(tid)
						break
			for ia in rim.size():
				var a2: int = int(rim[ia])
				var pa2: Vector2i = sim.pos[a2]
				for ib in range(ia + 1, rim.size()):
					var b2: int = int(rim[ib])
					var t2: int = V10MjConnectPath.turns(sim.occ, sim.pw, sim.ph, pa2, sim.pos[b2] as Vector2i)
					if t2 < 0:
						continue
					if best_t < 0 or (want_long and t2 > best_t) or (not want_long and t2 < best_t):
						best_a = a2
						best_b = b2
						best_t = t2
					if (want_long and t2 == 2) or (not want_long and t2 <= 1):
						break
				if (want_long and best_t == 2) or (not want_long and best_t >= 0 and best_t <= 1):
					break
		if best_t < 0:
			return {}
		var path: Array = V10MjConnectPath.find(sim.occ, sim.pw, sim.ph, sim.pos[best_a] as Vector2i, sim.pos[best_b] as Vector2i)
		sim.remove(best_a, best_b, path)
		cert.append([best_a, best_b])
		if best_t == 2:
			nlong += 1
	var pairs: Array = cert.duplicate()
	pairs.reverse()
	return {"n": total, "pos": pos0, "pairs": pairs, "long": nlong}


static func _pick_weighted(open: Array, depth: Array, wsum: float, static_mode: bool, rng: RandomNumberGenerator) -> int:
	var r: = rng.randf() * wsum
	for si in open:
		r -= 1.0 + float(depth[si] * depth[si]) * (2.0 if static_mode else 0.0)
		if r <= 0.0:
			return si
	return open[open.size() - 1]


static func _write(stacks: Array, content: Array, occ: PackedInt32Array, pos: Array, pw: int, si: int) -> void:
	var cells: Array = stacks[si]
	var ids: Array = content[si]
	for i in cells.size():
		var c: Vector2i = cells[i]
		if i < ids.size():
			occ[c.y * pw + c.x] = ids[i]
			pos[ids[i]] = c
		else:
			occ[c.y * pw + c.x] = -1


static func _ins(stacks: Array, content: Array, occ: PackedInt32Array, pos: Array, pw: int, si: int, idx: int, t: int) -> void:
	content[si].insert(idx, t)
	_write(stacks, content, occ, pos, pw, si)


static func _del(stacks: Array, content: Array, occ: PackedInt32Array, pos: Array, pw: int, si: int, t: int) -> void:
	content[si].erase(t)
	_write(stacks, content, occ, pos, pw, si)


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j: = rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


# faces per pair (placement order): k distinct faces, every face used by 1–3 pairs
static func _faces(npairs: int, ratio: float, rng: RandomNumberGenerator) -> Array:
	var k: = clampi(int(ceil(npairs * ratio)), mini(npairs, 8), mini(FACES, npairs))
	k = maxi(k, int(ceil(npairs / 3.0)))
	k = mini(k, FACES)
	var pool: Array = []
	for f in FACES:
		pool.append(f)
	_shuffle(pool, rng)
	var out: Array = []
	for i in npairs:
		out.append(pool[i % k])
	_shuffle(out, rng)
	return out


# ── obstacles (MODES §5.2): «Брандмауэр» (сетка, открывается после 3 пар) and «Лёд» ───────────────────────
static func _obstacles(p: Dictionary, obst: Dictionary, rng: RandomNumberGenerator) -> void:
	if int(obst.get("net", 0)) <= 0 and int(obst.get("ice", 0)) <= 0:
		return
	var n: int = p.n
	var cert: Array = p.cert
	var step_of: = {}
	for i in cert.size():
		step_of[int(cert[i][0])] = i
		step_of[int(cert[i][1])] = i
	var at: = {}
	for t in n:
		at[Vector2i(int(p.pos[t * 2]), int(p.pos[t * 2 + 1]))] = t
	var used: = {}
	# nets: a 2×2 block of tiles that the certificate removes no earlier than step 3
	var nets: = int(obst.get("net", 0))
	var keys: Array = at.keys()
	_shuffle(keys, rng)
	for c in keys:
		if nets <= 0:
			break
		var blk: = [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(1, 1)]
		var ok: = true
		for q in blk:
			if not at.has(q) or used.has(at[q]) or step_of[at[q]] < 3:
				ok = false
				break
		if not ok:
			continue
		for q in blk:
			used[at[q]] = true
			p.lock.append([at[q], 3])
		nets -= 1
	# ice: tiles that the certificate's replay thaws before their own step
	var icen: = int(obst.get("ice", 0))
	if icen > 0:
		var b: = V10MjConnectBoard.new().load_payload(p)
		b.lock.fill(0)
		var thaw_step: = {}
		for i in cert.size():
			var a: int = cert[i][0]
			var bb: int = cert[i][1]
			for c in [b.pos[a], b.pos[bb]]:
				for d in V10MjConnectPath.DIRS:
					var t: = b.at(c + d)
					if t >= 0 and t != a and t != bb and not thaw_step.has(t):
						thaw_step[t] = i
			b.remove(a, bb)
		var cand: Array = []
		for t in thaw_step:
			if not used.has(t) and int(thaw_step[t]) < int(step_of[t]) and int(step_of[t]) >= 2:
				cand.append(t)
		_shuffle(cand, rng)
		for t in cand:
			if icen <= 0:
				break
			p.ice.append(t)
			used[t] = true
			icen -= 1


static func verify(p: Dictionary) -> String:
	if p.is_empty():
		return "empty"
	var b: = V10MjConnectBoard.new().load_payload(p)
	var seen: = {}
	for pr in p.cert:
		for t in pr:
			if seen.has(int(t)):
				return "tile %d twice in cert" % t
			seen[int(t)] = true
		if b.face[int(pr[0])] != b.face[int(pr[1])]:
			return "faces differ in cert pair"
	if seen.size() != int(p.n):
		return "cert covers %d of %d" % [seen.size(), p.n]
	var bad: = b.replay(p.cert)
	if bad >= 0:
		return "cert step %d fails" % bad
	if b.left() != 0:
		return "tiles left"
	return ""


# ── casual bot ──────────────────────────────────────────────────────────────────────────────────────────
# sees every short link (≤ 1 turn); a long link (2 turns) only with probability `see_long`; takes a random one of
# what it sees (if it sees nothing — any legal one, «долго ищет»). No move — shuffle.
static func bot(p: Dictionary, rng: RandomNumberGenerator, kind: = "casual") -> Dictionary:
	var b: = V10MjConnectBoard.new().load_payload(p)
	var see_long: = 0.35 if kind == "casual" else 1.0
	var shuffles: = 0
	var mv: = 0
	var guard: = 0
	while b.left() > 0 and guard < 400:
		guard += 1
		var seen: Array = []
		var all: Array = []
		var by_face: = {}
		for t in b.n_tiles:
			if b.selectable(t):
				var f: = b.face[t]
				if not by_face.has(f):
					by_face[f] = []
				by_face[f].append(t)
		for f in by_face:
			var g: Array = by_face[f]
			for i in g.size():
				for j in range(i + 1, g.size()):
					var tt: = V10MjConnectPath.turns(b.occ, b.pw, b.ph, b.pos[g[i]], b.pos[g[j]])
					if tt < 0:
						continue
					all.append([g[i], g[j]])
					if tt <= 1 or rng.randf() < see_long:
						seen.append([g[i], g[j]])
		if all.is_empty():
			shuffles += 1
			b.shuffle(rng)
			if shuffles > 30:
				break
			continue
		var pick: Array = seen[rng.randi_range(0, seen.size() - 1)] if not seen.is_empty() else all[rng.randi_range(0, all.size() - 1)]
		b.remove(pick[0], pick[1])
		mv += 1
	return {"shuffles": shuffles, "moves": mv, "clean": shuffles == 0 and b.left() == 0, "done": b.left() == 0}


static func bot_rate(p: Dictionary, games: int, seed: = 1) -> float:
	var ok: = 0
	for g in games:
		var r: = RandomNumberGenerator.new()
		r.seed = hash([seed, g, p.get("idx", 0), "bot"])
		if bot(p, r).clean:
			ok += 1
	return float(ok) / maxf(1.0, games)
