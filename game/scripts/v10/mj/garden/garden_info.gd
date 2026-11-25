class_name V10MjGardenInfo
extends RefCounted

# Сад 2.0 — карточка режима для хаба «Столы» (docs/MODES.md §4.9, §6.2, §6.4, §7.1). Хаб читает INFO через load()
# с проверкой ResourceLoader.exists и больше ничего о режиме не знает.
#   gate    — ранг Нефрит I, как у старого Сада (V6ModesData.GATES.zen = [1, 0]); открытие считает интегратор
#   pt      — демо-сцена (снимки день · ночь · перелив · волна · рекорд · итог)
#   screen  — экран партии (setup(main, args) + сигнал finished(result))
#   card    — карточка полки с тумблером «Ночной стол» (V10MjGardenCard)
#   icon    — иконка режима (символ: чашка, три фишки, луна; нарисована кодом, V10MjGardenIcon)
#   replaces — старый режим, который Сад 2.0 заменяет в хабе и Афише (play.gd mode "zen")

const INFO: = {
	"id": "garden",
	"name": "Сад",
	"shelf": "solitaire",
	"line": "Снимай пары волна за волной",
	"host": "yue",
	"gate": {"rank": [1, 0], "title": "Нефрит I"},
	"pt": "res://scripts/v10/mj/garden/garden_demo.tscn",
	"screen": "res://scripts/v10/mj/garden/garden_screen.gd",
	"card": "res://scripts/v10/mj/garden/garden_card.gd",
	"icon": "res://assets/v10/mj/garden/mode_icon.png",
	"save": "v10_mj_garden",
	"selftest": "res://scripts/v10/mj/garden/garden_selftest.tscn",
	"music": {"instruments": "дождь, колокольчики", "bpm": 0, "rhythm": false},
	"replaces": "zen",
}

# «Как играть»: три строки с иконками (UX_RULES §4.1 п.9)
# (слово «лоток» — как во всей игре, UX §4.1 п.1; «чашка переливается» из MODES — только картинка перелива)
const HOW: = [
	["tap", "Тапни свободную фишку — она уйдёт в лоток"],
	["pair", "Две одинаковые в лотке — пара снята"],
	["spill", "Лоток полон — три фишки вернутся на стол"],
]

# строка «Подробнее» (тихо, в паузе)
const MORE: = [
	"Когда на столе остаётся 6 фишек, приходит новая волна.",
	"Пары подряд растят множитель до ×5.",
	"Проигрыша и таймера нет — выйти можно в любой момент.",
]


# открыт ли режим: ранг игрока не ниже Нефрит I (или старый Сад уже играли — как V6ModesData.mode_open)
static func is_open(rp: int, played_zen: = false) -> bool:
	if played_zen:
		return true
	var g: Array = INFO.gate.rank
	return G.rank_index(rp) >= int(g[0]) * 3 + int(g[1])


static func lock_text() -> String:
	return "Откроется на ранге %s" % String(INFO.gate.title)
