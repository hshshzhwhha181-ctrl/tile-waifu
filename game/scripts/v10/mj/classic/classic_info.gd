extends RefCounted

# Mode card for the «Столы» hub (MODES §6.2, contract §7.1). The hub reads it with load() after
# ResourceLoader.exists(). pt = the screen to open (the mode screen: form shelf, variant segment, «Играть»).

const INFO: = {
	"id": "classic",
	"name": "Классика",
	"shelf": "solitaire",
	"line": "Сними пары с объёмной формы",
	"host": "mc",
	"gate": {"level": 9},
	"pt": "res://scripts/v10/mj/classic/classic_lobby.gd",
	"match": "res://scripts/v10/mj/classic/classic_screen.gd",
	"memory": "res://scripts/v10/mj/classic/memory.gd",
	"icon": "res://assets/v10/mj/classic/mode_icon.png",
	"variants": ["free", "daily", "memory"],
	"save": "v10_mj_classic",
	"selftest": "res://scripts/v10/mj/classic/classic_selftest.tscn",
	"music": {"instruments": "гучжэн, мягкий пэд", "bpm": 72},
}

# «Как играть» — 3 lines with icons (UX §4.1.9)
const HOW: = [
	["hint", "Тапни свободную фишку, потом такую же — пара уходит."],
	["view3d", "Свободна фишка без соседа сверху и хотя бы с одним открытым краем."],
	["shuffle", "Цветок парится с любым цветком, сезон — с любым сезоном."],
]
