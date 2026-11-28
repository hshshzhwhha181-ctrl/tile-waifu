extends RefCounted

# Module manifest "fonts" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "fonts", "order": 50, "step": 1, "selftest": {"scene": "res://scripts/v10/fonts/fonts_runner.tscn", "args": ["--fonts_selftest=1"], "marker": "FONTS SELFTEST"},
		"save": {"deco_fonts": true}}
