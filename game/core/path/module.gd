extends RefCounted

# Module manifest "path" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "path", "order": 140, "step": 2, "selftest": {"scene": "res://scripts/v10/path/path_demo.tscn", "args": ["--path_selftest=1"], "marker": "PATH SELFTEST"},
		"screens": {"v10path": "res://scripts/v10/path/path_map.gd"}, "nav": {"v10path": ["tables"]},
		"save": {"v10_levels": {}, "v10_boosters": {}},
		"ensure": func(S: Dictionary) -> void:
			var prev = V10PathState.root_override
			V10PathState.root_override = S
			V10PathState.st()
			V10PathBoosters.st()
			V10PathState.root_override = prev}
