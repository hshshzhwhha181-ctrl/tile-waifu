class_name V10TutLines
extends RefCounted
# Every word the tutorial shows (UX_RULES §4). One source; the selftest lints all of it:
#   heroine lines  -> V10Lint.ok() (spec §2.7 stop-words) + UX §4.2/§4.3 banned words, ≤ 2 lines of Caveat 30;
#   system strings -> UX §4.2/§4.3 banned words, buttons ≤ 18 chars.
# Address the player as «ты», gender-neutral (no past tense / adjectives with gender). No «урок/ученик/школа».
# The heroine never talks about money, the shop or offers (UX §5.2, §8.3).
#
# INTROS: one heroine line + one spotlight (UX §2 rule 7, §3.5). Keys:
#   screen  – main.screen_id where it may play ("home", "tables"/"levels" = Столы, "summon" = Желания, …; "*" = any)
#   target  – tut_id of the ONE element in the spotlight ("" = no spotlight, line only)
#   gate    – V10Reveal gate id that must be open; the intro plays on the first hub entry after it opens
#   speaker – "partner" (G.S.partner), "mc", or a heroine id (mode hostess)
#   mode    – "tap" (dim + hole, any tap closes), "do" (only the hole lets taps through; closes when the target
#             is tapped), "wait" (no dim, no blocking, the line fades by itself)
#   prio    – lower plays first when several are due (only one plays per hub entry)
#   system  – true: counts as «a new system» (≤ 1 per hub entry, UX О-1); false: a mechanic/first-visit line
#   help    – help topic id this intro replays from («Показать в игре»)

const INTROS: = {
	# --- staged reveal, UX §3.5 ------------------------------------------------------------------------
	"home_first": {"screen": "home", "target": "home.play", "gate": "tab.tables", "speaker": "partner",
		"mode": "tap", "prio": 10, "system": true, "help": "teahouse",
		"line": "Это наша чайная. Жми «Играть» — и сразу за стол."},
	"tables_first": {"screen": "tables", "target": "tables.play", "gate": "tab.tables", "speaker": "partner",
		"mode": "tap", "prio": 11, "system": false, "help": "tables",
		"line": "Здесь Путь и все столы. Начинай с «Играть»."},
	"lantern_salon": {"screen": "home", "target": "lantern.salon", "gate": "lantern.salon", "speaker": "mc",
		"mode": "do", "prio": 20, "system": true, "help": "salon",
		"line": "Салон проснулся! Начни с задачи «Вывеска — 3★»."},
	"wishes_first": {"screen": "home", "target": "nav.wishes", "gate": "tab.wishes", "speaker": "mc",
		"mode": "do", "prio": 30, "system": true, "help": "wishes",
		"line": "Загадай желание: первую героиню выбираешь ты."},
	"heroines_first": {"screen": "*", "target": "nav.heroines", "gate": "tab.heroines", "speaker": "partner",
		"mode": "tap", "prio": 31, "system": false, "help": "heroines",
		"line": "Во вкладке «Героини» — наряды, стиль и её Дар."},
	"heroines_partner": {"screen": "collection", "target": "heroines.partner", "gate": "tab.heroines", "speaker": "partner",
		"mode": "tap", "prio": 32, "system": false, "help": "heroines",
		"line": "Выбери партнёра и наряд — её Дар играет с тобой."},
	"phone_first": {"screen": "home", "target": "home.phone", "gate": "phone", "speaker": "partner",
		"mode": "do", "prio": 50, "system": true, "help": "phone",
		"line": "Тебе письмо. Загляни в телефон."},
	"lantern_today": {"screen": "home", "target": "lantern.today", "gate": "lantern.today", "speaker": "partner",
		"mode": "tap", "prio": 60, "system": true, "help": "today",
		"line": "Фонарь «Сегодня»: партия дня и задания дня."},
	"lantern_streak": {"screen": "home", "target": "lantern.streak", "gate": "lantern.streak", "speaker": "partner",
		"mode": "tap", "prio": 70, "system": true, "help": "streak",
		"line": "Серия: заглядывай ко мне, подарки копятся. Ничего не сгорит."},
	"path_boosters": {"screen": "*", "target": "level.boosters", "gate": "path.boosters", "speaker": "partner",
		"mode": "wait", "prio": 80, "system": true, "help": "play",
		"line": "Огонёк пути и бустеры — для трудных столов."},
	"tables_tourney": {"screen": "tables", "target": "tables.tourney", "gate": "tables.tourney", "speaker": "partner",
		"mode": "tap", "prio": 90, "system": true, "help": "tables",
		"line": "Турнир недели открыт: топ-5 поднимаются выше."},
	# --- «Столы» shelves (MODES §6.4): the hostess introduces her table on the first visit after it opens --
	"mode_classic": {"screen": "tables", "target": "tables.mode.classic", "gate": "mode.classic", "speaker": "mc",
		"mode": "tap", "prio": 100, "system": true, "help": "tables",
		"line": "Классика: снимай две одинаковые открытые фишки. Лотка нет~"},
	"mode_triples": {"screen": "tables", "target": "tables.mode.triples", "gate": "mode.triples", "speaker": "hana",
		"mode": "tap", "prio": 101, "system": true, "help": "triples",
		"line": "Тройки: три одинаковые в лотке схлопываются. На старт!"},
	"mode_connect": {"screen": "tables", "target": "tables.mode.connect", "gate": "mode.connect", "speaker": "rin",
		"mode": "tap", "prio": 102, "system": true, "help": "tables",
		"line": "Связи: пару снимает линия, не больше двух поворотов."},
	"mode_daily_task": {"screen": "tables", "target": "tables.mode.daily_task", "gate": "mode.daily_task", "speaker": "mc",
		"mode": "tap", "prio": 103, "system": true, "help": "tables",
		"line": "Задача дня: угадай, какую фишку сбросить. Сыграем?"},
	"mode_hand": {"screen": "tables", "target": "tables.mode.hand", "gate": "mode.hand", "speaker": "hana",
		"mode": "tap", "prio": 104, "system": true, "help": "tables",
		"line": "Собери руку: бери фишки со стола, тройки сложатся сами."},
	"mode_riichi": {"screen": "tables", "target": "tables.mode.riichi", "gate": "mode.riichi", "speaker": "mc",
		"mode": "tap", "prio": 105, "system": true, "help": "riichi",
		"line": "Стол на четверых: японский маджонг против трёх героинь."},
	"mode_cube": {"screen": "tables", "target": "tables.mode.cube", "gate": "mode.cube", "speaker": "nova",
		"mode": "tap", "prio": 106, "system": true, "help": "tables",
		"line": "Куб: вращай его и снимай пары с открытых граней."},
	"mode_koikoi": {"screen": "tables", "target": "tables.mode.koikoi", "gate": "mode.koikoi", "speaker": "rin",
		"mode": "tap", "prio": 107, "system": true, "help": "koikoi",
		"line": "Коикои: собирай карты месяцев. Позволь показать."},
	"mode_dragon": {"screen": "tables", "target": "tables.mode.dragon", "gate": "mode.dragon", "speaker": "nova",
		"mode": "tap", "prio": 108, "system": true, "help": "tables",
		"line": "Дракон над столом: каждая пара — удар по боссу."},
	"mode_palm": {"screen": "tables", "target": "tables.mode.palm", "gate": "mode.palm", "speaker": "partner",
		"mode": "tap", "prio": 109, "system": true, "help": "tables",
		"line": "Чтение руки: угадай, какую фишку я жду."},
	"mode_garden": {"screen": "tables", "target": "tables.mode.garden", "gate": "mode.garden", "speaker": "yue",
		"mode": "tap", "prio": 110, "system": true, "help": "tables",
		"line": "Сад: волны без таймера. Любопытно, сколько продержишься."},
	"mode_journey": {"screen": "tables", "target": "tables.mode.journey", "gate": "mode.journey", "speaker": "partner",
		"mode": "tap", "prio": 111, "system": true, "help": "journey",
		"line": "Странствие: недельный забег за пятью печатями."},
	"mode_duels": {"screen": "tables", "target": "tables.mode.duels", "gate": "mode.duels", "speaker": "hana",
		"mode": "tap", "prio": 112, "system": true, "help": "duels",
		"line": "Дуэли: гонка на общем столе. Реванш — сразу!"},
	"mode_etudes": {"screen": "tables", "target": "tables.mode.etudes", "gate": "mode.etudes", "speaker": "yue",
		"mode": "tap", "prio": 113, "system": true, "help": "tables",
		"line": "Этюды: все пары разные, а в лотке три места."},
	"mode_shift": {"screen": "tables", "target": "tables.mode.shift", "gate": "mode.shift", "speaker": "rin",
		"mode": "tap", "prio": 114, "system": true, "help": "tables",
		"line": "Смена в чайной: собирай заказы гостий. Позволь."},
	"mode_pagoda": {"screen": "tables", "target": "tables.mode.pagoda", "gate": "mode.pagoda", "speaker": "partner",
		"mode": "tap", "prio": 115, "system": true, "help": "pagoda",
		"line": "Пагода: поднимайся этаж за этажом."},
	# --- legacy 0.9 players: one line about the new navigation, then everything already open is «seen» --
	"v10_welcome": {"screen": "home", "target": "nav.tables", "gate": "", "speaker": "partner",
		"mode": "tap", "prio": 1, "system": true, "help": "tabs",
		"line": "Я всё переставила: столы теперь внизу, во вкладке «Столы»."},
}

# First match (L1) and match mechanics. Placed in the heroine zone (HUD_V2 §8.1), never over the field.
# {n} in m_tray is the tray size with the right plural (see places()).
const MATCH: = {
	"m_a": {"target": "match.tile_a", "mode": "do", "line": "Коснись фишки — она уйдёт в лоток."},
	"m_b": {"target": "match.tile_b", "mode": "do", "line": "Теперь такую же — и пара уйдёт."},
	"m_left": {"target": "match.status", "mode": "tap", "line": "Здесь видно, сколько фишек осталось."},
	"m_free": {"target": "match.tile_a", "mode": "wait", "line": "Открытая — та, что ничем не прижата."},
	"m_tray": {"target": "match.tray", "mode": "tap", "line": "В лотке {n}. Заполнишь — партия окончена~"},
	"m_danger": {"target": "match.tray", "mode": "wait", "line": "Осторожно! Лоток почти полон."},
	"m_ult": {"target": "match.hero", "mode": "do", "line": "Мой Приём — особый ход. Коснись меня!"},
	"m_fail": {"target": "fail.retry", "mode": "wait", "line": "Ничего~ Ещё раз — и стол наш."},
	"v_stars": {"target": "win.stars", "mode": "wait", "line": "Стол чист! Звёзды — за игру без помощи."},
	"v_home": {"target": "win.home", "mode": "do", "line": "Пойдём, покажу нашу чайную."},
	# mechanics, once each, at most one per match, never on L1 except where noted
	"match_help": {"target": "match.help", "mode": "tap", "line": "Подсказка, Отмена и Перемешать выручат, но без третьей звезды~"},
	"match_combo": {"target": "match.combo", "mode": "wait", "line": "Пары без пауз — и растёт ×2, ×3…"},
	"match_fever": {"target": "", "mode": "wait", "line": "Азарт! Сейчас каждая пара ценнее."},
	"match_stake": {"target": "match.stake", "mode": "tap", "line": "Ставка ×2: награда вдвое без помощи."},
}

# Speaker for a match line = the match partner (screen.partner), Маджонг-тян on L1.

# «?» in a screen header (UX §2 rule 4, §4.1.9, §4.4): one sheet, title + ≤ 3 rows (monoline icon + ≤ 2 lines) + «Подробнее».
# replay = intro id for «Показать в игре» (only if already seen). Icons: V10Icons.NAMES.
const HELP: = {
	"teahouse": {"title": "Чайная", "replay": "home_first", "rows": [
		["heart", "Касайся героини — она отвечает."],
		["tab_tables", "«Играть» ведёт к следующему столу Пути."],
		["info", "Фонарь горит, когда там есть дело."]]},
	"play": {"title": "Пары и лоток", "replay": "", "rows": [
		["tab_tables", "Снимай фишки парами: две одинаковые открытые."],
		["info", "Открытая фишка: сверху пусто, сбоку есть место."],
		["hint", "Отмена, Подсказка, Перемешать выручат, но третью звезду не дадут."]]},
	"victory": {"title": "Победа", "replay": "", "rows": [
		["info", "Звёзды — за партию без помощи."],
		["tab_tea", "Звёзды идут в Салон: на них чинят зоны."],
		["arrow_r", "«Ещё уровень» — следующий стол Пути."]]},
	"tables": {"title": "Столы", "replay": "tables_first", "rows": [
		["tab_tables", "Путь — главная дорога, глава за главой."],
		["info", "Новые столы открываются по одному, по ходу игры."],
		["arrow_r", "«Сегодня»: партия дня и режим дня ×2."]]},
	"salon": {"title": "Салон", "replay": "lantern_salon", "rows": [
		["info", "Звёзды из партий чинят зоны Салона."],
		["arrow_r", "Начни с задачи «Вывеска — 3★»."],
		["heart", "Готовая зона открывает новую сцену героини."]]},
	"wishes": {"title": "Желания", "replay": "wishes_first", "rows": [
		["info", "Здесь всё случайное. Шансы — по кнопке «Шансы»."],
		["tab_wishes", "SSR — не позже 60-го желания."],
		["heart", "Повтор наряда даёт Созвездие и Лепестки."]]},
	"heroines": {"title": "Героини", "replay": "heroines_first", "rows": [
		["tab_heroines", "Наряды, стиль и Дар каждой героини."],
		["heart", "Партнёр встречает в Чайной и играет с тобой."],
		["info", "Редкость — это сколько косметики у наряда. Силы в рейтинге она не даёт."]]},
	"shop": {"title": "Лавка", "replay": "", "rows": [
		["tab_shop", "Здесь ты точно знаешь, что получишь."],
		["info", "У каждой покупки видно, сколько это желаний."],
		["heart", "Подарок дня забирай раз в день."]]},
	"phone": {"title": "Телефон", "replay": "phone_first", "rows": [
		["phone", "Почта, Чаты и Лента: героини пишут тебе."],
		["heart", "Ответ выбирай касанием — она его запомнит."],
		["info", "Новые чаты и лента приходят со второго дня."]]},
	"today": {"title": "Сегодня", "replay": "lantern_today", "rows": [
		["info", "Всё на день: партия дня и задания дня."],
		["tab_tables", "В режиме дня ×2 вдвое больше монет и очков ранга."],
		["arrow_r", "Новый день начинается в 04:00."]]},
	"streak": {"title": "Серия", "replay": "lantern_streak", "rows": [
		["heart", "Заходи в гости — подарки копятся."],
		["info", "Ничего не сгорит, даже если день пропущен."],
		["arrow_r", "Утренний поднос ждёт раз в сутки."]]},
	"tabs": {"title": "Вкладки", "replay": "v10_welcome", "rows": [
		["tab_tea", "Чайная: твоя героиня и кнопка «Играть»."],
		["tab_tables", "Столы: Путь и все режимы на одном экране."],
		["tab_heroines", "Героини, Желания и Лавка — рядом внизу."]]},
	"priem": {"title": "Приём", "replay": "", "rows": [
		["heart", "Приём — особый ход героини."],
		["info", "Пары заряжают кольцо вокруг неё."],
		["arrow_r", "Кольцо полное — коснись героини."]]},
	"help_row": {"title": "Помощь", "replay": "", "rows": [
		["undo", "Отмена возвращает фишку из лотка."],
		["hint", "Подсказка показывает открытую пару."],
		["shuffle", "Перемешать раскладывает стол заново."]]},
	"triples": {"title": "Тройки", "replay": "mode_triples", "rows": [
		["tab_tables", "Собирай в лоток по три одинаковые открытые фишки."],
		["info", "Тройка схлопывается и освобождает лоток."],
		["heart", "Приём партнёра работает прямо на столе."]]},
	"riichi": {"title": "Стол на четверых", "replay": "mode_riichi", "rows": [
		["tab_tables", "Японский маджонг против трёх героинь."],
		["info", "Собери готовую комбинацию из четырёх групп и пары."],
		["arrow_r", "Начни с учебного зала — подсказки включены."]]},
	"koikoi": {"title": "Коикои", "replay": "mode_koikoi", "rows": [
		["tab_tables", "Бери карты одного месяца со стола в пару."],
		["info", "Сложи комбинацию карт раньше соперницы."],
		["heart", "Скажи «Коикои», чтобы продолжить раунд за больший счёт."]]},
	"pagoda": {"title": "Пагода", "replay": "mode_pagoda", "rows": [
		["tab_tables", "Поднимайся этаж за этажом с новыми условиями."],
		["info", "Выбирай благословения перед сложными этажами."],
		["arrow_r", "Чем выше этаж и Жар, тем ценнее награда."]]},
	"journey": {"title": "Странствие", "replay": "mode_journey", "rows": [
		["tab_tables", "Недельный маршрут за пятью печатями."],
		["info", "Каждый стол маршрута меняет правила раскладки."],
		["arrow_r", "Все пять печатей открывают сундук недели."]]},
	"duels": {"title": "Дуэли", "replay": "mode_duels", "rows": [
		["tab_tables", "Гонка на одной раскладке против соперницы."],
		["info", "Серии пар без пауз ускоряют победу."],
		["arrow_r", "Дружеская или рейтинговая — выбор перед стартом."]]},
}

# «Как играть» (one sheet, rows open the topic in place). Only open topics are listed, plus ≤ 1 teaser.
# gate "" = always open.
const HOW_TO: = [
	{"topic": "play", "title": "Пары и лоток", "sub": "Пары, лоток и звёзды", "gate": ""},
	{"topic": "help_row", "title": "Помощь", "sub": "Отмена, Подсказка, Перемешать", "gate": "match.help"},
	{"topic": "priem", "title": "Приём", "sub": "Особый ход героини", "gate": ""},
	{"topic": "teahouse", "title": "Чайная", "sub": "Героиня и «Играть»", "gate": "tab.tables"},
	{"topic": "tables", "title": "Столы", "sub": "Путь и режимы", "gate": "tab.tables"},
	{"topic": "salon", "title": "Салон", "sub": "Звёзды чинят зоны", "gate": "lantern.salon"},
	{"topic": "wishes", "title": "Желания", "sub": "Случайное и шансы", "gate": "tab.wishes"},
	{"topic": "heroines", "title": "Героини", "sub": "Наряды, стиль и Дар", "gate": "tab.heroines"},
	{"topic": "phone", "title": "Телефон", "sub": "Письма и чаты", "gate": "phone"},
	{"topic": "today", "title": "Сегодня", "sub": "Дела на день", "gate": "lantern.today"},
	{"topic": "streak", "title": "Серия", "sub": "Подарки каждый день", "gate": "lantern.streak"},
	{"topic": "shop", "title": "Лавка", "sub": "Известное, без случайности", "gate": "tab.shop"},
	{"topic": "triples", "title": "Тройки", "sub": "Три одинаковые в лотке", "gate": "mode.triples"},
	{"topic": "riichi", "title": "Стол на четверых", "sub": "Партия против трёх героинь", "gate": "mode.riichi"},
	{"topic": "koikoi", "title": "Коикои", "sub": "Карты двенадцати месяцев", "gate": "mode.koikoi"},
	{"topic": "journey", "title": "Странствие", "sub": "Маршрут за пятью печатями", "gate": "mode.journey"},
	{"topic": "duels", "title": "Дуэли", "sub": "Гонка на одной раскладке", "gate": "mode.duels"},
	{"topic": "pagoda", "title": "Пагода", "sub": "Этаж за этажом", "gate": "mode.pagoda"},
]

# System strings (not the heroine's voice): Nunito, UX §4.
const UI: = {
	"how_to": "Как играть",
	"understood": "Понятно",
	"more": "Подробнее",
	"show_in_game": "Показать в игре",
	"replay_first": "Первая партия",
	"hints": "Подсказки героини",
	"hints_sub": "Реплики со спотлайтом",
	"glossary": "Словарь",
	"skip": "Пропустить",
	"skip_sure": "Точно пропустить?",
	"locked_level": "Откроется после партии {n}",
	"locked_day": "Откроется на {n}-й день",
	"locked_rank": "Откроется на ступени «{r}»",
	"locked_soon": "Откроется позже",
	"teaser": "Откроется: {what}",
}

# Rank names for rank-gated shelves (UX §3.5).
const RANK_GATES: = {"mode.garden": "Нефрит I", "mode.journey": "Нефрит I", "mode.duels": "Нефрит III",
	"mode.etudes": "Нефрит III", "mode.shift": "Жемчуг I", "mode.pagoda": "Золото I"}


static func t(s: String) -> String:
	return TranslationServer.translate(s)


static func ui(key: String, args: = {}) -> String:
	var s: = t(String(UI.get(key, key)))
	for k in args:
		s = s.replace("{" + String(k) + "}", str(args[k]))
	return s


# «В лотке 5 мест» / «4 места» / «1 место» (Russian plural).
static func places(n: int) -> String:
	var m10: = n % 10
	var m100: = n % 100
	var w: = "мест"
	if m10 == 1 and m100 != 11:
		w = "место"
	elif m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		w = "места"
	return "%d %s" % [n, w]


static func match_line(key: String, args: = {}) -> String:
	var s: = t(String(MATCH.get(key, {}).get("line", "")))
	if args.has("n"):
		s = s.replace("{n}", places(int(args.n)))
	return s


static func intro_line(id: String) -> String:
	return t(String(INTROS.get(id, {}).get("line", "")))


static func hero_name(id: String) -> String:
	if G != null and G.HEROES.has(id):
		return String(G.HEROES[id].get("name", id))
	return id


# Every heroine line (for the selftest lint and the Caveat line-count check).
static func all_heroine_lines() -> Array:
	var out: = []
	for k in INTROS:
		out.append(String(INTROS[k].line))
	for k in MATCH:
		out.append(String(MATCH[k].line).replace("{n}", places(5)))
	return out


# Every system string a player can see (for the UX §4.2/§4.3 lint).
static func all_ui_strings() -> Array:
	var out: = []
	for k in UI:
		out.append(String(UI[k]))
	for k in HELP:
		out.append(String(HELP[k].title))
		for r in HELP[k].rows:
			out.append(String(r[1]))
	for e in HOW_TO:
		out.append(String(e.title))
		out.append(String(e.sub))
	for k in RANK_GATES:
		out.append(String(RANK_GATES[k]))
	return out
