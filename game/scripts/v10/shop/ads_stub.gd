class_name V10AdsStub
extends RefCounted

# V10AdsStub — the 0.10 rewarded-ad stand-in: a 2 s dark overlay «ТЕСТ · реклама» with a thin progress line, then
# the reward. Only in test builds (V10ShopPay.is_test()). instant = true (selftests) answers at once without UI.

var host: Node = null
var instant: = false
var next_ok: = true


func available() -> bool:
	return V10ShopPay.is_test()


func show(_slot: String, done: Callable) -> void:
	if instant or host == null or not is_instance_valid(host):
		done.call(next_ok)
		return
	var ov: = Control.new()
	ov.name = "V10AdStub"
	ov.add_to_group(V10ShopKit.FX)     # a screen rebuild must not drop the overlay (its tween pays the reward)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: = ColorRect.new()
	bg.color = Color(V10DS.NIGHT_900, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(bg)
	var l: = V10Type.label("ТЕСТ · реклама", "display", 44, V10DS.PAPER_100)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.size = Vector2(560, 64)
	l.position = -l.size * 0.5
	ov.add_child(l)
	var sub: = V10Type.label("ролик идёт 2 секунды, деньги и данные не нужны", "ui", 18, V10DS.PAPER_500)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.size = Vector2(600, 32)
	sub.position = Vector2(-300, 48)
	ov.add_child(sub)
	var bar: = ColorRect.new()
	bar.color = V10DS.JADE_300
	bar.set_anchors_preset(Control.PRESET_CENTER)
	bar.position = Vector2(-240, 100)
	bar.size = Vector2(0, 2)
	ov.add_child(bar)
	host.add_child(ov)
	var tw: = ov.create_tween()
	tw.tween_property(bar, "size:x", 480.0, V10ShopData.AD_STUB_SEC)
	tw.tween_property(ov, "modulate:a", 0.0, 0.16)
	tw.tween_callback(func():
		ov.queue_free()
		done.call(next_ok))
