class_name V10MjSanmaInfo
extends RefCounted

# Карточка режима для хаба «Столы» (MODES.md §6, контракт §7.1). Хаб читает через load() + ResourceLoader.exists.
const INFO: = {
	"id": "sanma",
	"name": "Лунный стол на троих",
	"shelf": "table",
	"line": "Втроём, дороже и быстрее",
	"host": "yue",
	"gate": {"table_games": 3},
	"pt": "sanma",
	"screen": "res://scripts/v10/mj/sanma/sanma_screen.gd",
	"music": "res://assets/v10/mj/sanma/music/moon_table.ogg",
	"cloth": "res://assets/v10/mj/sanma/cloth/moon_cloth.webp",
	"event": {"id": "landlord", "name": "Хозяйка против двоих", "line": "Её множитель против двоих", "period": "month"},
	"teaser": "Откроется: после 3 партий за столом",
}

# Открыт ли режим (gate по счётчику партий за «Столом на четверых»; берётся из сейва интегратора).
static func unlocked(table_games: int) -> bool:
	return table_games >= int(INFO.gate.table_games)
