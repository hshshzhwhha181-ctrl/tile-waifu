extends RefCounted

# Module manifest "tower" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "tower", "order": 240, "step": 4, "selftest": {"scene": "res://scripts/v10/tower/tower_selftest.tscn",
		"args": ["--tower_selftest=1"], "fast_args": ["--mods_selftest=1", "--pagoda_selftest=1", "--journey_selftest=1", "--tower_tables=1", "--tower_rules=1", "--tower_hygiene=1"],
		"marker": "TOWER_SELFTEST"},
		"screens": {
			"pagoda": "res://scripts/v10/tower/pagoda_screen.gd",
			"journey": "res://scripts/v10/tower/journey_screen.gd",
			"tower_play": "res://scripts/v10/tower/tower_play.gd",
		},
		"nav": {"pagoda": ["tables"], "journey": ["tables", "home"], "tower_play": ["pagoda", "journey"]},
		"save": {"v10_pagoda": V10Pagoda.DEFAULTS, "v10_journey": V10Journey.DEFAULTS},
		"ensure": func(_S: Dictionary) -> void:
			V10Pagoda.st()
			V10Journey.st(),
		"wire": func() -> void:
			for cdef in V10Pagoda.cos_defs():
				if not V10ProfileCos.has(String(cdef.get("id", "")), ""):
					V10ProfileCos.register(cdef)
	}
