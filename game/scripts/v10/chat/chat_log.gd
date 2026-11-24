class_name V10ChatLog
extends RefCounted

# Chat history per heroine: the last 60 bubbles (spec §Р8 «Данные»), kept in user://v10_logs/chat_<hero>.json,
# never in the save and never in the V8Recovery code (§2.6). Scripted thread text is rebuildable from the save's
# picks (V10Chat.transcript), so losing this file only loses stickers/reactions small talk — nothing that matters.

const DIR: = "user://v10_logs/"
const KEEP: = 60


static func path(hero: String) -> String:
	return DIR + "chat_%s.json" % hero


# pure: append and trim to the newest KEEP entries
static func append(log: Array, entries: Array) -> Array:
	var out: = log.duplicate()
	out.append_array(entries)
	if out.size() > KEEP:
		out = out.slice(out.size() - KEEP)
	return out


static func read(hero: String, dir: String = DIR) -> Array:
	var p: = dir + "chat_%s.json" % hero
	if not FileAccess.file_exists(p):
		return []
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return v if v is Array else []


static func write(hero: String, log: Array, dir: String = DIR) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var f: = FileAccess.open(dir + "chat_%s.json" % hero, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(log.slice(maxi(0, log.size() - KEEP))))
	f.close()
	return true
