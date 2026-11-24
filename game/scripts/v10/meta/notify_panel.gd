class_name V10NotifyPanel
extends Control

# V10NotifyPanel — Настройки → «Уведомления» (docs/0.10-spec.md M1 Ф1, the player part). A content block the
# integrator puts into Common.popup(main, "Уведомления", h):
#   · consent card: «Можно, героини иногда напишут тебе? Не чаще раза в 3 дня, никогда ночью (22:00–10:00), без цен»
#     with «Разрешить» and «Не сейчас» of EQUAL size and weight (no dark pattern);
#   · categories Дни рождения / Салон / Лента (on after consent) and «Возвращение» — OFF by default, its own switch;
#   · «Следующее уведомление не раньше: чт 18:30».
# In 0.10 nothing is posted (V10Notify only plans); 1.0 asks Android's POST_NOTIFICATIONS right after «Разрешить».
#
#   var p: = V10NotifyPanel.make(width); p.preferred_height(); signal changed

signal changed

const ASK: = "Можно, героини иногда напишут тебе? Не чаще раза в 3 дня, никогда ночью (22:00–10:00), без цен."
const CAT_SUB: = {"bday": "Её праздник и твой", "salon": "Когда хватает звёзд на уголок", "feed": "Новые снимки героинь",
	"comeback": "Если долго не заходишь. Выключено, пока не включишь"}

var w: = 0.0
var _h: = 0.0


static func make(width: float) -> V10NotifyPanel:
	var p: = V10NotifyPanel.new()
	p.w = width
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p._build()
	return p


func preferred_height() -> float:
	return _h


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var c: Dictionary = V10Meta.st().consent
	var y: = 0.0
	if not bool(c.push):
		var card: = UI.rbox("glass", Rect2(0, y, w, 230), 22, 3, 8)
		card.borders(Color(1, 0.88, 0.7, 0.5), Color(0.4, 0.2, 0.2, 0.6))
		add_child(card)
		card.add_child(V8Art.rect(V8Art.icon("letters"), Rect2(18, 18, 64, 64)))
		var t: = UI.label(ASK, 20, UI.INK, UI.DARK, 3, "body", 800)
		t.position = Vector2(96, 16)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		V10MetaUI.keep(t, Vector2(w - 112, 110))
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(t)
		var bw: = (w - 18 * 2 - 14) * 0.5
		# equal size, equal weight: both are glass/graphite secondary buttons — no bright «yes» vs a grey «no»
		var yes: = JButton.make("Разрешить", "glass", Rect2(18, 140, bw, 72), null, 26)
		var no: = JButton.make("Не сейчас", "glass", Rect2(18 + bw + 14, 140, bw, 72), null, 26)
		yes.name = "Allow"
		no.name = "NotNow"
		yes.pressed.connect(func():
			V10Notify.set_consent(true)
			V9Feel.success(null)
			_rebuild())
		no.pressed.connect(func():
			V10Notify.set_consent(false)
			_rebuild())
		card.add_child(yes)
		card.add_child(no)
		y += 230 + 16
	for cat in V10Notify.CATS:
		var row: = _cat_row(cat, Rect2(0, y, w, 76), bool(c.push))
		add_child(row)
		y += 76 + 10
	var nx: = UI.label(V10Notify.next_text(V10Meta.now_unix()) if bool(c.push) else "Уведомления выключены", 17,
		Color("e9c9a8"), UI.DARK, 2, "body", 800)
	nx.position = Vector2(4, y + 2)
	nx.size = Vector2(w - 8, 26)
	nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(nx)
	y += 32
	_h = y
	size = Vector2(w, _h)


func _ready() -> void:
	V10MetaUI.refit(self)


func _rebuild() -> void:
	_build.call_deferred()
	V10MetaUI.refit.call_deferred(self)
	changed.emit()


func _cat_row(cat: String, r: Rect2, consent: bool) -> Control:
	var on: = consent and V10Notify.cat_on(cat)
	var row: = UI.rbox("glass", r, 18, 2, 6)
	row.colors(Color(0.2, 0.16, 0.18, 0.9), Color(0.11, 0.08, 0.1, 0.92))
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var t: = UI.label(V10Notify.CAT_NAMES[cat], 21, UI.INK if consent else Color("8f8580"), UI.DARK, 3, "body", 900)
	t.position = Vector2(18, 8)
	t.size = Vector2(r.size.x - 140, 30)
	row.add_child(t)
	var s: = UI.label(CAT_SUB[cat], 15, Color("cdb8a8") if consent else Color("7a7270"), UI.DARK, 2, "body", 800)
	s.position = Vector2(18, 40)
	V10MetaUI.trim(s, Vector2(r.size.x - 140, 24))
	row.add_child(s)
	# the switch: a pill with a knob
	var sw: = UI.rbox("mint" if on else "glass", Rect2(r.size.x - 104, (r.size.y - 40) * 0.5, 86, 40), 20, 2, 4)
	if not on:
		sw.colors(Color(0.3, 0.27, 0.28, 0.95), Color(0.18, 0.16, 0.17, 0.95))
	row.add_child(sw)
	var knob: = UI.rbox("cream", Rect2(50 if on else 4, 4, 32, 32), 16, 2, 3)
	knob.colors(Color("fff6ea"), Color("d9cbbd"))
	sw.add_child(knob)
	row.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			if not consent:
				V9Feel.deny(row)
				return
			V9Feel.press(row)
			V10Notify.set_cat(cat, not V10Notify.cat_on(cat))
			_rebuild())
	return row
