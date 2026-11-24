class_name V10TileMarks
extends Node2D

# Suit marks and state badges on a tile (child of Tile, drawn above the face / back, below the special icons).
#   suit mark     bottom-right corner: a small silhouette in the suit colour — flower (цветы, pink), star (небо, blue),
#                 candy (сладости, orange), gem (сокровища, gold), paw (звери, green). Colour AND shape differ, so it
#                 reads for colour-blind players too. «Крупные символы» (V10ClarityState.big): the silhouette twice as
#                 big. NO number on the tile: playtesters paired «same digits» / «same colour»; the corner is only the suit.
#   blocked       the mark of a zажатая tile fades with it (marks of lower tiles peeking between upper ones read as
#                 belonging to nobody); full again once the tile is free or in the tray.
#                 Bottom-right because a tile on the layer above covers the top-left part of the one below.
#   gold coin     top-left «×5» on a gold tile (gold tiles never carry a gift, which also lives top-left)
#   back badge    face-down tiles: «↻» on a frosty back (Рубашка / перевёртыш: tap to flip) vs «?» on the plum back
#                 (Тайная: opens by itself once free). The face mark is hidden while the back shows (no peeking).
#   contrast      «Крупные символы»: a zажатая tile gets an extra dark veil, the difference free / blocked is obvious.
# Attach: V10TileMarks.attach(tile) after tile.build() (TrayBoard.setup hook). Settings changes: V10TileMarks.refresh_all().

const HW: = 42.0
const HH: = 43.6
const OUT: = Color(1, 1, 1, 0.96)
const INK: = Color(0.13, 0.06, 0.12)
const ICE_BACK: = Color("a9d6ff")

static var gen: = 0
static var force_on: = -1      # dev / icons: -1 = settings, 0 = off, 1 = on
static var force_big: = -1

var tile: Tile
var _sig: = ""
var _font: Font
var _gen: = -1
var always: = false          # legend / icons: show even when the setting is off
var big_override: = -1       # -1 = setting, 0 small, 1 big
var _board: Node = null      # the TrayBoard (tile → tile_layer → board), found once

static func attach(t: Tile) -> V10TileMarks:
	if t == null or not is_instance_valid(t):
		return null
	var old: = t.get_node_or_null("V10Marks")
	if old:
		return old as V10TileMarks
	var m: = V10TileMarks.new()
	m.name = "V10Marks"
	m.tile = t
	t.add_child(m)
	return m

static func refresh_all() -> void:
	gen += 1

static func on() -> bool:
	return V10ClarityState.marks_on() if force_on < 0 else force_on == 1

static func big() -> bool:
	return V10ClarityState.big() if force_big < 0 else force_big == 1

func _ready() -> void:
	_font = UI.font("body", 900)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(_dt: float) -> void:
	if tile == null or not is_instance_valid(tile):
		return
	var back: = tile.back_spr != null and is_instance_valid(tile.back_spr)
	var faded: = _faded()
	var s: = "%d|%s|%s|%s|%s|%s|%s|%d|%s" % [tile.face, back, tile.ice > 0, tile.secret, tile.gold, tile.free, tile.face_spr.visible if tile.face_spr else false, gen, faded]
	if s != _sig:
		_sig = s
		modulate.a = 0.3 if faded else 1.0
		if back and tile.ice > 0 and not tile.back_spr.has_meta("v10_ice"):
			tile.back_spr.set_meta("v10_ice", true)
			var b = tile.back_spr.get("body")
			if b is CanvasItem and (always or on()):
				(b as CanvasItem).modulate = (b as CanvasItem).modulate.lerp(ICE_BACK, 0.5)
		queue_redraw()

# a blocked tile on the table (not in the tray, not a legend / icon tile shown on purpose)
func _faded() -> bool:
	if always or not tile.alive or tile.free or tile.pending:
		return false
	if _board == null:
		var n: = tile.get_parent()
		for i in 3:
			if n == null:
				break
			if n.get("tray") is Array:
				_board = n
				break
			n = n.get_parent()
		if _board == null:
			return false
	if not is_instance_valid(_board):
		return false
	return not (_board.tray as Array).has(tile)

func _draw() -> void:
	if tile == null or not is_instance_valid(tile) or not (always or on()):
		return
	var bg: = big() if big_override < 0 else big_override == 1
	var back: = tile.back_spr != null and is_instance_valid(tile.back_spr)
	if back:
		if tile.ice > 0:
			_badge_flip(Vector2(HW - 14, HH - 15), 12.5 if bg else 10.5)
		elif tile.secret:
			_badge_secret(Vector2(HW - 14, HH - 15), 12.5 if bg else 10.5)
		return
	if bg and not tile.free and tile.alive and not tile.pending:
		draw_style_box(_veil(), Rect2(-HW + 2, -HH + 2, HW * 2 - 4, HH * 2 - 4))
	if tile.face_spr and not tile.face_spr.visible:
		return
	var c: = V10Glossary.suit_of(tile.face)
	if c >= 0:
		if bg:
			draw_suit(self, c, Vector2(HW - 18, HH - 19), 16.0, 0, _font)
		else:
			draw_suit(self, c, Vector2(HW - 13, HH - 14), 10.5, 0, _font)
	if tile.gold:
		_coin(Vector2(-HW + 14, -HH + 14), 13.0 if bg else 11.0)

static var _veil_sb: StyleBoxFlat
static func _veil() -> StyleBoxFlat:
	if _veil_sb == null:
		_veil_sb = StyleBoxFlat.new()
		_veil_sb.bg_color = Color(0.08, 0.04, 0.1, 0.34)
		_veil_sb.set_corner_radius_all(10)
	return _veil_sb

# ── the suit silhouette (also used by V10ClarityIcon and the legend) ────────────────────────────────────────────
# ci: any CanvasItem inside its _draw; c: suit; p: centre; r: radius; num > 0 writes the number inside
static func draw_suit(ci: CanvasItem, c: int, p: Vector2, r: float, num: = 0, font: Font = null) -> void:
	var col: = V10Glossary.suit_color(c)
	var g: = V10Glossary.suit_glyph(c)
	var ow: = maxf(1.6, r * 0.2)
	# soft drop shadow, white rim, colour, a top gloss
	ci.draw_circle(p + Vector2(0, r * 0.22), r + ow * 0.6, Color(0.1, 0.03, 0.08, 0.3))
	_shape(ci, g, p, r + ow, OUT)
	_shape(ci, g, p, r, col)
	ci.draw_circle(p + Vector2(-r * 0.18, -r * 0.22), r * 0.34, Color(1, 1, 1, 0.2))
	if num > 0 and font:
		var fs: = int(round(r * (1.22 if num < 10 else 1.0)))
		var s: = str(num)
		var w: = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cy: = p.y + fs * 0.36 + (r * 0.16 if g == "paw" else 0.0)
		ci.draw_string_outline(font, Vector2(p.x - w * 0.5, cy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(r * 0.28)), col.darkened(0.55))
		ci.draw_string(font, Vector2(p.x - w * 0.5, cy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	elif num == 0:
		# the tiny inner sign so the small mark still reads as a symbol, not a dot
		_shape(ci, g, p, r * 0.36, Color(1, 1, 1, 0.85))

static func _shape(ci: CanvasItem, g: String, p: Vector2, r: float, col: Color) -> void:
	match g:
		"flower":
			for i in 5:
				var a: = -PI * 0.5 + TAU * i / 5.0
				ci.draw_circle(p + Vector2(cos(a), sin(a)) * r * 0.5, r * 0.5, col)
			ci.draw_circle(p, r * 0.6, col)
		"star":
			ci.draw_colored_polygon(_star_pts(p, r * 1.08, r * 0.62, 5), col)
		"candy":
			ci.draw_circle(p, r * 0.74, col)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.55, 0), p + Vector2(-r * 1.15, -r * 0.5), p + Vector2(-r * 1.15, r * 0.5)]), col)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.55, 0), p + Vector2(r * 1.15, -r * 0.5), p + Vector2(r * 1.15, r * 0.5)]), col)
		"gem":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.95, -r * 0.3), p + Vector2(-r * 0.5, -r * 0.85), p + Vector2(r * 0.5, -r * 0.85),
				p + Vector2(r * 0.95, -r * 0.3), p + Vector2(0, r * 1.0)]), col)
		"paw":
			ci.draw_circle(p + Vector2(0, r * 0.2), r * 0.68, col)
			for i in 3:
				var a: = -PI * 0.5 + (i - 1) * 0.72
				ci.draw_circle(p + Vector2(0, r * 0.12) + Vector2(cos(a), sin(a)) * r * 0.95, r * 0.3, col)
		_:
			ci.draw_circle(p, r, col)

static func _star_pts(c: Vector2, ro: float, ri: float, n: int) -> PackedVector2Array:
	var pts: = PackedVector2Array()
	for i in n * 2:
		var a: = -PI * 0.5 + PI * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * (ro if i % 2 == 0 else ri))
	return pts

func _coin(p: Vector2, r: float) -> void:
	draw_circle(p + Vector2(0, 1.5), r + 1.5, Color(0.2, 0.1, 0.0, 0.35))
	draw_circle(p, r + 1.5, Color("fff4c4"))
	draw_circle(p, r, Color("e0a52a"))
	draw_circle(p + Vector2(-1, -1), r * 0.72, Color("f6cf5c"))
	var s: = "×5"
	var fs: = int(r * 1.05)
	var w: = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(_font, p + Vector2(-w * 0.5, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color("7a4a0c"))
	draw_string(_font, p + Vector2(-w * 0.5, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _badge_flip(p: Vector2, r: float) -> void:
	draw_badge_flip(self, p, r)

func _badge_secret(p: Vector2, r: float) -> void:
	draw_badge_secret(self, p, r, _font)

static func draw_badge_flip(ci: CanvasItem, p: Vector2, r: float) -> void:
	ci.draw_circle(p + Vector2(0, 1.5), r + 2, Color(0, 0, 0, 0.3))
	ci.draw_circle(p, r + 2, OUT)
	ci.draw_circle(p, r, Color("2f8fc9"))
	# a circular arrow ↻
	var pts: = PackedVector2Array()
	for i in 15:
		var a: = deg_to_rad(-60.0 + 270.0 * i / 14.0)
		pts.append(p + Vector2(cos(a), sin(a)) * r * 0.55)
	ci.draw_polyline(pts, Color.WHITE, maxf(2.0, r * 0.2), true)
	var end: = pts[pts.size() - 1]
	var a1: = deg_to_rad(-60.0 + 270.0)
	var tang: = Vector2(-sin(a1), cos(a1))
	var nrm: = Vector2(cos(a1), sin(a1))
	ci.draw_colored_polygon(PackedVector2Array([end + tang * r * 0.42, end - nrm * r * 0.3 - tang * r * 0.05, end + nrm * r * 0.3 - tang * r * 0.05]), Color.WHITE)

static func draw_badge_secret(ci: CanvasItem, p: Vector2, r: float, font: Font) -> void:
	ci.draw_circle(p + Vector2(0, 1.5), r + 2, Color(0, 0, 0, 0.3))
	ci.draw_circle(p, r + 2, OUT)
	ci.draw_circle(p, r, Color("7a4bb8"))
	if font:
		var fs: = int(r * 1.5)
		var w: = font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(font, p + Vector2(-w * 0.5, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
