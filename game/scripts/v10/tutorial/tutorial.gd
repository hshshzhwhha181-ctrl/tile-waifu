class_name V10Tutorial
extends Node

# V10Tutorial — onboarding for 0.10: the guided first run with Маджонг-тян (V10TutSteps), first-time tips for
# every feature (V10TutTips) and the «Как играть» encyclopedia (V10Help). Integration: README.md next to this file.
#
#   V10Tutorial.attach(main)            once, at the end of main._ready() (after go("home")). Everything else is
#                                       automatic: it watches main.screen_id / main.screen every frame.
#   V10Tutorial.event(name, data = {})  a feature tells the tutorial something happened ("settings", "streak", …)
#   V10Tutorial.owns_first_match()      true while the guided first match is ours (play.gd skips its 0.9 finger)
#   V10Tutorial.help(main, topic = "")  opens «Как играть» (settings row, «?» buttons)
#   V10Tutorial.replay(chapter = "")    from «Как играть»: the guided chapters come back
#   V10Tutorial.skip_all()              «Пропустить обучение» (confirmed in the coach)
#   V10Tutorial.busy()                  a coach-mark is on screen (other overlays may wait)
#
# One coach on screen at a time; never more than one tip per screen visit; nothing during a guided step.

const LAYER: = 90
const TIP_DELAY: = 0.9

static var inst: V10Tutorial

var main
var layer: CanvasLayer
var coach: V10Coach
var t: = 0.0

# flow
var ch: = {}                 # current chapter
var step: = {}               # current step
var step_entry: = false
var step_t0: = 0.0
var step_shown: = false
var snap: = {}               # counters at step start (tray, pairs, pulls…)
var flags: = {}              # runtime facts (ult_skipped…)
var _resume_id: = ""         # S.v10_tut.step at boot

# screens
var screen_ref: WeakRef
var screen_id: = ""
var screen_t0: = 0.0
var tip_done_visit: = false
var tip_check_at: = -1.0
var tip_showing: = ""
var _victory_seen_t: = -1.0
var _pair_pick: = []         # [first, twin] chosen for the forced pair


static func attach(m) -> V10Tutorial:
	if inst and is_instance_valid(inst):
		return inst
	V10TutState.ensure()
	var n: = V10Tutorial.new()
	n.name = "V10Tutorial"
	n.main = m
	m.add_child(n)
	inst = n
	return n


static func active() -> bool:
	return inst != null and is_instance_valid(inst)


static func owns_first_match() -> bool:
	return active() and not V10TutState.skipped() and not V10TutState.chapter_done("match1")


static func busy() -> bool:
	return active() and inst.coach != null and inst.coach.visible


static func event(name: String, _data: = {}) -> void:
	if active():
		inst._on_event(name)


static func help(m, topic: = "") -> void:
	V10Help.open(m, topic)


static func skip_all() -> void:
	V10TutState.skip_all()
	if active():
		inst._end_flow(true)


static func replay(chapter: = "") -> void:
	if chapter == "":
		V10TutState.replay()
	else:
		var d: = V10TutState.st()
		d.skipped = false
		d.chapters.erase(chapter)
		if chapter == "match1":
			V10TutState.S()["tut_done"] = false
		V10TutState.save()
	if active():
		inst._end_flow(false)


func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = LAYER
	layer.name = "V10TutLayer"
	add_child(layer)
	coach = V10Coach.make(layer, _ctx)
	coach.visible = false
	coach.advanced.connect(_on_advanced)
	coach.skip_confirmed.connect(func():
		V10Tutorial.skip_all())
	coach.forced_continue.connect(_on_forced_continue)
	_resume_id = V10TutState.step()
	V10Tutorial.register_dyn_all()


func _ctx() -> Dictionary:
	return {"main": main, "screen": _screen(), "tut": self}


func _screen():
	if main == null or not is_instance_valid(main):
		return null
	var s = main.get("screen")
	return s if s is Node and is_instance_valid(s) and not (s as Node).is_queued_for_deletion() else null


func _sid() -> String:
	return String(main.get("screen_id")) if main and is_instance_valid(main) else ""


# ── frame loop ───────────────────────────────────────────────────────────────────────────────────────────────

func _process(dt: float) -> void:
	t += dt
	if main == null or not is_instance_valid(main):
		return
	var s = _screen()
	var sid: = _sid()
	if s == null:
		return
	if screen_ref == null or screen_ref.get_ref() != s:
		_on_screen_enter(s, sid)
	if main.get("busy"):
		return
	_tick_flow()
	if tip_check_at > 0.0 and t >= tip_check_at:
		tip_check_at = -1.0
		_try_screen_tip()


func _on_screen_enter(s, sid: String) -> void:
	screen_ref = weakref(s)
	screen_id = sid
	screen_t0 = t
	tip_done_visit = false
	tip_check_at = t + TIP_DELAY
	_victory_seen_t = -1.0
	_pair_pick = []
	# a tip of the last screen never travels to the next one
	if tip_showing != "":
		tip_showing = ""
		coach.close()
	# a forced step whose goal was to leave this screen (tab, «Ещё уровень», bridge) is done now
	if not step.is_empty() and step_shown and String(step.get("mode", "tap")) == "do" and _pred(String(step.get("done", ""))):
		_next()
	# a step on screen that belongs to another screen goes quiet (its chapter waits or resumes later)
	if not step.is_empty() and _step_screen() != sid:
		step_shown = false
		coach.idle()


# ── flow ─────────────────────────────────────────────────────────────────────────────────────────────────────

func _flow_on() -> bool:
	return not V10TutState.skipped()


func _step_screen() -> String:
	if step.is_empty():
		return ""
	return String(step.get("screen", ch.get("screen", "")))


func _tick_flow() -> void:
	if not _flow_on():
		return
	if tip_showing != "":
		return
	# a forced / waiting step whose goal is reached ends even on another screen (a bridge that leads away)
	if not step.is_empty() and step_shown and String(step.get("mode", "tap")) == "do" and _pred(String(step.get("done", ""))):
		_next()
	if step.is_empty() or _step_screen() != screen_id:
		if not _pick_chapter():
			return
	_run_step()


# finds what to show on this screen: the chapter in progress (resumed), or the first due chapter that can start
func _pick_chapter() -> bool:
	for c in V10TutSteps.CHAPTERS:
		if V10TutState.chapter_done(c.id):
			continue
		if not _pred(String(c.get("need", ""))):
			continue
		var resume: = _resume_in(c)
		if screen_id == String(c.screen):
			if not _pred(String(c.get("when", ""))) and resume.is_empty():
				continue
			_start(c, resume if not resume.is_empty() else c.steps[0], false)
			return true
		for e in c.get("entry", []):
			if String(e.get("screen", "")) == screen_id and not _pred(String(e.get("done", ""))):
				_start(c, e, true)
				return true
	return false


# a step id saved before the app was killed: restart at its "resume" checkpoint (match state is not restored)
func _resume_in(c: Dictionary) -> Dictionary:
	if _resume_id == "":
		return {}
	for s in c.steps:
		if s.id == _resume_id:
			var rid: = String(s.get("resume", s.id))
			for s2 in c.steps:
				if s2.id == rid:
					return s2
			return s
	return {}


func _start(c: Dictionary, s: Dictionary, entry: bool) -> void:
	if ch.get("id", "") != c.id:
		flags.clear()
	ch = c
	_set_step(s, entry)


func _set_step(s: Dictionary, entry: bool) -> void:
	step = s
	step_entry = entry
	step_t0 = t
	step_shown = false
	# a bridge step does not use up the resume point (it only leads to the chapter screen)
	if not entry:
		_resume_id = ""
	V10TutState.set_step(String(s.id))
	var b = _board()
	snap = {"tray": b.tray.size() if b else 0, "gone": _gone(b), "pulls": int(G.S.get("pulls", 0)),
		"outfit": str(G.S.get("outfit", {})), "screen": screen_id}


func _run_step() -> void:
	if step.is_empty():
		return
	if _step_screen() != screen_id:
		return
	if _pred(String(step.get("skip_if", ""))) and String(step.get("skip_if", "")) != "":
		_next()
		return
	var m: = String(step.get("mode", "tap"))
	if m == "wait":
		if coach.visible and not coach._closing:
			coach.idle()
		if _pred(String(step.get("done", ""))):
			_next()
		return
	if not step_shown:
		if not _pred(String(step.get("when", ""))):
			return
		_show_current()
		return
	if m == "do" and _pred(String(step.get("done", ""))):
		V9Feel.success(null, "sparkle", 1.0)
		_next()


func _show_current() -> void:
	step_shown = true
	var b = _board()
	snap.tray = b.tray.size() if b else 0
	snap.gone = _gone(b)
	snap.pulls = int(G.S.get("pulls", 0))
	var gift: = String(step.get("gift", ""))
	if gift != "":
		grant(gift)
	var vis: = V10TutSteps.visible_steps(String(ch.id))
	var idx: = vis.find(String(step.id))
	var d: = {
		"text": fill(String(step.get("text", ""))),
		"emo": step.get("emo", "happy"),
		"target": step.get("target", []),
		"mode": step.get("mode", "tap"),
		"finger": step.get("finger", false),
		"timeout": step.get("timeout", 0.0),
		"skippable": true,
		"counter": [idx + 1, vis.size()] if idx >= 0 and not step_entry else null,
	}
	if String(step.get("mode", "")) == "do" and step.has("target"):
		# a forced step whose target cannot be found turns into a read step (no softlock)
		var r: = V10TutTarget.resolve(step.target, _ctx())
		if not r.ok:
			d.mode = "tap"
			d.finger = false
	coach.show_step(d)


func _next() -> void:
	var list: Array = ch.get("entry", []) if step_entry else ch.steps
	var i: = -1
	for k in list.size():
		if list[k].id == step.id:
			i = k
	if step_entry:
		# the bridge is done: the chapter itself starts once its screen is up
		if i + 1 < list.size():
			_set_step(list[i + 1], true)
		else:
			_set_step(ch.steps[0], false)
		coach.idle()
		return
	if i + 1 < list.size():
		_set_step(list[i + 1], false)
		if String(step.get("mode", "tap")) == "wait" or _step_screen() != screen_id:
			coach.idle()
		_run_step()
	else:
		V10TutState.finish_chapter(String(ch.id))
		step = {}
		ch = {}
		coach.close()
		# the next chapter (or a tip) may follow on this screen after a breath
		tip_check_at = t + 1.2 if not tip_done_visit else -1.0


func _on_advanced() -> void:
	if tip_showing != "":
		tip_showing = ""
		coach.close()
		return
	if step.is_empty() or not step_shown:
		return
	if String(step.get("mode", "tap")) == "tap":
		_next()


func _on_forced_continue() -> void:
	if step.is_empty():
		return
	if step.id == "u_tap":
		flags["ult_skipped"] = true
	_next()


func _end_flow(skipped: bool) -> void:
	step = {}
	ch = {}
	_resume_id = ""
	if tip_showing == "":
		coach.close()
	if skipped:
		main.call("toast", "Обучение пропущено. «Как играть» — в настройках", "heart") if main and main.has_method("toast") else null


static func fill(s: String) -> String:
	if s.find("{") < 0:
		return s
	var slots: = 4
	if active():
		var b = inst._board()
		if b and "slots" in b:
			slots = int(b.slots)
	var word: = "место" if slots % 10 == 1 and slots % 100 != 11 else ("места" if slots % 10 in [2, 3, 4] and not (slots % 100 in [12, 13, 14]) else "мест")
	return s.replace("{slots} места", "%d %s" % [slots, word]).replace("{slots}", str(slots))


# ── gifts ────────────────────────────────────────────────────────────────────────────────────────────────────

# one-time tutorial gifts. "first_wish": one free wish — a Билет желания when the 0.10 wallet has `tickets`
# (spec §2.1: the only field for free wishes), else the gems of one wish (0.9 economy). Never twice.
static func grant(id: String) -> bool:
	if V10TutState.gift_given(id):
		return false
	var s: = V10TutState.S()
	match id:
		"first_wish":
			if s.has("tickets"):
				s.tickets = int(s.tickets) + 1
			else:
				s.gems = int(s.get("gems", 0)) + int(G.PULL_COST)
		_:
			return false
	V10TutState.mark_gift(id)
	if active() and inst.main and inst.main.has_method("refresh_currency"):
		inst.main.refresh_currency(true)
		inst.main.toast("Подарок от Маджонг-тян: одно желание", "gem")
	return true


# ── tips ─────────────────────────────────────────────────────────────────────────────────────────────────────

func _flow_wants_screen() -> bool:
	if not _flow_on():
		return false
	if not step.is_empty() and _step_screen() == screen_id:
		return true
	for c in V10TutSteps.CHAPTERS:
		if V10TutState.chapter_done(c.id) or not _pred(String(c.get("need", ""))):
			continue
		if screen_id == String(c.screen) and _pred(String(c.get("when", ""))):
			return true
		for e in c.get("entry", []):
			if String(e.get("screen", "")) == screen_id:
				return true
	return false


func _try_screen_tip() -> void:
	if tip_done_visit or V10TutState.tips_off() or _flow_wants_screen() or coach.visible:
		return
	for tp in V10TutTips.for_screen(screen_id):
		if _tip_ok(tp):
			_show_tip(tp)
			return


func _on_event(name: String) -> void:
	if tip_done_visit or V10TutState.tips_off() or coach.visible or main.get("busy"):
		return
	if not step.is_empty() and _step_screen() == screen_id:
		return
	for tp in V10TutTips.for_event(name):
		if _tip_ok(tp):
			_show_tip(tp)
			return


func _tip_ok(tp: Dictionary) -> bool:
	if V10TutState.tip_seen(String(tp.id)):
		return false
	if int(tp.get("min_level", 0)) > 0 and int(G.S.get("unlocked", 1)) < int(tp.min_level):
		return false
	if bool(tp.get("need_target", false)):
		return V10TutTarget.resolve(tp.get("target", []), _ctx()).ok
	return true


func _show_tip(tp: Dictionary) -> void:
	tip_done_visit = true
	tip_showing = String(tp.id)
	V10TutState.mark_tip(String(tp.id))
	var tgt = tp.get("target", [])
	# a tip whose spotlight is only a rough fallback rectangle draws no hole (it would point at nothing)
	var r: = V10TutTarget.resolve(tgt, _ctx())
	if r.ok and r.kind in ["rect", "px"]:
		tgt = []
	coach.show_step({"text": String(tp.tip), "emo": tp.get("emo", "happy"), "target": tgt, "mode": "tip",
		"finger": false, "speaker": tp.get("speaker", "mc")})


# shows one tip now (a lane can call it for a moment that has no screen of its own); false if seen / blocked
static func tip_now(id: String) -> bool:
	if not active():
		return false
	var tp: = V10TutTips.topic(id)
	if tp.is_empty() or not inst._tip_ok(tp) or inst.coach.visible or V10TutState.tips_off():
		return false
	inst._show_tip(tp)
	return true


# ── predicates (step / chapter conditions, data refers to them by name) ──────────────────────────────────────

func _board():
	var s = _screen()
	if s and "board" in s:
		var b = s.get("board")
		if b is TrayBoard and is_instance_valid(b):
			return b
	return null


static func _gone(b) -> int:
	if b == null:
		return 0
	var n: = 0
	for x in b.tiles:
		if not x.alive:
			n += 1
	return n


func _pred(name: String) -> bool:
	if name == "":
		return true
	var s = _screen()
	var b = _board()
	match name:
		"first_match":
			return screen_id == "play" and s and int(s.get("lvl")) == 0 and String(s.get("mode")) == ""
		"board_ready":
			return b != null and b.input_on and not b.dealing and b.tiles.size() > 0 and t - step_t0 > 1.2
		"tile_in_tray":
			return b != null and (b.tray.size() > int(snap.tray) or _gone(b) > int(snap.gone))
		"pair_done":
			return b != null and _gone(b) > int(snap.gone)
		"no_blocked":
			return b == null or _blocked_tile(b) == null
		"victory_shown":
			return screen_id == "play" and s and V10TutTarget.usable(s.get("victory_next_btn"))
		"victory_settled":
			if not _pred("victory_shown"):
				_victory_seen_t = -1.0
				return false
			if _victory_seen_t < 0.0:
				_victory_seen_t = t
			return t - _victory_seen_t > 2.6
		"left_victory":
			return screen_id != "play" or not V10TutTarget.usable(s.get("victory_next_btn") if s else null)
		"home_ready", "screen_settled":
			return t - screen_t0 > 1.2
		"screen_play_or_levels":
			return screen_id in ["play", "levels"]
		"screen_summon":
			return screen_id == "summon"
		"screen_collection":
			return screen_id == "collection"
		"summon_ready":
			return G.summon_open() and V10TutState.chapter_done("home1")
		"summon_idle":
			if screen_id != "summon" or t - screen_t0 < 0.9 or s == null:
				return false
			var seq = s.get("seq")
			var sc = s.get("showcase")
			return not (seq is CanvasItem and is_instance_valid(seq) and (seq as CanvasItem).is_visible_in_tree()) \
				and not (sc is CanvasItem and is_instance_valid(sc) and (sc as CanvasItem).is_visible_in_tree()) \
				and not bool(s.get("flipping")) and (V10TutTarget.usable(s.get("pull1_btn")) or V10TutTarget.usable(s.get("pull10_btn")))
		"pulled":
			return int(G.S.get("pulls", 0)) > int(snap.pulls)
		"ult_ready":
			# the ult is taught on the 2nd / 3rd table (spec: when the meter first fills after the first match)
			return screen_id == "play" and s and int(s.get("lvl")) >= 1 and bool(s.get("skill_ready")) and b != null and b.input_on
		"ult_used":
			if s == null:
				return true
			var u = s.get("ult")
			return not bool(s.get("skill_ready")) or (u != null and is_instance_valid(u) and bool(u.get("busy")))
		"ult_skipped":
			return bool(flags.get("ult_skipped", false))
		"after_match1":
			return V10TutState.chapter_done("match1")
		"after_summon1":
			return V10TutState.chapter_done("summon1")
	if name.begins_with("screen:"):
		return screen_id == name.substr(7)
	push_warning("V10Tutorial: unknown predicate %s" % name)
	return false


# all names the data may use (the selftest checks every step / chapter against this list)
const PREDICATES: = ["first_match", "board_ready", "tile_in_tray", "pair_done", "no_blocked", "victory_shown",
	"victory_settled", "left_victory", "home_ready", "screen_settled", "screen_play_or_levels", "screen_summon",
	"screen_collection", "summon_ready", "summon_idle", "pulled", "ult_ready", "ult_used", "ult_skipped",
	"after_match1", "after_summon1"]


# ── dynamic targets (board tiles, victory window parts) ──────────────────────────────────────────────────────

static func register_dyn_all() -> void:
	V10TutTarget.register_dyn("board", func(c):
		return inst._dyn_board() if V10Tutorial.active() else null)
	V10TutTarget.register_dyn("pair_first", func(c):
		return inst._pair_tile(false) if V10Tutorial.active() else null)
	V10TutTarget.register_dyn("pair_twin", func(c):
		return inst._pair_tile(true) if V10Tutorial.active() else null)
	V10TutTarget.register_dyn("blocked", func(c):
		if not V10Tutorial.active():
			return null
		var b = inst._board()
		return inst._blocked_tile(b) if b else null)
	V10TutTarget.register_dyn("win_stars", func(c):
		return inst._dyn_win_stars() if V10Tutorial.active() else null)
	V10TutTarget.register_dyn("win_reward", func(c):
		return inst._dyn_win_reward() if V10Tutorial.active() else null)


func _dyn_board():
	if _board() == null:
		return null
	var s = _screen()
	var r = s.get("board_rect") if s else null
	return r if r is Rect2 else null


func _dyn_win_stars():
	var root = _win_root()
	if root == null:
		return null
	var hits: = V10TutTarget.find_tex(root, "star_empty", true)
	hits.append_array(V10TutTarget.find_tex(root, "nav/play", true))
	hits = hits.filter(func(n): return (n as Control).size.x >= 60.0 if n is Control else true)
	if hits.is_empty():
		return null
	var acc: = V10TutTarget.node_rect(hits[0])
	for n in hits:
		acc = acc.merge(V10TutTarget.node_rect(n))
	return acc


func _dyn_win_reward():
	var root = _win_root()
	if root == null:
		return null
	var g: = V10TutTarget.find_tex(root, "cur/gem", false)
	if g.is_empty():
		return null
	var row = (g[0] as Node).get_parent()
	return row if row is Control and (row as Control).size.x < 700.0 else g[0]


# the forced pair: a free pair on the table, or the free twin of a tile already in the tray
func _pair_tile(twin: bool):
	var b = _board()
	if b == null or not b.input_on:
		return null
	if twin:
		for x in b.tray:
			for tl in b.free_tiles():
				if tl.face == x.face and not tl.pending:
					return tl
		return null
	if _pair_pick.size() == 2 and is_instance_valid(_pair_pick[0]) and b.on_board(_pair_pick[0]) and b.is_free(_pair_pick[0]):
		return _pair_pick[0]
	var by_face: = {}
	for tl in b.free_tiles():
		if tl.pending or tl.ice > 0:
			continue
		by_face[tl.face] = by_face.get(tl.face, []) + [tl]
	var best = null
	var best_d: = INF
	var c: Vector2 = b.get_global_transform_with_canvas().origin
	for f in by_face:
		if by_face[f].size() >= 2:
			for tl in by_face[f]:
				var d: = (tl as Node2D).get_global_transform_with_canvas().origin.distance_to(c)
				if d < best_d:
					best_d = d
					best = tl
	if best == null:
		best = b.best_move()
	if best != null:
		_pair_pick = [best, null]
	return best


func _blocked_tile(b):
	var best = null
	var best_z: = -1
	for tl in b.tiles:
		if b.on_board(tl) and not b.is_free(tl) and not tl.pending:
			if int(tl.gz) > best_z:
				best_z = int(tl.gz)
				best = tl
	return best


func _win_root():
	var s = _screen()
	if s == null:
		return null
	var nb = s.get("victory_next_btn")
	if not V10TutTarget.usable(nb):
		return null
	var n: Node = nb
	for i in 8:
		var p: = n.get_parent()
		if p == null or p == main.get("overlay") or p == s:
			return n
		n = p
	return n
