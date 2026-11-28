extends RefCounted

# Module manifest "affection" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "affection", "order": 430, "step": 4, "selftest": {"scene": "res://scripts/v10/economy/affection_selftest.tscn",
		"args": ["--affection_selftest=1"], "marker": "AFFECTION_SELFTEST"},
		"save": {"v10_gifts": V10AffCurve.defaults()},
		"ensure": func(S: Dictionary) -> void:
			V10AffCurve.ensure(S)}
