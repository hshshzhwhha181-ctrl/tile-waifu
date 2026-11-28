class_name V10DuelSim
extends RefCounted

# V10DuelSim — a headless model of the duel race (spec R6 «калибровка офлайн») and the calibration itself.
#
# The table is the tower track's model V10TowerSim (TWFree.gen_layout as is, the «free» rule of
# tray_board._free_if, the _assign algorithm from a seeded stream) on the duel cfg of V10DuelCfg. The heroine is
# V6Duel / V10DuelRun as an event model: her clock runs down from `pace` (±15 %), at `telegraph` she marks a free
# pair (aiming at a face you hold in the tray only with soft_steal), at 0 she takes it if both tiles are still there,
# otherwise it is a steal (her clock restarts at 0,75 pace). Every `need` pairs she plays her trick, at most trick_n
# times (double / sprint / veil / frost / gust; her clock stands 1,2 s for the cast). An overflow of your tray gives
# her a pair and returns 3 tiles. The table is cleared → more pairs wins.
# The player is a bot of the tower model (V10TowerSim._choose: sees free faces, plans one move ahead at expert)
# plus `notice`: how often it grabs her shimmering pair first.
#
#   race(cfg, her, bot, rng) -> {win, draw, me, her, steals, tricks, secs}   (win = the PLAYER won)
#   calibrate(games, heroes, verbose) -> Dictionary   all heroines × forms I–V × bots, then a Bradley–Terry (Elo) fit
#                                     anchored at the casual bot = 1000; ratings made strictly monotone in the form
#   write(path, data)              JSON for duel_rank.gd

const TS: = preload("res://core/modes/tower/sim.gd")
const U: = preload("res://core/modes/duels/duel_util.gd")
const F: = preload("res://core/modes/duels/duel_forms.gd")
const C: = preload("res://core/modes/duels/duel_cfg.gd")

# player bots on one skill line s = 0 … 1 (interpolated between the two ends below); the anchor «casual» = 1000
const BOT_ORDER: = ["novice", "casual", "regular", "steady", "keen", "skilled", "expert", "master"]
const BOT_S: = [0.0, 0.14, 0.28, 0.42, 0.56, 0.7, 0.85, 1.0]
const BOT_LO: = {"tap": 1.55, "think": 0.95, "careless": 0.45, "miss_pair": 0.25, "notice": 0.0}
const BOT_HI: = {"tap": 0.44, "think": 0.16, "careless": 0.0, "miss_pair": 0.0, "notice": 0.72}
static var BOTS: = _make_bots()

static func _make_bots() -> Dictionary:
	var out: = {}
	for i in BOT_ORDER.size():
		var k: float = BOT_S[i]
		var b: = {}
		for key in BOT_LO:
			b[key] = lerpf(float(BOT_LO[key]), float(BOT_HI[key]), k)
		b["plan"] = k >= 0.55
		b["sees_covered"] = k >= 0.3
		out[BOT_ORDER[i]] = b
	return out

const ANCHOR: = "casual"
const ANCHOR_R: = 1000.0
const MIN_STEP: = 20          # strictly monotone: every form at least this much above the previous one
const CAST_PAUSE: = 1.2       # her clock stands while the trick is cast
const FAIL_PAUSE: = 0.65      # the tray overflow beat (0.45 s + the return)
const START_DELAY: = 0.9      # the deal lands
const REACT: = 0.3            # a player needs this long to see her shimmer before grabbing her pair


static func race(cfg: Dictionary, her: Dictionary, bot: String, r: RandomNumberGenerator) -> Dictionary:
	var b: = TS.deal(cfg)
	var sk: Dictionary = BOTS.get(bot, BOTS.casual)
	var slots: = C.SLOTS
	var tray: = []
	var fog: = PackedByteArray()
	fog.resize(b.n)
	var veil: = PackedFloat32Array()
	veil.resize(b.n)
	var pace: = float(her.pace)
	var tele: = float(her.telegraph)
	var need: = int(her.need)
	var trick_n: = int(her.trick_n)
	var kind: = String(her.trick)
	var soft: = float(her.soft_steal)
	var jit: = float(her.get("jitter", F.JITTER))
	var t: = 0.0
	var p_next: = START_DELAY + float(sk.tap) + r.randf() * float(sk.think)
	var clock: = pace + 1.0
	var target: = []
	var target_t: = 0.0
	var steal_k: = float(her.get("steal_recover", 0.75))
	var sprint_until: = float(her.get("start_sprint", 0.0))
	var pause_until: = 0.0
	var me: = 0
	var hp: = int(her.get("her_start", 0))
	var steals: = 0
	var gauge: = 0
	var tricks: = 0
	var guard: = 0
	while (b.count() > 0 or not tray.is_empty()) and guard < 3000:
		guard += 1
		var thresh: = 0.0 if not target.is_empty() else tele
		var h_due: = _due(t, maxf(0.0, clock - thresh), sprint_until, pause_until)
		if p_next <= h_due:
			clock -= _consumed(t, p_next, sprint_until, pause_until)
			t = p_next
			# the player
			for i in b.n:
				fog[i] = 1 if veil[i] > t else 0
			var fr: = b.free_list()
			for i in fr:
				b.secret[i] = 0
			var pick: = -1
			if not target.is_empty() and t - target_t >= REACT and r.randf() < float(sk.notice):
				pick = _notice(b, target, tray, slots, fog)
			if pick < 0:
				pick = TS._choose(b, fr, tray, slots, fog, sk, r)
			if pick < 0:
				break
			p_next = t + float(sk.tap) + r.randf() * float(sk.think)
			if b.ice[pick] > 0:
				b.ice[pick] -= 1
			else:
				b.present[pick] = 0
				var twin: = -1
				for x in tray:
					if b.face[x] == b.face[pick]:
						twin = x
						break
				if twin >= 0:
					tray.erase(twin)
					me += 1
				else:
					tray.append(pick)
					if tray.size() >= slots:
						hp += 1
						for k in mini(3, tray.size()):
							b.present[int(tray.pop_back())] = 1
						p_next += FAIL_PAUSE
			if not target.is_empty() and (b.present[int(target[0])] == 0 or b.present[int(target[1])] == 0):
				target = []
				steals += 1
				clock = pace * steal_k
		else:
			clock -= _consumed(t, h_due, sprint_until, pause_until)
			t = h_due
			if target.is_empty():
				var c: = _candidates(b, tray, soft, r)
				if c.is_empty():
					clock = 1.2 + tele
				else:
					target = c[0]
					target_t = t
					clock = tele
			else:
				var a: = int(target[0])
				var c2: = int(target[1])
				target = []
				if b.present[a] == 1 and b.present[c2] == 1:
					b.present[a] = 0
					b.present[c2] = 0
					hp += 1
					gauge += 1
				clock = pace * (1.0 + jit * (r.randf() * 2.0 - 1.0))
				if gauge >= need and tricks < trick_n:
					gauge = 0
					tricks += 1
					pause_until = t + CAST_PAUSE
					match kind:
						"double":
							for k in 2:
								var cc: = _candidates(b, tray, 1.0, r)
								if cc.is_empty():
									break
								b.present[int(cc[0][0])] = 0
								b.present[int(cc[0][1])] = 0
								hp += 1
						"sprint":
							sprint_until = pause_until + float(F.TRICKS.sprint.secs)
							clock = minf(clock, 1.0)
						"veil":
							var fr2: = b.free_list()
							U.shuffle(fr2, r)
							for i in mini(4, fr2.size()):
								veil[int(fr2[i])] = pause_until + float(F.TRICKS.veil.secs)
						"frost":
							var fr3: = b.free_list().filter(func(i): return b.ice[i] == 0)
							U.shuffle(fr3, r)
							for i in mini(3, fr3.size()):
								b.ice[int(fr3[i])] = 1
						"gust":
							var fr4: = b.free_list()
							U.shuffle(fr4, r)
							fr4 = fr4.slice(0, mini(6, fr4.size()))
							var fs: = fr4.map(func(i): return b.face[i])
							U.shuffle(fs, r)
							for i in fr4.size():
								b.face[int(fr4[i])] = int(fs[i])
	return {"win": me > hp, "draw": me == hp, "me": me, "her": hp, "steals": steals, "tricks": tricks, "secs": t}


# her countdown consumed between a and b (the cast pause stops it; a sprint runs it ×2.2)
static func _consumed(a: float, b: float, sprint_until: float, pause_until: float) -> float:
	var s: = maxf(a, pause_until)
	if b <= s:
		return 0.0
	var fast: = maxf(0.0, minf(b, sprint_until) - s)
	return fast * float(F.TRICKS.sprint.speed) + (b - s - fast)


# when her countdown has consumed `need` starting at a
static func _due(a: float, need: float, sprint_until: float, pause_until: float) -> float:
	var s: = maxf(a, pause_until)
	var sp: = float(F.TRICKS.sprint.speed)
	if s < sprint_until:
		var fast_cap: = (sprint_until - s) * sp
		if need <= fast_cap:
			return s + need / sp
		return sprint_until + (need - fast_cap)
	return s + need


# her pairs: two free tiles of a face (not iced, face up); faces you hold in the tray only with soft_steal
static func _candidates(b, tray: Array, soft: float, r: RandomNumberGenerator) -> Array:
	var by: = {}
	for i in b.free_list():
		if b.ice[i] > 0 or b.secret[i] == 1:
			continue
		var f: int = b.face[i]
		if not by.has(f):
			by[f] = []
		by[f].append(i)
	var held: = {}
	for x in tray:
		held[b.face[x]] = true
	var out: = []
	var soft_l: = []
	for f in by:
		var arr: Array = by[f]
		if arr.size() < 2:
			continue
		var pair: = [arr[0], arr[1]]
		if held.has(f):
			soft_l.append(pair)
		else:
			out.append(pair)
	if out.is_empty() or r.randf() < soft:
		out.append_array(soft_l)
	U.shuffle(out, r)
	return out


# the player saw her shimmer: finish a tray pair with one of her tiles, or take her pair outright while there is room
static func _notice(b, target: Array, tray: Array, slots: int, fog: PackedByteArray) -> int:
	var a: = int(target[0])
	var c: = int(target[1])
	if b.present[a] == 0 or b.present[c] == 0:
		return -1
	for x in tray:
		for i in [a, c]:
			if b.face[x] == b.face[i] and b.free_i(i) and fog[i] == 0:
				return i
	if tray.size() <= slots - 2 and b.free_i(a) and b.free_i(c) and fog[a] == 0 and fog[c] == 0:
		return a
	return -1


# ---------------------------------------------------------------- calibration

static func table_cfg(h: String, f: int, seed_v: int) -> Dictionary:
	return C.cfg_for({"kind": "ranked", "rival": h, "form": f, "seed": seed_v}, "mc")


# results[h][f-1][bot] = [her_score, games]
static func play_cells(games: int, heroes: Array, verbose: = false) -> Dictionary:
	var res: = {}
	var t0: = U.tick_ms()
	for h in heroes:
		res[h] = []
		for f in range(1, F.FORMS + 1):
			var hp: = F.run_params(h, f, "ranked")
			var cell: = {}
			for bot in BOT_ORDER:
				var sc: = 0.0
				for g in games:
					var sd: = U.hseed(["cal", h, f, bot, g])
					var o: = race(table_cfg(h, f, 1 + sd % 999999), hp, bot, U.rng(sd, "race"))
					sc += 0.5 if bool(o.draw) else (0.0 if bool(o.win) else 1.0)
				cell[bot] = [sc, games]
			res[h].append(cell)
		if verbose:
			print("DUEL_CAL %s done (%.0f s)" % [h, (U.tick_ms() - t0) / 1000.0])
	return res


# Bradley–Terry on the Elo scale (base 10, 400): heroine-forms and bots; Laplace prior ½ win + ½ loss per cell
static func fit(cells: Dictionary) -> Dictionary:
	var hr: = {}
	var br: = {}
	for bot in BOT_ORDER:
		br[bot] = ANCHOR_R
	for h in cells:
		hr[h] = []
		for f in F.FORMS:
			hr[h].append(ANCHOR_R)
	var LN: = log(10.0) / 400.0
	for it in 200:
		for h in cells:
			for fi in F.FORMS:
				var g: = 0.0
				var hh: = 0.0
				for bot in BOT_ORDER:
					var c: Array = cells[h][fi][bot]
					var n: = float(c[1]) + 1.0
					var s: = float(c[0]) + 0.5
					var e: = 1.0 / (1.0 + pow(10.0, (float(br[bot]) - float(hr[h][fi])) / 400.0))
					g += (s - n * e) * LN
					hh -= n * e * (1.0 - e) * LN * LN
				if hh < 0.0:
					hr[h][fi] = float(hr[h][fi]) - clampf(g / hh, -300.0, 300.0)
		for bot in BOT_ORDER:
			var g: = 0.0
			var hh: = 0.0
			for h in cells:
				for fi in F.FORMS:
					var c: Array = cells[h][fi][bot]
					var n: = float(c[1]) + 1.0
					var s: = n - (float(c[0]) + 0.5)
					var e: = 1.0 / (1.0 + pow(10.0, (float(hr[h][fi]) - float(br[bot])) / 400.0))
					g += (s - n * e) * LN
					hh -= n * e * (1.0 - e) * LN * LN
			if hh < 0.0:
				br[bot] = float(br[bot]) - clampf(g / hh, -300.0, 300.0)
		var shift: = ANCHOR_R - float(br[ANCHOR])
		for bot in BOT_ORDER:
			br[bot] = float(br[bot]) + shift
		for h in hr:
			for fi in F.FORMS:
				hr[h][fi] = float(hr[h][fi]) + shift
	return {"heroes": hr, "bots": br}


# strictly increasing in the form: pool adjacent violators, then at least MIN_STEP between forms
static func monotone(v: Array) -> Array:
	var blocks: = []
	for x in v:
		blocks.append([float(x), 1])
		while blocks.size() >= 2 and float(blocks[-2][0]) > float(blocks[-1][0]):
			var b2: Array = blocks.pop_back()
			var b1: Array = blocks.pop_back()
			var n: = int(b1[1]) + int(b2[1])
			blocks.append([(float(b1[0]) * int(b1[1]) + float(b2[0]) * int(b2[1])) / n, n])
	var out: = []
	for bl in blocks:
		for k in int(bl[1]):
			out.append(float(bl[0]))
	for i in range(1, out.size()):
		if out[i] < out[i - 1] + MIN_STEP:
			out[i] = out[i - 1] + MIN_STEP
	return out.map(func(x): return int(round(x)))


static func calibrate(games: int, heroes: Array, verbose: = false) -> Dictionary:
	var t0: = U.tick_ms()
	var cells: = play_cells(games, heroes, verbose)
	var ft: = fit(cells)
	var ratings: = {}
	var raw: = {}
	var fixed: = 0
	for h in heroes:
		var v: Array = ft.heroes[h]
		raw[h] = v.map(func(x): return int(round(float(x))))
		var m: = monotone(v)
		for i in m.size():
			if int(m[i]) != int(raw[h][i]):
				fixed += 1
		ratings[h] = m
	var bots: = {}
	for bot in BOT_ORDER:
		bots[bot] = int(round(float(ft.bots[bot])))
	var winrates: = {}
	for h in heroes:
		winrates[h] = []
		for fi in F.FORMS:
			var row: = {}
			for bot in BOT_ORDER:
				var c: Array = cells[h][fi][bot]
				row[bot] = int(round(100.0 * float(c[0]) / maxf(1.0, float(c[1]))))
			winrates[h].append(row)
	return {"ver": 1, "generated": U.cal_key(), "games_per_cell": games, "anchor": {"bot": ANCHOR, "rating": int(ANCHOR_R)},
		"bots": bots, "ratings": ratings, "raw": raw, "monotone_fixed": fixed, "her_score_x100": winrates,
		"forms": {"pace_k": F.PACE_K, "telegraph": F.TELEGRAPH, "need": F.NEED, "trick_n": F.TRICK_N, "soft_steal": F.SOFT_STEAL},
		"secs": int((U.tick_ms() - t0) / 1000.0)}


static func write(path: String, data: Dictionary) -> bool:
	var f: = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t", false))
	f.close()
	return true
