class_name V10TutTarget
extends RefCounted
# tut_id -> on-screen rectangle (viewport px, the space of a CanvasLayer with no transform).
# Search: provider -> node with meta "tut_id" -> group "tut:<id>" -> FALLBACKS (W1 5-tab / HUD v2 / 0.9 compatibility).

static var _providers: = {}
static var _cache: = {}  # id -> WeakRef(node)
static var _cleanup_armed: = false

# Fallback paths: "s:<prop>[.<prop>|[i]]" = property of main.screen, "m:<prop>…" = property of main.
const FALLBACKS: = {
	"nav.teahouse": ["m:tab_nodes.home", "s:home2.tab_ls[0]", "s:tab_ls[0]"],
	"nav.heroines": ["m:tab_nodes.collection", "s:home2.tab_ls[1]", "s:tab_ls[1]"],
	"nav.tables": ["m:tab_nodes.tables", "m:tab_nodes.levels", "s:home2.tab_ls[2]", "s:tab_ls[2]"],
	"nav.wishes": ["m:tab_nodes.summon", "s:home2.tab_ls[3]", "s:tab_ls[3]"],
	"nav.shop": ["m:tab_nodes.shop", "s:home2.tab_ls[4]", "s:tab_ls[4]"],
	"home.play": ["s:home2.play_b", "s:play_b", "s:play_btn"],
	"home.phone": ["s:home2.phone_b", "s:phone_b"],
	"home.partner": ["s:home2.partner", "s:partner", "s:aff_root"],
	"home.hero": ["s:home2.rig", "s:live.art", "s:video", "s:rig", "s:hero"],
	"lantern.today": ["s:home2.lantern_tr[0]", "s:lantern_tr[0]"],
	"lantern.salon": ["s:home2.lantern_tr[1]", "s:lantern_tr[1]"],
	"lantern.streak": ["s:home2.lantern_tr[2]", "s:lantern_tr[2]"],
	"tables.play": ["s:play_btn", "s:play_b"],
	"tables.tourney": ["s:shelf_plates.tourney", "s:mode_tiles.tourney"],
	"match.tray": ["s:hud.tray", "s:hud2.tray", "s:tray", "s:tray_box"],
	"match.status": ["s:hud.status_l", "s:hud2.status_l", "s:status_l", "s:tiles_lbl"],
	"match.hero": ["s:portrait", "s:hud.hero_holder", "s:hero_holder"],
	"match.pause": ["s:hud.pause_btn", "s:hud2.pause_btn", "s:pause_btn"],
	"match.help": ["s:hud.help_row", "s:hud2.help_row", "s:help_row"],
	"match.hint": ["s:hud.discs.hint", "s:hud2.discs.hint", "s:discs.hint", "s:btn_hint"],
	"match.stake": ["s:hud.stake", "s:hud2.stake", "s:stake", "s:riichi_btn"],
	"match.combo": ["s:hud.combo_l", "s:hud2.combo_l", "s:combo_l", "s:combo_lbl"],
	"win.stars": ["s:stars_c", "s:victory_hud.stars_c"],
	"win.next": ["s:play_b", "s:victory_hud.play_b", "s:victory_next_btn"],
	"win.home": ["s:home_b", "s:victory_hud.home_b"],
	"fail.retry": ["s:fail_retry_btn"],
}

const MODE_ALIASES: = {
	"duels": ["duels", "duel"],
	"garden": ["garden", "zen"],
	"etudes": ["etudes", "etude"],
	"pagoda": ["pagoda", "climb"],
	"daily_task": ["daily_task", "bridge_daily"],
	"hand": ["hand", "bridge_hand"],
}


static func arm_cleanup() -> void:
	if _cleanup_armed:
		return
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_cleanup_armed = true
	if not tree.root.tree_exiting.is_connected(clear_all):
		tree.root.tree_exiting.connect(clear_all, CONNECT_ONE_SHOT)


static func clear_all() -> void:
	_providers.clear()
	_cache.clear()
	_cleanup_armed = false


static func provide(id: String, fn: Callable) -> void:
	arm_cleanup()
	_providers[id] = fn


static func unprovide(id: String) -> void:
	_providers.erase(id)


static func clear_cache() -> void:
	_cache.clear()


static func _visible(n: Node) -> bool:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree() or n.is_queued_for_deletion():
		return false
	if n is CanvasItem:
		return (n as CanvasItem).is_visible_in_tree() and (n as CanvasItem).modulate.a > 0.05
	return true


static func _unlocked_plate(n: Node) -> bool:
	if n is V10Plate and (n as V10Plate).disabled:
		return false
	if n is Control and (n as Control).get_script() != null and bool((n as Control).get("disabled")):
		return false
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
		if sz == Vector2.ZERO and n2.has_method("head_global"):
			var hg: Vector2 = n2.call("head_global")
			return Rect2(hg - Vector2(96, 80), Vector2(192, 420))
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
	# 1. live match tile pair (dynamic per-move target)
	if id in ["match.tile_a", "match.tile_b"] and _providers.has(id):
		var fn_t: Callable = _providers[id]
		if fn_t.is_valid():
			var vt = fn_t.call()
			if vt is Dictionary and vt.get("rect", null) is Rect2:
				var rt: = _result(vt.rect, float(vt.get("radius", 4.0)), vt.get("node", null))
				if rt.ok:
					return rt
	# 2. explicit meta "tut_id" on a visible node (primary contract with W2–W4 screens)
	if _cache.has(id):
		var n0 = (_cache[id] as WeakRef).get_ref()
		if n0 != null and _visible(n0) and String(n0.get_meta("tut_id", "")) == id and (root == null or root == n0 or root.is_ancestor_of(n0)):
			var r0: = rect_of(n0)
			return _result(r0, _radius_for(n0, r0), n0)
		_cache.erase(id)
	if root != null and is_instance_valid(root):
		var n: = _find_tagged(root, id)
		if n != null:
			_cache[id] = weakref(n)
			var r1: = rect_of(n)
			return _result(r1, _radius_for(n, r1), n)
		# 3. group "tut:<id>"
		if root.is_inside_tree():
			for g in root.get_tree().get_nodes_in_group("tut:" + id):
				if _visible(g):
					var r2: = rect_of(g)
					return _result(r2, _radius_for(g, r2), g)
	# 4. dynamic provider fallback (for untagged screens)
	if _providers.has(id):
		var fn: Callable = _providers[id]
		if fn.is_valid():
			var v = fn.call()
			if v is Rect2:
				return _result(v, minf(v.size.x, v.size.y) * 0.5 if absf(v.size.x - v.size.y) < 2.0 else 4.0, null)
			if v is Dictionary and v.get("rect", null) is Rect2:
				var rp0: = _result(v.rect, float(v.get("radius", 4.0)), v.get("node", null))
				if rp0.ok:
					return rp0
		else:
			_providers.erase(id)
	# 5. property path fallbacks on current code
	var main: Node = V10Tutorial.main_node() if V10Tutorial.inst != null else null
	if main == null and root != null and is_instance_valid(root) and ("screen_root" in root or "screen" in root):
		main = root
	if FALLBACKS.has(id):
		for path in FALLBACKS[id]:
			var v2 = _walk(main, root, String(path))
			if v2 is Node and _visible(v2):
				if id == "tables.tourney" and not _unlocked_plate(v2):
					continue
				var r3: = rect_of(v2)
				var res: = _result(r3, _radius_for(v2, r3), v2)
				if res.ok:
					return res
			elif v2 is Rect2:
				var res2: = _result(v2, 4.0, null)
				if res2.ok:
					return res2
	# 5. dynamic shelf cards on tables_hub.gd (tables.mode.<key>)
	if id.begins_with("tables.mode."):
		var mkey: = id.substr(12)
		var keys: Array = MODE_ALIASES.get(mkey, [mkey])
		for k in keys:
			for dict_name in ["shelf_plates", "mode_tiles"]:
				var plate = _walk(main, root, "s:%s.%s" % [dict_name, str(k)])
				if plate is Node and _visible(plate) and _unlocked_plate(plate):
					var rp: = rect_of(plate)
					var resp: = _result(rp, _radius_for(plate, rp), plate)
					if resp.ok:
						return resp
	return {"ok": false, "rect": Rect2(), "radius": 0.0, "node": null}


static func _find_tagged(n: Node, id: String) -> Node:
	if n.has_meta("tut_id") and String(n.get_meta("tut_id")) == id and _visible(n):
		return n
	for c in n.get_children():
		var f: = _find_tagged(c, id)
		if f != null:
			return f
	return null


static func _walk(main: Node, root: Node, path: String):
	var cur = null
	if path.begins_with("m:"):
		cur = main
	elif path.begins_with("s:"):
		if main != null and is_instance_valid(main) and "screen" in main and main.get("screen") != null:
			cur = main.get("screen")
		else:
			cur = root
	else:
		return null
	if cur == null or not is_instance_valid(cur):
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
