class_name V10MjTriplesRules
extends RefCounted

# V10MjTriplesRules — безголовый движок правил Троек (docs/MODES.md §4.2). Ни узлов, ни сцены: одна правда для доски,
# генератора, бота, сертификата и самотеста.
#
# Стол: фишки на позициях TrayBoard.gen_layout (x, y — полушаги сетки, z — ярус). Фишка СВОБОДНА, если на ней не лежит
# ни одна фишка стола (жанр «тайл-матч»: боковых блокировок нет, «не могу взять» не бывает). Тап по свободной — в лоток.
# Лоток: SLOTS = 7 ячеек (+1 бустером). Одинаковые встают рядом (после последней такой же), остальные — в конец.
# Три одинаковые в лотке схлопываются сразу. Проигрыш — строго когда в лотке 7 из 7 и тройки нет.
#
#   r = V10MjTriplesRules.make(pos: Array[Vector3i], faces: PackedInt32Array)
#   r.is_free(i) / r.frees / r.board_count() / r.tray / r.history
#   r.pick(i) -> {ok, at, triple: Array[int], lost, won}
#   r.return_last(n = 3) -> Array[int]           «Вернуть 3»: последние n фишек лотка на свои места
#   r.add_slot()                                  «+1 ячейка» (один раз за партию)
#   r.remove(ids)                                 снять фишки мимо лотка («Магнит», Приёмы)
#   r.reshuffle(rng) -> bool                       «Перемешать»: новые лица на столе, стол остаётся решаемым
#   r.clone()                                     копия состояния (бот, решатель, самотест)
#   r.can_auto_finish() -> bool                   все фишки свободны и жадный добор не переполнит лоток
#   V10MjTriplesRules.replay(pos, faces, order, slots) -> bool   проверка сертификата

const SLOTS: = 7
const SLOTS_MAX: = 8

var pos: Array = []
var face: PackedInt32Array = PackedInt32Array()
var covers: Array = []          # covers[i] — индексы фишек, на которых лежит i
var under: Array = []           # under[i]  — индексы фишек, лежащих на i
var present: PackedByteArray = PackedByteArray()
var cnt: PackedInt32Array = PackedInt32Array()   # сколько фишек стола лежит на i сейчас
var frees: Array[int] = []      # свободные фишки стола
var tray: Array[int] = []       # порядок в лотке (автосортировка)
var history: Array[int] = []    # порядок попадания в лоток
var slots: = SLOTS
var on_board: = 0
var lost: = false
var won: = false
var triples: = 0
var max_tray: = 0
var last_shuffle_order: Array[int] = []


static func covers_rel(o: Vector3i, t: Vector3i) -> bool:
	return o.z > t.z and absi(o.x - t.x) < 2 and absi(o.y - t.y) < 2


static func make(p: Array, f: PackedInt32Array) -> V10MjTriplesRules:
	var r: = V10MjTriplesRules.new()
	r.pos = p
	r.face = f.duplicate()
	var n: = p.size()
	r.covers.resize(n)
	r.under.resize(n)
	for i in n:
		r.covers[i] = []
		r.under[i] = []
	for i in n:
		var a: Vector3i = p[i]
		for j in n:
			if i != j and covers_rel(p[j], a):
				(r.under[i] as Array).append(j)
	for i in n:
		for j in (r.under[i] as Array):
			(r.covers[j] as Array).append(i)
	r.present.resize(n)
	r.present.fill(1)
	r.cnt.resize(n)
	for i in n:
		r.cnt[i] = (r.under[i] as Array).size()
	r.on_board = n
	r.frees.clear()
	for i in n:
		if r.cnt[i] == 0:
			r.frees.append(i)
	return r


func clone() -> V10MjTriplesRules:
	var r: = V10MjTriplesRules.new()
	r.pos = pos
	r.face = face.duplicate()
	r.covers = covers
	r.under = under
	r.present = present.duplicate()
	r.cnt = cnt.duplicate()
	r.frees = frees.duplicate()
	r.tray = tray.duplicate()
	r.history = history.duplicate()
	r.slots = slots
	r.on_board = on_board
	r.lost = lost
	r.won = won
	r.triples = triples
	r.max_tray = max_tray
	return r


func size() -> int:
	return pos.size()


func is_free(i: int) -> bool:
	return i >= 0 and i < present.size() and present[i] == 1 and cnt[i] == 0


func board_count() -> int:
	return on_board


func tray_count(f: int) -> int:
	var n: = 0
	for t in tray:
		if face[t] == f:
			n += 1
	return n


# снять фишку со стола (в лоток или мимо него): счётчики покрытия и список свободных
func _take(i: int) -> void:
	present[i] = 0
	on_board -= 1
	frees.erase(i)
	for c in (covers[i] as Array):
		cnt[c] -= 1
		if cnt[c] == 0 and present[c] == 1:
			frees.append(c)


# вернуть фишку на её место
func _put(i: int) -> void:
	present[i] = 1
	on_board += 1
	for c in (covers[i] as Array):
		if cnt[c] == 0 and present[c] == 1:
			frees.erase(c)
		cnt[c] += 1
	if cnt[i] == 0 and not frees.has(i):
		frees.append(i)


# место, куда встанет фишка лица f: сразу после последней такой же, иначе в конец
func insert_at(f: int) -> int:
	var at: = -1
	for k in tray.size():
		if face[tray[k]] == f:
			at = k
	return tray.size() if at < 0 else at + 1


func pick(i: int) -> Dictionary:
	var out: = {"ok": false, "at": -1, "triple": [], "lost": false, "won": false}
	if lost or won or not is_free(i):
		return out
	_take(i)
	var f: = face[i]
	var at: = insert_at(f)
	tray.insert(at, i)
	history.append(i)
	out.ok = true
	out.at = at
	var same: Array[int] = []
	for t in tray:
		if face[t] == f:
			same.append(t)
	if same.size() >= 3:
		var tri: Array[int] = []
		for k in 3:
			tri.append(same[k])
		for t in tri:
			tray.erase(t)
			history.erase(t)
		triples += 1
		out.triple = tri
	else:
		max_tray = maxi(max_tray, tray.size())
		if tray.size() >= slots:
			lost = true
			out.lost = true
	if on_board == 0 and tray.is_empty():
		won = true
		out.won = true
	return out


# «Вернуть 3»: последние n фишек лотка (по порядку попадания) на свои места на столе. Снимает проигрыш.
func return_last(n: = 3) -> Array[int]:
	var back: Array[int] = []
	for k in mini(n, history.size()):
		var t: int = history.pop_back()
		tray.erase(t)
		back.append(t)
	# возвращаем сверху вниз: фишка с верхнего яруса последней (её счётчики правильны в любом порядке)
	for t in back:
		_put(t)
	if not back.is_empty():
		lost = false
	return back


func add_slot() -> bool:
	if slots >= SLOTS_MAX:
		return false
	slots += 1
	if lost and tray.size() < slots:
		lost = false
	return true


# снять фишки мимо лотка (Магнит, Приёмы). Фишки лотка из списка уходят из лотка.
func remove(ids: Array) -> void:
	for i in ids:
		if present[i] == 1:
			_take(i)
		elif tray.has(i):
			tray.erase(i)
			history.erase(i)
	if on_board == 0 and tray.is_empty():
		won = true


# ── Приёмы и помощь ──────────────────────────────────────────────────────────

# тройка для Приёма: лицо, которое разгрузит лоток (сначала пара в лотке, потом одиночка), иначе лучшее на столе.
# deep = true — самая глубокая тройка (Нова). Возвращает индексы трёх фишек (часть может лежать в лотке).
func ult_triple(deep: = false) -> Array[int]:
	var tc: = {}
	for t in tray:
		tc[face[t]] = int(tc.get(face[t], 0)) + 1
	var board_by: = {}
	for i in present.size():
		if present[i] == 1:
			if not board_by.has(face[i]):
				board_by[face[i]] = []
			(board_by[face[i]] as Array).append(i)
	var best_f: = -1
	var best_s: = -INF
	for f in board_by:
		var need: = 3 - int(tc.get(f, 0))
		var lst: Array = board_by[f]
		if lst.size() < need:
			continue
		lst.sort_custom(func(a, b): return cnt[a] > cnt[b] if deep else cnt[a] < cnt[b])
		var s: = 0.0
		if deep:
			for k in need:
				s += cnt[lst[k]] * 10.0 + pos[lst[k]].z
		else:
			s = int(tc.get(f, 0)) * 100.0 - need
		if s > best_s:
			best_s = s
			best_f = f
	if best_f < 0:
		return []
	var out: Array[int] = []
	for t in tray:
		if face[t] == best_f:
			out.append(t)
	var lst2: Array = board_by[best_f]
	var k2: = 0
	while out.size() < 3 and k2 < lst2.size():
		out.append(lst2[k2])
		k2 += 1
	return out


# жадный добор, когда на столе всё свободно: «Благословение стола». Порядок фишек или [] если лоток переполнится.
func auto_finish_order() -> Array[int]:
	var out: Array[int] = []
	if lost or won:
		return out
	for i in present.size():
		if present[i] == 1 and cnt[i] != 0:
			return []
	var r: = clone()
	while r.on_board > 0:
		var pick_i: = -1
		var best: = -1
		for i in r.frees:
			var c: = r.tray_count(r.face[i])
			if c > best:
				best = c
				pick_i = i
		if pick_i < 0:
			return []
		# новая масть, когда в лотке нет места на пару, — тупик
		var res: = r.pick(pick_i)
		out.append(pick_i)
		if res.lost:
			return []
	return out if r.won else []


func can_auto_finish() -> bool:
	return not auto_finish_order().is_empty()


# ── «Перемешать»: новые лица фишкам стола с сертификатом от текущего состояния ─────────────────────────────

func removal_order(rng: RandomNumberGenerator, dig: = 0.3) -> Array[int]:
	var r: = clone()
	r.tray.clear()
	r.history.clear()
	var order: Array[int] = []
	var recent: Array[int] = []
	while r.on_board > 0:
		var fr: = r.frees
		if fr.is_empty():
			break
		var pick_i: int
		var dig_c: Array[int] = []
		for x in recent:
			if r.present[x] == 1 and r.cnt[x] == 0:
				dig_c.append(x)
		if not dig_c.is_empty() and rng.randf() < dig:
			pick_i = dig_c[rng.randi() % dig_c.size()]
		else:
			pick_i = fr[rng.randi() % fr.size()]
		var before: = {}
		for x in fr:
			before[x] = true
		r._take(pick_i)
		order.append(pick_i)
		recent.clear()
		for x in r.frees:
			if not before.has(x):
				recent.append(x)
	return order


# open: [[face, need], ...] — группы, уже начатые в лотке; avail[face] — сколько фишек этого лица идёт в новые группы
# Возвращает лица по порядку order (или пусто, если жадность упёрлась). cap — максимум фишек в лотке по сертификату.
static func assign_greedy(order: Array, open_in: Array, tray_n: int, avail_in: Dictionary, cap: int, hold: int,
		p_open: float, spread: float, rng: RandomNumberGenerator, groups_out = null) -> PackedInt32Array:
	var n: = order.size()
	var out: = PackedInt32Array()
	out.resize(n)
	var grp: = PackedInt32Array()
	grp.resize(n)
	var open: Array = []
	var gid: = 0
	for o in open_in:
		open.append([int(o[0]), int(o[1]), -1 - gid])
		gid += 1
	var avail: = avail_in.duplicate()
	var used: = {}
	var tsz: = tray_n
	var gcount: = 0
	for k in n:
		var left_after: = n - k - 1
		var need_total: = 0
		for o in open:
			need_total += int(o[1])
		var open_faces: = {}
		for o in open:
			open_faces[int(o[0])] = true
		var cand: Array = []
		for f in avail:
			if int(avail[f]) >= 3 and not open_faces.has(f):
				cand.append(f)
		var can_open: bool = not cand.is_empty() and open.size() < hold and tsz + 1 <= cap and need_total + 2 <= left_after
		var do_join: bool = not open.is_empty() and (not can_open or rng.randf() >= p_open)
		# закрыть группу нельзя, если от этого лоток переполнится (группа с need 2 станет need 1: +1 фишка)
		if do_join:
			var choices: Array = []
			for j in open.size():
				var o: Array = open[j]
				if int(o[1]) == 1 or tsz + 1 <= cap:
					choices.append(j)
			if choices.is_empty():
				if not can_open:
					return PackedInt32Array()
				do_join = false
			else:
				var j: int
				if rng.randf() < spread:
					j = choices[rng.randi() % choices.size()]
				else:
					# чаще закрываем ту, которой осталось меньше (пара в лотке)
					j = choices[0]
					for c in choices:
						if int(open[c][1]) < int(open[j][1]):
							j = c
				var o2: Array = open[j]
				out[k] = int(o2[0])
				grp[k] = int(o2[2])
				o2[1] = int(o2[1]) - 1
				if int(o2[1]) == 0:
					tsz -= 2
					open.remove_at(j)
				else:
					tsz += 1
				continue
		if not can_open:
			return PackedInt32Array()
		# новая группа: лицо с наименьшим числом использований, случайно среди равных
		var best: Array = []
		var bu: = 1 << 30
		for f in cand:
			var u: = int(used.get(f, 0))
			if u < bu:
				bu = u
				best = [f]
			elif u == bu:
				best.append(f)
		var nf: int = best[rng.randi() % best.size()]
		used[nf] = int(used.get(nf, 0)) + 1
		avail[nf] = int(avail[nf]) - 3
		out[k] = nf
		grp[k] = gcount
		open.append([nf, 2, gcount])
		gcount += 1
		tsz += 1
	if not open.is_empty():
		return PackedInt32Array()
	if groups_out is Array:
		(groups_out as Array).clear()
		for g in grp:
			(groups_out as Array).append(g)
	return out


func reshuffle(rng: RandomNumberGenerator, tries: = 40) -> bool:
	if lost or won or on_board == 0:
		return false
	var tc: = {}
	for t in tray:
		tc[face[t]] = int(tc.get(face[t], 0)) + 1
	var bc: = {}
	var board: Array[int] = []
	for i in present.size():
		if present[i] == 1:
			board.append(i)
			bc[face[i]] = int(bc.get(face[i], 0)) + 1
	var open_in: Array = []
	var avail: = {}
	for f in bc:
		var a: = int(bc[f])
		if tc.has(f):
			var need: = 3 - int(tc[f])
			open_in.append([f, need])
			a -= need
		if a < 0 or a % 3 != 0:
			return false
		avail[f] = a
	for f in tc:
		if not bc.has(f):
			return false
	var cap: = slots - 1
	for attempt in tries:
		var order: = removal_order(rng, 0.2)
		if order.size() != board.size():
			return false
		var hold: = maxi(open_in.size() + 1, 2)
		var faces: = assign_greedy(order, open_in, tray.size(), avail, cap, hold, 0.3, 0.2, rng)
		if faces.is_empty():
			continue
		var newf: = face.duplicate()
		for k in order.size():
			newf[order[k]] = faces[k]
		# проверка сертификатом от текущего состояния
		var r: = clone()
		r.face = newf
		var ok: = true
		for i in order:
			var res: = r.pick(i)
			if not res.ok or res.lost:
				ok = false
				break
		if ok and r.won:
			face = newf
			last_shuffle_order = order
			return true
	return false


# ── сертификат ───────────────────────────────────────────────────────────────

static func replay(p: Array, f: PackedInt32Array, order: Array, n_slots: = SLOTS) -> bool:
	var r: = make(p, f)
	r.slots = n_slots
	if order.size() != p.size():
		return false
	for i in order:
		var res: = r.pick(int(i))
		if not res.ok or res.lost:
			return false
	return r.won


# проиграть остаток порядка от текущего состояния (фишки, которых нет на столе, пропускаются)
func replay_rest(order: Array) -> bool:
	var r: = clone()
	for i in order:
		var ii: = int(i)
		if r.present[ii] == 0:
			continue
		var res: = r.pick(ii)
		if not res.ok or res.lost:
			return false
	return r.won


# ── решатель (ограниченный DFS с памятью) для самотеста ───────────────────────

func key() -> String:
	var tc: = PackedInt32Array()
	for t in tray:
		tc.append(face[t])
	tc.sort()
	return present.hex_encode() + ":" + str(tc) + ":" + str(slots)


static func solve(r: V10MjTriplesRules, limit: = 20000) -> int:
	# 1 — решаемо, 0 — нет, -1 — не знаю (лимит)
	var seen: = {}
	var budget: = [limit]
	var res: = _dfs(r, seen, budget)
	if res:
		return 1
	return -1 if budget[0] <= 0 else 0


static func _dfs(r: V10MjTriplesRules, seen: Dictionary, budget: Array) -> bool:
	if r.won:
		return true
	if r.lost:
		return false
	budget[0] -= 1
	if budget[0] <= 0:
		return false
	var k: = r.key()
	if seen.has(k):
		return false
	seen[k] = true
	# ходы: по одному представителю на (лицо, «что откроет»); сначала завершающие тройку
	var moves: Array = r.frees.duplicate()
	moves.sort_custom(func(a, b):
		var ca: = r.tray_count(r.face[a])
		var cb: = r.tray_count(r.face[b])
		if ca != cb:
			return ca > cb
		return (r.covers[a] as Array).size() > (r.covers[b] as Array).size())
	var tried: = {}
	for m in moves:
		var sig: = str(r.face[m]) + "|" + str(r.covers[m])
		if (r.covers[m] as Array).is_empty():
			sig = str(r.face[m]) + "|leaf"
		if tried.has(sig):
			continue
		tried[sig] = true
		var c: = r.clone()
		c.pick(m)
		if _dfs(c, seen, budget):
			return true
		if budget[0] <= 0:
			return false
	return false
