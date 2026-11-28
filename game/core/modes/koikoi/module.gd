extends RefCounted

# Module manifest "mj_koikoi" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "mj_koikoi", "order": 300, "step": 4, "selftest": {"scene": "res://scripts/v10/mj/koikoi/koikoi_selftest.tscn", "args": ["--mj_koikoi_selftest=1"],
		"fast_args": ["--mj_koikoi_selftest=1", "--games=100"], "marker": "MJ_KOIKOI"},
		"screens": {"mj_koikoi": "res://scripts/v10/mj/koikoi/koikoi_screen.gd"},
		"nav": {"mj_koikoi": ["tables"]}}
