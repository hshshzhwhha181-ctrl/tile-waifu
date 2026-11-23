class_name V8Mj
extends RefCounted




const AKA: = [16, 52, 88]
const SUIT_RU: = ["ман", "пин", "со"]
const HONOR_RU: = ["Восток", "Юг", "Запад", "Север", "Белый дракон", "Зелёный дракон", "Красный дракон"]
const WIND_RU: = ["Восток", "Юг", "Запад", "Север"]
const WIND_CH: = ["東", "南", "西", "北"]


const YAKU: = {
	"riichi": ["Риичи", 1, 0, "Объяви темпай закрытой рукой и поставь 1000 очков"], 
	"ippatsu": ["Иппацу", 1, 0, "Победа в первый круг после риичи"], 
	"tsumo": ["Цумо", 1, 0, "Закрытая рука, победный тайл взят из стены сам"], 
	"pinfu": ["Пинфу", 1, 0, "Только последовательности, пара без бонуса, ожидание с двух сторон"], 
	"iipeikou": ["Иипэйко", 1, 0, "Две одинаковые последовательности, закрытая рука"], 
	"tanyao": ["Таняо", 1, 1, "Только тайлы 2–8, без единиц, девяток и знаков"], 
	"haku": ["Белый дракон", 1, 1, "Три белых дракона"], 
	"hatsu": ["Зелёный дракон", 1, 1, "Три зелёных дракона"], 
	"chun": ["Красный дракон", 1, 1, "Три красных дракона"], 
	"seat": ["Ветер места", 1, 1, "Три тайла своего ветра"], 
	"round": ["Ветер раунда", 1, 1, "Три тайла ветра раунда"], 
	"haitei": ["Хайтей", 1, 1, "Победа последним тайлом стены"], 
	"houtei": ["Хотей", 1, 1, "Рон на последний сброс"], 
	"rinshan": ["Ринсян", 1, 1, "Победа тайлом после кана"], 
	"chankan": ["Чанкан", 1, 1, "Рон на тайл, которым добирают кан"], 
	"double_riichi": ["Дабл риичи", 2, 0, "Риичи первым же сбросом"], 
	"chiitoitsu": ["Читойцу", 2, 0, "Семь разных пар"], 
	"sanshoku": ["Сансёку", 2, 1, "Одна и та же последовательность в трёх мастях"], 
	"ittsu": ["Иццу", 2, 1, "1-2-3, 4-5-6, 7-8-9 одной масти"], 
	"chanta": ["Чанта", 2, 1, "В каждом блоке и паре есть 1, 9 или знак"], 
	"toitoi": ["Тойтой", 2, 2, "Все блоки — тройки"], 
	"sanankou": ["Сананко", 2, 2, "Три закрытые тройки"], 
	"sankantsu": ["Санканцу", 2, 2, "Три кана"], 
	"sanshoku_doukou": ["Сансёку доко", 2, 2, "Тройки одного числа в трёх мастях"], 
	"shousangen": ["Сёсанген", 2, 2, "Две тройки драконов и пара третьего"], 
	"honroutou": ["Хонрото", 2, 2, "Только единицы, девятки и знаки"], 
	"honitsu": ["Хонъицу", 3, 2, "Одна масть и знаки"], 
	"junchan": ["Дзюнчан", 3, 2, "В каждом блоке и паре есть 1 или 9, без знаков"], 
	"ryanpeikou": ["Рянпэйко", 3, 0, "Дважды по две одинаковые последовательности"], 
	"chinitsu": ["Чинъицу", 6, 5, "Вся рука одной масти"], 
}
const YAKUMAN: = {
	"kokushi": ["Кокуси мусо", "Все 13 разных единиц, девяток и знаков + пара"], 
	"suuankou": ["Сууанко", "Четыре закрытые тройки"], 
	"daisangen": ["Дайсанген", "Тройки всех трёх драконов"], 
	"shousuushii": ["Сёсууси", "Три тройки ветров и пара четвёртого"], 
	"daisuushii": ["Дайсууси", "Тройки всех четырёх ветров"], 
	"tsuuiisou": ["Цуисо", "Только знаки"], 
	"ryuuiisou": ["Рюисо", "Только зелёные тайлы"], 
	"chinroutou": ["Чинрото", "Только единицы и девятки"], 
	"chuuren": ["Чууренпото", "Девять врат: 1112345678999 одной масти + любой"], 
	"suukantsu": ["Сууканцу", "Четыре кана"], 
	"tenhou": ["Тенхо", "Победа раздачей у дилера"], 
	"chiihou": ["Тихо", "Победа первым же набором"], 
}
const LIMIT_RU: = {2000: "Манган", 3000: "Ханеман", 4000: "Байман", 6000: "Санбайман", 8000: "Якуман"}


static func kind(t: int) -> int:
	return t >> 2

static func is_aka(t: int) -> bool:
	return t == 16 or t == 52 or t == 88


static func face(t: int) -> int:
	if t == 16:
		return 34
	if t == 52:
		return 35
	if t == 88:
		return 36
	return t >> 2

static func is_honor(k: int) -> bool:
	return k >= 27

static func is_term(k: int) -> bool:
	return k < 27 and (k % 9 == 0 or k % 9 == 8)

static func is_yaochu(k: int) -> bool:
	return k >= 27 or k % 9 == 0 or k % 9 == 8

static func suit(k: int) -> int:
	return mini(k / 9, 3)

static func num(k: int) -> int:
	return k % 9 + 1

static func dora_of(ind: int) -> int:
	if ind < 27:
		return ind - ind % 9 + (ind % 9 + 1) % 9
	if ind < 31:
		return 27 + (ind - 27 + 1) % 4
	return 31 + (ind - 31 + 1) % 3

static func name_ru(k: int) -> String:
	if k >= 27:
		return HONOR_RU[k - 27]
	return "%d %s" % [num(k), SUIT_RU[suit(k)]]

static func short_ru(k: int) -> String:
	if k >= 27:
		return ["В", "Ю", "З", "С", "Бел", "Зел", "Кр"][k - 27]
	return "%d%s" % [num(k), ["м", "п", "с"][suit(k)]]

static func counts(tiles: Array) -> Array:
	var c: = []
	c.resize(34)
	c.fill(0)
	for t in tiles:
		c[t >> 2] += 1
	return c

static func sort_tiles(tiles: Array) -> Array:
	var a: = tiles.duplicate()
	a.sort_custom( func(x, y): return (x >> 2) < (y >> 2) or ((x >> 2) == (y >> 2) and x < y))
	return a


static var _cache: = {}

static func _dfs(v: Array, i: int, n: int, seq: bool, m: int, t: int, p: int, res: Dictionary) -> void :
	while i < n and v[i] == 0:
		i += 1
	if i >= n:
		res[m * 100 + t * 10 + p] = true
		return
	if v[i] >= 3:
		v[i] -= 3
		_dfs(v, i, n, seq, m + 1, t, p, res)
		v[i] += 3
	if seq and i + 2 < n and v[i + 1] > 0 and v[i + 2] > 0:
		v[i] -= 1;v[i + 1] -= 1;v[i + 2] -= 1
		_dfs(v, i, n, seq, m + 1, t, p, res)
		v[i] += 1;v[i + 1] += 1;v[i + 2] += 1
	if v[i] >= 2:
		v[i] -= 2
		if p == 0:
			_dfs(v, i, n, seq, m, t, 1, res)
		_dfs(v, i, n, seq, m, t + 1, p, res)
		v[i] += 2
	if seq and i + 1 < n and v[i + 1] > 0:
		v[i] -= 1;v[i + 1] -= 1
		_dfs(v, i, n, seq, m, t + 1, p, res)
		v[i] += 1;v[i + 1] += 1
	if seq and i + 2 < n and v[i + 2] > 0:
		v[i] -= 1;v[i + 2] -= 1
		_dfs(v, i, n, seq, m, t + 1, p, res)
		v[i] += 1;v[i + 2] += 1
	v[i] -= 1
	_dfs(v, i, n, seq, m, t, p, res)
	v[i] += 1

static func _prune(codes: Array) -> Array:
	var out: = []
	for a in codes:
		var am: int = a / 100
		var at: int = (a / 10) % 10
		var ap: int = a % 10
		var dominated: = false
		for b in codes:
			if b == a:
				continue
			var bm: int = b / 100
			var bt: int = (b / 10) % 10
			var bp: int = b % 10
			if bm >= am and bt >= at and bp >= ap:
				dominated = true
				break
		if not dominated:
			out.append(a)
	return out

static func _opts(c: Array, base: int, n: int, seq: bool) -> Array:
	var key: = 1 if seq else 2
	for i in n:
		key = key * 5 + c[base + i]
	if _cache.has(key):
		return _cache[key]
	var v: = []
	for i in n:
		v.append(c[base + i])
	var res: = {}
	_dfs(v, 0, n, seq, 0, 0, 0, res)
	var out: = _prune(res.keys())
	_cache[key] = out
	return out

static func shanten_regular(c: Array, melds: int) -> int:
	var acc: = [melds * 100]
	var groups: = [_opts(c, 0, 9, true), _opts(c, 9, 9, true), _opts(c, 18, 9, true), _opts(c, 27, 7, false)]
	for g in groups:
		var nxt: = {}
		for a in acc:
			for b in g:
				if (a % 10) + (b % 10) > 1:
					continue
				var s: int = a + b
				if (s / 10) % 10 > 7:
					s = (s / 100) * 100 + 70 + s % 10
				nxt[s] = true
		acc = _prune(nxt.keys())
	var best: = 8
	for a in acc:
		var m: int = a / 100
		var t: int = (a / 10) % 10
		var p: int = a % 10
		var s: = 8 - 2 * m - mini(t, 4 - m) - p
		best = mini(best, s)
	return best

static func shanten_chiitoi(c: Array) -> int:
	var pairs: = 0
	var kinds: = 0
	for k in 34:
		if c[k] >= 1:
			kinds += 1
		if c[k] >= 2:
			pairs += 1
	return 6 - pairs + maxi(0, 7 - kinds)

static func shanten_kokushi(c: Array) -> int:
	var y: = 0
	var pr: = 0
	for k in [0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33]:
		if c[k] >= 1:
			y += 1
		if c[k] >= 2:
			pr = 1
	return 13 - y - pr

static func shanten(c: Array, melds: = 0) -> int:
	var s: = shanten_regular(c, melds)
	if melds == 0:
		s = mini(s, mini(shanten_chiitoi(c), shanten_kokushi(c)))
	return s

static func is_agari(c: Array, melds: = 0) -> bool:
	return shanten(c, melds) == -1


static func waits(c: Array, melds: = 0) -> Array:
	var out: = []
	for k in 34:
		if c[k] >= 4:
			continue
		c[k] += 1
		if shanten(c, melds) == -1:
			out.append(k)
		c[k] -= 1
	return out


static func ukeire(c: Array, melds: int, seen: Array) -> Dictionary:
	var s0: = shanten(c, melds)
	var kinds: = []
	var total: = 0
	for k in 34:
		if c[k] >= 4:
			continue

		if not _near(c, k):
			continue
		c[k] += 1
		if shanten(c, melds) < s0:
			var left: = maxi(0, 4 - seen[k])
			kinds.append(k)
			total += left
		c[k] -= 1
	return {"kinds": kinds, "n": total, "shanten": s0}

static func _near(c: Array, k: int) -> bool:
	if c[k] > 0:
		return true
	if k >= 27:
		return c[k] > 0 or true
	var b: = k - k % 9
	for d in [-2, -1, 1, 2]:
		var j: int = k + d
		if j >= b and j < b + 9 and c[j] > 0:
			return true
	return is_term(k)


static func decompose(c: Array) -> Array:
	var out: = []
	for p in 34:
		if c[p] >= 2:
			c[p] -= 2
			_dec(c, 0, [], out, p)
			c[p] += 2
	return out

static func _dec(c: Array, i: int, sets: Array, out: Array, pair: int) -> void :
	while i < 34 and c[i] == 0:
		i += 1
	if i >= 34:
		out.append({"pair": pair, "sets": sets.duplicate(true)})
		return
	if c[i] >= 3:
		c[i] -= 3
		sets.append([0, i])
		_dec(c, i, sets, out, pair)
		sets.pop_back()
		c[i] += 3
	if i < 27 and i % 9 <= 6 and c[i + 1] > 0 and c[i + 2] > 0:
		c[i] -= 1;c[i + 1] -= 1;c[i + 2] -= 1
		sets.append([1, i])
		_dec(c, i, sets, out, pair)
		sets.pop_back()
		c[i] += 1;c[i + 1] += 1;c[i + 2] += 1



static func meld_set(md: Dictionary) -> Dictionary:
	var ks: = []
	for t in md.tiles:
		ks.append(t >> 2)
	ks.sort()
	match md.type:
		"chi":
			return {"t": 1, "k": ks[0], "open": true}
		"pon":
			return {"t": 0, "k": ks[0], "open": true}
		"ankan":
			return {"t": 2, "k": ks[0], "open": false}
		_:
			return {"t": 2, "k": ks[0], "open": true}

static func ceil100(x: float) -> int:
	return int(ceil(x / 100.0 - 0.0001)) * 100

static func base_points(han: int, fu: int, yakuman: int) -> int:
	if yakuman > 0:
		return 8000 * yakuman
	if han >= 13:
		return 8000
	if han >= 11:
		return 6000
	if han >= 8:
		return 4000
	if han >= 6:
		return 3000
	var b: = fu * int(pow(2, 2 + han))
	if han >= 5 or b >= 2000:
		return 2000
	return b

static func limit_name(han: int, fu: int, yakuman: int) -> String:
	if yakuman > 1:
		return "Двойной якуман" if yakuman == 2 else "%d× якуман" % yakuman
	if yakuman == 1:
		return "Якуман"
	if han >= 13:
		return "Счётный якуман"
	var b: = base_points(han, fu, 0)
	return LIMIT_RU.get(b, "")






static func evaluate(closed: Array, melds: Array, win: int, ctx: Dictionary) -> Dictionary:
	var c: = counts(closed)
	var nm: = melds.size()
	if shanten(c, nm) != -1:
		return {}
	var wk: = win >> 2
	var menzen: = true
	var msets: = []
	for md in melds:
		var s: = meld_set(md)
		msets.append(s)
		if s.open:
			menzen = false
	var all_tiles: = closed.duplicate()
	for md in melds:
		all_tiles.append_array(md.tiles)
	var best: = {"han": 0, "fu": 0, "yaku": [], "yakuman": 0, "pts": -1}
	var cands: = []
	if nm == 0 and shanten_kokushi(c) == -1:
		cands.append({"special": "kokushi"})
	if nm == 0 and shanten_chiitoi(c) == -1:
		cands.append({"special": "chiitoi"})
	for d in decompose(c):
		var sets: = []
		for s in d.sets:
			sets.append({"t": s[0], "k": s[1], "open": false})

		var places: = []
		if d.pair == wk:
			places.append([-1, "tanki"])
		for i in sets.size():
			var s: Dictionary = sets[i]
			if s.t == 0 and s.k == wk:
				places.append([i, "shanpon"])
			elif s.t == 1 and wk >= s.k and wk <= s.k + 2:
				var w: = "ryanmen"
				if wk == s.k + 1:
					w = "kanchan"
				elif wk == s.k and s.k % 9 == 6:
					w = "penchan"
				elif wk == s.k + 2 and s.k % 9 == 0:
					w = "penchan"
				places.append([i, w])
		for pl in places:
			var ss: = sets.duplicate(true)
			if pl[1] == "shanpon" and not ctx.get("tsumo", false):
				ss[pl[0]].open = true
			cands.append({"sets": ss + msets.duplicate(true), "pair": d.pair, "wait": pl[1]})
	for cd in cands:
		var r: = _score_one(cd, c, menzen, wk, all_tiles, nm, ctx)
		if r.pts > best.pts:
			best = r
	return best

static func _score_one(cd: Dictionary, c: Array, menzen: bool, wk: int, all_tiles: Array, nm: int, ctx: Dictionary) -> Dictionary:
	var yaku: = []
	var ym: = []
	var tsumo: bool = ctx.get("tsumo", false)
	var seat_w: int = ctx.get("seat_wind", 27)
	var round_w: int = ctx.get("round_wind", 27)
	var kinds_all: = []
	for t in all_tiles:
		kinds_all.append(t >> 2)
	var special: String = cd.get("special", "")

	if ctx.get("tenhou", false):
		ym.append(["tenhou", 1])
	if ctx.get("chiihou", false):
		ym.append(["chiihou", 1])
	var fu: = 20
	if special == "kokushi":
		ym.append(["kokushi", 1])
	else:
		var sets: Array = cd.get("sets", [])
		var pair: int = cd.get("pair", -1)
		var wait: String = cd.get("wait", "")
		var seqs: = []
		var trips: = []
		var concealed_trips: = 0
		var kans: = 0
		for s in sets:
			if s.t == 1:
				seqs.append(s.k)
			else:
				trips.append(s.k)
				if not s.open:
					concealed_trips += 1
				if s.t == 2:
					kans += 1

		if special == "":
			var dr: = 0
			for k in [31, 32, 33]:
				if k in trips:
					dr += 1
			if dr == 3:
				ym.append(["daisangen", 1])
			var wt: = 0
			for k in [27, 28, 29, 30]:
				if k in trips:
					wt += 1
			if wt == 4:
				ym.append(["daisuushii", 2])
			elif wt == 3 and pair >= 27 and pair <= 30:
				ym.append(["shousuushii", 1])
			if concealed_trips == 4:
				ym.append(["suuankou", 1])
			if kans == 4:
				ym.append(["suukantsu", 1])
		var all_honor: = true
		var all_term: = true
		var all_green: = true
		for k in kinds_all:
			if k < 27:
				all_honor = false
			if not is_term(k):
				all_term = false
			if not (k in [19, 20, 21, 23, 25, 32]):
				all_green = false
		if all_honor:
			ym.append(["tsuuiisou", 1])
		if all_term:
			ym.append(["chinroutou", 1])
		if all_green:
			ym.append(["ryuuiisou", 1])
		if menzen and nm == 0 and special == "":
			var su: = suit(kinds_all[0])
			var one: = su < 3
			for k in kinds_all:
				if suit(k) != su:
					one = false
			if one:
				var need: = [3, 1, 1, 1, 1, 1, 1, 1, 3]
				var ok: = true
				for i in 9:
					if c[su * 9 + i] < need[i]:
						ok = false
				if ok:
					ym.append(["chuuren", 1])
		if ym.is_empty():

			if special == "chiitoi":
				yaku.append(["chiitoitsu", 2])
			var pinfu: = false
			if special == "" and menzen and seqs.size() == 4 and wait == "ryanmen" and not _yakuhai_pair(pair, seat_w, round_w):
				pinfu = true
				yaku.append(["pinfu", 1])
			if special == "" and menzen:
				var dup: = 0
				var sq: = seqs.duplicate()
				sq.sort()
				var i: = 0
				while i < sq.size() - 1:
					if sq[i] == sq[i + 1]:
						dup += 1
						i += 2
					else:
						i += 1
				if dup == 2:
					yaku.append(["ryanpeikou", 3])
				elif dup == 1:
					yaku.append(["iipeikou", 1])
			var tany: = true
			for k in kinds_all:
				if is_yaochu(k):
					tany = false
			if tany:
				yaku.append(["tanyao", 1])
			if special == "":
				for k in trips:
					if k == 31:
						yaku.append(["haku", 1])
					elif k == 32:
						yaku.append(["hatsu", 1])
					elif k == 33:
						yaku.append(["chun", 1])
					if k == seat_w:
						yaku.append(["seat", 1])
					if k == round_w:
						yaku.append(["round", 1])

				for n in 7:
					if n in seqs and (n + 9) in seqs and (n + 18) in seqs:
						yaku.append(["sanshoku", 2 if menzen else 1])
						break
				for su in 3:
					if su * 9 in seqs and su * 9 + 3 in seqs and su * 9 + 6 in seqs:
						yaku.append(["ittsu", 2 if menzen else 1])
						break
				for n in 9:
					if n in trips and (n + 9) in trips and (n + 18) in trips:
						yaku.append(["sanshoku_doukou", 2])
						break
				if trips.size() == 4:
					yaku.append(["toitoi", 2])
				if concealed_trips == 3:
					yaku.append(["sanankou", 2])
				if kans == 3:
					yaku.append(["sankantsu", 2])
				var drt: = 0
				for k in [31, 32, 33]:
					if k in trips:
						drt += 1
				if drt == 2 and pair >= 31:
					yaku.append(["shousangen", 2])

				var outside: = is_yaochu(pair)
				for s in sets:
					if s.t == 1:
						if not (s.k % 9 == 0 or s.k % 9 == 6):
							outside = false
					elif not is_yaochu(s.k):
						outside = false
				if outside and seqs.size() > 0:
					var hon: = false
					for k in kinds_all:
						if k >= 27:
							hon = true
					if hon:
						yaku.append(["chanta", 2 if menzen else 1])
					else:
						yaku.append(["junchan", 3 if menzen else 2])
			var all_yc: = true
			for k in kinds_all:
				if not is_yaochu(k):
					all_yc = false
			if all_yc:
				yaku.append(["honroutou", 2])

			var suits: = {}
			var hon2: = false
			for k in kinds_all:
				if k >= 27:
					hon2 = true
				else:
					suits[suit(k)] = true
			if suits.size() == 1:
				if hon2:
					yaku.append(["honitsu", 3 if menzen else 2])
				else:
					yaku.append(["chinitsu", 6 if menzen else 5])

			if ctx.get("double_riichi", false):
				yaku.append(["double_riichi", 2])
			elif ctx.get("riichi", false):
				yaku.append(["riichi", 1])
			if ctx.get("ippatsu", false) and ctx.get("riichi", false):
				yaku.append(["ippatsu", 1])
			if tsumo and menzen:
				yaku.append(["tsumo", 1])
			if ctx.get("haitei", false) and tsumo:
				yaku.append(["haitei", 1])
			if ctx.get("houtei", false) and not tsumo:
				yaku.append(["houtei", 1])
			if ctx.get("rinshan", false) and tsumo:
				yaku.append(["rinshan", 1])
			if ctx.get("chankan", false):
				yaku.append(["chankan", 1])

			if special == "chiitoi":
				fu = 25
			elif pinfu and tsumo:
				fu = 20
			else:
				fu = 20
				if menzen and not tsumo:
					fu += 10
				if tsumo:
					fu += 2
				for s in sets:
					if s.t == 1:
						continue
					var f: = 2
					if not s.open:
						f *= 2
					if is_yaochu(s.k):
						f *= 2
					if s.t == 2:
						f *= 4
					fu += f
				if pair >= 31:
					fu += 2
				if pair == seat_w:
					fu += 2
				if pair == round_w:
					fu += 2
				if wait in ["kanchan", "penchan", "tanki"]:
					fu += 2
				if fu == 20:
					fu = 30
				fu = int(ceil(fu / 10.0)) * 10
	var han: = 0
	for y in yaku:
		han += y[1]
	var res: = {"yaku": yaku, "han": han, "fu": fu, "yakuman": 0, "dora": 0, "aka": 0, "ura": 0, "pts": 0}
	if not ym.is_empty():
		var n: = 0
		for y in ym:
			n += y[1]
		res.yakuman = n
		res.yaku = ym
		res.han = 13 * n
	elif han == 0:
		res.pts = 0
		return res
	else:
		var dora: = 0
		for ind in ctx.get("dora_ind", []):
			var dk: = dora_of(ind >> 2)
			for k in kinds_all:
				if k == dk:
					dora += 1
		var aka: = 0
		for t in all_tiles:
			if is_aka(t):
				aka += 1
		var ura: = 0
		if ctx.get("riichi", false):
			for ind in ctx.get("ura_ind", []):
				var uk: = dora_of(ind >> 2)
				for k in kinds_all:
					if k == uk:
						ura += 1
		res.dora = dora
		res.aka = aka
		res.ura = ura
		res.han = han + dora + aka + ura
	var b: = base_points(res.han, res.fu, res.yakuman)
	res.base = b
	res.pts = b * 4 + res.han
	res.limit = limit_name(res.han, res.fu, res.yakuman)
	return res

static func _yakuhai_pair(p: int, seat_w: int, round_w: int) -> bool:
	return p >= 31 or p == seat_w or p == round_w


static func payments(base: int, dealer: bool) -> Dictionary:
	if dealer:
		return {"ron": ceil100(base * 6), "all": ceil100(base * 2)}
	return {"ron": ceil100(base * 4), "dealer": ceil100(base * 2), "other": ceil100(base)}

static func yaku_name(id: String) -> String:
	if YAKU.has(id):
		return YAKU[id][0]
	if YAKUMAN.has(id):
		return YAKUMAN[id][0]
	return id

static func yaku_hint(id: String) -> String:
	if YAKU.has(id):
		return YAKU[id][3]
	if YAKUMAN.has(id):
		return YAKUMAN[id][1]
	return ""
