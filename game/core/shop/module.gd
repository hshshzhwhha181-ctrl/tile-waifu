extends RefCounted

# Module manifest "shop" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "shop", "order": 80, "step": 1, "selftest": {"scene": "res://scripts/v10/shop/shop_demo.tscn", "args": ["--shop_selftest=1"], "marker": "SHOP_SELFTEST"},
		"screens": {"shop": "res://scripts/v10/shop/shop2_screen.gd"},
		"save": {"v10_shop": V10ShopModel.defaults()}}
