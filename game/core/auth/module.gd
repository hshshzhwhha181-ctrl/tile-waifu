extends RefCounted

# Module manifest "auth" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "auth", "order": 90, "step": 1, "selftest": {"scene": "res://scripts/v10/auth/auth_dev.tscn",
		"args": ["--auth_selftest=1", "--save=user://auth_selftest_save.json", "--save_wipe=1"], "marker": "AUTH_SELFTEST"},
		"ensure": func(S: Dictionary) -> void: V10Auth.ensure(S)}
