class_name V10TowerBoard
extends RefCounted

# Weekly tables of the tower track. Nothing is stored: every AI value comes from the population seed, the
# player id, the week and the time (like V8League / V8Population).
#
#   V10TowerBoard.pagoda_week(t)        the Pagoda week table: the player + 29 players of V8Population near
#                                       their rank. Rows like V8League.group_rows: {pid, name, hero, avatar,
#                                       score, floors, heat, tier, me}. Scores grow through the week (monotonic).
#   V10TowerBoard.heroine_records()     «Рекорды героинь»: the released goddesses as NPC climbers, always
#                                       labelled «соперницы-героини (ИИ)» (spec R2).
#   V10TowerBoard.journey_week(wid)     Странствие table: the goddesses as AI rivals (labelled, spec R3) + the player.
# Rewards never depend on a place in any of these tables (Pagoda: by the player's own floor; Journey: by the
# player's own best attempt), so the AI rows cannot cost the player anything.
#
# Owner decision (docs/STATE.md 23.11, spec §11 p.1): population rows carry no «AI» mark (SIM_LABEL = false, as in
# the league); goddess rows are always marked because they are named characters.

const U: = preload("res://scripts/v10/tower/tower_util.gd")
const M: = preload("res://scripts/v10/tower/mods.gd")

const SIM_LABEL: = false
const SIM_LABEL_TEXT: = "симулированные соперники"
const HEROINE_LABEL: = "соперницы-героини (ИИ)"
const GROUP: = 30

static var _test_profile_id = null

static func _pid() -> String:
	if _test_profile_id != null:
		return String(_test_profile_id)
	return String(G.profile().get("id", ""))

static func _my_tier() -> int:
	return int(G.rank_of(int(G.S.get("rp", 0))).tier)

# 29 players of the population near the player's rank tier, fixed for the week
static func group_ids(wid: int, tier: int) -> Array:
	var r: = U.rng(wid, "pagoda_group|%s|%d" % [_pid(), tier])
	var same: = []
	var near: = []
	var far: = []
	for p in V8Population.all():
		var d: = absi(int(p.tier) - tier)
		if d == 0:
			same.append(int(p.id))
		elif d == 1:
			near.append(int(p.id))
		else:
			far.append(int(p.id))
	U.shuffle(same, r)
	U.shuffle(near, r)
	U.shuffle(far, r)
	var out: = same.slice(0, mini(same.size(), 18))
	out.append_array(near.slice(0, mini(near.size(), GROUP - 1 - out.size())))
	if out.size() < GROUP - 1:
		out.append_array(far.slice(0, GROUP - 1 - out.size()))
	return out

# One AI climber's week: the final result (floors, heat) and how much of it is reached by time t.
static func ai_week(id: int, wid: int, t: int) -> Dictionary:
	var p: = V8Population.get_p(id)
	var r: = U.rng(id, "pagoda_week|%d" % wid)
	var skill: = clampf(float(p.skill) * 0.7 + float(p.tier) / 5.0 * 0.3, 0.0, 1.0)
	var active: = r.randf() < 0.55 + 0.4 * skill
	var heat: = 0
	if skill > 0.35:
		heat = int(round(lerpf(0.0, 24.0, pow((skill - 0.35) / 0.65, 1.3)) * r.randf_range(0.6, 1.2)))
		heat = clampi(heat, 0, M.heat_max())
	var floors: = int(round(lerpf(4.0, 26.0, pow(skill, 1.1)) * r.randf_range(0.75, 1.25) - heat * 0.25))
	floors = maxi(1, floors)
	# progress through the week: a few runs, the best grows in steps; earlier for eager players
	var start_frac: = r.randf_range(0.0, 0.55)
	var runs: = r.randi_range(1, 5)
	var frac: = clampf(float(t - U.week_start(wid)) / float(U.WEEK), 0.0, 1.0)
	var reached: = 0
	if active and frac >= start_frac:
		var k: = int(floor((frac - start_frac) / maxf(0.0001, 1.0 - start_frac) * runs)) + 1
		k = mini(k, runs)
		reached = int(round(float(floors) * (0.55 + 0.45 * float(k) / float(runs))))
	return {"floors": reached, "heat": heat if reached > 0 else 0, "final": floors, "active": active}

static func pagoda_week(t: = -1, my: = {}) -> Array:
	if t < 0:
		t = U.now_utc()
	var wid: = U.week_id(t)
	var tier: = _my_tier()
	var rows: = []
	for id in group_ids(wid, tier):
		var w: = ai_week(id, wid, t)
		if int(w.floors) <= 0:
			continue
		var p: = V8Population.get_p(id)
		rows.append({"pid": id, "name": String(p.nick), "hero": String(p.hero), "avatar": String(p.avatar),
			"floors": int(w.floors), "heat": int(w.heat), "score": int(round(float(w.floors) * M.mult(int(w.heat)) * 100.0)),
			"tier": int(p.tier), "me": false, "ai_label": SIM_LABEL_TEXT if SIM_LABEL else ""})
	var mine: = my if not my.is_empty() else _my_pagoda(wid)
	rows.append(mine)
	rows.sort_custom(_by_score)
	return rows

static func _my_pagoda(wid: int) -> Dictionary:
	var S = load("res://scripts/v10/tower/pagoda.gd")
	var d: Dictionary = S.st()
	var wk: Dictionary = d.week
	var sc: = int(wk.score) if int(wk.id) == wid else 0
	var fl: = int(wk.floors) if int(wk.id) == wid else 0
	return {"pid": -1, "name": String(G.nick()) if G.has_method("nick") else "Ты", "hero": String(G.S.get("level_partner", "mc")),
		"avatar": "", "floors": fl, "heat": 0, "score": sc, "tier": _my_tier(), "me": true, "ai_label": ""}

static func _by_score(a: Dictionary, b: Dictionary) -> bool:
	if int(a.score) == int(b.score):
		if bool(a.me) != bool(b.me):
			return bool(a.me)
		return int(a.pid) < int(b.pid)
	return int(a.score) > int(b.score)

static func place_of(rows: Array) -> int:
	for i in rows.size():
		if bool(rows[i].me):
			return i + 1
	return rows.size()

# ---------------------------------------------------------------- goddesses

const RANK_SKILL: = {"A": 0.55, "S": 0.7, "SSR": 0.85}
# a little personality: who climbs hot (high heat), who climbs far
const STYLE: = {"mc": [0.1, 1.0], "rin": [0.6, 0.9], "hana": [0.2, 1.2], "yue": [0.9, 0.8], "nova": [0.5, 1.1],
	"tsubame": [0.7, 1.0], "miel": [0.1, 1.1], "lian": [0.4, 0.9], "jess": [0.3, 1.1], "tsuru": [0.5, 0.9],
	"kohaku": [0.8, 1.0], "shirin": [0.4, 1.0], "mari": [0.7, 1.1], "hibana": [0.9, 1.0], "nemi": [0.3, 1.0],
	"zlata": [1.0, 0.9], "minamo": [0.5, 1.0], "kira": [0.8, 1.2], "vesper": [1.0, 1.0], "sigrid": [0.6, 1.1]}

# «Рекорды героинь»: per goddess the best floor at heat 0 and her hottest record; grows a little each week.
static func heroine_records(t: = -1, all_roster: = false) -> Array:
	if t < 0:
		t = U.now_utc()
	var wid: = U.week_id(t)
	var ids: Array = U.ROSTER if all_roster else U.released()
	var rows: = []
	for h in ids:
		var sk: float = RANK_SKILL.get(String(U.ROSTER_RANK.get(h, "A")), 0.55)
		var st: Array = STYLE.get(h, [0.5, 1.0])
		var r: = U.rng(hash(String(h)), "heroine_rec")
		var grow: = clampf(float(posmod(wid, 520)) / 52.0, 0.0, 10.0)
		var f0: = int(round((10.0 + 14.0 * sk) * float(st[1]) * r.randf_range(0.9, 1.1) + grow * 0.6))
		var hh: = clampi(int(round(6.0 + 22.0 * float(st[0]) * sk + grow * 0.4)), 0, M.heat_max())
		var fh: = maxi(5, int(round(float(f0) * (1.0 - hh / 60.0))))
		rows.append({"hero": String(h), "name": U.hero_name(String(h)), "rank": String(U.ROSTER_RANK.get(h, "A")),
			"floors0": f0, "heat": hh, "floors_heat": fh, "score": int(round(float(fh) * M.mult(hh) * 100.0)),
			"ai_label": HEROINE_LABEL})
	rows.sort_custom(func(a, b): return int(a.score) > int(b.score) or (int(a.score) == int(b.score) and String(a.hero) < String(b.hero)))
	return rows

# Странствие: the goddesses' runs of this week (same seed for everyone) and the player's best
static func journey_week(wid: int, my_best: int, t: = -1) -> Array:
	if t < 0:
		t = U.now_utc()
	var frac: = clampf(float(t - U.week_start(wid)) / float(U.WEEK), 0.0, 1.0)
	var rows: = []
	for h in U.released():
		var sk: float = RANK_SKILL.get(String(U.ROSTER_RANK.get(h, "A")), 0.55)
		var r: = U.rng(wid, "journey_heroine|%s" % h)
		var final: = int(round((5200.0 + 6800.0 * sk) * r.randf_range(0.8, 1.15) / 10.0) * 10)
		var at: = r.randf_range(0.05, 0.6)
		if frac < at:
			continue
		var second: = r.randf() < 0.6 and frac >= at + 0.25
		var sc: = final if second else int(round(final * r.randf_range(0.7, 0.95) / 10.0) * 10)
		rows.append({"hero": String(h), "name": U.hero_name(String(h)), "score": sc, "me": false, "ai_label": HEROINE_LABEL})
	rows.append({"hero": String(G.S.get("level_partner", "mc")), "name": "Ты", "score": my_best, "me": true, "ai_label": ""})
	rows.sort_custom(func(a, b):
		if int(a.score) == int(b.score):
			return bool(a.me)
		return int(a.score) > int(b.score))
	return rows
