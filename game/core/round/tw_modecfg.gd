class_name TWModeCfg
extends RefCounted

# TWModeCfg (P20 / WP7): the mode table of a round and the board configs of the modes that build their own (daily, blitz, zen, trial,
# a Path table's fill-ins), lifted out of play.gd (build, _mode_cfg, _v8_source, _v10_mode, _slot_count, the fortune gold).
# Pure: texts arrive through a Callable (key -> String), levels through callables / dictionaries, the seed as an int.
#
# mode ids: "" (Path) | "daily" | "blitz" | "zen" | "duel" | "trial" | "pagoda" | "journey" | "practice" (the tower family).

const MODES: = ["", "daily", "blitz", "zen", "duel", "trial", "pagoda", "journey", "practice"]
const TOWER: = ["pagoda", "journey", "practice"]
const RANKED: = ["duel", "v7tourney", "duel_ranked"]
const SHAPES: = ["rect", "heart", "diamond", "butterfly", "ring", "pyramid"]
const BLITZ_SECS: = 120.0
const BG_ZEN: = ["play", "bg_teahouse", "bg_festival", "bg_palace", "bg_shrine"]

# per mode: source (rank / stats bucket), hook (the V10Hooks mode name), pairs (a pair pays crystals), rp / yaku / tasks (the win gives
# rank points, yaku, tasks), overflow ("fail" = a lost round, "free_return" = the tray returns), slots (tray slots), timed (seconds)
const TABLE: = {
	"": {"source": "path", "hook": "path", "pairs": true, "rp": true, "yaku": true, "tasks": true, "overflow": "fail", "slots": 4, "timed": 0.0},
	"daily": {"source": "daily", "hook": "daily", "pairs": true, "rp": true, "yaku": true, "tasks": true, "overflow": "fail", "slots": 4, "timed": 0.0},
	"blitz": {"source": "blitz", "hook": "blitz", "pairs": true, "rp": true, "yaku": false, "tasks": false, "overflow": "free_return", "slots": 4, "timed": 120.0},
	"zen": {"source": "zen", "hook": "zen", "pairs": true, "rp": true, "yaku": false, "tasks": false, "overflow": "free_return", "slots": 6, "timed": 0.0},
	"duel": {"source": "duel", "hook": "duel", "pairs": true, "rp": true, "yaku": false, "tasks": false, "overflow": "free_return", "slots": 4, "timed": 0.0},
	"trial": {"source": "other", "hook": "trial", "pairs": false, "rp": false, "yaku": false, "tasks": false, "overflow": "fail", "slots": 4, "timed": 0.0},
	"pagoda": {"source": "other", "hook": "pagoda", "pairs": false, "rp": true, "yaku": false, "tasks": true, "overflow": "fail", "slots": 4, "timed": 0.0},
	"journey": {"source": "other", "hook": "journey", "pairs": false, "rp": true, "yaku": false, "tasks": true, "overflow": "fail", "slots": 4, "timed": 0.0},
	"practice": {"source": "other", "hook": "practice", "pairs": false, "rp": false, "yaku": false, "tasks": false, "overflow": "fail", "slots": 4, "timed": 0.0},
}


static func known(mode: String) -> bool:
	return TABLE.has(mode)


static func row(mode: String) -> Dictionary:
	return TABLE.get(mode, {"source": "other", "hook": mode if mode != "" else "path", "pairs": true, "rp": false, "yaku": false, "tasks": false,
		"overflow": "fail", "slots": 4, "timed": 0.0})


# play.gd _v8_source: the bucket G.record_game / G.add_rp count in ("other" for everything else)
static func source(mode: String) -> String:
	return String(row(mode).source)


# play.gd _v10_mode: the name the V10Hooks payloads carry
static func hook_mode(mode: String) -> String:
	return "path" if mode == "" else mode


static func is_ranked(mode: String) -> bool:
	return mode in RANKED


static func is_tower(mode: String) -> bool:
	return mode in TOWER


# the tray slots before the partner's passives: zen has 6, the rest 4
static func slot_base(mode: String) -> int:
	return 6 if mode == "zen" else 4


# the seconds on the clock at the start (blitz only)
static func start_clock(mode: String) -> float:
	return BLITZ_SECS if mode == "blitz" else 0.0


# ── board configs ─────────────────────────────────────────────────────────────────────────────────────────────────

# the table number of the daily board from the day of the month
static func daily_level(day_of_month: int, levels_size: int) -> int:
	return day_of_month % maxi(1, levels_size)


# the seed of the daily table: the date as a number
static func daily_seed(day_key: String) -> int:
	return int(day_key.replace("-", ""))


# the daily config over the Path level `base` (TWLevels.at(daily_level))
static func daily_cfg(base: Dictionary, day_key: String, text: Callable) -> Dictionary:
	var cfg: = base.duplicate(true)
	cfg["name"] = text.call("play.daily_name")
	cfg["seed"] = daily_seed(day_key)
	cfg["reward"] = {"gems": 100}
	cfg.erase("shard")
	cfg["goal"] = text.call("play.goal_clear")
	cfg["intro"] = text.call("play.daily_intro")
	return cfg


# blitz / zen: board number n (0 for the first), the deal seed and the shape come from `seed` (the legacy code used an unseeded RNG)
static func blitz_zen_cfg(zen: bool, n: int, partner: String, seed: int, text: Callable) -> Dictionary:
	var r: = TWRng.make(seed)
	return {
		"name": text.call("play.blitz_name") if not zen else text.call("play.zen_name"), "code": "",
		"bg": BG_ZEN[n % 5] if zen else "bg_festival",
		"fx": "petals" if zen else "lanterns", "tint": Color(1, 1, 1), "hero": partner,
		"shape": SHAPES[r.below(SHAPES.size())], "cols": 5 if not zen else 6, "rows": 6 if not zen else 7,
		"layers": 2 + mini(n, 2) if not zen else 3, "fill": 0.65, "faces": 7 + mini(n, 4) if not zen else 12,
		"mech": "", "hard": 0, "seed": r.rand_i31(), "gold": 2 if not zen else 0, "ice": 0, "hidden": false,
		"reward": {"gems": 0}, "goal": text.call("play.blitz_goal") if not zen else text.call("play.zen_goal"),
		"intro": text.call("play.blitz_intro") if not zen else text.call("play.zen_intro"),
	}


# the trial table of a heroine: `base` is TWLevels.trial_cfg(hero) (the Path board of that level, NOT a stub)
static func trial_cfg(base: Dictionary, hero_name: String, text: Callable) -> Dictionary:
	var cfg: = base.duplicate(true)
	cfg["name"] = String(text.call("play.trial_name_pre")) + hero_name
	cfg["reward"] = {"gems": 0}
	cfg.erase("shard")
	cfg["goal"] = text.call("play.trial_goal")
	cfg["intro"] = text.call("play.trial_intro")
	return cfg


# a Path table: the keys the screen needs and the level may lack. loc = the location row {tint, intro} the level belongs to
static func path_fill(cfg: Dictionary, loc: Dictionary, text: Callable) -> Dictionary:
	var c: = cfg
	if not c.has("tint"):
		c["tint"] = loc.get("tint", Color(1, 1, 1))
	if not c.has("goal"):
		c["goal"] = text.call("play.goal_clear")
	if not c.has("intro") or str(c.intro).length() < 12:
		var il: = str(c.get("intro_line", ""))
		c["intro"] = il if il != "" else str(loc.get("intro", ""))
	return c


# the «Золотой дождь» fortune adds gold tiles to a Path table (not to a v10-certified one)
static func apply_fortune(cfg: Dictionary, fortune: Dictionary) -> Dictionary:
	if int(fortune.get("gold", 0)) > 0 and not cfg.has("v10_id"):
		var c: = cfg.duplicate(true)
		c["gold"] = int(c.get("gold", 0)) + int(fortune.gold)
		return c
	return cfg
