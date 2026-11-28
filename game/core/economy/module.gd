extends RefCounted

# Module manifest "economy" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "economy", "order": 20, "step": 1, "selftest": {"scene": "res://scripts/v10/economy/econ_selftest.tscn", "args": ["--econ_selftest=1"],
		"fast_args": ["--econ_selftest=1", "--econ_mc=0.1"], "marker": "ECON_SELFTEST"},
		"migrator": func(S: Dictionary, now: int) -> void:
			if not (S.get("econ") is Dictionary) or (S.econ as Dictionary).is_empty():
				S["econ"] = V10Econ.from_legacy(S, now)}
