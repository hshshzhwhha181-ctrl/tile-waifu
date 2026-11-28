extends RefCounted

# Module manifest "rituals" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "rituals", "order": 160, "step": 2, "selftest": {"scene": "res://scripts/v10/rituals/rituals_runner.tscn",
		"args": ["--rit=selftest", "--save=user://rit_runner.json", "--save_wipe=1"], "marker": "RIT_SELFTEST"},
		"save": V10RitSave.defaults(),
		"ensure": func(S: Dictionary) -> void:
			var df: = V10RitSave.defaults()
			for k in df:
				if not (S.get(k) is Dictionary):
					S[k] = df[k].duplicate(true),
		"wire": func() -> void:
			V10Rituals.install()
	}
