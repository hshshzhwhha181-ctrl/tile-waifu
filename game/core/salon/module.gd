extends RefCounted

# Module manifest "salon" (P07). V10Registry finds it by scanning game/core for module.gd - adding a module is ONE new
# file like this one, no shared list. "order" fixes the initialisation order (the old registry_list.gd line order;
# ties by id); spec keys are documented in game/core/base/registry.gd.

static func spec() -> Dictionary:
	return {"id": "salon", "order": 150, "step": 2, "selftest": {"scene": "res://scripts/v10/salon/salon_runner.tscn", "args": ["--salon_selftest=1"], "marker": "SALON_SELFTEST"},
		"screens": {"v10salon": "res://scripts/v10/salon/salon_screen.gd", "v10scene": "res://scripts/v10/salon/zone_scene.gd"},
		"nav": {"v10salon": ["home"], "v10scene": ["v10salon"]},
		"save": {"v10_salon": V10Salon.defaults()},
		"ensure": func(S: Dictionary) -> void:
			V10Salon.ensure(S)
			V10Salon.notify_stars(0),
		"wire": func() -> void:
			V10Salon.grant_cb = func(rewards: Dictionary, src: String) -> void:
				var cur: = {}
				for k in rewards:
					var n: = int(rewards[k])
					if k in ["gems", "coins", "tickets", "petals"]:
						cur[k] = n
					elif k == "leaves":
						V10Streak.st().leaves = mini(V10Streak.LEAF_MAX, int(V10Streak.st().leaves) + n)
					elif k in ["hint", "shuffle", "undo"]:
						var inv: Dictionary = G.S.get("v10_items", {}) if G.S.get("v10_items") is Dictionary else {}
						var ik: String = str(k) + "s"
						inv[ik] = int(inv.get(ik, 0)) + n
						G.S["v10_items"] = inv
				if not cur.is_empty():
					V10Money.grant(cur, src)
			V10Salon.bond_cb = func(hero: String, n: int, src: String) -> void:
				V10Bond.gain(hero, n, src)
			V10Salon.letter_cb = func(hero: String, kind: String) -> void:
				V9Letters.queue(kind, {"hero": hero})
			V10Salon.day_cb = func() -> String:
				return V10Meta.day_key()
			V10Salon.level_cb = func() -> int:
				return V10PathState.current() + 1
			V10Salon.help_cb = func(topic: String) -> void:
				var tree: = Engine.get_main_loop() as SceneTree
				var main = tree.current_scene if tree else null
				if main != null:
					V10Clarity.open_glossary(main, topic)
	}
