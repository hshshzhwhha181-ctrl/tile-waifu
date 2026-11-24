class_name V10MjClassicPresence
extends Control

# The heroine in a «Классика» match when no presence director was passed in (args.presence) and the stage lane
# (V10MjPresence, branch v10-mj-stage) is not in the tree yet. Same contract — attach / on(event, data) / sacred /
# input_on — and the same hard rule (MODES §3.1): nothing of her is ever drawn over the sacred zone while input is
# on. She lives in the arch window of the top band (her painted waist-up frames, assets/v08/emotions), the Приём
# ring around it fills with pairs, motes of a pair fly to her (≤ 8, alpha ≤ 0.6, ≤ 0.45 s), a line is written at her
# shoulder (left of the window, inside the band), a wink on «motif», a glance on every pick.
#
# When V10MjPresence exists, V10MjClassicPresence.make() returns that instead: the classic screen does not care.

signal reacted(event: String, info: Dictionary)
signal finale_done
signal portrait_tapped

const EMO: = "res://assets/v08/emotions/%s_%s.webp"
const FRAME_OF: = {"rest": "shy", "smile": "happy", "ah": "surprised", "win": "happy", "lose": "sad", "bite": "pout", "wink": "happy"}
const STAGE_PRESENCE: = "res://scripts/v10/mj/stage/presence.gd"

var hero: = "mc"
var accent: = Color("ff8fb8")
var input_on: = true
var band: = Rect2(0, 0, 720, 120)
var win_rect: = Rect2()
var text_rect: = Rect2()
var sacred_rects: Array = []
var charge: = 0.0
var charge_need: = 10
var fx: = "full"
var log: Array = []
var _frame: = "rest"
var _tex: = {}
var _line: Label
var _line_tw: Tween
var _react_tw: Tween
var _wink: = 0.0
var _look: = Vector2.ZERO
var _motes: Array = []
var _last_line_t: = -100.0
var _last_react_t: = -100.0
var _moves_since_react: = 0
var _bob: = 0.0
var _fin: = 0.0
var _fin_frame: = ""


# the director to use: the stage lane's if present, else this one
static func make(parent: Control, hero_id: String, opts: = {}) -> Object:
	if ResourceLoader.exists(STAGE_PRESENCE):
		var cls = load(STAGE_PRESENCE)
		if cls:
			var p = cls.new()
			if p.has_method("attach"):
				return p.attach(parent, hero_id, opts)
	var me: = V10MjClassicPresence.new()
	return me.attach(parent, hero_id, opts)


func attach(parent: Control, hero_id: String, opts: = {}) -> V10MjClassicPresence:
	hero = hero_id
	accent = V10MjClassicStyle.accent(hero_id)
	charge_need = int(opts.get("charge_need", 10))
	fx = String(opts.get("fx", G.fx_level() if G.has_method("fx_level") else "full"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "V10MjClassicPresence"
	z_index = 400
	parent.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_line = V10MjClassicStyle.label("", 26, V10MjClassicStyle.TOK.paper100, "title", 600)
	_line.label_settings.font = load("res://assets/fonts/playfair-i-cyr.woff2") if ResourceLoader.exists("res://assets/fonts/playfair-i-cyr.woff2") else _line.label_settings.font
	V10MjClassicStyle.shadow(_line, 0.8)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.modulate.a = 0.0
	add_child(_line)
	set_band(opts.band_rect if opts.get("band_rect") is Rect2 else Rect2(0, 0, get_viewport_rect().size.x, 120))
	return self


func set_band(r: Rect2) -> void:
	band = r
	var wh: = clampf(r.size.y - 16.0, 96.0, 300.0)
	var ww: = clampf(wh * 0.82, 88.0, 220.0)
	win_rect = Rect2(r.end.x - ww - 18.0, r.position.y + (r.size.y - wh) * 0.5 + 2.0, ww, wh)
	text_rect = Rect2(r.position.x + 104.0, r.end.y - 44.0, win_rect.position.x - r.position.x - 120.0, 40.0)
	if r.size.y > 200.0:
		text_rect = Rect2(r.position.x + 32.0, r.end.y - 96.0, win_rect.position.x - r.position.x - 48.0, 84.0)
	if _line:
		_line.position = text_rect.position
		_line.size = text_rect.size
	queue_redraw()


func sacred(r: Rect2) -> void:
	sacred_rects.append(r.grow(8.0))


func clear_sacred() -> void:
	sacred_rects.clear()


func set_mode(_m: String) -> void:
	pass


func apply_settings() -> void:
	pass


func _gui_input(_e: InputEvent) -> void:
	pass


func _tex_of(frame: String) -> Texture2D:
	var f: String = FRAME_OF.get(frame, frame)
	var key: = "%s_%s" % [hero, f]
	if not _tex.has(key):
		var p: = EMO % [hero, f]
		if not ResourceLoader.exists(p):
			p = EMO % ["mc", f]
		_tex[key] = load(p) if ResourceLoader.exists(p) else null
	return _tex[key]


func _now() -> float:
	return V10MjClassicStyle.now()


func _react(frame: String, hold: float) -> void:
	_frame = frame
	_last_react_t = _now()
	_moves_since_react = 0
	queue_redraw()
	if _react_tw and _react_tw.is_valid():
		_react_tw.kill()
	_react_tw = create_tween()
	_react_tw.tween_interval(hold)
	_react_tw.tween_callback(func():
		_frame = "rest"
		queue_redraw())


func say(text: String, force: = false) -> bool:
	var now: = _now()
	if not force and now - _last_line_t < 20.0:
		return false
	_last_line_t = now
	_line.text = text
	if _line_tw and _line_tw.is_valid():
		_line_tw.kill()
	_line.visible_ratio = 0.0
	_line.modulate.a = 1.0
	_line_tw = create_tween()
	_line_tw.tween_property(_line, "visible_ratio", 1.0, 0.4)
	_line_tw.tween_interval(4.0)
	_line_tw.tween_property(_line, "modulate:a", 0.0, 0.3)
	return true


func on(event: String, data: = {}) -> Dictionary:
	var acts: Array = []
	match event:
		"pick":
			if data.has("pos"):
				_look = ((data.pos as Vector2) - win_rect.get_center()).normalized()
			acts.append("glance")
		"pair":
			_moves_since_react += 1
			charge = minf(1.0, charge + 1.0 / float(charge_need))
			if data.has("pos") and fx != "min":
				_burst(data.pos)
				acts.append("motes")
			if _moves_since_react >= 3:
				_react("smile", 0.4)
				acts.append("smile")
		"combo":
			var n: = int(data.get("n", 0))
			if n >= 5:
				_react("ah", 0.6)
				acts.append("clap")
			elif n >= 3:
				_react("smile", 0.4)
				acts.append("nod")
		"motif":
			_wink = 1.0
			_react("wink", 0.45)
			create_tween().tween_property(self, "_wink", 0.0, 0.45)
			acts.append("wink")
		"signature":
			charge = minf(1.0, charge + 0.25)
			_react("ah", 0.6)
			acts.append("ah")
		"last_pair":
			_react("rest", 1.4)
			acts.append("look_camera")
		"idle":
			var kind: = String(data.get("kind", ""))
			if kind == "shuffle":
				_react("ah", 0.8)
				if say("Ходов нет — перемешала", true):
					acts.append("line")
			else:
				_react("rest", 1.2)
				if say(String(data.get("text", "Я тут. Смотри по краям."))):
					acts.append("line")
		"win":
			input_on = false
			_finale("win")
			_react("win", 3.0)
			say(String(data.get("text", "Стол чист! Красиво.")), true)
			acts.append("win")
			get_tree().create_timer(1.2).timeout.connect(func(): finale_done.emit())
		"lose":
			input_on = false
			_finale("lose")
			_react("lose", 1.2)
			acts.append("lose")
			get_tree().create_timer(1.2).timeout.connect(func(): finale_done.emit())
		"danger", "wave", "ult", "mech_intro":
			pass
	var info: = {"event": event, "acts": acts}
	log.append([_now(), event, acts])
	reacted.emit(event, info)
	queue_redraw()
	return info


# the finish: she comes out large over the (now inactive) table, waist up, in her win / lose frame
func _finale(frame: String) -> void:
	_fin_frame = frame
	if fx == "min":
		_fin = 1.0
		return
	var tw: = create_tween()
	tw.tween_property(self, "_fin", 1.0, 0.45).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func finale_rect() -> Rect2:
	var vs: = get_viewport_rect().size
	var w: = minf(420.0, vs.x * 0.62)
	var h: = w * 1.25
	return Rect2((vs.x - w) * 0.5, band.end.y + 24.0 + (1.0 - _fin) * 40.0, w, h)


func _burst(from: Vector2) -> void:
	var n: = 6 if fx == "full" else 3
	var to: = win_rect.get_center()
	for k in n:
		var m: = {"p0": from + Vector2(randf_range(-18, 18), randf_range(-12, 12)), "t": -0.03 * k, "p1": to + Vector2(randf_range(-20, 20), randf_range(-20, 20)), "a": 0.6}
		_motes.append(m)


func _process(dt: float) -> void:
	_bob += dt
	if not _motes.is_empty():
		for m in _motes:
			m.t += dt
		_motes = _motes.filter(func(m): return m.t < 0.42)
	queue_redraw()


# for the selftest: rects of everything she draws right now
func audit_rects() -> Array:
	var out: = [win_rect.grow(8.0)]
	if _fin > 0.001:
		out.append(finale_rect())
	if _line and _line.modulate.a > 0.01 and _line.text != "":
		out.append(Rect2(_line.position, _line.size))
	return out


func sacred_hits() -> Array:
	var hits: = []
	if not input_on:
		return hits
	for r in audit_rects():
		for s in sacred_rects:
			if (r as Rect2).intersects(s):
				hits.append([r, s])
	return hits


func _draw() -> void:
	var T: = V10MjClassicStyle.TOK
	var r: = win_rect
	if r.size.x <= 0.0:
		return
	# arch window: dark lacquer, her accent light inside, the frame clipped to the arch
	var arch: = _arch(r, 0.0)
	draw_colored_polygon(arch, T.night800)
	var glow: = Color(accent, 0.22)
	draw_colored_polygon(_arch(r.grow(-6.0), 0.0), glow)
	var tex: = _tex_of(_frame)
	if tex:
		var tw: = float(tex.get_width())
		var th: = float(tex.get_height())
		# head-and-shoulders crop of the waist-up frame, slight breath and glance
		var src: = Rect2(tw * 0.2, th * 0.0, tw * 0.6, tw * 0.6 * r.size.y / r.size.x)
		src.size.y = minf(src.size.y, th)
		var breath: = 0.0 if fx == "min" else sin(_bob * 1.6) * 1.5
		var dst: = Rect2(r.position + Vector2(_look.x * 2.0, breath + 4.0), r.size)
		var uv: = PackedVector2Array()
		for p in _arch(r.grow(-3.0), 0.0):
			var q: = (p - dst.position) / dst.size
			uv.append((src.position + q * src.size) / Vector2(tw, th))
		draw_colored_polygon(_arch(r.grow(-3.0), 0.0), Color.WHITE, uv, tex)
	# rim and the Приём ring (one honest gauge): from the left foot over the top to the right foot
	draw_polyline(_arch_open(r, 0.0), Color(T.gold700, 0.6), 1.5, true)
	var ring: = _arch_open(r.grow(5.0), 0.0)
	draw_polyline(ring, Color(T.night600, 0.9), 5.0, true)
	if charge > 0.001:
		var k: = int(round(charge * (ring.size() - 1)))
		if k >= 1:
			draw_polyline(ring.slice(0, k + 1), accent, 5.0, true)
			draw_circle(ring[k], 4.5, accent.lightened(0.4))
	if _fin > 0.001 and _fin_frame != "":
		var fr: = finale_rect()
		var ftex: = _tex_of(_fin_frame)
		var col: = Color(1, 1, 1, _fin)
		draw_colored_polygon(_arch(fr.grow(10.0), 0.0), Color(T.night800, 0.9 * _fin))
		draw_colored_polygon(_arch(fr.grow(4.0), 0.0), Color(accent, 0.3 * _fin))
		if ftex:
			var fw: = float(ftex.get_width())
			var fh: = float(ftex.get_height())
			var src2: = Rect2(fw * 0.04, 0.0, fw * 0.92, minf(fh, fw * 0.92 * fr.size.y / fr.size.x))
			var uv2: = PackedVector2Array()
			var poly: = _arch(fr, 0.0)
			for q in poly:
				var qq: = (q - fr.position) / fr.size
				uv2.append((src2.position + qq * src2.size) / Vector2(fw, fh))
			draw_colored_polygon(poly, col, uv2, ftex)
		draw_polyline(_arch(fr.grow(6.0), 0.0), Color(T.gold500, 0.8 * _fin), 2.0, true)
	if _wink > 0.01:
		var c: = r.position + Vector2(r.size.x * 0.78, r.size.y * 0.2)
		for a in 4:
			var ang: = PI * 0.5 * a + PI / 4
			draw_line(c, c + Vector2(cos(ang), sin(ang)) * 12.0 * _wink, Color(T.gold300, _wink), 2.0, true)
	for m in _motes:
		var t: float = clampf(m.t / 0.4, 0.0, 1.0)
		if m.t < 0.0:
			continue
		var p0: Vector2 = m.p0
		var p1: Vector2 = m.p1
		var ctrl: = p0.lerp(p1, 0.5) + Vector2(0, -80)
		var p: = p0.lerp(ctrl, t).lerp(ctrl.lerp(p1, t), t)
		draw_circle(p, 5.0 * (1.0 - 0.5 * t), Color(accent.lightened(0.3), 0.6 * (1.0 - 0.6 * t)))


func _arch(r: Rect2, _pad: float) -> PackedVector2Array:
	var pts: = PackedVector2Array()
	var rad: = r.size.x * 0.5
	var cy: = r.position.y + rad
	pts.append(Vector2(r.position.x, r.end.y))
	for i in 25:
		var a: = PI + PI * i / 24.0
		pts.append(Vector2(r.position.x + rad + cos(a) * rad, cy + sin(a) * rad))
	pts.append(Vector2(r.end.x, r.end.y))
	return pts


func _arch_open(r: Rect2, pad: float) -> PackedVector2Array:
	var pts: = _arch(r, pad)
	return pts
