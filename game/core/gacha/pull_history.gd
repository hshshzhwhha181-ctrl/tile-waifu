class_name PullHistory
extends RefCounted

# PullHistory (P22 / GDD §5.9 / MONETIZATION_PLAN §8.2 DP-17, §10.4, AT-M10):
# Pure core wish/gacha pull history journal:
#   - Retains records for >= 365 days (prunes strictly older than 365 * 86400 s on TWClock).
#   - Stores banner_id, family, rarity, item_id, featured, candle, pity counters, cost, odds_hash, seed_commit.
#   - Supports filtering by banner, pagination, and deterministic Russian plain-text export + SHA-256 hash.
#   - Persists in TWState.data["pull_history"] under mod_ver.pull_history = 1 (SAVE_VER remains 8).
# Zero Node / UI / G dependencies; zero currency symbols or percent-digit literals.

const MODULE_ID: String = "pull_history"
const MODULE_VER: int = 1
const STATE_KEY: String = "pull_history"

const DAY_SEC: int = 86400
const RETENTION_DAYS: int = 365
const RETENTION_SEC: int = RETENTION_DAYS * DAY_SEC
const MAX_ENTRIES: int = 20000

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
		data[STATE_KEY] = {"mod_ver": MODULE_VER, "next_id": 1, "entries": []}
	var box: Dictionary = data[STATE_KEY]
	if not (box.get("entries") is Array):
		box["entries"] = []
	box["next_id"] = maxi(1, int(box.get("next_id", 1)))
	box["mod_ver"] = MODULE_VER
	return box


func _touch_state(urgent: bool = false) -> void:
	if _state != null:
		_state.set_module_ver(MODULE_ID, MODULE_VER)
		_state.mark_dirty(urgent)


func record_pull(entry: Dictionary) -> Dictionary:
	var box: Dictionary = _root()
	var list: Array = box["entries"]
	var nid: int = int(box["next_id"])
	box["next_id"] = nid + 1
	var ts: int = int(entry.get("ts", clock.now()))
	var rec: Dictionary = {
		"id": nid,
		"ts": ts,
		"banner_id": str(entry.get("banner_id", "")),
		"family": str(entry.get("family", "outfit")),
		"rarity": str(entry.get("rarity", "gift")),
		"item_id": str(entry.get("item_id", "")),
		"featured": bool(entry.get("featured", false)),
		"candle": bool(entry.get("candle", false)),
		"k_before": int(entry.get("k_before", 0)),
		"g_before": int(entry.get("g_before", 0)),
		"c_before": int(entry.get("c_before", 0)),
		"cost_cur": str(entry.get("cost_cur", "gems")),
		"cost_amt": int(entry.get("cost_amt", 150)),
		"odds_hash": str(entry.get("odds_hash", "")),
		"seed_commit": str(entry.get("seed_commit", "")),
	}
	list.append(rec)
	prune()
	while list.size() > MAX_ENTRIES:
		list.pop_front()
	_touch_state(true)
	return rec.duplicate(true)


# Retains everything within [now - 365 days, now]; removes only entries strictly older than 365 days
func prune() -> int:
	var box: Dictionary = _root()
	var list: Array = box["entries"]
	var cutoff: int = clock.now() - RETENTION_SEC
	var kept: Array = []
	var removed: int = 0
	for item in list:
		if item is Dictionary:
			var ts: int = int((item as Dictionary).get("ts", 0))
			if ts < cutoff:
				removed += 1
			else:
				kept.append(item)
	if removed > 0:
		box["entries"] = kept
		_touch_state(false)
	return removed


func count(banner_id: String = "") -> int:
	var list: Array = _root()["entries"]
	if banner_id == "":
		return list.size()
	var n: int = 0
	for item in list:
		if item is Dictionary and str((item as Dictionary).get("banner_id", "")) == banner_id:
			n += 1
	return n


func list_entries(banner_id: String = "", limit: int = 100, offset: int = 0, newest_first: bool = true) -> Array:
	var raw: Array = _root()["entries"]
	var filtered: Array = []
	for item in raw:
		if item is Dictionary:
			if banner_id == "" or str((item as Dictionary).get("banner_id", "")) == banner_id:
				filtered.append((item as Dictionary).duplicate(true))
	if newest_first:
		filtered.reverse()
	var start: int = maxi(0, offset)
	if start >= filtered.size() or limit <= 0:
		return []
	var end_idx: int = mini(filtered.size(), start + limit)
	return filtered.slice(start, end_idx)


func oldest_ts() -> int:
	var list: Array = _root()["entries"]
	if list.is_empty():
		return 0
	var mn: int = int((list[0] as Dictionary).get("ts", 0))
	for item in list:
		if item is Dictionary:
			mn = mini(mn, int((item as Dictionary).get("ts", 0)))
	return mn


func newest_ts() -> int:
	var list: Array = _root()["entries"]
	if list.is_empty():
		return 0
	var mx: int = int((list[0] as Dictionary).get("ts", 0))
	for item in list:
		if item is Dictionary:
			mx = maxi(mx, int((item as Dictionary).get("ts", 0)))
	return mx


func span_days() -> int:
	var o: int = oldest_ts()
	var n: int = newest_ts()
	if o <= 0 or n <= o:
		return 0
	return (n - o) / DAY_SEC


func export_text(banner_id: String = "") -> String:
	var items: Array = list_entries(banner_id, MAX_ENTRIES, 0, false)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("История желаний Tile Waifu (хранение не менее 365 дней)")
	if banner_id != "":
		lines.append("Баннер: %s" % banner_id)
	lines.append("Всего записей: %d" % items.size())
	for e in items:
		var msk: Dictionary = TWAge.msk_date_of(int(e.get("ts", 0)))
		var dt_s: String = "%04d-%02d-%02d %02d:%02d МСК" % [
			int(msk["year"]), int(msk["month"]), int(msk["day"]), int(msk["hour"]), int(msk["minute"])
		]
		var tags: PackedStringArray = PackedStringArray()
		if bool(e.get("featured", false)):
			tags.append("избр")
		if bool(e.get("candle", false)):
			tags.append("свеча")
		var tag_s: String = (" [" + ",".join(tags) + "]") if not tags.is_empty() else ""
		lines.append("#%d | %s | %s (%s) | %s | %s%s | k=%d g=%d c=%d | %d %s | odds=%s" % [
			int(e.get("id", 0)),
			dt_s,
			str(e.get("banner_id", "")),
			str(e.get("family", "")),
			str(e.get("rarity", "")),
			str(e.get("item_id", "")),
			tag_s,
			int(e.get("k_before", 0)),
			int(e.get("g_before", 0)),
			int(e.get("c_before", 0)),
			int(e.get("cost_amt", 0)),
			str(e.get("cost_cur", "")),
			str(e.get("odds_hash", "")),
		])
	return "\n".join(lines)


func export_hash(banner_id: String = "") -> String:
	return export_text(banner_id).sha256_text()
