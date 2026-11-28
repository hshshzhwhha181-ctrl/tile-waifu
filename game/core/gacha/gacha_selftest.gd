class_name V10GachaSelftest
extends RefCounted

# --gacha_selftest=1 : rules of gacha v2 (spec Г1–Г8). Prints «GACHA_SELFTEST ok/total» and returns [ok, total].
# Never touches G.S or user:// (fresh dicts, history log off).

var ok: = 0
var total: = 0
var fails: = []
var mc: = 1.0


func check(cond: bool, name: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(name)
		print("  FAIL ", name)


func fresh(extra: = {}) -> Dictionary:
	var S: = {"gems": 10_000_000, "tickets": 0, "petals": 0, "owned": {}, "pulls": 0, "newbie_left": 20, "pity": 0, "sr_pity": 0, "guar": false}
	S.merge(extra, true)
	return S


func gacha(S: Dictionary) -> V10Gacha2:
	var g: = V10Gacha2.new(S, G.ITEMS)
	g.log_enabled = false
	return g


static func run(scale: = 1.0) -> Array:
	var t: = V10GachaSelftest.new()
	t.mc = scale
	t._all()
	print("GACHA_SELFTEST %d/%d" % [t.ok, t.total])
	if not t.fails.is_empty():
		print("GACHA_SELFTEST FAILS: ", ", ".join(t.fails))
	return [t.ok, t.total]


func _all() -> void:
	V10GClock.fixed = V10GClock.msk_at(2026, 11, 24) + 3600 * 10
	_rates()
	_monte_carlo()
	_odds()
	_newbie()
	_phase()
	_banners()
	_candles()
	_first_pick()
	_seven()
	_stars()
	_mastery()
	_misc()
	_lint()
	V10GClock.fixed = 0


func _rates() -> void:
	var c2: = V10Rates.consolidated(2)
	check(absf(c2.SSR * 100.0 - 2.90) < 0.02, "consolidated v2 SSR 2.90 (%.3f)" % (c2.SSR * 100))
	check(absf(c2.S * 100.0 - 16.4) < 0.1, "consolidated v2 S 16.4 (%.3f)" % (c2.S * 100))
	check(absf(c2.A * 100.0 - 80.7) < 0.1, "consolidated v2 A 80.7")
	check(absf(1.0 / V10Rates.mean_ssr_wishes(2) - c2.SSR) < 0.0005, "renewal mean == chain SSR")
	var c1: = V10Rates.consolidated(1)
	check(absf(c1.SSR * 100.0 - 3.85) < 0.02, "consolidated v1 SSR 3.85")
	check(V10Rates.ssr_rate(45, 2) == 0.016 and absf(V10Rates.ssr_rate(46, 2) - 0.076) < 1e-6 and V10Rates.ssr_rate(60, 2) == 1.0, "soft pity from #46, hard #60")
	var lines: = V10Rates.worst_lines()
	check("19\u00a0700\u00a0₽" in lines[0] and "120" in lines[0], "worst case 120 ≈ 19 700 ₽")
	check("32\u00a0800\u00a0₽" in lines[1] and "200" in lines[1], "candle 200 ≈ 32 800 ₽")


func _monte_carlo() -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 424242
	var n: = int(300000 * mc)
	var c: = {"p": 0, "s": 0}
	var cnt: = {"SSR": 0, "S": 0, "A": 0}
	var gap: = 0
	var max_gap: = 0
	var s_gap: = 0
	var max_s_gap: = 0
	for i in n:
		var r: = V10Rates.roll(c, 2, rng.randf())
		cnt[r] += 1
		gap += 1
		s_gap += 1
		if r == "SSR":
			max_gap = maxi(max_gap, gap)
			gap = 0
		if r != "A":
			max_s_gap = maxi(max_s_gap, s_gap)
			s_gap = 0
	var ssr: = float(cnt.SSR) / n * 100.0
	var s: = float(cnt.S) / n * 100.0
	check(absf(ssr - 2.91) < 0.1, "MC SSR 2.91±0.1 (%.3f)" % ssr)
	check(absf(s - 16.4) < 0.3, "MC S 16.4±0.3 (%.3f)" % s)
	check(max_gap <= 60, "MC never more than 60 wishes without SSR (%d)" % max_gap)
	check(max_s_gap <= 10, "MC S-or-better every 10 (%d)" % max_s_gap)
	# the full pull() path (pool, grants, candles) agrees with the rarity roll
	var S: = fresh({"newbie_left": 0})
	var g: = gacha(S)
	var std: = V10Banners.std()
	var k: = {"SSR": 0, "S": 0, "A": 0}
	var m: = int(30000 * mc)
	for i in m / 10:
		for r in g.pull(std, 10):
			k[r.rar] += 1
	check(absf(float(k.SSR) / m * 100.0 - 2.9) < 0.5, "pull() SSR ≈ 2.9 (%.2f)" % (float(k.SSR) / m * 100.0))
	check(int(S.candles) == m, "a candle for every wish (%d)" % int(S.candles))
	check(int(S.pity) == 0 and int(S.pity_std) < 60, "std banner uses its own counter")


func _odds() -> void:
	var S: = fresh()
	var g: = gacha(S)
	var pool: = g.pool()
	var all_ids: = []
	for rar in pool:
		for it in pool[rar]:
			all_ids.append(String(it.id))
			check(not it.get("start", false) and not it.get("nogacha", false) and not it.get("hidden", false), "pool excludes start/nogacha/hidden " + String(it.id))
	for b in g.banners():
		var rows: = g.odds(b)
		var sb: = 0.0
		var st: = 0.0
		var ids: = []
		for r in rows:
			sb += float(r.base)
			st += float(r.total)
			ids.append(String(r.id))
		check(absf(sb - 100.0) < 0.01 and absf(st - 100.0) < 0.01, "odds sum 100 on %s (%.4f / %.4f)" % [b.id, sb, st])
		if b.kind != "newbie":
			check(all_ids.all(func(id): return id in ids), "every pool item listed on " + String(b.id))
		if b.kind == "phase":
			var f: = rows.filter(func(r): return r.featured and r.rar == "SSR")
			check(f.size() == 1 and String(f[0].id) == String(b.target), "featured SSR of %s marked" % b.id)


func _newbie() -> void:
	var never_first: = true
	var always: = true
	for i in int(1000 * mc):
		var S: = fresh({"newbie_left": 20, "first_pick": "o_dragon", "owned": {"o_dragon": true}})
		var g: = gacha(S)
		check_once(int(S.newbie_left) == 50, "migration 20 → 50")
		var nb: = V10Banners.newbie()
		var got: = false
		for k in 5:
			for r in g.pull(nb, 10):
				if r.rar == "SSR":
					got = true
					if r.id == "o_dragon":
						never_first = false
		if not got:
			always = false
		check_once(not g.newbie_open(), "newbie hidden after 50")
		check_once(g.banners().size() == 2, "banners: phase + std after 50")
	check(always, "newbie: SSR always within 50 (1000 runs)")
	check(never_first, "newbie SSR never the first pick")
	var S2: = fresh({"newbie_left": 12, "pulls": 30})
	var g2: = gacha(S2)
	check(int(S2.newbie_left) == 42, "migration old_left 12 → 42")
	check(g2.cost(V10Banners.newbie(), 10) == 1200, "newbie ×10 = 1200")
	check(int(S2.rates_ver) == 1, "0.9 save keeps rates v1")
	var S3: = fresh({"newbie_left": 0, "pulls": 30})
	var g3: = gacha(S3)
	var std: = V10Banners.std()
	var guard: = 0
	while int(S3.rates_ver) == 1 and guard < 200:
		g3.pull(std, 1)
		guard += 1
	check(int(S3.rates_ver) == 2 and guard <= 60, "rates v1 until the first SSR, then v2 (%d)" % guard)
	var S4: = fresh({"newbie_left": 20, "newbie_ssr": true})
	var g4: = gacha(S4)
	check(g4.pity_left(V10Banners.newbie()) == 60, "newbie promise not repeated after a 0.9 SSR")
	check(g4.split(V10Banners.newbie(), 1).tickets == 0, "tickets are not taken on «Первый гость»")


var _once: = {}
func check_once(cond: bool, name: String) -> void:
	if not cond and not _once.has(name):
		_once[name] = false
		check(false, name)
	elif cond and not _once.has(name):
		_once[name] = true
		check(true, name)


func _phase() -> void:
	# worst case for the featured SSR ≤ 120, phase B gives the target
	var worst: = 0
	var target_ok: = true
	var S: = fresh({"newbie_left": 0})
	var g: = gacha(S)
	var ph: = V10Banners.phase_at(V10Banners.anchor_t() + 22 * V10GClock.DAY)
	check(ph.half == "B" and ph.ssr.size() == 2, "phase 2 is B with two SSRs")
	V10Banners.set_target(S, ph, String(ph.ssr[1]))
	ph["target"] = V10Banners.target(S, ph)
	var since: = 0
	var featured_n: = 0
	var ssr_n: = 0
	for i in int(10000 * mc):
		var r: Dictionary = g.pull(ph, 1)[0]
		since += 1
		if r.rar == "SSR":
			ssr_n += 1
			if r.featured:
				featured_n += 1
				worst = maxi(worst, since)
				since = 0
				if r.id != ph.target:
					target_ok = false
	check(worst <= 120, "featured SSR not later than 120 (%d)" % worst)
	check(target_ok, "phase B 50/50 gives the chosen target")
	check(absf(float(featured_n) / maxf(1, ssr_n) - 2.0 / 3.0) < 0.08, "2/3 of SSRs featured (%.2f)" % (float(featured_n) / maxf(1, ssr_n)))
	check(not V10Banners.set_target(S, ph, "r_base"), "target must be an SSR of the phase")
	var sp: = g.split(ph, 10)
	TWWallet.for_state(S).set_balance("tickets", 3)
	sp = g.split(ph, 10)
	check(sp.tickets == 3 and sp.gems == 1050, "split: 3 tickets then 1050 crystals")


func _banners() -> void:
	var from: = V10Banners.anchor_t()
	var sch: = V10Banners.schedule(V10GClock.now(), 26)
	var ok_seq: = true
	var ok_len: = true
	var ok_alt: = true
	for i in sch.size():
		var p: Dictionary = sch[i]
		if int(p.end) - int(p.start) != 21 * V10GClock.DAY:
			ok_len = false
		if i > 0 and int(sch[i - 1].end) != int(p.start):
			ok_seq = false
		if i > 0 and String(sch[i - 1].half) == String(p.half):
			ok_alt = false
	check(ok_seq, "phases without overlaps or holes for 26 weeks")
	check(ok_len, "each phase 21 days")
	check(ok_alt, "A and B alternate")
	var far: = V10Banners.phase_at(from + 400 * V10GClock.DAY)
	check(bool(far.get("fallback", false)) and far.ssr.size() == 2, "fallback loop of B phases after the schedule")
	var d: = V10GClock.msk_date(int(sch[0].start))
	check(int(d.hour) == 4 and int(d.minute) == 0, "phase starts 04:00 МСК")
	# rolled-back clock does not bring an ended phase back
	var S: = fresh()
	V10GClock.fixed = from + 25 * V10GClock.DAY
	var p2: = V10Banners.current(S)
	V10GClock.fixed = from + 5 * V10GClock.DAY
	var p1: = V10Banners.current(S)
	check(String(p1.id) == String(p2.id), "clock rollback keeps the later phase")
	V10GClock.fixed = V10GClock.msk_at(2026, 11, 24) + 3600 * 10
	var ph: = V10Banners.phase_at(V10GClock.now())
	var t_far: = V10GClock.until_text(int(ph.end), V10GClock.now())
	check(t_far.begins_with("до ") and t_far.ends_with("МСК"), "date, not countdown, far from the end: " + t_far)
	var t_near: = V10GClock.until_text(int(ph.end), int(ph.end) - 47 * 3600)
	check(t_near.begins_with("ещё"), "countdown only in the last 48 h: " + t_near)
	check(not V10Banners.countdown_visible(ph, int(ph.end) - 49 * 3600) and V10Banners.countdown_visible(ph, int(ph.end) - 3600), "countdown_visible 48 h")


func _candles() -> void:
	var S: = fresh({"newbie_left": 0, "tickets": 20})
	var g: = gacha(S)
	var std: = V10Banners.std()
	g.pull(std, 10)
	check(int(S.candles) == 10 and int(S.tickets) == 10, "candles also from tickets")
	for i in 19:
		g.pull(std, 10)
	check(g.can_spark() and int(S.candles) == 200, "200 wishes → Свеча ready")
	var opts: = g.spark_options().map(func(x): return String(x.id))
	check(opts.all(func(id): return String(g.item(id).rar) == "SSR"), "spark options are SSR only")
	check(g.spark("r_base").is_empty(), "spark refuses a non-SSR")
	var before: = V10Stars.level(S, String(opts[0]))
	var r: = g.spark(String(opts[0]))
	check(not r.is_empty() and int(S.candles) == 0, "spark takes exactly 200")
	check((before == 0 and r.new) or (before > 0 and int(r.star) == mini(5, before + 1)), "spark of an owned SSR adds ✦")
	check(not g.can_spark(), "spark not ready right after")
	# phase end does not touch candles
	S.candles = 150
	V10GClock.fixed += 30 * V10GClock.DAY
	V10Banners.current(S)
	check(int(S.candles) == 150, "candles never burn at the end of a phase")
	V10GClock.fixed -= 30 * V10GClock.DAY


func _first_pick() -> void:
	var S: = fresh({"gems": 0})
	var g: = gacha(S)
	check(g.first_needed() and g.first_options().size() == 3, "first pick offered before the choice")
	var r: = g.choose_first("y_queen")
	check(not r.is_empty() and S.owned.has("y_queen") and int(S.gems) == 0, "one item, nothing spent")
	check(not g.first_needed() and g.choose_first("n_ssr").is_empty(), "not offered again")
	check(g.offer_quiet(), "no full-screen offer for 24 h")
	var S2: = fresh({"owned": {"o_dragon": true, "y_queen": true, "n_ssr": true}, "tickets": 0})
	var g2: = gacha(S2)
	check(not g2.first_needed() and int(S2.tickets) == 10, "migration: all three → 10 tickets")
	var S3: = fresh({"owned": {"o_dragon": true}})
	var g3: = gacha(S3)
	check(g3.first_options().size() == 2, "migration: owned one → choose among the other two")


func _seven() -> void:
	var S: = {}
	check(V10Seven.visit(S, "2026-11-24") and not V10Seven.visit(S, "2026-11-24"), "two visits a day = one")
	V10Seven.visit(S, "2026-11-26")
	check(V10Seven.claimable(S) == [0, 1], "days need not be in a row")
	check(V10Seven.tickets_total() == 10, "Семь встреч: 10 tickets in all")
	var got: = []
	V10Seven.claim(S, 0, func(r): got.append(r))
	check(got.size() == 1 and V10Seven.claim(S, 0, func(r): got.append(r)).is_empty(), "claim once")
	for d in ["a", "b", "c", "d", "e", "f", "g"]:
		V10Seven.visit(S, d)
	check(S.seven.days.size() == 7, "at most 7 days")
	for i in 7:
		V10Seven.claim(S, i, func(r): got.append(r))
	check(V10Seven.done(S) and got.size() == 8, "all claimed (+ backdrop on day 7)")


func _stars() -> void:
	var S: = fresh({"newbie_left": 0})
	var it: Dictionary = G.ITEM.get("o_cafe", {"id": "o_cafe", "rar": "SR", "cat": "outfit"})
	V10Stars.on_new(S, "o_cafe")
	var d: = V10Stars.on_dup(S, it)
	check(V10Stars.level(S, "o_cafe") == 2 and d.up, "✦1 → ✦2 on a duplicate")
	for i in 3:
		V10Stars.on_dup(S, it)
	var d5: = V10Stars.on_dup(S, it)
	check(V10Stars.level(S, "o_cafe") == 5 and int(d5.petals) == 20, "S over ✦5 → 20 petals")
	var ssr: = {"id": "x", "rar": "SSR", "cat": "outfit"}
	S.ostars["x"] = 5
	check(int(V10Stars.on_dup(S, ssr).petals) == 60, "SSR over ✦5 → 60 petals")
	check(int(V10Stars.on_dup(S, {"id": "s_lemon", "rar": "R", "cat": "skin"}).gems) == 25, "A non-outfit dup → 25 crystals")
	var g: = gacha(S)
	S.ostars["r_maid"] = 2
	TWWallet.for_state(S).set_balance("petals", 70)
	check(g.add_star("r_maid") and int(S.petals) == 10 and V10Stars.level(S, "r_maid") == 3, "add star costs exactly 60")
	check(not g.add_star("r_maid"), "not without petals")
	check(V10Stars.unlocks({"name": "Юэ"}, 5).all(func(u): return u.ranked_safe), "unlocks ranked_safe")
	var S2: = fresh({"owned": {"o_cafe": true, "s_lemon": true}})
	gacha(S2)
	check(V10Stars.level(S2, "o_cafe") == 1 and V10Stars.level(S2, "s_lemon") == 0, "migration ✦1 for owned outfits")


func _mastery() -> void:
	check(V10Mastery.level(299, "S") == 0 and V10Mastery.level(300, "S") == 1 and V10Mastery.level(1000, "S") == 2 and V10Mastery.level(2500, "S") == 3, "thresholds 300/1000/2500")
	check(V10Mastery.level(9999, "S") == 3 and V10Mastery.level(5000, "SSR") == 4, "IV only for SSR")
	var S: = {}
	var m: = V10Mastery.new()
	for i in 150:
		m.on_pair("o_cafe", true)
	var ups: = m.flush(S, func(_o): return "S")
	check(V10Mastery.points(S, "o_cafe") == 300 and ups.size() == 1 and ups[0].to == 1, "rested ×2, flush at the end")
	check(m.pending.is_empty(), "flush clears memory")
	check(V10Mastery.set_palette(S, "o_cafe", 2, "S") and V10Mastery.palette(S, "o_cafe") == 2, "palette saved")
	check(not V10Mastery.set_palette(S, "r_maid", 1, "S"), "palette locked before I")
	var pr: = V10Mastery.progress(650, "S")
	check(pr.lv == 1 and absf(pr.frac - 0.5) < 0.01, "progress inside a level")


func _misc() -> void:
	check(V10GachaBank.plural(1, "a", "b", "c") == "a" and V10GachaBank.plural(3, "a", "b", "c") == "b" and V10GachaBank.plural(11, "a", "b", "c") == "c", "plural")
	check(V10GachaBank.split_text({"tickets": 3, "gems": 1050, "moon": 0}) == "Спишется: 3 билета → 1\u00a0050 кристаллов", "split text")
	var S: = fresh({"gems": 100})
	var g: = gacha(S)
	check(g.pull(V10Banners.std(), 1).is_empty() and int(S.gems) == 100, "no pull without crystals, nothing spent")
	check(V10Rates.group(19656) == "19\u00a0656" and V10Rates.pct(2.9) == "2,90 %", "number format")


# visible strings of the lane must not use banned jargon (UX_RULES §4.3)
func _lint() -> void:
	var banned: = ["гарант", "50/50", "пити", "крутк", "гача", "(^|[^а-яё])ульт", "\\bSR\\b", "\\bR\\b", "Ранг", "−\\d+%", "успей", "последний шанс", "Звезда наряда"]
	var dir: = "res://scripts/v10/gacha/ui/"
	var bad: = []
	var re: = RegEx.create_from_string("\"([^\"\\\\]|\\\\.)*\"")
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		var src: = FileAccess.get_file_as_string(dir + f)
		for line in src.split("\n"):
			var l: = line.strip_edges()
			if l.begins_with("#"):
				continue
			for m in re.search_all(l):
				var s: = m.get_string()
				if s.length() < 5 or not RegEx.create_from_string("[а-яА-Я]").search(s):
					continue
				for w in banned:
					if RegEx.create_from_string(w).search(s):
						bad.append("%s: %s" % [f, s])
	check(bad.is_empty(), "no banned jargon in visible strings " + str(bad))
