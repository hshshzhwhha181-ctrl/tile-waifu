extends SceneTree



var fails: = 0

func _init() -> void :
	_shanten_tests()
	_score_tests()
	_sim(int(_arg("games", "12")))
	print("TABLE SELFTEST ", "OK" if fails == 0 else "FAILED %d" % fails)
	quit()

func _arg(k: String, d: String) -> String:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--" + k + "="):
			return s.split("=")[1]
	return d


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
				while used.has(k * 4 + copy):
					copy += 1
				if d != 0 and copy == 0:
					copy = 1
				used[k * 4 + copy] = true
				out.append(k * 4 + copy)
			digits = []
	return out

func check(name: String, got, want) -> void :
	if str(got) == str(want):
		print("PASS ", name)
	else:
		fails += 1
		print("FAIL ", name, " got=", got, " want=", want)

func _shanten_tests() -> void :
	check("tenpai ryanmen", V8Mj.shanten(V8Mj.counts(parse("123m456p789s1122z")), 0), 0)
	check("agari", V8Mj.shanten(V8Mj.counts(parse("123m456p789s11222z")), 0), -1)
	check("1-shanten", V8Mj.shanten(V8Mj.counts(parse("123m456p78s11z359m")), 0), 1)
	check("chiitoi tenpai", V8Mj.shanten(V8Mj.counts(parse("1199m2288p3377s1z")), 0), 0)
	check("kokushi tenpai", V8Mj.shanten(V8Mj.counts(parse("19m19p19s1234567z")), 0), 0)
	check("waits 23m", V8Mj.waits(V8Mj.counts(parse("23m456p789s11z555s")), 0), [0, 3])
	check("nobetan", V8Mj.waits(V8Mj.counts(parse("1234m567p234s666z")), 0), [0, 3])
	check("6-shanten worst-ish", V8Mj.shanten(V8Mj.counts(parse("159m159p159s1234z")), 0) >= 5, true)

func _ev(closed: String, win: String, ctx: Dictionary, melds: = []) -> Dictionary:
	var cl: = parse(closed)
	var w: = parse(win)[0]

	for t in cl:
		if t >> 2 == w >> 2:
			w = t
	var base: = {"seat_wind": 28, "round_wind": 27, "dora_ind": [], "ura_ind": []}
	base.merge(ctx, true)
	return V8Mj.evaluate(cl, melds, w, base)

func _names(ev: Dictionary) -> Array:
	var a: = []
	for y in ev.yaku:
		a.append(y[0])
	a.sort()
	return a

func _score_tests() -> void :
	var e: = _ev("234m567p234s56788s", "8s", {"tsumo": true, "riichi": true})
	check("riichi pinfu tsumo tanyao", _names(e), ["pinfu", "riichi", "tanyao", "tsumo"])
	check(" ... 20 fu", e.fu, 20)
	check(" ... 4 han nondealer tsumo base", e.base, 1280)
	e = _ev("1199m2288p3377s11z", "1z", {"tsumo": false})
	check("chiitoi 25fu", [_names(e), e.fu], [["chiitoitsu"], 25])
	e = _ev("123m456p789s555z22z", "2z", {"tsumo": false})
	check("haku tanki ron", [_names(e), e.fu], [["haku"], 50])
	e = _ev("123456789m11z", "9m", {"tsumo": false}, [{"type": "pon", "tiles": parse("555z")}])
	check("open honitsu ittsu haku", _names(e), ["haku", "honitsu", "ittsu"])
	e = _ev("111m999p111s11z", "1z", {"tsumo": true}, [{"type": "pon", "tiles": parse("777z")}])
	check("toitoi chun honroutou", _names(e), ["chun", "honroutou", "toitoi"])
	e = _ev("19m19p19s12345677z", "7z", {"tsumo": false})
	check("kokushi", [e.yakuman, e.base], [1, 8000])
	e = _ev("11122233344455m", "5m", {"tsumo": true})
	check("suuankou", e.yakuman >= 1, true)
	e = _ev("234m234p234s23488s", "4s", {"tsumo": false})
	check("no-yaku open-shape? closed ron sanshoku tanyao", _names(e).has("sanshoku"), true)
	e = _ev("123m456m789m2345p", "5p", {"tsumo": false}, [{"type": "chi", "tiles": parse("789s")}])
	check("open yakuless", e.han, 0)
	e = _ev("22m345p345p66s789s", "9s", {"tsumo": false, "riichi": true, "dora_ind": [parse("1m")[0]]})
	check("iipeikou riichi dora2", [e.han >= 4, _names(e).has("iipeikou")], [true, true])

func _sim(games: int) -> void :
	var t0: = Time.get_ticks_msec()
	var wins: = [0, 0, 0, 0]
	var draws: = 0
	var hands: = 0
	var places: = {}
	var maxdec: = 0
	var decisions: = 0
	var yaku_seen: = {}
	var ids: = ["mc", "hana", "yue", "nova", "rin"]
	for g in games:
		var r: = V8Round.new()
		var pl: = []
		for i in 4:
			var id: String = ids[(g + i) % ids.size()]
			pl.append({"id": id, "ctl": "ai"})
		r.setup({"seed": 1000 + g, "length": "east" if g % 2 == 0 else "south", "players": pl})
		var guard: = 0
		while not r.match_over and guard < 20000:
			guard += 1
			var ta: = Time.get_ticks_usec()
			var ev: = r.advance()
			var dt: = (Time.get_ticks_usec() - ta) / 1000
			maxdec = maxi(maxdec, dt)
			decisions += 1
			if ev.ev == "win":
				hands += 1
				wins[ev.seat] += 1
				for y in ev.eval.yaku:
					yaku_seen[y[0]] = yaku_seen.get(y[0], 0) + 1
				var tot: = 0
				for d in ev.delta:
					tot += d
				if tot != ev.sticks * 1000:
					fails += 1
					print("FAIL points not zero-sum ", ev.delta, " sticks ", ev.sticks)
			elif ev.ev == "draw_end":
				hands += 1
				draws += 1
			elif ev.ev == "ask":
				fails += 1
				print("FAIL ask in all-AI game")
				break
		if guard >= 20000:
			fails += 1
			print("FAIL match did not end, seed ", 1000 + g, " state ", r.state)
		var tot2: = 0
		for s in r.scores:
			tot2 += s
		if tot2 != 100000:
			fails += 1
			print("FAIL total score ", tot2, " seed ", 1000 + g)
		var res: = r.final_result()
		for i in 4:
			var id2: String = pl[i].id
			if not places.has(id2):
				places[id2] = []
			places[id2].append(res.place[i])
	var ms: = Time.get_ticks_msec() - t0
	print("SIM games=%d hands=%d draws=%d steps=%d max_step_ms=%d total_ms=%d" % [games, hands, draws, decisions, maxdec, ms])
	for id in places:
		var a: Array = places[id]
		var sum: = 0.0
		for p in a:
			sum += p
		print("  avg place %s: %.2f over %d" % [id, sum / a.size(), a.size()])
	print("  yaku: ", yaku_seen)
