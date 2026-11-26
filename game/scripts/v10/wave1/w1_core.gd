class_name V10W1Core
extends RefCounted

# V10W1Core — wave 1 of the roster (docs/ROSTER_20.md §2, §3.2–3.4): Цубамэ, Миэль, Кохаку, Ширин, Злата.
# Pure data + small static helpers, no state of the player. NOTHING here is gated: the facade V10Wave1 decides when the
# five are released and then merges these rows into the founders' tables (hooks in the lane README / core report).
#
# DATA (the founders' schema, copied 1:1)
#   V10W1Core.HEROES / HERO_ORDER          G.HEROES rows {name, title, age, job, color} and the order after the founders
#   V10W1Core.ITEMS                        18 outfits in the G.ITEMS schema {id, cat, hero, rar, name, img, +flags}
#                                          (img == id; R/SR/SSR = ranks A/S/SSR 1:1, ROSTER §1.1)
#   V10W1Core.BASE_OUTFITS                 the five base outfits (join G.BASE_OUTFITS: «base» = the rigged art is shown)
#   V10W1Core.FACTS                        fixed facts per goddess: rank, element, signature tile, palette, birthday
#   V10W1Core.VOW_AFF                      «Обет» outfits -> the Симпатия level that grants them (never pulled, never sold)
#   V10W1Core.STAGE_BG                     Гардероб backdrop per goddess (assets/bg names, like collection.gd STAGE_BG)
#   V10W1Core.POSE_SLOTS / EMOTIONS        base-outfit pose slots and emotion portraits the art set carries
#
# ART (game/assets/v10/wave1/**, measured data in data/*.json — read once at runtime, cached)
#   outfit_tex_path(img) / hero_tex_path(h) / emotion_path(h, emo) / pose_path(h, slot)   wave-1 files only
#   outfit_webp(img) / hero_png(h) / emotion_webp(h, emo)   ANY id: the founders' exact path for a founder id, the
#                                          wave-1 path for a wave-1 id — what a hooked consumer calls instead of its own
#                                          "res://assets/…%s…" literal (founders stay byte-identical)
#   rigs() / rig(h)                        Hero.RIGS rows (Vector2/Vector3/Vector4/Color/float, the founders' types)
#   emo_face() / emo_face_w() / rig_face_w()   V8Art.EMO_FACE / EMO_FACE_W / RIG_FACE_W rows
#   outfit_rect(id, "face_rect"|"alt_rect") / outfit_face(img) / pose_face_rect(h, slot)
#
# MERGE (called by the facade, idempotent; both return problems, [] = done)
#   merge_g(g)      G.HEROES, G.HERO_ORDER, G.ITEMS, G.ITEM, G.BASE_OUTFITS (needs hook H1: those three consts -> var)
#   merge_art()     Hero.RIGS, V8Art.EMO_FACE / EMO_FACE_W / RIG_FACE_W (needs hooks H3/H4: consts -> static var);
#                   also lists incomplete measured rig data
#   sanitize_save(S, heroes) -> int        a save that points at a wave-1 goddess while she is not in `heroes`
#                                          (wave 1 switched off) falls back to «mc»; founders' saves are never touched
#
# SELFTEST
#   selfcheck(files = true) -> Array       failure strings ([] = all good): schema, ids, ranks, flags, texts (V10Lint),
#                                          agreement with V10KitData / V10ProfileCos, art files, rig and face tables

const ROOT: = "res://assets/v10/wave1/"
const CARDS_JSON: = "res://scripts/v10/wave1/data/w1_art_cards.json"
const RIG_JSON: = "res://scripts/v10/wave1/data/w1_art_rig.json"

const FOUNDERS: = ["mc", "rin", "hana", "yue", "nova"]

# ------------------------------------------------------------------ heroes (G.HEROES schema)
# color = the name colour on dark UI: the first palette hex, except Цубамэ (her first hex is the night indigo) and
# Миэль (her first hex is cream) — they take their accent.
const HERO_ORDER: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]

const HEROES: = {
	"tsubame": {"name": "Цубамэ", "title": "Курьер миров, 24 года", "age": "24 года", "job": "куноити-курьер гильдии «Ночные ласточки», носит письма между мирами", "color": Color("c8283c")},
	"miel": {"name": "Миэль", "title": "Кондитер, 25 лет", "age": "25 лет", "job": "кондитер западной улицы, хозяйка кондитерской «Мёд и пар»", "color": Color("e0566f")},
	"kohaku": {"name": "Кохаку", "title": "Лиса-жрица, на вид 25", "age": "на вид 25 (лисе 900 лет)", "job": "белая лиса-жрица храма Тысячи врат", "color": Color("f3efe9")},
	"shirin": {"name": "Ширин", "title": "Танцовщица, 26 лет", "age": "26 лет", "job": "танцовщица и гадалка каравана «Семь колодцев»", "color": Color("d9b26f")},
	"zlata": {"name": "Злата", "title": "Царевна весны, 25 лет", "age": "25 лет", "job": "царевна Жар-птица из сказочного царства", "color": Color("c3242b")},
}

# fixed facts (ROSTER §2 table; sig = G.TILE_NAMES index, same as V10KitData.KITS[h].sig; bday "MM-DD", spec Р6)
const FACTS: = {
	"tsubame": {"rank": "A", "element": "тень и дым", "sig": 1, "sig_tile": "plum", "palette": ["1d1b2e", "c8283c", "a9b0c2"], "bday": "05-20", "base": "tb_base"},
	"miel": {"rank": "A", "element": "сахар", "sig": 16, "sig_tile": "cake", "palette": ["f6e7cf", "c98a4b", "e0566f"], "bday": "02-27", "base": "me_base"},
	"kohaku": {"rank": "S", "element": "лисий огонь", "sig": 31, "sig_tile": "fox", "palette": ["f3efe9", "d63a2a", "e2a23d"], "bday": "04-27", "base": "ko_base"},
	"shirin": {"rank": "S", "element": "песок и солнце", "sig": 9, "sig_tile": "sun", "palette": ["d9b26f", "1f8f8a", "c08a1e"], "bday": "08-27", "base": "sh_base"},
	"zlata": {"rank": "SSR", "element": "жар-птица и весна", "sig": 12, "sig_tile": "fire", "palette": ["c3242b", "e8b23a", "1b1513"], "bday": "03-18", "base": "zl_base"},
}

# heroine rank -> `rar` of her base outfit (ROSTER §1.1: R→A, SR→S, SSR→SSR)
const RAR_OF_RANK: = {"A": "R", "S": "SR", "SSR": "SSR"}
const RANK_OF_RAR: = {"R": "A", "SR": "S", "SSR": "SSR"}

# ------------------------------------------------------------------ outfits (G.ITEMS schema)
# Flags exactly as the founders use them:
#   shop: <кристаллы> + nogacha   the S goddesses' everyday A outfit («повседневный, магазин», ROSTER §1.2);
#                                 480 = an A price on the Лавка ladder (founders: S 680, SSR 1280)
#   nogacha (alone)               «Обет» outfits: granted at Симпатия 10 (VOW_AFF), never in a wish pool, never sold
#   bold + sfw:false + alt        ko_kyubi only (strapless + slit to the hip with the ofuda band showing: the y_duel
#                                 class of the founders); the modest preset / photos / posters / feed draw `alt`
# No `pass` item: the season pass prize is picked per season by the economy lane (V10Catalog «@season_outfit»).
const ITEMS: = [
	{"id": "tb_base", "cat": "outfit", "hero": "tsubame", "rar": "R", "rank": "A", "name": "Ночная ласточка", "img": "tb_base", "sfw": true, "lw": "LW33"},
	{"id": "tb_post", "cat": "outfit", "hero": "tsubame", "rar": "SR", "rank": "S", "name": "Почта сквозь миры", "img": "tb_post", "sfw": true, "lw": "LW34"},
	{"id": "tb_crimson", "cat": "outfit", "hero": "tsubame", "rar": "SSR", "rank": "SSR", "name": "Алая луна клана", "img": "tb_crimson", "sfw": true, "lw": "LW35"},
	{"id": "me_base", "cat": "outfit", "hero": "miel", "rar": "R", "rank": "A", "name": "Утренняя выпечка", "img": "me_base", "sfw": true, "lw": "LW36"},
	{"id": "me_parlor", "cat": "outfit", "hero": "miel", "rar": "SR", "rank": "S", "name": "Салон «Мёд»", "img": "me_parlor", "sfw": true, "lw": "LW37"},
	{"id": "me_gala", "cat": "outfit", "hero": "miel", "rar": "SSR", "rank": "SSR", "name": "Сахарный бал", "img": "me_gala", "sfw": true, "lw": "LW38"},
	{"id": "ko_base", "cat": "outfit", "hero": "kohaku", "rar": "SR", "rank": "S", "name": "Жрица тысячи врат", "img": "ko_base", "sfw": true, "lw": "LW48"},
	{"id": "ko_matsuri", "cat": "outfit", "hero": "kohaku", "rar": "R", "rank": "A", "name": "Ночной мацури", "img": "ko_matsuri", "sfw": true, "lw": "LW49", "shop": 480, "nogacha": true},
	{"id": "ko_kyubi", "cat": "outfit", "hero": "kohaku", "rar": "SSR", "rank": "SSR", "name": "Девятихвостая", "img": "ko_kyubi", "bold": true, "sfw": false, "alt": "ko_matsuri", "lw": "LW50"},
	{"id": "ko_vow", "cat": "outfit", "hero": "kohaku", "rar": "SSR", "rank": "SSR", "name": "Обет лисьей свадьбы", "img": "ko_vow", "sfw": true, "lw": "LW51", "nogacha": true},
	{"id": "sh_base", "cat": "outfit", "hero": "shirin", "rar": "SR", "rank": "S", "name": "Танец семи колодцев", "img": "sh_base", "sfw": true, "lw": "LW52"},
	{"id": "sh_oasis", "cat": "outfit", "hero": "shirin", "rar": "R", "rank": "A", "name": "Оазис", "img": "sh_oasis", "sfw": true, "lw": "LW53", "shop": 480, "nogacha": true},
	{"id": "sh_sun", "cat": "outfit", "hero": "shirin", "rar": "SSR", "rank": "SSR", "name": "Дочь полуденного солнца", "img": "sh_sun", "sfw": true, "lw": "LW54"},
	{"id": "sh_night", "cat": "outfit", "hero": "shirin", "rar": "SSR", "rank": "SSR", "name": "Тысяча и одна партия", "img": "sh_night", "sfw": true, "lw": "LW55"},
	{"id": "zl_base", "cat": "outfit", "hero": "zlata", "rar": "SSR", "rank": "SSR", "name": "Жар-птица", "img": "zl_base", "sfw": true, "lw": "LW68"},
	{"id": "zl_fair", "cat": "outfit", "hero": "zlata", "rar": "SR", "rank": "S", "name": "Масленичная ярмарка", "img": "zl_fair", "sfw": true, "lw": "LW69"},
	{"id": "zl_ember", "cat": "outfit", "hero": "zlata", "rar": "SSR", "rank": "SSR", "name": "Царица-пламя", "img": "zl_ember", "sfw": true, "lw": "LW70"},
	{"id": "zl_vow", "cat": "outfit", "hero": "zlata", "rar": "SSR", "rank": "SSR", "name": "Обет Жар-птицы", "img": "zl_vow", "sfw": true, "lw": "LW71", "nogacha": true},
]

# Legwear metadata (docs/LEGWEAR.md §3.1, §3.2): unique LW code, RU/EN names, rank, heroine and sfw flag per outfit
const LEGWEAR: = {
	"tb_base": {"code": "LW33", "hero": "tsubame", "rank": "A", "ru": "Ласточка", "en": "Swallow Print", "sfw": true},
	"tb_post": {"code": "LW34", "hero": "tsubame", "rank": "S", "ru": "Лента почтальона", "en": "Courier Side-Lacing", "sfw": true},
	"tb_crimson": {"code": "LW35", "hero": "tsubame", "rank": "SSR", "ru": "Сасико клана", "en": "Sashiko Clan Mark", "sfw": true},
	"me_base": {"code": "LW36", "hero": "miel", "rank": "A", "ru": "Карамельная лента", "en": "Caramel Ribbon", "sfw": true},
	"me_parlor": {"code": "LW37", "hero": "miel", "rank": "S", "ru": "Медовые соты", "en": "Dripping Honey", "sfw": true},
	"me_gala": {"code": "LW38", "hero": "miel", "rank": "SSR", "ru": "Безе", "en": "Meringue Ruffle", "sfw": true},
	"ko_base": {"code": "LW48", "hero": "kohaku", "rank": "S", "ru": "Бубенцы мико", "en": "Bell-Bow Thigh-Highs", "sfw": true},
	"ko_matsuri": {"code": "LW49", "hero": "kohaku", "rank": "A", "ru": "Лисьи огни", "en": "Fox-Fire Knee Socks", "sfw": true},
	"ko_kyubi": {"code": "LW50", "hero": "kohaku", "rank": "SSR", "ru": "Офуда", "en": "Ofuda Band", "sfw": false},
	"ko_vow": {"code": "LW51", "hero": "kohaku", "rank": "SSR", "ru": "Красная нить", "en": "Red Thread", "sfw": true},
	"sh_base": {"code": "LW52", "hero": "shirin", "rank": "S", "ru": "Пайал", "en": "Coin Payal", "sfw": true},
	"sh_oasis": {"code": "LW53", "hero": "shirin", "rank": "A", "ru": "Базарные манжеты", "en": "Embroidered Cuffs", "sfw": true},
	"sh_sun": {"code": "LW54", "hero": "shirin", "rank": "SSR", "ru": "Мехенди-стремя", "en": "Henna Stirrup", "sfw": true},
	"sh_night": {"code": "LW55", "hero": "shirin", "rank": "SSR", "ru": "Звёздный арабеск", "en": "Star Arabesque", "sfw": true},
	"zl_base": {"code": "LW68", "hero": "zlata", "rank": "SSR", "ru": "Золотая роспись", "en": "Gold-Thread Firebird", "sfw": true},
	"zl_fair": {"code": "LW69", "hero": "zlata", "rank": "S", "ru": "Ярмарочная вышивка", "en": "Cross-Stitch Ribbon Ties", "sfw": true},
	"zl_ember": {"code": "LW70", "hero": "zlata", "rank": "SSR", "ru": "Тлеющий шов", "en": "Ember Seam", "sfw": true},
	"zl_vow": {"code": "LW71", "hero": "zlata", "rank": "SSR", "ru": "Кокошник", "en": "Gold-Sheen Vow", "sfw": true},
}

const BASE_OUTFITS: = ["tb_base", "me_base", "ko_base", "sh_base", "zl_base"]
const VOW_AFF: = {"ko_vow": 10, "zl_vow": 10}
const SHOP_PRICES: = [480, 680, 1280]

# Гардероб backdrop (Common.backdrop names; the goddesses' own tables arrive with the look lane): night roofs,
# the quarter's pastry street, the torii shrine, warm lanterns for the caravan, the salon's spring window for Злата
const STAGE_BG: = {"tsubame": "bg_rooftop", "miel": "bg_street", "kohaku": "bg_shrine", "shirin": "bg_festival", "zlata": "menu"}

const EMOTIONS: = ["happy", "sad", "surprised", "pout", "shy"]
# base-outfit pose slots in the art set (w1src/<hero>__<base>__<slot>.png); data/w1_art_cards.json «poses» wins when present
const POSE_SLOTS: = {
	"tsubame": ["select", "shy", "win"],
	"miel": ["select", "tease", "lose"],
	"kohaku": ["select", "shy", "win"],
	"shirin": ["select", "shy"],
	"zlata": ["select", "win", "lose"],
}

# Hero.RIGS keys: the shader gets every one of RIG_KEYS (hero.gd setup), the optional ones only when present
const RIG_KEYS: = ["head_c", "head_r", "neck", "chest_c", "chest_r", "waist_y", "feet", "hair_l", "hair_r", "eye_l", "eye_r", "mouth", "lash"]
const RIG_V2: = ["head_c", "neck", "chest_c", "chest_r", "feet", "lid_tilt"]
const RIG_V4: = ["hair_l", "hair_r", "eye_l", "eye_r", "mouth", "lid_l", "lid_r"]
const RIG_F: = ["head_r", "waist_y", "zoom_k"]
# a key that may be missing without a problem (founders without hair sway carry zeros)
const RIG_ZERO_OK: = ["hair_l", "hair_r"]
# the shader's own defaults (shaders/hero.gdshader) for a key the rig file lacks — drawn, but reported by rig_problems()
const RIG_DEFAULT: = {"head_c": Vector2(424, 200), "head_r": 115.0, "neck": Vector2(424, 290), "chest_c": Vector2(430, 400),
	"chest_r": Vector2(110, 80), "waist_y": 600.0, "feet": Vector2(424, 1240), "hair_l": Vector4(0, 0, 0, 0),
	"hair_r": Vector4(0, 0, 0, 0), "eye_l": Vector4(397, 215, 14, 8), "eye_r": Vector4(452, 215, 14, 8),
	"mouth": Vector4(424, 258, 0, 8), "lash": Color(0.25, 0.12, 0.12)}
const ART_W: = 848.0
const ART_H: = 1264.0
const OUTFIT_SIZE: = Vector2(850, 1280)
const EMO_SIZE: = Vector2(600, 800)
# eye distance -> face width (cheek to cheek) on the rigged art: the formula V8Art's mc / hana numbers were measured with
const FACE_W_PER_EYES: = 1.75

static var _json_cache: = {}
static var _rigs: = {}
static var _rig_problems: = []
static var _cards_done: = false
static var _emo_face: = {}
static var _emo_face_w: = {}
static var _outfits: = {}
static var _poses: = {}
static var _ids: = {}


# ------------------------------------------------------------------ lookups

static func is_wave1_hero(id: String) -> bool:
	return HEROES.has(id)


static func is_wave1_item(id: String) -> bool:
	_index()
	return _ids.has(id)


# outfit art id (G.ITEM.img / .alt): wave-1 art ids are the outfit ids
static func is_wave1_img(img: String) -> bool:
	return is_wave1_item(img)


static func _index() -> void:
	if not _ids.is_empty():
		return
	for i in ITEMS.size():
		_ids[String(ITEMS[i].id)] = i


static func hero(h: String) -> Dictionary:
	return HEROES.get(h, {})


static func facts(h: String) -> Dictionary:
	return FACTS.get(h, {})


# the item row (read-only const) or {}
static func item(id: String) -> Dictionary:
	_index()
	return ITEMS[_ids[id]] if _ids.has(id) else {}


# writable deep copies, ready to be appended to G.ITEMS (a const row is read-only)
static func items_copy() -> Array:
	var out: = []
	for it in ITEMS:
		out.append((it as Dictionary).duplicate(true))
	return out


static func outfits_of(h: String) -> Array:
	return ITEMS.filter(func(x): return String(x.hero) == h).map(func(x): return String(x.id))


static func base_of(h: String) -> String:
	return String(FACTS.get(h, {}).get("base", ""))


static func hero_of_img(img: String) -> String:
	return String(item(img).get("hero", ""))


# Симпатия level that grants an «Обет» outfit; 0 = not a vow
static func vow_level(id: String) -> int:
	return int(VOW_AFF.get(id, 0))


static func legwear(id: String) -> Dictionary:
	return LEGWEAR.get(id, {})


static func outfit_rank(id: String) -> String:
	var it: = item(id)
	return String(it.get("rank", RANK_OF_RAR.get(String(it.get("rar", "")), "")))


static func stage_bg(h: String) -> String:
	return String(STAGE_BG.get(h, "menu"))


static func palette(h: String) -> Array:
	var out: = []
	for c in FACTS.get(h, {}).get("palette", []):
		out.append(Color(String(c)))
	return out


# ------------------------------------------------------------------ paths

static func outfit_tex_path(img: String) -> String:
	return ROOT + ("outfits/%s.webp" % img)


static func hero_tex_path(h: String) -> String:
	return ROOT + ("hero/%s.png" % h)


static func emotion_path(h: String, emo: String) -> String:
	return ROOT + ("emotions/%s_%s.webp" % [h, emo])


static func pose_path(h: String, slot: String) -> String:
	return ROOT + ("poses/%s_%s.webp" % [h, slot])


# any hero id -> her rigged full-body art (founders: assets/hero/<id>.png, unchanged)
static func hero_png(h: String) -> String:
	return hero_tex_path(h) if is_wave1_hero(h) else "res://assets/hero/%s.png" % h


# any outfit art id -> its card art (founders: assets/outfits/<img>.webp, unchanged)
static func outfit_webp(img: String) -> String:
	return outfit_tex_path(img) if is_wave1_img(img) else "res://assets/outfits/%s.webp" % img


# any hero + a normalised emotion name -> the emotion portrait (founders: assets/v08/emotions, unchanged)
static func emotion_webp(h: String, emo: String) -> String:
	return emotion_path(h, emo) if is_wave1_hero(h) else "res://assets/v08/emotions/%s_%s.webp" % [h, emo]


static func has_pose(h: String, slot: String) -> bool:
	return ResourceLoader.exists(pose_path(h, slot))


# pose slots of her base outfit: the measured list (data/w1_art_cards.json) when present, else POSE_SLOTS
static func poses(h: String) -> Array:
	_cards()
	var out: = []
	for k in _poses:
		if String(k).get_slice("_", 0) == h:
			out.append(String(k).substr(h.length() + 1))
	return out if not out.is_empty() else (POSE_SLOTS.get(h, []) as Array).duplicate()


# ------------------------------------------------------------------ measured data (JSON, read once)

static func _json(path: String) -> Dictionary:
	if _json_cache.has(path):
		return _json_cache[path]
	var d: = {}
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			d = parsed
		else:
			push_warning("V10W1Core: %s is not a JSON object" % path)
	_json_cache[path] = d
	return d


# forget the cached JSON and the tables built from it (dev tools re-measuring art; tests)
static func reload() -> void:
	_json_cache.clear()
	_rigs.clear()
	_rig_problems.clear()
	_cards_done = false
	_emo_face.clear()
	_emo_face_w.clear()
	_outfits.clear()
	_poses.clear()


static func _v2(a, d: Vector2) -> Vector2:
	if a is Vector2:
		return a
	if a is Array and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return d


static func _v3(a, d: Vector3) -> Vector3:
	if a is Vector3:
		return a
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return d


static func _v4(a, d: Vector4) -> Vector4:
	if a is Vector4:
		return a
	if a is Array and a.size() >= 4:
		return Vector4(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return d


static func _col(a, d: Color) -> Color:
	if a is Color:
		return a
	if a is String:
		var s: = String(a).strip_edges().trim_prefix("#")
		if s != "" and Color.html_is_valid(s):
			return Color(s)
	if a is Array and a.size() >= 3:
		var k: = 255.0 if (float(a[0]) > 1.0 or float(a[1]) > 1.0 or float(a[2]) > 1.0) else 1.0
		return Color(float(a[0]) / k, float(a[1]) / k, float(a[2]) / k)
	return d


static func _rect(a) -> Rect2:
	if a is Rect2:
		return a
	if a is Array and a.size() >= 4:
		return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return Rect2()


# one Hero.RIGS row from data/w1_art_rig.json {<hero>: {file, source, rig: {…}}} in the founders' types
static func _to_rig(h: String, src: Dictionary) -> Dictionary:
	var r: = {}
	for k in RIG_KEYS:
		if not src.has(k):
			r[k] = RIG_DEFAULT[k]
			if not (k in RIG_ZERO_OK):
				_rig_problems.append("%s: rig has no %s" % [h, k])
			continue
		var v = src[k]
		if k in RIG_V2:
			r[k] = _v2(v, RIG_DEFAULT[k])
		elif k in RIG_V4:
			r[k] = _v4(v, RIG_DEFAULT[k])
		elif k in RIG_F:
			r[k] = float(v)
		elif k == "lash":
			r[k] = _col(v, RIG_DEFAULT.lash)
	for k in ["lid_l", "lid_r"]:
		if src.has(k):
			r[k] = _v4(src[k], Vector4.ZERO)
	if src.has("lid_tilt"):
		r["lid_tilt"] = _v2(src.lid_tilt, Vector2.ZERO)
	if src.has("av"):
		r["av"] = _v3(src.av, Vector3(424, 200, 4.6))
	if src.has("zoom_k"):
		r["zoom_k"] = float(src.zoom_k)
	return r


static func rigs() -> Dictionary:
	if not _rigs.is_empty():
		return _rigs
	_rig_problems.clear()
	var data: = _json(RIG_JSON)
	if data.is_empty():
		_rig_problems.append("no rig data (%s)" % RIG_JSON)
	for h in HERO_ORDER:
		var e = data.get(h, {})
		var src: Dictionary = {}
		if e is Dictionary:
			src = e.get("rig", e) if e.get("rig") is Dictionary else e
		if src.is_empty():
			_rig_problems.append("%s: no rig" % h)
		_rigs[h] = _to_rig(h, src)
	return _rigs


static func rig(h: String) -> Dictionary:
	return rigs().get(h, {})


static func rig_problems() -> Array:
	rigs()
	return _rig_problems.duplicate()


# V8Art.RIG_FACE_W rows: face width on the rigged art — the rig file's "face_w", else 1.75 × the eye distance
static func rig_face_w() -> Dictionary:
	var out: = {}
	var data: = _json(RIG_JSON)
	for h in HERO_ORDER:
		var e = data.get(h, {})
		var src = e.get("rig", e) if e is Dictionary else {}
		if src is Dictionary and float(src.get("face_w", 0.0)) > 0.0:
			out[h] = float(src.face_w)
			continue
		var r: = rig(h)
		var el: Vector4 = r.eye_l
		var er: Vector4 = r.eye_r
		out[h] = snappedf(Vector2(el.x, el.y).distance_to(Vector2(er.x, er.y)) * FACE_W_PER_EYES, 0.5)
	return out


static func _cards() -> void:
	if _cards_done:
		return
	_cards_done = true
	var data: = _json(CARDS_JSON)
	var ems = data.get("emotions", {})
	if ems is Dictionary:
		for key in ems:
			var e = ems[key]
			var k: = String(key)
			var cut: = k.rfind("_")
			if cut <= 0 or not (e is Dictionary):
				continue
			var h: = k.substr(0, cut)
			var emo: = k.substr(cut + 1)
			if not is_wave1_hero(h):
				continue
			var sz: = _v2(e.get("size"), EMO_SIZE)
			var f: = _v2(e.get("face"), Vector2(-1, -1))
			if f.x < 0.0:
				continue
			# fractions of the file like V8Art.EMO_FACE; pixels are accepted and converted
			if f.x > 1.5 or f.y > 1.5:
				f = Vector2(f.x / maxf(1.0, sz.x), f.y / maxf(1.0, sz.y))
			if not _emo_face.has(h):
				_emo_face[h] = {}
				_emo_face_w[h] = {}
			_emo_face[h][emo] = [snappedf(f.x, 0.0001), snappedf(f.y, 0.0001)]
			if float(e.get("face_w", 0.0)) > 0.0:
				_emo_face_w[h][emo] = float(e.face_w)
	var ofs = data.get("outfits", {})
	if ofs is Dictionary:
		for key in ofs:
			if ofs[key] is Dictionary:
				_outfits[String(key)] = ofs[key]
	var pss = data.get("poses", {})
	if pss is Dictionary:
		for key in pss:
			if pss[key] is Dictionary:
				_poses[String(key)] = pss[key]


# V8Art.EMO_FACE rows {hero: {emo: [fx, fy]}} — only emotions the measured file lists
static func emo_face() -> Dictionary:
	_cards()
	return _emo_face


# V8Art.EMO_FACE_W rows {hero: {emo: px}} (the per-emotion form V8Art uses for mc / hana)
static func emo_face_w() -> Dictionary:
	_cards()
	return _emo_face_w


static func outfit_size(id: String) -> Vector2:
	_cards()
	return _v2(_outfits.get(id, {}).get("size"), OUTFIT_SIZE)


# measured rects on the outfit card art (V9Ults face_rect / alt_rect format, card pixels); Rect2() when unmeasured
static func outfit_rect(id: String, key: = "face_rect") -> Rect2:
	_cards()
	return _rect(_outfits.get(id, {}).get(key))


# round face crop of an outfit card in V8Population.FACES form [focus x, focus y, zoom] (Common.card_art): the face
# rect centre raised by 0.15 of its width, ≈0.68 of the rect across the circle — the ratio the founders' crops have
static func outfit_face(img: String) -> Array:
	var r: = outfit_rect(img, "face_rect")
	if r.size.x <= 0.0:
		return [0.5, 0.18, 4.6]
	var sz: = outfit_size(img)
	var c: = r.get_center()
	return [snappedf(c.x / sz.x, 0.001), snappedf((c.y - r.size.x * 0.15) / sz.y, 0.001), snappedf(sz.x / (r.size.x * 0.68), 0.01)]


static func pose_face_rect(h: String, slot: String) -> Rect2:
	_cards()
	return _rect(_poses.get("%s_%s" % [h, slot], {}).get("face_rect"))


# ------------------------------------------------------------------ merge (the facade calls these once released)

# G (the autoload node): append the five to HEROES / HERO_ORDER / BASE_OUTFITS and the 18 outfits to ITEMS + ITEM.
# Idempotent. Returns problems ([] = merged). Wave-1 rows go to the END of every table, so the founders' indices
# (G._hidden_items positions, gacha draw order of founders' items) do not move.
static func merge_g(g) -> Array:
	if g == null:
		return ["G is missing"]
	var probs: = []
	var heroes: Dictionary = g.HEROES
	var order: Array = g.HERO_ORDER
	var bases: Array = g.BASE_OUTFITS
	var items: Array = g.ITEMS
	var item_map: Dictionary = g.ITEM
	if heroes.is_read_only():
		probs.append("G.HEROES is still a const (hook H1)")
	if order.is_read_only():
		probs.append("G.HERO_ORDER is still a const (hook H1)")
	if bases.is_read_only():
		probs.append("G.BASE_OUTFITS is still a const (hook H1)")
	if not probs.is_empty():
		return probs
	for h in HERO_ORDER:
		if not heroes.has(h):
			heroes[h] = (HEROES[h] as Dictionary).duplicate(true)
		if not (h in order):
			order.append(h)
	for b in BASE_OUTFITS:
		if not (b in bases):
			bases.append(b)
	for it in items_copy():
		var id: = String(it.id)
		if item_map.has(id):
			if String(item_map[id].get("hero", "")) != String(it.hero):
				probs.append("item id %s already taken in G.ITEM" % id)
			continue
		items.append(it)
		item_map[id] = it
	return probs


# Hero.RIGS + V8Art face tables. Idempotent; a founder row is never replaced. Returns the problems: a table still
# const (hook missing) and incomplete measured rig data (rig_problems) — the merge itself still happens.
# Hero / V8Art are looked up by class name (no compile-time dependency: this file parse-checks without the autoloads).
static func merge_art() -> Array:
	var probs: = []
	var hs: = _script_of("Hero")
	var vs: = _script_of("V8Art")
	if hs == null or vs == null:
		return ["Hero / V8Art scripts not found"]
	var hr: Dictionary = hs.get("RIGS")
	var ef: Dictionary = vs.get("EMO_FACE")
	var efw: Dictionary = vs.get("EMO_FACE_W")
	var rfw: Dictionary = vs.get("RIG_FACE_W")
	if hr.is_read_only():
		probs.append("Hero.RIGS is still a const (hook H3)")
	else:
		var rr: = rigs()
		for h in rr:
			if not hr.has(h):
				hr[h] = rr[h]
	if ef.is_read_only() or efw.is_read_only() or rfw.is_read_only():
		probs.append("V8Art.EMO_FACE / EMO_FACE_W / RIG_FACE_W are still consts (hook H4)")
	else:
		var f: = emo_face()
		var fw: = emo_face_w()
		var rw: = rig_face_w()
		for h in HERO_ORDER:
			if f.has(h) and not ef.has(h):
				ef[h] = (f[h] as Dictionary).duplicate(true)
			if fw.has(h) and not efw.has(h):
				efw[h] = (fw[h] as Dictionary).duplicate(true)
			if rw.has(h) and not rfw.has(h):
				rfw[h] = rw[h]
	return probs + rig_problems()


# a save written while wave 1 was on, loaded while it is off: the pointers at her fall back to the founders'
# defaults (G would index G.HEROES with them). Only wave-1 ids are touched. Returns how many fields were reset.
static func sanitize_save(S: Dictionary, heroes: Dictionary) -> int:
	var n: = 0
	for k in ["partner", "level_partner"]:
		var h: = String(S.get(k, ""))
		if is_wave1_hero(h) and not heroes.has(h):
			S[k] = "mc"
			n += 1
	var p = S.get("profile")
	if p is Dictionary:
		var a: = String(p.get("avatar", ""))
		if is_wave1_hero(a) and not heroes.has(a):
			p["avatar"] = "mc"
			n += 1
	return n


# ------------------------------------------------------------------ selftest

static func _cyr(t: String) -> bool:
	for ch in t:
		var c: = ch.unicode_at(0)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			return false
	return t.strip_edges() != ""


static func _script_of(cn: String) -> Script:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == cn:
			return load(String(c.path)) as Script
	return null


static func _const_of(cn: String, name: String):
	var s: = _script_of(cn)
	return s.get_script_constant_map().get(name) if s else null


# the one stop-word list V10Lint.BANNED (docs/0.10-spec.md §2.7; its ALLOW list lets «Тысяча и одна партия» through);
# without the lint lane the check cannot run and says so
static func _lint(t: String) -> Array:
	var s: = _script_of("V10Lint")
	if s == null:
		return ["V10Lint missing"]
	var bad: Array = s.call("check", t)
	for u in s.call("ui_check", t):
		if not (u in bad):
			bad.append(u)
	return bad


# every check the wave-1 core data must pass; `files` also checks the art on disk and the measured JSON tables
static func selfcheck(files: = true) -> Array:
	var fails: = []
	var ck: = func(ok: bool, what: String) -> void:
		if not ok:
			fails.append(what)
	var g = _g()
	var tiles: Array = ["sakura", "plum", "chrysanthemum", "sunflower", "tulip", "clover", "maple", "moon", "star", "sun",
		"rainbow", "snowflake", "fire", "water", "lightning", "dango", "cake", "strawberry", "peach", "cherry", "lemon",
		"matcha", "bubbletea", "bow", "diamond", "crown", "bell", "windchime", "lantern", "cat", "rabbit", "fox"]
	if g != null:
		tiles = g.TILE_NAMES
	# heroes
	ck.call(HERO_ORDER.size() == 5 and HEROES.size() == 5, "five heroes")
	for h in HERO_ORDER:
		ck.call(HEROES.has(h) and FACTS.has(h), "%s has a row and facts" % h)
		ck.call(not (h in FOUNDERS), "%s is not a founder id" % h)
		var e: Dictionary = HEROES.get(h, {})
		for k in ["name", "title", "age", "job", "color"]:
			ck.call(e.has(k), "%s.%s" % [h, k])
		ck.call(e.get("color") is Color, "%s.color is a Color" % h)
		var fc: Dictionary = FACTS.get(h, {})
		var want: = String(fc.get("palette", ["", "", ""])[0])
		if h == "tsubame":
			want = "c8283c"
		elif h == "miel":
			want = "e0566f"
		ck.call(e.get("color", Color()) == Color(want), "%s.color = %s" % [h, want])
		ck.call(String(e.get("title", "")).ends_with(String(e.get("age", "")).get_slice(" (", 0)), "%s title ends with her age" % h)
		for k in ["name", "title", "age", "job"]:
			var t: = String(e.get(k, ""))
			ck.call(_cyr(t), "%s.%s is Russian" % [h, k])
			ck.call(_lint(t).is_empty(), "%s.%s passes V10Lint: %s" % [h, k, str(_lint(t))])
		ck.call(fc.get("rank", "") in RAR_OF_RANK, "%s rank" % h)
		var sig: = int(fc.get("sig", -1))
		ck.call(sig >= 0 and sig < tiles.size() and String(tiles[sig]) == String(fc.get("sig_tile", "")), "%s signature tile %d" % [h, sig])
		var bd: = String(fc.get("bday", ""))
		ck.call(bd.length() == 5 and bd[2] == "-" and int(bd.substr(0, 2)) in range(1, 13) and int(bd.substr(3)) in range(1, 32), "%s birthday" % h)
		ck.call(STAGE_BG.has(h) and ResourceLoader.exists("res://assets/bg/%s.webp" % STAGE_BG.get(h, "")), "%s Гардероб backdrop" % h)
		# one base outfit per goddess, of her own rank (ROSTER §1.2), listed in BASE_OUTFITS
		var bases: = ITEMS.filter(func(x): return String(x.hero) == h and String(x.id) in BASE_OUTFITS)
		ck.call(bases.size() == 1 and String(bases[0].id) == base_of(h), "%s has one base outfit" % h)
		if bases.size() == 1:
			ck.call(String(bases[0].rar) == String(RAR_OF_RANK.get(fc.get("rank", ""), "")), "%s base rank = her rank" % h)
		var n_out: = outfits_of(h).size()
		ck.call(n_out >= 3 and n_out <= 4, "%s has 3–4 outfits" % h)
	# outfits
	ck.call(ITEMS.size() == 18, "18 outfits")
	var seen: = {}
	for it in ITEMS:
		var id: = String(it.get("id", ""))
		ck.call(not seen.has(id), "outfit id %s unique" % id)
		seen[id] = true
		for k in ["id", "cat", "hero", "rar", "rank", "name", "img", "sfw", "lw"]:
			ck.call(it.has(k), "%s.%s" % [id, k])
		ck.call(String(it.get("cat", "")) == "outfit", "%s is an outfit" % id)
		ck.call(HEROES.has(String(it.get("hero", ""))), "%s hero" % id)
		ck.call(String(it.get("rar", "")) in RANK_OF_RAR, "%s rar" % id)
		ck.call(String(it.get("rank", "")) == String(RANK_OF_RAR.get(String(it.get("rar", "")), "")), "%s rank matches rar" % id)
		var lw: Dictionary = LEGWEAR.get(id, {})
		ck.call(not lw.is_empty() and String(lw.get("code", "")) == String(it.get("lw", "")) and String(lw.get("hero", "")) == String(it.get("hero", "")) and String(lw.get("rank", "")) == String(it.get("rank", "")) and bool(lw.get("sfw", true)) == bool(it.get("sfw", true)), "%s legwear LW metadata matches" % id)
		ck.call(_cyr(String(lw.get("ru", ""))) and _lint(String(lw.get("ru", ""))).is_empty(), "%s legwear RU name clean" % id)
		ck.call(String(it.get("img", "")) == id, "%s img = id" % id)
		ck.call(not it.get("start", false) and not it.get("hidden", false), "%s is neither start nor hidden" % id)
		var nm: = String(it.get("name", ""))
		ck.call(_cyr(nm) and nm.length() <= 24, "%s name Russian, ≤ 24" % id)
		ck.call(_lint(nm).is_empty(), "%s name passes V10Lint" % id)
		if it.has("shop"):
			ck.call(int(it.shop) in SHOP_PRICES and it.get("nogacha", false), "%s shop price + nogacha" % id)
		if VOW_AFF.has(id):
			ck.call(it.get("nogacha", false) and not it.has("shop") and not it.get("pass", false) and String(it.rar) == "SSR", "%s vow: SSR, nogacha, never sold" % id)
		if it.get("sfw", true) == false or it.get("bold", false):
			var alt: = item(String(it.get("alt", "")))
			ck.call(it.get("bold", false) and it.get("sfw", true) == false, "%s bold ⇔ sfw:false" % id)
			ck.call(not alt.is_empty() and String(alt.hero) == String(it.hero) and alt.get("sfw", true) != false, "%s alt is a safe outfit of hers" % id)
	for id in VOW_AFF:
		ck.call(seen.has(id) and int(VOW_AFF[id]) == 10, "vow %s at Симпатия 10" % id)
	for b in BASE_OUTFITS:
		ck.call(seen.has(b), "base %s exists" % b)
	# no clash with the founders' items (and the game's whole ITEM table when G is up)
	if g != null:
		var gm: Dictionary = g.ITEM
		for id in seen:
			ck.call(not gm.has(id) or String(gm[id].get("hero", "")) == String(item(id).hero), "outfit id %s free in G.ITEM" % id)
		for h in HERO_ORDER:
			var gh: Dictionary = g.HEROES
			ck.call(not gh.has(h) or String(gh[h].name) == String(HEROES[h].name), "G.HEROES.%s is ours" % h)
	# agreement with the lanes that already carry wave-1 stubs
	var kits = _const_of("V10KitData", "KITS")
	if kits is Dictionary:
		for h in HERO_ORDER:
			var k: Dictionary = kits.get(h, {})
			ck.call(int(k.get("sig", -1)) == int(FACTS[h].sig), "V10KitData.%s.sig = %d" % [h, FACTS[h].sig])
			ck.call(String(k.get("rank", "")) == String(FACTS[h].rank), "V10KitData.%s.rank" % h)
	var extra = _const_of("V10KitData", "EXTRA_OUTFITS")
	if extra is Dictionary:
		for id in extra:
			if seen.has(id):
				ck.call(String(extra[id][0]) == String(item(id).hero) and String(extra[id][1]) == String(RANK_OF_RAR[item(id).rar]) and String(extra[id][2]) == String(item(id).name), "V10KitData.EXTRA_OUTFITS.%s agrees" % id)
	var roster = _const_of("V10ProfileCos", "ROSTER")
	if roster is Dictionary:
		for h in HERO_ORDER:
			ck.call(roster.has(h) and String(roster[h][0]) == String(HEROES[h].name) and String(roster[h][2]) == String(FACTS[h].rank), "V10ProfileCos.ROSTER.%s agrees" % h)
	if not files:
		return fails
	# art on disk
	for it in ITEMS:
		ck.call(ResourceLoader.exists(outfit_tex_path(String(it.img))), "art %s" % outfit_tex_path(String(it.img)))
	for h in HERO_ORDER:
		ck.call(ResourceLoader.exists(hero_tex_path(h)), "art %s" % hero_tex_path(h))
		for e in EMOTIONS:
			ck.call(ResourceLoader.exists(emotion_path(h, e)), "art %s" % emotion_path(h, e))
		for s in poses(h):
			ck.call(has_pose(h, s), "art %s" % pose_path(h, s))
	# measured tables
	for p in rig_problems():
		fails.append("rig: " + String(p))
	for h in HERO_ORDER:
		var r: = rig(h)
		var feet: Vector2 = r.get("feet", Vector2.ZERO)
		var hc: Vector2 = r.get("head_c", Vector2.ZERO)
		var el: Vector4 = r.get("eye_l", Vector4.ZERO)
		var er: Vector4 = r.get("eye_r", Vector4.ZERO)
		ck.call(feet.y > 1100.0 and feet.y <= ART_H and feet.x > 0.0 and feet.x < ART_W, "%s rig feet on the art" % h)
		ck.call(hc.y > 0.0 and hc.y < 500.0 and hc.x > 100.0 and hc.x < ART_W - 100.0, "%s rig head on the art" % h)
		ck.call(el.x < er.x and absf(el.y - er.y) < 40.0, "%s rig eyes left < right" % h)
		ck.call(float(r.get("head_r", 0.0)) > 40.0, "%s rig head_r" % h)
		if r.has("av"):
			var av: Vector3 = r.av
			ck.call(av.z >= 3.0 and av.z <= 7.0 and av.x > 0.0 and av.x < ART_W and av.y > 0.0 and av.y < ART_H * 0.5, "%s rig av crop" % h)
		ck.call(float(rig_face_w().get(h, 0.0)) > 40.0, "%s rig face width" % h)
		var ef: Dictionary = emo_face().get(h, {})
		var efw: Dictionary = emo_face_w().get(h, {})
		for e in EMOTIONS:
			if not ResourceLoader.exists(emotion_path(h, e)):
				continue
			var f: Array = ef.get(e, [])
			ck.call(f.size() == 2 and float(f[0]) > 0.1 and float(f[0]) < 0.9 and float(f[1]) > 0.05 and float(f[1]) < 0.7, "%s_%s face point measured" % [h, e])
			ck.call(float(efw.get(e, 0.0)) > 40.0, "%s_%s face width measured" % [h, e])
	for it in ITEMS:
		ck.call(outfit_rect(String(it.id), "face_rect").size.x > 0.0, "%s face_rect measured" % it.id)
		ck.call(outfit_rect(String(it.id), "alt_rect").size.x > 0.0, "%s alt_rect measured" % it.id)
	return fails


static func _g() -> Node:
	var tree: = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("G") if tree else null
