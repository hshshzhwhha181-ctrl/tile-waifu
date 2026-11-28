class_name V10MjBridgeLevels
extends RefCounted

# «Собери руку» — 60 уровней (docs/MODES.md §4.5). Каждый уровень строится детерминированно из номера:
#   пирамида (основание c×r, слоёв L, верхний слой сдвинут на полклетки) → целевая рука H* (14 фишек, 4 набора и пара,
#   с комбинацией не дешевле цели) → порядок снятия (случайный, всегда только свободные фишки) → первые 14 + d фишек
#   этого порядка = H* и d «ложных» фишек, которые надо снять и вернуть «Сбросом», чтобы добраться до нужных.
#   Остальное — приманки (≥ 30 % — похожие: соседи по масти, лишние копии, фишки «не той» комбинации).
# Сертификат: этот порядок, проигранный по правилам V10MjBridgeHand (с автосборкой), даёт победу — уровень решаем.
# Бот (solve) решает уровень сам, без знания H*: перебор с отсечением «рука ещё собираема с целью уровня».
#
# Рост требований: цель ×1 (L1–19) → ×2 (L20–34, «рука с комбинацией не дешевле ×2») → ×3 (L35–49) → ×4 (L50–60);
# «ложных» фишек на пути 0 (L1–12) → 1 (L13–34) → 2 (L35–60); пирамида растёт по главам, 10-й уровень главы — больше.

const COUNT: = 60
const SEED: = 4057
const CHAPTER_HOST: = ["hana", "mc", "rin", "yue", "nova", "hana"]
const SHAPES: = [
	[[5, 3, 2], [6, 3, 2]],
	[[5, 4, 2], [6, 4, 2]],
	[[6, 3, 3], [6, 4, 3]],
	[[6, 4, 2], [7, 4, 3]],
	[[6, 4, 3], [7, 4, 3]],
	[[7, 4, 3], [7, 4, 3]],
]

static var _cache: = {}


static func req_of(i: int) -> int:
	if i < 20:
		return 1
	if i < 35:
		return 2
	if i < 50:
		return 3
	return 4


static func digs_of(i: int) -> int:
	if i <= 12:
		return 0
	if i <= 34:
		return 1
	return 2


static func is_boss(i: int) -> bool:
	return i % 10 == 0


static func chapter_of(i: int) -> int:
	return clampi((i - 1) / 10, 0, 5)


static func shape_of(i: int) -> Array:
	return SHAPES[chapter_of(i)][1 if is_boss(i) else 0]


static func tempt_of(i: int) -> float:
	return 0.3 + 0.5 * float(i - 1) / float(COUNT - 1)


static func difficulty_name(i: int) -> String:
	if is_boss(i):
		return "Большой стол"
	if req_of(i) >= 2:
		return "Нужна комбинация от ×%d" % req_of(i)
	return "Собери любую руку"


static func positions(c: int, r: int, layers: int) -> Array:
	var out: = []
	for z in layers:
		for y in r - z:
			for x in c - z:
				out.append(Vector3(x + z * 0.5, y + z * 0.5, z))
	return out


# ── уровень ──────────────────────────────────────────────────────────────────

const BAKE_PATH: = "res://data/mj/bridge/hand_levels.json"
const BOT_BUDGET: = 1500

static var _bake: = {}


# запечённая «соль» уровня: номер варианта, который бот решает в пределах BOT_BUDGET узлов (--bridge_bake=1)
static func bake_data() -> Dictionary:
	if not _bake.is_empty():
		return _bake
	if FileAccess.file_exists(BAKE_PATH):
		var j = JSON.parse_string(FileAccess.open(BAKE_PATH, FileAccess.READ).get_as_text())
		if j is Dictionary:
			_bake = j
	return _bake


static func salt_of(i: int) -> int:
	for e in bake_data().get("levels", []):
		if int(e.i) == i:
			return int(e.salt)
	return 0


static func bake_entry(i: int) -> Dictionary:
	for e in bake_data().get("levels", []):
		if int(e.i) == i:
			return e
	return {}


static func build(i: int, salt: = -1) -> Dictionary:
	i = clampi(i, 1, COUNT)
	if salt < 0:
		salt = salt_of(i)
	var key: = "%d:%d" % [i, salt]
	if _cache.has(key):
		return _cache[key]
	var sh: Array = shape_of(i)
	var pos: = positions(int(sh[0]), int(sh[1]), int(sh[2]))
	var req: = req_of(i)
	var d: = digs_of(i)
	var rng: = RandomNumberGenerator.new()
	rng.seed = SEED + i * 104729 + salt * 7919
	var lv: = {}
	for attempt in 400:
		lv = _try(rng, i, pos, req, d)
		if not lv.is_empty():
			lv["attempt"] = attempt
			break
	if lv.is_empty():
		push_error("bridge levels: L%d failed" % i)
		return {}
	lv["salt"] = salt
	lv["seed"] = SEED + i * 104729 + salt * 7919
	_cache[key] = lv
	return lv


# запекание: для каждого уровня первая «соль», при которой бот решает уровень в пределах бюджета
static func bake(path: = BAKE_PATH, log: Callable = Callable()) -> Dictionary:
	var out: = []
	for i in range(1, COUNT + 1):
		var got: = {}
		for salt in 60:
			var lv: = build(i, salt)
			if lv.is_empty():
				continue
			var sv: = solve(lv, BOT_BUDGET)
			if bool(sv.ok):
				got = {"i": i, "salt": salt, "nodes": int(sv.nodes), "n": int(lv.n), "req": int(lv.req), "digs": int(lv.digs),
					"mult": int(V10MjBridgeHand.combos(lv.target).mult), "target": lv.target}
				break
		if got.is_empty():
			got = {"i": i, "salt": 0, "nodes": -1}
		out.append(got)
		if log.is_valid():
			log.call(got)
	var d: = {"ver": 1, "budget": BOT_BUDGET, "levels": out}
	var abs: = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f: = FileAccess.open(abs, FileAccess.WRITE)
	var lines: = PackedStringArray()
	lines.append("{\"ver\":1,\"budget\":%d,\"levels\":[" % BOT_BUDGET)
	for k in out.size():
		lines.append(JSON.stringify(out[k]) + ("," if k < out.size() - 1 else ""))
	lines.append("]}")
	f.store_string("\n".join(lines) + "\n")
	f.close()
	_bake = {}
	_cache = {}
	return d


static func _try(rng: RandomNumberGenerator, i: int, pos: Array, req: int, d: int) -> Dictionary:
	var n: = pos.size()
	var zeros: = []
	zeros.resize(n)
	zeros.fill(0)
	var r: = V10MjBridgeHand.make({"pos": pos, "kinds": zeros})
	# случайный порядок снятия (только свободные), первые 14 + d — путь сертификата
	var order: = []
	while order.size() < 14 + d:
		var fr: = r.frees()
		var t: int = fr[rng.randi() % fr.size()]
		r.present[t] = 0
		order.append(t)
	# «ложные» фишки на пути: рано в порядке и закрывают нужные
	var dig_at: = []
	if d > 0:
		var cands: = []
		for p in range(0, mini(10, order.size() - 5)):
			var t: int = order[p]
			var covers_later: = false
			for b in r.below[t]:
				if order.find(b) > p:
					covers_later = true
					break
			if covers_later:
				cands.append(p)
		if cands.size() < d:
			return {}
		_shuffle(rng, cands)
		dig_at = cands.slice(0, d)
	var target: = target_hand(rng, req)
	if target.is_empty():
		return {}
	var kinds: = []
	kinds.resize(n)
	kinds.fill(-1)
	var cnt: = V10MjBridgeTiles.counts(target)
	var tgt: = target.duplicate()
	_shuffle(rng, tgt)
	var ti: = 0
	for p in order.size():
		if dig_at.has(p):
			continue
		kinds[order[p]] = tgt[ti]
		ti += 1
	# приманки
	var tempt: = tempt_of(i)
	var plan_bad: = _plan_breakers(target)
	for p in n:
		if int(kinds[p]) >= 0:
			continue
		var k: = -1
		for g in 30:
			var cand: int
			var roll: = rng.randf()
			if roll < tempt * 0.65:
				var base: int = target[rng.randi() % 14]
				if base < 27 and rng.randf() < 0.7:
					var off: int = [-2, -1, 1, 2][rng.randi() % 4]
					var c2: = base + off
					cand = c2 if c2 >= base - base % 9 and c2 <= base - base % 9 + 8 else base
				else:
					cand = base
			elif roll < tempt and not plan_bad.is_empty():
				cand = plan_bad[rng.randi() % plan_bad.size()]
			else:
				cand = rng.randi_range(0, 33)
			if int(cnt[cand]) < 4:
				k = cand
				break
		if k < 0:
			return {}
		kinds[p] = k
		cnt[k] += 1
	var lv: = {"i": i, "pos": pos, "kinds": kinds, "req": req, "digs": d, "n": n, "target": V10MjBridgeTiles.sorted(target),
		"order": order, "dig_at": dig_at, "host": CHAPTER_HOST[chapter_of(i)], "shape": shape_of(i)}
	if not certificate_ok(lv):
		return {}
	return lv


static func _shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for k in range(a.size() - 1, 0, -1):
		var j: = rng.randi() % (k + 1)
		var t = a[k]
		a[k] = a[j]
		a[j] = t


# фишки «не той» комбинации: края и знаки рядом с «Все простые», чужая масть рядом с «Одна масть»
static func _plan_breakers(target: Array) -> Array:
	var cb: = V10MjBridgeHand.combos(target)
	var out: = []
	var ids: Array = cb.ids
	if ids.has("tanyao"):
		for k in target:
			if int(k) < 27:
				var b: = int(k) - int(k) % 9
				out.append(b)
				out.append(b + 8)
	if ids.has("chinitsu"):
		for k in target:
			for off in [9, 18]:
				out.append((int(k) + off) % 27)
	return out


# целевая рука по цели комбинации
static func target_hand(rng: RandomNumberGenerator, req: int) -> Array:
	for attempt in 200:
		var plan: = ""
		var roll: = rng.randf()
		match req:
			1:
				plan = "free" if roll < 0.65 else ("tanyao" if roll < 0.85 else "sanankou")
			2:
				plan = "tanyao" if roll < 0.45 else ("sanankou" if roll < 0.75 else "ittsu")
			3:
				plan = "ittsu" if roll < 0.35 else ("tan_san" if roll < 0.65 else "chinitsu")
			_:
				plan = "chinitsu" if roll < 0.5 else ("tan_san" if roll < 0.8 else "chin_tan")
		var h: = _hand_for(rng, plan)
		if h.size() != 14:
			continue
		var cb: = V10MjBridgeHand.combos(h)
		if int(cb.mult) >= req:
			return h
	return []


static func _hand_for(rng: RandomNumberGenerator, plan: String) -> Array:
	var suit: = rng.randi_range(0, 2)
	var allow: = func(k: int) -> bool:
		match plan:
			"tanyao", "tan_san":
				return V10MjBridgeTiles.is_simple(k)
			"chinitsu":
				return V10MjBridgeTiles.suit(k) == suit
			"chin_tan":
				return V10MjBridgeTiles.suit(k) == suit and V10MjBridgeTiles.is_simple(k)
		return true
	var c: = V10MjBridgeTiles.zero()
	var h: = []
	var add: = func(blk: Array) -> bool:
		var tmp: = c.duplicate()
		for k in blk:
			if not allow.call(int(k)):
				return false
			tmp[k] += 1
			if int(tmp[k]) > 4:
				return false
		for k in blk:
			c[k] += 1
		h.append_array(blk)
		return true
	var sets_left: = 4
	if plan == "ittsu":
		for st in [0, 3, 6]:
			add.call([suit * 9 + st, suit * 9 + st + 1, suit * 9 + st + 2])
		sets_left = 1
	elif plan == "sanankou" or plan == "tan_san":
		var made: = 0
		for g in 60:
			if made >= 3:
				break
			var k: = rng.randi_range(0, 33)
			if add.call([k, k, k]):
				made += 1
		if made < 3:
			return []
		sets_left = 1
	var guard: = 0
	while sets_left > 0 and guard < 200:
		guard += 1
		var blk: = []
		if rng.randf() < 0.65:
			var s: = suit if plan in ["chinitsu", "chin_tan"] else rng.randi_range(0, 2)
			var st: = s * 9 + rng.randi_range(0, 6)
			blk = [st, st + 1, st + 2]
		else:
			var k: = rng.randi_range(0, 33)
			if plan in ["chinitsu", "chin_tan"]:
				k = suit * 9 + rng.randi_range(0, 8)
			blk = [k, k, k]
		if add.call(blk):
			sets_left -= 1
	guard = 0
	while h.size() < 14 and guard < 200:
		guard += 1
		var k: = rng.randi_range(0, 33)
		if plan in ["chinitsu", "chin_tan"]:
			k = suit * 9 + rng.randi_range(0, 8)
		add.call([k, k])
	return h


# сертификат: путь уровня по правилам V10MjBridgeHand даёт победу
static func certificate_ok(lv: Dictionary) -> bool:
	var r: = V10MjBridgeHand.make(lv)
	var order: Array = lv.order
	var dig_at: Array = lv.dig_at
	for p in order.size():
		var t: int = order[p]
		var res: = r.take(t)
		if not bool(res.get("ok", false)):
			return false
		if dig_at.has(p):
			if not r.reset_kind(int(lv.kinds[t]), r.where(int(lv.kinds[t]))):
				return false
		elif r.lost:
			return false
	return r.won


# ── бот ──────────────────────────────────────────────────────────────────────
# Перебор в глубину с отсечением: брать можно только фишку, после которой рука ещё собираема с целью уровня
# (или победную 14-ю). «Копнуть» — взять фишку, которая закрывает другие, и сразу вернуть её «Сбросом».
# Возвращает {ok, path: [[ход, место]], nodes, resets}.

static func solve(lv: Dictionary, budget: = 6000) -> Dictionary:
	var r: = V10MjBridgeHand.make(lv)
	var st: = {"nodes": 0, "memo": {}}
	var path: = []
	var ok: = _solve(r, st, path, budget)
	return {"ok": ok, "path": path, "nodes": int(st.nodes)}


static func _solve(r: V10MjBridgeHand, st: Dictionary, path: Array, budget: int) -> bool:
	if r.won:
		return true
	if int(st.nodes) >= budget:
		return false
	st.nodes = int(st.nodes) + 1
	var key: = r.state_key()
	if (st.memo as Dictionary).has(key):
		return false
	st.memo[key] = true
	var moves: = []
	var rates: = {}
	var seen_take: = {}
	for i in r.frees():
		var k: int = r.kind[i]
		if not rates.has(k):
			rates[k] = r.rate(k)
		var rt: int = rates[k]
		var under: = []
		for b in r.below[i]:
			if r.present[b] == 1:
				under.append(b)
		var sig: = "%d:%s" % [k, str(under)]
		if rt < 1000 and not seen_take.has(sig):
			seen_take[sig] = true
			moves.append([rt * 10 - mini(under.size(), 9), "take", i])
		if r.resets_left > 0 and not under.is_empty() and r.edge.size() < V10MjBridgeHand.EDGE_MAX:
			# копать стоит, если под фишкой откроется полезная: оценка — лучшая из открывающихся
			var dig: = 60000
			for b in under:
				var opens: = true
				for a in r.above[b]:
					if a != i and r.present[a] == 1:
						opens = false
						break
				if not opens:
					continue
				var kb: int = r.kind[b]
				if not rates.has(kb):
					rates[kb] = r.rate(kb)
				if int(rates[kb]) < 1000:
					dig = mini(dig, int(rates[kb]) * 10 + 400)
			moves.append([dig, "dig", i])
	for j in r.edge.size():
		var k: int = r.edge[j]
		if not rates.has(k):
			rates[k] = r.rate(k)
		if int(rates[k]) < 1000:
			moves.append([int(rates[k]) * 10 + 5, "edge", j])
	moves.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	for m in moves:
		var c: = r.clone()
		match String(m[1]):
			"take":
				c.take(int(m[2]))
			"edge":
				c.take_edge(int(m[2]))
			"dig":
				var k: int = c.kind[int(m[2])]
				c.take(int(m[2]))
				if c.won:
					pass
				elif not c.reset_kind(k, c.where(k)):
					continue
		if c.lost:
			continue
		path.append([String(m[1]), int(m[2])])
		if _solve(c, st, path, budget):
			return true
		path.pop_back()
	return false
