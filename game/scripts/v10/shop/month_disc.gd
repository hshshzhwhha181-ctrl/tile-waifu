class_name V10MonthDisc
extends Control

# V10MonthDisc — the lunar disc of «Лунный абонемент» (spec 0.10 Л4) for the home screen / morning tray. Visible only
# while the card is active. The ring is the share of days left (≤ 180). The label is «+90» while today's crystals
# wait (they are taken in the morning tray: econ.shop.month_claim()), else the end date «до 12 дек» — a date, never a
# countdown (UX §4.1.7). No price on the home screen (С-7).
# On Чайная the disc is DECORATION ONLY (UX §3.3: «7 тапаемых, главная не растёт»; §3.6.4: «у Чайной точки нет
# никогда»): no tap, no dot. `tappable = true` (+ the dot) is for a host that is not the home, e.g. the tray itself.

signal claimed(grant: Dictionary)

var m: V10ShopModel
var tappable: = false
var _t: Texture2D
var _lbl: Label


static func make(model: V10ShopModel, can_tap: = false) -> V10MonthDisc:
	var d: = V10MonthDisc.new()
	d.m = model
	d.tappable = can_tap
	d.name = "V10MonthDisc"
	d.size = Vector2(112, 136)
	d.custom_minimum_size = d.size
	return d


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if tappable else Control.MOUSE_FILTER_IGNORE
	if tappable:
		set_meta("v10_tap", true)
		set_meta("ux_role", "secondary")
	_t = V10ShopKit.tex("item_month")
	_lbl = V10ShopKit.lbl("", "ui", 18, V10DS.PAPER_300, true)
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.position = Vector2(-24, 108)
	_lbl.size = Vector2(160, 26)
	add_child(_lbl)
	refresh()


func refresh() -> void:
	var dl: = m.econ.shop.month_days_left()
	visible = dl > 0
	if dl <= 0:
		return
	if m.econ.shop.month_can_claim():
		_lbl.text = "+%s" % V10ShopTxt.num(int(V10Catalog.MONTH_DAILY.crystal))
		_lbl.label_settings = V10Type.settings("ui", 18, V10DS.GOLD_300, true)
	else:
		_lbl.text = "до " + V10ShopTxt.date_short(m.now() + (dl - 1) * 86400)
		_lbl.label_settings = V10Type.settings("ui", 18, V10DS.PAPER_300, true)
	queue_redraw()


var _down: = false


func _gui_input(e: InputEvent) -> void:
	if not tappable:
		return
	if ((e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch) and e.pressed:
		_down = true      # touch + emulated mouse come in pairs: one press arms, the first release fires
		accept_event()
		return
	if ((e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch) and not e.pressed and _down:
		_down = false
		if m.econ.shop.month_can_claim():
			var g: = m.econ.shop.month_claim()
			V10ShopKit.press(self, true)
			claimed.emit(g)
			var host: = get_parent() as Control
			if host:
				V10ShopKit.fly(host, position + size * 0.5, position + Vector2(size.x * 0.5, -40), V10ShopKit.tex("item_crystal"), 4)
				V10ShopKit.toast(host, "Зачислено: %s · баланс %s" % [V10ShopTxt.amount("crystal", int(g.get("crystal", 0))), V10ShopTxt.num(m.bal("crystal"))])
		else:
			V10ShopKit.press(self)
		refresh()
		accept_event()


func _draw() -> void:
	var c: = Vector2(56, 56)
	draw_circle(c, 52, Color(V10DS.NIGHT_900, 0.6), true, -1.0, true)
	if _t:
		draw_texture_rect(_t, Rect2(c - Vector2(44, 44), Vector2(88, 88)), false)
	var k: = clampf(float(m.econ.shop.month_days_left()) / float(V10Catalog.MONTH_DAYS), 0.0, 1.0)
	draw_arc(c, 52, -PI * 0.5, -PI * 0.5 + TAU * k, 48, V10DS.GOLD_500, 2.5, true)
	if tappable and m.econ.shop.month_can_claim():
		draw_circle(c + Vector2(38, -38), 6, V10DS.ROSE_300, true, -1.0, true)   # «есть что забрать» (never «купи»), not on Чайная
