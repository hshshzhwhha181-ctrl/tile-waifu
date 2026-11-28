extends RefCounted

# Module manifest "voice" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "voice", "order": 210, "step": 3, "selftest": {"scene": "res://scripts/v10/voice/v10_voice_selftest.tscn", "args": [], "marker": "V10VOICE OK"}}
