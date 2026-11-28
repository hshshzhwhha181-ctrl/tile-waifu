class_name V10MjClassicInfo
extends RefCounted

# «Классика» — карточка режима для хаба «Столы» (docs/MODES.md §4.1, §6.2, §7.1). Хаб читает INFO через load() с
# проверкой ResourceLoader.exists и ничего больше о режиме не знает.
#   pt      — экран режима (полка форм, переключатель «Свободная · Раскладка дня · Память», «Играть»)
#   screen  — экран партии Классики; memory — экран Памяти (оба: setup(main, args) + сигнал finished(result))
#   music   — ключ петли V10MjMusic (MODES §6.5: гучжэн, мягкий пэд, 72 bpm)

const HOW: = [
	["tap", "Тапни свободную фишку, потом такую же — пара уходит."],
	["view3d", "Свободна фишка, на которой ничего нет и у которой открыт левый или правый край."],
	["flower", "Цветок парится с любым цветком, сезон — с любым сезоном."],
]

const HOW_MEMORY: = [
	["tap", "Открывай по две закрытые фишки."],
	["flower", "Одинаковые фишки уходят со стола."],
	["star", "Ошибки бесплатны — звёзды за число ходов."],
]

const INFO: = {
	"id": "classic",
	"name": "Классика",
	"title": "Классика",
	"shelf": "solitaire",
	"line": "Сними пары с объёмной формы",
	"host": "mc",
	"gate": {"level": 9},
	"pt": "res://scripts/v10/mj/classic/classic_lobby.gd",
	"screen": "res://scripts/v10/mj/classic/classic_screen.gd",
	"match": "res://scripts/v10/mj/classic/classic_screen.gd",
	"memory": "res://scripts/v10/mj/classic/memory.gd",
	"demo": "res://scripts/v10/mj/classic/classic_demo.tscn",
	"icon": "res://assets/v10/mj/classic/mode_icon.png",
	"variants": ["free", "daily", "memory"],
	"save": "v10_mj_classic",
	"selftest": "res://scripts/v10/mj/classic/classic_selftest.tscn",
	"music": "classic",
	"music_note": {"instruments": "гучжэн, мягкий пэд", "bpm": 72},
	"forms": 22,
	"HOW": HOW,
}

# звёзды за форму (строка в «Подробнее» и на итоге)
const STARS_HOW: = [
	"★ — стол чист",
	"★★ — без перемешиваний",
	"★★★ — чистая игра: без подсказок и перемешиваний",
]

# варианты для переключателя на экране режима (один контрол)
const VARIANTS: = [["free", "Свободная"], ["daily", "Раскладка дня"], ["memory", "Память"]]
