class_name V10MjConnectInfo
extends RefCounted

# Связи (Шисэн-сё) — карточка режима для хаба «Столы» (docs/MODES.md §4.3, §6.2, §6.4, §6.5, §7.1).
# Хаб читает INFO через load() с проверкой ResourceLoader.exists.

const HOW: = [
	["tap", "Тапни две одинаковые свободные фишки"],
	["thread", "Нить соединяет пару не больше чем с двумя поворотами"],
	["shuffle", "Ходов нет — поле перемешается само"],
]

const STARS_HOW: = [
	"★ — стол чист",
	"★★ — без перемешиваний",
	"★★★ — без перемешиваний и вовремя",
]

const VARIANT_NAMES: = {
	"static": "Поле",
	"rain": "Ливень",
	"shift": "Сдвиг",
	"timed": "На время",
}

const INFO: = {
	"id": "connect",
	"name": "Связи",
	"title": "Связи",
	"shelf": "solitaire",
	"line": "Сними пары по линии",
	"host": "rin",
	"gate": {"level": 18},
	"pt": "res://scripts/v10/mj/connect/connect_demo.tscn",
	"screen": "res://scripts/v10/mj/connect/connect_screen.gd",
	"save": "v10_mj_connect",
	"selftest": "res://scripts/v10/mj/connect/connect_selftest.tscn",
	"music": "connect",
	"music_note": {"instruments": "эрху, струнные пиццикато", "bpm": 88},
	"levels": 90,
	"HOW": HOW,
}
