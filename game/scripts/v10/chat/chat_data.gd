class_name V10ChatData
extends RefCounted

# 0.10 «Телефон» — data layer of the heroine chat (docs/0.10-spec.md §Р8, §Р9).
# Everything here is static and pure: it loads the JSON under res://data/v10/chat/, caches it and answers lookups.
# Source of the threads is the DSL in data/v10/chat/src/<hero>.chat, compiled by scripts/v10/chat/tools/build_chat.py
# into data/v10/chat/threads_<hero>.json (the JSON is what ships and what a server would send later).
#
# Thread JSON:
#   {id, hero, trigger, level, title, start, nodes:{name:{msgs:[…], choices:[…]?, next:"…"?, end:true?}},
#    outfit?, need?, repeat?}
#   msg:    {k:"text", t} | {k:"photo", img:"outfits/mc_cafe", t?} | {k:"sticker", id} | {k:"voice", sec, t}
#   choice: {t, next, aff?, set?} | {sticker, next, aff?, set?}
#   tokens in texts: {name} {name_voc} {combo} {rank} {days} {outfit} and {g:male|female} for player-gendered forms.

const DIR: = "res://data/v10/chat/"
const HEROES: = ["mc", "rin", "hana", "yue", "nova"]
const HERO_NAME: = {"mc": "Маджонг-тян", "rin": "Рин", "hana": "Хана", "yue": "Юэ", "nova": "Нова"}

# trigger kinds: one "daily" ladder (gated by affection level) and the game events
const TRIGGERS: = ["daily", "first_win", "combo_record", "rank_up", "comeback", "birthday", "outfit"]
const EVENT_TRIGGERS: = ["first_win", "combo_record", "rank_up", "comeback", "birthday", "outfit"]

# owner bar / store compliance limits
const MAX_BUBBLE: = 220        # heroine text bubble
const MAX_CHOICE: = 46         # reply pill
const MAX_CAPTION: = 120       # photo caption
const MAX_TITLE: = 32          # thread title in the list
const MAX_FEED: = 280          # feed post caption (§Р9)
const MAX_COMMENT: = 140       # feed comment / reply
const MAX_REACT_LINE: = 120    # her answer to a reaction / sticker
const MIN_MSGS: = 4            # heroine messages on the shortest path of a thread
const MAX_MSGS: = 16           # heroine messages on the longest path
const MAX_THREAD_AFF: = 5      # completion +3 plus choice bonuses on any path
const DONE_AFF: = 3            # completed thread (soft source, §2.4)

# photos must be safe for every build (§2.7: sfw=false at h_beach, h_gym, y_duel, n_ssr; o_tutor is retired)
const PHOTO_DENY: = ["outfits/hana_beach", "outfits/hana_gym", "outfits/yue_duel", "outfits/nova_ssr", "outfits/mc_tutor"]

# V10Lint.BANNED (§2.7) + the 0.9 red-line list; substrings, case-insensitive. Checked on every heroine-facing string.
const BANNED: = ["скуча", "одна", "обещал", "пропал", "забыл", "почему ты", "бросил", "вернись", "₽", "скидк", "успей",
	"последн", "только сегодня", "купи", "баннер", "акци", "цена", "бесплатн", "руб.", "рубл", "донат", "призыв",
	"учител", "ученик", "урок", "школ", "за парт", "куда смотришь", "колен", "грудь", "бёдр", "бедр", "вино", "пиво",
	"алкогол", "раздев", "бельё", "белье"]

static var _cache: = {}


static func _load(file: String) -> Variant:
	if _cache.has(file):
		return _cache[file]
	var path: = DIR + file
	var v: Variant = null
	if FileAccess.file_exists(path):
		v = JSON.parse_string(FileAccess.get_file_as_string(path))
	_cache[file] = v
	return v


static func reload() -> void:
	_cache.clear()


# --- threads ---------------------------------------------------------------

static func hero_file(hero: String) -> Dictionary:
	var d: Variant = _load("threads_%s.json" % hero)
	return d if d is Dictionary else {}


static func threads(hero: String) -> Array:
	return hero_file(hero).get("threads", [])


static func all_threads() -> Array:
	var out: = []
	for h in HEROES:
		out.append_array(threads(h))
	return out


static func thread(tid: String) -> Dictionary:
	var idx: Dictionary = _cache.get("#idx", {})
	if idx.is_empty():
		for t in all_threads():
			idx[t.id] = t
		_cache["#idx"] = idx
	return idx.get(tid, {})


static func hero_of(tid: String) -> String:
	return str(thread(tid).get("hero", ""))


# --- stickers, reactions, feed, meta ---------------------------------------

static func meta() -> Dictionary:
	var d: Variant = _load("meta.json")
	return d if d is Dictionary else {}


static func stickers() -> Dictionary:
	var d: Variant = _load("stickers.json")
	return d if d is Dictionary else {}


static func sticker(id: String) -> Dictionary:
	for s in stickers().get("common", []):
		if s.id == id:
			return s
	for h in HEROES:
		for s in stickers().get(h, []):
			if s.id == id:
				return s
	return {}


static func reactions() -> Dictionary:
	var d: Variant = _load("reactions.json")
	return d if d is Dictionary else {}


static func feed() -> Array:
	var d: Variant = _load("feed.json")
	return d.get("posts", []) if d is Dictionary else []


static func birthday(hero: String) -> String:
	return str(meta().get("birthdays", {}).get(hero, ""))


# photo id "outfits/mc_cafe" → an existing texture path (webp or png) or ""
static func photo_path(img: String) -> String:
	for ext in [".webp", ".png", ".jpg"]:
		var p: String = "res://assets/" + img + ext
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			return p
	return ""


static func lint(text: String) -> Array:
	var lo: = text.to_lower()
	var hits: = []
	for w in BANNED:
		if lo.contains(w):
			hits.append(w)
	return hits
