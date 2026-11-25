class_name V10SkinAssemble
extends Control

# V10SkinAssemble — «Новый стиль стола» (D7): shown on the FIRST receipt of an SSR goddess and on every skin change,
# never on a plain entry. Чайная assembles from the centre in 0,6 с; Злата — the black lacquer floods out, the pen
# draws the gold ornament, sting (≤ once per 600 с). Two buttons: «Оставить» / «Вернуть «Пять ветров»».
#
#   V10SkinAssemble.play(root, home, skin_id, on_keep, on_revert) -> V10SkinAssemble
#     root: overlay parent; home: the Чайная Control whose children assemble (may be null in tests)
#   assemble_time() -> float     0,6 full / 0,3 mid / 0 min (selftest: ≤ 0,65 s, 0 tweens at min)

signal decided(keep: bool)

const T_FULL: = 0.6
const T_MID: = 0.3

var skin_id: = "zlata"
var home: Control
var level: = "full"
var tweens_made: = 0
var _k: = 0.0


static func assemble_time(lvl: String) -> float:
	match lvl:
		"min":
			return 0.0
		"mid":
			return T_MID
	return T_FULL


static func play(root: Control, home_ctrl: Control, sid: String, on_keep: = Callable(), on_revert: = Callable(), lvl: = "") -> V10SkinAssemble:
	var a: = V10SkinAssemble.new()
	a.skin_id = sid
	a.home = home_ctrl
	a.level = lvl if lvl != "" else V10HudSkin.fx_level()
	a.size = root.size
	a.mouse_filter = Control.MOUSE_FILTER_STOP
	a.decided.connect(func(keep: bool):
		if keep and on_keep.is_valid():
			on_keep.call()
		elif not keep and on_revert.is_valid():
			on_revert.call())
	root.add_child(a)
	a._start()
	return a


func _start() -> void:
	var dur: = assemble_time(level)
	if home and dur > 0.0:
		var c: = home.size * 0.5
		var i: = 0
		for ch in home.get_children():
			if not (ch is Control):
				continue
			var n: Control = ch
			var d: = (n.position + n.size * 0.5).distance_to(c)
			var delay: = clampf(d / maxf(home.size.length() * 0.5, 1.0), 0.0, 1.0) * dur * 0.5
			# every block lands on ITS OWN resting state (a mirrored corner keeps scale −1, a dimmed layer its alpha)
			var sc0: = n.scale
			var a0: = n.modulate.a
			n.pivot_offset = n.size * 0.5
			n.scale = sc0 * 0.94
			n.modulate.a = 0.0
			var tw: = n.create_tween().set_parallel()
			tw.tween_property(n, "scale", sc0, dur * 0.5).set_delay(delay).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tw.tween_property(n, "modulate:a", a0, dur * 0.5).set_delay(delay)
			tweens_made += 1
			i += 1
	if dur > 0.0:
		var t: = create_tween()
		t.tween_property(self, "_k", 1.0, dur).set_trans(Tween.TRANS_SINE)
		tweens_made += 1
	else:
		_k = 1.0
	if skin_id != V10HudSkin.BASE:
		V10HudSkin.sting(true)
	_buttons()


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var a: = 1.0 - _k
	if a <= 0.0 or level == "min":
		return
	# the lacquer floods outward from the centre and leaves a gold ring where the ornament is being drawn
	var c: = size * 0.5
	var R: = size.length() * 0.6 * _k
	var lac: = V10HudSkin.tok("night_900", skin_id)
	draw_rect(Rect2(Vector2.ZERO, size), Color(lac, 0.55 * a))
	if skin_id != V10HudSkin.BASE:
		draw_arc(c, R, 0.0, TAU, 128, Color(V10HudSkin.tok("gold_500", skin_id), 0.8 * a), 3.0, true)
		draw_arc(c, R - 10.0, 0.0, TAU * _k, 128, Color(V10HudSkin.tok("gold_300", skin_id), 0.6 * a), 1.5, true)


func _buttons() -> void:
	# a scrim under the decision so it reads over the assembling Чайная: fully opaque from just above the overline,
	# so no line of the Чайная under it (partner plate, buttons) shows through the title
	var g: = Gradient.new()
	g.set_color(0, Color(V10HudSkin.tok("night_900", skin_id), 0.0))
	g.set_color(1, Color(V10HudSkin.tok("night_900", skin_id), 0.97))
	var gt: = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 0.36)
	var scrim: = TextureRect.new()
	scrim.texture = gt
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.position = Vector2(0, size.y - 620)
	scrim.size = Vector2(size.x, 620)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	_corners()
	var w: = minf(size.x - 48.0, 656.0)
	var x: = (size.x - w) * 0.5
	var nm: = String(V10HudSkinData.skin(skin_id).name)
	var cap: = V10HudSkin.label("Новый стиль стола", 15, V10HudSkin.tok("gold_500", skin_id))
	cap.uppercase = true
	cap.position = Vector2(x, size.y - 360)
	cap.size = Vector2(w, 22)
	add_child(cap)
	var t: = V10HudSkin.label("«%s»" % nm, 44, V10HudSkin.tok("paper_100", skin_id), "display", w)
	t.position = Vector2(x, size.y - 336)
	t.size = Vector2(w, 60)
	add_child(t)
	var keep: = V10HudSkin.button("play", "Оставить", Rect2(x + (w - 440) * 0.5, size.y - 256, 440, 104), func(): _close(true))
	add_child(keep)
	var back: = V10HudSkin.button("secondary", "Вернуть «Пять ветров»", Rect2(x + (w - 440) * 0.5, size.y - 136, 440, 80), func(): _close(false))
	add_child(back)


# the skin's corner ornaments bloom at the four screen corners (Злата: gold vine with a feather)
func _corners() -> void:
	var t: = V10HudSkin.tex(String(V10HudSkinData.skin(skin_id).get("corner", "")))
	if t == null:
		return
	var s: = 168.0
	var spots: = [[Vector2(0, 0), Vector2(1, 1)], [Vector2(size.x, 0), Vector2(-1, 1)], [Vector2(0, size.y), Vector2(1, -1)], [Vector2(size.x, size.y), Vector2(-1, -1)]]
	var i: = 0
	for sp in spots:
		var tr: = TextureRect.new()
		tr.texture = t
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = Vector2(s, s)
		tr.position = sp[0]
		tr.scale = sp[1]
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		if level != "min":
			tr.modulate.a = 0.0
			var tw: = tr.create_tween()
			tw.tween_property(tr, "modulate:a", 1.0, 0.3).set_delay(T_FULL * 0.5 + 0.05 * i)
			tweens_made += 1
		i += 1


func _close(keep: bool) -> void:
	decided.emit(keep)
	if level == "min":
		queue_free()
		return
	var tw: = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_callback(queue_free)
