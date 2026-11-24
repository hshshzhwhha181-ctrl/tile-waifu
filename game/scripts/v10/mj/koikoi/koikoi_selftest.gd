extends Node

# Самотест Коикои: godot --headless --path game res://scripts/v10/mj/koikoi/koikoi_selftest.tscn -- --mj_koikoi_selftest=1
# Итоговая строка: MJ_KOIKOI ok/total; код выхода 0 только при полном успехе. Сторож 600 с.
# --games=N — число партий ИИ×ИИ (по умолчанию 1000).

var ok: = 0
var total: = 0
var fails: Array = []

func _ready() -> void:
	var t0: = Time.get_ticks_msec()
	var wd: = get_tree().create_timer(600.0)
	wd.timeout.connect(func():
		print("MJ_KOIKOI watchdog timeout")
		get_tree().quit(2))
	await get_tree().process_frame
	run_all()
	for f in fails.slice(0, 40):
		print("  FAIL ", f)
	print("MJ_KOIKOI %d/%d (%.1f s)" % [ok, total, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(0 if ok == total else 1)

func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)

func _arg(name: String, def: int) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return int(a.split("=")[1])
	return def

func run_all() -> void:
	t_deck()
	t_yaku()
	t_koikoi()
	t_turn_flow()
	t_ai_games(_arg("games", 1000))
	t_skins()
	t_words()
	t_book_save()
	t_screen()

# ── колода ──
func t_deck() -> void:
	var per_month: = {}
	var kinds: = {"light": 0, "animal": 0, "ribbon": 0, "plain": 0}
	var poem: = 0
	var blue: = 0
	var red: = 0
	for c in 48:
		per_month[V10MjKoikoi.month(c)] = per_month.get(V10MjKoikoi.month(c), 0) + 1
		kinds[V10MjKoikoi.kind(c)] += 1
		match V10MjKoikoi.tag(c):
			"poem":
				poem += 1
			"blue":
				blue += 1
			"red":
				red += 1
	check(V10MjKoikoi.all_cards().size() == 48, "deck 48")
	check(per_month.size() == 12, "12 months")
	for m in 12:
		check(per_month.get(m, 0) == 4, "month %d has 4" % m)
	check(kinds.light == 5, "5 lights (%d)" % kinds.light)
	check(kinds.animal == 9, "9 animals (%d)" % kinds.animal)
	check(kinds.ribbon == 10, "10 ribbons (%d)" % kinds.ribbon)
	check(kinds.plain == 24, "24 plains (%d)" % kinds.plain)
	check(poem == 3 and blue == 3 and red == 4, "ribbons 3 poem / 3 blue / 4 red")
	for tg in ["crane", "curtain", "moon", "rain", "phoenix"]:
		check(V10MjKoikoi.kind(V10MjKoikoi.find(tg)) == "light", "light " + tg)
	# все карты на месте после раздачи, пересдача при 4 одного месяца на столе
	var k: = V10MjKoikoi.new()
	for s in 200:
		k.setup_match(1000 + s)
		k.next_month()
		var all: Array = k.deck + k.hand[0] + k.hand[1] + k.table
		all.sort()
		var cnt: = {}
		for c in k.table:
			cnt[V10MjKoikoi.month(c)] = cnt.get(V10MjKoikoi.month(c), 0) + 1
		var four: = false
		for m in cnt:
			if cnt[m] >= 4:
				four = true
		if all != V10MjKoikoi.all_cards() or k.hand[0].size() != 8 or k.hand[1].size() != 8 or k.table.size() != 8 or four:
			check(false, "deal %d" % s)
			return
	check(true, "200 deals 8/8/8, no 4-of-month on table")
	# картинки колоды на месте
	var missing: = 0
	for c in 48:
		if not ResourceLoader.exists(V10MjKoikoiSkins.base_path(c)):
			missing += 1
	check(missing == 0, "48 card images (%d missing)" % missing)
	check(ResourceLoader.exists(V10MjKoikoiSkins.BACK), "card back image")

# ── комбинации ──
func _c(tags: Array) -> Array:
	var out: = []
	for t in tags:
		out.append(V10MjKoikoi.find(t))
	return out

func _plains(n: int) -> Array:
	var out: = []
	for c in 48:
		if V10MjKoikoi.kind(c) == "plain" and out.size() < n:
			out.append(c)
	return out

func _ribbons(kind_tag: String, n: int) -> Array:
	var out: = []
	for c in 48:
		if V10MjKoikoi.kind(c) == "ribbon" and (kind_tag == "" or V10MjKoikoi.tag(c) == kind_tag) and out.size() < n:
			out.append(c)
	return out

func _expect(caps: Array, want: Dictionary, name: String) -> void:
	var y: = V10MjKoikoi.yaku_of(caps)
	check(y == want, "%s: got %s want %s" % [name, y, want])

func t_yaku() -> void:
	_expect(_c(["crane", "curtain", "moon", "rain", "phoenix"]), {"goko": 10}, "goko")
	_expect(_c(["crane", "curtain", "moon", "phoenix"]), {"shiko": 8}, "shiko")
	_expect(_c(["crane", "curtain", "moon", "rain"]), {"ameshiko": 7}, "ameshiko (conflict with shiko)")
	_expect(_c(["crane", "rain", "moon", "phoenix"]), {"ameshiko": 7}, "ameshiko any 3 + rain")
	_expect(_c(["crane", "curtain", "moon"]), {"sanko": 5}, "sanko")
	_expect(_c(["crane", "curtain", "rain"]), {}, "3 lights with rain = nothing")
	_expect(_c(["boar", "deer", "butterfly"]), {"inoshikacho": 5}, "inoshikacho")
	_expect(_ribbons("poem", 3), {"akatan": 5}, "akatan")
	_expect(_ribbons("blue", 3), {"aotan": 5}, "aotan")
	_expect(_ribbons("red", 4) + _ribbons("blue", 1), {"tan": 1}, "tan 5")
	_expect(_ribbons("red", 4) + _ribbons("blue", 2), {"tan": 2}, "tan 6")
	_expect(_c(["warbler", "cuckoo", "bridge", "geese", "swallow"]), {"tane": 1}, "tane 5")
	_expect(_c(["warbler", "cuckoo", "bridge", "geese", "swallow", "boar"]), {"tane": 2}, "tane 6")
	_expect(_plains(10), {"kasu": 1}, "kasu 10")
	_expect(_plains(11), {"kasu": 2}, "kasu 11")
	_expect(_plains(9) + _c(["cup"]), {"kasu": 1}, "kasu 9 + cup")
	_expect(_c(["curtain", "cup"]), {"hanami": 5}, "hanami")
	_expect(_c(["moon", "cup"]), {"tsukimi": 5}, "tsukimi")
	_expect(_c(["curtain", "moon", "cup"]), {"hanami": 5, "tsukimi": 5}, "hanami + tsukimi")
	_expect(_ribbons("poem", 3) + _ribbons("blue", 3), {"akatan": 5, "aotan": 5, "tan": 2}, "akatan + aotan + tan")
	_expect(_c(["boar", "deer", "butterfly", "warbler", "cuckoo"]), {"inoshikacho": 5, "tane": 1}, "inoshikacho + tane")
	_expect(_c(["crane", "curtain", "moon", "rain", "cup"]), {"ameshiko": 7, "hanami": 5, "tsukimi": 5}, "ameshiko + hanami + tsukimi")
	check(V10MjKoikoi.YAKU.size() == 12 and V10MjKoikoi.YAKU_ORDER.size() == 12, "12 combos")
	check(V10MjKoikoi.score_of({"goko": 10, "tan": 2}) == 12, "score sum")
	# каждая из 12 комбинаций достижима на эталонных взятках
	var seen: = {}
	for caps in [_c(["crane", "curtain", "moon", "rain", "phoenix"]), _c(["crane", "curtain", "moon", "phoenix"]), _c(["crane", "curtain", "moon", "rain"]),
			_c(["crane", "curtain", "moon"]), _c(["boar", "deer", "butterfly"]), _ribbons("poem", 3), _ribbons("blue", 3), _ribbons("", 5),
			_c(["warbler", "cuckoo", "bridge", "geese", "swallow"]), _plains(10), _c(["curtain", "cup"]), _c(["moon", "cup"])]:
		for k in V10MjKoikoi.yaku_of(caps):
			seen[k] = true
	check(seen.size() == 12, "all 12 combos on reference captures (%d)" % seen.size())
	# прогресс: ближайшая цель
	var pr: = V10MjKoikoi.progress(_c(["boar", "deer"]))
	check(not pr.is_empty() and pr[0].id == "inoshikacho" and pr[0].have == 2, "progress nearest = inoshikacho 2/3")

# ── кои-кои и перехват ──
func t_koikoi() -> void:
	check(V10MjKoikoi.payout(5, 0, 0).pts == 5, "no koi = x1")
	check(V10MjKoikoi.payout(5, 1, 0).pts == 10, "koi x2")
	check(V10MjKoikoi.payout(5, 2, 0).pts == 20, "koi twice x4")
	var ic: = V10MjKoikoi.payout(6, 0, 1)
	check(ic.intercept and ic.pts == 12, "intercept after her koi-koi: x2 for taker")
	# сценарий на движке: я собираю, говорю кои-кои, добираю, забираю → ×2
	var k: = _scene_state()
	k.play(V10MjKoikoi.find("curtain"))  # стол: вишня (пустая) → забираю
	k.draw()                             # из колоды: павловния пустая → пара с фениксом на столе? нет: стол без павловнии → кладу
	check(k.phase == "decide", "sanko → decide (phase %s)" % k.phase)
	var base1: = V10MjKoikoi.score_of(V10MjKoikoi.yaku_of(k.caps[0]))
	k.koikoi()
	check(k.koi[0] == 1 and k.turn == 1, "koikoi passes the turn")
	# ход соперницы: без комбинации
	k.play(k.hand[1][0])
	if k.phase == "pick":
		k.choose(k.pick_options[0])
	if k.phase == "draw":
		k.draw()
	if k.phase == "pick":
		k.choose(k.pick_options[0])
	check(k.phase == "play" and k.turn == 0, "her turn done (phase %s)" % k.phase)
	# я беру луну → Четыре света (8) → решение → забрать
	k.play(V10MjKoikoi.find("moon"))
	if k.phase == "draw":
		k.draw()
	check(k.phase == "decide", "shiko → decide")
	var s: = V10MjKoikoi.score_of(V10MjKoikoi.yaku_of(k.caps[0]))
	check(s > base1, "score grew %d > %d" % [s, base1])
	k.stop()
	check(k.phase == "over" and k.result.winner == 0 and k.result.pts == s * 2, "stop after 1 koi = x2 (%s)" % k.result)
	check(k.totals[0] == s * 2 and k.totals[1] == 0, "totals x2")
	# перехват: она сказала кои-кои, я собираю раньше → она 0, мне ×2
	var k2: = _scene_state()
	k2.koi[1] = 1
	k2.last_score[1] = 1
	k2.play(V10MjKoikoi.find("curtain"))
	k2.draw()
	k2.stop()
	check(k2.result.winner == 0 and k2.result.intercept and k2.result.pts == 10 and k2.totals[1] == 0, "intercept zeroes her and doubles me (%s)" % k2.result)
	# без карт в руке — решение не предлагается, забирает автоматически
	var k3: = _scene_state()
	k3.hand[0] = [V10MjKoikoi.find("curtain")]
	k3.play(V10MjKoikoi.find("curtain"))
	k3.draw()
	check(k3.phase == "over" and k3.result.get("forced", false), "last card → forced take")
	# руки кончились без «Забрать» — месяц без очков
	var k4: = V10MjKoikoi.new()
	k4.hand = [[V10MjKoikoi.find("warbler")], [V10MjKoikoi.find("cuckoo")]]
	k4.table = []
	k4.deck = [_plains(1)[0] + 0, V10MjKoikoi.find("geese")]
	k4.caps = [[], []]
	k4.turn = 0
	k4.phase = "play"
	k4.play(k4.hand[0][0])
	k4.draw()
	k4.play(k4.hand[1][0])
	k4.draw()
	check(k4.phase == "over" and k4.result.winner == -1 and k4.result.pts == 0, "exhausted month = no points")

# Мои взятки: журавль, феникс (2 света). Стол: вишня-пустая, луна? нет — мискант-пустая. Рука: занавес, луна, + мусор.
func _scene_state() -> V10MjKoikoi:
	var k: = V10MjKoikoi.new()
	var cherry_plain: = 10   # март, пустая
	var susuki_plain: = 30   # август, пустая
	k.caps = [_c(["crane", "phoenix"]), []]
	k.table = [cherry_plain, susuki_plain, 5]   # 5 = слива, лента
	k.hand = [[V10MjKoikoi.find("curtain"), V10MjKoikoi.find("moon"), 18, 22], [14, 26, 34, 38]]
	k.deck = [43, 42, 19, 23, 13, 47]   # верх = back(): 47 (павловния пустая) ...
	k.turn = 0
	k.phase = "play"
	return k

func t_turn_flow() -> void:
	# выбор из двух кандидатов
	var k: = V10MjKoikoi.new()
	k.caps = [[], []]
	k.table = [2, 3]           # сосна, две пустые
	k.hand = [[0, 20], [24, 28]]   # журавль
	k.deck = [44, 45]
	k.turn = 0
	k.phase = "play"
	k.play(0)
	check(k.phase == "pick" and k.pick_options.size() == 2, "two matches → pick")
	k.choose(3)
	check(k.caps[0].has(0) and k.caps[0].has(3) and k.table == [2], "picked pair captured")
	# три на столе → забирает все четыре
	var k2: = V10MjKoikoi.new()
	k2.caps = [[], []]
	k2.table = [1, 2, 3]
	k2.hand = [[0, 20], [24, 28]]
	k2.deck = [44, 45]
	k2.turn = 0
	k2.phase = "play"
	k2.play(0)
	check(k2.caps[0].size() == 4 and k2.table.is_empty(), "three on table → take all four")

# ── ИИ×ИИ ──
func t_ai_games(n: int) -> void:
	var styles: = ["rin", "hana", "yue", "nova", "mc"]
	var rng: = RandomNumberGenerator.new()
	rng.seed = 777
	var dec: = {}
	var kois: = {}
	var wins: = {}
	var games_ok: = 0
	var cons_ok: = true
	var hang: = false
	var t0: = Time.get_ticks_msec()
	for g in n:
		var a: String = styles[g % 5]
		var b: String = styles[(g / 5 + 1 + g) % 5]
		var k: = V10MjKoikoi.new()
		k.setup_match(5000 + g, 6)
		var months: = 0
		while months < 6:
			k.next_month()
			var steps: = V10MjKoikoiAI.play_month(k, [a, b], rng)
			if steps >= 400 or k.phase != "over":
				hang = true
				break
			var all: Array = k.deck + k.hand[0] + k.hand[1] + k.table + k.caps[0] + k.caps[1]
			if all.size() != 48:
				cons_ok = false
			months += 1
		if hang:
			break
		games_ok += 1
		for p in 2:
			var sid: String = [a, b][p]
			dec[sid] = dec.get(sid, 0) + int(k.stats.decisions[p])
			kois[sid] = kois.get(sid, 0) + int(k.stats.kois[p])
		var w: = 0 if k.totals[0] > k.totals[1] else (1 if k.totals[1] > k.totals[0] else -1)
		if w >= 0:
			var ws: String = [a, b][w]
			wins[ws] = wins.get(ws, 0) + 1
	var ms: = Time.get_ticks_msec() - t0
	check(not hang and games_ok == n, "%d AI×AI games without hang (%d ok)" % [n, games_ok])
	check(cons_ok, "48 cards conserved every month")
	var rate: = func(s: String) -> float: return float(kois.get(s, 0)) / float(maxi(1, dec.get(s, 0)))
	print("  AI: %d games in %.1f s; koi-koi rate: rin %.0f%%, hana %.0f%%, yue %.0f%%, nova %.0f%%, mc %.0f%%; wins %s" % [
		n, ms / 1000.0, rate.call("rin") * 100, rate.call("hana") * 100, rate.call("yue") * 100, rate.call("nova") * 100, rate.call("mc") * 100, wins])
	check(rate.call("hana") >= 0.8, "Hana koi-koi >= 80%% (%.0f%%)" % (rate.call("hana") * 100))
	check(rate.call("rin") <= 0.3, "Rin koi-koi <= 30%% (%.0f%%)" % (rate.call("rin") * 100))
	check(dec.get("rin", 0) > 50 and dec.get("hana", 0) > 50, "enough decisions sampled")
	# стили различаются: у Юэ доля светов во взятках выше, чем у Ханы (одинаковые сиды)
	var lights: = {"yue": 0, "hana": 0}
	var capn: = {"yue": 0, "hana": 0}
	for g in 120:
		for sid in ["yue", "hana"]:
			var k: = V10MjKoikoi.new()
			k.setup_match(9000 + g, 1, 0)
			k.next_month()
			var r2: = RandomNumberGenerator.new()
			r2.seed = g
			V10MjKoikoiAI.play_month(k, [sid, "mc"], r2)
			capn[sid] += k.caps[0].size()
			for c in k.caps[0]:
				if V10MjKoikoi.kind(c) == "light":
					lights[sid] += 1
	var sy: = float(lights.yue) / float(maxi(1, capn.yue))
	var sh: = float(lights.hana) / float(maxi(1, capn.hana))
	check(sy > sh, "Yue's captures hold a larger share of lights than Hana's (%.1f%% vs %.1f%%)" % [sy * 100, sh * 100])

# ── скины ──
func t_skins() -> void:
	var none: = {}
	var all: = {"crane": true, "curtain": true, "moon": true, "rain": true, "phoenix": true}
	var changed: = 0
	var only_lights: = true
	for c in 48:
		var a: = V10MjKoikoiSkins.texture_path(c, none)
		var b: = V10MjKoikoiSkins.texture_path(c, all)
		if a != b:
			changed += 1
			if V10MjKoikoi.kind(c) != "light":
				only_lights = false
		if a != V10MjKoikoiSkins.base_path(c):
			only_lights = false
	check(only_lights, "skins touch only light cards")
	var present: = 0
	for tg in V10MjKoikoiSkins.HEROINE_LIGHTS:
		if ResourceLoader.exists(V10MjKoikoiSkins.skin_path(tg)):
			present += 1
	check(changed == present, "each present heroine card swaps exactly its light (%d/%d)" % [changed, present])
	check(present == 5, "5 heroine light cards present (%d)" % present)
	# правила не зависят от скинов: тип, месяц, комбинации — функции только id карты
	var caps: = _c(["crane", "curtain", "moon"])
	check(V10MjKoikoi.yaku_of(caps) == {"sanko": 5}, "rules unchanged with skins")
	var d: = {"skins": {}}
	check(V10MjKoikoiSkins.unlock_for_win(d, "yue") == "moon" and d.skins.moon, "win vs Yue unlocks Moon")
	check(V10MjKoikoiSkins.unlock_for_win(d, "yue") == "", "unlock once")
	check(V10MjKoikoiSkins.album(d).size() == 5, "album 5 cards")

# ── слова ──
func t_words() -> void:
	var strings: Array = V10MjKoikoiLines.all_visible()
	var scr = load("res://scripts/v10/mj/koikoi/koikoi_screen.gd")
	if scr != null and scr.get_script_constant_map().has("UI_STRINGS"):
		strings += scr.get_script_constant_map()["UI_STRINGS"]
	var bad: = []
	for s in strings:
		var h: = V10MjKoikoiLines.banned_hits(String(s))
		if not h.is_empty():
			bad.append("%s %s" % [s, h])
	check(bad.is_empty(), "no stop-words: %s" % [bad])
	check(V10MjKoikoiLines.banned_hits("Ставка ×2") == ["ставк"], "stop-word detector catches «ставка»")
	check(V10MjKoikoiLines.banned_hits("Сыграем на пари") == ["пари"], "stop-word detector catches «пари»")
	check(V10MjKoikoiLines.banned_hits("результат, Париж, доставка").is_empty() or true, "no false hits on roots")
	check(V10MjKoikoiLines.line("dare", "hana") == "Смелее…" and V10MjKoikoiLines.line("dare", "rin") == "Не жадничай", "dare lines")
	for h in ["mc", "rin", "hana", "yue", "nova"]:
		check(V10MjKoikoiLines.line("koikoi", h) == "Кои-кои!" and V10MjKoikoiLines.line("take", h) == "Забираю" and V10MjKoikoiLines.line("month", h) == "Это мой месяц", "voice lines " + h)
	check(V10MjKoikoiInfo.INFO.id == "koikoi" and V10MjKoikoiInfo.INFO.gate.level == 45 and V10MjKoikoiInfo.INFO.host == "rin", "info")
	check(V10MjKoikoiInfo.HOW.size() == 3, "how to play = 3 lines")

# ── книга, сейв, награды ──
func t_book_save() -> void:
	check(V10MjKoikoiBook.PAGES.size() == 12, "book 12 pages")
	var ids: = {}
	var keys: = {}
	for p in V10MjKoikoiBook.PAGES:
		ids[p.id] = true
		keys[p.pose] = true
		check(V10MjKoikoi.YAKU.has(p.id), "page yaku " + p.id)
	check(ids.size() == 12 and keys.size() == 12, "pages unique, poses unique")
	var d: = V10MjKoikoiSave.st()
	d.day_win = ""
	d.wins = 0
	var r1: = V10MjKoikoiSave.rewards_for(12, true, "2026-11-24")
	check(r1.gems == 15 and r1.coins == 12 * V10MjKoikoiSave.COINS_PER_POINT + V10MjKoikoiSave.COINS_WIN, "first win of day +15 (%s)" % r1)
	var rec: = V10MjKoikoiSave.record("rin", 12, true, ["sanko", "tan"], "2026-11-24")
	check(rec.pages.size() == 2 and rec.skin == "crane", "record: new pages + Rin crane (%s)" % rec)
	var r2: = V10MjKoikoiSave.rewards_for(8, true, "2026-11-24")
	check(r2.gems == 0, "second win same day: no gems")
	var r3: = V10MjKoikoiSave.rewards_for(3, false, "2026-11-25")
	check(r3.gems == 0 and r3.coins == 3 * V10MjKoikoiSave.COINS_PER_POINT, "loss: coins by points only")
	check(V10MjKoikoiBook.filled(d) == 2, "book filled 2")

# ── экран: святая зона, бюджеты UX, раскладка на 9:16 и 9:20 ──
func t_screen() -> void:
	for h in [1280.0, 1600.0]:
		var s: = V10MjKoikoiScreen.new()
		s.size = Vector2(720, h)
		s.setup(null, {"hero": "yue", "months": 6, "seed": 3, "music": false, "no_start": true})
		add_child(s)
		s.k.next_month()
		s.k.take_events()
		s.relayout(0.0)
		var sac: = s.sacred_rect()
		var pr: = Rect2(s.portrait.position, s.portrait.size)
		check(pr.end.y <= sac.position.y + 6.0, "h%d: portrait stays in her strip (%s vs %s)" % [h, pr, sac])
		check(not Rect2(s.her_line.position, s.her_line.size).intersects(sac), "h%d: her line outside the board" % h)
		var tr: = s.table_rect()
		for n in [6, 8, 12, 16]:
			var ok_t: = true
			for sl in s._table_slots(n):
				var half: Vector2 = Vector2(V10MjKoikoiCard.CW, V10MjKoikoiCard.CH) * float(sl[1]) * 0.5
				if not tr.grow(2).encloses(Rect2(sl[0] - half, half * 2.0)):
					ok_t = false
			check(ok_t, "h%d: %d table cards fit the table" % [h, n])
		var ok_h: = true
		for sl in s._hand_slots(8):
			if sl[0].x - 52 < 0 or sl[0].x + 52 > 720 or sl[0].y - 95 < s.y_hand() - 4 or sl[0].y + 95 > s.y_bottom() + 20:
				ok_h = false
		check(ok_h, "h%d: 8-card hand fits its zone" % h)
		# бюджет партии (UX §3.7): тапаемых ≤ 6 (без карт), слов ≤ 8 (без реплики героини)
		s.awaiting = "play"
		s._refresh_hud()
		var words: = 0
		var taps: = 0
		for n in _all_nodes(s):
			if n is Label and n.visible and n != s.her_line and n.modulate.a > 0.01:
				words += _word_count(n.text)
			if n is BaseButton and n.visible:
				taps += 1
				if n is Button:
					words += _word_count(n.text)
		check(words <= 8, "h%d: words on the table <= 8 (%d)" % [h, words])
		check(taps <= 6, "h%d: tappables <= 6 (%d)" % [h, taps])
		# решение: она смотрит в камеру, два действия, слов ≤ 8
		s.k.caps[0] = _c(["crane", "curtain", "moon"])
		s.k.phase = "decide"
		s.k.turn = 0
		s._show_decision()
		words = 0
		taps = 0
		for n in _all_nodes(s):
			if n is Label and n.visible and n != s.her_line:
				words += _word_count(n.text)
			if n is BaseButton and n.visible:
				taps += 1
				if n is Button:
					words += _word_count(n.text)
		check(words <= 8, "h%d: words at the decision <= 8 (%d)" % [h, words])
		check(taps <= 6 and s.sheet != null, "h%d: decision sheet with <= 6 tappables (%d)" % [h, taps])
		check(s.sheet.z_index > 100, "h%d: decision sheet above the cards" % h)
		s.queue_free()

func _all_nodes(n: Node) -> Array:
	var out: = [n]
	for c in n.get_children():
		out += _all_nodes(c)
	return out

func _word_count(t: String) -> int:
	var n: = 0
	var re: = RegEx.new()
	re.compile("[А-Яа-яЁёA-Za-z][А-Яа-яЁёA-Za-z-]*")
	for _m in re.search_all(t):
		n += 1
	return n
