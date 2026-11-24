extends Node

# Самотест Лунного стола: --mj_sanma_selftest=1 [--games=200] [--shots=<dir>]
# Итог: «MJ_SANMA ok/total», код выхода 0 только при полном успехе. Сторож 600 с.
# Запуск: godot --headless --audio-driver Dummy --path game res://scripts/v10/mj/sanma/sanma_selftest.tscn -- --mj_sanma_selftest=1

var ok: = 0
var total: = 0
var fails: = []
var t0: = 0

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if s.begins_with("--" + k + "="):
			return s.split("=")[1]
	return d

func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		print("FAIL ", what)

func _ready() -> void:
	V10MjSanmaData.force_mem = true
	t0 = Time.get_ticks_msec()
	var wd: = Timer.new()
	wd.wait_time = 600.0
	wd.one_shot = true
	wd.timeout.connect(func():
		print("MJ_SANMA watchdog: timeout")
		print("MJ_SANMA %d/%d" % [ok, total + 1])
		get_tree().quit(1))
	add_child(wd)
	wd.start()
	await get_tree().process_frame
	_t_wall()
	_t_no_chi()
	_t_kita()
	_t_kita_score()
	_t_dora_map()
	_t_payments()
	_t_ai_kita()
	_t_landlord()
	_t_save()
	_t_text()
	await _t_sim(int(_arg("games", "200")))
	await _t_screen()
	_t_shots(_arg("shots", ""))
	for f in fails:
		print("  - ", f)
	print("MJ_SANMA %d/%d (%.1f s)" % [ok, total, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(0 if ok == total else 1)


# «123p456p789s11z» → id фишек (как parse в v08 selftest; 0 = красная пятёрка).
static func parse(txt: String) -> Array:
	var out: = []
	var digits: = []
	var used: = {}
	for ch in txt:
		if ch in "0123456789":
			digits.append(int(ch))
		else:
			var base: int = {"m": 0, "p": 9, "s": 18, "z": 27}[ch]
			for d in digits:
				var k: int = base + (4 if d == 0 else d - 1)
				var copy: = 0 if d == 0 else 1
				while used.has(k * 4 + copy) or (d != 0 and V8Mj.is_aka(k * 4 + copy)):
					copy += 1
				used[k * 4 + copy] = true
				out.append(k * 4 + copy)
			digits = []
	return out

func _mk(seed: int, human: = -1, opts: = {}) -> V10MjSanmaRound:
	var r: = V10MjSanmaRound.new()
	var pl: = []
	var ids: = ["yue", "rin", "hana", "mc", "nova"]
	for i in 3:
		pl.append({"id": ids[(seed + i) % ids.size()], "ctl": "human" if i == human else "ai"})
	var o: = {"seed": seed, "players": pl, "dealer": 0}
	o.merge(opts, true)
	r.setup(o)
	return r


func _t_wall() -> void:
	var r: = _mk(7)
	r.advance()
	var all: = r.wall
	check(all.size() == 108, "стена 108 (есть %d)" % all.size())
	var bad: = 0
	var aka: = 0
	var kinds: = {}
	for t in all:
		var k: int = t >> 2
		if k >= 1 and k <= 7:
			bad += 1
		if V8Mj.is_aka(t):
			aka += 1
		kinds[k] = kinds.get(k, 0) + 1
	check(bad == 0, "нет 2–8m в стене")
	check(aka == 2 and not (16 in all), "красные только 5p и 5s")
	check(kinds.size() == 27, "27 видов фишек")
	var uniq: = {}
	for t in all:
		uniq[t] = true
	check(uniq.size() == 108, "фишки не повторяются")
	check(r.hands[0].size() == 13 and r.hands[1].size() == 13 and r.hands[2].size() == 13 and r.hands[3].is_empty(), "раздача 13×3, место 3 пустое")
	check(r.wall_left() == 108 - 14 - 39, "живая стена 55 после раздачи (есть %d)" % r.wall_left())
	check(r.seat_wind(0) == 27 and r.seat_wind(1) == 28 and r.seat_wind(2) == 29, "ветра мест: Восток, Юг, Запад")


func _t_no_chi() -> void:
	var r: = _mk(11)
	r.advance()
	r.hands[1] = parse("45p") + parse("19s19m1234567z")
	r.last_discard = parse("3p")[0]
	r.last_from = 0
	var co: = r.call_options(1)
	check(co.chi.is_empty(), "чи не предлагается следующему за сбросившим")
	var a: Dictionary = V10MjSanmaAI.decide_call(r, 1, {"ron": false, "pon": false, "kan": false, "chi": [[parse("4p")[0], parse("5p")[0]]]})
	check(a.get("a", "") != "chi", "ИИ не объявляет чи, даже если ему подсунули вариант")


func _t_kita() -> void:
	var r: = _mk(21, 0)
	var ev: = r.advance()
	check(ev.ev == "deal", "раздача")
	var hand: = parse("19m19p19s12356z") + parse("77z")
	r.hands[0] = V8Mj.sort_tiles(hand)
	r.wall[r.pos] = parse("4z")[0]
	ev = r.advance()
	check(ev.ev == "draw" and (ev.tile >> 2) == 30, "добор Севера")
	ev = r.advance()
	check(ev.get("kind", "") == "turn" and ev.opts.get("kita", false), "в опциях хода есть «Север · кита»")
	var le0: = r.live_end
	var n_north0: = 0
	for t in r.hands[0]:
		if t >> 2 == 30:
			n_north0 += 1
	r.answer({"a": "kita"})
	ev = r.advance()
	check(ev.ev == "kita" and ev.seat == 0 and r.kita[0].size() == 1, "кита откладывает Север")
	var n_north1: = 0
	for t in r.hands[0]:
		if t >> 2 == 30:
			n_north1 += 1
	check(n_north1 == n_north0 - 1 and r.hands[0].size() == 13, "Север ушёл из руки (13 фишек)")
	ev = r.advance()
	while ev.ev == "noop":
		ev = r.advance()
	check(ev.ev == "draw" and ev.rinshan and ev.get("from", "") == "kita", "добор с мёртвой стены после кита")
	check(r.hands[0].size() == 14 and r.live_end == le0 - 1, "рука 14, мёртвая стена пополнена из живой")
	check(r.kita_dora_each() >= 1, "Север считается дорой")
	# в риичи кита можно только вытянутым Севером
	r.riichi[0] = true
	r.drawn = parse("9s")[0]
	check(not r.can_kita(0) or (r.drawn >> 2) == 30, "в риичи кита только вытянутым Севером")
	r.riichi[0] = false


func _ev_hand(r: V10MjSanmaRound, closed: String, win: String, tsumo: bool) -> Dictionary:
	var cl: = parse(closed)
	r.hands[0] = cl.duplicate()
	var w: int = cl[cl.size() - 1]
	for t in cl:
		if t >> 2 == parse(win)[0] >> 2:
			w = t
	if not tsumo:
		r.hands[0].erase(w)
	r.after_kan = false
	r.first_go = [false, false, false, false]
	return r.win_eval(0, w, tsumo)

func _t_kita_score() -> void:
	var r: = _mk(31)
	r.advance()
	r.melds[0] = []
	r.riichi[0] = false
	r.dora_ind = [parse("2s")[0]]
	r.ura_ind = [parse("2s")[0]]
	var e0: = _ev_hand(r, "111m999m123p456p11s", "1s", true)
	check(not e0.is_empty() and e0.han >= 1, "базовая рука цумо оценивается")
	r.kita[0] = [parse("4z")[0]]
	var e1: = _ev_hand(r, "111m999m123p456p11s", "1s", true)
	check(e1.han == e0.han + 1 and e1.kita == 1 and e1.kita_han == 1, "1 Север = +1 дора (%d→%d)" % [e0.han, e1.han])
	r.kita[0] = [parse("4z")[0], parse("44z")[1]]
	r.dora_ind = [parse("3z")[0]]
	var e2: = _ev_hand(r, "111m999m123p456p11s", "1s", true)
	check(e2.kita_han == 4, "2 Севера при индикаторе Запад = +4 (есть %d)" % e2.kita_han)
	r.kita[0] = [parse("4z")[0]]
	r.dora_ind = [parse("2s")[0]]
	var e3: = _ev_hand(r, "123p456p789p11s22s", "2s", false)
	check(e3.is_empty() or e3.han == 0, "Север не создаёт комбинацию (рон без яку = 0)")
	check(e1.base >= e0.base, "Северы поднимают цену")


func _t_dora_map() -> void:
	var r: = _mk(41)
	r.advance()
	r.dora_ind = [parse("1m")[0]]
	check(r.dora_kinds() == [8], "индикатор 1m → дора 9m")
	r.dora_ind = [parse("9m")[0]]
	check(r.dora_kinds() == [0], "индикатор 9m → дора 1m")
	r.melds[0] = []
	r.kita[0] = []
	r.dora_ind = [parse("1m")[0]]
	r.ura_ind = [parse("2s")[0]]
	var e: = _ev_hand(r, "111m999m123p456p11s", "1s", true)
	check(int(e.get("dora", 0)) == 3, "три 9m при индикаторе 1m = 3 доры (есть %s)" % str(e.get("dora", -1)))


func _t_payments() -> void:
	var r: = _mk(51)
	r.advance()
	r.honba = 0
	r.dealer = 0
	var d: = r.pay_delta(1, -1, 2000)
	check(d[1] == 8000 and d[0] == -5000 and d[2] == -3000, "цумо не-дилера без потери: 5000/3000 = 8000 (%s)" % str(d))
	d = r.pay_delta(0, -1, 2000)
	check(d[0] == 12000 and d[1] == -6000 and d[2] == -6000, "цумо дилера без потери: 6000 ×2")
	r.tsumo_loss = true
	d = r.pay_delta(1, -1, 2000)
	check(d[1] == 6000, "флаг tsumo_loss: 4000+2000 (как на четверых)")
	r.tsumo_loss = false
	d = r.pay_delta(2, 1, 2000)
	check(d[2] == 8000 and d[1] == -8000 and d[0] == 0, "рон 8000 платит только набросивший")
	var s: = 0
	for x in d:
		s += x
	check(s == 0, "платёж не создаёт очков")


func _t_ai_kita() -> void:
	var r: = _mk(61)
	r.advance()
	r.hands[1] = V8Mj.sort_tiles(parse("444z19m19p19s123z") + parse("5z"))
	r.drawn = r.hands[1][r.hands[1].size() - 1]
	var o: = {"kita": true, "tsumo": false}
	check(not V10MjSanmaAI.want_kita(r, 1, o), "ИИ держит Север-тройку")
	r.hands[1] = V8Mj.sort_tiles(parse("4z19m19p19s1235z") + parse("6z"))
	check(V10MjSanmaAI.want_kita(r, 1, o), "ИИ откладывает одиночный Север")


func _t_landlord() -> void:
	var L: = V10MjSanmaLandlord.new().setup(1, "yue", 99)
	var seen: = {}
	for i in 200:
		seen[L.declare()] = true
	check(seen.has(2) and seen.has(3) and seen.size() == 2, "хозяйка объявляет только ×2 или ×3")
	check(V10MjSanmaLandlord.p_triple(V8AI.STYLES.yue) > V10MjSanmaLandlord.p_triple(V8AI.STYLES.hana), "стиль: Юэ чаще ×3, чем Хана")
	L.declare()
	var m0: = L.mult
	L.on_engine({"ev": "kita"})
	L.on_engine({"ev": "call", "type": "ankan"})
	L.on_engine({"ev": "call", "type": "pon"})
	check(L.mult == m0 * 4, "кан и Север удваивают, пон нет")
	for i in 20:
		L.double("kan")
	check(L.mult == V10MjSanmaLandlord.CAP, "потолок множителя")
	var d: = L.settle({"ev": "win", "seat": 0, "delta": [8000, 0, -8000, 0]})
	check(d[0] + d[1] + d[2] == 0 and d[1] < 0 and d[0] > 0 and d[2] > 0, "двое выиграли у хозяйки: сумма 0")
	check(V10MjSanmaData.rewards(1, true) == V10MjSanmaData.rewards(1, true) and V10MjSanmaData.rewards(1, false).coins == 32, "награды ×0,8: 1-е место 32 монеты")
	check(V10MjSanmaData.rewards(2, false).coins == 20 and V10MjSanmaData.rewards(3, false).coins == 12 and V10MjSanmaData.rewards(1, true).gems == 16, "2-е 20, 3-е 12, первая партия дня 16 кр")


func _t_save() -> void:
	V10MjSanmaData._mem = {}
	var d: = V10MjSanmaData.st()
	check(d.has("best_hand") and d.has("event") and d.places.size() == 3, "сейв v10_mj_sanma с DEFAULTS")
	var res: = {"ev": "win", "seat": 0, "delta": [12000, -6000, -6000, 0], "sticks": 0, "eval": {"han": 5, "fu": 30, "limit": "Манган", "yaku": [["tsumo", 1]], "kita": 2, "base": 2000}}
	check(V10MjSanmaData.note_hand(res, 0, 5, "2026-11-24"), "рекорд «дороже всего за руку» пишется")
	res.delta = [3000, -1500, -1500, 0]
	check(not V10MjSanmaData.note_hand(res, 0, 6, "2026-11-24"), "рекорд не перезаписывается дешёвой рукой")
	check(int(V10MjSanmaData.st().best_hand.pts) == 12000 and int(V10MjSanmaData.st().best_hand.kita) == 2, "рекорд хранит очки и северы")
	var rw: = V10MjSanmaData.note_match({"place": [1, 2, 3], "scores": [50000, 30000, 25000]}, 0, 3, "2026-11-24")
	check(rw.coins == 32 and rw.gems == 16, "первая партия дня: 32 монеты + 16 кр")
	rw = V10MjSanmaData.note_match({"place": [1, 2, 3], "scores": [50000, 30000, 25000]}, 0, 0, "2026-11-24")
	check(rw.gems == 0, "вторая партия за день без кристаллов")


func _t_text() -> void:
	var bad: = V10MjSanmaText.lint(V10MjSanmaText.all_visible())
	check(bad.is_empty(), "тексты без стоп-слов %s" % str(bad))
	var probe: = V10MjSanmaText.lint(["Лучший донат", "ульта готова"])
	check(probe.size() == 2, "линтер ловит стоп-слова")
	var long_btn: = 0
	for k in V10MjSanmaText.BTN:
		var b: Array = V10MjSanmaText.BTN[k]
		if (b[0] + " · " + b[1]).length() > 18:
			long_btn += 1
	check(long_btn == 0, "кнопки ≤ 18 символов")
	check(V10MjSanmaInfo.INFO.id == "sanma" and V10MjSanmaInfo.INFO.shelf == "table" and V10MjSanmaInfo.INFO.host == "yue" and V10MjSanmaInfo.INFO.gate.table_games == 3, "INFO по контракту")
	check(not V10MjSanmaInfo.unlocked(2) and V10MjSanmaInfo.unlocked(3), "открытие после 3 партий за столом")


func _t_sim(games: int) -> void:
	var hangs: = 0
	var conserve_bad: = 0
	var chi_seen: = 0
	var kitas: = 0
	var kans: = 0
	var wins: = 0
	var draws: = 0
	var ends: = 0
	var ev_only_bad: = 0
	var ev_sum_bad: = 0
	var kita_hand_wins: = 0
	var max_mult: = 0
	var short_games: = 0
	var t_start: = Time.get_ticks_msec()
	for g in games:
		var seed: = 1000 + g * 7919
		var r: = _mk(seed, -1, {"dealer": g % 3, "tsumo_loss": g % 10 == 9})
		var L: = V10MjSanmaLandlord.new().setup(g % 3, ["yue", "rin", "hana", "mc", "nova"][g % 5], seed)
		var total0: = r.total_points()
		var steps: = 0
		var done: = false
		var dealers_seen: = {}
		while steps < 40000:
			steps += 1
			var ev: = r.advance()
			match ev.ev:
				"deal":
					L.declare()
					dealers_seen[r.kyoku] = true
				"kita", "call":
					L.on_engine(ev)
					if ev.ev == "kita":
						kitas += 1
					elif String(ev.type) in ["ankan", "minkan", "kakan"]:
						kans += 1
					elif ev.type == "chi":
						chi_seen += 1
				"win", "draw_end":
					if ev.ev == "win":
						wins += 1
						if int(ev.eval.get("kita", 0)) > 0:
							kita_hand_wins += 1
					else:
						draws += 1
					var before: = r.scores.duplicate()
					L.settle(ev)
					max_mult = maxi(max_mult, L.mult)
					if r.scores != before:
						ev_only_bad += 1
					if L.ev_score[0] + L.ev_score[1] + L.ev_score[2] != 0:
						ev_sum_bad += 1
					if r.total_points() != total0:
						conserve_bad += 1
				"match_end":
					ends += 1
					done = true
					var bust: = false
					for x in r.scores.slice(0, 3):
						if x < 0:
							bust = true
					if dealers_seen.size() < 3 and not bust:
						short_games += 1
				"ask":
					hangs += 1
					done = true
			if done:
				break
		if not done:
			hangs += 1
		if g % 25 == 24:
			await get_tree().process_frame
	var ms: = Time.get_ticks_msec() - t_start
	print("SIM games=%d ends=%d wins=%d draws=%d kita=%d kans=%d kita_wins=%d max_mult=×%d %.1f s" % [games, ends, wins, draws, kitas, kans, kita_hand_wins, max_mult, ms / 1000.0])
	check(hangs == 0 and ends == games, "%d партий ИИ×3 без зависаний (зависло %d)" % [games, hangs])
	check(conserve_bad == 0, "сумма очков сохраняется в каждой раздаче (нарушений %d)" % conserve_bad)
	check(chi_seen == 0, "в симуляции ни одного чи")
	check(short_games == 0, "«Восток» играется до конца: все 3 раздачи, если никто не ушёл в минус (коротких %d)" % short_games)
	check(kitas > 0 and kita_hand_wins > 0, "кита случается и учитывается в победах (%d/%d)" % [kitas, kita_hand_wins])
	check(ev_only_bad == 0, "множитель события не трогает очки стола")
	check(ev_sum_bad == 0, "счёт события с нулевой суммой")
	# детерминизм: тот же сид — та же партия
	check(_replay(4242) == _replay(4242), "тот же сид даёт ту же партию")

func _replay(seed: int) -> Array:
	var r: = _mk(seed)
	var steps: = 0
	while steps < 40000:
		steps += 1
		var ev: = r.advance()
		if ev.ev == "match_end":
			return ev.result.scores
	return []


# Экран: кита как событие presence, ввод свободен; кнопка «Север · кита» в ряду решений.
func _t_screen() -> void:
	var sc: Control = load("res://scripts/v10/mj/sanma/sanma_screen.gd").new()
	sc.size = Vector2(720, 1280)
	add_child(sc)
	var pres: = V10MjSanmaPresenceProbe.new()
	sc.setup(null, {"seed": 777, "presence": pres, "event": true, "fast": true})
	await get_tree().process_frame
	check(sc.seats == 3, "экран на 3 места")
	var got_ask: = false
	for i in 3000:
		sc.pump_once()
		if sc.waiting_input():
			if sc.cur_ask.get("kind", "") == "turn":
				got_ask = true
				break
			sc._demo_answer()
	check(got_ask, "экран дошёл до решения игрока")
	# форсируем ситуацию кита для игрока
	var ok_kita: bool = sc.debug_force_kita()
	check(ok_kita and sc.has_button("kita"), "кнопка «Север · кита» в ряду решений")
	check(not sc.has_button("chi"), "кнопки чи нет")
	sc.press("kita")
	for i in 4:
		sc.pump_once()
	check(pres.count("kita") >= 1, "событие presence kita отправлено")
	check(pres.max_block <= 0.3 + 0.001, "кита не блокирует ввод дольше 0,3 с")
	var rects: Array = pres.sacred_rects
	check(rects.size() >= 3, "святая зона передана (рука, кнопки, сброс)")
	var host_r: Rect2 = sc.host_portrait_rect()
	var hit: = false
	for rr in rects:
		if Rect2(rr).grow(8).intersects(host_r):
			hit = true
	check(not hit, "портрет хозяйки вне святой зоны")
	var ev_r: Rect2 = sc.event_board_rect()
	var hit2: = false
	for rr in rects:
		if Rect2(rr).grow(8).intersects(ev_r):
			hit2 = true
	check(not hit2 and ev_r.size.x > 0, "табло множителя у края, вне святой зоны")
	check(sc.ux_tappables() <= 6, "в партии ≤ 6 тапаемых без руки (есть %d)" % sc.ux_tappables())
	sc.queue_free()
	await get_tree().process_frame


func _t_shots(dir: String) -> void:
	if dir == "":
		print("NOTE shots: --shots не задан, снимки не проверены")
		return
	for nm in ["sanma_720x1280_table.png", "sanma_1080x2400_table.png"]:
		var p: = dir.path_join(nm)
		var ex: = FileAccess.file_exists(p)
		var okd: = false
		if ex:
			var img: = Image.load_from_file(p)
			okd = img != null and img.get_width() in [720, 1080]
		check(ex and okd, "снимок %s" % nm)
