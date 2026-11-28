class_name V10AdventureReg
extends RefCounted

# V10AdventureReg — registers the standalone Monster Battle RPG mode ("adventure")
# into V10Registry so main.go("adventure") and --screen=adventure work cleanly
# without touching play.gd, nav.gd, tables_hub.gd, or button.gd.


static func register() -> void:
	V10Registry.module("adventure", {
		"step": 4,
		"selftest": {
			"scene": "res://scripts/v10/adventure/adventure_selftest.tscn",
			"args": ["--adventure_selftest=1"],
			"marker": "ADVENTURE_SELFTEST",
		},
		"screens": {
			V10AdventureData.SCREEN_ID: V10AdventureData.SCREEN_PATH,
		},
		"nav": {
			V10AdventureData.SCREEN_ID: ["tables"],
		},
		"save": {
			V10AdventureData.SAVE_KEY: V10AdventureData.defaults(),
		},
		"ensure": func(S: Dictionary) -> void:
			V10AdventureData.ensure(S),
	})
