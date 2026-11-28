extends RefCounted

# Module manifest "mj_garden" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "mj_garden", "order": 340, "step": 4, "selftest": {"scene": "res://scripts/v10/mj/garden/garden_selftest.tscn", "args": ["--mj_garden_selftest=1"],
		"marker": "MJ_GARDEN"},
		"save": {"v10_mj_garden": V10MjGardenSave.DEFAULTS},
		"ensure": func(S: Dictionary) -> void: V10MjGardenSave.ensure(S),
		"screens": {"mj_garden": "res://scripts/v10/mj/garden/garden_screen.gd"},
		"nav": {"mj_garden": ["tables"]}}
