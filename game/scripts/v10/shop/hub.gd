class_name V10ShopHub
extends RefCounted

# V10ShopHub — the one place the running game gets its V10ShopModel (after integration). Everything is looked up
# dynamically so this file parses before the integrator adds G.econ / S.v10_shop.
#
#   V10ShopHub.model()            -> V10ShopModel over G.econ (v10-economy) and G.S.v10_shop
#   V10ShopHub.open(main, id)     -> builds V10Shop2 / V10PassScreen / V10Purchases into a main.gd screen Control

static var _m: V10ShopModel = null


static func model() -> V10ShopModel:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g == null or g.get("econ") == null:
		push_warning("V10ShopHub: G.econ is missing (merge v10-economy and wire it in g.gd first)")
		return null
	var S: Dictionary = g.S
	if not (S.get("v10_shop") is Dictionary):
		S["v10_shop"] = V10ShopModel.defaults()
	# a loaded / reset save or a new econ replaces the dictionaries: never keep writing into the old ones
	if _m != null and is_same(_m.econ, g.econ) and is_same(_m.st, S.v10_shop):
		return _m
	_m = V10ShopModel.new(g.econ, S.v10_shop)
	_m.level_fn = func(): return maxi(0, int(S.get("unlocked", 1)) - 1)
	_m.owns_fn = func(id): return bool(g.call("owns", id)) if g.has_method("owns") else false
	_m.items_fn = func():
		var out: = []
		for it in g.ITEMS:
			if String(it.get("cat", "")) == "outfit" and not bool(it.get("start", false)) and not bool(it.get("hidden", false)) \
					and bool(it.get("sfw", not bool(it.get("bold", false)))):
				out.append(it)
		return out
	_m.free_paths_fn = func() -> Array:
		var fp: = []
		var t: Dictionary = g.tasks()
		var left_g: = 0
		for i in g.TASKS.size():
			if not bool(t.claimed[i]):
				left_g += int(g.TASKS[i].gems)
		if left_g > 0 and int(S.get("unlocked", 1)) >= 7:
			fp.append({"text": "Задания дня: +%d кристаллов" % left_g, "go": "today"})
		fp.append({"text": "Столы Пути: +15 кристаллов за первую победу", "go": "path"})
		return fp
	return _m


static func _go_free(main, go: String) -> void:
	if main == null:
		return
	var nav_sc = load("res://scripts/v10/core/nav.gd")
	if go == "pass":
		main.go("shop", {"v10": "pass"})
	elif go == "today" and nav_sc:
		nav_sc.today_sheet(main)
	elif go == "path" and nav_sc:
		nav_sc.play_path(main)


static func go_free_cb(main) -> Callable:
	return func(go: String) -> void: _go_free(main, go)


# main.gd screen adapter: SCREENS["shop"] = preload("res://scripts/v10/shop/shop2_screen.gd")
static func build_into(screen: Control, main, args: Dictionary) -> void:
	var m: = model()
	if m == null:
		return
	var id: = String(args.get("v10", "shop"))
	var s: Control
	match id:
		"pass":
			s = V10PassScreen.make(m)
		"purchases":
			s = V10Purchases.make(m)
		_:
			s = V10Shop2.make(m, {"tab": int(args.get("tab", 0)), "bottom_reserve": 120.0})
	s.size = screen.size
	screen.add_child(s)
	s.go_screen.connect(func(to: String, a: Dictionary) -> void:
		if to == "back":
			main.back()
		elif to in ["pass", "purchases"]:
			var aa: = a.duplicate()
			aa["v10"] = to
			main.go("shop", aa)
		elif to == "odds":
			main.go("odds", a))
