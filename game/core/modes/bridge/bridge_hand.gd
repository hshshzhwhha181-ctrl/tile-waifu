class_name V10MjBridgeHand
extends RefCounted

# «Собери руку» — безголовые правила (docs/MODES.md §4.5). Поле — пирамида фишек риичи (виды 0…33), внизу рука
# на 14 мест. Тап по свободной фишке кладёт её в руку. Три одинаковые или ряд одной масти складываются в набор
# («тройка» / «ряд») и уходят влево. Цель — 4 набора и пара (только регулярная форма, без семи пар).
# «Сброс» — 3 раза за партию: любую фишку руки вернуть на край стола (край — свободные фишки, их можно взять снова).
# Рука полна (14) и готовой формы нет (или комбинация дешевле цели уровня) — проигрыш (его снимает «Сброс»).
#
# Автосборка не жадная: набор складывается, только если с ним рука остаётся собираемой (completable) так же, как
# без него — с учётом фишек, которые ещё можно взять со стола и с края. Победа считается по всей руке как по
# набору фишек (multiset), а не по сложенным наборам: сложение — подача, оно не может отнять решение. Если
# сложенные наборы перестали подходить к живой руке (стол изменился), они раскладываются и складываются заново.
#
# Комбинации (множитель очков; имена — простые, оригинал V8Mj.yaku_name мелко):
#   Все простые ×2 (таняо) · Три тройки ×2 (сананко) · Чистый ряд 1–9 ×3 (иццу) · Одна масть ×4 (чинъицу);
#   множители перемножаются. С 20-го уровня цель — рука с комбинацией не дешевле ×2 (дальше ×3, ×4).

const CAP: = 14
const RESETS: = 3
const EDGE_MAX: = 6
const COMBOS: = {
	"tanyao": {"name": "Все простые", "mult": 2},
	"sanankou": {"name": "Три тройки", "mult": 2},
	"ittsu": {"name": "Чистый ряд 1–9", "mult": 3},
	"chinitsu": {"name": "Одна масть", "mult": 4},
}
const COMBO_ORDER: = ["chinitsu", "ittsu", "sanankou", "tanyao"]
const SET_NAME: = {"triple": "тройка", "run": "ряд"}
const NODE_CAP: = 60000

# стол
var pos: Array = []        # Vector3 (x, y, z) в клетках; слой z сдвинут на z/2 клетки
var kind: Array = []       # вид фишки на месте i
var present: Array = []    # 1 — на столе
var above: Array = []      # above[i] — кто лежит на i
var below: Array = []      # below[i] — на ком лежит i
# рука
var loose: Array = []      # свободные фишки руки (виды, по порядку)
var sets: Array = []       # [{"t": "triple"|"run", "k": [a, b, c]}] — сложенные наборы, слева направо
var pair: = []             # пара победной руки (заполняется на победе)
var edge: Array = []       # край стола: виды возвращённых фишек
var resets_left: = RESETS
var req: = 1
var won: = false
var lost: = false
var lost_why: = ""         # "shape" — нет формы, "combo" — форма есть, комбинация дешевле цели
var takes: = 0
var resets_used: = 0
var reforms: = 0
var max_hand: = 0
var log: Array = []        # ходы [что, вид, место]
var last_formed: Array = []


static func make(lv: Dictionary) -> V10MjBridgeHand:
	var r: = V10MjBridgeHand.new()
	r.pos = (lv.pos as Array).duplicate()
	r.kind = []
	for k in lv.kinds:
		r.kind.append(int(k))
	r.present = []
	r.present.resize(r.pos.size())
	r.present.fill(1)
	r.req = int(lv.get("req", 1))
	r._links()
	return r


func _links() -> void:
	above = []
	below = []
	for i in pos.size():
		above.append([])
		below.append([])
	for i in pos.size():
		var a: Vector3 = pos[i]
		for j in pos.size():
			if i == j:
				continue
			var b: Vector3 = pos[j]
			if b.z > a.z and absf(b.x - a.x) < 0.99 and absf(b.y - a.y) < 0.99:
				(above[i] as Array).append(j)
				(below[j] as Array).append(i)


func clone() -> V10MjBridgeHand:
	var r: = V10MjBridgeHand.new()
	r.pos = pos
	r.kind = kind.duplicate()
	r.present = present.duplicate()
	r.above = above
	r.below = below
	r.loose = loose.duplicate()
	r.sets = sets.duplicate(true)
	r.pair = pair.duplicate()
	r.edge = edge.duplicate()
	r.resets_left = resets_left
	r.req = req
	r.won = won
	r.lost = lost
	r.lost_why = lost_why
	r.takes = takes
	r.resets_used = resets_used
	r.reforms = reforms
	r.max_hand = max_hand
	return r


# ── стол ─────────────────────────────────────────────────────────────────────

func is_free(i: int) -> bool:
	if present[i] != 1:
		return false
	for j in above[i]:
		if present[j] == 1:
			return false
	return true


func frees() -> Array:
	var out: = []
	for i in pos.size():
		if is_free(i):
			out.append(i)
	return out


func table_count() -> int:
	var n: = 0
	for v in present:
		n += int(v)
	return n


# сколько фишек вида ещё можно взять: на столе + на краю
func avail() -> Array:
	var a: = V10MjBridgeTiles.zero()
	for i in pos.size():
		if present[i] == 1:
			a[kind[i]] += 1
	for k in edge:
		a[int(k)] += 1
	return a


func mask() -> int:
	var m: = 0
	for i in pos.size():
		if present[i] == 1:
			m |= 1 << i
	return m


# ── рука ─────────────────────────────────────────────────────────────────────

func hand_kinds() -> Array:
	var out: = []
	for s in sets:
		out.append_array(s.k)
	out.append_array(loose)
	return out


func hand_count() -> int:
	return loose.size() + 3 * sets.size()


func free_places() -> int:
	return CAP - hand_count()


func is_over() -> bool:
	return won or lost


func take(i: int) -> Dictionary:
	if won or lost or i < 0 or i >= pos.size() or not is_free(i) or hand_count() >= CAP:
		return {"ok": false}
	present[i] = 0
	log.append(["take", kind[i], i])
	return _add(kind[i])


func take_edge(j: int) -> Dictionary:
	if won or lost or j < 0 or j >= edge.size() or hand_count() >= CAP:
		return {"ok": false}
	var k: int = edge[j]
	edge.remove_at(j)
	log.append(["edge", k, j])
	return _add(k)


func _add(k: int) -> Dictionary:
	takes += 1
	loose.append(k)
	loose.sort()
	var formed: = form()
	max_hand = maxi(max_hand, hand_count())
	_check_end()
	return {"ok": true, "kind": k, "formed": formed, "won": won, "lost": lost}


# вернуть фишку вида k на край («Сброс»). src: "loose" или индекс набора (набор раскладывается)
func reset_kind(k: int, set_idx: = -1, free_reset: = false) -> bool:
	if won or (resets_left <= 0 and not free_reset) or edge.size() >= EDGE_MAX:
		return false
	if set_idx >= 0 and set_idx < sets.size():
		var s: Array = (sets[set_idx].k as Array).duplicate()
		if not s.has(k):
			return false
		sets.remove_at(set_idx)
		s.erase(k)
		loose.append_array(s)
	else:
		var at: = loose.find(k)
		if at < 0:
			return false
		loose.remove_at(at)
	loose.sort()
	edge.append(k)
	if not free_reset:
		resets_left -= 1
		resets_used += 1
	log.append(["reset", k, set_idx])
	lost = false
	lost_why = ""
	form()
	return true


func _check_end() -> void:
	if hand_count() < CAP:
		return
	var all: = hand_kinds()
	if V10MjBridgeTiles.is_complete(all):
		var cb: = combos(all)
		if int(cb.mult) >= req:
			won = true
			_final_form(cb)
			return
		lost = true
		lost_why = "combo"
		return
	lost = true
	lost_why = "shape"


# на победе наборы складываются по лучшему разбору (с комбинацией), пара — отдельно
func _final_form(cb: Dictionary) -> void:
	var d: Dictionary = cb.get("dec", {})
	if d.is_empty():
		return
	sets = []
	for s in d.sets:
		if int(s[0]) == 0:
			sets.append({"t": "triple", "k": [int(s[1]), int(s[1]), int(s[1])]})
		else:
			sets.append({"t": "run", "k": [int(s[1]), int(s[1]) + 1, int(s[1]) + 2]})
	pair = [int(d.pair), int(d.pair)]
	loose = pair.duplicate()


# ── автосборка ───────────────────────────────────────────────────────────────

func form() -> Array:
	var formed: = []
	last_formed = []
	var A: = avail()
	if not sets.is_empty():
		var all_c: = V10MjBridgeTiles.counts(hand_kinds())
		if completable(all_c, 0, A) and not completable(V10MjBridgeTiles.counts(loose), sets.size(), A):
			# наборы перестали подходить к живой руке — разложить и сложить заново
			for s in sets:
				loose.append_array(s.k)
			sets = []
			loose.sort()
			reforms += 1
	while sets.size() < 4:
		var L: = V10MjBridgeTiles.counts(loose)
		var before: = completable(L, sets.size(), A)
		var best: = {}
		var best_score: = 99999
		for c in candidates(L):
			for k in c.k:
				L[k] -= 1
			var ok: = not before or completable(L, sets.size() + 1, A)
			var sc: = V8Mj.shanten_regular(L, sets.size() + 1) * 100 + (0 if c.t == "triple" else 1) * 50 + int(c.k[0])
			for k in c.k:
				L[k] += 1
			if ok and sc < best_score:
				best_score = sc
				best = c
		if best.is_empty():
			break
		for k in best.k:
			loose.erase(k)
		sets.append(best)
		formed.append(best)
	last_formed = formed
	return formed


static func candidates(L: Array) -> Array:
	var out: = []
	for k in 34:
		if int(L[k]) >= 3:
			out.append({"t": "triple", "k": [k, k, k]})
	for k in 27:
		if k % 9 <= 6 and int(L[k]) > 0 and int(L[k + 1]) > 0 and int(L[k + 2]) > 0:
			out.append({"t": "run", "k": [k, k + 1, k + 2]})
	return out


# жадная автосборка (для сравнения в самотесте): первый найденный набор
static func greedy_pick(L: Array) -> Dictionary:
	var c: = candidates(L)
	return c[0] if not c.is_empty() else {}


# ── собираемость ─────────────────────────────────────────────────────────────
# completable(L, s, A): можно ли добрать к фишкам L (свободные фишки руки) фишки из A так, чтобы вместе с s
# сложенными наборами вышли 4 набора и пара (всего 14). opt: allow (маска видов), min_trip (тройки), runs (обязательные
# ряды для «чистого ряда»).

static var _nodes: = 0


static func completable(L: Array, s: int, A: Array, opt: = {}) -> bool:
	var sn: = 4 - s
	if sn < 0:
		return false
	var n: = V10MjBridgeTiles.total(L)
	if n > 3 * sn + 2:
		return false
	var allow = opt.get("allow", null)
	if allow != null:
		for k in 34:
			if int(L[k]) > 0 and not allow[k]:
				return false
	var LL: = L.duplicate()
	var AA: = A.duplicate()
	var trips: = 0
	var runs: Array = opt.get("runs", [])
	for st in runs:
		if sn <= 0:
			return false
		for j in [int(st), int(st) + 1, int(st) + 2]:
			if int(LL[j]) > 0:
				LL[j] -= 1
			elif int(AA[j]) > 0:
				AA[j] -= 1
			else:
				return false
		sn -= 1
	_nodes = 0
	return _cdfs(LL, AA, sn, 1, trips, int(opt.get("min_trip", 0)), allow)


static func _cdfs(L: Array, A: Array, sn: int, pn: int, trips: int, min_trip: int, allow) -> bool:
	_nodes += 1
	if _nodes > NODE_CAP:
		return false
	var i: = 0
	while i < 34 and int(L[i]) == 0:
		i += 1
	if i >= 34:
		return _fill(A, sn, pn, maxi(0, min_trip - trips), allow, 0)
	if sn <= 0 and pn <= 0:
		return false
	if min_trip - trips > sn:
		return false
	var li: = int(L[i])
	# пара
	if pn > 0:
		var u2: = mini(li, 2)
		var need: = 2 - u2
		if int(A[i]) >= need:
			L[i] -= u2
			A[i] -= need
			var ok: = _cdfs(L, A, sn, pn - 1, trips, min_trip, allow)
			L[i] += u2
			A[i] += need
			if ok:
				return true
	if sn <= 0:
		return false
	# тройка
	var u: = mini(li, 3)
	var need3: = 3 - u
	if int(A[i]) >= need3:
		L[i] -= u
		A[i] -= need3
		var ok3: = _cdfs(L, A, sn - 1, pn, trips + 1, min_trip, allow)
		L[i] += u
		A[i] += need3
		if ok3:
			return true
	# ряды через i (если нужны тройки — только когда наборов хватает)
	if i < 27 and min_trip - trips < sn:
		var base: = i - i % 9
		for st in [i - 2, i - 1, i]:
			if st < base or st + 2 > base + 8:
				continue
			if allow != null and (not allow[st] or not allow[st + 1] or not allow[st + 2]):
				continue
			var from_l: = []
			var from_a: = []
			var feasible: = true
			for j in [st, st + 1, st + 2]:
				if j >= i and int(L[j]) > 0:
					from_l.append(j)
				elif int(A[j]) > 0:
					from_a.append(j)
				else:
					feasible = false
					break
			if not feasible or not from_l.has(i):
				continue
			for j in from_l:
				L[j] -= 1
			for j in from_a:
				A[j] -= 1
			var okr: = _cdfs(L, A, sn - 1, pn, trips, min_trip, allow)
			for j in from_l:
				L[j] += 1
			for j in from_a:
				A[j] += 1
			if okr:
				return true
	return false


# добрать sn наборов и pn пар только из A (≥ need_trip троек), виды по возрастанию
static func _fill(A: Array, sn: int, pn: int, need_trip: int, allow, k0: int) -> bool:
	if sn == 0 and pn == 0:
		return need_trip <= 0
	_nodes += 1
	if _nodes > NODE_CAP:
		return false
	if need_trip > sn:
		return false
	# грубые границы: фишек хватает, троек хватает
	var tot: = 0
	var trip_kinds: = 0
	var pair_kinds: = 0
	for k in range(k0, 34):
		if allow != null and not allow[k]:
			continue
		tot += int(A[k])
		if int(A[k]) >= 3:
			trip_kinds += 1
		if int(A[k]) >= 2:
			pair_kinds += 1
	if tot < 3 * sn + 2 * pn or trip_kinds < need_trip or (pn > 0 and pair_kinds == 0):
		return false
	for k in range(k0, 34):
		if allow != null and not allow[k]:
			continue
		var a: = int(A[k])
		if a == 0:
			continue
		if pn > 0 and a >= 2:
			A[k] -= 2
			var ok: = _fill(A, sn, pn - 1, need_trip, allow, k)
			A[k] += 2
			if ok:
				return true
		if sn > 0 and a >= 3:
			A[k] -= 3
			var ok3: = _fill(A, sn - 1, pn, need_trip - 1, allow, k)
			A[k] += 3
			if ok3:
				return true
		if sn > need_trip and k < 27 and k % 9 <= 6 and int(A[k + 1]) > 0 and int(A[k + 2]) > 0:
			if allow == null or (allow[k + 1] and allow[k + 2]):
				A[k] -= 1; A[k + 1] -= 1; A[k + 2] -= 1
				var okr: = _fill(A, sn - 1, pn, need_trip, allow, k)
				A[k] += 1; A[k + 1] += 1; A[k + 2] += 1
				if okr:
					return true
	return false


# планы комбинаций для цели req: [{mult, opt}], от дешёвых к дорогим
static var _plans: = {}


static func plans(req: int) -> Array:
	if _plans.has(req):
		return _plans[req]
	var simple: = []
	var suit_masks: = []
	for k in 34:
		simple.append(V10MjBridgeTiles.is_simple(k))
	for s in 3:
		var m: = []
		for k in 34:
			m.append(k >= s * 9 and k < s * 9 + 9)
		suit_masks.append(m)
	var out: = []
	for tan in [false, true]:
		for chin in [-1, 0, 1, 2]:
			for san in [false, true]:
				for itt in [-1, 0, 1, 2]:
					if itt >= 0 and (tan or san):
						continue
					if itt >= 0 and chin >= 0 and itt != chin:
						continue
					var mult: = 1
					if tan:
						mult *= int(COMBOS.tanyao.mult)
					if chin >= 0:
						mult *= int(COMBOS.chinitsu.mult)
					if san:
						mult *= int(COMBOS.sanankou.mult)
					if itt >= 0:
						mult *= int(COMBOS.ittsu.mult)
					if mult < req:
						continue
					var allow = null
					if tan or chin >= 0:
						allow = []
						for k in 34:
							var ok: bool = (not tan or simple[k]) and (chin < 0 or suit_masks[chin][k])
							allow.append(ok)
					var opt: = {}
					if allow != null:
						opt["allow"] = allow
					if san:
						opt["min_trip"] = 3
					if itt >= 0:
						opt["runs"] = [itt * 9, itt * 9 + 3, itt * 9 + 6]
					out.append({"mult": mult, "opt": opt, "tan": tan, "chin": chin, "san": san, "itt": itt})
	out.sort_custom(func(a, b): return int(a.mult) < int(b.mult))
	_plans[req] = out
	return out


# можно ли из руки H (вся рука, multiset) и доступных A собрать руку с комбинацией не дешевле req
static func completable_req(H: Array, A: Array, req: int) -> bool:
	if req <= 1:
		return completable(H, 0, A)
	var suits: = {}
	var has_out: = false
	for k in 34:
		if int(H[k]) > 0:
			suits[V10MjBridgeTiles.suit(k)] = true
			if not V10MjBridgeTiles.is_simple(k):
				has_out = true
	for p in plans(req):
		if p.tan and has_out:
			continue
		if int(p.chin) >= 0 and (suits.size() > 1 or not suits.is_empty() and not suits.has(int(p.chin))):
			continue
		if completable(H, 0, A, p.opt):
			return true
	return false


# ── форма и комбинации ───────────────────────────────────────────────────────

func complete() -> bool:
	return V10MjBridgeTiles.is_complete(hand_kinds())


# лучшая комбинация готовой руки: {ids, mult, dec}
static func combos(kinds: Array) -> Dictionary:
	var c: = V10MjBridgeTiles.counts(kinds)
	if kinds.size() != 14 or V8Mj.shanten_regular(c, 0) != -1:
		return {"ids": [], "mult": 0, "dec": {}}
	var tan: = true
	var suits: = {}
	for k in kinds:
		if not V10MjBridgeTiles.is_simple(int(k)):
			tan = false
		suits[V10MjBridgeTiles.suit(int(k))] = true
	var chin: = suits.size() == 1 and not suits.has(3)
	var best: = {"ids": [], "mult": 0, "dec": {}}
	for d in V8Mj.decompose(c):
		var ids: = []
		if chin:
			ids.append("chinitsu")
		var trips: = 0
		var run_at: = {}
		for s in d.sets:
			if int(s[0]) == 0:
				trips += 1
			else:
				run_at[int(s[1])] = true
		for st in [0, 9, 18]:
			if run_at.has(st) and run_at.has(st + 3) and run_at.has(st + 6):
				ids.append("ittsu")
				break
		if trips >= 3:
			ids.append("sanankou")
		if tan:
			ids.append("tanyao")
		var m: = 1
		for id in ids:
			m *= int(COMBOS[id].mult)
		if m > int(best.mult) or (m == int(best.mult) and ids.size() > (best.ids as Array).size()):
			best = {"ids": ids, "mult": m, "dec": d}
	return best


static func combo_line(ids: Array, mult: int) -> String:
	if ids.is_empty():
		return ""
	var names: = []
	for id in COMBO_ORDER:
		if ids.has(id):
			names.append(String(COMBOS[id].name))
	return "Комбинация: %s ×%d" % [", ".join(names), mult]


static func combo_orig(ids: Array) -> String:
	var o: = []
	for id in COMBO_ORDER:
		if ids.has(id):
			o.append(V8Mj.yaku_name(id).to_lower())
	return " · ".join(o)


func tenpai() -> bool:
	return hand_count() == CAP - 1 and not waits().is_empty()


# виды, которые сейчас доводят руку до победы (с целью req; только те, что ещё можно взять)
func waits(live_only: = true) -> Array:
	var out: = []
	if hand_count() != CAP - 1:
		return out
	var all: = hand_kinds()
	var A: = avail()
	for k in 34:
		if live_only and int(A[k]) <= 0:
			continue
		all.append(k)
		if V10MjBridgeTiles.is_complete(all) and int(combos(all).mult) >= req:
			out.append(k)
		all.pop_back()
	return out


# жива ли рука: можно ли ещё собрать цель из того, что есть на столе и на краю
func alive() -> bool:
	if won:
		return true
	return completable_req(V10MjBridgeTiles.counts(hand_kinds()), avail(), req)


# полезность взять вид k: 0 — победа, 1 — рука жива, 2 — рука умирает. Меньше — лучше; дальше — шантен.
func rate(k: int) -> int:
	var H: = V10MjBridgeTiles.counts(hand_kinds())
	var A: = avail()
	H[k] += 1
	A[k] -= 1
	if hand_count() + 1 == CAP:
		var all: = hand_kinds()
		all.append(k)
		if V10MjBridgeTiles.is_complete(all) and int(combos(all).mult) >= req:
			return 0
		return 2000
	if not completable_req(H, A, req):
		return 1000
	return 100 + V8Mj.shanten_regular(H, 0) * 10


# лучшая свободная фишка: {"src": "table"|"edge", "i": индекс, "kind": k, "rate": r}
func best_take(skip: = []) -> Dictionary:
	var best: = {}
	var memo: = {}
	for i in frees():
		if skip.has(i):
			continue
		var k: int = kind[i]
		if not memo.has(k):
			memo[k] = rate(k)
		var r: int = memo[k]
		# при равенстве — фишка, которая открывает больше
		var opens: = 0
		for j in below[i]:
			opens += 1
		var sc: = r * 10 - mini(opens, 9)
		if best.is_empty() or sc < int(best.sc):
			best = {"src": "table", "i": i, "kind": k, "rate": r, "sc": sc}
	for j in edge.size():
		var k: int = edge[j]
		if not memo.has(k):
			memo[k] = rate(k)
		var sc2: = int(memo[k]) * 10
		if best.is_empty() or sc2 < int(best.sc):
			best = {"src": "edge", "i": j, "kind": k, "rate": memo[k], "sc": sc2}
	return best


# самая бесполезная фишка руки (для «Сброса и играть» и Приёма Рин): та, без которой рука ближе к цели
func worst_in_hand() -> int:
	var all: = hand_kinds()
	if all.is_empty():
		return -1
	var A: = avail()
	var best_k: = -1
	var best_sc: = 99999
	var seen: = {}
	for k in all:
		if seen.has(k):
			continue
		seen[k] = true
		var H: = V10MjBridgeTiles.counts(all)
		H[k] -= 1
		var A2: = A.duplicate()
		A2[k] += 1
		var sc: = (0 if completable_req(H, A2, req) else 1000) + V8Mj.shanten_regular(H, 0) * 10
		if sc < best_sc:
			best_sc = sc
			best_k = int(k)
	return best_k


# где лежит вид k в руке: индекс набора или −1 (свободные)
func where(k: int) -> int:
	if loose.has(k):
		return -1
	for si in sets.size():
		if (sets[si].k as Array).has(k):
			return si
	return -2


func state_key() -> String:
	var e: = edge.duplicate()
	e.sort()
	return "%d|%s|%d" % [mask(), str(e), resets_left]
