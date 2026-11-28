extends RefCounted

# Module manifest "responsive" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "responsive", "order": 10, "step": 1, "selftest": {"scene": "", "args": ["--layout_selftest=1", "--save=user://layout_shots_save.json", "--save_wipe=1"],
		"needs_render": true, "resolution": "1536x2048", "marker": "LAYOUT_SELFTEST"}}
