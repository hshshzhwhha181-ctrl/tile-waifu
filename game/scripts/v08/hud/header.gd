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


static func make(screen: Control, main, title: String, on_back: Callable, on_help: = Callable()) -> V8Header:
	var h: = V8Header.new()
	# 0.10 M0: the screen is the content column (V10Layout); the header plate spans the viewport like the top bar,
	# so «назад» and «?» sit at the real edges on tablets
	h._w = screen.size.x
	var bx: = 0.0
	if screen.is_inside_tree():
		var br: Rect2 = V10Layout.bleed_rect(screen)
		bx = br.position.x
		h._w = br.size.x
	# 0.10 W1 (HUD_V2 §8.6): ONE bar at the very top (88 + safe top), no status ribbon above it. The content keeps
	# CONTENT_Y (the 0.9 screens lay out from it); the band under the bar is the screen's own background.
	var st: = float(main.safe_top) if main != null and "safe_top" in main else 0.0
	h.position = Vector2(bx, st)
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
	fade.position = Vector2(0, -position.y)
	fade.size.y += position.y
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


class _Fade:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c0: = Color(V10DS.NIGHT_900, 0.85)
		var c1: = Color(V10DS.NIGHT_900, 0.0)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
				PackedColorArray([c0, c0, c1, c1]))
