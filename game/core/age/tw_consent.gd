class_name TWConsent
extends RefCounted

# TWConsent (P22 / P108 / GDD §11.3 / MONETIZATION_PLAN §7.4, §8.5, §10.4):
# Unified single source of truth for the append-only consent journal (Offer, Privacy Policy,
# separate 152-FZ PDn consent, 18+ confirmation, and separate voluntary Analytics toggle).
# Deterministic on TWClock.safe_now() with monotonic seq & ts; stores in TWState.data["tw_consents"]
# under mod_ver.consent = 1 without bumping SAVE_VER (stays 8). Zero Node / UI / G dependencies.

const MODULE_ID: String = "consent"
const MODULE_VER: int = 1
const STATE_KEY: String = "tw_consents"
const LEGACY_STATE_KEY: String = "legal_consents"
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


static func normalize_kind(kind: String) -> String:
	var k: String = kind.strip_edges().to_lower()
	if k == "pdn_consent":
		return KIND_PDN
	if k == "age_18_full_tier":
		return KIND_AGE_18
	return k


func _root() -> Dictionary:
	var target: Dictionary = _state.data if _state != null else _store
	return _ensure_in(target)


static func _ensure_in(data: Dictionary) -> Dictionary:
	if not (data.get(STATE_KEY) is Dictionary):
		data[STATE_KEY] = {
			"mod_ver": MODULE_VER,
			"offer_ver_accepted": "",
			"next_seq": 1,
			"last_ts": 0,
			"entries": [],
		}
	var box: Dictionary = data[STATE_KEY]
	if not (box.get("entries") is Array):
		box["entries"] = []
	if not box.has("offer_ver_accepted"):
		box["offer_ver_accepted"] = ""
	var list: Array = box["entries"]
	# One-way compatibility merge if a pre-unification save had data under "legal_consents"
	if data.get(LEGACY_STATE_KEY) is Dictionary:
		var leg: Dictionary = data[LEGACY_STATE_KEY]
		var leg_entries: Variant = leg.get("entries", [])
		if leg_entries is Array and not (leg_entries as Array).is_empty() and not bool(box.get("_legacy_merged", false)):
			for le in (leg_entries as Array):
				if le is Dictionary:
					var cp: Dictionary = (le as Dictionary).duplicate(true)
					cp["kind"] = normalize_kind(str(cp.get("kind", "")))
					list.append(cp)
			box["_legacy_merged"] = true
	var max_seq: int = 0
	var max_ts: int = 0
	for item in list:
		if item is Dictionary:
			var d_item: Dictionary = item as Dictionary
			d_item["kind"] = normalize_kind(str(d_item.get("kind", "")))
			max_seq = maxi(max_seq, int(d_item.get("seq", 0)))
			max_ts = maxi(max_ts, int(d_item.get("ts", 0)))
	box["next_seq"] = maxi(maxi(1, int(box.get("next_seq", 1))), max_seq + 1)
	box["last_ts"] = maxi(int(box.get("last_ts", 0)), max_ts)
	box["mod_ver"] = MODULE_VER
	return box


func _touch_state(urgent: bool = true) -> void:
	if _state != null:
		_state.set_module_ver(MODULE_ID, MODULE_VER)
		_state.mark_dirty(urgent)


# Rotates oldest superseded entries when > MAX_ENTRIES while NEVER dropping:
#   (a) the founding (first accepted) entry of any required kind, or
#   (b) the latest entry of any kind currently present in the journal.
static func _rotate_to_cap(list: Array) -> void:
	while list.size() > MAX_ENTRIES:
		var pinned: Dictionary = {}
		var founding_seen: Dictionary = {}
		for i in range(list.size()):
			var item: Variant = list[i]
			if item is Dictionary:
				var k: String = normalize_kind(str((item as Dictionary).get("kind", "")))
				if REQUIRED_KINDS.has(k) and bool((item as Dictionary).get("accepted", false)) and not founding_seen.has(k):
					founding_seen[k] = true
					pinned[i] = true
		var latest_idx: Dictionary = {}
		for i in range(list.size()):
			var item: Variant = list[i]
			if item is Dictionary:
				var k: String = normalize_kind(str((item as Dictionary).get("kind", "")))
				if k != "":
					latest_idx[k] = i
		for k in latest_idx:
			pinned[int(latest_idx[k])] = true
		var victim: int = -1
		for i in range(list.size()):
			if not pinned.has(i):
				victim = i
				break
		if victim < 0:
			break
		list.remove_at(victim)


func record(kind: String, doc_ver: String, offer_ver: String, accepted: bool = true, source: String = "gate", doc_hash: String = "") -> Dictionary:
	var k: String = normalize_kind(kind)
	if k == "":
		return {}
	var box: Dictionary = _root()
	var list: Array = box["entries"]
	if clock.clock_ok():
		clock.tick()
	var ts: int = maxi(clock.safe_now(), int(box["last_ts"]))
	var seq: int = int(box["next_seq"])
	box["next_seq"] = seq + 1
	box["last_ts"] = ts
	var entry: Dictionary = {
		"seq": seq,
		"kind": k,
		"ver": doc_ver,
		"offer_ver": offer_ver,
		"doc_hash": doc_hash,
		"accepted": accepted,
		"ts": ts,
		"source": source,
	}
	list.append(entry)
	_rotate_to_cap(list)
	if k == KIND_OFFER:
		box["offer_ver_accepted"] = offer_ver if accepted else ""
	_touch_state(true)
	return entry.duplicate(true)


func accept_offer(doc_ver: String, offer_ver: String, source: String = "legal_screen", doc_hash: String = "") -> Dictionary:
	return record(KIND_OFFER, doc_ver, offer_ver, true, source, doc_hash)


func accept_privacy(doc_ver: String, offer_ver: String, source: String = "legal_screen", doc_hash: String = "") -> Dictionary:
	return record(KIND_PRIVACY, doc_ver, offer_ver, true, source, doc_hash)


# 152-FZ: PDn processing consent is a separate explicit act.
func accept_pdn(doc_ver: String, offer_ver: String, source: String = "legal_screen", doc_hash: String = "") -> Dictionary:
	return record(KIND_PDN, doc_ver, offer_ver, true, source, doc_hash)


# 18+ consent requires a verified adult TWAge state (fails closed otherwise).
func accept_age_18(age: TWAge, doc_ver: String, offer_ver: String, source: String = "age_gate", doc_hash: String = "") -> Dictionary:
	if age == null or not age.is_adult():
		return {}
	return record(KIND_AGE_18, doc_ver, offer_ver, true, source, doc_hash)


# Convenience helper for explicit multi-step flow / tests; fails closed if age is provided and not adult.
func accept_required(offer_ver: String, analytics_ok: bool = false, source: String = "gate", age: TWAge = null) -> Array:
	if age != null and not age.is_adult():
		return []
	var out: Array = []
	for k in REQUIRED_KINDS:
		out.append(record(k, offer_ver, offer_ver, true, source, ""))
	out.append(record(KIND_ANALYTICS, offer_ver, offer_ver, analytics_ok, source, ""))
	return out


func set_analytics(enabled: bool, offer_ver: String, source: String = "settings") -> Dictionary:
	return record(KIND_ANALYTICS, offer_ver, offer_ver, enabled, source, "")


func revoke(kind: String, offer_ver: String, source: String = "settings", doc_hash: String = "") -> Dictionary:
	return record(kind, offer_ver, offer_ver, false, source, doc_hash)


func entries() -> Array:
	var out: Array = []
	for e in _root()["entries"]:
		if e is Dictionary:
			out.append((e as Dictionary).duplicate(true))
	return out


func entry_count() -> int:
	return (_root()["entries"] as Array).size()


func latest_for(kind: String) -> Dictionary:
	var target: String = normalize_kind(kind)
	var list: Array = _root()["entries"]
	for i in range(list.size() - 1, -1, -1):
		var e: Variant = list[i]
		if e is Dictionary and normalize_kind(str((e as Dictionary).get("kind", ""))) == target:
			return (e as Dictionary).duplicate(true)
	return {}


func latest_by_kind() -> Dictionary:
	var out: Dictionary = {}
	for e in _root()["entries"]:
		if e is Dictionary:
			var k: String = normalize_kind(str((e as Dictionary).get("kind", "")))
			if k != "":
				out[k] = (e as Dictionary).duplicate(true)
	return out


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
	lines.append("Принятая версия оферты: %s" % (ov if ov != "" else "не принята"))
	var list: Array = entries()
	lines.append("Записей: %d" % list.size())
	for e in list:
		var msk: Dictionary = TWAge.msk_date_of(int(e.get("ts", 0)))
		var ts_s: String = "%04d-%02d-%02d %02d:%02d МСК" % [
			int(msk["year"]), int(msk["month"]), int(msk["day"]), int(msk["hour"]), int(msk["minute"])
		]
		var act: String = "принято" if bool(e.get("accepted", false)) else "отозвано/отклонено"
		var dh: String = str(e.get("doc_hash", ""))
		var hash_part: String = (" | hash %s" % dh) if dh != "" else ""
		lines.append("#%d | %s | %s | вер. %s | оферта %s%s | %s | %s" % [
			int(e.get("seq", 0)),
			str(e.get("kind", "")),
			act,
			str(e.get("ver", "")),
			str(e.get("offer_ver", "")),
			hash_part,
			ts_s,
			str(e.get("source", "")),
		])
	return "\n".join(lines)
