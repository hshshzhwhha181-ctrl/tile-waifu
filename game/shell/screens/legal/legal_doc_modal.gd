class_name TWLegalDocModal
extends TWModal

# TWLegalDocModal (P108): modal legal document reader opened exclusively via ModalStack.open().
# Uses TWSheet + TWButton + TWTokens (zero raw hex, zero raw font sizes, <= 3 font sizes, buttons >= 96 px).

var doc_id: String = ""
var doc_title: String = ""
var doc_version: String = ""
var doc_text: String = ""
var show_accept_btn: bool = false

var _sheet: TWSheet = null
var _meta_lbl: Label = null
var _body_lbl: Label = null
var _scroll: ScrollContainer = null
var _btn_close: TWButton = null
var _btn_accept: TWButton = null


static func make(p_id: String, p_title: String, p_version: String, p_text: String, p_allow_accept: bool = false) -> TWLegalDocModal:
	var m: TWLegalDocModal = TWLegalDocModal.new()
	m.doc_id = p_id
	m.doc_title = p_title
	m.doc_version = p_version
	m.doc_text = p_text
	m.show_accept_btn = p_allow_accept
	return m


func _build(opts: Dictionary) -> void:
	if opts.has("id"):
		doc_id = str(opts.get("id", doc_id))
	if opts.has("title"):
		doc_title = str(opts.get("title", doc_title))
	if opts.has("version"):
		doc_version = str(opts.get("version", doc_version))
	if opts.has("text"):
		doc_text = str(opts.get("text", doc_text))
	if opts.has("allow_accept"):
		show_accept_btn = bool(opts.get("allow_accept", show_accept_btn))

	var vs: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(TWTokens.BASE_WIDTH, 1280)
	var content_h: float = minf(840.0, maxf(440.0, vs.y * 0.68))
	_sheet = TWSheet.make(doc_title if doc_title != "" else "Документ", content_h)
	_sheet.closable = true
	_sheet.closed.connect(func() -> void:
		if is_open():
			close({"id": doc_id, "accepted": false}, "sheet_close")
	)
	add_child(_sheet)
	_sheet.open(vs)
	_sheet.advance(TWSheet.T_OPEN)

	var body: Control = _sheet.body
	var bw: float = maxf(320.0, body.size.x)
	var bh: float = maxf(320.0, body.size.y)

	_meta_lbl = TWDraw.label(
		"Версия: %s  ·  %s" % [doc_version, TWLegalData.REQUIRED_DISCLAIMER],
		"ui",
		TWTokens.TYPE_CAPTION,
		TWSkin.c("GOLD_300")
	)
	_meta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta_lbl.position = Vector2(0.0, 0.0)
	_meta_lbl.size = Vector2(bw, float(TWTokens.S8))
	body.add_child(_meta_lbl)

	var footer_h: float = float(TWTokens.HIT_TARGET_MIN) + float(TWTokens.S2)
	var scroll_y: float = float(TWTokens.S8) + float(TWTokens.S1)
	var scroll_h: float = maxf(160.0, bh - scroll_y - footer_h)

	_scroll = ScrollContainer.new()
	_scroll.name = "DocScroll"
	_scroll.position = Vector2(0.0, scroll_y)
	_scroll.size = Vector2(bw, scroll_h)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(bw - float(TWTokens.S2), 0.0)
	_scroll.add_child(box)

	_body_lbl = TWDraw.label(doc_text, "ui", TWTokens.TYPE_CAPTION, TWSkin.c("PAPER_100"))
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_body_lbl)

	var btn_y: float = scroll_y + scroll_h + float(TWTokens.S2)
	var btn_h: float = float(TWTokens.HIT_TARGET_MIN)
	if show_accept_btn:
		var half_w: float = floorf((bw - float(TWTokens.S2)) * 0.5)
		_btn_close = TWButton.make("secondary", "Закрыть", Vector2(half_w, btn_h))
		_btn_close.position = Vector2(0.0, btn_y)
		_btn_close.pressed.connect(func() -> void:
			close({"id": doc_id, "accepted": false}, "dismiss")
		)
		body.add_child(_btn_close)

		_btn_accept = TWButton.make("play", "Принять", Vector2(half_w, btn_h))
		_btn_accept.position = Vector2(half_w + float(TWTokens.S2), btn_y)
		_btn_accept.pressed.connect(func() -> void:
			close({"id": doc_id, "accepted": true}, "accept")
		)
		body.add_child(_btn_accept)
	else:
		_btn_close = TWButton.make("secondary", "Закрыть", Vector2(bw, btn_h))
		_btn_close.position = Vector2(0.0, btn_y)
		_btn_close.pressed.connect(func() -> void:
			close({"id": doc_id, "accepted": false}, "dismiss")
		)
		body.add_child(_btn_close)


func displayed_text() -> String:
	return _body_lbl.text if _body_lbl != null else doc_text


func accept_from_code() -> bool:
	return close({"id": doc_id, "accepted": true}, "accept")
