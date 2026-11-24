class_name V10SalonData
extends RefCounted

# Салон Пяти ветров — data only (docs/0.10-spec.md §Р1–Р2). No logic here: V10Salon reads it.
#
# A zone is one painted room in two states (art in res://assets/v10/salon/):
#   <zid>_broken.webp  ruined (cold, dusty)        <zid>_done.webp   restored (warm evening)
# Both are 1200×896 and pixel-aligned (the broken one was painted as an edit of the done one), so a task
# restores by revealing the done art inside its rects (salon_zone.gdshader). Rects are normalised to the art
# (x, y, w, h) and listed back → front: a later rect occludes an earlier one (painter's order), so a stool in
# front of the counter keeps its ruined look until the stool itself is restored. Whatever no task covers
# (sky, walls, floor) turns warm in the zone finale («свет волной»).
#
# `layer` sets the painter's order of a task's rects (higher = in front). `anchor` = where its tag hangs.
# Costs: z1 3+4+5+6+7 = 25★, z2 4+5+6+7+8+10 = 40★, z3 5+6+7+8+9+10+10 = 55★ (spec). Нефрит = +ceil(cost/2).

const ART: = "res://assets/v10/salon/"
const ZONE_ASPECT: = 1200.0 / 896.0

const ZONES: = [
	{
		"id": "z1", "key": "gate", "arc": 1, "name": "Ворота и вывеска", "hero": "mc",
		"scene": "Маджонг-тян у входа", "scene_bg": "z1_lobby.webp", "lobby": "z1_lobby.webp",
		"chest": "c1", "accent": Color("e8a6b8"),
		"intro": "Здесь всё начиналось. Поможешь вернуть свет у входа?",
		"finale_line": "Смотри, фонари снова горят. Теперь к нам точно заглянут гости!",
		"tasks": [
			{"id": "t5", "name": "Сакура и двор", "cost": 7, "anchor": Vector2(0.10, 0.62), "layer": 0,
				"rects": [[0.0, 0.0, 0.19, 0.88], [0.19, 0.0, 0.44, 0.17], [0.76, 0.47, 0.24, 0.42], [0.0, 0.87, 1.0, 0.13]]},
			{"id": "t4", "name": "Двери салона", "cost": 6, "anchor": Vector2(0.50, 0.66), "layer": 1,
				"rects": [[0.31, 0.49, 0.38, 0.38]]},
			{"id": "t3", "name": "Колокольчики ветров", "cost": 5, "anchor": Vector2(0.50, 0.41), "layer": 2,
				"rects": [[0.35, 0.34, 0.30, 0.15]]},
			{"id": "t2", "name": "Фонари у входа", "cost": 4, "anchor": Vector2(0.77, 0.45), "layer": 3,
				"rects": [[0.18, 0.32, 0.10, 0.31], [0.72, 0.32, 0.10, 0.31]]},
			{"id": "t1", "name": "Вывеска", "cost": 3, "anchor": Vector2(0.50, 0.25), "layer": 4,
				"rects": [[0.31, 0.17, 0.39, 0.17]]},
		],
	},
	{
		"id": "z2", "key": "counter", "arc": 1, "name": "Чайная стойка", "hero": "rin",
		"scene": "Рин за стойкой", "scene_bg": "z2_scene_rin.webp", "lobby": "z2_lobby.webp",
		"chest": "c2", "accent": Color("a9d9c4"),
		"intro": "Стойка Рин. Без неё в салоне не пахнет чаем.",
		"finale_line": "Чай заварен. Садись, первая чашка — тебе.",
		"tasks": [
			{"id": "t3", "name": "Полки и чайницы", "cost": 6, "anchor": Vector2(0.64, 0.27), "layer": 0,
				"rects": [[0.25, 0.09, 0.66, 0.40]]},
			{"id": "t1", "name": "Бумажный фонарь", "cost": 4, "anchor": Vector2(0.43, 0.30), "layer": 1,
				"rects": [[0.35, 0.0, 0.17, 0.36]]},
			{"id": "t4", "name": "Жаровня и чайник", "cost": 7, "anchor": Vector2(0.92, 0.50), "layer": 2,
				"rects": [[0.86, 0.34, 0.14, 0.23]]},
			{"id": "t2", "name": "Стойка и поднос", "cost": 5, "anchor": Vector2(0.52, 0.62), "layer": 3,
				"rects": [[0.04, 0.53, 0.96, 0.42], [0.17, 0.30, 0.17, 0.29]]},
			{"id": "t5", "name": "Табуреты", "cost": 8, "anchor": Vector2(0.68, 0.80), "layer": 4,
				"rects": [[0.18, 0.69, 0.16, 0.31], [0.60, 0.69, 0.17, 0.31]]},
			{"id": "t6", "name": "Ширма со сливой", "cost": 10, "anchor": Vector2(0.10, 0.42), "layer": 5,
				"rects": [[0.0, 0.12, 0.21, 0.76]]},
		],
	},
	{
		"id": "z3", "key": "study", "arc": 1, "name": "Кабинет хозяйки", "hero": "mc",
		"scene": "Вечер в кабинете", "scene_bg": "z3_lobby.webp", "lobby": "z3_lobby.webp",
		"chest": "c3", "accent": Color("c9a7e8"),
		"intro": "Мой кабинет. Тут я храню все свои секреты… почти все.",
		"finale_line": "Мой кабинет снова мой. Заходи без стука — тебе можно.",
		"tasks": [
			{"id": "t1", "name": "Лунное окно", "cost": 5, "anchor": Vector2(0.43, 0.22), "layer": 0,
				"rects": [[0.26, 0.04, 0.33, 0.42]]},
			{"id": "t2", "name": "Книжный шкаф", "cost": 6, "anchor": Vector2(0.10, 0.25), "layer": 1,
				"rects": [[0.0, 0.0, 0.22, 0.47]]},
			{"id": "t4", "name": "Ширма пяти ветров", "cost": 8, "anchor": Vector2(0.83, 0.33), "layer": 2,
				"rects": [[0.66, 0.18, 0.34, 0.38]]},
			{"id": "t3", "name": "Письменный стол", "cost": 7, "anchor": Vector2(0.43, 0.52), "layer": 3,
				"rects": [[0.23, 0.33, 0.41, 0.30]]},
			{"id": "t5", "name": "Тахта", "cost": 9, "anchor": Vector2(0.13, 0.62), "layer": 4,
				"rects": [[0.0, 0.45, 0.29, 0.31]]},
			{"id": "t6", "name": "Маджонг-стол", "cost": 10, "anchor": Vector2(0.72, 0.68), "layer": 5,
				"rects": [[0.48, 0.51, 0.52, 0.46]]},
			{"id": "t7", "name": "Фонарь и курильница", "cost": 10, "anchor": Vector2(0.80, 0.12), "layer": 6,
				"rects": [[0.74, 0.0, 0.12, 0.21], [0.58, 0.0, 0.07, 0.26], [0.02, 0.73, 0.22, 0.18]]},
		],
	},
]

# Arc 2 (M6): shown as ONE silhouette teaser «Следующая зона откроется с аркой 2» (UX_RULES §6.4: one locked teaser).
const LATER: = [
	{"id": "z4", "key": "yard", "arc": 2, "name": "Фонарный двор", "hero": "hana", "total": 60},
	{"id": "z5", "key": "veranda", "arc": 2, "name": "Лунная веранда", "hero": "yue", "total": 65},
	{"id": "z6", "key": "loft", "arc": 2, "name": "Мансарда Новы", "hero": "nova", "total": 70},
]

# Chests (spec §Р1): z1 — 100 кр, 1 подсказка, 1 шаффл; z2/z4/z5 — 150 кр + подсказка, шаффл, отмена;
# z3/z6 — то же + 1 чайный лист + 1 билет. Keys follow the 0.10 glossary (§2.1).
const CHESTS: = {
	"c1": {"gems": 100, "hint": 1, "shuffle": 1},
	"c2": {"gems": 150, "hint": 1, "shuffle": 1, "undo": 1},
	"c3": {"gems": 150, "hint": 1, "shuffle": 1, "undo": 1, "leaves": 1, "tickets": 1},
}
const CHEST_NAMES: = {"gems": "Кристаллы", "hint": "Подсказка", "shuffle": "Перемешать", "undo": "Отмена",
	"leaves": "Чайный лист", "tickets": "Билет желания"}

# Finishes: lacquer comes with the restore; jade costs +ceil(cost/2); seasonal is a season-pass flag (M4).
const FINISHES: = ["lacquer", "jade", "season"]
const FINISH_NAMES: = {"lacquer": "Лак", "jade": "Нефрит", "season": "Сезонная"}

# Heroine scene lines: 3 per affinity threshold (levels 0/3/6/9 → tiers 0..3), never the same twice in a row.
# Warm, a little flirty, always adult; no pressure words (V10Lint.BANNED — checked by the selftest).
const LINES: = {
	"mc": [
		["Ну как тебе? Я весь день выбирала, где повесить фонари.", "Не стой в дверях — проходи, здесь тепло.", "Салон оживает, когда ты рядом. Странно, правда?"],
		["Сыграем вечером? Я даже дам тебе фору… может быть.", "Ты так смотришь, будто я тоже часть интерьера.", "Тсс. Слышишь колокольчики? Это ветер тебя узнал."],
		["Знаешь, я привыкла ждать твоих шагов на ступенях.", "Подойди ближе — хочу поправить тебе воротник.", "Если проиграешь мне партию, сваришь чай. Договорились?"],
		["Этот салон — наш. Я так и записала в книге гостей.", "Останься до первых фонарей. Мне с тобой спокойно.", "Когда ты смеёшься, мне хочется выиграть ещё раз."],
	],
	"rin": [
		["Чай любит тишину. И терпеливых гостей.", "Садись. Первая заварка — для того, кто вернул стойку.", "Очки запотели… Не смотри, я сейчас."],
		["Улун сегодня мягкий. Почти как ты в проигрыше.", "Ты пьёшь слишком быстро. Я налью ещё — медленнее.", "Здесь пахнет жасмином. Это я выбрала для тебя."],
		["Я научу тебя держать пиалу. Дай руку… вот так.", "Ты единственный гость, ради кого я грею воду дважды.", "Если задержишься, заварю редкий лист. Секрет."],
		["Лёд тает медленно. Но со мной это уже случилось.", "Мой чай теперь пахнет вечерами с тобой.", "Останься. Я не умею говорить это иначе."],
	],
}

# What a heroine says when the player taps an empty spot of her scene (neutral glance, no reaction animation).
const NEUTRAL: = {"mc": "М? Что там?", "rin": "Хм?"}

# The salon's first-visit intro and the «уже есть звёзды» variant for 0.9 players (migration, spec §Р1 «Данные»).
const INTRO_NEW: = "Пойдём, покажу, что осталось от салона."
const INTRO_OLD: = "У тебя уже %d★ — давай вернём салону свет."


static func zone(zid: String) -> Dictionary:
	for z in ZONES:
		if z.id == zid:
			return z
	return {}


static func task(zid: String, tid: String) -> Dictionary:
	for t in zone(zid).get("tasks", []):
		if t.id == tid:
			return t
	return {}


static func zone_total(zid: String) -> int:
	var n: = 0
	for t in zone(zid).get("tasks", []):
		n += int(t.cost)
	return n


static func jade_cost(cost: int) -> int:
	return int(ceil(cost / 2.0))


# tasks of a zone in the order the player is guided through them (cheapest first, then by id)
static func tasks_by_cost(zid: String) -> Array:
	var ts: Array = zone(zid).get("tasks", []).duplicate()
	ts.sort_custom(func(a, b): return a.cost < b.cost or (a.cost == b.cost and a.id < b.id))
	return ts


static func zone_ids() -> Array:
	var r: = []
	for z in ZONES:
		r.append(z.id)
	return r
