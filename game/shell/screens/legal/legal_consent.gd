class_name TWLegalConsent
extends RefCounted

# TWLegalConsent (P108 / MP PM21 / §10.4): shell adapter over the SINGLE unified core TWConsent journal.
# Shares TWConsent.STATE_KEY ("tw_consents"), canonical kind names ("offer", "privacy", "pdn", "age_18", "analytics"),
# monotonic seq/ts (TWClock.safe_now()), founding-entry-safe rotation, and unified MSK export format.
# Records mod_ver.legal = 1 alongside mod_ver.consent = 1 without bumping SAVE_VER (stays 8).
# Enforces 152-FZ separation: PDn consent and 18+ confirmation (gated by adult TWAge) are separate explicit acts
# and require the underlying documents to have been opened and validated.

const MODULE_ID: String = "legal"
const MODULE_VER: int = 1
const STATE_KEY: String = TWConsent.STATE_KEY
const MAX_ENTRIES: int = TWConsent.MAX_ENTRIES

var core: TWConsent = null
var _state: TWState = null
var _bus: TWBus = null


func _init(state: TWState = null, clock: TWClock = null, bus: TWBus = null, store_override: Dictionary = {}) -> void:
	_state = state
	_bus = bus
	core = TWConsent.new(clock, state, store_override)


func core_journal() -> TWConsent:
	return core


func _touch_legal_mod_ver() -> void:
	if _state != null:
		_state.set_module_ver(MODULE_ID, MODULE_VER)
		_state.mark_dirty(true)


func _publish_event(entry: Dictionary) -> void:
	if _bus != null and not entry.is_empty():
		var ev: Dictionary = entry.duplicate(true)
		ev["t"] = "legal.consent_recorded"
		_bus.publish(ev)


func record_consent(kind: String, doc_ver: String, offer_ver: String, doc_hash: String = "", accepted: bool = true, source: String = "legal_screen") -> Dictionary:
	var entry: Dictionary = core.record(kind, doc_ver, offer_ver, accepted, source, doc_hash)
	if entry.is_empty():
		return {}
	_touch_legal_mod_ver()
	_publish_event(entry)
	return entry


# Records consent for ONE validated document. For age_18_full_tier / age_18, requires a verified adult TWAge.
func record_doc_consent(data: TWLegalData, doc_id: String, source: String = "legal_screen", age_gate: TWAge = null) -> Dictionary:
	if data == null or not data.is_valid() or not data.has_doc(doc_id):
		return {}
	if TWConsent.normalize_kind(doc_id) == TWConsent.KIND_AGE_18:
		if age_gate == null or not age_gate.is_adult():
			return {}
	var meta: Dictionary = data.find_doc(doc_id)
	var ov: String = data.offer_version()
	var dv: String = str(meta.get("version", ov))
	var dh: String = data.doc_hash_short(doc_id)
	return record_consent(doc_id, dv, ov, dh, true, source)


# Step 1: Offer & Privacy Policy acceptance (requires both documents opened; never bundles PDn or 18+).
func record_offer_and_privacy(data: TWLegalData, opened_docs: Dictionary, source: String = "legal_screen") -> Array:
	if data == null or not data.is_valid():
		return []
	if not bool(opened_docs.get("offer", false)) or not bool(opened_docs.get("privacy", false)):
		return []
	var out: Array = []
	out.append(record_doc_consent(data, "offer", source))
	out.append(record_doc_consent(data, "privacy", source))
	return out


# Step 2 (152-FZ): Separate explicit PDn processing consent (requires pdn_consent opened; never bundles analytics).
func record_pdn_consent(data: TWLegalData, opened_docs: Dictionary, source: String = "legal_screen") -> Dictionary:
	if data == null or not data.is_valid():
		return {}
	if not bool(opened_docs.get("pdn_consent", false)):
		return {}
	return record_doc_consent(data, "pdn_consent", source)


# Step 3: 18+ confirmation requires BOTH opening age_18_full_tier AND an adult TWAge verification.
func record_age_18_consent(data: TWLegalData, opened_docs: Dictionary, age_gate: TWAge, source: String = "legal_screen") -> Dictionary:
	if data == null or not data.is_valid():
		return {}
	if not bool(opened_docs.get("age_18_full_tier", false)):
		return {}
	if age_gate == null or not age_gate.is_adult():
		return {}
	return record_doc_consent(data, "age_18_full_tier", source, age_gate)


# Separate voluntary analytics toggle (never stamped with pdn_consent hash, never bundled into offer).
func set_analytics_consent(data: TWLegalData, enabled: bool, source: String = "legal_screen") -> Dictionary:
	if data == null or not data.is_valid():
		return {}
	var ov: String = data.offer_version()
	return record_consent(TWConsent.KIND_ANALYTICS, ov, ov, "", enabled, source)


# Guarded bundle recorder: FAILS CLOSED unless confirmed_acts proves every required document was opened,
# 152-FZ PDn consent was explicitly confirmed separately, and adult TWAge is verified.
func record_required_bundle(data: TWLegalData, source: String = "legal_screen", include_analytics: bool = false, confirmed_acts: Dictionary = {}) -> Array:
	if data == null or not data.is_valid():
		return []
	var opened: Variant = confirmed_acts.get("opened_docs", {})
	if not (opened is Dictionary):
		return []
	var opened_d: Dictionary = opened as Dictionary
	for doc_id in TWLegalData.REQUIRED_CONSENT_IDS:
		if not bool(opened_d.get(doc_id, false)):
			return []
	if not bool(confirmed_acts.get("pdn_separate_confirmed", false)):
		return []
	var age_v: Variant = confirmed_acts.get("age_gate", null)
	if not (age_v is TWAge) or not (age_v as TWAge).is_adult():
		return []
	var recorded: Array = []
	for doc_id in TWLegalData.REQUIRED_CONSENT_IDS:
		var e: Dictionary = record_doc_consent(data, doc_id, source, age_v as TWAge)
		if e.is_empty():
			return []
		recorded.append(e)
	if bool(confirmed_acts.get("record_analytics_choice", false)):
		recorded.append(set_analytics_consent(data, include_analytics, source))
	return recorded


func entries() -> Array:
	return core.entries()


func entry_count() -> int:
	return core.entry_count()


func latest_for(kind: String) -> Dictionary:
	return core.latest_for(kind)


func latest_by_kind() -> Dictionary:
	return core.latest_by_kind()


func accepted_offer_version() -> String:
	return core.accepted_offer_version()


func has_accepted(kind: String, required_offer_ver: String = "") -> bool:
	return core.has_accepted(kind, required_offer_ver)


func has_all_required(required_offer_ver: String) -> bool:
	return core.has_required_consents(required_offer_ver)


func analytics_enabled() -> bool:
	return core.analytics_enabled()


func needs_reconsent(kind: String, current_offer_ver: String) -> bool:
	return core.needs_reconsent(kind, current_offer_ver)


func export_text() -> String:
	return core.export_text()
