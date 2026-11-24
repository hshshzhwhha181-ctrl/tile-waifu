class_name V10MjTriplesInfo
extends RefCounted

# Тройки — карточка режима для хаба «Столы» (docs/MODES.md §4.2, §6.2, §7.1). Хаб читает INFO через load() с
# проверкой ResourceLoader.exists и не знает ничего больше о режиме.
#   pt     — сцена плейтеста/демо (снимки старт · 6/7 · победа)
#   screen — экран партии (setup(main, args) + сигнал finished(result))
#   music  — ключ петли режима (MODES §6.5: пипа, щелчки, бас, 104 bpm); петлю делает дорожка look

const INFO: = {
	"id": "triples",
	"name": "Тройки",
	"shelf": "solitaire",
	"line": "Собирай по три в лотке",
	"host": "hana",
	"gate": {"level": 14},
	"pt": "res://scripts/v10/mj/triples/triples_demo.tscn",
	"screen": "res://scripts/v10/mj/triples/triples_screen.gd",
	"music": "mode_triples",
	"levels": 120,
}

# «Как играть»: три строки с иконками (UX_RULES §4.1 п.9)
const HOW: = [
	["tap", "Тапни свободную фишку — она уйдёт в лоток"],
	["three", "Три одинаковые в лотке исчезают"],
	["full", "Лоток заполнен на 7 из 7 — партия проиграна"],
]

# звёзды за уровень (одна строка на каждую, показывается в «Подробнее»)
const STARS_HOW: = [
	"★ — стол чист",
	"★★ — без помощи",
	"★★★ — без помощи и лоток ни разу не дошёл до 6",
]
