extends RefCounted

# Module manifest "mj_bridge" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "mj_bridge", "order": 350, "step": 4, "selftest": {"scene": "res://scripts/v10/mj/bridge/bridge_selftest.tscn", "args": ["--mj_bridge_selftest=1"],
		"marker": "MJ_BRIDGE"},
		"save": {"v10_mj_bridge": V10MjBridgeSave.DEFAULTS},
		"ensure": func(S: Dictionary) -> void: V10MjBridgeSave.ensure(S),
		"screens": {
			"mj_bridge": "res://scripts/v10/mj/bridge/bridge_screen.gd",
			"mj_bridge_daily": "res://scripts/v10/mj/bridge/bridge_daily_screen.gd",
			"mj_bridge_hand": "res://scripts/v10/mj/bridge/bridge_hand_screen.gd",
		},
		"nav": {"mj_bridge": ["tables"], "mj_bridge_daily": ["tables"], "mj_bridge_hand": ["tables"]}}
