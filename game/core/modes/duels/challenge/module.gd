extends RefCounted

# Module manifest "challenge" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "challenge", "order": 380, "step": 4, "selftest": {"scene": "res://scripts/v10/duels/challenge/challenge_selftest.tscn",
		"args": ["--challenge_selftest=1", "--save=user://ch_selftest.json", "--save_wipe=1"],
		"marker": "CHALLENGE_SELFTEST"},
		"screens": {"challenge": V10DuelInfo.CHALLENGE_PATH, "challenge_play": V10DuelInfo.CHALLENGE_PLAY_PATH},
		"nav": {"challenge": ["tables"], "challenge_play": ["challenge"]},
		"ensure": func(_S: Dictionary) -> void: V10ChallengeState.st()}
