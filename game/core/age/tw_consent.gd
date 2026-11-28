class_name TWConsent
extends RefCounted

# TWConsent (P22 / GDD §11.3 / MONETIZATION_PLAN §7.4, §8.5, §10.4):
# Pure core consent journal for Offer, Privacy Policy, PDn processing, 18+ declaration, and separate Analytics toggle.
# Deterministic on TWClock; stores append-only history in TWState.data["tw_consents"] under mod_ver.consent = 1
# without bumping SAVE_VER (stays 8). Zero Node / UI / G dependencies.

const MODULE_ID: String = "consent"
const MODULE_VER: int = 1
const STATE_KEY: String = "tw_consents"
const MAX_ENTRIES: int = 512

const KIND_OFFER: String = "offer"
const KIND_PRIVACY: String = "privacy"
const KIND_PDN: String = "pdn"
const KIND_AGE_18: String = "age_18"
const KIND_ANALYTICS: String = "analytics"
const REQUIRED_KINDS: = ["offer", "privacy", "pdn", "age_18"]

var _state: TWState = null
var _store: Dictionary = {}
var clock: TWClock = null


func _init(p_clock: TWClock = null, p_state: TWState = null, store_override: Dictionary = {}) -> void:
	_state = p_state
	clock = p_clock if p_clock != null else (p_state.clock if p_state != null else TWClock.new())
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


func record(kind: String, doc_ver: String, offer_ver: String, accepted: bool = true, source: String = "gate") -> Dictionary:
	var k: String = kind.strip_edges().to_lower()
	if k == "":
		return {}
	var box: Dictionary = _root()
	var list: Array = box["entries"]
	var entry: Dictionary = {
		"seq": list.size() + 1,
		"kind": k,
		"ver": doc_ver,
		"offer_ver": offer_ver,
		"accepted": accepted,
		"ts": clock.now(),
		"source": source,
	}
	list.append(entry)
	while list.size() > MAX_ENTRIES:
		list.pop_front()
	if k == KIND_OFFER:
		box["offer_ver_accepted"] = offer_ver if accepted else ""
	_touch_state(true)
	return entry.duplicate(true)


func accept_required(offer_ver: String, analytics_ok: bool = false, source: String = "gate") -> Array:
	var out: Array = []
	for k in REQUIRED_KINDS:
		out.append(record(k, offer_ver, offer_ver, true, source))
	out.append(record(KIND_ANALYTICS, offer_ver, offer_ver, analytics_ok, source))
	return out


func set_analytics(enabled: bool, offer_ver: String, source: String = "settings") -> Dictionary:
	return record(KIND_ANALYTICS, offer_ver, offer_ver, enabled, source)


func revoke(kind: String, offer_ver: String, source: String = "settings") -> Dictionary:
	return record(kind, offer_ver, offer_ver, false, source)


func entries() -> Array:
	var out: Array = []
	for e in _root()["entries"]:
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


func has_accepted(kind: String, required_offer_ver: String = "") -> bool:
	var last_e: Dictionary = latest_for(kind)
	if last_e.is_empty() or not bool(last_e.get("accepted", false)):
		return false
	if required_offer_ver != "" and str(last_e.get("offer_ver", "")) != required_offer_ver:
		return false
	return true


func has_required_consents(required_offer_ver: String = "") -> bool:
	for k in REQUIRED_KINDS:
		if not has_accepted(k, required_offer_ver):
			return false
	return true


func analytics_enabled() -> bool:
	return has_accepted(KIND_ANALYTICS)


func accepted_offer_version() -> String:
	var last_offer: Dictionary = latest_for(KIND_OFFER)
	if last_offer.is_empty() or not bool(last_offer.get("accepted", false)):
		return ""
	return str(last_offer.get("offer_ver", ""))


func needs_reconsent(kind: String, current_offer_ver: String) -> bool:
	return not has_accepted(kind, current_offer_ver)


func export_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Журнал согласий Tile Waifu")
	var ov: String = accepted_offer_version()
	lines.append("Оферта: %s" % (ov if ov != "" else "не принята"))
	var list: Array = entries()
	lines.append("Записей: %d" % list.size())
	for e in list:
		var msk: Dictionary = TWAge.msk_date_of(int(e.get("ts", 0)))
		var ts_s: String = "%04d-%02d-%02d %02d:%02d МСК" % [
			int(msk["year"]), int(msk["month"]), int(msk["day"]), int(msk["hour"]), int(msk["minute"])
		]
		var act: String = "принято" if bool(e.get("accepted", false)) else "отозвано"
		lines.append("#%d | %s | %s | вер. %s | оферта %s | %s | %s" % [
			int(e.get("seq", 0)),
			str(e.get("kind", "")),
			act,
			str(e.get("ver", "")),
			str(e.get("offer_ver", "")),
			ts_s,
			str(e.get("source", "")),
		])
	return "\n".join(lines)
