extends RefCounted

# Module manifest "tutorial" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "tutorial", "order": 110, "step": 1, "selftest": {"scene": "res://scripts/v10/tutorial/tut_selftest.tscn",
		"args": ["--save=user://tut_test.json", "--save_wipe=1", "--tut_static=1"], "marker": "V10TUT", "static_only": true},
		# S.tut_done (0.9) becomes chapters.match1 only when the block is created: the module's own ensure does it
		"ensure": func(S: Dictionary) -> void: V10TutState.ensure(S)}
