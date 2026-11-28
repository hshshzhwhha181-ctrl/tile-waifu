class_name TWState
extends RefCounted

# TWState (P12 / WP4): the ONE record of the save. Owns the state dictionary (`data`, the future G.S), a dirty flag and the
# debounced flush, and sits on an INJECTED TWSave (path) and TWClock (time), so tests run on a scratch dir and a fake clock.
# G is not rewired to it yet (P15): nothing here reads G, the scene tree or the real save.
#
#   TWState.new(save: TWSave, clock: TWClock, ctx: Dictionary)      ctx = TWMigrate ctx (defaults / heroes / ...)
#   load_game() -> String      status: "fresh" (no files), "loaded", "recovered" (main damaged, tmp/bak used), "future" (a
#                              newer game wrote the save: NOT applied, files untouched, saving is locked), "damaged" (files
#                              exist, none usable: fresh state, the broken main moves to .corrupt.json on the first save)
#   message() -> String        Russian explanation for the player for every status other than loaded / fresh
#   apply_state(d) -> bool     the import path: same future-version / type checks as load, never partial
#   mark_dirty(urgent = false) something changed. urgent (any money operation) -> flushed within MONEY_FLUSH_MS (100 ms);
#                              anything else within DEBOUNCE_MS (1 s) of the FIRST unsaved change (a busy player cannot
#                              starve the save: the window is not extended by later changes)
#   poll() -> bool             call every frame / 100 ms from the shell: flushes when the deadline has passed
#   flush(force = false) -> bool   write now (no-op while clean unless force); false + stays dirty (retry in RETRY_MS) on
#                              an I/O error; always false while locked (status "future")
#   on_pause() / on_exit()     the shell calls these on NOTIFICATION_APPLICATION_PAUSED / FOCUS_OUT / WM_CLOSE_REQUEST:
#                              flush at once if anything is dirty
#   state_hash(d = data) -> String   sha256 of the canonical JSON (sorted keys, int/float-normalised): the golden-save hash
#   module_ver(id) / set_module_ver(id, v)   per-module save versions, kept in data.mod_ver (created on first use)

const SAVE_VER: = TWMigrate.SAVE_VER
const DEBOUNCE_MS: = 1000
const MONEY_FLUSH_MS: = 100
const RETRY_MS: = 2000

signal flushed(ok: bool)

var save: TWSave
var clock: TWClock
var ctx: Dictionary
var data: Dictionary = {}
var status: = "fresh"
var loaded_from: = ""
var reason: = ""
var locked: = false
var dirty: = false
var last_flush_ok: = true
var writes: = 0
var before_save: Callable = Callable()      # (data) -> void, e.g. seal the wallet; runs right before every write
var _due: int = -1


func _init(s: TWSave = null, c: TWClock = null, context: Dictionary = {}) -> void:
	save = s if s != null else TWSave.new()
	clock = c if c != null else TWClock.new()
	ctx = context
	data = _fresh()


func _fresh() -> Dictionary:
	if ctx.get("defaults") is Callable and (ctx.defaults as Callable).is_valid():
		var d = (ctx.defaults as Callable).call()
		if d is Dictionary:
			var st: Dictionary = d
			st["ver"] = SAVE_VER
			return st
	return {"ver": SAVE_VER}


# ── load / import ──────────────────────────────────────────────────────────────────────────────────────────────

func _validate(d: Variant) -> Dictionary:
	var c: = TWMigrate.check(d)
	return {"ok": bool(c.ok), "reason": str(c.reason)}


func load_game() -> String:
	_due = -1
	dirty = false
	locked = false
	reason = ""
	var r: = save.load_best(_validate)
	if bool(r.ok):
		var a: = TWMigrate.apply(r.data, ctx)
		if bool(a.ok):
			data = a.state
			loaded_from = str(r.from)
			status = "loaded" if loaded_from == save.path else "recovered"
			if status == "recovered":
				dirty = true            # write the repaired state back to the main file soon
				_due = clock.mono_msec() + DEBOUNCE_MS
			return status
		reason = str(a.reason)          # cannot happen after a successful check, kept so nothing is swallowed
		r = {"reason": "damaged"}
	data = _fresh()
	loaded_from = ""
	reason = str(r.get("reason", "missing"))
	match reason:
		"missing":
			status = "fresh"
		"future":
			status = "future"
			locked = true               # never overwrite a save written by a newer game
		_:
			status = "damaged"
	return status


func message() -> String:
	match status:
		"recovered":
			return "Основное сохранение повреждено: прогресс восстановлен из резервной копии."
		"future":
			return "Сохранение создано более новой версией игры. Обнови игру: старая версия не будет его перезаписывать."
		"damaged":
			return "Сохранение повреждено и не читается. Начата новая игра; повреждённый файл сохранён рядом с пометкой corrupt."
	return ""


# import / restore from outside (recovery code, cloud): all or nothing, a newer version is refused as it is on load
func apply_state(d: Variant) -> bool:
	var a: = TWMigrate.apply(d, ctx) if d is Dictionary else {"ok": false, "reason": "notdict"}
	if not bool(a.ok):
		reason = str(a.reason)
		return false
	data = a.state
	locked = false
	status = "loaded"
	reason = ""
	mark_dirty(true)
	return true


# ── dirty / debounce / flush ───────────────────────────────────────────────────────────────────────────────────

func mark_dirty(urgent: bool = false) -> void:
	var delay: = MONEY_FLUSH_MS if urgent else DEBOUNCE_MS
	var due: = clock.mono_msec() + delay
	if not dirty or _due < 0 or due < _due:
		_due = due
	dirty = true


func set_value(key: String, value: Variant, urgent: bool = false) -> void:
	data[key] = value
	mark_dirty(urgent)


func due_in_ms() -> int:
	if not dirty or _due < 0:
		return -1
	return maxi(0, _due - clock.mono_msec())


func poll() -> bool:
	if not dirty or _due < 0:
		return false
	if clock.mono_msec() < _due:
		return false
	return flush()


func flush(force: bool = false) -> bool:
	if locked:
		return false
	if not dirty and not force:
		return true
	if before_save.is_valid():
		before_save.call(data)
	data["ver"] = SAVE_VER
	var ok: = save.write(JSON.stringify(data), _validate)
	last_flush_ok = ok
	if ok:
		dirty = false
		_due = -1
		writes += 1
		if status == "recovered" or status == "damaged":
			status = "loaded"
			loaded_from = save.path
	else:
		dirty = true
		_due = clock.mono_msec() + RETRY_MS
	flushed.emit(ok)
	return ok


func on_pause() -> bool:
	return flush() if dirty else true


func on_exit() -> bool:
	return flush() if dirty else true


# ── hash / module versions ─────────────────────────────────────────────────────────────────────────────────────

static func canonical(d: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(d)), "", true)


static func state_hash_of(d: Variant) -> String:
	return canonical(d).sha256_text()


func state_hash() -> String:
	return state_hash_of(data)


func module_ver(id: String) -> int:
	var mv = data.get("mod_ver")
	if mv is Dictionary:
		return int(mv.get(id, 0))
	return 0


func set_module_ver(id: String, v: int) -> void:
	if not (data.get("mod_ver") is Dictionary):
		data["mod_ver"] = {}
	data.mod_ver[id] = v
	mark_dirty()
