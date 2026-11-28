extends RefCounted

# Module manifest "mj_connect" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "mj_connect", "order": 320, "step": 4, "selftest": {"scene": "res://scripts/v10/mj/connect/connect_selftest.tscn", "args": ["--mj_connect_selftest=1"],
		"marker": "MJ_CONNECT"},
		"save": {"v10_mj_connect": V10MjConnectSave.DEFAULTS},
		"ensure": func(S: Dictionary) -> void: V10MjConnectSave.ensure(S),
		"screens": {"mj_connect": "res://scripts/v10/mj/connect/connect_screen.gd"},
		"nav": {"mj_connect": ["tables"]}}
