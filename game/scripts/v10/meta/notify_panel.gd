class_name V10NotifyPanel
extends Control

# V10NotifyPanel — Настройки → «Уведомления» (docs/0.10-spec.md M1 Ф1, the player part). A GROUP of the Settings
# sheet (UX_RULES §3.2: «⚙ Настройки (2): Доступность · Звук · Картинка · Уведомления …»): the integrator puts it
# INTO the settings sheet under the caption «Уведомления» — never as a popup over the settings popup (UX §3.7:
# no window over a window; depth stays 2):
#   · consent card: «Можно, героини иногда напишут тебе? Не чаще раза в 3 дня, никогда ночью (22:00–10:00), без цен»
#     with «Разрешить» and «Не сейчас» of EQUAL size and look (no dark pattern). ux_role: «Разрешить» primary,
#     «Не сейчас» secondary — the roles mark the hierarchy for the audit, the look stays equal (spec Ф1);
#   · categories Дни рождения / Салон / Лента (on after consent) and «Возвращение» — OFF by default, its own switch;
#     rows are HUD_V2 M plates 80 px (the whole row is the switch's hit zone);
#   · «Следующее уведомление не раньше: чт 18:30».
# In 0.10 nothing is posted (V10Notify only plans); 1.0 asks Android's POST_NOTIFICATIONS right after «Разрешить».
#
#   var p: = V10NotifyPanel.make(width); p.preferred_height(); signal changed

signal changed

const ASK: = "Можно, героини иногда напишут тебе? Не чаще раза в 3 дня, никогда ночью (22:00–10:00), без цен."
const CAT_SUB: = {"bday": "Её праздник и твой", "salon": "Когда хватает звёзд на уголок", "feed": "Новые снимки героинь",
	"comeback": "Если долго не заходишь. Выключено, пока не включишь"}
const ROW_H: = 80.0
const BTN_H: = 80.0
const GAP: = 8.0

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
		remove_child(c)
		c.queue_free()
	var c: Dictionary = V10Meta.st().consent
	var y: = 0.0
	if not bool(c.push):
		var pad: = 16.0
		var tx: = pad + 56.0 + 16.0
		var tw: = w - tx - pad
		var f: = UI.font("body", 800)
		var th: = f.get_multiline_string_size(ASK, HORIZONTAL_ALIGNMENT_LEFT, tw, V10MetaUI.FS_BODY).y + 4.0
		th = maxf(th, 56.0)
		var ch: = pad + th + 16.0 + BTN_H + pad
		var card: = V10MetaUI.plate(Rect2(0, y, w, ch), V10MetaUI.NIGHT_700, 1.0)
		card.name = "Consent"
		add_child(card)
		card.add_child(V8Art.rect(V8Art.icon("letters"), Rect2(pad, pad, 56, 56)))
		var t: = V10MetaUI.text(ASK, V10MetaUI.FS_BODY, V10MetaUI.PAPER_100, "body", 800)
		t.position = Vector2(tx, pad)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		V10MetaUI.keep(t, Vector2(tw, th))
		card.add_child(t)
		var bw: = (w - pad * 2 - 16) * 0.5
		# equal size, equal look: both are the same quiet glass buttons — no bright «yes» next to a grey «no»
		var by: = pad + th + 16.0
		var yes: = JButton.make("Разрешить", "glass", Rect2(pad, by, bw, BTN_H), null, V10MetaUI.FS_BODY)
		var no: = JButton.make("Не сейчас", "glass", Rect2(pad + bw + 16, by, bw, BTN_H), null, V10MetaUI.FS_BODY)
		yes.name = "Allow"
		no.name = "NotNow"
		V10MetaUI.role(yes, "primary")
		V10MetaUI.role(no, "secondary")
		yes.pressed.connect(func():
			V10Notify.set_consent(true)
			V9Feel.success(null)
			_rebuild())
		no.pressed.connect(func():
			V10Notify.set_consent(false)
			_rebuild())
		card.add_child(yes)
		card.add_child(no)
		y += ch + 16.0
	for cat in V10Notify.CATS:
		var row: = _cat_row(cat, Rect2(0, y, w, ROW_H), bool(c.push))
		add_child(row)
		y += ROW_H + GAP
	var nx: = V10MetaUI.text(V10Notify.next_text(V10Meta.now_unix()) if bool(c.push) else "Уведомления выключены",
		V10MetaUI.FS_CAPTION, V10MetaUI.PAPER_300, "body", 800)
	nx.name = "Next"
	nx.position = Vector2(0, y + 4)
	nx.size = Vector2(w, 26)
	add_child(nx)
	y += 34.0
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
	var row: = V10MetaUI.plate(r)
	row.name = "Cat_" + cat
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.pivot_offset = r.size * 0.5
	var tw: = r.size.x - 24 - 120
	var t: = V10MetaUI.text(V10Notify.CAT_NAMES[cat], V10MetaUI.FS_BODY, V10MetaUI.PAPER_100 if consent else V10MetaUI.PAPER_500,
		"body", 800)
	t.position = Vector2(24, 8)
	V10MetaUI.trim(t, Vector2(tw, 32))
	row.add_child(t)
	var s: = V10MetaUI.text(CAT_SUB[cat], V10MetaUI.FS_CAPTION, V10MetaUI.PAPER_500,
		"body", 700)
	s.position = Vector2(24, 42)
	V10MetaUI.trim(s, Vector2(tw, 28))
	row.add_child(s)
	# the switch: a jade track with a paper knob (on) or a night track (off) — the whole row is its hit zone
	var sw: = Panel.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = V10MetaUI.JADE_500 if on else V10MetaUI.NIGHT_600
	sb.set_corner_radius_all(20)
	sw.add_theme_stylebox_override("panel", sb)
	sw.position = Vector2(r.size.x - 24 - 76, (r.size.y - 40) * 0.5)
	sw.size = Vector2(76, 40)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sw)
	var knob: = Panel.new()
	var kb: = StyleBoxFlat.new()
	kb.bg_color = V10MetaUI.PAPER_100 if on else V10MetaUI.PAPER_500
	kb.set_corner_radius_all(16)
	knob.add_theme_stylebox_override("panel", kb)
	knob.position = Vector2(40 if on else 4, 4)
	knob.size = Vector2(32, 32)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.add_child(knob)
	row.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			if not consent:
				# before consent the switches are dimmed: a tap answers with the deny feedback, the card above says why
				V9Feel.deny(row)
				return
			V9Feel.press(row)
			V10Notify.set_cat(cat, not V10Notify.cat_on(cat))
			_rebuild())
	return row
