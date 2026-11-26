class_name V10TowerFan
extends Control

# V10TowerFan — the card fan of the tower (spec 0.10 R1 «Игрок»): «1 из 3» blessings after a floor / board, «1 из 2»
# curses after a Journey board. UX §6.8 «Фишка как форма» (3:4 card, bevel cut 12, chamfer) and «Печать-ханко»
# (the confirm stamp), §6.7 motion, HUD_V2 §2.5 buttons on fixed places (H−B−216 / H−B−104).
#
#   var f := V10TowerFan.open(parent, cards, {title = "Выбери благословение", run = run, mode = "pagoda"})
#   f.picked.connect(func(id): V10Pagoda.pick_blessing(run, id))
#   cards: dicts of V10Mods.bless_card(id, run) / V10Mods.curse_card(id, lvl, mode)
#   opts:  title (H1, left field), can_skip + skip_text («Без проклятия»), run (badge «уже ×N»), mode,
#          subtitle (Caption 18 under the title), embedded (true inside a V10TowerSheets sheet: no own backdrop,
#          the sheet fades its content on «показать стол» through peek_changed)
#
# Flow: the cards come up from under the bottom edge (вдох, 40 ms steps, QUINT OUT, tilt ±6°). A tap lifts a card
# (+40 px, «вдох» 1,06, sound, haptic), the others step aside and dim. A second tap on the lifted card or «Взять»
# (the only primary) confirms: a cinnabar hanko falls on the card (140 ms, one squashed frame, a dull «тук»), the
# ink shows in 300 ms, then picked(id) and the fan leaves. A swipe down over the fan = «показать стол»: the fan goes
# down while the finger holds and comes back on release. can_skip → secondary «Без проклятия» → skipped.
# fx_level «min»: every motion is a 120 ms fade, no particles; all information stays.
# The fan never credits or applies anything itself: the caller (or V10TowerSheets) applies the pick.

signal picked(id: String)
signal skipped
signal lifted(id: String)
signal peek_changed(k: float)

const UI: = preload("res://scripts/v10/tower/ui/tower_ui.gd")
const ART: = preload("res://scripts/v10/tower/ui/tower_art.gd")

const CARD: = Vector2(208, 280)  # 3:4 (≈ 0,743 on the 8-grid)
const CUT: = 12.0  # bevel cut of the corners (UX §6.1 «скос 12»)
const TILT: = 6.0  # degrees of the outer cards
const DROP: = 20.0  # outer cards sit lower: the arc of a hand of cards
const STEP3: = 230.0  # centre distance of 3 cards (no overlap even with the tilt)
const STEP2: = 244.0
const LIFT: = 40.0
const LIFT_SCALE: = 1.06
const SHIFT: = 12.0  # neighbours move away from the lifted card
const DIM: = 0.5  # neighbours' brightness
const TAB_H: = 28.0  # «+ она с тобой» tab straddles the top edge
const PEEK_MAX: = 460.0
const EMO: = "shy"  # her portrait: eyes open, a warm smile

static var hint_shown: = false  # «Потяни вниз — посмотреть стол» once per session

var cards: Array = []
var opts: Dictionary = {}
var embedded: = false
var L: Dictionary = {}
var slots: Array = []  # Control per card (position / rotation / lift)
var views: Array = []  # CardView per card
var sel: = -1
var done: = false
var peek: = 0.0
var title_l: Label
var hint_l: Label
var take_b: V10Button
var skip_b: V10Button
var zone: Control
var deck: Control
var backdrop: Control
var _press_at: = Vector2.ZERO
var _pressing: = false
var _dragging: = false
var _peek_tw: Tween
var _take_a: = 1.0
var _d0: = 0.0  # opts.delay: the sheet deals the fan as its second beat


static func open(parent: Control, cards_in: Array, opts_in: = {}) -> V10TowerFan:
	var f: = V10TowerFan.new()
	f.cards = cards_in.duplicate()
	f.opts = opts_in
	f.embedded = bool(opts_in.get("embedded", false))
	parent.add_child(f)
	return f


# ---------------------------------------------------------------- layout (pure)

static func compute(vs: Vector2, ins: Dictionary, n: int) -> Dictionary:
	var W: = vs.x
	var H: = vs.y
	var T: = float(ins.get("top", 0.0))
	var B: = float(ins.get("bottom", 0.0))
	var cx: = floorf(maxf(0.0, (W - 720.0) * 0.5))
	var d: = {"vs": vs, "T": T, "B": B, "cx": cx}
	d.play = Rect2(cx + 80, H - B - 216, 560, 104)
	d.second = Rect2(cx + 80, H - B - 104, 560, 80)
	var bottom: = (d.play as Rect2).position.y - 64.0
	var cy: = bottom - CARD.y * 0.5
	var sl: = []
	for i in n:
		var k: = float(i) - float(n - 1) * 0.5
		var step: = STEP3 if n >= 3 else STEP2
		var y: = cy + (DROP * absf(k) if n >= 3 else (8.0 if n == 2 else 0.0))
		sl.append({"c": Vector2(cx + 360.0 + k * step, y), "rot": deg_to_rad(TILT * signf(k))})
	d.slots = sl
	d.card_top = cy - CARD.y * 0.5
	var lifted_top: = float(d.card_top) - LIFT - CARD.y * (LIFT_SCALE - 1.0) * 0.5 - TAB_H * 0.5
	d.hint = Rect2(cx + 32, lifted_top - 8.0 - 26.0, 656, 26)
	d.title = Rect2(cx + 32, (d.hint as Rect2).position.y - 2.0 - 62.0, 656, 62)
	d.zone = Rect2(cx, (d.title as Rect2).position.y, 720, (d.play as Rect2).position.y - 40.0 - (d.title as Rect2).position.y)
	return d


# ---------------------------------------------------------------- build

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vs: = get_viewport_rect().size
	L = compute(vs, UI.insets(vs), cards.size())
	if not embedded:
		mouse_filter = Control.MOUSE_FILTER_STOP  # the table below does not take taps while the fan is up
		backdrop = _Backdrop.new()
		backdrop.fan = self
		add_child(backdrop)
	zone = _Zone.new()
	zone.fan = self
	add_child(zone)
	deck = Control.new()
	deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck.size = vs
	add_child(deck)
	for i in cards.size():
		var s: = Control.new()
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.size = CARD
		s.pivot_offset = CARD * 0.5
		deck.add_child(s)
		var v: = CardView.new(cards[i], opts)
		s.add_child(v)
		slots.append(s)
		views.append(v)
	var title: = UI.ui_text(String(opts.get("title", "")))
	title_l = Label.new()
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fit_label(title_l, title, "display", [44, 32], 656.0, 1, V10DS.PAPER_100)
	add_child(title_l)
	var sub: = UI.ui_text(String(opts.get("subtitle", "")))
	var show_hint: = not hint_shown
	if show_hint:
		hint_shown = true
		sub = "Потяни вниз — посмотреть стол"
	hint_l = UI.label(sub, "ui", 18, V10DS.PAPER_500)
	hint_l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	hint_l.visible = sub != ""
	add_child(hint_l)
	take_b = V10Button.make("play", "Взять", Vector2(560, 104))
	UI.role(take_b, "primary")
	take_b.pressed.connect(_on_take)
	add_child(take_b)
	if bool(opts.get("can_skip", false)):
		skip_b = V10Button.make("secondary", UI.ui_text(String(opts.get("skip_text", "Без проклятия"))), Vector2(560, 80))
		UI.role(skip_b, "secondary")
		skip_b.pressed.connect(_on_skip)
		add_child(skip_b)
	_layout()
	_set_take_ready(false)
	_enter()


func _layout() -> void:
	var vs: = get_viewport_rect().size
	if backdrop:
		backdrop.size = vs
	zone.position = (L.zone as Rect2).position
	zone.size = (L.zone as Rect2).size
	deck.size = vs
	title_l.position = (L.title as Rect2).position
	title_l.size = (L.title as Rect2).size
	hint_l.position = (L.hint as Rect2).position
	hint_l.size = (L.hint as Rect2).size
	take_b.position = (L.play as Rect2).position
	if skip_b:
		skip_b.position = (L.second as Rect2).position
	for i in slots.size():
		var s: Control = slots[i]
		var st: Dictionary = _target(i)
		s.position = st.pos
		s.rotation = st.rot
		s.scale = Vector2.ONE * float(st.scale)


func _target(i: int) -> Dictionary:
	var sl: Dictionary = (L.slots as Array)[i]
	var base: Vector2 = (sl.c as Vector2) - CARD * 0.5
	var out: = {"pos": base, "rot": float(sl.rot), "scale": 1.0, "dim": 1.0, "z": 0}
	if sel >= 0:
		if i == sel:
			out.pos = base - Vector2(0, LIFT)
			out.rot = 0.0
			out.scale = LIFT_SCALE
			out.z = 2
		else:
			out.pos = base + Vector2(SHIFT * signf(float(i - sel)), 0)
			out.dim = DIM
	return out


func _enter() -> void:
	var calm: = UI.calm()
	var vs: = get_viewport_rect().size
	_d0 = float(opts.get("delay", 0.0))
	for n in [title_l, hint_l]:
		_fade_in(n, 0.0)
	if backdrop:
		_fade_in(backdrop, 0.0, 0.22)
	for i in slots.size():
		var s: Control = slots[i]
		var st: Dictionary = _target(i)
		if calm:
			_fade_in(s, 0.0)
			continue
		# from under the bottom edge: «вдох» with a 40 ms step, QUINT OUT; the tilt opens while it rises
		var end_pos: Vector2 = st.pos
		s.position = Vector2(end_pos.x, vs.y + 40.0)
		s.rotation = float(st.rot) * 2.2
		s.modulate.a = 0.0
		var d: = _d0 + 0.08 + i * V10DS.T_IN_STEP
		var tw: = s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", end_pos, 0.36).set_delay(d).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "rotation", float(st.rot), 0.36).set_delay(d).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 1.0, 0.16).set_delay(d)
		var tw_s: = s.create_tween()
		tw_s.tween_interval(d)
		tw_s.tween_callback(func() -> void: V9Feel.sound("flip", 0.92 + 0.06 * i, -8.0))
	# the one primary is on its place from the first beat of the sheet (grey until a card is lifted)
	_fade_in(take_b, minf(_d0 + 0.24, 0.3) - _d0, 0.0, _take_a)
	if skip_b:
		_fade_in(skip_b, 0.28)
	if hint_l.visible and hint_l.text == "Потяни вниз — посмотреть стол":
		# the hint is said once and then gives its place to the subtitle (if any)
		var sub: = UI.ui_text(String(opts.get("subtitle", "")))
		var tw2: = hint_l.create_tween()
		tw2.tween_interval(5.0 + _d0)
		tw2.tween_property(hint_l, "modulate:a", 0.0, 0.3)
		tw2.tween_callback(func() -> void:
			hint_l.text = sub
			hint_l.visible = sub != ""
			hint_l.modulate.a = 1.0)


func _fade_in(n: CanvasItem, delay: float, dur: = 0.0, to: = 1.0) -> void:
	if dur <= 0.0:
		dur = 0.12 if UI.calm() else V10DS.T_IN
	n.modulate.a = 0.0
	var tw: = n.create_tween()
	tw.tween_property(n, "modulate:a", to, dur).set_delay(delay + _d0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _set_take_ready(on: bool) -> void:
	# before a card is lifted «Взять» is grey with its reason above it (no dead buttons: a tap says «no»)
	_take_a = 1.0 if on else 0.42
	take_b.breathing = on
	take_b.sheen = on
	take_b.modulate.a = _take_a * _btn_k(peek / PEEK_MAX)
	take_b.set_meta("ux_ready", on)


# ---------------------------------------------------------------- selection

func card_id(i: int) -> String:
	return String((cards[i] as Dictionary).get("id", "")) if i >= 0 and i < cards.size() else ""


func select(i: int) -> void:
	if done or i < 0 or i >= views.size():
		return
	if i == sel:
		confirm()
		return
	sel = i
	_apply_sel()
	UI.tap(views[i], "select")
	_set_take_ready(true)
	lifted.emit(card_id(i))


func deselect() -> void:
	if done or sel < 0:
		return
	sel = -1
	_apply_sel()
	_set_take_ready(false)


func _apply_sel() -> void:
	var calm: = UI.calm()
	var dur: = 0.12 if calm else V10DS.T_IN
	for i in slots.size():
		var s: Control = slots[i]
		var v: CardView = views[i]
		var st: Dictionary = _target(i)
		s.z_index = int(st.z)
		var col: = Color(float(st.dim), float(st.dim), float(st.dim), 1.0)
		var tw: = s.create_tween().set_parallel(true)
		if calm:
			s.position = st.pos
			s.rotation = float(st.rot)
			s.scale = Vector2.ONE * float(st.scale)
		else:
			tw.tween_property(s, "position", st.pos, dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tw.tween_property(s, "rotation", float(st.rot), dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tw.tween_property(s, "scale", Vector2.ONE * float(st.scale), dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "modulate", col, dur)
		tw.tween_property(v, "lit", 1.0 if i == sel else 0.0, dur)


func confirm() -> void:
	if done:
		return
	if sel < 0:
		UI.deny(take_b)
		return
	done = true
	var i: = sel
	var v: CardView = views[i]
	var id: = card_id(i)
	for b in [take_b, skip_b]:
		if b:
			var tw: = (b as Control).create_tween()
			tw.tween_property(b, "modulate:a", 0.0, 0.16)
			tw.tween_callback(func() -> void: (b as Control).visible = false)
	var t_ink: = v.stamp()
	var tw2: = create_tween()
	tw2.tween_interval(t_ink)
	tw2.tween_callback(func() -> void:
		picked.emit(id)
		_leave(0.12))


func skip() -> void:
	if done:
		return
	done = true
	UI.tap(skip_b if skip_b else take_b)
	for b in [take_b, skip_b]:
		if b:
			(b as Control).visible = false
	skipped.emit()
	_leave(0.0)


func _on_take() -> void:
	if sel < 0:
		UI.deny(take_b)
		return
	UI.tap(take_b)
	confirm()


func _on_skip() -> void:
	skip()


func _leave(delay: float) -> void:
	var calm: = UI.calm()
	var vs: = get_viewport_rect().size
	var tw: = create_tween().set_parallel(true)
	for n in [title_l, hint_l, backdrop]:
		if n:
			tw.tween_property(n, "modulate:a", 0.0, 0.16).set_delay(delay)
	for i in slots.size():
		var s: Control = slots[i]
		if calm:
			tw.tween_property(s, "modulate:a", 0.0, 0.12).set_delay(delay)
		else:
			var d: = delay + 0.03 * i
			tw.tween_property(s, "position:y", vs.y + 60.0, 0.22).set_delay(d).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


# ---------------------------------------------------------------- input: tap, lift, «показать стол»

# hit test in screen space against the rotated cards (the lifted card first)
func card_at(p: Vector2) -> int:
	var order: = range(slots.size())
	order.sort_custom(func(a, b) -> bool: return (slots[a] as Control).z_index > (slots[b] as Control).z_index)
	for i in order:
		var s: Control = slots[i]
		var lp: = s.get_global_transform().affine_inverse() * p
		if Rect2(Vector2.ZERO, CARD).has_point(lp):
			return int(i)
	return -1


func tap_at(p: Vector2) -> void:
	if done:
		return
	var i: = card_at(p)
	if i >= 0:
		select(i)
	elif sel >= 0:
		deselect()


func set_peek(dy: float) -> void:
	peek = clampf(dy, 0.0, PEEK_MAX)
	var k: = peek / PEEK_MAX
	deck.position.y = peek
	for n in [title_l, hint_l]:
		(n as CanvasItem).modulate.a = 1.0 - k
	# the buttons leave first: the cards going down never lie on a live button
	if skip_b:
		skip_b.modulate.a = _btn_k(k)
	take_b.modulate.a = _take_a * _btn_k(k)
	if backdrop:
		backdrop.modulate.a = 1.0 - k
	peek_changed.emit(k)


static func _btn_k(k: float) -> float:
	return clampf(1.0 - k * 3.0, 0.0, 1.0)


func release_peek() -> void:
	if _peek_tw and _peek_tw.is_valid():
		_peek_tw.kill()
	_peek_tw = create_tween()
	_peek_tw.tween_method(set_peek, peek, 0.0, 0.12 if UI.calm() else V10DS.T_IN).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	# the button keeps its «not ready» dimming after a peek
	_peek_tw.tween_callback(func() -> void: _set_take_ready(sel >= 0))


func _zone_input(e: InputEvent) -> void:
	if done:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: = e as InputEventMouseButton
		if mb.pressed:
			_press_at = mb.global_position
			_pressing = true
			_dragging = false
		elif _pressing:
			_pressing = false
			if _dragging:
				_dragging = false
				release_peek()
			else:
				tap_at(mb.global_position)
	elif e is InputEventMouseMotion and _pressing:
		var d: = (e as InputEventMouseMotion).global_position - _press_at
		if not _dragging and d.y > 18.0 and absf(d.y) > absf(d.x):
			_dragging = true
			if _peek_tw and _peek_tw.is_valid():
				_peek_tw.kill()
		if _dragging:
			set_peek(maxf(0.0, d.y - 18.0))


class _Zone:
	extends Control
	var fan: V10TowerFan

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("gesture_zone", true)

	func _gui_input(e: InputEvent) -> void:
		if fan:
			fan._zone_input(e)
			accept_event()


class _Backdrop:
	extends Control
	var fan: V10TowerFan

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# standalone: the table stays visible above the fan; a tone (not a box) rises from under the cards
		var y1: = float((fan.L.title as Rect2).position.y) - 24.0
		var y0: = y1 - 160.0
		var w: = size.x
		var c0: = Color(V10DS.NIGHT_900, 0.0)
		var c1: = Color(V10DS.NIGHT_900, 0.88)
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]), PackedColorArray([c0, c0, c1, c1]))
		draw_rect(Rect2(0, y1, w, size.y - y1), c1)


# ---------------------------------------------------------------- the card («фишка как форма»)

# the card shape: a 3:4 tile with the four corners cut by CUT
static func shape(sz: Vector2, inset: = 0.0, cut: = CUT) -> PackedVector2Array:
	var a: = inset
	var c: = cut + inset * 0.4
	return PackedVector2Array([Vector2(a + c, a), Vector2(sz.x - a - c, a), Vector2(sz.x - a, a + c), Vector2(sz.x - a, sz.y - a - c),
		Vector2(sz.x - a - c, sz.y - a), Vector2(a + c, sz.y - a), Vector2(a, sz.y - a - c), Vector2(a, a + c)])


static func moved(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out: = PackedVector2Array()
	for q in p:
		out.append(q + d)
	return out


# A/S/SSR of a heroine (docs/ROSTER_20) → the colour of the rarity stripe (UX §6.2 «полоса на скосе»)
static func rarity_of(hero: String) -> String:
	return String(V10TowerUtil.ROSTER_RANK.get(hero, "A"))


static func rarity_color(r: String) -> Color:
	return G.rar_color({"A": "R", "S": "SR"}.get(r, r))


static func accent_of(hero: String) -> Dictionary:
	if V10DS.HEROES.has(hero):
		return V10DS.hero(hero)
	var c: Color = G.HEROES[hero].color if G.HEROES.has(hero) else V10DS.GOLD_500
	return {"accent": c, "glow": c.lightened(0.4), "deep": c.darkened(0.55)}


# a standalone card node (the heat flare, curse scrolls and tests use the same look)
static func card_node(card: Dictionary, o: = {}) -> CardView:
	return CardView.new(card, o)


# fit a label to its box: the first size of `sizes` that fits in `max_lines` wins, else the last size + ellipsis
# (logged in V10Type.overflow, the selftest reads it)
static func fit_label(l: Label, text: String, role: String, sizes: Array, max_w: float, max_lines: int, col: Color, on_art: = false) -> int:
	var chosen: int = sizes[sizes.size() - 1]
	var ok: = false
	for s in sizes:
		if (max_lines <= 1 and V10Type.text_w(text, role, s) <= max_w) or (max_lines > 1 and V10Type.lines_needed(text, role, s, max_w) <= max_lines):
			chosen = s
			ok = true
			break
	if not ok:
		V10Type.overflow.append({"text": text, "steps": role, "max_w": max_w})
	l.text = text
	l.label_settings = V10Type.settings(role, chosen, col, on_art)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if max_lines > 1 else TextServer.AUTOWRAP_OFF
	l.max_lines_visible = max_lines if max_lines > 1 else -1
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.set_meta("v10_role", role)
	l.set_meta("v10_fit_ok", ok)
	return chosen


static func lines_of(text: String, role: String, size: int, max_w: float) -> int:
	return V10Type.lines_needed(text, role, size, max_w)


# the height of a label box that shows `lines` lines whole: the font is taller than its line step at 26+
# (Display 44: 61 px of font in a 52 px line), and a Label grows to the font height anyway
static func box_h(role: String, size: int, lines: = 1) -> float:
	var lh: = float(V10Type.line_h(size))
	var fh: = V10Type.font(role).get_height(size)
	return lines * lh + maxf(0.0, fh - lh) + 1.0


static func circle(c: Vector2, r: float, n: = 40) -> PackedVector2Array:
	var p: = PackedVector2Array()
	for i in n:
		p.append(c + Vector2.from_angle(TAU * i / n) * r)
	return p


class CardView:
	extends Control

	# Text sizes of the card stay inside the sheet's type budget (UX §3.7 «≤ 4 кеглей»: 44 · 32 · 22 · 18 + Overline):
	# the name / price is Overline 15, the title Display 22 (18 for the longest), the effect UI 18 (≤ 4 lines, curse ≤ 5).
	const PAD: = 12.0
	const NAME_H: = 22.0
	const TITLE_H: = 32.0
	const LINE_H: = 26.0
	const BOTTOM: = 12.0
	const FACE_W: = 66.0  # her face, cheek to cheek, on the card
	const FACE_C: = Vector2(104, 60)  # between the eyes and the mouth
	const SEAL_MAX: = 104.0
	const SEAL_MIN: = 56.0

	var data: Dictionary
	var kind: = "bless"
	var mode: = "pagoda"
	var plus: = false
	var have: = 0
	var hero: = ""
	var acc: Dictionary = {}
	var tex: Texture2D
	var face: = Vector2.ZERO
	var face_w: = 150.0
	var heat: = 0
	var lit: = 0.0:  # lifted: her light behind the card
		set(v):
			lit = v
			queue_redraw()
	var flare: = 0.0:  # heat flare: the edge burns in the heat colour (no white)
		set(v):
			flare = v
			queue_redraw()
	var flare_col: = V10DS.GOLD_300
	var name_l: Label
	var badge_l: Label
	var title_l: Label
	var line_l: Label
	var tag_l: Label  # curse: the price («+3 Жара» / «очки ×1,15») — the Overline of the card
	var mono_l: Label
	var tab: Control
	var seal: Control

	func _init(card: Dictionary, o: = {}) -> void:
		data = card
		kind = String(card.get("kind", "bless"))
		mode = String(o.get("mode", (o.get("run", {}) as Dictionary).get("mode", "pagoda")))
		size = V10TowerFan.CARD
		custom_minimum_size = size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_meta("tower_card", String(card.get("id", "")))
		if kind == "bless":
			plus = bool(card.get("plus", false))
			hero = String(card.get("hero", "mc"))
			acc = V10TowerFan.accent_of(hero)
			var run: Dictionary = o.get("run", {})
			have = int((run.get("bless", {}) as Dictionary).get(String(card.get("id", "")), 0))
			if Hero.RIGS.has(V8Art.emo_hero(hero)):
				tex = V8Art.emotion(hero, V10TowerFan.EMO)
				face = V8Art.emotion_face(hero, V10TowerFan.EMO)
				face_w = V8Art.emotion_face_w(hero, V10TowerFan.EMO)
		else:
			heat = int(card.get("heat", 0))
			tex = V10TowerArt.curse_tex(String(card.get("id", "")))
			flare_col = V10TowerUI.heat_color(maxi(heat * 4, 8))
		_build()

	func _build() -> void:
		var w: = size.x - PAD * 2.0
		name_l = Label.new()
		title_l = Label.new()
		line_l = Label.new()
		for l in [name_l, title_l, line_l]:
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(l)
		var on_art: = kind == "bless" and tex != null
		# the Overline: her name (gold) or the price of the curse (heat colour, Пагода) / the score bonus (Странствие)
		var nm: = String(data.get("hero_name", "")) if kind == "bless" else String(data.get("tag", "Проклятие"))
		var ncol: = V10DS.GOLD_500
		if kind != "bless":
			ncol = flare_col if mode == "pagoda" else V10DS.GOLD_300
			tag_l = name_l
		name_l.text = V10TowerUI.ui_text(nm).to_upper()
		name_l.label_settings = V10Type.settings("overline", 15, ncol, on_art)
		name_l.set_meta("v10_role", "overline")
		name_l.clip_text = true
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		if have > 0:
			badge_l = V10TowerUI.label("уже ×%d" % have, "ui", 18, V10DS.PAPER_300, on_art)
			badge_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			badge_l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			add_child(badge_l)
		# the title: Display 22 on one line (18 for the longest names); the effect: UI 18, as many lines as it needs
		var title: = V10TowerUI.ui_text(String(data.get("title", "")))
		var line: = V10TowerUI.ui_text(String(data.get("line", "")))
		var ts: = V10TowerFan.fit_label(title_l, title, "display", [22, 18], w, 1, V10DS.PAPER_100, on_art)
		if ts < 22:
			title_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var l_max: = 4 if kind == "bless" else 5
		V10TowerFan.fit_label(line_l, line, "ui", [18], w, l_max, V10DS.PAPER_300)
		var n_line: = mini(l_max, V10TowerFan.lines_of(line, "ui", 18, w))
		var bottom: = size.y - BOTTOM
		line_l.position = Vector2(PAD, bottom - LINE_H * n_line)
		line_l.size = Vector2(w, V10TowerFan.box_h("ui", 18, n_line))
		title_l.position = Vector2(PAD, line_l.position.y - 2.0 - TITLE_H)
		title_l.size = Vector2(w, TITLE_H)
		name_l.position = Vector2(PAD, title_l.position.y - NAME_H)
		name_l.size = Vector2(w, NAME_H)
		if badge_l:
			badge_l.position = Vector2(PAD, name_l.position.y - 3.0)
			badge_l.size = Vector2(w, 26)
			var bw: = V10Type.text_w(badge_l.text, "ui", 18)
			name_l.size.x = maxf(40.0, w - bw - 8.0)
		if kind == "curse":
			if tex == null:
				# the seal of the curse: its first letter, paper on cinnabar
				mono_l = V10TowerUI.label(title.substr(0, 1).to_upper(), "display", 44, V10DS.PAPER_100)
				mono_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				mono_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				mono_l.size = Vector2(80, V10TowerFan.box_h("display", 44, 1))
				mono_l.position = _seal_c() - mono_l.size * 0.5
				add_child(mono_l)
		elif plus:
			tab = _Tab.new(self)
			add_child(tab)

	# the curse medallion fills the space above the text (56..104 px)
	func _seal_r() -> float:
		var top: = 14.0
		var bot: = name_l.position.y - 8.0
		return clampf(bot - top, SEAL_MIN, SEAL_MAX) * 0.5

	func _seal_c() -> Vector2:
		var top: = 14.0
		var bot: = name_l.position.y - 8.0
		return Vector2(size.x * 0.5, top + maxf(bot - top, SEAL_MIN) * 0.5)

	func text_top() -> float:
		return minf(name_l.position.y, badge_l.position.y if badge_l else 9999.0)

	func _draw() -> void:
		var sz: = size
		var poly: = V10TowerFan.shape(sz)
		# lifted: her light behind the card (accent colour, warm, low alpha — never white); many thin steps, no bands
		if lit > 0.01:
			var gc: Color = acc.get("accent", V10TowerUI.SEAL) if kind == "bless" else V10TowerUI.SEAL
			_halo(gc, 0.035 * lit, 12, 3.5)
		if flare > 0.01:
			_halo(flare_col, 0.06 * flare, 14, 4.0)
		# the tile's thickness (form, not a shadow): the same shape 5 px lower in night.900
		draw_colored_polygon(V10TowerFan.moved(V10TowerFan.shape(sz), Vector2(0, 5)), V10DS.NIGHT_900)
		var base: = V10DS.NIGHT_800 if kind == "bless" else V10TowerUI.LACQUER
		draw_colored_polygon(poly, base)
		if kind == "bless":
			_draw_portrait(sz)
		else:
			_draw_curse(sz)
		# bevel («фаска»): light on the top-left inner edge, dark on the bottom-right
		var inner: = V10TowerFan.shape(sz, 3.0)
		var hi: = Color(V10DS.PAPER_100, 0.10)
		var lo: = Color(V10DS.NIGHT_900, 0.55)
		draw_polyline(PackedVector2Array([inner[6], inner[7], inner[0], inner[1]]), hi, 1.0, true)
		draw_polyline(PackedVector2Array([inner[2], inner[3], inner[4], inner[5]]), lo, 1.0, true)
		# the rarity stripe lies on the bevel cut (top left); curse cards carry no rarity
		if kind == "bless":
			var rc: = V10TowerFan.rarity_color(V10TowerFan.rarity_of(hero))
			var c: = V10TowerFan.CUT
			draw_polyline_colors(PackedVector2Array([Vector2(0.8, c + 30.0), Vector2(0.8, c), Vector2(c, 0.8), Vector2(c + 30.0, 0.8)]),
				PackedColorArray([Color(rc, 0.0), rc, rc, Color(rc, 0.0)]), 3.0, true)
		# the plus card: a gold edge (the one ornament of the card)
		if plus:
			var e: = V10TowerFan.shape(sz, 1.0)
			e.append(e[0])
			draw_polyline(e, V10DS.GOLD_500, 2.0, true)
		else:
			var e2: = V10TowerFan.shape(sz, 0.5)
			e2.append(e2[0])
			draw_polyline(e2, Color(V10DS.GOLD_700, 0.35), 1.0, true)

	# a soft halo around the card: n thin steps of the card shape
	func _halo(col: Color, a: float, n: int, step: float) -> void:
		for i in n:
			var g: = 2.0 + (n - 1 - i) * step
			var k: = 1.0 - float(n - 1 - i) / float(n)
			draw_colored_polygon(V10TowerFan.moved(V10TowerFan.shape(size + Vector2(g, g) * 2.0, 0.0, V10TowerFan.CUT + g * 0.6), Vector2(-g, -g)),
				Color(col, a * k))

	# a glow disc clipped to a shape (never a grey disc outside the card)
	func _glow(c: Vector2, r: float, col: Color, clip: PackedVector2Array) -> void:
		for pl in Geometry2D.intersect_polygons(V10TowerFan.circle(c, r), clip):
			draw_colored_polygon(pl, col)

	func _draw_portrait(sz: Vector2) -> void:
		var cut: = V10TowerFan.CUT
		var tt: = text_top()
		var art_b: = minf(sz.y - cut, tt + 28.0)
		var art: = PackedVector2Array([Vector2(cut, 0), Vector2(sz.x - cut, 0), Vector2(sz.x, cut),
			Vector2(sz.x, art_b), Vector2(0, art_b), Vector2(0, cut)])
		# a studio backdrop in her colours: deep on top, night at the bottom, a soft light behind the head
		var deep: Color = acc.get("deep", V10DS.NIGHT_700)
		var top: = deep.lerp(V10DS.NIGHT_800, 0.25)
		draw_polygon(art, PackedColorArray([top, top, top, V10DS.NIGHT_800, V10DS.NIGHT_800, top]))
		var gl: Color = acc.get("accent", V10DS.GOLD_500)
		for i in 6:
			_glow(FACE_C + Vector2(0, 8), 26.0 + i * 14.0, Color(gl, 0.045), art)
		if tex:
			var ts: = tex.get_size()
			var s: = FACE_W / maxf(1.0, face_w)
			var org: = FACE_C - face * s
			var img: = PackedVector2Array([org, org + Vector2(ts.x * s, 0), org + ts * s, org + Vector2(0, ts.y * s)])
			for pl in Geometry2D.intersect_polygons(art, img):
				var uvs: = PackedVector2Array()
				for q in pl:
					uvs.append((q - org) / (ts * s))
				draw_polygon(pl, PackedColorArray([Color.WHITE]), uvs, tex)
		else:
			# a heroine without art yet: her initial, large, on her colours
			var f: = V10Type.font("display")
			var ch: = String(data.get("hero_name", "?")).substr(0, 1)
			draw_string(f, Vector2(0, FACE_C.y + 30.0), ch, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 64, Color(V10DS.PAPER_100, 0.5))
		# the portrait fades into the lacquer under the name and the title
		var c0: = Color(V10DS.NIGHT_800, 0.0)
		var c1: = Color(V10DS.NIGHT_800, 0.97)
		var y0: = tt - 40.0
		var y1: = art_b
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(sz.x, y0), Vector2(sz.x, y1), Vector2(0, y1)]), PackedColorArray([c0, c0, c1, c1]))

	func _draw_curse(sz: Vector2) -> void:
		# «алая тушь на лаке»: a lacquer gloss on the top, the medallion with a warm heat glow behind it
		var gloss: = Color(V10TowerUI.LACQUER_HI, 1.0)
		var poly: = V10TowerFan.shape(sz, 2.0)
		var cols: = PackedColorArray()
		for q in poly:
			cols.append(gloss.lerp(V10TowerUI.LACQUER, clampf(q.y / sz.y * 1.6, 0.0, 1.0)))
		draw_polygon(poly, cols)
		var c: = _seal_c()
		var r: = _seal_r()
		for i in 6:
			_glow(c, r * 0.7 + i * 10.0, Color(flare_col, 0.035), poly)
		if tex:
			draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
		else:
			V10TowerUI.draw_seal(self, c, r * 0.8, V10TowerUI.SEAL)

	# the hanko falls (140 ms, one squashed frame, a dull «тук»), the cinnabar shows in 300 ms; returns the time
	# until the ink is set (the fan emits picked then)
	func stamp() -> float:
		var calm: = V10TowerUI.calm()
		seal = ColorRect.new()
		seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seal.color = Color.WHITE
		var ss: = 76.0
		seal.size = Vector2(ss, ss)
		seal.pivot_offset = seal.size * 0.5
		seal.position = Vector2(size.x - ss - 10.0, size.y - ss - 14.0)
		seal.rotation = -0.14
		seal.material = V10Juice.mat("juice_seal", {"color": V10TowerUI.SEAL, "seed": float(get_instance_id() % 97), "fill": 0.92, "erosion": 0.9})
		add_child(seal)
		var ch: = String(data.get("hero_name", "")) if kind == "bless" else String(data.get("title", ""))
		var ml: = V10TowerUI.label(V10TowerUI.ui_text(ch).substr(0, 1).to_upper(), "display", 44, V10DS.PAPER_100)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ml.size = Vector2(ss, V10TowerFan.box_h("display", 44, 1))
		ml.position = Vector2(0, (ss - ml.size.y) * 0.5 + 2.0)
		seal.add_child(ml)
		var tw: = seal.create_tween()
		if calm:
			seal.modulate.a = 0.0
			V10Juice.param(seal, "erosion", 0.22)
			tw.tween_property(seal, "modulate:a", 1.0, 0.12)
			tw.tween_callback(func() -> void:
				V10Juice.sound("stamp_thud", 1.0, -2.0)
				V10TowerUI.haptic("match"))
			return 0.3
		seal.scale = Vector2.ONE * 1.7
		seal.modulate.a = 0.0
		tw.set_parallel(true)
		tw.tween_property(seal, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(seal, "modulate:a", 1.0, 0.08)
		tw.chain().tween_callback(func() -> void:
			seal.scale = Vector2(1.08, 0.9)  # one squashed frame
			V10Juice.sound("stamp_thud", 1.0, -2.0)
			V10TowerUI.haptic("match")
			V10Juice.ripple(self, seal.position + seal.size * 0.5, V10TowerUI.SEAL, 70.0, 0.45, 0.05))
		tw.chain().tween_interval(1.0 / 60.0)
		tw.chain().tween_property(seal, "scale", Vector2.ONE, 0.06)
		tw.parallel().tween_method(func(v: float) -> void: V10Juice.param(seal, "erosion", v), 0.9, 0.22, 0.3)
		return 0.14 + 0.32 + 0.1


class _Tab:
	extends Control
	# «+ она с тобой»: a small lacquer tab over the top edge of her own card (not a caps shout)
	var v: Control
	var l: Label

	func _init(view: Control) -> void:
		v = view
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		l = V10Type.label("+ она с тобой", "ui", 18, V10DS.GOLD_300)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(l)
		var tw: = V10Type.text_w(l.text, "ui", 18) + 24.0
		size = Vector2(tw, V10TowerFan.TAB_H)
		position = Vector2((V10TowerFan.CARD.x - tw) * 0.5, -V10TowerFan.TAB_H * 0.5)
		l.size = size
		l.position = Vector2(0, -1)

	func _draw() -> void:
		var r: = Rect2(Vector2.ZERO, size)
		var sb: = StyleBoxFlat.new()
		sb.bg_color = V10DS.NIGHT_900
		sb.set_corner_radius_all(V10DS.RADIUS)
		sb.border_color = V10DS.GOLD_500
		sb.set_border_width_all(1)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
