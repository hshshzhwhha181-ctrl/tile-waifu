class_name V10HandText
extends RefCounted

# «Чтение руки» — every string the player sees or hears from this module (UX_RULES §4: one concept — one word;
# button = verb + what, ≤ 18 chars; numbers with units; no abbreviations; no «%» / «₽»; only «догадка», never
# «ставка» or «пари»). The screens take their words from here; the selftest lints all of them (V10Lint + §4.3).
#
# Naming note (HEROINES red lines: no school theme): the spec's «Школа» / «Школа ожиданий» / «уроки» are shown as
# «С подсказкой» (the first 7 days) and «Разбор ожиданий» with «разборы». Save keys keep the spec names (school).

const MODE: = "Чтение руки"
const MODE_LINE: = "Угадай, какую фишку ждёт героиня"            # Столы shelf / Афиша tab subtitle
const MODE_SUB: = "Снимай пары — её рука откроется"

const BTN_GUESS: = "Сделать догадку"        # primary of the hand screen (opens the 34-kind shutter)
const BTN_YES: = "Да"                        # confirms «Она ждёт 5 пин?»
const BTN_NO: = "Выбрать другую"
const BTN_SHARE: = "Поделиться"
const BTN_DONE: = "Готово"
const BTN_LESSONS: = "Разбор ожиданий"
const BTN_LESSON_CHECK: = "Проверить"
const BTN_LESSON_NEXT: = "Дальше"

const ASK: = "Она ждёт %s?"                  # %s = V8Mj.name_ru(kind)
const SHUTTER_TITLE: = "Чего она ждёт?"
const SHUTTER_DIM: = "Все 4 копии уже видны"
const STRIP: = "Не у неё"
const SLEEVE: = "В рукаве"
const SLEEVE_SUB: = "Эти карты не откроются"
const CLOSED_N: = "Закрыто %d из 13"         # «Закрыто 8 из 13»
const BOLD: = "Смелость ×%d"                 # ×1 / ×2 / ×3
const BOLD_SUB: = "Чем больше закрыто, тем больше награда"
const STAMP: = "РОН!"
const RIGHT: = "Верно!"
const WRONG: = "Она ждала другое"
const TABLE_CLOSED: = "Стол закрыт"
const TABLE_CLOSED_SUB: = "Догадка всё ещё доступна"
const DONE_TODAY: = "Догадка на сегодня сделана"
const NEXT_HAND: = "Новая рука в 04:00"
const LOCK: = "Откроется на уровне %d"
const FAIR: = "Здесь только честная игра"   # Огонёк пути / стартовые бустеры are grey in this mode (spec П3)
const SCHOOL: = "С подсказкой"
const SCHOOL_SUB: = "Первые 7 дней форма и кандидаты подсвечены"
const SCHOOL_FORM: = "Форма: %s"             # %s = form title, lower-case first letter
const CAND: = "Кандидаты"
const STREAK: = "Серия верных догадок: %d"
const REWARD_GEMS: = "+%d %s"                # +30 кристаллов (V10HandUtil.gems_text)
const REWARD_BOND: = "+%d симпатии"
const HERO_OF_DAY: = "Руку загадала %s"      # %s = heroine name

# Rules sheet (UX §4.1 rule 9: 3 lines + «Подробнее»)
const RULES: = [
	"Сними пару — такие же карты в её руке перевернутся",
	"Сделай догадку в любой момент: чем раньше, тем больше смелость",
	"Догадка — раз в день, новая рука в 04:00",
]
const RULES_MORE: = "Подробнее"

# Share (clipboard): never a tile name, never the answer
const SHARE: = "%s · %s · %s · закрыто %d из 13"
const SHARE_STREAK: = " · серия %d"
const SHARE_RIGHT: = "догадка верна"
const SHARE_WRONG: = "догадка не совпала"

# The heroine of the day: one line on the entry queue (UX §3.5: one system per launch, one line, one spotlight)
# and one line on each outcome. She never talks about purchases (V10Lint).
const INTRO: = {
	"mc": "Я загадала руку. Снимай пары — и увидишь, чего я жду.",
	"rin": "Чайная пауза: угадай, какую фишку я жду.",
	"hana": "Угадаешь мою фишку быстрее, чем я пробегу круг?",
	"yue": "Луна сегодня скрыла мою руку. Прочтёшь её?",
	"nova": "Я спрятала руку за кодом. Взломаешь?",
}
const INTRO_ANY: = "Я загадала руку. Угадаешь, чего я жду?"
const SAY_RIGHT: = {
	"mc": "Ты читаешь меня, как открытую книгу!",
	"rin": "Точно в чашку. Красиво.",
	"hana": "Есть! Вот это скорость!",
	"yue": "Ты видишь сквозь лунный свет.",
	"nova": "Доступ получен. Впечатляет.",
}
const SAY_WRONG: = {
	"mc": "Почти! Смотри, вот как она складывалась.",
	"rin": "Не сегодня. Взгляни на форму спокойно.",
	"hana": "Мимо, но отличная попытка!",
	"yue": "Луна ещё прячет секреты. Взгляни.",
	"nova": "Неверный ключ. Вот исходник руки.",
}

# Glossary entries (V10Glossary format: id, cat, name, sub, why, how, reward, icon)
const GLOSSARY: = [
	{"id": "hand.mode", "cat": "mode", "name": "Чтение руки", "sub": "партия дня",
		"why": "Героиня загадывает руку из 13 карт и ждёт одну из фишек. Снимай пары со стола и угадай её ожидание.",
		"how": "Каждый день с 04:00, догадка — раз в день", "reward": "Кристаллы и симпатия героини", "icon": "glyph:palm"},
	{"id": "hand.wait", "cat": "mode", "name": "Ожидание", "sub": "чего она ждёт",
		"why": "Фишка, которая закроет её руку: четыре тройки или ряда и пара.",
		"how": "Смотри, каких соседей не хватает её картам", "reward": "", "icon": "glyph:palm"},
	{"id": "hand.sleeve", "cat": "mode", "name": "Рукав", "sub": "карты, что не откроются",
		"why": "От одной до трёх карт её руки остаются закрытыми до самой догадки.",
		"how": "Их место в ряду подсказывает, что там может лежать", "reward": "", "icon": "glyph:palm"},
	{"id": "hand.bold", "cat": "mode", "name": "Смелость", "sub": "множитель награды",
		"why": "Закрыто 7 карт и больше — ×3, от 4 до 6 — ×2, меньше — ×1.",
		"how": "Делай догадку раньше, пока рука ещё закрыта", "reward": "До 30 кристаллов за верную догадку", "icon": "glyph:palm"},
	{"id": "hand.notin", "cat": "mode", "name": "Не у неё", "sub": "снятые пары не из её руки",
		"why": "Если снятой пары нет в её руке, фишка уходит в эту полоску.",
		"how": "Эти фишки она не держит", "reward": "", "icon": "glyph:palm"},
]

# «Разбор ожиданий»: 7 разборов (≈2 минуты: 3 руки каждый)
const LESSONS_TITLE: = "Разбор ожиданий"
const LESSONS_SUB: = "7 разборов по 2 минуты"
const LESSON_N: = "Разбор %d"
const LESSON_ASK: = "Отметь все фишки, которых она ждёт"
const LESSON_RIGHT: = "Верно!"
const LESSON_MISS: = "Не все: %s"            # «Не все: ещё 6 пин»
const LESSON_EXTRA: = "Лишние: %s"
const LESSON_DONE: = "Разбор пройден"
const LESSON_LOCK: = "Откроется после разбора %d"


static func all_strings() -> Array:
	var out: = [MODE, MODE_LINE, MODE_SUB, BTN_GUESS, BTN_YES, BTN_NO, BTN_SHARE, BTN_DONE, BTN_LESSONS, BTN_LESSON_CHECK,
		BTN_LESSON_NEXT, ASK % "5 пин", SHUTTER_TITLE, SHUTTER_DIM, STRIP, SLEEVE, SLEEVE_SUB, CLOSED_N % 8, BOLD % 3,
		BOLD_SUB, STAMP, RIGHT, WRONG, TABLE_CLOSED, TABLE_CLOSED_SUB, DONE_TODAY, NEXT_HAND, LOCK % 30, FAIR, SCHOOL,
		SCHOOL_SUB, SCHOOL_FORM % "с двух сторон", CAND, STREAK % 4, REWARD_GEMS % [30, "кристаллов"], REWARD_BOND % 2,
		HERO_OF_DAY % "Рин", RULES_MORE, SHARE_RIGHT, SHARE_WRONG, INTRO_ANY, LESSONS_TITLE, LESSONS_SUB, LESSON_N % 1,
		LESSON_ASK, LESSON_RIGHT, LESSON_MISS % "6 пин", LESSON_EXTRA % "2 пин", LESSON_DONE, LESSON_LOCK % 1]
	out.append_array(RULES)
	for d in [INTRO, SAY_RIGHT, SAY_WRONG]:
		for k in d:
			out.append(d[k])
	for g in GLOSSARY:
		for k in ["name", "sub", "why", "how", "reward"]:
			out.append(String(g[k]))
	return out


# heroine-facing lines only (V10Lint.BANNED is for her voice; UX §4.3 for everything)
static func hero_lines() -> Array:
	var out: = [INTRO_ANY]
	for d in [INTRO, SAY_RIGHT, SAY_WRONG]:
		for k in d:
			out.append(d[k])
	return out


static func intro(h: String) -> String:
	return String(INTRO.get(h, INTRO_ANY))


static func say(h: String, right: bool) -> String:
	var d: Dictionary = SAY_RIGHT if right else SAY_WRONG
	return String(d.get(h, d.mc))
