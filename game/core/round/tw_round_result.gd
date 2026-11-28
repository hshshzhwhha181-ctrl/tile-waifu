class_name TWRoundResult
extends RefCounted

# TWRoundResult (P20 / WP7): what TWRound.resolve() returns. A plain record: the shell applies it (wallet grants, bond, tasks, stats, rank
# ladder) and draws it. There is NO field for a daily limit or an «осталось сегодня» counter, on purpose (GDD P5, gate 5): a result
# screen shows what was earned, never what is left. round_selftest checks the key set.
#
#   mode, source, outcome   "win" | "lose" | "end" (blitz run over) | "board" (one zen board cleared) | "draw" (duel)
#   win, stars, first, secs
#   reward                  crystals shown as the reward of the table (the victory window's number)
#   grants                  [{cur, n, reason}] in the order the shell must apply them (rank-up crystals are paid by add_rp, not listed here)
#   rp_before, rp_gain, rp_after, rank_ups [{tier, sub, gems}], rank_title ("" when no rank-up)
#   yaku                    ids of the won table's yaku, yaku_seen = ids to count in S.yaku_seen (not the set:N ones)
#   record                  {"source", "won"} for G.record_game, {} when the game is not counted
#   bond                    [{hero, n, src}]
#   tasks                   [{key, n}]
#   pass_xp, xp
#   writes                  state edits: stars (level -> stars to store), unlocked, daily_done_day, item, tut_done, blitz_best, ...
#   flags                   first_unlock_summon, starter_path_win, riichi, ...
#   events                  [{t: "ROUND_ENDED" | "RANK_UP" | "TASK_PROGRESS", ...}] (TWEvents vocabulary, GDD 3.5)
#   hook                    the V10Hooks game_ended payload (the shell adds stars_delta / first_win_day)

const KEYS: = ["mode", "source", "outcome", "win", "stars", "first", "secs", "reward", "grants", "rp_before", "rp_gain", "rp_after", "rank_ups",
	"rank_title", "yaku", "yaku_seen", "record", "bond", "tasks", "pass_xp", "xp", "writes", "flags", "events", "hook"]

var mode: = ""
var source: = "other"
var outcome: = "lose"
var win: = false
var stars: = 0
var first: = false
var secs: = 0.0
var reward: = 0
var grants: Array = []
var rp_before: = 0
var rp_gain: = 0
var rp_after: = 0
var rank_ups: Array = []
var rank_title: = ""
var yaku: Array = []
var yaku_seen: Array = []
var record: Dictionary = {}
var bond: Array = []
var tasks: Array = []
var pass_xp: = 0
var xp: = 0
var writes: Dictionary = {}
var flags: Dictionary = {}
var events: Array = []
var hook: Dictionary = {}


func grant(cur: String, n: int, reason: String) -> void:
	if n > 0:
		grants.append({"cur": cur, "n": n, "reason": reason})


func granted(cur: String) -> int:
	var t: = 0
	for g in grants:
		if String(g.cur) == cur:
			t += int(g.n)
	return t


# pay the grants through a TWWallet in order; returns the WALLET_CHANGED events (a refused line is skipped and reported as {"type": "ERROR"})
func pay(w: TWWallet) -> Array:
	var out: Array = []
	for g in grants:
		var res: Dictionary = w.grant({String(g.cur): int(g.n)}, String(g.reason))
		if bool(res.get("ok", false)):
			out.append_array(res.get("events", []))
		else:
			out.append({"type": "ERROR", "cur": g.cur, "error": res.get("error", "")})
	return out


func to_dict() -> Dictionary:
	var d: = {}
	for k in KEYS:
		d[k] = get(k)
	return d


# a stable text of the whole result (the table tests compare two results with it)
func digest() -> String:
	return JSON.stringify(to_dict(), "", true)
