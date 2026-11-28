extends RefCounted

# Module manifest "mj_riichi" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "mj_riichi", "order": 280, "step": 4, "selftest": {"scene": "res://scripts/v10/mj/riichi/riichi_selftest.tscn", "args": ["--mj_riichi_selftest=1"],
		"fast_args": ["--mj_riichi_selftest=1", "--games=20"], "marker": "MJ_RIICHI"},
		"screens": {"mj_riichi": "res://scripts/v10/mj/riichi/riichi_screen.gd"},
		"nav": {"mj_riichi": ["tables"]}}
