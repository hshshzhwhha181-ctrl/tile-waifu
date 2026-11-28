extends RefCounted

# Module manifest "profile" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "profile", "order": 60, "step": 1, "selftest": {"scene": "res://scripts/v10/profile/profile2_selftest.tscn", "args": ["--profile2_selftest=1"],
		"marker": "PROFILE2_SELFTEST"},
		"save": {"v10_cos_owned": {}, "v10_feats": {"stats": {}, "done": {}}},
		# seed BEFORE ensure adds an empty v10_cos_seen: a veteran must not get dozens of «новое»
		"migrator": func(S: Dictionary, _now: int) -> void: V10ProfileCos.seed_seen(S, V10ProfileCos.ctx_from_save(S)),
		"ensure": func(S: Dictionary) -> void:
			if not (S.get("v10_cos_seen") is Dictionary):
				S["v10_cos_seen"] = {}}
