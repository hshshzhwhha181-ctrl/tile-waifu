class_name V10WeekLetterView
extends Control

# «Письмо недели» (Р10) as shown in Почта: the envelope's wax seal breaks, the washi sheet unfolds (lacquer 600 ms),
# the ink appears line by line under the pen (shader, pen_scratch), the signature last. Tap = write everything now.
#   V10WeekLetterView.open(parent, letter = V10WeekLetter.compose(...)) -> view        signal closed

signal closed

const INK: = V10RitUI.INK
const INK_SOFT: = V10RitUI.INK_SOFT

var letter: = {}
var _paper: Control
var _blocks: = []
var _tw: Tween
var _done: = false
var _ink_shader: Shader = preload("res://scripts/v10/rituals/ui/rit_ink.gdshader")
var _paper_shader: Shader = preload("res://scripts/v10/rituals/ui/rit_paper.gdshader")


static func open(parent: Control, l: Dictionary) -> V10WeekLetterView:
	var v: = V10WeekLetterView.new()
	v.letter = l
	v.size = parent.size
	parent.add_child(v)
	return v


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var W: = size.x
	var M: = 40.0
	add_child(V10RitUI.panel(Rect2(Vector2.ZERO, size), V10RitUI.NIGHT900, 0))
	var over: = V10RitUI.label("Почта · письмо недели", 15, V10RitUI.GOLD500, "over")
	over.position = Vector2(M, 56)
	add_child(over)
	var ph: = minf(size.y - 300, 900.0)
	_paper = Control.new()
	_paper.position = Vector2(M - 8, 110)
	_paper.size = Vector2(W - 2 * M + 16, ph)
	_paper.pivot_offset = Vector2(_paper.size.x * 0.5, 0)
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)
	var sheet: = ColorRect.new()
	sheet.size = _paper.size
	var pm: = ShaderMaterial.new()
	pm.shader = _paper_shader
	pm.set_shader_parameter("rect_size", _paper.size)
	sheet.material = pm
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(sheet)
	# fold line
	_paper.add_child(V10RitUI.panel(Rect2(0, ph * 0.5, _paper.size.x, 1), Color(0, 0, 0, 0.06), 0))
	var x: = 40.0
	var tw: = _paper.size.x - 80
	var y: = 44.0
	var date: = V10RitUI.label(str(letter.get("subj", "Письмо недели")), 18, INK_SOFT, "body", 800)
	date.position = Vector2(x, y)
	_paper.add_child(date)
	y += 44
	var parts: = [[str(letter.get("open", "")), 38, INK]]
	for f in letter.get("facts", []):
		parts.append(["• " + str(f), 34, INK])
	parts.append([str(letter.get("close", "")), 36, INK])
	for p in parts:
		var l: = V10RitUI.wrap_w(V10RitUI.label(str(p[0]), int(p[1]), p[2], "hand"), tw)
		l.label_settings.shadow_color = Color(0, 0, 0, 0)
		l.position = Vector2(x, y)
		_paper.add_child(l)
		var fnt: Font = l.label_settings.font
		var lh: = fnt.get_height(int(p[1]))
		var mh: = fnt.get_multiline_string_size(str(p[0]), HORIZONTAL_ALIGNMENT_LEFT, tw, int(p[1]), -1,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y
		var lines: = maxi(1, int(round(mh / lh)))
		var mat: = ShaderMaterial.new()
		mat.shader = _ink_shader
		mat.set_shader_parameter("progress", 0.0)
		mat.set_shader_parameter("line_h", lh)
		mat.set_shader_parameter("block_w", tw)
		mat.set_shader_parameter("lines", float(lines))
		l.material = mat
		_blocks.append(l)
		y += lines * lh + 22
	var sign: = V10RitUI.label("— " + str(letter.get("sign", "")), 46, V10RitUI.INK_SIGN, "hand")
	sign.label_settings.shadow_color = Color(0, 0, 0, 0)
	sign.position = Vector2(40, minf(y + 6, ph - 90))
	sign.size.x = _paper.size.x - 80
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sign.modulate.a = 0.0
	_paper.add_child(sign)
	var seal: = V10RitUI.tex(V10RitUI.ART + "envelope.webp", Rect2(_paper.size.x - 150, ph - 86, 110, 84))
	seal.modulate.a = 0.0
	_paper.add_child(seal)
	# the sheet is as tall as the letter
	ph = minf(ph, y + 130)
	_paper.size.y = ph
	sheet.size.y = ph
	pm.set_shader_parameter("rect_size", _paper.size)
	sign.position.y = y + 4
	seal.position = Vector2(40, ph - 100)
	var ok: = V10RitUI.button("Ответить улыбкой", Rect2((W - 560) * 0.5, size.y - 150, 560, 104), "primary", _close)
	add_child(ok)
	ok.modulate.a = 0.0
	# unfold, then write
	var fx: = V9Feel.can_fx()
	_paper.scale = Vector2(1.0, 0.04 if fx else 1.0)
	_paper.modulate.a = 0.0
	_tw = create_tween()
	_tw.tween_property(_paper, "modulate:a", 1.0, 0.15)
	_tw.parallel().tween_property(_paper, "scale", Vector2.ONE, 0.6 if fx else 0.01).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	_tw.parallel().tween_callback(func(): V10RitUI.sfx("paper_fan", "whoosh", 1.3, -8.0))
	for b in _blocks:
		var mat: ShaderMaterial = b.material
		var dur: = 0.9 if b == _blocks[0] else 0.55
		_tw.tween_callback(func(): V10RitUI.sfx("pen_scratch", "flip", randf_range(0.95, 1.08), -6.0))
		_tw.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.1, dur if fx else 0.12)
	_tw.tween_property(sign, "modulate:a", 1.0, 0.4)
	_tw.parallel().tween_property(seal, "modulate:a", 1.0, 0.4)
	_tw.tween_callback(func():
		_done = true
		V9Feel.success(sign, "", 0.5))
	_tw.tween_property(ok, "modulate:a", 1.0, 0.3)
	V10RitUI.inhale([over])


func _gui_input(e: InputEvent) -> void:
	if _done:
		return
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		accept_event()
		finish_now()


func finish_now() -> void:
	if _tw and _tw.is_valid():
		_tw.custom_step(30.0)
	_done = true


func _close() -> void:
	var t: = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(func():
		closed.emit()
		queue_free())
