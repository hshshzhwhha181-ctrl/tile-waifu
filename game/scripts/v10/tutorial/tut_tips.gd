class_name V10TutTips
extends RefCounted

# V10TutTips — first-time tips for every feature + the «Как играть» encyclopedia, as data.
# A tip shows the first time its screen opens (or its event fires), at most ONE tip per screen visit,
# never while a guided step is on screen. 1–3 short warm lines from Маджонг-тян + a soft spotlight.
#
# Topic keys:
#   id, title, icon (assets/v10/tutorial/<icon>.webp), cat (encyclopedia section)
#   screens     screen ids that trigger it (main.screen_id; aliases cover names other lanes may pick)
#   events      event names that trigger it (V10Tutorial.event(main, name))
#   need_target true: show only when the target resolves (a feature that is not on screen yet stays quiet)
#   tip         1–3 short lines for the first-time tip ("" = encyclopedia only; taught by the guided flow)
#   target      spotlight (V10TutTarget spec; [] = bubble only)
#   emo         portrait
#   help        the encyclopedia text (2–4 short sentences)
#   replay      guided chapter replayed by «Показать в игре» (optional)
#   speaker     "guide" = a neutral «Подсказка» card without her portrait. Used for the shop: by the 0.10 contract
#               (spec §1.2) a heroine never talks about purchases.
#   min_level   (optional) only after S.unlocked ≥ N, so a tip never shows for something still locked

const CATS: = [["play", "Партия"], ["home", "Чайная"], ["wish", "Желания"], ["modes", "Режимы"], ["more", "Ещё"]]

const TOPICS: = [
	# ── партия ──
	{"id": "basics", "title": "Свободные фишки", "icon": "basics", "cat": "play", "screens": [], "tip": "",
		"replay": "match1",
		"help": "Фишка свободна, если на ней ничего не лежит и хотя бы один её бок открыт. Свободные светлые, заблокированные затенены. Тапни свободную — она уедет в лоток."},
	{"id": "tray", "title": "Лоток и пары", "icon": "tray", "cat": "play", "screens": [], "tip": "",
		"replay": "match1",
		"help": "Две одинаковые фишки в лотке исчезают парой. Лоток маленький: если он заполнится, партия проиграна. Бери парами и не набирай лишнего."},
	{"id": "combo", "title": "Комбо и ульта", "icon": "combo", "cat": "play", "screens": [], "events": ["ult_ready"], "tip": "",
		"replay": "ult1",
		"help": "Пары подряд без пауз — это комбо, оно копит шкалу ульты. Когда героиня засияла, тапни её портрет: она сама снимет пару. Приём ульты зависит от наряда."},
	{"id": "helpers", "title": "Подсказка, отмена, перемешать", "icon": "helpers", "cat": "play", "screens": [], "tip": "",
		"replay": "match1",
		"help": "Подсказка показывает хороший ход. Отмена возвращает последнюю фишку из лотка. Перемешать раскладывает стол заново. На партию их немного — дальше за кристаллы."},
	{"id": "victory", "title": "Звёзды и награды", "icon": "victory", "cat": "play", "screens": [], "tip": "",
		"replay": "victory1",
		"help": "Три звезды — за партию без ошибок и без помощи. Звёзды Пути копятся и открывают сундуки и зоны Салона. «Ещё уровень» сразу сажает за следующий стол."},
	{"id": "path", "title": "Путь и Пики", "icon": "path", "cat": "play", "screens": ["path", "v10path", "levels"],
		"tip": "Это Путь — тысяча столов, глава за главой.\nКаменные Пики сбоку — самые трудные, и там ничего не продаётся.",
		"target": [{"meta": "path.peak"}, {"meta": "path.current"}, {"rect": [0.05, 0.2, 0.9, 0.6]}],
		"help": "Путь ведёт через главы по десять уровней: обычные, «Сложный», «Очень сложный» и босс. Сложность видна до входа. После босса главы открывается Пик — испытание без продажи бустеров, за лавровую рамку."},
	{"id": "tile_themes", "title": "Темы фишек и столы", "icon": "tile_themes", "cat": "play", "screens": ["themes", "v10themes", "tile_themes"], "events": ["tile_themes"],
		"tip": "Темы меняют рубашки фишек и стол.\nНа игру не влияют — только на настроение.",
		"target": [{"meta": "themes.list"}, {"rect": [0.05, 0.2, 0.9, 0.6]}],
		"help": "Тема фишек — это рубашки, лицевая роспись и стол под ними. Темы приходят из нарядов SSR, событий и Пагоды. Силы в партии они не дают."},
	# ── чайная ──
	{"id": "home", "title": "Чайная", "icon": "home", "cat": "home", "screens": [], "tip": "",
		"replay": "home1",
		"help": "Чайная — твой дом. Слева поручения, визиты, письма и рейтинг, справа события и баннер. Тапни героиню, чтобы поболтать: симпатия растёт и открывает наряды и сцены."},
	{"id": "salon", "title": "Салон Пяти ветров", "icon": "salon", "cat": "home", "screens": ["salon", "v10salon"],
		"tip": "Это мой салон, только в пыли…\nЗвёзды Пути восстанавливают его по кусочку. Начнём с вывески?",
		"target": [{"meta": "salon.task"}, {"meta": "salon.bank"}, {"rect": [0.05, 0.25, 0.9, 0.5]}], "emo": "shy",
		"help": "Звёзды, заработанные на Пути, тратятся на задачи реставрации: вывеска, фонари, ширмы. Закрытая зона открывает сцену героини и сундук. Отделку можно сменить бесплатно."},
	{"id": "phone", "title": "Телефон: почта, чаты, лента", "icon": "phone", "cat": "home", "screens": ["phone", "v10phone", "letters", "chats", "feed"],
		"tip": "Мой телефон! Тут письма, чаты и лента девушек.\nОтвечай, когда удобно — никто не обидится.",
		"target": [{"meta": "phone.tabs"}, {"rect": [0.04, 0.16, 0.92, 0.12]}],
		"help": "В Почте приходят письма героинь, в Чатах можно переписываться с ними, в Ленте — их фото и новости. Ответы и лайки немного поднимают симпатию. Ничего не сгорает."},
	{"id": "rituals", "title": "Ритуалы: серия, поднос, «Она ждала»", "icon": "rituals", "cat": "home", "screens": ["home"], "events": ["streak", "tray", "comeback"],
		"need_target": true,
		"tip": "Пиала — серия чая: выигрывай хоть партию в день.\nПропустил день? Чайный лист его простит.",
		"target": [{"meta": "rituals.streak"}, {"meta": "rituals.tray"}],
		"help": "Серия чая растёт за победу в день; пропуск закрывает Чайный лист. Утренний поднос — маленький подарок к первому входу дня. Если тебя долго не было, «Она ждала» встретит тёплой лестницей подарков."},
	{"id": "room", "title": "Комната героини", "icon": "room", "cat": "home", "screens": ["room"],
		"tip": "Это моя комната. Касания отвечают по-разному —\nпопробуй волосы, руки, улыбку.",
		"target": [{"meta": "room.hero"}, {"rect": [0.2, 0.18, 0.6, 0.55]}], "emo": "shy",
		"help": "В комнате можно поговорить с героиней и подарить подарок. Касания дают немного симпатии (до трёх в день). Растущая симпатия открывает наряды, письма и сцены."},
	{"id": "profile", "title": "Профиль и карточка игрока", "icon": "profile", "cat": "home", "screens": ["profile"],
		"tip": "Твоя карточка: ник, аватар, рамка и ранг.\nЕё видят соперницы в лигах и дуэлях.",
		"target": [{"meta": "profile.card"}, {"rect": [0.05, 0.16, 0.9, 0.32]}],
		"help": "В профиле меняют ник, аватар, рамку и титул. Ранг растёт от побед на Пути и в режимах. Карточку видят другие игроки в лигах и вызовах."},
	{"id": "wardrobe", "title": "Гардероб и наряды", "icon": "wardrobe", "cat": "home", "screens": ["collection"], "tip": "",
		"replay": "wardrobe1",
		"help": "В Гардеробе выбирают напарницу и наряд. Ранг наряда A, S или SSR — это редкость и косметика, а не сила в рейтинге. Каждый наряд меняет приём ульты."},
	# ── желания ──
	{"id": "gacha", "title": "Желания, шансы и Свеча", "icon": "gacha", "cat": "wish", "screens": ["summon"], "min_level": 4,
		"tip": "Каждое желание зажигает свечу. 200 свечей — Свеча желаний:\nвыбираешь наряд сама. Шансы — кнопка рядом.",
		"target": [{"meta": "gacha.candle"}, {"meta": "gacha.rates"}, {"text": "Шансы"}, {"prop": "pity_lbl"}],
		"help": "Желание приносит наряд A, S или SSR. Шансы всегда открыты на экране «Шансы и правила». Свечи копятся с каждого желания и не сгорают: за 200 — Свеча желаний с выбором. Первую SSR ты выбираешь сам из списка."},
	{"id": "shop", "title": "Лавка", "icon": "shop", "cat": "wish", "screens": ["shop"], "speaker": "guide",
		"tip": "Лавка: наборы, абонемент и пропуск сезона.\nЦены всегда в рублях, лимит трат можно задать.",
		"target": [{"meta": "shop.tabs"}, {"rect": [0.04, 0.16, 0.92, 0.12]}],
		"help": "В Лавке наборы, Лунный абонемент и пропуск сезона. Цена всегда в рублях и с пересчётом «≈ за желание». Можно задать лимит трат в месяц. Без покупок игра проходится целиком."},
	# ── режимы ──
	{"id": "modes", "title": "Режимы", "icon": "modes", "cat": "modes", "screens": ["modes"],
		"tip": "Здесь другие столы: на время, без спешки и необычные.\nНовые режимы открываются по мере игры.",
		"target": [{"meta": "modes.list"}, {"rect": [0.04, 0.2, 0.92, 0.6]}],
		"help": "Режимы — партии с другими правилами: на время, дзен без проигрыша, турнир, дуэли и забеги. Замок на карточке подсказывает, когда режим откроется."},
	{"id": "pagoda", "title": "Пагода Луны", "icon": "pagoda", "cat": "modes", "screens": ["pagoda", "v10pagoda"],
		"tip": "Пагода — подъём по этажам с фонарями.\nПроклятия добавляют Жар и множат очки. Рискнёшь?",
		"target": [{"meta": "pagoda.heat"}, {"meta": "pagoda.climb"}, {"rect": [0.05, 0.2, 0.9, 0.6]}],
		"help": "Поднимайся с этажа на этаж: у тебя 3 фонаря, переполненный лоток гасит один. Каждый 5-й этаж — Страж с сундуком. Проклятия поднимают Жар и множитель очков. Выход между этажами сохраняет забег."},
	{"id": "journey", "title": "Странствие", "icon": "journey", "cat": "modes", "screens": ["journey", "v10journey"],
		"tip": "Странствие — пять столов за неделю, в конце богиня-босс.\nДве зачётные попытки, честный зачёт без силы нарядов.",
		"target": [{"meta": "journey.map"}, {"rect": [0.05, 0.2, 0.9, 0.6]}],
		"help": "Недельный забег из 4 столов и босса. После стола выбери благословение, можно взять проклятие ради очков. У тебя 3 сердца. Награда — за лучшую попытку недели."},
	{"id": "palm", "title": "Чтение руки", "icon": "palm", "cat": "modes", "screens": ["hand", "palm", "v10hand"],
		"tip": "Угадай, какой фишки ждёт её рука.\nЧем раньше догадка, тем больше множитель.",
		"target": [{"meta": "hand.hud"}, {"meta": "hand.guess"}, {"rect": [0.04, 0.12, 0.92, 0.16]}],
		"help": "Снятая пара переворачивает такие же фишки в руке богини дня. Нажми «Догадка», когда поймёшь, чего она ждёт: верный ответ раньше — множитель ×2 или ×3. Первую неделю работает «Школа» с подсветкой."},
	{"id": "duels", "title": "Дуэли", "icon": "duels", "cat": "modes", "screens": ["duels", "duel", "v10duel"],
		"tip": "Дуэль — гонка за одним столом против героини-ИИ.\nРейтинговые меняют ранг, дружеские — просто для души.",
		"target": [{"meta": "duel.offers"}, {"rect": [0.05, 0.2, 0.9, 0.6]}],
		"help": "В рейтинговой дуэли выбираешь соперницу из трёх, ставка — твой рейтинг. Выход из партии засчитывается поражением. Дружеские дуэли дают симпатию и кристаллы, а дуэль недели — особое правило."},
	{"id": "leagues", "title": "Лиги и ранги", "icon": "leagues", "cat": "modes", "screens": ["v7tourney", "league", "rank"],
		"tip": "Лига недели: играй партии — очки ранга двигают тебя вверх.\nВ конце недели лучшие поднимаются в лигу выше.",
		"target": [{"meta": "league.table"}, {"rect": [0.04, 0.2, 0.92, 0.6]}],
		"help": "Очки ранга идут за победы на Пути и в режимах. Каждую неделю группа соревнуется в лиге: верх поднимается, низ опускается. Ранг виден в профиле и на карточке."},
	{"id": "events", "title": "Ивенты и турнир", "icon": "events", "cat": "modes", "screens": ["v7event", "event"],
		"tip": "Ивент на несколько дней: свои столы, награды и турнир.\nДаты всегда видны — без спешки.",
		"target": [{"meta": "event.track"}, {"rect": [0.04, 0.2, 0.92, 0.5]}],
		"help": "Ивенты идут по календарю для всех одинаково. Партии ивента копят очки трека наград, а турнир сравнивает лучший счёт. Конец ивента подписан датой и временем по Москве."},
	# ── ещё ──
	{"id": "settings", "title": "Настройки эффектов", "icon": "settings", "cat": "more", "screens": [], "events": ["settings"],
		"tip": "«Эффекты» убавляют вспышки и тряску,\nа «Вставки ульт» — длину сцен. Как тебе удобнее.",
		"target": [{"text": "Эффекты"}, {"rect": [0.05, 0.2, 0.9, 0.2]}],
		"help": "«Эффекты: полные» — вспышки, тряска и частицы; «умеренные» — без тряски; «минимум» — только отклик кнопок. «Вставки ульт» решают, как долго идёт сцена ульты. Здесь же звук, музыка, голос и вибрация."},
]


static func topic(id: String) -> Dictionary:
	for t in TOPICS:
		if t.id == id:
			return t
	return {}


static func for_screen(screen_id: String) -> Array:
	var out: = []
	for t in TOPICS:
		if String(t.get("tip", "")) != "" and screen_id in t.get("screens", []):
			out.append(t)
	return out


static func for_event(ev: String) -> Array:
	var out: = []
	for t in TOPICS:
		if String(t.get("tip", "")) != "" and ev in t.get("events", []):
			out.append(t)
	return out


static func icon_path(t: Dictionary) -> String:
	return "res://assets/v10/tutorial/%s.webp" % String(t.get("icon", t.id))
