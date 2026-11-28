extends RefCounted

# Module manifest "events" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "events", "order": 420, "step": 4, "selftest": {"scene": "res://scripts/v10/events/events_selftest.tscn",
		"args": [], "marker": "EVENTS_SELFTEST"},
		"screens": {
			"v10welcome7": "res://scripts/v10/events/welcome7_screen.gd",
			"v10wheel": "res://scripts/v10/events/lucky_wheel_screen.gd",
		},
		"nav": {"v10welcome7": ["home"], "v10wheel": ["home"]},
		"save": {"v10_welcome7": {}, "v10_wheel": {}, "v10_dates": {}}}
