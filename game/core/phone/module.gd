extends RefCounted

# Module manifest "phone" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "phone", "order": 180, "step": 2, "selftest": {"scene": "res://scripts/v10/phone/phone_runner.tscn",
		"args": ["--save=user://phone_st.json", "--save_wipe=1", "--phone_selftest=1"], "needs_render": true, "resolution": "720x1280",
		"marker": "PHONE SELFTEST"},
		"save": {"v10_phone": V10Phone.default_state(), "v10_feed": V10ChatFeed.default_state()},
		"ensure": func(S: Dictionary) -> void:
			if is_same(S, G.S):
				V10Phone.ensure()
			else:
				if not (S.get("v10_phone") is Dictionary):
					S["v10_phone"] = V10Phone.default_state()
				if not (S.get("v10_feed") is Dictionary):
					S["v10_feed"] = V10ChatFeed.default_state()}
