extends Node

# Тройки: самотест / запекание / пробы. См. README.
#   --mj_triples_selftest=1            итог MJ_TRIPLES ok/total, код выхода 0 только при 100 %
#     [--mj_triples_shots=<dir>]       проверить снимки старт · 6/7 · победа в 720×1280 и 1080×2400 (демо-сцена)
#   --triples_bake=1                   подбор сидов ботом → game/data/mj/triples/bake.json
#   --triples_probe=1 --from= --to= --x=0,0.5   пробы долей бота (разработка)

var args: = {}

func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			args[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
	get_tree().create_timer(600.0).timeout.connect(func():
		print("MJ_TRIPLES watchdog: 600 s")
		get_tree().quit(2))
	await get_tree().process_frame
	if args.has("triples_probe"):
		_probe()
		get_tree().quit(0)
	elif args.has("triples_bake"):
		_bake()
	elif args.has("mj_triples_selftest"):
		await _selftest()
	else:
		get_tree().quit(1)


func _probe() -> void:
	var from: = int(args.get("from", "1"))
	var to: = int(args.get("to", "10"))
	var t0: = Time.get_ticks_msec()
	if args.has("x"):
		for xs in String(args.x).split(","):
			for i in range(from, to + 1):
				var lv: = V10MjTriplesGen.build(i, float(xs), 0)
				var ok: = V10MjTriplesGen.certificate_ok(lv)
				print("i=%d x=%s n=%d kinds=%d hold=%d ok=%s rate=%.2f" % [i, xs, lv.n, lv.kinds, lv.hold, ok, V10MjTriplesGen.bot_rate(lv)])
	else:
		for i in range(from, to + 1):
			print(JSON.stringify(V10MjTriplesGen.calibrate(i)))
	print("ms=", Time.get_ticks_msec() - t0)


func _bake() -> void:
	var t0: = Time.get_ticks_msec()
	var d: = V10MjTriplesGen.bake(V10MjTriplesGen.BAKE_PATH, func(e): print(JSON.stringify(e)))
	print("TRIPLES_BAKE miss=%d ms=%d" % [int(d.miss), Time.get_ticks_msec() - t0])
	get_tree().quit(0)


# ── самотест ─────────────────────────────────────────────────────────────────

var ok_n: = 0
var total: = 0
var fails: Array = []


func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok_n += 1
	else:
		fails.append(what)
		if fails.size() <= 40:
			print("FAIL ", what)


func _selftest() -> void:
	var t0: = Time.get_ticks_msec()
	_t_levels()
	_t_bands()
	_t_return_slot()
	_t_dfs_monotone()
	_t_autosort()
	_t_loss()
	_t_boosters()
	_t_magnet_shuffle()
	_t_ults()
	_t_save_sound()
	_t_words()
	await _t_screen()
	_t_shots()
	print("MJ_TRIPLES %d/%d (%d ms)" % [ok_n, total, Time.get_ticks_msec() - t0])
	get_tree().quit(0 if ok_n == total else 1)


# 1. 120 уровней: сертификат проигрывается без переполнения; кривая и полосы на месте
func _t_levels() -> void:
	check(V10MjTriplesGen.COUNT == 120, "count 120")
	var bk: = V10MjTriplesGen.bake_data()
	check((bk.get("levels", []) as Array).size() == 120, "bake has 120 levels")
	for i in range(1, 121):
		var lv: = V10MjTriplesGen.build(i)
		check(lv.ok and lv.n % 3 == 0 and lv.n >= 24, "L%d built n=%d" % [i, lv.n])
		check(V10MjTriplesGen.certificate_ok(lv), "L%d certificate" % i)
		var fc: = {}
		for f in lv.faces:
			fc[f] = int(fc.get(f, 0)) + 1
		var m3: = true
		for f in fc:
			if int(fc[f]) % 3 != 0:
				m3 = false
		check(m3, "L%d faces multiple of 3" % i)
		var r: = V10MjTriplesRules.make(lv.pos, lv.faces)
		for t in lv.order:
			r.pick(int(t))
		check(r.won and r.max_tray <= 6, "L%d cert max tray %d" % [i, r.max_tray])
		var lv2: = V10MjTriplesGen.build(i)
		check(lv2.faces == lv.faces and lv2.pos == lv.pos, "L%d deterministic" % i)
		var bk_e: = V10MjTriplesGen.bake_entry(i)
		check(int(bk_e.get("n", -1)) == lv.n, "L%d bake matches build" % i)
	var kinds: = []
	for s in range(1, 11):
		kinds.append(V10MjTriplesGen.kind_of(20 + s))
	check(kinds == ["easy", "normal", "normal", "hard", "rest", "normal", "hard", "peak", "rest", "boss"], "saw chapter 3: %s" % str(kinds))
	check(V10MjTriplesGen.kind_of(8) == "hard" and V10MjTriplesGen.kind_of(18) == "hard", "no peaks in chapters 1-2")
	check(V10MjTriplesGen.band_kind(10) == "hard" and V10MjTriplesGen.band_kind(50) == "peak", "boss bands")


# 2. полосы бота casual по уровням сложности (детерминированные прогоны)
func _t_bands() -> void:
	var by: = {}
	for i in range(1, 121):
		var lv: = V10MjTriplesGen.build(i)
		var rate: = V10MjTriplesGen.bot_rate(lv)
		var b: Array = V10MjTriplesGen.band(i)
		check(rate >= float(b[0]) - 0.0001 and rate <= float(b[1]) + 0.0001, "L%d bot %.3f in %s" % [i, rate, str(b)])
		var k: = V10MjTriplesGen.band_kind(i)
		if not by.has(k):
			by[k] = []
		(by[k] as Array).append(rate)
	var avg: = {}
	for k in by:
		var s: = 0.0
		for v in by[k]:
			s += v
		avg[k] = s / (by[k] as Array).size()
	print("bot avg by band: ", avg)
	check(float(avg.easy) > float(avg.normal) and float(avg.normal) > float(avg.hard) and float(avg.hard) > float(avg.peak), "band averages monotone")


# 3. «Вернуть 3» и «+1 ячейка» на решаемом состоянии оставляют стол решаемым (свидетель — сертификат)
func _t_return_slot() -> void:
	for i in range(1, 121, 3):
		var lv: = V10MjTriplesGen.build(i)
		for frac in [0.2, 0.45, 0.7, 0.9]:
			var r: = V10MjTriplesRules.make(lv.pos, lv.faces)
			var k: = int(lv.n * frac)
			for s in k:
				r.pick(int(lv.order[s]))
			var rest: Array = lv.order.slice(k)
			check(r.replay_rest(rest), "L%d@%.2f prefix solvable" % [i, frac])
			var r2: = r.clone()
			var back: = r2.return_last(3)
			check(back.size() == mini(3, r.history.size()), "L%d return count" % i)
			check(r2.tray.size() == r.tray.size() - back.size(), "L%d return tray size" % i)
			var on_board: = true
			for b in back:
				if r2.present[b] != 1:
					on_board = false
			check(on_board, "L%d returned tiles on board" % i)
			# свидетель: снова взять возвращённые (сверху вниз), затем остаток сертификата
			var r3: = r2.clone()
			var pend: Array = back.duplicate()
			var guard: = 0
			while not pend.is_empty() and guard < 20:
				guard += 1
				for b in pend.duplicate():
					if r3.is_free(b):
						r3.pick(b)
						pend.erase(b)
			check(pend.is_empty() and r3.replay_rest(rest), "L%d@%.2f return3 keeps solvable" % [i, frac])
			var r4: = r.clone()
			check(r4.add_slot() and r4.slots == 8, "L%d slot +1" % i)
			check(not r4.add_slot(), "L%d slot only once" % i)
			check(r4.replay_rest(rest), "L%d@%.2f slot keeps solvable" % [i, frac])


# 3б. на случайных состояниях: если решаемо до — решаемо после (DFS с памятью, малые столы)
func _t_dfs_monotone() -> void:
	var tested: = 0
	var unknown: = 0
	for i in range(1, 60):
		var lv: = V10MjTriplesGen.build(i)
		if lv.n > 45:
			continue
		for run in 4:
			var rng: = RandomNumberGenerator.new()
			rng.seed = i * 31 + run
			var r: = V10MjTriplesRules.make(lv.pos, lv.faces)
			var steps: = rng.randi_range(4, lv.n / 2)
			for s in steps:
				if r.lost or r.won or r.frees.is_empty():
					break
				var m: int = r.frees[rng.randi() % r.frees.size()]
				var c: = r.clone()
				c.pick(m)
				if c.lost:
					break
				r.pick(m)
			if r.lost or r.won or r.tray.is_empty():
				continue
			var before: = V10MjTriplesRules.solve(r, 6000)
			if before != 1:
				if before == -1:
					unknown += 1
				continue
			var a: = r.clone()
			a.return_last(3)
			var sa: = V10MjTriplesRules.solve(a, 6000)
			var b: = r.clone()
			b.add_slot()
			var sb: = V10MjTriplesRules.solve(b, 6000)
			if sa == -1 or sb == -1:
				unknown += 1
				continue
			tested += 1
			check(sa == 1, "L%d run%d return3 DFS solvable" % [i, run])
			check(sb == 1, "L%d run%d slot DFS solvable" % [i, run])
	print("dfs monotone tested=%d unknown=%d" % [tested, unknown])
	check(tested >= 20, "dfs monotone sample >= 20 (got %d)" % tested)


# 4. автосортировка: одинаковые рядом (новая — сразу после последней такой же), порядок остальных не меняется
func _t_autosort() -> void:
	var bad_group: = 0
	var bad_stable: = 0
	var moves: = 0
	for i in range(1, 121, 7):
		var lv: = V10MjTriplesGen.build(i)
		for run in 6:
			var rng: = RandomNumberGenerator.new()
			rng.seed = 7000 + i * 13 + run
			var r: = V10MjTriplesRules.make(lv.pos, lv.faces)
			while not r.lost and not r.won and not r.frees.is_empty():
				var before: = r.tray.duplicate()
				var m: int = r.frees[rng.randi() % r.frees.size()]
				var res: = r.pick(m)
				moves += 1
				var seen: = {}
				var prev: = -1
				for t in r.tray:
					var f: = r.face[t]
					if f != prev and seen.has(f):
						bad_group += 1
					seen[f] = true
					prev = f
				var tri: Array = res.triple
				var old: Array = before.filter(func(x): return not tri.has(x))
				var j: = 0
				for t in r.tray:
					if j < old.size() and t == old[j]:
						j += 1
				if j != old.size():
					bad_stable += 1
				if tri.is_empty():
					var at: = r.tray.find(m)
					var had: bool = before.any(func(x): return r.face[x] == r.face[m])
					if had and not (at > 0 and r.face[r.tray[at - 1]] == r.face[m]):
						bad_group += 1
					if not had and at != r.tray.size() - 1:
						bad_group += 1
	check(moves > 500, "autosort moves %d" % moves)
	check(bad_group == 0, "autosort grouped (bad %d)" % bad_group)
	check(bad_stable == 0, "autosort stable (bad %d)" % bad_stable)


# 5. проигрыш строго на 7/7 без тройки
func _t_loss() -> void:
	var pos: Array = []
	var faces: = PackedInt32Array()
	for k in 21:
		pos.append(Vector3i((k % 7) * 2, (k / 7) * 2, 0))
		faces.append(k % 7)
	var r: = V10MjTriplesRules.make(pos, faces)
	for k in 6:
		var res: = r.pick(k)
		check(not res.lost and not r.lost, "no loss at %d/7" % (k + 1))
	var r6: = r.clone()
	var res7: = r.pick(6)
	check(res7.lost and r.lost and r.tray.size() == 7, "loss exactly at 7/7")
	check(not r.pick(7).ok, "no picks after loss")
	var r2: = V10MjTriplesRules.make(pos, faces)
	r2.pick(0)
	r2.pick(7)
	for k in [1, 2, 3, 4]:
		r2.pick(k)
	check(r2.tray.size() == 6 and not r2.lost, "6/7 with a pair")
	var res: = r2.pick(14)
	check(not res.lost and (res.triple as Array).size() == 3 and r2.tray.size() == 4, "7th completes triple -> no loss")
	var r3: = V10MjTriplesRules.make(pos, faces)
	r3.add_slot()
	for k in 7:
		r3.pick(k)
	check(not r3.lost and r3.tray.size() == 7, "slot 8: no loss at 7")
	var lv: = V10MjTriplesGen.build(60)
	var bad: = 0
	for run in 40:
		var rng: = RandomNumberGenerator.new()
		rng.seed = run * 17 + 3
		var rr: = V10MjTriplesRules.make(lv.pos, lv.faces)
		while not rr.lost and not rr.won:
			var res2: = rr.pick(rr.frees[rng.randi() % rr.frees.size()])
			if bool(res2.lost) != (rr.tray.size() >= rr.slots):
				bad += 1
	check(bad == 0, "loss iff tray full (bad %d)" % bad)
	var back: = r6.clone()
	back.pick(6)
	back.return_last(3)
	check(not back.lost and back.tray.size() == 4, "return3 revives a lost tray")


# 6. бустеры открываются на 5 / 9 / 15 / 22
func _t_boosters() -> void:
	check(V10MjTriplesSave.open_for(4).is_empty(), "no boosters before 5")
	check(V10MjTriplesSave.open_for(5) == ["return3"], "L5 return3")
	check(V10MjTriplesSave.open_for(8) == ["return3"], "L8 return3 only")
	check(V10MjTriplesSave.open_for(9) == ["return3", "magnet"], "L9 magnet")
	check(V10MjTriplesSave.open_for(14) == ["return3", "magnet"], "L14 no slot yet")
	check(V10MjTriplesSave.open_for(15) == ["return3", "magnet", "slot"], "L15 slot")
	check(V10MjTriplesSave.open_for(21).size() == 3, "L21 3 boosters")
	check(V10MjTriplesSave.open_for(22) == ["return3", "magnet", "slot", "shuffle"], "L22 shuffle")
	for lvl in [5, 9, 15, 22]:
		check(V10MjTriplesSave.new_at(lvl) != "", "new_at %d" % lvl)
	check(V10MjTriplesSave.new_at(6) == "", "new_at 6 empty")
	var S: = {}
	var d: = V10MjTriplesSave.st(S)
	check(int(d.level) == 1 and (d.boosters_open as Array).is_empty() and S.has("v10_mj_triples"), "save defaults")
	d.level = 4
	var rec: = V10MjTriplesSave.record(d, 4, true, 3, 100)
	check(int(d.level) == 5 and rec.opened == ["return3"] and (d.boosters_open as Array) == ["return3"], "win L4 opens return3")
	d.level = 8
	rec = V10MjTriplesSave.record(d, 8, true, 2, 100)
	check(rec.opened == ["magnet"], "win L8 opens magnet")
	rec = V10MjTriplesSave.record(d, 9, false, 0, 0)
	check(int(d.level) == 9 and (rec.opened as Array).is_empty(), "loss does not advance")


# 7. Магнит снимает 3 целые тройки, сертификат остаётся верным; «Перемешать» сохраняет решаемость
func _t_magnet_shuffle() -> void:
	for i in range(1, 121):
		var lv: = V10MjTriplesGen.build(i)
		var groups: = V10MjTriplesGen.magnet_groups(lv, 3)
		var ids: = []
		var same: = true
		for g in groups:
			ids.append_array(g)
			if (g as Array).size() != 3 or lv.faces[g[0]] != lv.faces[g[1]] or lv.faces[g[1]] != lv.faces[g[2]]:
				same = false
		check(groups.size() == 3 and same, "L%d magnet 3 triples" % i)
		var r: = V10MjTriplesRules.make(lv.pos, lv.faces)
		r.remove(ids)
		check(r.board_count() == lv.n - 9 and r.replay_rest(lv.order), "L%d magnet keeps certificate" % i)
	for i in range(3, 121, 4):
		var lv: = V10MjTriplesGen.build(i)
		var r: = V10MjTriplesRules.make(lv.pos, lv.faces)
		var k: = int(lv.n * 0.4)
		for s in k:
			r.pick(int(lv.order[s]))
		var rng: = RandomNumberGenerator.new()
		rng.seed = i
		var before_tray: = r.tray.duplicate()
		var bc: = _board_faces(r)
		var ok: = r.reshuffle(rng)
		check(ok, "L%d shuffle ok" % i)
		if not ok:
			continue
		check(bc == _board_faces(r) and r.tray == before_tray, "L%d shuffle keeps multiset" % i)
		check(r.replay_rest(r.last_shuffle_order), "L%d shuffle solvable" % i)


func _board_faces(r: V10MjTriplesRules) -> Dictionary:
	var bc: = {}
	for t in r.present.size():
		if r.present[t] == 1:
			bc[r.face[t]] = int(bc.get(r.face[t], 0)) + 1
	return bc


# 8. Приёмы (MODES §5.5)
func _t_ults() -> void:
	var lv: = V10MjTriplesGen.build(40)
	var base: = V10MjTriplesRules.make(lv.pos, lv.faces)
	for s in int(lv.n * 0.3):
		base.pick(int(lv.order[s]))
	if base.tray.is_empty():
		base.pick(base.frees[0])
	var expect: = {"mc": 1, "hana": 2, "yue": 1, "nova": 1, "rin": 0}
	for h in expect:
		var r: = base.clone()
		var p: = V10MjTriplesUlts.plan(h, r)
		var nt: = (p.triples as Array).size()
		check(nt == int(expect[h]), "ult %s triples %d" % [h, nt])
		if h == "rin":
			check(int(p.get("return", 0)) == mini(3, r.tray.size()), "ult rin returns tray")
		var faces_ok: = true
		for tri in p.triples:
			if (tri as Array).size() != 3 or r.face[tri[0]] != r.face[tri[1]] or r.face[tri[1]] != r.face[tri[2]]:
				faces_ok = false
		check(faces_ok, "ult %s triples same face" % h)
		V10MjTriplesUlts.apply(p, r)
		var cnt: = _board_faces(r)
		for t in r.tray:
			cnt[r.face[t]] = int(cnt.get(r.face[t], 0)) + 1
		var m3: = true
		for f in cnt:
			if int(cnt[f]) % 3 != 0:
				m3 = false
		check(m3, "ult %s keeps faces mod 3" % h)
		check(V10MjTriplesUlts.ult_name(h) != "", "ult %s name" % h)
	var pn: = V10MjTriplesUlts.plan("nova", base.clone())
	var pm: = V10MjTriplesUlts.plan("mc", base.clone())
	var depth: = func(ids: Array) -> int:
		var d: = 0
		for x in ids:
			if base.present[x] == 1:
				d += base.cnt[x]
		return d
	check(int(depth.call(pn.triples[0])) >= int(depth.call(pm.triples[0])), "nova deeper than mc")
	var r0: = V10MjTriplesRules.make(lv.pos, lv.faces)
	var p0: = V10MjTriplesUlts.plan("rin", r0)
	check(int(p0.get("return", 0)) == 0 and (p0.triples as Array).size() == 1, "rin on empty tray takes a triple")
	check(V10MjTriplesUlts.need(1) >= 4 and V10MjTriplesUlts.need(10) <= V10MjTriplesUlts.need(1), "ult need")


# 9. награды, звёзды, звук и вибрация
func _t_save_sound() -> void:
	check(V10MjTriplesSave.stars_for(true, false, 4) == 3, "3 stars clean calm")
	check(V10MjTriplesSave.stars_for(true, false, 6) == 2, "2 stars danger")
	check(V10MjTriplesSave.stars_for(true, true, 3) == 1, "1 star helped")
	check(V10MjTriplesSave.stars_for(false, false, 3) == 0, "0 stars loss")
	var rw: = V10MjTriplesSave.rewards(30, true, true)
	var pr: = V10MjTriplesSave.path_reward(30)
	check(int(rw.coins) == int(round(float(pr.coins) * 0.5)), "rewards = path x0.5")
	check(int(V10MjTriplesSave.rewards(30, false, false).coins) == 0, "no rewards on loss")
	var d: = V10MjTriplesSave.st({})
	var rec: = V10MjTriplesSave.record(d, 1, true, 3, 10)
	check(is_equal_approx(float(rec.salon_stars), 1.5), "salon stars x0.5")
	rec = V10MjTriplesSave.record(d, 1, true, 3, 10)
	check(float(rec.salon_stars) == 0.0, "no salon stars twice")
	check(is_equal_approx(V10MjTriplesSound.penta_hz(0, 0), 261.63), "C4 root")
	check(V10MjTriplesSound.penta_hz(3, 0) > V10MjTriplesSound.penta_hz(0, 0), "suit raises tone")
	check(V10MjTriplesSound.chord_steps(1) == [0, 2, 4] and V10MjTriplesSound.chord_steps(3) == [2, 4, 6], "chord steps rise with combo")
	check(V10MjTriplesSound.chord_steps(20) == [7, 9, 11], "chord cap")
	var w: = V10MjTriplesSound.pluck(V10MjTriplesSound.penta_hz(0, 0))
	check(w != null and w.data.size() > 1000, "pluck synth")
	var snd: = V10MjTriplesSound.new()
	snd.mute = true
	add_child(snd)
	snd.place(3)
	snd.triple(3, 1)
	check(snd.log_haptics.size() == 2 and snd.log_haptics[0] == ["tick", 15] and snd.log_haptics[1] == ["double", 12, 12], "haptics tick 15 / double 2x12")
	snd.queue_free()


# 10. слова: без запретного жаргона (UX_RULES §4.3), имена простые
const BANNED: = ["гарант", "пити", "pity", "гача", "ролл", "крутка", "фивер", "ивент", "перк", "ульта", "риичи", "яку",
	"донат", "успей", "последний шанс", "выгодно", "лихорадка", "богиня", "best", "new"]

func _t_words() -> void:
	var texts: = [V10MjTriplesInfo.INFO.name, V10MjTriplesInfo.INFO.line]
	for h in V10MjTriplesInfo.HOW:
		texts.append(h[1])
	texts.append_array(V10MjTriplesInfo.STARS_HOW)
	texts.append_array(V10MjTriplesSave.NAMES.values())
	for k in V10MjTriplesPresence.LINES:
		texts.append_array((V10MjTriplesPresence.LINES[k] as Dictionary).values())
	var bad: = []
	for t in texts:
		var lo: = String(t).to_lower()
		for b in BANNED:
			var rx: = RegEx.create_from_string("(^|[^a-zа-яё])" + b + "($|[^a-zа-яё])")
			if rx.search(lo) != null:
				bad.append(t)
	check(bad.is_empty(), "no banned words %s" % str(bad))
	check(V10MjTriplesInfo.INFO.id == "triples" and int(V10MjTriplesInfo.INFO.gate.level) == 14 and V10MjTriplesInfo.INFO.host == "hana" and V10MjTriplesInfo.INFO.shelf == "solitaire", "INFO contract")
	for k in V10MjTriplesSave.NAMES:
		check(String(V10MjTriplesSave.NAMES[k]).length() <= 18, "button name <= 18: %s" % k)


# 11. экран: святая зона, бюджет партии, поток (старт → 6/7 → помощь → Приём → тройка)
func _t_screen() -> void:
	var holder: = Node.new()
	add_child(holder)
	var s: = V10MjTriplesScreen.new()
	s.setup(null, {"level": 22, "hero": "rin", "demo": true, "start_sheet": false, "instant": true})
	holder.add_child(s)
	await get_tree().create_timer(0.6).timeout
	check(s.board != null and s.board.input_on, "screen ready, input on")
	check(s.lite.sacred_hits() == 0, "sacred zone clear at start")
	var taps: = 0
	var words: = 0
	var word_rx: = RegEx.create_from_string("[A-Za-zА-Яа-яЁё]")
	for n in _all(s):
		if n is BaseButton and (n as CanvasItem).is_visible_in_tree():
			taps += 1
		if n is Label and (n as CanvasItem).is_visible_in_tree() and (n as Label).modulate.a > 0.01 and n != s.lite._line and n != s.combo_lbl and n != s.banner:
			for w in String((n as Label).text).split(" ", false):
				if word_rx.search(w) != null:
					words += 1
	taps += 1   # окно героини (Приём)
	print("screen taps=%d words=%d" % [taps, words])
	check(taps <= 6, "play taps <= 6 (%d)" % taps)
	check(words <= 8, "play words <= 8 (%d)" % words)
	var hits_win: = 0
	for sr in s.sacred_rects():
		if s.lite.win_rect.intersects(sr.grow(8)):
			hits_win += 1
	check(hits_win == 0, "portrait window outside sacred zone")
	var r: = s.board.rules
	var guard: = 0
	while r.tray.size() < 6 and guard < 30:
		guard += 1
		var tc: = {}
		for t in r.tray:
			tc[r.face[t]] = int(tc.get(r.face[t], 0)) + 1
		var pick: = -1
		for i in r.frees:
			if not tc.has(r.face[i]):
				pick = i
				break
		if pick < 0:
			for i in r.frees:
				if int(tc.get(r.face[i], 0)) == 1:
					pick = i
					break
		if pick < 0:
			break
		s.board.tap(pick)
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.5).timeout
	check(r.tray.size() == 6 and not r.lost, "reached 6/7")
	check(s.lite.danger, "presence danger on 6/7")
	check(s.lite.events.has("danger"), "danger event sent")
	check(s.lite.sacred_hits() == 0, "sacred zone clear in danger (hits %d)" % s.lite.sacred_hits())
	s._use_help("return3")
	await get_tree().create_timer(0.4).timeout
	check(r.tray.size() == 3 and int(s.help_left.return3) == 0 and s.used_help, "help return3 used")
	check(not s.lite.danger, "danger off after return3")
	s.charge = s.need
	s._sync_charge()
	check(s.lite.ready_ult, "ult ready ring")
	await s._try_ult()
	await get_tree().create_timer(0.4).timeout
	check(r.tray.is_empty() and s.charge == 0, "rin ult returned tray")
	check(s.lite.events.has("ult"), "ult event")
	var before_pairs: = s.lite.events.count("pair")
	var by: = {}
	for i in r.frees:
		if not by.has(r.face[i]):
			by[r.face[i]] = []
		(by[r.face[i]] as Array).append(i)
	for f in by:
		if (by[f] as Array).size() >= 3:
			for k in 3:
				s.board.tap(by[f][k])
				await get_tree().create_timer(0.05).timeout
			break
	await get_tree().create_timer(1.0).timeout
	check(s.lite.events.count("pair") > before_pairs, "triple -> presence pair")
	check(s.lite.sacred_hits() == 0, "sacred zone clear after play")
	holder.queue_free()
	await get_tree().process_frame


func _all(n: Node) -> Array:
	var out: = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


# 12. снимки старт / 6/7 / победа в 720×1280 и 1080×2400 (если передана папка снимков)
func _t_shots() -> void:
	var dir: = String(args.get("mj_triples_shots", ""))
	if dir == "":
		print("shots: skipped (no --mj_triples_shots=<dir>)")
		return
	for tag in [["720", Vector2i(720, 1280)], ["1080", Vector2i(1080, 2400)]]:
		for nm in ["start", "danger", "win"]:
			var p: = "%s/triples_%s_%s.png" % [dir, tag[0], nm]
			var ok: = FileAccess.file_exists(p)
			if ok:
				var img: = Image.load_from_file(p)
				ok = img != null and img.get_size() == tag[1]
			check(ok, "shot %s" % p.get_file())
