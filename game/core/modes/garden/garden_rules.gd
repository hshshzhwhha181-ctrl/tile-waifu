class_name V10MjGardenRules
extends RefCounted

# Сад 2.0 — безголовые правила (docs/MODES.md §4.9). Одна правда для экрана, бота, генератора волн и самотеста.
#
# Стол бесконечный: фишки приходят волнами (V10MjGardenGen). Свобода фишки — как в Пути (tray_board): сверху ничего
# не лежит и хотя бы один край (слева или справа на том же ярусе) открыт. Тап по свободной фишке кладёт её в лоток
# на 6; такая же фишка в лотке — пара снимается. Лоток заполнен 6/6 без пары — «чашка переливается»: три последние
# фишки возвращаются на свои места на столе, серия сбрасывается. Проигрыша нет, таймера нет.
# Счёт = пары × множитель серии: серия 1–3 → ×1, 4–6 → ×2, 7–9 → ×3, 10–12 → ×4, 13 и больше → ×5.
# Когда на столе остаётся 6 фишек (need_pour), экран просит у генератора следующую волну и «доливает» её (pour).
#
# Координаты — полушаг сетки tray_board: x 0…12, y 0…12 (поле 7 × 7 клеток на нижнем ярусе; волна — до 6 × 7), z — ярус.
# Фишка — целое id (растёт всю партию). Позиция фишки в лотке остаётся её «домом»: перелив возвращает туда, и
# генератор не ставит туда новые фишки, пока она не снята.

const SLOTS: = 6
const POUR_AT: = 6
const BACK: = 3
const SERIES_STEP: = 3
const MULT_MAX: = 5
const FIELD_X: = 12
const FIELD_Y: = 12
const MAX_Z: = 5

var face: = {}          # id -> лицо 0…35
var at: = {}            # id -> Vector3i (дом)
var occ: = {}           # Vector3i -> id (фишки на столе)
var tray: Array[int] = []
var next_id: = 0
var wave: = 0           # сколько волн налито (1 — первый стол)
var series: = 0
var best_series: = 0    # лучшая серия этой партии
var score: = 0
var pairs: = 0
var overflows: = 0
var run_seed: = 1
var wave_tiles: = {}    # id -> номер волны, в которой фишка пришла (для «Осталось» и снимков)


static func make(seed: int) -> V10MjGardenRules:
	var r: = V10MjGardenRules.new()
	r.run_seed = seed
	return r


# ── состояние ───────────────────────────────────────────────────────────────

func board_count() -> int:
	return occ.size()


func on_board(id: int) -> bool:
	return at.has(id) and occ.get(at[id], -1) == id


func in_tray(id: int) -> bool:
	return tray.has(id)


func board_ids() -> Array[int]:
	var out: Array[int] = []
	for p in occ:
		out.append(int(occ[p]))
	out.sort()
	return out


func is_free(id: int) -> bool:
	if not on_board(id):
		return false
	var p: Vector3i = at[id]
	for z in range(p.z + 1, MAX_Z + 1):
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


func frees() -> Array[int]:
	var out: Array[int] = []
	for p in occ:
		var id: int = occ[p]
		if is_free(id):
			out.append(id)
	out.sort()
	return out


static func mult_for(s: int) -> int:
	if s <= 0:
		return 1
	return mini(MULT_MAX, 1 + (s - 1) / SERIES_STEP)


func mult() -> int:
	return mult_for(series)


func need_pour() -> bool:
	return occ.size() <= POUR_AT


# все занятые «дома»: стол + лоток (генератор волны их обходит)
func present_positions() -> Array:
	var out: = []
	for p in occ:
		out.append(p)
	for id in tray:
		out.append(at[id])
	return out


func present_ids() -> Array[int]:
	var out: = board_ids()
	for id in tray:
		out.append(id)
	return out


func tray_faces() -> Array[int]:
	var out: Array[int] = []
	for id in tray:
		out.append(int(face[id]))
	return out


# каждое лицо на столе и в лотке встречается чётное число раз — стол всегда «собирается» парами
func parity_ok() -> bool:
	var cnt: = {}
	for id in present_ids():
		var f: int = face[id]
		cnt[f] = int(cnt.get(f, 0)) + 1
	for f in cnt:
		if int(cnt[f]) % 2 != 0:
			return false
	return true


# ── ход ─────────────────────────────────────────────────────────────────────

# {ok, id, pair: [a, b] | [], back: [ids, вернувшиеся на стол], overflow, gain, mult, series}
func pick(id: int) -> Dictionary:
	var res: = {"ok": false, "id": id, "pair": [], "back": [], "overflow": false, "gain": 0, "mult": mult(), "series": series}
	if not is_free(id):
		return res
	res.ok = true
	occ.erase(at[id])
	var f: int = face[id]
	var twin: = -1
	for t in tray:
		if int(face[t]) == f:
			twin = t
			break
	if twin >= 0:
		tray.erase(twin)
		_forget(twin)
		_forget(id)
		pairs += 1
		series += 1
		best_series = maxi(best_series, series)
		var m: = mult_for(series)
		score += m
		res.pair = [twin, id]
		res.gain = m
		res.mult = m
		res.series = series
		return res
	tray.append(id)
	if tray.size() >= SLOTS:
		# «чашка переливается»: три последние фишки — домой, серия — с нуля
		var back: Array[int] = []
		for k in BACK:
			var b: int = tray.pop_back()
			occ[at[b]] = b
			back.append(b)
		back.reverse()
		series = 0
		overflows += 1
		res.back = back
		res.overflow = true
		res.series = 0
		res.mult = 1
	return res


func _forget(id: int) -> void:
	face.erase(id)
	at.erase(id)
	wave_tiles.erase(id)


# долить волну: позиции и лица от генератора; возвращает id новых фишек
func pour(pos: Array, faces: Array) -> Array[int]:
	var ids: Array[int] = []
	wave += 1
	for k in pos.size():
		var p: Vector3i = pos[k]
		var id: = next_id
		next_id += 1
		face[id] = int(faces[k])
		at[id] = p
		occ[p] = id
		wave_tiles[id] = wave
		ids.append(id)
	return ids


# сколько фишек текущей (последней) волны ещё на столе или в лотке
func left_of_wave(w: = -1) -> int:
	var ww: = wave if w < 0 else w
	var n: = 0
	for id in present_ids():
		if int(wave_tiles.get(id, 0)) == ww:
			n += 1
	return n


# подсказка: свободная фишка, чья пара уже в лотке; иначе две одинаковые свободные; иначе пусто
func hint() -> Array[int]:
	var fr: = frees()
	var tf: = tray_faces()
	for id in fr:
		if tf.has(int(face[id])):
			return [id] as Array[int]
	var by: = {}
	for id in fr:
		var f: int = face[id]
		if by.has(f):
			return [int(by[f]), id] as Array[int]
		by[f] = id
	return [] as Array[int]


# ── сохранение (JSON-безопасно: только целые и массивы) ─────────────────────

func to_dict() -> Dictionary:
	var tiles: = []
	for id in at:
		var p: Vector3i = at[id]
		tiles.append([int(id), p.x, p.y, p.z, int(face[id]), 1 if on_board(id) else 0, int(wave_tiles.get(id, wave))])
	tiles.sort_custom(func(a, b): return a[0] < b[0])
	return {
		"v": 1, "tiles": tiles, "tray": tray.duplicate(), "next_id": next_id, "wave": wave, "series": series,
		"best_series": best_series, "score": score, "pairs": pairs, "overflows": overflows, "seed": run_seed,
	}


static func from_dict(d: Dictionary) -> V10MjGardenRules:
	var r: = V10MjGardenRules.new()
	if not (d.get("tiles") is Array):
		return r
	r.run_seed = int(d.get("seed", 1))
	r.next_id = int(d.get("next_id", 0))
	r.wave = int(d.get("wave", 0))
	r.series = int(d.get("series", 0))
	r.best_series = int(d.get("best_series", 0))
	r.score = int(d.get("score", 0))
	r.pairs = int(d.get("pairs", 0))
	r.overflows = int(d.get("overflows", 0))
	for t in d.tiles:
		if not (t is Array) or (t as Array).size() < 6:
			continue
		var id: = int(t[0])
		var p: = Vector3i(int(t[1]), int(t[2]), int(t[3]))
		r.face[id] = int(t[4])
		r.at[id] = p
		r.wave_tiles[id] = int(t[6]) if (t as Array).size() > 6 else r.wave
		if int(t[5]) == 1:
			r.occ[p] = id
		r.next_id = maxi(r.next_id, id + 1)
	for x in d.get("tray", []):
		var id: = int(x)
		if r.at.has(id) and not r.on_board(id) and not r.tray.has(id):
			r.tray.append(id)
	# фишка, которой нет ни на столе, ни в лотке, — мусор старого сейва
	for id in r.at.keys():
		if not r.on_board(int(id)) and not r.tray.has(int(id)):
			r._forget(int(id))
	# лоток не может быть полным (перелив случается сразу)
	while r.tray.size() >= SLOTS:
		var b: int = r.tray.pop_back()
		r.occ[r.at[b]] = b
	return r


func clone() -> V10MjGardenRules:
	return from_dict(to_dict())


# одинаковы ли два состояния (самотест сохранения)
func same_as(o: V10MjGardenRules) -> bool:
	return JSON.stringify(to_dict()) == JSON.stringify(o.to_dict())
