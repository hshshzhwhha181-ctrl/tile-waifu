class_name TWModalSelftest
extends RefCounted

# Selftest of P24 (WP8b): TWModal, ModalStack, TWExitConfirm and the Android back table. Prints "TWMODAL_SELFTEST ok/total".
#   * unit checks: scrim ownership, on_close exactly once on every exit path, ordering, reentrancy, refusals
#   * the 0.12.1 regression: a full-screen STOP view (+ a legacy-style stray child) is gone after the next go()
#   * the back table (4 cases) driven through a real TWScreens with fake screens
#   * the property test: 500 random sequences of go / back / go_tab / open / close / external free / clear, ending in a go() or in
#     a drain by back(); after every sequence the layer is empty and no visible STOP control is left, and every modal opened
#     got its on_close exactly once.
# Nothing here touches G or the real save.

const FAKE: = "res://shell/nav/nav_fake_screen.gd"
const IDS: = ["home", "map", "play", "result", "wish", "shop", "profile", "settings"]
const SEQUENCES: = 500

var host: Node
var _pass: = 0
var _fail: = 0
# modal id (instance id) -> number of on_close calls, for every TestModal created while a test runs
var calls: Dictionary = {}
var order: Array = []


class TestModal extends TWModal:
	var owner_test: TWModalSelftest
	var kind: = "plain"
	var steps: = 0                      # wizard: back steps left before it closes
	var follow: Callable = Callable()   # chain: called from on_close when closed by a user path

	func _build(_opts: Dictionary) -> void:
		match kind:
			"forced":
				dismissable = false
			"wizard":
				steps = 2
			"full":
				# a first-pick like view: a full-screen STOP catcher of its own, on top of the scrim
				var f: = ColorRect.new()
				f.name = "FullView"
				f.set_anchors_preset(Control.PRESET_FULL_RECT)
				f.color = Color(0, 0, 0, 0.1)
				f.mouse_filter = Control.MOUSE_FILTER_STOP
				add_child(f)
			"content":
				for i in 3:
					var b: = Button.new()
					b.custom_minimum_size = Vector2(0, 96)
					add_child(b)

	func on_back() -> bool:
		if kind == "wizard" and steps > 0:
			steps -= 1
			return true
		return super.on_back()


func check(name: String, ok: bool, info: String = "") -> void:
	if ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		printerr("FAIL ", name, " ", info)


func run(p_host: Node) -> Array:
	host = p_host
	_scrim_and_basics()
	_close_paths()
	_ordering_and_back()
	_clear_all()
	_reentrancy()
	_external_free()
	_refusals()
	_regression_0121()
	await _back_table()
	await _property()
	var total: = _pass + _fail
	print("TWMODAL_SELFTEST %d/%d" % [_pass, total])
	return [_pass, total]


# ── helpers ─────────────────────────────────────────────────────────────────────────────────────────────────

func _stack() -> ModalStack:
	var s: = ModalStack.new()
	host.add_child(s)
	return s


func _drop(s: ModalStack) -> void:
	if is_instance_valid(s):
		s.get_parent().remove_child(s)
		s.free()


func _mk(kind: String = "plain", tag: String = "") -> TestModal:
	var m: = TestModal.new()
	m.kind = kind
	m.owner_test = self
	var id: = m.get_instance_id()
	calls[id] = 0
	m.on_close = func(res, reason):
		calls[id] = int(calls.get(id, 0)) + 1
		order.append("%s:%s" % [tag if tag != "" else str(id), reason])
	return m


func _calls_of(m: TWModal) -> int:
	return int(calls.get(m.get_instance_id(), -1))


# ── unit checks ─────────────────────────────────────────────────────────────────────────────────────────────

func _scrim_and_basics() -> void:
	var s: = _stack()
	check("layer: full rect, ignores the mouse, named ModalLayer", s.mouse_filter == Control.MOUSE_FILTER_IGNORE and s.name == "ModalLayer" and s.anchor_right == 1.0 and s.anchor_bottom == 1.0)
	check("layer: empty at start", s.depth() == 0 and not s.is_open() and s.top() == null and s.is_clean())
	var m: = _mk()
	check("modal: the scrim is child 0 and exists before open", m.get_child_count() == 1 and m.get_child(0) == m.scrim and m.scrim is ColorRect)
	check("modal: scrim blocks (STOP), the modal root ignores the mouse", m.scrim.mouse_filter == Control.MOUSE_FILTER_STOP and m.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	check("modal: not open before stack.open()", not m.is_open() and m.life == TWModal.Life.NEW)
	var got: = s.open(m)
	check("open: returns the modal, it is a child of the layer and the top", got == m and m.get_parent() == s and s.top() == m and s.depth() == 1 and m.is_open() and m.stack == s)
	check("open: layer is clean (children == stack)", s.is_clean())
	check("open: STOP controls under the layer = exactly the scrim", ModalStack.stop_visible_under(s) == [m.scrim], str(ModalStack.stop_visible_under(s)))
	m.scrim_alpha = 0.3
	check("scrim_alpha drives the scrim colour", is_equal_approx(m.scrim.color.a, 0.3))
	# scrim tap closes a dismissable modal
	var ev: = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	m.scrim.gui_input.emit(ev)
	check("scrim tap closes with reason 'scrim', on_close once", s.depth() == 0 and not m.is_open() and _calls_of(m) == 1 and m.close_reason == "scrim", str(order))
	check("scrim tap: modal left the tree, no STOP left in the layer", m.get_parent() == null and ModalStack.stop_visible_under(s).is_empty() and s.get_child_count() == 0)
	var m2: = _mk()
	m2.scrim_tap_closes = false
	s.open(m2)
	m2.scrim.gui_input.emit(ev)
	check("scrim_tap_closes=false: the scrim only blocks", m2.is_open() and s.depth() == 1)
	var m3: = _mk()
	m3.dismissable = false
	s.open(m3)
	m3.scrim.gui_input.emit(ev)
	check("dismissable=false: a scrim tap does nothing", m3.is_open() and s.depth() == 2)
	var touch: = InputEventScreenTouch.new()
	touch.pressed = true
	var m4: = _mk()
	s.open(m4)
	m4.scrim.gui_input.emit(touch)
	check("a touch on the scrim closes too", not m4.is_open() and _calls_of(m4) == 1)
	var released: = InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	var m5: = _mk()
	s.open(m5)
	m5.scrim.gui_input.emit(released)
	check("a release does not close", m5.is_open())
	_drop(s)


func _close_paths() -> void:
	order.clear()
	var s: = _stack()
	var seen: Array = []
	s.closed.connect(func(mm, reason): seen.append(reason))
	var m: = _mk("plain", "a")
	s.open(m)
	var sig: Array = []
	m.closed.connect(func(res, reason): sig.append([res, reason]))
	check("close(result): true the first time", m.close("yes", "answer"))
	check("close: on_close got (result, reason) once", _calls_of(m) == 1 and order == ["a:answer"] and m.result == "yes" and m.close_reason == "answer", str(order))
	check("close: signals fired (modal.closed, stack.closed)", sig == [["yes", "answer"]] and seen == ["answer"])
	check("close: the second close is a no-op (false, no second on_close)", not m.close("again") and not s.close(m) and _calls_of(m) == 1)
	check("close: stack empty and clean", s.depth() == 0 and s.is_clean() and s.get_child_count() == 0)
	# closing a modal from inside its own on_close is a no-op
	var m2: = _mk("plain", "b")
	var prev: Callable = m2.on_close
	m2.on_close = func(res, reason):
		prev.call(res, reason)
		m2.close("inner")
	s.open(m2)
	m2.close()
	check("close from inside on_close does not run on_close twice", _calls_of(m2) == 1)
	# close of a modal in the middle of the stack
	var a: = _mk("plain", "a")
	var b: = _mk("plain", "b")
	var c: = _mk("plain", "c")
	s.open(a)
	s.open(b)
	s.open(c)
	order.clear()
	check("close(middle): pops only that one", s.close(b) and s.modals() == [a, c] and s.is_clean(), str(s.modals()))
	check("close_top pops the top", s.close_top("t") and s.top() == a and c.result == "t")
	# a bare modal (never opened) closed directly still reports once
	var lone: = _mk("plain", "lone")
	check("a modal that was never opened can be closed (on_close once)", lone.close() and not lone.close() and _calls_of(lone) == 1)
	lone.free()
	_drop(s)
	for k in [a, b, c, m, m2]:
		if is_instance_valid(k):
			k.queue_free()


func _ordering_and_back() -> void:
	order.clear()
	var s: = _stack()
	var a: = _mk("plain", "a")
	var b: = _mk("wizard", "b")
	var c: = _mk("forced", "c")
	s.open(a)
	s.open(b)
	s.open(c)
	check("order: top is the last opened, children follow the stack", s.top() == c and s.is_clean())
	check("back: no modal -> false", _no_modal_back())
	check("back: a forced modal swallows back and stays", s.handle_back() and c.is_open() and s.depth() == 3)
	c.close(null, "x")
	check("back: a wizard modal handles two steps first (1/3)", s.handle_back() and b.is_open() and b.steps == 1)
	check("back: a wizard modal handles two steps first (2/3)", s.handle_back() and b.is_open() and b.steps == 0)
	check("back: a wizard modal then closes (3/3), reason 'back'", s.handle_back() and not b.is_open() and b.close_reason == "back")
	check("back: next press closes the one below", s.handle_back() and not a.is_open() and s.depth() == 0)
	check("back: nothing left -> false (TWScreens continues)", not s.handle_back())
	check("back: every modal reported once, in the order it left", order == ["c:x", "b:back", "a:back"], str(order))
	_drop(s)


func _no_modal_back() -> bool:
	var s: = _stack()
	var r: = not s.handle_back()
	_drop(s)
	return r


func _clear_all() -> void:
	order.clear()
	var s: = _stack()
	var a: = _mk("plain", "a")
	var b: = _mk("full", "b")
	var c: = _mk("forced", "c")
	s.open(a)
	s.open(b)
	s.open(c)
	# legacy-style strays: added to the layer behind the stack's back
	var stray: = ColorRect.new()
	stray.mouse_filter = Control.MOUSE_FILTER_STOP
	s.add_child(stray)
	var stray2: = Control.new()
	s.add_child(stray2)
	check("clear_all: setup (3 modals + 2 strays in the layer)", s.get_child_count() == 5 and not s.is_clean())
	var n: = s.clear_all("go:home")
	check("clear_all: returns the number of modals closed", n == 3)
	check("clear_all: top-down, each on_close once with the reason", order == ["c:go:home", "b:go:home", "a:go:home"], str(order))
	check("clear_all: layer is empty, strays swept and counted", s.get_child_count() == 0 and s.depth() == 0 and s.strays_swept == 2 and s.is_clean())
	check("clear_all: no visible STOP control under the layer", ModalStack.stop_visible_under(s).is_empty())
	check("clear_all: a forced (dismissable=false) modal is cleared too", not c.is_open() and _calls_of(c) == 1)
	check("clear_all on an empty stack is a no-op", s.clear_all("go:x") == 0 and s.get_child_count() == 0)
	_drop(s)


func _reentrancy() -> void:
	order.clear()
	var s: = _stack()
	# on_close of a normal close opens a follow-up (allowed)
	var follow: = _mk("plain", "follow")
	var first: = _mk("plain", "first")
	var prev: Callable = first.on_close
	first.on_close = func(res, reason):
		prev.call(res, reason)
		s.open(follow)
	s.open(first)
	first.close()
	check("reentrancy: on_close of a normal close may open a follow-up modal", follow.is_open() and s.top() == follow and s.depth() == 1 and s.is_clean())
	follow.close()
	# during clear_all an on_close cannot open a modal
	var late: = _mk("plain", "late")
	var x: = _mk("plain", "x")
	var xprev: Callable = x.on_close
	x.on_close = func(res, reason):
		xprev.call(res, reason)
		s.open(late)
	s.open(x)
	s.clear_all("go:map")
	check("reentrancy: open() during clear_all is refused, the refused modal gets on_close once", s.depth() == 0 and s.get_child_count() == 0 and _calls_of(late) == 1 and late.close_reason == "refused", str(order))
	# after the clear_all opening works again
	var ok: = _mk("plain", "ok")
	check("reentrancy: opening works again after clear_all", s.open(ok) == ok and s.depth() == 1)
	# on_close calling clear_all
	var y: = _mk("plain", "y")
	var yprev: Callable = y.on_close
	y.on_close = func(res, reason):
		yprev.call(res, reason)
		s.clear_all("nested")
	s.open(y)
	y.close()
	check("reentrancy: clear_all from inside an on_close terminates, all closed once", s.depth() == 0 and _calls_of(ok) == 1 and _calls_of(y) == 1, str(order))
	_drop(s)


func _external_free() -> void:
	order.clear()
	var s: = _stack()
	var a: = _mk("plain", "a")
	var b: = _mk("content", "b")
	var c: = _mk("plain", "c")
	s.open(a)
	s.open(b)
	s.open(c)
	b.queue_free()
	# queue_free is deferred: the modal is still in the tree until the next idle frame; the pop happens on tree_exiting
	check("external free: queue_free does not touch the stack until the node leaves the tree", s.depth() == 3)
	c.free()
	check("external free: free() pops the modal at once (tree_exiting), on_close 'freed' once", s.depth() == 2 and order == ["c:freed"] and s.is_clean(), str(order))
	s.remove_child(b)
	check("external free: removing a modal from the layer pops it too", s.depth() == 1 and _calls_of(b) == 1 and s.top() == a and s.is_clean())
	order.clear()
	# the stack itself leaves the tree with modals open
	var d: = _mk("plain", "d")
	var e: = _mk("plain", "e")
	s.open(d)
	s.open(e)
	s.get_parent().remove_child(s)
	check("stack leaves the tree: every open modal got its on_close once ('freed')", _calls_of(a) == 1 and _calls_of(d) == 1 and _calls_of(e) == 1 and s.depth() == 0, str(order))
	var late: = _mk("plain", "late")
	check("a stack that left the tree refuses to open", s.open(late) == null and _calls_of(late) == 1)
	host.add_child(s)
	var again: = _mk("plain", "again")
	var again_id: = again.get_instance_id()
	check("a stack back in the tree opens again", s.open(again) == again and s.depth() == 1)
	_drop(s)
	check("freeing the stack with a modal open reports it once", int(calls.get(again_id, -1)) == 1)
	for k in [a, b, c, d, e]:
		if is_instance_valid(k):
			k.queue_free()


func _refusals() -> void:
	order.clear()
	var s: = _stack()
	check("refusal: open(null) is null", s.open(null) == null)
	var ms: Array = []
	for i in ModalStack.MAX_DEPTH:
		var m: = _mk("plain", "m%d" % i)
		ms.append(m)
		s.open(m)
	check("depth: MAX_DEPTH modals open", s.depth() == ModalStack.MAX_DEPTH and s.is_clean())
	var over: = _mk("plain", "over")
	check("depth: the next one is refused (null) with on_close 'refused' once", s.open(over) == null and _calls_of(over) == 1 and over.close_reason == "refused" and s.depth() == ModalStack.MAX_DEPTH)
	check("refusal: a modal that is already open is not opened twice", s.open(ms[0]) == null and s.depth() == ModalStack.MAX_DEPTH and _calls_of(ms[0]) == 0)
	var other: = _stack()
	check("refusal: a modal open in another stack is not stolen", other.open(ms[1]) == null and ms[1].stack == s)
	check("refused count recorded", s.refused_count == 3, str(s.refused_count))
	s.clear_all("done")
	var all_once: = true
	for m in ms:
		all_once = all_once and _calls_of(m) == 1
	check("depth: clear_all reports each of the 8 once", all_once and s.depth() == 0)
	_drop(other)
	_drop(s)


# the 0.12.1 first-pick bug: a full-screen view in the overlay kept its STOP catcher over the new screen
func _regression_0121() -> void:
	var mgr: = _mgr()
	var s: ModalStack = mgr[1]
	var m: TWScreens = mgr[0]
	m.go("home")
	var fp: = _mk("full", "firstpick")
	s.open(fp)
	var legacy: = ColorRect.new()          # what the legacy overlay did: a view added straight to the layer, no meta, no class
	legacy.name = "LegacyFirstPick"
	legacy.set_anchors_preset(Control.PRESET_FULL_RECT)
	legacy.mouse_filter = Control.MOUSE_FILTER_STOP
	s.add_child(legacy)
	check("0.12.1: a full-screen view + a legacy stray are blocking input over the screen", ModalStack.stop_visible_under(s).size() == 3, str(ModalStack.stop_visible_under(s).size()))
	m.go("map")
	check("0.12.1: after go() the layer is empty", s.get_child_count() == 0 and s.depth() == 0)
	check("0.12.1: after go() no visible STOP control is left (the legacy detector missed exactly this)", ModalStack.stop_visible_under(s).is_empty())
	check("0.12.1: the full-screen view got its on_close once with 'go:map'", _calls_of(fp) == 1 and fp.close_reason == "go:map" and s.strays_swept == 1)
	_drop_mgr(mgr)


# ── manager + stack wired together ──────────────────────────────────────────────────────────────────────────

func _mgr() -> Array:
	var m: = TWScreens.new()
	m.ctx = TWContext.build(null, null, TWBus.new(), m)
	host.add_child(m)
	for id in IDS:
		var opts: = {}
		match id:
			"home":
				opts = {"tab": "main", "is_tab_root": true}
			"wish":
				opts = {"tab": "wish", "is_tab_root": true}
			"shop":
				opts = {"tab": "wish"}
			"result":
				opts = {"keep_history": false}
		m.register(ScreenSpec.make(id, FAKE, opts))
	var s: = ModalStack.new()
	host.add_child(s)                      # after the screens: above them
	s.bind_screens(m)
	return [m, s]


func _drop_mgr(mgr: Array) -> void:
	mgr[0].reset()
	mgr[0].queue_free()
	_drop(mgr[1])


# the four rows of the Android back table (TWScreens.back with a ModalStack bound)
func _back_table() -> void:
	var mgr: = _mgr()
	var m: TWScreens = mgr[0]
	var s: ModalStack = mgr[1]
	var quits: Array = [0]
	var confirmed: Array = [0]
	s.quit_fn = func(): quits[0] += 1
	s.exit_confirmed.connect(func(): confirmed[0] += 1)
	check("bind: screens.modals is the stack", m.modals == s and m.exit_requested.is_connected(s.request_exit))
	m.go("home")
	m.go("map")
	# row 1: a modal is open -> back closes the top modal, the screen does not move
	order.clear()
	var a: = _mk("plain", "a")
	var b: = _mk("plain", "b")
	s.open(a)
	s.open(b)
	var r1: = m.back()
	check("back row 1: a modal is open -> 'modal', the top one closes", r1 == "modal" and not b.is_open() and a.is_open() and m.current_id == "map" and order == ["b:back"], "%s %s" % [r1, str(order)])
	check("back row 1: the next press closes the next modal, still on the same screen", m.back() == "modal" and s.depth() == 0 and m.current_id == "map" and Array(m.history_ids()) == ["home"])
	var forced: = _mk("forced", "f")
	s.open(forced)
	check("back row 1: a forced modal swallows back, nothing navigates", m.back() == "modal" and forced.is_open() and m.current_id == "map")
	forced.close()
	# row 2: no modal, the screen forbids back -> blocked
	m.go("play", {"block": true})
	var h_before: = Array(m.history_ids())
	check("back row 2: can_back() == false -> 'blocked', nothing moves, no modal, no exit", m.back() == "blocked" and m.current_id == "play" and Array(m.history_ids()) == h_before and s.depth() == 0 and quits[0] == 0)
	# row 3: no modal, can_back, history -> history
	m.go("home")
	m.go("map")
	check("back row 3: history -> 'history', back on the previous screen", m.back() == "history" and m.current_id == "home" and s.depth() == 0)
	# row 4: no modal, no history, no target -> the exit confirmation
	var r4: = m.back()
	check("back row 4: nothing left -> 'exit' and the exit confirmation opens", r4 == "exit" and s.top() is TWExitConfirm and s.depth() == 1, "%s %s" % [r4, str(s.top())])
	check("back row 4: the app is NOT closed by the first press", quits[0] == 0 and confirmed[0] == 0)
	var conf: TWExitConfirm = s.top() as TWExitConfirm
	check("back row 4: the confirmation has two buttons of at least HIT_TARGET_MIN", conf.yes_button != null and conf.no_button != null and conf.yes_button.custom_minimum_size.y >= TWTokens.HIT_TARGET_MIN and conf.no_button.custom_minimum_size.y >= TWTokens.HIT_TARGET_MIN)
	check("back row 4: request_exit while it is open does not stack a second one", s.request_exit() == conf and s.depth() == 1)
	check("back row 4: back on the confirmation closes it (stay in the game)", m.back() == "modal" and s.depth() == 0 and quits[0] == 0 and conf.close_reason == "back" and conf.result == null)
	check("back row 4: back again asks again", m.back() == "exit" and s.top() is TWExitConfirm and s.depth() == 1)
	var conf2: TWExitConfirm = s.top() as TWExitConfirm
	conf2.no_button.pressed.emit()
	check("back row 4: 'stay' closes it with result 'no', no quit", s.depth() == 0 and conf2.result == "no" and quits[0] == 0 and confirmed[0] == 0)
	m.back()
	var conf3: TWExitConfirm = s.top() as TWExitConfirm
	conf3.yes_button.pressed.emit()
	check("back row 4: 'leave' quits exactly once (quit_fn + exit_confirmed)", quits[0] == 1 and confirmed[0] == 1 and s.depth() == 0 and conf3.result == "yes", "%d %d" % [quits[0], confirmed[0]])
	# a screen change while the confirmation is open clears it without quitting
	m.back()
	var conf4: = s.top()
	m.go("map")
	check("back row 4: a go() while the confirmation is open clears it, no quit", s.depth() == 0 and conf4 != null and not conf4.is_open() and quits[0] == 1)
	# the whole table drives only through the stack: layer clean at the end
	check("back table: layer clean at the end", s.is_clean() and ModalStack.stop_visible_under(s).is_empty())
	_drop_mgr(mgr)
	await host.get_tree().process_frame


# ── property test ───────────────────────────────────────────────────────────────────────────────────────────

func _property() -> void:
	calls.clear()
	var mgr: = _mgr()
	var m: TWScreens = mgr[0]
	var s: ModalStack = mgr[1]
	s.quit_fn = func(): pass
	var rng: = RandomNumberGenerator.new()
	rng.seed = 20261128
	var kinds: = ["plain", "plain", "forced", "wizard", "full", "content"]
	var created: Array = []
	var step_bad: = 0
	var step_first: = ""
	var end_bad: = 0
	var end_first: = ""
	var stop_bad: = 0
	var stop_first: = ""
	var ops: = 0
	var max_depth: = 0
	var ended_by_go: = 0
	var ended_by_back: = 0
	for seq in SEQUENCES:
		var n: = 20 + rng.randi() % 41
		for i in n:
			ops += 1
			var r: = rng.randi() % 100
			if r < 18:
				m.go(IDS[rng.randi() % IDS.size()], {"i": i})
			elif r < 32:
				m.back()
			elif r < 36:
				m.go_tab(["main", "wish", "nope"][rng.randi() % 3])
			elif r < 62:
				var mod: = _mk(kinds[rng.randi() % kinds.size()])
				created.append(mod)
				if rng.randi() % 8 == 0:
					# an on_close that opens a follow-up, like a confirm that leads to the next sheet
					var prev: Callable = mod.on_close
					mod.on_close = func(res, reason):
						prev.call(res, reason)
						var nxt: = _mk("plain")
						created.append(nxt)
						s.open(nxt)
				s.open(mod)
			elif r < 72:
				if s.is_open():
					var pick: TWModal = s.modals()[rng.randi() % s.depth()]
					pick.close(null, "user")
			elif r < 78:
				s.close_top(null, "top")
			elif r < 82:
				if s.is_open():
					var pick2: TWModal = s.modals()[rng.randi() % s.depth()]
					pick2.queue_free()
			elif r < 85:
				if s.is_open():
					var pick3: TWModal = s.modals()[rng.randi() % s.depth()]
					pick3.free()
			elif r < 88:
				s.clear_all("clear")
			elif r < 91:
				# a legacy view added straight to the layer
				var st: = ColorRect.new()
				st.mouse_filter = Control.MOUSE_FILTER_STOP
				s.add_child(st)
			elif r < 94:
				s.request_exit()
			else:
				if s.top() is TWExitConfirm:
					(s.top() as TWExitConfirm).no_button.pressed.emit()
				elif s.is_open():
					s.top().close("res", "x")
			max_depth = maxi(max_depth, s.depth())
			# per-step invariants (a stray may sit in the layer until the next clear_all: the stack's own bookkeeping must hold)
			var why: = ""
			if s.depth() > ModalStack.MAX_DEPTH:
				why = "depth %d" % s.depth()
			for mm in s.modals():
				if not is_instance_valid(mm) or not (mm as TWModal).is_inside_tree() or (mm as TWModal).life != TWModal.Life.OPEN:
					why = "a stacked modal is not open/in the tree"
			if why != "":
				step_bad += 1
				if step_first == "":
					step_first = "seq %d step %d: %s" % [seq, i, why]
		# end of the sequence
		if seq % 2 == 0:
			ended_by_go += 1
			m.go(IDS[rng.randi() % IDS.size()], {"end": seq})
		else:
			ended_by_back += 1
			var guard: = 0
			while s.is_open() and guard < 40:
				guard += 1
				if m.back() != "modal":
					break
			# strays are cleaned by the next screen change, which the shell does on every go
			m.go(IDS[rng.randi() % IDS.size()], {"end": seq})
		var empty: = s.get_child_count() == 0 and s.depth() == 0 and s.is_clean()
		var stops: = ModalStack.stop_visible_under(host, m)
		stops.erase(host)
		if not empty:
			end_bad += 1
			if end_first == "":
				end_first = "seq %d: layer children %d depth %d" % [seq, s.get_child_count(), s.depth()]
		if not stops.is_empty():
			stop_bad += 1
			if stop_first == "":
				stop_first = "seq %d: %d visible STOP controls (%s)" % [seq, stops.size(), str(stops[0])]
		if seq % 50 == 49:
			await host.get_tree().process_frame
	check("property: %d random sequences (%d ops, max depth %d) keep the stack bookkeeping" % [SEQUENCES, ops, max_depth], step_bad == 0, step_first)
	check("property: after every sequence the modal layer is empty (%d ended by go(), %d drained by back() then go())" % [ended_by_go, ended_by_back], end_bad == 0, end_first)
	check("property: after every sequence no visible STOP control is left outside the screen", stop_bad == 0, stop_first)
	var once_bad: = 0
	var first_once: = ""
	for id in calls:
		if int(calls[id]) != 1:
			once_bad += 1
			if first_once == "":
				first_once = "instance %s got %d on_close calls" % [str(id), int(calls[id])]
	check("property: all %d modals got on_close exactly once (closed, cleared, freed or refused)" % calls.size(), once_bad == 0 and calls.size() >= created.size(), first_once)
	check("property: the soak actually exercised the paths (opened %d, closed %d, refused %d, strays swept %d)" % [s.opened_count, s.closed_count, s.refused_count, s.strays_swept], s.opened_count > 1500 and s.closed_count == s.opened_count and s.refused_count > 0 and s.strays_swept > 0)
	_drop_mgr(mgr)
	await host.get_tree().process_frame
