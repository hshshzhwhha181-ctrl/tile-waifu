class_name TWLegalConsent
extends RefCounted

# TWLegalConsent (P108 / MP PM21 / §10.4): append-only consent journal with offer_ver tracking.
# Persists under TWState.data["legal_consents"] using modular version TWState.set_module_ver("legal", MODULE_VER)
# so TWState.SAVE_VER stays at 8 (UNIFIED_QA_PLAN / DECISIONS rule: never bump SAVE_VER for new modules).

const MODULE_ID: String = "legal"
const MODULE_VER: int = 1
const STATE_KEY: String = "legal_consents"
const MAX_ENTRIES: int = 512

var _state: TWState = null
var _store: Dictionary = {}
var _clock: TWClock = null
var _bus: TWBus = null


func _init(state: TWState = null, clock: TWClock = null, bus: TWBus = null, store_override: Dictionary = {}) -> void:
	_state = state
	_clock = clock if clock != null else (state.clock if state != null else TWClock.new())
	_bus = bus
	if _state != null:
		_ensure_in(_state.data)
	else:
		_store = store_override
		_ensure_in(_store)


func _root() -> Dictionary:
	var target: Dictionary = _state.data if _state != null else _store
	return _ensure_in(target)


static func _ensure_in(data: Dictionary) -> Dictionary:
	if not (data.get(STATE_KEY) is Dictionary):
		data[STATE_KEY] = {"mod_ver": MODULE_VER, "offer_ver_accepted": "", "entries": []}
	var box: Dictionary = data[STATE_KEY]
	if not (box.get("entries") is Array):
		box["entries"] = []
	if not box.has("offer_ver_accepted"):
		box["offer_ver_accepted"] = ""
	box["mod_ver"] = MODULE_VER
	return box


func _touch_state(urgent: bool = true) -> void:
	if _state != null:
		_state.set_module_ver(MODULE_ID, MODULE_VER)
		_state.mark_dirty(urgent)


func record_consent(kind: String, doc_ver: String, offer_ver: String, doc_hash: String = "", accepted: bool = true, source: String = "legal_screen") -> Dictionary:
	var box: Dictionary = _root()
	var ts: int = _clock.now() if _clock != null else 0
	var seq: int = (box["entries"] as Array).size() + 1
	var entry: Dictionary = {
		"seq": seq,
		"kind": kind,
		"ver": doc_ver,
		"offer_ver": offer_ver,
		"doc_hash": doc_hash,
		"accepted": accepted,
		"ts": ts,
		"source": source,
	}
	(box["entries"] as Array).append(entry)
	while (box["entries"] as Array).size() > MAX_ENTRIES:
		(box["entries"] as Array).pop_front()
	if kind == "offer":
		box["offer_ver_accepted"] = offer_ver if accepted else ""
	_touch_state(true)
	if _bus != null:
		var ev: Dictionary = entry.duplicate(true)
		ev["t"] = "legal.consent_recorded"
		_bus.publish(ev)
	return entry.duplicate(true)


func record_required_bundle(data: TWLegalData, source: String = "legal_screen", include_analytics: bool = false) -> Array:
	if data == null or not data.is_loaded():
		return []
	var ov: String = data.offer_version()
	var recorded: Array = []
	for doc_id in TWLegalData.REQUIRED_CONSENT_IDS:
		var meta: Dictionary = data.find_doc(doc_id)
		var dv: String = str(meta.get("version", ov))
		var dh: String = data.doc_hash_short(doc_id)
		recorded.append(record_consent(doc_id, dv, ov, dh, true, source))
	var pdn_meta: Dictionary = data.find_doc("pdn_consent")
	recorded.append(record_consent(
		"analytics",
		str(pdn_meta.get("version", ov)),
		ov,
		data.doc_hash_short("pdn_consent"),
		include_analytics,
		source
	))
	return recorded


func entries() -> Array:
	var box: Dictionary = _root()
	var out: Array = []
	for e in box["entries"]:
		if e is Dictionary:
			out.append((e as Dictionary).duplicate(true))
	return out


func entry_count() -> int:
	return (_root()["entries"] as Array).size()


func latest_for(kind: String) -> Dictionary:
	var list: Array = _root()["entries"]
	for i in range(list.size() - 1, -1, -1):
		var e: Variant = list[i]
		if e is Dictionary and str((e as Dictionary).get("kind", "")) == kind:
			return (e as Dictionary).duplicate(true)
	return {}


func latest_by_kind() -> Dictionary:
	var out: Dictionary = {}
	for e in _root()["entries"]:
		if e is Dictionary:
			var k: String = str((e as Dictionary).get("kind", ""))
			if k != "":
				out[k] = (e as Dictionary).duplicate(true)
	return out


func accepted_offer_version() -> String:
	var last_offer: Dictionary = latest_for("offer")
	if last_offer.is_empty() or not bool(last_offer.get("accepted", false)):
		return ""
	return str(last_offer.get("offer_ver", ""))


func has_accepted(kind: String, required_offer_ver: String = "") -> bool:
	var last_e: Dictionary = latest_for(kind)
	if last_e.is_empty() or not bool(last_e.get("accepted", false)):
		return false
	if required_offer_ver != "" and str(last_e.get("offer_ver", "")) != required_offer_ver:
		return false
	return true


func has_all_required(required_offer_ver: String) -> bool:
	for k in TWLegalData.REQUIRED_CONSENT_IDS:
		if not has_accepted(k, required_offer_ver):
			return false
	return true


func needs_reconsent(kind: String, current_offer_ver: String) -> bool:
	return not has_accepted(kind, current_offer_ver)


func export_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Журнал согласий Tile Waifu")
	var ov: String = accepted_offer_version()
	lines.append("Принятая версия оферты: %s" % (ov if ov != "" else "не принята"))
	var list: Array = entries()
	lines.append("Всего записей: %d" % list.size())
	for e in list:
		var action_s: String = "принято" if bool(e.get("accepted", false)) else "отозвано/отклонено"
		var ts_i: int = int(e.get("ts", 0))
		var dt_s: String = Time.get_datetime_string_from_unix_time(ts_i, true)
		lines.append("#%d | %s | %s | вер. док. %s | оферта %s | %s | %s" % [
			int(e.get("seq", 0)),
			str(e.get("kind", "")),
			action_s,
			str(e.get("ver", "")),
			str(e.get("offer_ver", "")),
			dt_s,
			str(e.get("source", "")),
		])
	return "\n".join(lines)
