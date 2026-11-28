extends RefCounted

# Module manifest "palm" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "palm", "order": 360, "step": 4, "selftest": {"scene": "res://scripts/v10/palm/hand_selftest.tscn", "args": ["--hand_selftest=1"],
		"fast_args": ["--hand_selftest=1", "--hand_real=24"], "marker": "HAND_SELFTEST"},
		"screens": {"hand": V10PalmInfo.SCREEN_PATH},
		"nav": {"hand": ["tables"]},
		"save": {"v10_hand": V10HandState.defaults()},
		"ensure": func(_S: Dictionary) -> void:
			V10HandState.st()
			V10HandState.register_cos(),
		"wire": func() -> void:
			V10Afisha.set_provider("hand", func() -> bool: return bool(V10PalmInfo.afisha_entry().done))
	}
