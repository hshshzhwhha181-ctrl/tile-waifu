extends RefCounted

# Module manifest "mj_sanma" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "mj_sanma", "order": 290, "step": 4, "selftest": {"scene": "res://scripts/v10/mj/sanma/sanma_selftest.tscn", "args": ["--mj_sanma_selftest=1"],
		"fast_args": ["--mj_sanma_selftest=1", "--games=20"], "marker": "MJ_SANMA"},
		"screens": {"mj_sanma": "res://scripts/v10/mj/sanma/sanma_screen.gd"},
		"nav": {"mj_sanma": ["tables"]}}
