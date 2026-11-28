extends RefCounted

# Module manifest "clarity" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "clarity", "order": 100, "step": 1, "selftest": {"scene": "res://scripts/v10/clarity/clarity_selftest.tscn", "args": [], "marker": "V10 CLARITY SELFTEST"},
		"ensure": func(S: Dictionary) -> void:
			if not (S.get("v10_clarity") is Dictionary):
				S["v10_clarity"] = {"marks": "auto", "big": false, "asked": false, "seen": {}, "tips": {}}}
