class_name V8Round
extends RefCounted





var seed: = 0
var rng: = RandomNumberGenerator.new()
var length: = "east"
var players: = []
var scores: = [25000, 25000, 25000, 25000]
var start_dealer: = 0
var dealer: = 0
var round_wind: = 0
var kyoku: = 0
var honba: = 0
var sticks: = 0
var hand_no: = 0
var log: = []


var wall: = []
var live_end: = 0
var pos: = 0
var dead: = []
var rinshan_used: = 0
var dora_ind: = []
var ura_ind: = []
var hands: = [[], [], [], []]
var melds: = [[], [], [], []]
var ponds: = [[], [], [], []]
var riichi: = [false, false, false, false]
var double_riichi: = [false, false, false, false]
var ippatsu: = [false, false, false, false]
var riichi_furiten: = [false, false, false, false]
var temp_furiten: = [false, false, false, false]
var first_go: = [true, true, true, true]
var no_calls_yet: = true
var turn: = 0
var drawn: = -1
var after_kan: = false
var kan_count: = 0
var kuikae: = []
var pending_riichi: = -1
var last_discard: = -1
var last_from: = -1
var state: = "idle"
var ask: = {}
var ask_answers: = {}
var call_queue: = []
var chankan_tile: = -1
var chankan_seat: = -1
var result: = {}
var match_over: = false
var _pending: = {}

signal said(seat: int, what: String)

func setup(opts: Dictionary) -> void :
	seed = int(opts.get("seed", randi()))
	rng.seed = seed
	length = opts.get("length", "east")
	players = opts.get("players", [])
	var s0: int = int(opts.get("start", 25000))
	scores = [s0, s0, s0, s0]
	start_dealer = int(opts.get("dealer", rng.randi_range(0, 3)))
	dealer = start_dealer
	round_wind = 0
	kyoku = 0
	honba = 0
	sticks = 0
	hand_no = 0
	match_over = false
	state = "start_hand"

func seat_wind(s: int) -> int:
	return 27 + (s - dealer + 4) % 4

func round_wind_kind() -> int:
	return 27 + round_wind

func wall_left() -> int:
	return live_end - pos

func round_name() -> String:
	return "%s %d" % [V8Mj.WIND_RU[round_wind], kyoku + 1]

func is_last_hand() -> bool:
	var last_wind: = 0 if length == "east" else 1
	return round_wind == last_wind and kyoku == 3


func advance() -> Dictionary:
	match state:
		"start_hand":
			return _start_hand()
		"draw":
			return _draw()
		"turn":
			return _turn()
		"after_discard":
			return _after_discard()
		"after_kakan":
			return _after_kakan()
		"next_hand":
			return _next_hand()
		"ask":
			return ask
		"apply_turn":
			return _apply_turn(turn, _pending)
		"end":
			return {"ev": "match_end", "result": final_result()}
	return {"ev": "idle"}

func answer(a: Dictionary) -> void :
	if state != "ask":
		return
	log.append(a)
	var kind: String = ask.get("kind", "")
	state = ask.get("resume", "draw")
	ask = {}
	if kind == "turn":
		_pending = a
		state = "apply_turn"
	elif kind == "call":
		ask_answers[a.get("seat", 0)] = a
		state = "after_discard"
	elif kind == "chankan":
		ask_answers[a.get("seat", 0)] = a
		state = "after_kakan"


func _start_hand() -> Dictionary:
	wall = []
	for i in 136:
		wall.append(i)
	_shuffle(wall)
	dead = wall.slice(122, 136)
	live_end = 122
	pos = 0
	rinshan_used = 0
	dora_ind = [dead[4]]
	ura_ind = [dead[9]]
	hands = [[], [], [], []]
	melds = [[], [], [], []]
	ponds = [[], [], [], []]
	riichi = [false, false, false, false]
	double_riichi = [false, false, false, false]
	ippatsu = [false, false, false, false]
	riichi_furiten = [false, false, false, false]
	temp_furiten = [false, false, false, false]
	first_go = [true, true, true, true]
	no_calls_yet = true
	kan_count = 0
	after_kan = false
	kuikae = []
	pending_riichi = -1
	last_discard = -1
	result = {}
	for r in 3:
		for k in 4:
			var s: = (dealer + k) % 4
			for j in 4:
				hands[s].append(wall[pos])
				pos += 1
	for k in 4:
		var s: = (dealer + k) % 4
		hands[s].append(wall[pos])
		pos += 1
	for s in 4:
		hands[s] = V8Mj.sort_tiles(hands[s])
	turn = dealer
	state = "draw"
	hand_no += 1
	return {"ev": "deal", "dealer": dealer, "round": round_name(), "honba": honba, "sticks": sticks, "dora": dora_ind.duplicate()}


var forced_wall: = []

func _shuffle(a: Array) -> void :
	if not forced_wall.is_empty():
		a.assign(forced_wall)
		forced_wall = []
		return
	for i in range(a.size() - 1, 0, -1):
		var j: = rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _draw() -> Dictionary:
	if after_kan:
		var t: int = dead[rinshan_used]
		rinshan_used += 1
		live_end -= 1
		hands[turn].append(t)
		drawn = t
		state = "turn"
		return {"ev": "draw", "seat": turn, "tile": t, "rinshan": true}
	if wall_left() <= 0:
		return _exhaustive()
	var t2: int = wall[pos]
	pos += 1
	hands[turn].append(t2)
	drawn = t2
	state = "turn"
	return {"ev": "draw", "seat": turn, "tile": t2, "rinshan": false}


func turn_options(s: int) -> Dictionary:
	var o: = {"tsumo": false, "riichi": [], "kans": [], "forbidden": kuikae.duplicate(), "drawn": drawn, "in_riichi": riichi[s]}
	var c: = V8Mj.counts(hands[s])
	var nm: int = melds[s].size()
	if drawn >= 0:
		var ev: = win_eval(s, drawn, true)
		if not ev.is_empty() and (ev.han > 0 or ev.yakuman > 0):
			o.tsumo = true
			o.tsumo_eval = ev

		if wall_left() > 0 and kan_count < 4:
			for k in 34:
				if c[k] == 4:
					if not riichi[s] or _riichi_kan_ok(s, k):
						o.kans.append({"a": "ankan", "k": k})
			if not riichi[s]:
				for md in melds[s]:
					if md.type == "pon" and c[md.tiles[0] >> 2] >= 1:
						o.kans.append({"a": "kakan", "k": md.tiles[0] >> 2})

		if not riichi[s] and _closed(s) and scores[s] >= 1000 and wall_left() >= 4:
			var seen: = {}
			for t in hands[s]:
				var k: int = t >> 2
				if seen.has(k):
					continue
				seen[k] = true
				c[k] -= 1
				if V8Mj.shanten(c, 0) == 0:
					o.riichi.append(t)
				c[k] += 1
	return o

func _closed(s: int) -> bool:
	for md in melds[s]:
		if md.type != "ankan":
			return false
	return true

func _riichi_kan_ok(s: int, k: int) -> bool:
	if (drawn >> 2) != k:
		return false
	var c: = V8Mj.counts(hands[s])
	c[k] -= 1
	var w0: = V8Mj.waits(c, melds[s].size())
	c[k] -= 3
	var w1: = V8Mj.waits(c, melds[s].size() + 1)
	return w0 == w1 and not w0.is_empty()

func _turn() -> Dictionary:
	var s: = turn
	var o: = turn_options(s)
	if players[s].ctl != "ai":
		ask = {"ev": "ask", "kind": "turn", "seat": s, "opts": o, "resume": "turn"}
		state = "ask"
		return ask
	var a: Dictionary = V8AI.turn(self, s, o)
	return _apply_turn(s, a)

func _apply_turn(s: int, a: Dictionary) -> Dictionary:
	var act: String = a.get("a", "discard")
	if act == "tsumo":
		var ev: = win_eval(s, drawn, true)
		if not ev.is_empty() and (ev.han > 0 or ev.yakuman > 0):
			return _win(s, -1, drawn, ev)
		act = "discard"
		a = {"a": "discard", "t": drawn}
	if act == "ankan" or act == "kakan":
		return _kan_self(s, act, int(a.k))

	var t: int = int(a.get("t", drawn))
	if not t in hands[s]:
		t = drawn if drawn in hands[s] else hands[s][hands[s].size() - 1]
	if riichi[s] and drawn >= 0 and t != drawn:
		t = drawn
	hands[s].erase(t)
	hands[s] = V8Mj.sort_tiles(hands[s])
	var declare: bool = a.get("riichi", false) and not riichi[s] and _closed(s) and scores[s] >= 1000 and wall_left() >= 4
	if declare:
		var c: = V8Mj.counts(hands[s])
		if V8Mj.shanten(c, 0) != 0:
			declare = false
	var tg: = t == drawn
	ponds[s].append({"t": t, "riichi": declare, "called": false, "tsumogiri": tg})
	if ippatsu[s] and not declare:
		ippatsu[s] = false
	if declare:
		riichi[s] = true
		double_riichi[s] = first_go[s] and no_calls_yet
		pending_riichi = s
	first_go[s] = false
	temp_furiten[s] = false
	drawn = -1
	after_kan = false
	kuikae = []
	last_discard = t
	last_from = s
	ask_answers = {}
	call_queue = []
	for k in range(1, 4):
		call_queue.append((s + k) % 4)
	state = "after_discard"
	return {"ev": "discard", "seat": s, "tile": t, "riichi": declare, "tsumogiri": tg}

func _kan_self(s: int, act: String, k: int) -> Dictionary:
	var tiles: = []
	if act == "ankan":
		for t in hands[s].duplicate():
			if t >> 2 == k:
				hands[s].erase(t)
				tiles.append(t)
		melds[s].append({"type": "ankan", "tiles": tiles, "from": s, "called": -1})
	else:
		var add: = -1
		for t in hands[s]:
			if t >> 2 == k:
				add = t
				break
		hands[s].erase(add)
		for md in melds[s]:
			if md.type == "pon" and md.tiles[0] >> 2 == k:
				md.type = "kakan"
				md.tiles.append(add)
				tiles = md.tiles

		chankan_tile = add
		chankan_seat = s
	kan_count += 1
	for i in 4:
		ippatsu[i] = false
	no_calls_yet = false
	drawn = -1
	_new_dora()
	if act == "kakan":
		ask_answers = {}
		call_queue = []
		for j in range(1, 4):
			call_queue.append((s + j) % 4)
		state = "after_kakan"
	else:
		after_kan = true
		state = "draw"
	return {"ev": "call", "seat": s, "type": act, "tiles": tiles, "from": s, "dora": dora_ind.duplicate()}

func _new_dora() -> void :
	var n: = dora_ind.size()
	if n < 5:
		dora_ind.append(dead[4 + n])
		ura_ind.append(dead[9 + n])

func _after_kakan() -> Dictionary:

	while not call_queue.is_empty():
		var o: int = call_queue[0]
		if ask_answers.has(o):
			call_queue.pop_front()
			continue
		var ev: = win_eval(o, chankan_tile, false, {"chankan": true})
		var can: bool = not ev.is_empty() and (ev.han > 0 or ev.yakuman > 0) and not is_furiten(o)
		if not can:
			ask_answers[o] = {"a": "pass", "seat": o}
			continue
		if players[o].ctl != "ai":
			ask = {"ev": "ask", "kind": "chankan", "seat": o, "tile": chankan_tile, "from": chankan_seat, "opts": {"ron": true}, "resume": "after_kakan"}
			state = "ask"
			return ask
		ask_answers[o] = {"a": "ron", "seat": o}
	for j in range(1, 4):
		var o2: = (chankan_seat + j) % 4
		if ask_answers.get(o2, {}).get("a", "") == "ron":
			var ev2: = win_eval(o2, chankan_tile, false, {"chankan": true})
			return _win(o2, chankan_seat, chankan_tile, ev2)
	turn = chankan_seat
	after_kan = true
	state = "draw"
	return {"ev": "noop"}


func call_options(o: int) -> Dictionary:
	var t: = last_discard
	var k: = t >> 2
	var res: = {"ron": false, "pon": false, "kan": false, "chi": []}
	var ev: = win_eval(o, t, false)
	if not ev.is_empty() and (ev.han > 0 or ev.yakuman > 0) and not is_furiten(o):
		res.ron = true
		res.ron_eval = ev
	elif not ev.is_empty():
		res.no_yaku_win = true
	if riichi[o] or wall_left() <= 0:
		return res
	var c: = V8Mj.counts(hands[o])
	if c[k] >= 2:
		res.pon = true
	if c[k] >= 3 and kan_count < 4:
		res.kan = true
	if o == (last_from + 1) % 4 and k < 27:
		var n: = k % 9
		var opts: = []
		if n >= 2 and c[k - 2] > 0 and c[k - 1] > 0:
			opts.append([k - 2, k - 1])
		if n >= 1 and n <= 7 and c[k - 1] > 0 and c[k + 1] > 0:
			opts.append([k - 1, k + 1])
		if n <= 6 and c[k + 1] > 0 and c[k + 2] > 0:
			opts.append([k + 1, k + 2])
		for op in opts:

			res.chi.append(_pick(o, op))
	return res

func _pick(o: int, ks: Array) -> Array:
	var out: = []
	for k in ks:
		for t in hands[o]:
			if t >> 2 == k and not t in out:
				out.append(t)
				break
	return out

func _after_discard() -> Dictionary:
	while not call_queue.is_empty():
		var o: int = call_queue[0]
		if ask_answers.has(o):
			call_queue.pop_front()
			continue
		var opts: = call_options(o)
		var any: bool = opts.ron or opts.pon or opts.kan or not opts.chi.is_empty()
		if not any:
			ask_answers[o] = {"a": "pass", "seat": o}
			continue
		if players[o].ctl != "ai":
			ask = {"ev": "ask", "kind": "call", "seat": o, "tile": last_discard, "from": last_from, "opts": opts, "resume": "after_discard"}
			state = "ask"
			return ask
		var a: Dictionary = V8AI.decide_call(self, o, opts)
		a["seat"] = o
		ask_answers[o] = a
	return _resolve_calls()

func _resolve_calls() -> Dictionary:
	var t: = last_discard
	var s: = last_from

	for j in range(1, 4):
		var o: = (s + j) % 4
		var a: Dictionary = ask_answers.get(o, {})
		var co: = call_options(o)
		if a.get("a", "") == "ron" and co.ron:
			var houtei: = wall_left() <= 0
			var ev: = win_eval(o, t, false, {"houtei": houtei})
			return _win(o, s, t, ev)

	for j in range(1, 4):
		var o2: = (s + j) % 4
		if ask_answers.get(o2, {}).get("a", "pass") != "ron":
			var ev2: = win_eval(o2, t, false)
			if not ev2.is_empty():
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

	for j in range(1, 4):
		var o3: = (s + j) % 4
		var a3: Dictionary = ask_answers.get(o3, {})
		if a3.get("a", "") in ["pon", "kan"]:
			return _do_call(o3, a3.a, [])
	var nx: = (s + 1) % 4
	var a4: Dictionary = ask_answers.get(nx, {})
	if a4.get("a", "") == "chi":
		return _do_call(nx, "chi", a4.get("use", []))
	turn = nx
	state = "draw"
	if not evs.is_empty():
		return evs[0]
	return {"ev": "noop"}

func _do_call(o: int, kind: String, use: Array) -> Dictionary:
	var t: = last_discard
	var k: = t >> 2
	var tiles: = [t]
	if kind == "chi":
		if use.size() != 2 or not (use[0] in hands[o] and use[1] in hands[o]):
			var co: = call_options(o)
			use = co.chi[0] if not co.chi.is_empty() else []
		for u in use:
			hands[o].erase(u)
			tiles.append(u)
	else:
		var need: = 2 if kind == "pon" else 3

		var mine: = []
		for x in hands[o]:
			if x >> 2 == k:
				mine.append(x)
		mine.sort_custom( func(a, b): return V8Mj.is_aka(a) and not V8Mj.is_aka(b))
		for i in need:
			hands[o].erase(mine[i])
			tiles.append(mine[i])
	ponds[last_from][ponds[last_from].size() - 1].called = true
	var mtype: = kind if kind != "kan" else "minkan"
	melds[o].append({"type": mtype, "tiles": tiles, "from": last_from, "called": t})
	for i in 4:
		ippatsu[i] = false
	no_calls_yet = false
	first_go = [false, false, false, false]
	turn = o
	drawn = -1
	kuikae = [k]
	if kind == "chi":
		var ks: = [use[0] >> 2, use[1] >> 2]
		ks.sort()

		if k < ks[0] and ks[1] %9 < 8:
			kuikae.append(ks[1] + 1)
		elif k > ks[1] and ks[0] %9 > 0:
			kuikae.append(ks[0] - 1)
	if kind == "kan":
		kan_count += 1
		kuikae = []
		after_kan = true
		_new_dora()
		state = "draw"
	else:
		state = "turn"
	return {"ev": "call", "seat": o, "type": mtype, "tiles": tiles, "from": last_from, "tile": t, "dora": dora_ind.duplicate()}


func is_furiten(s: int) -> bool:
	if temp_furiten[s] or riichi_furiten[s]:
		return true
	var c: = V8Mj.counts(hands[s])
	if hands[s].size() % 3 != 1:
		return false
	var w: = V8Mj.waits(c, melds[s].size())
	for p in ponds[s]:
		if (p.t >> 2) in w:
			return true
	return false

func win_eval(s: int, t: int, tsumo: bool, extra: = {}) -> Dictionary:
	var closed: Array = hands[s].duplicate()
	if not tsumo:
		closed.append(t)
	if closed.size() % 3 != 2:
		return {}
	var ctx: = {
		"tsumo": tsumo, "riichi": riichi[s], "double_riichi": double_riichi[s], "ippatsu": ippatsu[s], 
		"haitei": tsumo and wall_left() <= 0 and not after_kan, "houtei": extra.get("houtei", false), 
		"rinshan": tsumo and after_kan, "chankan": extra.get("chankan", false), 
		"tenhou": tsumo and first_go[s] and no_calls_yet and s == dealer, 
		"chiihou": tsumo and first_go[s] and no_calls_yet and s != dealer, 
		"seat_wind": seat_wind(s), "round_wind": round_wind_kind(), "dora_ind": dora_ind, "ura_ind": ura_ind, "dealer": s == dealer, 
	}
	return V8Mj.evaluate(closed, melds[s], t, ctx)

func _win(w: int, from: int, t: int, ev: Dictionary) -> Dictionary:
	var pay: = V8Mj.payments(int(ev.base), w == dealer)
	var delta: = [0, 0, 0, 0]
	if from >= 0:
		var amt: int = pay.ron + 300 * honba
		delta[from] -= amt
		delta[w] += amt
	else:
		for i in 4:
			if i == w:
				continue
			var p: int
			if w == dealer:
				p = pay.all
			else:
				p = pay.dealer if i == dealer else pay.other
			p += 100 * honba
			delta[i] -= p
			delta[w] += p
	if pending_riichi >= 0 and pending_riichi != w and from == pending_riichi:
		pending_riichi = -1
	delta[w] += sticks * 1000
	var got_sticks: = sticks
	sticks = 0
	for i in 4:
		scores[i] += delta[i]
	var closed: Array = hands[w].duplicate()
	result = {"ev": "win", "seat": w, "from": from, "tile": t, "eval": ev, "delta": delta, "tsumo": from < 0, 
		"hand": V8Mj.sort_tiles(closed), "melds": melds[w].duplicate(true), "dora": dora_ind.duplicate(), 
		"ura": ura_ind.slice(0, dora_ind.size()) if riichi[w] else [], "sticks": got_sticks, "honba": honba, "scores": scores.duplicate()}
	_rotate(w == dealer)
	return result

func _exhaustive() -> Dictionary:
	var ten: = []
	for s in 4:
		var c: = V8Mj.counts(hands[s])
		if V8Mj.shanten(c, melds[s].size()) == 0 and not V8Mj.waits(c, melds[s].size()).is_empty():
			ten.append(s)
	var delta: = [0, 0, 0, 0]
	if ten.size() > 0 and ten.size() < 4:
		var get: = 3000 / ten.size()
		var pay: = 3000 / (4 - ten.size())
		for s in 4:
			delta[s] = get if s in ten else - pay
	for i in 4:
		scores[i] += delta[i]
	result = {"ev": "draw_end", "tenpai": ten, "delta": delta, "scores": scores.duplicate(), "hands": hands.duplicate(true)}
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
		dealer = (dealer + 1) % 4
		kyoku += 1
		if kyoku >= 4:
			kyoku = 0
			round_wind += 1
	state = "next_hand"

func _next_hand() -> Dictionary:
	var over: = false
	for s in scores:
		if s < 0:
			over = true
	var last_wind: = 0 if length == "east" else 1
	if round_wind > last_wind:
		over = true

	if round_wind == last_wind and kyoku == 3 and hand_no > 1 and result.get("ev", "") == "win" and result.seat == dealer:
		var top: = true
		for i in 4:
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
	var ord: = [0, 1, 2, 3]
	ord.sort_custom( func(a, b):
		if scores[a] != scores[b]:
			return scores[a] > scores[b]
		return (a - start_dealer + 4) % 4 < (b - start_dealer + 4) % 4)
	return ord

func final_result() -> Dictionary:
	var ord: = placements()
	var place: = [0, 0, 0, 0]
	for i in 4:
		place[ord[i]] = i + 1
	return {"order": ord, "place": place, "scores": scores.duplicate(), "seed": seed, "log_size": log.size()}



func visible(s: int) -> Array:
	var c: = V8Mj.counts(hands[s])
	for i in 4:
		for p in ponds[i]:
			if not p.called:
				c[p.t >> 2] += 1
		for md in melds[i]:
			for t in md.tiles:
				c[t >> 2] += 1
	for d in dora_ind:
		c[d >> 2] += 1
	return c

func dora_kinds() -> Array:
	var out: = []
	for d in dora_ind:
		out.append(V8Mj.dora_of(d >> 2))
	return out
