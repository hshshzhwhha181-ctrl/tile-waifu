extends RefCounted

# Module manifest "adventure" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {
		"id": "adventure",
		"order": 400,
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
	}
