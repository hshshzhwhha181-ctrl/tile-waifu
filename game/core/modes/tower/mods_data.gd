class_name V10ModsData
extends RefCounted

# Data of the shared modifier engine (spec R1): blessings of the goddesses and the curses («проклятия») that
# give «Жар». One table for Пагода Луны and Странствие. Logic lives in mods.gd (V10Mods).
#
# Effect primitives (every blessing / curse level is a small dict of these; V10Mods.resolve() sums them):
#   lamps, lamp_cap, hearts            run lives: Pagoda lanterns (start 3, max 5) / Journey hearts (3)
#   slots                              tray size delta (base 4, clamp 3..6)
#   hint, undo, shuffle                booster counts delta per floor / board
#   hint_off, undo_off, shuffle_off    bools: that help is off
#   ult_off                            bool: no ult this floor
#   ult_start                          0..1 ult charge at the start (max of all)
#   ult_every                          every N-th pair gives +1 ult charge (smallest wins)
#   ult_need_mult                      ult charge needed × (product)
#   combo_window                       + seconds the combo holds
#   start_pairs                        pairs removed at the start (step order: never breaks solvability)
#   open_tiles                         covered tiles made free at the start (board.open_tile, never breaks solvability)
#   gold_extra, gold_mult              more gold pairs on the table; gold value × (product)
#   no_hidden, no_ice                  bools: no secret tiles / no ice
#   shroud                             0..2: 1 = covered tiles face down (cfg.hidden), 2 = every tile that is not free
#   fog                                0..2: a share of the table under a veil (faces unseen) until N pairs are taken
#   fog_lift_mult                      × pairs needed to lift the fog (product)
#   guards                             + ice tiles (V6/0.9 ice: a tap flips it before it can be taken)
#   greedy                             0..3: bigger table, more kinds of tiles
#   time_per_tile                      hourglass: seconds per tile of the table (0 = none; smallest wins); the clock of a
#                                      floor = tiles × this + time_bonus; time out = like an overflow, clock refills
#   time_bonus                         + seconds to the time limit
#   shield                             overflows forgiven per floor (no lantern / heart lost)
#   return_all                         bool: an overflow returns the whole tray, not 3 tiles
#   auto_every                         every N-th pair the wind takes one more pair (step order)
#   peek_secs                          face-down tiles show their faces for N s at the start
#   first_hint                         bool: a free hint at the start of every floor
#   lamp_one                           bool: one lantern / heart for the whole run, blessings cannot add more

# ---------------------------------------------------------------- blessings
# hero: the goddess. A blessing is offered only when she is in the build (G.HEROES); "plus" (the stronger effect,
# gold «+» edge) only when the player owns her AND the mode is personal (Pagoda). Journey is normalized: base only.
# The ten founders' blessings keep the ids, names and texts of V6ModesData.BLESS (0.6 «Лунная лестница»).
const BLESS: = {
	"lamp": {"hero": "mc", "name": "Тёплое слово", "desc": "+1 фонарь", "plus": "+2 фонаря",
		"eff": {"lamps": 1}, "eff_plus": {"lamps": 2}, "cap": 99},
	"tips": {"hero": "mc", "name": "Совет хозяйки", "desc": "+2 подсказки", "plus": "+3 подсказки",
		"eff": {"hint": 2}, "eff_plus": {"hint": 3}},
	"cup": {"hero": "rin", "name": "Лишняя чашка", "desc": "+1 место в лотке", "plus": "+1 место и +1 отмена",
		"eff": {"slots": 1}, "eff_plus": {"slots": 1, "undo": 1}, "cap": 2},
	"pause": {"hero": "rin", "name": "Чайная пауза", "desc": "+3 отмены", "plus": "+4 отмены",
		"eff": {"undo": 3}, "eff_plus": {"undo": 4}},
	"breath": {"hero": "hana", "name": "Второе дыхание", "desc": "Комбо держится на 1,5 с дольше", "plus": "Комбо держится на 2,5 с дольше",
		"eff": {"combo_window": 1.5}, "eff_plus": {"combo_window": 2.5}},
	"warmup": {"hero": "hana", "name": "Разминка", "desc": "Каждый этаж начинается с одной снятой пары", "plus": "Каждый этаж начинается с двух снятых пар",
		"eff": {"start_pairs": 1}, "eff_plus": {"start_pairs": 2}},
	"silver": {"hero": "yue", "name": "Лунное серебро", "desc": "На этажах больше золота, золото ×2", "plus": "Больше золота, золото ×3",
		"eff": {"gold_extra": 4, "gold_mult": 2.0}, "eff_plus": {"gold_extra": 4, "gold_mult": 3.0}},
	"clear": {"hero": "yue", "name": "Ясная ночь", "desc": "Тайные фишки открыты, льда нет", "plus": "Тайных и льда нет, +1 подсказка",
		"eff": {"no_hidden": true, "no_ice": true}, "eff_plus": {"no_hidden": true, "no_ice": true, "hint": 1}, "once": true},
	"backdoor": {"hero": "nova", "name": "Бэкдор", "desc": "+1 смешивание на каждом этаже", "plus": "+2 смешивания на каждом этаже",
		"eff": {"shuffle": 1}, "eff_plus": {"shuffle": 2}},
	"overclock": {"hero": "nova", "name": "Разгон", "desc": "Приём героини заряжен наполовину в начале этажа", "plus": "Приём героини готов в начале этажа",
		"eff": {"ult_start": 0.5}, "eff_plus": {"ult_start": 1.0}},
	# ---- one per new goddess (docs/ROSTER_20.md); hidden until she is in G.HEROES
	"smoke": {"hero": "tsubame", "name": "Дымовая завеса", "desc": "Первый переполненный лоток на этаже прощён", "plus": "Первый перебор прощён, +1 отмена",
		"eff": {"shield": 1}, "eff_plus": {"shield": 1, "undo": 1}, "cap": 2},
	"sugar": {"hero": "miel", "name": "Сахарная пудра", "desc": "Каждая 4-я пара даёт заряд приёма", "plus": "Каждая 3-я пара даёт заряд приёма",
		"eff": {"ult_every": 4}, "eff_plus": {"ult_every": 3}, "once": true},
	"river": {"hero": "lian", "name": "Течение реки", "desc": "+20 с к часам, комбо держится на 1 с дольше", "plus": "+30 с к часам, комбо +1,5 с",
		"eff": {"time_bonus": 20, "combo_window": 1.0}, "eff_plus": {"time_bonus": 30, "combo_window": 1.5}},
	"lasso": {"hero": "jess", "name": "Лассо", "desc": "В начале этажа одна фишка из-под завала становится свободной", "plus": "Две фишки из-под завала свободны",
		"eff": {"open_tiles": 1}, "eff_plus": {"open_tiles": 2}},
	"onsen": {"hero": "tsuru", "name": "Горячий источник", "desc": "Переполнение возвращает весь лоток, +1 отмена", "plus": "Возвращает весь лоток, +2 отмены",
		"eff": {"return_all": true, "undo": 1}, "eff_plus": {"return_all": true, "undo": 2}, "once": true},
	"foxluck": {"hero": "kohaku", "name": "Лисья удача", "desc": "Подсказка в начале каждого этажа, +1 подсказка", "plus": "Подсказка в начале этажа, +2 подсказки",
		"eff": {"first_hint": true, "hint": 1}, "eff_plus": {"first_hint": true, "hint": 2}},
	"mirage": {"hero": "shirin", "name": "Мираж", "desc": "Фишки рубашкой вверх показывают лица 3 с в начале этажа", "plus": "Лица видны 5 с",
		"eff": {"peek_secs": 3.0}, "eff_plus": {"peek_secs": 5.0}, "once": true},
	"storm": {"hero": "mari", "name": "Попутный шторм", "desc": "+2 смешивания на каждом этаже", "plus": "+3 смешивания на каждом этаже",
		"eff": {"shuffle": 2}, "eff_plus": {"shuffle": 3}},
	"thunder": {"hero": "hibana", "name": "Раскат", "desc": "Каждая 12-я пара уносит с собой ещё одну", "plus": "Каждая 9-я пара уносит ещё одну",
		"eff": {"auto_every": 12}, "eff_plus": {"auto_every": 9}, "once": true},
	"trail": {"hero": "nemi", "name": "Тропа следопыта", "desc": "Туман рассеивается вдвое быстрее", "plus": "Туман рассеивается втрое быстрее",
		"eff": {"fog_lift_mult": 0.5}, "eff_plus": {"fog_lift_mult": 0.34}, "once": true},
	"feather": {"hero": "zlata", "name": "Перо жар-птицы", "desc": "+1 фонарь сверх предела", "plus": "+2 фонаря, предел +1",
		"eff": {"lamps": 1, "lamp_cap": 1}, "eff_plus": {"lamps": 2, "lamp_cap": 1}, "once": true},
	"pearl": {"hero": "minamo", "name": "Жемчужина", "desc": "Льда нет, +1 отмена", "plus": "Льда нет, +2 отмены",
		"eff": {"no_ice": true, "undo": 1}, "eff_plus": {"no_ice": true, "undo": 2}, "once": true},
	"boost": {"hero": "kira", "name": "Форсаж", "desc": "Приёму нужно на четверть меньше зарядов", "plus": "Приёму нужно на две пятых меньше зарядов",
		"eff": {"ult_need_mult": 0.75}, "eff_plus": {"ult_need_mult": 0.6}, "once": true},
	"pact": {"hero": "vesper", "name": "Гранатовый договор", "desc": "+1 место в лотке, но фишки под другими рубашкой вверх", "plus": "+1 место в лотке без условий",
		"eff": {"slots": 1, "shroud": 1}, "eff_plus": {"slots": 1}, "once": true},
	"aurora": {"hero": "sigrid", "name": "Северное сияние", "desc": "+30 с к часам, лица видны 2 с в начале этажа", "plus": "+45 с к часам, лица видны 3 с",
		"eff": {"time_bonus": 30, "peek_secs": 2.0}, "eff_plus": {"time_bonus": 45, "peek_secs": 3.0}},
}
const BLESS_ORDER: = ["lamp", "tips", "cup", "pause", "breath", "warmup", "silver", "clear", "backdoor", "overclock",
	"smoke", "sugar", "river", "lasso", "onsen", "foxluck", "mirage", "storm", "thunder", "trail", "feather", "pearl",
	"boost", "pact", "aurora"]
const BLESS_CAP_DEFAULT: = 3
# blessings that make no sense in a mode (Journey has hearts and no lantern cap, no hourglass by default)
const BLESS_SKIP: = {"journey": ["feather"], "practice": ["feather"]}

# ---------------------------------------------------------------- curses
# Each curse has 1..3 levels; a level replaces the lower one (heat is the level's own value, not a sum of levels).
# All curses at their top level = 34 «Жар» (spec R1). Names are «алая тушь на лаке» cards: title + one line.
const CURSES: = {
	"shroud": {"name": "Рубашка", "levels": [
		{"heat": 2, "desc": "Фишки под другими лежат рубашкой вверх", "eff": {"shroud": 1}},
		{"heat": 4, "desc": "Рубашкой вверх всё, что ещё не свободно", "eff": {"shroud": 2}}]},
	"hourglass": {"name": "Песочные часы", "levels": [
		{"heat": 2, "desc": "3 секунды на каждую фишку стола; время вышло — гаснет фонарь", "eff": {"time_per_tile": 3.0}},
		{"heat": 4, "desc": "2 секунды на каждую фишку стола; время вышло — гаснет фонарь", "eff": {"time_per_tile": 2.0}},
		{"heat": 6, "desc": "1,5 секунды на каждую фишку; время вышло — гаснет фонарь", "eff": {"time_per_tile": 1.5}}]},
	"greedy": {"name": "Жадность", "levels": [
		{"heat": 1, "desc": "Стол больше на десятую часть, видов фишек больше", "eff": {"greedy": 1}},
		{"heat": 2, "desc": "Стол больше на пятую часть, видов фишек больше", "eff": {"greedy": 2}},
		{"heat": 4, "desc": "Стол больше на треть, видов фишек намного больше", "eff": {"greedy": 3}}]},
	"narrow": {"name": "Тесный лоток", "levels": [
		{"heat": 3, "desc": "В лотке на одно место меньше", "eff": {"slots": -1}}]},
	"one_lamp": {"name": "Один фонарь", "levels": [
		{"heat": 4, "desc": "На весь забег один фонарь, благословения его не добавят", "eff": {"lamp_one": true}}]},
	"no_ult": {"name": "Без приёма", "levels": [
		{"heat": 2, "desc": "Приём героини молчит", "eff": {"ult_off": true}}]},
	"no_undo": {"name": "Без отмен", "levels": [
		{"heat": 1, "desc": "Отмены не работают", "eff": {"undo_off": true}}]},
	"no_hint": {"name": "Без подсказок", "levels": [
		{"heat": 1, "desc": "Подсказки не работают", "eff": {"hint_off": true}}]},
	"no_shuffle": {"name": "Без смешиваний", "levels": [
		{"heat": 1, "desc": "Смешивания не работают", "eff": {"shuffle_off": true}}]},
	"fog": {"name": "Туман", "levels": [
		{"heat": 2, "desc": "Пятая часть стола в тумане, пока не снимешь 6 пар", "eff": {"fog": 1}},
		{"heat": 4, "desc": "Треть стола в тумане, пока не снимешь 10 пар", "eff": {"fog": 2}}]},
	"guards": {"name": "Стражи", "levels": [
		{"heat": 2, "desc": "Четыре фишки скованы льдом", "eff": {"guards": 4}},
		{"heat": 4, "desc": "Восемь фишек скованы льдом", "eff": {"guards": 8}}]},
}
const CURSE_ORDER: = ["shroud", "hourglass", "greedy", "narrow", "one_lamp", "no_ult", "no_undo", "no_hint", "no_shuffle", "fog", "guards"]
const HEAT_MAX: = 34

# fog levels: [share of the table, pairs to lift]
const FOG: = [[0.0, 0], [0.2, 6], [0.34, 10]]
# greedy levels: [tile count ×, extra kinds of tiles, extra layer]
const GREEDY: = [[1.0, 0, 0], [1.1, 2, 0], [1.2, 4, 1], [1.33, 6, 1]]

# Journey: curses offered after a board («опционально 1 из 2 проклятий, +15% очков») — level I only, and never
# one_lamp (a run of 5 boards with one heart is a lottery, not a test) nor narrow on the boss board.
const JOURNEY_CURSES: = ["shroud", "hourglass", "greedy", "narrow", "no_ult", "no_undo", "no_hint", "no_shuffle", "fog", "guards"]
const JOURNEY_CURSE_BONUS: = 0.15

# Pagoda: every 10th floor adds one more curse (spec R2). Chosen deterministically from the run seed among the
# curses still below their top level; a forced curse never pushes past what validate() allows.
const FORCED_EVERY: = 10

const SAFE_TEXT: = "Слишком жестоко даже для Пагоды"
