class_name V10PathMap
extends Control

# 0.10 · Карта Пути (0.10-spec П1–П3). A screen for main.SCREENS (build(main, args)).
#
# One arc (100 levels) per map: 10 chapters climb from the bottom (chapter 1) to the top (the Legendary crown),
# arc plate on top (cover, «Арка 1 · Пробуждение чайной · 37/91», «Арки»), the CTA «Играть» above the navbar.
# Chapter sections are virtualised: only the chapters around the view live in the tree (≈ current ±2).
# Peaks are side rocks to the right of the chapter boss; chests (chapter / star 25★) sit to the left of it.
#
# args: {arc, select: i (opens the card), won: {i, stars} (plays the progress animation), from_fail: {i, log}}

const Gen = preload("res://scripts/v10/levels/level_gen.gd")
const State = preload("res://scripts/v10/path/path_state.gd")
const Rules = preload("res://scripts/v10/path/path_rules.gd")
const Boost = preload("res://scripts/v10/path/path_boosters.gd")
const PNode = preload("res://scripts/v10/path/path_node.gd")
const Card = preload("res://scripts/v10/path/path_card.gd")
const Dlg = preload("res://scripts/v10/path/path_dialogs.gd")
const PFx = preload("res://scripts/v10/path/path_fx.gd")

const CH: = 1260.0          # chapter section height
const SPAN: = 936.0         # vertical span of the main nodes of a chapter
const NODE0: = 170.0        # first node above the section bottom
const TOP_INSET: = 100.0    # main topbar
const NAV_INSET: = 136.0    # main navbar
const HDR_H: = 176.0        # arc plate
const START_H: = 360.0      # bottom of the content: arc start + room for CTA and navbar
const CW_MAX: = 760.0
# node x (share of the content column) bottom → top, 10 or 9 main nodes; odd chapters are mirrored
const XP10: = [0.50, 0.68, 0.76, 0.60, 0.38, 0.26, 0.38, 0.62, 0.34, 0.50]
const XP9: = [0.50, 0.70, 0.70, 0.46, 0.28, 0.40, 0.64, 0.34, 0.50]

# the runner (and tests) can take over «Играть»; default: main.go("play", {level, v10_cfg})
static var on_play: Callable

var main
var W: = 720.0
var H: = 1280.0
var CW: = 720.0
var X0: = 0.0
var arc: = 0
var cur: = 0
var scroll: = 0.0
var content_h: = 0.0
var gate_h: = 0.0
var map_root: Control
var sections: = {}
var nodes: = {}
var chests: = {}
var marker: Control
var hdr: Control
var cta: JButton
var jump_btn: JButton
var line_done: Line2D
var line_rest: Line2D
var glow_done: Line2D
var path_pts: = PackedVector2Array()
var path_idx: = []          # level index for each node point of path_pts (sampled points in between)
var _drag: = false
var _drag_y: = 0.0
var _moved: = 0.0
var _vel: = 0.0
var _press = null
var _last_vis: = Vector2i(-99, -99)
var _built_ms: = 0.0
var _t: = 0.0
var ambient: Node2D


func build(m, args: Dictionary = {}) -> void:
	var t0: = Time.get_ticks_usec()
	main = m
	W = size.x
	H = size.y
	CW = minf(W, CW_MAX)
	X0 = (W - CW) * 0.5
	clip_contents = true
	if main and main.has_method("show_chrome"):
		main.show_chrome(true, true)
	if Engine.get_main_loop() and Sfx.has_method("music"):
		Sfx.music("menu")
	State.st()
	cur = State.current()
	arc = clampi(int(args.get("arc", State.arc_of(cur))), 0, Gen.WORLDS - 1)
	if not State.arc_released(arc):
		arc = State.arc_of(cur)
	gate_h = TOP_INSET + HDR_H + 380.0
	content_h = gate_h + 10.0 * CH + START_H

	var base: = ColorRect.new()
	base.size = size
	base.color = Color(0.075, 0.05, 0.09)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	map_root = Control.new()
	map_root.size = Vector2(W, content_h)
	map_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_root)
	_build_path_lines()
	_build_gate()
	_build_start()
	var wfx: String = str(Gen.WORLD[arc].fx)
	ambient = Fx.ambient(self, wfx, size)
	_build_marker()
	_build_header()
	_build_cta()
	var focus: = cur if State.arc_of(cur) == arc else arc * Gen.PER_WORLD
	scroll = _clamp_scroll(_node_y(focus) - H * 0.56)
	_apply_scroll(true)
	_built_ms = (Time.get_ticks_usec() - t0) / 1000.0
	set_meta("build_ms", _built_ms)
	_intro_anim()
	if args.has("won"):
		_after_win(args.won)
	elif args.has("select"):
		var s: = int(args.select)
		call_deferred("open_card", s)


# ------------------------------------------------------------------ geometry

func _sec_top(c: int) -> float:
	return gate_h + (9 - c) * CH


func _mains(gc: int) -> Array:
	var out: = []
	for k in Gen.CHAPTER:
		var i: = gc * Gen.CHAPTER + k
		if not Gen.is_peak(i):
			out.append(i)
	return out


func _mirror(c: int) -> bool:
	return c % 2 == 1


func _fx(c: int, f: float) -> float:
	return X0 + CW * (1.0 - f if _mirror(c) else f)


# centre of level i in map_root coordinates
func _pos(i: int) -> Vector2:
	var c: = State.chapter_in_arc(i)
	var gc: = State.gchapter(i)
	var top: = _sec_top(c)
	if Gen.is_peak(i):
		var b: = _pos(State.boss_of(i))
		return Vector2(_fx(c, 0.83), b.y + 96.0)
	var ms: = _mains(gc)
	var m: = ms.find(i)
	var pat: Array = XP10 if ms.size() == 10 else XP9
	var y: = top + CH - NODE0 - SPAN * float(m) / float(ms.size() - 1)
	return Vector2(_fx(c, float(pat[m])), y)


func _node_y(i: int) -> float:
	return _pos(i).y


func _chest_pos(gc: int, kind: String) -> Vector2:
	var c: = gc % 10
	var b: = _pos(gc * Gen.CHAPTER + Gen.CHAPTER - 1)
	if kind == "chapter":
		return Vector2(_fx(c, 0.15), b.y - 6.0)
	return Vector2(_fx(c, 0.15), b.y + 150.0)


# ------------------------------------------------------------------ path

func _build_path_lines() -> void:
	path_pts = PackedVector2Array()
	path_idx = []
	var mains: = []
	for k in Gen.PER_WORLD:
		var i: = arc * Gen.PER_WORLD + k
		if not Gen.is_peak(i):
			mains.append(i)
	var ctrl: = PackedVector2Array()
	for i in mains:
		ctrl.append(_pos(i))
	# Catmull-Rom through the node centres, 10 samples a segment
	for k in ctrl.size() - 1:
		var p0: = ctrl[maxi(k - 1, 0)]
		var p1: = ctrl[k]
		var p2: = ctrl[k + 1]
		var p3: = ctrl[mini(k + 2, ctrl.size() - 1)]
		for s in 10:
			var t: = s / 10.0
			path_pts.append(_cr(p0, p1, p2, p3, t))
			path_idx.append(mains[k])
	path_pts.append(ctrl[ctrl.size() - 1])
	path_idx.append(mains[mains.size() - 1])
	var shadow: = Line2D.new()
	shadow.points = path_pts
	shadow.width = 26.0
	shadow.default_color = Color(0.05, 0.02, 0.06, 0.45)
	shadow.joint_mode = Line2D.LINE_JOINT_ROUND
	shadow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.end_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.z_index = 1
	map_root.add_child(shadow)
	line_rest = Line2D.new()
	line_rest.points = path_pts
	line_rest.width = 12.0
	line_rest.texture = _dash_tex()
	line_rest.texture_mode = Line2D.LINE_TEXTURE_TILE
	line_rest.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line_rest.default_color = Color(1.0, 0.95, 0.88, 0.7)
	line_rest.z_index = 1
	map_root.add_child(line_rest)
	glow_done = Line2D.new()
	glow_done.width = 30.0
	glow_done.default_color = Color(1.0, 0.8, 0.45, 0.22)
	glow_done.joint_mode = Line2D.LINE_JOINT_ROUND
	glow_done.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow_done.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow_done.z_index = 1
	map_root.add_child(glow_done)
	line_done = Line2D.new()
	line_done.width = 12.0
	line_done.gradient = _gold_grad()
	line_done.joint_mode = Line2D.LINE_JOINT_ROUND
	line_done.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line_done.end_cap_mode = Line2D.LINE_CAP_ROUND
	line_done.z_index = 1
	map_root.add_child(line_done)
	_set_done_to(_done_upto())


func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: = t * t
	var t3: = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _dash_tex() -> Texture2D:
	var img: = Image.create(32, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in 18:
		for y in 8:
			var dy: = absf(y - 3.5) / 4.0
			var edge: = minf(float(x), 17.0 - float(x)) / 3.0
			img.set_pixel(x + 7, y, Color(1, 1, 1, clampf(minf(1.0 - dy * dy, edge), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _gold_grad() -> Gradient:
	var g: = Gradient.new()
	g.colors = PackedColorArray([Color("ffe3a0"), Color("f1b54e"), Color("ffe9b8")])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	return g


# the last sampled point index of the cleared part of the path (up to the current node)
func _done_upto() -> int:
	var target: = cur
	if State.arc_of(cur) > arc:
		return path_pts.size() - 1
	if State.arc_of(cur) < arc:
		return 0
	for k in path_idx.size():
		if int(path_idx[k]) >= target:
			return k
	return path_pts.size() - 1


func _set_done_to(k: int) -> void:
	k = clampi(k, 0, path_pts.size() - 1)
	var pts: = path_pts.slice(0, k + 1)
	if pts.size() < 2:
		pts = PackedVector2Array()
	line_done.points = pts
	glow_done.points = pts


# ------------------------------------------------------------------ sections (virtualised)

func _visible_range() -> Vector2i:
	var top: = scroll - 700.0
	var bot: = scroll + H + 700.0
	var lo: = 99
	var hi: = -1
	for c in 10:
		var y0: = _sec_top(c)
		if y0 + CH >= top and y0 <= bot:
			lo = mini(lo, c)
			hi = maxi(hi, c)
	return Vector2i(lo, hi)


func _update_sections() -> void:
	var r: = _visible_range()
	if r == _last_vis:
		return
	_last_vis = r
	for c in sections.keys():
		if c < r.x or c > r.y:
			_free_section(c)
	for c in range(r.x, r.y + 1):
		if not sections.has(c):
			_build_section(c)


func _free_section(c: int) -> void:
	var sec: Control = sections[c]
	sections.erase(c)
	for i in nodes.keys():
		if State.chapter_in_arc(i) == c and State.arc_of(i) == arc:
			nodes.erase(i)
	for k in chests.keys():
		if int(str(k).get_slice(":", 0)) % 10 == c:
			chests.erase(k)
	sec.queue_free()


func _build_section(c: int) -> void:
	var gc: = arc * 10 + c
	var sec: = Control.new()
	sec.position = Vector2(0, _sec_top(c))
	sec.size = Vector2(W, CH)
	sec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec.name = "Chapter%d" % (c + 1)
	map_root.add_child(sec)
	map_root.move_child(sec, 0)
	sections[c] = sec
	# backdrop: the arc's illustrated map, dimmed so the nodes carry the light; mirrored every other chapter
	var bgt: = Rules.map_bg(arc)
	if bgt:
		var bg: = TextureRect.new()
		bg.texture = bgt
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.size = Vector2(W, CH + 2)
		bg.flip_h = _mirror(c)
		bg.flip_v = c % 4 >= 2
		bg.modulate = Color(0.6, 0.55, 0.64)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sec.add_child(bg)
	Common.edge_shade(sec, Rect2(0, 0, W, 160), 1, Color(0.075, 0.05, 0.09), 0.85)
	Common.edge_shade(sec, Rect2(0, CH - 160, W, 160), -1, Color(0.075, 0.05, 0.09), 0.85)
	if W > CW + 8:
		Common.edge_shade(sec, Rect2(0, 0, X0 + 40, CH), 1, Color(0.075, 0.05, 0.09), 0.6).rotation = 0.0
	_chapter_plate(sec, gc)
	# nodes
	var host: = State.host_of_chapter(gc)
	for k in Gen.CHAPTER:
		var i: = gc * Gen.CHAPTER + k
		var info: = State.node(i)
		var st: = State.state_of(i)
		if st == "current" and i != cur:
			st = "open"
		if i == cur and st == "open":
			st = "current"
		var n: = PNode.new().setup(info, st, State.stars(i), host if (info.boss or info.legend) else "")
		var p: = _pos(i) - sec.position
		n.position = p - n.centre()
		n.z_index = 2
		n.name = "Node%d" % i
		sec.add_child(n)
		nodes[i] = n
		if info.peak:
			_peak_branch(sec, i)
	for kind in ["chapter", "star"]:
		_build_chest(sec, gc, kind)


func _chapter_plate(sec: Control, gc: int) -> void:
	var c: = gc % 10
	var y: = CH - 82.0
	var w: = minf(CW - 80.0, 520.0)
	var x: = X0 + (CW - w) * 0.5
	var plate: = UI.rbox("graphite", Rect2(x, y, w, 62), 31, 2, 10)
	plate.borders(Color("ffe7a6"), Color("a8742a"))
	plate.z_index = 2
	sec.add_child(plate)
	var host: = State.host_of_chapter(gc)
	plate.add_child(Common.avatar(host, Rect2(-10, -10, 82, 82), "gold"))
	var t1: = UI.label("Глава %d" % (c + 1), 26, Color("fff3d6"), Color(0.12, 0.05, 0.08), 4, "title", 900)
	t1.position = Vector2(84, 4)
	t1.size = Vector2(w - 220, 32)
	plate.add_child(t1)
	var t2: = UI.label("хозяйка: %s" % Rules.host_name(host), 17, Color("e9d9c8"))
	t2.position = Vector2(86, 34)
	t2.size = Vector2(w - 220, 24)
	plate.add_child(t2)
	var cs: = State.chapter_stars(gc)
	var st: = UI.label("★ %d/%d" % [cs, State.chapter_max(gc)], 22, Color("ffd75e"), Color(0.15, 0.08, 0.02), 4, "body", 900)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	st.position = Vector2(w - 150, 14)
	st.size = Vector2(130, 34)
	plate.add_child(st)


func _peak_branch(sec: Control, i: int) -> void:
	var a: = _pos(State.boss_of(i)) - sec.position
	var b: = _pos(i) - sec.position
	var l: = Line2D.new()
	var mid: = (a + b) * 0.5 + Vector2(0, 40)
	var pts: = PackedVector2Array()
	for s in 13:
		var t: = s / 12.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	l.points = pts
	l.width = 8.0
	l.texture = _dash_tex()
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var open: = State.state_of(i) != "locked"
	l.default_color = Color(0.86, 0.9, 1.0, 0.8) if open else Color(0.6, 0.62, 0.72, 0.45)
	l.z_index = 1
	sec.add_child(l)


func _build_chest(sec: Control, gc: int, kind: String) -> void:
	var st: = State.chest_state(gc, kind)
	var p: = _chest_pos(gc, kind) - sec.position
	var sz: = Vector2(104, 104)
	var box: = Control.new()
	box.size = sz + Vector2(0, 30)
	box.position = p - sz * 0.5
	box.pivot_offset = sz * 0.5
	box.z_index = 2
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.name = "Chest_%s" % kind
	box.set_meta("gc", gc)
	box.set_meta("kind", kind)
	sec.add_child(box)
	var tex: Texture2D
	if kind == "star":
		tex = Rules.icon("star_chest")
	else:
		tex = V8Art.misc("chest_open" if st == "claimed" else "chest_closed")
	if st == "ready" and V9Feel.can_fx():
		var glow: = UI.tex(G.fx("glow") if G.has_method("fx") else null, Rect2(-40, -40, sz.x + 80, sz.y + 80))
		glow.modulate = Color(1.0, 0.85, 0.5, 0.65)
		box.add_child(glow)
		var tw: = glow.create_tween().set_loops()
		tw.tween_property(glow, "modulate:a", 0.25, 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(glow, "modulate:a", 0.65, 0.8).set_trans(Tween.TRANS_SINE)
	var art: = UI.tex(tex, Rect2(Vector2.ZERO, sz))
	art.name = "Art"
	if st == "locked":
		art.modulate = Color(0.55, 0.52, 0.6, 0.9)
	elif st == "claimed":
		art.modulate = Color(0.75, 0.72, 0.78, 0.85)
	box.add_child(art)
	if st == "ready":
		var bob: = art.create_tween().set_loops()
		bob.tween_property(art, "position:y", -8.0, 0.45).set_trans(Tween.TRANS_SINE)
		bob.tween_property(art, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	var cap: = ""
	if kind == "star":
		cap = "★ %d/%d" % [mini(State.chapter_stars(gc), Rules.STAR_CHEST_NEED), Rules.STAR_CHEST_NEED]
	else:
		cap = "Сундук главы"
	if st == "claimed":
		cap = "Открыт"
	var l: = UI.center_label(UI.label(cap, 17, Color("ffe7c4") if st != "locked" else Color("cfc6d6"), Color(0.1, 0.05, 0.08), 4, "body", 900),
		Rect2(-20, sz.y - 6, sz.x + 40, 26))
	box.add_child(l)
	chests["%d:%s" % [gc, kind]] = box


# ------------------------------------------------------------------ gate (top) and start (bottom)

func _build_gate() -> void:
	var nxt: = arc + 1
	var y0: = TOP_INSET + HDR_H + 40.0
	var w: = CW - 60.0
	var r: = Rect2(X0 + 30, y0, w, 300)
	var g: = Control.new()
	g.position = r.position
	g.size = r.size
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.name = "ArcGate"
	map_root.add_child(g)
	if nxt >= Gen.WORLDS:
		g.add_child(UI.center_label(UI.title("Конец Пути", 40, Color("fff3d6"), Color(0.2, 0.08, 0.1)), Rect2(0, 100, w, 80)))
		return
	var cov: = Rules.cover(nxt)
	var rel: = State.arc_released(nxt)
	if cov:
		var a: = Common.card_art(cov, Rect2(0, 0, w, 260), Vector2(0.5, 0.5), 1.0, 26.0)
		a.modulate = Color(0.85, 0.8, 0.9) if rel else Color(0.16, 0.14, 0.2)
		g.add_child(a)
	else:
		var ph: = UI.rbox("graphite", Rect2(0, 0, w, 260), 26, 2, 10)
		g.add_child(ph)
	var fr: = UI.rbox("graphite", Rect2(0, 0, w, 260), 26, 3, 10)
	fr.colors(Color(0, 0, 0, 0), Color(0, 0, 0, 0.0))
	fr.borders(Color("ffe7a6"), Color("a8742a"))
	g.add_child(fr)
	Common.floor_fade(g, 120, 260, Color(0.06, 0.03, 0.07), 0.92).size.x = w
	var t1: = UI.center_label(UI.title("Арка %d · %s" % [nxt + 1, Rules.ARC_TITLES[nxt]], 30, Color("fff3d6"), Color(0.15, 0.05, 0.08)), Rect2(10, 150, w - 20, 50))
	g.add_child(t1)
	var sub: = "Откроется после Легенды арки %d" % (arc + 1) if rel else "Арка выходит с обновлением"
	g.add_child(UI.center_label(UI.label(sub, 20, Color("e9dccb"), Color(0.08, 0.04, 0.06), 4), Rect2(10, 200, w - 20, 34)))
	if not rel:
		var lk: = V8Art.icon("lock")
		if lk:
			g.add_child(UI.tex(lk, Rect2(w * 0.5 - 34, 50, 68, 68)))


func _build_start() -> void:
	var y: = gate_h + 10.0 * CH + 20.0
	var l: = UI.center_label(UI.label("Начало арки · %s" % str(Gen.WORLD[arc].name), 20, Color("e9dccb"), Color(0.08, 0.04, 0.06), 4), Rect2(X0, y, CW, 34))
	map_root.add_child(l)


# ------------------------------------------------------------------ header, marker, CTA

func _build_header() -> void:
	hdr = Control.new()
	hdr.position = Vector2(X0 + 14, TOP_INSET + 6)
	hdr.size = Vector2(CW - 28, HDR_H)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.name = "ArcPlate"
	add_child(hdr)
	var shade: = Common.edge_shade(self, Rect2(0, 0, W, TOP_INSET + HDR_H + 60), 1, Color(0.075, 0.05, 0.09), 0.96, 0.55)
	move_child(shade, hdr.get_index())
	var w: = hdr.size.x
	var cov: = Rules.cover(arc)
	if cov:
		hdr.add_child(Common.card_art(cov, Rect2(0, 0, w, HDR_H), Vector2(0.5, 0.42), 1.0, 24.0))
	var ff: = Common.floor_fade(hdr, 30, HDR_H, Color(0.06, 0.03, 0.07), 0.9)
	ff.size.x = w
	var fr: = UI.rbox("graphite", Rect2(0, 0, w, HDR_H), 24, 3, 10)
	fr.colors(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	fr.borders(Color("ffe7a6"), Color("a8742a"))
	hdr.add_child(fr)
	var pr: = State.arc_progress(arc)
	var t1: = UI.title("Арка %d · %s" % [arc + 1, Rules.ARC_TITLES[arc]], 30, Color("fff6e4"), Color(0.16, 0.05, 0.08))
	t1.position = Vector2(20, HDR_H - 96)
	t1.size = Vector2(w - 170, 44)
	Common.fit_line(t1, w - 170, 22)
	hdr.add_child(t1)
	var sub: = UI.label("%s · пройдено %d/%d" % [str(Gen.WORLD[arc].name), pr[0], pr[1]], 19, Color("f0e2cf"), Color(0.06, 0.03, 0.05), 4)
	sub.position = Vector2(22, HDR_H - 54)
	sub.size = Vector2(w - 170, 26)
	hdr.add_child(sub)
	Common.progress_bar(hdr, Rect2(22, HDR_H - 24, w - 44, 12), float(pr[0]) / maxf(1.0, float(pr[1])), "gold")
	var b: = JButton.make("Арки", "graphite", Rect2(w - 140, HDR_H - 98, 124, 60), null, 24)
	b.name = "ArcsBtn"
	b.pressed.connect(func(): Dlg.arcs_sheet(main, self))
	hdr.add_child(b)
	# summits chip when the player has any (the «Восходящая» frame climbs every 10)
	if State.summits() > 0:
		var ch: = Common.chip(hdr, Rules.icon("peak"), "Вершин: %d" % State.summits(), Rect2(w - 196, 14, 180, 40), "plum", 18)
		ch.name = "SummitsChip"


func _build_marker() -> void:
	marker = Control.new()
	marker.size = Vector2(84, 100)
	marker.pivot_offset = Vector2(42, 100)
	marker.z_index = 4
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.name = "Marker"
	map_root.add_child(marker)
	var pin: = Polygon2D.new()
	pin.polygon = PackedVector2Array([Vector2(28, 70), Vector2(56, 70), Vector2(42, 98)])
	pin.color = Color("e8c47e")
	marker.add_child(pin)
	var who: String = str(G.S.get("partner", "mc")) if State.root_override == null else "mc"
	if not (who in Gen.READY_HEROES):
		who = "mc"
	marker.add_child(Common.avatar(who, Rect2(0, 0, 84, 84), "gold"))
	_place_marker(cur)
	if V9Feel.can_fx():
		var tw: = marker.create_tween().set_loops()
		tw.tween_property(marker, "scale", Vector2(1.04, 0.97), 0.55).set_trans(Tween.TRANS_SINE)
		tw.tween_property(marker, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)


func _place_marker(i: int) -> void:
	marker.visible = State.arc_of(i) == arc
	var p: = _pos(i)
	var r: = 66.0 if Gen.is_boss(i) else 46.0
	marker.position = p - Vector2(42, 100 + r + 26)


func _build_cta() -> void:
	var lv: = cur
	var txt: = "Играть  %s" % Gen.code(lv)
	if State.arc_of(cur) != arc:
		txt = "К текущему уровню"
	var r: = Rect2(X0 + 70, H - NAV_INSET - 116, CW - 140, 98)
	cta = JButton.make(txt, "pink" if not State.is_legend(lv) else "gold", r, null, 34)
	cta.name = "PlayCTA"
	cta.pressed.connect(func():
		if State.arc_of(cur) != arc:
			switch_arc(State.arc_of(cur))
		else:
			open_card(cur))
	add_child(cta)
	cta.pulse = true
	# Огонёк пути: three cups over the CTA
	var fl: = Boost.flame()
	var row: = Control.new()
	row.size = Vector2(240, 44)
	row.position = Vector2(X0 + (CW - 240) * 0.5, r.position.y - 46)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.name = "FlameRow"
	add_child(row)
	var pill: = UI.rbox("graphite", Rect2(0, 2, 240, 40), 20, 2, 8)
	pill.borders(Color("ffe7a6"), Color("a8742a"))
	row.add_child(pill)
	var l: = UI.label("Огонёк пути", 17, Color("ffe7c4"), Color(0.1, 0.05, 0.05), 3, "body", 900)
	l.position = Vector2(14, 2)
	l.size = Vector2(110, 40)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var ft: = Rules.icon("flame")
	for k in 3:
		var cup: = UI.tex(ft, Rect2(128 + k * 36, -2, 44, 44))
		if k >= fl:
			cup.modulate = Color(0.35, 0.32, 0.4, 0.75)
		row.add_child(cup)
	jump_btn = JButton.make("", "graphite", Rect2(X0 + CW - 86, r.position.y - 80, 68, 68), null, 30, 34.0)
	jump_btn.name = "JumpBtn"
	var arr: = UI.center_label(UI.label("▲", 28, Color("ffe7c4"), Color(0.1, 0.05, 0.05), 3), Rect2(0, 0, 68, 68))
	arr.name = "Arrow"
	jump_btn.add_child(arr)
	jump_btn.pressed.connect(func(): scroll_to_level(cur, true))
	jump_btn.visible = false
	add_child(jump_btn)


# ------------------------------------------------------------------ scrolling and input

func _clamp_scroll(y: float) -> float:
	return clampf(y, 0.0, maxf(0.0, content_h - H))


func _apply_scroll(force: = false) -> void:
	map_root.position.y = -scroll
	_update_sections()
	if is_instance_valid(jump_btn):
		var y: = _node_y(cur) - scroll
		var off: = State.arc_of(cur) == arc and (y < TOP_INSET + HDR_H or y > H - NAV_INSET - 160)
		jump_btn.visible = off
		var a: Label = jump_btn.get_node_or_null("Arrow")
		if a:
			a.text = "▲" if y < TOP_INSET + HDR_H else "▼"


func scroll_to_level(i: int, animate: bool) -> void:
	var y: = _clamp_scroll(_node_y(i) - H * 0.56)
	if not animate:
		scroll = y
		_apply_scroll()
		return
	_vel = 0.0
	var tw: = create_tween()
	tw.tween_method(func(v): scroll = v; _apply_scroll(), scroll, y, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _popup_open() -> bool:
	if main == null or not ("overlay" in main) or main.overlay == null:
		return false
	for p in main.overlay.get_children():
		if p.has_meta("popup") or p.has_meta("v10_sheet"):
			return true
	return false


func _in_map(p: Vector2) -> bool:
	if p.y < TOP_INSET + HDR_H + 8 or p.y > H - NAV_INSET:
		return false
	if is_instance_valid(cta) and cta.get_global_rect().grow(6).has_point(p):
		return false
	if is_instance_valid(jump_btn) and jump_btn.visible and jump_btn.get_global_rect().has_point(p):
		return false
	return true


func _hit(p: Vector2):
	for i in nodes:
		var n: PNode = nodes[i]
		if not is_instance_valid(n):
			continue
		var c: = n.get_global_transform_with_canvas() * n.centre()
		if c.distance_to(p) <= n.radius + 18.0:
			return n
	for k in chests:
		var b: Control = chests[k]
		if is_instance_valid(b) and b.get_global_rect().grow(10).has_point(p):
			return b
	return null


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree() or _popup_open():
		_drag = false
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = get_global_transform_with_canvas().affine_inverse() * e.position
		if e.pressed:
			if not _in_map(p):
				return
			_drag = true
			_drag_y = p.y
			_moved = 0.0
			_vel = 0.0
			_press = _hit(e.position)
			if _press:
				V9Feel.press_down(_press)
		elif _drag:
			_drag = false
			if _press and is_instance_valid(_press):
				var fire: = _moved < 14.0
				V9Feel.press_up(_press, fire, "")
				if fire:
					_tap(_press)
			_press = null
	elif e is InputEventMouseMotion and _drag:
		var p2: Vector2 = get_global_transform_with_canvas().affine_inverse() * e.position
		var dy: = p2.y - _drag_y
		_drag_y = p2.y
		_moved += absf(dy)
		if _moved >= 14.0 and _press:
			if is_instance_valid(_press):
				V9Feel.press_up(_press, false, "")
			_press = null
		scroll = _clamp_scroll(scroll - dy)
		_vel = -dy / maxf(get_process_delta_time(), 0.008)
		_apply_scroll()


func _process(dt: float) -> void:
	_t += dt
	if not _drag and absf(_vel) > 4.0:
		scroll = _clamp_scroll(scroll + _vel * dt)
		_vel *= pow(0.06, dt)
		if scroll <= 0.0 or scroll >= content_h - H:
			_vel = 0.0
		_apply_scroll()


func _tap(target) -> void:
	if target is PNode:
		var n: PNode = target
		if n.state == "arc_locked":
			V9Feel.deny(n)
			_toast("Арка выходит с обновлением")
			return
		if n.state == "locked":
			V9Feel.deny(n)
			if n.kind == "peak":
				_toast("Пик откроется после босса главы")
			else:
				_toast("Откроется после уровня %s" % Gen.code(maxi(n.i - 1, 0)))
			return
		V9Feel.sound("pop")
		open_card(n.i)
	elif target is Control and target.has_meta("kind"):
		_chest_tap(target)


func _chest_tap(box: Control) -> void:
	var gc: int = box.get_meta("gc")
	var kind: String = box.get_meta("kind")
	var st: = State.chest_state(gc, kind)
	if st == "locked":
		V9Feel.deny(box)
		if kind == "star":
			_toast("Звёздный сундук: собери ★ %d из %d в главе" % [Rules.STAR_CHEST_NEED, State.chapter_max(gc)])
		else:
			_toast("Сундук откроется после босса главы")
		return
	if st == "claimed":
		V9Feel.press(box)
		_toast("Этот сундук уже открыт")
		return
	var r: = State.claim_chest(gc, kind)
	PFx.chest_open(box, r, self)
	var art: TextureRect = box.get_node_or_null("Art")
	if art:
		art.create_tween().kill()
		if kind == "chapter":
			get_tree().create_timer(0.22).timeout.connect(func():
				if is_instance_valid(art):
					art.texture = V8Art.misc("chest_open"))
	if main and main.has_method("refresh_currency"):
		main.refresh_currency()


func _toast(t: String) -> void:
	if main and main.has_method("toast"):
		main.toast(t)
	else:
		print("[path] ", t)


# ------------------------------------------------------------------ cards, play, arcs

func open_card(i: int) -> void:
	if not State.playable(i):
		return
	Card.open(main, self, i)


func play(i: int, sel: Dictionary) -> void:
	var mode: = "peak" if State.is_peak(i) else ("legend" if State.is_legend(i) else "")
	var cfg: = State.play_cfg(i)
	var applied: = Boost.commit(sel, i, mode)
	Boost.apply_cfg(cfg, applied)
	State.mark_intro(i)
	var go: = func():
		if on_play.is_valid():
			on_play.call(i, cfg)
		elif main and main.has_method("go"):
			main.go("play", {"level": i, "v10_cfg": cfg})
	if State.is_peak(i) or State.is_legend(i):
		PFx.peak_enter(main.overlay if main and "overlay" in main else self, get_viewport_rect().size, go)
	else:
		go.call()


func switch_arc(w: int) -> void:
	if w == arc or not State.arc_released(w):
		return
	V9Feel.sound("whoosh")
	if main and main.has_method("go") and main.get("screen") == self and main.SCREENS.has("v10path"):
		main.go("v10path", {"arc": w}, true, false)
		return
	# standalone: rebuild in place
	var p: = get_parent()
	var s: = size
	var nm: Control = Control.new()
	nm.set_script(get_script())
	nm.size = s
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(nm)
	nm.build(main, {"arc": w})
	if main and "screen" in main and main.screen == self:
		main.screen = nm
	queue_free()


# ------------------------------------------------------------------ animation

func _intro_anim() -> void:
	if is_instance_valid(hdr):
		UI.slide_in(hdr, Vector2(0, -40), 0.0, 0.45)
	if is_instance_valid(cta):
		UI.pop_in(cta, 0.25, 0.7)
	var k: = 0
	var near: = []
	for i in nodes:
		var y: float = _node_y(i) - scroll
		if y > 0 and y < H:
			near.append(i)
	near.sort()
	for i in near:
		var n: PNode = nodes[i]
		n.scale = Vector2(0.6, 0.6)
		n.modulate.a = 0.0
		var tw: = n.create_tween().set_parallel()
		tw.tween_property(n, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.05 + 0.035 * k)
		tw.tween_property(n, "modulate:a", 1.0, 0.2).set_delay(0.05 + 0.035 * k)
		k += 1
	if is_instance_valid(marker) and marker.visible:
		var target: = marker.position
		marker.position = target - Vector2(0, 160)
		marker.modulate.a = 0.0
		var tm: = marker.create_tween()
		tm.tween_interval(0.35)
		tm.tween_property(marker, "modulate:a", 1.0, 0.1)
		tm.parallel().tween_property(marker, "position", target, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# after a win: the gold line runs from the won node to the new current one, the new node bursts open, the marker hops
func _after_win(w: Dictionary) -> void:
	var from_i: = int(w.get("i", cur))
	if State.arc_of(from_i) != arc:
		return
	var k0: = 0
	for k in path_idx.size():
		if int(path_idx[k]) >= from_i:
			k0 = k
			break
	var k1: = _done_upto()
	_set_done_to(k0)
	_place_marker(from_i)
	var tw: = create_tween()
	tw.tween_interval(0.5)
	tw.tween_method(func(v): _set_done_to(int(v)), float(k0), float(k1), 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_method(func(v): _place_marker_at(v), _pos(from_i), _pos(cur), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_place_marker(cur)
		var n: PNode = nodes.get(cur)
		if n:
			PFx.unlock_burst(map_root, _pos(cur), Rules.tier_look(n.tier).top)
			UI.punch(n, 0.22, 0.45)
		UI.punch(marker, 0.15, 0.35))


func _place_marker_at(p: Vector2) -> void:
	marker.position = p - Vector2(42, 100 + 46 + 26)
