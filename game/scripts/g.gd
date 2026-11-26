extends Node

# G — global game state (autoload). 0.8 core API (Stream A):
#   G.version() -> String                 build version from project.godot ("0.8.0")
#   G.save()                              atomic write: save.tmp.json -> save.json, previous file kept as save.bak.json
#   G.load_game()                         main file -> interrupted temp -> backup; never crashes on bad/missing files
#   G.apply_state(d) -> bool              replace S with a loaded/imported dict (merged over defaults + migrated)
#   G.add_rp(n, source="other") -> Array  the ONLY way to give rank points; returns rank-ups [{tier, sub, gems}]
#                                         n may be negative but rp never drops below the start of the current step
#   G.record_game(source, won)            per-mode game/win counters for the profile (S.stats)
#   G.set_profile(nick, avatar, done=true) -> bool, G.nick_error(nick) -> String, G.nick() -> String
#   Signals: profile_changed, rank_changed(old_index, new_index), rp_changed(old_rp, new_rp)
#   Save keys added in v6: S.profile {nick, avatar, frame, created, id}, S.profile_done, S.stats {source: {games, wins, rp}}
# add_rp / record_game / set_* do not write to disk except set_profile; call G.save() after a batch of changes.
#
# 0.9 Foundation (Stream A) — feel settings, save v7:
#   G.fx_level() -> "full" | "mid" | "min"    «Эффекты: полные / умеренные / минимум» (S.fx_level, default "full").
#                                             mid = no screen shake, no edge flashes; min = press feedback only.
#                                             Effects ask V9Feel.can_shake() / can_edge_flash() / can_fx() / fx_scale().
#   G.set_fx_level(l)                         also keeps the 0.6 keys S.v6_fx.shake/flash in step (V6Fx reads them)
#   G.ult_cutin() -> "full" | "short" | "off" «Вставки ульт: полностью / коротко / выкл» (S.ult_cutin, default "full");
#                                             the per-cast decision is V9Ults.cutin_mode()
#   G.set_ult_cutin(m)
#   Signal settings_changed(key)              emitted by both setters (key "fx_level" / "ult_cutin"); setters do not save
#   Save v6 -> v7: adds fx_level (a player who had turned «Тряска и вспышки» off gets "mid") and ult_cutin "full".

signal profile_changed
signal rank_changed(old_index: int, new_index: int)
signal rp_changed(old_rp: int, new_rp: int)
signal settings_changed(key: String)

const SAVE_PATH: = "user://save.json"
const SAVE_VER: = 8
const FX_LEVELS: = ["full", "mid", "min"]
const ULT_CUTINS: = ["full", "short", "off"]
const RP_SOURCES: = ["path", "daily", "duel", "blitz", "zen", "etude", "event", "tourney", "table", "other"]
const NICK_MIN: = 3
const NICK_MAX: = 16

var save_path: = SAVE_PATH
var loaded_from: = ""
var save_ok: = true
var _main_ok: = false

const HEROES: = {
	"mc": {"name": "Маджонг-тян", "title": "Хозяйка салона, 26 лет", "age": "26 лет", "job": "хозяйка салона «Пять ветров»", "color": Color("ff8fb8")}, 
	"rin": {"name": "Рин", "title": "Мастер чая, 27 лет", "age": "27 лет", "job": "мастер чая, хозяйка «Ледяного павильона»", "color": Color("4fbf9f")}, 
	"hana": {"name": "Хана", "title": "Тренер, 24 года", "age": "24 года", "job": "тренер спорткомплекса и капитан фонарной эстафеты", "color": Color("ffb35c")}, 
	"yue": {"name": "Юэ", "title": "Царица луны, на вид 27", "age": "на вид 27", "job": "правительница Лунного дворца", "color": Color("c8b6ff")}, 
	"nova": {"name": "Нова", "title": "Белый хакер, 23 года", "age": "23 года", "job": "специалист по кибербезопасности и гонщица", "color": Color("4fe3ff")}, 
}
const HERO_ORDER: = ["mc", "rin", "hana", "yue", "nova"]


var ITEMS: = [
	{"id": "o_base", "cat": "outfit", "hero": "mc", "rar": "R", "name": "Ципао наставницы", "img": "mc_base", "start": true}, 
	{"id": "o_tutor", "cat": "outfit", "hero": "mc", "rar": "SR", "name": "Лектор салона", "img": "mc_tutor", "alt": "mc_base", "nogacha": true, "hidden": true}, 
	{"id": "o_cafe", "cat": "outfit", "hero": "mc", "rar": "SR", "name": "Официантка чайной", "img": "mc_cafe"}, 
	{"id": "o_dragon", "cat": "outfit", "hero": "mc", "rar": "SSR", "name": "Императрица дракона", "img": "mc_dragon"}, 
	{"id": "r_base", "cat": "outfit", "hero": "rin", "rar": "R", "name": "Мастер чая", "img": "rin_base"}, 
	{"id": "r_maid", "cat": "outfit", "hero": "rin", "rar": "SR", "name": "Горничная", "img": "rin_maid"}, 
	{"id": "r_after", "cat": "outfit", "hero": "rin", "rar": "SR", "name": "После работы", "img": "rin_after"}, 
	{"id": "r_agent", "cat": "outfit", "hero": "rin", "rar": "SSR", "name": "Городской агент", "img": "rin_agent"}, 
	{"id": "r_idol", "cat": "outfit", "hero": "rin", "rar": "SSR", "name": "Звёздная айдол", "img": "rin_idol"}, 
	{"id": "h_base", "cat": "outfit", "hero": "hana", "rar": "R", "name": "Спортивный стиль", "img": "hana_base"}, 
	{"id": "h_street", "cat": "outfit", "hero": "hana", "rar": "SR", "name": "Уличный раннер", "img": "hana_street"}, 
	{"id": "h_beach", "cat": "outfit", "hero": "hana", "rar": "SR", "name": "Летний пляж", "img": "hana_beach", "bold": true, "sfw": false, "alt": "hana_winter"}, 
	{"id": "h_gym", "cat": "outfit", "hero": "hana", "rar": "SSR", "name": "Чемпионка зала", "img": "hana_gym", "bold": true, "sfw": false, "alt": "hana_winter"}, 
	{"id": "y_base", "cat": "outfit", "hero": "yue", "rar": "SR", "name": "Лунная принцесса", "img": "yue_base"}, 
	{"id": "y_duel", "cat": "outfit", "hero": "yue", "rar": "SSR", "name": "Драконья дуэлянтка", "img": "yue_duel", "bold": true, "sfw": false, "alt": "yue_base"}, 
	{"id": "y_queen", "cat": "outfit", "hero": "yue", "rar": "SSR", "name": "Королева лунной ночи", "img": "yue_queen"}, 
	{"id": "n_base", "cat": "outfit", "hero": "nova", "rar": "SR", "name": "Нетраннер", "img": "nova_base"}, 
	{"id": "n_ssr", "cat": "outfit", "hero": "nova", "rar": "SSR", "name": "Неоновый форсаж", "img": "nova_ssr", "bold": true, "sfw": false, "alt": "nova_base"}, 

	{"id": "o_cozy", "cat": "outfit", "hero": "mc", "rar": "SR", "name": "Уютный вечер", "img": "mc_cozy", "shop": 680, "nogacha": true}, 
	{"id": "r_yukata", "cat": "outfit", "hero": "rin", "rar": "SR", "name": "Летняя юката", "img": "rin_yukata", "shop": 680, "nogacha": true}, 
	{"id": "h_winter", "cat": "outfit", "hero": "hana", "rar": "SR", "name": "Зимний каток", "img": "hana_winter", "shop": 680, "nogacha": true}, 
	{"id": "n_offline", "cat": "outfit", "hero": "nova", "rar": "SSR", "name": "Офлайн-выходной", "img": "nova_offline", "shop": 1280, "nogacha": true}, 
	{"id": "y_ball", "cat": "outfit", "hero": "yue", "rar": "SSR", "name": "Лунный бал", "img": "yue_ball", "pass": true, "nogacha": true}, 
	{"id": "s_sakura", "cat": "skin", "rar": "R", "name": "Фишки «Сакура»", "tile": 0, "start": true}, 
	{"id": "s_mint", "cat": "skin", "rar": "R", "name": "Фишки «Мята»", "tile": 5, "start": true}, 
	{"id": "s_lemon", "cat": "skin", "rar": "R", "name": "Фишки «Лимон»", "tile": 20}, 
	{"id": "s_night", "cat": "skin", "rar": "SR", "name": "Фишки «Полночь»", "tile": 7}, 
	{"id": "s_neon", "cat": "skin", "rar": "SR", "name": "Фишки «Неон»", "tile": 35}, 
	{"id": "s_gold", "cat": "skin", "rar": "SSR", "name": "Золото дракона", "tile": 25}, 
	{"id": "b_tea", "cat": "bg", "rar": "R", "name": "Фон «Чайный сад»", "bg": "play"}, 
	{"id": "b_palace", "cat": "bg", "rar": "SR", "name": "Фон «Лунный дворец»", "bg": "bg_palace"}, 
	{"id": "b_neon", "cat": "bg", "rar": "SSR", "name": "Фон «Неоновый город»", "bg": "bg_neon"}, 
	{"id": "b_fest", "cat": "bg", "rar": "R", "name": "Фон «Фестиваль»", "bg": "bg_festival"}, 
]
var ITEM: = {}

const TILE_NAMES: = ["sakura", "plum", "chrysanthemum", "sunflower", "tulip", "clover", "maple", "moon", "star", "sun", "rainbow", "snowflake", "fire", "water", "lightning", "dango", "cake", "strawberry", "peach", "cherry", "lemon", "matcha", "bubbletea", "bow", "diamond", "crown", "bell", "windchime", "lantern", "cat", "rabbit", "fox", "panda", "dragon", "koi", "butterfly"]



const LOCS: = [
	{"name": "Чайный сад", "bg": "play", "fx": "petals", "tint": Color(1, 1, 1), "hero": "mc", "shard": "rin", "item": "s_mint", 
		"intro": "Свободная фишка уходит в лоток, две одинаковые исчезают. Держи в лотке хотя бы одно место пустым.",
		"stages": [["rect", 5, 6, 2, 0.7, 6, "", 0], ["heart", 5, 6, 2, 0.75, 7, "", 0], ["diamond", 5, 6, 3, 0.6, 8, "gold", 0], ["butterfly", 6, 6, 3, 0.65, 9, "hidden", 1]]}, 
	{"name": "Чайная во льду", "bg": "bg_teahouse", "fx": "snow", "tint": Color(0.92, 0.97, 1.0), "hero": "rin", "shard": "rin", "item": "b_tea", 
		"intro": "Фишки рубашкой вверх: первое касание переворачивает фишку, второе берёт её в лоток.", 
		"stages": [["rect", 6, 6, 3, 0.6, 9, "ice", 0], ["cross", 6, 7, 3, 0.6, 9, "", 0], ["ring", 6, 7, 3, 0.65, 10, "ice", 0], ["pyramid", 7, 8, 4, 0.6, 11, "ice,hidden", 1]]}, 
	{"name": "Фестиваль фонарей", "bg": "bg_festival", "fx": "lanterns", "tint": Color(1, 0.95, 0.9), "hero": "hana", "shard": "hana", "item": "b_fest", 
		"intro": "Серия пар запускает фейерверк над крышами. Держи в лотке не больше двух разных фишек.", 
		"stages": [["butterfly", 6, 7, 3, 0.65, 11, "", 0], ["heart", 6, 7, 3, 0.7, 11, "gold", 0], ["towers", 7, 8, 4, 0.6, 12, "hidden", 0], ["diamond", 6, 7, 4, 0.7, 13, "gold,ice", 1]]}, 
	{"name": "Лунный дворец", "bg": "bg_palace", "fx": "fireflies", "tint": Color(0.93, 0.92, 1.0), "hero": "yue", "shard": "yue", "item": "s_night", 
		"intro": "Золотые фишки — дар луны, ×5 кристаллов. Тайные покажут лицо, только когда их освободишь.", 
		"stages": [["pyramid", 7, 8, 4, 0.6, 13, "gold", 0], ["ring", 6, 7, 4, 0.6, 13, "hidden", 0], ["butterfly", 6, 7, 4, 0.65, 14, "ice", 0], ["cross", 7, 8, 5, 0.7, 15, "gold,hidden", 2]]}, 
	{"name": "Драконье святилище", "bg": "bg_shrine", "fx": "mist", "tint": Color(1, 0.95, 0.95), "hero": "mc", "shard": "yue", "item": "s_gold", 
		"intro": "Здесь хранится Звёздный набор: все фишки разные. Думай на два хода вперёд.", 
		"stages": [["diamond", 6, 7, 4, 0.75, 15, "ice", 0], ["towers", 7, 8, 5, 0.65, 15, "gold", 0], ["heart", 6, 7, 5, 0.7, 16, "hidden,ice", 1], ["rect", 6, 7, 5, 0.75, 17, "gold,ice,hidden", 2]]}, 
	{"name": "Неоновая ночь", "bg": "bg_neon", "fx": "rain", "tint": Color(0.9, 0.95, 1.05), "hero": "nova", "shard": "nova", "item": "s_neon", 
		"intro": "Нова взломала вывески квартала. Золото, перевёртыши и тайные фишки — всё разом.", 
		"stages": [["rect", 6, 7, 5, 0.7, 17, "gold", 0], ["butterfly", 6, 7, 5, 0.7, 17, "hidden", 0], ["ring", 6, 7, 5, 0.7, 18, "ice,gold", 1], ["pyramid", 7, 8, 5, 0.75, 18, "gold,ice,hidden", 2]]}, 
]
const SHAPE_NAMES: = {"rect": "Плато", "heart": "Сердце", "diamond": "Ромб", "butterfly": "Бабочка", "cross": "Крест", "ring": "Кольцо", "pyramid": "Пагода", "towers": "Две башни"}
const HARD_NAMES: = ["", "Сложный", "Очень сложный"]
var LEVELS: = []
var _arcs_built: = {}

# 0.10 W2: 1000-level Path via V10LevelGen, materialized lazily by 100-level arc (Arc 0 built at startup in ~65 ms;
# Arcs 1..9 hold light stubs until ensure_arc/level_at touches them).
func _build_levels() -> void :
	LEVELS.clear()
	_arcs_built.clear()
	for i in V10LevelGen.TOTAL:
		var w: = i / V10LevelGen.PER_WORLD
		var Wd: Dictionary = V10LevelGen.WORLD[w]
		var tier: = V10LevelGen.tier_of(i)
		LEVELS.append({
			"v10_id": i, "code": V10LevelGen.code(i), "world": w, "num": i % V10LevelGen.PER_WORLD + 1,
			"name": str(Wd.name), "loc": mini(w, LOCS.size() - 1), "world_loc": w, "stage": i % V10LevelGen.PER_WORLD,
			"bg": str(Wd.bg), "fx": str(Wd.fx), "tint": LOCS[mini(w, LOCS.size() - 1)].tint,
			"hero": V10LevelGen.ready_hero(str(Wd.hero), w), "shard": V10LevelGen.ready_hero(str(Wd.shard), w),
			"tier": tier, "tier_name": str(V10LevelGen.TIER_NAMES.get(tier, "")), "hard": int(V10LevelGen.TIER_HARD.get(tier, 0)),
			"boss": V10LevelGen.is_boss(i), "peak": V10LevelGen.is_peak(i), "legend": tier == "legendary",
			"shape": "rect", "cols": 6, "rows": 8, "layers": 3, "fill": 0.7, "faces": 12, "seed": 11 + i * 11,
			"mech": "", "gold": 0, "ice": 0, "hidden": false, "reward": {"gems": 2, "per_star": 2, "first_only": true},
			"goal": "Очисти стол", "intro": str(LOCS[mini(w, LOCS.size() - 1)].intro), "_lazy": true,
		})
	ensure_arc(0)


func ensure_arc(w: int) -> void :
	w = clampi(w, 0, V10LevelGen.WORLDS - 1)
	if _arcs_built.has(w):
		return
	_arcs_built[w] = true
	var base: = w * V10LevelGen.PER_WORLD
	for k in V10LevelGen.PER_WORLD:
		var i: = base + k
		var lv: Dictionary = V10PathState._lv_cache.get(i, V10LevelGen.level(i))
		V10PathState._lv_cache[i] = lv
		var copy: = lv.duplicate(true)
		copy["world_loc"] = int(lv.get("loc", w))
		copy["loc"] = mini(int(lv.get("loc", w)), LOCS.size() - 1)
		copy["tint"] = LOCS[int(copy.loc)].tint
		if not copy.has("goal"):
			copy["goal"] = "Очисти стол"
		if not copy.has("intro") or str(copy.intro).length() < 12:
			var il: = str(copy.get("intro_line", ""))
			copy["intro"] = il if il != "" else str(LOCS[int(copy.loc)].intro)
		LEVELS[i] = copy


func level_at(i: int) -> Dictionary:
	i = clampi(i, 0, V10LevelGen.TOTAL - 1)
	ensure_arc(i / V10LevelGen.PER_WORLD)
	return LEVELS[i]


func loc_name(w: int) -> String:
	if w >= 0 and w < V10LevelGen.WORLDS:
		return str(V10LevelGen.WORLD[w].name)
	return str(LOCS[clampi(w, 0, LOCS.size() - 1)].name)


# 0.10 W2 (levels/README.md, INTEGRATION_0.10.md §4 W2): one-time 48 → 1000 migration for legacy saves.
#   passed = clamp(old_unlocked - 1, 0, 48), raised to k + 1 if stars[k] > 0 (48 passed when index 47 has stars).
#   new_unlocked = 1 if passed == 0 else clamp(round(passed * 100 / 48) + 1, 1, released_total).
#   Each old star at 0..47 moves to the nearest unused non-Peak main-path level around round(old_i * 99 / 47) in Arc 1,
#   preserving 100 % of earned stars (Salon bank == sum of legacy stars).
static func migrate_48_to_1000(st_dict: Dictionary) -> void :
	if not (st_dict.get("v10_levels") is Dictionary):
		st_dict["v10_levels"] = {}
	var lv10: Dictionary = st_dict["v10_levels"]
	if bool(lv10.get("mig48", false)):
		return
	var old_stars: Dictionary = st_dict.get("stars", {}) if st_dict.get("stars") is Dictionary else {}
	var old_unl: = maxi(1, int(st_dict.get("unlocked", 1)))
	var has_hi: = old_unl > 48
	for k in old_stars:
		if int(k) >= 48:
			has_hi = true
			break
	if has_hi:
		lv10["mig48"] = true
		return
	var passed: = clampi(old_unl - 1, 0, 48)
	var max_idx: = -1
	for k in old_stars:
		var idx: = int(k)
		if idx >= 0 and idx < 48 and int(old_stars[k]) > 0:
			passed = maxi(passed, idx + 1)
			max_idx = maxi(max_idx, idx)
	if old_unl <= 6 and max_idx < 6:
		lv10["mig48"] = true
		return
	var new_stars: = {}
	var used: = {}
	var keys: = old_stars.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in keys:
		var sv: = clampi(int(old_stars[k]), 0, 3)
		if sv <= 0:
			continue
		var oi: = clampi(int(k), 0, 47)
		var target: = clampi(int(round(oi * 99.0 / 47.0)), 0, 99)
		var pick: = -1
		for d in 100:
			for cand in ([target] if d == 0 else [target - d, target + d]):
				if cand >= 0 and cand < 100 and not V10LevelGen.is_peak(cand) and not used.has(cand):
					pick = cand
					break
			if pick >= 0:
				break
		if pick < 0:
			pick = target
		used[pick] = true
		new_stars[str(pick)] = sv
	st_dict["stars"] = new_stars
	if passed <= 0:
		st_dict["unlocked"] = 1
	else:
		st_dict["unlocked"] = clampi(int(round(passed * 100.0 / 48.0)) + 1, 1, V10PathState.released_total())
	lv10["mig48"] = true


func level_feature(lv: Dictionary) -> String:
	var parts: = [V6Layouts.shape_name(lv.shape)]
	if lv.gold > 0:
		parts.append("золото")
	if lv.ice > 0:
		parts.append("перевёртыши")
	if lv.hidden:
		parts.append("тайные фишки")
	parts.append("%d слоя" % lv.layers if lv.layers < 5 else "%d слоёв" % lv.layers)
	return " · ".join(parts)


const RANKS: = [
	{"name": "Бамбук", "color": Color("7fd18b"), "dark": Color("2f6b3a"), "per": 60, "gems": 150}, 
	{"name": "Нефрит", "color": Color("3fd6b0"), "dark": Color("16614f"), "per": 100, "gems": 250}, 
	{"name": "Жемчуг", "color": Color("e9e4ff"), "dark": Color("5b4f8a"), "per": 150, "gems": 400}, 
	{"name": "Золото", "color": Color("ffc93c"), "dark": Color("7a4a0c"), "per": 220, "gems": 600}, 
	{"name": "Дракон", "color": Color("ff5a7a"), "dark": Color("6a1030"), "per": 300, "gems": 900}, 
	{"name": "Небожитель", "color": Color("c9a2ff"), "dark": Color("3f1f7a"), "per": 400, "gems": 1200}, 
]
const ROMAN: = ["I", "II", "III"]


func rank_of(rp: int) -> Dictionary:
	var left: = rp
	for t in RANKS.size():
		var per: int = RANKS[t].per
		var subs: = 3 if t < RANKS.size() - 1 else 999
		for s in subs:
			if left < per:
				return {"tier": t, "sub": s, "into": left, "need": per, "title": rank_title(t, s)}
			left -= per
	return {"tier": RANKS.size() - 1, "sub": 0, "into": 0, "need": 1, "title": RANKS[-1].name}

func rank_title(t: int, s: int) -> String:
	if t == RANKS.size() - 1:
		return "%s %d" % [RANKS[t].name, s + 1]
	return "%s %s" % [RANKS[t].name, ROMAN[s]]

func rank_index(rp: int) -> int:
	var r: = rank_of(rp)
	return r.tier * 3 + r.sub


func rank_floor(rp: int) -> int:
	return maxi(0, rp - int(rank_of(rp).into))


func add_rp(n: int, source: = "other") -> Array:
	if not source in RP_SOURCES:
		push_warning("G.add_rp: unknown source '%s', counted as 'other'" % source)
		source = "other"
	# 0.8: a new quarter starts before the points land, so they count for the quarter they were earned in
	V8League._roll_quarter(V8League.now())
	var old_rp: = int(S.get("rp", 0))
	var before: = rank_index(old_rp)
	var new_rp: = old_rp + n
	if n < 0:
		new_rp = maxi(new_rp, rank_floor(old_rp))
	new_rp = maxi(0, new_rp)
	S.rp = new_rp
	var st: = _stat(source)
	st.rp = int(st.rp) + (new_rp - old_rp)
	var ups: = []
	var after: = rank_index(new_rp)
	for k in range(before + 1, after + 1):
		var t: = mini(k / 3, RANKS.size() - 1)
		var s: = k - t * 3
		var g: int = RANKS[t].gems if s == 0 else 50 * (t + 1)
		V10Money.grant({"gems": g}, "rank_up")
		ups.append({"tier": t, "sub": s, "gems": g})
	if new_rp != old_rp:
		rp_changed.emit(old_rp, new_rp)
	if after != before:
		rank_changed.emit(before, after)
	return ups


func record_game(source: String, won: bool) -> void :
	if not source in RP_SOURCES:
		push_warning("G.record_game: unknown source '%s', counted as 'other'" % source)
		source = "other"
	var st: = _stat(source)
	st.games = int(st.games) + 1
	if won:
		st.wins = int(st.wins) + 1
		V9Letters.note_win()


func stats_of(source: String) -> Dictionary:
	var st = S.get("stats", {}).get(source, {})
	if not (st is Dictionary):
		st = {}
	return {"games": int(st.get("games", 0)), "wins": int(st.get("wins", 0)), "rp": int(st.get("rp", 0))}


func _stat(source: String) -> Dictionary:
	if not (S.get("stats") is Dictionary):
		S.stats = {}
	var st = S.stats.get(source)
	if not (st is Dictionary):
		st = {}
		S.stats[source] = st
	for k in ["games", "wins", "rp"]:
		st[k] = int(st.get(k, 0))
	return st


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.8.0"))


func new_profile() -> Dictionary:
	return {"nick": "", "avatar": "mc", "frame": "", "created": V10Meta.now_unix(), "id": "%08x" % (randi() & 0xffffffff)}


func profile() -> Dictionary:
	_ensure_profile()
	return S.profile


func nick() -> String:
	var n: String = str(profile().get("nick", "")).strip_edges()
	return n if n != "" else "Гость"


func nick_error(text: String) -> String:
	var n: = text.strip_edges()
	if n == "":
		return "Введи ник"
	if n.length() < NICK_MIN:
		return "Ник короче %d символов" % NICK_MIN
	if n.length() > NICK_MAX:
		return "Ник длиннее %d символов" % NICK_MAX
	for ch in n:
		if ch.unicode_at(0) < 32:
			return "Недопустимые символы в нике"
	return ""


func set_profile(new_nick: String, avatar: = "", done: = true) -> bool:
	if nick_error(new_nick) != "":
		return false
	var p: = profile()
	p.nick = " ".join(new_nick.strip_edges().split(" ", false))
	if avatar != "" and HEROES.has(avatar):
		p.avatar = avatar
	if done:
		S.profile_done = true
	save()
	profile_changed.emit()
	return true


func set_avatar(avatar: String) -> void :
	if not HEROES.has(avatar):
		return
	profile().avatar = avatar
	save()
	profile_changed.emit()


func _ensure_profile() -> void :
	var d: = new_profile()
	if not (S.get("profile") is Dictionary):
		S.profile = d
		return
	for k in d:
		if not S.profile.has(k):
			S.profile[k] = d[k]
	S.profile.created = int(S.profile.created)
	if not HEROES.has(str(S.profile.avatar)):
		S.profile.avatar = "mc"


const CATS: = [[0, 6, "Букет", "цветы"], [7, 14, "Небосвод", "небо"], [15, 22, "Сладкоежка", "сладости"], [23, 28, "Сокровищница", "сокровища"], [29, 35, "Зверинец", "звери"]]
# 0.8: yaku rank points scaled to the single-rank economy (a Path win ≈ 25–45 points, see V8PlayRules.path_rp)
const YAKU: = {
	"clean": {"name": "Чистая рука", "rp": 4, "desc": "без помощи и переполнений"}, 
	"calm": {"name": "Пустой лоток", "rp": 3, "desc": "в лотке не больше двух фишек"}, 
	"sharp": {"name": "Без промаха", "rp": 2, "desc": "ни одного касания по закрытой"}, 
	"swift": {"name": "Молния", "rp": 3, "desc": "очень быстрая победа"}, 
	"riichi": {"name": "Ва-банк", "rp": 6, "desc": "нажат «Ва-банк» и стол пройден, награда ×2"},  # v10-clarity: was «Риичи» 
	"dragon": {"name": "Пробуждение дракона", "rp": 4, "desc": "комбо ×7"}, 
	"goldvein": {"name": "Золотая жила", "rp": 2, "desc": "все золотые пары"}, 
	"finale": {"name": "Финальный аккорд", "rp": 2, "desc": "последняя пара в комбо"}, 
	"set": {"name": "Тройка", "rp": 2, "desc": "три пары одной масти подряд"}, 
}

func face_cat(f: int) -> int:
	for i in CATS.size():
		if f >= CATS[i][0] and f <= CATS[i][1]:
			return i
	return -1



const SKIN_LOOK: = {
	"s_sakura": {"side": Color("e8789f"), "rim": Color("f6dfe6"), "tint": Color(1, 1, 1)}, 
	"s_mint": {"side": Color("3f9c7c"), "rim": Color("e6d3b3"), "tint": Color(1, 1, 1)}, 
	"s_lemon": {"side": Color("e3b53a"), "rim": Color("fff1c9"), "tint": Color(1, 1, 0.97)}, 
	"s_night": {"side": Color("232a52"), "rim": Color("c9a55a"), "tint": Color(0.97, 0.97, 1.03)}, 
	"s_neon": {"side": Color("3b2a6e"), "rim": Color("49e3ff"), "tint": Color(1, 1, 1), "neon": true}, 
	"s_gold": {"side": Color("a8741c"), "rim": Color("ffe08a"), "tint": Color(1.04, 1.0, 0.92)}, 
}

const BASE_OUTFITS: = ["o_base", "r_base", "h_base", "y_base", "n_base"]


func equipped(h: String) -> String:
	var id: String = S.outfit.get(h, "")
	if id == "" or id in BASE_OUTFITS or not owns(id) or not ITEM.has(id):
		return ""
	return id

func skin_source(id: String) -> String:
	for lv in LEVELS:
		if lv.reward.get("item", "") == id:
			return "награда за партию %s" % lv.code
	return "в Желаниях"

func skin_look(ranked: bool = false) -> Dictionary:
	var lsc = load("res://scripts/v10/look/look.gd")
	if lsc != null:
		var big: = bool(S.get("v10_clarity", {}).get("big", false)) if S.get("v10_clarity") is Dictionary else false
		return lsc.tile_look(S, {"ranked": ranked, "big_symbols": big})
	return SKIN_LOOK.get(S.get("skin", "s_sakura"), SKIN_LOOK.s_sakura)

const SHARDS_NEED: = 5


const PERKS: = {
	"mc": "+1 бесплатная подсказка", 
	"rin": "+1 бесплатная отмена", 
	"hana": "Окно комбо +1 секунда", 
	"yue": "Золотые фишки ×8 вместо ×5", 
	"nova": "+1 перемешивание и +10% кристаллов", 
}

const SKILLS: = {
	"mc": {"name": "Подсказка сердца", "desc": "сама убирает одну пару"}, 
	"rin": {"name": "Чайная пауза", "desc": "возвращает весь лоток на стол"}, 
	"hana": {"name": "Рывок", "desc": "убирает две пары подряд"}, 
	"yue": {"name": "Лунный свет", "desc": "переворачивает все закрытые фишки и показывает пару"}, 
	"nova": {"name": "Взлом", "desc": "снимает самую глубоко спрятанную пару"}, 
}


const FORTUNES: = [
	{"id": "great", "rank": "Великая удача", "name": "Щедрый вечер", "desc": "Кристаллы за эту партию +50%.", "w": 2}, 
	{"id": "tray", "rank": "Великая удача", "name": "Ладонь кицунэ", "desc": "Если лоток переполнится, он один раз спасётся сам.", "w": 2}, 
	{"id": "pairs", "rank": "Удача", "name": "Счастливое начало", "desc": "Первые три пары приносят втрое больше кристаллов.", "w": 3}, 
	{"id": "wind", "rank": "Удача", "name": "Ветер перемен", "desc": "Ещё одно бесплатное смешивание.", "w": 3}, 
	{"id": "reveal", "rank": "Удача", "name": "Лунный взгляд", "desc": "Тайные фишки открыты с самого начала.", "w": 2}, 
	{"id": "gold", "rank": "Удача", "name": "Золотой дождь", "desc": "На столе появятся ещё четыре золотые фишки.", "w": 3, "gold": 4}, 
	{"id": "tea", "rank": "Малая удача", "name": "Тёплый чай", "desc": "Комбо держится на полторы секунды дольше.", "w": 3}, 
	{"id": "small", "rank": "Малая удача", "name": "Шёпот ветра", "desc": "Одна подсказка сверху.", "w": 3}, 
	{"id": "later", "rank": "Будущая удача", "name": "Терпение", "desc": "Сегодня без подарка. Зато следующее гадание точно будет великой удачей.", "w": 2}, 
]

func draw_fortune(lv: = {}) -> Dictionary:
	var pool: = FORTUNES.filter( func(f): return f.id != "reveal" or lv.get("hidden", false))
	if S.get("next_great", false):
		S.next_great = false
		var gs: = FORTUNES.filter( func(f): return f.rank == "Великая удача")
		return gs[randi() % gs.size()]
	var total: = 0
	for f in pool:
		total += int(f.w)
	var r: = randi() % total
	for f in pool:
		r -= int(f.w)
		if r < 0:
			if f.id == "later":
				S.next_great = true
			return f
	return FORTUNES[0]

const PULL_COST: = 150
const NEWBIE_COST: = 1200

const BANNERS: = [
	{"id": "newbie", "name": "Первый гость", "sub": "50 желаний по 120 кристаллов, SSR среди них", "hero": "mc", "item": "o_dragon", "img": "mc_dragon", "color": Color("ff8fb8"), "newbie": true}, 
	{"id": "moon", "name": "Лунная ночь", "sub": "Шанс SSR повышен", "hero": "yue", "item": "y_queen", "img": "yue_queen", "color": Color("8f7cff")}, 
	{"id": "neon", "name": "Неоновый форсаж", "sub": "Только на время события", "hero": "nova", "item": "n_ssr", "img": "nova_ssr", "color": Color("38d9ff")}, 
]

var S: = {}
var demo: = false
var demo_force_ssr: = false
var current_level: = 0
var rng: = RandomNumberGenerator.new()
var time: = 0.0
var offer_shown: = false

func _process(dt: float) -> void :
	time += dt

func _ready() -> void :
	for it in ITEMS:
		ITEM[it.id] = it
	_collect_hidden_items()
	_build_levels()
	demo = "--demo" in OS.get_cmdline_user_args()
	rng.randomize()
	var args: = OS.get_cmdline_user_args()
	# --save=user://pt_save.json: use another save file (playtests, dev runs); --save_wipe=1 deletes it first.
	# A playtest (--pt=) always runs on its own wiped save, user://pt_save.json unless --save= says otherwise.
	var pt: = false
	for a in args:
		if a.begins_with("--pt="):
			pt = true
			save_path = "user://pt_save.json"
	for a in args:
		if a.begins_with("--save="):
			var sp: = a.substr(7)
			if sp.begins_with("user://") and sp.ends_with(".json"):
				save_path = sp
	if save_path != SAVE_PATH and ("--save_wipe=1" in args or pt):
		for p in [save_path, _tmp_path(), _bak_path()]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	# 0.10: every module registers its save keys / migrators before the save is read (scripts/v10/core)
	V10Registry.load_all()
	load_game()
	if "--recovery_selftest=1" in args:
		_recovery_selftest.call_deferred()
	if "--ults_selftest=1" in args:
		_ults_selftest.call_deferred()
	for a in args:
		if a.begins_with("--ults_overlay="):
			_ults_overlay.call_deferred(a.substr(15))
	if "--v8_confirm_demo=1" in args:
		_confirm_demo.call_deferred()
	if "--v8_header_demo=1" in args:
		_header_demo.call_deferred()


func _recovery_selftest() -> void :
	var fails: int = V8RecoverySelftest.run()
	get_tree().quit(1 if fails > 0 else 0)


func _ults_selftest() -> void :
	var fails: int = V9UltsSelftest.run()
	get_tree().quit(1 if fails > 0 else 0)


# dev: writes contact sheets of every outfit art with its V9Ults face_rect (red) and alt_rect (cyan) to <dir>
func _ults_overlay(dir: String) -> void :
	var n: int = V9UltsSelftest.overlay(dir)
	print("ULTS OVERLAY %d sheets -> %s" % [n, dir])
	get_tree().quit()


func _header_demo() -> void :
	for i in 30:
		await get_tree().process_frame
	var main = get_tree().current_scene
	if main == null or not ("screen" in main) or main.screen == null:
		return
	var bg: = ColorRect.new()
	bg.color = Color(0.1, 0.09, 0.11)
	bg.position = Vector2(0, V8Header.TOP)
	bg.size = Vector2(main.W, main.H - V8Header.TOP)
	main.screen.add_child(bg)
	V8Header.make(main.screen, main, "Турнир недели", func(): main.toast("Назад", ""), func(): main.toast("Справка", ""))
	var l: = UI.label("Контент начинается с V8Header.CONTENT_Y = %d" % int(V8Header.CONTENT_Y), 22, UI.INK)
	l.position = Vector2(24, V8Header.CONTENT_Y + 8)
	main.screen.add_child(l)
	var line: = ColorRect.new()
	line.color = Color(1, 0.8, 0.3, 0.8)
	line.position = Vector2(0, V8Header.CONTENT_Y)
	line.size = Vector2(main.W, 2)
	main.screen.add_child(line)


func _confirm_demo() -> void :
	for i in 30:
		await get_tree().process_frame
	var main = get_tree().current_scene
	if main == null or not ("overlay" in main):
		return
	Common.confirm(main, "Подсказка", "Подсказки на эту партию закончились. Взять ещё одну за кристаллы?", "gem", 30, func(): main.toast("Подсказка куплена", "gem"), {"skip_key": "demo_hint"})

func default_state() -> Dictionary:
	var owned: = {}
	for it in ITEMS:
		if it.get("start", false):
			owned[it.id] = true
	return {
		"gems": 1500, "coins": 2400, "player_lv": 7, "xp": 340, "unlocked": 1, "stars": {}, 
		"owned": owned, "partner": "mc", "outfit": {"mc": "o_base"}, "skin": "s_sakura", 
		"pity": 0, "aff": {"mc": 120, "rin": 40, "hana": 30, "yue": 0, "nova": 0}, 
		"daily_day": "", "streak": 0, "sound": true, "music": true, "pulls": 0, 
		"level_partner": "mc", "tut_done": false, "free10": false, "newbie_left": 20, "newbie_ssr": false, 
		"guar": false, "sr_pity": 0, "ex": 0, 
		"pet": {"day": "", "n": 0}, 
		"tasks": {"day": "", "pairs": 0, "levels": 0, "combo5": 0, "claimed": [false, false, false]}, 
		"login": {"n": 0, "last": ""}, 
		"dailymap": {"month": "", "done": []}, 
		"pass": {"owned": false, "xp": 0, "claimed": 0}, 
		"month_card": {"until": "", "last": ""}, 
		"modest": false, "cutins": true, "voice": true, "first_buy": {}, "shards": {}, "side": "f", 
		"rp": 0, "ver": SAVE_VER, "yaku_seen": {}, "blitz_best": 0, "next_great": false, "intro_done": false,
		"profile": new_profile(), "profile_done": false, "stats": {},
		"fx_level": "full", "ult_cutin": "full",
	}

# Compliance wave 0 (docs/HEROINES.md §6): an item marked "hidden" is retired — never sold, pulled,
# put on a banner or listed. It stays in ITEM (lookup, equip), and ITEMS — the list the wardrobe,
# album counters, shop and gacha pools iterate — carries it only while the current save owns it.
var _hidden_items: = []


func _collect_hidden_items() -> void :
	_hidden_items.clear()
	for i in ITEMS.size():
		if ITEMS[i].get("hidden", false):
			_hidden_items.append([i, ITEMS[i]])


func sync_hidden_items() -> void :
	var owned = S.get("owned", {})
	var missing: = 0
	for h in _hidden_items:
		var it: Dictionary = h[1]
		var at: = -1
		for i in ITEMS.size():
			if ITEMS[i].id == it.id:
				at = i
				break
		var own: bool = owned is Dictionary and owned.has(it.id)
		if own and at < 0:
			ITEMS.insert(clampi(int(h[0]) - missing, 0, ITEMS.size()), it)
		elif not own and at >= 0:
			ITEMS.remove_at(at)
		if not own:
			missing += 1


func load_game() -> void :
	_load_game()
	sync_hidden_items()
	v10_attach()


# 0.10: the save keys of the modules (V10Save + V10Registry, idempotent) and the economy wallet behind the 0.9
# currency fields (V10Money mirrors S.gems/S.coins). Runs after every load and every accepted import.
var econ = null

func v10_attach() -> void :
	V10Save.migrate(S)
	V10Registry.ensure_all(S)
	V10Money.attach(S)
	V10Fonts.deco = bool(S.get("deco_fonts", true))
	var tt_sc = load("res://scripts/v10/look/tile_themes.gd")
	if tt_sc != null:
		tt_sc.anim_on = fx_level() != "min"
	var hs_sc = load("res://scripts/v10/look/hud_skin.gd")
	var lk_sc = load("res://scripts/v10/look/look.gd")
	if hs_sc != null and lk_sc != null:
		hs_sc.sync(lk_sc.current(S))
	if V10Registry.wired("salon"):
		V10Salon.notify_stars(0)
	if V10Registry.wired("phone"):
		V10Phone.reset()


func _load_game() -> void :
	S = default_state()
	loaded_from = ""
	_main_ok = false
	if demo:

		S.unlocked = 3
		S.stars = {"0": 3, "1": 3}
		S.rp = 50
		S.owned["s_mint"] = true
		S.owned["b_tea"] = true
		S.tut_done = true
		S.level_partner = "mc"
		S.profile_done = true
		S.profile.nick = "Гость"
		return
	for p in [save_path, _tmp_path(), _bak_path()]:
		var d = read_save_file(p)
		if d is Dictionary and apply_state(d):
			loaded_from = p
			_main_ok = p == save_path
			if p != save_path:
				push_warning("G.load_game: main save unreadable, restored from %s" % p)
			return
		elif FileAccess.file_exists(p):
			push_warning("G.load_game: save file %s is damaged, skipped" % p)


func read_save_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f: = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt: = f.get_as_text()
	f.close()
	if txt.strip_edges() == "":
		return null
	var j: = JSON.new()
	if j.parse(txt) != OK:
		return null
	return j.data if j.data is Dictionary else null


func apply_state(d: Dictionary) -> bool:
	if not d.has("gems") or not d.has("unlocked"):
		return false
	var st: = default_state()
	for k in d:
		st[k] = d[k]
	st.ver = int(d.get("ver", 0))
	var prev: = S
	S = st
	_migrate()
	if not (S.get("stars") is Dictionary) or not (S.get("owned") is Dictionary):
		S = prev
		return false
	sync_hidden_items()
	v10_attach()
	return true


func _migrate() -> void :
	if int(S.ver) < 4:
		var old_unl: = int(S.unlocked)
		var ns: = {}
		for k in S.stars:
			ns[str(int(k) * 4)] = S.stars[k]
		S.stars = ns
		S.unlocked = mini(1 + (old_unl - 1) * 4, LEVELS.size())
		S.ver = 4
	if int(S.ver) < 5:
		var ns5: = {}
		for k in S.stars:
			ns5[str(V6Worlds.migrate_index(int(k)))] = S.stars[k]
		S.stars = ns5
		S.unlocked = mini(V6Worlds.migrate_index(maxi(0, int(S.unlocked) - 1)) + 1, LEVELS.size())
		S["v6_map"] = {"chests": {}, "seen": int(S.unlocked)}
		S.ver = 5
	if int(S.ver) < 6:
		S.profile = new_profile()
		S.profile.avatar = str(S.get("partner", "mc"))
		S.profile_done = false
		S.stats = {}
		S.ver = 6
	if int(S.ver) < 7:
		# 0.9: the old «Тряска и вспышки» switch becomes the 3-step effects level
		var v6fx = S.get("v6_fx", {})
		var calm: bool = v6fx is Dictionary and not bool(v6fx.get("shake", true))
		S.fx_level = "mid" if calm else "full"
		S.ult_cutin = "full"
		S.ver = 7
	if not (str(S.get("fx_level", "")) in FX_LEVELS):
		S.fx_level = "full"
	if not (str(S.get("ult_cutin", "")) in ULT_CUTINS):
		S.ult_cutin = "full"
	_sync_v6_fx()
	_ensure_profile()
	S.profile_done = bool(S.get("profile_done", false))
	if not (S.get("stats") is Dictionary):
		S.stats = {}
	# 0.10: SAVE_VER 7 → 8, once (V10Save: v10_meta, v10_afisha, module migrators — economy, profile, meta; ver 8: ensure)
	V10Save.migrate(S)


func fx_level() -> String:
	var l: = str(S.get("fx_level", "full"))
	return l if l in FX_LEVELS else "full"


func set_fx_level(l: String) -> void :
	if not (l in FX_LEVELS):
		push_warning("G.set_fx_level: unknown level '%s'" % l)
		return
	S.fx_level = l
	_sync_v6_fx()
	var tt_sc = load("res://scripts/v10/look/tile_themes.gd")
	if tt_sc != null:
		tt_sc.anim_on = l != "min"
	settings_changed.emit("fx_level")


func ult_cutin() -> String:
	var m: = str(S.get("ult_cutin", "full"))
	return m if m in ULT_CUTINS else "full"


func set_ult_cutin(m: String) -> void :
	if not (m in ULT_CUTINS):
		push_warning("G.set_ult_cutin: unknown mode '%s'" % m)
		return
	S.ult_cutin = m
	settings_changed.emit("ult_cutin")


# V6Fx.shake()/flash() read S.v6_fx.shake/flash (missing = on): only the "full" level keeps them on. Writes only
# what differs, so a save that never touched the keys round-trips unchanged.
func _sync_v6_fx() -> void :
	var on: = str(S.get("fx_level", "full")) == "full"
	var d = S.get("v6_fx")
	if not (d is Dictionary):
		if on:
			return
		d = {}
		S.v6_fx = d
	for k in ["shake", "flash"]:
		if bool(d.get(k, true)) != on:
			d[k] = on


func _tmp_path() -> String:
	return save_path.get_basename() + ".tmp.json"

func _bak_path() -> String:
	return save_path.get_basename() + ".bak.json"


func save() -> void :
	if demo:
		return
	# 0.10: a leftover direct write of S.gems/S.coins becomes a wallet operation; the wallet is sealed into S.econ
	V10Money.sync(S)
	if econ != null and is_same(S.get("econ"), econ.st):
		S.econ = econ.save_dict()
	save_ok = write_atomic(save_path, JSON.stringify(S), _main_ok)
	if save_ok:
		_main_ok = true


func write_atomic(path: String, text: String, keep_backup: = true) -> bool:
	var tmp: = path.get_basename() + ".tmp.json"
	var bak: = path.get_basename() + ".bak.json"
	var f: = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("G.save: cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.flush()
	var werr: = f.get_error()
	f.close()
	if werr != OK:
		push_error("G.save: write failed (%s)" % error_string(werr))
		return false
	if FileAccess.file_exists(path):
		if keep_backup:
			if FileAccess.file_exists(bak):
				DirAccess.remove_absolute(bak)
			if DirAccess.rename_absolute(path, bak) != OK:
				DirAccess.copy_absolute(path, bak)
	var err: = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(path)
		err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("G.save: rename failed (%s)" % error_string(err))
		return false
	return true

func level_stars(i: int) -> int:
	return int(S.stars.get(str(i), 0))

func owns(id: String) -> bool:
	return S.owned.has(id)

# 0.10 (M4): duplicates in gacha go to V10Stars (✦ / Лепестки), never DUP_GEMS; DUP_GEMS stays only for 0.9 UI fallback
const DUP_GEMS: = 25

func give(id: String) -> bool:
	if id == "" or owns(id):
		return false
	S.owned[id] = true
	return true


func give_new(id: String) -> bool:
	return give(id)

func add_aff(hero: String, n: int) -> void :
	if not (S.get("aff") is Dictionary):
		S["aff"] = {}
	S.aff[hero] = maxi(0, int(S.aff.get(hero, 0)) + n)

func aff_level(hero: String) -> int:
	return V10AffCurve.level_for_xp(int(S.get("aff", {}).get(hero, 0)) if S.get("aff") is Dictionary else 0)

func aff_info(hero: String) -> Dictionary:
	return V10AffCurve.progress(int(S.get("aff", {}).get(hero, 0)) if S.get("aff") is Dictionary else 0)

func aff_ratio(hero: String) -> float:
	return float(aff_info(hero).get("ratio", 0.0))

# the outfit image an item actually shows: a retired (hidden) item never shows its own art, even to a save that
# owns it (o_tutor: HEROINES.md §6) — it draws its "alt" until it is redrawn
func item_img(it: Dictionary) -> String:
	if it.get("hidden", false) and it.has("alt"):
		return String(it.alt)
	return String(it.get("img", ""))

func item_tex(it: Dictionary) -> Texture2D:
	if it.has("img"):
		return load("res://assets/outfits/%s.webp" % item_img(it))
	if it.has("tile"):
		return tile_tex(it.tile)
	if it.has("bg"):
		return load("res://assets/bg/%s.webp" % it.bg)
	return null

func tile_tex(i: int) -> Texture2D:
	if i < 0 or i >= TILE_NAMES.size():
		push_warning("tile_tex: face %d has no tile texture" % i)
		i = posmod(i, TILE_NAMES.size())
	return load("res://assets/tiles/%02d_%s.png" % [i, TILE_NAMES[i]])

# 0.8: every icon goes through the one V8Art cache (cur/*, nav/*, icon/*); a name with no 0.8 art falls back to the
# old v06/hud or assets/icons texture inside V8Art.old_icon()
func icon(name: String) -> Texture2D:
	return Common.ui_icon(name)

# particles only (glow, sparkle, petal, star …): white textures drawn additively and tinted. Rating stars are 0.8
# art and never come through here: call V8Art.star() / V8Art.star_rect() for those.
func fx(name: String) -> Texture2D:
	return load("res://assets/fx/%s.png" % name)

# 0.10: one rarity palette (A / S / SSR) — V10Rank
func rar_color(r: String) -> Color:
	return V10Rank.color(r)


func art_tex(it: Dictionary) -> Texture2D:

	if S.get("modest", false) and (it.get("bold", false) or not bool(it.get("sfw", true))) and it.has("alt"):
		return load("res://assets/outfits/%s.webp" % it.alt)
	return item_tex(it)

# 0.10 (spec §2.5): the daily day starts at 04:00 phone time and never rolls back (V10Meta, the one clock)
func today() -> String:
	return V10Meta.day_key()

func days_between(a: String, b: String) -> int:
	if a == "" or b == "":
		return 9999
	return int((Time.get_unix_time_from_datetime_string(b) - Time.get_unix_time_from_datetime_string(a)) / 86400)

func hero_unlocked(h: String) -> bool:
	if h == "mc" or int(S.shards.get(h, 0)) >= SHARDS_NEED:
		return true
	for it in ITEMS:
		if it.get("hero", "") == h and owns(it.id):
			return true
	return false

func summon_open() -> bool:
	return int(S.unlocked) >= 4

func tasks() -> Dictionary:
	if S.tasks.get("day", "") != today():
		S.tasks = {"day": today(), "pairs": 0, "levels": 0, "combo5": 0, "claimed": [false, false, false]}
	return S.tasks

const TASKS: = [
	{"key": "pairs", "name": "Собери 40 пар", "goal": 40, "gems": 60}, 
	{"key": "levels", "name": "Сыграй 2 партии", "goal": 2, "gems": 60}, 
	{"key": "combo5", "name": "Собери серию ×5", "goal": 1, "gems": 80}, 
]

func task_add(key: String, n: = 1) -> void :
	var t: = tasks()
	t[key] = int(t.get(key, 0)) + n

func tasks_ready() -> int:
	var t: = tasks()
	var n: = 0
	for i in TASKS.size():
		if int(t[TASKS[i].key]) >= TASKS[i].goal and not t.claimed[i]:
			n += 1
	return n

func pet_left() -> int:
	if S.pet.get("day", "") != today():
		S.pet = {"day": today(), "n": 0}
	return 3 - int(S.pet.n)

const LOGIN_REWARDS: = [
	{"gems": 50}, {"gems": 50}, {"coins": 500}, {"gems": 100}, {"gems": 50}, {"coins": 1000}, {"gems": 300}, 
]

func login_ready() -> bool:
	return S.login.get("last", "") != today()

func dailymap() -> Dictionary:
	var m: = today().substr(0, 7)
	if S.dailymap.get("month", "") != m:
		S.dailymap = {"month": m, "done": []}
	return S.dailymap

func daily_done_today() -> bool:
	return int(today().substr(8, 2)) in dailymap().done.map( func(x): return int(x))

func pass_tier() -> int:
	return mini(30, int(S.pass.xp) / 100)

func add_pass_xp(n: int) -> void :
	S.pass.xp = int(S.pass.xp) + n
	if econ != null:
		econ.pass_.add_xp(n)

func month_card_days() -> int:
	if econ != null and econ.shop.month_days_left() > 0:
		return econ.shop.month_days_left()
	var u: String = S.month_card.get("until", "")
	if u == "":
		return 0
	return maxi(0, days_between(today(), u))




func _make_gacha() -> V10Gacha2:
	var bk: = V10GachaBank.new(S)
	bk.live_money = true
	bk.give_fn = func(id: String) -> bool: return give_new(id)
	return V10Gacha2.new(S, ITEMS, bk)


func roll() -> String:
	var g2: = _make_gacha()
	var b: Dictionary = g2.banners()[0]
	if not g2.can_pull(b, 1):
		V10Money.grant({"tickets": 1}, "roll_proxy")
	var r: Array = g2.pull(b, 1)
	if r.is_empty():
		return "R"
	return V10Gacha2.rar09(String(r[0].rar))


func pull(n: int, banner: Dictionary, gifted: bool = false) -> Array:
	var g2: = _make_gacha()
	var bl: = g2.banners()
	var b: Dictionary = bl[0]
	for cand in bl:
		if (banner.get("newbie", false) and String(cand.get("kind", "")) == "newbie") or String(cand.get("hero", "")) == String(banner.get("hero", "")):
			b = cand
			break
	if gifted or not g2.can_pull(b, n):
		V10Money.grant({"tickets": n}, "pull_proxy")
	var raw: = g2.pull(b, n)
	save()
	var out: = []
	for r in raw:
		var it: Dictionary = r.get("item", ITEM.get(String(r.get("id", "")), {}))
		var o: Dictionary = it.duplicate()
		o["rar"] = V10Gacha2.rar09(String(r.rar))
		o["new"] = bool(r.get("new", false))
		o["v10"] = r
		out.append(o)
	return out
