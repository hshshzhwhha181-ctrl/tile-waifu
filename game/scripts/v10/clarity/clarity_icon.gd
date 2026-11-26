class_name V10ClarityIcon
extends Control

# One icon for any glossary entry, from its spec string "kind:arg[|badge]":
#   art:<icon>      V8Art.icon (trophy hint heart gift rating visits undo shuffle star …)
#   cur:<name>      V8Art.cur (gem coin ticket)
#   rank:<t> / league:<t>   rank medallion / league crest
#   tile:<face>     a real mini tile (same shaders as the board) with its suit mark
#   suit:<c>        the suit silhouette, big
#   state:<s>       a real mini tile in a state: free blocked gold flip secret shard pair
#   spec:<kind>     a mini tile carrying a special icon (gift lock chain joker bomb)
#   combo:<n>       a flame with ×n
#   glyph:<g>       drawn medallion: target watch tray2 tray_full riichi finale album three starfall omikuji secret_star
#   |no |x2 |<n>    a badge: red «нет» slash, «×2» pill, a number pill
# A PNG at res://assets/v10/clarity/icons/<kind>_<arg>.png overrides any spec (art drop-in, no code change).

const ICON_DIR: = "res://assets/v10/clarity/icons/"
const GOLD: = Color("e8c47e")
const PLUM: = Color("2a1a2e")

var spec: = ""
var kind: = ""
var arg: = ""
var badge: = ""
var _tex: Texture2D
var _font: Font
var _t: = 0.0
var animate: = false

static func make(s: String, sz: float, pos: = Vector2.ZERO) -> V10ClarityIcon:
	var ic: = V10ClarityIcon.new()
	ic.position = pos
	ic.size = Vector2(sz, sz)
	ic.custom_minimum_size = Vector2(sz, sz)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_spec(s)
	return ic

func set_spec(s: String) -> void:
	spec = s
	var parts: = s.split("|", true, 1)
	badge = parts[1] if parts.size() > 1 else ""
	var ka: = parts[0].split(":", true, 1)
	kind = ka[0]
	arg = ka[1] if ka.size() > 1 else ""
	_tex = null
	for c in get_children():
		c.queue_free()
	var over: = ICON_DIR + "%s_%s.png" % [kind, arg.replace(":", "_")]
	if ResourceLoader.exists(over):
		_tex = load(over)
	else:
		match kind:
			"art":
				if ResourceLoader.exists("res://assets/v10/shop/%s.png" % arg):
					_tex = load("res://assets/v10/shop/%s.png" % arg)
				else:
					_tex = V8Art.icon(arg)
			"cur":
				_tex = V8Art.cur(arg)
			"rank":
				_tex = V8Art.rank(int(arg))
			"league":
				_tex = V8Art.league(int(arg))
			"tile", "state", "spec":
				_build_tile()
	queue_redraw()

func _ready() -> void:
	_font = UI.font("body", 900)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(kind in ["combo", "glyph"] and animate)
	resized.connect(_relayout)

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _relayout() -> void:
	var h: = get_node_or_null("Holder") as Node2D
	if h:
		h.position = size * 0.5
		var k: = minf(size.x, size.y) / 96.0
		h.scale = Vector2(k, k)

# a real Tile in a holder, so the icon looks exactly like the board
func _build_tile() -> void:
	var holder: = Node2D.new()
	holder.name = "Holder"
	add_child(holder)
	var faces: = [arg.to_int()] if kind == "tile" else [8]
	if kind == "state" and arg == "pair":
		faces = [0, 0]
	if kind == "state" and arg == "blocked":
		faces = [21]
	if kind == "state" and arg == "gold":
		faces = [25]
	if kind == "spec":
		faces = [{"gift": 26, "lock": 17, "chain": 9, "joker": 0, "bomb": 30}.get(arg, 4)]
	for i in faces.size():
		var t: = mini_tile(int(faces[i]), arg if kind == "state" else "")
		if faces.size() > 1:
			t.position = Vector2(-20 + i * 40, i * 6 - 3)
			t.scale = Vector2(0.78, 0.78)
		holder.add_child(t)
		if kind == "state" and arg == "blank":
			t.face_spr.visible = false
		if kind == "state" and arg == "back":
			# a generic «фишка»: the plain back, no badge
			var mk: = t.get_node_or_null("V10Marks")
			if mk:
				mk.queue_free()
		if kind == "spec":
			var sk: = arg
			var ic: = V6SpecIcon.new(sk, V6SpecIcon.group_color(0), 3)
			if sk == "joker":
				t.face_spr.visible = false
			t.add_child(ic)
	_relayout.call_deferred()

# a stand-alone mini tile in a given state (used by icons, the legend and the tile bubble)
static func mini_tile(face: int, state: = "") -> Tile:
	var t: = Tile.new()
	t.face = face
	if state == "gold":
		t.gold = true
	if state == "secret" or state == "back":
		t.secret = true
	if state == "flip":
		t.ice = 1
	t.build(G.skin_look())
	t.free = true
	if state == "shard":
		t.set_shard("rin")
	if state == "blocked":
		t.set_free(false, false)
	else:
		t.set_free(true, false)
	t.mat.set_shader_parameter("dim", 1.0 if state == "blocked" else 0.0)
	var mk: = V10TileMarks.attach(t)
	if mk:
		mk.always = true
	return t

func _draw() -> void:
	var s: = size
	var r: = Rect2(Vector2.ZERO, s)
	if _tex:
		draw_texture_rect(_tex, r, false)
	else:
		match kind:
			"suit":
				V10TileMarks.draw_suit(self, int(arg), s * 0.5, minf(s.x, s.y) * 0.36, 0, _font)
			"combo":
				_flame(s * 0.5, minf(s.x, s.y) * 0.5, int(arg))
			"glyph":
				_medal(s * 0.5, minf(s.x, s.y) * 0.47)
				_glyph(arg, s * 0.5, minf(s.x, s.y) * 0.47)
	if badge != "":
		_badge(s)

# ── drawing helpers ─────────────────────────────────────────────────────────────────────────────────────────────

func _medal(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(0, r * 0.08), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, Color("c58a2c"))
	draw_circle(c, r * 0.93, Color("ffe7a6"))
	draw_circle(c, r * 0.86, PLUM)
	draw_circle(c + Vector2(0, -r * 0.3), r * 0.55, Color(1, 1, 1, 0.05))

func _glyph(g: String, c: Vector2, r: float) -> void:
	var cream: = Color("f5ead8")
	var w: = maxf(2.0, r * 0.1)
	match g:
		"target":
			draw_circle(c, r * 0.6, Color("e3a1b0"))
			draw_circle(c, r * 0.44, PLUM)
			draw_circle(c, r * 0.28, Color("e3a1b0"))
			draw_circle(c, r * 0.12, Color("ffe7a6"))
		"watch":
			draw_circle(c + Vector2(0, r * 0.06), r * 0.56, cream)
			draw_circle(c + Vector2(0, r * 0.06), r * 0.45, PLUM)
			draw_rect(Rect2(c + Vector2(-r * 0.1, -r * 0.72), Vector2(r * 0.2, r * 0.16)), cream)
			draw_line(c + Vector2(0, r * 0.06), c + Vector2(0, -r * 0.28), Color("ffe7a6"), w, true)
			draw_line(c + Vector2(0, r * 0.06), c + Vector2(r * 0.26, r * 0.16), Color("ffe7a6"), w, true)
		"tray2", "tray_full":
			var tr: = Rect2(c + Vector2(-r * 0.66, -r * 0.3), Vector2(r * 1.32, r * 0.6))
			draw_rect(tr, Color("c58a2c"))
			draw_rect(tr.grow(-r * 0.06), Color(0.1, 0.07, 0.1))
			var n: = 4 if g == "tray_full" else 2
			for i in 4:
				var cell: = Rect2(tr.position + Vector2(r * 0.1 + i * r * 0.29, r * 0.1), Vector2(r * 0.24, r * 0.4))
				draw_rect(cell, Color("fbf3e2") if i < n else Color(1, 1, 1, 0.12))
			if g == "tray_full":
				draw_line(c + Vector2(-r * 0.5, -r * 0.5), c + Vector2(r * 0.5, r * 0.5), Color("e8455f"), w * 1.3, true)
		"riichi":
			draw_rect(Rect2(c + Vector2(-r * 0.34, -r * 0.52), Vector2(r * 0.68, r * 0.98)), cream)
			draw_rect(Rect2(c + Vector2(-r * 0.66, -r * 0.08), Vector2(r * 1.32, r * 0.22)), Color("d6334f"))
			_text("×2", c + Vector2(0, -r * 0.24), int(r * 0.42), Color("7a1a2a"))
		"finale":
			draw_line(c + Vector2(r * 0.12, r * 0.3), c + Vector2(r * 0.12, -r * 0.5), Color("ffe7a6"), w * 1.2, true)
			draw_line(c + Vector2(r * 0.12, -r * 0.5), c + Vector2(r * 0.42, -r * 0.34), Color("ffe7a6"), w * 1.2, true)
			draw_circle(c + Vector2(-r * 0.06, r * 0.32), r * 0.2, Color("ffe7a6"))
			draw_colored_polygon(V10TileMarks._star_pts(c + Vector2(-r * 0.36, -r * 0.3), r * 0.22, r * 0.08, 4), Color("ffd34d"))
		"album":
			draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.55), Vector2(r * 1.0, r * 1.1)), Color("e3a1b0"))
			draw_rect(Rect2(c + Vector2(-r * 0.42, -r * 0.47), Vector2(r * 0.84, r * 0.94)), cream)
			draw_colored_polygon(V10TileMarks._star_pts(c, r * 0.32, r * 0.14, 5), Color("e0a52a"))
		"three":
			for i in 3:
				V10TileMarks.draw_suit(self, i, c + Vector2((i - 1) * r * 0.5, 0), r * 0.24, 0, _font)
		"starfall":
			for i in 3:
				var p: = c + Vector2((i - 1) * r * 0.36, (i - 1) * r * 0.2 - r * 0.1)
				draw_line(p, p + Vector2(-r * 0.3, -r * 0.3), Color(1, 0.9, 0.6, 0.5), w, true)
				draw_colored_polygon(V10TileMarks._star_pts(p, r * 0.2, r * 0.08, 5), Color("ffd34d"))
		"omikuji":
			draw_rect(Rect2(c + Vector2(-r * 0.26, -r * 0.6), Vector2(r * 0.52, r * 1.2)), cream)
			draw_rect(Rect2(c + Vector2(-r * 0.26, -r * 0.08), Vector2(r * 0.52, r * 0.16)), Color("d6334f"))
			draw_circle(c + Vector2(0, -r * 0.34), r * 0.08, Color("d6334f"))
		"secret_star":
			draw_colored_polygon(V10TileMarks._star_pts(c, r * 0.55, r * 0.2, 4), Color("ffe7a6"))
			draw_colored_polygon(V10TileMarks._star_pts(c, r * 0.3, r * 0.11, 4), Color.WHITE)
		_:
			draw_circle(c, r * 0.3, cream)

func _flame(c: Vector2, r: float, n: int) -> void:
	var k: = 1.0 + 0.04 * sin(_t * 9.0)
	var outer: = PackedVector2Array()
	var inner: = PackedVector2Array()
	for i in 24:
		var a: = TAU * i / 24.0
		var y: = sin(a)
		var x: = cos(a)
		var stretch: = 1.0 + maxf(0.0, -y) * 0.75
		outer.append(c + Vector2(x * r * 0.62 * (1.0 - maxf(0.0, -y) * 0.55), y * r * 0.62 * stretch * k + r * 0.16))
		inner.append(c + Vector2(x * r * 0.42 * (1.0 - maxf(0.0, -y) * 0.55), y * r * 0.42 * stretch * k + r * 0.3))
	draw_colored_polygon(outer, Color("ff7a3c"))
	draw_colored_polygon(inner, Color("ffd34d"))
	_text("×%d" % n, c + Vector2(0, r * 0.32), int(r * (0.62 if n < 10 else 0.5)), Color.WHITE, Color("8a2a0c"))

func _text(s: String, c: Vector2, fs: int, col: Color, out: = Color(0, 0, 0, 0)) -> void:
	if _font == null:
		_font = UI.font("body", 900)
	var w: = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p: = Vector2(c.x - w * 0.5, c.y + fs * 0.36)
	if out.a > 0.0:
		draw_string_outline(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, fs / 5), out)
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _badge(s: Vector2) -> void:
	var m: = minf(s.x, s.y)
	if badge == "no":
		var c: = Vector2(s.x * 0.76, s.y * 0.76)
		var r: = m * 0.2
		draw_circle(c, r + 2, Color.WHITE)
		draw_circle(c, r, Color("d6334f"))
		draw_line(c + Vector2(-r * 0.5, -r * 0.5), c + Vector2(r * 0.5, r * 0.5), Color.WHITE, maxf(2.0, r * 0.28), true)
		return
	var txt: = badge if badge.begins_with("x") == false else "×" + badge.substr(1)
	var fs: = int(m * 0.26)
	if _font == null:
		_font = UI.font("body", 900)
	var w: = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.7
	var rr: = Rect2(Vector2(s.x - w, s.y - fs * 1.25), Vector2(w, fs * 1.25))
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color("d6334f")
	sb.border_color = Color.WHITE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(fs * 0.62))
	draw_style_box(sb, rr)
	_text(txt, rr.get_center(), fs, Color.WHITE)
