class_name V10MjKoikoiInfo
extends RefCounted

# Инфо режима для хаба «Столы» (MODES §6, контракт §7.1). Хаб читает через load() + ResourceLoader.exists.
const INFO: = {
	"id": "koikoi",
	"name": "Коикои",
	"shelf": "table",
	"line": "Карты месяцев, рискни ещё раз",
	"host": "rin",
	"gate": {"level": 45},
	"pt": "Сыграй карту — забери пару по месяцу",
	"scene": "res://scripts/v10/mj/koikoi/koikoi_screen.gd",
	"music": "res://assets/v10/mj/koikoi/audio/koikoi_loop.ogg",
	"variants": [{"id": "short", "name": "6 месяцев", "months": 6}, {"id": "full", "name": "12 месяцев", "months": 12}],
	"rivals": ["rin", "hana", "yue", "nova", "mc"],
}

# «Как играть»: ровно 3 строки (UX §4.1 п. 9).
const HOW: = [
	"Сыграй карту: совпал месяц — пара твоя.",
	"Собери комбинацию из взяток.",
	"Забери очки или рискни: «Кои-кои!» удваивает.",
]

static func unlocked(level: int) -> bool:
	return level >= int(INFO.gate.level)
