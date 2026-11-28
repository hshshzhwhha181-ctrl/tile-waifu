class_name TWNavFakeScreen
extends TWScreen

# Test double of a screen (P23): behaviour is chosen by the params of go(), every hook is logged in `log` (a static list shared by
# all instances, cleared by the selftest). params: intro = "" | "hang" (a Signal that never fires) | "late" (fires on
# `late_signal`, driven by the test); block = true (can_back false); consume = true (on_back handles it once).
# Used only by the nav selftest and by lanes that need a throw-away screen: it has no ScreenSpec of its own.

signal late_signal
signal never

static var log: Array = []
static var last: TWNavFakeScreen = null

var consumed: = false
var forced: = false


func enter(p: Dictionary) -> void:
	last = self
	log.append("enter:%s" % spec.id)


func intro() -> Signal:
	match str(params.get("intro", "")):
		"hang":
			return never
		"late":
			return late_signal
	return Signal()


func intro_forced() -> void:
	forced = true
	log.append("forced:%s" % spec.id)


func on_back() -> bool:
	if bool(params.get("consume", false)) and not consumed:
		consumed = true
		log.append("consumed:%s" % spec.id)
		return true
	return false


func can_back() -> bool:
	return not bool(params.get("block", false))


func exit() -> void:
	log.append("exit:%s" % spec.id)
