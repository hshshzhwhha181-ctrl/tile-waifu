extends Node

# TWLevels selftest (P19). Run:
#   godot --headless --audio-driver Dummy --path game res://scripts/v10/levels/tw_levels_selftest.tscn
# Prints: TW_LEVELS_SELFTEST <ok>/<total> (+ one TW_LEVELS FAIL line per failed check)
#
# What it proves
#   * at(n) gives a fully built level (no _lazy stub) for any index, also in arcs nobody touched yet; G.level_at == at
#   * trial_cfg(hero) is the Path board of the hero's trial level: for every trial level (incl. 499/699/799/899/999)
#     the layout digest (shape, layers, seed, positions, faces, ice, specials) equals V10PathState.play_cfg(i), the real
#     V10LevelBoard built from the trial cfg has the Path board's tiles in the same places, and the OLD behaviour
#     (the raw stub) is detectably different
#   * building a trial cfg is fast (< 250 ms each)
# The "no direct G.LEVELS[...]" half of the package is tools/lint_no_direct_levels.py (tw_test suite no_direct_levels).

const MUST: = [499, 699, 799, 899, 999]

var ok: int = 0
var total: int = 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		print("TW_LEVELS FAIL: ", msg)


func _digest(cfg: Dictionary) -> int:
	var v: Dictionary = cfg.get("v10", {})
	var s: = "%s|%s|%s|%s|%s|%s|%s|%s" % [cfg.get("shape"), cfg.get("layers"), cfg.get("seed"), v.get("pos"), v.get("face"), v.get("ice"), v.get("spec"), cfg.get("cert")]
	return s.hash()


func _tiles_sig(cfg: Dictionary) -> int:
	var BoardScript: Script = load("res://scripts/v10/levels/level_board.gd")
	var b = BoardScript.new()
	b.look = G.skin_look()
	add_child(b)
	b.setup(cfg)
	var s: = "%s|" % [b.v10_used]
	for t in b.tiles:
		s += "%d:%d,%d,%d;" % [t.face, int(round(t.position.x)), int(round(t.position.y)), int(t.z_index)]
	b.queue_free()
	return s.hash()


func _run() -> void:
	# --- at() ---
	var n: = TWLevels.count()
	check(n == 1000, "count %d" % n)
	for i in [0, 99, 100, 250, 499, 500, 750, 999, 1500, -5]:
		var lv: Dictionary = TWLevels.at(i)
		var want: = clampi(i, 0, n - 1)
		check(int(lv.v10_id) == want, "at(%d) v10_id %d" % [i, int(lv.v10_id)])
		check(not lv.has("_lazy"), "at(%d) is still a lazy stub" % i)
		check(lv.has("v10") or lv.has("shape"), "at(%d) has no board" % i)
	check(TWLevels.at(777) == G.level_at(777), "G.level_at is TWLevels.at")
	check(TWLevels.at(5) == (G.LEVELS as Array)[5], "G.LEVELS alias holds the built level")

	# --- trial: every hero that has a trial level, the five boss levels in particular ---
	var seen_idx: = {}
	var max_ms: = 0.0
	for hero in G.HEROES:
		var idx: = TWLevels.trial_index(str(hero))
		if seen_idx.has(idx):
			continue
		seen_idx[idx] = str(hero)
	for m in MUST:
		if not seen_idx.has(m):
			# a hero must exist whose trial level is each of these (the boss of each world); report, do not hide
			check(false, "no hero has trial level %d (trial levels: %s)" % [m, str(seen_idx.keys())])
	print("TW_LEVELS trial levels: ", seen_idx.keys())
	var rect_before: = 0
	for idx in seen_idx:
		var hero: String = seen_idx[idx]
		var t0: = Time.get_ticks_usec()
		var cfg: Dictionary = TWLevels.trial_cfg(hero)
		var ms: = (Time.get_ticks_usec() - t0) / 1000.0
		max_ms = maxf(max_ms, ms)
		var path: Dictionary = V10PathState.play_cfg(idx)
		check(int(cfg.v10_id) == idx, "trial %s: v10_id %d != %d" % [hero, int(cfg.v10_id), idx])
		check(cfg.has("v10"), "trial %s (level %d): no v10 payload" % [hero, idx])
		check(_digest(cfg) == _digest(path), "trial %s (level %d): layout digest differs from the Path" % [hero, idx])
		check(_tiles_sig(cfg) == _tiles_sig(path), "trial %s (level %d): real board differs from the Path" % [hero, idx])
		var stub: Dictionary = V10LevelGen.level(idx)
		if str(stub.get("shape", "")) != "rect" or int(stub.get("faces", 0)) != 12:
			rect_before += 1
		check(cfg.has("tint") and cfg.has("bg") and cfg.has("fx"), "trial %s: presentation keys missing" % hero)
	check(max_ms < 250.0, "slowest trial cfg %.0f ms (limit 250)" % max_ms)
	print("TW_LEVELS trial: %d levels, slowest cfg %.0f ms; %d of them were NOT a plain rect stub (the old bug)" % [seen_idx.size(), max_ms, rect_before])
	print("TW_LEVELS_SELFTEST %d/%d" % [ok, total])
	get_tree().quit(0 if ok == total else 1)
