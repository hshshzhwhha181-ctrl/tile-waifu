extends RefCounted

# Module manifest "duels" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "duels", "order": 370, "step": 4, "selftest": {"scene": "res://scripts/v10/duels/duel_selftest.tscn",
		"args": ["--duel_selftest=1", "--save=user://duel_selftest.json", "--save_wipe=1"], "marker": "DUEL_SELFTEST"},
		"screens": {"duels": V10DuelInfo.SCREEN_PATH, "duel2": V10DuelInfo.PLAY_PATH},
		"nav": {"duels": ["tables"], "duel2": ["duels"]},
		"ensure": func(_S: Dictionary) -> void:
			V10Duel.st()
			V10DuelRank.register_cos()}
