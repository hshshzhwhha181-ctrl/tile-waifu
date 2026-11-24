class_name V10ProfileCos
extends RefCounted

# V10ProfileCos — THE registry of profile cosmetics (docs/0.10-spec.md §2.7, §D5): avatar frames, titles, badges
# and card backgrounds. Arc laurels, Pagoda cosmetics, «Читающая руки», birthday frames, kit frames and shop frames
# are registered HERE — never in G.ITEMS or a module's own dictionary.
#
# CATALOG
#   V10ProfileCos.all(kind = "")          every entry (kind: frame / title / badge / bg), hidden goddesses excluded
#   V10ProfileCos.entry(id)               one entry or {}
#   V10ProfileCos.register(e) -> String   add an entry at runtime (other modules: bday years, pagoda…); "" = ok
#   V10ProfileCos.validate_all() -> Array error strings for the whole catalog (selftest)
#   Entry: {id, kind, name, tier: A|S|SSR, src: {type, …}, sim_ok, price (shop frames only, кристаллы),
#           look (frames), icon (badges), tex/focus/tint (backgrounds), hero (goddess-bound, hidden until released)}
#
# UNLOCKS (pure: everything reads an unlock context, never G.S directly)
#   V10ProfileCos.ctx_from_save(S) -> Dictionary   snapshot: rank, seasons, heroes, owned items, granted cosmetics,
#                                                   feat counters (V10Feats), legends, Созвездие, симпатия
#   V10ProfileCos.is_unlocked(id, ctx)              bool
#   V10ProfileCos.hint(id) -> String                «откроется …» line for a locked cell
#   V10ProfileCos.unlocked(kind, ctx) -> Array      ids
#   V10ProfileCos.grant(S, id) -> bool              event / shop / pass / birthday cosmetics: writes S.v10_cos_owned
#   V10ProfileCos.unseen(S, ctx) / mark_seen(S, id) new unlocks for the «новый титул» toast (S.v10_cos_seen)
#
# SELECTION (S.profile: frame, title, badges[3], showcase{hero, outfit, pose}, card_bg)
#   V10ProfileCos.select(profile, slot, value, ctx) -> String   "" = applied; otherwise why not (locked hint …)
#   V10ProfileCos.sanitize(profile, ctx) -> bool                 locked / unknown picks fall back to defaults
#   V10ProfileCos.showcase_img(outfit_id, modest) -> String      outfit art id honouring the SFW alt
#
# Titles and badges are NEVER sold (no price, no shop / pass source); the selftest enforces it.

const KINDS: = ["frame", "title", "badge", "bg"]
const TIERS: = ["A", "S", "SSR"]
const SLOTS: = ["frame", "title", "badges", "showcase", "card_bg"]
const BADGE_SLOTS: = 3
const DEFAULT: = {"frame": "fr_default", "title": "t_guest", "card_bg": "cb_salon"}
# unlocked by being granted (S.v10_cos_owned): another module decides when
const GRANT_TYPES: = ["grant", "shop", "pass", "bday"]
const SRC_TYPES: = ["default", "rank", "season", "goddess", "item", "feat", "ostars", "aff", "summits", "streak",
	"arc", "legend", "grant", "shop", "pass", "bday"]
const SHOP_PRICES: = [300, 480, 680, 980]
const SEASONS: = [1, 2]

# rarity colours (A jade, S lavender-silver, SSR gold — the 0.9 summon lanterns). V10Rank.color replaces this
# table when the economy branch is merged (README «Хуки»).
const TIER_COL: = {"A": Color("74dcb8"), "S": Color("cdbfff"), "SSR": Color("ffcf5a")}
const TIER_DARK: = {"A": Color("1d5a49"), "S": Color("3e3470"), "SSR": Color("6e4210")}

# the 20 goddesses (docs/ROSTER_20.md §2): name, signature colour, rank. Only ids present in G.HEROES are
# «released»; cosmetics bound to an unreleased goddess stay out of every list.
const ROSTER: = {
	"mc": ["Маджонг-тян", "ff8fb8", "A"], "rin": ["Рин", "4fbf9f", "A"], "hana": ["Хана", "ffb35c", "A"],
	"tsubame": ["Цубамэ", "c8283c", "A"], "miel": ["Миэль", "e0566f", "A"], "lian": ["Лянь", "c9a35b", "A"],
	"jess": ["Джесс", "b5532f", "A"], "tsuru": ["Цуру", "e0703b", "A"],
	"yue": ["Юэ", "c8b6ff", "S"], "nova": ["Нова", "4fe3ff", "S"], "kohaku": ["Кохаку", "d63a2a", "S"],
	"shirin": ["Ширин", "1f8f8a", "S"], "mari": ["Марисоль", "c23a3a", "S"], "hibana": ["Хибана", "ffd23f", "S"],
	"nemi": ["Неми", "b8612e", "S"],
	"zlata": ["Злата", "c3242b", "SSR"], "minamo": ["Минамо", "7fd3d0", "SSR"], "kira": ["Кира", "e03a3e", "SSR"],
	"vesper": ["Веспер", "8a1426", "SSR"], "sigrid": ["Сигрид", "7fc8d8", "SSR"],
}
const RANK_NAMES: = ["Бамбук", "Нефрит", "Жемчуг", "Золото", "Дракон", "Небожитель"]
const ROMAN: = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

static var _list: = []
static var _by_id: = {}


# ================================================================== catalog

static func _ensure() -> void:
	if _list.is_empty():
		_build()


static func _add(e: Dictionary) -> void:
	e.merge({"sim_ok": false, "price": 0, "tier": "A"}, false)
	_list.append(e)
	_by_id[e.id] = e


static func _frame(id: String, name: String, tier: String, src: Dictionary, look: Dictionary, extra: = {}) -> void:
	var e: = {"id": id, "kind": "frame", "name": name, "tier": tier, "src": src, "look": look}
	e.merge(extra, true)
	_add(e)


static func _build() -> void:
	_list.clear()
	_by_id.clear()
	# ---- frames ------------------------------------------------------------------------------------------
	# look: base ring (frame/avatar) | wing (frame/avatar_top); metal / petal / violet = recolour targets of the
	# painted gold, sakura pink and amethyst (frame_fx.gdshader); deco = code-drawn layer (V10FrameView);
	# anim = slow sheen + living deco (static at fx «минимум» and in league rows); glow = halo colour.
	_frame("fr_default", "Чайный салон", "A", {"type": "default"}, {"base": "ring"}, {"sim_ok": true})
	var rank_looks: = [
		{"base": "ring", "metal": "a8d67c", "petal": "f1f7d6", "deco": "leaves", "deco_col": "7fbf5a"},
		{"base": "ring", "metal": "56d2b2", "petal": "e2fff5", "deco": "gems", "deco_col": "3fd6b0"},
		{"base": "ring", "metal": "e8e4f6", "petal": "f6dcef", "deco": "pearls", "deco_col": "fbf8ff"},
		{"base": "ring", "deco": "stars", "deco_col": "ffe08a", "glow": "ffc93c"},
		{"base": "wing", "violet": "ff4d6d", "deco": "gems", "deco_col": "ff4d6d", "glow": "ff5a7a"},
		{"base": "wing", "deco": "stars", "deco_col": "e6d4ff", "glow": "c9a2ff", "anim": true},
	]
	for t in 6:
		_frame("fr_rank_%d" % t, RANK_NAMES[t], ["A", "A", "S", "S", "SSR", "SSR"][t], {"type": "rank", "tier": t},
			rank_looks[t], {"sim_ok": true})
	for s in SEASONS:
		for band in [[3, "ffd75e", "S"], [4, "ff6b86", "SSR"], [5, "d2b4ff", "SSR"]]:
			_frame("fr_s%d_%d" % [s, band[0]], "Сезон %d · %s" % [s, RANK_NAMES[band[0]]], band[2],
				{"type": "season", "season": s, "tier": band[0]},
				{"base": "wing" if band[0] >= 4 else "ring", "metal": "" if band[0] == 3 else "f3d58a", "violet": band[1],
					"deco": "plate", "text": "S%d" % s, "deco_col": band[1], "glow": band[1], "anim": band[0] == 5})
	# goddess kit frames (ROSTER §1.3: every rank's kit has a frame). Founders are released; SSR goddesses hidden.
	var g_looks: = {
		"mc": ["Пять ветров", {"base": "ring", "deco": "petals", "deco_col": "ff8fb8", "glow": "ff8fb8"}],
		"rin": ["Ледяной павильон", {"base": "ring", "metal": "9fe0c8", "petal": "e9d8a6", "deco": "frost", "deco_col": "c9f3ff", "glow": "4fbf9f"}],
		"hana": ["Фонарная эстафета", {"base": "ring", "metal": "ffbf6a", "petal": "fff1d6", "deco": "sun", "deco_col": "ffb35c", "glow": "ffb35c"}],
		"yue": ["Лунный дворец", {"base": "ring", "metal": "d9d2f2", "petal": "c8b6ff", "deco": "moon", "deco_col": "f2ecff", "glow": "c8b6ff"}],
		"nova": ["Неоновая ночь", {"base": "ring", "metal": "8feaff", "petal": "ff6fd8", "deco": "circuit", "deco_col": "4fe3ff", "glow": "4fe3ff"}],
		"zlata": ["Жар-птица", {"base": "wing", "metal": "ffc44a", "violet": "e8452f", "petal": "ffb070", "deco": "flames", "deco_col": "ff7a2a", "glow": "ff6a2a", "anim": true}],
		"minamo": ["Жемчужный дворец", {"base": "wing", "metal": "e7f6f6", "violet": "7fd3d0", "petal": "f3e9f1", "deco": "pearls", "deco_col": "ffffff", "glow": "7fd3d0", "anim": true}],
		"kira": ["Хризантема", {"base": "wing", "metal": "f2f2f5", "violet": "e03a3e", "petal": "ffd0d0", "deco": "stars", "deco_col": "ffffff", "glow": "e03a3e", "anim": true}],
		"vesper": ["Алая ночь", {"base": "wing", "metal": "d8c9cf", "violet": "8a1426", "petal": "c42a44", "deco": "petals", "deco_col": "b01830", "glow": "a0182e", "anim": true}],
		"sigrid": ["Северное сияние", {"base": "wing", "metal": "eaf7fb", "violet": "8b7fd6", "petal": "dff1f7", "deco": "frost", "deco_col": "dff6ff", "glow": "7fc8d8", "anim": true}],
	}
	for h in g_looks:
		var rk: String = ROSTER[h][2]
		_frame("fr_g_" + h, g_looks[h][0], rk, {"type": "goddess", "hero": h}, g_looks[h][1],
			{"hero": h, "sim_ok": rk != "SSR"})
	# Path: arc laurels, the Legendary laurel, «Восходящая» I–X (every 10 summits)
	for a in [1, 2]:
		_frame("fr_laurel_%d" % a, "Лавр арки %d" % a, "S", {"type": "arc", "arc": a},
			{"base": "ring", "deco": "laurel", "deco_col": "8cc46a", "text": ROMAN[a - 1]})
	_frame("fr_legend_1", "Легенда арки 1", "SSR", {"type": "legend", "arc": 1},
		{"base": "ring", "metal": "ffe08a", "deco": "laurel", "deco_col": "ffd75e", "glow": "ffc93c", "anim": true})
	for k in 10:
		var m: Color = Color("c58b5a").lerp(Color("e9eef5"), clampf(k / 4.0, 0.0, 1.0)) if k < 5 else Color("e9eef5").lerp(Color("ffd75e"), (k - 4) / 5.0)
		_frame("fr_rise_%d" % (k + 1), "Восходящая %s" % ROMAN[k], "A" if k < 3 else ("S" if k < 7 else "SSR"),
			{"type": "summits", "n": (k + 1) * 10},
			{"base": "ring", "metal": m.to_html(false), "deco": "plate", "text": ROMAN[k], "deco_col": m.to_html(false),
				"glow": "" if k < 7 else "ffd75e", "anim": k == 9})
	# rituals and events (granted by their modules through grant())
	_frame("fr_tea_1", "Чайный мастер I", "S", {"type": "streak", "days": 30},
		{"base": "ring", "metal": "a9cf86", "petal": "f3f0d8", "deco": "leaves", "deco_col": "6fa85a", "text": "I"})
	_frame("fr_tea_2", "Чайный мастер II", "SSR", {"type": "streak", "days": 60},
		{"base": "ring", "metal": "d7e8a6", "petal": "fff7e0", "deco": "leaves", "deco_col": "a8d27a", "glow": "b8e08a", "anim": true})
	_frame("fr_back_2027", "Снова за столом · 2027", "A", {"type": "grant", "event": "comeback", "hint": "Вернись к столу после перерыва"},
		{"base": "ring", "metal": "f2d49a", "deco": "plate", "text": "2027", "deco_col": "f2d49a"})
	_frame("fr_own", "Свой за столом", "A", {"type": "grant", "event": "newbie", "hint": "Сыграй 50 желаний «Первого гостя»"},
		{"base": "ring", "metal": "8fd8bd", "deco": "gems", "deco_col": "8fd8bd"})
	_frame("fr_palm", "Читающая руки", "S", {"type": "grant", "event": "palm", "hint": "Угадай 30 рук в «Чтении руки»"},
		{"base": "ring", "metal": "d9c8ff", "petal": "f0e6ff", "deco": "moon", "deco_col": "e6dcff", "glow": "b9a2ff"})
	_frame("fr_me_2027", "Мой праздник · 2027", "S", {"type": "bday", "hero": "", "year": 2027},
		{"base": "ring", "deco": "plate", "text": "2027", "deco_col": "ffb0c8", "glow": "ff8fb8"})
	for h in ["rin", "nova"]:
		_frame("fr_bday_%s_2027" % h, "Праздник %s · 2027" % ROSTER[h][0], "S", {"type": "bday", "hero": h, "year": 2027},
			{"base": "ring", "metal": "f6dc9a", "petal": ROSTER[h][1], "deco": "plate", "text": "2027", "deco_col": ROSTER[h][1], "glow": ROSTER[h][1]},
			{"hero": h})
	# Lavka (prices in crystals, CEO_PLAN; frames are the ONLY sold profile cosmetic) and the season pass
	var shop: = [
		["fr_shop_lotus", "Лотос", "A", 300, {"base": "ring", "metal": "f3c9b8", "petal": "fff0f4", "deco": "petals", "deco_col": "ffd6e2"}],
		["fr_shop_lantern", "Фонари", "S", 480, {"base": "ring", "metal": "ffcf7a", "petal": "ff7a5a", "deco": "sun", "deco_col": "ff9a4a", "glow": "ff9a4a"}],
		["fr_shop_jade", "Нефритовый дракон", "S", 680, {"base": "wing", "metal": "e9d38a", "violet": "2fbf8f", "petal": "c9f0d8", "deco": "gems", "deco_col": "3fd6a0", "glow": "3fd6a0"}],
		["fr_shop_aurora", "Аврора", "SSR", 980, {"base": "wing", "metal": "eef4ff", "violet": "7fb8ff", "petal": "ffd6f2", "deco": "stars", "deco_col": "dff0ff", "glow": "9fd0ff", "anim": true}],
	]
	for s in shop:
		_frame(s[0], s[1], s[2], {"type": "shop", "price": s[3]}, s[4], {"price": s[3]})
	_frame("fr_pass_1", "Пропуск · Сезон 1", "S", {"type": "pass", "season": 1, "plus": false},
		{"base": "ring", "metal": "ffe39a", "deco": "plate", "text": "S1", "deco_col": "ffe39a", "glow": "ffd75e"})
	_frame("fr_pass_plus_1", "Пропуск+ · Сезон 1", "SSR", {"type": "pass", "season": 1, "plus": true},
		{"base": "wing", "metal": "fff0b8", "violet": "ffb347", "deco": "stars", "deco_col": "fff3c4", "glow": "ffc93c", "anim": true})

	# ---- titles (never sold) ------------------------------------------------------------------------------
	_add({"id": "t_guest", "kind": "title", "name": "Гость салона", "tier": "A", "src": {"type": "default"}, "sim_ok": true})
	var rank_titles: = ["Бамбуковый росток", "Нефритовая рука", "Жемчужный взгляд", "Золотой ход", "Сердце дракона", "Небожитель стола"]
	for t in 6:
		_add({"id": "t_rank_%d" % t, "kind": "title", "name": rank_titles[t], "tier": ["A", "A", "S", "S", "SSR", "SSR"][t],
			"src": {"type": "rank", "tier": t}, "sim_ok": t <= 3})
	var feat_titles: = [
		["t_games", "Тысяча партий", "f_games_1000"], ["t_combo", "Мастер комбо", "f_combo_10"],
		["t_combo15", "Буря пар", "f_combo_15"], ["t_dragon", "Повелитель драконов", "f_dragon_25"],
		["t_clean", "Чистая рука", "f_clean_100"], ["t_tea", "Чайный мастер", "f_streak_30"],
		["t_year", "Год у стола", "f_streak_365"], ["t_summit", "Покоритель вершин", "f_summit_10"],
		["t_summit50", "Над облаками", "f_summit_50"], ["t_arc", "Путник арки", "f_arc_1"],
		["t_heroes5", "Друг основательниц", "f_heroes_5"], ["t_heroes20", "Признан всеми двадцатью", "f_heroes_20"],
		["t_duel", "Мастер дуэлей", "f_duel_100"], ["t_pagoda", "Жар Пагоды", "f_pagoda_32"],
		["t_salon", "Салон в цвету", "f_salon_6"], ["t_letters", "Хранитель писем", "f_letters_50"],
	]
	for ft in feat_titles:
		_add({"id": ft[0], "kind": "title", "name": ft[1], "tier": V10Feats.get_feat(ft[2]).get("tier", "A"),
			"src": {"type": "feat", "id": ft[2]}, "sim_ok": V10Feats.get_feat(ft[2]).get("tier", "A") == "A"})
	_add({"id": "t_legend", "kind": "title", "name": "Легенда арки 1", "tier": "SSR", "src": {"type": "legend", "arc": 1}})
	_add({"id": "t_own", "kind": "title", "name": "Свой за столом", "tier": "A", "src": {"type": "grant", "event": "newbie", "hint": "Сыграй 50 желаний «Первого гостя»"}, "sim_ok": true})
	_add({"id": "t_palm", "kind": "title", "name": "Читающий руки", "tier": "S", "src": {"type": "grant", "event": "palm", "hint": "Угадай 30 рук в «Чтении руки»"}})
	_add({"id": "t_back", "kind": "title", "name": "Снова за столом", "tier": "A", "src": {"type": "grant", "event": "comeback", "hint": "Вернись к столу после перерыва"}})
	for s in SEASONS:
		_add({"id": "t_s%d_gold" % s, "kind": "title", "name": "Сезон %d · Золото" % s, "tier": "S", "src": {"type": "season", "season": s, "tier": 3}})
	for h in ROSTER:
		_add({"id": "t_star_" + h, "kind": "title", "name": "Звезда: %s" % ROSTER[h][0], "tier": "SSR", "hero": h,
			"src": {"type": "ostars", "hero": h, "n": 5}})
		_add({"id": "t_heart_" + h, "kind": "title", "name": "Сердце: %s" % ROSTER[h][0], "tier": "S", "hero": h,
			"src": {"type": "aff", "hero": h, "lv": 10}})

	# ---- badges (never sold): medallion + an icon from the 0.8 kit -----------------------------------------
	var badges: = [
		["b_first_win", "Первая победа", "f_first_win", "icon/trophy"], ["b_games_100", "Сто партий", "f_games_100", "icon/tasks"],
		["b_games_1000", "Тысяча партий", "f_games_1000", "icon/tasks"], ["b_combo_10", "Комбо ×10", "f_combo_10", "nav/play"],
		["b_combo_15", "Комбо ×15", "f_combo_15", "nav/play"], ["b_streak_7", "Неделя чая", "f_streak_7", "icon/calendar"],
		["b_streak_30", "Месяц чая", "f_streak_30", "icon/calendar"], ["b_streak_100", "Сто чашек", "f_streak_100", "icon/calendar"],
		["b_heart", "Сердце богини", "f_aff_10", "icon/heart"], ["b_heroes_5", "Основательницы", "f_heroes_5", "icon/visits"],
		["b_letters", "Хранитель писем", "f_letters_50", "icon/letters"], ["b_summit_1", "Первая вершина", "f_summit_1", "icon/rating"],
		["b_summit_50", "Над облаками", "f_summit_50", "icon/rating"], ["b_legend", "Легенда арки", "f_legend_1", "icon/trophy"],
		["b_league_3", "Золотая лига", "f_league_3", "league/gold"], ["b_rank_5", "Небожитель", "f_rank_5", "rank/celestial"],
		["b_gifts", "Щедрая душа", "f_gifts_20", "icon/gift"], ["b_daily_100", "Раскладка ×100", "f_daily_100", "misc/chest_open"],
		["b_outfits", "Гардероб", "f_outfits_10", "nav/wardrobe"], ["b_pagoda", "Жар Пагоды", "f_pagoda_32", "icon/hint"],
	]
	for b in badges:
		var tier: String = V10Feats.get_feat(b[2]).get("tier", "A")
		_add({"id": b[0], "kind": "badge", "name": b[1], "tier": tier, "src": {"type": "feat", "id": b[2]}, "icon": b[3],
			"sim_ok": tier == "A"})

	# ---- card backgrounds ------------------------------------------------------------------------------------
	var bgs: = [
		["cb_salon", "Чайный салон", "A", {"type": "default"}, "res://assets/v08/ui/bg/profile.webp", [0.5, 0.42], "ffffff", true],
		["cb_tea", "Чайный сад", "A", {"type": "item", "item": "b_tea"}, "res://assets/bg/play.webp", [0.5, 0.45], "ffffff", true],
		["cb_ice", "Ледяная чайная", "A", {"type": "goddess", "hero": "rin"}, "res://assets/bg/bg_teahouse.webp", [0.5, 0.45], "e6f4ff", true],
		["cb_fest", "Фестиваль фонарей", "A", {"type": "item", "item": "b_fest"}, "res://assets/bg/bg_festival.webp", [0.5, 0.4], "ffffff", true],
		["cb_street", "Ночная улица", "A", {"type": "goddess", "hero": "hana"}, "res://assets/bg/bg_street.webp", [0.5, 0.45], "ffffff", true],
		["cb_palace", "Лунный дворец", "S", {"type": "item", "item": "b_palace"}, "res://assets/bg/bg_palace.webp", [0.5, 0.4], "f0ecff", true],
		["cb_rooftop", "Крыша над городом", "S", {"type": "goddess", "hero": "nova"}, "res://assets/bg/bg_rooftop.webp", [0.5, 0.4], "ffffff", false],
		["cb_neon", "Неоновый город", "SSR", {"type": "item", "item": "b_neon"}, "res://assets/bg/bg_neon.webp", [0.5, 0.45], "ffffff", false],
		["cb_shrine", "Драконье святилище", "SSR", {"type": "rank", "tier": 4}, "res://assets/bg/bg_shrine.webp", [0.5, 0.42], "fff0ec", false],
		["cb_tourney", "Турнирный зал", "S", {"type": "feat", "id": "f_league_3"}, "res://assets/v08/ui/bg/tourney.webp", [0.5, 0.4], "ffffff", false],
		["cb_evening", "Первый вечер", "A", {"type": "grant", "event": "seven", "hint": "Седьмой день «Семи встреч»"}, "res://assets/bg/menu.webp", [0.5, 0.4], "fff2ea", false],
	]
	for b in bgs:
		_add({"id": b[0], "kind": "bg", "name": b[1], "tier": b[2], "src": b[3], "tex": b[4], "focus": b[5], "tint": b[6], "sim_ok": b[7]})


# ---- public catalog API ---------------------------------------------------------------------------------------

static func released(hero: String) -> bool:
	if hero == "":
		return true
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.get_node_or_null("G") == null:
		return hero in ["mc", "rin", "hana", "yue", "nova"]
	return G.HEROES.has(hero)


static func all(kind: = "", include_hidden: = false) -> Array:
	_ensure()
	var out: = []
	for e in _list:
		if kind != "" and e.kind != kind:
			continue
		if not include_hidden and not released(String(e.get("hero", ""))):
			continue
		out.append(e)
	return out


static func entry(id: String) -> Dictionary:
	_ensure()
	return _by_id.get(id, {})


static func has(id: String, kind: = "") -> bool:
	var e: = entry(id)
	return not e.is_empty() and (kind == "" or e.kind == kind)


static func tier_col(tier: String) -> Color:
	return TIER_COL.get(tier, TIER_COL.A)


static func hero_name(h: String) -> String:
	return String(ROSTER.get(h, [h])[0])


# validates one entry; "" when fine
static func check_entry(e: Dictionary) -> String:
	for k in ["id", "kind", "name", "tier", "src"]:
		if not e.has(k):
			return "%s: no %s" % [e.get("id", "?"), k]
	if not (e.kind in KINDS):
		return "%s: bad kind %s" % [e.id, e.kind]
	if not (e.tier in TIERS):
		return "%s: bad tier %s" % [e.id, e.tier]
	if not (e.src is Dictionary) or not (String(e.src.get("type", "")) in SRC_TYPES):
		return "%s: bad source" % e.id
	var st: String = e.src.type
	if e.kind in ["title", "badge"]:
		if int(e.get("price", 0)) != 0 or st in ["shop", "pass"]:
			return "%s: titles and badges are never sold" % e.id
	if st == "shop" and (e.kind != "frame" or not (int(e.get("price", 0)) in SHOP_PRICES) or int(e.src.get("price", 0)) != int(e.price)):
		return "%s: shop entries are frames with a Lavka price" % e.id
	if st != "shop" and int(e.get("price", 0)) != 0:
		return "%s: price without a shop source" % e.id
	if e.kind == "frame":
		if not (e.get("look") is Dictionary) or not (String(e.look.get("base", "")) in ["ring", "wing"]):
			return "%s: frame without look.base" % e.id
	if e.kind == "badge" and String(e.get("icon", "")) == "":
		return "%s: badge without icon" % e.id
	if e.kind == "bg" and String(e.get("tex", "")) == "":
		return "%s: background without texture" % e.id
	if st == "feat" and V10Feats.get_feat(String(e.src.get("id", ""))).is_empty():
		return "%s: unknown feat %s" % [e.id, e.src.get("id", "")]
	return ""


static func register(e: Dictionary) -> String:
	_ensure()
	e = e.duplicate(true)
	e.merge({"sim_ok": false, "price": 0}, false)
	var err: = check_entry(e)
	if err != "":
		return err
	if _by_id.has(e.id):
		return "%s: duplicate id" % e.id
	_add(e)
	return ""


static func validate_all() -> Array:
	_ensure()
	var errs: = []
	var seen: = {}
	for e in _list:
		var err: = check_entry(e)
		if err != "":
			errs.append(err)
		if seen.has(e.id):
			errs.append("%s: duplicate id" % e.id)
		seen[e.id] = true
	return errs


# ================================================================== unlocks

static func ctx_from_save(S: Dictionary) -> Dictionary:
	var ctx: = {"rank_tier": 0, "rank_best": 0, "seasons": {}, "heroes": {}, "owned": {}, "cos_owned": {},
		"legends": {}, "arcs": {}, "ostars": {}, "aff_lv": {}, "stats": {}, "modest": bool(S.get("modest", false))}
	var g_ok: = released("mc") and Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).root.get_node_or_null("G") != null
	var tier: = 0
	if g_ok:
		tier = int(G.rank_of(int(S.get("rp", 0))).tier)
	ctx.rank_tier = tier
	var owned = S.get("owned", {})
	ctx.owned = (owned as Dictionary).duplicate() if owned is Dictionary else {}
	var cos = S.get("v10_cos_owned", {})
	ctx.cos_owned = (cos as Dictionary).duplicate() if cos is Dictionary else {}
	var shards = S.get("shards", {})
	for h in ROSTER:
		if not released(h):
			continue
		if h == "mc" or (shards is Dictionary and int(shards.get(h, 0)) >= 5) or bool(S.get("v10_heroes", {}).get(h, false)):
			ctx.heroes[h] = true
	var aff = S.get("aff", {})
	var aff_max: = 0
	if aff is Dictionary:
		for h in aff:
			var lv: = 1 + int(aff[h]) / 100
			ctx.aff_lv[h] = lv
			aff_max = maxi(aff_max, lv)
	var ost = S.get("ostars", {})
	var ost_max: = 0
	if ost is Dictionary:
		ctx.ostars = (ost as Dictionary).duplicate()
		for k in ost:
			ost_max = maxi(ost_max, int(ost[k]))
	var lv10 = S.get("v10_levels", {})
	var summits: = 0
	if lv10 is Dictionary:
		summits = int(lv10.get("summits", 0))
		var lg = lv10.get("legend", {})
		if lg is Dictionary:
			for a in lg:
				if lg[a] is Dictionary and bool(lg[a].get("won", false)) and not bool(lg[a].get("bypass", false)):
					ctx.legends[str(a)] = true
		var arcs = lv10.get("arcs_done", {})
		if arcs is Dictionary:
			for a in arcs:
				if arcs[a]:
					ctx.arcs[str(a)] = true
	var seasons = S.get("v10_seasons", {})
	if seasons is Dictionary:
		for s in seasons:
			ctx.seasons[str(s)] = int(seasons[s])
	var streak = S.get("v10_streak", {})
	var games: = 0
	var wins: = 0
	var st_all = S.get("stats", {})
	if st_all is Dictionary:
		for m in st_all:
			if st_all[m] is Dictionary:
				games += int(st_all[m].get("games", 0))
				wins += int(st_all[m].get("wins", 0))
	var outfits: = 0
	if g_ok:
		for id in ctx.owned:
			if G.ITEM.has(id) and String(G.ITEM[id].get("cat", "")) == "outfit":
				outfits += 1
	var st: = {"games": games, "wins": wins, "heroes": ctx.heroes.size(), "outfits": outfits, "aff_max_lv": aff_max,
		"rank_best": tier, "summits": summits, "legends": ctx.legends.size(), "arcs": ctx.arcs.size(), "ostars_max": ost_max,
		"streak_best": int(streak.get("best", 0)) if streak is Dictionary else 0}
	var fb = S.get("v10_feats", {})
	if fb is Dictionary and fb.get("stats") is Dictionary:
		for k in fb.stats:
			st[k] = maxi(int(st.get(k, 0)), int(fb.stats[k]))
	ctx.rank_best = maxi(tier, int(st.rank_best))
	st.rank_best = ctx.rank_best
	ctx.stats = st
	return ctx


static func is_unlocked(id: String, ctx: Dictionary) -> bool:
	var e: = entry(id)
	if e.is_empty() or not released(String(e.get("hero", ""))):
		return false
	var s: Dictionary = e.src
	match String(s.type):
		"default":
			return true
		"rank":
			return int(ctx.get("rank_best", 0)) >= int(s.tier)
		"season":
			return int(ctx.get("seasons", {}).get(str(s.season), -1)) >= int(s.tier)
		"goddess":
			return bool(ctx.get("heroes", {}).get(String(s.hero), false))
		"item":
			return bool(ctx.get("owned", {}).get(String(s.item), false))
		"feat":
			return V10Feats.done(String(s.id), ctx)
		"ostars":
			return _hero_ostars(String(s.hero), ctx) >= int(s.n)
		"aff":
			return int(ctx.get("aff_lv", {}).get(String(s.hero), 0)) >= int(s.lv)
		"summits":
			return int(ctx.get("stats", {}).get("summits", 0)) >= int(s.n)
		"streak":
			return int(ctx.get("stats", {}).get("streak_best", 0)) >= int(s.days)
		"arc":
			return bool(ctx.get("arcs", {}).get(str(s.arc), false))
		"legend":
			return bool(ctx.get("legends", {}).get(str(s.arc), false))
	if String(s.type) in GRANT_TYPES:
		return bool(ctx.get("cos_owned", {}).get(id, false))
	return false


static func _hero_ostars(h: String, ctx: Dictionary) -> int:
	var best: = 0
	var os: Dictionary = ctx.get("ostars", {})
	var tree: = Engine.get_main_loop() as SceneTree
	var g_ok: = tree != null and tree.root.get_node_or_null("G") != null
	for oid in os:
		var oh: = String(oid).get_slice(":", 0) if ":" in String(oid) else ""
		if oh == "" and g_ok and G.ITEM.has(oid):
			oh = String(G.ITEM[oid].get("hero", ""))
		if oh == h:
			best = maxi(best, int(os[oid]))
	return best


static func hint(id: String) -> String:
	var e: = entry(id)
	if e.is_empty():
		return ""
	var s: Dictionary = e.src
	match String(s.type):
		"default":
			return "Есть у всех"
		"rank":
			return "Откроется на ранге «%s»" % RANK_NAMES[clampi(int(s.tier), 0, 5)]
		"season":
			return "Сезон %d: дойди до ранга «%s»" % [int(s.season), RANK_NAMES[clampi(int(s.tier), 0, 5)]]
		"goddess":
			return "Открой богиню: %s" % hero_name(String(s.hero))
		"item":
			var nm: = String(s.item)
			var tree: = Engine.get_main_loop() as SceneTree
			if tree and tree.root.get_node_or_null("G") and G.ITEM.has(nm):
				nm = String(G.ITEM[nm].name)
			return "Получи «%s»" % nm
		"feat":
			return String(V10Feats.get_feat(String(s.id)).get("desc", ""))
		"ostars":
			return "%s: наряд до ★5" % hero_name(String(s.hero))
		"aff":
			return "%s: симпатия %d" % [hero_name(String(s.hero)), int(s.lv)]
		"summits":
			return "Вершин: %d" % int(s.n)
		"streak":
			return "Серия чая: %d дней" % int(s.days)
		"arc":
			return "Пройди арку %d" % int(s.arc)
		"legend":
			return "Легендарный уровень арки %d без обходной тропы" % int(s.arc)
		"shop":
			return "Лавка · %d кр" % int(s.price)
		"pass":
			return ("Пропуск+ · сезон %d" if bool(s.get("plus", false)) else "Пропуск сезона %d") % int(s.season)
		"bday":
			if String(s.get("hero", "")) == "":
				return "Твой день рождения · %d" % int(s.year)
			return "День рождения: %s · %d" % [hero_name(String(s.hero)), int(s.year)]
		"grant":
			return String(s.get("hint", "Событие"))
	return ""


static func unlocked(kind: String, ctx: Dictionary) -> Array:
	var out: = []
	for e in all(kind):
		if is_unlocked(e.id, ctx):
			out.append(e.id)
	return out


static func grant(S: Dictionary, id: String) -> bool:
	var e: = entry(id)
	if e.is_empty() or not (String(e.src.type) in GRANT_TYPES):
		return false
	if not (S.get("v10_cos_owned") is Dictionary):
		S["v10_cos_owned"] = {}
	if S.v10_cos_owned.has(id):
		return false
	S.v10_cos_owned[id] = true
	return true


static func unseen(S: Dictionary, ctx: Dictionary) -> Array:
	var seen = S.get("v10_cos_seen", {})
	var out: = []
	for e in all():
		if String(e.src.type) == "default":
			continue
		if is_unlocked(e.id, ctx) and not (seen is Dictionary and seen.has(e.id)):
			out.append(e.id)
	return out


static func mark_seen(S: Dictionary, id: String) -> void:
	if not (S.get("v10_cos_seen") is Dictionary):
		S["v10_cos_seen"] = {}
	S.v10_cos_seen[id] = true


# ================================================================== selection

static func defaults() -> Dictionary:
	return {"frame": DEFAULT.frame, "title": DEFAULT.title, "badges": [], "card_bg": DEFAULT.card_bg,
		"showcase": {"hero": "mc", "outfit": "o_base", "pose": "base"}}


static func outfit_ok(hero: String, outfit: String, ctx: Dictionary) -> String:
	if not released(hero):
		return "Эта богиня ещё не пришла в салон"
	if not bool(ctx.get("heroes", {}).get(hero, false)):
		return "Сначала открой богиню: %s" % hero_name(hero)
	var tree: = Engine.get_main_loop() as SceneTree
	if tree and tree.root.get_node_or_null("G"):
		if not G.ITEM.has(outfit) or String(G.ITEM[outfit].get("cat", "")) != "outfit":
			return "Нет такого наряда"
		if String(G.ITEM[outfit].get("hero", "")) != hero:
			return "Это наряд другой богини"
	if not bool(ctx.get("owned", {}).get(outfit, false)):
		return "Наряда нет в гардеробе"
	return ""


static func select(profile: Dictionary, slot: String, value, ctx: Dictionary) -> String:
	match slot:
		"frame", "title", "card_bg":
			var kind: String = {"frame": "frame", "title": "title", "card_bg": "bg"}[slot]
			var id: = String(value)
			if not has(id, kind) or not released(String(entry(id).get("hero", ""))):
				return "Нет такого варианта"
			if not is_unlocked(id, ctx):
				return hint(id)
			profile[slot] = id
			return ""
		"badges":
			if not (value is Array):
				return "Нужен список значков"
			if value.size() > BADGE_SLOTS:
				return "Не больше %d значков" % BADGE_SLOTS
			var seen: = {}
			for b in value:
				var id: = String(b)
				if seen.has(id):
					return "Значок уже выбран"
				seen[id] = true
				if not has(id, "badge"):
					return "Нет такого значка"
				if not is_unlocked(id, ctx):
					return hint(id)
			profile.badges = (value as Array).map(func(x): return String(x))
			return ""
		"showcase":
			if not (value is Dictionary):
				return "Нужна богиня и наряд"
			var h: = String(value.get("hero", ""))
			var o: = String(value.get("outfit", ""))
			var err: = outfit_ok(h, o, ctx)
			if err != "":
				return err
			profile.showcase = {"hero": h, "outfit": o, "pose": String(value.get("pose", "base"))}
			return ""
	return "Нет такого слота"


static func sanitize(profile: Dictionary, ctx: Dictionary) -> bool:
	var changed: = false
	var d: = defaults()
	for slot in ["frame", "title", "card_bg"]:
		var kind: String = {"frame": "frame", "title": "title", "card_bg": "bg"}[slot]
		var id: = String(profile.get(slot, ""))
		if not has(id, kind) or not is_unlocked(id, ctx):
			profile[slot] = d[slot]
			changed = true
	var bs = profile.get("badges", [])
	var keep: = []
	if bs is Array:
		for b in bs:
			if keep.size() < BADGE_SLOTS and has(String(b), "badge") and is_unlocked(String(b), ctx) and not (String(b) in keep):
				keep.append(String(b))
	if not (bs is Array) or keep.size() != (bs as Array).size():
		changed = true
	profile.badges = keep
	var sc = profile.get("showcase", {})
	if not (sc is Dictionary) or outfit_ok(String(sc.get("hero", "")), String(sc.get("outfit", "")), ctx) != "":
		profile.showcase = d.showcase
		changed = true
	return changed


# outfit art id for the showcase; the SFW alt when the viewer runs the modest preset (or a poster is made)
static func showcase_img(outfit: String, modest: = false) -> String:
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.get_node_or_null("G") == null or not G.ITEM.has(outfit):
		return "mc_base"
	var it: Dictionary = G.ITEM[outfit]
	if modest and (bool(it.get("bold", false)) or it.get("sfw", true) == false) and it.has("alt"):
		return String(it.alt)
	if V8Art.RETIRED_IMG.has(String(it.get("img", ""))):
		return String(V8Art.RETIRED_IMG[it.img])
	return String(it.get("img", "mc_base"))


static func outfit_rar(outfit: String) -> String:
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.get_node_or_null("G") == null or not G.ITEM.has(outfit):
		return "A"
	return {"R": "A", "SR": "S", "SSR": "SSR"}.get(String(G.ITEM[outfit].get("rar", "R")), "A")
