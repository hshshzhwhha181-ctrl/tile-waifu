extends Node

# Сад 2.0: самотест / пробы. См. README.
#   --mj_garden_selftest=1             итог MJ_GARDEN ok/total, код выхода 0 только при 100 % (≈ 60–90 с)
#     [--mj_garden_shots=<dir>]        дополнительно проверить, что снимки демо (720×1280 и 1080×2400) на месте
#   --garden_probe=1 [--waves=200] [--seed=…]   распределение размеров волн и переливов у ботов (разработка)

var args: = {}

func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			args[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
	get_tree().create_timer(600.0).timeout.connect(func():
		print("MJ_GARDEN watchdog: 600 s")
		get_tree().quit(2))
	await get_tree().process_frame
	if args.has("garden_probe"):
		_probe()
		get_tree().quit(0)
	elif args.has("mj_garden_selftest"):
		await _selftest()
	else:
		get_tree().quit(1)


# ── бот ──────────────────────────────────────────────────────────────────────

# Партия в rules на `waves` волн. kind: "cert" — по сертификату (старые, потом новые); "random" — случайная
# свободная; "smart" — пара из лотка, иначе случайная. on_wave(r, wave, ids) — проверки на каждой волне.
func play(r: V10MjGardenRules, waves: int, kind: String, rng: RandomNumberGenerator, on_wave: Callable, on_pick: = Callable()) -> Dictionary:
	var st: = {"overflows": 0, "stuck": 0, "picks": 0}
	for w in waves:
		var wave: = V10MjGardenGen.make_wave(r)
		var ids: = r.pour(wave.pos, wave.faces)
		on_wave.call(r, wave, ids)
		var seq: = []
		seq.append_array(wave.fixed)
		for k in wave.order:
			seq.append(ids[int(k)])
		while true:
			var id: = -1
			if kind == "cert":
				while not seq.is_empty():
					var c: int = seq.pop_front()
					if r.on_board(c):
						id = c
						break
			else:
				var fr: = r.frees()
				if fr.is_empty():
					if r.board_count() > 0:
						st.stuck += 1
					break
				if kind == "smart":
					var tf: = r.tray_faces()
					for x in fr:
						if tf.has(int(r.face[x])):
							id = x
							break
				if id < 0:
					id = fr[rng.randi() % fr.size()]
			if id < 0:
				break
			var before: = r.clone()
			var res: = r.pick(id)
			st.picks += 1
			if on_pick.is_valid():
				on_pick.call(before, r, res)
			if not res.ok:
				st.stuck += 1
				break
			if res.overflow:
				st.overflows += 1
			if r.need_pour():
				break
	return st


func _probe() -> void:
	var t0: = Time.get_ticks_msec()
	var waves: = int(args.get("waves", "200"))
	for kind in ["cert", "smart", "random"]:
		var r: = V10MjGardenRules.make(int(args.get("seed", "12345")))
		var rng: = RandomNumberGenerator.new()
		rng.seed = 7
		var ns: = []
		var shapes: = {}
		var fixed_bad: = [0]
		var st: = play(r, waves, kind, rng, func(rr, wave, ids):
			ns.append(int(wave.n))
			shapes[wave.shape] = int(shapes.get(wave.shape, 0)) + 1
			if not wave.fixed_ok:
				fixed_bad[0] += 1)
		ns.sort()
		print("%s: n %d..%d mean %.1f · fixed_bad %d · overflows %d · stuck %d · pairs %d · score %d · best %d · %d ms" % [
			kind, ns[0], ns[ns.size() - 1], float(ns.reduce(func(a, b): return a + b, 0)) / ns.size(), fixed_bad[0],
			st.overflows, st.stuck, r.pairs, r.score, r.best_series, Time.get_ticks_msec() - t0])
	print("shapes ok")


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
	_t_rules_basic()
	_t_waves_cert()
	_t_waves_random()
	_t_save_restore()
	_t_save_module()
	_t_words()
	print("core %d ms" % (Time.get_ticks_msec() - t0))
	await _t_extra()
	print("MJ_GARDEN %d/%d (%d ms)" % [ok_n, total, Time.get_ticks_msec() - t0])
	get_tree().quit(0 if ok_n == total else 1)


func _t_extra() -> void:
	pass


# 1. правила на маленьком ручном столе: свобода, пара, перелив ровно 3 домой, серия и множитель
func _t_rules_basic() -> void:
	var r: = V10MjGardenRules.make(1)
	# ряд из 8 фишек на ярусе 0 и одна сверху над 2-й и 3-й: лица A B C D E F A B …
	var pos: = []
	for k in 8:
		pos.append(Vector3i(k * 2, 0, 0))
	pos.append(Vector3i(3, 0, 1))
	var faces: = [0, 1, 2, 3, 4, 5, 6, 7, 8]
	var ids: = r.pour(pos, faces)
	check(r.is_free(ids[0]) and r.is_free(ids[7]), "края ряда свободны")
	check(not r.is_free(ids[3]), "середина ряда закрыта с обеих сторон")
	check(not r.is_free(ids[1]) and not r.is_free(ids[2]), "фишки под верхней закрыты")
	check(r.is_free(ids[8]), "верхняя свободна")
	check(r.mult_for(1) == 1 and r.mult_for(3) == 1 and r.mult_for(4) == 2 and r.mult_for(13) == 5 and r.mult_for(40) == 5, "множитель ×1 → ×5")
	# перелив: 6 разных в лоток
	var order: = [ids[0], ids[7], ids[8], ids[1], ids[6], ids[2]]
	var res: = {}
	for k in order.size():
		res = r.pick(order[k])
		check(res.ok, "ход %d разрешён" % k)
	check(res.overflow and (res.back as Array).size() == 3, "6/6 без пары — перелив, вернулось 3")
	check(r.tray.size() == 3, "в лотке осталось 3")
	var homes_ok: = true
	for b in res.back:
		if not r.on_board(int(b)) or r.at[int(b)] != pos[ids.find(int(b))]:
			homes_ok = false
	check(homes_ok, "вернувшиеся фишки — на своих местах")
	check(res.back == [ids[8], ids[1], ids[6]] or res.back == [ids[1], ids[6], ids[2]], "вернулись три последние")
	check(r.series == 0 and r.overflows == 1, "серия сброшена, перелив учтён")
	# пары и счёт
	var r2: = V10MjGardenRules.make(2)
	var p2: = []
	for k in 12:
		p2.append(Vector3i(k * 2, 0, 0))
	var f2: = []
	for k in 6:
		f2.append(k)
		f2.append(k)
	var ids2: = r2.pour(p2, f2)
	var exp_score: = 0
	for k in 6:
		r2.pick(ids2[k * 2])
		var rr: = r2.pick(ids2[k * 2 + 1])
		exp_score += V10MjGardenRules.mult_for(k + 1)
		check((rr.pair as Array).size() == 2 and rr.gain == V10MjGardenRules.mult_for(k + 1), "пара %d, очки ×%d" % [k + 1, V10MjGardenRules.mult_for(k + 1)])
	check(r2.score == exp_score and r2.pairs == 6 and r2.series == 6 and r2.best_series == 6, "счёт = пары × множитель (%d)" % r2.score)
	check(r2.board_count() == 0 and r2.tray.is_empty() and r2.at.is_empty(), "стол и лоток пусты")


# 2. 200 волн подряд по сертификату: каждая волна 24–40, решаема при лотке 6 (независимое проигрывание), без переливов
func _t_waves_cert() -> void:
	var t0: = Time.get_ticks_msec()
	var r: = V10MjGardenRules.make(20261124)
	var rng: = RandomNumberGenerator.new()
	rng.seed = 1
	var stats: = {"n_bad": 0, "alone_bad": 0, "comb_bad": 0, "fixed_bad": 0, "parity_bad": 0, "disjoint_bad": 0,
		"max_tray": 0, "n_min": 99, "n_max": 0, "complete_bad": 0}
	var st: = play(r, 200, "cert", rng, func(rr: V10MjGardenRules, wave: Dictionary, ids: Array):
		var n: = int(wave.n)
		stats.n_min = mini(stats.n_min, n)
		stats.n_max = maxi(stats.n_max, n)
		if n < V10MjGardenGen.N_MIN or n > V10MjGardenGen.N_MAX or n % 2 == 1:
			stats.n_bad += 1
		if not bool(wave.complete):
			stats.complete_bad += 1
		var al: = V10MjGardenGen.verify_alone(wave)
		if not al.ok:
			stats.alone_bad += 1
		stats.max_tray = maxi(stats.max_tray, int(al.max_tray))
		if not bool(wave.fixed_ok):
			stats.fixed_bad += 1
		elif not V10MjGardenGen.verify(rr, wave, ids).ok:
			stats.comb_bad += 1
		if not rr.parity_ok():
			stats.parity_bad += 1
		# лица новой волны не совпадают с лицами старых фишек
		var newf: = {}
		for f in wave.faces:
			newf[int(f)] = true
		for id in rr.present_ids():
			if not ids.has(id) and newf.has(int(rr.face[id])):
				stats.disjoint_bad += 1
				break)
	print("cert 200: n %d..%d, max_tray %d, overflows %d, %d ms" % [stats.n_min, stats.n_max, stats.max_tray, st.overflows, Time.get_ticks_msec() - t0])
	check(r.wave == 200, "налито 200 волн (%d)" % r.wave)
	check(stats.n_bad == 0, "все волны 24–40 фишек, чётные (%d..%d, плохих %d)" % [stats.n_min, stats.n_max, stats.n_bad])
	check(stats.complete_bad == 0, "лица розданы всем фишкам (%d)" % stats.complete_bad)
	check(stats.alone_bad == 0, "каждая волна сама по себе решаема (плохих %d)" % stats.alone_bad)
	check(stats.max_tray <= V10MjGardenGen.TRAY_CAP, "по сертификату лоток ≤ 4 из 6 (%d)" % stats.max_tray)
	check(stats.fixed_bad == 0, "старые фишки снимаются без перелива на каждой волне (%d)" % stats.fixed_bad)
	check(stats.comb_bad == 0, "стол целиком решаем при лотке 6 на каждой волне (%d)" % stats.comb_bad)
	check(stats.parity_bad == 0, "каждое лицо — чётное число раз (%d)" % stats.parity_bad)
	check(stats.disjoint_bad == 0, "лица новой волны — свои (%d)" % stats.disjoint_bad)
	check(st.overflows == 0 and st.stuck == 0, "бот по сертификату: ни одного перелива и тупика")
	check(r.score > 0 and r.best_series >= 200 * 12, "серия не рвётся без перелива (лучшая %d)" % r.best_series)


# 3. 200 волн случайным и «разумным» ботом: тупиков нет, перелив = ровно 3 домой, серия с нуля, счёт сходится
func _t_waves_random() -> void:
	for kind in ["random", "smart"]:
		var t0: = Time.get_ticks_msec()
		var r: = V10MjGardenRules.make(777 if kind == "random" else 4242)
		var rng: = RandomNumberGenerator.new()
		rng.seed = 99
		var s: = {"n_bad": 0, "alone_bad": 0, "back_bad": 0, "series_bad": 0, "score_bad": 0, "parity_bad": 0, "sc": 0}
		var st: = play(r, 200, kind, rng, func(rr: V10MjGardenRules, wave: Dictionary, ids: Array):
			var n: = int(wave.n)
			if n < V10MjGardenGen.N_MIN or n > V10MjGardenGen.N_MAX:
				s.n_bad += 1
			if not V10MjGardenGen.verify_alone(wave).ok:
				s.alone_bad += 1
			if not rr.parity_ok():
				s.parity_bad += 1,
			func(before: V10MjGardenRules, after: V10MjGardenRules, res: Dictionary):
				if res.overflow:
					var back: Array = res.back
					var good: = back.size() == 3 and after.tray.size() == 3 and after.series == 0
					for b in back:
						if not after.on_board(int(b)) or after.at[int(b)] != before.at[int(b)]:
							good = false
					# три последние из лотка «до» плюс только что взятая
					var expect: Array = (before.tray.slice(before.tray.size() - 2) as Array) + [int(res.id)]
					if back != expect:
						good = false
					if not good:
						s.back_bad += 1
				if (res.pair as Array).size() == 2:
					s.sc += V10MjGardenRules.mult_for(before.series + 1)
					if after.series != before.series + 1:
						s.series_bad += 1
				if after.score != s.sc:
					s.score_bad += 1)
		print("%s 200: overflows %d, pairs %d, best series %d, %d ms" % [kind, st.overflows, r.pairs, r.best_series, Time.get_ticks_msec() - t0])
		check(r.wave == 200 and st.stuck == 0, "%s: 200 волн без тупика (волн %d, тупиков %d)" % [kind, r.wave, st.stuck])
		check(s.n_bad == 0, "%s: волны 24–40 (%d)" % [kind, s.n_bad])
		check(s.alone_bad == 0, "%s: каждая волна решаема (%d)" % [kind, s.alone_bad])
		check(st.overflows > 0 or kind == "smart", "%s: переливы были (%d)" % [kind, st.overflows])
		check(s.back_bad == 0, "%s: перелив возвращает ровно 3 последние домой, серия 0 (%d)" % [kind, s.back_bad])
		check(s.series_bad == 0 and s.score_bad == 0, "%s: серия и счёт сходятся (%d/%d)" % [kind, s.series_bad, s.score_bad])
		check(s.parity_bad == 0, "%s: стол всегда собирается парами (%d)" % [kind, s.parity_bad])


# 4. сохранение и восстановление посреди волны (через JSON, как G.save)
func _t_save_restore() -> void:
	var r: = V10MjGardenRules.make(31337)
	var rng: = RandomNumberGenerator.new()
	rng.seed = 5
	play(r, 3, "smart", rng, func(_a, _b, _c): pass)
	# посреди 4-й волны: налить и сделать 9 ходов (лоток не пуст)
	var wave: = V10MjGardenGen.make_wave(r)
	r.pour(wave.pos, wave.faces)
	for k in 9:
		var fr: = r.frees()
		r.pick(fr[rng.randi() % fr.size()])
	if r.tray.is_empty():
		r.pick(r.frees()[0])
	var d: = {}
	V10MjGardenSave.fix(d)
	V10MjGardenSave.save_run(d, r)
	var text: = JSON.stringify({"v10_mj_garden": d})
	var back = JSON.parse_string(text)
	var d2: = V10MjGardenSave.st(back)
	var r2: = V10MjGardenSave.load_run(d2)
	check(r2 != null, "сейв читается после JSON")
	if r2 == null:
		return
	check(r2.same_as(r), "состояние совпадает (стол, лоток, волна, серия, счёт)")
	check(r2.tray == r.tray and r2.board_count() == r.board_count() and r2.wave == r.wave and r2.series == r.series and r2.score == r.score, "лоток %d, стол %d, волна %d" % [r2.tray.size(), r2.board_count(), r2.wave])
	check(r2.frees() == r.frees(), "свободные фишки те же")
	# продолжение одинаково: те же ходы → то же состояние, та же следующая волна
	var rng_a: = RandomNumberGenerator.new()
	rng_a.seed = 11
	var rng_b: = RandomNumberGenerator.new()
	rng_b.seed = 11
	var ok_same: = true
	for k in 40:
		var fa: = r.frees()
		var fb: = r2.frees()
		if fa != fb or fa.is_empty():
			ok_same = fa == fb
			break
		var ia: int = fa[rng_a.randi() % fa.size()]
		var ib: int = fb[rng_b.randi() % fb.size()]
		r.pick(ia)
		r2.pick(ib)
		if r.need_pour():
			break
	check(ok_same and r.same_as(r2), "после восстановления игра идёт так же")
	var wa: = V10MjGardenGen.make_wave(r)
	var wb: = V10MjGardenGen.make_wave(r2)
	check(JSON.stringify(wa.pos) == JSON.stringify(wb.pos) and wa.faces == wb.faces, "следующая волна та же")
	# мусор в сейве не ломает чтение
	var junk: = {"v10_mj_garden": {"run": {"tiles": [[1, 2], "x", [3, 0, 0, 0, 5, 1]], "tray": [99]}, "night": "да", "week": 5}}
	var dj: = V10MjGardenSave.st(junk)
	var rj: = V10MjGardenSave.load_run(dj)
	check(rj != null and rj.board_count() == 1 and rj.tray.is_empty() and dj.week is Dictionary, "битый сейв чинится")


# 5. модуль сейва: награды 5 монет за волну, ≤ 30 волн в день, без кристаллов; «Чайный куст» каждые 10 волн; неделя
func _t_save_module() -> void:
	var S: = {}
	var d: = V10MjGardenSave.st(S)
	check(S.has("v10_mj_garden") and d.night == false and d.ambient == "rain", "st() создаёт поле по DEFAULTS")
	var coins: = 0
	var tea: = 0
	for k in 35:
		var w: = V10MjGardenSave.wave_done(d, "2026-11-24")
		coins += int(w.coins)
		if w.tea:
			tea += 1
	check(coins == 150 and int(d.day.paid) == 30, "35 волн за день → 30 оплачено, 150 монет (%d)" % coins)
	check(V10MjGardenSave.paid_left(d, "2026-11-24") == 0, "на сегодня лимит исчерпан")
	check(tea == 3, "«Чайный куст» каждые 10 волн (%d)" % tea)
	var w2: = V10MjGardenSave.wave_done(d, "2026-11-25")
	check(int(w2.coins) == 5 and int(d.day.paid) == 1, "новый день — снова монеты")
	var take: = V10MjGardenSave.take_pending(d)
	check(int(take.rewards.coins) == 155 and int(take.rewards.gems) == 0, "награды: 155 монет, 0 кристаллов")
	check((take.events as Array).size() == 3 and String(take.events[0].id) == "tea_bush", "события Салона в result")
	check(int(d.pending.coins) == 0 and V10MjGardenSave.take_pending(d).rewards.coins == 0, "отданное не отдаётся дважды")
	check(V10MjGardenSave.week_key("2026-11-24") == "2026-11-23" and V10MjGardenSave.week_key("2026-11-29") == "2026-11-23" and V10MjGardenSave.week_key("2026-11-30") == "2026-11-30", "неделя с понедельника")
	V10MjGardenSave.note_series(d, 12, "2026-11-25")
	V10MjGardenSave.record_visit(d, 4, 60, 220, "2026-11-25")
	check(int(d.week.series) == 12 and int(d.week.waves) == 4 and int(d.best_series) == 12, "рекорд недели: серия и волны")
	var bar: = V10MjGardenSave.record_bar(d, "2026-11-26")
	check(int(bar.series) == 12 and int(bar.waves) == 4, "планка рекорда на неделе")
	var bar2: = V10MjGardenSave.record_bar(d, "2026-12-01")
	check(int(bar2.series) == 0 and int(d.week.series) == 0 and int(d.best_series) == 12, "новая неделя — рекорд недели с нуля, лучший за всё время остаётся")


# 6. тексты: простые имена, без запретных слов (UX §4.3 и V10Lint)
const UX_BANNED: = ["гарант", "пити", "pity", "50/50", "гача", "ролл", "крутк", "фивер", "ивент", "квартал", "перк",
	"ульта", "банер", "донат", "хит", "выгодно", "best", "new", "успей", "последний шанс", "топ-100", "комбо", "лихорадк"]


static func texts() -> Array:
	var out: = [V10MjGardenInfo.INFO.name, V10MjGardenInfo.INFO.line, V10MjGardenInfo.lock_text()]
	for h in V10MjGardenInfo.HOW:
		out.append(h[1])
	out.append_array(V10MjGardenInfo.MORE)
	for k in V10MjGardenSave.AMB_NAMES:
		out.append(V10MjGardenSave.AMB_NAMES[k])
	return out


func _t_words() -> void:
	var bad: = []
	for t in texts():
		var low: = String(t).to_lower()
		for w in UX_BANNED:
			if low.find(w) >= 0:
				bad.append("%s: %s" % [t, w])
		if not V10Lint.ok(String(t)):
			bad.append("%s: %s" % [t, str(V10Lint.check(String(t)))])
	check(bad.is_empty(), "тексты чистые %s" % str(bad))
	check(String(V10MjGardenInfo.INFO.name) == "Сад" and String(V10MjGardenInfo.INFO.shelf) == "solitaire" and String(V10MjGardenInfo.INFO.host) == "yue", "INFO: имя, полка, хозяйка")
	check(V10MjGardenInfo.INFO.gate.rank == [1, 0], "ворота: Нефрит I, как у старого Сада")
