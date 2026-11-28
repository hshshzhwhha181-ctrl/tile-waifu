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
	_migration_v7()
	_migration_48_to_1000()
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


static func _norm_no_econ(d: Dictionary) -> String:
	var c: = d.duplicate()
	c.erase("econ")
	return _norm(c)


static func _norm(d) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(d)), "", true)


static func late_game_state() -> Dictionary:
	var s: = G.default_state()
	s.gems = 23456
	s.coins = 98765
	s.unlocked = 120
	for i in 120:
		if not V10LevelGen.is_peak(i):
			s.stars[str(i)] = 1 + i % 3
	s["v10_levels"] = {"mig48": true}
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
	s.v6_map = {"chests": {"0": true, "1": true, "2": true}, "seen": 48}
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
	G.v10_attach()  # 0.10: a live save always carries the module keys and the sealed wallet (S.econ)
	G.S.econ = G.econ.save_dict()
	# the wallet's clock fields move with the wall clock between export and import: compared by balances below
	var want: = _norm_no_econ(G.S)
	var want_bal: = [V10Money.bal("gems"), V10Money.bal("coins")]
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
	_check("round-trip state identical", _norm_no_econ(G.S) == want)
	_check("round-trip wallet identical", [V10Money.bal("gems"), V10Money.bal("coins")] == want_bal and V10Econ.verify(G.S.econ))
	_check("round-trip progress (rp/gems/unlocked)", int(G.S.rp) == 1777 and int(G.S.gems) == 23456 and int(G.S.unlocked) == 120)
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
	V10Money.set_balance("gems", 111)
	G.save()
	V10Money.set_balance("gems", 222)
	G.save()
	_check("save writes main", int(G.read_save_file(G.save_path).gems) == 222)
	_check("save keeps backup of previous", int(G.read_save_file(G._bak_path()).gems) == 111)
	_check("no temp file left", not FileAccess.file_exists(G._tmp_path()))
	var f: = FileAccess.open(G.save_path, FileAccess.WRITE)
	f.store_string("{\"gems\": 9, \"unlo")
	f.close()
	G.load_game()
	_check("damaged main -> loaded from backup", G.loaded_from == G._bak_path() and int(G.S.gems) == 111, G.loaded_from)
	V10Money.set_balance("gems", 333)
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
	old.erase("v10_levels")
	old.unlocked = 48
	old.stars = {}
	for i in 48:
		old.stars[str(i)] = 1 + i % 3
	old.ver = 5
	var d = JSON.parse_string(JSON.stringify(old))
	_check("v5 save applies", G.apply_state(d))
	_check("v5 -> current: ver bumped", int(G.S.ver) == G.SAVE_VER)
	_check("v5 -> v6: profile card shown again", G.S.profile_done == false and str(G.S.profile.nick) == "" and str(G.S.profile.id).length() == 8)
	_check("v5 -> v6: progress kept", int(G.S.rp) == 1777 and int(G.S.unlocked) >= 48 and G.S.stars.size() == 48)
	_check("v5 -> v6: stats empty dict", G.S.stats is Dictionary and G.S.stats.is_empty())
	var code: = V8Recovery.export_code(d)
	G.S = G.default_state()
	_check("0.7 save code imports with migration", V8Recovery.import_code(code) and int(G.S.ver) == G.SAVE_VER and not G.S.profile_done)


# 0.10 (docs/INTEGRATION_0.10.md §3.7): a 0.9 save (ver 7) → ver 8 exactly once; old keys kept, the W1+W2 module keys
# registered, the wallet built from the 0.9 balances and sealed, a second pass adds nothing, damaged new keys are
# repaired, the .bak fallback works on ver 8, and the 0.9 mirrors S.gems / S.coins follow the wallet.
const W1_KEYS: = ["v10_meta", "v10_afisha", "econ", "v10_shop", "v10_cos_owned", "v10_cos_seen", "v10_feats", "v10_auth",
	"v10_tut", "v10_clarity", "look", "hero_combo", "a11y_calm",
	"v10_levels", "v10_boosters", "v10_salon", "v10_phone", "v10_feed"]

static func _all_v10_keys() -> Array:
	var out: = W1_KEYS.duplicate()
	for k in V10RitSave.defaults():
		if not (k in out):
			out.append(str(k))
	return out

static func _migration_v7() -> void :
	var old: = late_game_state()
	old.ver = 7
	old.streak = 9
	old.login = {"n": 12, "last": "2026-11-20"}
	var all_keys: = _all_v10_keys()
	for k in all_keys:
		old.erase(k)
	var d = JSON.parse_string(JSON.stringify(old))
	_check("v7 save applies", G.apply_state(d))
	_check("v7 -> v8: ver is 8", int(G.S.ver) == 8 and G.SAVE_VER == 8, str(G.S.ver))
	var keep: = true
	for k in old:
		if k != "streak" and not G.S.has(k):
			keep = false
	_check("v7 -> v8: every 0.9 key kept", keep)
	_check("v7 -> v8: progress kept", int(G.S.rp) == 1777 and int(G.S.unlocked) == 120 and str(G.S.profile.nick) == "Лунная Сова")
	var missing: = []
	for k in all_keys:
		if not G.S.has(k):
			missing.append(k)
	_check("v7 -> v8: W1 module keys registered", missing.is_empty(), str(missing))
	_check("v7 -> v8: v10_meta days_seen from the visits", int(G.S.v10_meta.get("days_seen", -1)) == 12)
	_check("v7 -> v8: 0.9 visit streak reset (Серия starts at 0)", int(G.S.get("streak", -1)) == 0)
	_check("v7 -> v8: wallet holds the 0.9 balances", V10Money.bal("gems") == 23456 and V10Money.bal("coins") == 98765,
		"%d/%d" % [V10Money.bal("gems"), V10Money.bal("coins")])
	G.save()
	var disk = G.read_save_file(G.save_path)
	_check("v7 -> v8: S.econ sealed on disk", disk is Dictionary and disk.get("econ") is Dictionary and V10Econ.verify(disk.econ))
	var before: = _norm(G.S)
	var rep: = V10Save.migrate(G.S)
	V10Registry.ensure_all(G.S)
	_check("second migrate adds nothing", (rep.added as Array).is_empty() and (rep.migrators as Array).is_empty() and _norm(G.S) == before, str(rep))
	G.load_game()
	_check("reload of a ver 8 save changes nothing", int(G.S.ver) == 8 and V10Money.bal("gems") == 23456 and G.loaded_from == G.save_path)
	G.S.v10_clarity = 7
	G.S.erase("v10_afisha")
	G.v10_attach()
	_check("damaged new keys repaired", G.S.v10_clarity is Dictionary and G.S.v10_afisha is Dictionary)
	# the snapshot S.gems is not an input (P10): a leftover direct write is UNDONE and counted, never turned into money
	var dw0: = TWWallet.direct_writes
	G.S.gems = int(G.S.gems) + 44   # wallet-lint: ok the test of the guard itself
	G.save()
	_check("direct S.gems write undone, not absorbed", V10Money.bal("gems") == 23456 and int(G.S.gems) == 23456 and TWWallet.direct_writes == dw0 + 1)
	V10Money.grant({"gems": 44}, "test")
	G.save()
	_check("a grant moves wallet and snapshot", V10Money.bal("gems") == 23500 and int(G.S.gems) == 23500)
	_check("spend all or nothing", not V10Money.spend({"gems": 10, "coins": 10 ** 9}, "test") and V10Money.bal("gems") == 23500)
	_check("spend moves the mirror", V10Money.spend({"gems": 500}, "test") and int(G.S.gems) == 23000)
	G.save()
	G.save()
	var f: = FileAccess.open(G.save_path, FileAccess.WRITE)
	f.store_string("{\"ver\": 8, \"gem")
	f.close()
	G.load_game()
	_check("ver 8: damaged main -> backup with the wallet", G.loaded_from == G._bak_path() and int(G.S.ver) == 8 and V10Money.bal("gems") == 23000)
	_check("econ audit clean after migration", G.econ != null and (G.econ.audit() as Array).is_empty(), str(G.econ.audit() if G.econ else []))


# 0.10 W2 (INTEGRATION_0.10.md §4 W2): 0.9 fixture with 48 cleared levels → formula round(N * 100 / 48) + 1 opens 2-1
# (unlocked = 101), all 48 star entries preserved without loss on Arc 1 main-path nodes, Salon bank == sum of stars
# (intro «У тебя уже N★…»), and reloading changes nothing.
static func _migration_48_to_1000() -> void :
	var old: = G.default_state()
	old.ver = 7
	for k in _all_v10_keys():
		old.erase(k)
	old.unlocked = 48
	old.stars = {}
	var sum_old: = 0
	for i in 48:
		var st_v: = 1 + i % 3
		old.stars[str(i)] = st_v
		sum_old += st_v
	var d = JSON.parse_string(JSON.stringify(old))
	_check("48->1000: 0.9 48-level save applies", G.apply_state(d))
	var want_unl: = int(round(48 * 100.0 / 48.0)) + 1
	_check("48->1000: unlocked mapped by formula (%d)" % want_unl, int(G.S.unlocked) == want_unl, str(G.S.unlocked))
	var sum_new: = 0
	var no_peaks: = true
	for k in G.S.stars:
		sum_new += int(G.S.stars[k])
		if V10LevelGen.is_peak(int(k)):
			no_peaks = false
	_check("48->1000: zero stars lost (%d == %d, main nodes)" % [sum_new, sum_old], sum_new == sum_old and G.S.stars.size() == 48 and no_peaks)
	V10Salon.notify_stars(0)
	_check("48->1000: Salon bank == sum of stars (%d)" % V10Salon.bank(), V10Salon.bank() == sum_old)
	_check("48->1000: Salon intro greets veteran stars", V10Salon.intro_text() == (V10SalonData.INTRO_OLD % sum_old), V10Salon.intro_text())
	G.save()
	var snap: = _norm(G.S)
	G.load_game()
	_check("48->1000: reload is idempotent", _norm(G.S) == snap and V10Salon.bank() == sum_old)


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
