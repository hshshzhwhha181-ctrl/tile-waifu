class_name V8Recovery
extends RefCounted

# Recovery code: moves the whole offline save to another phone without a server.
#   V8Recovery.export_code() -> String   "TW8-xxxxxx-xxxxxx-…" (save JSON -> deflate -> base64url + 6-char checksum)
#   V8Recovery.import_code(code) -> bool  checks prefix, checksum, format and save version; backs up the current
#                                         save to user://save.pre_import.json, replaces G.S (with migration) and saves.
#                                         On failure G.S is untouched and V8Recovery.last_error holds a Russian message.
#   V8Recovery.decode(code) -> Dictionary {ok, err, state} — validation only, nothing is changed.
# Format: body = base64url(deflate(JSON {f, v, sv, s})) + checksum (first 6 hex of sha256(body)),
# cut into groups of 6 joined by "-". base64url itself may contain "-", so groups are split by position.

const PREFIX: = "TW8-"
const FORMAT: = 1
const GROUP: = 6
const SUM_LEN: = 6
const MAX_JSON: = 4 * 1024 * 1024
const PRE_IMPORT_PATH: = "user://save.pre_import.json"

const ERR: = {
	"empty": "Вставь код восстановления",
	"prefix": "Это не код Tile Waifu: он должен начинаться с TW8-",
	"format": "Код повреждён: проверь, что он скопирован целиком",
	"sum": "Код повреждён: контрольная сумма не совпала",
	"data": "Код не читается: данные повреждены",
	"version": "Код из более новой версии игры. Обнови игру и попробуй снова",
	"save": "Не удалось сохранить прогресс на телефоне",
}

static var last_error: = ""


static func export_code(state: = {}) -> String:
	var s: Dictionary = state if not state.is_empty() else G.S
	var env: = {"f": FORMAT, "v": G.version(), "sv": int(s.get("ver", G.SAVE_VER)), "t": int(Time.get_unix_time_from_system()), "s": s}
	var raw: = JSON.stringify(env).to_utf8_buffer()
	var packed: = raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var body: = _b64url(packed)
	var full: = body + _sum(body)
	var groups: = PackedStringArray()
	for i in range(0, full.length(), GROUP):
		groups.append(full.substr(i, GROUP))
	return PREFIX + "-".join(groups)


static func decode(code: String) -> Dictionary:
	var c: = _clean(code)
	if c == "":
		return _fail("empty")
	if not c.begins_with(PREFIX):
		return _fail("prefix")
	var rest: = c.substr(PREFIX.length())
	var full: = ""
	var i: = 0
	while i < rest.length():
		full += rest.substr(i, GROUP)
		i += GROUP
		if i < rest.length():
			if rest[i] != "-":
				return _fail("format")
			i += 1
			if i >= rest.length():
				return _fail("format")
	if full.length() <= SUM_LEN:
		return _fail("format")
	var body: = full.substr(0, full.length() - SUM_LEN)
	if full.substr(full.length() - SUM_LEN) != _sum(body):
		return _fail("sum")
	var packed: = _unb64url(body)
	if packed.is_empty():
		return _fail("data")
	var raw: = packed.decompress_dynamic(MAX_JSON, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return _fail("data")
	var env = JSON.parse_string(raw.get_string_from_utf8())
	if not (env is Dictionary) or not (env.get("s") is Dictionary):
		return _fail("data")
	if int(env.get("f", 0)) != FORMAT:
		return _fail("version") if int(env.get("f", 0)) > FORMAT else _fail("data")
	var st: Dictionary = env.s
	if int(env.get("sv", 0)) > G.SAVE_VER or int(st.get("ver", 0)) > G.SAVE_VER:
		return _fail("version")
	if not st.has("gems") or not st.has("unlocked") or not (st.get("stars") is Dictionary) or not (st.get("owned") is Dictionary):
		return _fail("data")
	last_error = ""
	return {"ok": true, "err": "", "state": st, "version": str(env.get("v", "")), "time": int(env.get("t", 0))}


static func import_code(code: String) -> bool:
	var d: = decode(code)
	if not d.ok:
		return false
	var prev: = G.S
	G.write_atomic(PRE_IMPORT_PATH, JSON.stringify(prev), false)
	if not G.apply_state(d.state):
		G.S = prev
		_fail("data")
		return false
	G.save()
	if not G.save_ok:
		G.S = prev
		_fail("save")
		return false
	G.profile_changed.emit()
	G.rank_changed.emit(G.rank_index(int(prev.get("rp", 0))), G.rank_index(int(G.S.rp)))
	return true


static func _fail(key: String) -> Dictionary:
	last_error = ERR.get(key, ERR.data)
	return {"ok": false, "err": key, "state": {}}


static func _clean(code: String) -> String:
	var out: = ""
	for ch in code:
		if ch in " \t\r\n ":
			continue
		out += ch
	return out


static func _sum(body: String) -> String:
	return body.sha256_text().substr(0, SUM_LEN)


static func _b64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


static func _unb64url(s: String) -> PackedByteArray:
	for ch in s:
		if not (ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"):
			return PackedByteArray()
	var b: = s.replace("-", "+").replace("_", "/")
	while b.length() % 4 != 0:
		b += "="
	return Marshalls.base64_to_raw(b)
