class_name V10Feats
extends RefCounted

# V10Feats — 40 achievements of Profile 2.0 (docs/0.10-spec.md §D5). Pure data + pure checks over an unlock
# context (V10ProfileCos.ctx_from_save): titles and badges in V10ProfileCos point at a feat with
# {"type": "feat", "id": "<feat id>"}. Feats never reward spending (no «N желаний», no purchases).
#
#   V10Feats.FEATS                      [{id, name, desc, stat, n, tier}]  tier = A / S / SSR (colour only)
#   V10Feats.get_feat(id)               the entry or {}
#   V10Feats.done(id, ctx)              ctx.stats[stat] >= n
#   V10Feats.progress(id, ctx)          [have, need]
#   V10Feats.done_list(ctx)             ids of every finished feat
#
# Counters that the 0.9 save does not keep yet live in S.v10_feats.stats and are fed by the integrator through
#   V10Feats.bump(S, "clean", 1)        (+n to a counter)
#   V10Feats.best(S, "best_combo", 12)  (keep the maximum)
# from V10Hooks.game_ended / pair_taken (see README «Хуки»). Everything else is derived from the save.

const STATS: = ["games", "wins", "best_combo", "clean", "dragons", "streak_best", "daily_done", "summits", "arcs",
	"legends", "letters", "gifts", "heroes", "outfits", "aff_max_lv", "rank_best", "league_best", "duel_wins",
	"pagoda_heat", "salon_zones", "ostars_max"]

const FEATS: = [
	{"id": "f_first_win", "name": "Первая победа", "desc": "Выиграй первую партию", "stat": "wins", "n": 1, "tier": "A"},
	{"id": "f_wins_10", "name": "Десять побед", "desc": "Выиграй 10 партий", "stat": "wins", "n": 10, "tier": "A"},
	{"id": "f_wins_100", "name": "Сто побед", "desc": "Выиграй 100 партий", "stat": "wins", "n": 100, "tier": "S"},
	{"id": "f_wins_500", "name": "Пятьсот побед", "desc": "Выиграй 500 партий", "stat": "wins", "n": 500, "tier": "SSR"},
	{"id": "f_games_100", "name": "Сто партий", "desc": "Сыграй 100 партий", "stat": "games", "n": 100, "tier": "A"},
	{"id": "f_games_1000", "name": "Тысяча партий", "desc": "Сыграй 1000 партий", "stat": "games", "n": 1000, "tier": "S"},
	{"id": "f_combo_5", "name": "Комбо ×5", "desc": "Собери комбо из 5 пар", "stat": "best_combo", "n": 5, "tier": "A"},
	{"id": "f_combo_10", "name": "Комбо ×10", "desc": "Собери комбо из 10 пар", "stat": "best_combo", "n": 10, "tier": "S"},
	{"id": "f_combo_15", "name": "Комбо ×15", "desc": "Собери комбо из 15 пар", "stat": "best_combo", "n": 15, "tier": "SSR"},
	{"id": "f_clean_10", "name": "Чистая рука ×10", "desc": "10 побед без помощи и переполнений", "stat": "clean", "n": 10, "tier": "A"},
	{"id": "f_clean_100", "name": "Чистая рука ×100", "desc": "100 побед без помощи и переполнений", "stat": "clean", "n": 100, "tier": "S"},
	{"id": "f_dragon_1", "name": "Пробуждение дракона", "desc": "Собери яку «Пробуждение дракона»", "stat": "dragons", "n": 1, "tier": "A"},
	{"id": "f_dragon_25", "name": "Повелитель драконов", "desc": "25 раз «Пробуждение дракона»", "stat": "dragons", "n": 25, "tier": "S"},
	{"id": "f_streak_7", "name": "Неделя чая", "desc": "Серия чая 7 дней", "stat": "streak_best", "n": 7, "tier": "A"},
	{"id": "f_streak_30", "name": "Чайный мастер", "desc": "Серия чая 30 дней", "stat": "streak_best", "n": 30, "tier": "S"},
	{"id": "f_streak_100", "name": "Сто чашек", "desc": "Серия чая 100 дней", "stat": "streak_best", "n": 100, "tier": "SSR"},
	{"id": "f_streak_365", "name": "Год у стола", "desc": "Серия чая 365 дней", "stat": "streak_best", "n": 365, "tier": "SSR"},
	{"id": "f_daily_10", "name": "Раскладка ×10", "desc": "10 партий дня", "stat": "daily_done", "n": 10, "tier": "A"},
	{"id": "f_daily_100", "name": "Раскладка ×100", "desc": "100 партий дня", "stat": "daily_done", "n": 100, "tier": "S"},
	{"id": "f_summit_1", "name": "Первая вершина", "desc": "Пройди первый Пик", "stat": "summits", "n": 1, "tier": "A"},
	{"id": "f_summit_10", "name": "Покоритель вершин", "desc": "Пройди 10 Пиков", "stat": "summits", "n": 10, "tier": "S"},
	{"id": "f_summit_50", "name": "Над облаками", "desc": "Пройди 50 Пиков", "stat": "summits", "n": 50, "tier": "SSR"},
	{"id": "f_arc_1", "name": "Путник арки", "desc": "Пройди первую арку Пути", "stat": "arcs", "n": 1, "tier": "A"},
	{"id": "f_legend_1", "name": "Легенда арки", "desc": "Победи Легендарный уровень без обходной тропы", "stat": "legends", "n": 1, "tier": "SSR"},
	{"id": "f_letters_50", "name": "Хранитель писем", "desc": "Прочитай 50 писем", "stat": "letters", "n": 50, "tier": "A"},
	{"id": "f_gifts_20", "name": "Щедрая душа", "desc": "Подари богиням 20 подарков", "stat": "gifts", "n": 20, "tier": "A"},
	{"id": "f_heroes_5", "name": "Все основательницы", "desc": "Открой пять основательниц салона", "stat": "heroes", "n": 5, "tier": "S"},
	{"id": "f_heroes_10", "name": "Десять богинь", "desc": "Открой 10 богинь", "stat": "heroes", "n": 10, "tier": "S"},
	{"id": "f_heroes_20", "name": "Признан всеми", "desc": "Открой всех 20 богинь", "stat": "heroes", "n": 20, "tier": "SSR"},
	{"id": "f_outfits_10", "name": "Гардероб", "desc": "Собери 10 нарядов", "stat": "outfits", "n": 10, "tier": "S"},
	{"id": "f_aff_10", "name": "Сердце богини", "desc": "Симпатия 10 с любой богиней", "stat": "aff_max_lv", "n": 10, "tier": "S"},
	{"id": "f_rank_3", "name": "Золотой ранг", "desc": "Достигни ранга Золото", "stat": "rank_best", "n": 3, "tier": "A"},
	{"id": "f_rank_5", "name": "Небожитель", "desc": "Достигни ранга Небожитель", "stat": "rank_best", "n": 5, "tier": "SSR"},
	{"id": "f_league_3", "name": "Золотая лига", "desc": "Сыграй неделю в Лиге Золота", "stat": "league_best", "n": 3, "tier": "S"},
	{"id": "f_league_5", "name": "Небесная лига", "desc": "Сыграй неделю в Лиге Небожителей", "stat": "league_best", "n": 5, "tier": "SSR"},
	{"id": "f_duel_10", "name": "Дуэлянт", "desc": "Выиграй 10 дуэлей", "stat": "duel_wins", "n": 10, "tier": "A"},
	{"id": "f_duel_100", "name": "Мастер дуэлей", "desc": "Выиграй 100 дуэлей", "stat": "duel_wins", "n": 100, "tier": "S"},
	{"id": "f_pagoda_32", "name": "Жар Пагоды", "desc": "Набери 32 Жара в Пагоде", "stat": "pagoda_heat", "n": 32, "tier": "SSR"},
	{"id": "f_salon_6", "name": "Салон в цвету", "desc": "Открой все 6 зон салона", "stat": "salon_zones", "n": 6, "tier": "S"},
	{"id": "f_ostar_5", "name": "Созвездие ★5", "desc": "Подними наряд до ★5", "stat": "ostars_max", "n": 5, "tier": "SSR"},
]

static var _by_id: = {}


static func get_feat(id: String) -> Dictionary:
	if _by_id.is_empty():
		for f in FEATS:
			_by_id[f.id] = f
	return _by_id.get(id, {})


static func stat(ctx: Dictionary, key: String) -> int:
	var st = ctx.get("stats", {})
	return int(st.get(key, 0)) if st is Dictionary else 0


static func done(id: String, ctx: Dictionary) -> bool:
	var f: = get_feat(id)
	return not f.is_empty() and stat(ctx, String(f.stat)) >= int(f.n)


static func progress(id: String, ctx: Dictionary) -> Array:
	var f: = get_feat(id)
	if f.is_empty():
		return [0, 0]
	return [mini(stat(ctx, String(f.stat)), int(f.n)), int(f.n)]


static func done_list(ctx: Dictionary) -> Array:
	var out: = []
	for f in FEATS:
		if done(f.id, ctx):
			out.append(f.id)
	return out


# ---- save-side counters (S.v10_feats = {stats: {}, done: {id: day}}) ------------------------------------------

static func _box(S: Dictionary) -> Dictionary:
	if not (S.get("v10_feats") is Dictionary):
		S["v10_feats"] = {}
	var b: Dictionary = S.v10_feats
	if not (b.get("stats") is Dictionary):
		b["stats"] = {}
	if not (b.get("done") is Dictionary):
		b["done"] = {}
	return b


static func bump(S: Dictionary, key: String, n: = 1) -> void:
	var st: Dictionary = _box(S).stats
	st[key] = int(st.get(key, 0)) + n


static func best(S: Dictionary, key: String, v: int) -> void:
	var st: Dictionary = _box(S).stats
	st[key] = maxi(int(st.get(key, 0)), v)
