class_name V10PathBoosters
extends RefCounted

# 0.10 · Огонёк пути (0.10-spec П3): start boosters earned by playing.
#   S.v10_boosters = {lantern, wind, scroll, flame: 0..3}
#   flame step 1/2/3 gives 1/2/3 free boosters at the start (Фонарик → +Ветер → +Свиток). A win lifts the flame
#   one step, a fail takes one step away (never resets to 0 at once).
#   Three circles on the level card: tap = use from stock; empty stock = buy for BOOST_PRICE crystals (confirm).
#   At most BOOST_MAX per level. Peaks, Legendary, Очень сложный, Пагода, Странствие, рейтинг, Чтение руки:
#   circles grey «Здесь только честная игра» (can_use = false). No «+1 tray slot» booster exists.
#
#   Фонарик: tiles start revealed (no secret, no flip-backs). Попутный ветер: 2 pairs leave at the start and do NOT
#   count for combo. Свиток: +3 hints.

const Gen = preload("res://core/levels/level_gen.gd")
const Sim = preload("res://core/levels/level_sim.gd")
const Rules = preload("res://core/path/path_rules.gd")
const State = preload("res://core/path/path_state.gd")


static func st() -> Dictionary:
	var s: = State.S()
	if not (s.get("v10_boosters") is Dictionary):
		s["v10_boosters"] = {}
	var d: Dictionary = s["v10_boosters"]
	for k in ["lantern", "wind", "scroll", "flame"]:
		if not d.has(k):
			d[k] = 0
	return d


static func flame() -> int:
	return clampi(int(st().flame), 0, 3)


static func stock(kind: String) -> int:
	return int(st().get(kind, 0))


# UX_RULES §3.5: Огонёк пути and the booster row appear at L10 (the card and the map hide them before that)
static func opened() -> bool:
	return State.unlocked() >= Rules.BOOST_FROM


# crystals the player can spend on a booster (V10Wallet when merged, else the plain counter)
static func gems_balance() -> int:
	var wallet = Rules.cls("V10Wallet") if State.root_override == null else null
	if wallet != null and wallet.has_method("balance"):
		return int(wallet.balance("gems"))
	return int(State.S().get("gems", 0))


static func can_use(mode: String, tier: String, peak: = false) -> bool:
	if mode in Rules.HONEST_MODES:
		return false
	if tier in Rules.HONEST_TIERS:
		return false
	return not peak


static func can_use_level(i: int, mode: = "") -> bool:
	var n: = State.node(i)
	return can_use(mode, str(n.tier), bool(n.peak))


# the flame moves only where boosters are allowed (honest tables do not feed or drain it)
static func on_win(mode: String, tier: String, peak: = false) -> int:
	if can_use(mode, tier, peak):
		st().flame = mini(flame() + 1, 3)
	return flame()


static func on_fail(mode: String, tier: String, peak: = false) -> int:
	if can_use(mode, tier, peak):
		st().flame = maxi(flame() - 1, 0)
	return flame()


# the boosters the flame gives for free at this start
static func free_at_start() -> Array:
	return Rules.BOOSTERS.slice(0, flame())


# The selection the card starts with: free ones are on. Returns {kind: "free"|"stock"|"" }.
static func initial_selection(i: int, mode: = "") -> Dictionary:
	var sel: = {}
	if not can_use_level(i, mode):
		return sel
	for k in free_at_start():
		sel[k] = "free"
	return sel


# Tap on a circle: returns the new source for that booster: "free"/"stock" = on, "" = off, "buy" = needs the
# crystal confirm (caller asks, then calls buy() and toggles again), "deny" = honest table or limit.
static func toggle(sel: Dictionary, kind: String, i: int, mode: = "") -> String:
	if not can_use_level(i, mode):
		return "deny"
	if sel.has(kind):
		if str(sel[kind]) == "free":
			# a free booster can be switched off (and back on) without touching the stock
			sel.erase(kind)
			sel["_off_" + kind] = true
			return ""
		sel.erase(kind)
		return ""
	if sel.has("_off_" + kind):
		sel.erase("_off_" + kind)
		sel[kind] = "free"
		return "free"
	if _count(sel) >= Rules.BOOST_MAX:
		return "deny"
	if stock(kind) > 0:
		sel[kind] = "stock"
		return "stock"
	return "buy"


static func _count(sel: Dictionary) -> int:
	var n: = 0
	for k in sel:
		if not str(k).begins_with("_"):
			n += 1
	return n


# buy one booster for crystals (the card asks first). V10Money when merged, else plain counter.
static func buy(kind: String) -> bool:
	var s: = State.S()
	var mon = Rules.cls("V10Money") if State.root_override == null else null
	if mon != null and mon.has_method("spend"):
		if not bool(mon.call("spend", {"gems": Rules.BOOST_PRICE}, "path_booster_" + kind)):
			return false
		st()[kind] = stock(kind) + 1
		State.save()
		return true
	var wallet = Rules.cls("V10Wallet") if State.root_override == null else null
	if wallet != null and wallet.has_method("spend"):
		if not wallet.spend("gems", Rules.BOOST_PRICE, "path_booster_" + kind):
			return false
	else:
		if int(s.get("gems", 0)) < Rules.BOOST_PRICE:
			return false
		s["gems"] = int(s.get("gems", 0)) - Rules.BOOST_PRICE
	st()[kind] = stock(kind) + 1
	State.save()
	return true


# Start of the level: take the stock for the non-free ones. Returns the list of applied boosters.
static func commit(sel: Dictionary, i: int, mode: = "") -> Array:
	var out: = []
	if not can_use_level(i, mode):
		return out
	for k in Rules.BOOSTERS:
		if not sel.has(k):
			continue
		if str(sel[k]) == "stock":
			if stock(k) <= 0:
				continue
			st()[k] = stock(k) - 1
		out.append(k)
		if out.size() >= Rules.BOOST_MAX:
			break
	State.save()
	return out


# cfg side: the play screen reads cfg.v10_boost / cfg.extra_hints
static func apply_cfg(cfg: Dictionary, applied: Array) -> Dictionary:
	cfg["v10_boost"] = applied.duplicate()
	if "scroll" in applied:
		cfg["extra_hints"] = int(cfg.get("extra_hints", 0)) + 3
	if "wind" in applied and cfg.has("v10"):
		cfg["v10_wind"] = wind_pairs(cfg)
	return cfg


# Payload side of the Фонарик (used by the selftest and by boards that read the payload before setup):
# no flip-backs, no secret tiles.
static func lantern_payload(cfg: Dictionary) -> void:
	if not cfg.has("v10"):
		cfg["ice"] = 0
		cfg["hidden"] = false
		return
	var b: Dictionary = cfg.v10
	var ice: PackedByteArray = (b.ice as PackedByteArray).duplicate()
	ice.fill(0)
	var sec: PackedByteArray = (b.secret as PackedByteArray).duplicate()
	sec.fill(0)
	b["ice"] = ice
	b["secret"] = sec


# Попутный ветер: up to 2 pairs that are free at the start, plain (no special, no shard; flip-backs are fine), chosen so
# the level stays provably solvable: the pairs are taken first, then the certificate (minus them) must replay.
static func wind_pairs(cfg: Dictionary, want: = 2) -> Array:
	if not cfg.has("v10"):
		return []
	var sim: = Sim.new()
	Gen.load_into(sim, cfg)
	sim.reset()
	var b: Dictionary = cfg.v10
	var shard: PackedByteArray = b.shard
	var cert: PackedInt32Array = b.cert
	var rank: = {}
	for k in cert.size():
		rank[cert[k]] = k
	var cands: = []
	for t in sim.freel:
		if sim.kind[t] == 0 and shard[t] == 0 and sim.face0[t] < Sim.JOKER:
			cands.append(t)
	cands.sort_custom(func(x, y): return int(rank.get(x, 0)) < int(rank.get(y, 0)))
	var picked: = []
	var used: = {}
	for a in cands:
		if picked.size() >= want:
			break
		if used.has(a):
			continue
		for c in cands:
			if c == a or used.has(c) or sim.face0[c] != sim.face0[a]:
				continue
			var trial: Array = picked + [[a, c]]
			if verify_with(sim, cfg, trial).is_empty():
				picked = trial
				used[a] = true
				used[c] = true
				break
	return picked


# replay: the given pairs first (two taps each, tray empty), then the certificate without those tiles
static func verify_with(sim, cfg: Dictionary, pairs: Array) -> Dictionary:
	Gen.load_into(sim, cfg)
	sim.reset()
	var gone: = {}
	for pr in pairs:
		for t in pr:
			if sim.present[t] == 0 or not sim.is_free(t) or not sim.takeable(t):
				return {"why": "wind tile %d not free" % t}
			while sim.ice[t] > 0:
				sim.tap(t)
			sim.tap(t)
			gone[t] = true
		if not sim.tray.is_empty():
			return {"why": "wind pair did not pair"}
	var cert: PackedInt32Array = cfg.v10.cert
	for k in cert.size():
		var t: = cert[k]
		if gone.has(t):
			continue
		if sim.present[t] == 0 or not sim.is_free(t):
			return {"why": "tile %d not free" % t, "at": k}
		if not sim.takeable(t):
			return {"why": "tile %d locked" % t, "at": k}
		while sim.ice[t] > 0:
			sim.tap(t)
		if sim.tap(t) < 0:
			return {"why": "tray overflow", "at": k}
	if not sim.won():
		return {"why": "board not clear"}
	return {}


# Board side (play.gd calls this right after the deal): reveal for the Фонарик, quiet removal for the Ветер.
# The quiet removal does not emit `matched` (no combo, no chime ladder) but counts the pair for chains / keys.
static func apply_board(board, cfg: Dictionary) -> void:
	var applied: Array = cfg.get("v10_boost", [])
	if "lantern" in applied:
		for t in board.tiles:
			if not t.alive:
				continue
			if t.secret and t.has_method("reveal"):
				t.reveal()
			if t.ice > 0:
				t.ice = 0
				if t.has_method("_update_ice"):
					t._update_ice()
	if "wind" in applied:
		var pairs: Array = cfg.get("v10_wind", [])
		var k: = 0
		for pr in pairs:
			var a = board.tiles[int(pr[0])]
			var c = board.tiles[int(pr[1])]
			if not (a.alive and c.alive):
				continue
			_quiet_vanish(board, a, k)
			_quiet_vanish(board, c, k)
			if board.has_method("_pair_gone_quiet"):
				board._pair_gone_quiet(a, c)
			k += 1
		if board.has_method("reveal_free"):
			board.reveal_free()


static func _quiet_vanish(board, t, k: int) -> void:
	t.alive = false
	if t.has_method("kill_move"):
		t.kill_move()
	t.z_index = 150
	if not board.is_inside_tree():
		t.hide()
		return
	var tw: Tween = t.create_tween()
	tw.tween_interval(0.15 + 0.12 * k)
	tw.tween_property(t, "position", t.position + Vector2(220 if k % 2 == 0 else -220, -260), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(t, "rotation", 0.9 if k % 2 == 0 else -0.9, 0.45)
	tw.parallel().tween_property(t, "modulate:a", 0.0, 0.45)
	tw.tween_callback(t.hide)
