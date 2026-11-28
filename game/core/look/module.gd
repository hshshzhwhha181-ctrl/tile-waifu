extends RefCounted

# Module manifest "look" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "look", "order": 70, "step": 1, "selftest": {"scene": "res://scripts/v10/look/look_runner.tscn", "args": ["--look_selftest=1"], "marker": "LOOK_SELFTEST"},
		"ensure": func(S: Dictionary) -> void: V10Look.migrate(S)}
