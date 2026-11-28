extends Node

# Runner of the state selftest (P12): TWClock, TWSave, TWMigrate, TWState, golden saves v4..v8, 500-case save fuzzing.
#   godot --headless --path game res://scripts/v10/state/state_selftest.tscn [-- --fuzz_n=500 --seed=20261128]
# Prints "STATE_SELFTEST ok/total", exit code 0 when all pass. It runs as a scene so every autoload (G) exists: the shell
# side hands the core test the legacy G as an ORACLE (G.default_state for the defaults, G.apply_state for the old migration
# path, parity checks); the core classes themselves never see G.
#
# Fixture generator (one-shot; run again ONLY when a change to the save format is intended, the hashes in golden.json are the
# contract a refactor must not move):
#   godot --headless --path game res://scripts/v10/state/state_selftest.tscn -- --gen_golden=1     fixtures v4..v8 + golden.json
#   godot --headless --path game res://scripts/v10/state/state_selftest.tscn -- --hashes_only=1     only the expected hashes
# The fixtures are hand-built old saves (v4 .. v7) and one real v8 (the v7 one migrated by the legacy G).

const OUT: = "res://tests/fixtures/saves/"


func _ready() -> void:
	await get_tree().process_frame
	var env: = {}
	var mode: = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fuzz_n="):
			env["fuzz_n"] = int(a.substr(9))
		elif a.begins_with("--seed="):
			env["seed"] = int(a.substr(7))
		elif a == "--gen_golden=1":
			mode = "gen"
		elif a == "--hashes_only=1":
			mode = "hashes"
	env["defaults"] = Callable(G, "default_state")
	env["levels_size"] = G.LEVELS.size()
	env["heroes"] = G.HEROES.keys()
	env["oracle"] = _oracle
	if mode != "":
		_generate(env, mode == "hashes")
		get_tree().quit(0)
		return
	var r: Array = TWStateSelftest.run(env)
	get_tree().quit(0 if r[0] == r[1] else 1)


# the pre-P12 path: G.apply_state(d) on a throw-away copy; G.S and G.econ are put back afterwards
func _oracle(d: Dictionary) -> Dictionary:
	var prev_s = G.S
	var prev_econ = G.econ
	var ok: bool = G.apply_state(d.duplicate(true))
	var out: Dictionary = (G.S as Dictionary).duplicate(true) if ok else {}
	G.S = prev_s
	G.econ = prev_econ
	return {"ok": ok, "state": out}


func _generate(env: Dictionary, hashes_only: bool) -> void:
	var g = G
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var fx: = {}
	if hashes_only:
		for v in [4, 5, 6, 7, 8]:
			fx["v%d.json" % v] = JSON.parse_string(FileAccess.get_file_as_string(OUT + "v%d.json" % v))
	else:
		fx = _build(g)
		for name in fx:
			_write(OUT + name, JSON.stringify(fx[name], "\t", true))
	var gold: = {}
	for name in fx:
		var res: = TWStateSelftest.golden_run(fx[name], env)
		gold[name] = {"from_ver": int(fx[name].ver), "hash": res.hash, "ver": int(res.state.ver),
			"unlocked": int(res.state.unlocked), "stars": (res.state.stars as Dictionary).size(), "gems": int(res.state.gems)}
	_write(OUT + "golden.json", JSON.stringify(gold, "\t", true))
	print("GEN_GOLDEN ", JSON.stringify(gold))


func _write(path: String, text: String) -> void:
	var f: = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text + "\n")
	f.close()


func _items(g, n: int) -> Array:
	var out: = []
	for it in g.ITEMS:
		if bool(it.get("hidden", false)) or bool(it.get("start", false)):
			continue
		out.append(str(it.id))
		if out.size() >= n:
			break
	return out


func _base(g) -> Dictionary:
	var owned: = {"o_base": true, "s_sakura": true}
	for id in _items(g, 6):
		owned[id] = true
	return {
		"gems": 4200, "coins": 15800, "player_lv": 12, "xp": 55, "unlocked": 30, "stars": {}, "owned": owned,
		"partner": "rin", "outfit": {"mc": "o_base"}, "skin": "s_sakura", "pity": 21,
		"aff": {"mc": 220, "rin": 140, "hana": 60, "yue": 10, "nova": 0},
		"daily_day": "2026-03-02", "streak": 3, "sound": true, "music": false, "pulls": 87,
		"level_partner": "rin", "tut_done": true, "free10": true, "newbie_left": 3, "newbie_ssr": true,
		"guar": true, "sr_pity": 4, "ex": 2, "pet": {"day": "2026-03-02", "n": 2},
		"tasks": {"day": "2026-03-02", "pairs": 14, "levels": 2, "combo5": 1, "claimed": [true, false, false]},
		"login": {"n": 5, "last": "2026-03-02"}, "dailymap": {"month": "2026-03", "done": [1, 2, 5]},
		"pass": {"owned": true, "xp": 340, "claimed": 3}, "month_card": {"until": "2026-04-01", "last": "2026-03-02"},
		"modest": false, "cutins": true, "voice": true, "first_buy": {"pack1": true}, "shards": {"rin": 3, "hana": 1}, "side": "f",
		"rp": 640, "yaku_seen": {"clean": true, "calm": true}, "blitz_best": 21, "next_great": false, "intro_done": true,
	}


func _stars(n: int, map_index: bool) -> Dictionary:
	var s: = {}
	for i in n:
		var k: = V6Worlds.migrate_index(i) if map_index else i
		s[str(k)] = 1 + i % 3
	return s


func _build(g) -> Dictionary:
	var v4: = _base(g)
	v4.ver = 4
	v4.unlocked = 17            # old index scale (4 stages per location): 16 cleared = 4 locations
	v4.stars = _stars(16, false)

	var v5: = _base(g)
	v5.ver = 5
	v5.unlocked = 47
	v5.stars = _stars(24, true)
	v5["v6_map"] = {"chests": {"0": true, "3": true}, "seen": 47}

	var v6: = _base(g)
	v6.ver = 6
	v6.unlocked = 48
	v6.stars = _stars(48, false)
	v6["v6_map"] = {"chests": {"0": true, "1": true, "3": true}, "seen": 48}
	v6.profile = {"nick": "Сакура Тян", "avatar": "rin", "frame": "", "created": 1768000000, "id": "5a1c0de5"}
	v6.profile_done = true
	v6.stats = {"path": {"games": 40, "wins": 31, "rp": 420}, "duel": {"games": 6, "wins": 2, "rp": 40}}
	v6["v6_fx"] = {"shake": false, "flash": false}
	v6.rp = 902

	var v7: = v6.duplicate(true)
	v7.ver = 7
	v7.fx_level = "mid"
	v7.ult_cutin = "short"
	v7.streak = 9
	v7.login = {"n": 12, "last": "2026-11-20"}
	v7["v7_room"] = {"items": ["lamp", "rug"], "pos": {"lamp": [120, 340]}, "notes": ["Привет! «Кавычки», ёлка, 漢字 и эмодзи ✨"]}
	v7.gems = 23456
	v7.coins = 98765
	v7.unlocked = 48
	v7.rp = 1777

	# the real v8: the v7 save migrated by the legacy G (what a player's phone holds after the 0.10 update), time frozen
	V10Meta.set_now(TWStateSelftest.GOLD_NOW)
	V10Meta.set_tz(0)
	var prev_s = g.S
	var prev_econ = g.econ
	g.apply_state(v7.duplicate(true))
	var v8: Dictionary = (g.S as Dictionary).duplicate(true)
	g.S = prev_s
	g.econ = prev_econ
	V10Meta.clear_now()
	V10Meta.clear_tz()
	return {"v4.json": v4, "v5.json": v5, "v6.json": v6, "v7.json": v7, "v8.json": v8}
