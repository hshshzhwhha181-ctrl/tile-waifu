class_name V10Profile2Selftest
extends RefCounted

# --profile2_selftest=1 (docs/0.10-spec.md §D5/§D6): catalog, unlock logic, selection, payload and card build.
# Pure: works on seeded fake saves, never reads or writes G.S (G is only used for its constant tables).
#   V10Profile2Selftest.run(root) -> [ok, total]     root: a node to build card views under (may be null)
# Standalone runner: res://scripts/v10/profile/profile2_selftest.tscn (see README).

static var ok: = 0
static var total: = 0
static var fails: = []


static func check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)
		print("  FAIL ", what)


# ---- fixture saves ---------------------------------------------------------------------------------------------

static func save_fresh() -> Dictionary:
	return {"rp": 0, "owned": {"o_base": true, "s_sakura": true, "s_mint": true}, "shards": {}, "aff": {"mc": 120},
		"stats": {}, "profile": {"nick": "Новичок", "avatar": "mc", "frame": "", "created": 0, "id": "00000001"},
		"partner": "mc", "outfit": {"mc": "o_base"}, "skin": "s_sakura"}


# rank Золото (tier 3), rin + yue unlocked, a few outfits, streak 30, 12 summits, arc 1 done
static func save_mid() -> Dictionary:
	var s: = save_fresh()
	s.rp = 0
	for t in 3:
		s.rp += int(G.RANKS[t].per) * 3
	s.rp += 10
	s.owned.merge({"r_base": true, "r_idol": true, "y_base": true, "y_queen": true, "b_palace": true, "o_dragon": true}, true)
	s.shards = {"rin": 5, "yue": 5, "hana": 2}
	s.aff = {"mc": 950, "rin": 300}
	s.stats = {"path": {"games": 140, "wins": 120, "rp": 0}, "duel": {"games": 30, "wins": 12, "rp": 0}}
	s.v10_streak = {"best": 31}
	s.v10_levels = {"summits": 12, "arcs_done": {"1": true}, "legend": {"1": {"won": true, "bypass": true}}}
	s.v10_seasons = {"1": 3}
	s.v10_feats = {"stats": {"best_combo": 11, "clean": 14, "dragons": 2}}
	s.ostars = {"r_idol": 5}
	s.profile.nick = "Чайный_Дракон"
	return s


static func run(root: Node = null) -> Array:
	ok = 0
	total = 0
	fails.clear()
	_catalog()
	_unlocks()
	_selection()
	_payload()
	_sim()
	_feats()
	if root != null:
		_views(root)
	print("PROFILE2_SELFTEST %d/%d" % [ok, total])
	return [ok, total]


static func _catalog() -> void:
	var errs: = V10ProfileCos.validate_all()
	for e in errs:
		print("  catalog: ", e)
	check(errs.is_empty(), "catalog validates (%d errors)" % errs.size())
	var all: = V10ProfileCos.all("", true)
	var n: = {"frame": 0, "title": 0, "badge": 0, "bg": 0}
	for e in all:
		n[e.kind] += 1
	check(n.frame >= 40, "≥40 frames (%d)" % n.frame)
	check(n.title >= 28, "≥28 titles (%d)" % n.title)
	check(n.badge >= 20, "≥20 badges (%d)" % n.badge)
	check(n.bg >= 8, "≥8 card backgrounds (%d)" % n.bg)
	var tex_ok: = true
	for e in all:
		match String(e.kind):
			"badge":
				if not V8Art.has(String(e.icon)):
					tex_ok = false
					print("  no icon ", e.id)
			"bg":
				if not ResourceLoader.exists(String(e.tex)):
					tex_ok = false
					print("  no bg ", e.id)
	check(tex_ok, "every badge icon / background texture exists")
	check(V8Art.has("frame/avatar") and V8Art.has("frame/avatar_top"), "frame base textures exist")
	var sold_ok: = true
	var shop_frames: = 0
	for e in all:
		if e.kind in ["title", "badge"] and (int(e.get("price", 0)) > 0 or String(e.src.type) in ["shop", "pass"]):
			sold_ok = false
		if String(e.src.type) == "shop":
			shop_frames += 1
	check(sold_ok, "titles and badges are never sold")
	check(shop_frames == 4, "exactly 4 Lavka frames (%d)" % shop_frames)
	var hints_ok: = true
	for e in all:
		if V10ProfileCos.hint(String(e.id)) == "":
			hints_ok = false
			print("  no hint ", e.id)
	check(hints_ok, "every cosmetic has an unlock hint (source)")
	# hidden SSR goddesses stay out of the released catalog
	var vis: = V10ProfileCos.all("frame")
	check(vis.filter(func(e): return String(e.get("hero", "")) == "zlata").is_empty(), "unreleased goddess frame hidden")
	check(V10ProfileCos.has("fr_g_zlata", "frame"), "unreleased goddess frame is registered")
	# register(): other modules add their own; bad / sold titles refused
	check(V10ProfileCos.register({"id": "fr_test_pagoda", "kind": "frame", "name": "Тест", "tier": "S", "src": {"type": "grant", "event": "pagoda"}, "look": {"base": "ring"}}) == "", "register a grant frame")
	check(V10ProfileCos.register({"id": "fr_test_pagoda", "kind": "frame", "name": "Тест", "tier": "S", "src": {"type": "grant"}, "look": {"base": "ring"}}) != "", "duplicate id refused")
	check(V10ProfileCos.register({"id": "t_test_sold", "kind": "title", "name": "Куплен", "tier": "S", "src": {"type": "shop", "price": 300}, "price": 300}) != "", "sold title refused")
	check(V10ProfileCos.register({"id": "fr_test_cheap", "kind": "frame", "name": "x", "tier": "A", "src": {"type": "shop", "price": 123}, "price": 123, "look": {"base": "ring"}}) != "", "off-ladder shop price refused")


static func _unlocks() -> void:
	var c0: = V10ProfileCos.ctx_from_save(save_fresh())
	var fr0: = V10ProfileCos.unlocked("frame", c0)
	check("fr_default" in fr0 and "fr_rank_0" in fr0 and "fr_g_mc" in fr0, "fresh: default, Бамбук, Пять ветров")
	check(not ("fr_rank_1" in fr0) and not ("fr_g_rin" in fr0), "fresh: no Нефрит, no Рин frame")
	check(V10ProfileCos.unlocked("badge", c0).is_empty(), "fresh: no badges")
	check(V10ProfileCos.unlocked("title", c0).size() == 2, "fresh: Гость салона + Бамбуковый росток (%s)" % str(V10ProfileCos.unlocked("title", c0)))
	var c1: = V10ProfileCos.ctx_from_save(save_mid())
	check(int(c1.rank_tier) == 3, "mid: rank tier 3 (%d)" % int(c1.rank_tier))
	for t in 4:
		check(V10ProfileCos.is_unlocked("fr_rank_%d" % t, c1), "mid: rank frame %d" % t)
	check(not V10ProfileCos.is_unlocked("fr_rank_4", c1), "mid: no Дракон frame")
	check(V10ProfileCos.is_unlocked("fr_s1_3", c1) and not V10ProfileCos.is_unlocked("fr_s1_4", c1), "mid: season 1 gold, not dragon")
	check(V10ProfileCos.is_unlocked("fr_g_rin", c1) and V10ProfileCos.is_unlocked("fr_g_yue", c1) and not V10ProfileCos.is_unlocked("fr_g_hana", c1), "mid: goddess frames follow unlocked heroines")
	check(V10ProfileCos.is_unlocked("fr_rise_1", c1) and not V10ProfileCos.is_unlocked("fr_rise_2", c1), "mid: Восходящая I at 12 summits, not II")
	check(V10ProfileCos.is_unlocked("fr_tea_1", c1) and not V10ProfileCos.is_unlocked("fr_tea_2", c1), "mid: Чайный мастер I at 31 days")
	check(V10ProfileCos.is_unlocked("fr_laurel_1", c1), "mid: arc 1 laurel")
	check(not V10ProfileCos.is_unlocked("fr_legend_1", c1) and not V10ProfileCos.is_unlocked("t_legend", c1), "mid: bypass legend gives no laurel")
	check(V10ProfileCos.is_unlocked("t_combo", c1) and not V10ProfileCos.is_unlocked("t_combo15", c1), "mid: Мастер комбо, not Буря пар")
	check(V10ProfileCos.is_unlocked("t_star_rin", c1) and not V10ProfileCos.is_unlocked("t_star_mc", c1), "mid: ★5 Рин title")
	check(V10ProfileCos.is_unlocked("t_heart_mc", c1), "mid: симпатия 10 → Сердце title")
	check(V10ProfileCos.is_unlocked("cb_palace", c1) and V10ProfileCos.is_unlocked("cb_ice", c1) and not V10ProfileCos.is_unlocked("cb_neon", c1), "mid: backgrounds by items / goddess")
	check(V10ProfileCos.is_unlocked("b_first_win", c1) and V10ProfileCos.is_unlocked("b_streak_30", c1) and not V10ProfileCos.is_unlocked("b_streak_100", c1), "mid: badges by feats")
	check(not V10ProfileCos.is_unlocked("fr_shop_jade", c1), "shop frame locked until bought")
	check(not V10ProfileCos.is_unlocked("fr_g_zlata", c1), "unreleased goddess frame never unlocks")
	# grant(): only grant-type sources
	var s: = save_mid()
	check(V10ProfileCos.grant(s, "fr_shop_jade"), "grant shop frame")
	check(not V10ProfileCos.grant(s, "fr_shop_jade"), "grant is idempotent")
	check(not V10ProfileCos.grant(s, "t_combo15"), "a feat title cannot be granted")
	check(not V10ProfileCos.grant(s, "fr_rank_5"), "a rank frame cannot be granted")
	var c2: = V10ProfileCos.ctx_from_save(s)
	check(V10ProfileCos.is_unlocked("fr_shop_jade", c2), "granted shop frame unlocked")
	# unseen / seen for the «новый титул» toast
	var un: = V10ProfileCos.unseen(s, c2)
	check("t_combo" in un and "fr_shop_jade" in un and not ("t_guest" in un), "unseen lists new unlocks, not defaults")
	V10ProfileCos.mark_seen(s, "t_combo")
	check(not ("t_combo" in V10ProfileCos.unseen(s, c2)), "mark_seen hides it")


static func _selection() -> void:
	var s: = save_mid()
	var ctx: = V10ProfileCos.ctx_from_save(s)
	var p: Dictionary = s.profile
	check(V10ProfileCos.select(p, "frame", "fr_rank_4", ctx) != "" and String(p.get("frame", "")) == "", "locked frame refused")
	check(V10ProfileCos.select(p, "frame", "fr_rank_4", ctx) == V10ProfileCos.hint("fr_rank_4"), "refusal says how to unlock")
	check(V10ProfileCos.select(p, "frame", "fr_g_rin", ctx) == "" and p.frame == "fr_g_rin", "unlocked frame applied")
	check(V10ProfileCos.select(p, "frame", "fr_g_zlata", ctx) != "", "unreleased goddess frame refused")
	check(V10ProfileCos.select(p, "frame", "t_combo", ctx) != "", "a title is not a frame")
	check(V10ProfileCos.select(p, "title", "t_combo", ctx) == "", "unlocked title applied")
	check(V10ProfileCos.select(p, "card_bg", "cb_neon", ctx) != "", "locked background refused")
	check(V10ProfileCos.select(p, "badges", ["b_first_win", "b_streak_30", "b_streak_7"], ctx) == "", "3 badges applied")
	check(V10ProfileCos.select(p, "badges", ["b_first_win", "b_streak_30", "b_streak_7", "b_games_100"], ctx) != "", "4 badges refused")
	check(V10ProfileCos.select(p, "badges", ["b_first_win", "b_first_win"], ctx) != "", "duplicate badge refused")
	check(V10ProfileCos.select(p, "badges", ["b_streak_100"], ctx) != "" and p.badges.size() == 3, "locked badge refused, old pick kept")
	check(V10ProfileCos.select(p, "badges", [], ctx) == "", "empty badges allowed")
	check(V10ProfileCos.select(p, "showcase", {"hero": "rin", "outfit": "r_idol"}, ctx) == "", "owned outfit showcase applied")
	check(V10ProfileCos.select(p, "showcase", {"hero": "rin", "outfit": "r_maid"}, ctx) != "", "unowned outfit refused")
	check(V10ProfileCos.select(p, "showcase", {"hero": "rin", "outfit": "y_queen"}, ctx) != "", "other goddess's outfit refused")
	check(V10ProfileCos.select(p, "showcase", {"hero": "hana", "outfit": "h_base"}, ctx) != "", "locked goddess refused")
	# sanitize: legacy 0.8 profile and picks that became locked
	var legacy: = {"nick": "x", "avatar": "mc", "frame": ""}
	check(V10ProfileCos.sanitize(legacy, ctx) and legacy.frame == "fr_default" and legacy.title == "t_guest" and legacy.badges == [], "0.8 profile → defaults")
	var stale: = {"frame": "fr_rank_5", "title": "t_combo", "badges": ["b_rank_5", "b_first_win"], "card_bg": "cb_palace", "showcase": {"hero": "nova", "outfit": "n_ssr"}}
	V10ProfileCos.sanitize(stale, ctx)
	check(stale.frame == "fr_default" and stale.title == "t_combo" and stale.badges == ["b_first_win"] and stale.card_bg == "cb_palace" and stale.showcase.hero == "mc", "sanitize keeps legal picks only")
	check(not V10ProfileCos.sanitize(stale, ctx), "sanitize is idempotent")


static func _payload() -> void:
	var s: = save_mid()
	s.profile.merge({"frame": "fr_g_rin", "title": "t_combo", "badges": ["b_first_win", "b_streak_30"], "card_bg": "cb_ice",
		"showcase": {"hero": "rin", "outfit": "r_idol", "pose": "base"}}, true)
	var p: = V10CardPayload.mine(s, {"league": 3, "games_week": 42})
	check(V10CardPayload.validate(p) == "", "mine() validates (%s)" % V10CardPayload.validate(p))
	check(V10CardPayload.size_bytes(p) <= 2048, "payload ≤ 2 KB (%d)" % V10CardPayload.size_bytes(p))
	check(p.frame == "fr_g_rin" and p.ostars == 5 and int(p.rank.tier) == 3 and int(p.stats.games_week) == 42, "mine() carries picks, Созвездие, rank, games")
	check(not p.has("gems") and not p.has("spent") and not p.has("moon"), "no spending on the card")
	# a save with a locked pick is sanitised before it leaves the phone
	var s2: = save_mid()
	s2.profile.frame = "fr_shop_aurora"
	check(V10CardPayload.mine(s2).frame == "fr_default", "locked pick never reaches the payload")
	var s3: = save_fresh()
	s3.profile.nick = "ОченьДлинныйНик16"
	var p3: = V10CardPayload.mine(s3)
	check(V10CardPayload.validate(p3) == "" and String(p3.nick).length() <= 16, "long nick trimmed to 16")
	var bad: = p.duplicate(true)
	bad.badges = ["b_first_win", "b_first_win"]
	check(V10CardPayload.validate(bad) != "", "duplicate badge invalid")
	bad = p.duplicate(true)
	bad.frame = "fr_nope"
	check(V10CardPayload.validate(bad) != "", "unknown frame invalid")
	bad = p.duplicate(true)
	bad.showcase = {"hero": "rin", "outfit": "o_dragon", "pose": "base"}
	check(V10CardPayload.validate(bad) != "", "showcase outfit of another goddess invalid")
	bad = p.duplicate(true)
	bad.nick = "x".repeat(40)
	check(V10CardPayload.validate(bad) != "", "nick > 16 invalid")
	bad = p.duplicate(true)
	bad["junk"] = "z".repeat(2100)
	check(V10CardPayload.validate(bad) == "too big", "oversize payload invalid")
	bad = p.duplicate(true)
	bad.frame = "fr_g_zlata"
	check(V10CardPayload.validate(bad) != "", "unreleased goddess frame invalid")
	check(V10CardPayload.validate("x") != "" and V10CardPayload.validate({}) != "", "garbage invalid")


static func _sim() -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = 42
	var all_ok: = true
	var ssr: = 0
	var paid: = 0
	var t0: = Time.get_ticks_usec()
	for i in 1000:
		var p: = V10CardPayload.sim(rng, i % 6)
		if V10CardPayload.validate(p) != "":
			all_ok = false
			if all_ok == false and i < 3:
				print("  sim invalid: ", V10CardPayload.validate(p))
		if V10ProfileCos.outfit_rar(String(p.showcase.outfit)) == "SSR" or String(V10ProfileCos.ROSTER[String(p.showcase.hero)][2]) == "SSR":
			ssr += 1
		for id in [p.frame, p.title, p.card_bg] + Array(p.badges):
			var e: = V10ProfileCos.entry(String(id))
			if String(e.src.type) in ["shop", "pass"] or String(e.tier) == "SSR" and String(e.kind) == "frame" and String(e.src.type) != "rank":
				paid += 1
	check(all_ok, "1000 sim cards validate")
	check(ssr == 0, "no SSR goddess / outfit on sim cards (%d)" % ssr)
	check(paid == 0, "no paid or SSR-goddess frames on sim cards (%d)" % paid)
	print("  1000 sim cards in %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var rng2: = RandomNumberGenerator.new()
	rng2.seed = 42
	check(V10CardPayload.sim(rng2, 0) == V10CardPayload.sim(_seeded(42), 0), "sim is deterministic per seed")


static func _seeded(sd: int) -> RandomNumberGenerator:
	var r: = RandomNumberGenerator.new()
	r.seed = sd
	return r


static func _feats() -> void:
	check(V10Feats.FEATS.size() == 40, "40 feats (%d)" % V10Feats.FEATS.size())
	var ids: = {}
	var stats_ok: = true
	for f in V10Feats.FEATS:
		ids[f.id] = true
		if not (String(f.stat) in V10Feats.STATS):
			stats_ok = false
	check(ids.size() == 40, "feat ids unique")
	check(stats_ok, "every feat reads a known counter")
	var ctx: = V10ProfileCos.ctx_from_save(save_mid())
	check(V10Feats.done("f_wins_100", ctx) and not V10Feats.done("f_wins_500", ctx), "feats on the seeded save (wins 132)")
	check(V10Feats.progress("f_combo_15", ctx) == [11, 15], "progress [11, 15]")
	var s: = save_fresh()
	V10Feats.bump(s, "clean", 3)
	V10Feats.bump(s, "clean")
	V10Feats.best(s, "best_combo", 9)
	V10Feats.best(s, "best_combo", 4)
	check(int(s.v10_feats.stats.clean) == 4 and int(s.v10_feats.stats.best_combo) == 9, "bump / best counters")


static func _views(root: Node) -> void:
	var s: = save_mid()
	s.profile.merge({"frame": "fr_g_rin", "title": "t_combo", "badges": ["b_first_win", "b_streak_30", "b_heart"], "card_bg": "cb_ice",
		"showcase": {"hero": "rin", "outfit": "r_idol", "pose": "base"}}, true)
	var p: = V10CardPayload.mine(s, {"league": 3, "games_week": 42})
	var aff_before: = JSON.stringify(G.S.get("aff", {}))
	var other: = V10CardView.make(p, Rect2(0, 0, 0, 0), "other")
	root.add_child(other)
	check(other.size == Vector2(660, 880), "other card 660×880")
	check(other.badge_nodes.size() == 3, "3 badge medallions")
	check(other.frame_view != null and other.frame_view.frame_id == "fr_g_rin", "avatar frame built")
	var fired: = [""]
	other.showcase_tapped.connect(func(h): fired[0] = h)
	other._on_showcase()
	check(fired[0] == "rin", "showcase tap → showcase_tapped(rin)")
	check(JSON.stringify(G.S.get("aff", {})) == aff_before, "showcase tap does not change affection")
	var own: = V10CardView.make(p, Rect2(0, 0, 0, 0), "own")
	root.add_child(own)
	check(own.size == Vector2(672, 560) and own.get_node_or_null("EditButton") != null, "own card 672×560 with «Оформить карточку»")
	var edit: = [false]
	own.edit_requested.connect(func(): edit[0] = true)
	(own.get_node("EditButton") as JButton).pressed.emit()
	check(edit[0], "edit_requested fires")
	var lp: = p.duplicate(true)
	lp.nick = "Ш".repeat(16)
	var lc: = V10CardView.make(lp, Rect2(0, 0, 0, 0), "other")
	root.add_child(lc)
	check(lc.nick_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS and lc.nick_label.clip_text, "long nick ellipsised")
	var poster: = V10CardView.make(p, Rect2(0, 0, 330, 440), "poster")
	root.add_child(poster)
	check(is_equal_approx(poster.scale.x, 0.5) and not poster.interactive and not poster.anim, "poster scaled, static, no taps")
	# league rows: static frame, 50 rows build time
	var rng: = _seeded(5)
	var t0: = Time.get_ticks_usec()
	var rows: = []
	for i in 50:
		var rp: = V10CardPayload.sim(rng, i % 6)
		rp["pts"] = 2000 - i * 17
		var r: = V10CardView.make(rp, Rect2(0, i * 84, 680, 84), "row")
		root.add_child(r)
		rows.append(r)
	var ms: = (Time.get_ticks_usec() - t0) / 1000.0
	print("  50 league rows built in %.1f ms" % ms)
	check(rows.all(func(r): return not r.frame_view.anim and not r.frame_view.is_processing()), "row frames are static")
	check(ms < 400.0, "50 rows build < 400 ms headless (%.1f)" % ms)
	for n in [other, own, lc, poster] + rows:
		n.queue_free()
	_editor(root)


static func _editor(root: Node) -> void:
	var host: = Control.new()
	host.size = Vector2(720, 1280)
	root.add_child(host)
	var s: = save_mid()
	s.profile.merge({"frame": "fr_g_rin", "title": "t_combo"}, true)
	var ed: = V10CardEditor.open(host, s)
	check(ed.work.frame == "fr_g_rin" and ed.preview != null, "editor opens on the current picks with a preview")
	ed._set_tab("frame")
	var cells: = ed.grid.get_children()
	check(cells.size() == V10ProfileCos.all("frame").size(), "editor lists every released frame (%d)" % cells.size())
	ed._tap({"id": "fr_rank_5", "ok": false, "sel": false, "new": false}, cells[0])
	check(ed.work.frame == "fr_g_rin" and ed.hint.text == V10ProfileCos.hint("fr_rank_5"), "locked cell: no change, hint shown")
	ed._tap({"id": "fr_rank_2", "ok": true, "sel": false, "new": true}, cells[0])
	check(ed.work.frame == "fr_rank_2" and String(s.profile.frame) == "fr_g_rin", "unlocked cell edits the draft only")
	check(bool(s.get("v10_cos_seen", {}).get("fr_rank_2", false)), "tapped cell marked seen")
	ed._set_tab("badges")
	for b in ["b_first_win", "b_streak_7", "b_streak_30", "b_games_100"]:
		ed._tap({"id": b, "ok": V10ProfileCos.is_unlocked(b, ed.ctx), "sel": false, "new": false}, ed.grid.get_child(0))
	check(ed.work.badges.size() == 3 and not ("b_games_100" in ed.work.badges), "editor caps badges at 3")
	ed._tap({"id": "b_streak_7", "ok": true, "sel": true, "new": false}, ed.grid.get_child(0))
	check(ed.work.badges.size() == 2, "tap on a chosen badge removes it")
	ed._set_tab("showcase")
	ed._tap({"id": "y_queen", "hero": "yue", "ok": true, "sel": false, "new": false}, ed.grid.get_child(0))
	check(ed.work.showcase.outfit == "y_queen" and ed.work.avatar == "yue", "showcase pick follows the goddess")
	ed._finish(true)
	check(s.profile.frame == "fr_rank_2" and s.profile.showcase.outfit == "y_queen" and s.profile.badges.size() == 2, "«Сохранить» writes S.profile")
	var s2: = save_mid()
	var ed2: = V10CardEditor.open(host, s2)
	ed2._tap({"id": "fr_rank_2", "ok": true, "sel": false, "new": false}, ed2.grid.get_child(0))
	ed2._finish(false)
	check(String(s2.profile.get("frame", "")) == "", "«Отмена» leaves the profile alone")
	host.queue_free()
