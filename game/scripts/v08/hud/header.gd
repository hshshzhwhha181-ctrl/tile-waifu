class_name V8Header
extends Control

# One screen header for 0.8: «назад» (V8Art icon/back) on the left, title centred (Playfair 28–34), «?» (icon/help) on the right
# when on_help is given. Sits right under the global top bar.
#   var h: = V8Header.make(screen, main, "Режимы", func(): main.go("home"), func(): show_help())
#   content starts at V8Header.CONTENT_Y (= TOP + HEIGHT)
#   h.set_title("…"), h.back_btn / h.help_btn / h.title_lbl for tweaks.
# The back callback is also stored on the screen as meta "v8_back" (Callable) so the Android back key handler
# can reuse it: if screen.has_meta("v8_back"): screen.get_meta("v8_back").call()

const TOP: = 120.0
const HEIGHT: = 96.0
const CONTENT_Y: = TOP + HEIGHT
const BTN: = 72.0
const SIDE: = 16.0
const TITLE_MAX: = 34
const TITLE_MIN: = 28

var back_btn: JButton
var help_btn: JButton
var title_lbl: Label
var _w: = 720.0
var _bleed_top: = 0.0


static func make(screen: Control, main, title: String, on_back: Callable, on_help: = Callable()) -> V8Header:
	var h: = V8Header.new()
	# 0.10 M0: the screen is the content column (V10Layout); the header plate spans the viewport like the top bar,
	# so «назад» and «?» sit at the real edges on tablets
	h._w = screen.size.x
	var bx: = 0.0
	var by: = 0.0
	if screen.is_inside_tree():
		var br: Rect2 = V10Layout.bleed_rect(screen)
		bx = br.position.x
		by = minf(0.0, br.position.y)
		h._w = br.size.x
	# 0.10 W1 (HUD_V2 §8.6): ONE bar at the top of the column (the column already starts under the safe top), no
	# status ribbon above it; its fade reaches up to the real screen edge. The content keeps CONTENT_Y (the 0.9
	# screens lay out from it); the band under the bar is the screen's own background.
	h._bleed_top = -by
	h.position = Vector2(bx, 0.0)
	h.size = Vector2(h._w, V2_H)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.name = "V8Header"
	h._build(title, on_back, on_help)
	screen.add_child(h)
	if on_back.is_valid():
		screen.set_meta("v8_back", on_back)
	return h


const V2_H: = 88.0

# HUD v2 header (V10Header look): night.900 α 0.85 → 0, «‹» quiet 80 hit / 48 icon, H1 Display 44 → 32 on the left
# margin, «?» quiet on the right. No plate, no border.
func _build(title: String, on_back: Callable, on_help: Callable) -> void :
	var fade: = _Fade.new()
	fade.size = Vector2(_w, V2_H + 24.0)
	fade.position = Vector2(0, -_bleed_top)
	fade.size.y += _bleed_top
	add_child(fade)
	var cx: = floorf(maxf(0.0, (_w - 720.0) * 0.5))
	if on_back.is_valid():
		back_btn = _quiet_btn(Rect2(cx + 8.0, 4.0, 80.0, 80.0), "back")
		back_btn.sound = "tap"
		back_btn.pressed.connect(on_back)
		back_btn.name = "Back"
		add_child(back_btn)
	if on_help.is_valid():
		help_btn = _quiet_btn(Rect2(cx + 632.0, 4.0, 80.0, 80.0), "help")
		help_btn.pressed.connect(on_help)
		help_btn.name = "Help"
		add_child(help_btn)
	set_title(title)


func _quiet_btn(r: Rect2, icon: String) -> JButton:
	var b: = JButton.make("", "graphite", r, null, 22, r.size.y * 0.5)
	b.box.visible = false
	var ic: = V10Icons.icon(icon, 48, V10DS.PAPER_300)
	ic.name = "Icon"
	ic.position = (r.size - Vector2(48, 48)) * 0.5
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	return b


func set_title(text: String) -> void :
	if title_lbl and is_instance_valid(title_lbl):
		title_lbl.queue_free()
	var cx: = floorf(maxf(0.0, (_w - 720.0) * 0.5))
	var x0: = cx + (88.0 if back_btn else 24.0)
	var x1: = cx + (632.0 if help_btn else 696.0)
	if _money_x > 0.0:
		x1 = minf(x1, _money_x - 16.0)
	var fs: = 44
	for k in [44, 32]:
		fs = k
		if V10Type.text_w(text, "display", k) <= x1 - x0:
			break
	title_lbl = V10Type.label(text, "display", fs, V10DS.PAPER_100, true)
	title_lbl.position = Vector2(x0, 14.0)
	title_lbl.size = Vector2(x1 - x0, 60.0)
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.clip_text = true
	title_lbl.name = "Title"
	add_child(title_lbl)


# 0.10 W1 (HUD_V2 §8.6): the currency being spent on this screen, as S-plates on the right of the bar (Numerals +
# painted icon 24); only Желания and Лавка call it. main.refresh_currency() refreshes them (group "v10_money").
const MONEY_ICON: = {"gems": "gem", "coins": "coin", "tickets": "ticket", "moon": "moon"}
var money_plates: = {}
var _money_x: = 0.0

func show_money(keys: Array) -> void :
	var cx: = floorf(maxf(0.0, (_w - 720.0) * 0.5))
	var right: = cx + (632.0 if help_btn else 696.0)
	for i in range(keys.size() - 1, -1, -1):
		var k: String = keys[i]
		var p: = V10Plate.make("S", 144, "", "", UI.fmt(V10Money.bal(k)))
		p.icon_tex = V8Art.cur(MONEY_ICON.get(k, "gem"))
		p.name = "Money_" + k
		right -= 144.0
		p.position = Vector2(right, 20.0)
		right -= 8.0
		add_child(p)
		money_plates[k] = p
	_money_x = right + 8.0
	add_to_group("v10_money")
	set_title(title_lbl.text if title_lbl else "")


func refresh_money() -> void :
	for k in money_plates:
		if is_instance_valid(money_plates[k]):
			(money_plates[k] as V10Plate).value = UI.fmt(V10Money.bal(k))


class _Fade:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c0: = Color(V10DS.NIGHT_900, 0.85)
		var c1: = Color(V10DS.NIGHT_900, 0.0)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
				PackedColorArray([c0, c0, c1, c1]))
