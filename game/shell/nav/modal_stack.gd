class_name ModalStack
extends Control

# ModalStack (P24 / WP8b): the ONE modal layer of the v11 shell and the ONE Android back handler for modals.
#
# It replaces the legacy `main.overlay` convention (anything can add a child, go() clears by a whitelist of metas and classes,
# the "is something open?" detector is re-implemented in 39 places) with a stack that owns its children:
#
#   open(modal) -> TWModal    push a TWModal (null when refused: depth over MAX_DEPTH, a clear_all in progress, a modal that is
#                             already open, null). A refused modal still gets its on_close(null, "refused") exactly once
#   close(modal, result, reason) -> bool     pop that modal (not necessarily the top), detach it at once, run its on_close once
#   close_top(result, reason) -> bool
#   clear_all(reason) -> int  close everything top-down (TWScreens calls it with "go:<id>" before every mount), then sweep any
#                             stray child someone added to the layer behind the stack's back. Afterwards the layer is EMPTY
#   handle_back() -> bool     Android back for modals: the top modal's on_back() runs and the press is swallowed (true); with
#                             no modal open it returns false and TWScreens continues with the screen / history / exit
#   request_exit()            the last step of the back table: open the exit confirmation (TWExitConfirm)
#   bind_screens(screens)     wire TWScreens.modals = self and screens.exit_requested -> request_exit()
#
# Guarantees (the property test in modal_selftest.gd runs 500 random go/back/open/close/free sequences against them)
#   1. the layer's children are exactly the open modals, in stack order (is_clean())
#   2. every modal that was opened gets on_close exactly once, whatever happens to it: closed, cleared by a screen change,
#      queue_free()d/free()d from outside (the tree_exiting hook pops it), refused, or the stack itself leaving the tree
#   3. the scrim belongs to the modal (TWModal child 0), so no STOP catcher can outlive its modal
#   4. nothing is opened while a clear_all is running (so an on_close callback cannot resurrect a modal into a screen change) or
#      while the on_close of a modal freed from outside runs (the node tree is mid-removal then)
#
# The layer itself ignores the mouse and takes the full rect: put it LAST in the root (above the screen, the chrome and toasts).
# Legacy screens that still add children to main.overlay are the LegacyHost's problem (P25); tools/lint_modal_only_via_stack.py
# counts those sites (report mode) and is enforcing inside game/shell.

signal opened(modal: TWModal)
signal closed(modal: TWModal, reason: String)
signal changed(depth: int)
signal exit_confirmed

const MAX_DEPTH: = 8
const LAYER_NAME: = "ModalLayer"

var quit_fn: Callable = Callable()        # () -> void, called after the exit confirmation; default get_tree().quit()
var strays_swept: = 0                     # children found in the layer that were not opened through the stack
var opened_count: = 0
var closed_count: = 0
var refused_count: = 0

var _stack: Array = []                    # [TWModal], bottom first
var _leaving: = {}                        # instance_id -> true while the stack itself is detaching that modal
var _clearing: = false
var _dead: = false                        # the layer is leaving the tree
var _popping: = 0                         # >0 while an on_close of a modal that was freed from outside runs
var _exit_modal: TWModal = null


func _init() -> void:
	name = LAYER_NAME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_exiting.connect(_on_layer_exiting)
	tree_entered.connect(func(): _dead = false)


# ── queries ─────────────────────────────────────────────────────────────────────────────────────────────────

func depth() -> int:
	return _stack.size()


func is_open() -> bool:
	return not _stack.is_empty()


func top() -> TWModal:
	return _stack.back() if not _stack.is_empty() else null


func modals() -> Array:
	return _stack.duplicate()


func contains(modal: TWModal) -> bool:
	return modal != null and _stack.has(modal)


# the layer holds exactly the open modals, in order, nothing else
func is_clean() -> bool:
	var kids: = get_children()
	if kids.size() != _stack.size():
		return false
	for i in kids.size():
		if kids[i] != _stack[i]:
			return false
	return true


# every visible Control with mouse_filter STOP under `root` (not counting `skip` and its subtree). Used by the soak tests and
# by the shell's debug overlay: after a screen change the modal layer must have none.
static func stop_visible_under(root: Node, skip: Node = null) -> Array:
	var out: Array = []
	_collect_stop(root, skip, out)
	return out


static func _collect_stop(n: Node, skip: Node, out: Array) -> void:
	if n == skip:
		return
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
		out.append(n)
	for c in n.get_children():
		_collect_stop(c, skip, out)


# ── open / close ────────────────────────────────────────────────────────────────────────────────────────────

func open(modal: TWModal, opts: Dictionary = {}) -> TWModal:
	if modal == null:
		refused_count += 1
		return null
	if modal.life != TWModal.Life.NEW or modal.stack != null or modal.get_parent() != null:
		# already opened (here or elsewhere) or reparented by someone: not ours to touch, its own owner keeps the on_close
		refused_count += 1
		return null
	if _clearing or _dead or _popping > 0 or _stack.size() >= MAX_DEPTH:
		refused_count += 1
		modal._finish(null, "refused")
		if is_instance_valid(modal):
			modal.queue_free()
		return null
	modal.stack = self
	modal.life = TWModal.Life.OPEN
	_stack.append(modal)
	add_child(modal)
	modal.tree_exiting.connect(_on_modal_exiting.bind(modal))
	opened_count += 1
	opened.emit(modal)
	changed.emit(_stack.size())
	modal._opened(opts)
	return modal if is_instance_valid(modal) and modal.life == TWModal.Life.OPEN else null


func close(modal: TWModal, result: Variant = null, reason: String = "close") -> bool:
	var i: = _stack.find(modal) if modal != null else -1
	if i < 0:
		return false
	_stack.remove_at(i)
	_leaving[modal.get_instance_id()] = true
	if modal.get_parent() == self:
		remove_child(modal)                  # the scrim goes with it: input is free from this very line
	_leaving.erase(modal.get_instance_id())
	if modal == _exit_modal:
		_exit_modal = null
	closed_count += 1
	modal.stack = null
	modal._finish(result, reason)
	if is_instance_valid(modal):
		modal.queue_free()
	closed.emit(modal, reason)
	changed.emit(_stack.size())
	return true


func close_top(result: Variant = null, reason: String = "close") -> bool:
	return close(top(), result, reason)


# Close everything top-down, then drop strays. Safe against callbacks that try to open (refused) or close (no-op).
func clear_all(reason: String = "clear") -> int:
	var n: = 0
	var was: = _clearing
	_clearing = true
	var guard: = MAX_DEPTH * 4
	while not _stack.is_empty() and guard > 0:
		guard -= 1
		if close(_stack.back(), null, reason):
			n += 1
	_stack.clear()
	for c in get_children():
		# anything still here was added behind the stack's back (a legacy view, a forgotten scrim): detach it, free it
		strays_swept += 1
		remove_child(c)
		c.queue_free()
	_clearing = was
	return n


# ── Android back ────────────────────────────────────────────────────────────────────────────────────────────

func handle_back() -> bool:
	var t: = top()
	if t == null:
		return false
	t.on_back()
	return true


# The last row of the back table (no modal, screen lets go, history empty): ask before leaving the app.
func request_exit() -> TWModal:
	if _exit_modal != null and _stack.has(_exit_modal):
		return _exit_modal
	var m: = TWExitConfirm.new()
	m.on_close = _on_exit_closed
	_exit_modal = open(m)
	return _exit_modal


func _on_exit_closed(result: Variant, _reason: String) -> void:
	if str(result) != "yes":
		return
	exit_confirmed.emit()
	if quit_fn.is_valid():
		quit_fn.call()
	elif is_inside_tree():
		get_tree().quit()


# wire the screen manager: back() asks this stack first, and "no way back" opens the exit confirmation
func bind_screens(screens: TWScreens) -> void:
	screens.modals = self
	if not screens.exit_requested.is_connected(request_exit):
		screens.exit_requested.connect(request_exit)


# ── auto-pop ────────────────────────────────────────────────────────────────────────────────────────────────

# The modal left the tree without going through close(): queue_free()/free() from outside, a reparent, or the whole layer going
# away. Pop it and run on_close once. The node is already on its way out, so only the book-keeping happens here.
func _on_modal_exiting(modal: TWModal) -> void:
	if not is_instance_valid(modal) or _leaving.has(modal.get_instance_id()):
		return
	var i: = _stack.find(modal)
	if i < 0:
		return
	_stack.remove_at(i)
	if modal == _exit_modal:
		_exit_modal = null
	closed_count += 1
	modal.stack = null
	# the layer is mid-removal here (Godot refuses add_child on a parent that is busy): a modal opened from this on_close
	# would be lost, so open() refuses for the duration
	_popping += 1
	modal._finish(null, "freed")
	_popping -= 1
	closed.emit(modal, "freed")
	changed.emit(_stack.size())


func _on_layer_exiting() -> void:
	_dead = true
	# children are detached after this signal; their own tree_exiting follows and pops them one by one ("freed")
