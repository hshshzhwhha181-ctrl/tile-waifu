class_name V8AI
extends RefCounted






const STYLES: = {
	"coach": {"call": 0.5, "riichi": 0.9, "defense": 0.7, "skill": 1.0, "value": 0.6, "speed": 1.0}, 
	"mc": {"call": 0.45, "riichi": 0.8, "defense": 0.6, "skill": 0.85, "value": 0.6, "speed": 1.0, "name": "Ровный ветер", "desc": "Играет по учебнику: быстро, аккуратно, без глупых рисков."}, 
	"rin": {"call": 0.35, "riichi": 0.45, "defense": 0.85, "skill": 0.9, "value": 0.8, "speed": 0.9, "name": "Тихая церемония", "desc": "Часто ждёт молча, без риичи. Её сброс трудно читать."}, 
	"hana": {"call": 0.95, "riichi": 0.9, "defense": 0.25, "skill": 0.8, "value": 0.35, "speed": 1.2, "name": "Эстафета", "desc": "Открывается на всё подряд и летит к дешёвой, но быстрой победе."}, 
	"yue": {"call": 0.2, "riichi": 0.75, "defense": 0.95, "skill": 0.92, "value": 1.2, "speed": 0.85, "name": "Лунная тень", "desc": "Собирает дорогие руки и сразу уходит в защиту, если пахнет опасностью."}, 
	"nova": {"call": 0.55, "riichi": 1.0, "defense": 0.1, "skill": 0.85, "value": 1.0, "speed": 1.1, "name": "Оверклок", "desc": "Риичи при любой возможности, давит до конца и любит дору."}, 
}

static var room_skill: = 1.0

static func style_of(r, s: int) -> Dictionary:
	var st: Dictionary = r.players[s].get("style", {})
	if st.is_empty():
		st = STYLES.get(r.players[s].get("id", "mc"), STYLES.mc)
	return st


static func turn(r, s: int, o: Dictionary) -> Dictionary:
	if o.tsumo:
		return {"a": "tsumo"}
	var st: = style_of(r, s)
	if r.riichi[s]:
		for k in o.kans:
			if k.a == "ankan":
				return k
		return {"a": "discard", "t": r.drawn}

	for k in o.kans:
		if k.a == "ankan":
			var c: = V8Mj.counts(r.hands[s])
			var sh0: = _best_shanten_after_discard(c, r.melds[s].size())
			c[k.k] -= 4
			var sh1: = _best_shanten_after_discard_13(c, r.melds[s].size() + 1)
			if sh1 <= sh0:
				return k
	var pick: = choose_discard(r, s, st, o.forbidden)
	var t: int = pick.t
	if o.riichi.size() > 0 and t in o.riichi:
		if _want_riichi(r, s, st, t):
			return {"a": "discard", "t": t, "riichi": true}
	elif o.riichi.size() > 0 and pick.shanten == 0:
		pass
	return {"a": "discard", "t": t}

static func _best_shanten_after_discard(c: Array, nm: int) -> int:
	var best: = 9
	for k in 34:
		if c[k] > 0:
			c[k] -= 1
			best = mini(best, V8Mj.shanten(c, nm))
			c[k] += 1
	return best

static func _best_shanten_after_discard_13(c: Array, nm: int) -> int:

	return V8Mj.shanten(c, nm)

static func _want_riichi(r, s: int, st: Dictionary, t: int) -> bool:
	var c: = V8Mj.counts(r.hands[s])
	c[t >> 2] -= 1
	var w: = V8Mj.waits(c, r.melds[s].size())
	var seen: Array = r.visible(s)
	var live: = 0
	for k in w:
		live += maxi(0, 4 - seen[k])
	if live == 0:
		return false

	var est: = _dama_value(r, s, c, w)
	var p: float = st.riichi
	if est >= 3 and st.value >= 0.8:
		p *= 0.35
	if est == 0:
		p = maxf(p, 0.97)
	if live <= 2:
		p *= 0.7
	return r.rng.randf() < p


static func _dama_value(r, s: int, c13: Array, w: Array) -> int:
	var best: = 0
	var closed: = []
	for k in 34:
		for i in c13[k]:
			closed.append(k * 4 + 1)
	for k in w:
		var cl: = closed.duplicate()
		cl.append(k * 4 + 1)
		var ctx: = {"tsumo": false, "seat_wind": r.seat_wind(s), "round_wind": r.round_wind_kind(), "dora_ind": r.dora_ind, "dealer": s == r.dealer}
		var ev: = V8Mj.evaluate(cl, r.melds[s], k * 4 + 1, ctx)
		if not ev.is_empty():
			best = maxi(best, int(ev.han) + 13 * int(ev.yakuman))
	return best


static func choose_discard(r, s: int, st: Dictionary, forbidden: = []) -> Dictionary:
	var hand: Array = r.hands[s]
	var nm: int = r.melds[s].size()
	var c: = V8Mj.counts(hand)
	var seen: Array = r.visible(s)
	var dk: Array = r.dora_kinds()
	var threats: = threat_seats(r, s)
	var push: = _push_or_fold(r, s, st, c, nm, threats)
	var ranked: = []
	var tried: = {}
	var min_sh: = 9
	var sh_of: = {}
	for t in hand:
		var k: int = t >> 2
		if tried.has(k) or k in forbidden:
			continue
		tried[k] = true
		c[k] -= 1
		sh_of[k] = V8Mj.shanten(c, nm)
		min_sh = mini(min_sh, sh_of[k])
		c[k] += 1
	if tried.is_empty():
		var t0: int = hand[hand.size() - 1]
		return {"t": t0, "shanten": 9, "ranked": [[0.0, t0, {}]]}
	for k in tried.keys():
		var t: = _tile_of(hand, k)
		var sh: int = sh_of[k]
		var score: = 0.0
		var info: = {"shanten": sh}
		if sh <= min_sh + 1:
			c[k] -= 1
			var u: = V8Mj.ukeire(c, nm, seen) if sh <= min_sh else {"n": 0, "kinds": []}
			c[k] += 1
			info.ukeire = u.n
			info.waits = u.kinds
			score = - sh * 100.0 + float(u.n) * 2.2 * float(st.get("speed", 1.0))
		else:
			score = - sh * 100.0

		var val: = 0.0
		if k in dk:
			val -= 9.0 * c[k]
		if V8Mj.is_aka(t):
			val -= 8.0
		if k >= 27:
			var yh: bool = k >= 31 or k == r.seat_wind(s) or k == r.round_wind_kind()
			if c[k] == 1:
				val += 6.0 if not yh else 3.0
				val += 2.0 * seen[k]
			elif c[k] >= 2 and yh:
				val -= 12.0
		elif V8Mj.is_term(k):
			val += 2.0
		score += val * float(st.get("value", 0.6))

		var danger: = 0.0
		for o in threats:
			danger = maxf(danger, danger_of(r, o, k))
		info.danger = danger
		if threats.size() > 0:
			score -= danger * (40.0 if not push else 4.0) * float(st.get("defense", 0.5))
		ranked.append([score, t, info])
	ranked.sort_custom( func(a, b): return a[0] > b[0])
	var pick: Array = ranked[0]
	var skill: float = float(st.get("skill", 0.9)) * room_skill
	if r.rng.randf() > skill and ranked.size() > 1:
		pick = ranked[r.rng.randi_range(0, mini(2, ranked.size() - 1))]
	return {"t": pick[1], "shanten": min_sh, "ranked": ranked, "push": push, "threats": threats}

static func _tile_of(hand: Array, k: int) -> int:

	var pick: = -1
	for t in hand:
		if t >> 2 == k:
			if pick < 0 or (V8Mj.is_aka(pick) and not V8Mj.is_aka(t)):
				pick = t
	return pick


static func threat_seats(r, s: int) -> Array:
	var out: = []
	for o in 4:
		if o == s:
			continue
		if r.riichi[o]:
			out.append(o)
		elif r.melds[o].size() >= 3:
			out.append(o)
	return out

static func _push_or_fold(r, s: int, st: Dictionary, c: Array, nm: int, threats: Array) -> bool:
	if threats.is_empty():
		return true
	var sh: = V8Mj.shanten(c, nm)
	var d: float = float(st.get("defense", 0.5)) * room_skill
	if sh <= 0:
		return d < 0.97 or r.wall_left() > 12
	if sh == 1:
		return d < 0.5
	return d < 0.15


static func danger_of(r, o: int, k: int) -> float:
	var safe: = {}
	for p in r.ponds[o]:
		safe[p.t >> 2] = true

	if r.riichi[o]:
		var since: = -1
		for i in r.ponds[o].size():
			if r.ponds[o][i].riichi:
				since = i
		if since >= 0:
			var n_after: int = r.ponds[o].size() - since
			for j in 4:
				if j == o:
					continue
				var pj: Array = r.ponds[j]
				for i in range(maxi(0, pj.size() - n_after), pj.size()):
					safe[pj[i].t >> 2] = true
	if safe.has(k):
		return 0.0
	var seen: Array = _seen_all(r)
	if k >= 27:
		var left: int = 4 - seen[k]
		if left <= 1:
			return 0.5
		return 2.0 if left == 2 else 3.5
	var n: = k % 9 + 1
	var suji_lo: bool = n - 3 >= 1 and safe.has(k - 3)
	var suji_hi: bool = n + 3 <= 9 and safe.has(k + 3)
	var d: = 0.0
	if n == 1 or n == 9:
		d = 2.5 if (suji_lo or suji_hi) else 5.0
	elif n == 2 or n == 8:
		d = 3.5 if (suji_lo or suji_hi) else 7.0
	elif n == 3 or n == 7:
		d = 4.0 if (suji_lo or suji_hi) else 8.0
	else:
		if suji_lo and suji_hi:
			d = 4.0
		elif suji_lo or suji_hi:
			d = 6.5
		else:
			d = 9.5

	if n >= 2 and n <= 8 and (seen[k - 1] >= 4 or seen[k + 1] >= 4):
		d *= 0.75
	if k in r.dora_kinds():
		d += 1.5
	return d

static func _seen_all(r) -> Array:
	var c: = []
	c.resize(34)
	c.fill(0)
	for i in 4:
		for p in r.ponds[i]:
			c[p.t >> 2] += 1
		for md in r.melds[i]:
			for t in md.tiles:
				c[t >> 2] += 1
	for d in r.dora_ind:
		c[d >> 2] += 1
	return c


static func decide_call(r, s: int, opts: Dictionary) -> Dictionary:
	if opts.ron:
		return {"a": "ron"}
	var st: = style_of(r, s)
	var k: int = r.last_discard >> 2
	var c: = V8Mj.counts(r.hands[s])
	var nm: int = r.melds[s].size()
	var sh0: = V8Mj.shanten(c, nm)
	var threats: = threat_seats(r, s)
	if threats.size() > 0 and sh0 >= 2 and float(st.defense) > 0.4:
		return {"a": "pass"}
	var yh: bool = k >= 31 or k == r.seat_wind(s) or k == r.round_wind_kind()
	if opts.pon:
		c[k] -= 2
		var sh1: = _best_shanten_after_discard_13x(c, nm + 1)
		c[k] += 2
		if yh and r.rng.randf() < 0.35 + float(st.call):
			return {"a": "pon"}
		if sh1 < sh0 and _open_yaku_ok(r, s, k, -1) and r.rng.randf() < float(st.call):
			return {"a": "pon"}
	if opts.kan and r.rng.randf() < float(st.call) * 0.4 and yh:
		return {"a": "kan"}
	for use in opts.chi:
		c[use[0] >> 2] -= 1
		c[use[1] >> 2] -= 1
		var sh2: = _best_shanten_after_discard_13x(c, nm + 1)
		c[use[0] >> 2] += 1
		c[use[1] >> 2] += 1
		if sh2 < sh0 and _open_yaku_ok(r, s, k, use[0] >> 2) and r.rng.randf() < float(st.call) * 0.85:
			return {"a": "chi", "use": use}
	return {"a": "pass"}


static func _best_shanten_after_discard_13x(c: Array, nm: int) -> int:
	return _best_shanten_after_discard(c, nm)


static func _open_yaku_ok(r, s: int, called_k: int, chi_low: int) -> bool:
	var ks: = []
	for t in r.hands[s]:
		ks.append(t >> 2)
	ks.append(called_k)
	for md in r.melds[s]:
		for t in md.tiles:
			ks.append(t >> 2)
	var c: = V8Mj.counts([])
	for k in ks:
		c[k] += 1

	for k in [31, 32, 33, r.seat_wind(s), r.round_wind_kind()]:
		if c[k] >= 3 or (c[k] >= 2 and k != called_k):
			return true

	var yc: = 0
	for k in ks:
		if V8Mj.is_yaochu(k):
			yc += 1
	if yc <= 1 and not V8Mj.is_yaochu(called_k):
		return true

	var per: = [0, 0, 0]
	var hon: = 0
	for k in ks:
		if k >= 27:
			hon += 1
		else:
			per[V8Mj.suit(k)] += 1
	for su in 3:
		if per[su] + hon >= ks.size() - 2 and (called_k >= 27 or V8Mj.suit(called_k) == su):
			return true

	var pairs: = 0
	for k in 34:
		if c[k] >= 2:
			pairs += 1
	if pairs >= 4 and chi_low < 0:
		return true
	return false


static func coach(r, s: int) -> Dictionary:
	var st: Dictionary = STYLES.coach
	var o: Dictionary = r.turn_options(s)
	var pick: = choose_discard(r, s, st, o.forbidden)
	return pick
