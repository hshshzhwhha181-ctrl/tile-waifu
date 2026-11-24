class_name V10TileInfo
extends Node

# «Что это за фишка?» in a match:
#   long press (0.45 s, finger still) on any tile → an info bubble: picture, suit and its number, what it pairs with
#     (only the SAME picture — checked in TrayBoard.tap: x.face == t.face; no flower / season groups in this game),
#     how many twins are left on the table / in the tray, its special behaviour (gold, рубашка, тайная, замок, ключ,
#     цепь, джокер, хлопушка, подарок, портрет) and whether it can be taken now — and if not, the exact reason.
#     A tap still plays at once (no delay on the touch). A long press on a BLOCKED tile un-counts that miss, so
#     looking never costs «Ни одного промаха».
#   «лупа» mode (from the legend: «Показать на столе»): the next tap on a tile only shows its bubble.
#   the «Фишки» pill in the goal plate opens the legend (V10Legend); the goal plate reads «ФИШЕК» (not «ЦЕЛЬ» + sakura).
#
# Hooks (README): play.build → V10Clarity.attach_play(self); TrayBoard._unhandled_input → V10TileInfo.intercept(self, e)

const HOLD: = 0.45
const SLOP: = 22.0

static var active: V10TileInfo = null

var play
var board
var lupa: = false
var _press_t: = -1.0
var _press_pos: = Vector2.ZERO
var _press_tile: Tile = null
var _press_was_deny: = false
var _press_denies: = 0
var _shown_for_press: = false
var bubble: Control = null
var _lupa_bar: Control = null

static func attach(p) -> V10TileInfo:
	var n: = V10TileInfo.new()
	n.name = "V10TileInfo"
	n.play = p
	n.board = p.board
	p.add_child(n)
	active = n
	return n

func _exit_tree() -> void:
	if active == self:
		active = null

# called by TrayBoard._unhandled_input for every touch press on the table, BEFORE the tap. true = consumed.
static func intercept(b, e: InputEvent) -> bool:
	var a: = active
	if a == null or not is_instance_valid(a) or not (e is InputEventScreenTouch) or not e.pressed:
		return false
	a.board = b
	var t: Tile = b.tile_at(e.position)
	# a bubble on screen: this press only closes it (never takes a tile by accident)
	if a.bubble and is_instance_valid(a.bubble):
		a.close_bubble()
		return true
	if t == null:
		return false
	if a.lupa:
		a.set_lupa(false)
		a.show_for(t)
		return true
	a._press_t = G.time
	a._press_pos = e.position
	a._press_tile = t
	a._shown_for_press = false
	a._press_was_deny = not b.is_free(t) or (b.has_method("takeable") and not b.takeable(t))
	a._press_denies = int(a.play.get("denies")) if a.play else 0
	return false

func _input(e: InputEvent) -> void:
	if _press_t < 0.0:
		return
	if e is InputEventScreenTouch and not e.pressed:
		_press_t = -1.0
	elif e is InputEventScreenDrag and e.position.distance_to(_press_pos) > SLOP:
		_press_t = -1.0

func _process(_dt: float) -> void:
	if _press_t >= 0.0 and not _shown_for_press and G.time - _press_t >= HOLD:
		_shown_for_press = true
		var t: = _press_tile
		_press_t = -1.0
		if t and is_instance_valid(t):
			if _press_was_deny and play and int(play.get("denies")) > _press_denies:
				play.denies = int(play.denies) - 1
			show_for(t)

# ── lupa ────────────────────────────────────────────────────────────────────────────────────────────────────────
func set_lupa(on: bool) -> void:
	lupa = on
	if _lupa_bar and is_instance_valid(_lupa_bar):
		_lupa_bar.queue_free()
		_lupa_bar = null
	if not on or play == null:
		return
	var W: float = play.size.x
	var bar: = UI.rbox("gold", Rect2(W * 0.5 - 300, float(play.board_rect.position.y) + 8, 600, 64), 32, 3, 8)
	bar.z_index = 120
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	play.add_child(bar)
	var l: = UI.label("Коснись любой фишки — расскажу о ней", 20, Color("3a2208"), Color(0, 0, 0, 0), 0, "body", 900)
	l.position = Vector2(24, 0)
	l.size = Vector2(440, 64)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(l)
	var x: = JButton.make("Отмена", "glass", Rect2(472, 8, 118, 48), null, 18)
	x.pressed.connect(func(): set_lupa(false))
	bar.add_child(x)
	UI.pop_in(bar, 0.0, 0.8)
	_lupa_bar = bar

# ── the bubble ──────────────────────────────────────────────────────────────────────────────────────────────────
func close_bubble() -> void:
	if bubble and is_instance_valid(bubble):
		var b: = bubble
		var t: = b.create_tween()
		t.tween_property(b, "modulate:a", 0.0, 0.12)
		t.tween_callback(b.queue_free)
	bubble = null

static func describe(b, t: Tile) -> Dictionary:
	var out: = {"title": "", "sub": "", "lines": [], "icon": "", "suit": -1, "num": 0, "status": "", "ok": true}
	var back: = t.back_spr != null and is_instance_valid(t.back_spr)
	var spec: Dictionary = {}
	if b and b.get("spec") is Dictionary and b.spec.has(t):
		spec = b.spec[t]
	var kind: String = String(spec.get("kind", ""))
	if back and t.ice > 0:
		out.title = "Рубашка"
		out.sub = "фишка лицом вниз"
		out.icon = "state:flip"
		out.lines.append(V10Glossary.why("state.flip"))
		out.lines.append("Картинка откроется после первого касания")
	elif back:
		out.title = "Тайная фишка"
		out.sub = "картинка спрятана"
		out.icon = "state:secret"
		out.lines.append(V10Glossary.why("state.secret"))
	elif t.shard != "":
		out.title = "Портрет: %s" % String(G.HEROES.get(t.shard, {}).get("name", t.shard))
		out.sub = "частичка героини"
		out.icon = "state:shard"
		out.lines.append("Пара — второй такой же портрет. %s" % V10Glossary.why("win.shard").split(".")[1].strip_edges())
	elif kind == "joker" or t.face == 300:
		out.title = "Джокер"
		out.sub = "любая пара"
		out.icon = "spec:joker"
		out.lines.append(V10Glossary.why("special.joker"))
	else:
		var c: = V10Glossary.suit_of(t.face)
		out.title = String(V7AlbumData.FACE_NAMES[t.face]) if t.face >= 0 and t.face < 36 else "Фишка"
		out.suit = c
		out.num = V10Glossary.face_index(t.face)
		out.icon = "tile:%d" % t.face
		if c >= 0:
			out.sub = "масть «%s» · №%d" % [V10Glossary.SUIT_LOOK[c].short, out.num]
		var left: = 0
		var in_tray: = 0
		if b:
			for o in b.tiles:
				if o != t and o.alive and o.face == t.face:
					if b.tray.has(o):
						in_tray += 1
					elif b.on_board(o):
						left += 1
		var pl: = "Пара — только такая же картинка «%s»." % out.title
		if in_tray > 0:
			pl += " Одна уже ждёт в лотке!"
		elif left > 0:
			pl += " Таких на столе ещё %d." % left
		out.lines.append(pl)
		if t.gold:
			out.lines.append("Золотая: пара даёт ×5 кристаллов")
	match kind:
		"gift":
			out.lines.append("С бантом: пара откроет подарок с призом")
		"key":
			out.lines.append("С ключом: пара откроет замки этого цвета")
		"lock":
			out.lines.append("Под замком: " + ("открыт, можно брать" if bool(spec.get("open", false)) else "нужна пара с ключом того же цвета"))
		"chain":
			out.lines.append("В цепи: спадёт через %d %s" % [int(spec.get("n", 0)), V8PlayRules.plural(int(spec.get("n", 0)), "пару", "пары", "пар")])
		"bomb":
			out.lines.append("Хлопушка: пара снесёт до 3 соседних пар")
	if b and b.tray.has(t):
		out.status = "Уже в лотке — ждёт пару"
	elif b and b.on_board(t):
		var why: = V10Glossary.blocked_reason(b, t)
		if why == "":
			out.status = "Свободна — можно брать" if not back or t.secret else "Свободна — тапни, чтобы перевернуть"
		else:
			out.status = why
			out.ok = false
	return out

func show_for(t: Tile) -> void:
	close_bubble()
	if play == null or not is_instance_valid(t):
		return
	var d: = describe(board, t)
	var W: float = play.size.x
	var w: = minf(560.0, W - 32.0)
	var f: = UI.font("body", 800)
	var tx: = 112.0
	var lh: = 0.0
	for ln in d.lines:
		lh += f.get_multiline_string_size(String(ln), HORIZONTAL_ALIGNMENT_LEFT, w - tx - 20, 18).y + 4.0
	var h: = maxf(148.0, 74.0 + lh + 40.0)
	var tp: Vector2 = t.get_global_transform_with_canvas().origin
	tp = play.get_global_transform_with_canvas().affine_inverse() * tp
	var th: = Tile.TH * float(board.scale.y if board else 1.0)
	var above: = tp.y - th * 0.5 - h - 14.0 > 120.0
	var y: = tp.y - th * 0.5 - h - 14.0 if above else tp.y + th * 0.5 + 14.0
	y = clampf(y, 110.0, play.size.y - h - 20.0)
	var x: = clampf(tp.x - w * 0.5, 16.0, W - w - 16.0)
	var bb: = UI.rbox("cream", Rect2(x, y, w, h), 24, 3, 8)
	bb.borders(Color("ffe7a6"), Color("c58a2c"))
	bb.z_index = 130
	bb.mouse_filter = Control.MOUSE_FILTER_STOP
	play.add_child(bb)
	# the pointer towards the tile
	var tail: = Polygon2D.new()
	var tx0: = clampf(tp.x - x, 40.0, w - 40.0)
	if above:
		tail.polygon = PackedVector2Array([Vector2(tx0 - 14, h - 2), Vector2(tx0 + 14, h - 2), Vector2(tx0, h + 14)])
	else:
		tail.polygon = PackedVector2Array([Vector2(tx0 - 14, 2), Vector2(tx0 + 14, 2), Vector2(tx0, -14)])
	tail.color = Color(0.13, 0.12, 0.14, 0.97)
	bb.add_child(tail)
	var ic: = V10ClarityIcon.make(String(d.icon), 92, Vector2(12, 14))
	bb.add_child(ic)
	var nm: = UI.title(String(d.title), 28, Color("ffe7a6"), Color("5a1a6a"))
	nm.position = Vector2(tx, 8)
	nm.size = Vector2(w - tx - 16, 38)
	nm.clip_text = true
	bb.add_child(nm)
	var sub: = UI.label(String(d.sub), 17, Color("cfc2b4"), UI.DARK, 2, "body", 800)
	sub.position = Vector2(tx, 44)
	sub.size = Vector2(w - tx - 16, 24)
	bb.add_child(sub)
	var yy: = 72.0
	for ln in d.lines:
		var l: = UI.label(String(ln), 18, UI.INK, UI.DARK, 2, "body", 800)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector2(tx, yy)
		l.size = Vector2(w - tx - 20, 20)
		bb.add_child(l)
		yy += f.get_multiline_string_size(String(ln), HORIZONTAL_ALIGNMENT_LEFT, w - tx - 20, 18).y + 4.0
	var stc: = Color("9fe8b0") if d.ok else Color("ffb0a8")
	var sl: = UI.label(String(d.status), 18, stc, UI.DARK, 3, "body", 900)
	sl.position = Vector2(tx, h - 36)
	sl.size = Vector2(w - tx - 20, 26)
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bb.add_child(sl)
	var all: = UI.label("Все фишки ›", 15, Color("ffd98a"), UI.DARK, 2, "body", 900)
	all.position = Vector2(12, 112)
	bb.add_child(all)
	bb.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and not e.is_echo():
			if Rect2(0, 104, 110, 40).has_point(e.position):
				close_bubble()
				V10Legend.open(play)
			else:
				close_bubble())
	bb.pivot_offset = Vector2(tx0, h if above else 0.0)
	UI.pop_in(bb, 0.0, 0.7)
	t.press_glint()
	Sfx.play("pop", 1.25, -6)
	V9Feel.haptic("select")
	bubble = bb
	var me: = bb
	get_tree().create_timer(7.0).timeout.connect(func():
		if bubble == me:
			close_bubble())
