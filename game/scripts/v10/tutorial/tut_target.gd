class_name V10TutTarget
extends RefCounted
# tut_id -> on-screen rectangle (viewport px, the space of a CanvasLayer with no transform).
# Search: provider -> node with meta "tut_id" -> group "tut:<id>" -> FALLBACKS (current 0.9 code and HUD v2 members).

static var _providers: = {}
static var _cache: = {}  # id -> WeakRef(node)

# Fallback paths: "s:<prop>[.<prop>|[i]]" = property of main.screen, "m:<prop>…" = property of main.
# A path may end in "()" to call a method that returns a Rect2 or a Node.
const FALLBACKS: = {
	"nav.teahouse": ["m:tab_nodes.home", "s:tab_ls[0]"],
	"nav.heroines": ["m:tab_nodes.collection", "s:tab_ls[1]"],
	"nav.tables": ["m:tab_nodes.levels", "s:tab_ls[2]"],
	"nav.wishes": ["m:tab_nodes.summon", "s:tab_ls[3]"],
	"nav.shop": ["m:tab_nodes.shop", "s:tab_ls[4]"],
	"home.play": ["s:play_b", "s:play_btn"],
	"home.phone": ["s:phone_b"],
	"home.partner": ["s:partner"],
	"home.hero": ["s:hero"],
	"lantern.today": ["s:lantern_tr[0]"],
	"lantern.salon": ["s:lantern_tr[1]"],
	"lantern.streak": ["s:lantern_tr[2]"],
	"match.tray": ["s:tray_box", "s:hud.tray", "s:tray"],
	"match.status": ["s:tiles_lbl", "s:hud.status_l", "s:status_l"],
	"match.hero": ["s:portrait", "s:hud.hero_holder", "s:hero_holder"],
	"match.pause": ["s:hud.pause_btn", "s:pause_btn"],
	"match.help": ["s:hud.help_row", "s:help_row"],
	"match.hint": ["s:btn_hint", "s:hud.discs.hint", "s:discs.hint"],
	"match.stake": ["s:riichi_btn", "s:hud.stake", "s:stake"],
	"match.combo": ["s:combo_lbl", "s:hud.combo_l", "s:combo_l"],
	"win.next": ["s:victory_next_btn", "s:play_b"],
	"win.home": ["s:home_b"],
	"fail.retry": ["s:fail_retry_btn"],
}


static func provide(id: String, fn: Callable) -> void:
	_providers[id] = fn


static func unprovide(id: String) -> void:
	_providers.erase(id)


static func clear_cache() -> void:
	_cache.clear()


static func _visible(n: Node) -> bool:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return false
	if n is CanvasItem:
		return (n as CanvasItem).is_visible_in_tree()
	return true


static func rect_of(n: Node) -> Rect2:
	if n is Control:
		var c: = n as Control
		var xf: = c.get_global_transform_with_canvas()
		return xf * Rect2(Vector2.ZERO, c.size)
	if n is Node2D:
		var n2: = n as Node2D
		var xf2: = n2.get_global_transform_with_canvas()
		var sz: Vector2 = n2.get_meta("tut_size", Vector2.ZERO)
		if sz == Vector2.ZERO and n2.has_method("get_rect"):
			var r: Rect2 = n2.call("get_rect")
			return xf2 * r
		return xf2 * Rect2(-sz * 0.5, sz)
	return Rect2()


static func _radius_for(n: Node, r: Rect2) -> float:
	if n != null and n.has_meta("tut_radius"):
		return float(n.get_meta("tut_radius"))
	var h: = minf(r.size.x, r.size.y)
	if n is V10Button and String(n.get("kind")) == "play":
		return h * 0.5
	if absf(r.size.x - r.size.y) < 2.0 and h <= 96.0:
		return h * 0.5
	return 4.0


static func _result(r: Rect2, radius: float, n: Node) -> Dictionary:
	if r.size.x < 2.0 or r.size.y < 2.0:
		return {"ok": false, "rect": Rect2(), "radius": 0.0, "node": null}
	return {"ok": true, "rect": r, "radius": radius, "node": n}


static func find(root: Node, id: String) -> Dictionary:
	if id == "":
		return {"ok": false, "rect": Rect2(), "radius": 0.0, "node": null}
	# 1. provider
	if _providers.has(id):
		var fn: Callable = _providers[id]
		if fn.is_valid():
			var v = fn.call()
			if v is Rect2:
				return _result(v, minf(v.size.x, v.size.y) * 0.5 if absf(v.size.x - v.size.y) < 2.0 else 4.0, null)
			if v is Dictionary and v.get("rect", null) is Rect2:
				return _result(v.rect, float(v.get("radius", 4.0)), v.get("node", null))
		else:
			_providers.erase(id)
	# 2. cached / tagged node
	if _cache.has(id):
		var n0 = (_cache[id] as WeakRef).get_ref()
		if n0 != null and _visible(n0) and String(n0.get_meta("tut_id", "")) == id:
			var r0: = rect_of(n0)
			return _result(r0, _radius_for(n0, r0), n0)
		_cache.erase(id)
	if root != null and is_instance_valid(root):
		var n: = _find_tagged(root, id)
		if n != null:
			_cache[id] = weakref(n)
			var r1: = rect_of(n)
			return _result(r1, _radius_for(n, r1), n)
		# 3. group
		if root.is_inside_tree():
			for g in root.get_tree().get_nodes_in_group("tut:" + id):
				if _visible(g):
					var r2: = rect_of(g)
					return _result(r2, _radius_for(g, r2), g)
	# 4. fallbacks on the current code
	if FALLBACKS.has(id):
		var main: Node = V10Tutorial.main_node() if V10Tutorial.inst != null else null
		for path in FALLBACKS[id]:
			var v2 = _walk(main, String(path))
			if v2 is Node and _visible(v2):
				var r3: = rect_of(v2)
				var res: = _result(r3, _radius_for(v2, r3), v2)
				if res.ok:
					return res
			elif v2 is Rect2:
				var res2: = _result(v2, 4.0, null)
				if res2.ok:
					return res2
	return {"ok": false, "rect": Rect2(), "radius": 0.0, "node": null}


static func _find_tagged(n: Node, id: String) -> Node:
	if n.has_meta("tut_id") and String(n.get_meta("tut_id")) == id and _visible(n):
		return n
	for c in n.get_children():
		var f: = _find_tagged(c, id)
		if f != null:
			return f
	return null


static func _walk(main: Node, path: String):
	if main == null or not is_instance_valid(main):
		return null
	var cur = null
	if path.begins_with("m:"):
		cur = main
	elif path.begins_with("s:"):
		cur = main.get("screen")
	else:
		return null
	for part in path.substr(2).split("."):
		if cur == null:
			return null
		var key: = String(part)
		var idx: = -1
		var b: = key.find("[")
		if b >= 0:
			idx = int(key.substr(b + 1, key.length() - b - 2))
			key = key.substr(0, b)
		if cur is Dictionary:
			cur = (cur as Dictionary).get(key, null)
		elif cur is Object and is_instance_valid(cur):
			if not (key in cur):
				return null
			cur = cur.get(key)
		else:
			return null
		if idx >= 0:
			if cur is Array and idx < (cur as Array).size():
				cur = cur[idx]
			else:
				return null
	return cur
