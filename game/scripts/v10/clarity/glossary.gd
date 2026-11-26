class_name V10Glossary
extends RefCounted

# V10Glossary — ONE place for every name the player meets during and after a match (docs: game/scripts/v10/clarity/README.md).
# Every achievement, bonus, combo step, event, fortune, special tile, tile state, suit, tile face, rank, league,
# ult modifier and secret has a clear warm Russian name and the answers to «за что?» and «как получить ещё раз?».
#
# Entry fields:
#   id      "bonus.clean", "face.12", "suit.0" … (stable; the tutorial lane and the victory screen use these)
#   cat     section of the «Словарь» (CATS)
#   name    the main label: self-explanatory on its own (≤ NAME_MAX)
#   sub     optional mahjong / poetic flavour shown small under the name («риичи», «кокуси»…) (≤ SUB_MAX)
#   why     ONE line «За что: …» (≤ WHY_MAX, never empty)
#   how     «Как получить снова: …» (≤ HOW_MAX)
#   reward  what it gives (≤ REWARD_MAX; "" = nothing to give, e.g. a tile state)
#   icon    V10ClarityIcon spec ("art:trophy", "suit:2", "tile:12", "combo:7", "state:gold", "spec:lock", "glyph:target" …)
#   was     the names the game data / older builds use for the same thing (the selftest maps game labels → entries)
#
# API (all static):
#   get_entry(id) -> Dictionary ({} if unknown)       has(id)
#   label(id) / why(id) / how(id)                     the strings («» if unknown)
#   bonus_id(yaku) -> String                          G.YAKU key or "set:N" → "bonus.clean" / "set.2"
#   bonus_points(yaku) -> int                         rank points of a bonus (G.YAKU rp)
#   entries(cat) -> Array                             entries of one section, in display order
#   find_by_name(text) -> Dictionary                  an entry by its clear name or any old name («Чистая рука» → bonus.clean)
#   suit_of(face) -> int                              -1 for shard / joker / unknown
#   face_index(face) -> int                           1-based number of the face inside its suit (the corner numeral)
#   suit_color(cat) / suit_glyph(cat)                 colour + shape of the suit mark (colour-blind safe: shape differs too)
#   star_rule() / stats_line(secs, helps, overflows)  the clear victory lines
#   tip(id) -> String                                 one short line «Имя — за что» for the tutorial lane's tips

const NAME_MAX: = 26
const SUB_MAX: = 30
const WHY_MAX: = 74
const HOW_MAX: = 92
const REWARD_MAX: = 60

const CATS: = [
	["win", "Награды партии"],
	["bonus", "Бонусы за партию"],
	["combo", "Комбо и серии"],
	["event", "События на столе"],
	["fortune", "Гадание перед партией"],
	["suit", "Масти фишек"],
	["face", "Картинки фишек"],
	["special", "Особые фишки"],
	["state", "Как читать фишку"],
	["rank", "Ранги"],
	["league", "Лиги недели"],
	["ult", "Умение героини"],
	["path", "Путь"],
	["salon", "Салон"],
	["egg", "Секреты"],
]

# suit marks: colour + shape (the shape alone tells the suit apart for colour-blind players)
const SUIT_LOOK: = [
	{"col": Color("ec6f9c"), "glyph": "flower", "short": "цветы", "name": "Цветы"},
	{"col": Color("4aa3e6"), "glyph": "star", "short": "небо", "name": "Небо"},
	{"col": Color("f08a3a"), "glyph": "candy", "short": "сладости", "name": "Сладости"},
	{"col": Color("d9a520"), "glyph": "gem", "short": "сокровища", "name": "Сокровища"},
	{"col": Color("43ad6e"), "glyph": "paw", "short": "звери", "name": "Звери"},
]

const BASE: = [
	# ── награды партии (экран победы) ──
	{"id": "win.base", "cat": "win", "name": "Стол пройден", "why": "6 очков за победу, +4 за каждую звезду, +8 за сложный стол",
		"how": "Пройди любой стол Пути или ежедневный стол", "reward": "очки ранга", "icon": "art:trophy", "was": ["Победа"]},
	{"id": "win.stars", "cat": "win", "name": "Звёзды", "why": "1★ — победа, 2★ — до 2 подсказок, 3★ — совсем без помощи",
		"how": "Без подсказок, возвратов, перемешиваний и переполнений будет 3★", "reward": "+20 кристаллов за каждую звезду", "icon": "art:star"},
	{"id": "win.gems", "cat": "win", "name": "Кристаллы", "why": "Награда стола, +20 за звезду и всё собранное за партию",
		"how": "Пары, золотые фишки, комбо и подарки дают кристаллы", "reward": "тратятся в Желаниях и Лавке", "icon": "cur:gem"},
	{"id": "win.wishes", "cat": "win", "name": "Желания", "sub": "призыв", "why": "Здесь за кристаллы призывают героинь и наряды",
		"how": "Кнопка «Желания» после победы или вкладка внизу", "reward": "героини и наряды", "icon": "cur:gem", "was": ["Призыв"]},
	{"id": "win.style", "cat": "win", "name": "Свойство героини", "why": "У напарницы своё свойство на столе: Маджонг-тян даёт 5 мест в лотке",
		"how": "Свойство зависит от героини, с которой играешь", "reward": "", "icon": "art:heart", "was": ["Стиль"]},
	{"id": "win.affinity", "cat": "win", "name": "Симпатия", "why": "Героиня-напарница рада победе: +10 симпатии",
		"how": "Играй с ней в паре и болтай с ней в Чайной", "reward": "открывает письма, наряды и сцены", "icon": "art:heart", "was": ["Симпатия %d"]},
	{"id": "win.rank", "cat": "win", "name": "Очки ранга", "why": "Победа и бонусы партии копятся в ранге (Бамбук, Нефрит …). Ранг не падает",
		"how": "Чем чище партия, тем больше очков", "reward": "новый ранг даёт кристаллы и режимы", "icon": "rank:1", "was": ["очки ранга"]},
	{"id": "win.week", "cat": "win", "name": "Гонка недели", "why": "Неделя — гонка в группе из 20 игроков. Лига — это группа, не твой ранг",
		"how": "Побеждай за неделю: каждая победа двигает тебя вверх", "reward": "кристаллы и наряды за место", "icon": "league:0", "was": ["Лига"]},
	{"id": "win.season", "cat": "win", "name": "Сезон", "why": "Очки ранга идут в общий рейтинг сезона (3 месяца)",
		"how": "Копи очки ранга весь сезон", "reward": "место в общем рейтинге", "icon": "art:rating", "was": ["Квартал"]},
	{"id": "win.album", "cat": "win", "name": "Коллекция фишек", "why": "Картинка выросла в коллекции: 1, 10, 30 пар — бронза, серебро, золото",
		"how": "Собирай пары разных картинок", "reward": "полные масти дают бонусы в каждой партии", "icon": "glyph:album", "was": ["Альбом", "марки"]},
	{"id": "win.shard", "cat": "win", "name": "Частичка героини", "why": "Снята фишка с портретом героини. 5 частичек — она в команде",
		"how": "Ищи на столе фишку с лицом в золотом круге", "reward": "5 из 5 — новая героиня", "icon": "state:shard", "was": ["Осколок портрета", "осколок"]},
	{"id": "win.item", "cat": "win", "name": "Новая вещь", "why": "Первая победа на этом столе дарит вещь",
		"how": "Пройди новый стол впервые", "reward": "наряд, фон или фишки", "icon": "art:gift"},
	{"id": "win.helps", "cat": "win", "name": "Помощь", "why": "Подсказка, возврат и перемешивание — каждая считается",
		"how": "Чем меньше помощи, тем больше звёзд", "reward": "", "icon": "art:hint", "was": ["помощь"]},
	{"id": "win.overflow", "cat": "win", "name": "Переполнение лотка", "why": "Лоток заполнился, и стол пришлось спасать",
		"how": "Держи в лотке хотя бы одно место пустым", "reward": "", "icon": "glyph:tray_full", "was": ["переполнений"]},

	# ── бонусы за партию (G.YAKU) ──
	{"id": "bonus.clean", "cat": "bonus", "name": "Без подсказок", "why": "Ни одной подсказки, возврата, перемешивания и без переполнений",
		"how": "Реши стол сам, не нажимая кнопки помощи", "icon": "art:hint|no", "yaku": "clean", "was": ["Чистая рука"]},
	{"id": "bonus.calm", "cat": "bonus", "name": "Аккуратный лоток", "why": "В лотке всю партию было не больше 2 фишек",
		"how": "Бери фишку, когда уже видишь ей пару", "icon": "glyph:tray2", "yaku": "calm", "was": ["Пустой лоток"]},
	{"id": "bonus.sharp", "cat": "bonus", "name": "Ни одного промаха", "why": "Ни разу не нажата зажатая (тусклая) фишка",
		"how": "Жми только светлые фишки — тусклые пока заняты", "icon": "glyph:target", "yaku": "sharp", "was": ["Без промаха"]},
	{"id": "bonus.swift", "cat": "bonus", "name": "Быстрая рука", "why": "Стол пройден быстрее 1,1 секунды на фишку",
		"how": "Ищи пары сразу, не раздумывай долго", "icon": "glyph:watch", "yaku": "swift", "was": ["Молния"]},
	{"id": "bonus.riichi", "cat": "bonus", "name": "Ва-банк ×2", "why": "Нажат «Ва-банк», и стол пройден без подсказок: награда ×2",
		"how": "Когда фишек мало и лоток пуст, появится кнопка «Ва-банк». Нажми и доиграй сам", "icon": "glyph:riichi", "yaku": "riichi", "was": ["Ва-банк", "ВА-БАНК!", "Риичи", "РИИЧИ!"]},
	{"id": "bonus.dragon", "cat": "bonus", "name": "Комбо ×7", "why": "7 пар подряд без паузы",
		"how": "Снимай пары быстро, пока горит шкала комбо", "icon": "combo:7", "yaku": "dragon", "was": ["Пробуждение дракона"]},
	{"id": "bonus.goldvein", "cat": "bonus", "name": "Все золотые", "why": "Собраны все золотые фишки стола",
		"how": "Не оставляй золотые пары на потом", "icon": "state:gold", "yaku": "goldvein", "was": ["Золотая жила"]},
	{"id": "bonus.finale", "cat": "bonus", "name": "Красивый финал", "why": "Последняя пара снята в комбо ×3 или выше",
		"how": "Оставь к концу пары наготове и закончи серией", "icon": "glyph:finale", "yaku": "finale", "was": ["Финальный аккорд"]},
	{"id": "bonus.set", "cat": "bonus", "name": "Тройка", "why": "3 пары одной масти подряд (одного цвета уголка)",
		"how": "Смотри на цветной уголок: три пары одного цвета подряд", "icon": "glyph:three", "yaku": "set", "was": ["Тройка"]},

	# ── комбо и серии ──
	{"id": "combo.what", "cat": "combo", "name": "Комбо", "why": "Пары подряд без паузы: каждая следующая дороже",
		"how": "Снимай следующую пару, пока не погасла шкала", "reward": "×3 +5, ×5 двойные кристаллы, ×8 подсказка", "icon": "combo:3", "was": ["Серия ×N"]},
	{"id": "combo.fever", "cat": "combo", "name": "Полнолуние ×2", "why": "Комбо ×5 включает 8 секунд, когда кристаллы за пары ×2",
		"how": "Дотяни комбо до ×5", "reward": "кристаллы ×2 на 8 секунд", "icon": "cur:gem|x2", "was": ["Кристаллы ×2", "Полнолуние", "Лихорадка", "Лихорадка ×2"]},
	{"id": "combo.streak", "cat": "combo", "name": "Чистый ритм ×6", "why": "Каждые 6 пар подряд, пока в лотке не больше 2 фишек",
		"how": "Без промахов и без третьей фишки в лотке", "reward": "+20, потом +30 и подсказка, дальше заряд умения", "icon": "glyph:tray2|6", "was": ["Счастливая серия"]},

	# ── события на столе (V6Specials.EVENTS) и призы из подарка ──
	{"id": "event.starfall", "cat": "event", "name": "Звездопад ×3", "why": "10 секунд каждая пара даёт втрое больше кристаллов",
		"how": "Случайное событие в партии с 1-3 и дальше", "reward": "кристаллы ×3 на 10 секунд", "icon": "glyph:starfall", "ev": "starfall", "was": ["Звездопад"]},
	{"id": "event.giftdrop", "cat": "event", "name": "Подарок с неба", "why": "На стол упал подарок: собери пару фишек с коробочкой",
		"how": "Случайное событие в партии", "reward": "приз из подарка", "icon": "spec:gift", "ev": "giftdrop"},
	{"id": "event.wind", "cat": "event", "name": "Попутный ветер", "why": "Ветер сам унёс со стола 2 пары",
		"how": "Случайное событие в партии с главы 2", "reward": "−2 пары на столе", "icon": "art:shuffle", "ev": "wind"},
	{"id": "event.golden", "cat": "event", "name": "Золотые пары", "sub": "золотой дождь", "why": "3 пары на столе стали золотыми: каждая ×5 кристаллов",
		"how": "Случайное событие в партии с главы 3", "reward": "×5 кристаллов за эти пары", "icon": "state:gold", "ev": "golden", "was": ["Золотой дождь"]},
	{"id": "event.challenge", "cat": "event", "name": "Вызов: 3 пары за 12 с", "sub": "вызов Маджонг-тян", "why": "Успей снять 3 пары за 12 секунд",
		"how": "Случайное событие в партии с главы 3", "reward": "+60 кристаллов и подсказка", "icon": "glyph:watch", "ev": "challenge", "was": ["Вызов Маджонг-тян", "Вызов принят!"]},
	{"id": "event.box_star", "cat": "event", "name": "Кристаллы ×2 из подарка", "sub": "звёздный миг", "why": "В подарке оказались 8 секунд двойных кристаллов",
		"how": "Открой подарок: собери пару фишек с коробочкой", "reward": "кристаллы ×2 на 8 секунд", "icon": "spec:gift", "was": ["Звёздный миг"]},
	{"id": "event.jackpot", "cat": "event", "name": "Джекпот", "why": "Самый редкий приз подарка: 200 кристаллов сразу",
		"how": "Открывай подарки — повезёт", "reward": "200 кристаллов", "icon": "cur:gem", "was": ["Джекпот: 200 кристаллов!"]},

	# ── особые фишки (V6Specials.NAMES) ──
	{"id": "special.gift", "cat": "special", "name": "Подарок", "sub": "фишка с коробочкой", "why": "Собери пару фишек с коробочкой — внутри случайный приз",
		"how": "Подарки есть почти на каждом столе", "reward": "кристаллы, подсказка, возврат или джекпот", "icon": "spec:gift", "sp": "gift", "was": ["Шкатулка"]},
	{"id": "special.lock", "cat": "special", "name": "Замок и ключ", "why": "Фишку под замком не взять, пока не собрана пара с ключом того же цвета",
		"how": "Найди ключ цвета замка и собери его пару", "reward": "замки этого цвета открываются", "icon": "spec:lock", "sp": "lock"},
	{"id": "special.chain", "cat": "special", "name": "Цепь", "why": "Число на цепи — сколько пар снять, чтобы цепь спала",
		"how": "Снимай любые пары, цепь считает сама", "reward": "", "icon": "spec:chain", "sp": "chain"},
	{"id": "special.joker", "cat": "special", "name": "Джокер", "sub": "любая пара", "why": "Встаёт в пару к любой фишке в лотке",
		"how": "Возьми джокера, когда в лотке лишняя фишка", "reward": "", "icon": "spec:joker", "sp": "joker"},
	{"id": "special.bomb", "cat": "special", "name": "Хлопушка", "why": "Пара с хлопушкой снимает до 3 соседних пар",
		"how": "Собери пару с хлопушкой в гуще стола", "reward": "до 3 пар сразу", "icon": "spec:bomb", "sp": "bomb", "was": ["Бабах!"]},

	# ── как читать фишку (состояния) ──
	{"id": "state.free", "cat": "state", "name": "Свободная фишка", "why": "Сверху пусто и открыт хотя бы один бок — её можно взять",
		"how": "Свободные фишки светлые и чуть приподняты", "reward": "", "icon": "state:free"},
	{"id": "state.blocked", "cat": "state", "name": "Зажатая фишка", "why": "Сверху лежит фишка или оба бока закрыты — пока не взять",
		"how": "Сначала сними фишку сверху или сбоку", "reward": "", "icon": "state:blocked"},
	{"id": "state.pair", "cat": "state", "name": "Пара", "why": "Две одинаковые картинки в лотке исчезают",
		"how": "Пара — только точно такая же картинка", "reward": "кристаллы и заряд умения", "icon": "state:pair"},
	{"id": "state.tray", "cat": "state", "name": "Лоток", "why": "Сюда уезжает взятая фишка. Лоток полон — проигрыш, если не спасти",
		"how": "Держи в лотке хотя бы одно место пустым", "reward": "", "icon": "glyph:tray2"},
	{"id": "state.gold", "cat": "state", "name": "Золотая фишка", "why": "Пара золотых даёт ×5 кристаллов",
		"how": "Золото встречается с первой главы и в гадании", "reward": "×5 кристаллов за пару", "icon": "state:gold", "was": ["золото", "Золото"]},
	{"id": "state.flip", "cat": "state", "name": "Рубашка", "why": "Фишка лежит лицом вниз: первое касание её переворачивает",
		"how": "Тапни свободную рубашку (синий значок-стрелка), потом бери", "reward": "", "icon": "state:flip", "was": ["перевёртыши", "Перевёртыш", "лёд", "Лёд"]},
	{"id": "state.secret", "cat": "state", "name": "Тайная фишка", "why": "Откроется сама, когда станет свободной (значок «?»)",
		"how": "Сними фишки вокруг неё", "reward": "", "icon": "state:secret", "was": ["тайные фишки", "Тайная"]},
	{"id": "state.shard", "cat": "state", "name": "Фишка с портретом", "sub": "частичка героини", "why": "Пара с лицом героини даёт её частичку",
		"how": "Есть на столах Пути, по одной паре", "reward": "1 частичка из 5", "icon": "state:shard"},
	{"id": "state.mark", "cat": "state", "name": "Цветной уголок", "why": "Уголок — только масть. Пару он не задаёт: пара — одинаковая картинка",
		"how": "Включить или выключить: Настройки → «Фишки и словарь» → «Цветной уголок»", "reward": "", "icon": "suit:0"},

	# ── умение героини ──
	{"id": "ult.meter", "cat": "ult", "name": "Умение героини", "why": "Заряжается от каждой пары. Полная шкала — тапни героиню",
		"how": "Собирай пары, шкала под портретом растёт", "reward": "героиня сама помогает на столе", "icon": "art:visits", "was": ["ульта", "Ульта", "умение"]},
]

# fortunes (G.FORTUNES): clear name = the effect; the poetic name becomes the sub
const FORTUNE_TEXT: = {
	"great": {"name": "+50% кристаллов", "why": "Гадание перед партией: кристаллы за эту партию +50%"},
	"tray": {"name": "Лоток спасётся сам", "why": "Гадание: если лоток переполнится, он один раз спасётся"},
	"pairs": {"name": "Первые 3 пары ×3", "why": "Гадание: первые три пары дают втрое больше кристаллов"},
	"wind": {"name": "+1 перемешивание", "why": "Гадание: ещё одно бесплатное перемешивание в партии"},
	"reveal": {"name": "Тайные открыты", "why": "Гадание: тайные фишки открыты с самого начала"},
	"gold": {"name": "Ещё 4 золотые", "why": "Гадание: на столе появятся ещё 4 золотые фишки"},
	"tea": {"name": "Комбо дольше", "why": "Гадание: комбо держится на 1,5 секунды дольше"},
	"small": {"name": "+1 подсказка", "why": "Гадание: одна бесплатная подсказка сверху"},
	"later": {"name": "Удача завтра", "why": "Сегодня без бонуса, зато следующее гадание будет великой удачей"},
}

# album tiers, ranks, leagues, ult modifiers, secrets: clear text per data id
const MOD_TEXT: = {
	"П": {"name": "Наряд: подсказка", "icon": "art:hint", "why": "Умение в этом наряде ещё и подсвечивает пару на 3 секунды"},
	"О": {"name": "Наряд: открытие", "icon": "state:secret", "why": "Умение в этом наряде ещё и открывает 1 закрытую фишку"},
	"Л": {"name": "Наряд: рубашка", "icon": "state:flip", "why": "Умение в этом наряде ещё и открывает 1 рубашку или замок"},
	"В": {"name": "Наряд: возврат", "icon": "art:undo", "why": "Умение в этом наряде ещё и возвращает 1 фишку из лотка"},
	"Ц": {"name": "Наряд: прицел", "icon": "glyph:target", "why": "Умение ещё и показывает пару, что освободит больше всего фишек"},
	"С": {"name": "Наряд: к старой", "icon": "glyph:tray2", "why": "Умение ещё и подсвечивает пару к самой старой фишке в лотке"},
}
const EGG_TEXT: = {
	"star": {"name": "Звёздная пара", "why": "Пара с крошечной искоркой: +5 кристаллов", "how": "Приглядись к углам фишек"},
	"tickle": {"name": "Щекотка", "why": "Героиня засмеялась от частых касаний", "how": "Потормоши героиню в Чайной"},
	"cameo": {"name": "Гостья у окна", "why": "В окне Чайной мелькнула гостья", "how": "Загляни в Чайную в нужный момент"},
	"cameo_locked": {"name": "Силуэт у окна", "why": "В окне мелькнул силуэт ещё не открытой героини", "how": "Чаще заглядывай в Чайную"},
	"peek": {"name": "Подглядывание", "why": "Героиня тайком смотрела, как ты играешь", "how": "Поиграй подольше, не отвлекаясь"},
	"kokushi": {"name": "Тринадцать подряд", "sub": "почти «кокуси»", "why": "13 пар подряд без единой паузы", "how": "Дотяни комбо до ×13"},
	"clock": {"name": "Особая минута", "why": "Партия сыграна в особую минуту на часах", "how": "Посмотри на часы — время бывает красивым"},
	"date": {"name": "Особый день", "why": "Игра в особую дату календаря", "how": "Заходи в праздники"},
	"moon_hour": {"name": "Лунный час", "why": "Партия глубокой ночью", "how": "Сыграй после полуночи"},
	"dawn": {"name": "Самый ранний гость", "why": "Партия на рассвете", "how": "Загляни ранним утром"},
}
const RANK_WHY: = "Твой ранг навсегда: растёт от очков ранга и не падает. Лига — отдельно"
const LEAGUE_WHY: = "Группа недели из 20 игроков. Лучшие поднимаются в лигу выше"

static var _all: = {}
static var _order: = []
static var _by_name: = {}


static func _ensure() -> void:
	if not _all.is_empty():
		return
	for e in BASE:
		_add(e.duplicate(true))
	# yaku rewards from the live table
	for id in _all:
		var e: Dictionary = _all[id]
		if e.has("yaku") and G.YAKU.has(e.yaku):
			var rp: int = int(G.YAKU[e.yaku].rp)
			e["reward"] = "+%d %s ранга" % [rp, _pts(rp)] + (" и +15 кристаллов" if e.yaku == "set" else "")
	# set:N
	for c in G.CATS.size():
		var lk: Dictionary = SUIT_LOOK[c]
		var rp: int = int(G.YAKU.set.rp)
		_add({"id": "set.%d" % c, "cat": "bonus", "name": "Тройка: %s" % lk.short, "sub": "три пары одной масти",
			"why": "3 пары подряд одной масти: %s, %s уголок" % [lk.short, _col_word(c)],
			"how": "Бери подряд пары одного цвета уголка", "reward": "+%d %s ранга и +15 кристаллов" % [rp, _pts(rp)],
			"icon": "suit:%d" % c, "yaku": "set:%d" % c, "was": [String(G.CATS[c][2])]})
	# combo tiers
	var cw: = {2: "Комбо началось — держи темп", 3: "+5 кристаллов, пары вдвое дороже", 4: "+14 кристаллов", 5: "Двойные кристаллы на 8 секунд",
		8: "+1 подсказка", 12: "+1 перемешивание", 16: "+1 возврат"}
	for t in V7Combo.TIERS:
		var n: int = int(t[0])
		_add({"id": "combo.%d" % n, "cat": "combo", "name": "Комбо ×%d" % n, "sub": String(t[1]).to_lower(),
			"why": "%d %s подряд без паузы" % [n, V8PlayRules.plural(n, "пара", "пары", "пар")],
			"how": "Снимай пары одну за другой, пока горит шкала", "reward": String(cw.get(n, "кристаллы")),
			"icon": "combo:%d" % n, "was": [String(t[1])]})
	# fortunes
	for f in G.FORTUNES:
		var ft: Dictionary = FORTUNE_TEXT.get(f.id, {"name": f.name, "why": f.desc})
		_add({"id": "fortune.%s" % f.id, "cat": "fortune", "name": ft.name, "sub": "%s · %s" % [String(f.rank).to_lower(), String(f.name).to_lower()],
			"why": ft.why, "how": "Гадание тянется само перед каждой партией Пути", "reward": "" if f.id == "later" else "на одну партию",
			"icon": "glyph:omikuji", "was": [String(f.name), String(f.rank)]})
	# suits
	for c in G.CATS.size():
		var lk2: Dictionary = SUIT_LOOK[c]
		var faces: = []
		for f in range(int(G.CATS[c][0]), int(G.CATS[c][1]) + 1):
			faces.append(String(V7AlbumData.FACE_NAMES[f]).to_lower())
		var sb: String = V7AlbumData.SUITS[c].bonus if c < V7AlbumData.SUITS.size() else ""
		_add({"id": "suit.%d" % c, "cat": "suit", "name": lk2.name, "sub": "%d %s" % [faces.size(), V8PlayRules.plural(faces.size(), "картинка", "картинки", "картинок")],
			"why": "%s: %s" % [_col_word(c).capitalize(), ", ".join(faces)],
			"how": "3 пары этой масти подряд — бонус «Тройка»", "reward": "полная масть в коллекции: %s" % sb.to_lower(),
			"icon": "suit:%d" % c, "was": [String(G.CATS[c][2])]})
	# faces
	for f in V7AlbumData.FACE_NAMES.size():
		var c2: = G.face_cat(f)
		var nm: String = V7AlbumData.FACE_NAMES[f]
		_add({"id": "face.%d" % f, "cat": "face", "name": nm, "sub": "масть «%s»" % SUIT_LOOK[c2].short,
			"why": "Пара — только такая же картинка: %s к %s" % [nm.to_lower(), nm.to_lower()],
			"how": "Масть «%s»: %s уголок" % [SUIT_LOOK[c2].short, _col_word(c2)], "reward": "",
			"icon": "tile:%d" % f})
	# ranks
	for t2 in G.RANKS.size():
		var rn: String = G.RANKS[t2].name
		_add({"id": "rank.%d" % t2, "cat": "rank", "name": "Ранг «%s»" % rn, "sub": "ступени %s I · II · III" % rn if t2 < G.RANKS.size() - 1 else "",
			"why": RANK_WHY, "how": "%d очков ранга на каждую ступень" % int(G.RANKS[t2].per),
			"reward": "+%d кристаллов за новую ступень" % int(G.RANKS[t2].gems), "icon": "rank:%d" % t2, "was": [rn]})
	# leagues
	for li in V7Ladder.LEAGUES.size():
		var L: Dictionary = V7Ladder.LEAGUES[li]
		_add({"id": "league.%d" % li, "cat": "league", "name": String(L.name), "sub": "группа гонки недели",
			"why": LEAGUE_WHY, "how": "Побеждай за неделю — места считаются в воскресенье",
			"reward": "до %d кристаллов за 1-е место" % int(L.gems[0]), "icon": "league:%d" % li, "was": [String(L.short)]})
	# ult modifiers
	for k in V9Ults.MODS:
		var md: Dictionary = MOD_TEXT.get(k, {"name": V9Ults.MODS[k].name, "icon": "glyph:target"})
		_add({"id": "mod.%s" % k, "cat": "ult", "name": md.name, "sub": "значок наряда «%s»" % k,
			"why": String(md.get("why", "Умение в этом наряде ещё и %s" % String(V9Ults.MODS[k].desc))),
			"how": "Зависит от надетого наряда героини", "reward": "", "icon": md.icon, "was": [String(V9Ults.MODS[k].name)]})
	# secrets
	for id in V7Lines.EGG_NAMES:
		var et: Dictionary = EGG_TEXT.get(id, {"name": V7Lines.EGG_NAMES[id], "why": "Найден секрет", "how": "Ищи внимательнее"})
		var e2: = {"id": "egg.%s" % id, "cat": "egg", "name": et.name, "why": et.why, "how": et.how, "reward": "секрет в коллекцию",
			"icon": "glyph:secret_star", "was": [String(V7Lines.EGG_NAMES[id])]}
		if et.has("sub"):
			e2["sub"] = et.sub
		_add(e2)
	# Path & Salon (0.10 W2)
	for pe in [
		{"id": "path.flame", "cat": "path", "icon": "art:star", "name": "Огонёк пути",
			"why": "Победа зажигает чашку, провал гасит одну: 1–3 чашки дают бустеры даром",
			"how": "Побеждай подряд на обычных столах Пути", "reward": "бустеры на старт"},
		{"id": "path.boosters", "cat": "path", "icon": "art:hint", "name": "Бустеры Пути",
			"why": "Фонарик раскрывает фишки, Ветер уносит 2 пары, Свиток даёт +3 подсказки",
			"how": "Даром от Огонька, из запаса или за 60 кристаллов на карточке уровня"},
		{"id": "path.peak", "cat": "path", "icon": "art:trophy", "name": "Пик главы",
			"why": "Самый трудный стол главы, только честная игра без бустеров",
			"how": "Открывается после босса главы", "reward": "30 кристаллов за первую победу"},
		{"id": "path.legend", "cat": "path", "icon": "art:trophy", "name": "Легенда арки",
			"why": "Последний стол арки. Победа даёт лавр и награду арки",
			"how": "После 5 попыток можно пройти дальше без победы, но лавр — только за победу", "reward": "150 кристаллов и лавр"},
		{"id": "path.chests", "cat": "path", "icon": "art:gift", "name": "Сундуки главы",
			"why": "Сундук главы — за босса, звёздный — за 25 ★ из 30 в главе",
			"how": "Тапни сундук на карте, когда он светится", "reward": "кристаллы, монеты, Лепестки"},
		{"id": "path.jam", "cat": "path", "icon": "glyph:tray_full", "name": "Где лоток начал копиться",
			"why": "После провала видно ход, с которого лоток стал расти",
			"how": "«Показать» подсветит эту фишку на столе на 2 секунды"},
		{"id": "salon.salon", "cat": "salon", "icon": "art:star", "name": "Салон Пяти ветров",
			"why": "Зоны салона, которые ты восстанавливаешь за звёзды Пути",
			"how": "Играй уровни Пути: каждая звезда идёт в банк салона"},
		{"id": "salon.stars", "cat": "salon", "icon": "art:star", "name": "Звёзды Пути",
			"why": "До 3 за каждый уровень Пути; тратятся только в Салоне",
			"how": "Пройди уровень лучше: банк растёт на разницу. Звёзды не продаются"},
		{"id": "salon.finish", "cat": "salon", "icon": "art:star", "name": "Отделка",
			"why": "Как выглядит восстановленная вещь: Лак, Нефрит или Сезонная",
			"how": "Лак — сразу, Нефрит — за полцены вещи в звёздах, Сезонная — в пропуске сезона"},
	]:
		_add(pe)


static func _add(e: Dictionary) -> void:
	for k in ["sub", "reward", "how"]:
		if not e.has(k):
			e[k] = ""
	if not e.has("was"):
		e["was"] = []
	_all[e.id] = e
	_order.append(e.id)
	_by_name[String(e.name).to_lower()] = e.id
	for w in e.was:
		var k2: = String(w).to_lower()
		if not _by_name.has(k2):
			_by_name[k2] = e.id


static func _pts(n: int) -> String:
	return V8PlayRules.points_word(n)


static func _col_word(c: int) -> String:
	return ["розовый", "голубой", "оранжевый", "золотой", "зелёный"][clampi(c, 0, 4)]


# ── public API ────────────────────────────────────────────────────────────────────────────────────────────────

static func has(id: String) -> bool:
	_ensure()
	return _all.has(id)

static func get_entry(id: String) -> Dictionary:
	_ensure()
	return _all.get(id, {})

static func label(id: String) -> String:
	return String(get_entry(id).get("name", ""))

static func why(id: String) -> String:
	return String(get_entry(id).get("why", ""))

static func how(id: String) -> String:
	return String(get_entry(id).get("how", ""))

static func all_ids() -> Array:
	_ensure()
	return _order.duplicate()

static func entries(cat: String) -> Array:
	_ensure()
	var out: = []
	for id in _order:
		if _all[id].cat == cat:
			out.append(_all[id])
	return out

static func cat_title(cat: String) -> String:
	for c in CATS:
		if c[0] == cat:
			return c[1]
	return cat

static func find_by_name(text: String) -> Dictionary:
	_ensure()
	var id: String = _by_name.get(text.strip_edges().to_lower(), "")
	return _all.get(id, {})

# G.YAKU key or "set:N" → glossary id
static func bonus_id(yaku: String) -> String:
	if yaku.begins_with("set:"):
		return "set.%s" % yaku.substr(4)
	return "bonus.%s" % yaku

static func bonus_points(yaku: String) -> int:
	if yaku.begins_with("set:"):
		return int(G.YAKU.set.rp)
	return int(G.YAKU.get(yaku, {}).get("rp", 0))

static func suit_of(face: int) -> int:
	if face < 0 or face >= 36:
		return -1
	return G.face_cat(face)

static func face_index(face: int) -> int:
	var c: = suit_of(face)
	if c < 0:
		return 0
	return face - int(G.CATS[c][0]) + 1

static func suit_color(c: int) -> Color:
	return SUIT_LOOK[clampi(c, 0, SUIT_LOOK.size() - 1)].col

static func suit_glyph(c: int) -> String:
	return SUIT_LOOK[clampi(c, 0, SUIT_LOOK.size() - 1)].glyph

static func star_rule() -> String:
	return "1★ победа · 2★ до 2 подсказок · 3★ без помощи"

static func stats_line(secs: float, helps: int, overflows: int) -> String:
	var s: = int(secs)
	return "Время %d:%02d · Подсказок %d · Лоток переполнялся %d" % [s / 60, s % 60, helps, overflows]

# one short line for the tutorial lane's tips: «Без подсказок — ни одной подсказки, …»
static func tip(id: String) -> String:
	var e: = get_entry(id)
	if e.is_empty():
		return ""
	return "%s — %s" % [e.name, String(e.why).left(1).to_lower() + String(e.why).substr(1)]

# the fortune plaque / chip on the table: the EFFECT first («Первые 3 пары ×3»), never the poetic name alone
static func fortune_title(f: Dictionary) -> String:
	var id: = "fortune.%s" % String(f.get("id", ""))
	return label(id) if has(id) else String(f.get("name", ""))

static func fortune_chip(f: Dictionary) -> String:
	return "Гадание: %s" % fortune_title(f)

# the heroine's table perk (V7Passives), said by what it does: «Свойство: лоток на 5 мест»
const PASSIVE_SHORT: = {"mc": "лоток на 5 мест", "rin": "фишку из лотка можно вернуть", "hana": "в комбо пара зовёт себя сама",
	"yue": "видит пары сквозь стол", "nova": "открывает фишку под завалом"}

static func passive_note(hero: String, fallback: String) -> String:
	return "Свойство: %s" % String(PASSIVE_SHORT.get(hero, fallback))

# why a tile on the board cannot be taken right now («» when it can): exact, never «прижимают сверху» for a side lock
static func blocked_reason(board, t) -> String:
	if board == null or t == null:
		return ""
	if board.has_method("takeable") and board.is_free(t) and not board.takeable(t):
		var s = board.spec.get(t, {})
		if String(s.get("kind", "")) == "lock":
			return "Под замком: собери пару с ключом того же цвета"
		if String(s.get("kind", "")) == "chain":
			return "В цепи: сними ещё %d %s" % [int(s.get("n", 0)), V8PlayRules.plural(int(s.get("n", 0)), "пару", "пары", "пар")]
	if board.is_free(t):
		return ""
	for o in board.cov.get(t, []):
		if board.on_board(o):
			return "Сверху лежит другая фишка — сними её сначала"
	return "Зажата слева и справа — освободи один бок"
