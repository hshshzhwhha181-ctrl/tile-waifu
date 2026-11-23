class_name V8PlayerCard
extends RefCounted

# Player card popup (tap on a league / quarter row). The same card is shown for the player;
# then it also offers «Открыть профиль» when the profile screen exists.
#   V8PlayerCard.open(main, V8League.card_info(pid, ctx))   or simply V8League.open_card(main, pid, ctx)

const W: = 660.0

static func open(main, info: Dictionary) -> RBox:
	var me: bool = info.get("me", false)
	var has_profile: bool = me and main != null and "SCREENS" in main and main.SCREENS.has("profile")
	var h: = 548.0 + (104.0 if has_profile else 0.0)
	var p: = Common.popup(main, "Карточка игрока", h)
	p.name = "V8PlayerCard"
	var hero: = String(info.get("hero", "mc"))
	var tier: = clampi(int(info.get("tier", 0)), 0, G.RANKS.size() - 1)
	var rk: Dictionary = G.RANKS[tier]
	# 0.8 art: round portrait in the gold frame (the ornate one for Дракон / Небожитель), rank medallion and
	# league crest side by side with the name
	var av: = V8Population.avatar_view(String(info.get("avatar", "mc_base")), hero, Rect2(26, 54, 188, 188), 0.0, V8Art.top_tier(tier))
	p.add_child(av)
	UI.pop_in(av, 0.05, 0.7)
	var nm: = UI.label(String(info.get("name", "")), 34, Color.WHITE, UI.DARK, 4, "body", 900)
	nm.position = Vector2(226, 60)
	nm.size = Vector2(W - 226 - 30, 48)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	p.add_child(nm)
	_emblem_line(p, 112.0, "Ранг", String(info.get("rank", rk.name)), rk.color.lightened(0.2))
	Common.rank_emblem(p, Rect2(222, 110, 66, 66), tier, int(info.get("sub", 0)))
	var lt: = clampi(int(info.get("league", 0)), 0, V7Ladder.LEAGUES.size() - 1)
	var L: = V7Ladder.league_def(lt)
	_emblem_line(p, 182.0, "Лига недели", String(L.name), (L.color as Color).lightened(0.3))
	Common.league_emblem(p, Rect2(222, 180, 66, 66), lt)
	var tw: = (W - 72.0 - 16.0) * 0.5
	var y0: = 266.0
	if bool(info.get("me", false)) and not V8League.quarter_shown({"place": int(info.get("q_place", 0))}):
		# 0.8: the player's own card follows the victory / profile rule: no «#1 001» below the 80% cut
		_tile(p, Rect2(36, y0, tw, 116), "Место в квартале", "топ-100", "впереди")
	else:
		_tile(p, Rect2(36, y0, tw, 116), "Место в квартале", "#%s" % UI.fmt(int(info.get("q_place", 0))), "из %s" % UI.fmt(V8League.TOTAL))
	_tile(p, Rect2(52 + tw, y0, tw, 116), "Партий за неделю", str(int(info.get("games", 0))), "")
	var fav: = String(info.get("fav", hero))
	if not G.HEROES.has(fav):
		fav = "mc"
	var ft: = _tile(p, Rect2(36, y0 + 132, tw, 116), "Любимая героиня", "", "")
	ft.add_child(Common.avatar(fav, Rect2(14, 40, 64, 64), "plum"))
	var fl: = UI.label(String(G.HEROES[fav].name), 24, G.HEROES[fav].color.lightened(0.2), UI.DARK, 3, "body", 900)
	fl.position = Vector2(88, 40)
	fl.size = Vector2(tw - 96, 64)
	fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fl.clip_text = true
	ft.add_child(fl)
	_tile(p, Rect2(52 + tw, y0 + 132, tw, 116), "Очки турнира недели", UI.fmt(int(info.get("week_points", 0))), "")
	if has_profile:
		var b: = JButton.make("Открыть профиль", "gold", Rect2(110, h - 116, W - 220, 84), null, 28)
		b.shine_every = 3.0
		b.pressed.connect(func():
			Common.close_popup(p)
			main.go("profile", {"from": String(main.screen_id) if "screen_id" in main and String(main.screen_id) != "" else "home"}))
		p.add_child(b)
	return p

# caption + value to the right of a 66 px emblem at x 222
static func _emblem_line(p: Control, y: float, cap: String, val: String, col: Color) -> void:
	var c: = UI.label(cap, 16, UI.MUTED, UI.DARK, 2, "body", 800)
	c.position = Vector2(298, y + 2)
	c.size = Vector2(W - 298 - 30, 24)
	p.add_child(c)
	var v: = UI.label(val, 26, col, UI.DARK, 3, "body", 900)
	v.position = Vector2(298, y + 24)
	v.size = Vector2(W - 298 - 30, 38)
	Common.fit_line(v, v.size.x, 18)
	p.add_child(v)


static func _tile(parent: Control, r: Rect2, cap: String, val: String, sub: String) -> RBox:
	var b: = UI.rbox("glass", r, 22, 2, 6)
	b.borders(Color(1, 0.9, 0.7, 0.35), Color(0, 0, 0, 0.35))
	parent.add_child(b)
	var c: = UI.label(cap, 18, UI.MUTED, UI.DARK, 2, "body", 800)
	c.position = Vector2(16, 8)
	c.size = Vector2(r.size.x - 24, 28)
	c.clip_text = true
	b.add_child(c)
	if val != "":
		var v: = UI.label(val, 34, Color("ffe7a6"), UI.DARK, 4, "body", 900)
		v.position = Vector2(16, 40)
		v.size = Vector2(r.size.x - 24, 64)
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(v)
		if sub != "":
			var vw: float = UI.font("body", 900).get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
			var s: = UI.label(sub, 18, UI.MUTED, UI.DARK, 2, "body", 800)
			s.position = Vector2(16 + vw + 10, 40)
			s.size = Vector2(r.size.x - vw - 40, 64)
			s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			b.add_child(s)
	return b
