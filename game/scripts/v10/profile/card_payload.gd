class_name V10CardPayload
extends RefCounted

# V10CardPayload — the data of a player card as other players see it (docs/0.10-spec.md §D6). One flat
# dictionary, ≤ 2 KB as JSON; the same validate() will run on the server in 1.0. Spending is never on a card.
#
#   V10CardPayload.mine(S, extra = {}) -> Dictionary    the player's own card from the save (picks sanitised first)
#   V10CardPayload.validate(p) -> String                "" = ok, otherwise the first problem
#   V10CardPayload.size_bytes(p) -> int                 JSON size
#   V10CardPayload.sim(rng, tier, nick = "") -> Dict    a simulated opponent's card: rank frames, A/S goddess frames,
#                                                       early titles only; no SSR goddess, no SSR outfit, no Lavka or
#                                                       pass frames — never a fake showcase of paid content (sim: true)
#
# {v, nick, avatar, frame, title, badges[≤3], card_bg, showcase{hero, outfit, pose}, rank{tier, sub}, league,
#  stats{heroes, heroes_total, games_week, best_combo}, ostars, tile, sim, me}
# `extra` (and the caller after mine()) may set: league, games_week, best_combo, me, pts (league rows).

const VER: = 1
const MAX_BYTES: = 2048
const HEROES_TOTAL: = 20
const KEYS: = ["v", "nick", "avatar", "frame", "title", "badges", "card_bg", "showcase", "rank", "league", "stats", "ostars", "tile", "sim"]


static func _g() -> bool:
	var tree: = Engine.get_main_loop() as SceneTree
	return tree != null and tree.root.get_node_or_null("G") != null


static func mine(S: Dictionary, extra: = {}) -> Dictionary:
	var ctx: = V10ProfileCos.ctx_from_save(S)
	var prof_src = S.get("profile", {})
	var prof: Dictionary = (prof_src as Dictionary).duplicate(true) if prof_src is Dictionary else {}
	var d: = V10ProfileCos.defaults()
	# 0.8 saves: profile.frame was "" and there was no showcase -> partner's current outfit
	if not prof.has("showcase"):
		var h: = String(S.get("partner", prof.get("avatar", "mc")))
		var o: = String(S.get("outfit", {}).get(h, "")) if S.get("outfit") is Dictionary else ""
		prof["showcase"] = {"hero": h, "outfit": o, "pose": "base"}
	V10ProfileCos.sanitize(prof, ctx)
	var sc: Dictionary = prof.showcase
	var tier: = int(ctx.rank_tier)
	var sub: = 0
	if _g():
		sub = int(G.rank_of(int(S.get("rp", 0))).get("sub", 0))
	var nick: = ""
	for ch in String(prof.get("nick", "")):
		if ch.unicode_at(0) >= 32:
			nick += ch
	nick = nick.strip_edges()
	if nick == "":
		nick = "Гость"
	var ost = S.get("ostars", {})
	var p: = {
		"v": VER, "nick": nick.substr(0, 16), "avatar": String(prof.get("avatar", sc.hero)),
		"frame": String(prof.get("frame", d.frame)), "title": String(prof.get("title", d.title)),
		"badges": (prof.get("badges", []) as Array).duplicate(), "card_bg": String(prof.get("card_bg", d.card_bg)),
		"showcase": {"hero": String(sc.hero), "outfit": String(sc.outfit), "pose": String(sc.get("pose", "base"))},
		"rank": {"tier": tier, "sub": sub}, "league": int(extra.get("league", 0)),
		"stats": {"heroes": clampi(int(ctx.stats.get("heroes", 1)), 0, HEROES_TOTAL), "heroes_total": HEROES_TOTAL,
			"games_week": clampi(int(extra.get("games_week", 0)), 0, 100000), "best_combo": clampi(int(ctx.stats.get("best_combo", 0)), 0, 999)},
		"ostars": clampi(int(ost.get(String(sc.outfit), 0)), 0, 5) if ost is Dictionary else 0,
		"tile": String(S.get("skin", "s_sakura")), "sim": false,
	}
	if not roster_has(p.avatar):
		p.avatar = String(sc.hero)
	for k in extra:
		if not p.has(k) or k in ["league"]:
			p[k] = extra[k]
	if extra.has("games_week"):
		p.stats.games_week = clampi(int(extra.games_week), 0, 100000)
	return p


static func roster_has(h: String) -> bool:
	return V10ProfileCos.ROSTER.has(h) and V10ProfileCos.released(h)


static func size_bytes(p: Dictionary) -> int:
	return JSON.stringify(p).to_utf8_buffer().size()


static func _int_in(v, lo: int, hi: int) -> bool:
	return (v is int or v is float) and int(v) == v and int(v) >= lo and int(v) <= hi


static func validate(p) -> String:
	if not (p is Dictionary):
		return "not a dictionary"
	for k in KEYS:
		if not p.has(k):
			return "missing %s" % k
	if int(p.v) != VER:
		return "version"
	var nick = p.nick
	if not (nick is String) or nick.strip_edges().length() < 1 or nick.length() > 16:
		return "nick length"
	for ch in nick:
		if ch.unicode_at(0) < 32:
			return "nick control chars"
	if not (p.avatar is String) or not roster_has(p.avatar):
		return "avatar"
	if not V10ProfileCos.has(String(p.frame), "frame"):
		return "frame"
	if not V10ProfileCos.has(String(p.title), "title"):
		return "title"
	if not V10ProfileCos.has(String(p.card_bg), "bg"):
		return "card_bg"
	if not (p.badges is Array) or p.badges.size() > V10ProfileCos.BADGE_SLOTS:
		return "badges"
	var seen: = {}
	for b in p.badges:
		if not (b is String) or not V10ProfileCos.has(b, "badge") or seen.has(b):
			return "badge %s" % str(b)
		seen[b] = true
	for id in [p.frame, p.title, p.card_bg] + Array(p.badges):
		if not V10ProfileCos.released(String(V10ProfileCos.entry(String(id)).get("hero", ""))):
			return "unreleased %s" % id
	var sc = p.showcase
	if not (sc is Dictionary) or not roster_has(String(sc.get("hero", ""))):
		return "showcase hero"
	var outfit: = String(sc.get("outfit", ""))
	if _g():
		if not G.ITEM.has(outfit) or String(G.ITEM[outfit].get("cat", "")) != "outfit" or String(G.ITEM[outfit].get("hero", "")) != String(sc.hero):
			return "showcase outfit"
	if not (p.rank is Dictionary) or not _int_in(p.rank.get("tier"), 0, 5) or not _int_in(p.rank.get("sub"), 0, 99):
		return "rank"
	if not _int_in(p.league, 0, 5):
		return "league"
	var st = p.stats
	if not (st is Dictionary):
		return "stats"
	if not _int_in(st.get("heroes"), 0, HEROES_TOTAL) or not _int_in(st.get("heroes_total"), 1, 99):
		return "stats.heroes"
	if not _int_in(st.get("games_week"), 0, 100000) or not _int_in(st.get("best_combo"), 0, 999):
		return "stats.numbers"
	if not _int_in(p.ostars, 0, 5):
		return "ostars"
	if not (p.tile is String) or String(p.tile).length() > 24:
		return "tile"
	if not (p.sim is bool):
		return "sim"
	if p.sim:
		var err: = sim_check(p)
		if err != "":
			return err
	if size_bytes(p) > MAX_BYTES:
		return "too big"
	return ""


# a simulated card may only show what a real early / mid player could show without paying
static func sim_check(p: Dictionary) -> String:
	for id in [p.frame, p.title, p.card_bg] + Array(p.badges):
		var e: = V10ProfileCos.entry(String(id))
		if not bool(e.get("sim_ok", false)):
			return "sim shows %s" % id
		if String(e.src.type) in ["shop", "pass"] or int(e.get("price", 0)) > 0:
			return "sim shows paid %s" % id
	var h: = String(p.showcase.hero)
	if String(V10ProfileCos.ROSTER.get(h, ["", "", "SSR"])[2]) == "SSR":
		return "sim shows SSR goddess"
	if V10ProfileCos.outfit_rar(String(p.showcase.outfit)) == "SSR":
		return "sim shows SSR outfit"
	if _g():
		var it: Dictionary = G.ITEM.get(String(p.showcase.outfit), {})
		if it.has("shop") or bool(it.get("pass", false)):
			return "sim shows paid outfit"
	return ""


static func sim(rng: RandomNumberGenerator, tier: int, nick: = "") -> Dictionary:
	tier = clampi(tier, 0, 5)
	var frames: = []
	for e in V10ProfileCos.all("frame"):
		if not bool(e.sim_ok):
			continue
		var s: Dictionary = e.src
		if String(s.type) == "rank" and int(s.tier) > tier:
			continue
		frames.append(e.id)
	var titles: = []
	for e in V10ProfileCos.all("title"):
		if bool(e.sim_ok) and (String(e.src.type) != "rank" or int(e.src.tier) <= tier):
			titles.append(e.id)
	var badges: = []
	for e in V10ProfileCos.all("badge"):
		if bool(e.sim_ok):
			badges.append(e.id)
	var bgs: = []
	for e in V10ProfileCos.all("bg"):
		if bool(e.sim_ok):
			bgs.append(e.id)
	var outfits: = []
	if _g():
		for it in G.ITEMS:
			if String(it.get("cat", "")) != "outfit" or bool(it.get("hidden", false)) or it.has("shop") or bool(it.get("pass", false)):
				continue
			if String(it.get("rar", "R")) == "SSR" or not roster_has(String(it.hero)):
				continue
			if String(V10ProfileCos.ROSTER[String(it.hero)][2]) == "SSR":
				continue
			outfits.append([String(it.hero), String(it.id)])
	if outfits.is_empty():
		outfits.append(["mc", "o_base"])
	var pick: Array = outfits[rng.randi() % outfits.size()]
	var nb: = rng.randi_range(0, 3)
	var bs: = []
	var pool: = badges.duplicate()
	for i in nb:
		if pool.is_empty():
			break
		var k: = rng.randi() % pool.size()
		bs.append(pool[k])
		pool.remove_at(k)
	if nick == "":
		nick = "Игрок %d" % rng.randi_range(100, 999)
	var p: = {
		"v": VER, "nick": nick.substr(0, 16), "avatar": pick[0],
		"frame": frames[rng.randi() % frames.size()], "title": titles[rng.randi() % titles.size()],
		"badges": bs, "card_bg": bgs[rng.randi() % bgs.size()],
		"showcase": {"hero": pick[0], "outfit": pick[1], "pose": "base"},
		"rank": {"tier": tier, "sub": rng.randi_range(0, 2)}, "league": clampi(tier + rng.randi_range(-1, 0), 0, 5),
		"stats": {"heroes": rng.randi_range(1, 5), "heroes_total": HEROES_TOTAL, "games_week": rng.randi_range(3, 60),
			"best_combo": rng.randi_range(3, 4 + tier * 2)},
		"ostars": rng.randi_range(0, 2), "tile": ["s_sakura", "s_mint", "s_lemon"][rng.randi() % 3], "sim": true,
	}
	return p
