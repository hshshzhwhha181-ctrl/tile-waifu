extends RefCounted

# Module manifest "juice" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "juice", "order": 120, "step": 1, "selftest": {"scene": "res://scripts/v10/juice/demo/juice_demo.tscn", "args": ["--juice_selftest=1"], "marker": "JUICE SELFTEST"},
		"save": {"a11y_calm": false}}
