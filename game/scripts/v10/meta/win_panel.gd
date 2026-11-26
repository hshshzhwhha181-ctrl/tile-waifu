class_name V10WinPanel
extends Control

# V10WinPanel — the victory-window block (docs/0.10-spec.md M1 Ф5, UX_RULES §3.4 «Победа», HUD_V2 §8.3 такт 3):
# ≤ 2 progress bars from V10WinStack, one row of small ticks, and the button stack.
#
#   var p: = V10WinPanel.make(ctx, width)      ctx as in V10WinStack (+ count, stars_map, buttons: bool, on_more)
#   parent.add_child(p); p.position = …; p.play(delay)   delay = when the 0.9 stamps are done (play.gd _v9_yaku_at…)
#   p.height() — total height. Place the panel BOTTOM-anchored: p.position.y = H − B − 24 − p.height(), so the
#   buttons stand on their fixed places in the bottom third (HUD_V2 §8.3: primary ≈ y 1064–1168, secondary
#   ≈ 1176–1256 at 720×1280) and the extra height of 9:20 screens stays above for the heroine.
#   signals: more(next_index) · salon() · home() · denied(hint) (kept for old callers; the end of the path no longer
#   denies — it says why in a caption)
#
# Buttons (path mode only; other modes keep their 0.9 buttons, ctx.buttons = false hides them):
#   · primary «Ещё уровень · 58» — class «Игра», ≥ 440×104, centred (ux_role primary, the screen's only one);
#   · secondary under it, 80 high, class «Вторичная» (text + chevron): «В салон» when the salon bar is registered
#     and open (ctx.salon_open), otherwise «В чайную» (UX §3.4 names);
#   · at the end of the path: the caption «Все столы арки пройдены · новая уже в пути» and «В чайную» becomes the
#     primary (no grey dead button); «В салон» stays secondary when open.
# The «Ещё уровень» tap plays the press, then V10MoreLevel.wipe() (0.4 s) and calls ctx.on_more(next) under the
# curtain when ctx.on_more is set; the signal `more` fires either way — once (a second tap during the wipe is ignored).
# The ticks are information (not tappable); a bar is tappable only when its owner asked for it (V10WinBar opts.tap).

signal more(next_index: int)
signal salon
signal home
signal denied(hint: String)

const GAP: = 8.0
const TICK_H: = 40.0
const BTN_H: = 104.0
const ALT_H: = 80.0
const BTN_W_MAX: = 560.0

var ctx: Dictionary
var w: = 0.0
var bars: Array = []
var tick_row: Control
var more_btn: JButton
var alt_btn: Control
var end_note: Control
var st: Dictionary
var _h: = 0.0
var _going: = false


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
	var max_bars: = int(ctx.get("max_bars", 2))
	if max_bars > 0:
		var built_bars: = V10WinStack.build_bars(ctx, w)
		for bi in mini(max_bars, built_bars.size()):
			var c: Control = built_bars[bi]
			c.position = Vector2(0, y)
			add_child(c)
			bars.append(c)
			y += c.size.y + GAP
	var tk: = V10WinStack.ticks(ctx)
	if not tk.is_empty():
		tick_row = _build_ticks(tk)
		tick_row.position = Vector2(0, y)
		add_child(tick_row)
		y += TICK_H + GAP
	if _path() and bool(ctx.get("buttons", true)):
		y += 16.0
		y = _build_buttons(y)
	else:
		y -= GAP
	_h = maxf(0.0, y)
	size = Vector2(w, _h)


func _build_ticks(tk: Array) -> Control:
	var row: = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size = Vector2(w, TICK_H)
	var fs: = V10MetaUI.FS_CAPTION
	var chips: = []
	var total: = 0.0
	for d in tk:
		var txt: = str(d.get("text", ""))
		var tw: = UI.font("body", 800).get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cw: = 12.0 + 28.0 + 8.0 + tw + 16.0
		chips.append([d, cw, txt])
		total += cw
	var gap: = 8.0
	total += gap * (chips.size() - 1)
	# one row only: the ticks that do not fit are dropped from the end (lowest order), never drawn past the edge
	while total > w and chips.size() > 1:
		total -= chips.pop_back()[1] + gap
	var x: = maxf(0.0, (w - total) * 0.5)
	for c in chips:
		var d: Dictionary = c[0]
		var chip: = V10MetaUI.plate(Rect2(x, 0, c[1], TICK_H), V10MetaUI.NIGHT_800, 0.85, false)
		row.add_child(chip)
		var ic = d.get("icon", null)
		var tex: Texture2D = ic if ic is Texture2D else (V8Art.icon(str(ic)) if ic != null else null)
		if tex:
			chip.add_child(UI.tex(tex, Rect2(12, 6, 28, 28)))
		var l: = V10MetaUI.text(c[2], fs, V10MetaUI.PAPER_300, "body", 800)
		l.position = Vector2(48, 0)
		l.size = Vector2(c[1] - 56, TICK_H)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(l)
		x += c[1] + gap
	return row


func _build_buttons(y: float) -> float:
	st = V10MoreLevel.state(ctx)
	var salon_ok: = bool(ctx.get("salon_open", false)) and V10WinStack.has_bar("salon")
	var bw: = minf(w, BTN_W_MAX)
	var bx: = (w - bw) * 0.5
	if bool(st.enabled):
		more_btn = JButton.make(str(st.text), "gold", Rect2(bx, y, bw, BTN_H), null, V10MetaUI.FS_DISPLAY)
		more_btn.name = "MoreLevel"
		more_btn.shine_every = 2.8
		more_btn.pulse = true
		more_btn.pressed.connect(_on_more)
		V10MetaUI.role(more_btn, "primary")
		add_child(more_btn)
		y += BTN_H + 8.0
		var alt_text: = "В салон" if salon_ok else "В чайную"
		alt_btn = V10MetaUI.TextButton.make(alt_text, Rect2(bx, y, bw, ALT_H), V10MetaUI.FS_BODY)
		alt_btn.name = "AltBtn"
		alt_btn.pressed.connect(func(): (salon if salon_ok else home).emit())
		V10MetaUI.role(alt_btn, "secondary")
		add_child(alt_btn)
		return y + ALT_H
	# the end of the path: say why, and the way home is the main action
	# on a night plate like the ticks: Caption 18 straight on the scene art fails the 4.5:1 contrast (В-2)
	var nt: = str(st.text)
	var nw: = minf(w, UI.font("body", 800).get_string_size(nt, HORIZONTAL_ALIGNMENT_LEFT, -1, V10MetaUI.FS_CAPTION).x + 32.0)
	end_note = V10MetaUI.plate(Rect2((w - nw) * 0.5, y, nw, 36), V10MetaUI.NIGHT_800, 0.85, false)
	end_note.name = "EndNote"
	var nl: = V10MetaUI.text(nt, V10MetaUI.FS_CAPTION, V10MetaUI.PAPER_300, "body", 800)
	nl.position = Vector2(16, 0)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	V10MetaUI.trim(nl, Vector2(nw - 32, 36))
	end_note.add_child(nl)
	add_child(end_note)
	y += 36.0 + 12.0
	more_btn = JButton.make("В чайную", "gold", Rect2(bx, y, bw, BTN_H), null, V10MetaUI.FS_DISPLAY)
	more_btn.name = "HomeBtn"
	more_btn.pulse = true
	more_btn.pressed.connect(func(): home.emit())
	V10MetaUI.role(more_btn, "primary")
	add_child(more_btn)
	y += BTN_H
	if salon_ok:
		y += 8.0
		alt_btn = V10MetaUI.TextButton.make("В салон", Rect2(bx, y, bw, ALT_H), V10MetaUI.FS_BODY)
		alt_btn.name = "AltBtn"
		alt_btn.pressed.connect(func(): salon.emit())
		V10MetaUI.role(alt_btn, "secondary")
		add_child(alt_btn)
		y += ALT_H
	return y


func _on_more() -> void:
	var nx: = int(st.get("next", -1))
	if nx < 0 or _going:
		return
	_going = true
	more.emit(nx)
	var cb: Callable = ctx.get("on_more", Callable())
	if cb.is_valid():
		V10MoreLevel.wipe(self, func(): cb.call(nx))


# staged entrance after the 0.9 stamps: bars slide up one by one (their stars fly in), ticks fade in, buttons pop.
# fx_level=min: every element only fades in (120 ms), nothing flies.
func play(delay: float = 0.0) -> void:
	for c in get_children():
		(c as CanvasItem).modulate.a = 0.0
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	var d: = 0.0
	for b in bars:
		V10MetaUI.enter(b, Vector2(0, 12), d, 0.24)
		if b is V10WinBar:
			(b as V10WinBar).play(d + 0.3)
		d += 0.04 if not V9Feel.can_fx() else 0.18
	if tick_row:
		V10MetaUI.enter(tick_row, Vector2(0, 12), d + 0.1, 0.24)
		d += 0.15
	for b in [end_note, more_btn, alt_btn]:
		if b != null:
			V10MetaUI.enter(b, Vector2(0, 12), d + 0.2, 0.24)
			d += 0.04
