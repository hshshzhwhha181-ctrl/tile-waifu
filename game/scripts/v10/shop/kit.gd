class_name V10ShopKit
extends RefCounted

# V10ShopKit — shared drawing / feel helpers of Лавка 2 in the «Тишина и лак» system (UX §6, HUD_V2). Colours and
# type come ONLY from V10DS / V10Type (branch v10-hud2); no hex literals here.
#
#   tex(name)                 painted art from assets/v10/shop (png, else webp), cached
#   outfit_tex(img)           outfit art from assets/outfits
#   press(node, strong)       V9Feel answer of a tap (haptic + click); the node's own dip is done by the control
#   lbl(text, role, size, color, on_art)  V10Type.label with clip + ellipsis
#   hanko(host, center)       «печать-ханко»: falls in 140 ms, 1 squash frame, cinnabar shows in 300 ms (UX §6.8)
#   fly(host, from, to, tex, n)  reward cascade: n sprites, 80 ms step, pentatonic notes up (UX §6.7)
#   toast(host, text)         one line plate at the bottom third, fades in 4 s
#   inhale(nodes)             «Вдох»: ≤ 5 elements, +12 px and fade, 240 ms, step 40 ms (UX §6.7)

const DIR: = "res://assets/v10/shop/"
static var _tex: = {}
static var mute: = false       # selftests


static func tex(n: String) -> Texture2D:
	if _tex.has(n):
		return _tex[n]
	var t: Texture2D = null
	for ext in [".png", ".webp"]:
		if ResourceLoader.exists(DIR + n + ext):
			t = load(DIR + n + ext)
			break
	_tex[n] = t
	return t


static func outfit_tex(img: String) -> Texture2D:
	var p: = "res://assets/outfits/%s.webp" % img
	if _tex.has(p):
		return _tex[p]
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_tex[p] = t
	return t


static func fx_on() -> bool:
	return V10Hud2Util.fx_level() != "min"


static func press(_node: Node = null, strong: = false) -> void:
	if mute:
		return
	V9Feel.haptic("button" if not strong else "match")
	V9Feel.sound("pop")


static func deny(node: CanvasItem = null) -> void:
	if mute:
		return
	# «ошибка — глухое дерево, никогда не бззз» (UX §7.4): no shake on UI
	V9Feel.haptic("button")
	V10Hud2Util.sfx("wood_dull")
	if node:
		node.modulate = Color(1, 1, 1, 0.7)
		node.create_tween().tween_property(node, "modulate:a", 1.0, 0.2)


static func lbl(text: String, role: String, size: int, color: Color, on_art: = false) -> Label:
	return V10Type.label(text, role, size, color, on_art)


static func wrap(l: Label, lines: int) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return l


static func art(t: Texture2D, r: Rect2, cover: = false) -> TextureRect:
	var x: = TextureRect.new()
	x.texture = t
	x.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	x.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	x.position = r.position
	x.size = r.size
	x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return x


static func hanko(host: Control, center: Vector2) -> void:
	var t: = tex("hanko")
	if t == null or host == null:
		return
	var s: = TextureRect.new()
	s.texture = t
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s.size = Vector2(168, 168)
	s.position = center - s.size * 0.5
	s.pivot_offset = s.size * 0.5
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.name = "Hanko"
	host.add_child(s)
	if not mute:
		V10Hud2Util.sfx("stamp")
		V9Feel.haptic("match")
	if not fx_on():
		s.modulate.a = 0.0
		var t0: = s.create_tween()
		t0.tween_property(s, "modulate:a", 1.0, 0.12)
		t0.tween_interval(0.9)
		t0.tween_property(s, "modulate:a", 0.0, 0.3)
		t0.tween_callback(s.queue_free)
		return
	s.scale = Vector2(1.7, 1.7)
	s.modulate = Color(1, 1, 1, 0.0)
	var tw: = s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "modulate:a", 0.55, 0.14)
	tw.set_parallel(false)
	tw.tween_property(s, "scale", Vector2(1.08, 0.9), 0.033)       # one squash frame
	tw.tween_property(s, "scale", Vector2.ONE, 0.06)
	tw.tween_property(s, "modulate:a", 1.0, 0.3)                   # cinnabar soaks in
	tw.tween_interval(0.7)
	tw.tween_property(s, "modulate:a", 0.0, 0.3)
	tw.tween_callback(s.queue_free)


const PENTA: = [1.0, 1.122, 1.26, 1.498, 1.682, 2.0]


static func fly(host: Control, from: Vector2, to: Vector2, t: Texture2D, n: = 6) -> void:
	if host == null or t == null:
		return
	n = clampi(n, 1, 8)
	if not fx_on():
		n = 1
	for i in n:
		var s: = TextureRect.new()
		s.texture = t
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		s.size = Vector2(56, 56)
		s.pivot_offset = s.size * 0.5
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var jitter: = Vector2(randf_range(-40, 40), randf_range(-30, 30)) if n > 1 else Vector2.ZERO
		s.position = from + jitter - s.size * 0.5
		s.modulate.a = 0.0
		host.add_child(s)
		var tw: = s.create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(s, "modulate:a", 1.0, 0.08)
		var mid: = (from + to) * 0.5 + Vector2(-60, -80)
		tw.tween_method(func(k: float):
			var a: = (from + jitter).lerp(mid, k)
			var b: = mid.lerp(to, k)
			s.position = a.lerp(b, k) - s.size * 0.5
			s.scale = Vector2.ONE * lerpf(1.0, 0.55, k), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		var idx: = i
		tw.tween_callback(func():
			if not mute:
				V9Feel.sound("pop", PENTA[idx % PENTA.size()], -4.0)
			s.queue_free())


static func toast(host: Control, text: String) -> void:
	if host == null:
		return
	var old: = host.get_node_or_null("V10ShopToast")
	if old:
		old.name = "V10ShopToastOld"
		old.queue_free()
	var vs: = host.get_viewport_rect().size
	var w: = minf(624.0, vs.x - 48.0)
	var p: = ToastPlate.new()
	p.name = "V10ShopToast"
	p.size = Vector2(w, 72)
	p.position = Vector2((host.size.x - w) * 0.5, host.size.y * 0.70)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: = lbl(text, "ui", 22, V10DS.PAPER_100)
	V10Type.fit(l, text, "text_l", w - 48.0, 1, V10DS.PAPER_100)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(24, 0)
	l.size = Vector2(w - 48.0, 72)
	p.add_child(l)
	host.add_child(p)
	p.modulate.a = 0.0
	var tw: = p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


class ToastPlate:
	extends Control

	func _draw() -> void:
		V10Plate.draw_surface(self, Rect2(Vector2.ZERO, size), false, false, true, false, false, -1.0, V10DS.NIGHT_700)


static func inhale(nodes: Array) -> void:
	var k: = 0
	for n in nodes:
		if not (n is CanvasItem) or not is_instance_valid(n):
			continue
		if not fx_on():
			n.modulate.a = 0.0
			n.create_tween().tween_property(n, "modulate:a", 1.0, 0.12)
			continue
		var d: = mini(k, 4) * 0.04
		var p0: Vector2 = n.position
		n.position = p0 + Vector2(0, 12)
		n.modulate.a = 0.0
		var tw: Tween = n.create_tween().set_parallel(true)
		tw.tween_property(n, "position", p0, 0.24).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).set_delay(d)
		tw.tween_property(n, "modulate:a", 1.0, 0.24).set_delay(d)
		k += 1


# a rarity pill (UX §6.2: full saturation only on the pill)
static func rar_color(r: String) -> Color:
	return {"A": V10DS.JADE_300, "S": V10DS.ROSE_300, "SSR": V10DS.GOLD_300}.get(r, V10DS.PAPER_300)
