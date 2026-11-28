class_name V10W1Social
extends RefCounted

# Wave 1 «social» data — tsubame, miel, kohaku, shirin, zlata in the rituals (Р3–Р7, Р10), the phone (Р8 Чаты +
# стикеры, Р9 Лента) and the sign-in greeting. Pure data + small static helpers, no autoloads, no scenes; it does not
# gate anything itself: every consumer hook below sits behind V10Wave1.released() (integrator's facade).
#
# Files (all under res://scripts/v10/wave1/):
#   w1_social.gd            this file: constants, loaders, merge helpers for the consumers, self-checks
#   w1_social_lines.gd      V10W1SocialLines: RIT (= V10RitLines.L shape), AWAY_BODY, AUTH_NICKS, AUTH_GREET
#   data/w1_chat/src/<h>.chat     chat DSL (the chat lane's format, docs in scripts/v10/chat/tools/build_chat.py)
#   data/w1_chat/threads_<h>.json compiled threads (generated; build below — never edit by hand)
#   data/w1_chat/stickers.json · reactions.json · feed.json · meta.json   same shapes as res://data/v10/chat/*
#
# Build the chat JSON after editing src/*.chat (uses the chat lane's parser unchanged; from the repo root):
#   python3 -c "import sys,json,os; sys.path.insert(0,'game/scripts/v10/chat/tools'); import build_chat as b;
#     D='game/scripts/v10/wave1/data/w1_chat'
#     [json.dump({'v':1,'hero':h,'threads':b.parse(f'{D}/src/{h}.chat',h)[0]}, open(f'{D}/threads_{h}.json','w',encoding='utf-8'),
#       ensure_ascii=False, indent=1) for h in ['tsubame','miel','kohaku','shirin','zlata']]"
#   (b.parse returns (threads, errors): print the errors first; then run V10W1Social.problems() in Godot.)
#
# API
#   HEROES, BDAY, SIG, SIG_NAME, SIG_TILE, CAKE, OUTFITS, CHAT_OUTFITS     fixed facts (brief / spec Р6)
#   rit_lines(group, h) -> Array        her V10RitLines group ([] = none)      rit_all() -> Array  formatted, for lint
#   away_body(h, fallback) -> String    sig_icon(h) -> String ("" until the emblem art exists)   cake(h) -> String
#   portrait(h) -> String               full-body cut-out path ("" when missing)
#   chat_file(h) -> Dictionary          {v, hero, threads} like V10ChatData.hero_file
#   stickers() / reactions() / meta() -> Dictionary,  feed() -> Array,  birthday(h) -> "MM-DD"
#   with_stickers(base) / with_reactions(base) -> Dictionary,  with_feed(base) -> Array   founders' data + wave 1
#   sticker_path(id) -> String          wave-1 sticker art ("" → the phone draws glyph + label)
#   auth_nicks(h) -> Array, auth_greet(h) -> Array
#   problems(strict_art = true) -> Array   every self-check below; [] = shippable      volumes() -> Dictionary
#
# HOOKS for the integrator (each behind V10Wave1.released(); exact code in the lane report):
#   chat/chat_data.gd   heroes(); hero_file, all_threads, sticker, stickers, reactions, feed, birthday merge wave 1
#   chat/chat.gd        D.HEROES → D.heroes() in tick, _pick_daily, stickers_for
#   phone/phone.gd      D.HEROES → D.heroes() in owned, ctx;  sticker_path falls back to V10W1Social.sticker_path
#   phone/sticker_tray.gd  D.HEROES → D.heroes() in _packs
#   rituals/rit_lines.gd   pick() falls back to rit_lines(group, h)
#   rituals/comeback.gd    AWAY_BODY lookup;  rituals/bday.gd sig_icon / cake_icon;  rituals/ui/bday_cake.gd CAKE
#   rituals/rit_bridge.gd  portrait(h) falls back to the wave-1 cut-out
#   auth/auth_nicks.gd, auth/auth_text.gd   IDEAS / GREET fall back to auth_nicks / auth_greet

const HEROES: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
const NAMES: = {"tsubame": "Цубамэ", "miel": "Миэль", "kohaku": "Кохаку", "shirin": "Ширин", "zlata": "Злата"}
# spec Р6 — identical to V10BdayData.DATES (selftest)
const BDAY: = {"tsubame": "05-20", "miel": "02-27", "kohaku": "04-27", "shirin": "08-27", "zlata": "03-18"}

const CHAT_DIR: = "res://core/wave1/data/w1_chat/"
const STICKER_DIR: = "res://assets/v10/wave1/stickers/"
const PORTRAIT_DIR: = "res://assets/v10/wave1/hero/"
const RIT_ART: = "res://assets/v10/rituals/"

# birthday emblem drawn over a tile face (V10BdayData.SIG shape). Art lane: 192 px RGBA webp, gold medallion frame
# like assets/v10/rituals/sig_*.webp; until a file exists sig_icon() returns "" and V10Bday shows no overlay.
const SIG: = {
	"tsubame": "res://assets/v10/wave1/rituals/sig_tsubame.webp", "miel": "res://assets/v10/wave1/rituals/sig_miel.webp",
	"kohaku": "res://assets/v10/wave1/rituals/sig_kohaku.webp", "shirin": "res://assets/v10/wave1/rituals/sig_shirin.webp",
	"zlata": "res://assets/v10/wave1/rituals/sig_zlata.webp",
}
const SIG_NAME: = {"tsubame": "слива", "miel": "торт", "kohaku": "лиса", "shirin": "солнце", "zlata": "огонь"}
# G.TILE_NAMES index of her signature tile (= V10Look kit_data «sig»): plum 1, cake 16, fox 31, sun 9, fire 12
const SIG_TILE: = {"tsubame": 1, "miel": 16, "kohaku": 31, "shirin": 9, "zlata": 12}
# V10BdayData.CAKE: the second overlaid kind of her birthday deal (assets/v10/rituals/<cake>.webp)
const CAKE: = {"tsubame": "cake_matcha", "miel": "cake_tier", "kohaku": "cake_matcha", "shirin": "cake_tier", "zlata": "cake_tier"}

# her outfits (brief table) — the chat validator's ownership check for «outfit» threads
const OUTFITS: = {
	"tsubame": ["tb_base", "tb_post", "tb_crimson"],
	"miel": ["me_base", "me_parlor", "me_gala"],
	"kohaku": ["ko_base", "ko_matsuri", "ko_kyubi", "ko_vow"],
	"shirin": ["sh_base", "sh_oasis", "sh_sun", "sh_night"],
	"zlata": ["zl_base", "zl_fair", "zl_ember", "zl_vow"],
}
# the two outfits that open an «outfit» chat thread when worn (founders: two each)
const CHAT_OUTFITS: = {
	"tsubame": ["tb_post", "tb_crimson"], "miel": ["me_parlor", "me_gala"], "kohaku": ["ko_matsuri", "ko_kyubi"],
	"shirin": ["sh_oasis", "sh_night"], "zlata": ["zl_fair", "zl_ember"],
}

# founders' volume per heroine (res://data/v10/chat) — wave 1 matches it
const VOL: = {"threads": 14, "daily": 7, "outfit_threads": 2, "stickers": 8, "feed": 4, "min_msgs": 90, "min_pills": 27,
	"min_photos": 5, "min_stickers": 8, "voices": 1}
const MOODS: = ["warm", "fun", "tease", "tired", "win"]
const REACT_KEYS: = ["heart", "laugh", "wow", "sad", "fire", "tea", "sticker_warm", "sticker_fun", "sticker_tease",
	"sticker_tired", "sticker_win"]
const WEEK_BLACK: = ["проигр", "ноч", "не было", "пропуст", "\u20bd", "трат", "покуп", "другие игроки", "лучше, чем"]
const GENDERED: = ["ты пришёл", "ты пришла", "ты был ", "ты была", "ты собрал ", "ты подарил ", "уходил "]

static var _cache: = {}


# ── rituals (V10RitLines, V10Comeback, V10BdayData) ─────────────────────────────────────────────────────────────

static func rit_lines(group: String, h: String) -> Array:
	return (V10W1SocialLines.RIT.get(group, {}) as Dictionary).get(h, [])


# every ritual line formatted like V10RitLines.all() (n = 7, {voc} = «, Аня») — for the lint selftests
static func rit_all() -> Array:
	var out: = []
	for g in V10W1SocialLines.RIT:
		for h in V10W1SocialLines.RIT[g]:
			for s in V10W1SocialLines.RIT[g][h]:
				out.append(V10RitLines.fmt(str(s).replace("{voc}", ", Аня"), 7))
	return out


static func away_body(h: String, fallback: String = "") -> String:
	return str(V10W1SocialLines.AWAY_BODY.get(h, fallback))


static func sig_icon(h: String) -> String:
	var p: String = SIG.get(h, "")
	return p if p != "" and ResourceLoader.exists(p) else ""


static func cake(h: String) -> String:
	return str(CAKE.get(h, "cake_tier"))


static func portrait(h: String) -> String:
	var p: = PORTRAIT_DIR + h + ".png"
	return p if h in HEROES and ResourceLoader.exists(p) else ""


# ── chat / stickers / feed (V10ChatData shapes) ─────────────────────────────────────────────────────────────────

static func _load(file: String) -> Variant:
	if _cache.has(file):
		return _cache[file]
	var path: = CHAT_DIR + file
	var v: Variant = null
	if FileAccess.file_exists(path):
		v = JSON.parse_string(FileAccess.get_file_as_string(path))
	_cache[file] = v
	return v


static func reload() -> void:
	_cache.clear()


static func chat_file(h: String) -> Dictionary:
	if not h in HEROES:
		return {}
	var d: Variant = _load("threads_%s.json" % h)
	return d if d is Dictionary else {}


static func threads(h: String) -> Array:
	return chat_file(h).get("threads", [])


static func stickers() -> Dictionary:
	var d: Variant = _load("stickers.json")
	return d if d is Dictionary else {}


static func reactions() -> Dictionary:
	var d: Variant = _load("reactions.json")
	return d if d is Dictionary else {}


static func meta() -> Dictionary:
	var d: Variant = _load("meta.json")
	return d if d is Dictionary else {}


static func feed() -> Array:
	var d: Variant = _load("feed.json")
	return d.get("posts", []) if d is Dictionary else []


static func birthday(h: String) -> String:
	return str(meta().get("birthdays", {}).get(h, BDAY.get(h, "")))


# founders' dictionary + the five wave-1 groups (a new dictionary, cached per base; the base is never mutated)
static func _merged(key: String, base: Dictionary, add: Dictionary) -> Dictionary:
	var c: Dictionary = _cache.get(key, {})
	if not c.is_empty() and is_same(c.base, base):
		return c.out
	var out: = base.duplicate()
	for h in HEROES:
		if add.has(h) and not out.has(h):
			out[h] = add[h]
	_cache[key] = {"base": base, "out": out}
	return out


static func with_stickers(base: Dictionary) -> Dictionary:
	return _merged("#stickers", base, stickers())


static func with_reactions(base: Dictionary) -> Dictionary:
	return _merged("#reactions", base, reactions())


# founders' evergreen pool first (their order and days never move), then the wave-1 posts
static func with_feed(base: Array) -> Array:
	var c: Dictionary = _cache.get("#feed", {})
	if not c.is_empty() and is_same(c.base, base):
		return c.out
	var out: = base.duplicate()
	out.append_array(feed())
	_cache["#feed"] = {"base": base, "out": out}
	return out


static func is_w1_sticker(id: String) -> bool:
	for h in HEROES:
		if id.begins_with(h + "_"):
			return true
	return false


static func sticker_path(id: String) -> String:
	if not is_w1_sticker(id):
		return ""
	var p: = STICKER_DIR + id + ".webp"
	return p if ResourceLoader.exists(p) else ""


# ── sign-in (V10AuthNicks, V10AuthText) ─────────────────────────────────────────────────────────────────────────

static func auth_nicks(h: String) -> Array:
	return V10W1SocialLines.AUTH_NICKS.get(h, [])


static func auth_greet(h: String) -> Array:
	return V10W1SocialLines.AUTH_GREET.get(h, [])


# ── self-checks (the integrator's --wave1_selftest runs problems()) ─────────────────────────────────────────────

static func all_texts() -> Array:
	var out: Array = rit_all()
	out.append_array(V10W1SocialLines.AWAY_BODY.values())
	for h in HEROES:
		out.append_array(auth_nicks(h))
		for g in auth_greet(h):
			out.append(str(g) % "Аня")
	for h in HEROES:
		for t in threads(h):
			out.append(str(t.get("title", "")))
			for n in t.get("nodes", {}).values():
				for m in n.get("msgs", []):
					if m.has("t"):
						out.append(str(m.t))
				for c in n.get("choices", []):
					if c.has("t"):
						out.append(str(c.t))
		for s in stickers().get(h, []):
			out.append(str(s.get("label", "")))
		for k in reactions().get(h, {}):
			out.append_array(reactions()[h][k])
	for p in feed():
		out.append(str(p.get("t", "")))
		for c in p.get("comments", []):
			out.append(str(c.get("t", "")))
		for r in p.get("replies", []):
			out.append(str(r.get("t", "")))
			out.append(str(r.get("a", "")))
	return out


static func _lint_all(text: String) -> Array:
	# V10Lint.BANNED (spec §2.7) + the chat lane's stricter red-line list (substrings, no allow-list). V10Lint and
	# V10ChatData are pure scripts, so this also runs in a bare -s SceneTree without the G autoload.
	var bad: Array = V10Lint.check(text)
	for w in V10ChatData.lint(text):
		if not w in bad:
			bad.append(w)
	return bad


static func problems(strict_art: = true) -> Array:
	reload()
	var errs: = []
	errs.append_array(_check_rituals())
	errs.append_array(_check_auth())
	errs.append_array(_check_chat(strict_art))
	for t in all_texts():
		var b: = _lint_all(str(t))
		if not b.is_empty():
			errs.append("lint %s: «%s»" % [b, t])
	return errs


static func _check_rituals() -> Array:
	var errs: = []
	for h in HEROES:
		if str(V10BdayData.DATES.get(h, "")) != str(BDAY[h]):
			errs.append("bday %s: %s ≠ V10BdayData %s" % [h, BDAY[h], V10BdayData.DATES.get(h, "")])
		if birthday(h) != str(BDAY[h]):
			errs.append("chat meta birthday %s" % h)
		if _g() != null and not _bridge_gen().has(h):
			errs.append("rituals: no genitive for %s in V10RitBridge.GEN" % h)
		if str(V10W1SocialLines.AWAY_BODY.get(h, "")) == "":
			errs.append("rituals: no AWAY_BODY for %s" % h)
		if not CAKE.has(h) or not ResourceLoader.exists(RIT_ART + cake(h) + ".webp"):
			errs.append("rituals: cake art for %s" % h)
	if V10BdayData.problems().size() > 0:
		errs.append("V10BdayData.problems: %s" % [V10BdayData.problems()])
	# same groups and the same number of lines per group as a founder (rin)
	for g in V10RitLines.L:
		var want: int = (V10RitLines.L[g].get("rin", []) as Array).size()
		for h in HEROES:
			var got: = rit_lines(g, h).size()
			if got != want:
				errs.append("rituals %s/%s: %d lines, founders have %d" % [g, h, got, want])
	for g in V10W1SocialLines.RIT:
		if not V10RitLines.L.has(g):
			errs.append("rituals: unknown group %s" % g)
	for t in rit_all():
		for w in GENDERED:
			if str(t).to_lower().find(w) >= 0:
				errs.append("rituals: gendered past tense «%s»" % t)
		if str(t).find("{") >= 0:
			errs.append("rituals: unresolved token «%s»" % t)
	for g in ["week_open", "week_close"]:
		for h in HEROES:
			for t in rit_lines(g, h):
				for w in WEEK_BLACK:
					if str(t).to_lower().find(w) >= 0:
						errs.append("week letter black-list «%s» in «%s»" % [w, t])
	for g in ["milestone"]:
		for h in HEROES:
			for t in rit_lines(g, h):
				if str(t).find("{n}") < 0:
					errs.append("milestone without {n}: «%s»" % t)
	for h in HEROES:
		for t in rit_lines("player_bday", h):
			if str(t).find("{voc}") < 0:
				errs.append("player_bday without {voc}: «%s»" % t)
	return errs


static func _check_auth() -> Array:
	var errs: = []
	for h in HEROES:
		var nicks: = auth_nicks(h)
		if nicks.size() != 8:
			errs.append("auth: %s has %d nick ideas (founders 8)" % [h, nicks.size()])
		for n in nicks:
			var s: = str(n).strip_edges()
			if s.length() < 3 or s.length() > 16:
				errs.append("auth: nick «%s» not 3…16 chars" % s)
		var gr: = auth_greet(h)
		if gr.size() != 3:
			errs.append("auth: %s has %d greetings (founders 3)" % [h, gr.size()])
		for g in gr:
			if str(g).count("%s") != 1 or str(g).find("%") != str(g).find("%s"):
				errs.append("auth: greeting needs exactly one %%s: «%s»" % g)
	return errs


# ── chat: the rules of V10ChatValidate, applied to the wave-1 files ─────────────────────────────────────────────

static func _text(errs: Array, where: String, t: Variant, maxlen: int, trig: String = "") -> void:
	if not t is String or str(t).strip_edges() == "":
		errs.append("%s: empty text" % where)
		return
	var s: String = t
	var i: = s.find("{")
	while i >= 0:
		var j: = s.find("}", i)
		if j < 0:
			errs.append("%s: unclosed token" % where)
			break
		var tok: = s.substr(i + 1, j - i - 1)
		if tok.begins_with("g:"):
			if tok.substr(2).split("|").size() != 2:
				errs.append("%s: gender token needs male|female {%s}" % [where, tok])
		elif not tok in V10ChatValidate.TOKENS:
			errs.append("%s: unknown token {%s}" % [where, tok])
		elif V10ChatValidate.TOKEN_TRIGGER.has(tok) and trig != "" and V10ChatValidate.TOKEN_TRIGGER[tok] != trig:
			errs.append("%s: {%s} outside a %s thread" % [where, tok, V10ChatValidate.TOKEN_TRIGGER[tok]])
		i = s.find("{", j)
	var vars: = {"combo": 99, "rank": "Нефритовый мастер III", "days": 12, "outfit_name": "Императрица дракона"}
	for g in ["m", "f"]:
		var out: = V10Chat.format(s, vars, {"name": "Константин", "name_voc": "Константин", "gender": g})
		if out.length() > maxlen:
			errs.append("%s: too long %d > %d «%s»" % [where, out.length(), maxlen, out])
		if out.contains("{") or out.contains("}"):
			errs.append("%s: unresolved token «%s»" % [where, out])


static func _photo(errs: Array, where: String, img: Variant, strict_art: bool) -> void:
	var s: = str(img)
	if not s.begins_with("v10/wave1/"):
		errs.append("%s: photo must be wave-1 art: %s" % [where, s])
	if s in V10ChatData.PHOTO_DENY:
		errs.append("%s: photo is not sfw: %s" % [where, s])
	var it: = _g_item(s.get_file())
	if not it.is_empty() and not bool(it.get("sfw", true)):
		errs.append("%s: outfit %s is sfw=false" % [where, s])
	if strict_art and V10ChatData.photo_path(s) == "":
		errs.append("%s: photo art not found: %s" % [where, s])


static func _g() -> Node:
	var tree: = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("G") if tree != null else null


static func _g_item(id: String) -> Dictionary:
	var g: = _g()
	if g == null:
		return {}
	for it in g.ITEMS:
		if str(it.get("id", "")) == id:
			return it
	return {}


static func _check_chat(strict_art: bool) -> Array:
	var errs: = []
	# meta + stickers
	var sticker_ids: = {}
	for s in V10ChatData.stickers().get("common", []):
		sticker_ids[s.id] = "common"
	var all_st: = stickers()
	for h in HEROES:
		var arr: Array = all_st.get(h, [])
		if arr.size() != VOL.stickers:
			errs.append("stickers %s: %d (need %d)" % [h, arr.size(), VOL.stickers])
		var hi: = 0
		for st in arr:
			var id: = str(st.get("id", ""))
			if sticker_ids.has(id):
				errs.append("stickers: duplicate %s" % id)
			sticker_ids[id] = h
			if not id.begins_with(h + "_"):
				errs.append("stickers: %s must start with %s_" % [id, h])
			if not str(st.get("mood", "")) in MOODS:
				errs.append("stickers: %s bad mood" % id)
			if str(st.get("label", "")) == "" or str(st.get("glyph", "")) == "":
				errs.append("stickers: %s needs label and glyph" % id)
			if not str(st.get("img", "")).begins_with("res://assets/v10/stickers/"):
				errs.append("stickers: %s img path" % id)
			var lv: = int(st.get("level", 1))
			if lv < 1 or lv > 10:
				errs.append("stickers: %s bad level" % id)
			if lv >= 5:
				hi += 1
		if hi < 1 or hi > 4:
			errs.append("stickers %s: 1–4 should open at affection 5 (has %d)" % [h, hi])
	# reactions: same keys as the founders, ≥2 lines each
	var rset: Array = V10ChatData.reactions().get("set", [])
	for h in HEROES:
		var hr: Dictionary = reactions().get(h, {})
		for k in REACT_KEYS:
			var lines: Array = hr.get(k, [])
			if lines.size() < 2:
				errs.append("reactions %s/%s: needs ≥2 lines" % [h, k])
			for l in lines:
				_text(errs, "reactions/%s/%s" % [h, k], l, V10ChatData.MAX_REACT_LINE)
		for r in rset:
			if not hr.has(r):
				errs.append("reactions %s: missing %s" % [h, r])
	# feed
	var per: = {}
	var seen: = {}
	for p in V10ChatData.feed():
		seen[str(p.get("id", ""))] = true
	for p in feed():
		var id: = str(p.get("id", ""))
		var w: = "feed/" + id
		if id == "" or seen.has(id):
			errs.append("%s: duplicate or empty id" % w)
		seen[id] = true
		var h: = str(p.get("hero", ""))
		if not h in HEROES:
			errs.append("%s: unknown hero" % w)
		per[h] = int(per.get(h, 0)) + 1
		_photo(errs, w, p.get("img"), strict_art)
		_text(errs, w, p.get("t"), V10ChatData.MAX_FEED)
		if str(p.get("t", "")).contains("{"):
			errs.append("%s: the caption is shown raw, no tokens" % w)
		var cm: Array = p.get("comments", [])
		if cm.size() > 2:
			errs.append("%s: max 2 comments" % w)
		for c in cm:
			var ch: = str(c.get("hero", ""))
			if not (ch in HEROES or ch in V10ChatData.HEROES) or ch == h:
				errs.append("%s: comment by %s" % [w, ch])
			_text(errs, w + "/comment", c.get("t"), V10ChatData.MAX_COMMENT)
		var rp: Array = p.get("replies", [])
		if rp.size() != 2:
			errs.append("%s: needs exactly 2 reply pills" % w)
		for x in rp:
			_text(errs, w + "/reply", x.get("t"), V10ChatData.MAX_CHOICE)
			if str(x.get("t", "")).contains("{"):
				errs.append("%s: the reply pill is shown raw, no tokens" % w)
			_text(errs, w + "/answer", x.get("a"), V10ChatData.MAX_COMMENT)
	for h in HEROES:
		if int(per.get(h, 0)) != VOL.feed:
			errs.append("feed: %s has %d posts (founders %d)" % [h, int(per.get(h, 0)), VOL.feed])
	# threads
	var ids: = {}
	for t in V10ChatData.all_threads():
		ids[str(t.get("id", ""))] = true
	for h in HEROES:
		var f: = chat_file(h)
		if f.is_empty():
			errs.append("threads_%s.json: missing or invalid" % h)
			continue
		if str(f.get("hero", "")) != h:
			errs.append("threads_%s.json: hero field mismatch" % h)
		var list: Array = f.get("threads", [])
		var by_trig: = {}
		var outfits_seen: = []
		for t in list:
			var id: = str(t.get("id", ""))
			if ids.has(id):
				errs.append("%s: duplicate thread id" % id)
			ids[id] = true
			var trig: = str(t.get("trigger", ""))
			by_trig[trig] = int(by_trig.get(trig, 0)) + 1
			if trig == "outfit":
				outfits_seen.append(str(t.get("outfit", "")))
			_thread(errs, t, h, sticker_ids, strict_art)
		if list.size() != VOL.threads:
			errs.append("threads_%s: %d threads (founders %d)" % [h, list.size(), VOL.threads])
		if int(by_trig.get("daily", 0)) != VOL.daily:
			errs.append("threads_%s: %d daily (founders %d, levels 1–7)" % [h, int(by_trig.get("daily", 0)), VOL.daily])
		for trig in V10ChatData.EVENT_TRIGGERS:
			if not by_trig.has(trig):
				errs.append("threads_%s: no thread for event %s" % [h, trig])
		outfits_seen.sort()
		var want: Array = (CHAT_OUTFITS[h] as Array).duplicate()
		want.sort()
		if outfits_seen != want:
			errs.append("threads_%s: outfit threads %s ≠ %s" % [h, outfits_seen, want])
	var v: = volumes()
	for h in HEROES:
		var hv: Dictionary = v[h]
		if int(hv.msgs) < VOL.min_msgs or int(hv.pills) < VOL.min_pills or int(hv.photos) < VOL.min_photos \
				or int(hv.stickers) < VOL.min_stickers or int(hv.voices) < VOL.voices:
			errs.append("volume %s below the founders': %s" % [h, hv])
	return errs


static func _thread(errs: Array, t: Dictionary, h: String, sticker_ids: Dictionary, strict_art: bool) -> void:
	var id: = str(t.get("id", ""))
	var rx: = RegEx.create_from_string("^[a-z0-9_]+$")
	if rx.search(id) == null or not id.begins_with(h + "_"):
		errs.append("%s: id must be [a-z0-9_] and start with %s_" % [id, h])
	if str(t.get("hero", "")) != h:
		errs.append("%s: hero mismatch" % id)
	var trig: = str(t.get("trigger", ""))
	if not trig in V10ChatData.TRIGGERS:
		errs.append("%s: unknown trigger %s" % [id, trig])
	var lv: = int(t.get("level", 0))
	if lv < 1 or lv > 10:
		errs.append("%s: level must be 1..10" % id)
	_text(errs, id + "/title", t.get("title"), V10ChatData.MAX_TITLE, trig)
	if trig == "outfit":
		var o: = str(t.get("outfit", ""))
		if not o in OUTFITS.get(h, []):
			errs.append("%s: outfit %s is not one of %s's" % [id, o, h])
		var g: = _g()
		if g != null and V10W1Social._released() and _g_item(o).is_empty():
			errs.append("%s: outfit %s not in G.ITEMS" % [id, o])
	elif t.has("outfit"):
		errs.append("%s: outfit field only for trigger outfit" % id)
	if trig in ["comeback", "birthday"] and int(t.get("repeat", 0)) < 28:
		errs.append("%s: %s threads must be repeatable (repeat ≥28 days)" % [id, trig])
	var nodes: Dictionary = t.get("nodes", {})
	var start: = str(t.get("start", ""))
	if not nodes.has(start):
		errs.append("%s: start node missing" % id)
		return
	for name in nodes:
		var n: Dictionary = nodes[name]
		var wn: = "%s:%s" % [id, name]
		var outs: = int(n.has("choices")) + int(n.has("next")) + int(bool(n.get("end", false)))
		if outs != 1:
			errs.append("%s: needs exactly one of choices / next / end" % wn)
		if n.has("next") and not nodes.has(str(n.next)):
			errs.append("%s: next → missing node %s" % [wn, n.next])
		if n.has("choices"):
			var ch: Array = n.choices
			if ch.size() < 2 or ch.size() > 3:
				errs.append("%s: choices must be 2–3, has %d" % [wn, ch.size()])
			for c in ch:
				if not nodes.has(str(c.get("next", ""))):
					errs.append("%s: choice → missing node %s" % [wn, c.get("next", "")])
				if c.has("sticker"):
					var sown: = str(sticker_ids.get(c.sticker, ""))
					if sown != h and sown != "common":
						errs.append("%s: pill sticker %s must be common or %s's" % [wn, c.sticker, h])
				else:
					_text(errs, wn + "/choice", c.get("t"), V10ChatData.MAX_CHOICE, trig)
				var a: = int(c.get("aff", 0))
				if a < 0 or a > 2:
					errs.append("%s: choice aff must be 0..2" % wn)
		for m in n.get("msgs", []):
			var k: = str(m.get("k", ""))
			if not k in V10ChatValidate.MSG_KINDS:
				errs.append("%s: unknown msg kind %s" % [wn, k])
			elif k == "text":
				_text(errs, wn, m.get("t"), V10ChatData.MAX_BUBBLE, trig)
			elif k == "photo":
				_photo(errs, wn, m.get("img"), strict_art)
				if m.has("t"):
					_text(errs, wn + "/caption", m.t, V10ChatData.MAX_CAPTION, trig)
			elif k == "sticker":
				var owner: = str(sticker_ids.get(str(m.get("id", "")), ""))
				if owner != h and owner != "common":
					errs.append("%s: she can only send her own or common stickers: %s" % [wn, m.get("id", "")])
			elif k == "voice":
				var sec: = int(m.get("sec", 0))
				if sec < 2 or sec > 4:
					errs.append("%s: voice must be 2–4 s" % wn)
				_text(errs, wn + "/voice", m.get("t"), V10ChatData.MAX_BUBBLE, trig)
	var reach: = {}
	var stats: = {"paths": 0, "min": 999, "max": 0, "aff": 0, "cycle": false}
	V10ChatValidate._walk(t, start, [], 0, 0, reach, stats)
	if stats.cycle:
		errs.append("%s: cycle in the dialogue graph" % id)
	for name in nodes:
		if not reach.has(name):
			errs.append("%s: unreachable node %s" % [id, name])
	if int(stats.paths) == 0:
		errs.append("%s: no path reaches an end" % id)
	if int(stats.min) < V10ChatData.MIN_MSGS:
		errs.append("%s: shortest path has %d heroine messages (< %d)" % [id, stats.min, V10ChatData.MIN_MSGS])
	if int(stats.max) > V10ChatData.MAX_MSGS:
		errs.append("%s: longest path has %d heroine messages (> %d)" % [id, stats.max, V10ChatData.MAX_MSGS])
	if int(stats.aff) + V10ChatData.DONE_AFF > V10ChatData.MAX_THREAD_AFF:
		errs.append("%s: a path gives %d affection (> %d)" % [id, int(stats.aff) + V10ChatData.DONE_AFF, V10ChatData.MAX_THREAD_AFF])


static func _klass(cname: String) -> Script:
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == cname:
			return load(str(c.path))
	return null


static func _released() -> bool:
	var k: = _klass("V10Wave1")
	return k != null and bool(k.call("released"))


# V10RitBridge needs the G autoload to compile, so its GEN table is read only when G is present (the game, selftests)
static func _bridge_gen() -> Dictionary:
	var k: = _klass("V10RitBridge")
	return k.get_script_constant_map().get("GEN", {}) if k != null else {}


# per heroine: threads, msgs, pills, photos, stickers (in threads), voices, feed posts, sticker set, ritual lines
static func volumes() -> Dictionary:
	var out: = {}
	for h in HEROES:
		var v: = {"threads": 0, "msgs": 0, "pills": 0, "photos": 0, "stickers": 0, "voices": 0, "feed": 0,
			"sticker_set": (stickers().get(h, []) as Array).size(), "rit_lines": 0, "reaction_lines": 0}
		for t in threads(h):
			v.threads += 1
			for n in t.get("nodes", {}).values():
				v.pills += (n.get("choices", []) as Array).size()
				for m in n.get("msgs", []):
					v.msgs += 1
					match str(m.get("k", "")):
						"photo":
							v.photos += 1
						"sticker":
							v.stickers += 1
						"voice":
							v.voices += 1
		for p in feed():
			if str(p.get("hero", "")) == h:
				v.feed += 1
		for g in V10W1SocialLines.RIT:
			v.rit_lines += rit_lines(g, h).size()
		for k in reactions().get(h, {}):
			v.reaction_lines += (reactions()[h][k] as Array).size()
		out[h] = v
	return out
