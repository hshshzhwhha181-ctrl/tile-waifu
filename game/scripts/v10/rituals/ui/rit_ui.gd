class_name V10RitUI
extends RefCounted

# Shared UI kit of the rituals: «Тишина и лак» tokens (docs/UX_RULES.md §6), three voices of type, button classes,
# the hanko seal, the reward cascade, steam/petal particles and the lane's sounds. Everything a finger touches
# answers through V9Feel; every flourish respects S.fx_level (V9Feel.can_fx / fx_scale).

const NIGHT900: = Color("121014")
const NIGHT800: = Color("1b171c")
const NIGHT700: = Color("26212a")
const NIGHT600: = Color("332c36")
const PAPER100: = Color("f5ead8")
const PAPER300: = Color("ddd2c4")
const PAPER500: = Color("b3a89c")
const PAPER700: = Color("7e756d")
const GOLD300: = Color("f1d9a0")
const GOLD500: = Color("e8c47e")
const GOLD700: = Color("a87b3a")
const ROSE300: = Color("ecc0c9")
const ROSE500: = Color("d796a5")
const ROSE700: = Color("9a4f66")
const JADE300: = Color("a9d9c4")
const JADE500: = Color("5b9580")
const CINNABAR: = Color("c8463c")
const EMBER: = Color("e07a7a")
const TEAL: = Color("6fd6cf")
const FROST: = Color("9fc4e8")
# letter paper and ink (ask letter, week letter)
const WASHI: = Color("efe3cf")
const INK: = Color("3a2a2e")
const INK_SOFT: = Color("6a4a52")
const INK_SIGN: = Color("7a3a4a")

const SFX_DIR: = "res://assets/v10/rituals/sfx/"
const ART: = "res://assets/v10/rituals/"
const HAND_FONT: = "res://assets/v10/fonts/caveat/caveat-600.woff2"
# pentatonic ladder for reward cascades (semitones over the base pitch)
const PENTA: = [0, 2, 4, 7, 9, 12, 14, 16]

static var _hand: Font = null
static var _soft: Texture2D = null
static var _petal: Texture2D = null
static var _players: = []


# ── type ───────────────────────────────────────────────────────────────────────────────────────────────────────

static func hand_font() -> Font:
	if _hand == null:
		# Caveat 600 (v10-fonts) when merged, else Playfair Display Italic; Latin digits and symbols from the
		# Latin subset, then Nunito (the 0.8 Cyrillic subsets carry no digits)
		var fv: = FontVariation.new()
		var chain: = []
		for p in [HAND_FONT, "res://assets/fonts/playfair-i-cyr.woff2", "res://assets/fonts/playfair-i-lat.woff2"]:
			if ResourceLoader.exists(p):
				chain.append(load(p))
		if chain.is_empty():
			return UI.font("title", 600)
		fv.base_font = chain[0]
		var fb: = []
		for i in range(1, chain.size()):
			fb.append(chain[i])
		fb.append(UI.font("body", 700))
		fv.fallbacks = fb
		_hand = fv
	return _hand


# kind: body | title | hand | num | over (overline caps)
static func label(text: String, size: int, color: = PAPER100, kind: = "body", weight: = 800) -> Label:
	var l: = Label.new()
	l.text = text.to_upper() if kind == "over" else text
	var ls: = LabelSettings.new()
	match kind:
		"hand":
			ls.font = hand_font()
		"title":
			ls.font = UI.font_for("title", size, weight)
		"num":
			ls.font = UI.font("body", 900)
		"over":
			ls.font = UI.font("body", 900)
		_:
			ls.font = UI.font("body", weight)
	ls.font_size = size
	ls.font_color = color
	if kind == "hand":
		ls.shadow_color = Color(0, 0, 0, 0.45)
		ls.shadow_offset = Vector2(0, 2)
		ls.shadow_size = 6
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_w(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	l.size.x = w
	return l


# ── surfaces ───────────────────────────────────────────────────────────────────────────────────────────────────

static func box(bg: Color, radius: = 4, border: = Color(0, 0, 0, 0), bw: = 0) -> StyleBoxFlat:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.anti_aliasing = true
	return sb


static func panel(rect: Rect2, bg: = NIGHT700, radius: = 4, border: = Color(0, 0, 0, 0), bw: = 0) -> Panel:
	var p: = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", box(bg, radius, border, bw))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func tex(path: String, rect: Rect2) -> TextureRect:
	var t: = TextureRect.new()
	if ResourceLoader.exists(path):
		t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = rect.position
	t.size = rect.size
	t.pivot_offset = rect.size * 0.5
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func scrim(size: Vector2, a: = 0.62) -> ColorRect:
	var c: = ColorRect.new()
	c.color = Color(NIGHT900, a)
	c.size = size
	return c


# vertical gradient rect (night → transparent etc.)
static func grad(rect: Rect2, top: Color, bottom: Color) -> TextureRect:
	var g: = Gradient.new()
	g.colors = PackedColorArray([top, bottom])
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	var t: = TextureRect.new()
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = rect.position
	t.size = rect.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# ── buttons (UX_RULES §6.5) ────────────────────────────────────────────────────────────────────────────────────

class RitButton extends Button:
	var role: = "primary"
	var breathing: = false
	var _t: = 0.0

	func _process(dt: float) -> void:
		if not breathing or disabled or not V9Feel.can_fx():
			return
		_t += dt
		var k: = 0.9925 + 0.0075 * cos(_t * TAU / 3.2)
		if not has_meta("v9_feel_tw"):
			pivot_offset = size * 0.5
			scale = Vector2.ONE * k


# role: primary (rose pill, Playfair 32) | secondary (glass, paper text) | quiet (outline) | cash (gold line)
static func button(text: String, rect: Rect2, role: = "primary", on_press: = Callable()) -> RitButton:
	var b: = RitButton.new()
	b.role = role
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("ux_role", "tertiary" if role == "quiet" else role)
	var n: StyleBoxFlat
	var p: StyleBoxFlat
	var d: StyleBoxFlat
	match role:
		"primary":
			n = box(ROSE500, int(rect.size.y / 2))
			p = box(ROSE700, int(rect.size.y / 2))
			d = box(NIGHT600, int(rect.size.y / 2))
			b.add_theme_font_override("font", UI.font("title", 700))
			b.add_theme_font_size_override("font_size", 32 if rect.size.y >= 96 else 28)
			for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(k, NIGHT900)
			b.add_theme_color_override("font_disabled_color", PAPER700)
			b.breathing = true
		"secondary":
			n = box(Color(PAPER100, 0.07), 4)
			p = box(Color(PAPER100, 0.14), 4)
			d = box(Color(PAPER100, 0.03), 4)
			b.add_theme_font_override("font", UI.font("body", 800))
			b.add_theme_font_size_override("font_size", 24)
			for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(k, PAPER100)
			b.add_theme_color_override("font_disabled_color", PAPER700)
		_:
			n = box(Color(0, 0, 0, 0), 4, Color(PAPER500, 0.5), 2)
			p = box(Color(PAPER100, 0.08), 4, Color(PAPER300, 0.7), 2)
			d = n
			b.add_theme_font_override("font", UI.font("body", 800))
			b.add_theme_font_size_override("font_size", 22)
			for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(k, PAPER300)
	n.content_margin_left = 16
	n.content_margin_right = 16
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("focus", n)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.pressed.connect(func():
		V9Feel.press(b, "pop", "button")
		if on_press.is_valid():
			on_press.call())
	return b


# ── sound ──────────────────────────────────────────────────────────────────────────────────────────────────────

static func sfx(name: String, fallback: = "pop", pitch: = 1.0, db: = 0.0) -> void:
	if V10RitBridge.has_g() and G.S is Dictionary and not bool(G.S.get("sound", true)):
		return
	var p: = SFX_DIR + name + ".ogg"
	if not ResourceLoader.exists(p):
		V9Feel.sound(fallback, pitch, db)
		return
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var pl: AudioStreamPlayer = null
	for x in _players:
		if is_instance_valid(x) and not x.playing:
			pl = x
			break
	if pl == null:
		if _players.size() >= 8:
			pl = _players[0]
		else:
			pl = AudioStreamPlayer.new()
			tree.root.add_child(pl)
			_players.append(pl)
	pl.stream = load(p)
	pl.pitch_scale = pitch
	pl.volume_db = db
	pl.play()


static func note(i: int, base: = "pop", db: = -4.0) -> void:
	V9Feel.sound(base, pow(2.0, float(PENTA[i % PENTA.size()]) / 12.0), db)


# ── textures for particles ─────────────────────────────────────────────────────────────────────────────────────

static func soft_dot() -> Texture2D:
	if _soft == null:
		var g: = Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var gt: = GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_soft = gt
	return _soft


static func petal_tex() -> Texture2D:
	if _petal == null:
		var img: = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var u: = (x - 15.5) / 15.5
				var v: = (y - 15.5) / 15.5
				# a petal: ellipse with a notch at the tip
				var e: = u * u / 0.30 + v * v / 0.95
				var notch: = v < -0.75 and absf(u) < 0.12
				var a: = clampf((1.0 - e) * 3.0, 0.0, 1.0)
				if notch:
					a = 0.0
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_petal = ImageTexture.create_from_image(img)
	return _petal


static func steam(parent: Node, at: Vector2, width: = 60.0, amount: = 14, tint: = Color(1, 1, 1, 0.5)) -> CPUParticles2D:
	var p: = CPUParticles2D.new()
	p.texture = soft_dot()
	p.position = at
	p.amount = maxi(4, int(amount * maxf(0.35, V9Feel.fx_scale())))
	p.lifetime = 2.2
	p.preprocess = 2.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width * 0.5, 4)
	p.direction = Vector2(0, -1)
	p.spread = 12.0
	p.gravity = Vector2(0, -14)
	p.initial_velocity_min = 22.0
	p.initial_velocity_max = 38.0
	p.angular_velocity_min = -30
	p.angular_velocity_max = 30
	p.tangential_accel_min = -10
	p.tangential_accel_max = 10
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	var sc: = Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(0.5, 1.0))
	sc.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = sc
	var g: = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(tint, 0.0), tint, Color(tint, 0.0)])
	p.color_ramp = g
	parent.add_child(p)
	return p


static func petals(parent: Node, at: Vector2, col: Color, amount: = 28, spread: = 180.0) -> CPUParticles2D:
	var p: = CPUParticles2D.new()
	p.texture = petal_tex()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = maxi(6, int(amount * maxf(0.3, V9Feel.fx_scale())))
	p.lifetime = 2.4
	p.direction = Vector2(0, -1)
	p.spread = spread
	p.gravity = Vector2(0, 160)
	p.initial_velocity_min = 220
	p.initial_velocity_max = 460
	p.damping_min = 60
	p.damping_max = 120
	p.angular_velocity_min = -280
	p.angular_velocity_max = 280
	p.angle_min = 0
	p.angle_max = 360
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var g: = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
	g.colors = PackedColorArray([col.lightened(0.25), col, Color(col, 0.0)])
	p.color_ramp = g
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


# ── signature moves ────────────────────────────────────────────────────────────────────────────────────────────

# Печать-ханко (UX §6.8): falls 140 ms, one squash frame, a dull «тук», cinnabar seeps in over 300 ms
static func hanko(parent: Node, center: Vector2, glyph: = "受", size: = 64.0) -> Control:
	var c: = Control.new()
	c.size = Vector2(size, size)
	c.position = center - c.size * 0.5
	c.pivot_offset = c.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sq: = Panel.new()
	sq.size = c.size
	var sb: = box(Color(CINNABAR, 0.0), 6, CINNABAR, 4)
	sq.add_theme_stylebox_override("panel", sb)
	c.add_child(sq)
	var l: = label(glyph, int(size * 0.5), CINNABAR, "title", 800)
	l.size = c.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	c.rotation = deg_to_rad(randf_range(-9, -3))
	parent.add_child(c)
	c.scale = Vector2.ONE * 1.7
	c.modulate.a = 0.0
	var t: = c.create_tween()
	t.tween_property(c, "modulate:a", 0.75, 0.06)
	t.parallel().tween_property(c, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		sfx("hanko", "flip", randf_range(0.95, 1.05))
		V9Feel.haptic("button"))
	t.tween_property(c, "scale", Vector2(1.12, 0.86), 0.03)
	t.tween_property(c, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(c, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(sb, "bg_color", Color(CINNABAR, 0.16), 0.3)
	return c


# a reward chip: tile-shaped card (bevel 12) with icon and «+50»
static func chip(row: Dictionary, w: = 112.0) -> Control:
	var c: = Control.new()
	c.size = Vector2(w, w * 1.18)
	c.pivot_offset = c.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: = panel(Rect2(Vector2.ZERO, c.size), NIGHT700, 12, Color(GOLD700, 0.55), 1)
	c.add_child(bg)
	var ic: = tex(str(row.get("icon", "")), Rect2(w * 0.18, w * 0.1, w * 0.64, w * 0.64))
	c.add_child(ic)
	var txt: = "+%d" % int(row.get("n", 1)) if not (row.kind in ["frame", "title", "badge", "pick_outfit"]) else str(V10RitBridge.NAMES.get(row.kind, ""))
	var l: = label(txt, 22 if txt.length() < 6 else 15, GOLD300, "num")
	l.position = Vector2(0, w * 0.78)
	l.size = Vector2(w, w * 0.34)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	return c


# Rewards arrive as a cascade of chips, 80 ms apart, each on a rising pentatonic note (UX §6.7: no coin fountains).
# fly_to: global target (a counter) or Vector2.INF to just settle in a row at `at`. Returns the total time.
static func cascade(parent: Control, rows: Array, at: Vector2, fly_to: = Vector2.INF, on_land: = Callable()) -> float:
	var w: = 104.0
	var gap: = 14.0
	var total_w: = rows.size() * w + (rows.size() - 1) * gap
	var x0: = at.x - total_w * 0.5
	var full: = V9Feel.can_fx()
	for i in rows.size():
		var c: = chip(rows[i], w)
		c.position = Vector2(x0 + i * (w + gap), at.y - c.size.y * 0.5)
		parent.add_child(c)
		var d: = 0.08 * i
		c.modulate.a = 0.0
		c.scale = Vector2.ONE * (0.6 if full else 1.0)
		var t: = c.create_tween()
		t.tween_interval(d)
		t.tween_callback(func(): note(i, "pop", -6.0))
		t.tween_property(c, "modulate:a", 1.0, 0.12 if full else 0.12)
		if full:
			t.parallel().tween_property(c, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(c, "position:y", c.position.y - 16, 0.32).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		if fly_to != Vector2.INF:
			t.tween_interval(0.45 + 0.04 * (rows.size() - i))
			var dest: = fly_to - parent.global_position - c.size * 0.5
			t.tween_property(c, "position", dest, 0.42).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(c, "scale", Vector2.ONE * 0.35, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(c, "modulate:a", 0.0, 0.42).set_delay(0.24)
			t.tween_callback(func():
				if on_land.is_valid():
					on_land.call(rows[i])
				c.queue_free())
	return 0.08 * rows.size() + (1.3 if fly_to != Vector2.INF else 0.4)


# a number that rolls from a to b (Nunito 900)
static func roll(l: Label, a: int, b: int, dur: = 0.6, fmt: = "%d") -> void:
	var t: = l.create_tween()
	t.tween_method(func(v: float): l.text = fmt % int(round(v)), float(a), float(b), dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


# «Вдох»: ≤5 elements fade in, +12 px, 40 ms apart (UX §6.7)
static func inhale(nodes: Array, start: = 0.0) -> void:
	for i in nodes.size():
		var n = nodes[i]
		if not (n is CanvasItem):
			continue
		var y0: float = n.position.y
		n.modulate.a = 0.0
		n.position.y = y0 + (12.0 if V9Feel.can_fx() else 0.0)
		var t: Tween = n.create_tween()
		t.tween_interval(start + 0.04 * mini(i, 5))
		t.tween_property(n, "modulate:a", 1.0, 0.24 if V9Feel.can_fx() else 0.12)
		t.parallel().tween_property(n, "position:y", y0, 0.24).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


# heroine voice line: written with a pen in 0.4 s, holds, fades (UX §6.3)
static func voice(parent: Control, text: String, pos: Vector2, w: = 460.0, size: = 34, hold: = 4.0) -> Label:
	var l: = wrap_w(label(text, size, PAPER100, "hand"), w)
	l.position = pos
	l.visible_ratio = 0.0
	parent.add_child(l)
	var t: = l.create_tween()
	t.tween_property(l, "visible_ratio", 1.0, 0.4 + 0.012 * text.length())
	if hold > 0.0:
		t.tween_interval(hold)
		t.tween_property(l, "modulate:a", 0.0, 0.3)
	return l
