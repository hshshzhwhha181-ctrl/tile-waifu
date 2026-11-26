class_name V10HudHome
extends Control

# V10HudHome — «Чайная» in v2 metrics (docs/HUD_V2.md §8.2, mockup 03). The heroine owns the screen (≥ 35 %);
# the interface lies beside her: avatar + nick, «Телефон», three lanterns (Сегодня · Салон · Серия), the
# vertical spine «ЧАЙНАЯ · ВЕЧЕР», the partner plate (M 200x80), ONE «Играть · 1-4» pill, a dark underlay only
# under the action row, and 5 equal tabs. No currencies, no medallions, no stickers.
#
#   var h := V10HudHome.new(); add_child(h); h.configure({"hero": "mc", "nick": "Гость", "level": "1-4", "path": "Чайный сад", "affinity": 6})
#   signals: play_pressed, partner_pressed, phone_pressed, tab_pressed(i), lantern_pressed(i)

signal play_pressed
signal partner_pressed
signal phone_pressed
signal tab_pressed(i: int)
signal lantern_pressed(i: int)

const TABS: = [["tab_tea", "Чайная"], ["tab_heroines", "Героини"], ["tab_tables", "Столы"], ["tab_wishes", "Желания"], ["tab_shop", "Лавка"]]
const LANTERNS: = ["Сегодня", "Салон", "Серия"]

var hero_id: = "mc"
var nick: = "Гость"
var level: = "1-4"
var path_name: = "Чайный сад"
var affinity: = 6
var lit: = [true, false, true]
var own_figure: = false  # the screen already shows her (rig / video): do not add a second figure
# integration (W1): the host screen owns the backdrop and main.gd owns the navbar; staged lanterns (UX §3.5)
var own_backdrop: = false
var own_nav: = false
var shown: = [true, true, true]
var phone_shown: = true
var phone_dot: = true
var phone_count: = 0
var L: = {}

var backdrop: TextureRect
var rig: Node2D
var under: Control
var deco: Control
var nick_l: Label
var spine_l: Label
var lantern_ls: = []
var lantern_tr: = []
var partner: V10Plate
var play_b: V10Button
var phone_b: V10Button
var nav: Control
var tab_ls: = []
var glow: GradientTexture2D


static func compute(vs: Vector2, ins: Dictionary) -> Dictionary:
	var W: = vs.x
	var H: = vs.y
	var T: = float(ins.get("top", 0.0))
	var B: = float(ins.get("bottom", 0.0))
	var cx: = floorf(maxf(0.0, (W - 720.0) * 0.5))
	var d: = {"vs": vs, "T": T, "B": B, "cx": cx}
	d.avatar = Rect2(cx + 24, T + 16, 56, 56)
	d.nick = Rect2(cx + 96, T + 24, 360, 40)
	d.phone = Rect2(cx + 616, T + 4, 80, 80)
	var lan: = []
	for i in 3:
		lan.append(Rect2(cx + 40 + i * 112, T + 104, 72, 96))
	d.lanterns = lan
	d.spine = Rect2(cx + 0, T + 240, 32, 600)
	d.nav = Rect2(0, H - B - 136, W, 136 + B)
	d.play = Rect2(cx + 248, d.nav.position.y - 192, 440, 104)
	d.partner = Rect2(cx + 32, d.play.position.y + 12, 200, 80)
	d.under = Rect2(0, d.play.position.y - 64, W, d.nav.position.y - d.play.position.y + 64)
	# heroine from the knees: face at ~ y 380–440 on 9:16, right of centre; grows with the height
	var s: = clampf((H - T) / 1640.0, 0.78, 1.1) * maxf(1.0, W / 720.0)
	var face_y: = T + 400.0 + (H - 1280.0 - T - B) * 0.25
	d.hero_scale = s
	# her hair ornaments start under the lantern captions, never behind them
	d.hero_pos = Vector2(cx + 720.0 * 0.6 - V10HudMatch.RIG_FACE.x * s, maxf(face_y - V10HudMatch.RIG_FACE.y * s, T + 236.0))
	d.hero_face = Rect2(d.hero_pos + V10HudMatch.RIG_FACE_RECT.position * s, V10HudMatch.RIG_FACE_RECT.size * s)
	return d


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(cfg: Dictionary) -> void:
	hero_id = str(cfg.get("hero", hero_id))
	nick = str(cfg.get("nick", nick))
	level = str(cfg.get("level", level))
	path_name = str(cfg.get("path", path_name))
	affinity = int(cfg.get("affinity", affinity))
	lit = cfg.get("lit", lit)
	own_figure = bool(cfg.get("own_figure", false))
	own_backdrop = bool(cfg.get("own_backdrop", false))
	own_nav = bool(cfg.get("own_nav", false))
	shown = cfg.get("shown", shown)
	phone_shown = bool(cfg.get("phone_shown", phone_shown))
	phone_dot = bool(cfg.get("phone_dot", phone_dot))
	phone_count = int(cfg.get("phone_count", phone_count))


func _ready() -> void:
	glow = GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	var g: = Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(Color.WHITE, 0.0))
	glow.gradient = g
	backdrop = TextureRect.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = V10DS.TINT_HOME
	var bp: String = V10HudMatch.RIG_BG.get(hero_id, "res://assets/v10/rig/mc_gown/bg.png")
	if ResourceLoader.exists(bp) and not own_backdrop:
		backdrop.texture = load(bp)
	add_child(backdrop)
	var rp: String = V10HudMatch.RIG_PATHS.get(hero_id, "")
	if rp != "" and ResourceLoader.exists(rp) and not own_figure:
		rig = load(rp).instantiate()
		rig.set("show_background", false)
		add_child(rig)
	under = _Under.new()
	add_child(under)
	deco = _Deco.new()
	deco.h = self
	add_child(deco)
	nick_l = V10Type.label(nick, "ui", 22, V10DS.PAPER_100, true)
	add_child(nick_l)
	phone_b = V10Button.make("quiet", "", Vector2(80, 80))
	phone_b.icon = "phone"
	phone_b.icon_color = V10DS.PAPER_300
	phone_b.pressed.connect(func() -> void: phone_pressed.emit())
	add_child(phone_b)
	spine_l = V10Type.label("ЧАЙНАЯ · ВЕЧЕР", "overline", 15, Color(V10DS.PAPER_500, 0.4))
	spine_l.rotation = -PI * 0.5
	spine_l.clip_text = false
	# off: 15 px text at α 0.4 lying on her hair reads as noise, not as a spine (owner: «дешёвый текст»,
	# HUD_V2 §1.1 «UI не на ней»). The layout rect stays for a future painted spine outside her silhouette.
	spine_l.visible = false
	add_child(spine_l)
	for i in 3:
		var lt: = TextureRect.new()
		lt.texture = load("res://assets/v09/summon/lantern_r.png")  # the painted lantern (§4: items are painted)
		lt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lt.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		lt.modulate = Color.WHITE if lit[i] else V10DS.PAPER_700.darkened(0.35)
		lt.mouse_filter = Control.MOUSE_FILTER_STOP
		lt.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				lantern_pressed.emit(i))
		add_child(lt)
		lantern_tr.append(lt)
	for i in 3:
		var l: = V10Type.label(LANTERNS[i], "ui", 18, V10DS.PAPER_300 if lit[i] else V10DS.PAPER_500, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = false
		add_child(l)
		lantern_ls.append(l)
	partner = V10Plate.make("M", 200, V10DS.hero(hero_id).name, "Симпатия · %d" % affinity, "", "")
	partner.interactive = true
	partner.pressed.connect(func() -> void: partner_pressed.emit())
	add_child(partner)
	play_b = V10Button.make("play", "Играть · %s" % level, Vector2(440, 104))
	play_b.overline = "Путь · %s" % path_name
	play_b.pressed.connect(func() -> void: play_pressed.emit())
	add_child(play_b)
	nav = _Nav.new()
	nav.h = self
	nav.visible = not own_nav
	add_child(nav)
	for i in (0 if own_nav else TABS.size()):
		var tl: = V10Type.label(TABS[i][1], "ui", 18, V10DS.GOLD_300 if i == 0 else V10DS.PAPER_500)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(tl)
		tab_ls.append(tl)
	get_viewport().size_changed.connect(layout_now)
	layout_now()


func layout_now() -> void:
	var vs: = get_viewport_rect().size
	L = compute(vs, V10Hud2Util.safe_insets(vs))
	backdrop.position = Vector2.ZERO
	backdrop.size = vs
	if rig:
		rig.position = L.hero_pos
		rig.scale = Vector2.ONE * float(L.hero_scale)
	under.position = (L.under as Rect2).position
	under.size = (L.under as Rect2).size
	deco.position = Vector2.ZERO
	deco.size = vs
	nick_l.position = (L.nick as Rect2).position
	nick_l.size = (L.nick as Rect2).size
	phone_b.visible = phone_shown
	phone_b.position = (L.phone as Rect2).position
	var sp: Rect2 = L.spine
	spine_l.size = Vector2(sp.size.y, sp.size.x)
	spine_l.position = Vector2(sp.position.x, sp.end.y)
	for i in 3:
		var r: Rect2 = L.lanterns[i]
		lantern_tr[i].visible = bool(shown[i])
		lantern_ls[i].visible = bool(shown[i])
		lantern_tr[i].position = r.position
		lantern_tr[i].size = r.size
		lantern_ls[i].position = Vector2(r.position.x - 20, r.end.y + 8)
		lantern_ls[i].size = Vector2(r.size.x + 40, 26)
	partner.position = (L.partner as Rect2).position
	play_b.position = (L.play as Rect2).position
	nav.position = (L.nav as Rect2).position
	nav.size = (L.nav as Rect2).size
	var nr: Rect2 = L.nav
	var cw: = minf(720.0, nr.size.x) / 5.0
	var x0: = nr.position.x + (nr.size.x - cw * 5.0) * 0.5
	for i in tab_ls.size():
		tab_ls[i].position = Vector2(x0 + i * cw, nr.position.y + 76)
		tab_ls[i].size = Vector2(cw, 26)
	deco.queue_redraw()
	nav.queue_redraw()


class _Under:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c0: = Color(V10DS.NIGHT_900, 0.0)
		var c1: = Color(V10DS.NIGHT_900, 0.85)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]), PackedColorArray([c0, c0, c1, c1]))


class _Deco:
	extends Control
	var h: V10HudHome

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if h == null or h.L.is_empty():
			return
		var L: Dictionary = h.L
		# avatar 56 in a 1 px gold.700 ring
		var ar: Rect2 = L.avatar
		var c: = ar.get_center()
		draw_circle(c, 28, Color(V10DS.NIGHT_800, 0.9), true, -1.0, true)
		draw_arc(c, 28, 0, TAU, 64, V10DS.GOLD_700, 1.0, true)
		V10Icons.draw(self, "avatar_ring", c, 40, V10DS.PAPER_500)
		# «new» dot on the phone (12 px rose.300, no rim)
		# «new» badge on the phone (UX §3.6: Телефон is the ONLY number badge on Tea House; 9+ cap)
		var pr: Rect2 = L.phone
		if h.phone_shown and h.phone_count > 0:
			var bt: = "9+" if h.phone_count > 9 else str(h.phone_count)
			var bc: = pr.get_center() + Vector2(16, -16)
			var bw: = 32.0 if bt.length() > 1 else 26.0
			var box: = StyleBoxFlat.new()
			box.bg_color = V10DS.ROSE_500
			box.set_corner_radius_all(13)
			draw_style_box(box, Rect2(bc - Vector2(bw * 0.5, 13), Vector2(bw, 26)))
			var bf: = V10Type.font("ui")
			var ts: = bf.get_string_size(bt, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
			draw_string(bf, Vector2(bc.x - ts.x * 0.5, bc.y + ts.y * 0.28), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, V10DS.NIGHT_900)
		elif h.phone_shown and h.phone_dot:
			draw_circle(pr.get_center() + Vector2(14, -18), 6, V10DS.ROSE_300, true, -1.0, true)
		# threads of the three lanterns (the lanterns themselves are painted TextureRects)
		for i in 3:
			if not bool(h.shown[i]):
				continue
			var r: Rect2 = L.lanterns[i]
			var x: = r.get_center().x
			# the thread fades in under the header row: it never crosses the avatar ring or the nick
			var y0: = (L.avatar as Rect2).end.y + 8.0
			draw_polyline_colors(PackedVector2Array([Vector2(x, y0), Vector2(x, r.position.y + 4)]),
					PackedColorArray([Color(V10DS.PAPER_700, 0.0), Color(V10DS.PAPER_700, 0.5)]), 1.0, true)
			if bool(h.lit[i]):
				draw_texture_rect(h.glow, Rect2(r.get_center() - Vector2(64, 64), Vector2(128, 128)), false, Color(V10DS.GOLD_500, 0.22))


class _Nav:
	extends Control
	var h: V10HudHome

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(V10DS.NIGHT_900, 0.94))
		V10Plate.hairline(self, 24.0, size.x - 24.0, 0.5, Color(V10DS.GOLD_700, V10DS.HAIR_A))
		var cw: = minf(720.0, size.x) / 5.0
		var x0: = (size.x - cw * 5.0) * 0.5
		for i in V10HudHome.TABS.size():
			var c: = Vector2(x0 + cw * (i + 0.5), 44)
			V10Icons.draw(self, V10HudHome.TABS[i][0], c, 48, V10DS.GOLD_300 if i == 0 else V10DS.PAPER_500)

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			var cw: = minf(720.0, size.x) / 5.0
			var x0: = (size.x - cw * 5.0) * 0.5
			var i: = int((e.position.x - x0) / cw)
			if i >= 0 and i < 5:
				h.tab_pressed.emit(i)
			accept_event()
