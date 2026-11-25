class_name V10SalonUI
extends RefCounted

# Small UI kit of the salon screens in the «Тишина и лак» design system (docs/UX_RULES.md §6). When the M1 token
# class DS lands, the colours below are the same hex values (night/paper/gold/rose/jade), so the swap is 1:1.

const NIGHT_900: = Color("121014")
const NIGHT_800: = Color("1b171c")
const NIGHT_700: = Color("26212a")
const NIGHT_600: = Color("332c36")
const PAPER_100: = Color("f5ead8")
const PAPER_300: = Color("ddd2c4")
const PAPER_500: = Color("b3a89c")
const PAPER_700: = Color("7e756d")
const GOLD_300: = Color("f1d9a0")
const GOLD_500: = Color("e8c47e")
const GOLD_700: = Color("a87b3a")
const ROSE_300: = Color("ecc0c9")
const ROSE_500: = Color("d796a5")
const ROSE_700: = Color("9a4f66")
const JADE_300: = Color("a9d9c4")
const JADE_500: = Color("5b9580")
const EMBER: = Color("e07a7a")
const CINNABAR: = Color("c8463c")
# painted reward glyphs (items, not UI: UX §6.4 «предметы пишутся») — one place, for the DS swap
const ITEM_COL: = {"gems": Color("9fd3ff"), "hint": GOLD_300, "shuffle": ROSE_300, "undo": Color("c9b8ff"),
	"leaves": JADE_300, "tickets": Color("ffd08a")}

static var _fonts: = {}
static var _cleanup_armed: = false


# Static caches (fonts, generated textures, class lookups) must be dropped before the RenderingServer and the
# TextServer shut down, or the process aborts on exit («corrupted size vs. prev_size»). The root window leaves
# the tree first at shutdown, so its tree_exiting is the hook; armed once, lazily, by whoever fills a cache.
static func arm_cleanup() -> void:
	if _cleanup_armed:
		return
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_cleanup_armed = true
	if not tree.root.tree_exiting.is_connected(clear_caches):
		tree.root.tree_exiting.connect(clear_caches, CONNECT_ONE_SHOT)


static func clear_caches() -> void:
	_fonts.clear()
	V10SalonFx._soft = null
	V10SalonFx._spark = null
	V10Salon._classes.clear()
	# hook lambdas bound to objects that die at shutdown must not outlive them in static vars
	V10Salon.grant_cb = Callable()
	V10Salon.bond_cb = Callable()
	V10Salon.letter_cb = Callable()
	V10Salon.day_cb = Callable()
	V10Salon.season_cb = Callable()
	V10Salon.level_cb = Callable()
	V10Salon.state_override = null
	_cleanup_armed = false


# kind: "body" Nunito (facts, numbers) | "display" Playfair | "italic" Playfair Italic (zone names, her voice)
static func font(kind: = "body", weight: = 700) -> Font:
	var key: = "%s%d" % [kind, weight]
	if _fonts.has(key):
		return _fonts[key]
	arm_cleanup()
	var files: Array = {"body": ["nunito-cyr", "nunito-lat"], "display": ["playfair-cyr", "playfair-lat"],
		"italic": ["playfair-i-cyr", "playfair-i-lat"]}.get(kind, ["nunito-cyr", "nunito-lat"])
	var ts: = TextServerManager.get_primary_interface()
	var fv: = FontVariation.new()
	fv.base_font = load("res://assets/fonts/%s.woff2" % files[0])
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	var fb: = FontVariation.new()
	fb.base_font = load("res://assets/fonts/%s.woff2" % files[1])
	fb.variation_opentype = {ts.name_to_tag("wght"): weight}
	fv.fallbacks = [fb]
	_fonts[key] = fv
	return fv


static func label(text: String, size: int, color: Color = PAPER_100, kind: = "body", weight: = 700, shadow: = 0.0) -> Label:
	var l: = Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls: = LabelSettings.new()
	ls.font = font(kind, weight)
	ls.font_size = size
	ls.font_color = color
	if shadow > 0.0:
		ls.shadow_color = Color(0, 0, 0, shadow)
		ls.shadow_offset = Vector2(0, 2)
		ls.shadow_size = 6
	l.label_settings = ls
	return l


static func overline(text: String, color: Color = GOLD_500) -> Label:
	# Overline 15/20, Nunito 900, caps, +14 % tracking (UX §6.3)
	var l: = label(text.to_upper(), 15, color, "body", 900)
	if not _fonts.has("overline"):
		var fv: = FontVariation.new()
		fv.base_font = font("body", 900)
		fv.spacing_glyph = 2
		_fonts["overline"] = fv
	l.label_settings.font = _fonts["overline"]
	return l


static func panel_box(col: Color, radius: = 4.0, border: = Color(0, 0, 0, 0), bw: = 0) -> StyleBoxFlat:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.anti_aliasing = true
	return sb


static func panel(rect: Rect2, col: Color = NIGHT_700, radius: = 4.0, border: = Color(0, 0, 0, 0), bw: = 0) -> Panel:
	var p: = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", panel_box(col, radius, border, bw))
	return p


# a 5-point star polygon (the ★ glyph is not in Nunito; «★ means only Path stars», UX §6.4)
static func star_points(c: Vector2, r: float, inner: = 0.45) -> PackedVector2Array:
	var pts: = PackedVector2Array()
	for i in 10:
		var a: = -PI / 2.0 + i * PI / 5.0
		var rr: = r if i % 2 == 0 else r * inner
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


static func star_icon(size: float, col: Color = GOLD_300) -> Control:
	var c: = Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var p: = star_points(Vector2(size, size) * 0.5, size * 0.5)
		c.draw_colored_polygon(p, col)
		c.draw_polyline(p + PackedVector2Array([p[0]]), col.darkened(0.35), 1.0, true))
	return c


# «Вывеска · 3★» as one row: text + number + a drawn star
static func star_text(text: String, n: int, size: int, col: Color = PAPER_100, star_col: Color = GOLD_300, kind: = "body", weight: = 800) -> HBoxContainer:
	var h: = HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 3)
	var l: = label(text + str(n), size, col, kind, weight)
	h.add_child(l)
	var s: = star_icon(size * 0.82, star_col)
	var wrap: = CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(s)
	h.add_child(wrap)
	return h


# «1 звезда / 2 звезды / 5 звёзд»
static func stars_word(n: int) -> String:
	var m10: = n % 10
	var m100: = n % 100
	if m10 == 1 and m100 != 11:
		return "%d звезда" % n
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return "%d звезды" % n
	return "%d звёзд" % n


static func text_w(text: String, size: int, kind: = "body", weight: = 700) -> float:
	return font(kind, weight).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func fx_level() -> String:
	var tree: = Engine.get_main_loop() as SceneTree
	var g = tree.root.get_node_or_null("G") if tree else null
	if g != null and g.has_method("fx_level"):
		return str(g.fx_level())
	return "full"


static func can_fx() -> bool:
	return fx_level() != "min"


static func full_fx() -> bool:
	return fx_level() == "full"


# a sound with fallbacks: the audio lane adds salon_thud / salon_sweep / salon_zone_sting; until then the
# nearest existing SFX plays (Sfx.play ignores unknown names silently, so try the fallback explicitly)
const SFX_FALLBACK: = {"salon_thud": "clack1", "salon_sweep": "whoosh", "salon_zone_sting": "win", "salon_star": "star0",
	"salon_open": "flip", "salon_sheet": "flip", "salon_shutter": "flip"}

# The salon's own SFX (Higgsfield mirelo, res://assets/v10/salon/sfx/<name>.wav: salon_thud, salon_sweep,
# salon_zone_sting, salon_shutter) play on a one-shot player unless the audio lane ships a file of that name.
const OWN_SFX: = "res://assets/v10/salon/sfx/%s.wav"

static func sound(name: String, pitch: = 1.0, db: = 0.0) -> void:
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if ResourceLoader.exists(OWN_SFX % name) and not ResourceLoader.exists("res://assets/sfx/%s.wav" % name):
		var g = tree.root.get_node_or_null("G")
		if g != null and g.get("S") is Dictionary and not g.S.get("sound", true):
			return
		var p: = AudioStreamPlayer.new()
		p.stream = load(OWN_SFX % name)
		p.pitch_scale = pitch
		p.volume_db = db
		tree.root.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
		return
	var sfx = tree.root.get_node_or_null("Sfx")
	if sfx == null:
		return
	var n: = name
	if not ResourceLoader.exists("res://assets/sfx/%s.wav" % n) and SFX_FALLBACK.has(n):
		n = SFX_FALLBACK[n]
	sfx.play(n, pitch, db)


static func haptic(kind: String) -> void:
	V9Feel.haptic(kind)
