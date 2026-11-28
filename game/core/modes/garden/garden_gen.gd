class_name V10MjGardenGen
extends RefCounted

# Сад 2.0 — генератор волн (docs/MODES.md §4.9). Волна — небольшая раскладка 24–40 фишек на тех же формах, что Путь
# (TWFree.gen_layout + формы V6Layouts), «доливается» на стол, когда там остаётся 6 фишек.
#
# Как волна ложится рядом со старыми фишками (их ≤ 6 на столе и ≤ 5 в лотке):
#   • новая фишка не ставится ни над, ни под, ни вплотную сбоку (на том же ярусе) к старой — и к «дому» фишки в лотке,
#     поэтому свобода старых и новых фишек не зависит друг от друга, а перелив всегда возвращает фишку на пустое место;
#   • верхний ярус без опоры (≥ 2 из 4 фишек под ним) убирается; лишнее — с верхних ярусов; число фишек чётное.
# Лица новой волны — свои (не совпадают с лицами старых фишек), каждое лицо — пара или две пары.
#
# Сертификат решаемости при лотке 6 (самотест проверяет его независимым проигрыванием):
#   1) старые фишки (стол + лоток) — точный перебор: порядок, в котором они снимаются без перелива (≤ 5 в лотке);
#   2) новая волна — лица раздаются по порядку снятия: каждый ход берёт свободную фишку и либо «открывает» новое лицо,
#      либо «закрывает» открытое; открытых одновременно ≤ hold (1–3), лоток по сертификату ≤ 4 из 6.
# Если игрок сам довёл лоток до состояния, где без перелива не обойтись, часть 1 пуста (fixed_ok = false), но
# новая волна всё равно решаема сама по себе, а перелив не проигрыш.

const N_MIN: = 24
const N_MAX: = 40
const FIRST_N: = 28
const RHYTHM: = [28, 34, 24, 38, 30, 40, 26, 36]
const SHAPES: = ["rect", "diamond", "heart", "butterfly", "cross", "ring", "pyramid", "towers", "hourglass", "arch",
	"flower", "crown", "bowl", "lantern", "frame", "chevron", "star", "torii", "islands", "moon", "fan", "pagoda", "gem",
	"wings"]
const UPPERS: = ["", "peak", "walls", "checker", "rows", "ring"]
const TRAY_CAP: = 4
const ATTEMPTS: = 40
const CLOSE_P: = 0.55


static func seed_for(run_seed: int, wave: int) -> int:
	return absi(hash([run_seed, wave, "garden"])) + 1


static func target_n(wave: int, rng: RandomNumberGenerator) -> int:
	if wave <= 1:
		return FIRST_N
	var n: int = RHYTHM[wave % RHYTHM.size()] + rng.randi_range(-1, 1) * 2
	return clampi(n, N_MIN, N_MAX)


static func _conflict(q: Vector3i, p: Vector3i) -> bool:
	var dx: = absi(q.x - p.x)
	var dy: = absi(q.y - p.y)
	if dx < 2 and dy < 2:
		return true
	return q.z == p.z and dx == 2 and dy < 2


# раскладка волны в поле, обходя занятые «дома» present
static func place(raw: Array, off: Vector2i, present: Array, rng: RandomNumberGenerator) -> Array:
	var keep: = {}
	for q0 in raw:
		var q: Vector3i = q0 + Vector3i(off.x, off.y, 0)
		if q.x < 0 or q.y < 0 or q.x > V10MjGardenRules.FIELD_X or q.y > V10MjGardenRules.FIELD_Y:
			continue
		var bad: = false
		for p in present:
			if _conflict(q, p):
				bad = true
				break
		if not bad:
			keep[q] = true
	# опора верхних ярусов
	var changed: = true
	while changed:
		changed = false
		for q in keep.keys():
			if q.z == 0:
				continue
			var sup: = 0
			for dx in [-1, 1]:
				for dy in [-1, 1]:
					if keep.has(Vector3i(q.x + dx, q.y + dy, q.z - 1)):
						sup += 1
			if sup < 2:
				keep.erase(q)
				changed = true
	var out: = keep.keys()
	out.sort_custom(func(a, b): return a.z * 100000 + a.y * 100 + a.x < b.z * 100000 + b.y * 100 + b.x)
	# лишнее — сверху (верхний ярус ни на что не опирается снизу вверх)
	while out.size() > N_MAX or out.size() % 2 == 1:
		var top_z: int = out[out.size() - 1].z
		var tops: = []
		for k in out.size():
			if out[k].z == top_z:
				tops.append(k)
		out.remove_at(tops[rng.randi() % tops.size()])
	return out


# лица по порядку снятия; возвращает {faces, order, hold, kinds, max_tray}
static func assign(pos: Array, banned: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n: = pos.size()
	var sim: = V10MjGardenRules.new()
	var idx: = {}
	for k in n:
		sim.at[k] = pos[k]
		sim.occ[pos[k]] = k
		sim.face[k] = -1
		idx[k] = true
	var palette: = []
	for f in 36:
		if not banned.has(f):
			palette.append(f)
	# тасовка палитры сидом волны
	for i in range(palette.size() - 1, 0, -1):
		var j: = rng.randi_range(0, i)
		var t = palette[i]
		palette[i] = palette[j]
		palette[j] = t
	var kinds: = clampi(n / 3, 8, 12)
	palette = palette.slice(0, mini(kinds, palette.size()))
	var used: = {}
	var hold: = rng.randi_range(1, 3)
	var faces: = []
	faces.resize(n)
	var order: = []
	var open: = []
	var max_tray: = 0
	var left: = n
	while left > 0:
		var fr: = sim.frees()
		if fr.is_empty():
			break
		var i: int = fr[rng.randi() % fr.size()]
		var close: bool = not open.is_empty() and (left <= open.size() or open.size() >= mini(hold, TRAY_CAP) or rng.randf() < CLOSE_P)
		if close:
			faces[i] = open.pop_front()
		else:
			var best: = -1
			var best_u: = 1 << 30
			for f in palette:
				if open.has(f):
					continue
				var u: = int(used.get(f, 0))
				if u < best_u:
					best_u = u
					best = f
			faces[i] = best
			used[best] = best_u + 1
			open.append(best)
			max_tray = maxi(max_tray, open.size())
		sim.occ.erase(pos[i])
		order.append(i)
		left -= 1
	return {"faces": faces, "order": order, "hold": hold, "kinds": palette.size(), "max_tray": max_tray,
		"complete": order.size() == n and open.is_empty()}


# точный перебор: порядок снятия старых фишек без перелива (ids) или null
static func fixed_order(r: V10MjGardenRules) -> Variant:
	var board: = r.board_ids()
	var tray: = r.tray_faces()
	var memo: = {}
	var res = _dfs(r, board, tray, [], memo)
	return res


static func _dfs(r: V10MjGardenRules, board: Array, tray: Array, path: Array, memo: Dictionary) -> Variant:
	if board.is_empty():
		return path if tray.is_empty() else null
	var key: = str(board) + "|" + str(tray)
	if memo.has(key):
		return null
	memo[key] = true
	# свобода на «временном» столе: только эти фишки
	var occ: = {}
	for id in board:
		occ[r.at[id]] = id
	for id in board:
		if not _free_in(r.at[id], occ):
			continue
		var f: int = r.face[id]
		var nt: = tray.duplicate()
		if nt.has(f):
			nt.erase(f)
		else:
			nt.append(f)
			if nt.size() >= V10MjGardenRules.SLOTS:
				continue
		var nb: = board.duplicate()
		nb.erase(id)
		var got = _dfs(r, nb, nt, path + [id], memo)
		if got != null:
			return got
	return null


static func _free_in(p: Vector3i, occ: Dictionary) -> bool:
	for z in range(p.z + 1, V10MjGardenRules.MAX_Z + 1):
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if occ.has(Vector3i(p.x + dx, p.y + dy, z)):
					return false
	var left: = false
	var right: = false
	for dy in [-1, 0, 1]:
		if occ.has(Vector3i(p.x - 2, p.y + dy, p.z)):
			left = true
		if occ.has(Vector3i(p.x + 2, p.y + dy, p.z)):
			right = true
	return not (left and right)


# следующая волна для состояния r (не меняет r): {wave, pos, faces, order, fixed, fixed_ok, n, shape, hold, kinds}
static func make_wave(r: V10MjGardenRules) -> Dictionary:
	var w: = r.wave + 1
	var rng: = RandomNumberGenerator.new()
	rng.seed = seed_for(r.run_seed, w)
	var present: = r.present_positions()
	var want: = target_n(w, rng)
	var best: = []
	var best_cfg: = {}
	var best_d: = 1 << 30
	for a in ATTEMPTS:
		var cols: = rng.randi_range(5, 6)
		var rows: = rng.randi_range(6, 7)
		var cfg: = {
			"seed": rng.randi(), "cols": cols, "rows": rows, "layers": rng.randi_range(2, 3),
			"fill": rng.randf_range(0.6, 0.9), "shape": SHAPES[rng.randi() % SHAPES.size()],
			"upper": UPPERS[rng.randi() % UPPERS.size()],
		}
		if a < 2 and w <= 1:
			cfg.shape = "rect" if a == 0 else cfg.shape
		var raw: Array = TWFree.gen_layout(cfg)
		var free_x: = V10MjGardenRules.FIELD_X - 2 * (cols - 1)
		var free_y: = V10MjGardenRules.FIELD_Y - 2 * (rows - 1)
		var off: = Vector2i(rng.randi_range(0, free_x), rng.randi_range(0, free_y))
		var pos: = place(raw, off, present, rng)
		var n: = pos.size()
		var d: = absi(n - want) + (1000 if n < N_MIN else 0)
		if d < best_d:
			best_d = d
			best = pos
			best_cfg = cfg
		if d == 0:
			break
	# старые фишки раздробили поле: полная раскладка во всё поле, ярусы 3–4 (вместимость всегда ≥ 24)
	var extra: = 0
	while best.size() < N_MIN and extra < 16:
		var cfg2: = {"seed": rng.randi(), "cols": 6, "rows": 7, "layers": 3 + extra % 2, "fill": 1.0,
			"shape": "rect", "upper": ""}
		var off2: = Vector2i(extra % (V10MjGardenRules.FIELD_X - 10 + 1), 0)
		var pos2: = place(TWFree.gen_layout(cfg2), off2, present, rng)
		if pos2.size() > best.size():
			best = pos2
			best_cfg = cfg2
		extra += 1
	var banned: = {}
	for id in r.present_ids():
		banned[int(r.face[id])] = true
	var asg: = assign(best, banned, rng)
	var fo = fixed_order(r)
	return {
		"wave": w, "pos": best, "faces": asg.faces, "order": asg.order, "complete": asg.complete,
		"fixed": fo if fo != null else [], "fixed_ok": fo != null, "n": best.size(), "shape": String(best_cfg.get("shape", "")),
		"hold": asg.hold, "kinds": asg.kinds, "max_tray": asg.max_tray,
	}


# Независимая проверка сертификата на копии: после pour(wave) — снять старые по wave.fixed, затем новые по
# wave.order; каждый ход — свободная фишка, ни одного перелива, в конце стол и лоток пусты.
# new_ids — id, которые pour выдал новым позициям (по индексу pos). Возвращает {ok, max_tray, why}.
static func verify(r_after_pour: V10MjGardenRules, wave: Dictionary, new_ids: Array, need_fixed: = true) -> Dictionary:
	var c: = r_after_pour.clone()
	var max_tray: = c.tray.size()
	var seq: = []
	if need_fixed:
		if not bool(wave.fixed_ok):
			return {"ok": false, "max_tray": max_tray, "why": "fixed"}
		seq.append_array(wave.fixed)
	for k in wave.order:
		seq.append(new_ids[int(k)])
	for id in seq:
		var res: = c.pick(int(id))
		if not res.ok:
			return {"ok": false, "max_tray": max_tray, "why": "not free %d" % int(id)}
		if res.overflow:
			return {"ok": false, "max_tray": max_tray, "why": "overflow"}
		max_tray = maxi(max_tray, c.tray.size())
	if c.board_count() != 0 or not c.tray.is_empty():
		return {"ok": false, "max_tray": max_tray, "why": "left %d/%d" % [c.board_count(), c.tray.size()]}
	return {"ok": true, "max_tray": max_tray, "why": ""}


# только новая волна (как отдельный стол, пустой лоток)
static func verify_alone(wave: Dictionary) -> Dictionary:
	var r: = V10MjGardenRules.make(1)
	var ids: = r.pour(wave.pos, wave.faces)
	return verify(r, wave, ids, false)
