class_name TWBoosters
extends RefCounted

# TWBoosters (P20 / WP7): the help buttons (hint / undo / shuffle), their prices, the partner perks, the fortune perks, the rescue
# of a full tray and the overflow policy, lifted out of play.gd (_apply_perk, _hint/_undo/_shuffle + _v8_do_*, _v8_can_pay,
# _on_fail). Pure: the shell asks `decide`, runs the board action, then calls `commit` and spends the returned price through
# TWWallet. Nothing here knows the scene tree, G or a wallet.
#
# The counters of a round are one Dictionary (`counters()`):
#   hint_n undo_n shuffle_n        free helps left
#   rescue_free                    the first «вернуть 3 фишки» of the round is free
#   free_rescue_left               «Ладонь кицунэ» fortune: the next overflow rescues itself
#   boosters_used                  helps paid or free taken (the stars rule counts them)
#   riichi                         «Ва-банк» is on: no helps, a rescue burns it

const HELP_PRICE: = 30
const RESCUE_PRICE: = 60

const KINDS: = ["hint", "undo", "shuffle"]

# the free help the partner gives: hint (mc), undo (rin), combo window (hana), gold multiplier (yue), shuffle + 10% crystals (nova)
const PARTNER_PERKS: = {
	"mc": {"hint": 1},
	"rin": {"undo": 1},
	"hana": {"combo_window_set": 6.5},
	"yue": {"gold_mult_set": 8},
	"nova": {"shuffle": 1, "gem_bonus": 0.1},
}

const AFF_BONUS_PER_LEVEL: = 0.05


static func counters() -> Dictionary:
	return {"hint_n": 2, "undo_n": 2, "shuffle_n": 1, "rescue_free": true, "free_rescue_left": 0, "boosters_used": 0, "riichi": false}


# ── the start of a round ──────────────────────────────────────────────────────────────────────────────────────────

# everything _apply_perk gives, in the order play.gd applied it (partner perk, affection, album sets, fortune, level extras).
#   partner, aff_level (G.aff_level(partner)), album_keys (V7Album.active_keys(): "hint"/"shuffle"/"undo"/"gems"/"gold"/"combo"),
#   fortune_id, extra_hints (cfg.extra_hints)
# `base` = the counters / gold_mult / gem_bonus the round already has (default: counters() and 5 / 0.0).
# returns the counters on top of counters() plus {"gold_mult", "gem_bonus", "first_pairs_bonus", "combo_window_set" (-1 = leave the board's),
# "combo_window_add"}. The outfit is NOT an input: it never changes a number here.
static func loadout(partner: String, aff_level: int, album_keys: Array, fortune_id: String, extra_hints: int, base: Dictionary = {}) -> Dictionary:
	var o: = counters()
	o["gold_mult"] = 5
	o["gem_bonus"] = 0.0
	o["first_pairs_bonus"] = 0
	o["combo_window_set"] = -1.0
	o["combo_window_add"] = 0.0
	o.merge(base, true)       # a mode that starts with other numbers (a Climb run) gives them here: the perks add on top, as before
	var p: Dictionary = PARTNER_PERKS.get(partner, {})
	o.hint_n += int(p.get("hint", 0))
	o.undo_n += int(p.get("undo", 0))
	o.shuffle_n += int(p.get("shuffle", 0))
	if p.has("combo_window_set"):
		o.combo_window_set = float(p.combo_window_set)
	if p.has("gold_mult_set"):
		o.gold_mult = int(p.gold_mult_set)
	if p.has("gem_bonus"):
		o.gem_bonus = float(p.gem_bonus)
	o.gem_bonus += AFF_BONUS_PER_LEVEL * (aff_level - 1)
	for k in album_keys:
		match String(k):
			"hint": o.hint_n += 1
			"shuffle": o.shuffle_n += 1
			"undo": o.undo_n += 1
			"gems": o.gem_bonus += 0.1
			"gold": o.gold_mult += 1
			"combo": o.combo_window_add += 0.5
	match fortune_id:
		"great": o.gem_bonus += 0.5
		"pairs": o.first_pairs_bonus = 3
		"wind": o.shuffle_n += 1
		"tea": o.combo_window_add += 1.5
		"tray": o.free_rescue_left = 1
		"small": o.hint_n += 1
	o.hint_n += extra_hints
	return o


# ── a help tap ────────────────────────────────────────────────────────────────────────────────────────────────────

# what a tap on a help button does. ctx: input_on, hint_active (a hint already glows), has_move (a best move exists), history_empty.
# returns {"do": "locked" | "deny" | "active" | "none" | "free" | "pay", "price": int}
#   locked  «Ва-банк»: toast "play.riichi_locked"        deny   shake the button, no text
#   active  toast "hint_on"                              none   toast "undo_none" (nothing to take back)
#   free    use a free help                              pay    ask for HELP_PRICE crystals first
static func decide(kind: String, st: Dictionary, ctx: Dictionary) -> Dictionary:
	if bool(st.get("riichi", false)):
		return {"do": "locked", "price": 0}
	if not bool(ctx.get("input_on", true)):
		return {"do": "deny", "price": 0}
	match kind:
		"hint":
			if bool(ctx.get("hint_active", false)):
				return {"do": "active", "price": 0}
			if not bool(ctx.get("has_move", true)):
				return {"do": "deny", "price": 0}
			if int(st.get("hint_n", 0)) <= 0:
				return {"do": "pay", "price": HELP_PRICE}
			return {"do": "free", "price": 0}
		"undo":
			if bool(ctx.get("history_empty", false)):
				return {"do": "none", "price": 0}
			if int(st.get("undo_n", 0)) <= 0:
				return {"do": "pay", "price": HELP_PRICE}
			return {"do": "free", "price": 0}
		"shuffle":
			if int(st.get("shuffle_n", 0)) <= 0:
				return {"do": "pay", "price": HELP_PRICE}
			return {"do": "free", "price": 0}
	return {"do": "deny", "price": 0}


# the help ran on the board: take the free one or report the price to spend. Returns the crystals to spend (0 for a free help).
static func commit(kind: String, st: Dictionary, paid: bool) -> int:
	if not paid:
		match kind:
			"hint": st["hint_n"] = int(st.get("hint_n", 0)) - 1
			"undo": st["undo_n"] = int(st.get("undo_n", 0)) - 1
			"shuffle": st["shuffle_n"] = int(st.get("shuffle_n", 0)) - 1
	st["boosters_used"] = int(st.get("boosters_used", 0)) + 1
	return HELP_PRICE if paid else 0


# can the player pay? returns {"ok": bool, "missing": int} (missing = crystals short; the shell opens the shop for it)
static func afford(balance: int, price: int) -> Dictionary:
	return {"ok": balance >= price, "missing": maxi(0, price - balance)}


# ── the full tray ─────────────────────────────────────────────────────────────────────────────────────────────────

# what the overflow of the tray does in this mode.
#   {"kind": "free_return"}  zen / blitz / duel (and any mode with a kitsune rescue left): the tray returns 3 tiles, no fail counted
#        "consume_rescue"    a kitsune rescue is used up (Path / daily only)
#        "blitz_penalty"     seconds lost
#   {"kind": "fail"}         a lost round: the rescue window / fail window of the shell
static func overflow(mode: String, st: Dictionary) -> Dictionary:
	var free_left: = int(st.get("free_rescue_left", 0))
	if mode == "zen" or mode == "blitz" or mode == "duel" or free_left > 0:
		return {"kind": "free_return", "consume_rescue": free_left > 0 and mode == "", "blitz_penalty": 10.0 if mode == "blitz" else 0.0}
	return {"kind": "fail"}


# applies `overflow` to the counters (free_rescue_left) and the blitz clock; returns the decision plus {"blitz_left": new, "blitz_over": bool}
static func apply_overflow(mode: String, st: Dictionary, blitz_left: float) -> Dictionary:
	var d: = overflow(mode, st)
	d["blitz_left"] = blitz_left
	d["blitz_over"] = false
	if d.kind == "free_return":
		if d.consume_rescue:
			st["free_rescue_left"] = int(st.get("free_rescue_left", 0)) - 1
		if mode == "blitz":
			d["blitz_left"] = maxf(0.0, blitz_left - float(d.blitz_penalty))
			d["blitz_over"] = float(d.blitz_left) <= 0.0
	else:
		st["fails"] = int(st.get("fails", 0)) + 1
	return d


# the paid rescue of a lost round: the first one of a round is free, the next ones cost RESCUE_PRICE
static func rescue_price(st: Dictionary) -> int:
	return 0 if bool(st.get("rescue_free", true)) else RESCUE_PRICE


# the rescue is taken (price already spent): counts as a help, the first free rescue is gone, «Ва-банк» burns.
# returns {"price": what was due, "riichi_burnt": bool}
static func rescue_commit(st: Dictionary) -> Dictionary:
	var price: = rescue_price(st)
	st["rescue_free"] = false
	st["boosters_used"] = int(st.get("boosters_used", 0)) + 1
	var burnt: = bool(st.get("riichi", false))
	if burnt:
		st["riichi"] = false
	return {"price": price, "riichi_burnt": burnt}


# the shell's rule: a lost Path / daily table the player leaves counts as a lost game, a blitz / duel left early too, zen never
static func counts_loss(mode: String) -> bool:
	return TWModeCfg.source(mode) in ["path", "daily", "duel", "blitz"]
