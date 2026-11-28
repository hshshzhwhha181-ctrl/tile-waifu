class_name TWScreen
extends Control

# TWScreen (P23 / WP8a): base class of every v11 screen. A screen never receives the `main` god-object: it gets a typed
# TWContext (`ctx`) and its own ScreenSpec (`spec`) from TWScreens before enter() runs.
#
# Contract (all hooks are optional, the defaults do nothing):
#   enter(params)      the screen is mounted and has `ctx`/`spec`: build the view, subscribe on ctx.bus
#   intro() -> Signal  return a Signal that fires when the entrance animation is done; the default (null Signal) means "no
#                      animation". While it is pending TWScreens is TRANSITIONING; after TWScreens.WATCHDOG_MS it forces
#                      the transition to finish whatever the animation does and calls intro_forced()
#   intro_forced()     the watchdog fired: snap the animation to its end state
#   on_back() -> bool  consume a back press inside the screen (close a sub-view, step a wizard); true = handled
#   can_back() -> bool false = the manager must not navigate away on back (a match asks for confirmation first)
#   exit()             the screen is about to be freed: drop what is not owned by the node tree
#
# The shell never writes state from a screen: a screen calls core commands (ctx.state is read-only by convention and by
# lint) and animates the events it gets from ctx.bus.

var ctx: TWContext = null
var spec: ScreenSpec = null
var params: Dictionary = {}


func enter(_params: Dictionary) -> void:
	pass


func intro() -> Signal:
	return Signal()


func intro_forced() -> void:
	pass


func on_back() -> bool:
	return false


func can_back() -> bool:
	return true


func exit() -> void:
	pass
