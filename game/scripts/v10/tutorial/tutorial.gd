class_name V10Tutorial
extends Node
# Orchestrator (README §2.6). One node under main (process ALWAYS):
#   - watches the screen (main.screen_root.child_entered_tree + a frame, and a 0.25 s timer on main.screen_id);
#   - plays at most ONE intro per screen arrival and at most ONE «new system» per entry into the Чайная (UX О-1);
#   - owns the single V10Coach shared by the match driver (V10TutMatch) and by other lanes (say());
#   - registers the dynamic tut_id providers (tiles of the first match, 0.9 victory/levels/help nodes).
# Never shows anything while main.busy, during a transition, a V6Story scene, a full-screen view (title), a popup or
# a sheet. A spotlight whose target disappears ends («lost»); a watchdog closes any step the coach forgets.
#
# Observable state (tests, bot): V10Tutorial.shown (ids in show order), inst.step (id on the coach now, "" = none),
# inst.coach (V10Coach: current_rect() is the window to tap), inst.arrivals, inst.match_driver (V10TutMatch).

const TICK: = 0.25
const MAX_TRIES: = 3          # an intro whose target is never found: retried on the next entries, then dropped
const HUB_DIM: = 0.72
const MATCH_SCREENS: = ["play", "arena", "v7play"]
const VICTORY_SETTLE: = 1.6   # stars stamp in before v_stars

static var inst: V10Tutorial
static var shown: Array = []  # every intro / line id the coach was asked to show this launch, in order

var main: Node
var coach: V10Coach
var step: = ""                # id of the step on the coach ("" = none)
var owner_kind: = ""          # "intro" | "match" | "say" | "victory"
var match_driver: V10TutMatch
var arrivals: = 0
var settle: = 0.8             # s after an arrival before a hub intro may play (tests set 0)

var _cb: = Callable()
var _deadline: = 0.0
var _timer: Timer
var _last_sid: = "<none>"
var _last_screen: WeakRef = null
var _arr_t: = 0.0
var _arr_shown: = false
var _next_try: = 0.0
var _entry_system: = false
var _entry_postponed: = false
var _eq_seen: = false
var _missed: = {}
var _replay_id: = ""
var _say_q: Array = []
var _vic_t: = -1.0


# ---------------------------------------------------------------- public API (static) -------------------------------

static func attach(m: Node) -> V10Tutorial:
	if m == null:
		return null
	if inst != null and is_instance_valid(inst):
		if inst.main == m:
			return inst
		inst.queue_free()
	V10TutState.st()
	var t: = V10Tutorial.new()
	t.name = "V10Tutorial"
	t.main = m
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	inst = t
	_register_providers()
	m.add_child(t)
	return t


static func main_node() -> Node:
	return inst.main if inst != null and is_instance_valid(inst) else null


static func owns_first_match() -> bool:
	return inst != null and is_instance_valid(inst)


static func is_open(id: String) -> bool:
	return V10Reveal.is_open(id)


static func locked_tap(id: String, at) -> void:
	var txt: = V10Reveal.locked_text(id)
	if txt == "":
		return
	var r: = Rect2()
	if at is Rect2:
		r = at
	elif at is Node and is_instance_valid(at):
		r = V10TutTarget.rect_of(at)
	V10TutHelp.locked_toast(_host(), r, txt)


static func help(screen_id: = "") -> void:
	var sid: = screen_id
	var m: = main_node()
	if sid == "" and m != null:
		sid = String(m.get("screen_id"))
	if inst != null and is_instance_valid(inst):
		inst._yield_coach()
	V10TutHelp.open(_host(), V10TutHelp.topic_for_screen(sid))


static func how_to() -> void:
	if inst != null and is_instance_valid(inst):
		inst._yield_coach()
	V10TutHelp.open_how_to(_host())


# Shared coach for other lanes: one heroine line (+ optional spotlight), same look as the tutorial.
# opts: speaker, mode ("tap" with a target, else "wait"), dim, place, anchor, avoid, hold, timeout, portrait,
#       force (show even with hints off), on_done: Callable(result)
static func say(line: String, target_id: = "", opts: = {}) -> void:
	if inst == null or not is_instance_valid(inst) or line.strip_edges() == "":
		return
	if not V10TutState.hints_on() and not bool(opts.get("force", false)):
		return
	inst._say_q = inst._say_q.filter(func(q): return String(q.line) != line)
	if inst._say_q.size() >= 3:
		inst._say_q.pop_front()
	inst._say_q.append({"line": line, "target": target_id, "opts": opts})
	inst._tick.call_deferred()


static func event(ev_name: String, data: = {}) -> void:
	match ev_name:
		"replay_first_match":
			V10TutMatch.replay_l1 = true
			for k in V10TutLines.MATCH:
				if String(k).begins_with("m_") or String(k).begins_with("v_"):
					V10TutState.unmark(String(k))
			V10TutState.save()
			var m: = main_node()
			if bool(data.get("go", true)) and m != null and m.has_method("go"):
				V10TutHelp.close_all(_host())
				m.call("go", "play", {"level": 0, "partner": "mc"})
		"salon_done":
			# the salon lane ran its own first visit: the lantern intro has nothing left to show
			V10TutState.mark("lantern_salon")
			V10TutState.save()
		_:
			pass  # first_pick / partner_set / rank_up: gates read G.S live; just look again
	if inst != null and is_instance_valid(inst):
		inst._next_try = 0.0
		inst._tick.call_deferred()


static func replay(intro_id: String) -> void:
	V10TutState.unmark(intro_id)
	var d: = V10TutState.st()
	if d.get("tries", null) is Dictionary:
		(d.tries as Dictionary).erase(intro_id)
	V10TutState.save()
	if inst != null and is_instance_valid(inst):
		inst._replay_id = intro_id
		inst._next_try = 0.0
		inst._tick.call_deferred()


static func skip_all() -> void:
	V10TutState.skip()
	if inst == null or not is_instance_valid(inst):
		return
	inst._say_q.clear()
	inst._replay_id = ""
	if inst.match_driver != null and is_instance_valid(inst.match_driver):
		inst.match_driver.halt()
	V10TutMatch.victory_pending = false
	if inst._showing():
		inst._cb = Callable()
		inst.coach.complete("skip")


static func busy() -> bool:
	return inst != null and is_instance_valid(inst) and inst._showing()


# ---------------------------------------------------------------- coach (shared) ------------------------------------

# Show one step on the shared coach. false when the coach is busy (the caller keeps it queued).
func show_spec(spec: Dictionary, kind: String, cb: = Callable()) -> bool:
	if _showing():
		return false
	var c: = _coach_node()
	if c == null:
		return false
	step = String(spec.get("id", "say"))
	owner_kind = kind
	_cb = cb
	var lim: = maxf(float(spec.get("timeout", 8.0)), float(spec.get("hold", 4.0)))
	_deadline = _now() + lim + 4.0
	shown.append(step)
	if not spec.has("root"):
		spec["root"] = main
	c.show_step(spec)
	return true


# The game did what the step asked (tile taken, pair made, ult cast): close it.
func complete_step(result: = "target", kind: = "") -> void:
	if kind != "" and owner_kind != kind:
		return
	if _showing():
		coach.complete(result)
	elif owner_kind != "":
		_on_coach_finished(result)


# The owner goes away (screen freed): close its step without calling back into it.
func release(kind: String) -> void:
	if owner_kind != kind:
		return
	_cb = Callable()
	complete_step("lost", kind)


func _coach_node() -> V10Coach:
	if coach != null and is_instance_valid(coach) and coach.is_inside_tree():
		return coach
	if main == null or not is_instance_valid(main) or not main.is_inside_tree():
		return null
	var l: = V10Coach.layer(main)
	if l == null:
		return null
	coach = V10Coach.new()
	coach.name = "V10Coach"
	coach.finished.connect(_on_coach_finished)
	l.add_child(coach)
	return coach


func _showing() -> bool:
	return coach != null and is_instance_valid(coach) and coach.is_showing()


func _on_coach_finished(result: String) -> void:
	var cb: = _cb
	_cb = Callable()
	owner_kind = ""
	step = ""
	_deadline = 0.0
	if result == "skip":
		skip_all()
	if cb.is_valid():
		cb.call(result)


# «?» / «Как играть» open a sheet: one window at a time, the coach gives way.
func _yield_coach() -> void:
	if _showing():
		complete_step("lost")


func _watchdog() -> void:
	if owner_kind == "":
		return
	if not _showing():
		# the coach went away without a word (freed, replaced): settle the step
		_on_coach_finished("lost")
	elif _deadline > 0.0 and _now() > _deadline:
		coach.complete("timeout")


# ---------------------------------------------------------------- screen watching -----------------------------------

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = TICK
	_timer.autostart = true
	_timer.timeout.connect(_tick)
	add_child(_timer)
	var sr = main.get("screen_root") if main != null else null
	if sr is Node:
		(sr as Node).child_entered_tree.connect(_on_screen_child)
	_tick.call_deferred()


func _exit_tree() -> void:
	if match_driver != null and is_instance_valid(match_driver):
		match_driver.stop()
	if coach != null and is_instance_valid(coach):
		coach.queue_free()
	if inst == self:
		inst = null


func _on_screen_child(_n: Node) -> void:
	# fires inside main.go() before build(): look one frame later
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree():
		_tick()


func _tick() -> void:
	if main == null or not is_instance_valid(main):
		return
	_watchdog()
	var sid: = String(main.get("screen_id"))
	var scr = main.get("screen")
	if sid != _last_sid or not _same_screen(scr):
		_arrive(sid, scr)
	_match_watch(sid, scr)
	if _hard_blocked():
		return
	var popup: = _popup_open()
	if not popup and not _say_q.is_empty() and not _showing():
		_say_next(sid)
	if _showing():
		return
	if V10TutMatch.victory_pending and not sid in MATCH_SCREENS and not popup:
		_victory_elsewhere(sid)
		return
	if sid in MATCH_SCREENS or sid == "":
		return
	if _arr_shown and _replay_id == "":
		return
	var t: = _now()
	if t - _arr_t < settle or t < _next_try:
		return
	_next_try = t + 1.0
	_try_intro(sid, popup)


func _same_screen(scr) -> bool:
	var prev: Object = _last_screen.get_ref() if _last_screen != null else null
	if scr == null or not is_instance_valid(scr):
		return prev == null
	return prev == scr


func _arrive(sid: String, scr) -> void:
	_last_sid = sid
	_last_screen = weakref(scr) if scr is Object and is_instance_valid(scr) else null
	arrivals += 1
	_arr_t = _now()
	_arr_shown = false
	_next_try = 0.0
	# a hub intro / a line of the previous screen does not follow the player
	if _showing() and (owner_kind == "intro" or owner_kind == "say" or owner_kind == "victory"):
		complete_step("lost")
	if sid == "home":
		var d: = V10TutState.st()
		d.entries = int(d.get("entries", 0)) + 1
		_entry_system = false
		_entry_postponed = false
		_missed.clear()


func _match_watch(sid: String, scr) -> void:
	if match_driver != null and not is_instance_valid(match_driver):
		match_driver = null
	if match_driver != null and match_driver.screen != scr:
		match_driver.stop()
		match_driver = null
	if match_driver == null and sid == "play" and scr is Node and is_instance_valid(scr) and scr.get("board") is TrayBoard:
		match_driver = V10TutMatch.attach_to(self, scr)


# main.busy, a transition, a story scene, a full-screen view over everything (title, profile card) or a sheet.
func _hard_blocked() -> bool:
	if bool(main.get("busy")):
		return true
	var tm = main.get("trans_mat")
	if tm is ShaderMaterial:
		var pv = (tm as ShaderMaterial).get_shader_parameter("progress")
		if (pv is float or pv is int) and float(pv) > 0.02:
			return true
	var vs: = _vs()
	var skip: = [main.get("screen_root"), main.get("topbar"), main.get("navbar"), main.get("overlay"),
		main.get("trans"), main.get("finger")]
	for c in main.get_children():
		if c == self or c in skip or not (c is Control):
			continue
		var cc: = c as Control
		if not cc.visible:
			continue
		if c is V6StoryScene or (cc.size.x >= vs.x * 0.8 and cc.size.y >= vs.y * 0.8):
			return true
	if _sheet_open():
		return true
	return false


# Common.popup / v8_back views / large sheets on main.overlay.
func _popup_open() -> bool:
	var ov = main.get("overlay")
	if not (ov is Node):
		return false
	var vs: = _vs()
	for c in (ov as Node).get_children():
		if not (c is Control) or not (c as Control).visible or c.is_queued_for_deletion():
			continue
		if c.has_meta("popup") or c.has_meta("v8_back") or (c as Control).size.y >= vs.y * 0.6:
			return true
	return false


# A «?» / «Как играть» sheet (or anything else) on the tutorial layer besides the coach.
func _sheet_open() -> bool:
	var l: = get_tree().root.get_node_or_null("V10TutLayer") if is_inside_tree() else null
	if l == null:
		return false
	for c in l.get_children():
		if c == coach or not (c is CanvasItem) or c.is_queued_for_deletion():
			continue
		if (c as CanvasItem).visible:
			return true
	return false


# ---------------------------------------------------------------- intros --------------------------------------------

func _try_intro(sid: String, popup: bool) -> void:
	var forced_ok: = _replay_id != ""
	if not V10TutState.hints_on() and not forced_ok:
		return
	if sid == "home" and not _eq_seen and _eq_shown():
		# the entry queue showed its full-screen scene on this entry: the intro waits for the next one
		_eq_seen = true
		_entry_postponed = true
	var cands: = V10Reveal.due_intros(sid)
	if _replay_id != "" and cands.has(_replay_id):
		cands.erase(_replay_id)
		cands.push_front(_replay_id)
	for id in cands:
		var e: Dictionary = V10TutLines.INTROS[id]
		var forced: bool = id == _replay_id
		if not forced and (_arr_shown or not V10TutState.hints_on()):
			continue
		var anywhere: = String(e.get("screen", "")) == "*"
		if popup and not (anywhere and String(e.get("mode", "")) == "wait"):
			continue
		if bool(e.get("system", false)) and not forced and (_entry_system or _entry_postponed):
			continue
		var tg: = String(e.get("target", ""))
		if tg != "" and not V10TutTarget.find(main, tg).ok:
			if not anywhere:
				_miss(id)
			continue
		_show_intro(id)
		return


func _miss(id: String) -> void:
	if _missed.has(id):
		return
	_missed[id] = true
	var d: = V10TutState.st()
	if not (d.get("tries", null) is Dictionary):
		d["tries"] = {}
	var n: = int(d.tries.get(id, 0)) + 1
	d.tries[id] = n
	if n >= MAX_TRIES:
		V10TutState.mark(id)
		V10TutState.save()


func _show_intro(id: String) -> void:
	var e: Dictionary = V10TutLines.INTROS[id]
	var mode: = String(e.get("mode", "tap"))
	var spec: = {
		"id": id,
		"line": V10TutLines.intro_line(id),
		"speaker": speaker_of(String(e.get("speaker", "partner"))),
		"portrait": not _heroine_visible(),
		"target": String(e.get("target", "")),
		"mode": mode,
		"dim": HUB_DIM if mode == "tap" or mode == "do" else 0.0,
		"place": "auto",
		"ctx": "hub",
		"avoid": _face_avoid(),
		"hold": 4.0,
		"timeout": 12.0 if mode == "do" else 8.0,
		"skippable": false,
		"root": main,
	}
	if show_spec(spec, "intro", func(res: String): _intro_done(id, res)):
		_arr_shown = true
		if bool(e.get("system", false)):
			_entry_system = true


func _intro_done(id: String, _res: String) -> void:
	V10TutState.mark(id)
	V10TutState.save()
	if _replay_id == id:
		_replay_id = ""


static func speaker_of(s: String) -> String:
	if s == "partner" or s == "":
		var p: = "mc"
		if G != null and G.S is Dictionary:
			p = String(G.S.get("partner", "mc"))
		return p if p != "" else "mc"
	return s


func _heroine_visible() -> bool:
	if V10TutTarget.find(main, "home.hero").ok:
		return true
	var scr = main.get("screen")
	if scr is Object and is_instance_valid(scr):
		var h = scr.get("hero") if "hero" in scr else null
		if h is CanvasItem and is_instance_valid(h) and (h as CanvasItem).is_visible_in_tree():
			return true
	return false


func _face_avoid() -> Array:
	var scr = main.get("screen")
	if not (scr is Object) or not is_instance_valid(scr):
		return []
	if scr.has_method("hero_face_global"):
		var r = scr.call("hero_face_global")
		if r is Rect2:
			return [(r as Rect2).grow(48.0)]
	var h = scr.get("hero") if "hero" in scr else null
	if h is Node2D and is_instance_valid(h) and h.has_method("face_local"):
		var p: Vector2 = (h as Node2D).get_global_transform_with_canvas() * Vector2(h.call("face_local"))
		return [Rect2(p - Vector2(90, 90), Vector2(180, 180)).grow(48.0)]
	return []


func _eq_shown() -> bool:
	return not V10EntryQueue.shown_this_launch().is_empty()


# ---------------------------------------------------------------- say() queue / victory elsewhere --------------------

func _say_next(sid: String) -> void:
	var q: Dictionary = _say_q.pop_front()
	var opts: Dictionary = q.opts
	var tg: = String(q.target)
	var in_match: = sid in MATCH_SCREENS
	var mode: = String(opts.get("mode", "tap" if tg != "" else "wait"))
	var spec: = {
		"id": String(opts.get("id", "say")),
		"line": String(q.line),
		"speaker": speaker_of(String(opts.get("speaker", "partner"))),
		"portrait": bool(opts.get("portrait", not in_match and not _heroine_visible())),
		"target": tg,
		"mode": mode,
		"dim": float(opts.get("dim", 0.0 if in_match or mode == "wait" else HUB_DIM)),
		"place": String(opts.get("place", "hero" if in_match else "auto")),
		"ctx": String(opts.get("ctx", "match" if in_match else "hub")),
		"avoid": opts.get("avoid", _face_avoid()),
		"hold": float(opts.get("hold", 4.0)),
		"timeout": float(opts.get("timeout", 8.0)),
		"skippable": false,
		"root": main,
	}
	if in_match and match_driver != null and is_instance_valid(match_driver):
		spec["anchor"] = opts.get("anchor", match_driver.hero_anchor())
		spec["avoid"] = opts.get("avoid", match_driver.avoid_rects())
	elif opts.has("anchor"):
		spec["anchor"] = opts.anchor
	var cb: Callable = opts.get("on_done", Callable())
	show_spec(spec, "say", cb)


# The first-match victory ended up on another screen (a HUD v2 victory screen): v_stars, then v_home there.
func _victory_elsewhere(sid: String) -> void:
	if sid == "home" or not V10TutState.hints_on():
		V10TutMatch.victory_pending = false
		return
	if _vic_t < 0.0:
		_vic_t = _now()
	if _now() - _vic_t < VICTORY_SETTLE:
		return
	var key: = ""
	if not V10TutState.seen("v_stars") and V10TutTarget.find(main, "win.stars").ok:
		key = "v_stars"
	elif not V10TutState.seen("v_home") and V10TutTarget.find(main, "win.home").ok:
		key = "v_home"
	if key == "":
		if _now() - _vic_t > 8.0:
			V10TutMatch.victory_pending = false
			_vic_t = -1.0
		return
	var e: Dictionary = V10TutLines.MATCH[key]
	var spec: = {
		"id": key, "line": V10TutLines.match_line(key), "speaker": "mc", "portrait": false,
		"target": String(e.target), "mode": String(e.mode), "dim": 0.0, "place": "auto", "ctx": "work",
		"hold": 4.0, "timeout": 15.0, "skippable": false, "root": main,
	}
	show_spec(spec, "victory", func(_r: String):
		V10TutState.mark(key)
		V10TutState.save()
		if key == "v_home":
			V10TutMatch.victory_pending = false
			_vic_t = -1.0)


# ---------------------------------------------------------------- dynamic providers ---------------------------------
# Providers answer only for the 0.9 nodes they know; otherwise null, and V10TutTarget goes on to tags / fallbacks.

static func _register_providers() -> void:
	V10TutTarget.provide("match.tile_a", func(): return V10TutMatch.tile_rect(0))
	V10TutTarget.provide("match.tile_b", func(): return V10TutMatch.tile_rect(1))
	V10TutTarget.provide("match.board", func(): return _p_board())
	V10TutTarget.provide("match.help", func(): return _p_help())
	V10TutTarget.provide("win.stars", func(): return _p_win_stars())
	V10TutTarget.provide("win.home", func(): return _p_win_home())
	V10TutTarget.provide("tables.play", func(): return _p_tables_play())


static func _scr() -> Object:
	var m: = main_node()
	if m == null:
		return null
	var s = m.get("screen")
	return s if s is Object and is_instance_valid(s) else null


static func _vis(n) -> bool:
	return n is CanvasItem and is_instance_valid(n) and (n as CanvasItem).is_inside_tree() \
		and (n as CanvasItem).is_visible_in_tree() and not (n as Node).is_queued_for_deletion()


# the field: HUD v2 board_rect(), or the 0.9 play-local board_rect in viewport px
static func _p_board():
	var s: = _scr()
	if s == null or not (s is Control) or not ("board_rect" in s):
		return null
	for k in ["hud", "hud2"]:
		var h = s.get(k) if k in s else null
		if h is V10HudMatch and is_instance_valid(h):
			return {"rect": (h as V10HudMatch).board_rect(), "radius": 4.0}
	var br: Rect2 = s.get("board_rect")
	if br.size.x < 2.0:
		return null
	return {"rect": (s as Control).get_global_transform_with_canvas() * br, "radius": 4.0}


# 0.9: the three help buttons as one row (HUD v2 answers through the fallback s:hud.help_row)
static func _p_help():
	var s: = _scr()
	if s == null or not ("btn_hint" in s) or s.get("hud") != null:
		return null
	var r: = Rect2()
	for k in ["btn_undo", "btn_hint", "btn_shuffle"]:
		var b = s.get(k)
		if _vis(b) and b is Control:
			var rb: = V10TutTarget.rect_of(b)
			r = rb if r.size == Vector2.ZERO else r.merge(rb)
	return {"rect": r, "radius": 4.0} if r.size.x > 2.0 else null


# 0.9 victory window: the three star sockets (104 px) on V8Result/Plate
static func _p_win_stars():
	var s: = _scr()
	if s == null or not ("victory_next_btn" in s) or not (s is Node):
		return null
	var plate: = (s as Node).get_node_or_null("V8Result/Plate")
	if plate == null or not _vis(plate):
		return null
	var r: = Rect2()
	var n: = 0
	for c in plate.get_children():
		if c is Control and absf((c as Control).size.x - 104.0) < 1.0 and absf((c as Control).size.y - 104.0) < 1.0:
			var rc: = V10TutTarget.rect_of(c)
			r = rc if n == 0 else r.merge(rc)
			n += 1
			if n == 3:
				break
	return {"rect": r.grow(8.0), "radius": 4.0} if n > 0 else null


# 0.9 victory window: the second button is «На главную» while Желания are closed
static func _p_win_home():
	var s: = _scr()
	if s == null or not ("victory_summon_btn" in s):
		return null
	var b = s.get("victory_summon_btn")
	if not _vis(b) or (G != null and G.has_method("summon_open") and bool(G.summon_open())):
		return null
	return {"rect": V10TutTarget.rect_of(b), "radius": 4.0, "node": b}


# 0.9 «Столы» = levels screen: its «Партия N» button
static func _p_tables_play():
	var m: = main_node()
	var s: = _scr()
	if m == null or s == null or String(m.get("screen_id")) != "levels" or not ("play_btn" in s):
		return null
	var b = s.get("play_btn")
	if not _vis(b):
		return null
	var r: = V10TutTarget.rect_of(b)
	return {"rect": r, "radius": r.size.y * 0.5, "node": b}


# ---------------------------------------------------------------- helpers -------------------------------------------

static func _host() -> Node:
	var m: = main_node()
	if m != null and m.is_inside_tree():
		return m
	var ml: = Engine.get_main_loop()
	if ml is SceneTree:
		var st: = ml as SceneTree
		return st.current_scene if st.current_scene != null else st.root
	return null


func _vs() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(720, 1280)


static func _now() -> float:
	return Time.get_ticks_msec() * 0.001
