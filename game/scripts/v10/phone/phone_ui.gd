class_name V10PhoneUI
extends RefCounted

# Look and feel of the «Телефон» (docs/0.10-spec.md §Р8 п.2): a lacquered game phone in the HUD colours, never an
# imitation of Android. Palette, fonts (Nunito for bubbles, Caveat 600 for the founders' handwriting when V10Fonts is
# merged, Playfair italic until then), StyleBox helpers, sounds and the tap-vs-scroll rule.
# Every tappable thing goes through V10PhoneUI.tap() → V9Feel.press (spring 0.94 → 1.0, sound, haptic).

const INK: = Color("2a1a22")          # text on her ivory bubble
const INK_SOFT: = Color("6e5a62")
const CREAM: = Color("f7eee4")        # her bubble
const CREAM_B: = Color("efe1d3")
const MINE_A: = Color("e59ab0")       # my bubble gradient top
const MINE_B: = Color("c06a86")
const SCREEN_A: = Color("221823")     # phone screen background
const SCREEN_B: = Color("130d15")
const LACQUER_A: = Color("3b2230")    # case lacquer
const LACQUER_B: = Color("1c0f17")
const GOLD: = Color("e8c47e")
const GOLD_D: = Color("a8742a")
const TEXT: = Color("f5ead8")
const MUTED: = Color("b3a89c")
const DOT: = Color("ff5d7e")

const CAVEAT: = "res://assets/v10/fonts/caveat/caveat-600.woff2"
const SFX_DIR: = "res://assets/v10/phone/sfx/"
const TAP_SLOP: = 14.0

static var _hand: Font = null
static var _cache: = {}


static func body(weight: = 800) -> Font:
	return UI.font("body", weight)


# her handwriting (names in the chat list, signatures): Caveat 600 when the fonts lane is merged
static func hand() -> Font:
	if _hand == null:
		if ResourceLoader.exists(CAVEAT):
			_hand = load(CAVEAT)
		else:
			var fv: = FontVariation.new()
			fv.base_font = load("res://assets/fonts/playfair-i-cyr.woff2")
			var fb: = FontVariation.new()
			fb.base_font = load("res://assets/fonts/playfair-i-lat.woff2")
			fv.fallbacks = [fb]
			fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
			_hand = fv
	return _hand


static func has_caveat() -> bool:
	return ResourceLoader.exists(CAVEAT)


static func label(text: String, size: int, color: Color, font: Font = null, outline: = 0, out_col: = Color(0, 0, 0, 0.5)) -> Label:
	var l: = Label.new()
	l.text = text
	var ls: = LabelSettings.new()
	ls.font = font if font != null else body(800)
	ls.font_size = size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = out_col
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box(top: Color, radius: float, border: = 0.0, border_col: = Color(0, 0, 0, 0), shadow: = 0, shadow_col: = Color(0, 0, 0, 0.35)) -> StyleBoxFlat:
	var s: = StyleBoxFlat.new()
	s.bg_color = top
	s.set_corner_radius_all(int(radius))
	s.corner_detail = 10
	s.anti_aliasing = true
	if border > 0.0:
		s.set_border_width_all(int(border))
		s.border_color = border_col
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = shadow_col
		s.shadow_offset = Vector2(0, shadow * 0.35)
	return s


static func panel(rect: Rect2, sb: StyleBox) -> Panel:
	var p: = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# vertical gradient texture (cached), used for the case, screen and my bubbles
static func grad(a: Color, b: Color, horizontal: = false) -> GradientTexture2D:
	var key: = "%s%s%s" % [a.to_html(), b.to_html(), horizontal]
	if _cache.has(key):
		return _cache[key]
	var g: = Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t: = GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0) if horizontal else Vector2(0, 1)
	_cache[key] = t
	return t


static func grad_rect(rect: Rect2, a: Color, b: Color, horizontal: = false) -> TextureRect:
	var r: = TextureRect.new()
	r.texture = grad(a, b, horizontal)
	r.position = rect.position
	r.size = rect.size
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# hard ellipsis for a one-line label (the Label's own overrun does not shrink a label that already took its text width)
static func ellipsize(l: Label, width: float) -> void:
	var f: Font = l.label_settings.font
	var fs: int = l.label_settings.font_size
	var w: = width - 4.0
	var t: = l.text
	if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
		l.size.x = width
		return
	var lo: = 0
	var hi: = t.length()
	while lo < hi:
		var mid: = (lo + hi + 1) / 2
		if f.get_string_size(t.substr(0, mid).strip_edges() + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
			lo = mid
		else:
			hi = mid - 1
	l.text = t.substr(0, lo).strip_edges() + "…"
	l.size.x = w + 4.0


# --- sound ---------------------------------------------------------------------------------

const SFX_GROUP: = "v10_phone_sfx"


static func snd(name: String, pitch: = 1.0, db: = 0.0) -> void:
	if not bool(G.S.get("sound", true)):
		return
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var path: = SFX_DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		Sfx.play(name, pitch, db)
		return
	# the pool lives in the tree (group), never in a static: nothing outlives the SceneTree at exit
	var p: AudioStreamPlayer = null
	var pool: = tree.get_nodes_in_group(SFX_GROUP)
	for q in pool:
		if not (q as AudioStreamPlayer).playing:
			p = q
			break
	if p == null:
		if pool.size() >= 6:
			p = pool[0]
		else:
			p = AudioStreamPlayer.new()
			p.add_to_group(SFX_GROUP)
			tree.root.add_child(p)
	if not _cache.has(path):
		_cache[path] = load(path)
	p.stream = _cache[path]
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()


# --- input ---------------------------------------------------------------------------------

# tap on a node inside a ScrollContainer: dips on touch, fires on a release that moved less than TAP_SLOP px
# (a finger that starts a scroll springs it back without firing). press_snd "" = silent (the action plays its own).
static func tap(n: Control, cb: Callable, press_snd: = "pop", hold_cb: Callable = Callable()) -> void:
	n.mouse_filter = Control.MOUSE_FILTER_PASS
	var st: = {"down": false, "p": Vector2.ZERO, "t": 0, "held": false}
	n.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				st.down = true
				st.held = false
				st.p = e.global_position
				st.t = Time.get_ticks_msec()
				V9Feel.press_down(n)
				if hold_cb.is_valid():
					var tm: = n.get_tree().create_timer(0.45)
					tm.timeout.connect(func():
						if st.down and is_instance_valid(n) and Time.get_ticks_msec() - int(st.t) >= 440:
							st.held = true
							st.down = false
							V9Feel.press_up(n, false)
							V9Feel.haptic("select")
							hold_cb.call())
			elif st.down:
				st.down = false
				var ok: bool = (e.global_position - st.p).length() < TAP_SLOP
				V9Feel.press_up(n, ok, press_snd if press_snd != "" else "tap")
				if ok:
					cb.call()
		elif e is InputEventMouseMotion and st.down and (e.global_position - st.p).length() >= TAP_SLOP:
			st.down = false
			V9Feel.press_up(n, false))


# red unread badge with a number (or a dot when n == 0 and dot == true)
static func badge(n: int, at: Vector2, dot: = false) -> Control:
	var c: = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.name = "Badge"
	var txt: = "" if n <= 0 else ("99+" if n > 99 else str(n))
	var w: = 18.0 if txt == "" else maxf(30.0, body(900).get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 18.0)
	var h: = 18.0 if txt == "" else 30.0
	c.size = Vector2(w, h)
	c.position = at - c.size * 0.5
	c.pivot_offset = c.size * 0.5
	var p: = panel(Rect2(Vector2.ZERO, c.size), box(DOT, h * 0.5, 2.0, Color("2a0f18"), 4, Color(0.6, 0.05, 0.2, 0.45)))
	c.add_child(p)
	if txt != "":
		var l: = label(txt, 18, Color.WHITE, body(900))
		l.size = c.size
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.add_child(l)
	if not dot and n <= 0:
		c.visible = false
	return c


static func pop_in(n: CanvasItem, delay: = 0.0, from: = 0.6, dur: = 0.42) -> void:
	if not is_instance_valid(n):
		return
	n.scale = Vector2.ONE * from
	n.modulate.a = 0.0
	var t: = n.create_tween().set_parallel()
	t.tween_property(n, "scale", Vector2.ONE, dur).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "modulate:a", 1.0, dur * 0.5).set_delay(delay)


# little hearts / sparkles burst (feed double-tap, like); count follows V9Feel.fx_scale
static func burst(parent: Control, at: Vector2, color: Color, count: = 16, glyph: = "♥", spread: = 150.0) -> void:
	var k: = V9Feel.fx_scale()
	var n: = int(round(count * k))
	if n <= 0:
		return
	for i in n:
		var l: = label(glyph, randi_range(22, 40), color.lerp(Color.WHITE, randf() * 0.35), body(900), 3, Color(0.25, 0.02, 0.1, 0.6))
		l.position = at - Vector2(14, 22)
		l.pivot_offset = Vector2(14, 22)
		parent.add_child(l)
		var ang: = TAU * float(i) / n + randf_range(-0.25, 0.25)
		var dist: = spread * randf_range(0.55, 1.0)
		var dest: = l.position + Vector2(cos(ang), sin(ang) - 0.35) * dist
		var t: = l.create_tween().set_parallel()
		t.tween_property(l, "position", dest, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(l, "rotation", randf_range(-0.6, 0.6), 0.7)
		t.tween_property(l, "scale", Vector2.ONE * randf_range(0.6, 1.2), 0.7)
		t.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
		t.chain().tween_callback(l.queue_free)
