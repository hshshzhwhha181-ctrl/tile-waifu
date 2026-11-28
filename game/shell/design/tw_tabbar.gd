class_name TWTabBar
extends Control

# TWTabBar (P28 / WP9b): the bottom navigation bar. HEIGHT 112 (+ bottom safe inset); n tabs share the 720 content column equally (each >= 96 wide
# for n <= 7); icon 48 + caption label; selected = gold icon + label + a short gold pip on the top hairline; optional "new" dot.
#   var tb := TWTabBar.make([{"id": "tea", "icon": "tab_tea", "label": "Чайная"}, ...]); tb.tab_selected.connect(func(id): ...)
#   tb.select("tea", false); tb.set_badge("shop", true)
#   TWTabBar.compute(vs, insets, n) -> {bar, items:[Rect2], cx, cw}    (pure)

signal tab_selected(id: String)

const HEIGHT: = 112.0
const ICON: = 48

var items: Array = []
var current: = ""
var viewport_override: = Vector2.ZERO
var _labels: Array[Label] = []
var _badges: Dictionary = {}
var _down: = -1


static func compute(vs: Vector2, insets: Dictionary, n: int) -> Dictionary:
	var B: = float(insets.bottom)
	var cw: = minf(vs.x, float(TWTokens.BASE_WIDTH))
	var cx: = floorf(maxf(0.0, (vs.x - cw) * 0.5))
	var rects: Array = []
	var iw: = floorf(cw / float(maxi(1, n)))
	for i in n:
		rects.append(Rect2(cx + iw * i, vs.y - B - HEIGHT, iw, HEIGHT))
	return {"bar": Rect2(0, vs.y - B - HEIGHT, vs.x, HEIGHT + B), "items": rects, "cx": cx, "cw": cw}


static func make(tabs: Array, selected: = "") -> TWTabBar:
	var t: = TWTabBar.new()
	t.set_items(tabs)
	if selected != "":
		t.select(selected, false)
	elif tabs.size() > 0:
		t.select(str(tabs[0].id), false)
	return t


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(TWSkin.GROUP)


func _ready() -> void:
	if get_viewport() and not get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.connect(_layout)
	_layout()


func _skin_changed() -> void:
	_layout()


func set_items(tabs: Array) -> void:
	for l in _labels:
		l.queue_free()
	_labels.clear()
	items = tabs.duplicate(true)
	for it in items:
		var l: = TWDraw.label(str(it.label), "ui", TWTokens.TYPE_CAPTION, TWTokens.PAPER_500)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(l)
		_labels.append(l)
	_layout()


func select(id: String, emit: = true) -> void:
	if id == current:
		return
	current = id
	_layout()
	if emit:
		tab_selected.emit(id)


func set_badge(id: String, on: bool) -> void:
	_badges[id] = on
	queue_redraw()


func geometry() -> Dictionary:
	var vs: = viewport_override
	if vs == Vector2.ZERO:
		vs = get_viewport_rect().size if is_inside_tree() else Vector2(TWTokens.BASE_WIDTH, 1280)
	return compute(vs, TWDraw.safe_insets(vs), items.size())


func _layout() -> void:
	var g: = geometry()
	var bar: Rect2 = g.bar
	position = bar.position
	size = bar.size
	var rects: Array = g.items
	for i in items.size():
		var r: Rect2 = rects[i]
		var l: = _labels[i]
		var on: bool = str(items[i].id) == current
		var iw: = r.size.x - float(TWTokens.S1)
		TWDraw.fit(l, str(items[i].label), "ui", [TWTokens.TYPE_CAPTION], iw, TWSkin.c("GOLD_300") if on else TWSkin.c("PAPER_500"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(iw, TWDraw.box_h("ui", TWTokens.TYPE_CAPTION))
		l.position = Vector2(r.position.x - bar.position.x + float(TWTokens.HALF), HEIGHT - l.size.y - float(TWTokens.S1))
	queue_redraw()


func _item_at(p: Vector2) -> int:
	var rects: Array = geometry().items
	for i in rects.size():
		var r: Rect2 = rects[i]
		var local: = Rect2(r.position - position, r.size)
		if local.has_point(p):
			return i
	return -1


func _draw() -> void:
	var g: = geometry()
	var rects: Array = g.items
	draw_rect(Rect2(Vector2.ZERO, size), Color(TWSkin.c("NIGHT_800"), 0.96))
	TWDraw.hairline(self, float(TWTokens.HAIR_INSET), size.x - float(TWTokens.HAIR_INSET), 0.5, Color(TWSkin.c("GOLD_700"), TWTokens.HAIR_A))
	for i in items.size():
		var r: Rect2 = rects[i]
		var lr: = Rect2(r.position - position, r.size)
		var on: bool = str(items[i].id) == current
		var col: = TWSkin.c("GOLD_300") if on else TWSkin.c("PAPER_500")
		if i == _down:
			draw_circle(lr.get_center() + Vector2(0, -12), 40.0, Color(TWSkin.c("NIGHT_600"), 0.55), true, -1.0, true)
		var c: = Vector2(lr.get_center().x, lr.position.y + float(TWTokens.S1) + ICON * 0.5)
		V10Icons.draw(self, str(items[i].icon), c, ICON, col)
		if on:
			TWDraw.hairline(self, lr.get_center().x - 28.0, lr.get_center().x + 28.0, 1.5, Color(TWSkin.c("GOLD_500"), 1.0))
		if _badges.get(str(items[i].id), false):
			draw_circle(c + Vector2(ICON * 0.5 - 2.0, -ICON * 0.5 + 6.0), 7.0, TWSkin.c("ROSE_300"), true, -1.0, true)


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
		var i: = _item_at(e.position)
		if e.pressed:
			_down = i
			queue_redraw()
		else:
			var was: = _down
			_down = -1
			queue_redraw()
			if i >= 0 and i == was:
				TWDraw.feedback(self, false)
				select(str(items[i].id), true)
		accept_event()
