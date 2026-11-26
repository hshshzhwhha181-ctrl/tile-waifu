class_name V10MjBridgeDaily
extends RefCounted

# «Задача дня» — «Какую сбросить?» (docs/MODES.md §4.5). Рука риичи из 14 фишек, видимая дора (индикатор) и ветер.
# Лучший сброс — по движку V8Mj (не меняется, только вызывается): меньше шантен, при равенстве — больше фишек ждут
# (V8Mj.ukeire; видимые фишки = 14 фишек руки + индикатор доры). Лучших может быть несколько — тогда все они
# равноценны (одинаковые ожидания), иначе генератор руку не берёт.
#
#   analyze(hand, dora) -> {rows: {kind: {sh, n, waits}}, best: [kind…], sh, n, runner}
#   explain(item, pick, ok) -> String           одна фраза героини после ответа
#   share(item, tries, shown) -> String          шаринг без спойлера и без названий фишек
#   item_for(date) -> Dictionary                 задача на дату (2027 — точно; другие годы — тот же день недели)
#   generate(count) -> Dictionary                офлайн-генератор (флаг --bridge_gen=365 в самотесте)
#
# Сложность по дню недели (пн = 0 … вс = 6): пн — темпай в один шаг; вт — выбор ожидания в темпае; ср — шаг до
# темпая, лишняя фишка видна; чт — шаг до темпая, выбор формы; пт — тонкий выбор формы; сб — два шага, близкие
# варианты; вс — «дорогая или быстрая»: лучший сброс отпускает дору, а рука с дорой ждёт меньше.
# Первые 7 задач года — «Школа стола»: лёгкие, с подсказкой формы (линии под наборами).

const DATA_PATH: = "res://data/mj/bridge/daily_discard_2027.json"
const YEAR: = 2027
const COUNT: = 365
const SCHOOL: = 7
const SEED_BASE: = 2027_0001
const WD_KIND: = ["t1", "t2", "i1", "i2", "i3", "r2", "dv"]
const KIND_NAME: = {"t1": "темпай в один шаг", "t2": "выбор ожидания", "i1": "шаг до темпая", "i2": "выбор формы",
	"i3": "тонкий выбор", "r2": "два шага", "dv": "дорогая или быстрая"}
const NUM_NOM_N: = ["ноль", "одно", "два", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять", "десять",
	"одиннадцать", "двенадцать", "тринадцать"]
const NUM_GEN: = ["нуля", "одного", "двух", "трёх", "четырёх", "пяти", "шести", "семи", "восьми", "девяти", "десяти",
	"одиннадцати", "двенадцати", "тринадцати"]
const TRY_WORD: = ["", "с первой попытки", "со второй попытки", "с третьей попытки"]

static var _data: = {}


# ── анализ ───────────────────────────────────────────────────────────────────

static func seen_of(hand: Array, dora: int) -> Array:
	var seen: = V10MjBridgeTiles.counts(hand)
	if dora >= 0:
		seen[dora] += 1
	return seen


static func analyze(hand: Array, dora: int) -> Dictionary:
	var c: = V10MjBridgeTiles.counts(hand)
	var seen: = seen_of(hand, dora)
	var rows: = {}
	for k in V10MjBridgeTiles.KINDS:
		if c[k] == 0:
			continue
		c[k] -= 1
		var u: = V8Mj.ukeire(c, 0, seen)
		var w: Array = u.kinds
		w.sort()
		rows[k] = {"sh": int(u.shanten), "n": int(u.n), "waits": w}
		c[k] += 1
	return _rank(rows)


# эталон без отсечения: перебор всех 34 видов регулярным шантеном (самотест сверяет с V8Mj.ukeire)
static func analyze_brute(hand: Array, dora: int) -> Dictionary:
	var c: = V10MjBridgeTiles.counts(hand)
	var seen: = seen_of(hand, dora)
	var rows: = {}
	for k in V10MjBridgeTiles.KINDS:
		if c[k] == 0:
			continue
		c[k] -= 1
		var s0: = V8Mj.shanten_regular(c, 0)
		var w: = []
		var n: = 0
		for j in V10MjBridgeTiles.KINDS:
			if c[j] >= 4:
				continue
			c[j] += 1
			if V8Mj.shanten_regular(c, 0) < s0:
				w.append(j)
				n += maxi(0, 4 - int(seen[j]))
			c[j] -= 1
		rows[k] = {"sh": s0, "n": n, "waits": w}
		c[k] += 1
	return _rank(rows)


static func _better(a: Dictionary, b: Dictionary) -> bool:
	return int(a.sh) < int(b.sh) or (int(a.sh) == int(b.sh) and int(a.n) > int(b.n))


static func _rank(rows: Dictionary) -> Dictionary:
	var top: = {}
	for k in rows:
		if top.is_empty() or _better(rows[k], top):
			top = rows[k]
	var best: = []
	for k in rows:
		if int(rows[k].sh) == int(top.sh) and int(rows[k].n) == int(top.n):
			best.append(int(k))
	best.sort()
	var runner: = -1
	for k in rows:
		if best.has(int(k)):
			continue
		if runner < 0 or _better(rows[k], rows[runner]):
			runner = int(k)
	return {"rows": rows, "best": best, "sh": int(top.sh), "n": int(top.n), "runner": runner}


# лучший ответ однозначен или все лучшие ответы равноценны (одинаковые ожидания)
static func unambiguous(a: Dictionary) -> bool:
	var b: Array = a.best
	if b.size() == 1:
		return true
	var w0: Array = a.rows[b[0]].waits
	for k in b:
		if a.rows[k].waits != w0:
			return false
	return true


# семь пар и сироты не мешают: регулярная форма строго быстрее, ответ — про наборы
static func regular_only(hand: Array) -> bool:
	var c: = V10MjBridgeTiles.counts(hand)
	var reg: = V8Mj.shanten_regular(c, 0)
	return V8Mj.shanten_chiitoi(c) > reg + 1 and V8Mj.shanten_kokushi(c) > reg + 1


static func possible(hand: Array, dora: int) -> bool:
	if hand.size() != 14:
		return false
	var seen: = seen_of(hand, dora)
	for k in V10MjBridgeTiles.KINDS:
		if int(seen[k]) > 4:
			return false
	for k in hand:
		if int(k) < 0 or int(k) >= 34:
			return false
	return dora >= 0 and dora < 34


static func indicator_for(k: int) -> int:
	if k < 27:
		return k - k % 9 + (k % 9 + 8) % 9
	if k < 31:
		return 27 + (k - 27 + 3) % 4
	return 31 + (k - 31 + 2) % 3


# подсказка формы («Школа стола»): разбор руки на наборы, заготовки и лишние фишки
#   [{"t": "set"|"pair"|"part"|"free", "k": [виды]}], порядок — по первой фишке группы, лишние — в конце
static func shape(hand: Array) -> Array:
	var c: = V10MjBridgeTiles.counts(hand)
	var best: = {"score": -1, "groups": []}
	_shape_dfs(c, 0, [], best)
	var groups: = []
	var free: = []
	for g in best.groups:
		if String(g.t) == "free":
			free.append(g)
		else:
			groups.append(g)
	groups.sort_custom(func(a, b): return int(a.k[0]) < int(b.k[0]))
	groups.append_array(free)
	return groups


static func _shape_score(groups: Array) -> int:
	var m: = 0
	var t: = 0
	var p: = 0
	for g in groups:
		match String(g.t):
			"set":
				m += 1
			"pair":
				if p == 0:
					p = 1
				else:
					t += 1
			"part":
				t += 1
	return (2 * m + mini(t, 4 - m) + p) * 10 + m


static func _shape_dfs(c: Array, i: int, groups: Array, best: Dictionary) -> void:
	while i < 34 and c[i] == 0:
		i += 1
	if i >= 34:
		var s: = _shape_score(groups)
		if s > int(best.score):
			best.score = s
			best.groups = groups.duplicate(true)
		return
	if c[i] >= 3:
		c[i] -= 3
		groups.append({"t": "set", "k": [i, i, i]})
		_shape_dfs(c, i, groups, best)
		groups.pop_back()
		c[i] += 3
	var suited: = i < 27
	if suited and i % 9 <= 6 and c[i + 1] > 0 and c[i + 2] > 0:
		c[i] -= 1; c[i + 1] -= 1; c[i + 2] -= 1
		groups.append({"t": "set", "k": [i, i + 1, i + 2]})
		_shape_dfs(c, i, groups, best)
		groups.pop_back()
		c[i] += 1; c[i + 1] += 1; c[i + 2] += 1
	if c[i] >= 2:
		c[i] -= 2
		groups.append({"t": "pair", "k": [i, i]})
		_shape_dfs(c, i, groups, best)
		groups.pop_back()
		c[i] += 2
	if suited and i % 9 <= 7 and c[i + 1] > 0:
		c[i] -= 1; c[i + 1] -= 1
		groups.append({"t": "part", "k": [i, i + 1]})
		_shape_dfs(c, i, groups, best)
		groups.pop_back()
		c[i] += 1; c[i + 1] += 1
	if suited and i % 9 <= 6 and c[i + 2] > 0:
		c[i] -= 1; c[i + 2] -= 1
		groups.append({"t": "part", "k": [i, i + 2]})
		_shape_dfs(c, i, groups, best)
		groups.pop_back()
		c[i] += 1; c[i + 2] += 1
	# фишка остаётся лишней
	c[i] -= 1
	groups.append({"t": "free", "k": [i]})
	_shape_dfs(c, i, groups, best)
	groups.pop_back()
	c[i] += 1


# ── слова ─────────────────────────────────────────────────────────────────────

static func plural(n: int, one: String, few: String, many: String) -> String:
	var a: = absi(n) % 100
	if a >= 11 and a <= 14:
		return many
	match a % 10:
		1:
			return one
		2, 3, 4:
			return few
	return many


static func wait_phrase(n: int) -> String:
	var w: = plural(n, "ожидание", "ожидания", "ожиданий")
	if n < NUM_NOM_N.size():
		return "%s %s" % [NUM_NOM_N[n], w]
	return "%d %s" % [n, w]


static func gen_num(n: int) -> String:
	return NUM_GEN[n] if n < NUM_GEN.size() else str(n)


static func wait_tiles(n: int) -> String:
	return "%s %d %s" % ["ждёт" if plural(n, "1", "2", "5") == "1" else "ждут", n, plural(n, "фишка", "фишки", "фишек")]


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


# Одна фраза героини после ответа (≤ 2 строк). pick — сброшенный вид (−1 — «Не знаю — покажи»), ok — он из лучших.
static func explain(item: Dictionary, pick: int, ok: bool) -> String:
	var a: = analysis_of(item)
	var rows: Dictionary = a.rows
	var best: int = pick if ok and pick >= 0 else int(a.best[0])
	var rb: Dictionary = rows[best]
	var dora: = V8Mj.dora_of(int(item.dora))
	if ok or pick < 0:
		var r: int = int(a.runner)
		if String(item.get("kind", "")) == "dv" and best == dora:
			var keep: = _keep_dora_row(item, a)
			if not keep.is_empty():
				return "Дора дорогая, но без неё %s, а с ней — %d." % [wait_tiles(int(rb.n)), int(keep.n)]
		var lead: = "Без %s" % V10MjBridgeTiles.name_gen(best) if ok else "Сбрось %s:" % V10MjBridgeTiles.name_acc(best)
		if r < 0:
			return "%s %s." % [lead, wait_tiles(int(rb.n))]
		var rr: Dictionary = rows[r]
		if int(rr.sh) > int(rb.sh):
			if int(rb.sh) == 0:
				return "%s рука готова — %s." % [lead, wait_tiles(int(rb.n))]
			return "%s до готовности на шаг меньше." % lead
		var kb: = (rb.waits as Array).size()
		var kr: = (rr.waits as Array).size()
		if kb != kr and kb < NUM_NOM_N.size() and kr < NUM_GEN.size():
			return "%s у тебя %s вместо %s." % [lead, wait_phrase(kb), gen_num(kr)]
		return "%s %s, а не %d." % [lead, wait_tiles(int(rb.n)), int(rr.n)]
	# неверный сброс: что было лучше
	var rp: Dictionary = rows.get(pick, rb)
	if int(rp.sh) > int(rb.sh):
		return "Лучше сбросить %s: так до готовности на шаг ближе." % V10MjBridgeTiles.name_acc(best)
	return "Лучше сбросить %s: %s, а не %d." % [V10MjBridgeTiles.name_acc(best), wait_tiles(int(rb.n)), int(rp.n)]


# первая ошибка (можно попробовать ещё раз): без ответа, только сколько ждут
static func retry_line(item: Dictionary, pick: int) -> String:
	var a: = analysis_of(item)
	var rp: Dictionary = (a.rows as Dictionary).get(pick, {})
	if rp.is_empty():
		return "Попробуй другую."
	if int(rp.sh) > int(a.sh):
		return "Так рука дальше от готовности. Ещё раз?"
	return "Так %s. Можно лучше." % wait_tiles(int(rp.n))


static func intro_line(item: Dictionary, school: bool) -> String:
	if school:
		return "Школа стола: линия — готовый набор. Что лишнее?"
	match String(item.get("kind", "")):
		"t1", "t2":
			return "Один сброс до готовой руки. Какой?"
		"dv":
			return "Дора или скорость? Выбирай."
	return "Какую сбросить?"


# вариант, который держит дору (для «дорогая или быстрая»)
static func _keep_dora_row(item: Dictionary, a: Dictionary) -> Dictionary:
	var dora: = V8Mj.dora_of(int(item.dora))
	var out: = {}
	for k in a.rows:
		if int(k) == dora:
			continue
		var r: Dictionary = a.rows[k]
		if int(r.sh) != int(a.sh):
			continue
		if out.is_empty() or int(r.n) > int(out.n):
			out = r
	return out


static func analysis_of(item: Dictionary) -> Dictionary:
	if item.has("_a"):
		return item._a
	var a: = analyze(item.hand, int(item.dora))
	item["_a"] = a
	return a


static func share(item: Dictionary, tries: int, shown: bool) -> String:
	var how: = "с подсказкой" if shown or tries <= 0 or tries >= TRY_WORD.size() else String(TRY_WORD[tries])
	return "Задача %d · %s\n%s" % [int(item.n), how, V10MjBridgeTiles.squares(item.hand)]


# ── даты ──────────────────────────────────────────────────────────────────────

static func weekday(y: int, m: int, d: int) -> int:
	var u: = Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 12, "minute": 0, "second": 0})
	var dd: = Time.get_datetime_dict_from_unix_time(u)
	return (int(dd.weekday) + 6) % 7


static func day_of_year(y: int, m: int, d: int) -> int:
	var u0: = Time.get_unix_time_from_datetime_dict({"year": y, "month": 1, "day": 1, "hour": 12, "minute": 0, "second": 0})
	var u: = Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 12, "minute": 0, "second": 0})
	return int(round(float(u - u0) / 86400.0)) + 1


static func date_of(y: int, doy: int) -> Dictionary:
	var u0: = Time.get_unix_time_from_datetime_dict({"year": y, "month": 1, "day": 1, "hour": 12, "minute": 0, "second": 0})
	var dd: = Time.get_datetime_dict_from_unix_time(u0 + (doy - 1) * 86400)
	return {"year": int(dd.year), "month": int(dd.month), "day": int(dd.day)}


static func day_key(d: Dictionary) -> String:
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


static func parse_day(s: String) -> Dictionary:
	var p: = s.split("-")
	if p.size() != 3:
		return {}
	return {"year": int(p[0]), "month": int(p[1]), "day": int(p[2])}


static func today() -> Dictionary:
	var d: = Time.get_date_dict_from_system()
	return {"year": int(d.year), "month": int(d.month), "day": int(d.day)}


static func days_in_month(y: int, m: int) -> int:
	var ny: = y + (1 if m == 12 else 0)
	var nm: = 1 if m == 12 else m + 1
	return day_of_year(ny, nm, 1) - day_of_year(y, m, 1) if ny == y else 31


# ── данные ────────────────────────────────────────────────────────────────────

static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var f: = FileAccess.open(DATA_PATH, FileAccess.READ)
	var j = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		_data = j
		for it in _data.get("items", []):
			norm(it)
	return _data


static func items() -> Array:
	return data().get("items", [])


# JSON отдаёт числа как float: приводим виды к int, чтобы has()/== работали
static func norm(it: Dictionary) -> Dictionary:
	for key in ["hand", "best"]:
		var a: = []
		for v in it.get(key, []):
			a.append(int(v))
		it[key] = a
	for key in ["dora", "wind", "n", "wd", "sh", "uke", "runner"]:
		if it.has(key):
			it[key] = int(it[key])
	var shp: = []
	for g in it.get("shape", []):
		var ks: = []
		for v in g[1]:
			ks.append(int(v))
		shp.append([String(g[0]), ks])
	it["shape"] = shp
	return it


# задача на дату: 2027 — по номеру дня; другие годы — тот же номер дня, сдвинутый к записи того же дня недели
static func item_for(d: Dictionary) -> Dictionary:
	var all: = items()
	if all.is_empty():
		return {}
	var y: = int(d.year)
	var doy: = clampi(day_of_year(y, int(d.month), int(d.day)), 1, COUNT)
	var idx: = doy
	if y != YEAR:
		var wd: = weekday(y, int(d.month), int(d.day))
		var it0: Dictionary = all[idx - 1]
		var delta: = posmod(wd - int(it0.wd), 7)
		idx = idx + delta if idx + delta <= COUNT else idx + delta - 7
	var it: Dictionary = (all[idx - 1] as Dictionary).duplicate(true)
	it["day"] = day_key(d)
	return it


# ── генератор (офлайн) ────────────────────────────────────────────────────────

static func generate(count: = COUNT, log: Callable = Callable()) -> Dictionary:
	var out: = []
	var tries_total: = 0
	for n in range(1, count + 1):
		var dt: = date_of(YEAR, n)
		var wd: = weekday(YEAR, int(dt.month), int(dt.day))
		var kind: String = WD_KIND[wd]
		var school: = n <= SCHOOL
		if school:
			kind = ["t1", "t1", "t2", "i1", "t1", "i1", "t2"][n - 1]
		var rng: = RandomNumberGenerator.new()
		rng.seed = SEED_BASE + n * 7919
		var it: = {}
		var tries: = 0
		while it.is_empty() and tries < 20000:
			tries += 1
			it = _try_make(rng, kind, school)
		tries_total += tries
		if it.is_empty():
			push_error("bridge gen: day %d (%s) failed" % [n, kind])
			continue
		it["n"] = n
		it["date"] = day_key(dt)
		it["wd"] = wd
		it["kind"] = kind
		it["school"] = school
		out.append(it)
		if log.is_valid():
			log.call(it, tries)
	return {"ver": 1, "year": YEAR, "count": out.size(), "seed": SEED_BASE, "tries": tries_total, "items": out}


static func write(path: String, d: Dictionary) -> bool:
	var abs: = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f: = FileAccess.open(abs, FileAccess.WRITE)
	if f == null:
		return false
	var lines: = PackedStringArray()
	lines.append("{\"ver\":%d,\"year\":%d,\"count\":%d,\"seed\":%d,\"tries\":%d,\"items\":[" % [d.ver, d.year, d.count, d.seed, d.tries])
	var its: Array = d.items
	for i in its.size():
		var e: Dictionary = (its[i] as Dictionary).duplicate(true)
		e.erase("_a")
		lines.append(JSON.stringify(e) + ("," if i < its.size() - 1 else ""))
	lines.append("]}")
	f.store_string("\n".join(lines) + "\n")
	f.close()
	_data = {}
	return true


# одна попытка: рука по профилю дня → анализ → фильтр сложности
static func _try_make(rng: RandomNumberGenerator, kind: String, school: bool) -> Dictionary:
	var dora_ind: = rng.randi_range(0, 33)
	var c: = V10MjBridgeTiles.zero()
	c[dora_ind] += 1
	var plan: Array = _profile(rng, kind)
	var hand: = []
	for b in plan:
		var blk: = _block(rng, String(b), c)
		if blk.is_empty():
			return {}
		for k in blk:
			c[k] += 1
		hand.append_array(blk)
	if hand.size() != 14:
		return {}
	var c14: = V10MjBridgeTiles.counts(hand)
	if V8Mj.shanten_regular(c14, 0) < 0 or not regular_only(hand):
		return {}
	if kind == "dv":
		# дора — на лучшем сбросе: «быстрая» рука отпускает дорогую фишку
		var a0: = analyze(hand, dora_ind)
		if (a0.best as Array).size() != 1:
			return {}
		var b0: int = a0.best[0]
		dora_ind = indicator_for(b0)
		if int(c14[dora_ind]) + 1 > 4:
			return {}
	if not possible(hand, dora_ind):
		return {}
	var a: = analyze(hand, dora_ind)
	if not unambiguous(a) or not _fits(kind, a, hand, dora_ind, school):
		return {}
	var rows: = {}
	for k in a.rows:
		rows[str(k)] = [int(a.rows[k].sh), int(a.rows[k].n), a.rows[k].waits]
	var groups: = shape(hand)
	var sh_out: = []
	for g in groups:
		sh_out.append([String(g.t), g.k])
	return {"hand": V10MjBridgeTiles.sorted(hand), "dora": dora_ind, "wind": 27 + rng.randi_range(0, 3),
		"best": a.best, "sh": int(a.sh), "uke": int(a.n), "runner": int(a.runner), "rows": rows, "shape": sh_out}


static func _fits(kind: String, a: Dictionary, hand: Array, dora_ind: int, school: bool) -> bool:
	var rows: Dictionary = a.rows
	var r: int = int(a.runner)
	if r < 0:
		return false
	var rr: Dictionary = rows[r]
	var sh: int = int(a.sh)
	var gap: int = int(a.n) - int(rr.n)
	var same: = 0
	for k in rows:
		if int(rows[k].sh) == sh:
			same += 1
	match kind:
		"t1":
			return sh == 0 and (a.best as Array).size() == 1 and (int(rr.sh) > 0 or gap >= 4) and int(a.n) >= 4
		"t2":
			return sh == 0 and int(rr.sh) == 0 and gap >= 2 and gap <= 8 and int(rr.n) >= 1
		"i1":
			return sh == 1 and (int(rr.sh) > 1 or gap >= 6) and (a.best as Array).size() == 1
		"i2":
			return sh == 1 and int(rr.sh) == 1 and gap >= 2 and gap <= 10 and same >= 3
		"i3":
			return sh == 1 and int(rr.sh) == 1 and gap >= 1 and gap <= 4 and same >= 4
		"r2":
			return sh == 2 and int(rr.sh) == 2 and gap >= 1 and gap <= 8 and same >= 4
		"dv":
			var dk: = V8Mj.dora_of(dora_ind)
			if not (a.best as Array).has(dk) or (a.best as Array).size() != 1 or sh > 1:
				return false
			var keep: = _keep_dora_row({"dora": dora_ind}, a)
			return not keep.is_empty() and int(a.n) - int(keep.n) >= 2
	return false


static func _profile(rng: RandomNumberGenerator, kind: String) -> Array:
	var set3: = func() -> String: return "trip" if rng.randf() < 0.22 else "run"
	match kind:
		"t1":
			return [set3.call(), set3.call(), set3.call(), "pair", "ryan" if rng.randf() < 0.7 else "kan", "single"]
		"t2":
			match rng.randi_range(0, 2):
				0:
					return [set3.call(), set3.call(), set3.call(), "pair", "c3"]
				1:
					return ["run", "run", set3.call(), "pair", "pair", "near"]
				_:
					return [set3.call(), set3.call(), set3.call(), "pair", "ryan", "near"]
		"i1":
			return [set3.call(), set3.call(), "pair", "ryan", "ryan" if rng.randf() < 0.6 else "kan", "single", "single"]
		"i2":
			return [set3.call(), set3.call(), "pair", "ryan" if rng.randf() < 0.5 else "kan", "c3", "near"]
		"i3":
			if rng.randf() < 0.5:
				return [set3.call(), set3.call(), "pair", "c3", "c3"]
			return [set3.call(), set3.call(), "pair", "pair", "c3", "near"]
		"r2":
			return [set3.call(), "pair", "ryan", "kan" if rng.randf() < 0.5 else "ryan", "c3", "near", "single"]
		"dv":
			match rng.randi_range(0, 2):
				0:
					return [set3.call(), set3.call(), "pair", "ryan", "ryan", "near", "near"]
				1:
					return [set3.call(), set3.call(), "pair", "ryan", "c3", "near"]
				_:
					return [set3.call(), set3.call(), set3.call(), "pair", "ryan", "near"]
	return []


static func _fits_counts(c: Array, blk: Array) -> bool:
	var add: = {}
	for k in blk:
		add[k] = int(add.get(k, 0)) + 1
	for k in add:
		if int(c[k]) + int(add[k]) > 4:
			return false
	return true


static func _suited(rng: RandomNumberGenerator, lo: int, hi: int) -> int:
	var s: = rng.randi_range(0, 2)
	return s * 9 + rng.randi_range(lo, hi)


static func _block(rng: RandomNumberGenerator, b: String, c: Array) -> Array:
	for attempt in 40:
		var blk: = []
		match b:
			"run":
				var k: = _suited(rng, 0, 6)
				blk = [k, k + 1, k + 2]
			"trip":
				var k: = rng.randi_range(0, 33)
				blk = [k, k, k]
			"pair":
				var k: = rng.randi_range(0, 33)
				blk = [k, k]
			"ryan":
				var k: = _suited(rng, 1, 6)
				blk = [k, k + 1]
			"kan":
				var k: = _suited(rng, 0, 6)
				blk = [k, k + 2]
			"c3":
				match rng.randi_range(0, 4):
					0:
						var k: = _suited(rng, 0, 5)
						blk = [k, k + 1, k + 3]
					1:
						var k: = _suited(rng, 0, 7)
						blk = [k, k, k + 1]
					2:
						var k: = _suited(rng, 0, 7)
						blk = [k, k + 1, k + 1]
					3:
						var k: = _suited(rng, 0, 4)
						blk = [k, k + 2, k + 4]
					_:
						var k: = _suited(rng, 0, 5)
						blk = [k, k + 2, k + 3]
			"near":
				# «близкая» одиночка: простая фишка, которая может к чему-то прилипнуть
				var k: = _suited(rng, 1, 7)
				blk = [k]
			"single":
				# далёкая одиночка: знак или край
				if rng.randf() < 0.6:
					blk = [rng.randi_range(27, 33)]
				else:
					blk = [_suited(rng, 0, 0) + (8 if rng.randf() < 0.5 else 0)]
		if not blk.is_empty() and _fits_counts(c, blk):
			return blk
	return []
