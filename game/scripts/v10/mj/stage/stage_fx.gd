class_name V10MjStageFx
extends RefCounted

# V10MjStageFx — every tween of the stage nodes goes through here, so «fx_level = min → zero motion tweens»
# (selftest 6) is a counter, not a hope. Motion = position / scale / rotation / offset; fades (modulate,
# visible_ratio) are information and stay at every level (UX §6.7: «при fx_level=min … проявление за 120 мс»).

const MOTION_PROPS: = ["position", "scale", "rotation", "offset", "position:x", "position:y", "scale:x", "scale:y"]
static var motion_tweens: = 0
static var fade_tweens: = 0


static func is_motion(prop: String) -> bool:
	return prop in MOTION_PROPS or prop.begins_with("position") or prop.begins_with("scale") or prop.begins_with("rotation")


# one property step on tween `t` (created by the caller with node.create_tween())
static func step(t: Tween, node: Object, prop: String, to, dur: float, trans: = Tween.TRANS_QUINT,
		ease: = Tween.EASE_OUT) -> PropertyTweener:
	if is_motion(prop):
		motion_tweens += 1
	else:
		fade_tweens += 1
	return t.tween_property(node, prop, to, dur).set_trans(trans).set_ease(ease)


static func reset_counters() -> void:
	motion_tweens = 0
	fade_tweens = 0
