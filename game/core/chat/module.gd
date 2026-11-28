extends RefCounted

# Module manifest "chat" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "chat", "order": 170, "step": 2, "selftest": {"script": "res://scripts/v10/chat/chat_selftest_cli.gd", "args": [], "marker": "CHAT SELFTEST"}}
