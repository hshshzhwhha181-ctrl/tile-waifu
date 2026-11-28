class_name TWResultChain
extends RefCounted

# TWResultChain (P33 / WP10c): the victory screen as DATA, no nodes. What the player sees after a won round, how long it takes and what a
# tap does, all as pure functions of a TWRoundResult (P20) and a few facts about the player's history.
#
#   plan(res, facts)          -> {kind: "fast" | "chain" | "none", milestones: [...], ftue, sting, stars, view, timeline}
#   milestones(res, facts)    -> ["first_win", "chapter_boss", "first_3star", "tenth_win"] (those that apply)
#   TWResultChain.Run         the state machine of one showing: advance(dt) / tap() / skip(), cues, which panel, is the button ready
#
# Two shapes (GDD 9.6, S21):
#   fast   one panel, <= 3 s from "Поле чисто" to the button: 120 ms of silence, stars every 120 ms, reward icons fly, Bond and Season XP
#          fill, the primary button «Ещё уровень» comes in. The short sting (~1.2 s) plays, never the 9.3 s one.
#   chain  only on a milestone (the first win of a life, a chapter boss, the first 3-star of a chapter, every 10th win): three panels
#          (stars + «Поле чисто» / rewards / heroine win-art + Bond + Season XP), <= 20 s to the one Confirm. 400 ms of silence, then the
#          9.3 s sting as a bed that a tap cuts. A tap speeds the current panel up (settle), the next tap goes to the next panel.
#   FTUE   the first win of a life on L1-L3 is the fast shape with the short sting (GDD 6.1): the truncated chain.
#
# There is no field for «осталось сегодня», a sale or an interstitial anywhere here: the facts and the view carry what was EARNED only
# (the selftest greps every text the modal can show, and this file, for those words).
#
# facts (all optional): wins_before (lifetime wins before this one), is_boss (a chapter boss node), chapter_has_3star (an earlier
# 3-star in this chapter), ftue (L1-L3), partner (hero id for the win art), bond {"from", "to"} / xp {"from", "to"} (0..1 bar fractions;
# the shell passes the real tier progress, the default only shows the earned step).

const KIND_FAST: = "fast"
const KIND_CHAIN: = "chain"
const KIND_NONE: = "none"

const FAST_MAX_S: = 3.0                  # acceptance: «Поле чисто» to the button
const CHAIN_MAX_S: = 20.0                # acceptance: the whole chain to the one Confirm

const M_FIRST_WIN: = "first_win"
const M_BOSS: = "chapter_boss"
const M_FIRST_3STAR: = "first_3star"
const M_TENTH: = "tenth_win"
const WIN_EVERY: = 10

const STING_SHORT: = "sting_victory_short"
const STING_LONG: = "sting_victory"
const STING_SHORT_LEN: = 1.2
const STING_LONG_LEN: = 9.288

# what the player reads (the only copy in the victory screen; the lint greps this table)
const TEXT: = {
	"clear": "Поле чисто",
	"next": "Ещё уровень",
	"map": "На карту",
	"share": "Поделиться",
	"skip": "Пропустить",
	"rewards": "Награды",
	"bond": "Связь +%d",
	"xp": "Сезон +%d",
	"rank_up": "Новый ранг: %s",
	"rp": "Ранг +%d",
	M_FIRST_WIN: "Первая победа!",
	M_BOSS: "Босс главы побеждён",
	M_FIRST_3STAR: "Первые три звезды главы",
	M_TENTH: "%d-я победа",
}

# ---- fast timeline (s): the numbers of GDD 9.6 --------------------------------------------------------------------------------
const F_SILENCE: = 0.12                  # «Поле чисто» comes in after 120 ms of silence (400 ms in the chain)
const F_TITLE_IN: = 0.24
const F_STAR0: = 0.30
const F_STAR_STEP: = 0.12                # a star every 120 ms
const F_STAR_POP: = 0.18
const F_FLY0: = 0.66                     # the reward icons start to fly
const F_FLY_STEP: = 0.08
const F_FLY_LEN: = 0.50
const F_FILL0: = 0.70                    # Bond bar and Season XP ring
const F_FILL_LEN: = 0.60
const F_CTA: = 1.40                      # the primary button comes in (live from here; a tap before it only settles)
const F_CTA_IN: = 0.24
const F_SETTLE: = 1.70

# ---- chain timeline (s) ------------------------------------------------------------------------------------------------------
const C_PANEL: = 6.0                     # one panel, nominal
const C_SILENCE: = 0.4
const C_STAR0: = 0.9
const C_STAR_STEP: = 0.6
const C_MILESTONE: = 2.7
const C_SETTLE: = [3.4, 3.0, 3.4]        # when the content of panel i is complete (a tap before this jumps here)
const C_ROW0: = 0.4
const C_ROW_STEP: = 0.5
const C_ROW_ROLL: = 0.8
const C_HERO_IN: = 0.3
const C_FILL0: = 1.0
const C_FILL_LEN: = 1.2
const C_CTA: = 3.0                       # panel 3: the Confirm comes in (15.0 s from the start)


# ── milestones and kind ───────────────────────────────────────────────────────────────────────────────────────────────────

static func is_win(res) -> bool:
	return res != null and bool(res.win) and String(res.outcome) in ["win", "board", "end"]


static func milestones(res, facts: Dictionary) -> Array:
	var out: Array = []
	if not is_win(res):
		return out
	var before: = int(facts.get("wins_before", 1))   # a missing history is not a milestone: assume an old player
	if before <= 0:
		out.append(M_FIRST_WIN)
	if bool(facts.get("is_boss", false)):
		out.append(M_BOSS)
	if int(res.stars) >= 3 and not bool(facts.get("chapter_has_3star", true)):
		out.append(M_FIRST_3STAR)
	if before >= 0 and (before + 1) % WIN_EVERY == 0:
		out.append(M_TENTH)
	return out


static func kind_of(res, facts: Dictionary) -> String:
	if not is_win(res):
		return KIND_NONE
	if milestones(res, facts).is_empty() or bool(facts.get("ftue", false)):
		return KIND_FAST
	return KIND_CHAIN


static func milestone_text(m: String, wins_before: int = 0) -> String:
	var t: String = String(TEXT.get(m, ""))
	if m == M_TENTH:
		return t % (wins_before + 1)
	return t


# what the panels draw, from the result alone: no history, no counters of what is left
static func view_of(res, facts: Dictionary = {}) -> Dictionary:
	var rows: Array = []
	if res != null:
		for g in res.grants:
			var cur: = String(g.cur)
			var idx: = -1
			for i in rows.size():
				if String(rows[i].cur) == cur:
					idx = i
			if idx >= 0:
				rows[idx].n = int(rows[idx].n) + int(g.n)
			else:
				rows.append({"cur": cur, "n": int(g.n)})
	var bond_n: = 0
	var hero: = String(facts.get("partner", ""))
	if res != null:
		for b in res.bond:
			bond_n += int(b.n)
			if hero == "" and String(b.hero) != "":
				hero = String(b.hero)
	var xp_n: = int(res.pass_xp) if res != null else 0
	var bf: Dictionary = facts.get("bond", {}) if facts.get("bond") is Dictionary else {}
	var xf: Dictionary = facts.get("xp", {}) if facts.get("xp") is Dictionary else {}
	var b0: = clampf(float(bf.get("from", 0.5)), 0.0, 1.0)
	var x0: = clampf(float(xf.get("from", 0.5)), 0.0, 1.0)
	return {
		"stars": clampi(int(res.stars) if res != null else 0, 0, 3),
		"rows": rows,
		"bond_n": bond_n, "hero": hero,
		"bond_from": b0, "bond_to": clampf(float(bf.get("to", minf(1.0, b0 + float(bond_n) / 100.0))), b0, 1.0),
		"xp_n": xp_n,
		"xp_from": x0, "xp_to": clampf(float(xf.get("to", minf(1.0, x0 + float(xp_n) / 400.0))), x0, 1.0),
		"rp_gain": int(res.rp_gain) if res != null else 0,
		"rank_title": String(res.rank_title) if res != null else "",
	}


static func plan(res, facts: Dictionary = {}) -> Dictionary:
	var kind: = kind_of(res, facts)
	var ms: = milestones(res, facts)
	var ftue: = bool(facts.get("ftue", false)) and not ms.is_empty()
	var view: = view_of(res, facts)
	var tl: = timeline(kind, view)
	return {"kind": kind, "milestones": ms, "ftue": ftue, "sting": STING_LONG if kind == KIND_CHAIN else STING_SHORT,
		"stars": int(view.stars), "view": view, "timeline": tl, "wins_before": int(facts.get("wins_before", 0))}


# ── timelines ─────────────────────────────────────────────────────────────────────────────────────────────────────────────
# {kind, panels: [{id, t0, settle, end}], cues: [{t, name, data}], cta_t, total, silence, sting_t, sting_len}
# `settle` is the absolute time at which the content of the panel is complete, `end` when the next panel starts on its own (INF for the last).

static func timeline(kind: String, view: Dictionary = {}) -> Dictionary:
	if kind == KIND_CHAIN:
		return _chain(view)
	return _fast(view)


static func _fast(view: Dictionary) -> Dictionary:
	var cues: Array = []
	cues.append({"t": F_SILENCE, "name": STING_SHORT, "data": {}})
	cues.append({"t": F_SILENCE, "name": "title", "data": {}})
	for i in int(view.get("stars", 0)):
		cues.append({"t": F_STAR0 + F_STAR_STEP * i, "name": "star", "data": {"i": i}})
	var rows: Array = view.get("rows", [])
	for i in rows.size():
		var cur: = String(rows[i].cur)
		cues.append({"t": F_FLY0 + F_FLY_STEP * i, "name": "gem_fly" if cur == "gems" else "coin_fly", "data": {"cur": cur, "i": i}})
	if int(view.get("bond_n", 0)) > 0 or int(view.get("xp_n", 0)) > 0:
		cues.append({"t": F_FILL0, "name": "fill", "data": {}})
	cues.append({"t": F_CTA, "name": "cta", "data": {}})
	cues.sort_custom(func(a, b): return float(a.t) < float(b.t))
	return {"kind": KIND_FAST, "panels": [{"id": "all", "t0": 0.0, "settle": F_SETTLE, "end": INF}], "cues": cues, "cta_t": F_CTA,
		"total": F_SETTLE, "silence": F_SILENCE, "sting_t": F_SILENCE, "sting_len": STING_SHORT_LEN, "sting": STING_SHORT}


static func _chain(view: Dictionary) -> Dictionary:
	var cues: Array = []
	var p1: = C_PANEL
	var p2: = 2.0 * C_PANEL
	cues.append({"t": C_SILENCE, "name": STING_LONG, "data": {}})
	cues.append({"t": C_SILENCE, "name": "title", "data": {}})
	for i in int(view.get("stars", 0)):
		cues.append({"t": C_STAR0 + C_STAR_STEP * i, "name": "star", "data": {"i": i}})
	cues.append({"t": C_MILESTONE, "name": "milestone", "data": {}})
	cues.append({"t": p1, "name": "panel", "data": {"i": 1}})
	var rows: Array = view.get("rows", [])
	for i in mini(rows.size(), 4):
		var cur: = String(rows[i].cur)
		cues.append({"t": p1 + C_ROW0 + C_ROW_STEP * i, "name": "gem_fly" if cur == "gems" else "coin_fly", "data": {"cur": cur, "i": i}})
	cues.append({"t": p2, "name": "panel", "data": {"i": 2}})
	cues.append({"t": p2 + C_HERO_IN, "name": "hero", "data": {}})
	if int(view.get("bond_n", 0)) > 0 or int(view.get("xp_n", 0)) > 0:
		cues.append({"t": p2 + C_FILL0, "name": "fill", "data": {}})
	cues.append({"t": p2 + C_CTA, "name": "cta", "data": {}})
	cues.sort_custom(func(a, b): return float(a.t) < float(b.t))
	var panels: Array = [
		{"id": "stars", "t0": 0.0, "settle": C_SETTLE[0], "end": p1},
		{"id": "rewards", "t0": p1, "settle": p1 + C_SETTLE[1], "end": p2},
		{"id": "hero", "t0": p2, "settle": p2 + C_SETTLE[2], "end": INF},
	]
	return {"kind": KIND_CHAIN, "panels": panels, "cues": cues, "cta_t": p2 + C_CTA, "total": p2 + C_PANEL, "silence": C_SILENCE,
		"sting_t": C_SILENCE, "sting_len": STING_LONG_LEN, "sting": STING_LONG}


# ── the state machine of one showing ─────────────────────────────────────────────────────────────────────────────────────────

class Run extends RefCounted:
	var tl: Dictionary
	var kind: = "fast"
	var t: = 0.0
	var panel: = 0
	var fired: Array = []           # cue names that played in time
	var skipped: Array = []         # cue names a tap / skip jumped over
	var cue_sink: Callable          # (name: String, data: Dictionary, skipped: bool) -> void
	var sting_cut: = false          # a tap cut the sting
	var taps: = 0
	var accels: = 0
	var nexts: = 0
	var skip_used: = false
	var _ci: = 0

	func _init(p_tl: Dictionary) -> void:
		tl = p_tl
		kind = String(p_tl.kind)
		_fire(0.0, false)

	func n_panels() -> int:
		return (tl.panels as Array).size()

	func cta_ready() -> bool:
		return t >= float(tl.cta_t)

	func settled() -> bool:
		return t >= float(tl.panels[panel].settle)

	func sting_playing() -> bool:
		return not sting_cut and t >= float(tl.sting_t) and t < float(tl.sting_t) + float(tl.sting_len) and fired.has(String(tl.sting))

	# seconds into the current panel
	func local_t() -> float:
		return t - float(tl.panels[panel].t0)

	func panel_start(i: int) -> float:
		return float(tl.panels[i].t0)

	func advance(dt: float) -> void:
		if dt <= 0.0:
			return
		var from: = t
		t += dt
		_fire(t, false)
		_panel_follow()
		if from > t:
			t = from

	# a tap on the stage (not on a button). Returns "accel" | "next" | "none".
	func tap() -> String:
		taps += 1
		if kind == "chain" and not sting_cut and sting_playing():
			_cut_sting()
		var p: Dictionary = tl.panels[panel]
		if t < float(p.settle):
			_jump(float(p.settle))
			accels += 1
			return "accel"
		if kind == "chain" and panel < n_panels() - 1:
			_jump(float(tl.panels[panel + 1].t0))
			nexts += 1
			return "next"
		return "none"

	# the Skip button: straight to the end, the button ready
	func skip() -> void:
		skip_used = true
		if kind == "chain" and sting_playing():
			_cut_sting()
		var target: = maxf(float(tl.cta_t), float(tl.panels[n_panels() - 1].settle) if kind == "chain" else float(tl.cta_t))
		if t < target:
			_jump(target)

	func _cut_sting() -> void:
		sting_cut = true
		if cue_sink.is_valid():
			cue_sink.call("sting_stop", {}, false)
		fired.append("sting_stop")

	func _jump(to: float) -> void:
		if to <= t:
			return
		t = to
		_fire(t, true)
		_panel_follow()

	func _panel_follow() -> void:
		var i: = panel
		while i + 1 < n_panels() and t >= float(tl.panels[i + 1].t0):
			i += 1
		panel = i

	func _fire(upto: float, jumped: bool) -> void:
		var cues: Array = tl.cues
		while _ci < cues.size() and float(cues[_ci].t) <= upto + 1e-9:
			var c: Dictionary = cues[_ci]
			_ci += 1
			var nm: = String(c.name)
			if jumped and (nm == String(tl.sting) or nm in ["gem_fly", "coin_fly", "star"]):
				skipped.append(nm)           # a sound that is late is not played
				if cue_sink.is_valid():
					cue_sink.call(nm, c.data, true)
			else:
				fired.append(nm)
				if cue_sink.is_valid():
					cue_sink.call(nm, c.data, false)
