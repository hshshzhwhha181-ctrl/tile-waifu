class_name V10ChallengeDeal
extends RefCounted

# «Вызов по коду»: from a code payload {mode, gen, key} back to the very same table, and from a finished table
# (the live play screen or a win-screen context) to the payload.
#
# ONE CODE ⇒ ONE DEAL. The deal is fully defined by the resolved cfg:
#   · Путь / Пик on the 0.10 generator (gen = V10LevelGen.VERSION): V10LevelGen.build(index, salt, null, assist) —
#     faces, steps, gold, ice, secret tiles and specials come from the level payload (V10LevelBoard), no RNG at all;
#   · Путь on the 0.9 table list (gen 0, before the integrator switches G.LEVELS to V10LevelGen): G.LEVELS[i];
#   · Партия дня: the day formula of play.gd (level = day of month % levels, seed = YYYYMMDD);
#   · Странствие: V10Journey.board_cfg_for(week, board) with the theme of the week and no blessings or curses.
# The face deal of the non-payload tables is drawn by TrayBoard._assign from the GLOBAL generator, so play.gd seeds
# it with cfg.seed right before board.setup(cfg) for every seeded mode (seeded() below; the same line the tower
# lane needs for Странствие). Same cfg + same seed ⇒ same board: deal_hash() hashes the cfg, board_fingerprint()
# the dealt board, and the selftest proves both.
#
# KEY of Путь / Пик (the level uid): bits 0–15 level index, 16–23 bake salt, 24 «облегчённая раздача», 25–31 zero.
#   The salt is in the key, so a server re-bake of a level (CEO_PLAN №5) never changes a code already sent.
# KEY of Партия дня: days since 1970-01-01.  KEY of Странствие: week × 8 + board (0–4).
#
#   cur_gen(mode_id) -> int (−1: that table does not exist in this build)
#   payload_from_play(play) / payload_from_ctx(ctx) -> {ok, err, err_text, mode, gen, key, title fields…}
#   resolve(p) -> {ok, err, err_text, cfg, pairs, tiles, mode_name, table, title, seed, hash}
#   seeded(play) -> bool        play.gd hook: seed(int(cfg.seed)) before board.setup(cfg) when true
#   deal_hash(p) / cfg_hash(cfg) / board_fingerprint(board) / pairs_of(cfg)

const U: = preload("res://scripts/v10/duels/challenge/challenge_util.gd")
const C: = preload("res://scripts/v10/duels/challenge/challenge_code.gd")

const JOURNEY_GEN: = 1
# fingerprint of the Странствие board generator (V10Journey tables). The selftest recomputes it: if the tower lane
# retunes the boards, the test fails with «bump JOURNEY_GEN» so old codes are refused instead of misplayed.
const JOURNEY_FP: = "5x6x3x10x52|6x6x3x12x61|6x7x4x14x70|7x7x4x16x79|7x8x5x18x88|f19l2t30h0i0f0.13s1|b1f2t10"
const MODE_NAMES: = {1: "Путь", 2: "Партия дня", 3: "Странствие", 4: "Пик"}
const FIRST_DAY: = "2025-01-01"

# ---------------------------------------------------------------- generations

static func levelgen() -> Script:
	return U.cls("V10LevelGen")


static func journey() -> Script:
	return U.cls("V10Journey")


# the build's Path is the 0.10 generator once G.LEVELS holds its levels (integration step of v10-levels)
static func v10_levels() -> bool:
	var gg: = U.g()
	if gg == null:
		return false
	var L: Array = gg.LEVELS
	return not L.is_empty() and (L[0] as Dictionary).has("v10_id") and levelgen() != null


static func cur_gen(mode_id: String) -> int:
	match mode_id:
		"path", "daily":
			return int(levelgen().get("VERSION")) if v10_levels() else 0
		"peak":
			return int(levelgen().get("VERSION")) if v10_levels() else -1
		"journey":
			return JOURNEY_GEN if journey() != null else -1
	return -1


static func journey_fp() -> String:
	var J: = journey()
	if J == null:
		return ""
	var parts: = PackedStringArray()
	for d in J.get("BOARD_DIFF"):
		parts.append("x".join(PackedStringArray((d as Array).map(func(v): return str(v)))))
	var t: Dictionary = J.get("TUNED")
	parts.append("f%dl%dt%dh%di%df%ss%d" % [int(t.faces), int(t.layers), int(t.target), int(t.hidden_from), int(t.ice_from), str(t.fill), int(t.size)])
	var b: Dictionary = J.get("BOSS_ADD")
	parts.append("b%df%dt%d" % [int(b.layers), int(b.faces), int(b.target)])
	return "|".join(parts)

# ---------------------------------------------------------------- keys

static func path_key(idx: int, salt: = 0, assist: = false) -> int:
	return (idx & 0xFFFF) | ((salt & 0xFF) << 16) | ((1 if assist else 0) << 24)


static func path_unkey(key: int) -> Dictionary:
	return {"idx": key & 0xFFFF, "salt": (key >> 16) & 0xFF, "assist": ((key >> 24) & 1) == 1, "extra": (key >> 25) & 0x7F}


static func journey_key(week: int, board: int) -> int:
	return week * 8 + board


# ---------------------------------------------------------------- payload from a finished table

static func _err(e: String) -> Dictionary:
	return {"ok": false, "err": e, "err_text": C.err_text(e) if C.ERR.has(e) else e}


# ctx = {mode: "path"|"daily"|"journey"|"peak", lvl, salt?, assist?, day?, week?, board?}
static func payload_from_ctx(ctx: Dictionary) -> Dictionary:
	var mid: = String(ctx.get("mode", "path"))
	if not C.MODE_IDS.has(mid):
		return _err("Здесь вызов не бросить")
	var gen: = cur_gen(mid)
	if gen < 0:
		return _err("closed")
	var key: = 0
	match mid:
		"path", "peak":
			var i: = int(ctx.get("lvl", 0))
			var salt: = int(ctx.get("salt", -1))
			if salt < 0:
				salt = int(levelgen().call("salt_of", i)) if gen > 0 else 0
			key = path_key(i, salt, bool(ctx.get("assist", false)))
		"daily":
			key = U.day_index(String(ctx.get("day", U.day_key())))
		"journey":
			key = journey_key(int(ctx.get("week", 0)), int(ctx.get("board", 0)))
	return {"ok": true, "err": "", "err_text": "", "mode": int(C.MODE_IDS[mid]), "gen": gen, "key": key}


# the live play screen (the author's win): mode "" = Путь (or Пик), "daily", Странствие via cfg.mode, "challenge"
static func payload_from_play(play) -> Dictionary:
	var m: = String(play.get("mode"))
	var cfg: Dictionary = play.get("cfg")
	if m == "challenge":
		var a: Dictionary = play.get("args0")
		var ch: Dictionary = a.get("challenge", {})
		return {"ok": true, "err": "", "err_text": "", "mode": int(ch.mode), "gen": int(ch.gen), "key": int(ch.key)}
	if m == "":
		if bool(play.get("tut")):
			return _err("Обучающий стол без вызовов")
		if cfg.has("v10_id"):
			return {"ok": true, "err": "", "err_text": "", "mode": C.MODE_PEAK if bool(cfg.get("peak", false)) else C.MODE_PATH,
				"gen": int(cfg.get("v10_version", 1)), "key": path_key(int(cfg.v10_id), int(cfg.get("v10_salt", 0)), bool(cfg.get("assist", false)))}
		return payload_from_ctx({"mode": "path", "lvl": int(play.get("lvl"))})
	if m == "daily":
		var s: = str(int(cfg.get("seed", 0)))
		var day: = "%s-%s-%s" % [s.substr(0, 4), s.substr(4, 2), s.substr(6, 2)] if s.length() == 8 else U.day_key()
		return payload_from_ctx({"mode": "daily", "day": day})
	if String(cfg.get("mode", "")) == "journey" or m == "journey":
		var run = play.get("run")
		if not (run is Dictionary) or (run as Dictionary).is_empty():
			return _err("Здесь вызов не бросить")
		var p: = payload_from_ctx({"mode": "journey", "week": int(run.week), "board": int(run.board)})
		# a run with blessings or curses that reshaped the board is not the table of the week any more
		var base: = resolve(p)
		if not base.ok or cfg_hash(base.cfg) != cfg_hash(cfg):
			return _err("Вызов — только со стола недели без благословений и проклятий")
		return p
	return _err("Здесь вызов не бросить")

# ---------------------------------------------------------------- resolve

static func pairs_of(cfg: Dictionary) -> int:
	var v10 = cfg.get("v10", {})
	if v10 is Dictionary and int((v10 as Dictionary).get("n", 0)) > 0:
		return int(v10.n) / 2
	return TrayBoard.gen_layout(cfg).size() / 2


static func _fill_look(cfg: Dictionary) -> void:
	if not cfg.has("tint"):
		cfg["tint"] = Color(1, 1, 1)
	for k in ["bg", "fx"]:
		if not cfg.has(k):
			cfg[k] = "play" if k == "bg" else "petals"


# p = {mode, gen, key [, tenths]} → the table. With tenths, the time is checked for plausibility on that table.
static func resolve(p: Dictionary) -> Dictionary:
	var mode: = int(p.get("mode", 0))
	var mid: = String(C.MODES.get(mode, ""))
	if mid == "":
		return _err("mode")
	var gen: = cur_gen(mid)
	if gen < 0:
		return _err("closed")
	if int(p.get("gen", -1)) != gen:
		var r: = _err("gen")
		r.gen_code = int(p.get("gen", -1))
		r.gen_here = gen
		return r
	var key: = int(p.get("key", 0))
	var gg: = U.g()
	var cfg: = {}
	var table: = ""
	match mid:
		"path", "peak":
			var k: = path_unkey(key)
			if int(k.extra) != 0:
				return _err("key")
			if gen == 0:
				if int(k.salt) != 0 or bool(k.assist) or int(k.idx) >= (gg.LEVELS as Array).size():
					return _err("key")
				cfg = (gg.LEVELS[int(k.idx)] as Dictionary).duplicate(true)
			else:
				var LG: = levelgen()
				if int(k.idx) >= int(LG.call("count")):
					return _err("key")
				if mid == "peak" and (not bool(LG.call("is_peak", int(k.idx))) or bool(k.assist)):
					return _err("key")
				cfg = LG.call("build", int(k.idx), int(k.salt), null, bool(k.assist))
			table = "%s · %s" % [String(cfg.get("code", "")), String(cfg.get("name", ""))]
		"daily":
			var first: = U.day_index(FIRST_DAY)
			var today: = U.day_index(U.day_key())
			if key < first:
				return _err("key")
			if key > today + 1:
				return _err("future")
			var day: = U.date_of_index(key)
			var L: Array = gg.LEVELS
			var lvl: = int(day.substr(8, 2)) % L.size()
			cfg = (L[lvl] as Dictionary).duplicate(true)
			# the same formula as play.gd build() for args.daily
			cfg.name = V6Txt.s("play.daily_name")
			cfg.seed = int(day.replace("-", ""))
			cfg.reward = {"gems": 100}
			cfg.erase("shard")
			cfg.goal = V6Txt.s("play.goal_clear")
			cfg.intro = V6Txt.s("play.daily_intro")
			cfg.day = day
			table = U.date_text(day)
		"journey":
			var J: = journey()
			var wid: = key >> 3
			var b: = key & 7
			if b >= int(J.get("BOARDS")) or wid < 0:
				return _err("key")
			var TU: = U.cls("V10TowerUtil")
			if TU and wid > int(TU.call("cur_week")) + 1:
				return _err("future")
			var th: Dictionary = J.call("theme", wid)
			var run: = {"mode": "journey", "week": wid, "practice": true, "board": b, "hearts": 3, "partner": "mc",
				"bless": {}, "curses": {}, "extra_eff": [th.eff], "scores": [], "offer": [], "curse_offer": [], "attempt": 0}
			cfg = J.call("board_cfg_for", wid, b, run)
			table = "%s · стол %d из %d" % [String(th.name), b + 1, int(J.get("BOARDS"))]
	_fill_look(cfg)
	var pairs: = pairs_of(cfg)
	if pairs < 2:
		return _err("key")
	if p.has("tenths") and not C.plausible(int(p.tenths), pairs):
		return _err("time")
	var out: = {"ok": true, "err": "", "err_text": "", "cfg": cfg, "pairs": pairs, "tiles": pairs * 2,
		"mode_id": mid, "mode_name": String(MODE_NAMES[mode]), "table": table, "seed": int(cfg.get("seed", 0))}
	out.title = "%s · %s" % [out.mode_name, table]
	out.hash = deal_hash_of(p, cfg)
	return out

# ---------------------------------------------------------------- hashes

# the deal-defining part of a cfg (cosmetic keys — name, texts, bg — are left out)
static func cfg_hash(cfg: Dictionary) -> int:
	var a: = [int(cfg.get("seed", 0)), String(cfg.get("shape", "")), int(cfg.get("cols", 0)), int(cfg.get("rows", 0)),
		int(cfg.get("layers", 0)), snappedf(float(cfg.get("fill", 0.0)), 0.0001), int(cfg.get("faces", 0)),
		int(cfg.get("gold", 0)), snappedf(float(cfg.get("ice", 0)), 0.0001), bool(cfg.get("hidden", false)),
		String(cfg.get("upper", "")), String(cfg.get("shard", ""))]
	var v10 = cfg.get("v10", {})
	if v10 is Dictionary and not (v10 as Dictionary).is_empty():
		for k in ["face", "step", "gold", "ice", "secret", "shard", "spec"]:
			a.append(str((v10 as Dictionary).get(k, [])).hash())
	return hash(str(a))


static func deal_hash_of(p: Dictionary, cfg: Dictionary) -> int:
	return hash("%d|%d|%d|%d" % [int(p.get("mode", 0)), int(p.get("gen", 0)), int(p.get("key", 0)), cfg_hash(cfg)])


# hash of the payload's deal (resolves the table); 0 when the code points at no table
static func deal_hash(p: Dictionary) -> int:
	var r: = resolve({"mode": p.get("mode", 0), "gen": p.get("gen", 0), "key": p.get("key", 0)})
	return int(r.hash) if r.ok else 0


# the dealt board itself: positions, faces, pair steps, gold, ice, secret tiles, shard and specials
static func board_fingerprint(board) -> int:
	var a: = []
	var spec: Dictionary = board.get("spec") if board.get("spec") is Dictionary else {}
	for t in board.tiles:
		var s: = ""
		if spec.has(t):
			s = String((spec[t] as Dictionary).get("kind", ""))
		a.append("%d,%d,%d,%d,%d,%d,%d,%d,%s,%s" % [t.gx, t.gy, t.gz, t.face, t.step, int(t.gold), int(t.ice), int(t.secret), t.shard, s])
	return hash("|".join(PackedStringArray(a)))


# play.gd hook (_make_board): the global generator is seeded with cfg.seed right before board.setup(cfg) for every
# table a code can point at, and for the challenge run itself. Other modes keep their random deal.
static func seeded(play) -> bool:
	var m: = String(play.get("mode"))
	var cfg: Dictionary = play.get("cfg")
	if not cfg.has("seed"):
		return false
	return m in ["", "daily", "challenge"] or bool(cfg.get("seed_locked", false))
