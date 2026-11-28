class_name TWSave
extends RefCounted

# TWSave (P12 / WP4): the file side of the save. One instance == one save slot at an INJECTED path (tests use a scratch
# directory, the game uses user://save.json). Never touches G, the scene tree or the player's real save by itself.
#
#   write(text) -> bool           atomic: <path>.tmp.json is written, flushed and READ BACK (parse + byte-for-byte), only then
#                                 the live file becomes <path>.bak.json (when it was a valid save) and tmp is renamed
#                                 over <path>. A live file that is NOT a valid save is moved to <path>.corrupt.json
#                                 instead, so a good .bak is never overwritten by garbage and nothing is silently lost.
#   load_best(validate) -> Dictionary  tries main -> tmp -> bak; `validate.call(data) -> {ok: bool, reason: String}` decides if a
#                                 parsed dict is usable ("future" = written by a newer game, never overwritten).
#                                 Returns {ok, data, from, reason, tried:[{path, why}]}; reason when not ok:
#                                 "missing" (no file at all), "future" (a newer game wrote it), "damaged" (files exist, none
#                                 usable). It never throws and never crashes on a damaged / empty / huge / binary file.
#   exists() -> bool              any of the three files present
#
# Interruption safety (kill the process at ANY point of write()): main, tmp and bak are never all bad at once; see
# state_selftest.gd "kill at X" checks. `kill_at` is the test hook that simulates the kill: "tmp_open" "tmp_written"
# "tmp_verified" "rotated" "renamed" (write() returns false at that point and does nothing more).

const MAX_BYTES: = 16 * 1024 * 1024

var path: String
var last_error: = ""
var kill_at: = ""


func _init(p: String = "user://save.json") -> void:
	path = p


func tmp_path() -> String:
	return path.get_basename() + ".tmp.json"


func bak_path() -> String:
	return path.get_basename() + ".bak.json"


func corrupt_path() -> String:
	return path.get_basename() + ".corrupt.json"


func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(tmp_path()) or FileAccess.file_exists(bak_path())


func remove_all() -> void:
	for p in [path, tmp_path(), bak_path(), corrupt_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


# ── read ───────────────────────────────────────────────────────────────────────────────────────────────────────

# {ok, data, why}: why is "missing" | "unreadable" | "empty" | "toobig" | "badjson" | "notdict" | "" (ok)
static func read_file(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {"ok": false, "why": "missing", "data": null}
	var f: = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"ok": false, "why": "unreadable", "data": null}
	if f.get_length() > MAX_BYTES:
		f.close()
		return {"ok": false, "why": "toobig", "data": null}
	var bytes: = f.get_buffer(f.get_length())
	f.close()
	var txt: = bytes.get_string_from_utf8()
	if txt.strip_edges() == "":
		return {"ok": false, "why": "empty", "data": null}
	var j: = JSON.new()
	if j.parse(txt) != OK:
		return {"ok": false, "why": "badjson", "data": null}
	if not (j.data is Dictionary):
		return {"ok": false, "why": "notdict", "data": null}
	return {"ok": true, "why": "", "data": j.data}


func load_best(validate: Callable = Callable()) -> Dictionary:
	var tried: = []
	var best: = {}
	var future: = false
	var any_file: = false
	for p in [path, tmp_path(), bak_path()]:
		var r: = read_file(p)
		if r.why != "missing":
			any_file = true
		if not r.ok:
			if r.why != "missing":
				tried.append({"path": p, "why": r.why})
			continue
		var v: Dictionary = {"ok": true, "reason": ""}
		if validate.is_valid():
			var vr = validate.call(r.data)
			if vr is Dictionary:
				v = vr
		if bool(v.get("ok", false)):
			if best.is_empty():
				best = {"ok": true, "data": r.data, "from": p, "reason": ""}
			continue
		var reason: = str(v.get("reason", "invalid"))
		if reason == "future":
			future = true
		tried.append({"path": p, "why": reason})
	# a file from a NEWER game wins over any older readable copy: loading the old one would silently drop the newer
	# progress and the next save would overwrite it
	if future:
		return {"ok": false, "data": null, "from": "", "reason": "future", "tried": tried}
	if not best.is_empty():
		best["tried"] = tried
		return best
	return {"ok": false, "data": null, "from": "", "reason": "damaged" if any_file else "missing", "tried": tried}


# ── write ──────────────────────────────────────────────────────────────────────────────────────────────────────

func write(text: String) -> bool:
	last_error = ""
	if text.length() > MAX_BYTES:
		last_error = "too big"
		return false
	var tmp: = tmp_path()
	var bak: = bak_path()
	var f: = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())]
		return false
	if kill_at == "tmp_open":
		f.close()
		return false
	f.store_string(text)
	f.flush()
	var werr: = f.get_error()
	if kill_at == "tmp_written":
		# the process dies with the file half written: keep only a prefix on disk
		f.close()
		var h: = FileAccess.open(tmp, FileAccess.WRITE)
		if h:
			h.store_string(text.substr(0, text.length() / 2))
			h.close()
		return false
	f.close()
	if werr != OK:
		last_error = "write failed (%s)" % error_string(werr)
		DirAccess.remove_absolute(tmp)
		return false
	# read back: what is on disk must be exactly what we meant to write, otherwise the live save is left alone
	var back: = FileAccess.open(tmp, FileAccess.READ)
	var same: = false
	if back != null:
		same = back.get_as_text() == text
		back.close()
	if not same:
		last_error = "verify failed (disk full?)"
		DirAccess.remove_absolute(tmp)
		return false
	if kill_at == "tmp_verified":
		return false
	if FileAccess.file_exists(path):
		if bool(read_file(path).ok):
			if FileAccess.file_exists(bak):
				DirAccess.remove_absolute(bak)
			if DirAccess.rename_absolute(path, bak) != OK:
				DirAccess.copy_absolute(path, bak)
				DirAccess.remove_absolute(path)
		else:
			if FileAccess.file_exists(corrupt_path()):
				DirAccess.remove_absolute(corrupt_path())
			if DirAccess.rename_absolute(path, corrupt_path()) != OK:
				DirAccess.remove_absolute(path)
	if kill_at == "rotated":
		return false
	var err: = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		last_error = "rename failed (%s)" % error_string(err)
		# put the previous save back so the live path is never left empty
		if not FileAccess.file_exists(path) and FileAccess.file_exists(bak):
			DirAccess.copy_absolute(bak, path)
		return false
	if kill_at == "renamed":
		return false
	return true
