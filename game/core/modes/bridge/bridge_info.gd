class_name V10MjBridgeInfo
extends RefCounted

# Мост к столу — две карточки для хаба «Столы» (docs/MODES.md §4.5, §6, §7.1). Хаб читает их через load() с
# проверкой ResourceLoader.exists:
#   INFO       — «Задача дня»: строка «Сегодня» хаба (shelf "today"), хозяйка Маджонг-тян, открытие после L22;
#   INFO_HAND  — «Собери руку»: полка «За столом» (shelf "table"), хозяйка Хана, открытие после L26.
#   CARDS      — обе карточки по порядку (хаб, который знает про несколько карточек модуля, берёт этот список).
# pt — типичная длина в минутах; screen — экран партии (setup(main, args) + сигнал finished(result));
# icon — иконка карточки кодом (V10MjBridgeIcon.mode_icon) и готовый PNG в assets/v10/mj/bridge/.

const HOW_DAILY: = [
	["tap", "Выбери фишку в руке"],
	["drop", "Сбрось её — рука станет ближе к готовой"],
	["wait", "Чем больше фишек ждут, тем лучше"],
]
const HOW_HAND: = [
	["tap", "Тапни свободную фишку — она уйдёт в руку"],
	["set", "Тройка или ряд складываются сами"],
	["full", "Цель — 4 набора и пара за 14 мест"],
]
const HOW: = HOW_DAILY

const INFO: = {
	"id": "bridge_daily",
	"name": "Задача дня",
	"title": "Задача дня",
	"shelf": "trials",
	"today_row": true,
	"line": "Какую фишку сбросить?",
	"host": "mc",
	"gate": {"level": 22},
	"pt": 1,
	"screen": "res://scripts/v10/mj/bridge/bridge_daily_screen.gd",
	"pt_scene": "res://scripts/v10/mj/bridge/bridge_demo.tscn",
	"save": "v10_mj_bridge",
	"selftest": "res://scripts/v10/mj/bridge/bridge_selftest.tscn",
	"icon": "res://assets/v10/mj/bridge/icon_daily.png",
	"music": "mode_riichi",
	"HOW": HOW_DAILY,
}

const INFO_HAND: = {
	"id": "bridge_hand",
	"name": "Собери руку",
	"title": "Собери руку",
	"shelf": "table",
	"line": "Четыре набора и пара",
	"host": "hana",
	"gate": {"level": 26},
	"pt": 4,
	"screen": "res://scripts/v10/mj/bridge/bridge_hand_screen.gd",
	"pt_scene": "res://scripts/v10/mj/bridge/bridge_demo.tscn",
	"save": "v10_mj_bridge",
	"selftest": "res://scripts/v10/mj/bridge/bridge_selftest.tscn",
	"icon": "res://assets/v10/mj/bridge/icon_hand.png",
	"music": "mode_riichi",
	"levels": 60,
	"HOW": HOW_HAND,
}

const CARDS: = [INFO, INFO_HAND]

# звёзды «Собери руку» (по строке, «Подробнее»)
const STARS_HOW: = [
	"★ — рука собрана",
	"★★ — без Приёма",
	"★★★ — и комбинация дороже цели",
]

# статьи Словаря для комбинаций (заглушка V10Glossary: если в нём нет статьи — экран показывает эту).
# Поля как у V10Glossary: name ≤ 26, sub (оригинал мелко) ≤ 30, why ≤ 74, how ≤ 92.
const GLOSSARY: = {
	"tanyao": {"name": "Все простые", "sub": "таняо", "why": "Все фишки от 2 до 8, без единиц, девяток и знаков",
		"how": "Не бери единицы, девятки, ветры и драконов"},
	"sanankou": {"name": "Три тройки", "sub": "сананко", "why": "В руке три тройки одинаковых фишек",
		"how": "Собирай одинаковые: три тройки и любой четвёртый набор"},
	"ittsu": {"name": "Чистый ряд 1–9", "sub": "иццу", "why": "Ряды 1-2-3, 4-5-6 и 7-8-9 одной масти",
		"how": "Собери три ряда подряд одной масти"},
	"chinitsu": {"name": "Одна масть", "sub": "чинъицу", "why": "Вся рука одной масти, без ветров и драконов",
		"how": "Бери фишки только одной масти"},
	"bridge.daily": {"name": "Задача дня", "sub": "", "why": "Одна рука в день: какую фишку сбросить",
		"how": "Новая задача каждый день; три решённые открывают Стол на четверых"},
	"bridge.hand": {"name": "Собери руку", "sub": "", "why": "Четыре набора и пара из фишек пирамиды",
		"how": "60 уровней; с 20-го нужна комбинация не дешевле ×2"},
}


static func glossary(id: String) -> Dictionary:
	var gid: = "combo.%s" % id
	if ClassDB.class_exists("V10Glossary") or ResourceLoader.exists("res://scripts/v10/clarity/glossary.gd"):
		var g = load("res://scripts/v10/clarity/glossary.gd")
		if g != null and g.has(gid):
			return g.get_entry(gid)
	return GLOSSARY.get(id, {})
