extends RefCounted

# Module manifest "meta" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "meta", "order": 30, "step": 1, "selftest": {"scene": "res://scripts/v10/meta/meta_runner.tscn",
		"args": ["--meta_selftest=1", "--save=user://meta_runner.json", "--save_wipe=1"], "marker": "META_SELFTEST"},
		# 0.9 «Визиты» streak counter: the new Серия (rituals, W2) starts from zero (spec Р3)
		"migrator": func(S: Dictionary, _now: int) -> void: S["streak"] = 0,
		"wire": func() -> void:
			# one clock (spec §2.5, INTEGRATION §3.2): the wish clock reads V10Meta
			V10GClock.now_fn = V10Meta.now_unix
	}
