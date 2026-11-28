class_name V9SummonSelftest
extends RefCounted

# Summon rules selftest (0.9 §E). Run on the summon screen:
#   godot … -- --unlock=10 --screen=summon --shots=<dir> --at=1.5 --act=selftest
# prints «SUMMON_SELFTEST ok/total» and every failed check. Checks V9Summon against the rules of the real engine (TWGacha.pull), the
# lantern art / code fallback, the timings budget and that the fake dev pulls never touch the save.

static var ok: = 0
static var total: = 0


static func _check(cond: bool, what: String) -> void :
	total += 1
	if cond:
		ok += 1
	else:
		printerr("SUMMON_SELFTEST FAIL: " + what)


static func run(host: Node = null) -> int:
	ok = 0
	total = 0
	var R: = {"rar": "R", "id": "x"}
	var SR: = {"rar": "SR", "id": "y"}
	# best rarity and the colour climb
	_check(V9Summon.best_rar([R, R]) == "R", "best R")
	_check(V9Summon.best_rar([R, SR, R]) == "SR", "best SR")
	_check(V9Summon.best_rar([SR, {"rar": "SSR", "id": "z"}, R]) == "SSR", "best SSR")
	_check(V9Summon.best_rar([]) == "R", "best of empty")
	_check(V9Summon.steps("R") == ["R"], "steps R")
	_check(V9Summon.steps("SR") == ["R", "SR"], "steps SR")
	_check(V9Summon.steps("SSR") == ["R", "SR", "SSR"], "steps SSR")
	# colours: jade, lavender, gold (green-dominant, blue+red over green, red+green over blue)
	var j: Color = V9Summon.COL.R
	var l: Color = V9Summon.COL.SR
	var g: Color = V9Summon.COL.SSR
	_check(j.g > j.r and j.g > j.b, "R lantern is jade")
	_check(l.b > l.g and l.r > l.g, "SR lantern is lavender")
	_check(g.r > g.b and g.g > g.b, "SSR lantern is gold")
	# skip from the second summon on
	_check(not V9Summon.can_skip(0), "no skip on the first summon")
	_check(V9Summon.can_skip(1) and V9Summon.can_skip(10), "skip from the second summon")
	# pity replay: +1 per wish, 0 after an SSR
	var pt: = V9Summon.pity_track(40, [R, SR, {"rar": "SSR", "id": "a"}, R])
	_check(pt == [41, 42, 0, 1], "pity track %s" % [pt])
	_check(V9Summon.left(0) == 60 and V9Summon.left(59) == 1 and V9Summon.left(70) == 0, "wishes left")
	# guarantee: an off-banner SSR turns it on, the banner SSR turns it off, the newbie banner never changes it
	var gt: = V9Summon.guar_track(false, [R, {"rar": "SSR", "id": "off"}, R, {"rar": "SSR", "id": "ban"}], "ban")
	_check(gt == [false, true, true, false], "guar track %s" % [gt])
	_check(V9Summon.guar_track(true, [{"rar": "SSR", "id": "off"}], "ban", true) == [true], "newbie keeps guar")
	# replay against the real engine: TWGacha.pull on throw-away states (G.S and the global rng are never touched); the 0.9 tracks
	# must equal what V10Gacha2 reports card by card (r.pity / r.guar after each card)
	var pb: = TWGachaSelftest.banner("phase")
	var pits: = TWGachaSelftest.items()
	for k in 8:
		var p0: int = [0, 30, 50, 58, 59, 12, 44, 1][k]
		var g0: = k % 2 == 0
		var S: = TWGachaSelftest.fresh({"pity": p0, "guar": g0})
		var out: = TWGacha.pull(S, pb, 10, {"items": pits, "seed": 777 + k})
		var res09: Array = out.res.map(func(r): return {"rar": V10Gacha2.rar09(String(r.rar)), "id": String(r.id)})
		var tgt: = V10Banners.target(S, pb)
		_check(bool(out.ok) and res09.size() == 10, "replay pull %d ran" % k)
		_check(V9Summon.pity_track(p0, res09) == out.res.map(func(r): return int(r.pity)) and V9Summon.pity_track(p0, res09).back() == int(S.pity),
			"pity replay = TWGacha.pull (%d)" % p0)
		_check(V9Summon.guar_track(g0, res09, tgt) == out.res.map(func(r): return bool(r.guar)) and V9Summon.guar_track(g0, res09, tgt).back() == bool(S.guar),
			"guar replay = TWGacha.pull (%d)" % p0)
	# lantern art or the code fallback, both build
	for rar in V9Summon.ORDER:
		var tex: = V9Summon.lantern_tex(rar)
		_check(tex == null or tex.get_size().y >= 300, "lantern art %s readable" % rar)
		var la: = V9Lantern.new().setup(470, rar)
		_check(la.size.y == 470 and la.uses_art() == (tex != null), "lantern %s built" % rar)
		la.free()
		var lc: = V9Lantern.new().setup(470, rar, true)
		_check(not lc.uses_art() and lc.body is V9Lantern.CodeLantern, "code lantern %s" % rar)
		lc.free()
		_check(V9Summon.MUSIC_PITCH[rar] >= 1.0 and V9Summon.MUSIC_PITCH[rar] > V9Summon.SUSPENSE_PITCH, "music pitch %s" % rar)
	# timing budget: R snappy, SSR longest, nothing drags
	var tr: = V9Summon.climb_time("R")
	var ts: = V9Summon.climb_time("SR")
	var tss: = V9Summon.climb_time("SSR")
	_check(tr < ts and ts < tss, "climb grows with rarity")
	_check(tr <= 1.3 and tss <= 3.2, "climb times %.2f / %.2f" % [tr, tss])
	_check(V9Summon.AUTO_LIGHT >= 1.5 and V9Summon.AUTO_LIGHT <= 3.0, "auto light")
	# dev pulls: right best rarity, items exist, the save is untouched
	var gems: = int(G.S.gems)
	var pity: = int(G.S.pity)
	var pulls: = int(G.S.pulls)
	for n in [1, 10]:
		for best in V9Summon.ORDER:
			var res: = V9Summon.dev_results(n, best, G.BANNERS[1])
			_check(res.size() == n and V9Summon.best_rar(res) == best, "dev %s×%d" % [best, n])
			_check(res.all( func(r): return G.ITEM.has(r.id)), "dev %s×%d items" % [best, n])
	_check(int(G.S.gems) == gems and int(G.S.pity) == pity and int(G.S.pulls) == pulls, "dev pulls leave the save alone")
	printerr("SUMMON_SELFTEST %d/%d" % [ok, total])
	return ok
