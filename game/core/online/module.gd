extends RefCounted

# Module manifest "online" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {
		"id": "online",
		"order": 410,
		"step": 4,
		"selftest": {
			"scene": "res://scripts/v10/online/online_selftest.tscn",
			"args": [],
			"marker": "ONLINE_SELFTEST",
		},
		"screens": {
			"v10account": "res://scripts/v10/online/account_screen.gd",
			"v10pvp": "res://scripts/v10/online/pvp_online_screen.gd",
		},
		"nav": {"v10account": ["profile"], "v10pvp": ["tables"]},
		"save": {V10OnlineCfg.KEY: V10OnlineCfg.defaults()},
		"ensure": func(S: Dictionary) -> void: V10OnlineCfg.ensure(S),
	}
