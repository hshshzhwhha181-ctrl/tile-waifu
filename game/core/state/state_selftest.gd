class_name TWStateSelftest
extends RefCounted

# Selftest of the P12 state core: TWClock, TWSave, TWMigrate, TWState, the golden saves v4..v8 and a 500-case fuzz of damaged
# saves. Pure core (no G, no scene tree): the runner (scripts/v10/state/state_selftest_cli.gd) hands in `env`:
#   defaults: Callable   fresh default state (G.default_state)          levels_size: int    heroes: Array
#   oracle: Callable(d) -> {ok, state}   the pre-P12 migration path (G.apply_state) for the parity checks (optional)
#   fuzz_n: int (500)    seed: int
# Prints "STATE_SELFTEST ok/total"; every check is a PASS / FAIL line. Scratch files live in user://tw_state_selftest/.

const DIR: = "user://tw_state_selftest/"
const FIX: = "res://tests/fixtures/saves/"
const GOLD_NOW: = 1_795_000_000      # 2026-11-18 10:26 UTC: the frozen "now" of every golden migration
const FUZZ_N: = 500

static var _pass: = 0
static var _fail: = 0


static func run(env: Dictionary = {}) -> Array:
	_pass = 0
	_fail = 0
	DirAccess.make_dir_recursive_absolute(DIR)
	_clock()
	_migrate_units(env)
	_golden(env)
	_save_io()
	_state(env)
	_fuzz(env)
	var total: = _pass + _fail
	print("STATE_SELFTEST %d/%d" % [_pass, total])
	return [_pass, total]


static func _check(name: String, ok: bool, info: String = "") -> void:
	if ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		printerr("FAIL ", name, " ", info)


static func _rm_all(p: String) -> void:
	TWSave.new(p).remove_all()


static func _read(p: String) -> String:
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


static func _put(p: String, text: String) -> void:
	var f: = FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# ── golden helpers (also used by the fixture generator) ────────────────────────────────────────────────────────

static func golden_ctx(env: Dictionary) -> Dictionary:
	var c: = {"now": GOLD_NOW, "levels_size": int(env.get("levels_size", 1000)), "heroes": env.get("heroes", TWMigrate.DEFAULT_HEROES),
		"new_profile": func() -> Dictionary: return {"nick": "", "avatar": "mc", "frame": "", "created": GOLD_NOW, "id": "00c0ffee"}}
	if env.get("defaults") is Callable:
		c["defaults"] = env.defaults
	return c


# a fixture through TWMigrate with the clock, time zone and V10Meta state frozen: {ok, state, hash}
static func golden_run(d: Dictionary, env: Dictionary) -> Dictionary:
	V10Meta.set_now(GOLD_NOW)
	V10Meta.set_tz(0)
	V10Meta.bind({})
	var a: = TWMigrate.apply(d, golden_ctx(env))
	V10Meta.unbind()
	V10Meta.clear_now()
	V10Meta.clear_tz()
	a["hash"] = TWState.state_hash_of(a.state) if bool(a.ok) else ""
	return a


# ── TWClock ────────────────────────────────────────────────────────────────────────────────────────────────────

static func _clock() -> void:
	var c: = TWClock.fake(1_800_000_000, 0)     # 2027-01-15 08:00:00 UTC
	_check("clock: fake now", c.now() == 1_800_000_000 and c.raw_now() == 1_800_000_000)
	_check("clock: fresh state is ok", c.clock_ok() and c.skew() == 0 and c.tick())
	_check("clock: tick raises the high-water mark", int(c.st.max_unix) == 1_800_000_000)
	c.advance(90.5)
	_check("clock: advance moves wall and monotonic together", c.now() == 1_800_000_090 and c.mono_msec() == 90500, str(c.mono_msec()))
	c.tick()
	var mark: int = int(c.st.max_unix)
	c.set_wall(1_800_000_000 - 2 * 86400)
	_check("clock: rolled back 2 days -> not ok", not c.clock_ok() and c.skew() > 86400)
	_check("clock: safe_now never goes backwards", c.safe_now() == mark and c.now() < mark)
	c.tick()
	_check("clock: tick does not lower the high-water mark", int(c.st.max_unix) == mark)
	_check("clock: monotonic time unaffected by the wall clock", c.mono_msec() == 90500)
	c.set_wall(mark - 1800)
	_check("clock: 30 min back is inside the tolerance", c.clock_ok())
	c.set_wall(mark + 5000)
	_check("clock: forward again -> ok, tick follows", c.tick() and int(c.st.max_unix) == mark + 5000)
	# day rule: starts at 04:00 phone time, never goes back
	var d: = TWClock.fake(1_800_000_000 + 0, 0)             # 08:00 UTC, 2027-01-15
	_check("clock: day_key at 08:00 is the same date", d.day_key() == "2027-01-15", d.day_key())
	d.set_wall(1_800_000_000 - 5 * 3600)                    # 03:00: before 04:00 -> the previous raw day, but never below last_key
	_check("clock: 03:00 does not roll the day back", d.day_key() == "2027-01-15" and d.key_of(d.now()) == "2027-01-14")
	d.set_wall(1_800_000_000 + 19 * 3600)                   # 03:00 on the 16th: still the old day
	_check("clock: day changes at 04:00, not at midnight", d.day_key() == "2027-01-15")
	d.set_wall(1_800_000_000 + 21 * 3600)                   # 05:00 on the 16th
	var seen0: int = int(d.st.days_seen)
	_check("clock: 05:00 next day -> new key", d.day_key() == "2027-01-16" and int(d.st.days_seen) == seen0 + 1)
	d.set_wall(1_800_000_000 - 10 * 86400)
	_check("clock: a month-old clock cannot reuse an old day", d.day_key() == "2027-01-16")
	var tz: = TWClock.fake(1_800_000_000, 180)               # Moscow phone
	_check("clock: time zone shifts the day start", tz.key_of(1_800_000_000 + 3600 * 3) == "2027-01-15" and tz.local_unix(0) == 10800)
	_check("clock: cal_key is Moscow 04:00", tz.cal_key(1_800_000_000) == "2027-01-15")
	_check("clock: secs_to_rollover in (0, 86400]", tz.secs_to_rollover() > 0 and tz.secs_to_rollover() <= 86400)
	# state binding repairs garbage
	var junk: = {"max_unix": "x", "srv_offset": [], "last_key": 5, "days_seen": -3.0}
	var b: = TWClock.fake()
	b.bind(junk)
	_check("clock: bind repairs a damaged state", b.st.max_unix == 0 and b.st.srv_offset == 0 and b.st.last_key == "" and b.st.days_seen == 0)
	var b2: = TWClock.fake(1_800_000_000, 0)
	b2.bind({"max_unix": 1_800_000_000.0, "srv_offset": 60.0, "last_key": "2027-01-14", "days_seen": 4})
	_check("clock: json floats become ints and the offset applies", b2.now() == 1_800_000_060 and b2.st.max_unix is int)
	_check("clock: day_index", TWClock.day_index("1970-01-02") == 1 and TWClock.day_index("") == 0)
	var sys: = TWClock.new()
	_check("clock: system sources work", sys.now() > 1_700_000_000 and sys.mono_msec() >= 0 and sys.day_key().length() == 10)


# ── TWMigrate unit checks ──────────────────────────────────────────────────────────────────────────────────────

static func _min_save(ver: int) -> Dictionary:
	return {"gems": 100, "unlocked": 5, "stars": {}, "owned": {}, "ver": ver}


static func _migrate_units(env: Dictionary) -> void:
	_check("check: ok save", TWMigrate.check(_min_save(8)).ok)
	_check("check: no ver = legacy 0", TWMigrate.check({"gems": 1, "unlocked": 1}).ok and TWMigrate.check({"gems": 1, "unlocked": 1}).ver == 0)
	_check("check: future version refused", TWMigrate.check(_min_save(9)).reason == "future" and TWMigrate.check(_min_save(1000000)).reason == "future")
	_check("check: fractional future version refused", TWMigrate.check(_min_save(8)).ok and TWMigrate.check({"gems": 1, "unlocked": 1, "ver": 8.5}).reason == "future")
	for bad in ["8", null, [], {}, true]:
		_check("check: ver %s refused" % str(bad), TWMigrate.check({"gems": 1, "unlocked": 1, "ver": bad}).reason == "badver")
	_check("check: not a dict", TWMigrate.check([1]).reason == "notdict" and TWMigrate.check(null).reason == "notdict")
	_check("check: missing gems / unlocked", TWMigrate.check({"unlocked": 1}).reason == "keys" and TWMigrate.check({"gems": 1}).reason == "keys")
	_check("check: gems must be a number", TWMigrate.check({"gems": "5", "unlocked": 1}).reason == "badtype" and TWMigrate.check({"gems": 1e300, "unlocked": 1}).reason == "badtype")
	_check("check: stars / owned must be dictionaries", TWMigrate.check({"gems": 1, "unlocked": 1, "stars": []}).reason == "badtype" and TWMigrate.check({"gems": 1, "unlocked": 1, "owned": 3}).reason == "badtype")
	var ctx: = golden_ctx(env)
	ctx["modules"] = false
	var a: = TWMigrate.apply(_min_save(8), ctx)
	_check("apply: result is SAVE_VER, input untouched", bool(a.ok) and int(a.state.ver) == 8)
	var src: = {"gems": 7, "unlocked": 3, "stars": {"0": 2}, "owned": {}, "ver": 3}
	var snap: = JSON.stringify(src)
	var a3: = TWMigrate.apply(src, ctx)
	_check("apply: the input dictionary is never modified", JSON.stringify(src) == snap)
	_check("apply: ver 3 climbs the whole ladder", bool(a3.ok) and int(a3.state.ver) == 8 and a3.report.steps.has(4) and a3.report.steps.has(5) and a3.report.steps.has(6) and a3.report.steps.has(7))
	_check("apply: ver<4 x4 then world map (stars key 0 -> 0, unlocked 3 -> %d)" % int(a3.state.unlocked), a3.state.stars.has("0") and int(a3.state.stars["0"]) == 2)
	# unlocked arithmetic of the ladder: unlocked 3 -> 1 + 2*4 = 9 -> migrate_index(8) + 1 (8 = world 2, step 0 -> 16)
	_check("apply: unlocked follows the formulas", int(a3.state.unlocked) == V6Worlds.migrate_index(8) + 1, str(a3.state.unlocked))
	var fx: = TWMigrate.apply({"gems": 1, "unlocked": 1, "ver": 6, "v6_fx": {"shake": false, "flash": true}, "fx_level": "bogus", "ult_cutin": 5}, ctx)
	_check("apply: v6 calm shake -> fx_level mid", bool(fx.ok) and str(fx.state.fx_level) == "mid" and str(fx.state.ult_cutin) == "full")
	var fx2: = TWMigrate.apply({"gems": 1, "unlocked": 1, "ver": 8, "fx_level": "bogus", "ult_cutin": 5}, ctx)
	_check("apply: unknown fx_level / ult_cutin repaired", str(fx2.state.fx_level) == "full" and str(fx2.state.ult_cutin) == "full")
	var pr: = TWMigrate.apply({"gems": 1, "unlocked": 1, "ver": 8, "profile": {"avatar": "ghost", "created": "x"}}, ctx)
	_check("apply: profile completed, unknown avatar -> mc", str(pr.state.profile.avatar) == "mc" and pr.state.profile.has("id") and pr.state.profile.created is int)
	var st2: = TWMigrate.apply({"gems": 1, "unlocked": 1, "ver": 8, "stars": {"3": 9, "x": 1, "-2": 1, "5": "a", "7": 2.0}}, ctx)
	_check("apply: stars cleaned (junk keys dropped, 0..3)", st2.state.stars.size() == 2 and int(st2.state.stars["3"]) == 3 and int(st2.state.stars["7"]) == 2, str(st2.state.stars))
	# the 48 -> 1000 step (the same table as recovery_selftest "48->1000")
	var o: = {"unlocked": 48, "stars": {}, "ver": 7}
	var sum_old: = 0
	for i in 48:
		o.stars[str(i)] = 1 + i % 3
		sum_old += 1 + i % 3
	TWMigrate.migrate_48_to_1000(o, 800)
	var sum_new: = 0
	var no_peaks: = true
	for k in o.stars:
		sum_new += int(o.stars[k])
		if V10LevelGen.is_peak(int(k)):
			no_peaks = false
	_check("48->1000: unlocked by formula round(N*100/48)+1", int(o.unlocked) == 101, str(o.unlocked))
	_check("48->1000: no star lost, none on a peak", sum_new == sum_old and o.stars.size() == 48 and no_peaks)
	var once: = JSON.stringify(o)
	TWMigrate.migrate_48_to_1000(o, 800)
	_check("48->1000: second run changes nothing", JSON.stringify(o) == once and bool(o.v10_levels.mig48))
	var z: = {"unlocked": 3, "stars": {"1": 1}}
	TWMigrate.migrate_48_to_1000(z, 800)
	_check("48->1000: a barely started save is left alone", int(z.unlocked) == 3 and z.stars.size() == 1)
	var h: = {"unlocked": 120, "stars": {"60": 3}}
	TWMigrate.migrate_48_to_1000(h, 800)
	_check("48->1000: an already 1000-level save is only marked", int(h.unlocked) == 120 and bool(h.v10_levels.mig48))
	var cap: = {"unlocked": 48, "stars": {"47": 3}}
	TWMigrate.migrate_48_to_1000(cap, 50)
	_check("48->1000: unlocked capped by released levels", int(cap.unlocked) == 50)


# ── golden saves ───────────────────────────────────────────────────────────────────────────────────────────────

static func _golden(env: Dictionary) -> void:
	var gold = JSON.parse_string(FileAccess.get_file_as_string(FIX + "golden.json")) if FileAccess.file_exists(FIX + "golden.json") else null
	_check("golden: golden.json present", gold is Dictionary and (gold as Dictionary).size() == 5)
	if not (gold is Dictionary):
		return
	for v in [4, 5, 6, 7, 8]:
		var name: = "v%d.json" % v
		var raw: = FileAccess.get_file_as_string(FIX + name)
		var fx = JSON.parse_string(raw)
		_check("golden %s: fixture is a v%d save" % [name, v], fx is Dictionary and int(fx.get("ver", -1)) == v)
		if not (fx is Dictionary):
			continue
		var g: Dictionary = gold.get(name, {})
		var a: = golden_run(fx, env)
		_check("golden %s: migrates" % name, bool(a.ok), str(a.get("reason", "")))
		if bool(a.ok):
			print("  golden %s report: steps %s repaired %s" % [name, str(a.report.steps), str(a.report.repaired)])
		if not bool(a.ok):
			continue
		_check("golden %s: ends at SAVE_VER 8" % name, int(a.state.ver) == 8 and TWMigrate.SAVE_VER == 8)
		_check("golden %s: state hash == the recorded one" % name, str(a.hash) == str(g.get("hash", "?")), "%s vs %s" % [a.hash, g.get("hash", "?")])
		_check("golden %s: progress numbers as recorded" % name,
			int(a.state.unlocked) == int(g.get("unlocked", -1)) and a.state.stars.size() == int(g.get("stars", -1)) and int(a.state.gems) == int(g.get("gems", -1)))
		var again: = golden_run(a.state, env)
		_check("golden %s: migrating the result again changes nothing" % name, bool(again.ok) and again.hash == a.hash, "%s vs %s" % [again.hash, a.hash])
		var rt = JSON.parse_string(JSON.stringify(a.state))
		_check("golden %s: json round trip keeps the hash" % name, TWState.state_hash_of(rt) == a.hash)
		var twice: = golden_run(fx, env)
		_check("golden %s: deterministic (two runs, one hash)" % name, twice.hash == a.hash)
		if env.get("oracle") is Callable:
			_oracle_parity(name, fx, a.state, env)
	# semantic spot checks per version (the hash says "same as recorded"; these say "and the recorded one is right")
	var v4 = JSON.parse_string(FileAccess.get_file_as_string(FIX + "v4.json"))
	var s4: Dictionary = golden_run(v4, env).state
	var no_hi: = true
	for k in s4.stars:
		if int(k) >= 48:
			no_hi = false
	_check("golden v4: all 16 cleared levels kept (stars sum)", _sum_stars(s4.stars) == _sum_stars(v4.stars) and s4.stars.size() == 16, str(s4.stars.size()))
	_check("golden v4: profile card shown again (v6 step), stats empty", s4.profile_done == false and str(s4.profile.id) == "00c0ffee" and s4.stats.is_empty())
	_check("golden v4: wallet built from the 0.9 balances", int(s4.econ.wallet.bal.crystal) == 4200 and int(s4.econ.wallet.bal.coin) == 15800)
	_check("golden v4: 0.8 keys survive", s4.owned.has("o_base") and int(s4.rp) == 640 and str(s4.partner) == "rin" and int(s4.pulls) == 87)
	var v5 = JSON.parse_string(FileAccess.get_file_as_string(FIX + "v5.json"))
	var s5: Dictionary = golden_run(v5, env).state
	_check("golden v5: stars sum kept through 48->1000", _sum_stars(s5.stars) == _sum_stars(v5.stars) and bool(s5.v10_levels.mig48))
	_check("golden v5: unlocked mapped (47 -> passed 47 (star on index 46) -> round(47*100/48)+1 = 99)", int(s5.unlocked) == 99, str(s5.unlocked))
	var v6 = JSON.parse_string(FileAccess.get_file_as_string(FIX + "v6.json"))
	var s6: Dictionary = golden_run(v6, env).state
	_check("golden v6: profile kept, calm effects -> fx_level mid", str(s6.profile.nick) == "Сакура Тян" and bool(s6.profile_done) and str(s6.fx_level) == "mid" and str(s6.ult_cutin) == "full")
	_check("golden v6: v6_fx mirrors the mid level", bool(s6.v6_fx.shake) == false and bool(s6.v6_fx.flash) == false)
	_check("golden v6: stats kept", int(s6.stats.path.games) == 40 and int(s6.rp) == 902)
	var v7 = JSON.parse_string(FileAccess.get_file_as_string(FIX + "v7.json"))
	var s7: Dictionary = golden_run(v7, env).state
	_check("golden v7: 0.9 settings kept", str(s7.fx_level) == "mid" and str(s7.ult_cutin) == "short" and int(s7.rp) == 1777)
	_check("golden v7: days_seen from the login count, streak reset", int(s7.v10_meta.days_seen) == 12 and int(s7.streak) == 0)
	_check("golden v7: wallet == the 0.9 balances", int(s7.econ.wallet.bal.crystal) == 23456 and int(s7.econ.wallet.bal.coin) == 98765)
	_check("golden v7: module keys registered", s7.has("v10_afisha") and s7.has("v10_levels") and s7.has("v10_salon"))
	var v8 = JSON.parse_string(FileAccess.get_file_as_string(FIX + "v8.json"))
	var s8: Dictionary = golden_run(v8, env).state
	_check("golden v8: already current -> only canonical form, same progress", int(s8.gems) == int(v8.gems) and int(s8.unlocked) == int(v8.unlocked) and _sum_stars(s8.stars) == _sum_stars(v8.stars))
	# the v8 fixture is what the legacy path produced from v7; the new path from v7 must agree on everything but the clock-ish keys
	_check("golden: v7 -> new path and v8 fixture agree on progress", int(s7.gems) == int(s8.gems) and _sum_stars(s7.stars) == _sum_stars(s8.stars) and int(s7.unlocked) == int(s8.unlocked))


static func _sum_stars(stars: Dictionary) -> int:
	var n: = 0
	for k in stars:
		n += int(stars[k])
	return n


# the new path against the old one (G.apply_state): same state, up to the keys the wallet attach adds at run time
static func _oracle_parity(name: String, fx: Dictionary, got: Dictionary, env: Dictionary) -> void:
	V10Meta.set_now(GOLD_NOW)
	V10Meta.set_tz(0)
	V10Meta.bind({})
	var o: Dictionary = (env.oracle as Callable).call(fx)
	V10Meta.unbind()
	V10Meta.clear_now()
	V10Meta.clear_tz()
	_check("parity %s: legacy G.apply_state accepts the fixture" % name, bool(o.ok))
	if not bool(o.ok):
		return
	var a: = _normalized(got)
	var b: = _normalized(o.state)
	var diff: = []
	for k in a:
		if not b.has(k):
			diff.append("+" + str(k))
		elif JSON.stringify(a[k], "", true) != JSON.stringify(b[k], "", true):
			diff.append("%s: %s vs %s" % [k, JSON.stringify(a[k]).left(90), JSON.stringify(b[k]).left(90)])
	for k in b:
		if not a.has(k):
			diff.append("-" + str(k))
	_check("parity %s: new migration == legacy migration (%s)" % [name, ",".join(diff)], diff.is_empty(), str(diff))


# Not compared: profile.id / created (random for saves that predate the profile: v4, v5); econ (the legacy path's wallet attach
# reseals it); petals / tickets (wallet mirrors, rewritten by V10Money.attach at run time); and the keys whose module `ensure`
# ignores the dictionary it is given and works on G.S instead (v10_challenge, v10_duel, v10_journey, v10_pagoda) - see README.
const PARITY_SKIP: = ["econ", "petals", "tickets", "v10_challenge", "v10_duel", "v10_journey", "v10_pagoda"]

static func _normalized(s: Dictionary) -> Dictionary:
	var d: Dictionary = JSON.parse_string(JSON.stringify(s))
	for k in PARITY_SKIP:
		d.erase(k)
	if d.get("profile") is Dictionary:
		d.profile.erase("id")
		d.profile.erase("created")
	return d


# ── TWSave: atomic write, fallbacks, kill points ───────────────────────────────────────────────────────────────

static func _valid_fn(d: Variant) -> Dictionary:
	var c: = TWMigrate.check(d)
	return {"ok": bool(c.ok), "reason": str(c.reason)}


static func _save_text(gems: int, ver: int = 8) -> String:
	return JSON.stringify({"gems": gems, "unlocked": 3, "ver": ver, "stars": {}, "owned": {}})


static func _save_io() -> void:
	var p: = DIR + "io.json"
	_rm_all(p)
	var s: = TWSave.new(p)
	_check("save: nothing on disk -> missing", s.load_best(_valid_fn).reason == "missing" and not s.exists())
	_check("save: first write ok, no bak yet", s.write(_save_text(1)) and not FileAccess.file_exists(s.bak_path()) and not FileAccess.file_exists(s.tmp_path()))
	_check("save: second write keeps the previous as bak", s.write(_save_text(2)) and int(TWSave.read_file(s.bak_path()).data.gems) == 1 and int(TWSave.read_file(p).data.gems) == 2)
	_check("save: no temp file left behind", not FileAccess.file_exists(s.tmp_path()))
	_check("save: load picks the main file", s.load_best(_valid_fn).from == p)
	# damaged main: bak is used, and the damaged main never replaces a good bak
	_put(p, "{\"gems\": 9, \"unlo")
	var r: = s.load_best(_valid_fn)
	_check("save: truncated main -> loaded from bak", bool(r.ok) and r.from == s.bak_path() and int(r.data.gems) == 1)
	_check("save: damage is reported in `tried`", (r.tried as Array).size() == 1 and r.tried[0].why == "badjson")
	_check("save: write over a damaged main keeps the good bak", s.write(_save_text(3)) and int(TWSave.read_file(s.bak_path()).data.gems) == 1 and int(TWSave.read_file(p).data.gems) == 3)
	_check("save: the damaged main is kept as .corrupt.json", FileAccess.file_exists(s.corrupt_path()))
	# every kind of unreadable file
	for case in [["empty", ""], ["spaces", "   \n"], ["array", "[1,2]"], ["null", "null"], ["number", "12"], ["string", "\"x\""], ["binary", String.chr(0) + String.chr(255) + "{"], ["html", "<html></html>"]]:
		_rm_all(p)
		_put(p, case[1])
		var rr: = s.load_best(_valid_fn)
		_check("save: %s file -> damaged, no crash" % case[0], not bool(rr.ok) and rr.reason == "damaged")
	var big: = DIR + "big.json"
	_put(big, "x".repeat(1000))
	_check("save: read_file reports why", TWSave.read_file(big).why == "badjson" and TWSave.read_file(DIR + "nope.json").why == "missing")
	DirAccess.remove_absolute(big)
	# a future save is refused and wins over any older readable copy
	_rm_all(p)
	s.write(_save_text(5, 8))
	s.write(_save_text(6, 9))
	var f: = s.load_best(_valid_fn)
	_check("save: main from a newer game -> refused as future, not rolled back to bak", not bool(f.ok) and f.reason == "future")
	# kill points: whatever the process was doing when it died, a valid save loads and it is the old or the new one
	for kp in ["tmp_open", "tmp_written", "tmp_verified", "rotated", "renamed"]:
		_rm_all(p)
		var k: = TWSave.new(p)
		k.write(_save_text(10))
		k.write(_save_text(20))
		k.kill_at = kp
		var wrote: = k.write(_save_text(30))
		k.kill_at = ""
		var lr: = k.load_best(_valid_fn)
		var g: = int(lr.data.gems) if bool(lr.ok) else -1
		_check("save: kill at %s -> still loads (gems %d)" % [kp, g], not wrote and bool(lr.ok) and (g == 20 or g == 30), str(lr.get("reason", "")))
		_check("save: kill at %s -> the next write succeeds and cleans up" % kp, k.write(_save_text(40)) and int(TWSave.read_file(p).data.gems) == 40 and not FileAccess.file_exists(k.tmp_path()))
	# a truncated tmp next to a good main never beats the main
	_rm_all(p)
	var t: = TWSave.new(p)
	t.write(_save_text(7))
	_put(t.tmp_path(), "{\"gems\": 8, \"unlocked")
	_check("save: half-written tmp ignored while main is good", t.load_best(_valid_fn).from == p)
	# unwritable location: reports, never crashes, live file untouched
	var bad: = TWSave.new("user://tw_state_selftest/no_such_dir/deeper/save.json")
	_check("save: unwritable path -> false + last_error", not bad.write(_save_text(1)) and bad.last_error != "")
	_rm_all(p)


# ── TWState: debounce, flush, lifecycle ────────────────────────────────────────────────────────────────────────

static func _mk_state(p: String, clock: TWClock, env: Dictionary) -> TWState:
	var ctx: = golden_ctx(env)
	ctx["modules"] = false
	var st: = TWState.new(TWSave.new(p), clock, ctx)
	return st


static func _disk_gems(p: String) -> int:
	var r: = TWSave.read_file(p)
	return int(r.data.get("gems", -1)) if bool(r.ok) else -1


static func _state(env: Dictionary) -> void:
	var p: = DIR + "state.json"
	_rm_all(p)
	var clk: = TWClock.fake(1_800_000_000, 0)
	var st: = _mk_state(p, clk, env)
	_check("state: no files -> fresh", st.load_game() == "fresh" and not st.locked and not st.dirty and st.message() == "")
	st.data["gems"] = 111
	st.data["unlocked"] = 2
	st.data["stars"] = {}
	st.data["owned"] = {}
	st.mark_dirty()
	_check("state: dirty after a change, nothing written yet", st.dirty and st.writes == 0 and not FileAccess.file_exists(p))
	clk.advance_ms(999)
	_check("state: debounce 1 s: not yet at 999 ms", not st.poll() and st.dirty and st.due_in_ms() == 1)
	clk.advance_ms(1)
	_check("state: debounce 1 s: flushed at 1000 ms", st.poll() and not st.dirty and _disk_gems(p) == 111 and st.writes == 1)
	_check("state: poll on a clean state does nothing", not st.poll() and st.writes == 1)
	# a busy player cannot starve the save: the window starts at the FIRST change
	st.data["gems"] = 112
	st.mark_dirty()
	clk.advance_ms(500)
	st.data["gems"] = 113
	st.mark_dirty()
	clk.advance_ms(400)
	st.mark_dirty()
	clk.advance_ms(99)
	_check("state: later changes do not extend the window (999 ms after the first)", not st.poll())
	clk.advance_ms(1)
	_check("state: ...flush exactly 1 s after the first unsaved change", st.poll() and _disk_gems(p) == 113)
	# money operation: within 100 ms
	st.data["gems"] = 50
	st.mark_dirty(true)
	clk.advance_ms(99)
	_check("state: money op not yet at 99 ms", not st.poll())
	clk.advance_ms(1)
	_check("state: money op flushed within 100 ms", st.poll() and _disk_gems(p) == 50)
	# money after a pending ordinary change pulls the deadline forward
	st.data["coins"] = 5
	st.mark_dirty()
	clk.advance_ms(300)
	st.data["gems"] = 49
	st.mark_dirty(true)
	clk.advance_ms(100)
	_check("state: a money op pulls a pending 1 s flush forward to 100 ms", st.poll() and _disk_gems(p) == 49)
	# an ordinary change never pushes a pending money flush back
	st.data["gems"] = 48
	st.mark_dirty(true)
	clk.advance_ms(50)
	st.mark_dirty()
	clk.advance_ms(50)
	_check("state: an ordinary change does not delay a pending money flush", st.poll() and _disk_gems(p) == 48)
	# pause / exit flush at once
	st.data["gems"] = 47
	st.mark_dirty()
	var w0: = st.writes
	_check("state: on_pause flushes at once", st.on_pause() and _disk_gems(p) == 47 and st.writes == w0 + 1 and not st.dirty)
	st.data["gems"] = 46
	st.mark_dirty()
	_check("state: on_exit flushes at once", st.on_exit() and _disk_gems(p) == 46)
	_check("state: pause / exit on a clean state write nothing", st.on_pause() and st.on_exit() and st.writes == w0 + 2)
	# the wall clock does not matter for the debounce
	st.data["gems"] = 45
	st.mark_dirty()
	clk.set_wall(1_700_000_000)
	clk.advance_ms(0)
	_check("state: wall clock moved back does not stall or fire the debounce", not st.poll())
	clk.set_wall(1_800_000_100)
	clk.advance_ms(1000)
	_check("state: monotonic time drives the debounce", st.poll() and _disk_gems(p) == 45)
	# a process kill loses at most the pending window; money is safe after 100 ms
	st.data["gems"] = 44
	st.mark_dirty()
	var killed: = _mk_state(p, TWClock.fake(), env)
	killed.load_game()
	_check("state: kill inside the debounce window loses only the unsaved change", int(killed.data.gems) == 45 and killed.status == "loaded")
	st.data["gems"] = 43
	st.mark_dirty(true)
	clk.advance_ms(100)
	st.poll()
	var killed2: = _mk_state(p, TWClock.fake(), env)
	killed2.load_game()
	_check("state: kill after the money flush keeps the purchase", int(killed2.data.gems) == 43)
	# main damaged: recovered from the bak, flagged, message, repaired on the next flush
	var good: = _disk_gems(p)
	var f: = FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{\"gems\": 9, \"unl")
	f.close()
	var rc: = _mk_state(p, TWClock.fake(), env)
	_check("state: damaged main -> recovered from bak", rc.load_game() == "recovered" and rc.message() != "" and int(rc.data.gems) > 0 and rc.dirty)
	rc.clock.advance_ms(1000)
	_check("state: recovered state is written back to the main file", rc.poll() and rc.status == "loaded" and _disk_gems(p) == int(rc.data.gems) and good > 0)
	# future version
	_rm_all(p)
	_put(p, _save_text(777, 9))
	var fu: = _mk_state(p, TWClock.fake(), env)
	_check("state: save from a newer game -> status future, locked, Russian message", fu.load_game() == "future" and fu.locked and fu.message().begins_with("Сохранение создано"))
	fu.data["gems"] = 1
	fu.mark_dirty(true)
	fu.clock.advance_ms(5000)
	_check("state: a locked state never writes (the newer save survives)", not fu.poll() and not fu.flush(true) and not fu.on_exit() and int(TWSave.read_file(p).data.gems) == 777 and not FileAccess.file_exists(fu.save.bak_path()))
	_check("state: apply_state refuses a future version too", not fu.apply_state(JSON.parse_string(_save_text(5, 9))) and fu.reason == "future")
	_check("state: apply_state accepts a current save and unlocks", fu.apply_state(JSON.parse_string(_save_text(5, 8))) and not fu.locked and fu.dirty and fu.status == "loaded")
	# I/O failure keeps the state dirty and retries
	var dir2: = DIR + "later/"
	var p2: = dir2 + "save.json"
	var ck: = TWClock.fake()
	var ft: = _mk_state(p2, ck, env)
	ft.load_game()
	ft.data["gems"] = 5
	ft.data["unlocked"] = 1
	ft.mark_dirty()
	ck.advance_ms(1000)
	_check("state: write failure -> false, stays dirty", not ft.poll() and ft.dirty and not ft.last_flush_ok)
	DirAccess.make_dir_recursive_absolute(dir2)
	ck.advance_ms(TWState.RETRY_MS - 1)
	_check("state: no retry before RETRY_MS", not ft.poll())
	ck.advance_ms(1)
	_check("state: retried after RETRY_MS and succeeded", ft.poll() and not ft.dirty and _disk_gems(p2) == 5)
	_rm_all(p2)
	DirAccess.remove_absolute(dir2)
	# module versions
	var mv: = _mk_state(DIR + "mv.json", ck, env)
	_check("state: module_ver defaults to 0, set_module_ver marks dirty", mv.module_ver("econ") == 0 and not mv.dirty)
	mv.set_module_ver("econ", 3)
	_check("state: module_ver stored in data.mod_ver", mv.module_ver("econ") == 3 and mv.dirty and mv.data.mod_ver.econ == 3)
	# hash
	_check("state: hash is order independent and int/float stable", TWState.state_hash_of({"a": 1, "b": [1, 2]}) == TWState.state_hash_of({"b": [1.0, 2.0], "a": 1.0}))
	_check("state: hash changes with content", TWState.state_hash_of({"a": 1}) != TWState.state_hash_of({"a": 2}))
	# a whole play session through the real file: load -> change -> exit -> load
	_rm_all(p)
	var s1: = _mk_state(p, TWClock.fake(), env)
	s1.load_game()
	s1.data["gems"] = 900
	s1.data["unlocked"] = 12
	s1.data["stars"] = {"3": 2}
	s1.data["owned"] = {"o_base": true}
	s1.mark_dirty()
	s1.on_exit()
	var s2: = _mk_state(p, TWClock.fake(), env)
	s2.load_game()
	_check("state: session round trip keeps the state hash", s2.status == "loaded" and s2.state_hash() == s1.state_hash(), "%s vs %s" % [s2.state_hash(), s1.state_hash()])
	_rm_all(p)
	_rm_all(DIR + "mv.json")


# ── fuzz: damaged saves ────────────────────────────────────────────────────────────────────────────────────────

static func _junk(rng: RandomNumberGenerator, depth: int = 0) -> Variant:
	match rng.randi() % 10:
		0:
			return null
		1:
			return rng.randi_range(-1000000, 1000000000)
		2:
			return rng.randf() * 1.0e6 - 5.0e5
		3:
			return "".join(PackedStringArray([char(rng.randi_range(0x20, 0x7e)), "я", "\\", "\"", "\n", char(rng.randi_range(0x4e00, 0x4e20))]))
		4:
			return rng.randi() % 2 == 0
		5:
			return []
		6:
			return {}
		7:
			return 1.0e300 if rng.randi() % 2 == 0 else -1.0e300
		8:
			var a: = []
			if depth < 3:
				for i in rng.randi_range(0, 4):
					a.append(_junk(rng, depth + 1))
			return a
	var d: = {}
	if depth < 3:
		for i in rng.randi_range(0, 4):
			d[str(rng.randi() % 100000)] = _junk(rng, depth + 1)
	return d


# junk for a KNOWN key: any kind, but a container is empty (hostile contents of the right kind inside a module's own arrays
# are the module's business; unknown keys below get the full deep junk)
static func _shallow(rng: RandomNumberGenerator) -> Variant:
	var v: Variant = _junk(rng, 3)
	if v is Array:
		return []
	if v is Dictionary:
		return {}
	return v


static func _bytes_garbage(rng: RandomNumberGenerator, text: String) -> String:
	var b: = text.to_utf8_buffer()
	for i in rng.randi_range(1, 12):
		if b.size() == 0:
			break
		match rng.randi() % 3:
			0:
				b[rng.randi() % b.size()] = rng.randi() % 256
			1:
				b.remove_at(rng.randi() % b.size())
			2:
				b.insert(rng.randi() % b.size(), rng.randi() % 256)
	return b.get_string_from_utf8()


# returns {text, kind}: the damaged file content for case i
static func _mutate(rng: RandomNumberGenerator, good: Dictionary, i: int) -> Dictionary:
	var text: = JSON.stringify(good)
	var kind: = i % 12
	var d: Dictionary = good.duplicate(true)
	var keys: = d.keys()
	match kind:
		0:
			return {"kind": "truncate", "text": text.substr(0, rng.randi() % text.length())}
		1:
			for n in rng.randi_range(1, 6):
				d["junk_" + str(rng.randi() % 100000)] = _junk(rng)
			return {"kind": "junk keys", "text": JSON.stringify(d)}
		2:
			for n in rng.randi_range(1, 3):
				d[keys[rng.randi() % keys.size()]] = _shallow(rng)
			return {"kind": "wrong type", "text": JSON.stringify(d)}
		3:
			d["ver"] = rng.randi_range(9, 5000000)
			return {"kind": "future ver", "text": JSON.stringify(d)}
		4:
			var weird: Array = [null, "abc", "8", [], {}, -5, 1.0e300, true, 7.5, 8.0000001, -1.0e30, 0, 3, 5]
			d["ver"] = weird[rng.randi() % weird.size()]
			return {"kind": "odd ver", "text": JSON.stringify(d)}
		5:
			for n in rng.randi_range(1, 5):
				d.erase(keys[rng.randi() % keys.size()])
			if rng.randi() % 3 == 0:
				d.erase("gems")
			return {"kind": "deleted keys", "text": JSON.stringify(d)}
		6:
			return {"kind": "byte garbage", "text": _bytes_garbage(rng, text)}
		7:
			var dk: = []
			for k in d:
				if d[k] is Dictionary and not (d[k] as Dictionary).is_empty():
					dk.append(k)
			for n in rng.randi_range(1, 4):
				var k: String = dk[rng.randi() % dk.size()]
				var sub: Dictionary = d[k]
				var sk: String = sub.keys()[rng.randi() % sub.size()]
				sub[sk] = _shallow(rng)
			return {"kind": "nested junk", "text": JSON.stringify(d)}
		8:
			var whole: Array = ["[]", "null", "12", "\"s\"", "{}", "[" .repeat(300), "{\"a\":" .repeat(300), "﻿" + text, text + text, text + "}", " ".repeat(5000), "{\"gems\":1,\"unlocked\":1,\"ver\":8,\"stars\":[]}",
				"{\"gems\":\"1\",\"unlocked\":1}", "{\"gems\":1e999,\"unlocked\":1}", "{\"gems\":1,\"unlocked\":1,\"ver\":8,\"owned\":\"x\"}"]
			return {"kind": "whole file", "text": whole[rng.randi() % whole.size()]}
		9:
			# a hostile-but-valid save: every top-level value replaced by junk of a random kind, gems / unlocked kept sane
			for k in keys:
				if k != "gems" and k != "unlocked" and k != "ver" and rng.randi() % 2 == 0:
					d[k] = _shallow(rng)
			return {"kind": "all junk", "text": JSON.stringify(d)}
		10:
			# deep: a default sub-dictionary key replaced by a type that nests one more level
			for k in keys:
				if d[k] is Dictionary and rng.randi() % 3 == 0:
					for sk in (d[k] as Dictionary).keys():
						if rng.randi() % 2 == 0:
							d[k][sk] = _shallow(rng)
			return {"kind": "deep junk", "text": JSON.stringify(d)}
	var cut: = text.length() - rng.randi_range(1, 40)
	return {"kind": "tail cut", "text": text.substr(0, maxi(0, cut))}


static func _invariants(st: Dictionary) -> String:
	if int(st.get("ver", -1)) != TWMigrate.SAVE_VER:
		return "ver"
	if not TWMigrate.check(st).ok:
		return "check: " + str(TWMigrate.check(st).reason)
	if not (st.get("stars") is Dictionary) or not (st.get("owned") is Dictionary) or not (st.get("stats") is Dictionary) or not (st.get("profile") is Dictionary):
		return "containers"
	for k in st.stars:
		if not str(k).is_valid_int() or int(st.stars[k]) < 0 or int(st.stars[k]) > 3:
			return "stars"
	for k in ["tasks", "login", "pet", "pass", "aff", "outfit", "shards"]:
		if st.has(k) and not (st[k] is Dictionary):
			return "dict " + k
	if str(st.get("fx_level", "")) not in TWMigrate.FX_LEVELS or str(st.get("ult_cutin", "")) not in TWMigrate.ULT_CUTINS:
		return "levels"
	if st.has("econ") and not (st.econ is Dictionary):
		return "econ"
	if not (st.get("v10_meta") is Dictionary):
		return "v10_meta"
	if str(st.profile.get("avatar", "")) == "":
		return "avatar"
	var j: = JSON.new()
	if j.parse(JSON.stringify(st)) != OK:
		return "json"
	return ""


static func _fuzz(env: Dictionary) -> void:
	var n: int = int(env.get("fuzz_n", FUZZ_N))
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(env.get("seed", 20261128))
	var base_raw = JSON.parse_string(FileAccess.get_file_as_string(FIX + "v8.json"))
	if not (base_raw is Dictionary):
		_check("fuzz: v8 fixture readable", false)
		return
	V10Meta.set_now(GOLD_NOW)
	V10Meta.set_tz(0)
	V10Meta.bind({})
	var ctx: = golden_ctx(env)
	var p: = DIR + "fuzz.json"
	var good: Dictionary = TWMigrate.apply(base_raw, ctx).state
	var bad: = {"crash_free": 0, "future": 0, "damaged": 0, "recovered": 0, "loaded": 0, "refused_ok": 0}
	var failures: = []
	var by_kind: = {}
	for i in n:
		var m: = _mutate(rng, good, i)
		var kind: String = m.kind
		_rm_all(p)
		var has_bak: = i % 3 != 0
		var bak_gems: = 7000 + i
		if has_bak:
			var sv: = TWSave.new(p)
			sv.write(JSON.stringify(_with_gems(good, bak_gems)))
			sv.write(JSON.stringify(_with_gems(good, bak_gems + 1)))      # main (replaced below) + bak = bak_gems
			DirAccess.remove_absolute(p)
		_put(p, str(m.text))
		var before_main: = _read(p)
		var before_bak: = _read(TWSave.new(p).bak_path())
		var st: = TWState.new(TWSave.new(p), TWClock.fake(), ctx)
		var status: = st.load_game()
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		var why: = ""
		if not (status in ["loaded", "recovered", "fresh", "future", "damaged"]):
			why = "status " + status
		elif status == "loaded" or status == "recovered":
			why = _invariants(st.data)
			if why == "" and status == "recovered" and has_bak and int(st.data.gems) != bak_gems:
				why = "recovered but gems %s != bak %d" % [str(st.data.gems), bak_gems]
			bad["loaded" if status == "loaded" else "recovered"] += 1
		else:
			# a refusal: understandable, the files untouched, and if a good bak existed a plain damage must have used it
			if st.message() == "" and status != "fresh":
				why = "no message"
			if status == "damaged" and has_bak:
				why = "damaged although a good bak exists"
			if status == "fresh":
				why = "fresh although a file exists"
			if st.locked:
				bad["future"] += 1
				st.data["gems"] = 1
				st.mark_dirty(true)
				st.clock.advance_ms(2000)
				st.poll()
				st.on_exit()
			else:
				bad["damaged"] += 1
			if _read(p) != before_main or _read(TWSave.new(p).bak_path()) != before_bak:
				why = "files changed on refusal"
			bad["refused_ok"] += 1
		# a loaded state must survive its own save: write, load again, same hash
		if why == "" and (status == "loaded" or status == "recovered"):
			var h0: = st.state_hash()
			if not st.flush(true):
				why = "flush failed: " + st.save.last_error
			else:
				var again: = TWState.new(TWSave.new(p), TWClock.fake(), ctx)
				again.load_game()
				if again.status != "loaded" or again.state_hash() != h0:
					var dk: = []
					for k in st.data:
						if JSON.stringify(st.data[k]) != JSON.stringify(again.data.get(k)):
							dk.append(k)
					why = "reload differs (%s) keys %s" % [again.status, str(dk)]
		if why == "":
			bad["crash_free"] += 1
		else:
			failures.append("#%d %s: %s" % [i, kind, why])
	V10Meta.unbind()
	V10Meta.clear_now()
	V10Meta.clear_tz()
	_rm_all(p)
	_check("fuzz: %d damaged saves, 0 crashes, every one loads or is refused clearly (%s)" % [n, str(by_kind)], failures.is_empty() and int(bad.crash_free) == n, "\n".join(failures.slice(0, 12)))
	_check("fuzz: both outcomes happened (loaded %d, recovered %d, future %d, damaged %d)" % [bad.loaded, bad.recovered, bad.future, bad.damaged],
		int(bad.loaded) > 20 and int(bad.recovered) > 20 and int(bad.future) > 5 and int(bad.damaged) > 5)
	# determinism of the fuzz itself: the same seed gives the same first mutation
	var r1: = RandomNumberGenerator.new()
	r1.seed = 5
	var r2: = RandomNumberGenerator.new()
	r2.seed = 5
	_check("fuzz: seeded and reproducible", _mutate(r1, good, 3).text == _mutate(r2, good, 3).text)


static func _with_gems(d: Dictionary, gems: int) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	c["gems"] = gems
	return c
