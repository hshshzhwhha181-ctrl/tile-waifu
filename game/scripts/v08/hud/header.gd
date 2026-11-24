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
	h.position = Vector2(bx, TOP)
	h.size = Vector2(h._w, HEIGHT)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.name = "V8Header"
	h._build(title, on_back, on_help)
	screen.add_child(h)
	if on_back.is_valid():
		screen.set_meta("v8_back", on_back)
	return h


func _build(title: String, on_back: Callable, on_help: Callable) -> void :
	var plate: = UI.rbox("graphite", Rect2(SIDE * 0.5, 6, _w - SIDE, HEIGHT - 12), (HEIGHT - 12) * 0.5, 2, 10)
	plate.colors(Color(0.13, 0.12, 0.14, 0.82), Color(0.07, 0.065, 0.08, 0.86))
	plate.set_param("border_top", Color(0.95, 0.85, 0.6, 0.55)).set_param("border_bottom", Color(0.45, 0.32, 0.16, 0.6))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	var by: = (HEIGHT - BTN) * 0.5
	if on_back.is_valid():
		back_btn = _round_btn(Rect2(SIDE, by, BTN, BTN), "back")
		back_btn.sound = "tap"
		back_btn.pressed.connect(on_back)
		back_btn.name = "Back"
		add_child(back_btn)
	if on_help.is_valid():
		help_btn = _round_btn(Rect2(_w - SIDE - BTN, by, BTN, BTN), "help")
		help_btn.pressed.connect(on_help)
		help_btn.name = "Help"
		add_child(help_btn)
	set_title(title)


# 0.8: the round icon (V8Art icon/back, icon/help: 192 px gold-rimmed disc) is the whole button, so the
# JButton's own drawn disc is hidden; the JButton still gives the press animation and sound.
func _round_btn(r: Rect2, icon: String) -> JButton:
	var b: = JButton.make("", "graphite", r, null, 30, r.size.y * 0.5)
	b.box.visible = false
	var art: = V8Art.rect(V8Art.icon(icon), Rect2(Vector2.ZERO, r.size))
	art.name = "Icon"
	b.add_child(art)
	return b


func set_title(text: String) -> void :
	if title_lbl and is_instance_valid(title_lbl):
		title_lbl.queue_free()
	var avail: = _w - 2.0 * (SIDE + BTN + 14.0)
	var fs: = TITLE_MAX
	var f: = UI.font("title", 900)
	while fs > TITLE_MIN and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 1
	title_lbl = UI.title(text, fs, Color("fff6ea"), Color("3a1620"))
	UI.center_label(title_lbl, Rect2(SIDE + BTN + 14.0, 0, avail, HEIGHT))
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.clip_text = true
	title_lbl.name = "Title"
	add_child(title_lbl)
