class_name V10MjCubeInfo
extends RefCounted

# Куб — карточка режима для хаба «Столы» (docs/MODES.md §4.4, §6.2, §6.4, §6.5, §7.1). Хаб читает INFO через load()
# с проверкой ResourceLoader.exists и больше ничего о режиме не знает.
#   pt     — сцена демо и снимков
#   screen — экран партии (setup(main, args) + сигнал finished(result))
#   music  — ключ петли режима для V10MjMusic.play (дорожка look: синт-пэд, кото, гранулы, 80 уд/мин)
#   icon   — знак режима на полке (предмет, без героини): кубик 3×3 с сердцевиной её цвета

const INFO: = {
	"id": "cube",
	"name": "Куб",
	"shelf": "solitaire",
	"line": "Вращай куб и снимай пары",
	"host": "nova",
	"gate": {"level": 40},
	"pt": "res://scripts/v10/mj/cube/cube_demo.tscn",
	"screen": "res://scripts/v10/mj/cube/cube_screen.gd",
	"music": "cube",
	"music_desc": {"instruments": ["синт-пэд", "кото", "гранулы"], "bpm": 80},
	"icon": "res://assets/v10/mj/cube/cube_icon.png",
	"levels": 40,
}

# «Как играть»: три строки с иконками (UX_RULES §4.1 п.9)
const HOW: = [
	["rotate", "Веди пальцем по пустому месту — куб повернётся"],
	["pair", "Тапни две одинаковые свободные фишки"],
	["relic", "Внутри спрятана реликвия героини"],
]

# «Подробнее»: правило свободы одной фразой и звёзды
const RULE: = "Фишка свободна, если открыта грань, которую ты видишь, и хотя бы одна соседняя с ней"
const STARS_HOW: = [
	"★ — фигура разобрана",
	"★★ — уложилась в ходы на вторую звезду",
	"★★★ — почти без лишних ходов",
]
