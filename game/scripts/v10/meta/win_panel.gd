class_name V10WinPanel
extends Control

# V10WinPanel — the victory-window block UNDER the 0.9 result plate (docs/0.10-spec.md M1 Ф5): ≤ 2 progress bars
# from V10WinStack, one row of small ticks, and the «Ещё уровень» button row.
#
#   var p: = V10WinPanel.make(ctx, width)      ctx as in V10WinStack (+ count, stars_map, buttons: bool)
#   parent.add_child(p); p.position = …; p.play(delay)   delay = when the 0.9 stamps are done (play.gd _v9_yaku_at…)
#   p.height() — total height, to place it under the plate
#   signals: more(next_index) · salon() · home() · denied(hint)
#
# Buttons (path mode only; other modes keep their 0.9 buttons, ctx.buttons = false hides the row):
#   · big gold «Ещё уровень · 58» + glass «В салон» when the salon bar is registered and open (ctx.salon_open);
#   · otherwise big «Ещё уровень · 58» + small glass «Домой»;
#   · at the end of the path: grey «Скоро новая арка» (denies with the reason) + «Домой».
# The «Ещё уровень» tap plays the press, then V10MoreLevel.wipe() (0.4 s) and calls ctx.on_more(next) under the
# curtain when ctx.on_more is set; the signal `more` fires either way.

signal more(next_index: int)
signal salon
signal home
signal denied(hint: String)

const GAP: = 10.0
const TICK_H: = 40.0
const BTN_H: = 96.0

var ctx: Dictionary
var w: = 0.0
var bars: Array = []
var tick_row: Control
var more_btn: JButton
var alt_btn: JButton
var st: Dictionary
var _h: = 0.0


static func make(c: Dictionary, width: float) -> V10WinPanel:
	var p: = V10WinPanel.new()
	p.ctx = c
	p.w = width
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p._build()
	return p


func height() -> float:
	return _h


func _path() -> bool:
	return str(ctx.get("mode", "path")) == "path"


func _build() -> void:
	var y: = 0.0
	for b in V10WinStack.build_bars(ctx, w):
		var c: Control = b
		c.position = Vector2(0, y)
		add_child(c)
		bars.append(c)
		y += c.size.y + GAP
	var tk: = V10WinStack.ticks(ctx)
	if not tk.is_empty():
		tick_row = _build_ticks(tk)
		tick_row.position = Vector2(0, y)
		add_child(tick_row)
		y += TICK_H + GAP + 6.0
	if _path() and bool(ctx.get("buttons", true)):
		y += 6.0
		_build_buttons(y)
		y += BTN_H
	else:
		y -= GAP
	_h = maxf(0.0, y)
	size = Vector2(w, _h)


func _build_ticks(tk: Array) -> Control:
	var row: = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size = Vector2(w, TICK_H)
	var chips: = []
	var total: = 0.0
	for d in tk:
		var txt: = str(d.get("text", ""))
		var tw: = UI.font("body", 900).get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var cw: = 14.0 + 30.0 + 6.0 + tw + 16.0
		chips.append([d, cw, txt])
		total += cw
	var gap: = 8.0
	total += gap * (chips.size() - 1)
	var x: = maxf(0.0, (w - total) * 0.5)
	for c in chips:
		var d: Dictionary = c[0]
		var chip: = UI.rbox("glass", Rect2(x, 0, c[1], TICK_H), 20, 2, 4)
		chip.colors(Color(0.2, 0.15, 0.17, 0.88), Color(0.1, 0.07, 0.09, 0.9))
		chip.borders(Color(1, 0.9, 0.7, 0.35), Color(0, 0, 0, 0.3))
		row.add_child(chip)
		var ic = d.get("icon", null)
		var tex: Texture2D = ic if ic is Texture2D else (V8Art.icon(str(ic)) if ic != null else null)
		if tex:
			chip.add_child(UI.tex(tex, Rect2(12, 5, 30, 30)))
		var l: = UI.label(c[2], 17, Color("ffe7c4"), UI.DARK, 3, "body", 900)
		l.position = Vector2(48, 0)
		l.size = Vector2(c[1] - 56, TICK_H)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(l)
		x += c[1] + gap
	return row


func _build_buttons(y: float) -> void:
	st = V10MoreLevel.state(ctx)
	var salon_ok: = bool(ctx.get("salon_open", false)) and V10WinStack.has_bar("salon")
	var alt_w: = (w - GAP) * 0.4 if salon_ok else 176.0
	var main_w: = w - GAP - alt_w
	more_btn = JButton.make(str(st.text), "gold", Rect2(0, y, main_w, BTN_H), null, 30)
	more_btn.name = "MoreLevel"
	add_child(more_btn)
	if not bool(st.enabled):
		more_btn.disabled = true
		more_btn.denied.connect(func(): denied.emit(str(st.hint)))
	else:
		more_btn.shine_every = 3.2
		more_btn.pulse = true
		more_btn.pressed.connect(_on_more)
	if salon_ok:
		alt_btn = JButton.make("В салон", "glass", Rect2(main_w + GAP, y, alt_w, BTN_H), null, 28)
		alt_btn.pressed.connect(func(): salon.emit())
	else:
		alt_btn = JButton.make("Домой", "glass", Rect2(main_w + GAP, y + 10, alt_w, BTN_H - 20), V8Art.nav("home"), 24)
		alt_btn.pressed.connect(func(): home.emit())
	alt_btn.name = "AltBtn"
	add_child(alt_btn)


func _on_more() -> void:
	var nx: = int(st.get("next", -1))
	if nx < 0:
		return
	more.emit(nx)
	var cb: Callable = ctx.get("on_more", Callable())
	if cb.is_valid():
		V10MoreLevel.wipe(self, func(): cb.call(nx))


# staged entrance after the 0.9 stamps: bars slide up one by one (their stars fly in), ticks fade in, buttons pop
func play(delay: float = 0.0) -> void:
	for c in get_children():
		(c as CanvasItem).modulate.a = 0.0
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	var d: = 0.0
	for b in bars:
		UI.slide_in(b, Vector2(0, 28), d, 0.35)
		if b is V10WinBar:
			(b as V10WinBar).play(d + 0.3)
		d += 0.18
	if tick_row:
		UI.slide_in(tick_row, Vector2(0, 16), d + 0.1, 0.3)
		d += 0.15
	for b in [more_btn, alt_btn]:
		if b != null:
			UI.pop_in(b, d + 0.2, 0.7)
			d += 0.08
