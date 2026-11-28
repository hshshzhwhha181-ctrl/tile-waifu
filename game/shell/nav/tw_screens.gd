class_name TWScreens
extends Node

# TWScreens (P23 / WP8a): the v11 screen manager. A state machine (IDLE / TRANSITIONING) with a hard watchdog, a history
# stack, tabs and a registry filled by scanning ScreenSpec resources. It is a plain Node with a class_name and NOT an
# autoload yet (project.godot belongs to the integrator, and a class_name equal to an autoload name is a Godot error: if it is
# ever autoloaded, register it under another name, e.g. `Screens`, or keep a single instance in TWContext.screens).
#
# Navigation
#   go(id, params = {}, opts = {}) -> Signal      mount a screen. The Signal (`done(ok: bool, reason: String)`) fires on the
#                                                 NEXT idle frame, also when the work was instant, so `await screens.go(..)` never
#                                                 hangs. ok=false: reason is "unknown" | "locked" | "busy" | "instantiate"
#                                                 (go_tab adds "same"); ok=true with reason "watchdog" = the intro animation was force-finished
#                                                 opts: replace (do not push the current screen)
#   back() -> String                              the one Android-back handler: "busy" (ignored while TRANSITIONING) | "modal" (the
#                                                 top modal closed) | "screen" (on_back consumed it) | "blocked" (can_back false) |
#                                                 "history" | "back_target" | "exit" (exit_requested emitted)
#   go_tab(tab) -> Signal                         the remembered screen of a tab, else its root; a tab switch clears the history
#   state, current_id, current, history, tab      read-only for the shell
#
# TRANSITIONING lasts from the moment go() commits until the new screen's intro() Signal fires. If it does not fire within
# WATCHDOG_MS (3000) poll() force-finishes: intro_forced() on the screen, `watchdog_fired`, state back to IDLE. poll() runs from
# _process; tests drive it with `now_fn` (a fake monotonic clock, default ctx.clock.mono_msec else the engine ticks).
#
# Modal stack (another lane): `modals` is duck-typed: clear_all(reason) is called before every mount, handle_back() -> bool
# first on back(). Both are optional.
#
# History rules: the screen being left is pushed unless it is transient (spec.keep_history == false), the same id (params
# refresh), `replace` is set, or the move is a back(); entering a tab root clears the history; at most HISTORY_MAX entries.

signal screen_changed(id: String, from_id: String)
signal transition_finished(id: String, forced: bool)
signal watchdog_fired(id: String)
signal exit_requested
signal nav_rejected(id: String, reason: String)

enum State { IDLE, TRANSITIONING }

const WATCHDOG_MS: = 3000
const HISTORY_MAX: = 32
const DEFAULT_ROOT: = "res://shell/screens"

var ctx: TWContext = null
var host: Node = null                 # parent of the mounted screen; defaults to this node
var modals: Object = null
var unlock_check: Callable = Callable()   # (rule: String) -> bool
var now_fn: Callable = Callable()         # () -> int monotonic msec

var state: int = State.IDLE
var current: TWScreen = null
var current_id: = ""
var current_params: Dictionary = {}
var history: Array = []               # [{id, params}]
var tab: = ""
var registry: Dictionary = {}         # id -> ScreenSpec
var rejects: Array = []               # [{id, reason}] everything register() refused
var watchdog_count: = 0
var nav_count: = 0

var _tab_last: Dictionary = {}        # tab -> {id, params}
var _gen: = 0                         # transition generation: a stale intro signal is ignored
var _started_ms: = 0
var _nav: _Nav = null
var _pending: Array = []             # navs whose `done` Signal has not been emitted yet


# the object go() hands out; `done` is emitted on a later idle frame
class _Nav extends RefCounted:
	signal done(ok: bool, reason: String)
	var ok: = false
	var reason: = ""
	var emitted: = false
	var keep: Array = []           # the manager's list of pending navs: a Signal does not keep its object alive

	func _init(pending: Array = []) -> void:
		keep = pending
		keep.append(self)

	func finish(p_ok: bool, p_reason: String) -> void:
		ok = p_ok
		reason = p_reason
		call_deferred("_emit")

	func _emit() -> void:
		if not emitted:
			emitted = true
			done.emit(ok, reason)
		keep.erase(self)


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	poll()


# ── registry ────────────────────────────────────────────────────────────────────────────────────────────────

func register(spec: ScreenSpec) -> bool:
	if spec == null:
		rejects.append({"id": "", "reason": "SCREEN_HAS_SPEC: no ScreenSpec"})
		return false
	var why: = spec.validate()
	if why == "" and registry.has(spec.id) and registry[spec.id] != spec:
		why = "id: '%s' is already registered" % spec.id
	if why != "":
		rejects.append({"id": spec.id, "reason": why})
		return false
	registry[spec.id] = spec
	return true


# Directory scan: every sub-folder of `root` is one screen. spec.tres present -> loaded and registered; a folder that has a
# screen.gd but no (valid) spec.tres is refused with SCREEN_HAS_SPEC. Returns {registered: [ids], rejected: [{dir, reason}]}.
func scan(root: String = DEFAULT_ROOT) -> Dictionary:
	var rep: = {"registered": [], "rejected": []}
	var d: = DirAccess.open(root)
	if d == null:
		return rep
	var dirs: = Array(d.get_directories())
	dirs.sort()
	for sub in dirs:
		var dir: String = root.path_join(sub)
		var files: = _list(dir)
		var spec_path: = dir.path_join("spec.tres")
		if not files.has("spec.tres"):
			if files.has("screen.gd"):
				rep.rejected.append({"dir": dir, "reason": "SCREEN_HAS_SPEC: screen.gd without spec.tres"})
				rejects.append({"id": sub, "reason": "SCREEN_HAS_SPEC: screen.gd without spec.tres"})
			continue
		var res = load(spec_path)
		if not (res is ScreenSpec):
			rep.rejected.append({"dir": dir, "reason": "SCREEN_HAS_SPEC: spec.tres is not a ScreenSpec"})
			rejects.append({"id": sub, "reason": "SCREEN_HAS_SPEC: spec.tres is not a ScreenSpec"})
			continue
		if register(res):
			rep.registered.append(res.id)
		else:
			rep.rejected.append({"dir": dir, "reason": rejects[-1].reason})
	return rep


func _list(dir: String) -> PackedStringArray:
	var out: = PackedStringArray()
	var d: = DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(f.trim_suffix(".remap"))      # exported resources are listed as <name>.remap
	return out


func has_screen(id: String) -> bool:
	return registry.has(id)


func tabs() -> PackedStringArray:
	var out: = PackedStringArray()
	for id in registry:
		var t: String = registry[id].tab
		if t != "" and not out.has(t):
			out.append(t)
	out.sort()
	return out


func tab_root(t: String) -> String:
	for id in registry:
		var s: ScreenSpec = registry[id]
		if s.tab == t and s.is_tab_root:
			return id
	return ""


func is_busy() -> bool:
	return state == State.TRANSITIONING


# ── time / watchdog ─────────────────────────────────────────────────────────────────────────────────────────

func now_ms() -> int:
	if now_fn.is_valid():
		return int(now_fn.call())
	if ctx != null and ctx.clock != null:
		return ctx.clock.mono_msec()
	return Time.get_ticks_msec()


# true when the watchdog fired in this call
func poll() -> bool:
	if state != State.TRANSITIONING:
		return false
	if now_ms() - _started_ms < WATCHDOG_MS:
		return false
	_force_finish()
	return true


func _force_finish() -> void:
	watchdog_count += 1
	var id: = current_id
	_gen += 1                                 # the intro signal, if it ever fires, is now stale
	if current != null and is_instance_valid(current):
		current.intro_forced()
	watchdog_fired.emit(id)
	_finish(true)


# ── navigation ──────────────────────────────────────────────────────────────────────────────────────────────

func go(id: String, params: Dictionary = {}, opts: Dictionary = {}) -> Signal:
	var nav: = _Nav.new(_pending)
	var why: = _precheck(id)
	if why != "":
		return _reject(nav, id, why)
	var spec: ScreenSpec = registry[id]
	var inst: = _instantiate(spec)
	if inst == null:
		return _reject(nav, id, "instantiate")
	var from_id: = current_id
	var back_move: bool = bool(opts.get("_back", false))
	# history: decided before the old screen goes away
	if back_move:
		pass
	elif spec.is_tab_root:
		history.clear()
	elif current != null and not bool(opts.get("replace", false)) and from_id != id and _keeps_history(from_id):
		history.append({"id": from_id, "params": current_params})
		while history.size() > HISTORY_MAX:
			history.pop_front()
	# teardown + mount
	if modals != null and modals.has_method("clear_all"):
		modals.clear_all("go:" + id)
	_unmount()
	state = State.TRANSITIONING
	_started_ms = now_ms()
	_gen += 1
	var gen: = _gen
	_nav = nav
	nav_count += 1
	current = inst
	current_id = id
	current_params = params
	inst.ctx = ctx
	inst.spec = spec
	inst.params = params
	inst.name = id
	(host if host != null else self).add_child(inst)
	tab = spec.tab
	if spec.tab != "":
		_tab_last[spec.tab] = {"id": id, "params": params}
	screen_changed.emit(id, from_id)
	inst.enter(params)
	var sig: Signal = inst.intro()
	if sig.is_null():
		_finish(false)
	else:
		sig.connect(func(..._args): _on_intro(gen), CONNECT_ONE_SHOT)
	return nav.done


func _on_intro(gen: int) -> void:
	if gen != _gen or state != State.TRANSITIONING:
		return
	_finish(false)


func _finish(forced: bool) -> void:
	state = State.IDLE
	var nav: = _nav
	_nav = null
	transition_finished.emit(current_id, forced)
	if nav != null:
		nav.finish(true, "watchdog" if forced else "")


func _precheck(id: String) -> String:
	if state == State.TRANSITIONING:
		return "busy"
	if not registry.has(id):
		return "unknown"
	var rule: String = registry[id].unlock_rule
	if rule != "" and unlock_check.is_valid() and not bool(unlock_check.call(rule)):
		return "locked"
	return ""


func _reject(nav: _Nav, id: String, why: String) -> Signal:
	nav_rejected.emit(id, why)
	nav.finish(false, why)
	return nav.done


func _keeps_history(id: String) -> bool:
	var s: ScreenSpec = registry.get(id)
	return s != null and s.keep_history


func _instantiate(spec: ScreenSpec) -> TWScreen:
	var n: Object = null
	if spec.scene != "":
		var ps = load(spec.scene)
		if ps is PackedScene:
			n = (ps as PackedScene).instantiate()
	else:
		var sc = load(spec.script_path)
		if sc is Script and (sc as Script).can_instantiate():
			n = (sc as Script).new()
	if n is TWScreen:
		return n
	if n != null and n is Node:
		(n as Node).free()
	return null


func _unmount() -> void:
	if current == null:
		return
	if is_instance_valid(current):
		current.exit()
		var p: = current.get_parent()
		if p != null:
			p.remove_child(current)
		if is_inside_tree():
			current.queue_free()
		else:
			current.free()
	current = null


func go_tab(t: String, params: Dictionary = {}) -> Signal:
	var target: Dictionary = _tab_last.get(t, {})
	var id: String = str(target.get("id", ""))
	if id == "" or not registry.has(id):
		id = tab_root(t)
	var nav: = _Nav.new(_pending)
	if id == "":
		return _reject(nav, t, "unknown")
	if state == State.IDLE and id == current_id and t == tab:
		return _reject(nav, id, "same")
	history.clear()
	return go(id, params if not params.is_empty() else target.get("params", {}), {"replace": true})


func back() -> String:
	if state == State.TRANSITIONING:
		return "busy"
	if modals != null and modals.has_method("handle_back") and bool(modals.handle_back()):
		return "modal"
	if current != null and current.on_back():
		return "screen"
	if current != null and not current.can_back():
		return "blocked"
	while not history.is_empty():
		var e: Dictionary = history.pop_back()
		if registry.has(e.id):
			go(e.id, e.params, {"_back": true})
			return "history"
	var bt: String = ""
	if current != null and current.spec != null:
		bt = current.spec.back_target
	if bt != "" and registry.has(bt):
		go(bt, {}, {"_back": true})
		return "back_target"
	exit_requested.emit()
	return "exit"


func history_ids() -> PackedStringArray:
	var out: = PackedStringArray()
	for e in history:
		out.append(e.id)
	return out


# tests / app restart: drop the screen and every stack, keep the registry
func reset() -> void:
	_gen += 1
	_unmount()
	state = State.IDLE
	current_id = ""
	current_params = {}
	history.clear()
	tab = ""
	_tab_last.clear()
	_nav = null


func _exit_tree() -> void:
	if current != null and is_instance_valid(current) and current.get_parent() == null:
		current.free()
