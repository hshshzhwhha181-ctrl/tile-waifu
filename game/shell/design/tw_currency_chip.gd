class_name TWCurrencyChip
extends TWPlate

# TWCurrencyChip (P28 / WP9b): the S plate that shows one balance (moonstone / coin / ticket): painted-in-code glyph + tabular number that
# ROLLS to a new value in TWTokens.T_ROLL (0.32 s). Tappable (opens the shop) with the same press feel and a 96 px hit band.
#   var c := TWCurrencyChip.create("moon", 1980); c.set_amount(2100, true)

const KINDS: = ["moon", "coin", "ticket"]
const GLYPH_W: = 28

var chip_kind: = "moon":
	set(v):
		chip_kind = v if v in KINDS else "moon"
		queue_redraw()
var amount: = 0
var _shown: = 0.0
var _rolling: = false
var _roll_from: = 0.0
var _roll_t: = 0.0


static func create(k: String, amt: int) -> TWCurrencyChip:
	var c: = TWCurrencyChip.new()
	c.size_class = "S"
	c.interactive = true
	c.chip_kind = k
	c.set_amount(amt, false)
	return c


static func format_amount(n: int) -> String:
	var s: = str(absi(n))
	var out: = ""
	var i: = s.length()
	while i > 3:
		out = " " + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-" + out) if n < 0 else out


static func width_for(text: String) -> int:
	# the smallest S module that holds pad + glyph + gap + number + pad
	var need: = float(PAD["S"]) * 2.0 + GLYPH_W + 8.0 + TWDraw.text_w(text, "num", TWTokens.TYPE_CAPTION) + 4.0
	for m in WIDTHS["S"]:
		if float(m) >= need:
			return m
	return WIDTHS["S"][WIDTHS["S"].size() - 1]


func _init() -> void:
	super._init()
	size_class = "S"
	interactive = true


func set_amount(n: int, animate: = true) -> void:
	_roll_from = _shown
	amount = n
	if animate and TWDraw.fx_level() != "min" and is_inside_tree():
		_rolling = true
		_roll_t = 0.0
		set_process(true)
	else:
		_rolling = false
		_shown = float(n)
		_show_number(n)


func _show_number(n: int) -> void:
	var txt: = format_amount(n)
	plate_w = width_for(format_amount(maxi(absi(amount), absi(n))))
	value = txt


func is_rolling() -> bool:
	return _rolling


func advance(dt: float) -> void:
	if _rolling:
		_roll_t += dt
		var k: = clampf(_roll_t / TWTokens.T_ROLL, 0.0, 1.0)
		var e: = 1.0 - pow(1.0 - k, 3.0)
		_shown = lerpf(_roll_from, float(amount), e)
		_show_number(roundi(_shown))
		if k >= 1.0:
			_rolling = false
			_shown = float(amount)
			_show_number(amount)
	super.advance(dt)
	if _rolling:
		set_process(true)


func _relayout() -> void:
	value_max_w = float(plate_w) - float(PAD["S"]) * 2.0 - GLYPH_W - 8.0
	super._relayout()


func _draw() -> void:
	super._draw()
	var c: = Vector2(float(PAD["S"]) + GLYPH_W * 0.5, plate_h() * 0.5)
	var a: = 0.5 if disabled else 1.0
	match chip_kind:
		"moon":
			var pts: = PackedVector2Array([c + Vector2(0, -12), c + Vector2(10, 0), c + Vector2(0, 12), c + Vector2(-10, 0)])
			draw_colored_polygon(pts, Color(TWSkin.c("JADE_300"), a))
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(TWSkin.c("JADE_500"), a), 1.5, true)
			draw_line(c + Vector2(-10, 0), c + Vector2(10, 0), Color(TWSkin.c("PAPER_100"), 0.6 * a), 1.0)
		"coin":
			draw_circle(c, 11.0, Color(TWSkin.c("GOLD_500"), a), true, -1.0, true)
			draw_arc(c, 11.0, 0.0, TAU, 32, Color(TWSkin.c("GOLD_700"), a), 1.5, true)
			draw_arc(c, 6.0, 0.0, TAU, 24, Color(TWSkin.c("GOLD_300"), 0.8 * a), 1.0, true)
		_:
			var r: = Rect2(c - Vector2(12, 8), Vector2(24, 16))
			draw_colored_polygon(TWDraw.rr_pts(r, 3.0, 4), Color(TWSkin.c("ROSE_300"), a))
			draw_line(Vector2(c.x + 4, r.position.y + 2), Vector2(c.x + 4, r.end.y - 2), Color(TWSkin.c("ROSE_700"), a), 1.5)
