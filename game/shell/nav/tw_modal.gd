class_name TWModal
extends Control

# TWModal (P24 / WP8b): base class of every v11 modal (sheet, dialog, confirm, full-screen view). A modal is only ever opened
# through the ModalStack (`stack.open(modal)`); nothing else adds children to the modal layer.
#
# Why it exists: the 0.12.1 "nothing is clickable" bug was a full-screen view in main.overlay that lacked the meta tag the
# legacy go() whitelist looked for, so its STOP scrim survived the screen change and ate every tap. Here
#   * the SCRIM IS A CHILD OF THE MODAL (child 0, created in _init): it can never outlive the modal or be forgotten, and
#     nobody else owns a dimmer that has to be removed by hand;
#   * the modal root itself ignores the mouse (MOUSE_FILTER_IGNORE); only the scrim and the content the subclass builds block;
#   * `on_close` is a plain Callable (result, reason) that the stack calls EXACTLY ONCE on every way out: close(), back,
#     scrim tap, clear_all (screen change), the modal being freed by someone else, the stack leaving the tree, a refused open.
#
# Subclass contract (all optional)
#   _build(opts)       the modal is in the tree: add the content under `self` (the scrim is already child 0)
#   on_back() -> bool  Android back reached this modal. Default: close it when `dismissable`; either way the back press is
#                      swallowed (a modal always owns back while it is the top one). Override to step a wizard: return true
#                      after handling a step, or call super.on_back()
#   _closed(result, reason)  hook that runs just before on_close
#
# Closing: close(result = null, reason = "close") from anywhere inside the modal's own code (a button handler). Closing is
# idempotent and safe to call from on_close or from a signal handler of the modal's own nodes: the node is detached at once and
# freed with queue_free() on the next idle frame.
#
#   dismissable = false      back and a scrim tap do nothing (a forced choice); the modal still closes through close()/clear_all
#   scrim_tap_closes = false the scrim only blocks, a tap on it does nothing (back still closes a dismissable modal)
#   scrim_alpha              opacity of the black scrim, 0.0 = an invisible but still blocking catcher

signal closed(result: Variant, reason: String)

enum Life { NEW, OPEN, CLOSED }

var stack: ModalStack = null
var on_close: Callable = Callable()          # (result: Variant, reason: String) -> void
var result: Variant = null
var close_reason: = ""
var dismissable: = true
var scrim_tap_closes: = true
var scrim_alpha: = 0.62:
	set(v):
		scrim_alpha = clampf(v, 0.0, 1.0)
		if scrim != null:
			scrim.color = Color(0, 0, 0, scrim_alpha)
var scrim: ColorRect = null
var life: int = Life.NEW


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim = ColorRect.new()
	scrim.name = "Scrim"
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0, 0, 0, scrim_alpha)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_scrim_input)
	add_child(scrim)


func is_open() -> bool:
	return life == Life.OPEN


# called by ModalStack.open() once the modal is in the tree
func _opened(opts: Dictionary) -> void:
	life = Life.OPEN
	_build(opts)


func _build(_opts: Dictionary) -> void:
	pass


func _closed(_result: Variant, _reason: String) -> void:
	pass


func on_back() -> bool:
	if dismissable:
		close(null, "back")
	return true


func close(p_result: Variant = null, reason: String = "close") -> bool:
	if life == Life.CLOSED:
		return false
	if stack != null:
		return stack.close(self, p_result, reason)
	return _finish(p_result, reason)


# The one place where on_close runs. Idempotent: the Life flag flips before anything is called, so a callback that closes
# the same modal again (or a second path such as tree_exiting after close()) is a no-op.
func _finish(p_result: Variant, reason: String) -> bool:
	if life == Life.CLOSED:
		return false
	life = Life.CLOSED
	result = p_result
	close_reason = reason
	if scrim != null and is_instance_valid(scrim):
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scrim.visible = false
	_closed(p_result, reason)
	if on_close.is_valid():
		on_close.call(p_result, reason)
	closed.emit(p_result, reason)
	return true


func _scrim_input(ev: InputEvent) -> void:
	if life != Life.OPEN or not dismissable or not scrim_tap_closes:
		return
	var tap: = false
	if ev is InputEventMouseButton:
		tap = (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	elif ev is InputEventScreenTouch:
		tap = (ev as InputEventScreenTouch).pressed
	if tap:
		close(null, "scrim")
