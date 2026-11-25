class_name V10MetaTick
extends Node

# V10MetaTick — the only node of the meta core: polls V10Meta.tick() every 30 s and on app resume, so the day rolls
# over at 04:00 while the game is open and after it comes back from background. The integrator adds it ONCE:
#   project.godot [autoload]  V10MetaPoll="*res://scripts/v10/meta/meta_tick.gd"   (after V7Event)
#   — the autoload must NOT be named V10MetaTick: that is this script's class_name, and Godot 4 refuses a class
#   that hides an autoload singleton (none of the 0.9 autoload scripts has a class_name for the same reason);
# or main.gd _ready(): add_child(V10MetaTick.new()). It also flushes V10Notify's plan (marks due notifications as
# sent in the dev log) and saves nothing by itself: a day roll changes S.v10_meta only in memory, G.save() writes it
# with the next regular save (the home screen saves on day_rolled through its own refresh).

var _t: = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	V10Meta.tick()


func _process(dt: float) -> void:
	_t += dt
	if _t >= V10Meta.POLL_SECS:
		_t = 0.0
		V10Meta.tick()
		V10Notify.advance(V10Meta.now_unix())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_t = 0.0
		V10Meta.on_resumed()
		V10Notify.advance(V10Meta.now_unix())
