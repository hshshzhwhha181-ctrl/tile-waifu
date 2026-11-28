extends Control






const SH: = 1560.0
const FADE: = 160.0
const BOTTOM_PAD: = 310.0  # 0.8: the chapter card at the map bottom can scroll clear of the CTA and the navbar
const GAPS: = [270.0, 118.0, 118.0, 118.0, 115.0, 115.0, 118.0, 118.0, 240.0, 170.0]

const ORDER: = [0, 1, 2, 3, "mid", 4, 5, 6, 7, "star"]

var main
var W: = 720.0
var H: = 1280.0
var map_root: Control
var map_h: = 0.0
var items: Array = []
var level_item: = {}
var panels: Array = []
var path_pts: PackedVector2Array
var path_dist: PackedFloat32Array
var path_len: = 0.0
var path_mat: ShaderMaterial
var marker: Control
var marker_pin: Polygon2D
var play_btn: JButton
var partner_go_btn: JButton
var partner_rows: = {}
var sel: = 0
var cur: = 0
var _drag: = false
var _drag_y: = 0.0
var _vel: = 0.0
var _moved: = 0.0
var _anim: = false
var _txt = null



func _t(key: String, fallback: String) -> String:
	if _txt == null and ResourceLoader.exists("res://core/v06/story/txt.gd"):
		_txt = load("res://core/v06/story/txt.gd")
	if _txt:
		var v = _txt.s(key)
		if v is String and v != key and v != "":
			return v
	return fallback


func build(m, args: Dictionary) -> void :
	main = m
	W = size.x
	H = size.y
	main.show_chrome(true, true)
	Sfx.music("menu")
	var st: = V6Worlds.state()
	cur = clampi(int(G.S.unlocked) - 1, 0, G.LEVELS.size() - 1)
	sel = clampi(int(args.get("select", cur)), 0, cur)
	var bgc: = ColorRect.new()
	bgc.size = size
	bgc.color = Color(0.1, 0.05, 0.16)
	bgc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bgc)
	# 0.10 M0: on tablets the plate under the map reaches the real edges
	var bb: = V10Layout.bleed_rect(self)
	bgc.position = bb.position
	bgc.size = bb.size
	var nw: = mini(V6Worlds.world_count(), V6Worlds.LOOK.size())  # P25: the legacy map has art for LOOK.size() worlds only (G.LEVELS is 1000 long now)
	map_h = SH * nw + BOTTOM_PAD
	map_root = Control.new()
	map_root.size = Vector2(W, map_h)
	map_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_root)
	for w in nw:
		_world_panel(w)
	_layout_items(nw)
	_build_path()
	for w in nw:
		_world_gate(w)
	for k in items.size():
		var it: Dictionary = items[k]
		if it.kind == "lv":
			it.node = _boss_node(it) if TWLevels.at(it.level).get("boss", false) else _level_node(it)
		else:
			it.node = _chest_node(it)
	_build_marker()
	_build_overlays()
	V8Header.make(self, main, "Путь · " + G.LOCS[TWLevels.at(sel).loc].name, main.back, _help)
	_build_play_button()

	var seen: = clampi(int(st.get("seen", int(G.S.unlocked))), 1, int(G.S.unlocked))
	if seen < int(G.S.unlocked) and not G.demo:
		_scroll_to_level(seen - 1, false)
		_set_progress(seen - 1)
		_place_marker(seen - 1)
		_play_progress(seen - 1, cur, args.get("pick", false))
	else:
		_scroll_to_level(sel, false)
		_set_progress(cur)
		_place_marker(cur)
		st.seen = int(G.S.unlocked)
		if args.get("pick", false):
			await get_tree().create_timer(0.5).timeout
			if is_inside_tree():
				pick_partner(sel)


func _world_top(w: int) -> float:
	return map_h - BOTTOM_PAD - (w + 1) * SH

func _world_panel(w: int) -> void :
	var look: Dictionary = V6Worlds.LOOK[w]
	var tex: Texture2D = load("res://assets/v06/map/%s.webp" % look.art)
	var top: = _world_top(w)
	var h: = SH + (FADE if w > 0 else BOTTOM_PAD)
	var r: = TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = Vector2(0, top)
	r.size = Vector2(W, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: = ShaderMaterial.new()
	m.shader = preload("res://shaders/v06/map/world.gdshader")
	m.set_shader_parameter("size", r.size)
	m.set_shader_parameter("fade_bottom", FADE if w > 0 else 1.0)
	m.set_shader_parameter("fog", look.fog)
	var open: = V6Worlds.world_open(w)
	m.set_shader_parameter("gray", 0.0 if open else 0.8)
	m.set_shader_parameter("bright", 1.0 if open else 0.62)
	m.set_shader_parameter("fog_amt", 0.0 if open else 0.6)
	r.material = m
	# 0.10 M0: on tablets the map continues past the 720 px column as dimmed mirror copies of the same panel
	# (seamless at the column edges, never stretched); they scroll with the map
	var bx: = V10Layout.bleed_rect(self)
	if bx.size.x > W + 1.0:
		for sgn in [-1, 1]:
			var mr: = TextureRect.new()
			mr.texture = tex
			mr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mr.stretch_mode = TextureRect.STRETCH_SCALE
			mr.flip_h = true
			mr.position = Vector2(sgn * W, top)
			mr.size = Vector2(W, h)
			mr.material = m
			mr.modulate = Color(0.62, 0.56, 0.66)
			mr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			map_root.add_child(mr)
	map_root.add_child(r)
	panels.append(r)

	var side: = ColorRect.new()
	side.size = r.size
	side.position = r.position
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm: = ShaderMaterial.new()
	sm.shader = preload("res://shaders/overlay.gdshader")
	sm.set_shader_parameter("tint", Color(look.deep.r, look.deep.g, look.deep.b, 1.0))
	sm.set_shader_parameter("vignette", 0.28)
	side.material = sm
	map_root.add_child(side)
	if open:
		var amb: = Fx.ambient(map_root, G.LOCS[w].fx, Vector2(W, SH))
		amb.position = Vector2(0, top)

func _layout_items(nw: int) -> void :
	items.clear()
	level_item.clear()
	var n: = 0
	for w in nw:
		var y: = _world_top(w) + SH
		for k in ORDER.size():
			y -= GAPS[k]
			var o = ORDER[k]
			var x: = W * 0.5 + 196.0 * sin(n * 0.92 + 0.35 + w * 0.6)
			var it: = {"w": w, "node": null, "dist": 0.0}
			if o is String:
				it.kind = "chest"
				it.chest = o
				it.level = -1
			else:
				it.kind = "lv"
				it.level = V6Worlds.level_index(w, o)
				if o == V6Worlds.BOSS_AT:
					x = W * 0.5
				level_item[it.level] = items.size()
			it.pos = Vector2(x, y)
			items.append(it)
			n += 1

func _build_path() -> void :

	var pts: = PackedVector2Array()
	var dist: = PackedFloat32Array()
	var total: = 0.0
	var P: Array = items.map( func(it): return it.pos)
	for i in P.size():
		if pts.size() > 0:
			total += (P[i] as Vector2).distance_to(pts[pts.size() - 1])
		items[i].dist = total
		var p0: Vector2 = P[maxi(0, i - 1)]
		var p1: Vector2 = P[i]
		if i == P.size() - 1:
			pts.append(p1)
			dist.append(total)
			break
		var p2: Vector2 = P[i + 1]
		var p3: Vector2 = P[mini(P.size() - 1, i + 2)]
		var steps: = 14
		for s in steps:
			var t: = float(s) / steps
			var t2: = t * t
			var t3: = t2 * t
			var q: = 0.5 * ((2.0 * p1) + ( - p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + ( - p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			if s > 0:
				total += q.distance_to(pts[pts.size() - 1])
			pts.append(q)
			dist.append(total)
	path_pts = pts
	path_dist = dist
	path_len = total
	var road: = Line2D.new()
	road.points = pts
	road.width = 50
	road.default_color = Color(0.16, 0.04, 0.16, 0.38)
	road.joint_mode = Line2D.LINE_JOINT_ROUND
	road.begin_cap_mode = Line2D.LINE_CAP_ROUND
	road.end_cap_mode = Line2D.LINE_CAP_ROUND
	map_root.add_child(road)
	var stones: = Line2D.new()
	stones.points = pts
	stones.width = 32
	stones.texture = G.fx("white")
	stones.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	stones.joint_mode = Line2D.LINE_JOINT_ROUND
	path_mat = ShaderMaterial.new()
	path_mat.shader = preload("res://shaders/v06/map/path.gdshader")
	path_mat.set_shader_parameter("len", total)
	path_mat.set_shader_parameter("width", 32.0)
	stones.material = path_mat
	map_root.add_child(stones)

func _point_at(d: float) -> Vector2:
	if path_pts.is_empty():
		return Vector2.ZERO
	var lo: = 0
	var hi: = path_dist.size() - 1
	if d <= 0.0:
		return path_pts[0]
	if d >= path_dist[hi]:
		return path_pts[hi]
	while hi - lo > 1:
		var mid: = (lo + hi) / 2
		if path_dist[mid] < d:
			lo = mid
		else:
			hi = mid
	var t: float = (d - path_dist[lo]) / maxf(0.001, path_dist[hi] - path_dist[lo])
	return path_pts[lo].lerp(path_pts[hi], t)

func _level_dist(i: int) -> float:
	return items[level_item.get(i, 0)].dist

func _set_progress(i: int) -> void :
	path_mat.set_shader_parameter("progress", _level_dist(i) + 1.0)


func _world_gate(w: int) -> void :
	var L: Dictionary = G.LOCS[w]
	var look: Dictionary = V6Worlds.LOOK[w]
	var open: = V6Worlds.world_open(w)
	var y: = _world_top(w) + SH - 150.0
	var g: = UI.rbox("glass", Rect2(70, y, W - 140, 140), 30, 4, 12)
	g.borders(look.accent.lerp(Color.WHITE, 0.4), look.deep)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_root.add_child(g)
	var boss: Dictionary = V6Worlds.BOSS[w]
	var av: = Common.avatar(boss.hero, Rect2(16, 18, 104, 104), "gold" if open else "plum")
	g.add_child(av)
	if not open:
		((av.get_node("Pic") as TextureRect).material as ShaderMaterial).set_shader_parameter("gray", 1.0)
	var sub: = UI.label(look.sub.to_upper(), 17, look.accent.lerp(Color.WHITE, 0.25), UI.DARK, 3, "body", 900)
	sub.position = Vector2(136, 14)
	g.add_child(sub)
	var t: = UI.title(L.name, 34, Color("fff1dc"), look.deep)
	t.position = Vector2(134, 34)
	g.add_child(t)
	if open:
		var ws: = V6Worlds.world_stars(w)
		var max_st: = V6Worlds.PER_WORLD * 3
		g.add_child(V8Art.star_rect(true, Rect2(132, 92, 34, 34)))
		var sl: = UI.label("%d/%d" % [ws, max_st], 19, Color.WHITE, UI.DARK, 3, "body", 900)
		sl.position = Vector2(168, 94)
		g.add_child(sl)
		Common.progress_bar(g, Rect2(236, 100, g.size.x - 260, 18), float(ws) / max_st, "gold")
	else:
		g.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(132, 90, 34, 34)))
		var ll: = UI.label("Победи босса главы %d" % w, 19, Color("e0cdee"), UI.DARK, 3, "body", 900)
		ll.position = Vector2(170, 94)
		g.add_child(ll)
	if L.fx == "rain":
		var ev: = UI.rbox("pink", Rect2(g.size.x - 130, -16, 120, 34), 14, 3, 6)
		g.add_child(ev)
		ev.add_child(UI.center_label(UI.label("СОБЫТИЕ", 16, Color.WHITE, Color("7a2346"), 3), Rect2(0, 0, 120, 34)))


func _node_root(p: Vector2, sz: Vector2, pivot: Vector2) -> Control:
	var c: = Control.new()
	c.size = sz
	c.position = p - pivot
	c.pivot_offset = pivot
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	map_root.add_child(c)
	return c

func _tap(c: Control, cb: Callable) -> void :
	c.gui_input.connect( func(e):
		if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _moved < 14.0 and not _anim:
			cb.call())

func _level_node(it: Dictionary) -> Control:
	var i: int = it.level
	var lv: Dictionary = TWLevels.at(i)
	var c: = _node_root(it.pos, Vector2(128, 170), Vector2(64, 64))
	var locked: = i > cur
	var stars: = G.level_stars(i)
	var hard: = int(lv.hard)
	# 0.8 map nodes (misc/node_*): the current table glows pink, every played one is gold, locked ones are dark
	var key: = "node_lock"
	if not locked:
		key = "node_cur" if i == cur else "node_done"
	if i == cur:
		var r: = Common.rays(c, Vector2(64, 60), 300, Color(1, 0.88, 0.6, 0.85), 12, 0.07, 0.7)
		r.show_behind_parent = true
	var art: = V8Art.rect(V8Art.misc(key), Rect2(4, 0, 120, 120))
	art.name = "Node"
	c.add_child(art)
	var num_txt: = str(lv.stage + 1)
	if i == cur:
		# the number sits on the pink orb
		var num: = UI.center_label(UI.title(num_txt, 44, Color("fff6ea"), Color("4a1428")), Rect2(4, 0, 120, 118))
		num.label_settings.outline_size = 8
		c.add_child(num)
	else:
		# gold sakura / lock stay visible: the number goes on a small graphite plaque under the disc
		var pw: = maxf(48.0, UI.font("title", 900).get_string_size(num_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 26.0)
		var plq: = UI.rbox("graphite", Rect2(64 - pw * 0.5, 96, pw, 34), 17, 2, 4)
		plq.borders(Color("ffe7a6") if not locked else Color("9a8a7a"), Color("8a5a1a") if not locked else Color("3a3236"))
		c.add_child(plq)
		plq.add_child(UI.center_label(UI.title(num_txt, 26, Color("fff1c2") if not locked else Color("cfc6bd"), UI.DARK), Rect2(0, -1, pw, 34)))
	if not locked and (i < cur or stars > 0):
		for q in 3:
			var s: = V8Art.star_rect(q < stars, Rect2([10.0, 46.0, 82.0][q], [-6.0, -20.0, -6.0][q], 36, 36))
			s.pivot_offset = Vector2(18, 18)
			s.rotation = [-0.25, 0.0, 0.25][q]
			c.add_child(s)
	if hard > 0 and not locked:
		var chip: = UI.rbox("red" if hard == 1 else "lav", Rect2(6, 134, 116, 28), 14, 2, 4)
		c.add_child(chip)
		chip.add_child(UI.center_label(UI.label("СЛОЖНО" if hard == 1 else "ОЧЕНЬ", 16, Color.WHITE, Color(0.3, 0.05, 0.15), 3, "body", 900), Rect2(0, 0, 116, 28)))
	if i == cur:
		var t: Tween = c.create_tween().set_loops()
		t.tween_property(c, "scale", Vector2(1.08, 1.08), 0.6).set_trans(Tween.TRANS_SINE)
		t.tween_property(c, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	_tap(c, func():
		# 0.9: a locked node denies (shake, deny sound and haptic), never the «ok» press before the refusal toast
		if i > cur:
			V9Feel.deny(c)
		else:
			V9Feel.press(c)
		open_card(i))
	return c

func _boss_node(it: Dictionary) -> Control:
	var i: int = it.level
	var lv: Dictionary = TWLevels.at(i)
	var c: = _node_root(it.pos, Vector2(220, 300), Vector2(110, 132))
	var locked: = i > cur
	if not locked:
		var r: = Common.rays(c, Vector2(110, 132), 420, Color(1, 0.5, 0.6, 0.7) if i == cur else Color(1, 0.85, 0.5, 0.45), 16, 0.05, 0.6)
		r.show_behind_parent = true

	var hero: String = lv.get("boss_hero", lv.hero)
	# 0.8: the boss wears the ornate Dragon/Celestial avatar frame (V8Art), the red «БОСС» ribbon stays under it
	var av: = V8Art.avatar(c, hero, Rect2(-10, -8, 240, 240), true)
	var pic: = av.get_node_or_null("Pic") as TextureRect
	if locked and pic != null and pic.material is ShaderMaterial:
		(pic.material as ShaderMaterial).set_shader_parameter("gray", 0.9)
	var rib: = UI.rbox("red", Rect2(40, 200, 140, 40), 18, 3, 6)
	c.add_child(rib)
	rib.add_child(UI.center_label(UI.label("БОСС", 22, Color.WHITE, Color("6a1020"), 4, "body", 900), Rect2(0, 0, 140, 40)))
	var stars: = G.level_stars(i)
	if locked:
		c.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(83, 65, 52, 52)))
	else:
		for q in 3:
			c.add_child(V8Art.star_rect(q < stars, Rect2(52 + q * 40, 242, 38, 38)))
	c.add_child(UI.center_label(UI.label(lv.get("boss_title", ""), 17, Color("fff1dc"), UI.DARK, 4, "body", 900), Rect2(-40, 276, 300, 26)))
	if i == cur:
		var t: Tween = c.create_tween().set_loops()
		t.tween_property(c, "scale", Vector2(1.06, 1.06), 0.7).set_trans(Tween.TRANS_SINE)
		t.tween_property(c, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	_tap(c, func():
		# 0.9: a locked node denies (shake, deny sound and haptic), never the «ok» press before the refusal toast
		if i > cur:
			V9Feel.deny(c)
		else:
			V9Feel.press(c)
		open_card(i))
	return c

func _chest_node(it: Dictionary) -> Control:
	var w: int = it.w
	var kind: String = it.chest
	var c: = _node_root(it.pos, Vector2(140, 150), Vector2(70, 62))
	_refresh_chest(c, w, kind)
	_tap(c, func(): _chest_tap(c, w, kind))
	return c

func _refresh_chest(c: Control, w: int, kind: String) -> void :
	for ch in c.get_children():
		ch.queue_free()
	var opened: = V6Worlds.chest_opened(w, kind)
	var ready: = V6Worlds.chest_ready(w, kind)
	if ready:
		var r: = Common.rays(c, Vector2(70, 62), 260, Color(1, 0.9, 0.5, 0.9), 10, 0.1, 0.8)
		r.show_behind_parent = true
	var img: = V8Art.rect(V8Art.misc("chest_open" if opened else "chest_closed"), Rect2(-6, -22, 152, 152))
	img.pivot_offset = Vector2(76, 136)
	c.add_child(img)
	if kind == "star":
		var chip: = UI.rbox("plum", Rect2(28, 116, 84, 30), 15, 2, 4)
		chip.borders(Color("ffe7a6"), Color("c58a2c"))
		c.add_child(chip)
		chip.add_child(V8Art.star_rect(true, Rect2(2, -1, 30, 30)))
		chip.add_child(UI.center_label(UI.label(str(V6Worlds.STAR_NEED), 16, Color.WHITE, UI.DARK, 3, "body", 900), Rect2(30, 0, 50, 30)))
	if opened:
		img.modulate = Color(0.85, 0.8, 0.9, 0.85)
	elif ready:
		var t: Tween = img.create_tween().set_loops()
		t.tween_property(img, "rotation", 0.08, 0.12)
		t.tween_property(img, "rotation", -0.08, 0.12)
		t.tween_property(img, "rotation", 0.0, 0.1)
		t.tween_interval(1.2)
		Common.badge(c, 0, Vector2(108, 4))
	elif not V6Worlds.world_open(w):
		img.modulate = Color(0.6, 0.58, 0.68)

func _chest_tap(c: Control, w: int, kind: String) -> void :
	if V6Worlds.chest_opened(w, kind):
		V9Feel.deny(c)
		main.toast("Сундук уже открыт", "gift")
		return
	if not V6Worlds.chest_ready(w, kind):
		V9Feel.deny(c)
		main.toast(V6Worlds.chest_need_text(w, kind), "gift")
		return
	var r: = V6Worlds.open_chest(w, kind)
	Sfx.play("reveal_sr")
	Fx.burst(map_root, c.position + Vector2(70, 50), "sparkle", 40, Color(1, 0.85, 0.4), 1.4)
	Fx.ring(map_root, c.position + Vector2(70, 50), Color(1, 0.9, 0.6), 2.2, 0.6)
	_refresh_chest(c, w, kind)
	_chest_popup(r, kind)
	main.refresh_currency(true)

func _chest_popup(r: Dictionary, kind: String) -> void :
	var p: = Common.popup(main, "Сундук главы" if kind == "mid" else "Звёздный сундук", 560)
	Common.rays(p, Vector2(330, 160), 420, Color(1, 0.88, 0.5, 0.8), 14, 0.08, 0.8)
	var img: = V8Art.rect(V8Art.misc("chest_open"), Rect2(220, 50, 220, 220))
	p.add_child(img)
	UI.pop_in(img, 0.1, 0.3)
	var y: = 300.0
	Common.chip(p, V8Art.cur("gem"), "+%d" % int(r.gems), Rect2(50, y, 170, 58), "plum", 24)
	Common.chip(p, V8Art.cur("coin"), "+%s" % UI.fmt(int(r.coins)), Rect2(232, y, 170, 58), "plum", 24)
	var hero: String = r.hero
	var sh: = int(G.S.shards.get(hero, 0))
	p.add_child(Common.avatar(hero, Rect2(418, y - 4, 66, 66), "pink"))
	var sl: = UI.label("+%d осколок\n%s %d/%d" % [int(r.shard), G.HEROES[hero].name, mini(sh, G.SHARDS_NEED), G.SHARDS_NEED], 17, UI.INK, UI.DARK, 3, "body", 900)
	sl.position = Vector2(492, y - 2)
	p.add_child(sl)
	var b: = JButton.make("Забрать", "pink", Rect2(150, 410, 360, 96), null, 34)
	b.shine_every = 2.0
	b.pressed.connect( func():
		main.fly_gems(b.get_global_rect().get_center(), 6)
		Common.close_popup(p))
	p.add_child(b)


func _build_marker() -> void :
	marker = Control.new()
	marker.size = Vector2(90, 110)
	marker.pivot_offset = Vector2(45, 110)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_root.add_child(marker)
	var bob: = Control.new()
	bob.size = marker.size
	bob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(bob)
	marker_pin = Polygon2D.new()
	marker_pin.polygon = PackedVector2Array(PIN_DOWN)
	marker_pin.color = Color("f2799f")
	bob.add_child(marker_pin)
	var hero: String = G.S.level_partner if G.hero_unlocked(G.S.level_partner) else "mc"
	# 0.8: the heroine in the gold avatar frame (V8Art), like every other portrait
	var av: = V8Art.avatar(bob, hero, Rect2(0, -4, 90, 90))
	av.name = "MarkerAvatar"
	var t: Tween = bob.create_tween().set_loops()
	t.tween_property(bob, "position:y", -10.0, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(bob, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE)

# pin shapes: under the avatar pointing down, or at its side pointing at the node
const PIN_DOWN: = [Vector2(30, 74), Vector2(60, 74), Vector2(45, 100)]
const PIN_LEFT: = [Vector2(8, 26), Vector2(8, 56), Vector2(-14, 41)]
const PIN_RIGHT: = [Vector2(82, 26), Vector2(82, 56), Vector2(104, 41)]

# while walking along the path the marker floats above the point it passes
func _marker_pos(p: Vector2, boss: = false) -> Vector2:

	return p - Vector2(45, 110) + (Vector2(-140, 30) if boss else Vector2(0, -70))

# Resting spot next to level i's node: above it when that is clear, otherwise beside it on the side away from the
# path, so the marker never sits on the neighbouring (locked) node and hides its lock. Returns [position, pin].
func _marker_rest(i: int) -> Array:
	var it: Dictionary = items[level_item.get(i, 0)]
	var p: Vector2 = it.pos
	if TWLevels.at(i).get("boss", false):
		return [_marker_pos(p, true), PIN_DOWN]
	var cands: = [
		[p + Vector2(-45, -180), PIN_DOWN],
		[p + Vector2(66, -49), PIN_LEFT],
		[p + Vector2(-156, -49), PIN_RIGHT],
	]
	# neighbouring nodes (disc + stars above + number plaque below)
	var others: = []
	for j in [i - 2, i - 1, i + 1, i + 2]:
		if j >= 0 and j < G.LEVELS.size() and level_item.has(j):
			var np: Vector2 = items[level_item[j]].pos
			var big: bool = TWLevels.at(j).get("boss", false)
			others.append(Rect2(np - Vector2(100, 110), Vector2(200, 240)) if big else Rect2(np - Vector2(64, 86), Vector2(128, 222)))
	var best: Array = cands[0]
	var best_score: = INF
	for k in cands.size():
		var r: = Rect2(cands[k][0] + Vector2(0, -10), Vector2(90, 110))
		var score: = 0.0
		for o in others:
			var ov: Rect2 = r.intersection(o)
			score += ov.get_area()
		if r.position.x < 6.0 or r.end.x > W - 6.0:
			score += 100000.0
		score += float(k) * 50.0
		if score < best_score:
			best_score = score
			best = cands[k]
	return best

func _place_marker(i: int) -> void :
	var rest: = _marker_rest(i)
	marker.position = rest[0]
	if marker_pin:
		marker_pin.polygon = PackedVector2Array(rest[1])

func _build_overlays() -> void :
	for spec in [[0.0, 270.0, Color(0.12, 0.04, 0.16, 0.85), Color(0.12, 0.04, 0.16, 0.0)], [H - 380.0, 380.0, Color(0.12, 0.04, 0.16, 0.0), Color(0.12, 0.04, 0.16, 0.9)]]:
		var g: = Gradient.new()
		g.set_color(0, spec[2])
		g.set_color(1, spec[3])
		var gt: = GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		gt.width = 4
		gt.height = 64
		add_child(UI.tex(gt, Rect2(0, spec[0], W, spec[1]), false))

func _help() -> void :
	var p: = Common.popup(main, "Путь", 520)
	var l: = UI.label("Партии идут по главам. Звёзды: без переполнений лотка и без помощи (подсказка, отмена, перемешать) — три, с одной-двумя — две, иначе одна.\n\nСундук в середине главы открывается после её четвёртой партии, второй — за звёзды главы. В конце главы ждёт босс — хозяйка стола. Победа даёт очки ранга, кристаллы и осколки героинь.", 21, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(40, 64)
	l.size = Vector2(580, 380)
	l.custom_minimum_size = Vector2(580, 0)
	p.add_child(l)

func _build_play_button() -> void :
	var lv: Dictionary = TWLevels.at(cur)
	var boss: bool = lv.get("boss", false)
	play_btn = JButton.make(("Босс %s" if boss else "Партия %s") % lv.code, "red" if boss else "pink", Rect2(W * 0.5 - 220, H - 132 - 134, 440, 104), null, 36)
	play_btn.set_sub(G.LOCS[lv.loc].name, 19)
	play_btn.shine_every = 2.2
	play_btn.pressed.connect( func():
		_scroll_to_level(cur, true)
		open_card(cur))
	add_child(play_btn)
	UI.slide_in(play_btn, Vector2(0, 60), 0.15, 0.4)


func _clamp_y(y: float) -> float:
	return clampf(y, H - map_h, 0.0)

func _scroll_to_level(i: int, animate: bool) -> void :
	var it: Dictionary = items[level_item.get(i, 0)]
	_scroll_to(it.pos.y, animate)

func _scroll_to(y: float, animate: bool, dur: = 0.5) -> void :
	# 0.8: focus a bit above the middle — the CTA and navbar cover the bottom 270 px; when a chapter card
	# (at the bottom of each chapter) would land behind them, scroll it up clear of the CTA
	var t: = H * 0.44 - y
	var cta_top: = H - 132.0 - 134.0 - 12.0
	for w in V6Worlds.world_count():
		var gy: = _world_top(w) + SH - 150.0
		var top: = t + gy
		if top < H and top + 140.0 > cta_top:
			t -= top + 140.0 - cta_top
	var target: = _clamp_y(t)
	_vel = 0.0
	if animate:
		create_tween().tween_property(map_root, "position:y", target, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		map_root.position.y = target

func _popup_open() -> bool:
	for c in main.overlay.get_children():
		if c.has_meta("popup") and not c.has_meta("closing"):
			return true
	return false

func _input(e: InputEvent) -> void :
	if not is_visible_in_tree() or _anim:
		return
	if e is InputEventScreenTouch:
		# 0.10 M0: the touch is a viewport point, the header / nav band limits are this screen's (it sits below a cut-out)
		var ty: float = V10Layout.local_of(self, e.position).y
		if e.pressed and ty > V8Header.CONTENT_Y and ty < H - 132 and not _popup_open():
			_drag = true
			_drag_y = e.position.y
			_moved = 0.0
			_vel = 0.0
		elif not e.pressed:
			_drag = false
	elif e is InputEventScreenDrag and _drag:
		var dy: float = e.position.y - _drag_y
		_drag_y = e.position.y
		_moved += abs(dy)
		_vel = dy / max(0.001, get_process_delta_time())
		map_root.position.y = _clamp_y(map_root.position.y + dy)

func _process(dt: float) -> void :
	if not _drag and abs(_vel) > 5.0:
		map_root.position.y = _clamp_y(map_root.position.y + _vel * dt)
		_vel *= pow(0.03, dt)


func _play_progress(from_i: int, to_i: int, pick: bool) -> void :
	_anim = true
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return
	var d0: = _level_dist(from_i)
	var d1: = _level_dist(to_i)
	var boss_to: bool = TWLevels.at(to_i).get("boss", false)
	var to_it: Dictionary = items[level_item[to_i]]
	var new_node: Control = to_it.node
	if new_node:
		new_node.modulate.a = 0.35
	var dur: = clampf((d1 - d0) / 420.0, 0.8, 2.2)
	_scroll_to(to_it.pos.y, true, dur)
	Sfx.play("sparkle")
	var t: = create_tween()
	t.tween_method( func(d: float):
		path_mat.set_shader_parameter("progress", d)
		marker_pin.polygon = PackedVector2Array(PIN_DOWN)
		marker.position = _marker_pos(_point_at(d), false), d0, d1, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	if not is_inside_tree():
		return
	_place_marker(to_i)
	UI.punch(marker, 0.2)
	if new_node:
		new_node.modulate.a = 1.0
		UI.punch(new_node, 0.25, 0.5)
		Fx.burst(map_root, to_it.pos, "sparkle", 30, Color(1, 0.9, 0.6), 1.2)
		Fx.ring(map_root, to_it.pos, Color(1, 0.9, 0.6), 2.0, 0.5)
	Sfx.play("star1")

	var w_from: int = TWLevels.at(from_i).loc
	var w_to: int = TWLevels.at(to_i).loc
	if w_to != w_from and w_to < panels.size():
		var m: ShaderMaterial = panels[w_to].material
		var ft: = create_tween().set_parallel()
		ft.tween_property(m, "shader_parameter/fog_amt", 0.0, 1.2)
		ft.tween_property(m, "shader_parameter/gray", 0.0, 1.2)
		ft.tween_property(m, "shader_parameter/bright", 1.0, 1.2)
		Sfx.play("reveal_ssr")
		var rib: = Common.ribbon(self, "Глава %d · %s" % [w_to + 1, G.LOCS[w_to].name], Rect2(W * 0.5 - 300, H * 0.36, 600, 96), "pink", 34)
		UI.pop_in(rib, 0.0, 0.5)
		var rt: = rib.create_tween()
		rt.tween_interval(1.8)
		rt.tween_property(rib, "modulate:a", 0.0, 0.4)
		rt.tween_callback(rib.queue_free)
		await get_tree().create_timer(1.6).timeout
	elif boss_to:
		main.toast("Впереди босс: %s" % TWLevels.at(to_i).get("boss_title", ""), "star")
	V6Worlds.state().seen = int(G.S.unlocked)
	G.save()
	_anim = false
	_refresh_states()
	if pick and is_inside_tree():
		await get_tree().create_timer(0.35).timeout
		if is_inside_tree():
			pick_partner(sel)

func _refresh_states() -> void :
	for it in items:
		if it.kind == "chest" and it.node:
			_refresh_chest(it.node, it.w, it.chest)


func open_card(i: int) -> void :
	if i > cur:
		main.toast(_t("levels.locked", "Сначала сыграй партию %s") % TWLevels.at(i - 1).code, "star")
		return
	sel = i
	var lv: Dictionary = TWLevels.at(i)
	var w: int = lv.loc
	var look: Dictionary = V6Worlds.LOOK[w]
	var boss: bool = lv.get("boss", false)
	var ph: = 960.0 if boss else 860.0
	var p: = Common.popup(main, ("Босс %s" if boss else "Партия %s") % lv.code, ph)
	var y: = 52.0
	if boss:
		p.add_child(Common.avatar(lv.boss_hero, Rect2(30, y, 130, 130), "gold"))
		var bl: = UI.label(_t("levels.boss", "Хозяйка стола").to_upper(), 16, Color("ff9fb8"), UI.DARK, 3, "body", 900)
		bl.position = Vector2(180, y - 4)
		p.add_child(bl)
		var tt: = UI.title(lv.boss_title, 32, Color("fff1dc"), look.deep)
		tt.position = Vector2(178, y + 14)
		p.add_child(tt)
		var q: = UI.label("«%s»" % lv.boss_line, 19, Color("ffd9e6"), UI.DARK, 2, "body", 800)
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.custom_minimum_size = Vector2(450, 0)
		q.position = Vector2(180, y + 60)
		q.size = Vector2(450, 84)
		p.add_child(q)
		y += 142.0
	else:
		var wl: = UI.label("%s · %s" % [look.sub, G.LOCS[w].name], 20, look.accent.lerp(Color.WHITE, 0.3), UI.DARK, 3, "body", 900)
		wl.position = Vector2(0, y)
		wl.size = Vector2(660, 30)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(wl)
		y += 34.0

	var stn: = G.level_stars(i)
	for q in 3:
		var big: = q == 1
		var sz: = 74.0 if big else 60.0
		var s: = V8Art.star_rect(q < stn, Rect2(330 - 115 + q * 115 - sz * 0.5, y + (0.0 if big else 12.0), sz, sz))
		p.add_child(s)
		if q < stn:
			UI.pop_in(s, 0.1 + q * 0.08, 0.3)
	y += 84.0

	var n_pos: = TWFree.gen_layout(lv.duplicate(true)).size()
	var nt: = n_pos - n_pos % 2
	# 0.8: every info tag is the same graphite chip; a small coloured dot says what kind of tag it is
	var tags: Array = [["%d фишек" % nt, Color("f2e6d0")], [V6Layouts.shape_name(lv.shape), Color("c8b6ff")]]
	if lv.gold > 0:
		tags.append(["Золото", Color("ffd34d")])
	if lv.ice > 0:
		tags.append(["Лёд", Color("8fd8ff")])
	if lv.hidden:
		tags.append(["Тайные", Color("d08cff")])
	if lv.get("upper", "") != "":
		tags.append([V6Layouts.UPPER_NAMES.get(lv.upper, ""), Color("7fe0b4")])
	tags.append(["%d слоёв" % lv.layers if lv.layers >= 5 else "%d слоя" % lv.layers, Color("e9a8c4")])
	if int(lv.hard) > 0:
		tags.append([_t("levels.hard%d" % lv.hard, G.HARD_NAMES[lv.hard]), Color("ff6f7f")])
	# the preview takes the height the popup has left over (tags may wrap to a second row), so there is no dead
	# band above the buttons
	var tag_rows: = 1
	var tx: = 30.0
	for tg in tags:
		var tw0: float = UI.font("body", 900).get_string_size(tg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 50.0
		if tx + tw0 > 630.0:
			tx = 30.0
			tag_rows += 1
		tx += tw0 + 8.0
	var pv_h: = clampf((ph - 122.0 - 18.0) - y - 12.0 - (tag_rows * 46.0 + 8.0) - 64.0, 280.0, 440.0)
	# 0.8: the layout preview sits on this chapter's table (the board's own felt-and-frame shader and colours) and
	# its tiles use the tile-back art, so it reads as the board the player is about to sit at
	var pb: = Control.new()
	pb.position = Vector2(30, y)
	pb.size = Vector2(600, pv_h)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(pb)
	_felt(pb, String(G.LOCS[w].bg), Rect2(Vector2.ZERO, pb.size))
	var pv: = V6LayoutPreview.new()
	pv.position = Vector2(34, 30)
	pv.size = Vector2(532, pv_h - 60.0)
	pb.add_child(pv)
	pv.setup(lv.duplicate(true), look.accent)
	y += pv_h + 12.0

	var x: = 30.0
	var ty: = y
	for tg in tags:
		var tw: float = UI.font("body", 900).get_string_size(tg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 50.0
		if x + tw > 630.0:
			x = 30.0
			ty += 46.0
		var ch: = UI.rbox("graphite", Rect2(x, ty, tw, 38), 19, 2, 4)
		ch.borders(Color("ffe7a6").darkened(0.15), Color("6a4a20"))
		p.add_child(ch)
		var dot: = UI.rbox("gold", Rect2(14, 13, 12, 12), 6, 1, 2)
		dot.colors(tg[1].lightened(0.25), tg[1].darkened(0.2))
		ch.add_child(dot)
		ch.add_child(UI.center_label(UI.label(tg[0], 18, Color("f6ecdc"), UI.DARK, 2, "body", 900), Rect2(30, 0, tw - 40, 38)))
		x += tw + 8.0
	y = ty + 54.0

	# 0.8: the reward row is one chip style: crystals, the item, «Осколок · Рин» with her portrait inside its chip
	var rl: = UI.label("Награда", 18, Color("cbb5dc"), UI.DARK, 2, "body", 900)
	rl.position = Vector2(34, y + 14)
	p.add_child(rl)
	Common.chip(p, V8Art.cur("gem"), str(lv.reward.gems), Rect2(130, y, 130, 52), "plum", 22)
	var rx: = 272.0
	if lv.reward.has("item"):
		var itd: Dictionary = G.ITEM[lv.reward.item]
		var ib: = UI.rbox("plum", Rect2(rx, y, 64, 52), 26, 3, 8)
		ib.borders(Color("ffe7a6"), Color("c58a2c"))
		p.add_child(ib)
		ib.add_child(UI.tex(G.item_tex(itd), Rect2(12, 6, 40, 40)))
		rx += 76.0
	var sh_h: String = lv.shard
	var sc: = Common.chip(p, null, "Осколок · %s" % G.HEROES[sh_h].name, Rect2(rx, y, 630.0 - rx, 52), "plum", 20)
	sc.add_child(Common.avatar(sh_h, Rect2(4, 4, 44, 44), "gold"))
	var scl: Label = sc.get_node("L")
	scl.position.x = 56.0
	scl.size.x = sc.size.x - 66.0
	y += 64.0

	var skin_btn: = JButton.make(_t("levels.skins", "Фишки"), "lav", Rect2(30, ph - 122, 190, 92), G.tile_tex(G.ITEM[G.S.get("skin", "s_sakura")].tile), 22)
	skin_btn.pressed.connect( func(): Common.skin_picker(main, func(): pass))
	p.add_child(skin_btn)
	var go: = JButton.make(_t("levels.sit", "Сесть за стол"), "red" if boss else "pink", Rect2(232, ph - 122, 398, 92), null, 32)
	go.shine_every = 2.0
	go.pressed.connect( func():
		Common.close_popup(p)
		pick_partner(i))
	p.add_child(go)

# the board table under the level-card preview: V6BoardTable's felt / frame shader with this chapter's theme
func _felt(parent: Control, bg: String, r: Rect2) -> void :
	var th: Dictionary = V6BoardTable.theme_for(bg)
	var m: = 8.0
	var cr: = ColorRect.new()
	cr.position = r.position - Vector2(m, m)
	cr.size = r.size + Vector2(m, m) * 2.0
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: = ShaderMaterial.new()
	mat.shader = V6BoardTable.SHADER
	cr.material = mat
	mat.set_shader_parameter("size", cr.size)
	mat.set_shader_parameter("margin", m)
	mat.set_shader_parameter("frame_w", 14.0)
	mat.set_shader_parameter("radius", 22.0)
	mat.set_shader_parameter("noise", load("res://assets/v06/board/table_noise.png"))
	for key in ["frame_a", "frame_b", "trim", "mat_a", "mat_b", "pat_col"]:
		mat.set_shader_parameter(key, th[key])
	mat.set_shader_parameter("pat_alpha", th.pat_alpha)
	mat.set_shader_parameter("pattern", th.pattern)
	mat.set_shader_parameter("pat_scale", th.pat_scale * 0.6)
	mat.set_shader_parameter("fibre", th.fibre)
	mat.set_shader_parameter("neon", th.get("neon", 0.0))
	var lc: Color = th.lamp_col
	mat.set_shader_parameter("lamp_col", Vector3(lc.r, lc.g, lc.b))
	mat.set_shader_parameter("lamp_k", th.lamp_k)
	mat.set_shader_parameter("t", G.time)
	parent.add_child(cr)

func pick_skin() -> void :
	Common.skin_picker(main, func(): pass)


func pick_partner(level: int) -> void :
	var heroes: Array = G.HERO_ORDER
	var rh: = 150.0
	var p: = Common.popup(main, _t("levels.partner_t", "Кто сядет рядом?"), 90 + heroes.size() * (rh + 10) + 130)
	var cur_h: = [G.S.level_partner if G.hero_unlocked(G.S.level_partner) else "mc"]
	partner_rows.clear()
	for i in heroes.size():
		var h: String = heroes[i]
		var unl: = G.hero_unlocked(h)
		var row: = UI.rbox("glass", Rect2(24, 60 + i * (rh + 10), 612, rh), 24, 3, 8)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		p.add_child(row)
		var av: = Common.avatar(h, Rect2(10, 8, 100, 100), "gold" if unl else "plum")
		row.add_child(av)
		if not unl:
			((av.get_node("Pic") as TextureRect).material as ShaderMaterial).set_shader_parameter("gray", 1.0)
			av.add_child(V8Art.rect(V8Art.icon("lock"), Rect2(30, 30, 40, 40)))
			var nl0: = UI.label(G.HEROES[h].name, 24, Color("9a8a9a"), Color.WHITE, 3, "body", 900)
			nl0.position = Vector2(128, 10)
			row.add_child(nl0)
			var sh: = mini(int(G.S.shards.get(h, 0)), G.SHARDS_NEED)
			var hl0: = UI.label(_t("levels.shards", "Портрет: %d/%d осколков · или Желания") % [sh, G.SHARDS_NEED], 18, Color("9a6a8a"))
			hl0.position = Vector2(128, 48)
			row.add_child(hl0)
			Common.progress_bar(row, Rect2(128, 78, 300, 18), float(sh) / G.SHARDS_NEED, "gold")
			row.modulate = Color(1, 1, 1, 0.85)
			# 0.9: a locked heroine answers a tap with a clear «no» (shake, deny sound and haptic) and how to unlock her
			var hn: String = G.HEROES[h].name
			row.gui_input.connect( func(e):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					V9Feel.deny(row)
					main.toast(_t("levels.locked_hero", "%s ещё не с тобой: собери портрет из осколков") % hn, "lock"))
			continue
		var nl: = UI.label(G.HEROES[h].name, 26, UI.INK, Color.WHITE, 3, "body", 900)
		nl.position = Vector2(132, 12)
		row.add_child(nl)
		Common.chip(row, V8Art.icon("heart"), "ур. %d" % G.aff_level(h), Rect2(450, 14, 140, 40), "pink", 18)
		# 0.9 (spec §B): one name for the ability everywhere — «Ульта», named per equipped outfit (HEROINES §5)
		var u_id: = V9Ults.for_hero(h)
		var u_name: String = String(V9Ults.get_ult(u_id).get("name", G.SKILLS[h].name))
		var u_mod: = V9Ults.mod(u_id)
		var pk_t: String = _t("levels.skill", "Умение «%s»: %s") % [u_name, String(V9Ults.core(h).get("desc", G.SKILLS[h].desc))]
		var pk_w: = 452.0 if u_mod == "" else 408.0
		var pk_fs: = 17
		while pk_fs > 16 and UI.font("body", 900).get_string_size(pk_t, HORIZONTAL_ALIGNMENT_LEFT, -1, pk_fs).x > pk_w:
			pk_fs -= 1
		var pk: = UI.label(pk_t, pk_fs, Color("ffd98a"), UI.DARK, 2, "body", 900)
		pk.position = Vector2(132, 52)
		pk.size = Vector2(pk_w, 28)
		if u_mod != "":
			# the outfit modifier as a small lacquer badge with its gold glyph (V9ModIcon, П/О/Л/В/Ц/С)
			var mb: = UI.rbox("plum", Rect2(132 + pk_w + 8, 50, 34, 34), 17, 2, 4)
			mb.set_param("border_top", Color("ffe7a6")).set_param("border_bottom", Color("c58a2c"))
			mb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mb.tooltip_text = String(V9Ults.MODS.get(u_mod, {}).get("name", ""))
			row.add_child(mb)
			var mi: = V9ModIcon.make(u_mod, 24.0)
			mi.position = Vector2(5, 5)
			mb.add_child(mi)
		pk.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		pk.clip_text = true
		row.add_child(pk)
		var bonus: = UI.label(_t("levels.perk", "Перк: %s") % G.PERKS[h], 16, Color("e9cfe0"), UI.DARK, 2, "body", 800)
		bonus.position = Vector2(132, 84)
		bonus.size = Vector2(452, 24)
		bonus.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bonus.clip_text = true
		row.add_child(bonus)
		row.set_meta("b0", [row.mat.get_shader_parameter("border_top"), row.mat.get_shader_parameter("border_bottom")])
		V7Passives.partner_row(row, h, TWLevels.at(level))
		partner_rows[h] = row
		row.gui_input.connect( func(e):
			if e is InputEventMouseButton and e.pressed:
				UI.tap(row, 0.04)
				cur_h[0] = h
				Sfx.say(h, "greet")
				for k in partner_rows:
					var r: RBox = partner_rows[k]
					if not G.hero_unlocked(k):
						continue
					_pick_style(r, k == h))
		if h == cur_h[0]:
			_pick_style(row, true)
	partner_go_btn = JButton.make(_t("levels.deal", "Раздать фишки"), "pink", Rect2(130, p.size.y - 120, 400, 96), null, 32)
	partner_go_btn.shine_every = 2.0
	partner_go_btn.pressed.connect( func():
		G.S.level_partner = cur_h[0]
		G.current_level = level
		G.save()
		main.go("play", {"level": level, "partner": cur_h[0]}))
	p.add_child(partner_go_btn)


# 0.8: the chosen partner card stays dark (light text keeps its contrast) with a pink rim
func _pick_style(r: RBox, on: bool) -> void :
	if on:
		r.colors(Color(0.36, 0.15, 0.26, 0.95), Color(0.2, 0.07, 0.15, 0.96)).borders(Color("ffb3c8"), Color("e0457b"))
	else:
		r.colors(UI.PAL.glass[0], UI.PAL.glass[1])
		var b0: Array = r.get_meta("b0", [])
		if b0.size() == 2 and b0[0] is Color and b0[1] is Color:
			r.borders(b0[0], b0[1])

func dev_act(a: String) -> void :
	match a:
		"pick":
			pick_partner(sel)
		"skin":
			pick_skin()
		"card":
			open_card(cur)
		"top":
			_scroll_to(0.0, false)
		"back":
			main.android_back()
		"help":
			_help()
		_:
			if a.begins_with("w") and a.length() == 2:
				_scroll_to(_world_top(int(a.substr(1))) + SH * 0.5, false)
			elif a.begins_with("y"):
				map_root.position.y = _clamp_y( - float(a.substr(1)))
			elif a.begins_with("lv"):
				var i: = int(a.substr(2))
				_scroll_to_level(i, false)
				open_card(i)
			elif a.begins_with("chest"):
				var w: = int(a.substr(5))
				for it in items:
					if it.kind == "chest" and it.w == w and it.chest == "mid":
						_scroll_to(it.pos.y, false)
						_chest_tap(it.node, w, "mid")
