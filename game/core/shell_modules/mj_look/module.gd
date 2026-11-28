extends RefCounted

# Module manifest "mj_look" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "mj_look", "order": 260, "step": 4, "selftest": {"scene": "res://scripts/v10/mj/look/look_selftest.tscn", "args": ["--mj_look_selftest=1"],
		"needs_render": true, "resolution": "720x1280", "marker": "MJ_LOOK"}}
