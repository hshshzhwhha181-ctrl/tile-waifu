class_name V10TutTarget
extends RefCounted

# V10TutTarget — finds what a coach-mark points at, on any screen, at any aspect ratio.
# A target is a Dictionary or an Array of Dictionaries tried in order (fallbacks). Kinds:
#   {"meta": "salon.bank"}         a node with meta tut_id == "salon.bank" (or in group "tut:salon.bank") — the
#                                  preferred way: a lane tags its node once, `n.set_meta("tut_id", "salon.bank")`
#   {"prop": "btn_hint"}           a property of the current screen; dotted for dictionaries / sub-objects
#                                  ("side_btns.tasks"); {"prop": "tab_nodes.summon", "from": "main"} reads main
#   {"path": "V8Header/Help"}      a NodePath under the screen (or "from": "main")
#   {"text": "Загадать ×1"}        the visible Label / JButton whose text contains the string (the JButton wins)
#   {"tex": "star_on"}             visible TextureRect / Sprite2D whose texture path contains it; "union": true
#                                  spans all of them
#   {"dyn": "free_tile"}           a resolver registered in code (V10TutTarget.DYN; board tiles etc.)
#   {"rect": [x, y, w, h]}         fractions of the viewport (last-resort anchor that still scales)
#   {"px": [x, y, w, h]}           pixels; a negative x / y is measured from the right / bottom edge
#   {"union": [spec, spec]}        the bounding box of every spec that resolves
# Common keys: "pad" (px around the hole, default 10), "round" (true: circular-ish hole).
# resolve() returns {"ok": bool, "rect": Rect2 in viewport pixels, "node": Node or null, "kind": String}.

const NO: = {"ok": false, "rect": Rect2(), "node": null, "kind": ""}

# dynamic resolvers: name -> Callable(ctx: Dictionary) returning a Node, a Rect2 or null
static var DYN: = {}


static func register_dyn(name: String, fn: Callable) -> void:
	DYN[name] = fn


static func resolve(spec, ctx: Dictionary) -> Dictionary:
	if spec == null:
		return NO
	if spec is Array:
		for s in spec:
			var r: = resolve(s, ctx)
			if r.ok:
				return r
		return NO
	if not (spec is Dictionary):
		return NO
	var r: = _one(spec, ctx)
	if r.ok:
		var pad: = float(spec.get("pad", 10.0))
		r.rect = r.rect.grow(pad)
		r["round"] = bool(spec.get("round", false))
	return r


static func _vp(ctx: Dictionary) -> Vector2:
	var m = ctx.get("main")
	if m is CanvasItem and (m as CanvasItem).is_inside_tree():
		return (m as CanvasItem).get_viewport_rect().size
	return ctx.get("vp", Vector2(720, 1280))


static func _one(spec: Dictionary, ctx: Dictionary) -> Dictionary:
	if spec.has("union"):
		var acc: = Rect2()
		var any: = false
		for s in spec.union:
			var r: = resolve(s, ctx)
			if r.ok:
				acc = r.rect if not any else acc.merge(r.rect)
				any = true
		return {"ok": any, "rect": acc, "node": null, "kind": "union"} if any else NO
	if spec.has("meta"):
		return _node_res(find_meta(ctx, String(spec.meta)), "meta")
	if spec.has("prop"):
		var base = ctx.get("main") if spec.get("from", "") == "main" else ctx.get("screen")
		var v = _prop(base, String(spec.prop))
		if v is Rect2:
			return {"ok": (v as Rect2).size.x > 2.0, "rect": v, "node": null, "kind": "prop_rect"}
		return _node_res(v, "prop")
	if spec.has("path"):
		var base2 = ctx.get("main") if spec.get("from", "") == "main" else ctx.get("screen")
		if base2 is Node and is_instance_valid(base2):
			return _node_res((base2 as Node).get_node_or_null(NodePath(String(spec.path))), "path")
		return NO
	if spec.has("text"):
		return _node_res(find_text(_root(ctx), String(spec.text)), "text")
	if spec.has("tex"):
		var hits: = find_tex(_root(ctx), String(spec.tex), bool(spec.get("union", false)))
		if hits.is_empty():
			return NO
		var acc2: = node_rect(hits[0])
		for i in range(1, hits.size()):
			acc2 = acc2.merge(node_rect(hits[i]))
		return {"ok": true, "rect": acc2, "node": hits[0] if hits.size() == 1 else null, "kind": "tex"}
	if spec.has("dyn"):
		var fn = DYN.get(String(spec.dyn))
		if fn is Callable and (fn as Callable).is_valid():
			var v = (fn as Callable).call(ctx)
			if v is Rect2:
				return {"ok": v.size != Vector2.ZERO, "rect": v, "node": null, "kind": "dyn"}
			return _node_res(v, "dyn")
		return NO
	if spec.has("rect"):
		var vp: = _vp(ctx)
		var a: Array = spec.rect
		return {"ok": true, "rect": Rect2(float(a[0]) * vp.x, float(a[1]) * vp.y, float(a[2]) * vp.x, float(a[3]) * vp.y), "node": null, "kind": "rect"}
	if spec.has("px"):
		var vp2: = _vp(ctx)
		var b: Array = spec.px
		var x: = float(b[0])
		var y: = float(b[1])
		if x < 0.0:
			x += vp2.x
		if y < 0.0:
			y += vp2.y
		return {"ok": true, "rect": Rect2(x, y, float(b[2]), float(b[3])), "node": null, "kind": "px"}
	return NO


static func _root(ctx: Dictionary) -> Node:
	var m = ctx.get("main")
	if m is Node and is_instance_valid(m):
		return m
	var s = ctx.get("screen")
	return s if s is Node and is_instance_valid(s) else null


static func _node_res(n, kind: String) -> Dictionary:
	if not usable(n):
		return NO
	var r: = node_rect(n)
	if r.size.x < 2.0 or r.size.y < 2.0:
		return NO
	return {"ok": true, "rect": r, "node": n, "kind": kind}


# a node can be pointed at: alive, in the tree, drawn
static func usable(n) -> bool:
	if n == null or not (n is Object) or not is_instance_valid(n) or not (n is CanvasItem):
		return false
	var ci: = n as CanvasItem
	if not ci.is_inside_tree() or not ci.is_visible_in_tree() or ci.is_queued_for_deletion():
		return false
	if n is Tile and not (n as Tile).alive:
		return false
	return true


# the node's box in viewport pixels (canvas transform included: scaled boards, popups that pop in)
static func node_rect(n) -> Rect2:
	if not usable(n):
		return Rect2()
	var xf: Transform2D = (n as CanvasItem).get_global_transform_with_canvas()
	var local: = Rect2()
	if n is Tile:
		local = Rect2(-Tile.TW * 0.5, -Tile.TH * 0.5, Tile.TW, Tile.TH)
	elif n is Control:
		local = Rect2(Vector2.ZERO, (n as Control).size)
	elif n is Sprite2D:
		local = (n as Sprite2D).get_rect()
	elif n.has_method("tut_rect"):
		local = n.call("tut_rect")
	else:
		local = Rect2(-40, -40, 80, 80)
	return xf * local


static func _prop(base, path: String):
	var cur = base
	for part in path.split("."):
		if cur == null or (cur is Object and not is_instance_valid(cur)):
			return null
		if cur is Dictionary:
			cur = (cur as Dictionary).get(part)
		elif cur is Object:
			# get() (not `in`): a mock screen may serve properties through _get()
			cur = (cur as Object).get(part)
		else:
			return null
	return cur


# ── tree searches ──────────────────────────────────────────────────────────────────────────────────────────────

static func find_meta(ctx: Dictionary, id: String) -> Node:
	var root: = _root(ctx)
	if root == null:
		return null
	for n in root.get_tree().get_nodes_in_group("tut:" + id):
		if usable(n):
			return n
	return _walk_meta(root, id)


static func _walk_meta(n: Node, id: String) -> Node:
	if n.has_meta("tut_id") and String(n.get_meta("tut_id")) == id and usable(n):
		return n
	for c in n.get_children():
		if c is CanvasItem and not (c as CanvasItem).visible:
			continue
		var r: = _walk_meta(c, id)
		if r:
			return r
	return null


static func find_text(root: Node, text: String) -> Node:
	if root == null or text == "":
		return null
	var hit: = _walk_text(root, text)
	if hit == null:
		return null
	# a caption inside a button: point at the button
	var p: = hit.get_parent()
	for i in 3:
		if p == null:
			break
		if p is JButton:
			return p
		p = p.get_parent()
	return hit


static func _walk_text(n: Node, text: String) -> Node:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return null
	if n is V10Coach:
		return null
	if (n is Label or n is Button or n is RichTextLabel) and usable(n):
		var t: String = n.text if not (n is RichTextLabel) else (n as RichTextLabel).get_parsed_text()
		if text in t:
			return n
	for c in n.get_children():
		var r: = _walk_text(c, text)
		if r:
			return r
	return null


static func find_tex(root: Node, key: String, all: bool) -> Array:
	var out: = []
	if root:
		_walk_tex(root, key, all, out)
	return out


static func _walk_tex(n: Node, key: String, all: bool, out: Array) -> void:
	if not all and not out.is_empty():
		return
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is V10Coach:
		return
	var t: Texture2D = null
	if n is TextureRect:
		t = (n as TextureRect).texture
	elif n is Sprite2D:
		t = (n as Sprite2D).texture
	if t and key in t.resource_path and usable(n):
		out.append(n)
	for c in n.get_children():
		_walk_tex(c, key, all, out)
