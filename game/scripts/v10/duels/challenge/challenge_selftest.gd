extends Node

# Selftest of «Вызов по коду» (spec 0.10 R5). Scene challenge_selftest.tscn (boot: challenge_boot.gd):
#   flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/duels/challenge/challenge_selftest.tscn -- --challenge_selftest=1
# Under xvfb (opengl3) the poster is also rendered and its pixels checked; headless skips those pixel checks only.
# Runs on its own save files (user://ch_selftest_*.json) — the player's save is never written.
# Sections: codec · typos · crockford · extract · nick · deal · rewards · poster · ui · e2e · files
# Output: one line per section, then «CHALLENGE_SELFTEST ok/total»; exit 0 only when all pass.

const U: = preload("res://scripts/v10/duels/challenge/challenge_util.gd")
const C: = preload("res://scripts/v10/duels/challenge/challenge_code.gd")
const D: = preload("res://scripts/v10/duels/challenge/challenge_deal.gd")
const ST: = preload("res://scripts/v10/duels/challenge/challenge_state.gd")
const UI2: = preload("res://scripts/v10/duels/challenge/challenge_ui.gd")
const P: = preload("res://scripts/v10/duels/challenge/challenge_poster.gd")
const RUN: = preload("res://scripts/v10/duels/challenge/challenge_run.gd")
const SCR: = preload("res://scripts/v10/duels/challenge/challenge_screen.gd")
const PLAY: = "res://scripts/v10/duels/challenge/challenge_play.gd"
const UI_FILES: = ["challenge_ui.gd", "challenge_screen.gd", "challenge_run.gd", "challenge_poster.gd", "challenge_play.gd"]
const ALL_FILES: = ["challenge_util.gd", "challenge_code.gd", "challenge_deal.gd", "challenge_state.gd", "challenge_ui.gd",
	"challenge_poster.gd", "challenge_screen.gd", "challenge_run.gd", "challenge_play.gd"]
const SAVE_A: = "user://ch_selftest_author.json"
const SAVE_B: = "user://ch_selftest_friend.json"

var ok: = 0
var total: = 0
var sec: = ""
var sec_ok: = {}
var sec_total: = {}
var fails: = []
var rng: = RandomNumberGenerator.new()
var main
var paid: = []  # reward_sink log
var rendering: = false
var a: = {}


func check(cond: bool, what: String) -> void:
	total += 1
	sec_total[sec] = int(sec_total.get(sec, 0)) + 1
	if cond:
		ok += 1
		sec_ok[sec] = int(sec_ok.get(sec, 0)) + 1
	else:
		fails.append("%s: %s" % [sec, what])
		print("  FAIL %s: %s" % [sec, what])


func _begin(s: String) -> void:
	sec = s
	sec_ok[s] = int(sec_ok.get(s, 0))
	sec_total[s] = int(sec_total.get(s, 0))


func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--") and "=" in s:
			var kv: = s.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	rng.seed = 20261124
	rendering = DisplayServer.get_name() != "headless"
	U.mem_clip = true
	U.album_dir_override = OS.get_user_data_dir().path_join("ch_selftest_photos")
	U.reward_sink = func(r: Dictionary, src: String): paid.append({"r": r, "src": src})
	_profile(SAVE_A, "Ника Ветер")
	var t0: = U.tick_ms()
	_codec()
	_typos()
	_crockford()
	_extract()
	_nick()
	_deal()
	_rewards()
	await _poster()
	await _boot_main()
	await _ui()
	await _e2e()
	_files()
	U.reward_sink = Callable()
	U.fake_now = 0
	U.fake_day = ""
	U.fake_clock_ok = true
	for s in sec_total:
		print("CHALLENGE %-9s %d/%d" % [s, int(sec_ok.get(s, 0)), int(sec_total[s])])
	if not fails.is_empty():
		print("CHALLENGE fails: %d" % fails.size())
	print("CHALLENGE time %.1f s, rendering %s" % [(U.tick_ms() - t0) / 1000.0, "on" if rendering else "off (headless: poster pixels skipped)"])
	print("CHALLENGE_SELFTEST %d/%d" % [ok, total])
	for p in [SAVE_A, SAVE_B]:
		for q in [p, p.get_basename() + ".tmp.json", p.get_basename() + ".bak.json"]:
			if FileAccess.file_exists(q):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(q))
	await _teardown()
	get_tree().quit(0 if ok == total and total > 0 else 1)


func _teardown() -> void:
	if main and is_instance_valid(main):
		main.queue_free()
		main = null
	await get_tree().process_frame
	await get_tree().process_frame
	UI._fonts.clear()
	V10Fonts._cache.clear()
	V10Fonts._files.clear()
	V10Type._fonts.clear()
	V10Type._ls.clear()
	Fx._add = null
	JButton._desat_mat = null


# a separate save file per profile: wiped, loaded fresh, a nick, the tutorial done
func _profile(path: String, nick: String) -> void:
	G.save_path = path
	for q in [path, path.get_basename() + ".tmp.json", path.get_basename() + ".bak.json"]:
		if FileAccess.file_exists(q):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(q))
	G.load_game()
	G.S.profile.nick = nick
	G.S.profile_done = true
	G.S.intro_done = true
	G.S.tut_done = true
	G.S.unlocked = 8
	G.S.level_partner = "mc"
	ST.bind(null)


func _rand_payload() -> Dictionary:
	return {"mode": [1, 2, 3, 4][rng.randi() % 4], "gen": rng.randi() % 8, "key": rng.randi(),
		"tenths": 1 + rng.randi() % C.TIME_MAX, "stars": 1 + rng.randi() % 3}

# ---------------------------------------------------------------- codec

func _codec() -> void:
	_begin("codec")
	var re: = RegEx.new()
	re.compile("^TW-[0-9A-F][0-9A-HJKMNP-TV-Z]{3}-[0-9A-HJKMNP-TV-Z]{4}-[0-9A-HJKMNP-TV-Z]{5}$")
	var bad_rt: = 0
	var bad_fmt: = 0
	var seen: = {}
	for i in 10000:
		var p: = _rand_payload()
		var code: = C.encode(p)
		if re.search(code) == null:
			bad_fmt += 1
		var d: = C.decode(code)
		if not d.ok or int(d.mode) != p.mode or int(d.gen) != p.gen or int(d.key) != p.key or int(d.tenths) != p.tenths or int(d.stars) != p.stars:
			bad_rt += 1
		seen[code] = true
	check(bad_rt == 0, "10 000 random payloads round-trip (%d bad)" % bad_rt)
	check(bad_fmt == 0, "format TW-XXXX-XXXX-XXXXX, first symbol 0–F, Crockford alphabet (%d bad)" % bad_fmt)
	check(seen.size() == 10000, "10 000 payloads → 10 000 distinct codes")
	# edges
	for p in [{"mode": 1, "gen": 0, "key": 0, "tenths": 1, "stars": 1}, {"mode": 4, "gen": 7, "key": C.KEY_MAX, "tenths": C.TIME_MAX, "stars": 3}]:
		var d2: = C.decode(C.encode(p))
		check(d2.ok and int(d2.key) == int(p.key) and int(d2.tenths) == int(p.tenths), "edge payload %s" % str(p))
	check(C.encode({"mode": 1, "gen": 0, "key": 1, "tenths": 0, "stars": 3}) == "", "time 0 is not encoded")
	check(C.encode({"mode": 5, "gen": 0, "key": 1, "tenths": 10, "stars": 3}) == "", "reserved mode 5 is not encoded")
	check(C.encode({"mode": 1, "gen": 0, "key": 1, "tenths": 10, "stars": 0}) == "", "0 stars is not encoded")
	check(not C.decode("TW-0000-0000-00000").ok, "the all-zero code is invalid")
	# a reserved mode with a valid CRC is refused as «mode», not as a typo
	var bits: = [0]
	C._push(bits, 6, 3)
	C._push(bits, 0, 3)
	C._push(bits, 5, 32)
	C._push(bits, 100, 17)
	C._push(bits, 3, 2)
	C._push(bits, C.crc7(bits.slice(1)), 7)
	bits = C._whiten(bits)
	var s: = ""
	for i in C.SYMBOLS:
		s += C.ALPHABET[C._read(bits, i * 5, 5)]
	var dm: = C.decode(s)
	check(not dm.ok and String(dm.err) == "mode", "reserved mode 6 → «Такого стола в этой версии нет»")
	check(C.mask_bits().size() == 65 and C.mask_bits().count(1) > 20, "whitening mask is 64 mixed bits")
	var near: = [C.encode({"mode": 1, "gen": 0, "key": 3, "tenths": 600, "stars": 3}), C.encode({"mode": 1, "gen": 0, "key": 4, "tenths": 600, "stars": 3})]
	check(near[0].count("0") <= 6, "a small key does not give a code of zeros (%s)" % near[0])

# ---------------------------------------------------------------- typo detection

func _typo_caught(code_core: String, bad: String) -> bool:
	if bad == code_core:
		return true
	var d: = C.decode(bad)
	return not d.ok


func _typos() -> void:
	_begin("typos")
	var singles: = 0
	var singles_c: = 0
	var swaps: = 0
	var swaps_c: = 0
	var doubles: = 0
	var doubles_c: = 0
	for n in 200:
		var core: = C.core(_rand_payload())
		for i in C.SYMBOLS:
			for ch in C.ALPHABET:
				if ch == core[i]:
					continue
				var bad: = core.substr(0, i) + ch + core.substr(i + 1)
				singles += 1
				if _typo_caught(core, bad):
					singles_c += 1
		for i in C.SYMBOLS - 1:
			if core[i] == core[i + 1]:
				continue
			var sw: = core.substr(0, i) + core[i + 1] + core[i] + core.substr(i + 2)
			swaps += 1
			if _typo_caught(core, sw):
				swaps_c += 1
		# swaps two apart (a common slip in a 4-4-5 group)
		for i in C.SYMBOLS - 2:
			if core[i] == core[i + 2]:
				continue
			var sw2: = core.substr(0, i) + core[i + 2] + core[i + 1] + core[i] + core.substr(i + 3)
			swaps += 1
			if _typo_caught(core, sw2):
				swaps_c += 1
	for n in 30000:
		var core2: = C.core(_rand_payload())
		var i1: = rng.randi() % C.SYMBOLS
		var i2: = (i1 + 1 + rng.randi() % (C.SYMBOLS - 1)) % C.SYMBOLS
		var b: = core2
		for ii in [i1, i2]:
			var ch2: = b[ii]
			while ch2 == b[ii]:
				ch2 = C.ALPHABET[rng.randi() % 32]
			b = b.substr(0, ii) + ch2 + b.substr(ii + 1)
		doubles += 1
		if _typo_caught(core2, b):
			doubles_c += 1
	var rs: = float(singles_c) / singles
	var rw: = float(swaps_c) / swaps
	var rd: = float(doubles_c) / doubles
	var all: = float(singles_c + swaps_c + doubles_c) / (singles + swaps + doubles)
	print("  typos: singles %d/%d, swaps %d/%d, doubles %d/%d (%.2f), all %.4f" % [singles_c, singles, swaps_c, swaps, doubles_c, doubles, rd * 100.0, all])
	check(rs == 1.0, "every single substitution is caught (%d/%d)" % [singles_c, singles])
	check(rw == 1.0, "every transposition is caught (%d/%d)" % [swaps_c, swaps])
	check(rd >= 0.99, "double substitutions caught ≥ 99 (%.2f)" % (rd * 100.0))
	check(all >= 0.99, "typos overall caught ≥ 99 (%.3f)" % (all * 100.0))

# ---------------------------------------------------------------- Crockford normalisation

func _crockford() -> void:
	_begin("crockford")
	var p: = {"mode": 1, "gen": 0, "key": 7, "tenths": 1020, "stars": 3}
	var code: = C.encode(p)
	var core: = C.core(p)
	var low: = code.to_lower()
	check(C.decode(low).ok and String(C.decode(low).core) == core, "lower case")
	check(String(C.decode(core).core) == core, "without TW and dashes")
	check(C.decode(core.substr(0, 4) + " " + core.substr(4, 4) + " " + core.substr(8)).ok, "spaces instead of dashes")
	check(C.decode("tw " + core.substr(0, 4) + "—" + core.substr(4, 4) + " – " + core.substr(8)).ok, "long dashes and spaces mixed")
	# I / L → 1, O → 0 (only where the code has 1 or 0)
	var c2: = ""
	for ch in core:
		c2 += "l" if ch == "1" else ("O" if ch == "0" else ch)
	check(String(C.decode(c2).core) == core, "I/L → 1, O → 0 (%s)" % c2)
	var c3: = core.replace("1", "I")
	check(String(C.decode(c3).core) == core, "I → 1")
	# Cyrillic look-alikes on a Russian keyboard
	var cyr: = C.map_chars("ТW-") + core
	var cy2: = ""
	var back: = {"A": "А", "B": "В", "E": "Е", "K": "К", "M": "М", "H": "Н", "P": "Р", "C": "С", "T": "Т", "X": "Х"}
	for ch in core:
		cy2 += String(back.get(ch, ch))
	check(String(C.decode("ТW-" + cy2).core) == core, "Cyrillic look-alikes → Latin (%s)" % cy2)
	check(String(C.decode("TW-" + core.substr(0, 12) + "U").err) == "u", "U is refused with its own message")
	check(String(C.decode(core.substr(0, 12)).err) == "length", "12 symbols → length message")
	check(String(C.decode("").err) == "empty", "empty input")
	check(String(C.decode(core.substr(0, 12) + "*").err) == "chars", "a stray sign → chars message")
	check(C.normalize(" tw-" + low.substr(3) + " ").ok, "outer spaces")
	for e in C.ERR:
		check(U.bad_words(String(C.ERR[e])).is_empty(), "error text clean: %s" % e)

# ---------------------------------------------------------------- extraction from any text

func _extract() -> void:
	_begin("extract")
	var p: = {"mode": 1, "gen": 0, "key": 5, "tenths": 1023, "stars": 3}
	var code: = C.encode(p)
	var core: = C.core(p)
	var share: = C.share_text(p, {"mode_name": "Путь", "table": "1-6 · Чайный сад", "nick": "Ника Ветер"})
	var d: = C.extract(share)
	check(d.ok and String(d.core) == core and String(d.nick) == "Ника Ветер", "the share text gives the code and the nick")
	check(share.find("Мой стол — 1:42. Сможешь?") >= 0 and share.find(code + ":Ника_Ветер") >= 0, "share text lines")
	var noisy: = "Привет!!! 😊 смотри https://t.me/x?y=TW1234 вот:\n> Код вызова: %s:Ника_Ветер!\nну что, слабо?" % code.to_lower()
	var d2: = C.extract(noisy)
	check(d2.ok and String(d2.core) == core, "code in a forwarded message with an emoji and a link")
	check(String(d2.nick) == "Ника Ветер", "nick after «:» with a trailing «!»")
	var d3: = C.extract("код %s %s %s, жду" % [core.substr(0, 4), core.substr(4, 4), core.substr(8)])
	check(d3.ok and String(d3.core) == core, "a code typed with spaces and no TW inside a sentence")
	var d4: = C.extract("«%s»" % core)
	check(d4.ok and String(d4.core) == core, "13 symbols in guillemets")
	var d5: = C.extract("Ничего тут нет, только TWITTER и 2025-11-24")
	check(not d5.ok and String(d5.err) == "none", "no code → «none»")
	var typo: = code.substr(0, 8) + ("X" if code[8] != "X" else "Y") + code.substr(9)
	var d6: = C.extract("Код вызова: " + typo)
	check(not d6.ok and String(d6.err) == "crc", "a TW code with a typo → «Код не сходится» instead of «нет кода»")
	var p2: = {"mode": 2, "gen": 0, "key": U.day_index("2026-11-20"), "tenths": 900, "stars": 2}
	var two: = "старый: %s, новый: %s:Друг" % [typo, C.encode(p2)]
	var d7: = C.extract(two)
	check(d7.ok and int(d7.mode) == 2 and String(d7.nick) == "Друг", "the first VALID code of several wins")
	check(C.extract_all(two).size() == 2, "extract_all lists both")
	var d8: = C.extract("TW-%s-%s-%s:хуй" % [core.substr(0, 4), core.substr(4, 4), core.substr(8)])
	check(d8.ok and String(d8.nick) == "", "a bad nick is dropped, the code still works")
	var d9: = C.extract("ТW-" + core)  # Cyrillic Т
	check(d9.ok, "Cyrillic Т in TW")
	var d10: = C.extract("random words AAAAAAAAAAAAA and 1234-5678-ABCDE")
	check(not d10.ok, "random 13-letter words are not codes")

# ---------------------------------------------------------------- nick

func _nick() -> void:
	_begin("nick")
	check(C.clean_nick("Ника") == "Ника", "plain nick")
	check(C.clean_nick("Ника_Ветер") == "Ника Ветер", "underscores → spaces")
	check(C.clean_nick("Ни") == "", "shorter than G.NICK_MIN")
	check(C.clean_nick("ОченьДлинныйНикБольше16") == "", "longer than G.NICK_MAX")
	check(C.clean_nick("Сука_Ника") == "", "profanity filter (V8 list)")
	check(C.clean_nick("fuckboy") == "", "English profanity")
	check(C.clean_nick("Бот Вася") == "Бот Вася", "«бот» is a word, not profanity, in a player nick")
	check(C.nick_suffix("Ника Ветер") == ":Ника_Ветер", "suffix with «_»")
	check(C.nick_suffix("бля") == "", "no suffix for a bad nick")
	check(C.nick_suffix("") == "", "no suffix without a nick")
	var p: = {"mode": 1, "gen": 0, "key": 2, "tenths": 700, "stars": 3}
	var st_bad: = C.share_text(p, {"nick": "пиздец"})
	check(st_bad.rfind(":") == st_bad.find("Код вызова:") + 10 and not st_bad.contains("пиздец"), "share text drops a bad nick")

# ---------------------------------------------------------------- deal

func _deal() -> void:
	_begin("deal")
	var gp: = D.cur_gen("path")
	check(gp >= 0, "Путь has a generation in this build (%d)" % gp)
	check(D.cur_gen("journey") == D.JOURNEY_GEN, "Странствие generation %d" % D.JOURNEY_GEN)
	check(D.journey_fp() == D.JOURNEY_FP, "V10Journey generator constants unchanged (else bump JOURNEY_GEN): %s" % D.journey_fp())
	var p: = {"mode": 1, "gen": gp, "key": D.path_key(3), "tenths": 900, "stars": 3}
	var r: = D.resolve(p)
	check(r.ok and int(r.pairs) >= 2, "Путь 1-4 resolves (%s)" % String(r.get("table", r.get("err_text", ""))))
	var pg: = p.duplicate()
	pg.gen = (gp + 1) % 8
	var rg: = D.resolve(pg)
	check(not rg.ok and String(rg.err) == "gen" and int(rg.gen_here) == gp, "another generation → «gen» with both versions")
	check(U.bad_words(String(rg.err_text)).is_empty() and String(rg.err_text).find("Обнов") >= 0, "the gen message says what to do")
	check(not D.resolve({"mode": 1, "gen": gp, "key": D.path_key(9999)}).ok, "a level past the list → key")
	check(not D.resolve({"mode": 1, "gen": gp, "key": D.path_key(1) | (1 << 30)}).ok, "reserved key bits → key")
	if gp == 0:
		check(not D.resolve({"mode": 1, "gen": 0, "key": D.path_key(1, 5)}).ok, "gen 0 has no salt")
		check(D.cur_gen("peak") == -1 and String(D.resolve({"mode": 4, "gen": 0, "key": 1}).err) == "closed", "Пик closed until the 0.10 levels are in G.LEVELS")
	# plausibility
	var pairs: = int(r.pairs)
	check(not D.resolve({"mode": 1, "gen": gp, "key": p.key, "tenths": C.min_tenths(pairs) - 1}).ok, "faster than 0,35 s × pairs → impossible time")
	check(D.resolve({"mode": 1, "gen": gp, "key": p.key, "tenths": C.min_tenths(pairs)}).ok, "exactly 0,35 s × pairs is allowed")
	check(String(D.resolve({"mode": 1, "gen": gp, "key": p.key, "tenths": 5}).err) == "time", "0,5 s → «Время в коде невозможное»")
	check(C.min_tenths(20) == 70 and not C.plausible(69, 20) and C.plausible(70, 20), "min_tenths(20) = 7,0 s")
	# one code ⇒ one deal
	var h1: = D.deal_hash(p)
	check(h1 != 0 and h1 == D.deal_hash(p.duplicate()), "same code ⇒ same deal hash")
	var p_t: = p.duplicate()
	p_t.tenths = 1500
	check(D.deal_hash(p_t) == h1, "the time does not change the deal")
	check(D.deal_hash({"mode": 1, "gen": gp, "key": D.path_key(4)}) != h1, "another level → another deal")
	var hashes: = {}
	for i in mini(30, (G.LEVELS as Array).size()):
		hashes[D.deal_hash({"mode": 1, "gen": gp, "key": D.path_key(i)})] = true
	check(hashes.size() == mini(30, (G.LEVELS as Array).size()), "30 levels → 30 deal hashes")
	# the dealt board: same cfg + same seed ⇒ the same tiles (positions, faces, steps, gold, ice, secret)
	var cfg: Dictionary = r.cfg
	var fps: = []
	for k in 2:
		var b: = TrayBoard.new()
		add_child(b)
		randomize()
		randi()
		seed(int(cfg.seed))
		b.setup(cfg)
		randomize()
		fps.append(D.board_fingerprint(b))
		b.queue_free()
	check(fps[0] == fps[1], "same code ⇒ same dealt board (fingerprint)")
	# Партия дня
	var day: = "2026-11-20"
	U.fake_day = "2026-11-24"
	var pd: = {"mode": 2, "gen": D.cur_gen("daily"), "key": U.day_index(day)}
	var rd: = D.resolve(pd)
	check(rd.ok and int(rd.seed) == 20261120 and String(rd.table) == "20 ноября", "Партия дня 20 ноября: seed 20261120, table «20 ноября»")
	check(String(D.resolve({"mode": 2, "gen": pd.gen, "key": U.day_index("2026-12-30")}).err) == "future", "a day far ahead → «future»")
	check(not D.resolve({"mode": 2, "gen": pd.gen, "key": U.day_index("2020-01-01")}).ok, "before the first day → key")
	check(D.deal_hash(pd) == D.deal_hash(pd.duplicate()) and D.deal_hash(pd) != D.deal_hash({"mode": 2, "gen": pd.gen, "key": pd.key + 1}), "daily hash per day")
	U.fake_day = ""
	# Странствие (the table of the week without blessings or curses)
	if D.journey() != null:
		var pj: = {"mode": 3, "gen": D.JOURNEY_GEN, "key": D.journey_key(2, 1)}
		var rj: = D.resolve(pj)
		check(rj.ok and int(rj.pairs) >= 2, "Странствие week 2 board 2 resolves (%s)" % String(rj.get("table", rj.get("err_text", ""))))
		check(D.deal_hash(pj) == D.deal_hash(pj.duplicate()), "Странствие: same code ⇒ same hash")
		check(not D.resolve({"mode": 3, "gen": D.JOURNEY_GEN, "key": D.journey_key(2, 7)}).ok, "board 8 of 5 → key")
	# ctx → payload
	var pc: = D.payload_from_ctx({"mode": "path", "lvl": 3})
	check(pc.ok and int(pc.key) == D.path_key(3) and int(pc.gen) == gp, "payload_from_ctx Путь")
	check(not D.payload_from_ctx({"mode": "blitz"}).ok, "no challenge from Блиц")
	check(C.MODES.size() == 4 and C.RESERVED == [0, 5, 6, 7], "modes 1–4, 0 / 5 / 6 / 7 reserved")

# ---------------------------------------------------------------- rewards

func _rewards() -> void:
	_begin("rewards")
	ST.bind({})
	paid.clear()
	U.fake_now = 1795000000
	U.fake_day = "2026-11-24"
	U.fake_clock_ok = true
	var gp: = D.cur_gen("path")
	var codes: = []
	for i in 5:
		var p: = {"mode": 1, "gen": gp, "key": D.path_key(i + 1), "tenths": 900, "stars": 3}
		var dc: = C.decode(C.encode(p))
		dc.nick = "Друг"
		codes.append(dc)
	check(ST.beats(899, 3, 900, 3) and not ST.beats(900, 3, 900, 3) and not ST.beats(800, 2, 900, 3) and ST.beats(800, 3, 900, 2), "beats = faster and not fewer stars")
	var r1: = ST.finish(codes[0], 950, 3)
	check(not r1.won and r1.reward.is_empty() and String(r1.reason) == "lose", "a loss pays nothing")
	check(String(ST.find(String(codes[0].core)).result) == "lose" and int(ST.find(String(codes[0].core)).tries) == 1, "a loss is recorded")
	var won: = 0
	for i in 4:
		var r: = ST.finish(codes[i], 850, 3)
		if not r.reward.is_empty():
			won += 1
		if i == 3:
			check(r.won and r.reward.is_empty() and String(r.reason) == "cap", "the 4th win of the day → «cap»")
	check(won == 3, "3 paid wins a day (%d)" % won)
	check(paid.size() == 3 and int(paid[0].r.gems) == ST.win_gems() and String(paid[0].src) == "challenge_win", "paid through apply_rewards: +%d each" % ST.win_gems())
	check(ST.rewards_left() == 0, "rewards_left 0 after the cap")
	check(int(ST.st().stats.wins) == 4, "stats.wins counts every win")
	var r_again: = ST.finish(codes[0], 800, 3)
	check(r_again.won and String(r_again.reason) == "paid" or String(r_again.reason) == "cap", "the same code never pays twice")
	U.fake_day = "2026-11-25"
	check(ST.rewards_left() == 3, "a new day (04:00) → 3 again")
	var r_paid: = ST.finish(codes[1], 700, 3)
	check(r_paid.won and String(r_paid.reason) == "paid" and r_paid.reward.is_empty(), "a code that paid yesterday does not pay today")
	var r_new: = ST.finish(codes[4], 700, 3)
	check(not r_new.reward.is_empty(), "a new code pays on the new day")
	# own code
	var own_p: = {"mode": 1, "gen": gp, "key": D.path_key(7), "tenths": 1200, "stars": 3}
	ST.record_sent(own_p, C.core(own_p), {"title": "1-8"})
	var own_dc: = C.decode(C.encode(own_p))
	var r_own: = ST.finish(own_dc, 600, 3)
	check(r_own.won and String(r_own.reason) == "own" and r_own.reward.is_empty(), "the player's own code never pays")
	# the phone clock moved back
	U.fake_clock_ok = false
	var p9: = {"mode": 1, "gen": gp, "key": D.path_key(9), "tenths": 1200, "stars": 3}
	var r_clk: = ST.finish(C.decode(C.encode(p9)), 600, 3)
	check(r_clk.won and String(r_clk.reason) == "clock" and r_clk.reward.is_empty(), "no reward while the clock is moved back")
	U.fake_clock_ok = true
	# best result kept, list capped at 20, newest first
	var e0: = ST.find(String(codes[0].core))
	check(int(e0.my_t) == 800 and String(e0.result) == "win" and int(e0.tries) == 3, "best time and the win are kept (%s)" % str(e0.get("my_t")))
	for i in 25:
		var pp: = {"mode": 1, "gen": gp, "key": D.path_key(10 + i % 20), "tenths": 1000 + i, "stars": 2}
		ST.record_taken(C.decode(C.encode(pp)), {"title": "x"})
	check(ST.entries().size() == ST.LIST_MAX, "the list keeps the last %d" % ST.LIST_MAX)
	check(String(ST.entries()[0].core) == C.core({"mode": 1, "gen": gp, "key": D.path_key(10 + 24 % 20), "tenths": 1024, "stars": 2}), "newest first")
	# texts
	for k in ST.REASON_TEXT:
		check(U.bad_words(String(ST.REASON_TEXT[k])).is_empty(), "reason text clean: %s" % k)
	# apply_rewards without a sink: V10Money.grant updates both econ wallet and G.S.gems mirror
	U.reward_sink = Callable()
	var g0: = V10Money.bal("gems")
	U.apply_rewards({"gems": 5}, "challenge_win")
	check(V10Money.bal("gems") == g0 + 5 and int(G.S.gems) == g0 + 5, "apply_rewards → V10Money.grant (+5 crystals)")
	V10Money.grant({"gems": -5}, "challenge_selftest_restore")
	U.reward_sink = func(r: Dictionary, src: String): paid.append({"r": r, "src": src})
	# the save key
	var S: = {}
	ST.bind(S)
	ST.st()
	check(S.has("v10_challenge") and int(S.v10_challenge.ver) == 1, "S.v10_challenge created lazily")
	S.v10_challenge.list = "broken"
	S.v10_challenge.day = {"key": "x"}
	ST.st()
	check(S.v10_challenge.list is Array and (S.v10_challenge.day as Dictionary).has("n"), "a damaged key is repaired")
	ST.bind(null)
	U.fake_now = 0
	U.fake_day = ""

# ---------------------------------------------------------------- poster

func _poster() -> void:
	_begin("poster")
	var oa: = P.outfit_art("hana", "h_beach")
	check(oa.swapped and String(oa.img) == "hana_winter" and oa.kind == "art", "h_beach (bold) → its SFW alt hana_winter")
	var ob: = P.outfit_art("yue", "y_duel")
	check(ob.swapped and ob.kind == "cutout", "y_duel (bold, alt = base) → the base cut-out")
	var oc: = P.outfit_art("nova", "n_ssr")
	check(oc.swapped and oc.kind == "cutout", "n_ssr (bold) → nova base")
	var od: = P.outfit_art("rin", "r_maid")
	check(not od.swapped and String(od.img) == "rin_maid", "a SFW outfit is kept")
	var oe: = P.outfit_art("mc", "o_tutor")
	check(String(oe.img) != "mc_tutor", "a retired image is not used")
	var cnt_bold: = 0
	for id in G.ITEM:
		var it: Dictionary = G.ITEM[id]
		if String(it.get("cat", "")) != "outfit":
			continue
		var art: = P.outfit_art(String(it.hero), String(id))
		var sfw: = bool(it.get("sfw", not bool(it.get("bold", false))))
		if not sfw:
			cnt_bold += 1
			if String(art.img) == String(it.img):
				check(false, "bold outfit %s shown on the poster" % id)
	check(cnt_bold >= 3, "every bold outfit swapped (%d)" % cnt_bold)
	var p: = {"mode": 1, "gen": D.cur_gen("path"), "key": D.path_key(3), "tenths": 1023, "stars": 3}
	var deal: = D.resolve(p)
	for look in [["mc", ""], ["rin", "r_maid"], ["hana", "h_beach"], ["nova", "n_base"]]:
		var inf: = P.info(p, deal, {"hero": look[0], "outfit": look[1], "nick": "Ника Ветер"})
		var poster: = P.make(inf)
		add_child(poster)
		check(P.face_clear(poster), "%s: no text over the face + 48" % look[0])
		var texts: = []
		for n in poster.get_meta("text_nodes", []):
			texts.append((n as Label).text)
		check(" ".join(texts).find("1:42") >= 0 and " ".join(texts).find(String(inf.code)) >= 0, "%s: time and code on the poster" % look[0])
		check(String(inf.line) == "Мой стол — 1:42. Сможешь?", "the line")
		poster.queue_free()
	if rendering:
		var inf2: = P.info(p, deal, {"hero": "hana", "outfit": "h_beach", "nick": "Ника Ветер"})
		var img: Image = await P.render(inf2, self)
		check(img.get_width() == 720 and img.get_height() == 1280, "PNG 720×1280 (%s)" % str(img.get_size()))
		var lit: = 0
		var cols: = {}
		for y in range(0, 1280, 16):
			for x in range(0, 720, 16):
				var c: = img.get_pixel(x, y)
				if c.get_luminance() > 0.2:
					lit += 1
				cols[c.to_html(false).substr(0, 3)] = true
		check(lit > 200 and cols.size() > 30, "poster pixels are not empty (lit %d, tones %d)" % [lit, cols.size()])
		var path: = U.save_poster(img, "selftest")
		check(path != "" and FileAccess.file_exists(path), "poster saved as PNG into the game album folder")
		var back: = Image.load_from_file(path) if path != "" else null
		check(back != null and back.get_width() == 720, "the saved PNG reads back")

# ---------------------------------------------------------------- the real main

func _boot_main() -> void:
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	# the title splash (skipped by --shots in the demo) is hidden so its _wait_tap coroutine never sees a freed node
	for c in main.get_children():
		if not c in [main.screen_root, main.topbar, main.navbar, main.overlay, main.trans, main.finger]:
			if c is CanvasItem:
				(c as CanvasItem).visible = false
			if c is Control:
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


# budgets of one layer (UX §3.7 work screen, §10 П-1, В-2, В-6, С-1)
func audit(root: Node, what: String, face: = Rect2()) -> Dictionary:
	var roles: = {"primary": [], "secondary": [], "tertiary": []}
	var taps: = []
	var sizes: = {}
	var words: = 0
	var texts: = []
	var small: = []
	var bad: = []
	var cover: = []
	var stack: = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is SubViewport:
			continue
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		for c in n.get_children():
			stack.append(c)
		if n.has_meta("ux_role") and roles.has(String(n.get_meta("ux_role"))):
			roles[String(n.get_meta("ux_role"))].append(n)
		if n is V10Button or n.has_meta("ux_tap") or n is LineEdit:
			taps.append(n)
			var cs: = (n as Control).size
			if cs.x < 80 or cs.y < 80:
				small.append("%s %s" % [n.name, str(cs)])
		if n is Label:
			var l: = n as Label
			if l.text.strip_edges() == "" or l.modulate.a < 0.05:
				continue
			var fs: = l.label_settings.font_size if l.label_settings else 16
			sizes[fs] = true
			if fs < 18 and not (fs == 15 and l.text == l.text.to_upper()):
				small.append("text %d «%s»" % [fs, l.text])
			texts.append(l.text)
			for w in l.text.split(" ", false):
				if RegEx.create_from_string("[A-Za-zА-Яа-яЁё]{2,}").search(w) != null:
					words += 1
			var b: = U.bad_words(l.text)
			if not b.is_empty():
				bad.append("«%s» %s" % [l.text, str(b)])
		if face.size != Vector2.ZERO and n is Control and (n is Label or n is V10Button or n is UI2.Plate) and n.name != "Heroine":
			var gr: = Rect2((n as Control).global_position, (n as Control).size)
			if gr.intersects(face.grow(48)):
				cover.append(String(n.name))
	var prim: Array = roles.primary
	var vs: = get_viewport().get_visible_rect().size
	check(prim.size() == 1, "%s: exactly 1 primary (%d)" % [what, prim.size()])
	check(roles.secondary.size() <= 2, "%s: ≤ 2 secondary (%d)" % [what, roles.secondary.size()])
	check(roles.tertiary.size() <= 2, "%s: ≤ 2 quiet (%d)" % [what, roles.tertiary.size()])
	check(taps.size() <= 10, "%s: ≤ 10 tappable (%d)" % [what, taps.size()])
	check(small.is_empty(), "%s: hit zones ≥ 80, text ≥ 18 %s" % [what, str(small)])
	check(sizes.size() <= 4, "%s: ≤ 4 type sizes %s" % [what, str(sizes.keys())])
	check(words <= 60, "%s: ≤ 60 words (%d)" % [what, words])
	check(bad.is_empty(), "%s: words (UX §4, V10Lint, no «%%» «₽») %s" % [what, str(bad)])
	if prim.size() == 1:
		var pb: Control = prim[0]
		check(pb.size.x >= 440 and pb.size.y >= 104 and pb.global_position.y >= vs.y * 2.0 / 3.0 - 1.0,
			"%s: «Игра» ≥ 440×104 in the bottom third (%s at %d)" % [what, str(pb.size), int(pb.global_position.y)])
	if face.size != Vector2.ZERO:
		check(cover.is_empty(), "%s: nothing over face_rect + 48 %s" % [what, str(cover)])
	return {"texts": texts, "words": words, "sizes": sizes.keys(), "taps": taps.size()}


func _screen() -> Control:
	return main.screen


func _sheet() -> Control:
	return UI2.Sheet.current

# ---------------------------------------------------------------- UI budgets and strings

func _ui() -> void:
	_begin("ui")
	ST.bind(null)
	G.S.erase("v10_challenge")
	U.go_challenge(main, {})
	await _wait(0.5)
	var sc: = _screen()
	check(sc is V10ChallengeScreen and String(main.screen_id) == "challenge", "the screen opens (screen_id challenge)")
	check(sc.header != null and sc.header.title_lbl.text == "Вызов по коду", "one V10Header «Вызов по коду»")
	audit(sc, "home, empty", sc.page.get_meta("face_rect", Rect2()))
	# empty clipboard → the hint in the slot, no crash
	U.clip_set("")
	sc.paste()
	await _wait(0.3)
	check(sc.state == "home" and sc.last_error != "", "empty clipboard → hint, stays home")
	U.clip_set("привет, как дела")
	sc.paste()
	await _wait(0.3)
	check(String(sc.last_error).find("нет кода") >= 0, "no code in the text → «В тексте нет кода вызова…»")
	var p: = {"mode": 1, "gen": D.cur_gen("path"), "key": D.path_key(3), "tenths": 1023, "stars": 3}
	var bad_gen: = p.duplicate()
	bad_gen.gen = (int(p.gen) + 3) % 8
	U.clip_set("Код вызова: " + C.encode(bad_gen))
	sc.paste()
	await _wait(0.3)
	check(sc.state == "card" and not sc.cur.deal.ok and String(sc.cur.deal.err) == "gen", "a code of another generation → a clear card, no game")
	audit(sc, "card, other version")
	U.clip_set(C.share_text(p, {"mode_name": "Путь", "table": "1-4", "nick": "Ника Ветер"}))
	sc.paste()
	await _wait(0.4)
	check(sc.state == "card" and sc.cur.deal.ok, "«Вставить» → the card")
	var card_t: = audit(sc, "card")
	var tx: = " ".join(card_t.texts)
	check(tx.find("Вызов от Ника Ветер") >= 0 and tx.find("1:42,3") >= 0 and tx.find("Время не проверено сервером") >= 0, "card: author, time, «время не проверено сервером»")
	check(tx.find("Награда: +5 кристаллов") >= 0 or tx.find("Награда") >= 0, "card: what a win pays")
	check(sc.btn_primary.text == "Играть", "card primary «Играть»")
	# back → home with the list
	check(sc.handle_back() and sc.state == "home", "back from the card → home")
	await _wait(0.4)
	audit(sc, "home, list")
	check(sc.page.get_node_or_null("List") != null, "the list of challenges is shown")
	# manual entry sheet
	sc.open_manual()
	await _wait(0.4)
	var sh: = _sheet()
	check(sh != null and sh.body.get_node_or_null("CodeField") != null, "«Ввести вручную» → the sheet with one field")
	audit(sh, "manual sheet")
	var le: LineEdit = sh.body.get_node("CodeField")
	le.text = C.core(p).to_lower()
	le.text_changed.emit(le.text)
	check(String((sh.body.get_node("FieldCaption") as Label).text).begins_with("Код верный"), "live check: «Код верный»")
	le.text_submitted.emit(le.text)
	await _wait(0.4)
	check(sc.state == "card" and _sheet() == null, "submit → the card, the sheet closed")
	# help
	sc._help()
	await _wait(0.4)
	audit(_sheet(), "help sheet")
	sc._help()  # a second sheet replaces the first, never over it
	await _wait(0.3)
	var n_sheets: = 0
	for c in main.overlay.get_children():
		if c is UI2.Sheet and not c.is_queued_for_deletion() and not c._closing:
			n_sheets += 1
	check(n_sheets == 1, "never a sheet over a sheet (%d)" % n_sheets)
	_sheet().close(true)
	await _wait(0.2)
	# the throw sheet
	var ctx: = {"p": p, "deal": D.resolve(p), "hero": "hana", "outfit": "h_beach", "nick": "Ника Ветер"}
	U.clip_set("SENTINEL")
	var ts: = SCR.open_throw(sc, ctx)
	await _wait(0.5)
	audit(ts, "throw sheet")
	var pv: Node = ts.body.get_node_or_null("PosterVP")
	check(pv is SubViewport and (pv as SubViewport).get_child(0).get_meta("art").img == "hana_winter", "throw preview uses the SFW look")
	check(U.clip_get() == "SENTINEL", "nothing is copied before the tap")
	var clip_before: = U.clip_get()
	(ts.body.get_node("Btn_Copy") as V10Button).pressed.emit()
	await _wait(0.2)
	check(U.clip_get() != clip_before and U.clip_get().find(C.encode(p) + ":Ника_Ветер") >= 0, "«Скопировать текст» → the full share text with the code and the nick")
	check(ST.find(C.core(p)).get("kind", "") == "sent" and ST.is_own(C.core(p)), "a shared code is recorded as sent and own")
	if rendering:
		(ts.body.get_node("Btn_Save") as V10Button).pressed.emit()
		await _wait(0.8)
		var sp: = String(ts.get_meta("saved_path", ""))
		check(sp != "" and FileAccess.file_exists(sp), "«Сохранить в альбом» → PNG in the album folder")
	ts.close(true)
	await _wait(0.2)
	# a run's sheets (on a live play screen)
	U.go_play(main, {"challenge": _ch_of(p, "Ника Ветер"), "partner": "mc"})
	await _wait(2.4)
	var pl: Control = main.screen
	check(String(pl.get("mode")) == "challenge", "«Играть» → the play screen in mode challenge")
	var run: = RUN.of(pl)
	check(run != null and run.strip != null and run.strip.is_visible_in_tree(), "the pace strip is on")
	await _wait(0.3)
	var st_txt: = String(run.strip.cap.text)
	check(st_txt == "Ника Ветер · 1:42", "strip caption «Ника Ветер · 1:42» (%s)" % st_txt)
	var gp = pl.get("gems_lbl")
	check(gp is Label and not ((gp as Label).get_parent() as Control).visible, "no crystals in the match: the pill is hidden")
	var pc: = RUN.pace(51.15, 9, 18, 102.3)
	check(absf(float(pc.me) - 0.5) < 0.001 and absf(float(pc.ghost) - 0.5) < 0.001, "pace: half the pairs at half the author's time")
	var fs: = run.on_fail()
	await _wait(0.4)
	audit(fs, "fail sheet")
	check((fs.body.get_node("Btn_Вернуть_3_фишки") if fs.body.has_node("Btn_Вернуть_3_фишки") else null) != null, "fail sheet: «Вернуть 3 фишки» (free)")
	fs.close(true)
	await _wait(0.2)
	run.result = ST.finish(run.ch, 980, 3)
	run.result.nick = "Ника Ветер"
	run.result.own = false
	var rs: = run.show_result()
	await _wait(0.5)
	var rt: = audit(rs, "result sheet, win")
	check(" ".join(rt.texts).find("Ты против Ника Ветер: −4,3 с") >= 0, "«Ты против Ника Ветер: −4,3 с»")
	rs.on_close = Callable()
	rs.close(true)
	run.result = ST.finish(run.ch, 1100, 2)
	run.result.nick = "Ника Ветер"
	var rs2: = run.show_result()
	await _wait(0.5)
	var rt2: = audit(rs2, "result sheet, loss")
	check(" ".join(rt2.texts).find("+7,7 с") >= 0, "a loss shows «+7,7 с»")
	rs2.on_close = Callable()
	rs2.close(true)
	await _wait(0.2)


func _ch_of(p: Dictionary, nick: String) -> Dictionary:
	var dc: = C.decode(C.encode(p))
	return {"mode": int(p.mode), "gen": int(p.gen), "key": int(p.key), "tenths": int(p.tenths), "stars": int(p.stars),
		"core": String(dc.core), "code": String(dc.code), "nick": nick, "title": String(D.resolve(p).get("table", ""))}

# ---------------------------------------------------------------- two profiles: the author → a friend

func _bot(pl: Control, max_s: = 60.0) -> bool:
	var b = pl.get("board")
	var t0: = U.tick_ms()
	while is_instance_valid(pl) and is_instance_valid(b) and b.board_count() > 0 and (U.tick_ms() - t0) < max_s * 1000.0:
		if b.input_on:
			var t = b.solver_move()
			if t:
				b.tap(t)
		await _wait(0.09)
	return is_instance_valid(b) and b.board_count() == 0


func _e2e() -> void:
	_begin("e2e")
	paid.clear()
	# --- the author plays 1-4 (the hooked play screen: the deal is seeded like the hook asks)
	_profile(SAVE_A, "Ника Ветер")
	U.go_challenge(main, {})
	await _wait(0.3)
	U.open_screen(main, load(PLAY), "play", {"level": 3, "partner": "mc"})
	await _wait(2.2)
	var pa: Control = main.screen
	check(String(pa.get("mode")) == "" and int(pa.get("lvl")) == 3, "author: Путь 1-4 on the hooked play screen")
	var fp_a: = int(pa.get("ch_fingerprint"))
	check(fp_a != 0, "author: the deal fingerprint is taken")
	var won_a: = await _bot(pa)
	check(won_a, "author: the table is cleared by the bot")
	await _wait(0.2)
	var secs_a: = 0.0
	if is_instance_valid(pa):
		secs_a = maxf(1.0, float(pa.call("now")) - float(pa.get("start_t")))
	var ctx: = RUN.ctx_from_play(pa, secs_a + 30.0, 3)  # a slow author: the friend can beat this time
	check(ctx.ok and int(ctx.p.key) == D.path_key(3), "author: the win gives a challenge ctx (%s)" % str(ctx.get("err_text", "")))
	var sheet: = SCR.open_throw(main.screen, ctx)
	await _wait(0.4)
	(sheet.body.get_node("Btn_Copy") as V10Button).pressed.emit()
	var text: = U.clip_get()
	var code: = C.encode(ctx.p)
	check(text.find(code + ":Ника_Ветер") >= 0, "author: the copied text holds the code and «:Ника_Ветер»")
	sheet.close(true)
	check(ST.is_own(C.core(ctx.p)), "author: the code is the author's own")
	G.save()
	# --- the friend: another profile on the same phone
	_profile(SAVE_B, "Дружок")
	check(not ST.is_own(C.core(ctx.p)) and ST.entries().is_empty(), "friend: a clean profile")
	var gems0: = int(G.S.gems)
	U.go_challenge(main, {})
	await _wait(0.5)
	U.clip_set("Смотри, что Ника прислала:\n" + text)
	var sc: = _screen()
	sc.paste()
	await _wait(0.4)
	check(sc.state == "card" and sc.cur.deal.ok and String(sc.cur.dc.nick) == "Ника Ветер", "friend: «Вставить» → the card of Ника Ветер")
	check(ST.no_pay_reason(C.core(ctx.p)) == "", "friend: a win would pay")
	var dc_b: Dictionary = sc.cur.dc.duplicate(true)
	check(not SCR.can_throw_from_victory({"unlocked": 15}) and SCR.can_throw_from_victory({"unlocked": 16}), "Victory ⋯ gate: hidden before L15, open from L15")
	check(SCR.victory_more_item(pa if is_instance_valid(pa) else sc, 45.0, 3, {"unlocked": 10}).is_empty(), "Victory ⋯ item empty before L15")
	sc.play()
	await _wait(2.4)
	var pb: Control = main.screen
	check(String(pb.get("mode")) == "challenge", "friend: the run starts")
	check(int(pb.get("ch_fingerprint")) == fp_a, "friend: the SAME deal as the author's (board fingerprint)")
	check(D.deal_hash(ctx.p) == D.deal_hash(dc_b), "friend: the same deal hash")
	var gb: = int(G.S.gems)
	var won_b: = await _bot(pb)
	check(won_b, "friend: the table is cleared")
	await _wait(1.0)
	check(int(G.S.gems) == gb, "friend: no crystals per pair in a challenge (%d → %d)" % [gb, int(G.S.gems)])
	var rs: = _sheet()
	check(rs != null and rs.name == "ResultSheet", "friend: the result sheet opens")
	var e: = ST.find(C.core(ctx.p))
	check(String(e.get("result", "")) == "win" and bool(e.get("rewarded", false)), "friend: the win is recorded and rewarded")
	check(paid.size() == 1 and int(paid[0].r.gems) == 5, "friend: +5 crystals once")
	var title: = ""
	if rs:
		var tl: Node = rs.body.get_node_or_null("ResultTitle")
		title = (tl as Label).text if tl else ""
	check(title.begins_with("Ты против Ника Ветер: −"), "friend: «%s»" % title)
	# «Реванш»: the friend's time goes back as a new code
	var run: = RUN.of(pb)
	run.revenge()
	await _wait(0.4)
	var ts: = _sheet()
	check(ts != null and ts.name == "ThrowSheet", "«Реванш» → «Бросить вызов» with the friend's time")
	(ts.body.get_node("Btn_Copy") as V10Button).pressed.emit()
	var back: = C.extract(U.clip_get())
	check(back.ok and String(back.nick) == "Дружок" and int(back.tenths) == int(run.result.my_t) and int(back.key) == int(ctx.p.key), "the return code: same table, the friend's time and nick")
	ts.on_close = Callable()
	ts.close(true)
	await _wait(0.2)
	# a second win on the same code pays nothing
	var r2: = ST.finish(run.ch, 10, 3)
	check(r2.won and r2.reward.is_empty() and String(r2.reason) == "paid", "the same code does not pay twice")
	G.save()
	# --- back to the author: the friend's return code is someone else's → it would pay
	G.save_path = SAVE_A
	G.load_game()
	ST.bind(null)
	check(ST.is_own(C.core(ctx.p)), "author profile reloaded: own code remembered")
	check(ST.no_pay_reason(C.core(back)) == "", "author: the friend's return code would pay")
	check(ST.no_pay_reason(C.core(ctx.p)) == "own", "author: own code → «Свой вызов — без награды»")
	U.go_challenge(main, {})
	await _wait(0.4)

# ---------------------------------------------------------------- files: tokens only, clean strings

func _files() -> void:
	_begin("files")
	var hex: = RegEx.create_from_string("Color\\(\\s*\"|Color8\\(|Color\\(0x|#[0-9A-Fa-f]{6}\\b")
	var lit: = RegEx.create_from_string("\"([^\"\\\\]*[А-Яа-яЁё][^\"\\\\]*)\"")
	for f in UI_FILES:
		var src: = FileAccess.get_file_as_string("res://scripts/v10/duels/challenge/" + f)
		check(src != "", "%s readable" % f)
		var hits: = []
		for m in hex.search_all(src):
			hits.append(m.get_string())
		check(hits.is_empty(), "%s: colours only from V10DS (no hex) %s" % [f, str(hits)])
	var bad: = []
	var n: = 0
	for f in ALL_FILES:
		var src2: = FileAccess.get_file_as_string("res://scripts/v10/duels/challenge/" + f)
		var in_banned: = false
		for line in src2.split("\n"):
			var st_line: = line.strip_edges()
			if st_line.begins_with("#"):
				continue
			if st_line.begins_with("const UI_BANNED"):
				in_banned = true
			if in_banned:
				if "]" in st_line:
					in_banned = false
				continue
			for m in lit.search_all(line):
				var s: = m.get_string(1)
				n += 1
				var b: = U.bad_words(s.replace("%s", "").replace("%d", "").replace("%%", ""))
				if not b.is_empty():
					bad.append("%s: «%s» %s" % [f, s, str(b)])
	check(n > 60 and bad.is_empty(), "every Russian string literal passes V10Lint + UX §4 (%d strings) %s" % [n, str(bad)])
	var src3: = FileAccess.get_file_as_string("res://scripts/v10/duels/challenge/challenge_deal.gd") + FileAccess.get_file_as_string("res://scripts/v10/duels/challenge/challenge_code.gd")
	check(src3.find("randi()") < 0 and src3.find("randf()") < 0, "no global randomness in the code and the deal")
	var src4: = FileAccess.get_file_as_string("res://scripts/v10/duels/challenge/challenge_screen.gd")
	check(src4.count("U.clip_get()") == 1, "the clipboard is read in one place (the «Вставить» tap)")
