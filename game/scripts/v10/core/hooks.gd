extends Node

# V10Hooks — autoload (project.godot [autoload] V10Hooks="*res://scripts/v10/core/hooks.gd", after V7Event).
# The integration bus of 0.10 (docs/0.10-spec.md §2.8, docs/INTEGRATION_0.10.md §3.8): the hot files (play.gd,
# home.gd, summon.gd, main.gd, mode_play.gd, event_play.gd, daily.gd) emit here ONCE; modules connect to the
# signals instead of editing those files.
#
#   game_ended(result) — MODES §7.1 schema: {mode, win, score, stars, time_s, pairs, hero, seed, level, rewards}
#   pair_taken(info)   — {mid, combo, gold, shard, face, mode, partner}
#   screen_shown(id, screen) — main.go() after the screen's build() (music, tutorial, transitions)
#
# No class_name: the autoload name IS the global (a class_name of the same name would clash).

signal pair_taken(info: Dictionary)
signal game_started(cfg: Dictionary)
signal game_ended(result: Dictionary)
signal win_screen(ctx: Dictionary)
signal home_built(home: Node)
signal summon_built(sc: Node)
signal app_resumed
signal app_paused
signal screen_shown(id: String, screen: Node)

# counters (selftests and the playtest read them; never saved)
var counts: = {}
var last: = {}
var mastery: = V10Mastery.new()


func _bump(sig: String, payload = null) -> void:
	counts[sig] = int(counts.get(sig, 0)) + 1
	last[sig] = payload


func emit_pair_taken(info: Dictionary) -> void:
	_bump("pair_taken", info)
	pair_taken.emit(info)


func emit_game_started(cfg: Dictionary) -> void:
	_bump("game_started", cfg)
	game_started.emit(cfg)


# result keys missing from a caller are filled with neutral values, so a module can read any of them
func emit_game_ended(result: Dictionary) -> void:
	var r: = {"mode": "path", "win": false, "score": 0, "stars": 0, "time_s": 0.0, "pairs": 0, "hero": "", "seed": 0,
		"level": -1, "rewards": {}}
	r.merge(result, true)
	_bump("game_ended", r)
	game_ended.emit(r)


func emit_win_screen(ctx: Dictionary) -> void:
	_bump("win_screen", ctx)
	win_screen.emit(ctx)


func emit_home_built(home: Node) -> void:
	_bump("home_built")
	home_built.emit(home)


func emit_summon_built(sc: Node) -> void:
	_bump("summon_built")
	summon_built.emit(sc)


func emit_app_resumed() -> void:
	_bump("app_resumed")
	app_resumed.emit()


func emit_app_paused() -> void:
	_bump("app_paused")
	app_paused.emit()


func emit_screen_shown(id: String, screen: Node) -> void:
	_bump("screen_shown", id)
	screen_shown.emit(id, screen)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# economy: the clock skips the sleep, then the day's grants and store receipts are caught up; pause = save now
	app_resumed.connect(func() -> void:
		V10Money.on_resumed()
		if V10Registry.wired("phone"):
			V10Phone.tick())
	app_paused.connect(func() -> void:
		var g = get_node_or_null("/root/G")
		if g and g.has_method("save"):
			g.save())
	pair_taken.connect(func(info: Dictionary) -> void:
		if not V10Registry.wired("gacha") or str(info.get("mode", "")) == "trial":
			return
		var pt: = str(info.get("partner", G.S.get("partner", "mc")))
		var oid: = str(G.S.get("outfit", {}).get(pt, ""))
		if oid != "" and oid != "o_base":
			mastery.on_pair(oid, V10Comeback.rested() > 0, 1))
	game_ended.connect(func(r: Dictionary) -> void:
		V10Afisha.on_game_ended(r)
		if V10Registry.wired("salon") and int(r.get("stars_delta", 0)) > 0:
			V10Salon.notify_stars(int(r.stars_delta))
		if V10Registry.wired("gacha"):
			var ups: = mastery.flush(G.S, func(o: String) -> String: return V10Gacha2.rar10(str(G.ITEM.get(o, {}).get("rar", "R"))))
			if not ups.is_empty():
				G.save()
				var og = load("res://scripts/v10/gacha/ui/outfit_growth.gd")
				var main = get_tree().current_scene
				for u in ups:
					if main == null or og == null:
						break
					var to_lv: = int(u.get("to", 1))
					var oid2: = str(u.get("outfit", ""))
					if to_lv <= 1:
						if main.has_method("toast"):
							main.toast(og.toast_text(oid2, 1), "star")
					elif main.get("overlay") != null:
						og.mastery_up(main.overlay, oid2, to_lv, func():
							if is_instance_valid(main) and main.has_method("go"):
								main.go("collection", {"item": oid2}))
		if V10Registry.wired("profile"):
			var feats_sc = load("res://scripts/v10/profile/feats.gd")
			var pcos_sc = load("res://scripts/v10/profile/cosmetics.gd")
			if feats_sc:
				feats_sc.best(G.S, "best_combo", int(r.get("max_combo", 0)))
				if bool(r.get("win", false)):
					if bool(r.get("clean", false)):
						feats_sc.bump(G.S, "clean", 1)
					if int(r.get("dragons", 0)) > 0:
						feats_sc.bump(G.S, "dragons", int(r.dragons))
					if str(r.get("mode", "")) == "daily":
						feats_sc.bump(G.S, "daily_done", 1)
					if str(r.get("mode", "")) in ["duel", "duel_ranked"]:
						feats_sc.bump(G.S, "duel_wins", 1)
			if pcos_sc:
				var pctx: Dictionary = pcos_sc.ctx_from_save(G.S)
				var new_ids: Array = pcos_sc.unseen(G.S, pctx)
				var main_sc = get_tree().current_scene
				for cid in new_ids:
					var ce: Dictionary = pcos_sc.entry(str(cid))
					if str(ce.get("kind", "")) == "title":
						pcos_sc.mark_seen(G.S, str(cid))
						if main_sc and main_sc.has_method("toast"):
							main_sc.toast("Новый титул: «%s»" % str(ce.get("name", "")), "star")
							break
		if V10Registry.wired("phone") and bool(r.get("win", false)):
			if bool(r.get("first_win_day", false)):
				V10Phone.event({"kind": "first_win"})
			if bool(r.get("combo_rec", false)):
				V10Phone.event({"kind": "combo_record", "combo": int(r.get("max_combo", 0))})
			if bool(r.get("rank_up", false)):
				V10Phone.event({"kind": "rank_up", "rank": str(r.get("rank_title", ""))})
	)
	V10Meta.bus().day_rolled.connect(func(_old: String, _new: String) -> void:
		if V10Registry.wired("phone"):
			V10Phone.tick())
	# W4 audio: route screen changes to V10Music (0.4s crossfade, stops legacy Sfx.music automatically)
	screen_shown.connect(func(id: String, _sc: Node) -> void:
		if not V10Registry.wired("audio"):
			return
		var trk: = _music_screen_for(id)
		if trk != "":
			V10Music.play_screen(trk))
	# meta: at most one full-screen entry scene per launch, offered by the modules, run when the tea house is up
	home_built.connect(func(_h: Node) -> void: V10EntryQueue.run())
	# the W1+W2 shell: Afisha providers, MoreLevel codes, WinStack salon bar + streak/flame/daily ticks
	V10Nav.install()
	# Salon win bar intentionally disabled from Victory overlay to keep post-match screen clean
	if V10Registry.wired("rituals"):
		V10WinStack.add_tick("streak", func(_c: Dictionary) -> Dictionary:
			var n: = int(V10Streak.st().get("n", 0))
			return {"icon": "visits", "text": "Серия · %d" % n} if n > 0 else {}, {"order": 0})
	if V10Registry.wired("path"):
		V10WinStack.add_tick("flame", func(_c: Dictionary) -> Dictionary:
			var fl: = V10PathBoosters.flame()
			return {"icon": "star", "text": "Огонёк · %d" % fl} if fl > 0 and int(G.S.get("unlocked", 1)) >= V10PathRules.BOOST_FROM else {},
			{"order": 1, "modes": ["path"]})
		V10WinStack.add_tick("path15", func(_c: Dictionary) -> Dictionary:
			var d: = V10PathState.daily()
			return {"icon": "gem", "text": "Награда · %d/%d" % [int(d.n), V10PathRules.DAILY_FULL]} if bool(d.show) else {},
			{"order": 2, "modes": ["path"]})
	if V10Registry.wired("gacha"):
		V10WinStack.add_bar("mastery", V10WinStack.PRIO_MASTERY, func(_c: Dictionary, w: float):
			var pt: = str(G.S.get("level_partner", G.S.get("partner", "mc")))
			var oid: = str(G.S.get("outfit", {}).get(pt, ""))
			if oid == "" or oid == "o_base" or not G.ITEM.has(oid):
				return null
			var it: Dictionary = G.ITEM[oid]
			var pts: = V10Mastery.points(G.S, oid)
			if pts <= 0:
				return null
			var pr: = V10Mastery.progress(pts, V10Gacha2.rar10(str(it.get("rar", "R"))))
			if int(pr.lv) >= V10Mastery.max_level(V10Gacha2.rar10(str(it.get("rar", "R")))):
				return null
			return V10WinBar.make(w, {"icon": "wardrobe", "title": "Мастерство · %s" % str(it.name),
				"have": int(pr.cur), "need": int(pr.need), "gain": 0, "kind": "fill", "pal": "lav"}))
	if V10Registry.wired("shop"):
		V10WinStack.add_bar("pass", V10WinStack.PRIO_PASS, func(_c: Dictionary, w: float):
			if int(G.S.get("unlocked", 1)) < 21 or G.econ == null:
				return null
			var ps: V10Pass = (G.econ as V10Econ).pass_
			if ps.tier() >= V10Catalog.PASS_TIERS:
				return null
			return V10WinBar.make(w, {"icon": "star", "title": "Сезон · ступень %d" % ps.tier(),
				"have": int(ps.st.get("xp", 0)) % V10Catalog.PASS_XP_TIER, "need": V10Catalog.PASS_XP_TIER,
				"gain": 0, "kind": "fill", "pal": "gold"}))


const MODE_GEMS_DAILY_CAP: = 400
const _MUSIC_MAP: = {
	"home": "home", "profile": "home",
	"v10path": "path", "levels": "path", "tables": "path", "modes": "path", "journey": "path",
	"play": "play", "arena": "play", "v7play": "play", "tower_play": "play", "challenge_play": "play", "hand": "play",
	"mj_classic": "play", "mj_classic_lobby": "play", "mj_memory": "play", "mj_triples": "play", "mj_connect": "play",
	"mj_cube": "play", "mj_garden": "play", "mj_bridge": "play", "mj_bridge_daily": "play", "mj_bridge_hand": "play",
	"mj_riichi": "play", "mj_sanma": "play", "mj_koikoi": "play",
	"pagoda": "pagoda",
	"duels": "duels", "duel2": "duels", "challenge": "duels", "v7tourney": "duels", "v7event": "duels",
	"summon": "summon", "odds": "summon",
	"shop": "shop", "v10pass": "shop",
	"v10salon": "salon", "collection": "salon", "room": "salon",
	"v10phone": "phone", "letters": "phone",
}
const _MODE_SCREEN: = {
	"classic": "mj_classic", "memory": "mj_memory", "triples": "mj_triples", "connect": "mj_connect",
	"cube": "mj_cube", "garden": "mj_garden", "bridge_daily": "mj_bridge_daily", "bridge_hand": "mj_bridge_hand",
	"riichi": "mj_riichi", "sanma": "mj_sanma", "koikoi": "mj_koikoi",
	"hand": "hand", "palm": "hand", "pagoda": "pagoda", "journey": "journey", "duels": "duels", "challenge": "challenge",
}


static func _music_screen_for(id: String) -> String:
	return String(_MUSIC_MAP.get(id, ""))


static func _screen_for_mode(mode: String) -> String:
	if _MODE_SCREEN.has(mode):
		return String(_MODE_SCREEN[mode])
	return "mj_" + mode if mode != "" else "tables"


static func _mode_gems_allow(want: int) -> int:
	if want <= 0:
		return 0
	var meta: Dictionary = V10Meta.st()
	var dk: = V10Meta.day_key()
	var cap: Dictionary = meta.get("mode_gems", {}) if meta.get("mode_gems") is Dictionary else {}
	if String(cap.get("day", "")) != dk:
		cap = {"day": dk, "got": 0}
	var left: = maxi(0, MODE_GEMS_DAILY_CAP - int(cap.get("got", 0)))
	var give: = mini(want, left)
	cap["got"] = int(cap.get("got", 0)) + give
	meta["mode_gems"] = cap
	return give


func handle_mode_finished(main, res: Dictionary) -> void:
	var mode: = String(res.get("mode", ""))
	var rw: Dictionary = res.get("rewards", {}) if res.get("rewards") is Dictionary else {}
	var reason: = "mj_" + (mode if mode != "" else "mode")
	var cur: = {}
	if not bool(res.get("rewards_paid", false)):
		for k in ["coins", "petals", "tickets"]:
			if int(rw.get(k, 0)) > 0:
				cur[k] = int(rw[k])
		var gems: = _mode_gems_allow(int(rw.get("gems", 0)))
		if gems > 0:
			cur["gems"] = gems
		if not cur.is_empty():
			V10Money.grant(cur, reason)
		var aff: = int(rw.get("aff", 0))
		var hero: = String(res.get("hero", ""))
		if aff > 0 and hero != "":
			V10Bond.gain(hero, aff, "mode_win")
	if mode == "riichi":
		var rs: Dictionary = G.S.get("v10_mj_riichi", {}) if G.S.get("v10_mj_riichi") is Dictionary else {}
		rs["games"] = int(rs.get("games", 0)) + 1
		G.S["v10_mj_riichi"] = rs
	for ev in res.get("events", []):
		emit_salon_event(G.S, ev)
	emit_game_ended(res)
	G.save()
	if main == null or not is_instance_valid(main) or not main.has_method("go"):
		return
	var act: = String(res.get("action", "exit"))
	var scr: = _screen_for_mode(mode)
	if act == "next":
		main.go(scr, {"level": int(res.get("level", 1)) + 1, "hero": String(res.get("hero", ""))})
	elif act == "again" or act == "retry":
		main.go(scr, {"level": int(res.get("level", 1)), "hero": String(res.get("hero", "")), "retry": randi()})
	elif scr == "mj_classic" or scr == "mj_memory":
		main.go("mj_classic_lobby", {})
	else:
		main.go("tables", {})


static func emit_salon_event(S: Dictionary, ev) -> void:
	if S == null or not (S is Dictionary):
		return
	var log: Array = S.get("v10_salon_events", []) if S.get("v10_salon_events") is Array else []
	var id: = String(ev.get("id", "")) if ev is Dictionary else String(ev)
	if id != "" and not (id in log):
		log.append(id)
		S["v10_salon_events"] = log
