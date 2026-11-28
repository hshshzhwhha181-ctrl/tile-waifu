class_name V10MjCubeRules
extends RefCounted

# Правила Куба без сцены (docs/MODES.md §4.4). Фишки-кубики лежат в клетках сетки, у каждого куба на всех шести
# гранях один и тот же символ.
#
# ПРАВИЛО СВОБОДЫ (наше точное, сверено с Mahjongg Dimensions — см. README «Правило свободы»):
#   грань куба ОТКРЫТА, если соседняя клетка за ней пуста (фишки там нет: снята, сердцевина или край фигуры);
#   куб СВОБОДЕН, если открыты две его СОСЕДНИЕ грани (у них общее ребро), то есть открытые грани есть хотя бы на
#   двух разных осях (x, y, z). Глазами игрока: «грань, которую ты видишь, открыта, и открыта хотя бы одна боковая
#   рядом с ней — слева, справа, сверху или снизу». Это не зависит от поворота камеры: поворот только показывает
#   грани. Две открытые грани на одной оси (сквозной «туннель») куб не освобождают.
# ВИДНА (exposed): по одной из шести осей от куба до края фигуры нет ни одной фишки — к его грани можно дотянуться
#   взглядом прямо, значит и пальцем (подсказка и Приёмы выбирают только видимые; генератор кладёт только видимые).
# Пара: две разные свободные фишки с одним символом; снимаются вместе. Ход = снятая пара; Отмена, Подсказка и
# Перемешать тоже стоят ходов (звёзды считаются по ходам). «Мотив»: пара того же символа, что и предыдущая.
#
#   var r: = V10MjCubeRules.make(cells, faces)
#   r.is_free(i) · r.is_exposed(i) · r.tappable(i) · r.can_pair(a, b) · r.take(a, b) -> {ok, motif, series}
#   r.undo() -> [a, b] · r.free_pairs() · r.hint_pair() · r.shuffle(rng) -> bool · r.left() · r.won
#   r.clone() · r.deepest_pair(center)

const DIRS: = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1),
	Vector3i(0, 0, -1)]
const COST_UNDO: = 1
const COST_HINT: = 1
const COST_SHUFFLE: = 2

var cells: Array[Vector3i] = []
var face: PackedInt32Array = PackedInt32Array()
var present: PackedByteArray = PackedByteArray()
var dims: = Vector3i.ONE
var grid: PackedInt32Array = PackedInt32Array()     # cell → tile index (−1 = empty forever)
var n_left: = 0
var moves: = 0
var pairs_taken: = 0
var series: = 0
var last_face: = -1
var motif_armed: = false       # the next pair scores ×2 (MODES §5.4)
var motifs: = 0
var history: Array = []        # [[a, b, face, series_before, last_face_before, motif_before]]
var won: = false
# cached per tile: free (rule), exposed (line of sight); refreshed along the axis lines of a changed cell
var _free: PackedByteArray = PackedByteArray()
var _exp: PackedByteArray = PackedByteArray()


static func make(cell_list: Array, faces: Array) -> V10MjCubeRules:
	var r: = V10MjCubeRules.new()
	var hi: = Vector3i.ZERO
	for c in cell_list:
		r.cells.append(c)
		hi = Vector3i(maxi(hi.x, c.x), maxi(hi.y, c.y), maxi(hi.z, c.z))
	r.dims = hi + Vector3i.ONE
	r.grid.resize(r.dims.x * r.dims.y * r.dims.z)
	r.grid.fill(-1)
	for i in r.cells.size():
		r.grid[r._gi(r.cells[i])] = i
	r.face.resize(r.cells.size())
	for i in r.cells.size():
		r.face[i] = int(faces[i]) if i < faces.size() else 0
	r.present.resize(r.cells.size())
	r.present.fill(1)
	r.n_left = r.cells.size()
	r._free.resize(r.cells.size())
	r._exp.resize(r.cells.size())
	r.refresh_all()
	return r


func clone() -> V10MjCubeRules:
	var r: = V10MjCubeRules.new()
	r.cells = cells
	r.face = face.duplicate()
	r.present = present.duplicate()
	r.dims = dims
	r.grid = grid
	r.n_left = n_left
	r.moves = moves
	r.pairs_taken = pairs_taken
	r.series = series
	r.last_face = last_face
	r.motif_armed = motif_armed
	r.motifs = motifs
	r.history = history.duplicate(true)
	r.won = won
	r._free = _free.duplicate()
	r._exp = _exp.duplicate()
	return r


func _gi(c: Vector3i) -> int:
	return c.x + dims.x * (c.y + dims.y * c.z)


func inside(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < dims.x and c.y < dims.y and c.z < dims.z


# tile at a cell that is still on the figure, or −1
func at(c: Vector3i) -> int:
	if not inside(c):
		return -1
	var i: = grid[_gi(c)]
	if i >= 0 and present[i] == 1:
		return i
	return -1


func open_face(i: int, d: Vector3i) -> bool:
	return at(cells[i] + d) < 0


# axes (0 x, 1 y, 2 z) that have at least one open face
func open_axes(i: int) -> int:
	var n: = 0
	for a in 3:
		if open_face(i, DIRS[a * 2]) or open_face(i, DIRS[a * 2 + 1]):
			n += 1
	return n


func _calc_free(i: int) -> bool:
	return present[i] == 1 and open_axes(i) >= 2


# player's wording: the face towards the camera (view_dir = direction from the tile to the camera, an axis) is
# open and at least one of its four neighbouring faces is open. free ⇔ this holds for some open face (selftest).
func free_from(i: int, view_dir: Vector3i) -> bool:
	if present[i] != 1 or not open_face(i, view_dir):
		return false
	for d in DIRS:
		if d == view_dir or d == -view_dir:
			continue
		if open_face(i, d):
			return true
	return false


func _calc_exposed(i: int) -> bool:
	if present[i] != 1:
		return false
	for d in DIRS:
		var c: Vector3i = cells[i] + d
		var clear: = true
		while inside(c):
			if at(c) >= 0:
				clear = false
				break
			c += d
		if clear:
			return true
	return false


# axis directions with a straight line of sight to the outside (for the camera aim of the hint)
func exposed_dirs(i: int) -> Array:
	var out: = []
	for d in DIRS:
		var c: Vector3i = cells[i] + d
		var clear: = true
		while inside(c):
			if at(c) >= 0:
				clear = false
				break
			c += d
		if clear:
			out.append(d)
	return out


func refresh_all() -> void:
	for i in cells.size():
		_free[i] = 1 if _calc_free(i) else 0
		_exp[i] = 1 if _calc_exposed(i) else 0


# a cell changed (tile removed or restored): only the tiles on its three axis lines can change state
func _refresh_lines(c: Vector3i) -> void:
	for a in 3:
		var p: = c
		for k in dims[a]:
			p[a] = k
			var i: = grid[_gi(p)]
			if i >= 0:
				_free[i] = 1 if _calc_free(i) else 0
				_exp[i] = 1 if _calc_exposed(i) else 0


func is_free(i: int) -> bool:
	return i >= 0 and i < cells.size() and _free[i] == 1


func is_exposed(i: int) -> bool:
	return i >= 0 and i < cells.size() and _exp[i] == 1


func tappable(i: int) -> bool:
	return is_free(i) and is_exposed(i)


func left() -> int:
	return n_left


func frees() -> Array:
	var out: = []
	for i in cells.size():
		if _free[i] == 1:
			out.append(i)
	return out


func can_pair(a: int, b: int) -> bool:
	return a != b and a >= 0 and b >= 0 and present[a] == 1 and present[b] == 1 and face[a] == face[b] \
		and is_free(a) and is_free(b)


# remove a pair; {ok, motif (this pair repeats the previous symbol), bonus (×2 from an armed motif), series}
func take(a: int, b: int, count_move: = true) -> Dictionary:
	if not can_pair(a, b):
		return {"ok": false}
	var f: = face[a]
	history.append([a, b, f, series, last_face, motif_armed])
	var bonus: = motif_armed
	var motif: = last_face == f
	motif_armed = motif
	if motif:
		motifs += 1
	last_face = f
	series += 1
	present[a] = 0
	present[b] = 0
	n_left -= 2
	pairs_taken += 1
	if count_move:
		moves += 1
	_refresh_lines(cells[a])
	_refresh_lines(cells[b])
	won = n_left == 0
	return {"ok": true, "motif": motif, "bonus": bonus, "series": series, "face": f}


func undo() -> Array:
	if history.is_empty():
		return []
	var h: Array = history.pop_back()
	var a: int = h[0]
	var b: int = h[1]
	present[a] = 1
	present[b] = 1
	face[a] = h[2]
	face[b] = h[2]
	n_left += 2
	pairs_taken -= 1
	series = 0
	last_face = int(h[4])
	motif_armed = false
	moves += COST_UNDO
	won = false
	_refresh_lines(cells[a])
	_refresh_lines(cells[b])
	return [a, b]


func miss() -> void:
	series = 0


# every free pair that can be tapped (both tiles visible), as [a, b]
func free_pairs(need_exposed: = true) -> Array:
	var by: = {}
	for i in cells.size():
		if _free[i] == 1 and (not need_exposed or _exp[i] == 1):
			var f: = face[i]
			if not by.has(f):
				by[f] = []
			(by[f] as Array).append(i)
	var out: = []
	for f in by:
		var l: Array = by[f]
		for x in l.size():
			for y in range(x + 1, l.size()):
				out.append([l[x], l[y]])
	return out


# the pair a hint shows: a tappable pair after which the rest still has a certificate (quick greedy check);
# ties → the pair whose tiles sit closest together (easier to see in one view)
func hint_pair() -> Array:
	var ps: = free_pairs(true)
	if ps.is_empty():
		return []
	var best: Array = []
	var bs: = INF
	for p in ps:
		var d: = Vector3(cells[p[0]] - cells[p[1]]).length()
		var sim: = clone()
		sim.take(p[0], p[1], false)
		var ok: = sim.n_left == 0 or sim.greedy_solvable(4)
		var s: = d + (0.0 if ok else 1000.0)
		if s < bs:
			bs = s
			best = p
	return best


# randomised greedy play-out (tries times): true if some play-out clears the figure. A positive answer is a proof;
# a negative one is only «probably stuck» (used for hints, never for the generator's certificate).
func greedy_solvable(tries: = 3, seed_v: = 7) -> bool:
	var rng: = RandomNumberGenerator.new()
	rng.seed = seed_v
	for t in tries:
		var sim: = clone()
		var guard: = 0
		while sim.n_left > 0 and guard < 400:
			guard += 1
			var ps: = sim.free_pairs(true)
			if ps.is_empty():
				break
			var p: Array = ps[rng.randi() % ps.size()]
			sim.take(p[0], p[1], false)
		if sim.n_left == 0:
			return true
	return false


# a removal order of the present tiles by the rule (each pair free and visible when taken) — random, with retries.
# Returns [[a, b], …] or [] (no order found). Faces are not looked at: any face assignment to these pairs is a
# certificate.
func random_order(rng: RandomNumberGenerator, attempts: = 60, pick: Callable = Callable()) -> Array:
	for at_n in attempts:
		var sim: = clone()
		var order: = []
		var ok: = true
		while sim.n_left > 0:
			var cand: = []
			for i in sim.cells.size():
				if sim._free[i] == 1 and sim._exp[i] == 1:
					cand.append(i)
			if cand.size() < 2:
				ok = false
				break
			var ab: Array
			if pick.is_valid():
				ab = pick.call(sim, cand, rng)
			else:
				var a: int = cand[rng.randi() % cand.size()]
				var b: int = a
				while b == a:
					b = cand[rng.randi() % cand.size()]
				ab = [a, b]
			sim.face[ab[0]] = 0
			sim.face[ab[1]] = 0
			sim.take(ab[0], ab[1], false)
			order.append(ab)
		if ok:
			return order
	return []


# «Перемешать»: new faces for the tiles that are left, same multiset of symbols, solvable by construction
# (a fresh removal order of the remaining cells, face pairs dealt onto it). Clears the undo history.
func shuffle(rng: RandomNumberGenerator) -> Array:
	var order: = random_order(rng)
	if order.is_empty():
		return []
	var cnt: = {}
	for i in cells.size():
		if present[i] == 1:
			cnt[face[i]] = int(cnt.get(face[i], 0)) + 1
	var fpairs: = []
	for f in cnt:
		for k in int(cnt[f]) / 2:
			fpairs.append(int(f))
	if fpairs.size() != order.size():
		return []
	for k in range(fpairs.size() - 1, 0, -1):
		var j: = rng.randi() % (k + 1)
		var t = fpairs[k]
		fpairs[k] = fpairs[j]
		fpairs[j] = t
	for k in order.size():
		face[order[k][0]] = fpairs[k]
		face[order[k][1]] = fpairs[k]
	history.clear()
	series = 0
	motif_armed = false
	last_face = -1
	return order


# nova «Взлом»: the tappable pair nearest the core (deepest)
func deepest_pair(center: Vector3) -> Array:
	var best: Array = []
	var bs: = INF
	for p in free_pairs(true):
		var d: = Vector3(cells[p[0]]).distance_to(center) + Vector3(cells[p[1]]).distance_to(center)
		if d < bs:
			bs = d
			best = p
	return best


# replay a certificate: every pair same face, both free and visible at their turn, clears the figure
func replay(order: Array) -> bool:
	var sim: = clone()
	for p in order:
		if not (sim.tappable(p[0]) and sim.tappable(p[1])):
			return false
		if not sim.take(p[0], p[1], false).ok:
			return false
	return sim.n_left == 0


func faces_even() -> bool:
	var cnt: = {}
	for i in cells.size():
		if present[i] == 1:
			cnt[face[i]] = int(cnt.get(face[i], 0)) + 1
	for f in cnt:
		if int(cnt[f]) % 2 != 0:
			return false
	return true
