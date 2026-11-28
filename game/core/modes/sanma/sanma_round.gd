class_name V10MjSanmaRound
extends V8Round

# Санма (риичи на троих) поверх V8Round. Исходник v08 не меняется: всё, где там зашито «4 места»,
# переопределено здесь; остальное (оценка руки, фуритэн, пон/кан, чанкан) работает через super.
#
# Правила (MODES.md §4.7):
#  - стена 108: без 2–8 манов (виды 1..7); красные пятёрки — только 5p и 5s;
#  - 3 места (0,1,2). Место 3 в массивах V8Round — пустой «фантом»: без руки, сброса и наборов,
#    поэтому общие циклы `for i in 4` в V8Round/V8AI его просто пропускают;
#  - чи нет;
#  - kita: Север откладывается как дора, затем добор с мёртвой стены (как после кана);
#  - каждый отложенный Север = +1 дора, и ещё +1 за каждый индикатор, который указывает на Север (Запад);
#    с риичи так же считаются ура-индикаторы;
#  - индикатор 1m → дора 9m (2–8m нет), 9m → 1m;
#  - цумо: флаг `tsumo_loss` (по умолчанию false = «без потери за отсутствующего»: доля
#    отсутствующего делится пополам между двумя плательщиками; true = «цумо-сон», плательщики
#    платят как на четверых, победитель недополучает долю отсутствующего);
#  - за ничью в темпае банк 2000; старт 35 000; формат «Восток» (3 раздачи + повторы дилера).

const SEATS: = 3
const NORTH: = 30
const START: = 35000
const NOTEN_POOL: = 2000

var kita: = [[], [], [], []]
var tsumo_loss: = false
var kita_keeps_ippatsu: = true   # отложенный Север не сбивает иппацу (≈ Tenhou, сверить)
var kita_rinshan: = true         # победа добором после кита = «Ринсян» (≈ Tenhou, сверить)
var kita_ron: = true             # на отложенный Север можно объявить «Победа · рон»
var last_replace: = ""           # "kan" | "kita" — откуда взят последний добор с мёртвой стены
var kita_tile: = -1
var kita_seat: = -1
var stats: = {"kita": 0, "kan": 0, "hands": 0, "wins": 0, "draws": 0}

signal kita_done(seat: int, tile: int, n: int)


static func is_sanma_kind(k: int) -> bool:
	return not (k >= 1 and k <= 7)

static func sanma_wall() -> Array:
	var w: = []
	for i in 136:
		if is_sanma_kind(i >> 2):
			w.append(i)
	return w


func setup(opts: Dictionary) -> void :
	var o: = opts.duplicate()
	if not o.has("start"):
		o["start"] = START
	super.setup(o)
	scores[3] = 0
	if opts.has("dealer"):
		start_dealer = int(opts.dealer) % SEATS
	else:
		start_dealer = rng.randi_range(0, SEATS - 1)
	dealer = start_dealer
	tsumo_loss = bool(opts.get("tsumo_loss", false))
	kita_keeps_ippatsu = bool(opts.get("kita_keeps_ippatsu", true))
	kita_rinshan = bool(opts.get("kita_rinshan", true))
	kita_ron = bool(opts.get("kita_ron", true))

func seat_wind(s: int) -> int:
	return 27 + (s - dealer + SEATS) % SEATS

func is_last_hand() -> bool:
	var last_wind: = 0 if length == "east" else 1
	return round_wind == last_wind and kyoku == SEATS - 1

func next_seat(s: int) -> int:
	return (s + 1) % SEATS

func others(s: int) -> Array:
	return [(s + 1) % SEATS, (s + 2) % SEATS]

func total_points() -> int:
	return scores[0] + scores[1] + scores[2] + scores[3] + sticks * 1000


func answer(a: Dictionary) -> void :
	if state == "ask" and ask.get("kind", "") == "kita_ron":
		log.append(a)
		ask_answers[a.get("seat", 0)] = a
		ask = {}
		state = "after_kita"
		return
	super.answer(a)

func advance() -> Dictionary:
	if state == "after_kita":
		return _after_kita()
	return super.advance()


func _start_hand() -> Dictionary:
	wall = sanma_wall()
	_shuffle(wall)
	var n: = wall.size()
	dead = wall.slice(n - 14, n)
	live_end = n - 14
	pos = 0
	rinshan_used = 0
	dora_ind = [dead[4]]
	ura_ind = [dead[9]]
	hands = [[], [], [], []]
	melds = [[], [], [], []]
	ponds = [[], [], [], []]
	kita = [[], [], [], []]
	riichi = [false, false, false, false]
	double_riichi = [false, false, false, false]
	ippatsu = [false, false, false, false]
	riichi_furiten = [false, false, false, false]
	temp_furiten = [false, false, false, false]
	first_go = [true, true, true, false]
	no_calls_yet = true
	kan_count = 0
	after_kan = false
	last_replace = ""
	kuikae = []
	pending_riichi = -1
	last_discard = -1
	result = {}
	for r in 3:
		for k in SEATS:
			var s: = (dealer + k) % SEATS
			for j in 4:
				hands[s].append(wall[pos])
				pos += 1
	for k in SEATS:
		var s: = (dealer + k) % SEATS
		hands[s].append(wall[pos])
		pos += 1
	for s in SEATS:
		hands[s] = V8Mj.sort_tiles(hands[s])
	turn = dealer
	state = "draw"
	hand_no += 1
	stats.hands += 1
	return {"ev": "deal", "dealer": dealer, "round": round_name(), "honba": honba, "sticks": sticks, "dora": dora_ind.duplicate(), "seats": SEATS}


func _draw() -> Dictionary:
	if after_kan:
		var t: int
		if rinshan_used < 4:
			t = dead[rinshan_used]
		else:
			t = wall[live_end - 1]
		rinshan_used += 1
		live_end -= 1
		hands[turn].append(t)
		drawn = t
		state = "turn"
		return {"ev": "draw", "seat": turn, "tile": t, "rinshan": true, "from": last_replace}
	last_replace = ""
	return super._draw()


func can_kita(s: int) -> bool:
	if drawn < 0 or wall_left() <= 0:
		return false
	if riichi[s]:
		return (drawn >> 2) == NORTH
	for t in hands[s]:
		if t >> 2 == NORTH:
			return true
	return false

func turn_options(s: int) -> Dictionary:
	var o: = super.turn_options(s)
	o["kita"] = can_kita(s)
	return o

func _turn() -> Dictionary:
	var s: = turn
	var o: = turn_options(s)
	if players[s].ctl != "ai":
		ask = {"ev": "ask", "kind": "turn", "seat": s, "opts": o, "resume": "turn"}
		state = "ask"
		return ask
	var a: Dictionary = V10MjSanmaAI.turn(self, s, o)
	return _apply_turn(s, a)

func _apply_turn(s: int, a: Dictionary) -> Dictionary:
	if a.get("a", "") == "kita":
		if can_kita(s):
			return _kita(s)
		a = {"a": "discard", "t": drawn}
	var res: = super._apply_turn(s, a)
	if state == "after_discard":
		call_queue = others(s)
	return res

func _kan_self(s: int, act: String, k: int) -> Dictionary:
	var res: = super._kan_self(s, act, k)
	stats.kan += 1
	last_replace = "kan"
	if state == "after_kakan":
		call_queue = others(s)
	return res


func _kita(s: int) -> Dictionary:
	var t: = -1
	if drawn >= 0 and (drawn >> 2) == NORTH:
		t = drawn
	else:
		for x in hands[s]:
			if x >> 2 == NORTH:
				t = x
				break
	hands[s].erase(t)
	hands[s] = V8Mj.sort_tiles(hands[s])
	kita[s].append(t)
	stats.kita += 1
	if not kita_keeps_ippatsu:
		for i in 4:
			ippatsu[i] = false
	drawn = -1
	last_replace = "kita"
	kita_tile = t
	kita_seat = s
	ask_answers = {}
	call_queue = others(s) if kita_ron else []
	state = "after_kita"
	kita_done.emit(s, t, kita[s].size())
	return {"ev": "kita", "seat": s, "tile": t, "n": kita[s].size(), "dora_from_kita": kita_dora_each()}

func _after_kita() -> Dictionary:
	while not call_queue.is_empty():
		var o: int = call_queue[0]
		if ask_answers.has(o):
			call_queue.pop_front()
			continue
		var ev: = win_eval(o, kita_tile, false)
		var can: bool = not ev.is_empty() and (ev.han > 0 or ev.yakuman > 0) and not is_furiten(o)
		if not can:
			ask_answers[o] = {"a": "pass", "seat": o}
			continue
		if players[o].ctl != "ai":
			ask = {"ev": "ask", "kind": "kita_ron", "seat": o, "tile": kita_tile, "from": kita_seat, "opts": {"ron": true, "ron_eval": ev}, "resume": "after_kita"}
			state = "ask"
			return ask
		ask_answers[o] = {"a": "ron", "seat": o}
	for o2 in others(kita_seat):
		if ask_answers.get(o2, {}).get("a", "") == "ron":
			var ev2: = win_eval(o2, kita_tile, false)
			if not ev2.is_empty() and (ev2.han > 0 or ev2.yakuman > 0):
				return _win(o2, kita_seat, kita_tile, ev2)
	for o3 in others(kita_seat):
		if ask_answers.get(o3, {}).get("a", "pass") != "ron" and not win_eval(o3, kita_tile, false).is_empty():
			temp_furiten[o3] = true
			if riichi[o3]:
				riichi_furiten[o3] = true
	turn = kita_seat
	after_kan = true
	state = "draw"
	return {"ev": "noop"}


func call_options(o: int) -> Dictionary:
	var res: = super.call_options(o)
	res.chi = []
	return res

func _after_discard() -> Dictionary:
	while not call_queue.is_empty():
		var o: int = call_queue[0]
		if ask_answers.has(o):
			call_queue.pop_front()
			continue
		var opts: = call_options(o)
		var any: bool = opts.ron or opts.pon or opts.kan
		if not any:
			ask_answers[o] = {"a": "pass", "seat": o}
			continue
		if players[o].ctl != "ai":
			ask = {"ev": "ask", "kind": "call", "seat": o, "tile": last_discard, "from": last_from, "opts": opts, "resume": "after_discard"}
			state = "ask"
			return ask
		var a: Dictionary = V10MjSanmaAI.decide_call(self, o, opts)
		a["seat"] = o
		ask_answers[o] = a
	return _resolve_calls()

func _resolve_calls() -> Dictionary:
	var t: = last_discard
	var s: = last_from
	for o in others(s):
		var a: Dictionary = ask_answers.get(o, {})
		if a.get("a", "") == "ron" and call_options(o).ron:
			var ev: = win_eval(o, t, false, {"houtei": wall_left() <= 0})
			return _win(o, s, t, ev)
	for o2 in others(s):
		if ask_answers.get(o2, {}).get("a", "pass") != "ron":
			if not win_eval(o2, t, false).is_empty():
				temp_furiten[o2] = true
				if riichi[o2]:
					riichi_furiten[o2] = true
	var evs: = []
	if pending_riichi == s:
		scores[s] -= 1000
		sticks += 1
		ippatsu[s] = true
		pending_riichi = -1
		evs.append({"ev": "riichi_stick", "seat": s})
	for o3 in others(s):
		var a3: Dictionary = ask_answers.get(o3, {})
		if a3.get("a", "") in ["pon", "kan"]:
			var co: = call_options(o3)
			if (a3.a == "pon" and co.pon) or (a3.a == "kan" and co.kan):
				var r: = _do_call(o3, a3.a, [])
				if a3.a == "kan":
					stats.kan += 1
					last_replace = "kan"
				return r
	turn = next_seat(s)
	state = "draw"
	if not evs.is_empty():
		return evs[0]
	return {"ev": "noop"}


# Индикаторы для V8Mj.evaluate: 1m показывает 9m (подменяем на индикатор 8m — у него дора 9m).
static func map_ind(ind: Array) -> Array:
	var out: = []
	for t in ind:
		out.append(28 if (int(t) >> 2) == 0 else int(t))
	return out

static func dora_of_sanma(k: int) -> int:
	if k == 0:
		return 8
	return V8Mj.dora_of(k)

func dora_kinds() -> Array:
	var out: = []
	for d in dora_ind:
		out.append(dora_of_sanma(d >> 2))
	return out

# Сколько дор даёт каждый отложенный Север сейчас (1 + индикаторы, указывающие на Север).
func kita_dora_each(with_ura: = false) -> int:
	var n: = 1
	for d in dora_ind:
		if dora_of_sanma(d >> 2) == NORTH:
			n += 1
	if with_ura:
		for i in mini(ura_ind.size(), dora_ind.size()):
			if dora_of_sanma(ura_ind[i] >> 2) == NORTH:
				n += 1
	return n

func win_eval(s: int, t: int, tsumo: bool, extra: = {}) -> Dictionary:
	var closed: Array = hands[s].duplicate()
	if not tsumo:
		closed.append(t)
	if closed.size() % 3 != 2:
		return {}
	var rinshan: bool = tsumo and after_kan and (kita_rinshan or last_replace != "kita")
	var ctx: = {
		"tsumo": tsumo, "riichi": riichi[s], "double_riichi": double_riichi[s], "ippatsu": ippatsu[s],
		"haitei": tsumo and wall_left() <= 0 and not after_kan, "houtei": extra.get("houtei", false),
		"rinshan": rinshan, "chankan": extra.get("chankan", false),
		"tenhou": tsumo and first_go[s] and no_calls_yet and s == dealer and kita[s].is_empty(),
		"chiihou": tsumo and first_go[s] and no_calls_yet and s != dealer and kita[s].is_empty(),
		"seat_wind": seat_wind(s), "round_wind": round_wind_kind(), "dora_ind": map_ind(dora_ind),
		"ura_ind": map_ind(ura_ind.slice(0, dora_ind.size())), "dealer": s == dealer,
	}
	var ev: = V8Mj.evaluate(closed, melds[s], t, ctx)
	return apply_kita(ev, s)

# Добавляет дору за отложенные северы. Комбинацию (хан от яку) северы не создают.
func apply_kita(ev: Dictionary, s: int) -> Dictionary:
	if ev.is_empty():
		return ev
	var n: int = kita[s].size()
	ev["kita"] = n
	ev["kita_han"] = 0
	if n == 0 or int(ev.get("yakuman", 0)) > 0 or int(ev.get("han", 0)) <= 0:
		return ev
	var add: int = n * kita_dora_each(riichi[s])
	ev.kita_han = add
	ev.han = int(ev.han) + add
	var b: = V8Mj.base_points(int(ev.han), int(ev.fu), 0)
	ev.base = b
	ev.pts = b * 4 + int(ev.han)
	ev.limit = V8Mj.limit_name(int(ev.han), int(ev.fu), 0)
	return ev


# Платежи на троих. Возвращает массив дельт (4 элемента, место 3 = 0).
func pay_delta(w: int, from: int, base: int) -> Array:
	var delta: = [0, 0, 0, 0]
	var is_dealer: = w == dealer
	if from >= 0:
		var amt: int = V8Mj.ceil100(float(base) * (6.0 if is_dealer else 4.0)) + 300 * honba
		delta[from] -= amt
		delta[w] += amt
		return delta
	for i in others(w):
		var p: int
		if is_dealer:
			p = V8Mj.ceil100(float(base) * (2.0 if tsumo_loss else 3.0))
		elif i == dealer:
			p = V8Mj.ceil100(float(base) * (2.0 if tsumo_loss else 2.5))
		else:
			p = V8Mj.ceil100(float(base) * (1.0 if tsumo_loss else 1.5))
		p += 100 * honba
		delta[i] -= p
		delta[w] += p
	return delta

func _win(w: int, from: int, t: int, ev: Dictionary) -> Dictionary:
	var delta: = pay_delta(w, from, int(ev.base))
	if pending_riichi >= 0 and pending_riichi != w and from == pending_riichi:
		pending_riichi = -1
	delta[w] += sticks * 1000
	var got_sticks: = sticks
	sticks = 0
	for i in 4:
		scores[i] += delta[i]
	stats.wins += 1
	var closed: Array = hands[w].duplicate()
	result = {"ev": "win", "seat": w, "from": from, "tile": t, "eval": ev, "delta": delta, "tsumo": from < 0,
		"hand": V8Mj.sort_tiles(closed), "melds": melds[w].duplicate(true), "dora": dora_ind.duplicate(),
		"ura": ura_ind.slice(0, dora_ind.size()) if riichi[w] else [], "sticks": got_sticks, "honba": honba,
		"scores": scores.duplicate(), "kita": kita[w].duplicate(), "kan_count": kan_count, "renchan": w == dealer}
	_rotate(w == dealer)
	return result

func _exhaustive() -> Dictionary:
	var ten: = []
	for s in SEATS:
		var c: = V8Mj.counts(hands[s])
		if V8Mj.shanten(c, melds[s].size()) == 0 and not V8Mj.waits(c, melds[s].size()).is_empty():
			ten.append(s)
	var delta: = [0, 0, 0, 0]
	if ten.size() > 0 and ten.size() < SEATS:
		var get: int = NOTEN_POOL / ten.size()
		var pay: int = NOTEN_POOL / (SEATS - ten.size())
		for s in SEATS:
			delta[s] = get if s in ten else - pay
	for i in 4:
		scores[i] += delta[i]
	stats.draws += 1
	result = {"ev": "draw_end", "tenpai": ten, "delta": delta, "scores": scores.duplicate(), "hands": hands.duplicate(true), "kan_count": kan_count}
	honba += 1
	_rotate(dealer in ten, true)
	return result

func _rotate(dealer_keeps: bool, was_draw: = false) -> void :
	if dealer_keeps:
		if not was_draw:
			honba += 1
	else:
		if not was_draw:
			honba = 0
		dealer = (dealer + 1) % SEATS
		kyoku += 1
		if kyoku >= SEATS:
			kyoku = 0
			round_wind += 1
	state = "next_hand"

func _next_hand() -> Dictionary:
	var over: = false
	for s in SEATS:
		if scores[s] < 0:
			over = true
	var last_wind: = 0 if length == "east" else 1
	if round_wind > last_wind:
		over = true
	# «Агари-ямэ»: дилер выиграл последнюю раздачу (остался дилером) и он первый. В V8Round проверка шла по дилеру
	# ПОСЛЕ смены, поэтому партия кончалась, когда победитель предпоследней раздачи становился дилером последней.
	if round_wind == last_wind and kyoku == SEATS - 1 and hand_no > 1 and result.get("ev", "") == "win" and bool(result.get("renchan", false)):
		var top: = true
		for i in SEATS:
			if i != dealer and scores[i] >= scores[dealer]:
				top = false
		if top:
			over = true
	if over:
		state = "end"
		match_over = true
		var ord: = placements()
		scores[ord[0]] += sticks * 1000
		sticks = 0
		return {"ev": "match_end", "result": final_result()}
	state = "start_hand"
	return {"ev": "noop"}

func placements() -> Array:
	var ord: = [0, 1, 2]
	ord.sort_custom( func(a, b):
		if scores[a] != scores[b]:
			return scores[a] > scores[b]
		return (a - start_dealer + SEATS) % SEATS < (b - start_dealer + SEATS) % SEATS)
	return ord

func final_result() -> Dictionary:
	var ord: = placements()
	var place: = [0, 0, 0]
	for i in SEATS:
		place[ord[i]] = i + 1
	return {"order": ord, "place": place, "scores": scores.slice(0, SEATS), "seed": seed, "log_size": log.size(), "seats": SEATS}

func visible(s: int) -> Array:
	var c: = super.visible(s)
	for i in SEATS:
		for t in kita[i]:
			c[t >> 2] += 1
	return c
