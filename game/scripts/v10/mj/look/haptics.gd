class_name V10MjHaptics
extends RefCounted

# V10MjHaptics — the table's vibration scale (docs/MODES.md §3.2, BENCHMARK MD-2). Patterns are [ms, amp, gap_ms]
# steps played by the V7Haptics autoload, so the «Вибрация» toggle (S.v7_haptics.on) and power apply, and every
# call marks V9Feel.haptic_frame so the catch-all tap pulse never doubles it.
#
#   V10MjHaptics.play(kind)            tap · tick · double · heartbeat · win
#   V10MjHaptics.combo(n)              n ≥ 3 → rumble that swells with the combo; below 3 → tick
#   V10MjHaptics.pattern_for(kind, n)  the steps (pure; selftest)
# Heartbeat follows MD-2: off at fx_level=min (together with shake). Everything else keeps working at min: the
# press answer is information, not decoration.

const KINDS: = {
	"tap": [[10, 0.35, 0]],
	"tick": [[15, 0.5, 0]],
	"double": [[12, 0.55, 60], [12, 0.55, 0]],
	"heartbeat": [[18, 0.7, 120], [14, 0.45, 0]],
	"win": [[18, 0.2, 40], [26, 0.38, 40], [36, 0.55, 40], [26, 0.38, 40], [18, 0.2, 0]],
}

static var played: Array = []     # [kind, steps] — dev / selftest log
static var log_on: = false


static func pattern_for(kind: String, n: = 0) -> Array:
	if kind == "rumble":
		# 40 ms of contact split in 4 steps that rise with the combo (×3 → 0.45…0.75, ×10+ → 0.7…1.0)
		var top: = clampf(0.75 + 0.03 * float(maxi(n - 3, 0)), 0.75, 1.0)
		var low: = top - 0.3
		var out: = []
		for i in 4:
			out.append([10, snappedf(lerpf(low, top, float(i) / 3.0), 0.01), 0])
		return out
	return KINDS.get(kind, []).duplicate(true)


static func _hp():
	var tree: = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("V7Haptics")


static func enabled() -> bool:
	var hp = _hp()
	return hp != null and hp.enabled()


static func play(kind: String, n: = 0) -> bool:
	if kind == "heartbeat" and V10MjTileMaterial.fx_level() == "min":
		return false
	var steps: = pattern_for(kind, n)
	if steps.is_empty():
		return false
	if log_on:
		played.append([kind, steps])
	V9Feel.haptic_frame = Engine.get_process_frames()
	var hp = _hp()
	if hp == null or not hp.enabled():
		return false
	if steps.size() == 1:
		hp.pulse(int(steps[0][0]), float(steps[0][1]), true)
	else:
		hp.pattern(steps)
	return true


static func combo(n: int) -> bool:
	return play("rumble", n) if n >= 3 else play("tick")


# total length of a pattern in ms (tests: tap 10, tick 15, double 2×12, rumble 40)
static func contact_ms(steps: Array) -> int:
	var t: = 0
	for s in steps:
		t += int(s[0])
	return t
