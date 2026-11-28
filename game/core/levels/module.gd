extends RefCounted

# Module manifest "levels" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "levels", "order": 130, "step": 2, "selftest": {"scene": "res://scripts/v10/levels/levels_selftest.tscn", "args": ["--levels_selftest=1"],
		"fast_args": ["--levels_selftest=1", "--levels_n=200"], "marker": "LEVELS SELFTEST"},
		"migrator": func(S: Dictionary, _now: int) -> void: G.migrate_48_to_1000(S)}
