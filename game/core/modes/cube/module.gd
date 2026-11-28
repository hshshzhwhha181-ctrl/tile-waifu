extends RefCounted

# Module manifest "mj_cube" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "mj_cube", "order": 330, "step": 4, "selftest": {"scene": "res://scripts/v10/mj/cube/cube_selftest.tscn", "args": ["--mj_cube_selftest=1"],
		"marker": "MJ_CUBE"},
		"save": {"v10_mj_cube": V10MjCubeSave.DEFAULTS},
		"ensure": func(S: Dictionary) -> void: V10MjCubeSave.ensure(S),
		"screens": {"mj_cube": "res://scripts/v10/mj/cube/cube_screen.gd"},
		"nav": {"mj_cube": ["tables"]}}
