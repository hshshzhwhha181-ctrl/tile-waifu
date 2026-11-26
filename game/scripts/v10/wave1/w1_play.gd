class_name V10W1Play
extends RefCounted

# Wave 1 (docs/ROSTER_20.md §3.2–3.4): the gameplay data of the five goddesses for the v06 / v07 / v08 / v10
# consumers. Pure data + small static helpers, NOT gated here: the integrator's hooks merge every table into its
# consumer behind V10Wave1.released(), so the founders play exactly as before while wave 1 is off.
#
# Each table mirrors the founders' entry schema of its consumer, one entry per goddess:
#   SKILLS             G.SKILLS (g.gd)                                  ult name / desc fallback
#   SKILL_PAIRS        V6Skills.use (v06/heroines/skills.gd)            old-caller fallback: pairs the skill removes
#   PERKS, PERK_EFF    G.PERKS (g.gd) + Play._apply_perk (play.gd)      the 0.6 perk line and what it does
#   RIVALS, DUEL_LINES V6Heroines (v06/heroines/heroines_data.gd)       duel rival: pace, backdrop, «подлость», barks
#   PASSIVES           V7Passives.DATA (v07/passives/passives.gd)       table style; runs on a founder's engine
#   V6_BLESS           V6ModesData.BLESS (v06/modes/modes_data.gd)      «Лунная лестница» blessings (names = V10ModsData)
#   SHIFT_*            V6ModesData.GUESTS / TASTE / ORDER_LINES / THANKS / LEAVE   «Смена в чайной» guests
#   AI_STYLES          V8AI.STYLES (v08/table/ai.gd)                    riichi table style
#   POP_*              V8Population (v08/league/population.gd)          league avatars, face crops, nick filter
#   HOST_NAMES         V10PathRules.HOST_NAMES (v10/path/path_rules.gd) Path chapter hostess names
# Already complete upstream, nothing to add: V10ModsData.BLESS (smoke / sugar / foxluck / mirage / feather),
# V10Journey.BOSS, V10TowerBoard.STYLE, V10TowerUtil.ROSTER, V10LevelGen.WORLD (arcs 3, 5, 7, 9, 10).
#
# Balance (ROSTER §1.6): goddesses give no power in ranked, and every number here stays inside the founders' range
# (self_check() proves it). No new currencies: only hints, undos, shuffles, lanterns, tray slots and crystals.

const HEROES: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
const NAMES: = {"tsubame": "Цубамэ", "miel": "Миэль", "kohaku": "Кохаку", "shirin": "Ширин", "zlata": "Злата"}
const FOUNDERS: = ["mc", "rin", "hana", "yue", "nova"]

# ROSTER §1.4 + spec §2.1: «Осколки героини» open only the founders. Wave-1 goddesses come from Желания, never from
# shard drops (Path shard tiles, duel wins, chests, events). The hooks keep every shard source on founders.
const SHARDS_FROM_PLAY: = false

const W1_OUTFIT_DIR: = "res://assets/v10/wave1/outfits/"
const ART_CARDS_PATH: = "res://scripts/v10/wave1/data/w1_art_cards.json"


# ---------------------------------------------------------------- G.SKILLS (ult core, ROSTER «Ядро ульты»)
const SKILLS: = {
	"tsubame": {"name": "Теневой шаг", "desc": "снимает пару, зажатую соседями сбоку"},
	"miel": {"name": "Печенье-джокер", "desc": "кладёт в лоток печенье, которое встаёт в пару к любой фишке"},
	"kohaku": {"name": "Лисий оберег", "desc": "вешает на лоток оберег от переполнения и подсвечивает пару"},
	"shirin": {"name": "Танец монет", "desc": "снимает пару и сразу зажигает Азарт"},
	"zlata": {"name": "Огненный шлейф", "desc": "снимает пару и растапливает лёд и замки между её фишками"},
}

# V6Skills.use (0.6 path, used only when no V9UltCast is attached): every core is rated «1 пара» (ROSTER §3)
const SKILL_PAIRS: = {"tsubame": 1, "miel": 1, "kohaku": 1, "shirin": 1, "zlata": 1}

static func skill(h: String) -> Dictionary:
	if G.SKILLS.has(h):
		return G.SKILLS[h]
	return SKILLS.get(h, G.SKILLS.mc)


# ---------------------------------------------------------------- G.PERKS (0.6 perk, applied in Play._apply_perk)
# Founders: +1 hint · +1 undo · combo 6.5 s · gold ×8 · +1 shuffle and +10 % crystals. Each goddess gets one of the
# same primitives at founder strength or below.
const PERKS: = {
	"tsubame": "+1 перемешивание на старте",
	"miel": "+1 подсказка на старте",
	"kohaku": "+1 отмена на старте",
	"shirin": "Золотые фишки ×7 вместо ×5",
	"zlata": "Окно комбо +1 секунда",
}
# hint / undo / shuffle: + count at the start · gold_mult: gold tile value (base 5) · combo: + seconds of the window
const PERK_EFF: = {
	"tsubame": {"shuffle": 1},
	"miel": {"hint": 1},
	"kohaku": {"undo": 1},
	"shirin": {"gold_mult": 7},
	"zlata": {"combo": 1.0},
}

static func perk(h: String) -> String:
	if G.PERKS.has(h):
		return String(G.PERKS[h])
	return String(PERKS.get(h, ""))

# play: the Play screen (hint_n, undo_n, shuffle_n, gold_mult, board.combo_window)
static func apply_perk(play, h: String) -> void:
	var e: Dictionary = PERK_EFF.get(h, {})
	if e.is_empty():
		return
	play.hint_n = int(play.hint_n) + int(e.get("hint", 0))
	play.undo_n = int(play.undo_n) + int(e.get("undo", 0))
	play.shuffle_n = int(play.shuffle_n) + int(e.get("shuffle", 0))
	if e.has("gold_mult"):
		play.gold_mult = maxi(int(play.gold_mult), int(e.gold_mult))
	if e.has("combo") and play.board != null:
		play.board.combo_window = float(play.board.combo_window) + float(e.combo)


# ---------------------------------------------------------------- V6Heroines.RIVALS (duel rival)
# pace: seconds per rival pair (founders 3.7…5.6) · skill: the V6Duel engine (double / sprint / veil)
const RIVALS: = {
	"tsubame": {"pace": 4.2, "bg": "bg_rooftop", "fx": "mist", "skill": "sprint", "skill_name": "Бег по крышам",
		"skill_desc": "семь секунд играет вдвое быстрее"},
	"miel": {"pace": 5.3, "bg": "bg_teahouse", "fx": "snow", "skill": "double", "skill_name": "Двойная порция",
		"skill_desc": "забирает две пары подряд"},
	"kohaku": {"pace": 4.4, "bg": "bg_shrine", "fx": "fireflies", "skill": "veil", "skill_name": "Лисий морок",
		"skill_desc": "прячет лица четырёх твоих свободных фишек на пять секунд"},
	"shirin": {"pace": 4.8, "bg": "bg_palace", "fx": "fireflies", "skill": "double", "skill_name": "Пируэт",
		"skill_desc": "забирает две пары подряд"},
	"zlata": {"pace": 3.9, "bg": "bg_festival", "fx": "petals", "skill": "veil", "skill_name": "Сияние пера",
		"skill_desc": "слепит сиянием четыре твои свободные фишки на пять секунд"},
}

const DUEL_LINES: = {
	"tsubame": {"start": ["Партия принята к доставке. Адрес победы — мой."], "take": ["Доставлено.", "Моя.", "Чисто."],
		"steal": ["Перехват посылки… Ловко.", "Хм. Этого адреса не было в маршруте."], "skill": ["Бег по крышам. Не моргай."],
		"lead": ["Опережаю график."], "behind": ["Ты быстрее, чем пишут в донесениях."], "win": ["Победа доставлена. Распишись вот здесь."],
		"lose": ["Твоя партия. Не смотри так, я прячусь в шарф."], "draw": ["Ничья. Значит, нужен ещё один заход."]},
	"miel": {"start": ["Партия на десерт! Чур, без обид, если я выиграю."], "take": ["Ам!", "Эту в духовку!", "Вкусная пара!"],
		"steal": ["Эй, это было моё пирожное!", "Ловко! Как ложкой из-под носа."], "skill": ["Двойная порция! Две пары сразу!"],
		"lead": ["Я впереди на целый противень!"], "behind": ["Ой-ой, крем убегает…"], "win": ["Победа моя! Держи утешительный макарон."],
		"lose": ["Перестаралась с сахаром… Победа твоя!"], "draw": ["Ничья? Тогда делим торт пополам."]},
	"kohaku": {"start": ["Удача любит меня. Посмотрим, перепадёт ли что-нибудь тебе."], "take": ["Моя, лисья.", "Хи-хи, ловкость хвоста.", "Удача снова со мной."],
		"steal": ["Стащить у лисы? Какая дерзость!", "Хм! Хвост это запомнит."], "skill": ["Лисий морок! Попробуй разгляди."],
		"lead": ["Девятьсот лет практики, знаешь ли."], "behind": ["Уши не прижаты, вовсе нет! Сейчас догоню."],
		"win": ["Удача любит меня, а значит, и тебя. Сыграем ещё?"], "lose": ["Хвост поник… Ладно, сегодня удача твоя."],
		"draw": ["Ничья? Лисы такого не любят. Ещё партию!"]},
	"shirin": {"start": ["Звёзды не лгут: сегодня кто-то из нас удивится."], "take": ["Как и было предсказано.", "Звон монет — мой.", "Песок течёт ко мне."],
		"steal": ["Этого звёзды мне не показали…", "Ты меняешь судьбу на ходу. Красиво."], "skill": ["Пируэт! Две пары за один оборот."],
		"lead": ["Караван уходит вперёд."], "behind": ["Пески переменчивы. Я подожду ветра."], "win": ["Звёзды сказали правду. Партия моя."],
		"lose": ["Пески переменчивы… Сегодня они твои."], "draw": ["Звёзды молчат. Значит, разложим ещё."]},
	"zlata": {"start": ["Царевна садится за стол. Играй смело!"], "take": ["Моя!", "Жар-перо не ошибается.", "Ещё искра в копилку."],
		"steal": ["Дерзко! Царевну так не обыгрывают… обычно.", "Ах так? Огонь любит смелых."], "skill": ["Сияние пера! Прикрой глаза."],
		"lead": ["Весна наступает, а я впереди!"], "behind": ["Ничего, пепел — только начало."], "win": ["Весна пришла! Победа за мной."],
		"lose": ["Перья потускнели… Признаю по-царски: партия твоя."], "draw": ["Ничья! Тогда мировая за блинами."]},
}


# ---------------------------------------------------------------- V7Passives.DATA (table style)
# The founders' five keys (name, desc, long, good, col) + the engine the style runs on in V7PassiveRun and its
# numbers. A goddess is never stronger than the founder whose engine she borrows (self_check):
#   engine  "rin" (return a tray tile, a resource every N pairs) · "hana" (relay in combo) · "yue" (reveal a closed
#           tile every N pairs, see-through glow) · "nova" (a buried tile becomes takeable every N pairs)
#   every   N pairs (rin / yue / nova) · max: resource cap (rin) · combo: combo step the relay needs (hana)
#   see     yue engine: false = no see-through glow · tint: overlay colour (nova / yue engines)
#   pulse   float text of the engine's action · gain / act: rin engine texts («+1 чашка» / «Чайная пауза»)
#   short   the clarity line «Свойство: …» (V10Glossary.PASSIVE_SHORT)
const PASSIVES: = {
	"tsubame": {
		"name": "Обходной путь",
		"desc": "Каждые 6 пар фишка из-под завала становится доступной.",
		"long": "Цубамэ знает обходные крыши: каждые 6 пар она открывает ход к фишке под завалом. Её можно взять, хотя сверху лежат другие.",
		"good": "высокие башни",
		"col": Color("c8283c"),
		"engine": "nova", "every": 6, "pulse": "Ход открыт", "tint": Color("ff6a7c"),
		"short": "открывает фишку под завалом раз в 6 пар",
	},
	"miel": {
		"name": "Добавка",
		"desc": "Тапни фишку в лотке, и она вернётся на стол. Пирожное за каждые 5 пар.",
		"long": "У Миэль всегда найдётся добавка: пока на подносе есть пирожное, фишку из лотка можно вернуть на её место. Одно пирожное с начала, ещё одно за каждые 5 пар, не больше двух.",
		"good": "много разных фишек",
		"col": Color("e0566f"),
		"engine": "rin", "every": 5, "max": 2, "gain": "+1 пирожное", "act": "Добавка",
		"short": "фишку из лотка можно вернуть за пирожное",
	},
	"kohaku": {
		"name": "Лисьи огни",
		"desc": "Огни показывают пару фишки из лотка сквозь стол и открывают закрытую фишку каждые 4 пары.",
		"long": "Лисьи огни Кохаку видят сквозь фишки: пара того, что лежит в лотке, светится даже под завалом. Одну закрытую фишку огни открывают сразу, ещё одну за каждые 4 пары.",
		"good": "закрытые и тайные фишки",
		"col": Color("d63a2a"),
		"engine": "yue", "every": 4, "see": true, "pulse": "Лисий огонь", "tint": Color("ffb36b"),
		"short": "огни показывают пары сквозь стол",
	},
	"shirin": {
		"name": "Ритм каравана",
		"desc": "Пока горит комбо ×3, каждая вторая фишка сама зовёт свою свободную пару.",
		"long": "Ширин танцует в ритме стола: пока держится комбо ×3 и выше, каждая вторая фишка, ушедшая в лоток, сама приводит свою свободную пару со стола.",
		"good": "открытые столы, Блиц",
		"col": Color("d9b26f"),
		"engine": "hana", "combo": 3, "pulse": "В ритме!",
		"short": "в комбо ×3 пара зовёт себя сама",
	},
	"zlata": {
		"name": "Оттепель",
		"desc": "Растапливает лёд или открывает тайную фишку сразу и каждые 3 пары.",
		"long": "Где пролетает Жар-птица, тает лёд: одну закрытую фишку Злата открывает сразу, ещё одну за каждые 3 пары. Первыми уступают те, что нужны лотку.",
		"good": "лёд и тайные фишки",
		"col": Color("c3242b"),
		"engine": "yue", "every": 3, "see": false, "pulse": "Оттепель",
		"short": "растапливает лёд и открывает фишки",
	},
}

static func passive_engine(h: String) -> String:
	return String(PASSIVES[h].engine) if PASSIVES.has(h) else h

static func dar_line(h: String) -> String:
	return "Дар: %s" % String(PASSIVES[h].short) if PASSIVES.has(h) else ""


# ---------------------------------------------------------------- V6ModesData.BLESS («Лунная лестница», 0.6 climb)
# Same ids and names as V10ModsData.BLESS (Пагода), with effects the 0.6 climb run already has (lamps, hint, undo,
# shuffle, slots), applied once on pick by v6_bless_pick(). cap / once mirror V6ModesData.BLESS_CAP / BLESS_ONCE.
const V6_BLESS: = {
	"smoke": {"hero": "tsubame", "name": "Дымовая завеса", "desc": "+1 отмена и +1 смешивание", "plus": "+2 отмены и +1 смешивание",
		"eff": {"undo": 1, "shuffle": 1}, "eff_plus": {"undo": 2, "shuffle": 1}, "cap": 2},
	"sugar": {"hero": "miel", "name": "Сахарная пудра", "desc": "+1 подсказка и +1 отмена", "plus": "+2 подсказки и +1 отмена",
		"eff": {"hint": 1, "undo": 1}, "eff_plus": {"hint": 2, "undo": 1}, "cap": 3},
	"foxluck": {"hero": "kohaku", "name": "Лисья удача", "desc": "+1 подсказка и +1 смешивание", "plus": "+2 подсказки и +1 смешивание",
		"eff": {"hint": 1, "shuffle": 1}, "eff_plus": {"hint": 2, "shuffle": 1}, "cap": 3},
	"mirage": {"hero": "shirin", "name": "Мираж", "desc": "По подсказке, отмене и смешиванию", "plus": "+2 подсказки, +1 отмена и +1 смешивание",
		"eff": {"hint": 1, "undo": 1, "shuffle": 1}, "eff_plus": {"hint": 2, "undo": 1, "shuffle": 1}, "once": true},
	"feather": {"hero": "zlata", "name": "Перо жар-птицы", "desc": "+1 фонарь и +1 отмена", "plus": "+2 фонаря и +1 отмена",
		"eff": {"lamps": 1, "undo": 1}, "eff_plus": {"lamps": 2, "undo": 1}, "once": true},
}
const V6_BLESS_ORDER: = ["smoke", "sugar", "foxluck", "mirage", "feather"]

# the run fields of V6ModesData.new_run; lanterns and slots keep the climb's caps
static func v6_bless_pick(run: Dictionary, id: String, plus: bool) -> void:
	if not V6_BLESS.has(id):
		return
	var e: Dictionary = V6_BLESS[id].eff_plus if plus else V6_BLESS[id].eff
	run["lamps"] = mini(int(run.get("lamps", 0)) + int(e.get("lamps", 0)), V6ModesData.LAMPS_MAX)
	run["hint"] = int(run.get("hint", 0)) + int(e.get("hint", 0))
	run["undo"] = int(run.get("undo", 0)) + int(e.get("undo", 0))
	run["shuffle"] = int(run.get("shuffle", 0)) + int(e.get("shuffle", 0))
	run["slots"] = mini(int(run.get("slots", 4)) + int(e.get("slots", 0)), V6ModesData.SLOTS_MAX)


# ---------------------------------------------------------------- V6ModesData «Смена в чайной» guests
# cats: G.CATS index (0 цветы · 1 небо · 2 сладости · 3 сокровища · 4 звери), the first one is the favourite
# pat: patience in seconds (founders 38…60) · tip: tip multiplier (founders 1.0…1.3)
const SHIFT_GUESTS: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
const SHIFT_TASTE: = {
	"tsubame": {"cats": [0, 1], "pat": 40.0, "tip": 1.15},
	"miel": {"cats": [2, 0], "pat": 58.0, "tip": 1.05},
	"kohaku": {"cats": [4, 3], "pat": 48.0, "tip": 1.25},
	"shirin": {"cats": [3, 1], "pat": 52.0, "tip": 1.2},
	"zlata": {"cats": [1, 2], "pat": 45.0, "tip": 1.3},
}
const SHIFT_ORDER_LINES: = {
	"tsubame": ["Сливу и ночное небо. Я на минуту, у меня письма.", "Цветы в дорогу. Быстро и без шума."],
	"miel": ["Что-нибудь сладкое! Сравню со своим.", "Цветы к пирожным, пожалуйста."],
	"kohaku": ["Зверушек и что-нибудь блестящее. Лисы любят красивое.", "Удиви лису. Сокровища подойдут."],
	"shirin": ["Немного золота для каравана, прошу.", "Сокровища и звёздное небо. Остальное подскажут звёзды."],
	"zlata": ["Солнце на блюде и что-нибудь к блинам!", "Небо и сладкое, по-царски, пожалуйста."],
}
const SHIFT_THANKS: = {
	"tsubame": ["Доставлено. Спасибо… правда.", "Чисто сработано. Уважаю."],
	"miel": ["Ммм, как красиво сервировано!", "Идеально! Даже я бы так не украсила."],
	"kohaku": ["Хи-хи, удача любит тебя сегодня.", "Неплохо. Хвост доволен."],
	"shirin": ["Звёзды не лгут: ты чудесно служишь.", "Монеты звенят от радости."],
	"zlata": ["Весна пришла! Благодарю от всего царства.", "Царский стол! Щедро награжу."],
}
const SHIFT_LEAVE: = {
	"tsubame": "Письма не ждут. Мне пора.", "miel": "Ой, у меня духовка! Бегу!", "kohaku": "Лиса ушла гулять. В другой раз.",
	"shirin": "Караван трогается. До встречи под звёздами.", "zlata": "Блины стынут! Загляну позже.",
}

# part: "taste" | "order" | "thanks" | "leave" (V6ModesData.TASTE / ORDER_LINES / THANKS / LEAVE)
static func shift(h: String, part: String):
	match part:
		"taste":
			return SHIFT_TASTE.get(h, V6ModesData.TASTE.mc)
		"order":
			return SHIFT_ORDER_LINES.get(h, V6ModesData.ORDER_LINES.mc)
		"thanks":
			return SHIFT_THANKS.get(h, V6ModesData.THANKS.mc)
		"leave":
			return SHIFT_LEAVE.get(h, V6ModesData.LEAVE.mc)
	return null


# ---------------------------------------------------------------- V8AI.STYLES (riichi table)
# every number inside the founders' range per key (call 0.2…0.95, riichi 0.45…1.0, defense 0.1…0.95,
# skill 0.8…0.92, value 0.35…1.2, speed 0.85…1.2 — table_driver.ai_pause maps speed on 0.85…1.2)
const AI_STYLES: = {
	"tsubame": {"call": 0.65, "riichi": 0.55, "defense": 0.8, "skill": 0.88, "value": 0.5, "speed": 1.15, "name": "Тень на крыше",
		"desc": "Тихо подбирает чужие сбросы и закрывает руку раньше, чем её заметят."},
	"miel": {"call": 0.4, "riichi": 0.75, "defense": 0.4, "skill": 0.83, "value": 0.95, "speed": 0.95, "name": "Слоёное тесто",
		"desc": "Не торопится: слой за слоем собирает руку подороже и смело идёт до конца."},
	"kohaku": {"call": 0.3, "riichi": 0.85, "defense": 0.75, "skill": 0.9, "value": 1.05, "speed": 1.0, "name": "Лисья уловка",
		"desc": "Любит раннюю готовность и дорогие руки, но при первой опасности прячет хвост в защиту."},
	"shirin": {"call": 0.35, "riichi": 0.6, "defense": 0.85, "skill": 0.9, "value": 0.9, "speed": 0.9, "name": "Звёздный расклад",
		"desc": "Читает стол, как ладонь: терпеливо ждёт верную руку и редко рискует."},
	"zlata": {"call": 0.7, "riichi": 0.95, "defense": 0.25, "skill": 0.88, "value": 1.1, "speed": 1.05, "name": "Огненный размах",
		"desc": "Играет широко и щедро: ранняя готовность, дора и ни шагу назад."},
}


# ---------------------------------------------------------------- V8Population (league players)
# The 0.8 population stays byte-identical (same nicks, tiers, scores); once wave 1 is out a fixed share of players
# «main» a wave-1 goddess: pop_overlay() swaps hero / avatar / fav of those rows, keyed by the player id only.
# Avatars are the base and A/S outfits (no Обет, no SSR until their bold flags are final).
const POP_SHARE: = 0.4
const POP_AVATARS: = {
	"tsubame": ["tb_base", "tb_post"],
	"miel": ["me_base", "me_parlor"],
	"kohaku": ["ko_base", "ko_matsuri"],
	"shirin": ["sh_base", "sh_oasis"],
	"zlata": ["zl_base", "zl_fair"],
}
# V8Population.HERO_NICKS: no league nick is a goddess's name (checked against today's population: no collisions)
const POP_HERO_NICKS: = ["цубамэ", "миэль", "кохаку", "ширин", "злата", "tsubame", "miel", "kohaku", "shirin", "zlata"]
# V8Population.FACES fallback [focus x, focus y, zoom] when w1_art_cards.json has no face_rect for an outfit
const POP_FACE_DEFAULT: = [0.5, 0.17, 4.7]

static var _cards: Dictionary = {}
static var _cards_loaded: = false

# data/w1_art_cards.json (art-cards agent), read once
static func art_cards() -> Dictionary:
	if not _cards_loaded:
		_cards_loaded = true
		if FileAccess.file_exists(ART_CARDS_PATH):
			var d = JSON.parse_string(FileAccess.get_file_as_string(ART_CARDS_PATH))
			if d is Dictionary:
				_cards = d
	return _cards

static func is_outfit_img(img: String) -> bool:
	for h in POP_AVATARS:
		if img in (POP_AVATARS[h] as Array):
			return true
	return img.substr(0, 3) in ["tb_", "me_", "ko_", "sh_", "zl_"]

static func outfit_path(img: String) -> String:
	return W1_OUTFIT_DIR + "%s.webp" % img

# round face crop of a wave-1 outfit card, same rule as the founders' FACES: focus = face centre raised by 0.15 face
# width, zoom = 2 face widths across the circle (card shader: the circle spans tex_width / zoom)
static func pop_face(img: String) -> Array:
	var o = (art_cards().get("outfits", {}) as Dictionary).get(img, {})
	if not (o is Dictionary):
		return POP_FACE_DEFAULT
	var fr: Array = o.get("face_rect", [])
	var sz: Array = o.get("size", [850, 1280])
	if fr.size() != 4 or sz.size() != 2 or float(fr[2]) <= 0.0:
		return POP_FACE_DEFAULT
	var W: = float(sz[0])
	var H: = float(sz[1])
	var x: = float(fr[0])
	var y: = float(fr[1])
	var w: = float(fr[2])
	var h: = float(fr[3])
	if x <= 1.0 and y <= 1.0 and w <= 1.0 and h <= 1.0:
		# normalized rect
		x *= W
		y *= H
		w *= W
		h *= H
	var fx: = clampf((x + w * 0.5) / W, 0.1, 0.9)
	var fy: = clampf((y + h * 0.5 - 0.15 * w) / H, 0.05, 0.6)
	return [snappedf(fx, 0.001), snappedf(fy, 0.001), snappedf(clampf(W / (2.0 * w), 3.6, 6.0), 0.01)]

# p: a V8Population row {id, hero, avatar, fav, …}; changes it in place for the players who main a wave-1 goddess
static func pop_overlay(p: Dictionary) -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = hash("w1pop|%d" % int(p.get("id", 0)))
	if rng.randf() >= POP_SHARE:
		return
	var h: String = HEROES[rng.randi() % HEROES.size()]
	var outs: Array = POP_AVATARS[h]
	p["hero"] = h
	p["avatar"] = String(outs[rng.randi() % outs.size()])
	if rng.randf() < 0.7:
		p["fav"] = h


# ---------------------------------------------------------------- V10PathRules.HOST_NAMES (Path chapter hostess)
const HOST_NAMES: = {"tsubame": "Цубамэ", "miel": "Миэль", "kohaku": "Кохаку", "shirin": "Ширин", "zlata": "Злата"}


# ---------------------------------------------------------------- self checks (wave1_selftest)

# every player-facing string of this file
static func all_texts() -> Array:
	var out: = []
	for h in HEROES:
		out.append(NAMES[h])
		out.append(SKILLS[h].name)
		out.append(SKILLS[h].desc)
		out.append(PERKS[h])
		out.append(RIVALS[h].skill_name)
		out.append(RIVALS[h].skill_desc)
		for k in DUEL_LINES[h]:
			out.append_array(DUEL_LINES[h][k])
		for k in ["name", "desc", "long", "good", "pulse", "gain", "act", "short"]:
			if PASSIVES[h].has(k):
				out.append(String(PASSIVES[h][k]))
		out.append_array(SHIFT_ORDER_LINES[h])
		out.append_array(SHIFT_THANKS[h])
		out.append(SHIFT_LEAVE[h])
		out.append(AI_STYLES[h].name)
		out.append(AI_STYLES[h].desc)
		out.append(HOST_NAMES[h])
	for id in V6_BLESS:
		for k in ["name", "desc", "plus"]:
			out.append(String(V6_BLESS[id][k]))
	return out

static func _keys_ok(entry: Dictionary, template: Dictionary) -> bool:
	for k in template:
		if not entry.has(k):
			return false
	return true

static func _range(table: Dictionary, key: String) -> Array:
	var lo: = INF
	var hi: = -INF
	for h in table:
		var v: = float(table[h][key])
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return [lo, hi]

static func _in(v: float, r: Array) -> bool:
	return v >= float(r[0]) - 0.0001 and v <= float(r[1]) + 0.0001

# [] = all good; else one line per failure
static func self_check() -> Array:
	var bad: = []
	var tables: = {"SKILLS": SKILLS, "SKILL_PAIRS": SKILL_PAIRS, "PERKS": PERKS, "PERK_EFF": PERK_EFF, "RIVALS": RIVALS,
		"DUEL_LINES": DUEL_LINES, "PASSIVES": PASSIVES, "SHIFT_TASTE": SHIFT_TASTE, "SHIFT_ORDER_LINES": SHIFT_ORDER_LINES,
		"SHIFT_THANKS": SHIFT_THANKS, "SHIFT_LEAVE": SHIFT_LEAVE, "AI_STYLES": AI_STYLES, "POP_AVATARS": POP_AVATARS,
		"HOST_NAMES": HOST_NAMES}
	for tn in tables:
		var t: Dictionary = tables[tn]
		if t.size() != HEROES.size():
			bad.append("%s: %d entries, want 5" % [tn, t.size()])
		for h in HEROES:
			if not t.has(h):
				bad.append("%s: no %s" % [tn, h])
		for h in FOUNDERS:
			if t.has(h):
				bad.append("%s: overrides founder %s" % [tn, h])
	if bad.size() > 0:
		return bad
	# schema = the founder template of each consumer
	for h in HEROES:
		if not _keys_ok(SKILLS[h], G.SKILLS.mc):
			bad.append("SKILLS %s schema" % h)
		if not _keys_ok(RIVALS[h], V6Heroines.RIVALS.mc):
			bad.append("RIVALS %s schema" % h)
		if not _keys_ok(DUEL_LINES[h], V6Heroines.DUEL_LINES.mc):
			bad.append("DUEL_LINES %s schema" % h)
		if not _keys_ok(PASSIVES[h], V7Passives.DATA.mc):
			bad.append("PASSIVES %s schema" % h)
		if not _keys_ok(SHIFT_TASTE[h], V6ModesData.TASTE.mc):
			bad.append("SHIFT_TASTE %s schema" % h)
		if not _keys_ok(AI_STYLES[h], V8AI.STYLES.mc):
			bad.append("AI_STYLES %s schema" % h)
		if HOST_NAMES[h] != NAMES[h]:
			bad.append("HOST_NAMES %s != %s" % [h, NAMES[h]])
	for id in V6_BLESS:
		if not _keys_ok(V6_BLESS[id], V6ModesData.BLESS.lamp):
			bad.append("V6_BLESS %s schema" % id)
		if V6ModesData.BLESS.has(id):
			bad.append("V6_BLESS %s collides with a founder blessing" % id)
	# balance: inside the founders' ranges (ROSTER §1.6)
	var pace: = _range(V6Heroines.RIVALS, "pace")
	for h in HEROES:
		var rv: Dictionary = RIVALS[h]
		if not _in(float(rv.pace), pace):
			bad.append("RIVALS %s pace %.1f outside %s" % [h, float(rv.pace), str(pace)])
		if not String(rv.skill) in ["double", "sprint", "veil"]:
			bad.append("RIVALS %s skill %s has no V6Duel engine" % [h, rv.skill])
		if not ResourceLoader.exists("res://assets/bg/%s.webp" % rv.bg):
			bad.append("RIVALS %s bg %s missing" % [h, rv.bg])
		if not String(rv.fx) in ["petals", "snow", "lanterns", "fireflies", "mist", "rain"]:
			bad.append("RIVALS %s fx %s unknown" % [h, rv.fx])
		for k in DUEL_LINES[h]:
			if (DUEL_LINES[h][k] as Array).size() < (V6Heroines.DUEL_LINES.mc[k] as Array).size():
				bad.append("DUEL_LINES %s.%s shorter than the founders'" % [h, k])
	for k in ["call", "riichi", "defense", "skill", "value", "speed"]:
		var r: = _range(_founder_rows(V8AI.STYLES), k)
		for h in HEROES:
			if not _in(float(AI_STYLES[h][k]), r):
				bad.append("AI_STYLES %s.%s outside %s" % [h, k, str(r)])
	var pat: = _range(V6ModesData.TASTE, "pat")
	var tip: = _range(V6ModesData.TASTE, "tip")
	for h in HEROES:
		var t: Dictionary = SHIFT_TASTE[h]
		if not _in(float(t.pat), pat) or not _in(float(t.tip), tip):
			bad.append("SHIFT_TASTE %s outside pat %s / tip %s" % [h, str(pat), str(tip)])
		for c in t.cats:
			if int(c) < 0 or int(c) >= G.CATS.size():
				bad.append("SHIFT_TASTE %s cat %d" % [h, int(c)])
	for h in HEROES:
		var p: Dictionary = PASSIVES[h]
		match String(p.engine):
			"rin":
				if int(p.every) < V7Passives.RIN_EVERY or int(p.max) > V7Passives.RIN_MAX:
					bad.append("PASSIVES %s stronger than Rin" % h)
			"yue":
				if int(p.every) < V7Passives.YUE_EVERY:
					bad.append("PASSIVES %s stronger than Yue" % h)
			"nova":
				if int(p.every) < V7Passives.NOVA_EVERY:
					bad.append("PASSIVES %s stronger than Nova" % h)
			"hana":
				if int(p.combo) < V7Passives.HANA_COMBO:
					bad.append("PASSIVES %s stronger than Hana" % h)
			_:
				bad.append("PASSIVES %s engine %s (mc's slot engine is the salon's own)" % [h, p.engine])
	for h in HEROES:
		var e: Dictionary = PERK_EFF[h]
		if int(e.get("hint", 0)) > 1 or int(e.get("undo", 0)) > 1 or int(e.get("shuffle", 0)) > 1:
			bad.append("PERK_EFF %s: more than +1 help" % h)
		if int(e.get("gold_mult", 0)) >= 8 or float(e.get("combo", 0.0)) > 1.5:
			bad.append("PERK_EFF %s: stronger than Yue / Hana" % h)
		if int(SKILL_PAIRS[h]) != 1:
			bad.append("SKILL_PAIRS %s != 1 pair" % h)
	for id in V6_BLESS:
		var b: Dictionary = V6_BLESS[id]
		var n: = 0
		for k in b.eff_plus:
			n += int(b.eff_plus[k])
		if n > 4:
			bad.append("V6_BLESS %s plus gives %d helps (founders ≤4)" % [id, n])
	# one blessing per goddess, the same name as the Pagoda's (V10ModsData)
	for h in HEROES:
		var v6: = V6_BLESS.keys().filter(func(i): return String(V6_BLESS[i].hero) == h)
		var v10: = V10ModsData.BLESS.keys().filter(func(i): return String(V10ModsData.BLESS[i].hero) == h)
		if v6.size() != 1 or v10.size() != 1 or String(v6[0]) != String(v10[0]) \
				or String(V6_BLESS[v6[0]].name) != String(V10ModsData.BLESS[v10[0]].name):
			bad.append("blessing of %s differs between Лестница and Пагода" % h)
	# upstream tables that already carry the five
	for h in HEROES:
		if not V10Journey.BOSS.has(h):
			bad.append("V10Journey.BOSS has no %s" % h)
		if not V10TowerBoard.STYLE.has(h):
			bad.append("V10TowerBoard.STYLE has no %s" % h)
		if not h in V10TowerUtil.ROSTER or String(V10TowerUtil.ROSTER_NAMES.get(h, "")) != NAMES[h]:
			bad.append("V10TowerUtil.ROSTER name of %s" % h)
	# population: names filter changes nothing today (determinism), avatars are her outfits
	var prefix: = {"tsubame": "tb_", "miel": "me_", "kohaku": "ko_", "shirin": "sh_", "zlata": "zl_"}
	for h in HEROES:
		for img in POP_AVATARS[h]:
			if not String(img).begins_with(prefix[h]) or String(img).ends_with("_vow"):
				bad.append("POP_AVATARS %s: %s" % [h, img])
	for p in V8Population.all():
		var core: = String(p.nick).to_lower()
		for sep in ["_", "-", ".", " "]:
			core = core.get_slice(sep, 0)
		core = core.rstrip("0123456789")
		if core in POP_HERO_NICKS:
			bad.append("population nick %s would be filtered (population would change)" % p.nick)
	var shares: = {}
	for id in 1000:
		var row: = {"id": id, "hero": "mc", "avatar": "mc_base", "fav": "mc"}
		pop_overlay(row)
		shares[row.hero] = int(shares.get(row.hero, 0)) + 1
	for h in HEROES:
		if int(shares.get(h, 0)) < 40 or int(shares.get(h, 0)) > 120:
			bad.append("pop_overlay share of %s = %d / 1000" % [h, int(shares.get(h, 0))])
	# texts: V10Lint + a strict pass (no «бесплатн» at all, no Latin letters)
	for s in all_texts():
		var t: = String(s)
		var lint: = V10Lint.check(t)
		for u in V10Lint.ui_check(t):
			if not (u in lint):
				lint.append(u)
		if not lint.is_empty() or "бесплатн" in t.to_lower():
			bad.append("text «%s»: %s" % [t, str(lint)])
		for ch in t:
			var u: = ch.unicode_at(0)
			if (u >= 65 and u <= 90) or (u >= 97 and u <= 122):
				bad.append("text «%s»: Latin letters" % t)
				break
	return bad

static func _founder_rows(table: Dictionary) -> Dictionary:
	var out: = {}
	for h in FOUNDERS:
		if table.has(h):
			out[h] = table[h]
	return out
