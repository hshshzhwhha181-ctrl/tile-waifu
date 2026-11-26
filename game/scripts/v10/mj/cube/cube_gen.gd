class_name V10MjCubeGen
extends RefCounted

# Генератор Куба: решаемость — обратная укладка в 3D по правилу свободы (docs/MODES.md §4.4 «Сложность»).
# Фигура сначала «разбирается» по правилу: на каждом шаге берутся две свободные и видимые клетки (V10MjCubeRules:
# открыты две соседние грани + прямая видимость по оси). Обратный порядок — это укладка пар; затем парам раздаются
# символы. Любая раздача символов по этому порядку проходима, порядок хранится как сертификат (lv.order).
# Сложность: доля разных символов (меньше повторов — труднее), разнос пары (spread: далеко друг от друга, на разных
# сторонах — нужно вращать), глубина фигуры. «Мотив»: у части символов по 2 пары, иногда подряд в сертификате.
#
#   V10MjCubeGen.build(i, seed_k = 0) -> {i, name, host, chapter, slot, kind, seed, cells, faces, order, n, pairs,
#       kinds, core, relic_at, dims, par3, par2, hidden0, ok}
#   V10MjCubeGen.with_signature(lv, face) -> lv          её фишка-подпись в колоде (перекраска одного символа)
#   V10MjCubeGen.certificate_ok(lv) -> bool

const PARAMS: = {
	# доля разных символов к числу пар, разнос пары, доля символов, у которых пары идут подряд (Мотив)
	"easy": {"kinds": 0.45, "spread": 0.15, "motif": 0.5},
	"normal": {"kinds": 0.6, "spread": 0.45, "motif": 0.35},
	"hard": {"kinds": 0.78, "spread": 0.75, "motif": 0.25},
	"rest": {"kinds": 0.5, "spread": 0.25, "motif": 0.5},
	"boss": {"kinds": 0.85, "spread": 0.85, "motif": 0.25},
}
const DATA_PATH: = "res://data/mj/cube/figures.json"
const TILE_FACES: = 36


static func seed_of(i: int, seed_k: int) -> int:
	return 91733 + i * 7919 + seed_k * 104729


static func build(i: int, seed_k: = 0) -> Dictionary:
	var fig: = V10MjCubeShapes.figure(i)
	var kind: String = fig.kind
	var pr: Dictionary = PARAMS[kind]
	var rng: = RandomNumberGenerator.new()
	rng.seed = seed_of(i, seed_k)
	var cells: Array = fig.cells
	var n: = cells.size()
	var zero: = []
	zero.resize(n)
	zero.fill(0)
	var base: = V10MjCubeRules.make(cells, zero)
	var spread: float = pr.spread
	var center: = Vector3(fig.dims - Vector3i.ONE) * 0.5
	var picker: = func(sim: V10MjCubeRules, cand: Array, r: RandomNumberGenerator) -> Array:
		var a: int = cand[r.randi() % cand.size()]
		var far: = r.randf() < spread
		var best: = -1
		var bs: = -INF
		for t in mini(7, cand.size()):
			var b: int = cand[r.randi() % cand.size()]
			if b == a:
				continue
			var d: = Vector3(sim.cells[a] - sim.cells[b]).length()
			# far pairs prefer opposite sides of the figure (the player has to turn it)
			if far:
				d += (Vector3(sim.cells[a]) - center).normalized().dot(-(Vector3(sim.cells[b]) - center).normalized()) * 2.0
			var s: = d if far else -d
			if s > bs:
				bs = s
				best = b
		if best < 0:
			for b in cand:
				if b != a:
					best = b
					break
		return [a, best]
	var order: = base.random_order(rng, 80, picker)
	var lv: = {"i": i, "name": fig.name, "host": fig.host, "chapter": fig.chapter, "slot": fig.slot, "kind": kind,
		"seed": seed_of(i, seed_k), "seed_k": seed_k, "cells": cells, "core": fig.core, "relic_at": fig.relic_at,
		"dims": fig.dims, "n": n, "pairs": n / 2, "order": order, "ok": not order.is_empty()}
	if order.is_empty():
		lv.faces = zero
		lv.kinds = 0
		return lv
	# symbols: K kinds, every kind ≥ 1 pair, ≤ 2 pairs (4 copies)
	var P: = order.size()
	var K: = clampi(int(round(P * float(pr.kinds))), mini(6, P), mini(TILE_FACES, P))
	K = maxi(K, (P + 1) / 2)
	var pool: = range(TILE_FACES)
	for k in range(pool.size() - 1, 0, -1):
		var j: = rng.randi() % (k + 1)
		var t = pool[k]
		pool[k] = pool[j]
		pool[j] = t
	var kinds: Array = pool.slice(0, K)
	var count: = {}
	for f in kinds:
		count[f] = 1
	var extra: = P - K
	var doubles: = kinds.duplicate()
	for k in range(doubles.size() - 1, 0, -1):
		var j: = rng.randi() % (k + 1)
		var t = doubles[k]
		doubles[k] = doubles[j]
		doubles[j] = t
	for k in extra:
		count[doubles[k]] = 2
	# blocks: a doubled kind is either one block [f, f] (consecutive in the certificate → a Мотив is on the way)
	# or two separate entries
	var blocks: = []
	for f in kinds:
		if int(count[f]) == 2 and rng.randf() < float(pr.motif):
			blocks.append([f, f])
		else:
			for c in int(count[f]):
				blocks.append([f])
	for k in range(blocks.size() - 1, 0, -1):
		var j: = rng.randi() % (k + 1)
		var t = blocks[k]
		blocks[k] = blocks[j]
		blocks[j] = t
	var seq: = []
	for b in blocks:
		seq.append_array(b)
	var faces: = zero.duplicate()
	for k in P:
		faces[order[k][0]] = seq[k]
		faces[order[k][1]] = seq[k]
	lv.faces = faces
	lv.kinds = K
	lv.par3 = P + 1
	lv.par2 = P + maxi(3, P / 5)
	var r0: = V10MjCubeRules.make(cells, faces)
	var hidden: = 0
	for t in n:
		if not r0.tappable(t):
			hidden += 1
	lv.hidden0 = float(hidden) / float(n)
	return lv


static func certificate_ok(lv: Dictionary) -> bool:
	if not lv.get("ok", false):
		return false
	var r: = V10MjCubeRules.make(lv.cells, lv.faces)
	return r.replay(lv.order)


# her signature tile in the deck (MODES §3.4.1): if the symbol is missing, one kind is recoloured to it everywhere
# (a bijective relabel — the certificate stays valid)
static func with_signature(lv: Dictionary, sig: int) -> Dictionary:
	if sig < 0 or sig >= TILE_FACES or not lv.get("ok", false):
		return lv
	var faces: Array = lv.faces
	if faces.has(sig):
		return lv
	var out: = lv.duplicate()
	var from: int = faces[lv.order[0][0]] if not (lv.order as Array).is_empty() else faces[0]
	var nf: = faces.duplicate()
	for k in nf.size():
		if int(nf[k]) == from:
			nf[k] = sig
	out.faces = nf
	return out


# metadata for the hub / integrator (figures.json): n, kinds, par, hidden share, host, relic
static func bake(path: = DATA_PATH) -> Dictionary:
	var figs: = []
	for i in range(1, V10MjCubeShapes.COUNT + 1):
		var lv: = build(i)
		figs.append({"i": i, "name": lv.name, "host": lv.host, "kind": lv.kind, "n": lv.n, "pairs": lv.pairs,
			"kinds": lv.kinds, "par3": lv.get("par3", 0), "par2": lv.get("par2", 0),
			"hidden0": snappedf(float(lv.get("hidden0", 0.0)), 0.01), "dims": [lv.dims.x, lv.dims.y, lv.dims.z],
			"relic": V10MjCubeShapes.is_boss(i)})
	var d: = {"ver": 1, "count": figs.size(), "figures": figs}
	var abs_path: = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f: = FileAccess.open(abs_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))
		f.close()
	return d
