class_name V10MjKoikoi
extends RefCounted

# Коикои (ханафуда) — чистый движок правил, без узлов и без интерфейса.
#
# Колода: 48 карт = 12 месяцев × 4. Карта — целое id 0..47: месяц = id / 4 (0 = январь), слот = id % 4.
# Типы: свет 5, животные 9, ленты 10 (3 красные с узором «стихи», 4 красные простые, 3 синие), пустые 24.
#
# Партия (match) = N месяцев (6 или 12). Месяц (round):
#   раздача 8 в руку каждому, 8 на стол (4 карты одного месяца на столе → пересдача);
#   ход: play(card) из руки → совпадение по месяцу забирает пару (2 кандидата → выбор, 3 → забирает все 4);
#        затем draw() из колоды → то же; затем проверка комбинаций;
#   выросли очки комбинаций → решение: stop() «Забрать» или koikoi() «Кои-кои!» (без карт в руке — только «Забрать»);
#   множитель: ×2 за каждое своё кои-кои; если забираешь после кои-кои соперницы — ещё ×2, а она получает 0 (перехват);
#   руки кончились без «Забрать» — месяц без очков, сдающий остаётся.
# Сдающий ходит первым; следующий месяц сдаёт победитель месяца.
#
# Состояние полностью в полях; `log` — очередь событий для экрана (экран снимает её через take_events()).

signal changed

const MONTHS: = 12
const HAND: = 8
const TABLE: = 8

# kind: light / animal / ribbon / plain; tag — для комбинаций
const SLOTS: = [
	[["light", "crane"], ["ribbon", "poem"], ["plain", ""], ["plain", ""]],        # 1 сосна
	[["animal", "warbler"], ["ribbon", "poem"], ["plain", ""], ["plain", ""]],     # 2 слива
	[["light", "curtain"], ["ribbon", "poem"], ["plain", ""], ["plain", ""]],      # 3 вишня
	[["animal", "cuckoo"], ["ribbon", "red"], ["plain", ""], ["plain", ""]],       # 4 глициния
	[["animal", "bridge"], ["ribbon", "red"], ["plain", ""], ["plain", ""]],       # 5 ирис
	[["animal", "butterfly"], ["ribbon", "blue"], ["plain", ""], ["plain", ""]],   # 6 пион
	[["animal", "boar"], ["ribbon", "red"], ["plain", ""], ["plain", ""]],         # 7 клевер
	[["light", "moon"], ["animal", "geese"], ["plain", ""], ["plain", ""]],        # 8 мискант
	[["animal", "cup"], ["ribbon", "blue"], ["plain", ""], ["plain", ""]],         # 9 хризантема
	[["animal", "deer"], ["ribbon", "blue"], ["plain", ""], ["plain", ""]],        # 10 клён
	[["light", "rain"], ["animal", "swallow"], ["ribbon", "red"], ["plain", "storm"]],  # 11 ива
	[["light", "phoenix"], ["plain", ""], ["plain", ""], ["plain", ""]],           # 12 павловния
]

const MONTH_NAMES: = ["Сосна", "Слива", "Вишня", "Глициния", "Ирис", "Пион", "Клевер", "Мискант", "Хризантема", "Клён", "Ива", "Павловния"]
const KIND_NAMES: = {"light": "Свет", "animal": "Животные", "ribbon": "Ленты", "plain": "Пустые"}

# Чаша (хризантема) считается и животным, и пустой (классика Nintendo); типы колоды при этом не меняются.
const CUP_IS_PLAIN: = true

# Комбинации: id → имя (простое), оригинал (мелко), базовые очки. Порядок = порядок страниц Книги.
const YAKU: = {
	"goko": {"name": "Пять светов", "orig": "Гоко", "pts": 10},
	"shiko": {"name": "Четыре света", "orig": "Сико", "pts": 8},
	"ameshiko": {"name": "Дождливые четыре", "orig": "Амэ-сико", "pts": 7},
	"sanko": {"name": "Три света", "orig": "Санко", "pts": 5},
	"inoshikacho": {"name": "Кабан, олень, бабочки", "orig": "Ино-сика-тё", "pts": 5},
	"akatan": {"name": "Красные ленты", "orig": "Акатан", "pts": 5},
	"aotan": {"name": "Синие ленты", "orig": "Аотан", "pts": 5},
	"tan": {"name": "Ленты", "orig": "Тан", "pts": 1},
	"tane": {"name": "Животные", "orig": "Танэ", "pts": 1},
	"kasu": {"name": "Пустые", "orig": "Кас", "pts": 1},
	"hanami": {"name": "Любование цветами", "orig": "Ханами", "pts": 5},
	"tsukimi": {"name": "Любование луной", "orig": "Цукими", "pts": 5},
}
const YAKU_ORDER: = ["goko", "shiko", "ameshiko", "sanko", "inoshikacho", "akatan", "aotan", "tan", "tane", "kasu", "hanami", "tsukimi"]

# ── карты ──────────────────────────────────────────────────────────────────────────────────────────

static func month(c: int) -> int:
	return c / 4

static func kind(c: int) -> String:
	return SLOTS[c / 4][c % 4][0]

static func tag(c: int) -> String:
	return SLOTS[c / 4][c % 4][1]

static func card_name(c: int) -> String:
	var t: = tag(c)
	var n: String = MONTH_NAMES[month(c)]
	match kind(c):
		"light":
			return n + " · свет"
		"animal":
			return n + " · животное"
		"ribbon":
			return n + " · лента"
	return n

static func find(tg: String) -> int:
	for c in 48:
		if tag(c) == tg:
			return c
	return -1

static func all_cards() -> Array:
	var a: = []
	for c in 48:
		a.append(c)
	return a

# Ценность карты «сама по себе» (для ИИ и для подсветки): свет > особые животные > ленты-комбо > прочее.
static func base_value(c: int) -> float:
	var t: = tag(c)
	match kind(c):
		"light":
			return 9.0 if t != "rain" else 6.0
		"animal":
			if t in ["boar", "deer", "butterfly"]:
				return 5.5
			if t == "cup":
				return 6.5
			return 3.0
		"ribbon":
			return 4.5 if t in ["poem", "blue"] else 2.5
	return 1.0

# ── комбинации ─────────────────────────────────────────────────────────────────────────────────────

# caps: Array[int] — взятки игрока. Возвращает {id: очки} (только сработавшие).
static func yaku_of(caps: Array) -> Dictionary:
	var lights: = 0
	var rain: = false
	var animals: = 0
	var ribbons: = 0
	var plains: = 0
	var poem: = 0
	var blue: = 0
	var isc: = 0
	var cup: = false
	var curtain: = false
	var moon: = false
	for c in caps:
		var k: = kind(c)
		var t: = tag(c)
		match k:
			"light":
				lights += 1
				if t == "rain":
					rain = true
				elif t == "curtain":
					curtain = true
				elif t == "moon":
					moon = true
			"animal":
				animals += 1
				if t in ["boar", "deer", "butterfly"]:
					isc += 1
				if t == "cup":
					cup = true
			"ribbon":
				ribbons += 1
				if t == "poem":
					poem += 1
				elif t == "blue":
					blue += 1
			"plain":
				plains += 1
	if cup and CUP_IS_PLAIN:
		plains += 1
	var y: = {}
	# Свет — только старшая из четырёх (конфликты Сико / Амэ-сико / Санко).
	if lights == 5:
		y["goko"] = 10
	elif lights == 4:
		y["ameshiko" if rain else "shiko"] = 7 if rain else 8
	elif lights == 3 and not rain:
		y["sanko"] = 5
	if isc == 3:
		y["inoshikacho"] = 5
	if poem == 3:
		y["akatan"] = 5
	if blue == 3:
		y["aotan"] = 5
	if ribbons >= 5:
		y["tan"] = ribbons - 4
	if animals >= 5:
		y["tane"] = animals - 4
	if plains >= 10:
		y["kasu"] = plains - 9
	if cup and curtain:
		y["hanami"] = 5
	if cup and moon:
		y["tsukimi"] = 5
	return y

static func score_of(y: Dictionary) -> int:
	var s: = 0
	for k in y:
		s += int(y[k])
	return s

# Прогресс к ближайшим комбинациям для полосы «мои взятки»: [{id, have, need}] по возрастанию остатка.
static func progress(caps: Array) -> Array:
	var have: = {"light": 0, "light_dry": 0, "isc": 0, "poem": 0, "blue": 0, "ribbon": 0, "animal": 0, "plain": 0, "cup": 0, "curtain": 0, "moon": 0}
	for c in caps:
		var k: = kind(c)
		var t: = tag(c)
		if k == "light":
			have.light += 1
			if t != "rain":
				have.light_dry += 1
		if t in ["boar", "deer", "butterfly"]:
			have.isc += 1
		if t == "poem":
			have.poem += 1
		if t == "blue":
			have.blue += 1
		if k == "ribbon":
			have.ribbon += 1
		if k == "animal":
			have.animal += 1
		if k == "plain" or (t == "cup" and CUP_IS_PLAIN):
			have.plain += 1
		if t == "cup":
			have.cup = 1
		if t == "curtain":
			have.curtain = 1
		if t == "moon":
			have.moon = 1
	var out: = [
		{"id": "sanko", "have": have.light_dry, "need": 3},
		{"id": "inoshikacho", "have": have.isc, "need": 3},
		{"id": "akatan", "have": have.poem, "need": 3},
		{"id": "aotan", "have": have.blue, "need": 3},
		{"id": "tan", "have": have.ribbon, "need": 5},
		{"id": "tane", "have": have.animal, "need": 5},
		{"id": "kasu", "have": have.plain, "need": 10},
		{"id": "hanami", "have": have.cup + have.curtain, "need": 2},
		{"id": "tsukimi", "have": have.cup + have.moon, "need": 2},
	]
	out = out.filter(func(e): return e.have < e.need)
	out.sort_custom(func(a, b): return (a.need - a.have) * 10 - a.have < (b.need - b.have) * 10 - b.have)
	return out

# ── состояние месяца ───────────────────────────────────────────────────────────────────────────────

var rng: = RandomNumberGenerator.new()
var deck: Array = []          # колода, верх = back()
var hand: Array = [[], []]
var table: Array = []
var caps: Array = [[], []]
var turn: = 0
var dealer: = 0
var koi: Array = [0, 0]       # сколько раз игрок сказал «Кои-кои!» в этом месяце
var last_score: Array = [0, 0]  # очки комбинаций на момент последнего решения
var last_yaku: Array = [{}, {}]
var phase: = "idle"           # play / pick / draw / decide / over
var pending: = -1             # карта, которая ждёт выбора цели (фаза pick)
var pending_src: = ""         # "hand" / "deck"
var pick_options: Array = []
var result: = {}              # итог месяца: {winner, pts, base, yaku, mult, intercept, koi}
var turns: = 0
var log: Array = []           # события для экрана
var stats: = {"decisions": [0, 0], "kois": [0, 0]}

# партия
var months_total: = 6
var month_no: = 0             # 1-based номер текущего месяца
var totals: Array = [0, 0]
var history: Array = []       # итоги месяцев

func setup_match(seed_v: int, months_n: int = 6, first_dealer: int = -1) -> void:
	rng.seed = seed_v
	months_total = months_n
	month_no = 0
	totals = [0, 0]
	history = []
	dealer = first_dealer if first_dealer >= 0 else rng.randi() % 2

func match_over() -> bool:
	return month_no >= months_total and phase == "over"

func next_month() -> void:
	if month_no > 0 and result.has("winner") and int(result.winner) >= 0:
		dealer = int(result.winner)
	month_no += 1
	deal()

func deal(fixed: Array = []) -> void:
	for _i in 50:
		deck = all_cards()
		if fixed.is_empty():
			_shuffle(deck)
		else:
			deck = fixed.duplicate()
		hand = [[], []]
		table = []
		caps = [[], []]
		# раздача по 2: стол / сдающий / второй, как за настоящим столом (верх колоды = back)
		for _r in 4:
			for _k in 2:
				hand[dealer].append(deck.pop_back())
			for _k in 2:
				hand[1 - dealer].append(deck.pop_back())
			for _k in 2:
				table.append(deck.pop_back())
		if not fixed.is_empty() or not _four_on_table():
			break
	koi = [0, 0]
	last_score = [0, 0]
	last_yaku = [{}, {}]
	turn = dealer
	turns = 0
	pending = -1
	pick_options = []
	result = {}
	phase = "play"
	_ev({"t": "deal", "dealer": dealer, "month": month_no})

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j: = rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _four_on_table() -> bool:
	var cnt: = {}
	for c in table:
		cnt[month(c)] = cnt.get(month(c), 0) + 1
		if cnt[month(c)] >= 4:
			return true
	return false

func matches(c: int) -> Array:
	return table.filter(func(t): return month(t) == month(c))

func _ev(e: Dictionary) -> void:
	log.append(e)

func take_events() -> Array:
	var a: = log
	log = []
	return a

# Ход: сыграть карту из руки текущего игрока. target — карта стола (нужна, когда кандидатов два).
func play(c: int, target: int = -1) -> bool:
	if phase != "play" or not hand[turn].has(c):
		return false
	hand[turn].erase(c)
	_ev({"t": "play", "p": turn, "c": c})
	if not _resolve(c, "hand", target):
		return true
	phase = "draw"
	return true

# Открыть карту из колоды (вторая половина хода).
func draw(target: int = -1) -> bool:
	if phase != "draw":
		return false
	if deck.is_empty():
		_after_turn()
		return true
	var c: int = deck.pop_back()
	_ev({"t": "reveal", "p": turn, "c": c})
	if not _resolve(c, "deck", target):
		return true
	_after_turn()
	return true

# Выбор цели, когда совпали две карты стола.
func choose(target: int) -> bool:
	if phase != "pick" or not pick_options.has(target):
		return false
	var c: = pending
	var src: = pending_src
	pending = -1
	pick_options = []
	_capture(c, [target], src)
	if src == "hand":
		phase = "draw"
	else:
		_after_turn()
	return true

# false → ждём choose()
func _resolve(c: int, src: String, target: int) -> bool:
	var ms: = matches(c)
	if ms.size() == 0:
		table.append(c)
		_ev({"t": "place", "p": turn, "c": c, "src": src})
		return true
	if ms.size() == 1 or ms.size() == 3:
		_capture(c, ms, src)
		return true
	if target >= 0 and ms.has(target):
		_capture(c, [target], src)
		return true
	pending = c
	pending_src = src
	pick_options = ms
	phase = "pick"
	_ev({"t": "pick", "p": turn, "c": c, "options": ms.duplicate(), "src": src})
	return false

func _capture(c: int, ts: Array, src: String) -> void:
	for t in ts:
		table.erase(t)
	var got: = [c] + ts
	for g in got:
		caps[turn].append(g)
	_ev({"t": "capture", "p": turn, "c": c, "cards": got, "src": src})

func _after_turn() -> void:
	turns += 1
	var y: = yaku_of(caps[turn])
	var s: = score_of(y)
	if s > int(last_score[turn]):
		var fresh: = []
		for k in YAKU_ORDER:
			if y.has(k) and int(y[k]) > int(last_yaku[turn].get(k, 0)):
				fresh.append(k)
		last_yaku[turn] = y
		_ev({"t": "yaku", "p": turn, "yaku": y, "fresh": fresh, "score": s})
		if hand[turn].is_empty():
			last_score[turn] = s
			_finish(turn, true)
			return
		phase = "decide"
		stats.decisions[turn] += 1
		return
	_end_turn()

func _end_turn() -> void:
	turn = 1 - turn
	if hand[0].is_empty() and hand[1].is_empty():
		phase = "over"
		result = {"winner": -1, "pts": 0, "base": 0, "yaku": {}, "mult": 1, "intercept": false, "koi": koi.duplicate()}
		history.append(result)
		_ev({"t": "over", "result": result})
		return
	if hand[turn].is_empty():
		# у одного кончились карты раньше (не бывает при 8/8, но держим инвариант)
		_end_turn()
		return
	phase = "play"
	_ev({"t": "turn", "p": turn})

# Решение после новой комбинации.
func koikoi() -> bool:
	if phase != "decide":
		return false
	koi[turn] += 1
	stats.kois[turn] += 1
	last_score[turn] = score_of(yaku_of(caps[turn]))
	_ev({"t": "koikoi", "p": turn, "n": koi[turn]})
	_end_turn()
	return true

func stop() -> bool:
	if phase != "decide":
		return false
	last_score[turn] = score_of(yaku_of(caps[turn]))
	_finish(turn, false)
	return true

static func payout(base: int, own_koi: int, opp_koi: int) -> Dictionary:
	var mult: = 1 << own_koi
	var intercept: = opp_koi > 0
	if intercept:
		mult *= 2
	return {"pts": base * mult, "mult": mult, "intercept": intercept}

func _finish(p: int, forced: bool) -> void:
	var y: = yaku_of(caps[p])
	var base: = score_of(y)
	var pay: = payout(base, int(koi[p]), int(koi[1 - p]))
	phase = "over"
	result = {"winner": p, "pts": pay.pts, "base": base, "yaku": y, "mult": pay.mult, "intercept": pay.intercept, "koi": koi.duplicate(), "forced": forced}
	totals[p] += pay.pts
	history.append(result)
	_ev({"t": "stop", "p": p, "result": result})
	_ev({"t": "over", "result": result})

# ── вспомогательное для ИИ и экрана ───────────────────────────────────────────────────────────────

# Карты, которых не видит игрок p: колода + рука соперницы.
func unseen_for(p: int) -> Array:
	return deck + hand[1 - p]

func seen_for(p: int) -> Dictionary:
	var d: = {}
	for c in hand[p] + table + caps[0] + caps[1]:
		d[c] = true
	return d

# Сколько ещё карт месяца m может прийти игроку p (не видны ему).
func unseen_in_month(p: int, m: int) -> int:
	var n: = 0
	for c in unseen_for(p):
		if month(c) == m:
			n += 1
	return n

func cards_left() -> int:
	return deck.size()

func clone() -> V10MjKoikoi:
	var k: = V10MjKoikoi.new()
	k.deck = deck.duplicate()
	k.hand = [hand[0].duplicate(), hand[1].duplicate()]
	k.table = table.duplicate()
	k.caps = [caps[0].duplicate(), caps[1].duplicate()]
	k.turn = turn
	k.dealer = dealer
	k.koi = koi.duplicate()
	k.last_score = last_score.duplicate()
	k.last_yaku = [last_yaku[0].duplicate(), last_yaku[1].duplicate()]
	k.phase = phase
	k.months_total = months_total
	k.month_no = month_no
	k.totals = totals.duplicate()
	return k
