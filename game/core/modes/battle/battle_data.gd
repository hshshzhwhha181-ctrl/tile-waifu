class_name TWBattleData
extends RefCounted

# TWBattleData (P73/P76/P78/P74/P77): pure integer-safe loader and cache for all Layer B JSON tables.
# Canonical JSON files live in data/battle/*.json and are mirrored byte-for-byte into
# res://core/modes/battle/data/*.json so packaged builds and headless selftests read the exact same data.
# NOTE: Never define `static func get` or `static func reload` (Godot 4 shadows Object.get / Script.reload).

const BALANCE_PATH: = "res://core/modes/battle/data/balance.json"
const ROLES_PATH: = "res://core/modes/battle/data/roles.json"
const HEROES_PATH: = "res://core/modes/battle/data/heroes_battle.json"
const PROGRESS_PATH: = "res://core/modes/battle/data/progress.json"
const STAGES_PATH: = "res://core/modes/battle/data/stages.json"

static var _cache: Dictionary = {}


static func _load_json(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		push_error("TWBattleData: missing file %s" % path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		push_error("TWBattleData: invalid JSON dictionary in %s" % path)
		return {}
	_cache[path] = parsed
	return parsed


static func balance() -> Dictionary:
	return _load_json(BALANCE_PATH)


static func roles() -> Dictionary:
	return _load_json(ROLES_PATH)


static func heroes() -> Dictionary:
	return _load_json(HEROES_PATH)


static func progress() -> Dictionary:
	return _load_json(PROGRESS_PATH)


static func stages() -> Dictionary:
	return _load_json(STAGES_PATH)


static func clear_cache() -> void:
	_cache.clear()


static func load_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


static func raw_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)
