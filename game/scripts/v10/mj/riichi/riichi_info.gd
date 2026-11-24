class_name V10MjRiichiInfo
extends RefCounted

# Mode card for the «Столы» hub (MODES §7.1). The hub reads it with load() after ResourceLoader.exists().
# pt — typical length of one «Восток» match in minutes (shown as «≈ 12 мин» on the mode screen).

const INFO: = {
	"id": "riichi",
	"name": "Стол на четверых",
	"shelf": "table",
	"line": "Японский маджонг против трёх героинь",
	"host": "mc",
	"gate": {"level": 34, "daily_tasks": 3},
	"pt": 12,
	"screen": "res://scripts/v10/mj/riichi/riichi_screen.gd",
	"formats": ["east", "east_south", "one_hand"],
}
