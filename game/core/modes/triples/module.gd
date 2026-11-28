extends RefCounted

# Module manifest "mj_triples" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "mj_triples", "order": 270, "step": 4, "selftest": {"scene": "res://scripts/v10/mj/triples/triples_selftest.tscn", "args": ["--mj_triples_selftest=1"],
		"marker": "MJ_TRIPLES"},
		"screens": {"mj_triples": "res://scripts/v10/mj/triples/triples_screen.gd"},
		"nav": {"mj_triples": ["tables"]}}
