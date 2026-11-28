class_name TWLegalScreen
extends TWScreen

# TWLegalScreen (P108 / MP PM21): Legal Hub screen for Tile Waifu.
# Displays all 13 Russian legal template documents from res://data/legal/, validates bundle integrity at runtime
# (failing closed if tampered), opens any document (inline reader or via ModalStack), and manages the unified
# consent journal (TWLegalConsent -> TWConsent, SAVE_VER remains 8) with separate explicit acts for:
#   1. Offer & Privacy Policy (requires both opened)
#   2. 152-FZ PDn consent (separate explicit act, requires pdn_consent opened)
#   3. 18+ confirmation (requires age_18_full_tier opened AND adult TWAge)
#   4. Separate voluntary Analytics toggle
#
# params:
#   "data_dir": String   optional override path for legal bundle (tests)
#   "doc_id": String     optional document id to open immediately upon entering
#   "mode": String       "list" (default) | "journal"
#   "age_gate": TWAge    optional TWAge instance (defaults to ctx.service("age") or TWAge on ctx.state)
#
# Token/lint compliance:
#   - 0 raw hex / Color(r,g,b), 0 raw font sizes, <= 3 TWTokens.TYPE_* sizes (TYPE_H2, TYPE_BODY, TYPE_CAPTION)
#   - 0 res://assets/ literals, 0 .overlay accesses, 0 hardcoded currency/percent literals.

signal doc_opened(doc_id: String)
signal consent_updated(offer_ver: String)

enum ViewMode { LIST, READER, JOURNAL }

var legal_data: TWLegalData = null
var consent_journal: TWLegalConsent = null
var age_gate: TWAge = null
var view_mode: int = ViewMode.LIST
var active_doc_id: String = ""

var _opened_docs: Dictionary = {}
var _header: TWHeader = null
var _content_root: Control = null
var _list_view: Control = null
var _reader_view: Control = null
var _journal_view: Control = null
var _status_lbl: Label = null
var _disclaimer_lbl: Label = null
var _doc_plates: Dictionary = {}
var _reader_title_lbl: Label = null
var _reader_meta_lbl: Label = null
var _reader_text_lbl: Label = null
var _journal_text_lbl: Label = null
var _accept_offer_btn: TWButton = null
var _accept_pdn_btn: TWButton = null
var _accept_age_btn: TWButton = null
var _analytics_btn: TWButton = null
var _journal_btn: TWButton = null


func enter(p: Dictionary) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_opened_docs.clear()
	var dir_override: String = str(p.get("data_dir", ""))
	legal_data = TWLegalData.new(dir_override)
	# Explicitly enforce bundle validation at runtime before displaying or consenting.
	legal_data.validate_bundle()

	var st: TWState = ctx.state if ctx != null else null
	var clk: TWClock = ctx.clock if ctx != null else null
	var bus: TWBus = ctx.bus if ctx != null else null
	consent_journal = TWLegalConsent.new(st, clk, bus)

	var p_age: Variant = p.get("age_gate", null)
	if p_age is TWAge:
		age_gate = p_age as TWAge
	elif ctx != null and ctx.service("age") is TWAge:
		age_gate = ctx.service("age") as TWAge
	else:
		age_gate = TWAge.new(clk, st)

	_build_chrome()
	_build_views()
	_layout()
	resized.connect(_layout)

	var initial_doc: String = str(p.get("doc_id", ""))
	var initial_mode: String = str(p.get("mode", "list"))
	if initial_doc != "" and legal_data.is_valid() and legal_data.has_doc(initial_doc):
		open_doc(initial_doc, false)
	elif initial_mode == "journal":
		open_journal()
	else:
		show_list()


func exit() -> void:
	_doc_plates.clear()


func on_back() -> bool:
	if view_mode != ViewMode.LIST:
		show_list()
		return true
	return false


func _on_header_back() -> void:
	if on_back():
		return
	if ctx != null and ctx.screens != null:
		ctx.screens.back()


func _build_chrome() -> void:
	_header = TWHeader.make(self, "Правовая информация", _on_header_back)
	_content_root = Control.new()
	_content_root.name = "LegalContent"
	_content_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_content_root)


func _build_views() -> void:
	_build_list_view()
	_build_reader_view()
	_build_journal_view()


func _build_list_view() -> void:
	_list_view = Control.new()
	_list_view.name = "ListView"
	_list_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_root.add_child(_list_view)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_view.add_child(scroll)

	var col: VBoxContainer = VBoxContainer.new()
	col.name = "ListCol"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", TWTokens.S2)
	scroll.add_child(col)

	_disclaimer_lbl = TWDraw.label(
		"Внимание: все документы ниже — %s." % legal_data.disclaimer_text(),
		"ui",
		TWTokens.TYPE_CAPTION,
		TWSkin.c("GOLD_300")
	)
	_disclaimer_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_disclaimer_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_disclaimer_lbl)

	_status_lbl = TWDraw.label("", "ui", TWTokens.TYPE_BODY, TWSkin.c("PAPER_100"))
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_status_lbl)

	# Separate explicit consent buttons (152-FZ compliant: no one-tap bundling of PDn or 18+)
	var row_core: HBoxContainer = HBoxContainer.new()
	row_core.add_theme_constant_override("separation", TWTokens.S2)
	col.add_child(row_core)

	_accept_offer_btn = TWButton.make("play", "Оферта и Политика", Vector2(328, TWTokens.HIT_TARGET_MIN))
	_accept_offer_btn.pressed.connect(func() -> void: accept_offer_and_privacy())
	row_core.add_child(_accept_offer_btn)

	_accept_pdn_btn = TWButton.make("secondary", "Согласие на ПДн", Vector2(328, TWTokens.HIT_TARGET_MIN))
	_accept_pdn_btn.pressed.connect(func() -> void: accept_pdn_consent())
	row_core.add_child(_accept_pdn_btn)

	var row_age: HBoxContainer = HBoxContainer.new()
	row_age.add_theme_constant_override("separation", TWTokens.S2)
	col.add_child(row_age)

	_accept_age_btn = TWButton.make("secondary", "Подтвердить 18+", Vector2(328, TWTokens.HIT_TARGET_MIN))
	_accept_age_btn.pressed.connect(func() -> void: accept_age_18())
	row_age.add_child(_accept_age_btn)

	_analytics_btn = TWButton.make("secondary", "Аналитика: выкл", Vector2(328, TWTokens.HIT_TARGET_MIN))
	_analytics_btn.pressed.connect(func() -> void: toggle_analytics())
	row_age.add_child(_analytics_btn)

	_journal_btn = TWButton.make("secondary", "Журнал согласий", Vector2(672, TWTokens.HIT_TARGET_MIN))
	_journal_btn.pressed.connect(open_journal)
	col.add_child(_journal_btn)

	_doc_plates.clear()
	if legal_data.is_valid():
		for d in legal_data.list_docs():
			var did: String = str(d.get("id", ""))
			var num_prefix: String = "%d. %s" % [int(d.get("order", 0)), str(d.get("short_title", d.get("title", did)))]
			var sub: String = "%s · вер. %s" % [str(d.get("title", "")), str(d.get("version", ""))]
			var plate: TWPlate = TWPlate.make("M", 672, num_prefix, sub, "Открыть")
			plate.interactive = true
			plate.pressed.connect(func() -> void: open_doc(did, true))
			col.add_child(plate)
			_doc_plates[did] = plate

	_refresh_status()


func _build_reader_view() -> void:
	_reader_view = Control.new()
	_reader_view.name = "ReaderView"
	_reader_view.visible = false
	_reader_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_root.add_child(_reader_view)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "ReaderBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", TWTokens.S2)
	_reader_view.add_child(vbox)

	_reader_title_lbl = TWDraw.label("", "display", TWTokens.TYPE_H2, TWSkin.c("PAPER_100"))
	_reader_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reader_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_reader_title_lbl)

	_reader_meta_lbl = TWDraw.label("", "ui", TWTokens.TYPE_CAPTION, TWSkin.c("GOLD_300"))
	_reader_meta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reader_meta_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_reader_meta_lbl)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ReaderScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var text_col: VBoxContainer = VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text_col)

	_reader_text_lbl = TWDraw.label("", "ui", TWTokens.TYPE_CAPTION, TWSkin.c("PAPER_100"))
	_reader_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reader_text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_child(_reader_text_lbl)

	var back_btn: TWButton = TWButton.make("secondary", "К списку документов", Vector2(672, TWTokens.HIT_TARGET_MIN))
	back_btn.pressed.connect(show_list)
	vbox.add_child(back_btn)


func _build_journal_view() -> void:
	_journal_view = Control.new()
	_journal_view.name = "JournalView"
	_journal_view.visible = false
	_journal_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_root.add_child(_journal_view)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "JournalBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", TWTokens.S2)
	_journal_view.add_child(vbox)

	var jtitle: Label = TWDraw.label("Журнал согласий", "display", TWTokens.TYPE_H2, TWSkin.c("PAPER_100"))
	jtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(jtitle)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "JournalScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var text_col: VBoxContainer = VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text_col)

	_journal_text_lbl = TWDraw.label("", "ui", TWTokens.TYPE_CAPTION, TWSkin.c("PAPER_100"))
	_journal_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_journal_text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_child(_journal_text_lbl)

	var back_btn: TWButton = TWButton.make("secondary", "К списку документов", Vector2(672, TWTokens.HIT_TARGET_MIN))
	back_btn.pressed.connect(show_list)
	vbox.add_child(back_btn)


func _layout() -> void:
	var vs: Vector2 = size if size.x > 0.0 and size.y > 0.0 else Vector2(TWTokens.BASE_WIDTH, 1280)
	var ins: Dictionary = TWDraw.safe_insets(vs)
	var cw: float = minf(vs.x, float(TWTokens.BASE_WIDTH)) - float(TWTokens.SAFE_MARGIN) * 2.0
	var cx: float = floorf((vs.x - cw) * 0.5)
	var top_y: float = TWHeader.content_y(vs, ins)
	var bot_pad: float = maxf(float(TWTokens.SAFE_MARGIN), float(ins.bottom) + float(TWTokens.S2))
	if _content_root != null:
		_content_root.position = Vector2(cx, top_y)
		_content_root.size = Vector2(cw, maxf(200.0, vs.y - top_y - bot_pad))
	for v in [_list_view, _reader_view, _journal_view]:
		if v != null:
			v.position = Vector2.ZERO
			v.size = _content_root.size
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var pts: PackedVector2Array = PackedVector2Array([
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y),
	])
	var top_c: Color = TWSkin.c("NIGHT_800")
	var bot_c: Color = TWSkin.c("NIGHT_900")
	draw_polygon(pts, PackedColorArray([top_c, top_c, bot_c, bot_c]))


# ---- public screen API ------------------------------------------------------------------------------------

func has_opened_doc(doc_id: String) -> bool:
	return bool(_opened_docs.get(doc_id, false))


func show_list() -> void:
	view_mode = ViewMode.LIST
	active_doc_id = ""
	if _header != null:
		_header.set_title("Правовая информация")
	_list_view.visible = true
	_reader_view.visible = false
	_journal_view.visible = false
	_refresh_status()


func open_doc(doc_id: String, prefer_modal: bool = false) -> bool:
	if legal_data == null or not legal_data.is_valid() or not legal_data.has_doc(doc_id):
		return false
	var meta: Dictionary = legal_data.find_doc(doc_id)
	var txt: String = legal_data.read_doc_text(doc_id)
	if txt == "":
		return false
	active_doc_id = doc_id
	_opened_docs[doc_id] = true
	if prefer_modal and ctx != null:
		var ms: Object = ctx.service("modals")
		if ms is ModalStack:
			var allow_accept: bool = bool(meta.get("required_for_consent", false))
			if TWConsent.normalize_kind(doc_id) == TWConsent.KIND_AGE_18:
				allow_accept = allow_accept and age_gate != null and age_gate.is_adult()
			var modal: TWLegalDocModal = TWLegalDocModal.make(
				doc_id,
				str(meta.get("short_title", meta.get("title", doc_id))),
				str(meta.get("version", "")),
				txt,
				allow_accept
			)
			modal.on_close = func(res: Variant, _reason: String) -> void:
				if res is Dictionary and bool((res as Dictionary).get("accepted", false)):
					accept_single_doc(doc_id)
			(ms as ModalStack).open(modal)
			doc_opened.emit(doc_id)
			return true

	view_mode = ViewMode.READER
	if _header != null:
		_header.set_title(str(meta.get("short_title", meta.get("title", "Документ"))))
	_reader_title_lbl.text = str(meta.get("title", ""))
	_reader_meta_lbl.text = "Версия: %s · Оферта: %s · %s" % [
		str(meta.get("version", "")),
		legal_data.offer_version(),
		legal_data.disclaimer_text(),
	]
	_reader_text_lbl.text = txt
	_list_view.visible = false
	_reader_view.visible = true
	_journal_view.visible = false
	doc_opened.emit(doc_id)
	return true


func open_journal() -> void:
	view_mode = ViewMode.JOURNAL
	if _header != null:
		_header.set_title("Журнал согласий")
	_journal_text_lbl.text = consent_journal.export_text() if consent_journal != null else ""
	_list_view.visible = false
	_reader_view.visible = false
	_journal_view.visible = true


func accept_offer_and_privacy() -> Array:
	if consent_journal == null or legal_data == null or not legal_data.is_valid():
		return []
	var res: Array = consent_journal.record_offer_and_privacy(legal_data, _opened_docs, "legal_screen")
	if not res.is_empty():
		_refresh_status()
		consent_updated.emit(legal_data.offer_version())
	return res


func accept_pdn_consent() -> Dictionary:
	if consent_journal == null or legal_data == null or not legal_data.is_valid():
		return {}
	var res: Dictionary = consent_journal.record_pdn_consent(legal_data, _opened_docs, "legal_screen")
	if not res.is_empty():
		_refresh_status()
		consent_updated.emit(legal_data.offer_version())
	return res


func accept_age_18(override_age: TWAge = null) -> Dictionary:
	if consent_journal == null or legal_data == null or not legal_data.is_valid():
		return {}
	var ag: TWAge = override_age if override_age != null else age_gate
	var res: Dictionary = consent_journal.record_age_18_consent(legal_data, _opened_docs, ag, "legal_screen")
	if not res.is_empty():
		_refresh_status()
		consent_updated.emit(legal_data.offer_version())
	return res


func set_analytics_consent(enabled: bool) -> Dictionary:
	if consent_journal == null or legal_data == null or not legal_data.is_valid():
		return {}
	var res: Dictionary = consent_journal.set_analytics_consent(legal_data, enabled, "legal_screen")
	if not res.is_empty():
		_refresh_status()
		consent_updated.emit(legal_data.offer_version())
	return res


func toggle_analytics() -> Dictionary:
	var cur: bool = consent_journal.analytics_enabled() if consent_journal != null else false
	return set_analytics_consent(not cur)


# Fails closed unless every required doc was opened, PDn was separately confirmed, and adult TWAge is verified.
func accept_current_bundle(include_analytics: bool = false, pdn_separate_confirmed: bool = false) -> Array:
	if consent_journal == null or legal_data == null or not legal_data.is_valid():
		return []
	var acts: Dictionary = {
		"opened_docs": _opened_docs,
		"pdn_separate_confirmed": pdn_separate_confirmed,
		"age_gate": age_gate,
		"record_analytics_choice": include_analytics,
	}
	var res: Array = consent_journal.record_required_bundle(legal_data, "legal_screen", include_analytics, acts)
	if not res.is_empty():
		_refresh_status()
		consent_updated.emit(legal_data.offer_version())
	return res


func accept_single_doc(doc_id: String) -> Dictionary:
	if consent_journal == null or legal_data == null or not legal_data.is_valid() or not legal_data.has_doc(doc_id):
		return {}
	if not has_opened_doc(doc_id):
		return {}
	var e: Dictionary = consent_journal.record_doc_consent(legal_data, doc_id, "legal_modal", age_gate)
	if not e.is_empty():
		_refresh_status()
		consent_updated.emit(legal_data.offer_version())
	return e


func displayed_reader_text() -> String:
	return _reader_text_lbl.text if _reader_text_lbl != null else ""


func displayed_journal_text() -> String:
	return _journal_text_lbl.text if _journal_text_lbl != null else ""


func listed_doc_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if legal_data == null or not legal_data.is_valid():
		return out
	for d in legal_data.list_docs():
		out.append(str(d.get("id", "")))
	return out


func _refresh_status() -> void:
	if _status_lbl == null or legal_data == null or consent_journal == null:
		return
	if not legal_data.is_valid():
		_status_lbl.text = "Ошибка проверки пакета документов: отображение и принятие согласий заблокированы."
		return
	var ov: String = legal_data.offer_version()
	var pay_gate: Dictionary = legal_data.can_enable_real_payments()
	var pay_s: String = "Платежи активны" if bool(pay_gate.get("ok", false)) else "Реальные платежи отключены"
	if _analytics_btn != null:
		_analytics_btn.text = "Аналитика: вкл" if consent_journal.analytics_enabled() else "Аналитика: выкл"
	if consent_journal.has_all_required(ov):
		_status_lbl.text = "Согласия %s приняты · %s · Записей: %d" % [
			consent_journal.accepted_offer_version(),
			pay_s,
			consent_journal.entry_count(),
		]
	else:
		var offer_s: String = "да" if consent_journal.has_accepted("offer", ov) else "нет"
		var pdn_s: String = "да" if consent_journal.has_accepted("pdn", ov) else "нет"
		var age_s: String = "да" if consent_journal.has_accepted("age_18", ov) else "нет"
		_status_lbl.text = "Оферта: %s · ПДн: %s · 18+: %s · %s" % [offer_s, pdn_s, age_s, pay_s]
