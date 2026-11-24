class_name V8RecoverySelftest
extends RefCounted

# Headless checks for the 0.8 core: recovery codes, robust save and add_rp.
# Run: godot --headless --path game -- --recovery_selftest=1   (prints "RECOVERY SELFTEST n/m", exit code 1 on failure)
# Works on a scratch save path (user://selftest/), never touches the player's real save; G.S is restored afterwards.

static var _pass: = 0
static var _fail: = 0


static func run() -> int:
	_pass = 0
	_fail = 0
	var real_state: Dictionary = G.S
	var real_path: String = G.save_path
	var real_ok: bool = G._main_ok
	DirAccess.make_dir_recursive_absolute("user://selftest")
	G.save_path = "user://selftest/save.json"
	for p in ["user://selftest/save.json", "user://selftest/save.bak.json", "user://selftest/save.tmp.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	G._main_ok = false
	_round_trip()
	_bad_codes()
	_save_fallback()
	_migration_v5()
	_add_rp()
	G.S = real_state
	G.save_path = real_path
	G._main_ok = real_ok
	printerr("RECOVERY SELFTEST %d/%d" % [_pass, _pass + _fail])
	return _fail


static func _check(name: String, ok: bool, info: = "") -> void :
	if ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		printerr("FAIL ", name, " ", info)


static func _norm(d) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(d)), "", true)


static func late_game_state() -> Dictionary:
	var s: = G.default_state()
	s.gems = 23456
	s.coins = 98765
	s.unlocked = G.LEVELS.size()
	for i in G.LEVELS.size():
		s.stars[str(i)] = 1 + i % 3
	for it in G.ITEMS:
		s.owned[it.id] = true
	s.partner = "yue"
	s.outfit = {"mc": "o_dragon", "rin": "r_idol", "hana": "h_gym", "yue": "y_queen", "nova": "n_ssr"}
	s.skin = "s_gold"
	s.aff = {"mc": 940, "rin": 612, "hana": 455, "yue": 380, "nova": 207}
	s.shards = {"rin": 5, "hana": 5, "yue": 5, "nova": 5}
	s.rp = 1777
	s.pulls = 312
	s.pity = 37
	s.yaku_seen = {"clean": true, "calm": true, "riichi": true, "dragon": true}
	s.v6_map = {"chests": {"0": true, "1": true, "2": true}, "seen": G.LEVELS.size()}
	s["pass"] = {"owned": true, "xp": 2750, "claimed": 27}
	s.month_card = {"until": "2026-12-20", "last": "2026-11-22"}
	s.v7_room = {"items": ["lamp", "rug", "shelf"], "pos": {"lamp": [120, 340]}, "notes": ["Привет! «Кавычки», ёлка, 漢字 и эмодзи ✨"]}
	s.profile = {"nick": "Лунная Сова", "avatar": "yue", "frame": "gold", "created": 1763900000, "id": "a1b2c3d4"}
	s.profile_done = true
	s.stats = {"path": {"games": 140, "wins": 121, "rp": 1300}, "duel": {"games": 30, "wins": 18, "rp": 360}, "blitz": {"games": 12, "wins": 9, "rp": 117}}
	return s


static func _round_trip() -> void :
	var st: = late_game_state()
	G.S = st.duplicate(true)
	var want: = _norm(G.S)
	var code: = V8Recovery.export_code()
	_check("code has TW8- prefix", code.begins_with("TW8-"))
	var groups_ok: = true
	var rest: = code.substr(4)
	for i in range(GROUP_SEP_START, rest.length(), 7):
		if rest[i] != "-":
			groups_ok = false
	_check("code grouped by 6 with dashes", groups_ok)
	print("  code length %d chars, json %d bytes" % [code.length(), JSON.stringify(G.S).length()])
	G.S = G.default_state()
	var ok: = V8Recovery.import_code(code)
	_check("import of exported code succeeds", ok, V8Recovery.last_error)
	_check("round-trip state identical", _norm(G.S) == want)
	_check("round-trip progress (rp/gems/unlocked)", int(G.S.rp) == 1777 and int(G.S.gems) == 23456 and int(G.S.unlocked) == G.LEVELS.size())
	_check("round-trip profile", str(G.S.profile.nick) == "Лунная Сова" and bool(G.S.profile_done))
	_check("imported save written to disk", G.read_save_file(G.save_path) is Dictionary)
	_check("pre-import backup written", FileAccess.file_exists(V8Recovery.PRE_IMPORT_PATH))
	var spaced: = code.replace("-", "- ").insert(10, "\n")
	G.S = G.default_state()
	_check("code with spaces/newlines accepted", V8Recovery.import_code(spaced) and int(G.S.rp) == 1777, V8Recovery.last_error)


const GROUP_SEP_START: = 6


static func _bad_codes() -> void :
	var st: = late_game_state()
	G.S = st.duplicate(true)
	var code: = V8Recovery.export_code()
	var guard: = G.default_state()
	guard.gems = 4242
	G.S = guard
	var mid: = code.length() / 2
	if code[mid] == "-":
		mid += 1
	var flipped: = code.substr(0, mid) + ("B" if code[mid] != "B" else "C") + code.substr(mid + 1)
	_check("corrupted code rejected", not V8Recovery.import_code(flipped))
	_check("corrupted code: reason is checksum", V8Recovery.decode(flipped).err == "sum")
	_check("corrupted code leaves S untouched", int(G.S.gems) == 4242)
	_check("wrong prefix rejected", not V8Recovery.import_code("TW7-" + code.substr(4)) and V8Recovery.decode("TW7-" + code.substr(4)).err == "prefix")
	_check("truncated code rejected", not V8Recovery.import_code(code.substr(0, code.length() - 9)))
	_check("garbage rejected", not V8Recovery.import_code("привет") and not V8Recovery.import_code("") and not V8Recovery.import_code("TW8-"))
	_check("dashes removed rejected", not V8Recovery.import_code("TW8-" + code.substr(4).replace("-", "")))
	var fut: = late_game_state()
	fut.ver = G.SAVE_VER + 1
	var fcode: = V8Recovery.export_code(fut)
	_check("future save version rejected", not V8Recovery.import_code(fcode) and V8Recovery.decode(fcode).err == "version")
	_check("error text is Russian", V8Recovery.last_error.begins_with("Код"))
	_check("rejections leave S untouched", int(G.S.gems) == 4242)


static func _save_fallback() -> void :
	G.S = late_game_state()
	G.S.gems = 111
	G.save()
	G.S.gems = 222
	G.save()
	_check("save writes main", int(G.read_save_file(G.save_path).gems) == 222)
	_check("save keeps backup of previous", int(G.read_save_file(G._bak_path()).gems) == 111)
	_check("no temp file left", not FileAccess.file_exists(G._tmp_path()))
	var f: = FileAccess.open(G.save_path, FileAccess.WRITE)
	f.store_string("{\"gems\": 9, \"unlo")
	f.close()
	G.load_game()
	_check("damaged main -> loaded from backup", G.loaded_from == G._bak_path() and int(G.S.gems) == 111, G.loaded_from)
	G.S.gems = 333
	G.save()
	_check("save after fallback keeps good backup", int(G.read_save_file(G._bak_path()).gems) == 111 and int(G.read_save_file(G.save_path).gems) == 333)
	DirAccess.remove_absolute(G.save_path)
	DirAccess.remove_absolute(G._bak_path())
	G.load_game()
	_check("no files -> fresh state, no crash", G.loaded_from == "" and int(G.S.gems) == 1500)


static func _migration_v5() -> void :
	var old: = late_game_state()
	old.erase("profile")
	old.erase("profile_done")
	old.erase("stats")
	old.ver = 5
	var d = JSON.parse_string(JSON.stringify(old))
	_check("v5 save applies", G.apply_state(d))
	_check("v5 -> current: ver bumped", int(G.S.ver) == G.SAVE_VER)
	_check("v5 -> v6: profile card shown again", G.S.profile_done == false and str(G.S.profile.nick) == "" and str(G.S.profile.id).length() == 8)
	_check("v5 -> v6: progress kept", int(G.S.rp) == 1777 and int(G.S.unlocked) == G.LEVELS.size() and G.S.stars.size() == G.LEVELS.size())
	_check("v5 -> v6: stats empty dict", G.S.stats is Dictionary and G.S.stats.is_empty())
	var code: = V8Recovery.export_code(d)
	G.S = G.default_state()
	_check("0.7 save code imports with migration", V8Recovery.import_code(code) and int(G.S.ver) == G.SAVE_VER and not G.S.profile_done)


static func _add_rp() -> void :
	G.S = G.default_state()
	var seen: = []
	var cb: = func(a, b): seen.append([a, b])
	G.rank_changed.connect(cb)
	var ups: = G.add_rp(70, "duel")
	_check("add_rp up: rank-up returned", ups.size() == 1 and int(ups[0].tier) == 0 and int(ups[0].sub) == 1)
	_check("add_rp up: rank_changed emitted", seen.size() == 1 and seen[0] == [0, 1])
	_check("add_rp stats rp", G.stats_of("duel").rp == 70)
	G.add_rp(-50, "duel")
	_check("add_rp negative stops at step floor", int(G.S.rp) == 60, str(G.S.rp))
	_check("add_rp stats count real delta", G.stats_of("duel").rp == 60)
	G.add_rp(-500, "table")
	_check("add_rp never below floor", int(G.S.rp) == 60 and G.stats_of("table").rp == 0)
	G.add_rp(5)
	_check("old signature add_rp(n) -> other", G.stats_of("other").rp == 5 and int(G.S.rp) == 65)
	G.record_game("duel", true)
	G.record_game("duel", false)
	_check("record_game counts", G.stats_of("duel").games == 2 and G.stats_of("duel").wins == 1)
	G.rank_changed.disconnect(cb)
	var prof_seen: = [0]
	var pcb: = func(): prof_seen[0] += 1
	G.profile_changed.connect(pcb)
	_check("nick too short rejected", not G.set_profile("ab", "rin") and G.nick_error("  ") != "")
	_check("set_profile ok", G.set_profile("  Сакура  Тян ", "rin") and G.S.profile.nick == "Сакура Тян" and G.S.profile.avatar == "rin" and G.S.profile_done)
	_check("profile_changed emitted", prof_seen[0] == 1)
	G.profile_changed.disconnect(pcb)
