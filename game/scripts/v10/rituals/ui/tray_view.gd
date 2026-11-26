class_name V10TrayView
extends Control

# «Утренний поднос» overlay (Р4, UX_RULES §3.4: main «Забрать всё», nothing else). It rises in the lower third
# (lacquer, 600 ms EXPO), the cards breathe in; «Забрать всё» stamps each card with the hanko (120 ms apart), the
# rewards fly into the counters as a pentatonic cascade, then the tray slides away. The scene behind stays visible.
#   V10TrayView.open(parent, cards = V10Tray.collect(), targets = {kind: global Vector2}) -> V10TrayView | null
#   signal finished(results)       results = V10Tray.claim_all() rows

signal finished(results: Array)

const TRAY_W: = 680.0

var cards: Array = []
var targets: = {}
var _tray: Control
var _btn: Button
var _cards_nodes: = []
var _busy: = false
var claim_fn: Callable = Callable()   # selftest / runner may replace V10Tray.claim_all


static func open(parent: Control, cards_in: = [], targets_in: = {}) -> V10TrayView:
	var cs: Array = cards_in if not cards_in.is_empty() else V10Tray.collect()
	if cs.is_empty():
		return null
	var v: = V10TrayView.new()
	v.cards = cs
	v.targets = targets_in
	v.size = parent.size
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_meta("popup", true)
	parent.add_child(v)
	return v


func _ready() -> void:
	var W: = size.x
	var H: = size.y
	var shade: = V10RitUI.grad(Rect2(0, H * 0.42, W, H * 0.58), Color(V10RitUI.NIGHT900, 0.0), Color(V10RitUI.NIGHT900, 0.86))
	add_child(shade)
	shade.modulate.a = 0.0
	create_tween().tween_property(shade, "modulate:a", 1.0, 0.4)
	var th: = TRAY_W * 588.0 / 1024.0
	_tray = Control.new()
	_tray.size = Vector2(TRAY_W, th + 140)
	var rest_y: = H - _tray.size.y - 28
	_tray.position = Vector2((W - TRAY_W) * 0.5, H + 20)
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tray)
	var img: = V10RitUI.tex(V10RitUI.ART + "tray.webp", Rect2(0, 0, TRAY_W, th))
	_tray.add_child(img)
	var over: = V10RitUI.label("Утренний поднос", 15, V10RitUI.GOLD500, "over")
	over.position = Vector2(40, -30)
	_tray.add_child(over)
	# cards on the lacquer (perspective: the tray surface is ~ y 14%..80% of the image)
	var n: = cards.size()
	var cw: = minf(136.0, (TRAY_W - 160) / maxf(1, n) - 16)
	var chh: = minf(cw * 1.3, th * 0.66)
	var total: = n * cw + (n - 1) * 16
	var x0: = (TRAY_W - total) * 0.5
	for i in n:
		var c: = _card(cards[i], cw, chh)
		c.position = Vector2(x0 + i * (cw + 16), th * 0.5 - chh * 0.5)
		c.rotation = deg_to_rad((i - (n - 1) * 0.5) * 2.2)
		_tray.add_child(c)
		_cards_nodes.append(c)
	_btn = V10RitUI.button("Забрать всё", Rect2((TRAY_W - 560) * 0.5, th + 12, 560, 104), "primary", _claim)
	_tray.add_child(_btn)
	var dur: = 0.6 if V9Feel.can_fx() else 0.12
	var t: = _tray.create_tween()
	t.tween_property(_tray, "position:y", rest_y, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	V10RitUI.inhale(_cards_nodes, dur * 0.6)
	V10RitUI.sfx("paper_fan", "whoosh", 0.9, -10.0)


func _card(c: Dictionary, w: float, h: float) -> Control:
	var box: = Control.new()
	box.size = Vector2(w, h)
	box.clip_contents = true
	box.pivot_offset = box.size * 0.5
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(V10RitUI.panel(Rect2(Vector2.ZERO, box.size), Color(V10RitUI.NIGHT800, 0.94), 12, Color(V10RitUI.GOLD700, 0.7), 2))
	var icon = c.get("icon", "")
	var ic_sz: = minf(w * 0.50, 74.0)
	var ic: TextureRect
	if icon is Texture2D:
		ic = V10RitUI.tex("", Rect2((w - ic_sz) * 0.5, 10, ic_sz, ic_sz))
		ic.texture = icon
	else:
		ic = V10RitUI.tex(str(icon), Rect2((w - ic_sz) * 0.5, 10, ic_sz, ic_sz))
	box.add_child(ic)
	var tl: = V10RitUI.wrap_w(V10RitUI.label(str(c.get("title", "")), 16, V10RitUI.PAPER100, "body", 800), w - 12)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.position = Vector2(6, 12 + ic_sz)
	box.add_child(tl)
	var tx: = V10RitUI.wrap_w(V10RitUI.label(str(c.get("text", "")), 16, V10RitUI.GOLD300, "body", 800), w - 12)
	tx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tx.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tx.size = Vector2(w - 12, 46)
	tx.position = Vector2(6, h - 52)
	box.add_child(tx)
	return box


func _claim() -> void:
	if _busy:
		return
	_busy = true
	_btn.disabled = true
	var results: Array = claim_fn.call() if claim_fn.is_valid() else V10Tray.claim_all()
	var t: = create_tween()
	for i in _cards_nodes.size():
		var node: Control = _cards_nodes[i]
		t.tween_callback(func():
			V10RitUI.hanko(node, Vector2(node.size.x - 22, 24), "受", 40)
			V9Feel.success(node, "", 0.6))
		t.tween_interval(0.12)
	t.tween_interval(0.25)
	t.tween_callback(func():
		var rows: = []
		for r in results:
			rows.append_array(r.get("rows", []))
		var dt: = 0.0
		if not rows.is_empty():
			var tgt: Vector2 = targets.get("default", Vector2(size.x * 0.5, 40))
			dt = V10RitUI.cascade(self, rows, Vector2(size.x * 0.5, _tray.position.y - 70), tgt, func(row):
				var p = targets.get(str(row.kind), null)
				if p is Control:
					V9Feel.success(p, "", 0.5))
		var t2: = create_tween()
		t2.tween_interval(dt + 0.1)
		t2.tween_property(_tray, "position:y", size.y + 40, 0.42).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		t2.parallel().tween_property(self, "modulate:a", 0.0, 0.42).set_delay(0.2)
		t2.tween_callback(func():
			finished.emit(results)
			queue_free()))
