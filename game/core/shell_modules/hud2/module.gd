extends RefCounted

# Module manifest "hud2" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "hud2", "order": 40, "step": 1, "selftest": {"scene": "res://scripts/v10/hud2/hud2_demo.tscn", "args": ["--hud2_selftest=1"], "marker": "HUD2 SELFTEST"},
		"save": {"hero_combo": "full"}}
