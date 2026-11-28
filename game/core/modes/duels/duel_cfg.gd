class_name V10DuelCfg
extends RefCounted

# V10DuelCfg — the table of a «Дуэли 2.0» match (spec R6, «Честный стол»).
#
#   deal_seed(kind, day, rival, form, round = 0) -> int   one deal per (day, rival, form): the same numbers give the
#                                         same table; friendly and weekly use their own salt, so a friendly game never
#                                         shows today's ranked table
#   cfg_for(args, partner) -> Dictionary  the board cfg for play.gd: fixed seed (cfg.seed, cfg.seed_locked = true),
#                                         shape from the seed, the weekly rule's table changes, normalized in ranked
#   is_duel2(args) / normalized(args)     args.duel2 == true / ranked (normalized: 4 slots, 1 hint, no outfit power)
#   SLOTS = 4, HELPS_RANKED = {hint 1, undo 0, shuffle 0}
#
# Determinism needs the play.gd hook H2 (README): seed(int(cfg.seed)) right before board.setup(cfg), because
# TrayBoard._assign still deals faces from the global RNG (until the M1 «засев» lands, then cfg.seed feeds V10Seed).
# The layout itself (TrayBoard.gen_layout) is already seeded by cfg.seed.

const U: = preload("res://core/modes/duels/duel_util.gd")
const F: = preload("res://core/modes/duels/duel_forms.gd")

const SLOTS: = 4
const HELPS_RANKED: = {"hint": 1, "undo": 0, "shuffle": 0}
const SHAPES: = ["rect", "heart", "diamond", "butterfly", "ring", "pyramid"]
const TABLE: = {"cols": 6, "rows": 7, "layers": 3, "fill": 0.8, "faces": 11, "gold": 2, "ice": 0}
const BG: = {"mc": ["play", "petals"], "rin": ["bg_teahouse", "petals"], "hana": ["bg_street", "lanterns"],
	"yue": ["bg_palace", "petals"], "nova": ["bg_neon", "lanterns"]}
const KIND_NAMES: = {"ranked": "Рейтинговая дуэль", "friendly": "Дружеская дуэль", "weekly": "Дуэль недели"}


static func deal_seed(kind: String, day: String, rival: String, form: int, round_n: int = 0) -> int:
	var salt: = "ranked" if kind == "ranked" else kind
	return 1 + (U.hseed(["duel2", salt, day, rival, form, round_n]) % 999999999)


static func is_duel2(args: Dictionary) -> bool:
	return bool(args.get("duel2", false))


static func normalized(args: Dictionary) -> bool:
	return is_duel2(args) and String(args.get("kind", "ranked")) == "ranked"


static func kind_name(kind: String) -> String:
	return String(KIND_NAMES.get(kind, KIND_NAMES.friendly))


static func cfg_for(args: Dictionary, partner: String) -> Dictionary:
	var kind: = String(args.get("kind", "ranked"))
	var rival: = String(args.get("rival", "rin"))
	var form: = clampi(int(args.get("form", 3)), 1, F.FORMS)
	var sd: = int(args.get("seed", 0))
	if sd <= 0:
		sd = deal_seed(kind, U.cal_key(), rival, form, 0)
	var r: = U.rng(sd, "table")
	var bgfx: Array = BG.get(rival, ["play", "petals"])
	var name: = U.hero_name(rival)
	var c: = {
		"name": kind_name(kind), "code": "", "bg": bgfx[0], "fx": bgfx[1], "tint": Color(1, 1, 1),
		"hero": partner, "shape": SHAPES[r.randi() % SHAPES.size()],
		"mech": "", "hard": 0, "seed": sd, "hidden": false, "reward": {"gems": 0},
		"goal": "Собери больше пар, чем %s" % name,
		"intro": "%s снимает пары с того же стола. Её цель мерцает заранее: забери пару первым, и её ход сорвётся." % name,
		"seed_locked": true, "duel2": true, "kind": kind, "rival": rival, "form": form,
		"normalized": kind == "ranked",
	}
	for k in TABLE:
		c[k] = TABLE[k]
	if kind == "weekly":
		var rule: = F.weekly_rule(rival)
		var rc: Dictionary = rule.get("cfg", {})
		for k in rc:
			c[k] = rc[k]
		c["rule"] = String(rule.id)
		c["goal"] = "%s · %s" % [String(rule.name), c.goal]
	return c


static func helps_for(args: Dictionary) -> Dictionary:
	return HELPS_RANKED.duplicate() if normalized(args) else {}


static func all_texts() -> Array:
	var out: = []
	for k in KIND_NAMES:
		out.append(KIND_NAMES[k])
	for h in F.HEROES:
		var c: = cfg_for({"kind": "weekly", "rival": h, "form": 3, "seed": 7}, "mc")
		out.append(String(c.goal))
		out.append(String(c.intro))
	return out
