class_name V10HudSkin
extends RefCounted

# V10HudSkin — skin framework (docs/0.10-spec.md D7). Builds skinned pieces for the active skin; with `five_winds`
# active every hook is a no-op (decorate / restyle return without touching the node).
#
#   V10HudSkin.use(id, palette = "")          activate (from V10Look.current().hud / .palette)
#   V10HudSkin.active / .palette              current skin id / palette preset
#   V10HudSkin.skinned() -> bool              active != five_winds (the ONE check the hot files make)
#   V10HudSkin.tok(name) -> Color             token of the active skin + palette
#   V10HudSkin.nine(role, size, id = active) -> Control        background of a role (vector or @2x 9-patch)
#   V10HudSkin.button(cls, text, rect, cb) -> Control          4 classes of UX §6.5 (play / cash / secondary / quiet)
#   V10HudSkin.plate(cls, title, sub, rect) -> Control         plate S/M/L (HUD_V2 §2)
#   V10HudSkin.window(parent, title, rect) -> Control          popup with the skin's opening (silk / pen)
#   V10HudSkin.header(parent, title, w, top_inset) -> Control  one header (UX §6.1), title in the skin font
#   V10HudSkin.currency(parent, icon, value, rect) -> Control
#   V10HudSkin.tabs(parent, names, active_i, rect) -> Control  5-tab navbar
#   V10HudSkin.menu_bg(parent, rect) / loading(parent, rect)   textured backgrounds (none for five_winds)
#   V10HudSkin.decorate(ctrl, role) -> Control|null            hook for jbutton / rbox / popup / V8Header
#   V10HudSkin.sting(full) -> bool                             ≤ once per 600 s, ducking −8 dB (Sfx.sting when merged)
#   V10HudSkin.role_fill(id, role) -> Color / contrast(a, b)   for the selftest (≥ 4,5:1)

const BASE: = "five_winds"
const STING_GAP_MS: = 600000
const T_SILK: = 0.22
const T_PEN: = 0.4

static var active: = BASE
static var palette: = ""
static var _tex: = {}
static var _fill_cache: = {}
static var _last_sting_ms: = -10000000
static var sting_count: = 0


static func use(id: String, pal: = "") -> void:
	active = id if V10HudSkinData.has(id) else BASE
	palette = pal


static func sync(look: Dictionary) -> void:
	use(String(look.get("hud", BASE)), String(look.get("palette", "")))


static func skinned() -> bool:
	return active != BASE


static func tok(name: String, id: = "") -> Color:
	var sid: = active if id == "" else id
	return V10HudSkinData.tokens(sid, palette if sid == active else "").get(name, Color.MAGENTA)


static func tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


static func fx_level() -> String:
	var tree: = Engine.get_main_loop() as SceneTree
	if tree and tree.root.get_node_or_null("G"):
		return V9Feel.level()
	return "full"


# ------------------------------------------------------------------------------------------------- roles

static func role_def(id: String, role: String) -> Dictionary:
	return V10HudSkinData.skin(id).get("nine", {}).get(role, {})


static func nine(role: String, sz: Vector2, id: = "") -> Control:
	var sid: = active if id == "" else id
	var d: = role_def(sid, role)
	var tint: = V10HudSkinData.tint(sid, palette if sid == active else "")
	var t: = tex(String(d.get("tex", "")))
	var c: Control
	if t == null:
		var v: = _Vec.new()
		v.def = d
		v.toks = V10HudSkinData.tokens(sid, palette if sid == active else "")
		c = v
	elif d.has("m"):
		# @2x 9-patch drawn at scale 0.5 (HUD_V2 §2.4): corners stay 1:1 to the 720 base
		var holder: = Control.new()
		var np: = NinePatchRect.new()
		np.texture = t
		var m: Array = d.m
		np.patch_margin_left = int(m[0])
		np.patch_margin_top = int(m[1])
		np.patch_margin_right = int(m[2])
		np.patch_margin_bottom = int(m[3])
		# margins are fixed in texture px: a role drawn smaller than its margins (a 64 px secondary button on the
		# 80 px plate art) is drawn at a proportionally smaller scale, so corners never overlap
		var need: = Vector2(m[0] + m[2] + 2, m[1] + m[3] + 2)
		var k: = minf(1.0, minf(sz.x * 2.0 / need.x, sz.y * 2.0 / need.y))
		np.scale = Vector2(0.5, 0.5) * k
		np.size = sz * 2.0 / k
		np.modulate = tint
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(np)
		holder.resized.connect(func(): np.size = holder.size * 2.0 / k)
		c = holder
	else:
		var cv: = _Cover.new()
		cv.texture = t
		cv.mode = String(d.get("mode", "fit"))
		cv.modulate = tint
		cv.fill = V10HudSkinData.tokens(sid, palette if sid == active else "").get(String(d.get("fill", "")), Color(0, 0, 0, 0))
		c = cv
	c.name = "V10Skin_" + role
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("v10_skin", sid)
	return c


# background colour a reader sees under the text of a role (textured: mean of the centre of the texture)
static func role_fill(id: String, role: String) -> Color:
	var key: = "%s|%s" % [id, role]
	if _fill_cache.has(key):
		return _fill_cache[key]
	var d: = role_def(id, role)
	var toks: = V10HudSkinData.tokens(id)
	var col: Color = toks.get(String(d.get("fill", "night_800")), Color.BLACK)
	if d.get("alpha", 1.0) < 0.5:
		col = toks.night_900   # transparent roles sit on the night background
	var t: = tex(String(d.get("tex", "")))
	if d.has("text_bg"):
		# the role's caption sits beside the art (tab captions under the feather), on this token
		t = null
		col = toks.get(String(d.text_bg), col)
	if t:
		var img: = t.get_image()
		if img.is_compressed():
			img.decompress()
		var w: = img.get_width()
		var h: = img.get_height()
		var acc: = Vector3.ZERO
		var n: = 0
		for yy in range(int(h * 0.35), int(h * 0.65), maxi(1, h / 40)):
			for xx in range(int(w * 0.3), int(w * 0.7), maxi(1, w / 40)):
				var p: = img.get_pixel(xx, yy)
				if p.a > 0.5:
					acc += Vector3(p.r, p.g, p.b)
					n += 1
		if n > 0:
			acc /= n
			col = Color(acc.x, acc.y, acc.z)
	_fill_cache[key] = col
	return col


static func lum(c: Color) -> float:
	var f: = func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la: = lum(a)
	var lb: = lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# ------------------------------------------------------------------------------------------------- type

static func font_display(size: int) -> Font:
	var hero: = String(V10HudSkinData.skin(active).get("hero", ""))
	if active != BASE and V10Fonts.SKIN_FONTS.has(hero):
		return V10Fonts.skin(hero, "title", size)
	return V10Fonts.font("ui_display")


static func label(text: String, size: int, col: Color, kind: = "ui", w: = 0.0) -> Label:
	var l: = Label.new()
	l.text = text
	var ls: = LabelSettings.new()
	if kind == "display":
		var hero: = String(V10HudSkinData.skin(active).get("hero", ""))
		if w > 0.0:
			var fit: = V10Fonts.fit_title(text, hero if active != BASE else "", size, w)
			ls.font = fit.font
			ls.font_size = fit.size
		else:
			ls.font = font_display(size)
			ls.font_size = size
	elif kind == "num":
		ls.font = V10Fonts.font("ui_body", 900)
		ls.font_size = size
	else:
		ls.font = V10Fonts.font("ui_body", 800 if size <= 22 else 700)
		ls.font_size = size
	ls.font_color = col
	ls.outline_size = 0
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


# ------------------------------------------------------------------------------------------------- pieces

static func button(cls: String, text: String, rect: Rect2, cb: = Callable()) -> Control:
	var role: String = V10HudSkinData.BUTTON_CLASSES.get(cls, "btn_secondary")
	var b: = _Btn.new()
	b.name = "V10Btn_" + cls
	b.position = rect.position
	b.size = rect.size
	b.cb = cb
	b.skin_id = active
	b.cls = cls
	var bg: = nine(role, rect.size)
	b.add_child(bg)
	if cls == "quiet":
		var dsz: = rect.size.y - (30.0 if text != "" else 0.0)
		bg.size = Vector2(dsz, dsz)
		bg.position = Vector2((rect.size.x - dsz) * 0.5, 0)
	if text != "":
		var col: = tok(V10HudSkinData.TEXT_ON.get(role, "paper_100"))
		var kind: = "display" if cls == "play" else ("num" if cls == "cash" else "ui")
		var fs: = 32 if cls == "play" else (28 if cls == "cash" else 22)
		var l: = label(text, fs, col, kind, rect.size.x - 96.0)
		l.size = rect.size
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if cls == "quiet":
			l.position.y = rect.size.y - 28.0
			l.size.y = 26.0
			l.label_settings.font_size = 18
		b.add_child(l)
	b.pivot_offset = rect.size * 0.5
	return b


static func plate(cls: String, title: String, sub: String, rect: Rect2) -> Control:
	var role: = "plate_" + cls.to_lower()
	var h: float = V10HudSkinData.ROLE_H.get(role, 80)
	var c: = Control.new()
	c.name = "V10Plate_" + cls
	c.position = rect.position
	c.size = Vector2(rect.size.x, h)
	c.add_child(nine(role, c.size))
	var pad: = 16.0 if cls == "S" else 24.0
	var t: = label(title, 32 if cls == "L" else 22, tok("paper_100"), "display" if cls == "L" else "ui", rect.size.x - 2 * pad)
	t.position = Vector2(pad, 6 if cls == "S" else (14 if cls == "M" else 22))
	t.size = Vector2(rect.size.x - 2 * pad, 36 if cls != "L" else 44)
	if cls == "S":
		t.size.y = 36
	c.add_child(t)
	if sub != "" and cls != "S":
		var s: = label(sub, 18, tok("paper_300"))
		s.position = Vector2(pad, t.position.y + t.size.y)
		s.size = Vector2(rect.size.x - 2 * pad, 26 if cls == "M" else 56)
		if cls == "L":
			s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			s.max_lines_visible = 2
		c.add_child(s)
	return c


static func window(parent: Control, title: String, rect: Rect2) -> Control:
	var w: = Control.new()
	w.name = "V10Window"
	w.position = rect.position
	w.size = rect.size
	w.pivot_offset = rect.size * 0.5
	w.add_child(nine("window", rect.size))
	var inset: = 56.0 if skinned() else 32.0
	var t: = label(title, 44, tok("paper_100"), "display", rect.size.x - 2 * inset)
	t.position = Vector2(inset, inset - 6)
	t.size = Vector2(rect.size.x - 2 * inset, 60)
	t.set_meta("v10_title", true)
	w.add_child(t)
	parent.add_child(w)
	V10SkinFx.open(w, active)
	return w


static func header(parent: Control, title: String, w: float, top: = 0.0) -> Control:
	var h: = Control.new()
	h.name = "V10Header"
	h.size = Vector2(w, 120 + top)
	if skinned():
		h.size.y = float(role_def(active, "header").get("h", 120)) + top
		h.add_child(nine("header", h.size))
	var dy: = 4.0 if skinned() else 26.0   # skinned: the title sits above the ornament strip
	var back: = label("‹", 44, tok("paper_100"), "ui")
	back.position = Vector2(24, top + dy - 4)
	back.size = Vector2(48, 64)
	h.add_child(back)
	var t: = label(title, 44, tok("paper_100"), "display", w - 160)
	t.position = Vector2(80, top + dy)
	t.size = Vector2(w - 160, 60)
	t.set_meta("v10_title", true)
	h.add_child(t)
	parent.add_child(h)
	return h


static func currency(parent: Control, icon: Texture2D, value: String, rect: Rect2) -> Control:
	var c: = Control.new()
	c.name = "V10Currency"
	c.position = rect.position
	c.size = rect.size
	c.add_child(nine("currency", rect.size))
	var ix: = 24.0 if not skinned() else rect.size.x * 0.2
	if icon:
		var ir: = TextureRect.new()
		ir.texture = icon
		ir.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ir.size = Vector2(40, 40)
		ir.position = Vector2(ix - 6, (rect.size.y - 40) * 0.5)
		ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(ir)
	var l: = label(value, 22, tok("gold_300"), "num")
	l.position = Vector2(ix + 40, 0)
	l.size = Vector2(rect.size.x - ix - 40 - (rect.size.x * 0.18 if skinned() else 16), rect.size.y)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if skinned() else HORIZONTAL_ALIGNMENT_LEFT
	c.add_child(l)
	parent.add_child(c)
	return c


static func tabs(parent: Control, names: Array, active_i: int, rect: Rect2) -> Control:
	var bar: = Control.new()
	bar.name = "V10Tabs"
	bar.position = rect.position
	bar.size = rect.size
	var bg: = ColorRect.new()
	bg.color = Color(tok("night_900"), 0.94)
	bg.size = rect.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg)
	var line: = ColorRect.new()
	line.color = Color(tok("gold_700"), 0.35)
	line.size = Vector2(rect.size.x, 1)
	bar.add_child(line)
	var w: = rect.size.x / names.size()
	for i in names.size():
		var on: = i == active_i
		if skinned() and on:
			var f: = nine("tab", Vector2(40, 86))
			f.position = Vector2(w * i + w * 0.5 - 20, 4)
			bar.add_child(f)
		elif on:
			var ul: = ColorRect.new()
			ul.color = tok("gold_500")
			ul.size = Vector2(40, 3)
			ul.position = Vector2(w * i + w * 0.5 - 20, 12)
			bar.add_child(ul)
		var l: = label(String(names[i]), 18, tok("gold_300") if on else tok("paper_500"))
		l.position = Vector2(w * i, rect.size.y - 40)
		l.size = Vector2(w, 26)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bar.add_child(l)
		var dot: = _Glyph.new()
		dot.col = tok("gold_300") if on else tok("paper_500")
		dot.kind = i
		dot.size = Vector2(40, 40)
		dot.position = Vector2(w * i + w * 0.5 - 20, 26 if not (skinned() and on) else 30)
		bar.add_child(dot)
	parent.add_child(bar)
	return bar


static func menu_bg(parent: Control, rect: Rect2) -> Control:
	var path: = String(V10HudSkinData.skin(active).get("menu_bg", ""))
	return _cover(parent, path, rect, "menu_bg")


static func loading(parent: Control, rect: Rect2) -> Control:
	var path: = String(V10HudSkinData.skin(active).get("loading", ""))
	return _cover(parent, path, rect, "loading")


static func _cover(parent: Control, path: String, rect: Rect2, nm: String) -> Control:
	var t: = tex(path)
	if t == null:
		return null
	var cv: = _Cover.new()
	cv.name = "V10Skin_" + nm
	cv.texture = t
	cv.mode = "cover"
	cv.position = rect.position
	cv.size = rect.size
	cv.modulate = V10HudSkinData.tint(active, palette)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cv)
	parent.move_child(cv, 0)
	return cv


# Hook for the hot files: one call, no-op while five_winds is active.
static func decorate(ctrl: Control, role: String) -> Control:
	if not skinned() or ctrl == null or not (role in V10HudSkinData.NINE_ROLES):
		return null
	var old: = ctrl.get_node_or_null("V10Skin_" + role)
	if old:
		old.free()
	var bg: = nine(role, ctrl.size)
	ctrl.add_child(bg)
	ctrl.move_child(bg, 0)
	ctrl.resized.connect(func(): if is_instance_valid(bg): bg.size = ctrl.size)
	return bg


static func sting(full: = false, now_ms: = -1) -> bool:
	var sid: = String(V10HudSkinData.skin(active).get("sting", ""))
	if sid == "":
		return false
	var now: = Time.get_ticks_msec() if now_ms < 0 else now_ms
	if now - _last_sting_ms < STING_GAP_MS:
		return false
	_last_sting_ms = now
	sting_count += 1
	var st: Dictionary = V10KitData.STINGS.get(sid, {})
	var path: = String(st.get("full" if full else "short", ""))
	var tree: = Engine.get_main_loop() as SceneTree
	var sfx = tree.root.get_node_or_null("Sfx") if tree else null
	if sfx and path != "" and ResourceLoader.exists(path) and sfx.has_method("sting"):
		sfx.call("sting", path)
	return true


static func reset_sting() -> void:
	_last_sting_ms = -10000000


# ------------------------------------------------------------------------------------------------- drawables

class _Vec extends Control:
	var def: = {}
	var toks: = {}

	func _draw() -> void:
		var fill: Color = toks.get(String(def.get("fill", "night_800")), Color.BLACK)
		var a: float = def.get("alpha", 1.0)
		if a <= 0.0:
			return
		var sb: = StyleBoxFlat.new()
		sb.bg_color = Color(fill, a)
		sb.anti_aliasing = true
		var r: = 4
		if def.get("pill", false):
			r = int(size.y * 0.5)
		if def.get("circle", false):
			r = int(minf(size.x, size.y) * 0.5)
		sb.set_corner_radius_all(r)
		if def.has("border"):
			sb.border_color = toks.get(String(def.border), Color.WHITE)
			sb.set_border_width_all(2)
		var rr: = Rect2(Vector2.ZERO, size)
		if def.get("circle", false):
			var s: = minf(size.x, size.y)
			rr = Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
		draw_style_box(sb, rr)
		# lacquer: paper.100 at 5 % over the top 40 %
		var p100: Color = toks.get("paper_100", Color.WHITE)
		if not def.get("circle", false):
			for i in 8:
				draw_rect(Rect2(r * 0.5, rr.size.y * 0.05 * i, rr.size.x - r, rr.size.y * 0.05), Color(p100, 0.05 * (1.0 - i / 8.0)))
		if def.get("hair", false):
			var g7: Color = toks.get("gold_700", Color.GOLD)
			var x0: = 12.0
			var x1: = size.x - 12.0
			var pts: = PackedVector2Array()
			var cols: = PackedColorArray()
			for i in 9:
				var x: = lerpf(x0, x1, i / 8.0)
				pts.append(Vector2(x, 0.5))
				var fade: = clampf(minf(x - x0, x1 - x) / 24.0, 0.0, 1.0)
				cols.append(Color(g7, 0.35 * fade))
			draw_polyline_colors(pts, cols, 1.0, true)
		# bottom tone
		draw_line(Vector2(r, size.y - 0.5), Vector2(size.x - r, size.y - 0.5), Color(toks.get("night_900", Color.BLACK), 0.6), 1.0)


class _Cover extends Control:
	var texture: Texture2D
	var mode: = "cover"
	var fill: = Color(0, 0, 0, 0)

	func _draw() -> void:
		if texture == null:
			return
		var ts: = Vector2(texture.get_width(), texture.get_height())
		if mode == "strip_bottom":
			# lacquer band + the ornament strip on its bottom edge, full width, never cropped
			draw_rect(Rect2(Vector2.ZERO, size), fill)
			for i in 10:
				draw_rect(Rect2(0, size.y * 0.05 * i, size.x, size.y * 0.05), Color(1, 0.95, 0.85, 0.035 * (1.0 - i / 10.0)))
			var sh: = ts.y * size.x / ts.x
			draw_texture_rect(texture, Rect2(0, size.y - sh, size.x, sh), false)
			return
		var s: float
		if mode == "fit":
			s = minf(size.x / ts.x, size.y / ts.y)
		else:
			s = maxf(size.x / ts.x, size.y / ts.y)
		var ds: = ts * s
		var pos: = (size - ds) * 0.5
		if mode == "cover_bottom":
			pos.y = size.y - ds.y
		if mode != "fit":
			# crop to the rect: draw only the visible part of the texture
			var vis: = Rect2(Vector2.ZERO, size).intersection(Rect2(pos, ds))
			var src: = Rect2((vis.position - pos) / s, vis.size / s)
			draw_texture_rect_region(texture, vis, src)
		else:
			draw_texture_rect(texture, Rect2(pos, ds), false)


# monoline tab glyphs (tea cup, heroines, tables, wishes lantern, shop) — enough for previews; HUD v2 icons replace them
class _Glyph extends Control:
	var col: = Color.WHITE
	var kind: = 0

	func _draw() -> void:
		var c: = size * 0.5
		var w: = 2.5
		match kind:
			0:
				draw_arc(c + Vector2(0, 2), 12, 0.0, PI, 16, col, w, true)
				draw_line(c + Vector2(-12, 2), c + Vector2(12, 2), col, w, true)
				draw_arc(c + Vector2(14, 6), 5, -PI * 0.5, PI * 0.5, 8, col, w, true)
			1:
				draw_arc(c + Vector2(0, -6), 7, 0.0, TAU, 20, col, w, true)
				draw_arc(c + Vector2(0, 16), 14, PI, TAU, 20, col, w, true)
			2:
				draw_rect(Rect2(c - Vector2(10, 13), Vector2(20, 26)), col, false, w)
				draw_line(c + Vector2(-5, -4), c + Vector2(5, -4), col, w, true)
			3:
				draw_arc(c, 11, 0.0, TAU, 20, col, w, true)
				draw_line(c + Vector2(0, -18), c + Vector2(0, -11), col, w, true)
				draw_line(c + Vector2(0, 11), c + Vector2(0, 17), col, w, true)
			_:
				draw_rect(Rect2(c - Vector2(12, 6), Vector2(24, 18)), col, false, w)
				draw_arc(c + Vector2(0, -6), 7, PI, TAU, 12, col, w, true)


class _Btn extends Control:
	var cb: = Callable()
	var skin_id: = "five_winds"
	var cls: = "secondary"
	var _down: = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		if cls == "play" and V10HudSkin.fx_level() != "min":
			# the one infinite UI motion: «дыхание» of the main button 0,985↔1,0 / 3,2 с
			var tw: = create_tween().set_loops()
			tw.tween_property(self, "scale", Vector2(0.985, 0.985), 1.6).set_trans(Tween.TRANS_SINE)
			tw.tween_property(self, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_down = true
				if _g():
					V9Feel.press_down(self)
			elif _down:
				_down = false
				var inside: = Rect2(Vector2.ZERO, size).has_point(ev.position)
				if _g():
					V9Feel.press_up(self, inside)
				if inside:
					V10SkinFx.press(self, skin_id)
					if cb.is_valid():
						cb.call()
			accept_event()

	func _g() -> bool:
		return get_tree() != null and get_tree().root.get_node_or_null("G") != null
