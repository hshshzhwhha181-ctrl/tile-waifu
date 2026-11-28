class_name V10MjKoikoiAI
extends RefCounted

# ИИ соперниц Коикои. Видит только то, что видит игрок за столом: свою руку, стол, все взятки, число карт.
# Стили (MODES §4.8):
#   rin  «Чайная церемония» — берёт рано: «Кои-кои!» редко (≤ 30% решений), бережёт стол;
#   hana «Эстафета»         — почти всегда «Кои-кои!» (≥ 80%), гонится за дорогими картами;
#   yue  «Лунная тень»      — копит свет, тянет месяц, пока свет ещё в игре;
#   nova «Оверклок»         — считает оставшиеся карты: вероятность ответа соперницы и шанс улучшить руку;
#   mc   «Учебник»          — ровная учебная игра с редкими ошибками, чтобы новичок мог выиграть.

const STYLES: = {
	"rin": {"name": "Рин", "light": 1.0, "combo": 1.0, "defense": 1.0, "take": 1.6, "noise": 0.4, "slip": 0.0},
	"hana": {"name": "Хана", "light": 1.2, "combo": 1.2, "defense": 0.35, "take": 0.6, "noise": 0.8, "slip": 0.0},
	"yue": {"name": "Юэ", "light": 3.2, "combo": 0.8, "defense": 0.8, "take": 0.4, "noise": 0.3, "slip": 0.0, "hold_light": 4.0},
	"nova": {"name": "Нова", "light": 1.1, "combo": 1.1, "defense": 1.4, "take": 0.8, "noise": 0.05, "slip": 0.0},
	"mc": {"name": "Маджонг-тян", "light": 1.0, "combo": 0.9, "defense": 0.6, "take": 1.0, "noise": 1.2, "slip": 0.12},
}

static func style_of(id: String) -> Dictionary:
	return STYLES.get(id, STYLES.mc)

# ── выбор хода ─────────────────────────────────────────────────────────────────────────────────────

# → {card, target}; target = -1, если выбор цели не нужен.
static func choose_play(k: V10MjKoikoi, p: int, sid: String, rng: RandomNumberGenerator) -> Dictionary:
	var st: = style_of(sid)
	var best: = {"card": k.hand[p][0], "target": -1}
	var best_v: = -INF
	var opts: = []
	for c in k.hand[p]:
		var ms: = k.matches(c)
		var v: = 0.0
		var target: = -1
		if ms.is_empty():
			v = -_danger(k, p, c, st) - V10MjKoikoi.base_value(c) * 0.6
			if float(st.get("hold_light", 0.0)) > 0.0 and _light_alive(k, p, V10MjKoikoi.month(c)):
				# «Лунная тень»: карту месяца, где свет ещё в игре, держит в руке — ею потом заберёт свет
				v -= float(st.hold_light)
		elif ms.size() == 2:
			var tv: = -INF
			for t in ms:
				var g: = _gain(k, p, [c, t], st)
				if g > tv:
					tv = g
					target = t
			v = tv + st.take
			# вторая карта месяца остаётся на столе — её может забрать соперница
			var left: int = ms[0] if ms[1] == target else ms[1]
			v -= _danger(k, p, left, st) * 0.5
		else:
			v = _gain(k, p, [c] + ms, st) + st.take
		v += rng.randf() * float(st.noise)
		opts.append({"card": c, "target": target, "v": v})
		if v > best_v:
			best_v = v
			best = {"card": c, "target": target}
	if float(st.slip) > 0.0 and opts.size() > 1 and rng.randf() < float(st.slip):
		var o: Dictionary = opts[rng.randi() % opts.size()]
		return {"card": o.card, "target": o.target}
	return best

static func choose_pick(k: V10MjKoikoi, p: int, sid: String, c: int, options: Array) -> int:
	var st: = style_of(sid)
	var best: int = options[0]
	var bv: = -INF
	for t in options:
		var g: = _gain(k, p, [c, t], st)
		if g > bv:
			bv = g
			best = t
	return best

# Ценность забранных карт для игрока p: прирост очков комбинаций + приближение к комбинациям + сама карта.
static func _gain(k: V10MjKoikoi, p: int, got: Array, st: Dictionary) -> float:
	var before: = V10MjKoikoi.score_of(V10MjKoikoi.yaku_of(k.caps[p]))
	var after_caps: Array = k.caps[p] + got
	var after: = V10MjKoikoi.score_of(V10MjKoikoi.yaku_of(after_caps))
	var v: = float(after - before) * 6.0 * float(st.combo)
	for c in got:
		var b: = V10MjKoikoi.base_value(c)
		if V10MjKoikoi.kind(c) == "light":
			b *= float(st.light)
		v += b + _near(k.caps[p], c) * float(st.combo)
	return v

# Насколько карта c приближает комбинацию, если уже есть часть набора.
static func _near(caps: Array, c: int) -> float:
	var t: = V10MjKoikoi.tag(c)
	var kd: = V10MjKoikoi.kind(c)
	var cnt: = func(f: Callable) -> int:
		var n: = 0
		for x in caps:
			if f.call(x):
				n += 1
		return n
	var v: = 0.0
	if kd == "light":
		v += 1.5 * cnt.call(func(x): return V10MjKoikoi.kind(x) == "light")
	if t in ["boar", "deer", "butterfly"]:
		v += 2.0 * cnt.call(func(x): return V10MjKoikoi.tag(x) in ["boar", "deer", "butterfly"])
	if t == "poem":
		v += 2.0 * cnt.call(func(x): return V10MjKoikoi.tag(x) == "poem")
	if t == "blue":
		v += 2.0 * cnt.call(func(x): return V10MjKoikoi.tag(x) == "blue")
	if t in ["cup", "curtain", "moon"]:
		v += 3.0 * cnt.call(func(x): return V10MjKoikoi.tag(x) in ["cup", "curtain", "moon"])
	if kd == "ribbon":
		v += 0.3 * cnt.call(func(x): return V10MjKoikoi.kind(x) == "ribbon")
	if kd == "animal":
		v += 0.3 * cnt.call(func(x): return V10MjKoikoi.kind(x) == "animal")
	if kd == "plain":
		v += 0.12 * cnt.call(func(x): return V10MjKoikoi.kind(x) == "plain")
	return v

# Светлая карта месяца m ещё не взята и не лежит на столе (её можно поймать позже).
static func _light_alive(k: V10MjKoikoi, p: int, m: int) -> bool:
	for c in k.unseen_for(p):
		if V10MjKoikoi.month(c) == m and V10MjKoikoi.kind(c) == "light":
			return true
	return false

# Риск оставить карту c на столе: ценность для соперницы × шанс, что у неё есть карта того же месяца.
static func _danger(k: V10MjKoikoi, p: int, c: int, st: Dictionary) -> float:
	var q: = 1 - p
	var unseen: = k.unseen_for(p)
	if unseen.is_empty():
		return 0.0
	var u: = 0
	for x in unseen:
		if V10MjKoikoi.month(x) == V10MjKoikoi.month(c):
			u += 1
	var h: int = k.hand[q].size()
	var prob: = 1.0 - pow(1.0 - float(u) / float(unseen.size()), float(h) + 1.0)
	var val: = V10MjKoikoi.base_value(c) + _near(k.caps[q], c)
	return val * prob * float(st.defense) * 1.4

# ── решение «Забрать / Кои-кои!» ──────────────────────────────────────────────────────────────────

static func decide_koi(k: V10MjKoikoi, p: int, sid: String, rng: RandomNumberGenerator) -> bool:
	var s: = V10MjKoikoi.score_of(V10MjKoikoi.yaku_of(k.caps[p]))
	var left: int = k.hand[p].size()
	if left == 0:
		return false
	var threat: = threat_of(k, p)
	match sid:
		"hana":
			return rng.randf() < 0.92
		"rin":
			if s <= 1 and left >= 3 and rng.randf() < 0.3:
				return true   # редкая вольность: месяц только начался, а очков мало
			return s <= 2 and left >= 4 and threat < 0.45 and rng.randf() < 0.5
		"yue":
			var my_lights: = 0
			for c in k.caps[p]:
				if V10MjKoikoi.kind(c) == "light":
					my_lights += 1
			var lights_live: = 0
			for c in k.unseen_for(p) + k.table + k.hand[p]:
				if V10MjKoikoi.kind(c) == "light":
					lights_live += 1
			if my_lights >= 2 and my_lights < 5 and lights_live >= 1 and left >= 3 and threat < 0.6:
				return true
			return s <= 2 and left >= 4 and threat < 0.3
		"nova":
			var up: = upside_of(k, p)
			# ожидание: удвоение × шанс дожить без перехвата против синицы в руке
			var ev_koi: = (float(s) * 2.0 + up) * (1.0 - threat) - float(s) * threat * 0.5
			return left >= 2 and ev_koi > float(s) * 1.12
		_:
			return s < 3 and left >= 4 and threat < 0.5

# Шанс, что соперница (q = 1 - p) соберёт комбинацию до конца месяца, по публичной информации.
static func threat_of(k: V10MjKoikoi, p: int) -> float:
	var q: = 1 - p
	var turns_left: = float(k.hand[q].size())
	if turns_left <= 0.0:
		return 0.0
	var pool: = {}
	for c in k.unseen_for(p) + k.table:
		pool[c] = true
	var cq: Array = k.caps[q]
	var sets: = [
		[func(c): return V10MjKoikoi.kind(c) == "light" and V10MjKoikoi.tag(c) != "rain", 3],
		[func(c): return V10MjKoikoi.tag(c) in ["boar", "deer", "butterfly"], 3],
		[func(c): return V10MjKoikoi.tag(c) == "poem", 3],
		[func(c): return V10MjKoikoi.tag(c) == "blue", 3],
		[func(c): return V10MjKoikoi.kind(c) == "ribbon", 5],
		[func(c): return V10MjKoikoi.kind(c) == "animal", 5],
		[func(c): return V10MjKoikoi.kind(c) == "plain", 10],
	]
	var safe: = 1.0
	for s in sets:
		var f: Callable = s[0]
		var need: int = s[1]
		var have: = 0
		for c in cq:
			if f.call(c):
				have += 1
		var miss: = need - have
		if miss <= 0:
			continue
		var avail: = 0
		for c in pool:
			if f.call(c):
				avail += 1
		if avail < miss or float(miss) > turns_left * 2.0:
			continue
		# ожидаемое число карт набора, которые она заберёт: ≈ 2 карты за ход × доля набора в невидимых
		var lam: = turns_left * 2.0 * float(avail) / float(maxi(1, pool.size()))
		safe *= 1.0 - _poisson_tail(lam, miss)
	# чаша + занавес / луна
	var has_cup: = cq.has(V10MjKoikoi.find("cup"))
	for t in ["curtain", "moon"]:
		var c2: = V10MjKoikoi.find(t)
		var a: = has_cup or pool.has(V10MjKoikoi.find("cup"))
		var b: = cq.has(c2) or pool.has(c2)
		if a and b and (has_cup or cq.has(c2)):
			safe *= 0.8
	return clampf(1.0 - safe, 0.0, 1.0)

static func _poisson_tail(lam: float, k: int) -> float:
	var term: = exp(-lam)
	var cdf: = 0.0
	for i in k:
		cdf += term
		term *= lam / float(i + 1)
	return clampf(1.0 - cdf, 0.0, 1.0)

# Сколько очков в среднем можно добрать, если продолжить (грубо).
static func upside_of(k: V10MjKoikoi, p: int) -> float:
	var v: = 0.0
	for e in V10MjKoikoi.progress(k.caps[p]):
		var miss: int = e.need - e.have
		if miss <= 2 and miss <= k.hand[p].size():
			v += float(V10MjKoikoi.YAKU[e.id].pts) * (0.35 if miss == 1 else 0.12)
	return v

# ── полный автоход (для ИИ×ИИ и для хода соперницы на экране) ───────────────────────────────────

# Делает один шаг состояния за игрока k.turn. Возвращает описание шага.
static func step(k: V10MjKoikoi, sid: String, rng: RandomNumberGenerator) -> String:
	var p: = k.turn
	match k.phase:
		"play":
			var mv: = choose_play(k, p, sid, rng)
			k.play(int(mv.card), int(mv.target))
			return "play"
		"pick":
			k.choose(choose_pick(k, p, sid, k.pending, k.pick_options))
			return "pick"
		"draw":
			k.draw()
			return "draw"
		"decide":
			if decide_koi(k, p, sid, rng):
				k.koikoi()
				return "koikoi"
			k.stop()
			return "stop"
	return k.phase

# Сыграть весь месяц ИИ против ИИ. styles = [style_p0, style_p1]. Возвращает число шагов (сторож от зависаний).
static func play_month(k: V10MjKoikoi, styles: Array, rng: RandomNumberGenerator, max_steps: = 400) -> int:
	var n: = 0
	while k.phase != "over" and n < max_steps:
		step(k, styles[k.turn], rng)
		n += 1
	k.take_events()
	return n
