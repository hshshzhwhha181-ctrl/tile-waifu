class_name V7Replay
extends Control




const MAX_LEN: = 9.0

var play
var board: TrayBoard
var rec: Dictionary
var skip: = false
var prog: RBox
var prog_w: = 0.0
var combo_lbl: Label

static func has_log(b: TrayBoard) -> bool:
	return b != null and is_instance_valid(b) and b.has_meta("v7_rec") and not (b.get_meta("v7_rec").log as Array).is_empty()


static func show_start(b: TrayBoard) -> void :
	var rec: Dictionary = b.get_meta("v7_rec")
	for i in b.tiles.size():
		var t: Tile = b.tiles[i]
		t.kill_move()
		t.hint(false)
		t.visible = true
		t.position = t.home
		t.scale = Vector2.ONE
		t.rotation = 0.0
		t.modulate = Color.WHITE
		t.z_index = 0
		if t.shadow:
			t.shadow.visible = true
			t.shadow.position = Vector2(9, 15)
		var f0: int = int(rec.faces[i]) if i < rec.faces.size() else t.face
		if f0 < 36 and t.face < 36:
			t.set_face(f0)
		elif t.face < 36:
			t.set_face(t.face)
			t.mat.set_shader_parameter("gold", 1.0 if rec.gold[i] else 0.0)
		for k in ["flash", "sel", "dim", "ice"]:
			t.mat.set_shader_parameter(k, 0.0)
		if t.glow:
			t.glow.modulate.a = 0.0
		if t.back_spr:
			t.back_spr.visible = false
		t.face_spr.visible = t.face < 36


static func hide_hud(p: Control, keep_nodes: Array) -> Array:
	var keep: = {p.board: true}
	for k in keep_nodes:
		keep[k] = true
	var kids: Array = p.get_children()
	for i in mini(3, kids.size()):
		keep[kids[i]] = true
	var hid: = []
	for c in kids:
		if c is CanvasItem and not keep.has(c) and c.visible:
			c.visible = false
			hid.append(c)
	return hid

static func show_nodes(nodes: Array) -> void :
	for c in nodes:
		if is_instance_valid(c):
			c.visible = true

static func hide_all(b: TrayBoard) -> void :
	for t in b.tiles:
		t.kill_move()
		t.visible = false


static func run(p, layer: Control) -> void :
	if not has_log(p.board):
		p.main.toast("Повтор этой партии недоступен", "play")
		return
	var r: = V7Replay.new()
	r.play = p
	r.board = p.board
	r.rec = p.board.get_meta("v7_rec")
	r.size = p.size
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_child(r)
	layer.visible = false
	var hid: = hide_hud(p, [r])
	await r._play()
	show_nodes(hid)
	if is_instance_valid(layer):
		layer.visible = true
	if is_instance_valid(r):
		r.queue_free()

func _play() -> void :
	var W: = size.x
	var H: = size.y

	var top: = UI.rbox("graphite", Rect2(W * 0.5 - 220, 120, 440, 92), 24, 3, 10)
	add_child(top)
	top.add_child(V8Art.rect(V8Art.nav("play"), Rect2(10, 10, 72, 72)))
	var tl: = UI.label("Повтор партии", 26, UI.INK, UI.DARK, 3, "title", 800)
	tl.position = Vector2(90, 8)
	top.add_child(tl)
	var entries: Array = rec.log
	var sub: = UI.label("%s · пар: %d" % [String(play.cfg.get("code", "")) if play.cfg.get("code", "") != "" else String(play.cfg.get("name", "")), entries.size()], 17, UI.MUTED, UI.DARK, 3)
	sub.position = Vector2(92, 46)
	top.add_child(sub)
	var bar: = Common.progress_bar(top, Rect2(92, 72, 330, 12), 0.0, "gold")
	prog = bar
	prog_w = 330 - 6
	combo_lbl = UI.label("", 64, Color("ffe7a6"), Color(0.25, 0.08, 0.1), 8, "title", 900)
	combo_lbl.size = Vector2(W, 80)
	combo_lbl.position = Vector2(0, 260)
	combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_lbl.modulate.a = 0.0
	combo_lbl.pivot_offset = Vector2(W * 0.5, 40)
	add_child(combo_lbl)
	var sk: = JButton.make("Пропустить", "graphite", Rect2(W * 0.5 - 140, H - 120, 280, 76), null, 26)
	sk.pressed.connect( func(): skip = true)
	add_child(sk)
	gui_input.connect( func(e):
		if e is InputEventMouseButton and e.pressed:
			skip = true)
	UI.pop_in(top, 0.0, 0.8)

	show_start(board)
	Sfx.play("whoosh", 0.9)
	for t in board.tiles:
		var tw: Tween = t.create_tween()
		t.modulate.a = 0.0
		tw.tween_property(t, "modulate:a", 1.0, 0.25).set_delay(0.002 * t.get_index())
	await get_tree().create_timer(0.7).timeout

	var total: = 0.0
	var prev: = 0.0
	var gaps: = []
	for e in entries:
		var g: float = maxf(0.0, float(e.t) - prev)
		prev = float(e.t)
		gaps.append(g)
		total += g
	var k: = maxf(1.0, total / MAX_LEN)
	var shown: = {}
	for n in entries.size():
		if skip or not is_inside_tree():
			break
		var e: Dictionary = entries[n]
		var wait: = clampf(float(gaps[n]) / k, 0.07, 0.55) if n > 0 else 0.1
		await get_tree().create_timer(wait).timeout
		if skip or not is_inside_tree():
			break
		_pop_pair(e, n)
		for i in e.i:
			shown[int(i)] = true
		prog.size.x = maxf(12.0, prog_w * float(n + 1) / entries.size())

	for i in board.tiles.size():
		if not shown.has(i) and board.tiles[i].visible:
			var t: Tile = board.tiles[i]
			var tw: Tween = t.create_tween()
			tw.tween_property(t, "modulate:a", 0.0, 0.2 if not skip else 0.05)
			tw.tween_callback(t.hide)
	if not skip and is_inside_tree():
		Sfx.play("win", 1.15, -8)
		Fx.burst(self, Vector2(W * 0.5, H * 0.45), "confetti", 50, Color.WHITE, 1.0)
		await get_tree().create_timer(0.9).timeout
	if is_inside_tree():
		await get_tree().create_timer(0.1).timeout
		hide_all(board)

func _pop_pair(e: Dictionary, n: int) -> void :
	var pts: = []
	for i in e.i:
		var ii: = int(i)
		if ii < 0 or ii >= board.tiles.size():
			continue
		var t: Tile = board.tiles[ii]
		pts.append(t)
	if pts.is_empty():
		return
	var mid: = Vector2.ZERO
	for t in pts:
		mid += t.position
	mid /= pts.size()
	for t in pts:
		t.z_index = 100
		var tw: Tween = t.create_tween()
		tw.tween_property(t, "position", mid + (t.position - mid) * 0.6 + Vector2(0, -16), 0.09)
		tw.parallel().tween_method( func(v): t.mat.set_shader_parameter("flash", v), 0.0, 1.0, 0.09)
		tw.tween_property(t, "scale", Vector2(1.22, 1.22), 0.05)
		tw.tween_property(t, "scale", Vector2.ZERO, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "modulate:a", 0.0, 0.13)
		tw.tween_callback(t.hide)
	var c: = int(e.get("c", 1))
	var gp: Vector2 = (pts[0] as Tile).get_parent().get_global_transform_with_canvas() * mid
	var lp: = get_global_transform_with_canvas().affine_inverse() * gp
	Fx.burst(self, lp, "sparkle", 10 + mini(c, 8) * 2, Color(1, 0.85, 0.45) if e.get("g", false) else Color(1, 0.92, 0.95), 0.9)
	Sfx.play("match%d" % clampi(c - 1, 0, 7), 1.0, -5)
	if c >= 3:
		combo_lbl.text = "Комбо ×%d" % c
		combo_lbl.modulate.a = 1.0
		combo_lbl.scale = Vector2(1.25, 1.25)
		var tw2: = combo_lbl.create_tween()
		tw2.tween_property(combo_lbl, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
		tw2.tween_interval(0.35)
		tw2.tween_property(combo_lbl, "modulate:a", 0.0, 0.25)
