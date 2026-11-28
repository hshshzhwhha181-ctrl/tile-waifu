extends RefCounted

# Module manifest "mj_classic" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "mj_classic", "order": 310, "step": 4, "selftest": {"scene": "res://scripts/v10/mj/classic/classic_selftest.tscn", "args": ["--mj_classic_selftest=1"],
		"marker": "MJ_CLASSIC"},
		"save": {"v10_mj_classic": V10MjClassicSave.DEFAULTS},
		"ensure": func(S: Dictionary) -> void: V10MjClassicSave.ensure(S),
		"screens": {
			"mj_classic_lobby": "res://scripts/v10/mj/classic/classic_lobby.gd",
			"mj_classic": "res://scripts/v10/mj/classic/classic_screen.gd",
			"mj_memory": "res://scripts/v10/mj/classic/memory.gd",
		},
		"nav": {"mj_classic_lobby": ["tables"], "mj_classic": ["mj_classic_lobby", "tables"], "mj_memory": ["mj_classic_lobby", "tables"]}}
