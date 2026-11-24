class_name V10CardView
extends Control

# V10CardView — the stylised player card of Profile 2.0 (docs/0.10-spec.md §D5/§D6), built in code on the 0.8 HUD
# kit: gold-rimmed graphite plate, the chosen card background (blurred, shaded), the showcase goddess in the 0.8
# rarity card frame, the avatar in a V10FrameView, nick, title in its rarity colour, rank + league emblems,
# 3 badge medallions, stats tiles with the tile-back miniature.
#
#   V10CardView.make(payload, rect, mode) -> V10CardView     payload = V10CardPayload.mine(S) / sim() / server data
#     mode "other"  660×880  tap on a league row / duel opponent (V8PlayerCard.open builds this)
#          "own"    672×560  the profile screen's identity block («Оформить карточку» → edit_requested)
#          "row"    W×84     league / quarter rows: static frame, no animation, no taps of its own
#          "poster" 660×880  like other, static (sharing, 1.0)
#   rect.size: for own / other / poster the card is laid out at its design size and scaled uniformly to fit;
#   for row the width is taken as is (height 84).
#
# Juice (all through V9Feel; gated by S.fx_level): staggered reveal (plate spring, showcase slide, frame pop, title
# stamp, badges pop with a sparkle on SSR), hover lift + tilt + sheen sweep (mouse), press springs on showcase /
# avatar / title / badges, hearts on the showcase (no affection change), badge tooltip.
#
# Signals: showcase_tapped(hero) · avatar_tapped · title_tapped · badge_tapped(id) · edit_requested

signal showcase_tapped(hero: String)
signal avatar_tapped
signal title_tapped
signal badge_tapped(id: String)
signal edit_requested

const SIZES: = {"other": Vector2(660, 880), "poster": Vector2(660, 880), "own": Vector2(672, 560)}
const ROW_H: = 84.0
const SKIN_COL: = {"s_sakura": ["ffb7c9", "c0506e"], "s_mint": ["a9e6cc", "2f8a6c"], "s_lemon": ["ffe58a", "c08a1e"],
	"s_night": ["7d86c9", "232a5e"], "s_neon": ["ff7ad9", "3a1f6e"], "s_gold": ["ffe08a", "a8641a"]}
const SHEEN_SHADER: = "shader_type canvas_item;\nuniform vec2 size = vec2(660.0, 880.0);\nuniform float radius = 32.0;\n" + \
	"uniform float pos = -1.0;\nuniform float amount = 0.22;\n" + \
	"float sd(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }\n" + \
	"void fragment() {\n\tvec2 p = UV * size;\n\tfloat a = 1.0 - smoothstep(-0.8, 0.8, sd(p - size * 0.5, size * 0.5, radius));\n" + \
	"\tfloat band = exp(-pow((UV.x * 0.75 + UV.y * 0.45 - pos) / 0.06, 2.0)) + 0.35 * exp(-pow((UV.x * 0.75 + UV.y * 0.45 - pos + 0.12) / 0.025, 2.0));\n" + \
	"\tCOLOR = vec4(1.0, 0.97, 0.9, band * amount * a);\n}\n"

var data: = {}
var mode: = "other"
var interactive: = true
var anim: = true
var base_size: = Vector2.ZERO
var tier: = "A"
var frame_view: V10FrameView
var showcase: Control
var showcase_art: TextureRect
var title_node: Control
var nick_label: Label
var badge_nodes: = []
var tiles: = []
var plate: RBox
var bg: TextureRect
var sheen: ColorRect
var _sheen_mat: ShaderMaterial
var _hover: = false
var _tip: Control
var _rest_scale: = Vector2.ONE


# opts: {"interactive": bool, "anim": bool} override the mode defaults (the editor's live preview is a static «other»)
static func make(payload: Dictionary, rect: Rect2, view_mode: = "other", opts: = {}) -> V10CardView:
	var v: = V10CardView.new()
	v.data = payload
	v.mode = view_mode if view_mode in ["other", "own", "row", "poster"] else "other"
	v.name = "V10Card_" + v.mode
	v.position = rect.position
	v.interactive = bool(opts.get("interactive", v.mode in ["other", "own"]))
	v.anim = bool(opts.get("anim", v.mode in ["other", "own"])) and V10FrameView.fx_on()
	if v.mode == "row":
		v.size = Vector2(maxf(rect.size.x, 360.0), ROW_H)
		v.base_size = v.size
		v._build_row()
	else:
		v.base_size = SIZES[v.mode]
		v.size = v.base_size
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			var k: = minf(rect.size.x / v.base_size.x, rect.size.y / v.base_size.y)
			v.scale = Vector2(k, k)
			v._rest_scale = v.scale
			# the card scales around its centre (reveal / hover springs): shift so the scaled card sits at rect
			v.position = rect.position - v.base_size * 0.5 * (1.0 - k)
		v._build_card()
	return v


# ------------------------------------------------------------------------------------------------ data helpers

func _s(key: String, def: = "") -> String:
	return String(data.get(key, def))


func _sc() -> Dictionary:
	var sc = data.get("showcase", {})
	return sc if sc is Dictionary else {}


func _rank_tier() -> int:
	return clampi(int(data.get("rank", {}).get("tier", 0)), 0, G.RANKS.size() - 1)


func _rank_sub() -> int:
	return int(data.get("rank", {}).get("sub", 0))


func _rank_text() -> String:
	var t: = _rank_tier()
	var sub: = _rank_sub()
	var suffix: String = str(sub + 1) if t == G.RANKS.size() - 1 else G.ROMAN[clampi(sub, 0, 2)]
	return "%s %s" % [G.RANKS[t].name, suffix]


func _title_entry() -> Dictionary:
	var e: = V10ProfileCos.entry(_s("title", V10ProfileCos.DEFAULT.title))
	return e if not e.is_empty() else V10ProfileCos.entry(V10ProfileCos.DEFAULT.title)


func _outfit_rar() -> String:
	return V10ProfileCos.outfit_rar(String(_sc().get("outfit", "o_base")))


func _modest() -> bool:
	return bool(G.S.get("modest", false)) or mode == "poster"


# ------------------------------------------------------------------------------------------------ build: card

func _build_card() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	pivot_offset = base_size * 0.5
	var W: = base_size.x
	var H: = base_size.y
	var fe: = V10ProfileCos.entry(_s("frame", V10ProfileCos.DEFAULT.frame))
	tier = String(fe.get("tier", "A"))
	var tc: = V10ProfileCos.tier_col(tier)
	# plate: graphite with the gold rim of the kit; S / SSR frames add a soft halo in the rarity colour
	plate = UI.rbox("graphite", Rect2(Vector2.ZERO, base_size), 36, 5, 18)
	plate.borders(Color("fff0c2"), Color("9a6a26"))
	plate.set_param("glow_color", tc)
	plate.set_param("glow", 0.0 if tier == "A" else (0.35 if tier == "S" else 0.6))
	plate.set_param("shadow_offset", Vector2(0, 10))
	plate.set_param("shadow_blur", 18.0)
	plate.name = "Plate"
	add_child(plate)
	_build_bg(Rect2(6, 6, W - 12, H - 12), 31.0)
	var il: = _InnerLine.new()
	il.position = Vector2(14, 14)
	il.size = Vector2(W - 28, H - 28)
	add_child(il)
	if mode == "own":
		_layout_own(W, H)
	else:
		_layout_other(W, H)
	_add_sheen(W, H)
	if interactive:
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))
		gui_input.connect(_on_card_input)
	if anim:
		reveal.call_deferred()


func _build_bg(r: Rect2, radius: float) -> void:
	var e: = V10ProfileCos.entry(_s("card_bg", V10ProfileCos.DEFAULT.card_bg))
	if e.is_empty():
		e = V10ProfileCos.entry(V10ProfileCos.DEFAULT.card_bg)
	var path: = String(e.tex)
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else V8Art.bg("profile")
	bg = UI.tex(t, r, false)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bg.name = "CardBg"
	var m: = ShaderMaterial.new()
	m.shader = preload("res://scripts/v10/profile/card_bg.gdshader")
	m.set_shader_parameter("size", r.size)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("tex_size", Vector2(t.get_width(), t.get_height()))
	var fc: Array = e.get("focus", [0.5, 0.4])
	m.set_shader_parameter("focus", Vector2(fc[0], fc[1]))
	m.set_shader_parameter("zoom", 1.0)
	m.set_shader_parameter("blur", 3.0)
	m.set_shader_parameter("bright", 0.46)
	m.set_shader_parameter("tint", Color(String(e.get("tint", "ffffff"))))
	m.set_shader_parameter("shade", 0.9)
	m.set_shader_parameter("shade_from", 0.36 if mode != "own" else 0.5)
	m.set_shader_parameter("vignette", 0.5)
	m.set_shader_parameter("drift", 1.0 if anim else 0.0)
	bg.material = m
	add_child(bg)


func _add_sheen(W: float, H: float) -> void:
	sheen = ColorRect.new()
	sheen.size = Vector2(W - 12, H - 12)
	sheen.position = Vector2(6, 6)
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.name = "Sheen"
	var sh: = Shader.new()
	sh.code = SHEEN_SHADER
	_sheen_mat = ShaderMaterial.new()
	_sheen_mat.shader = sh
	_sheen_mat.set_shader_parameter("size", sheen.size)
	_sheen_mat.set_shader_parameter("radius", 31.0)
	sheen.material = _sheen_mat
	add_child(sheen)


func sweep(dur: = 0.7, amount: = 0.22) -> void:
	if _sheen_mat == null or not V10FrameView.fx_on():
		return
	_sheen_mat.set_shader_parameter("amount", amount)
	var t: = create_tween()
	t.tween_method(func(v): _sheen_mat.set_shader_parameter("pos", v), -0.3, 1.6, dur).set_trans(Tween.TRANS_SINE)


# --- other / poster: 660 × 880 -----------------------------------------------------------------------------------

func _layout_other(W: float, H: float) -> void:
	var win: = Rect2(W - 300.0 - 24.0, 24.0, 300.0, 447.0)
	_showcase(win)
	var cx: = (24.0 + win.position.x - 14.0) * 0.5 + 4.0
	var colw: = win.position.x - 14.0 - 24.0
	frame_view = V10FrameView.make(_s("frame"), _s("avatar", "mc"), 212.0, {"anim": anim})
	frame_view.position = Vector2(cx - 106.0, 16.0)
	add_child(frame_view)
	_hit(frame_view, Rect2(frame_view.position + Vector2(30, 14), Vector2(152, 152)), _on_avatar)
	nick_label = _nick(Rect2(24, 230, colw, 50), 34, 24)
	title_node = _title_plate(Vector2(cx, 300), colw, 21)
	_emblem_row(Rect2(28, 344, colw, 74), "Ранг", _rank_text(), G.RANKS[_rank_tier()].color.lightened(0.2), "rank")
	var lt: = clampi(int(data.get("league", 0)), 0, V7Ladder.LEAGUES.size() - 1)
	var L: = V7Ladder.league_def(lt)
	_emblem_row(Rect2(28, 422, colw, 74), "Лига недели", String(L.short), (L.color as Color).lightened(0.25), "league")
	_divider(Rect2(24, 518, W - 48, 30), "Значки")
	_badges(Rect2(24, 552, W - 48, 150), 96.0, true)
	var st: Dictionary = data.get("stats", {})
	var tw: = (W - 48.0 - 36.0) / 4.0
	var ty: = 728.0
	var heroes: = "%d/%d" % [int(st.get("heroes", 1)), int(st.get("heroes_total", 20))]
	_tile(Rect2(24, ty, tw, 124), "Богини", heroes, 0)
	_tile(Rect2(24 + (tw + 12) * 1, ty, tw, 124), "Партий\nза неделю", UI.fmt(int(st.get("games_week", 0))), 1)
	_tile(Rect2(24 + (tw + 12) * 2, ty, tw, 124), "Лучшее\nкомбо", "×%d" % int(st.get("best_combo", 0)), 2)
	_skin_tile(Rect2(24 + (tw + 12) * 3, ty, tw, 124), 3)


# --- own: 672 × 560 ----------------------------------------------------------------------------------------------

func _layout_own(W: float, H: float) -> void:
	var wh: = H - 44.0
	var win: = Rect2(W - wh * 0.672 - 22.0, 22.0, wh * 0.672, wh)
	_showcase(win)
	var colw: = win.position.x - 18.0 - 22.0
	var cx: = 22.0 + colw * 0.5
	frame_view = V10FrameView.make(_s("frame"), _s("avatar", "mc"), 168.0, {"anim": anim})
	frame_view.position = Vector2(cx - 84.0, 10.0)
	add_child(frame_view)
	_hit(frame_view, Rect2(frame_view.position + Vector2(24, 10), Vector2(120, 120)), _on_avatar)
	nick_label = _nick(Rect2(22, 170, colw, 42), 30, 22)
	title_node = _title_plate(Vector2(cx, 232), colw, 19)
	_badges(Rect2(22, 266, colw, 96), 78.0, false)
	var st: Dictionary = data.get("stats", {})
	var tw: = (colw - 12.0) * 0.5
	_tile(Rect2(22, 372, tw, 92), "Богини", "%d/%d" % [int(st.get("heroes", 1)), int(st.get("heroes_total", 20))], 0, 30)
	_skin_tile(Rect2(22 + tw + 12, 372, tw, 92), 1)
	var eb: = JButton.make("Оформить карточку", "gold", Rect2(22, 474, colw, 64), null, 22)
	eb.name = "EditButton"
	eb.shine_every = 4.0
	eb.pressed.connect(func(): edit_requested.emit())
	add_child(eb)


# ------------------------------------------------------------------------------------------------ pieces

func _showcase(win: Rect2) -> void:
	var sc: = _sc()
	var outfit: = String(sc.get("outfit", "o_base"))
	var img: = V10ProfileCos.showcase_img(outfit, _modest())
	var rar: = _outfit_rar()
	var old_rar: String = {"A": "R", "S": "SR", "SSR": "SSR"}[rar]
	showcase = Control.new()
	showcase.name = "Showcase"
	showcase.position = win.position
	showcase.size = win.size
	showcase.pivot_offset = win.size * Vector2(0.5, 0.6)
	showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(showcase)
	if rar != "A":
		var gl: = Sprite2D.new()
		gl.texture = G.fx("glow")
		gl.material = Fx.add_mat()
		gl.position = win.size * 0.5
		gl.scale = Vector2(win.size.x / 40.0, win.size.y / 46.0)
		var gc: = V10ProfileCos.tier_col(rar)
		gl.modulate = Color(gc.r, gc.g, gc.b, 0.28 if rar == "S" else 0.38)
		showcase.add_child(gl)
	var inner: = Common.card_inner(old_rar, win.size)
	var path: = "res://assets/outfits/%s.webp" % img
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else load("res://assets/outfits/mc_base.webp")
	var fc: Array = V8Population.face(img)
	var focus: = Vector2(float(fc[0]), clampf(float(fc[1]) + 0.26, 0.3, 0.6))
	showcase_art = Common.card_art(t, inner, focus, 1.1, Common.card_radius(old_rar, win.size))
	showcase_art.name = "Art"
	showcase_art.pivot_offset = inner.size * Vector2(0.5, 0.35)
	var m: = showcase_art.material as ShaderMaterial
	m.set_shader_parameter("bottom_shade", 0.5)
	m.set_shader_parameter("holo", 0.16 if (rar == "SSR" and anim) else 0.0)
	showcase.add_child(showcase_art)
	Common.card_frame(showcase, old_rar, Rect2(Vector2.ZERO, win.size))
	# name plate over the frame's bottom bar: outfit name + rank pill + Созвездие
	var name_txt: = String(G.ITEM.get(outfit, {}).get("name", ""))
	var stars: = clampi(int(data.get("ostars", 0)), 0, 5)
	var pw: = minf(win.size.x - 20.0, 286.0)
	var ph: = 62.0
	var pr: = Rect2((win.size.x - pw) * 0.5, win.size.y - ph - 18.0, pw, ph)
	var pl: = UI.rbox("graphite", pr, 20, 2, 8)
	pl.colors(Color(0.11, 0.09, 0.11, 0.9), Color(0.05, 0.04, 0.05, 0.94))
	pl.borders(Color(1.0, 0.9, 0.7, 0.55), Color(0.55, 0.38, 0.15, 0.6))
	pl.name = "NamePlate"
	showcase.add_child(pl)
	var pill_w: = 46.0 if rar != "SSR" else 58.0
	var pill: = UI.rbox("graphite", Rect2(10, 8, pill_w, 24), 12, 2, 4)
	var rc: = V10ProfileCos.tier_col(rar)
	pill.colors(rc.lightened(0.15), rc.darkened(0.35))
	pill.borders(Color(1, 1, 1, 0.75), V10ProfileCos.TIER_DARK[rar])
	pl.add_child(pill)
	pill.add_child(UI.center_label(UI.label(rar, 15, Color.WHITE, V10ProfileCos.TIER_DARK[rar], 3, "body", 900), Rect2(0, -1, pill_w, 24)))
	var nl: = UI.label(name_txt, 18, Color("fff4dc"), UI.DARK, 3, "body", 900)
	nl.position = Vector2(pill_w + 18, 5)
	nl.size = Vector2(pw - pill_w - 28, 28)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Common.fit_line(nl, nl.size.x, 14)
	pl.add_child(nl)
	var sx: = (pw - 5 * 20.0) * 0.5
	for i in 5:
		var s: = V8Art.star_rect(i < stars, Rect2(sx + i * 20.0, 34, 18, 18))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pl.add_child(s)
	_hit(showcase, Rect2(win.position, win.size), _on_showcase)


func _nick(r: Rect2, big: int, small: int) -> Label:
	var l: = UI.label(_s("nick", "Гость"), big, Color.WHITE, UI.DARK, 5, "body", 900)
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.name = "Nick"
	var f: = UI.font("body", 900)
	var fs: = big
	while fs > small and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 10.0:
		fs -= 2
	l.label_settings.font_size = fs
	add_child(l)
	return l


func _title_plate(center: Vector2, maxw: float, fs: int) -> Control:
	var e: = _title_entry()
	var tc: = V10ProfileCos.tier_col(String(e.tier))
	var txt: = String(e.name)
	var f: = UI.font("body", 900)
	while fs > 14 and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw - 84.0:
		fs -= 1
	var tw: = minf(f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, maxw - 84.0)
	var w: = tw + 84.0
	var h: = fs * 1.9
	var c: = Control.new()
	c.name = "Title"
	c.position = center - Vector2(w, h) * 0.5
	c.size = Vector2(w, h)
	c.pivot_offset = c.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var p: = UI.rbox("graphite", Rect2(Vector2.ZERO, c.size), h * 0.5, 2, 8)
	p.colors(Color(0.13, 0.1, 0.12, 0.92), Color(0.06, 0.05, 0.06, 0.95))
	p.borders(tc.lerp(Color.WHITE, 0.35), V10ProfileCos.TIER_DARK[String(e.tier)])
	if String(e.tier) == "SSR":
		p.set_param("glow", 0.45).set_param("glow_color", tc)
	c.add_child(p)
	# hanko-like seal on the left, a lacquer diamond on the right
	var seal: = _Seal.new()
	seal.col = tc
	seal.position = Vector2(8, (h - 24.0) * 0.5)
	seal.size = Vector2(24, 24)
	c.add_child(seal)
	var dm: = _Seal.new()
	dm.col = tc
	dm.diamond = true
	dm.position = Vector2(w - 30, (h - 16.0) * 0.5)
	dm.size = Vector2(16, 16)
	c.add_child(dm)
	var l: = UI.label(txt, fs, tc.lerp(Color.WHITE, 0.12), UI.DARK, 3, "body", 900)
	l.position = Vector2(40, 0)
	l.size = Vector2(tw + 4.0, h)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(l)
	_hit(c, Rect2(c.position - Vector2(6, 6), c.size + Vector2(12, 12)), _on_title)
	return c


func _emblem_row(r: Rect2, cap: String, val: String, col: Color, kind: String) -> void:
	var e: Control
	if kind == "rank":
		e = Common.rank_emblem(self, Rect2(r.position, Vector2(r.size.y, r.size.y)), _rank_tier(), _rank_sub())
	else:
		e = Common.league_emblem(self, Rect2(r.position, Vector2(r.size.y, r.size.y)), clampi(int(data.get("league", 0)), 0, 5))
	var x: = r.position.x + r.size.y + 12.0
	var cl: = UI.label(cap, 16, UI.MUTED, UI.DARK, 2, "body", 800)
	cl.position = Vector2(x, r.position.y + 8)
	cl.size = Vector2(r.end.x - x, 22)
	add_child(cl)
	var vl: = UI.label(val, 25, col, UI.DARK, 3, "body", 900)
	vl.position = Vector2(x, r.position.y + 30)
	vl.size = Vector2(r.end.x - x, 34)
	Common.fit_line(vl, vl.size.x, 17)
	add_child(vl)


func _divider(r: Rect2, cap: String) -> void:
	var d: = _Divider.new()
	d.position = r.position
	d.size = r.size
	d.caption = cap
	add_child(d)


func _badges(r: Rect2, side: float, names: bool) -> void:
	var ids: Array = data.get("badges", [])
	var n: = V10ProfileCos.BADGE_SLOTS
	var show_empty: = mode == "own"
	var list: = []
	for b in ids:
		if V10ProfileCos.has(String(b), "badge"):
			list.append(String(b))
	if list.is_empty() and not show_empty:
		# three quiet sockets + a line: the card never shows a hole where badges would be
		var sw: = r.size.x / float(n)
		for i in n:
			var em: = _EmptySlot.new()
			em.plus = false
			em.position = Vector2(r.position.x + sw * (i + 0.5) - side * 0.4, r.position.y + side * 0.1)
			em.size = Vector2(side * 0.8, side * 0.8)
			em.modulate.a = 0.55
			add_child(em)
		var l: = UI.label("Значков пока нет", 17, UI.MUTED, UI.DARK, 2, "body", 800)
		UI.center_label(l, Rect2(r.position + Vector2(0, side + 6), Vector2(r.size.x, 26)))
		add_child(l)
		return
	var count: = n if show_empty else list.size()
	var slot_w: = r.size.x / float(n)
	var x0: = r.position.x + (r.size.x - slot_w * count) * 0.5
	for i in count:
		var cx: = x0 + slot_w * (i + 0.5)
		var rr: = Rect2(cx - side * 0.5, r.position.y, side, side)
		if i < list.size():
			var m: = _medal(list[i], rr)
			badge_nodes.append(m)
			if names:
				var e: = V10ProfileCos.entry(list[i])
				var l: = UI.label(String(e.name), 17, UI.INK, UI.DARK, 3, "body", 900)
				UI.center_label(l, Rect2(cx - slot_w * 0.5 + 4, r.position.y + side + 6, slot_w - 8, 26))
				l.clip_text = true
				l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				add_child(l)
		else:
			var em: = _EmptySlot.new()
			em.position = rr.position
			em.size = rr.size
			add_child(em)
			_hit(em, rr, func(): V9Feel.press(em); edit_requested.emit())


static func medal(id: String, r: Rect2) -> Control:
	var e: = V10ProfileCos.entry(id)
	var t: = String(e.get("tier", "A"))
	var tc: = V10ProfileCos.tier_col(t)
	var c: = Control.new()
	c.name = "Badge_" + id
	c.position = r.position
	c.size = r.size
	c.pivot_offset = r.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s: = r.size.x
	if t != "A":
		var gl: = Sprite2D.new()
		gl.texture = G.fx("glow")
		gl.material = Fx.add_mat()
		gl.position = r.size * 0.5
		gl.scale = Vector2.ONE * s / 52.0
		gl.modulate = Color(tc.r, tc.g, tc.b, 0.3 if t == "S" else 0.45)
		c.add_child(gl)
	var ring: = UI.rbox("graphite", Rect2(Vector2.ZERO, r.size), s * 0.5, maxf(2.0, s * 0.03), 6)
	var metal: Array = {"A": [Color("c9f3e2"), Color("2c7a61")], "S": [Color("f3efff"), Color("6a5ea6")], "SSR": [Color("fff1b8"), Color("b2781c")]}[t]
	ring.colors(metal[0], metal[1])
	ring.borders(Color("fff6dc"), Color("7a5218"))
	ring.set_param("gloss", 0.25)
	c.add_child(ring)
	var ins: = s * 0.11
	var disc: = UI.rbox("graphite", Rect2(ins, ins, s - ins * 2.0, s - ins * 2.0), (s - ins * 2.0) * 0.5, 1.5, 4)
	disc.colors(Color(0.2, 0.15, 0.19), Color(0.07, 0.05, 0.07))
	disc.borders(Color(0, 0, 0, 0.6), Color(1, 0.9, 0.7, 0.35))
	disc.set_param("shadow_color", Color(0, 0, 0, 0))
	c.add_child(disc)
	var icon: = String(e.get("icon", "icon/trophy"))
	var tx: = V8Art.tex(icon)
	if tx:
		var ii: = s * 0.2
		var ir: = V8Art.rect(tx, Rect2(ii, ii, s - ii * 2.0, s - ii * 2.0))
		ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(ir)
	return c


func _medal(id: String, r: Rect2) -> Control:
	var c: = medal(id, r)
	add_child(c)
	_hit(c, r, _on_badge.bind(id, c))
	return c


func _tile(r: Rect2, cap: String, val: String, idx: int, vsize: = 34) -> RBox:
	var b: = UI.rbox("glass", r, 22, 2, 6)
	b.borders(Color(1, 0.9, 0.7, 0.38), Color(0, 0, 0, 0.35))
	b.name = "Tile%d" % idx
	b.pivot_offset = r.size * 0.5
	add_child(b)
	var lines: = cap.count("\n") + 1
	var c: = UI.label(cap, 15, UI.MUTED, UI.DARK, 2, "body", 800)
	c.position = Vector2(8, 8)
	c.size = Vector2(r.size.x - 16, 20 * lines)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(c)
	var v: = UI.label(val, vsize, Color("ffe7a6"), UI.DARK, 4, "body", 900)
	v.position = Vector2(6, 8 + 20 * lines)
	v.size = Vector2(r.size.x - 12, r.size.y - 16 - 20 * lines)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Common.fit_line(v, v.size.x, 18)
	b.add_child(v)
	tiles.append(b)
	return b


func _skin_tile(r: Rect2, idx: int) -> void:
	var skin: = _s("tile", "s_sakura")
	var b: = _tile(r, "Фишки", "", idx)
	var tb: = TileBack.new()
	tb.skin = skin
	var th: = minf(r.size.y - 52.0, 64.0)
	tb.size = Vector2(th * 0.76, th)
	tb.position = Vector2((r.size.x - tb.size.x) * 0.5, 30)
	b.add_child(tb)
	var nm: = String(G.ITEM.get(skin, {}).get("name", "")).replace("Фишки ", "").replace("«", "").replace("»", "")
	var l: = UI.label(nm, 14, UI.INK, UI.DARK, 2, "body", 800)
	UI.center_label(l, Rect2(4, r.size.y - 26, r.size.x - 8, 20))
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_child(l)


# ------------------------------------------------------------------------------------------------ build: row

func _build_row() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var W: = size.x
	var me: = bool(data.get("me", false))
	var b: = UI.rbox("glass", Rect2(0, 2, W, ROW_H - 4), 22, 2, 6)
	if me:
		b.colors(Color(0.32, 0.24, 0.16, 0.9), Color(0.16, 0.11, 0.08, 0.92)).borders(Color("ffe7a6"), Color("a8742a"))
	else:
		b.borders(Color(1, 0.9, 0.7, 0.25), Color(0, 0, 0, 0.3))
	b.name = "RowBg"
	add_child(b)
	frame_view = V10FrameView.make(_s("frame"), _s("avatar", "mc"), 84.0, {"anim": false, "glow": false})
	frame_view.position = Vector2(6, -2)
	add_child(frame_view)
	var e: = _title_entry()
	var pts_w: = 120.0
	var x: = 96.0
	var tb_w: = 34.0
	var text_w: = W - x - pts_w - tb_w - 30.0
	var nl: = UI.label(_s("nick", "Гость"), 24, Color.WHITE, UI.DARK, 3, "body", 900)
	nl.position = Vector2(x, 9)
	nl.size = Vector2(text_w, 34)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.name = "Nick"
	add_child(nl)
	nick_label = nl
	var tl: = UI.label(String(e.name), 17, V10ProfileCos.tier_col(String(e.tier)), UI.DARK, 2, "body", 900)
	tl.position = Vector2(x, 44)
	tl.size = Vector2(text_w, 26)
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tl.name = "Title"
	add_child(tl)
	var tbk: = TileBack.new()
	tbk.skin = _s("tile", "s_sakura")
	tbk.size = Vector2(tb_w, tb_w / 0.76)
	tbk.position = Vector2(W - pts_w - tb_w - 14.0, (ROW_H - tbk.size.y) * 0.5)
	add_child(tbk)
	var pl: = UI.label(UI.fmt(int(data.get("pts", 0))), 28, Color("ffe7a6"), UI.DARK, 4, "body", 900)
	pl.position = Vector2(W - pts_w - 4.0, 0)
	pl.size = Vector2(pts_w - 14.0, ROW_H)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.name = "Pts"
	add_child(pl)


# ------------------------------------------------------------------------------------------------ juice

# hit area on top of a visual (taps go to `cb`); visual press feedback is done by the callback
func _hit(visual: Control, r: Rect2, cb: Callable) -> void:
	if not interactive:
		return
	var h: = Control.new()
	h.position = r.position
	h.size = r.size
	h.mouse_filter = Control.MOUSE_FILTER_STOP
	h.name = "Hit_" + visual.name
	h.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# fire on release inside the area (like JButton): a drag that scrolls the profile never pops hearts
	var down: = [false, Vector2.ZERO]
	h.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				down[0] = true
				down[1] = ev.position
			elif down[0]:
				down[0] = false
				if Rect2(Vector2.ZERO, h.size).has_point(ev.position) and ev.position.distance_to(down[1]) < 24.0:
					cb.call())
	h.mouse_entered.connect(func():
		_on_hover(true)
		if is_instance_valid(visual) and V10FrameView.fx_on():
			var t: = visual.create_tween()
			t.tween_property(visual, "modulate", Color(1.08, 1.06, 1.02), 0.12))
	h.mouse_exited.connect(func():
		if is_instance_valid(visual):
			var t: = visual.create_tween()
			t.tween_property(visual, "modulate", Color.WHITE, 0.18))
	add_child(h)


func reveal() -> void:
	if not is_inside_tree() or not anim:
		return
	var k0: = _rest_scale
	scale = k0 * 0.94
	modulate.a = 0.0
	var t: = create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 1.0, 0.22)
	t.tween_property(self, "scale", k0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if showcase:
		var p0: = showcase.position
		showcase.position = p0 + Vector2(36, 0)
		showcase.modulate.a = 0.0
		var ts: = showcase.create_tween().set_parallel()
		ts.tween_property(showcase, "position", p0, 0.45).set_delay(0.08).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		ts.tween_property(showcase, "modulate:a", 1.0, 0.3).set_delay(0.08)
	if frame_view:
		UI.pop_in(frame_view, 0.12, 0.6)
	if nick_label:
		var np: = nick_label.position
		nick_label.position = np + Vector2(0, 14)
		nick_label.modulate.a = 0.0
		var tn: = nick_label.create_tween().set_parallel()
		tn.tween_property(nick_label, "position", np, 0.32).set_delay(0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tn.tween_property(nick_label, "modulate:a", 1.0, 0.25).set_delay(0.2)
	if title_node:
		_stamp(title_node, 0.3)
	for i in badge_nodes.size():
		var bn: Control = badge_nodes[i]
		UI.pop_in(bn, 0.42 + i * 0.09, 0.4)
		var e: = V10ProfileCos.entry(String(bn.name).trim_prefix("Badge_"))
		if String(e.get("tier", "A")) == "SSR":
			get_tree().create_timer(0.55 + i * 0.09).timeout.connect(func():
				if is_instance_valid(bn):
					Fx.burst(self, bn.position + bn.size * 0.5, "sparkle", 10, V10ProfileCos.tier_col("SSR"), 0.45))
	for i in tiles.size():
		var tl: Control = tiles[i]
		var tp: = tl.position
		tl.position = tp + Vector2(0, 22)
		tl.modulate.a = 0.0
		var tt: = tl.create_tween().set_parallel()
		tt.tween_property(tl, "position", tp, 0.36).set_delay(0.5 + i * 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tt.tween_property(tl, "modulate:a", 1.0, 0.25).set_delay(0.5 + i * 0.06)
	get_tree().create_timer(0.75).timeout.connect(func():
		if is_instance_valid(self):
			sweep(0.8, 0.2))


func _stamp(n: Control, delay: float) -> void:
	n.scale = Vector2(1.45, 1.45)
	n.modulate.a = 0.0
	var t: = n.create_tween().set_parallel()
	t.tween_property(n, "modulate:a", 1.0, 0.12).set_delay(delay)
	t.tween_property(n, "scale", Vector2.ONE, 0.26).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_hover(on: bool) -> void:
	if not interactive or _hover == on:
		return
	_hover = on
	if not V10FrameView.fx_on():
		return
	var t: = create_tween().set_parallel()
	t.tween_property(self, "scale", _rest_scale * (1.012 if on else 1.0), 0.22).set_trans(Tween.TRANS_SINE)
	if not on:
		t.tween_property(self, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	if on:
		sweep(0.6, 0.16)


func _on_card_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and _hover and V10FrameView.fx_on():
		var k: = clampf(ev.position.x / base_size.x - 0.5, -0.5, 0.5)
		rotation = lerpf(rotation, k * 0.014, 0.3)


func _on_showcase() -> void:
	V9Feel.press(showcase, "pop", "button")
	if showcase_art and V10FrameView.fx_on():
		var t: = showcase_art.create_tween()
		t.tween_property(showcase_art, "scale", Vector2(1.035, 1.035), 0.1).set_trans(Tween.TRANS_SINE)
		t.tween_property(showcase_art, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var hero: = String(_sc().get("hero", "mc"))
	var hc: Color = G.HEROES.get(hero, {}).get("color", Color("ff7fa8"))
	Fx.burst(self, showcase.position + showcase.size * Vector2(0.5, 0.4), "heart", 8, hc, 0.5)
	# reaction only: the showcase never touches affection (V10Bond is not called from here)
	showcase_tapped.emit(hero)


func _on_avatar() -> void:
	V9Feel.press(frame_view, "pop", "button")
	frame_view.flash()
	avatar_tapped.emit()


func _on_title() -> void:
	V9Feel.press(title_node, "pop", "tap")
	if V10FrameView.fx_on():
		Fx.burst(self, title_node.position + title_node.size * 0.5, "sparkle", 8, V10ProfileCos.tier_col(String(_title_entry().tier)), 0.35)
	title_tapped.emit()


func _on_badge(id: String, node: Control) -> void:
	V9Feel.press(node, "pop", "button")
	if V10FrameView.fx_on():
		Fx.burst(self, node.position + node.size * 0.5, "sparkle", 8, V10ProfileCos.tier_col(String(V10ProfileCos.entry(id).get("tier", "A"))), 0.35)
	_show_tip(id, node)
	badge_tapped.emit(id)


func _show_tip(id: String, node: Control) -> void:
	if _tip and is_instance_valid(_tip):
		_tip.queue_free()
	var e: = V10ProfileCos.entry(id)
	var txt: = "%s\n%s" % [String(e.get("name", "")), V10ProfileCos.hint(id)]
	var w: = 300.0
	var x: = clampf(node.position.x + node.size.x * 0.5 - w * 0.5, 12.0, base_size.x - w - 12.0)
	_tip = Common.bubble(self, txt, Vector2(x, node.position.y - 96.0), w, node.position.x < base_size.x * 0.5)
	_tip.modulate.a = 0.0
	var t: = _tip.create_tween()
	t.tween_property(_tip, "modulate:a", 1.0, 0.15)
	t.tween_interval(1.8)
	t.tween_property(_tip, "modulate:a", 0.0, 0.3)
	t.tween_callback(_tip.queue_free)


# ------------------------------------------------------------------------------------------------ small drawables

# mahjong tile back in the skin's colours (the «рубашка» miniature): slab, lacquered back, inset rim, emblem
class TileBack extends Control:
	var skin: = "s_sakura"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cols: Array = V10CardView.SKIN_COL.get(skin, V10CardView.SKIN_COL.s_sakura)
		var a: = Color(cols[0])
		var b: = Color(cols[1])
		var r: = Rect2(Vector2.ZERO, size)
		var rad: = int(size.x * 0.18)
		var slab: = StyleBoxFlat.new()
		slab.bg_color = Color("efe4cf")
		slab.set_corner_radius_all(rad)
		slab.anti_aliasing = true
		slab.shadow_color = Color(0, 0, 0, 0.45)
		slab.shadow_size = 4
		slab.shadow_offset = Vector2(0, 2)
		draw_style_box(slab, Rect2(r.position + Vector2(0, size.y * 0.06), r.size - Vector2(0, size.y * 0.06)))
		var face: = StyleBoxFlat.new()
		face.bg_color = b
		face.border_color = a
		face.set_border_width_all(maxi(1, int(size.x * 0.06)))
		face.set_corner_radius_all(rad)
		face.anti_aliasing = true
		draw_style_box(face, Rect2(r.position, r.size - Vector2(0, size.y * 0.08)))
		var c: = Vector2(size.x * 0.5, size.y * 0.45)
		var d: = size.x * 0.2
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d * 0.8, 0), c + Vector2(0, d), c + Vector2(-d * 0.8, 0)]), a)
		draw_circle(c, d * 0.28, Color(1, 1, 1, 0.9), true, -1.0, true)
		draw_line(Vector2(size.x * 0.22, size.y * 0.12), Vector2(size.x * 0.78, size.y * 0.12), Color(1, 1, 1, 0.35), 1.5, true)


class _Seal extends Control:
	var col: = Color.WHITE
	var diamond: = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: = size * 0.5
		var r: = size.x * 0.5
		if diamond:
			var p: = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)])
			draw_colored_polygon(p, col.darkened(0.1))
			var loop: = p.duplicate()
			loop.append(p[0])
			draw_polyline(loop, col.lerp(Color.WHITE, 0.5), 1.2, true)
			return
		draw_circle(c, r, Color("b8283c"), true, -1.0, true)
		draw_arc(c, r - 1.0, 0, TAU, 32, Color("ffd9a0"), 1.5, true)
		draw_arc(c, r * 0.62, 0, TAU, 24, Color(1, 0.92, 0.8, 0.85), 1.2, true)
		# four-petal knot
		for i in 4:
			var a: = PI * 0.5 * i + PI * 0.25
			draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.3, r * 0.16, Color(1, 0.92, 0.8, 0.95), true, -1.0, true)


class _Divider extends Control:
	var caption: = ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f: = UI.font("body", 900)
		var fs: = 17
		var tw: = f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cy: = size.y * 0.5
		var gap: = tw * 0.5 + 26.0
		var cx: = size.x * 0.5
		var gold: = Color("e8c47e")
		for side: float in [-1.0, 1.0]:
			var x0: = cx + side * gap
			var x1: = cx + side * (size.x * 0.5 - 4.0)
			var n: = 24
			for i in n:
				var a0: = x0 + (x1 - x0) * i / n
				var a1: = x0 + (x1 - x0) * (i + 1) / n
				var al: = 0.8 * (1.0 - float(i) / n)
				draw_line(Vector2(a0, cy), Vector2(a1, cy), Color(gold.r, gold.g, gold.b, al), 2.0, true)
			var p: = Vector2(cx + side * (gap - 12.0), cy)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(4, 0), p + Vector2(0, 5), p + Vector2(-4, 0)]), gold)
		draw_string_outline(f, Vector2(cx - tw * 0.5, cy + 6), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.6))
		draw_string(f, Vector2(cx - tw * 0.5, cy + 6), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f1dcae"))


class _EmptySlot extends Control:
	var plus: = true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot_offset = size * 0.5

	func _draw() -> void:
		var c: = size * 0.5
		var r: = size.x * 0.5 - 3.0
		draw_circle(c, r, Color(0, 0, 0, 0.3), true, -1.0, true)
		var n: = 28
		for i in n:
			if i % 2 == 0:
				draw_arc(c, r, TAU * i / n, TAU * (i + 1) / n, 4, Color(1, 0.9, 0.7, 0.5), 2.0, true)
		if not plus:
			return
		draw_line(c - Vector2(r * 0.3, 0), c + Vector2(r * 0.3, 0), Color(1, 0.9, 0.7, 0.6), 3.0, true)
		draw_line(c - Vector2(0, r * 0.3), c + Vector2(0, r * 0.3), Color(1, 0.9, 0.7, 0.6), 3.0, true)


# hairline gold rule inside the rim (the «expensive» double border of the 0.8 panels)
class _InnerLine extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb: = StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = Color(1.0, 0.88, 0.62, 0.28)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(24)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
